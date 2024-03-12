#!/bin/bash
#自动 MySQL 数据库备份脚本 - 此脚本会压缩并加密 MySQL 数据库备份为单文件并生成校验码。
#Automatic MySQL database backup script - This script will compress and encrypt the MySQL database backup as a single file and generate a checksum.
#Author: 10935336
#Creation date: 2022-09-28
#Modified date: 2024-03-12

#### Require ####
#运行本脚本需要 Percona XtraBackup 8.0，测试版本：8.0.35-30、8.0.31-24、8.0.30-23、8.0.29-22、8.0.28-21
#你可以在这里下载 Percona XtraBackup：https://www.percona.com/downloads

#### Note ####
#从 Percona XtraBackup 8.0.31-24 开始，qpress/QuickLZ 压缩备份已被弃用，并可能在未来版本中删除。
#我建议使用 Zstandard (zstd) 压缩算法。zstd 支持在 XtraBackup 8.0.30-23 版本加入。

#### Document ####
#备份恢复步骤：1.解密解压备份文件 2.准备备份文件 3.恢复备份
#备份解密解压命令：'xbstream -x --decompress --decrypt=AES256 --encrypt-key=<加密秘钥>    <    <备份文件>.xbstream.ase256'
#在 8.0.30-23 版本中 '--encrypt-key-file'选项有 BUG，使用此选项解密失败，所以你可能需要直接用'--encrypt-key'选项来输入密钥，其他版本不确定。
#备份准备方法：https://docs.percona.com/percona-xtrabackup/8.0/prepare-full-backup.html
#备份恢复方法：https://docs.percona.com/percona-xtrabackup/8.0/restore-a-backup.html

#### Prepare ####
#1.准备备份加密秘钥 enc_key
#备份加密密码请单行写入 enc_key 文件，可以使用 'openssl rand -base64 24' 生成密码（256位)，官方文档是错的，结尾不能有CRLF，目录不同请自定义，并使用 chmod 600 保护。
#或者直接使用秘钥生成命令：'printf '%s' "$(openssl rand -base64 24)" | sudo tee <秘钥目录> && echo'

#2.准备数据库配置文件 db_conf
#数据库用户和密码请用以下格式写入 db_conf 文件，也可以指定端口和主机名(ip)或套接字，目录不同请自定义，并使用 chmod 600 保护
#[client]
#user=username
#password=password
#socket=socket_path
#port=port
#host=ip


#### Variable #####
#你需要填写本节变量。
#You need to fill in the variables in this section.

#备份加密秘钥
readonly ENC_KEY=<加密秘钥路径>

#数据库配置文件
readonly DB_CONF=<数据库配置文件路径>


#可选命令默认留空''，填写这个可以忽略版本检查 '--no-server-version-check'
readonly OPT_CMD=''

#压缩命令，默认为'--compress=zstd'，取决于你的版本，也可以使用 qpress '--compress=quicklz'，或 lz4 '--compress=lz4'
readonly COMP_CMD='--compress=zstd'

#可选压缩命令，默认留空''，可选填压缩参数等，如 '--compress-threads=4 --compress-zstd-level=10' 等
readonly COMP_CMD_OPT=''

#备份文件输出目录，结尾需要/
readonly OUT_DIR=<备份文件输出目录/>

#备份文件输出文件名，默认格式为 'MYSQL_2022-10-01_21-20'
readonly NOW_DATE=$(date '+%Y-%m-%d_%H-%M')
readonly OUT_NAME="MYSQL_""${NOW_DATE}"

#临时文件夹路径，默认 '/tmp/xtrabackup/'
readonly TMP_DIR='/tmp/xtrabackup/'

#临时 STDERR 输出路径，默认 "${TMP_DIR}/xtrabackup_stderr.txt"
readonly TMP_STDERR="${TMP_DIR}/xtrabackup_stderr.txt"

#文件后缀默认 xbstream.aes256
readonly FILE_EXT=xbstream.aes256


#勿动，备份文件完整路径
readonly FULL_PATH="${OUT_DIR}${OUT_NAME}"


#是否启用超容删除，True 为启用，其他值为禁用。循环删除最旧文件直到容量达标或超出文件限制
readonly OVER_DEL=True

#超容检查路径，一般设置为备份文件输出路径，结尾需要/
readonly OVER_CHK_DIR=<备份文件输出目录/>

#目标文件夹超出多少 GiB 时删除文件
readonly OVER_CAP=150

#超容时至少保留多少个文件。即虽然超出了容量限制，但文件数量低于此值就不会删除
readonly FILE_LIM=6



#### Function ####

# error 函数，你可以 error '某某某错误',来向 STDERR 输出信息并退出脚本
function error {
    printf "%s: %s\n" "$(basename "${BASH_SOURCE[0]}")" "${1}" >&2
    exit 1
}



