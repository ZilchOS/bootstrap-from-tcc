#!/1/out/protobusybox/bin/ash

#> FETCH 936162c0312886c21581002b79932829aa048cfaf9937c6265aeaa14f1cd1775
#>  FROM http://gcc.gnu.org/pub/gcc/infrastructure/gmp-4.3.2.tar.bz2

#> FETCH 246d7e184048b1fc48d3696dd302c9774e24e921204221540745e5464022b637
#>  FROM https://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.gz

#> FETCH e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4
#>  FROM http://www.multiprecision.org/downloads/mpc-0.8.1.tar.gz

#> FETCH ddbaa583c5d4e4f0928bf15d9f6b6c283349e16eedc47bde71e1b813f6f37819
#>  FROM https://ftp.gnu.org/gnu/gcc/gcc-4.7.4/gcc-4.7.4.tar.gz

set -uex

export PATH='/2/00.ccache/out/wrappers/cc-only'  # may or may not exist
export PATH="$PATH:/1/out/tinycc/wrappers"
export PATH="$PATH:/1/out/protobusybox/bin"
export PATH="$PATH:/2/01-gnumake/out/bin"

mkdir -p /2/03-static-gnugcc4/tmp; cd /2/03-static-gnugcc4/tmp

# TODO: better, outer-level solution for /usr/bin/env and popen specifically
# just patch musl to search in $PATH?
echo "### $0: providing /usr/bin/env and sh in PATH for popen..."
mkdir /usr; mkdir /usr/bin
ln -s /1/out/protobusybox/bin/env /usr/bin/env
mkdir aliases; ln -s /1/out/protobusybox/bin/ash aliases/sh
export PATH="/2/03-static-gnugcc4/tmp/aliases:$PATH"

echo "### $0: unpacking GNU GCC sources..."
mkdir mpfr mpc gmp
gzip -d < /downloads/gcc-4.7.4.tar.gz | tar -x --strip-components=1
gzip -d < /downloads/mpfr-2.4.2.tar.gz | tar -x --strip-components=1 -C mpfr
gzip -d < /downloads/mpc-0.8.1.tar.gz | tar -x --strip-components=1 -C mpc
bzip2 -d < /downloads/gmp-4.3.2.tar.bz2 | tar -x --strip-components=1 -C gmp

echo "### $0: building static GNU GCC 4 (statically linked, C only)"
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' \
	missing move-if-change mkdep mkinstalldirs symlink-tree \
	gcc/genmultilib */*.sh gcc/exec-tool.in \
	install-sh */install-sh
sed -i 's|^\(\s*\)sh |\1/1/out/protobusybox/bin/ash |' Makefile* */Makefile*
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh */ltmain.sh
ash configure \
	CONFIG_SHELL='/1/out/protobusybox/bin/ash' \
	SHELL='/1/out/protobusybox/bin/ash' \
	--with-sysroot=/1/out/protomusl \
	--with-native-system-header-dir=/include \
	--with-build-time-tools=/2/02-static-binutils/out/bin \
	--prefix=/2/03-static-gnugcc4/out \
	--enable-languages=c \
	--disable-bootstrap \
	--disable-libquadmath --disable-decimal-float --disable-fixed-point \
	--disable-lto \
	--disable-libgomp \
	--disable-multilib \
	--disable-multiarch \
	--disable-libmudflap \
	--disable-libssp \
	--disable-nls \
	--host x86_64-linux --build x86_64-linux
gnumake $MKOPTS
echo "### $0: installing static GNU GCC 4 (statically linked, C only)"
gnumake $MKOPTS install

#rm -rf /2/03-static-gnugcc4/tmp
rm /usr/bin/env && rmdir /usr/bin && rmdir /usr
[ ! -e /2/00.ccache/out/bin/ccache ] || /2/00.ccache/out/bin/ccache -sz
