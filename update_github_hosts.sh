#!/bin/bash
# Function: 更新 Github Host - 可以选择多个源，有助于改善中国大陆的 Github 网络封锁。
# Function: Update Github Host - Multiple sources can be selected, which will help improve the Github network blockade in mainland China.
# Author: 10935336
# Creation date：2022-05-07
# Modified date：2023-05-07


#### Usage ####
# -c 可以删除当前 /etc/hosts 中的 github-hosts
# -u <数字> 可以选择更新源


#### Variable ####
# 默认更新源
UPDATE_SOURCE=1

# 更新源 1  https://github.com/521xueweihan/GitHub520
SOURCE1_URL=https://raw.hellogithub.com/hosts

# 更新源 2  https://github.com/ineo6/hosts
SOURCE2_URL=https://gitlab.com/ineo6/hosts/-/raw/master/next-hosts

# 取消标志
CANCEL_FLAG=0


# 解析命令行参数

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--cancel) CANCEL_FLAG=1;;
        -u|--update-source) UPDATE_SOURCE="$2"; shift;;
        *) echo "Unknown parameter passed: $1"; exit 1;;
    esac
    shift
done


# 取消操作
if [ $CANCEL_FLAG -eq 1 ]; then
    echo "取消更新并删除现有 GitHub Hosts"
    sed -i '/# GitHub Host Start/,/# GitHub Host End/d' /etc/hosts
    sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' /etc/hosts
    exit 0
fi


# 根据选择的更新源设置URL
case $UPDATE_SOURCE in
    1) HOSTS_URL=$SOURCE1_URL;;
    2) HOSTS_URL=$SOURCE2_URL;;
    *) echo "无效的更新源: $UPDATE_SOURCE"; exit 1;;
esac


#### Execution ####
# 获取 hosts 内容
wget -q -O github-hosts $HOSTS_URL

# 检查是否获取成功
if [ $? -ne 0 ]; then
    echo "获取 github-hosts 失败"
    exit 1
else
    echo "获取 github-hosts 成功，开始更新"
fi

# 检查hosts文件是否存在
if [ ! -f /etc/hosts ]; then
    echo "未找到 hosts 文件"
    exit 1
fi

# 获取现有hosts内容暂存
cat /etc/hosts > hosts-temp

# 删除 https://github.com/ineo6/hosts 中 # GitHub Host Start 前的不合规内容
# 记录文件内容
content=$(cat github-hosts) 
# 执行sed命令 
sed -i '1,/# GitHub Host Start/{/# GitHub Host Start/!d;}' github-hosts
# 如果为空,还原内容 
[ -s github-hosts ] || echo "$content" > github-hosts


# 删除现有hosts中已有的 GitHub Hosts
sed -i '/# GitHub Host Start/,/# GitHub Host End/d' hosts-temp
sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' hosts-temp

# 将新的hosts内容添加到现有hosts暂存中
cat github-hosts >> hosts-temp

# 将更新后的hosts内容写入/etc/hosts
cat hosts-temp > /etc/hosts

# 删除临时文件
rm -f github-hosts hosts-temp

echo "更新完成"
