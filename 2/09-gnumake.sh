#!/1/out/protobusybox/bin/ash

#> FETCH e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19
#>  FROM http://ftp.gnu.org/gnu/make/make-4.3.tar.gz

set -uex

export PATH='/2/00.ccache/out/wrappers/c'  # may or may not exist
export PATH="$PATH:/1/out/protobusybox/bin"
export PATH="$PATH:/2/01-gnumake/out/bin"
export PATH="$PATH:/2/05-gnugcc4/out/bin"
export PATH="$PATH:/2/06-binutils/out/bin"

echo "### $0: unpacking intermediate GNU Make sources..."
mkdir -p /2/09-gnumake/tmp; cd /2/09-gnumake/tmp
gzip -d < /downloads/make-4.3.tar.gz | tar -x --strip-components=1

echo "### $0: building gnumake with intermediate GNU make"
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' build-aux/install-sh
#sed -i 's|/bin/sh|sh|' src/job.c
#sed -i 's|r = posix_spawn (|r = posix_spawnp (|' src/job.c
ash ./configure \
	CONFIG_SHELL=ash SHELL=ash MAKEINFO=true \
	--build x86_64-linux \
	--prefix=/2/09-gnumake/out \
	--disable-dependency-tracking
gnumake $MKOPTS

echo "### $0: installing gnumake with itself to test it"
./make $MKOPTS SHELL=ash install

[ ! -e /2/00.ccache/out/bin/ccache ] || /2/00.ccache/out/bin/ccache -sz
#rm -rf /2/09-gnumake/tmp
