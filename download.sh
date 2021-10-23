#!/bin/sh
set -uex

mkdir -p downloads
cd downloads
[[ -e alloca.S ]] ||
	wget https://repo.or.cz/tinycc.git/blob_plain/ca11849ebb88ef4ff87beda46bf5687e22949bd6:/lib/alloca.S
[[ -e libtcc1.c ]] ||
	wget https://repo.or.cz/tinycc.git/blob_plain/ca11849ebb88ef4ff87beda46bf5687e22949bd6:/lib/libtcc1.c
[[ -e va_list.c ]] ||
	wget https://repo.or.cz/tinycc.git/blob_plain/ca11849ebb88ef4ff87beda46bf5687e22949bd6:/lib/va_list.c
[[ -e musl-1.2.2.tar.gz ]] ||
	wget http://musl.libc.org/releases/musl-1.2.2.tar.gz
[[ -e sash-3.8.tar.gz ]] ||
	wget http://members.tip.net.au/%7Edbell/programs/sash-3.8.tar.gz
[[ -e make-4.3.tar.gz ]] ||
	wget http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
[[ -e busybox-1.34.1.tar.bz2 ]] ||
	wget https://busybox.net/downloads/busybox-1.34.1.tar.bz2
[[ -e linux-5.10.74.tar.xz ]] ||
	wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.74.tar.xz

sha256sum -c <<EOF
35e5f8b2be44cefa3acc75365acac703f1cd908ada861ae8a3605da185074a2e  alloca.S
8f8370b9e888009046dac83452c1fbcd12fd9bc0b88b8ce873810d2dde9db689  libtcc1.c
d647913c5c4a4146b3a760b30e293baa428a580cb387e2014bcf749666e1f644  va_list.c
9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd  musl-1.2.2.tar.gz
13c4f9a911526949096bf543c21a41149e6b037061193b15ba6b707eea7b6579  sash-3.8.tar.gz
e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19  make-4.3.tar.gz
415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549  busybox-1.34.1.tar.bz2
5755a6487018399812238205aba73a2693b0f9f3cd73d7cf1ce4d5436c3de1b0  linux-5.10.74.tar.xz
EOF
