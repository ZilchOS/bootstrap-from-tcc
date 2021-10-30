#!/bin/sh
set -uex

mkdir -p downloads
cd downloads
[[ -e musl-1.2.2.tar.gz ]] ||
	wget http://musl.libc.org/releases/musl-1.2.2.tar.gz
[[ -e tinycc-mob-gitda11cf6.tar.gz ]] ||
	wget https://github.com/TinyCC/tinycc/archive/da11cf651576f94486dbd043dbfcde469e497574.tar.gz -O tinycc-mob-gitda11cf6.tar.gz
[[ -e busybox-1.34.1.tar.bz2 ]] ||
	wget https://busybox.net/downloads/busybox-1.34.1.tar.bz2
[[ -e make-4.3.tar.gz ]] ||
	wget http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
[[ -e linux-5.10.74.tar.xz ]] ||
	wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.74.tar.xz

sha256sum -c <<EOF
9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd  musl-1.2.2.tar.gz
c6b244e58677c4c486dbf80e35ee01b192e133876942afa07454159ba118b44e  tinycc-mob-gitda11cf6.tar.gz
415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549  busybox-1.34.1.tar.bz2
e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19  make-4.3.tar.gz
5755a6487018399812238205aba73a2693b0f9f3cd73d7cf1ce4d5436c3de1b0  linux-5.10.74.tar.xz
EOF
