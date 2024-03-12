#!/bin/bash
#文件拷贝脚本 - 可用于复制一对文件（一个备份文件，一个校验值文件）至额外文件夹（比如映射到本地的远程文件夹）带容量控制
#File Copy Script - Can be used to copy a pair of files (a backup file, a check value file) to an additional folder (such as a remote folder mapped to the local) with capacity control
#Author: 10935336
#Creation date: 2022-10-27
#Modified date: 2024-03-12

#### Note ####
#按后缀名将文件夹中'最新'的 2 个文件复制到另一个目录（一个备份文件，一个校验值文件）
#如提取某文件夹中后缀为 xbstream.aes256.sha256 和 xbstream.aes256 的最新两个文件并复制到另一个文件夹


#### Variable #####
#你需要填写本节变量。
#You need to fill in the variables in this section.

#要从这里复制文件的目录，结尾需要/
readonly SOURCE_DIR=<要从这里复制文件的目录/>

#要复制到的文件夹，结尾需要/
readonly EXTRA_DIR=<远程映射到本地的目录/>

#文件后缀名 A（默认为校验文件）例如 'xbstream.aes256.sha256'  'tar.zst.aes256.sha256'
readonly FILE_SUFFIX_A=tar.zst.aes256.sha256

#文件后缀名 B（默认为备份文件）例如 'xbstream.aes256'  'tar.zst.aes256'
readonly FILE_SUFFIX_B=tar.zst.aes256


#是否启用超容删除，True 为启用，其他值为禁用。循环删除最旧文件直到容量达标或超出文件限制
readonly OVER_DEL=True

#超容检查路径，一般设置为要复制到的文件夹，结尾需要/
readonly OVER_CHK_DIR=<超容检查路径/>

#目标文件夹超出多少 GiB 时删除文件
readonly OVER_CAP=100

#超容时至少保留多少个文件。即虽然超出了容量限制，但文件数量低于此值就不会删除
readonly FILE_LIM=6


#### Function ####

# error 函数，你可以 error "某某某错误",来向 STDERR 输出信息并退出脚本
function error {
    printf "%s: %s\n" "$(basename "${BASH_SOURCE[0]}")" "${1}" >&2
    exit 1
}


#环境检查函数
function env_check {
#备份文件输出目录检查
    if [ ! -d "${SOURCE_DIR}" ];then
        error "${SOURCE_DIR} folder does not exist"
    fi
#远程映射目录检查
    if [ ! -d "${EXTRA_DIR}" ];then
        error "${EXTRA_DIR} folder does not exist"
    fi
#超容检查目录检查
    if [ "${OVER_DEL}" == "True" ]; then
	    if [ ! -d "${OVER_CHK_DIR}" ]; then
	       error "${OVER_CHK_DIR} folder does not exist"
	    fi
    fi
#软件检查
	if ! command -v awk &> /dev/null; then
		error "awk not installed"
	fi

	if ! command -v find &> /dev/null; then
		error "find not installed"
	fi

	if ! command -v du &> /dev/null; then
		error "du not installed"
	fi

	if ! command -v basename &> /dev/null; then
		error "basename not installed"
	fi
}



#复制到额外文件夹
function cp_to_extra { 
#获取完整文件名 A
SHA_PATH=$(ls -t "${SOURCE_DIR}"*."${FILE_SUFFIX_A}" | head -n 1)
if [ -z "${SHA_PATH}" ] || [ ! -f "${SHA_PATH}" ]; then
	error "A 文件（默认为校验文件）后缀 ${FILE_SUFFIX_A} 提取不正确，请检查脚本，提取结果为 ${SHA_PATH}"
else
	echo "A 文件（默认为校验文件）提取成功，提取结果为 ${SHA_PATH}"
	SHA=$(basename "${SHA_PATH}")
fi

#获取完整文件名 B
FILE_PATH=$(ls -t "${SOURCE_DIR}"*."${FILE_SUFFIX_B}" | head -n 1)
if [ -z "${FILE_PATH}" ] || [ ! -f "${FILE_PATH}" ]; then
	error "B 文件（默认为备份文件）后缀 ${FILE_SUFFIX_B} 提取不正确，请检查脚本，提取结果为 ${FILE_PATH}"
else
	echo "B 文件（默认为备份文件）提取成功，提取结果为 ${FILE_PATH}"
	FILE=$(basename "${FILE_PATH}")
fi



echo "开始复制 A 文件（默认为校验文件）"

if cp "${SOURCE_DIR}${SHA}" "${EXTRA_DIR}";then
	echo "A 文件（默认为校验文件）复制成功，来源 ${SOURCE_DIR}${SHA}，目标 ${EXTRA_DIR}${SHA}"
	echo "A 文件大小为 $(du -h ${SOURCE_DIR}${SHA} | awk '{print $1}')"
else
	error "A 文件（默认为校验文件）复制失败，来源 ${SOURCE_DIR}${SHA}，目标 ${EXTRA_DIR}${SHA}"
fi

echo "开始复制 B 文件（默认为备份文件）"

if cp "${SOURCE_DIR}${FILE}" "${EXTRA_DIR}";then
	echo "B 文件（默认为备份文件）复制成功，来源 ${SOURCE_DIR}${FILE} 目标 ${EXTRA_DIR}${FILE}"
	echo "B 文件大小为 $(du -h ${SOURCE_DIR}${FILE} | awk '{print $1}')"
else
	error "B 文件（默认为备份文件）复制失败，来源 ${SOURCE_DIR}${FILE} 目标 ${EXTRA_DIR}${FILE}"
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


#### Execution ####
trap 'error "意外错误，复制失败"' ERR

cp_to_extra
capacity_limit

echo "复制脚本执行完毕"
echo
