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

export PATH='/2/01-gnumake/out/bin'
export PATH="$PATH:/2/02-static-binutils/out/bin"
export PATH="$PATH:/2/03-static-gnugcc4/out/bin"
export PATH="$PATH:/1/out/protobusybox/bin"

mkdir -p /2/05-gnugcc4/tmp; cd /2/05-gnugcc4/tmp

# TODO: better, outer-level solution for /usr/bin/env and popen specifically
# just patch musl to search in $PATH?
echo "### $0: providing /usr/bin/env and sh in PATH for popen..."
mkdir /usr; mkdir /usr/bin
ln -s /1/out/protobusybox/bin/env /usr/bin/env
mkdir aliases; ln -s /1/out/protobusybox/bin/ash aliases/sh
export PATH="/2/05-gnugcc4/tmp/aliases:$PATH"

echo "### $0: creating wrappers that make previous GNU GCC target new musl..."
SYSROOT=/2/04-musl/out
export _SYSROOT="--sysroot $SYSROOT"
export _LDFLAG="--dynamic-linker=$SYSROOT/lib/libc.so"
export _NEWINC="-I/2/04-musl/out/include"
export _REALCC="-I/2/04-musl/out/include"
mkdir wrappers
echo '#!/1/out/protobusybox/bin/ash' > wrappers/cc
echo '#!/1/out/protobusybox/bin/ash' > wrappers/cpp
echo '#!/1/out/protobusybox/bin/ash' > wrappers/ld
echo '/2/03-static-gnugcc4/out/bin/gcc $_SYSROOT -Wl,$_LDFLAG "$@"' \
	>> wrappers/cc
echo '/2/03-static-gnugcc4/out/bin/cpp $_NEWINC "$@"' >> wrappers/cpp
echo '/2/02-static-binutils/out/bin/ld $_LDFLAG "$@"' >> wrappers/ld
chmod +x wrappers/cc wrappers/cpp wrappers/ld
export PATH="/2/05-gnugcc4/tmp/wrappers:$PATH"

echo "### $0: unpacking GNU GCC 4 sources..."
mkdir mpfr mpc gmp
gzip -d < /downloads/gcc-4.7.4.tar.gz | tar -x --strip-components=1
gzip -d < /downloads/mpfr-2.4.2.tar.gz | tar -x --strip-components=1 -C mpfr
gzip -d < /downloads/mpc-0.8.1.tar.gz | tar -x --strip-components=1 -C mpc
bzip2 -d < /downloads/gmp-4.3.2.tar.bz2 | tar -x --strip-components=1 -C gmp

echo "### $0: fixing up GNU GCC 4 sources..."
sed -i 's|/dev/null|/2/05-gnugcc4/tmp/null|g' \
	config.sub configure* */configure \
	libtool.m4 ltmain.sh */ltmain.sh \
	*/acinclude.m4 */*/acinclude.m4 \
	*/Makefile* */*/Makefile* \
	mkinstalldirs \
	fixincludes/genfixes fixincludes/*.* \
	gcc/genmultilib
:> null
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' \
	missing move-if-change mkdep mkinstalldirs symlink-tree \
	gcc/genmultilib */*.sh gcc/exec-tool.in \
	install-sh */install-sh
sed -i 's|^\(\s*\)sh |\1/1/out/protobusybox/bin/ash |' Makefile* */Makefile*
sed -i 's|/lib64/ld-linux-x86-64.so.2|/2/04-musl/out/lib/libc.so|' \
	gcc/config/i386/linux64.h
sed -i 's|"os/gnu-linux"|"os/generic"|' libstdc++-v3/configure.host
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh */ltmain.sh

echo "### $0: building GNU GCC 4 (dynamically linked, with C++ support)"
ash configure \
	cache_file=nonex \
	CONFIG_SHELL='/1/out/protobusybox/bin/ash' \
	SHELL='/1/out/protobusybox/bin/ash' \
	CC=cc CPP=cpp LD=ld \
	--with-build-time-tools=/2/02-static-binutils/out/bin \
	--prefix=/2/05-gnugcc4/out \
	--with-sysroot=$SYSROOT \
	--enable-languages=c,c++ \
	--with-specs='%{!static:%x{-rpath=/2/05-gnugcc4/out/lib64}}' \
	--with-native-system-header-dir=/include \
	--disable-bootstrap \
	--disable-quadmath --disable-decimal-float --disable-fixed-point \
	--disable-lto \
	--disable-libgomp \
	--disable-multilib --disable-multiarch \
	--disable-libmudflap --disable-libsanitizer \
	--disable-libssp --disable-libmpx \
	--disable-nls \
	--disable-libitm \
	--host x86_64-linux --build x86_64-linux
gnumake $MKOPTS
echo "### $0: installing GNU GCC 4 (dynamically linked, with C++ support)"
gnumake $MKOPTS install

rm /usr/bin/env && rmdir /usr/bin && rmdir /usr
#rm -rf /2/05-gnugcc4/tmp
