#!/1/out/protobusybox/bin/ash

#> FETCH e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19
#>  FROM http://ftp.gnu.org/gnu/make/make-4.3.tar.gz

set -uex

export PATH=/1/out/tinycc/wrappers:/1/out/protobusybox/bin

echo "### $0: unpacking intermediate GNU Make sources..."
mkdir -p /2/00-intermediate-gnumake/out /2/00-intermediate-gnumake/tmp
gzip -d < /downloads/make-4.3.tar.gz | \
	tar --strip-components=1 -x -C /2/00-intermediate-gnumake/tmp

echo "### $0: building intermediate GNU Make..."
cd /2/00-intermediate-gnumake/tmp
# FIXME this is part of stdlib, no idea how it's supposed to not clash
rm src/getopt.h
for f in src/getopt.c src/getopt1.c; do :> $f; done
for f in lib/fnmatch.c lib/glob.c lib/xmalloc.c lib/error.c; do :> $f; done
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' src/job.c
ash ./configure \
	--build x86_64-linux \
	--disable-posix-spawn \
	--disable-dependency-tracking \
	CONFIG_SHELL='/1/out/protobusybox/bin/ash' \
	SHELL='/1/out/protobusybox/bin/ash'
ash ./build.sh
./make --version

echo "### $0: installing intermediate GNU Make..."
mkdir -p /2/00-intermediate-gnumake/out/bin
cp make /2/00-intermediate-gnumake/out/bin/gnumake

#rm -r /2/00-intermediate-gnumake/tmp
