#!/bin/bash
#文件拷贝脚本 - 可用于复制一对文件至已映射到本地的远程目录（一个备份文件，一个校验值文件）带容量控制
#File Copy Script - can be used to copy a pair file to a remote directory mapped to the local (a backup file and a checksum file) with capacity control
#Author: 10935336
#Creation date: 2022-10-27
#Modified date: 2023-03-22

#### Note ####
#按后缀名将文件夹中'最新'的 2 个文件复制到另一个目录（一个备份文件，一个校验值文件）
#如提取后缀为 xbstream.ase256.sha256 和 xbstream.ase256 的最新两个文件并复制到另一个文件夹


#### Variable #####
#你需要填写本节变量。
#You need to fill in the variables in this section.

#要从这里复制文件的目录，结尾需要/
SOURCE_DIR=<要从这里复制文件的目录/>

#远程映射到本地的目录，结尾需要/
REMOTE_DIR=<远程映射到本地的目录/>

#文件后缀名 A，默认为'xbstream.ase256.sha256'
FILE_SUFFIX_A=xbstream.ase256.sha256

#文件后缀名 B，默认为'xbstream.ase256'
FILE_SUFFIX_B=xbstream.ase256


#是否启用超容删除，True 为启用，其他值为禁用。循环删除最旧文件直到容量达标或超出文件限制
OVER_DEL=True

#超容检查路径，一般设置为备份文件输出路径，结尾需要/
OVER_DIR=<超容检查路径/>

#目标文件夹超出多少 GiB 时删除文件
OVER_CAP=150

#超容时至少保留多少个文件。比如虽然超出了容量限制，但文件数低于此值就不会删除
FILE_LIM=6


#### Function ####

# error 函数，你可以 error "某某某错误",来向 STDERR 输出信息并退出脚本
function error {
    printf "%s: %s\n" "$(basename "${BASH_SOURCE[0]}")" "${1}" >&2
    exit 1
}


#环境检查函数
function env_check {
#备份文件输出目录检查
    if [ ! -d "$SOURCE_DIR" ];then
        error "$SOURCE_DIR folder does not exist"
    fi
#远程映射目录检查
    if [ ! -d "$REMOTE_DIR" ];then
        error "$REMOTE_DIR folder does not exist"
    fi
#超容检查目录检查
    if [ ! -d "$OVER_DIR" ];then
        error "$OVER_DIR folder does not exist"
    fi
}



#复制到
function cp_to_remote { 
#获取完整文件名A
SHA=$(ls -t $SOURCE_DIR|grep "$FILE_SUFFIX_A$"|head -n2|awk 'NR==1{print $0}')
if ! [[ $SHA =~ "$FILE_SUFFIX_A" ]];then
	error "校验文件提取不正确，请检查脚本，提取结果为""$SHA"
fi
#获取完整文件名B
FILE=$(ls -t $SOURCE_DIR|grep "$FILE_SUFFIX_B$"|head -n2|awk 'NR==2{print $0}')
if ! [[ $FILE =~ "$FILE_SUFFIX_B" ]];then
	error "备份文件提取不正确，请检查脚本，提取结果为""$FILE"
fi

if cp $SOURCE_DIR"$SHA" $REMOTE_DIR;then
	echo "校验值复制成功，""$REMOTE_DIR""$SHA"
	else
	error "校验值复制失败"
fi


if cp $SOURCE_DIR"$FILE" $REMOTE_DIR;then
	echo "备份复制成功，""$REMOTE_DIR""$FILE"
	else
	error "备份复制失败"
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
cp_to_remote
capacity_limit


trap 'error "备份失败，错误如下"' ERR
