#!/bin/bash
#更新 Github Host - 从 https://github.com/ineo6/hosts 获取最新的 Github Host 并更新，有助于改善中国大陆的 Github 网络封锁。
#Update Github Host - Get the latest Github Host from https://github.com/ineo6/hosts and update it, which will help improve the Github network blockade in mainland China.
#Author: 10935336
#Creation date：2023-02-03
#Modified date：2023-03-22


#### Variable #####
#Hosts 获取地址，默认为从 gitlab 获取 'https://gitlab.com/ineo6/hosts/-/raw/master/next-hosts'
NEXT_HOSTS_URL=https://gitlab.com/ineo6/hosts/-/raw/master/next-hosts


#### Execution ####
# 获取next-hosts内容
wget -q -O next-hosts $NEXT_HOSTS_URL

# 检查是否获取成功
if [ $? -ne 0 ]; then
    echo "获取 next-hosts 失败"
    exit 1
else
    echo "获取 next-hosts 成功，开始更新"
fi

# 检查hosts文件是否存在
if [ ! -f /etc/hosts ]; then
    echo "未找到 hosts 文件"
    exit 1
fi

# 获取现有 hosts 内容暂存
cat /etc/hosts > hosts-temp

# 删除现有 hosts 中以# GitHub Host Start开头，以# GitHub Host End结尾的内容
sed -i '/# GitHub Host Start/,/# GitHub Host End/d' hosts-temp

# 删除 next-hosts 中 # GitHub Host Start 前的内容
sed -i '1,/# GitHub Host Start/{/# GitHub Host Start/!d;}' next-hosts

# 将新的 hosts 内容添加到现有 hosts 暂存中
cat next-hosts >> hosts-temp

# 删除现有 hosts 暂存中可能多余的内容
sed -i '/# New！欢迎使用基于DNS的新方案/,/# 也可以关注公众号：湖中剑，保证不迷路/d' hosts-temp

# 将更新后的 hosts 内容写入 /etc/hosts
cat hosts-temp > /etc/hosts

# 删除临时文件
rm -f next-hosts hosts-temp

echo "更新完成"
