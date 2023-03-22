#!/bin/bash
#任意文件夹压缩加密备份脚本 - 此脚本可用于备份任意文件夹为压缩文件并生成校验码
#Arbitrary folder compression encryption backup script - this script can be used to back up any folder as a compressed file and generate a verification code
#Author: 10935336
#Creation date: 2022-10-30
#Modified date: 2023-03-22

#### Require ####
#需要 tar 版本大于等于 1.29。
#你可以使用 'tar --version' 查看。

#### Note ####
#默认采用 tar.gz 压缩，使用 openssl aes-256-cbc 加密。

#### Document ####
#解密方法: 'openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass file:<加密秘钥> -in <加密文件名> -out <解密文件名>'

#### Prepare ####
#1.备份加密秘钥 enc_key
#备份加密密码请单行写入 enc_key 文件，可以使用 'openssl rand -base64 24' 生成密码（256位)，结尾不能有CRLF，并使用 chmod 600 保护。
#或者直接使用秘钥生成命令：'printf '%s' "$(openssl rand -base64 24)" | sudo tee <秘钥目录> && echo'


#### Variable #####
#你需要填写本节变量。
#You need to fill in the variables in this section.

#备份加密秘钥
readonly ENC_KEY=<enc_key路径>

#要备份的目录，结尾需要/，tar 会自行处理绝对路径
readonly SOURCE_DIR=<要备份的目录/>

#备份文件输出目录，结尾需要/
readonly OUT_DIR=<备份文件输出目录/>

#压缩等级,1-9 越高文件越小越慢
COMP_LV=9

#备份文件输出文件名，默认格式为 'DIR_2022-10-01_21-20'
NOW_DATA=$(date '+%Y-%m-%d_%H-%M')
OUT_NAME="DIR_""$NOW_DATA"

#勿动，备份文件完整路径
FULL_PACH=$OUT_DIR"$OUT_NAME"

#是否启用超容删除，True 为启用，其他值为禁用。循环删除最旧文件直到容量达标或超出文件限制
OVER_DEL=True

#超容检查路径，一般设置为备份文件输出路径，结尾需要/
OVER_DIR=<备份文件输出目录/>

#目标文件夹超出多少 GiB 时删除文件
OVER_CAP=100

#超容时至少保留多少个文件。比如虽然超出了容量限制，但文件数低于此值就不会删除
FILE_LIM=6


#### Function ####

# error 函数，你可以 erreo "某某某错误",来向 STDERR 输出信息并退出脚本
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
#备份软件检查
    TAR_VER=$(tar --version|awk 'NR==1{print $4}')
    if [ $(echo "$TAR_VER >= 1.29" |bc) -eq 0 ]; then 
       error 'Your tar version is lower than 1.29 or not installed' 	
    fi
#加密密钥长度检查
    if [[ "$(wc -c $ENC_KEY|awk '{print $1}')" -ne 32 ]]; then
       error 'Encryption key length error'
    fi
#备份输出目录检查
    if [ ! -d "$OUT_DIR" ];then
       error "$OUT_DIR folder does not exist"
    fi
#超容检查目录检查
    if [ ! -d "$OVER_DIR" ];then
       error "$OVER_DIR folder does not exist"
    fi
}



#文件夹备份并加密，很遗憾为了不造成额外读写，加密将在一条命令中
function dir_backup {

echo "开始备份"
#不加密 'tar --use-compress-program="gzip -$COMP_LV" -cvf "$FULL_PACH".tar.gz $SOURCE_DIR'

if tar cvf - "$SOURCE_DIR" 2>/dev/null| gzip -"$COMP_LV" |openssl enc -aes-256-cbc -e -salt -pbkdf2 -pass file:$ENC_KEY -out "$FULL_PACH".tar.gz.aes256
then
echo "备份命令执行完毕"
	else
	error "备份命令执行失败"
fi

if [ -f "$FULL_PACH.tar.gz.aes256" ]; then
	echo "备份文件成功，备份文件是 $FULL_PACH.tar.gz.aes256"
	else
	error "备份文件失败"
fi
}


#生成校验值函数
function hash_code_gen {
#生成校验值
if [ -f "$FULL_PACH.tar.gz.aes256" ];then
sha256sum "$FULL_PACH".tar.gz.aes256 >"$FULL_PACH".tar.gz.aes256.sha256
	else 
	error "未找到备份文件，校验值生成失败"
fi

if [ -f "$FULL_PACH.tar.gz.aes256.sha256" ]; then
echo "校验值生成完毕，校验文件是 $FULL_PACH.tar.gz.aes256.sha256"
	else 
	error "校验值生成失败"
fi
}



#超容删除
function capacity_limit {

NOW_CAP=$(du -d 0  $OVER_DIR | awk '{print $1}')
NOW_CAP_GiB=$((NOW_CAP / 1024 / 1024))
NOW_FILE=$(find $OVER_DIR -type f | wc -l)
OLDEST_FILE=$(find $OVER_DIR -maxdepth 1 -type f -printf '%T+ %p\n' | sort | head -n 1|awk '{print $2}')


if [ "$OVER_DEL" == "True" ]; then
	echo "超容删除已启用，当前备份文件夹大小""$NOW_CAP_GiB""GiB""，设定超容值""$OVER_CAP""GiB，如果超过容量则会进行删除"
	until [ $NOW_CAP_GiB -le $OVER_CAP ] || [ $NOW_FILE -le $FILE_LIM ]; do
	
		echo "当前备份文件夹大小""$NOW_CAP_GiB""GiB，大于设定超容值""$OVER_CAP""GiB，进行删除"

		if [ $NOW_FILE -gt $FILE_LIM ]; then
			echo "当前备份文件夹有""$NOW_FILE""个文件，大于最低设定超容值""$FILE_LIM""，开始删除"
				if rm $OLDEST_FILE; then
				echo "已删除""$OLDEST_FILE"
					else
				error "删除""$OLDEST_FILE""失败"
				fi
			else 
			error "当前备份文件夹有""$NOW_FILE""个文件，小于等于最低设定值""$FILE_LIM""......""当前备份文件夹大小""$NOW_CAP_GiB""GiB，设定超容值""$OVER_CAP""GiB""......""推荐进行检查是否单个备份文件过大"
		fi
		
		OLDEST_FILE=$(find $OVER_DIR -maxdepth 1 -type f -printf '%T+ %p\n' | sort | head -n 1|awk '{print $2}')
		NOW_FILE=$(find $OVER_DIR -type f | wc -l)
		NOW_CAP=$(du -d 0  $OVER_DIR | awk '{print $1}')
		NOW_CAP_GiB=$((NOW_CAP / 1024 / 1024))
		echo "当前备份文件夹大小""$NOW_CAP_GiB""GiB"
		echo
	done
fi
}




#### Execution ####
env_check
dir_backup
hash_code_gen
capacity_limit


trap 'error "备份失败，错误如下"' ERR

