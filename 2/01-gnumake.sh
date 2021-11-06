#!/1/out/protobusybox/bin/ash

#> FETCH e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19
#>  FROM http://ftp.gnu.org/gnu/make/make-4.3.tar.gz

set -uex

export PATH='/2/00-intermediate-gnumake/out/bin'
export PATH="$PATH:/1/out/tinycc/wrappers:/1/out/protobusybox/bin"

echo "### $0: unpacking intermediate GNU Make sources..."
mkdir -p /2/01-gnumake/tmp; cd /2/01-gnumake/tmp
gzip -d < /downloads/make-4.3.tar.gz | tar -x --strip-components=1

echo "### $0: building gnumake with intermediate GNU make"
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' src/job.c build-aux/install-sh
sed -i 's|/dev/null|/2/01-gnumake/tmp/null|' configure
ash ./configure \
	--build x86_64-linux \
	--disable-posix-spawn \
	--disable-dependency-tracking \
	CONFIG_SHELL='/1/out/protobusybox/bin/ash' \
	SHELL='/1/out/protobusybox/bin/ash'
gnumake

echo "### $0: installing gnumake"
mkdir -p /2/01-gnumake/out/bin
cp make /2/01-gnumake/out/bin/gnumake

#rm -rf /2/01-gnumake/tmp
