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

You can copy 1 pair of files and checksums to another directory, which is usually mapped to a local remote directory. This can be done with tools such as rclone. With capacity control, you can delete the oldest files cyclically until the capacity is reached or the minimum file limit is exceeded.

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

可以复制 1 对文件和校验码到另外一个目录，该目录通常是映射到本地的远程目录。可以通过 rclone 等工具完成。带容量控制，可以循环删除最旧文件直到容量达标或超出最少文件限制。
