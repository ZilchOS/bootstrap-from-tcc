#!/1/out/protobusybox/bin/ash

#> FETCH 498449a994efeba527885c10405993427995d3f86b8768d8cdf8d9dd7c6b73e8
#>  FROM http://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2

#> FETCH 0d4de7e1476f79d24c38d5bc04a06fcc9a1bb9cf35fd654ceada29af03ad1844
#>  FROM https://www.mpfr.org/mpfr-3.1.4/mpfr-3.1.4.tar.gz

#> FETCH 617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3
#>  FROM http://www.multiprecision.org/downloads/mpc-1.0.3.tar.gz

#> FETCH 6b8b0fd7f81d0a957beb3679c81bbb34ccc7568d5682844d8924424a0dadcb1b
#>  FROM http://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2

#> FETCH 8fcf994811ad4e5c7ac908e8cf62af2c1982319e5551f62ae72016064dacdf16
#>  FROM https://ftp.gnu.org/gnu/gcc/gcc-10.3.0/gcc-10.3.0.tar.gz

set -uex

export PATH='/2/00.ccache/out/wrappers/c++'  # may or may not exist
export PATH="$PATH:/1/out/protobusybox/bin"
export PATH="$PATH:/2/01-gnumake/out/bin"
export PATH="$PATH:/2/02-static-binutils/out/bin"
export PATH="$PATH:/2/05-gnugcc4/out/bin"

mkdir -p /2/90-gnugcc10/tmp; cd /2/90-gnugcc10/tmp

# TODO: better, outer-level solution for /usr/bin/env and popen specifically
# just patch musl to search in $PATH?
echo "### $0: providing /usr/bin/env and sh in PATH for popen..."
mkdir /usr; mkdir /usr/bin
ln -s /1/out/protobusybox/bin/env /usr/bin/env
mkdir aliases; ln -s /1/out/protobusybox/bin/ash aliases/sh
export PATH="/2/90-gnugcc10/tmp/aliases:$PATH"

SYSROOT=/2/04-musl/out

echo "### $0: unpacking GNU GCC 10 sources..."
mkdir gmp mpfr mpc isl
gzip -d < /downloads/gcc-10.3.0.tar.gz | tar -x --strip-components=1
bzip2 -d < /downloads/gmp-6.1.0.tar.bz2 | tar -x --strip-components=1 -C gmp
gzip -d < /downloads/mpfr-3.1.4.tar.gz | tar -x --strip-components=1 -C mpfr
gzip -d < /downloads/mpc-1.0.3.tar.gz | tar -x --strip-components=1 -C mpc
bzip2 -d < /downloads/isl-0.18.tar.bz2 | tar -x --strip-components=1 -C isl

echo "### $0: fixing up GNU GCC 10 sources..."
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' \
	missing move-if-change mkdep mkinstalldirs symlink-tree install-sh \
	gcc/exec-tool.in libgcc/mkheader.sh
sed -i 's|/lib/ld-musl-x86_64.so.1|/2/04-musl/out/lib/libc.so|' \
	gcc/config/i386/linux64.h
sed -i 's|"os/gnu-linux"|"os/generic"|' libstdc++-v3/configure.host
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh */ltmain.sh

echo "### $0: building GNU GCC 10"
ash configure \
	CONFIG_SHELL='/1/out/protobusybox/bin/ash' \
	SHELL='/1/out/protobusybox/bin/ash' \
	--with-sysroot=/2/04-musl/out \
	--with-native-system-header-dir=/include \
	--with-build-time-tools=/2/02-static-binutils/out/bin \
	--prefix=/2/90-gnugcc10/out \
	--with-specs='%{!static:%x{-rpath=/2/90-gnugcc10/out/lib}}' \
	--enable-languages=c,c++ \
	--disable-bootstrap \
	--disable-libquadmath --disable-decimal-float --disable-fixed-point \
	--disable-lto \
	--disable-libgomp \
	--disable-multilib \
	--disable-multiarch \
	--disable-libmudflap \
	--disable-libssp \
	--disable-nls \
	--disable-libitm \
	--disable-libsanitizer \
	--disable-cet \
	--disable-gnu-unique-object \
	--disable-checking \
	--host x86_64-linux-musl --build x86_64-linux-musl
gnumake $MKOPTS
echo "### $0: installing GNU GCC 10"
gnumake $MKOPTS install

rm /usr/bin/env && rmdir /usr/bin && rmdir /usr
[ ! -e /2/00.ccache/out/bin/ccache ] || /2/00.ccache/out/bin/ccache -sz
#rm -rf /2/90-gnugcc10/tmp
