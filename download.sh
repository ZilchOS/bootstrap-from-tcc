#!/bin/sh
set -ue

mkdir -p downloads
cd downloads

github() { echo https://github.com/$1/archive/$2.tar.gz; }

fetch() {
	hash=$1; url=$2; filename=${3:-$(basename $url)}
	if [[ ! -e $filename ]]; then
		wget -nv --show-progress $url -O $filename
		echo "$hash $filename" | sha256sum -c --quiet
	else
		echo "$hash $filename" | sha256sum -c
	fi
}

fetch 9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd \
	http://musl.libc.org/releases/musl-1.2.2.tar.gz
fetch c6b244e58677c4c486dbf80e35ee01b192e133876942afa07454159ba118b44e \
	$(github TinyCC/tinycc da11cf651576f94486dbd043dbfcde469e497574) \
	tinycc-mob-gitda11cf6.tar.gz
fetch 415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549 \
	https://busybox.net/downloads/busybox-1.34.1.tar.bz2
fetch e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19 \
	http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
fetch 820d9724f020a3e69cb337893a0b63c2db161dadcb0e06fc11dc29eb1e84a32c \
	https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.xz
fetch 936162c0312886c21581002b79932829aa048cfaf9937c6265aeaa14f1cd1775 \
	http://gcc.gnu.org/pub/gcc/infrastructure/gmp-4.3.2.tar.bz2
fetch d7271bbfbc9ddf387d3919df8318cd7192c67b232919bfa1cb3202d07843da1b \
	https://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.xz
fetch e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4 \
	http://www.multiprecision.org/downloads/mpc-0.8.1.tar.gz
fetch 92e61c6dc3a0a449e62d72a38185fda550168a86702dea07125ebd3ec3996282 \
	https://ftp.gnu.org/gnu/gcc/gcc-4.7.4/gcc-4.7.4.tar.bz2
#fetch 5755a6487018399812238205aba73a2693b0f9f3cd73d7cf1ce4d5436c3de1b0 \
#	https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.74.tar.xz
