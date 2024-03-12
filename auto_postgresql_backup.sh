#!/bin/bash
# PostgreSQL 数据库备份脚本 - 此脚本会压缩并加密 PostgreSQL 数据库备份为单文件并生成校验码。
# PostgreSQL database backup script - This script will compress and encrypt the PostgreSQL database backup as a single file and generate a checksum.
#Author: 10935336
#Creation date: 2024-02-29
#Modified date: 2024-03-12

#### Require ####
#运行本脚本需要 pg_dumpall，测试版本：pg_dumpall (PostgreSQL) 15.6

#### Note ####


#### Document ####
#备份恢复步骤：1.解密备份文件 2.解压备份文件 3.恢复备份
#解密方法：openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass file:<enc_key> -in <backup.sql.zst.ase256> -out <backup.sql.zst>
#解压方法：zstd -d <backup.sql.zst> -o <backup.sql>
#恢复备份：使用 pg_restore 恢复，详见 https://www.postgresql.org/docs/current/app-pgrestore.html

#### Prepare ####
#1.准备备份加密秘钥 enc_key
#备份加密密码请单行写入 enc_key 文件，可以使用 'openssl rand -base64 24' 生成密码（256位)，结尾不能有CRLF，并使用 chmod 600 保护。
#或者直接使用秘钥生成命令：'printf '%s' "$(openssl rand -base64 24)" | sudo tee <秘钥目录> && echo'

#2.准备数据库配置文件 .pgpass 
#新建 .pgpass 并使用 chmod 600 保护。
#注意.pgpass 内只需要填写用户名和密码，其他值可以使用 *，
#因为 pg_dumapall 并不会从中读取用户名、主机名等，而是检查这些值是否和命令行参数匹配，如果匹配则读取密码。
#内容格式如下，* 代表通配：

##hostname:port:database:username:password
#*:*:*:postgres:verysecuritypassword

#详见 https://www.postgresql.org/docs/current/libpq-pgpass.html


#### Variable #####
#你需要填写本节变量。
#You need to fill in the variables in this section.

#备份加密秘钥
readonly ENC_KEY=<加密秘钥路径>

#数据库配置文件,即 .pgpass 文件路径
readonly DB_CONF=<.pgpass文件路径>

#用于备份的数据库用户，须与.pgpass 内一致（不可通配），默认 postgres
readonly DB_USER=postgres

#要备份的数据库的主机名，须与.pgpass 内一致（可通配）
#如果以 / 开头则为 Unix 域套接字的目录，默认 localhost
readonly DB_HOST=localhost

#要备份的数据库的端口，默认 5432
readonly DB_PORT=5432

#压缩类型，默认为 'zstd'
readonly COMP_TYPE='zstd'

#压缩等级，gzip 1-9，zstd 1-19，数值越高文件越小越慢
readonly COMP_LV=9

#备份文件输出目录，结尾需要/
readonly OUT_DIR=<备份文件输出目录/>

#备份文件输出文件名，默认格式为 'PostgreSQL_2022-10-01_21-20'
readonly NOW_DATE=$(date '+%Y-%m-%d_%H-%M')
readonly OUT_NAME="PostgreSQL_""${NOW_DATE}"

#临时 STDERR 输出路径，默认 "/tmp/PostgreSQL_dumpall_stderr.txt"
readonly TMP_STDERR="/tmp/PostgreSQL_dumpall_stderr.txt"

#文件后缀默认 sql.zst.aes256
readonly FILE_EXT=sql.zst.aes256


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
	if ! command -v pg_dumpall &> /dev/null; then
		error "pg_dumpall not installed"
	fi

	if ! command -v ${COMP_TYPE} &> /dev/null; then
		error "${COMP_TYPE} not installed"
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
}



#备份函数
function backup {

#开始备份并加密

echo "开始备份"

#pg_dumpall 用的环境变量
export PGPASSFILE="${DB_CONF}"

if pg_dumpall --host=${DB_HOST} --port=${DB_PORT} --username=${DB_USER} | ${COMP_TYPE} -${COMP_LV} | openssl enc -aes-256-cbc -e -salt -pbkdf2 -pass file:${ENC_KEY} -out "${FULL_PATH}.${FILE_EXT}" 2>"${TMP_STDERR}" ; then
	echo "备份命令执行完毕"
else
	echo "备份命令执行失败，错误信息如下:"
	cat "${TMP_STDERR}"
	cleanup
	error "备份命令执行失败"
fi

if [ -f "${FULL_PATH}.${FILE_EXT}" ]; then
	echo "备份文件成功，备份文件是 ${FULL_PATH}.${FILE_EXT}"
	echo "备份文件大小为 $(du -h ${FULL_PATH}.${FILE_EXT} | awk '{print $1}')"
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
