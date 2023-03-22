# English

A repository for my own Bash Shell scripts.

## auto_dir_backup.sh

Automatic folder backup script, can be used to backup any directory, I personally use it to backup website directories etc.

This script can be used to backup any folder as a compressed file and generate checksum. With capacity control, you can cycle through the oldest files until the capacity is reached or the minimum file limit is exceeded.

Unfortunately, the comments in this script are in Chinese.

## auto_mysql_backup.sh

Automatic MySQL database backup script using Percona XtraBackup 8.0.

This script compresses and encrypts MySQL database backups to a single file and generates checksums. With capacity control, you can delete the oldest files cyclically until the capacity is reached or the minimum file limit is exceeded.

Unfortunately, the comments in this script are in Chinese.



## backup_extra_copy

Companion tools to auto_dir_backup.sh and auto_mysql_backup.sh.

You can copy a pair of files and checksums to another directory, which is usually mapped to a local remote directory. This can be done with tools such as rclone. With capacity control, you can delete the oldest files cyclically until the capacity is reached or the minimum file limit is exceeded.

Unfortunately, the comments in this script are in Chinese.


## update_github_hosts_from_next-hosts.sh

Get the latest Github Host from https://github.com/ineo6/hosts and update it, which will help improve the Github network blockade in mainland China.

Only update existing /etc/hosts starting with # GitHub Host Start and ending with # GitHub Host End.

Unfortunately, the comments in this script are in Chinese.

<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>

# 中文

我的 Bash Shell 脚本仓库。

## auto_dir_backup.sh

自动文件夹备份脚本，可用于备份任意目录，我个人用于备份网站目录等。

此脚本可用于备份任意文件夹为压缩文件并生成校验码。带容量控制，可以循环删除最旧文件直到容量达标或超出最少文件限制。


## auto_mysql_backup.sh

自动 MySQL 数据库备份脚本，使用 Percona XtraBackup 8.0。

此脚本会压缩并加密 MySQL 数据库备份为单文件并生成校验码。带容量控制，可以循环删除最旧文件直到容量达标或超出最少文件限制。


## backup_extra_copy

auto_dir_backup.sh 和 auto_mysql_backup.sh 的配套工具。

可以复制一对文件和校验码到另外一个目录，该目录通常是映射到本地的远程目录。可以通过 rclone 等工具完成。带容量控制，可以循环删除最旧文件直到容量达标或超出最少文件限制。


## update_github_hosts_from_next-hosts.sh

从 https://github.com/ineo6/hosts 获取最新的 Github Host 并更新，有助于改善中国大陆的 Github 网络封锁。

仅更新现有 /etc/hosts 中的 以 # GitHub Host Start 开头，以 # GitHub Host End 结尾的内容。