#环境检查函数
function env_check {
#加密密钥存在检查
    if [ ! -r "${ENC_KEY}" ]; then
        error "Cannot read encryption key at ${ENC_KEY}"
    fi
#软件检查
	if ! command -v xtrabackup &> /dev/null; then
		error "xtrabackup not installed"
	fi

	if ! command -v find &> /dev/null; then
		error "find not installed"
	fi

	if ! command -v du &> /dev/null; then
		error "du not installed"
	fi

	if ! command -v awk &> /dev/null; then
		error "awk not installed"
	fi

	if ! command -v sha256sum &> /dev/null; then
		error "sha256sum not installed"
	fi

	if ! command -v openssl &> /dev/null; then
		error "openssl not installed"
	fi

	if ! command -v basename &> /dev/null; then
		error "basename not installed"
	fi
#加密密钥长度检查
    if [[ "$(wc -c "${ENC_KEY}" | awk '{print $1}')" -ne 32 ]]; then
        error 'Encryption key length incorrect'
    fi
#备份输出目录检查
    if [ ! -d "${OUT_DIR}" ];then
        error "${OUT_DIR} folder does not exist"
    fi
#超容检查目录检查
    if [ "${OVER_DEL}" == "True" ]; then
	    if [ ! -d "${OVER_CHK_DIR}" ]; then
	       error "${OVER_CHK_DIR} folder does not exist"
	    fi
    fi
#检查并创建临时目录
	if [ ! -d "${TMP_DIR}" ] ;then
		mkdir "${TMP_DIR}"
	fi
}



#备份函数
function backup {

#开始备份并加密

echo "开始备份"

#注意 xtrabackup 的那个日志备份过程输出是 STDERR
if xtrabackup --defaults-file="${DB_CONF}" "${OPT_CMD}" --backup --stream=xbstream "${COMP_CMD}" ${COMP_CMD_OPT} --encrypt=AES256 --encrypt-key-file="${ENC_KEY}" --target-dir="${TMP_DIR}" 1>"${FULL_PATH}.${FILE_EXT}" 2>"${TMP_STDERR}" ; then
	echo "备份命令执行完毕"
else
	echo "备份命令执行失败，错误信息如下:"
	cat "${TMP_STDERR}"  # 打印 stderr
	cleanup
	error "备份命令执行失败"
fi

if [ -f "${FULL_PATH}.${FILE_EXT}" ]; then
	echo "备份文件成功，备份文件是 ${FULL_PATH}.${FILE_EXT}"
	echo "备份文件大小：$(du -h ${FULL_PATH}.${FILE_EXT} | awk '{print $1}')"
else
	error "备份文件失败"
fi
}


#生成校验值函数
function hash_code_gen {
#生成校验值
if [ -f "${FULL_PATH}.${FILE_EXT}" ];then
	sha256sum "${FULL_PATH}.${FILE_EXT}" > "${FULL_PATH}.${FILE_EXT}".sha256
else 
	error "未找到备份文件，校验值生成失败"
fi

if [ -f "${FULL_PATH}.${FILE_EXT}.sha256" ]; then
	echo "校验值生成完毕，校验文件是 ${FULL_PATH}.${FILE_EXT}.sha256"
else 
	error "校验值生成失败"
fi
}


#超容删除
function capacity_limit {
if [ "${OVER_DEL}" == "True" ]; then

NOW_CAP=$(du -d 0  "${OVER_CHK_DIR}" | awk '{print $1}')
NOW_CAP_GiB=$((NOW_CAP / 1024 / 1024))
NOW_FILE=$(find "${OVER_CHK_DIR}" -type f | wc -l)
OLDEST_FILE=$(find "${OVER_CHK_DIR}" -maxdepth 1 -type f -printf '%T+ %p\n' | sort | head -n 1|awk '{print $2}')

	echo "超容删除已启用，当前备份文件夹大小""${NOW_CAP_GiB}""GiB""，设定超容值""${OVER_CAP}""GiB，如果超过容量则会进行删除"
	until [ ${NOW_CAP_GiB} -le ${OVER_CAP} ] || [ "${NOW_FILE}" -le "${FILE_LIM}" ]; do
	
		echo "当前备份文件夹大小""${NOW_CAP_GiB}""GiB，大于设定超容值""${OVER_CAP}""GiB，进行删除"

		if [ "${NOW_FILE}" -gt "${FILE_LIM}" ]; then
			echo "当前备份文件夹有""${NOW_FILE}""个文件，大于最低设定超容值""${FILE_LIM}""，开始删除"
				if rm "${OLDEST_FILE}"; then
					echo "已删除""${OLDEST_FILE}"
				else
					error "删除""${OLDEST_FILE}""失败"
				fi
		else 
			error "当前备份文件夹有""${NOW_FILE}""个文件，小于等于最低设定值""${FILE_LIM}""......""当前备份文件夹大小""${NOW_CAP_GiB}""GiB，设定超容值""${OVER_CAP}""GiB""......""推荐进行检查是否单个备份文件过大"
		fi
		
		OLDEST_FILE=$(find "${OVER_CHK_DIR}" -maxdepth 1 -type f -printf '%T+ %p\n' | sort | head -n 1|awk '{print $2}')
		NOW_FILE=$(find "${OVER_CHK_DIR}" -type f | wc -l)
		NOW_CAP=$(du -d 0  "${OVER_CHK_DIR}" | awk '{print $1}')
		NOW_CAP_GiB=$((NOW_CAP / 1024 / 1024))
		echo "当前备份文件夹大小""${NOW_CAP_GiB}""GiB"
		echo
	done
fi
}

function cleanup {
	#删除临时 STRERR 输出
	rm "${TMP_STDERR}"
}

#### Execution ####
trap 'error "意外错误，备份失败"' ERR

env_check
backup
hash_code_gen
capacity_limit
cleanup


echo "备份脚本执行完毕"
echo
