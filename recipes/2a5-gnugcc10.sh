#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 68dadacce515b0f8a54f510edf07c1b636492bcdb8e8d54c56eb216225d16989
#>  FROM https://gmplib.org/download/gmp/gmp-6.1.0.tar.xz

#> FETCH 761413b16d749c53e2bfd2b1dfaa3b027b0e793e404b90b5fbaeef60af6517f5
#>  FROM https://www.mpfr.org/mpfr-3.1.4/mpfr-3.1.4.tar.xz

#> FETCH 617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3
#>  FROM http://www.multiprecision.org/downloads/mpc-1.0.3.tar.gz

#> FETCH 6b8b0fd7f81d0a957beb3679c81bbb34ccc7568d5682844d8924424a0dadcb1b
#>  FROM http://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2

#> FETCH 25109543fdf46f397c347b5d8b7a2c7e5694a5a51cce4b9c6e1ea8a71ca307c1
#>  FROM https://ftp.gnu.org/gnu/gcc/gcc-10.5.0/gcc-10.5.0.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a4-gnugcc4-cpp/bin"

mkdir -p /tmp/2a5-gnugcc10; cd /tmp/2a5-gnugcc10
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: aliasing ash to sh..."
mkdir aliases; ln -s /store/1-stage1/protobusybox/bin/ash aliases/sh
export PATH="/tmp/2a5-gnugcc10/aliases:$PATH"

SYSROOT=/store/2a3-intermediate-musl

echo "### $0: unpacking GNU GCC 10 sources..."
mkdir gmp mpfr mpc isl
tar --strip-components=1 -xf /downloads/gcc-10.5.0.tar.xz
tar --strip-components=1 -xf /downloads/gmp-6.1.0.tar.xz -C gmp
tar --strip-components=1 -xf /downloads/mpfr-3.1.4.tar.xz -C mpfr
tar --strip-components=1 -xf /downloads/mpc-1.0.3.tar.gz -C mpc
tar --strip-components=1 -xf /downloads/isl-0.18.tar.bz2 -C isl

echo "### $0: fixing up GNU GCC 10 sources..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	missing move-if-change mkdep mkinstalldirs symlink-tree install-sh \
	gcc/exec-tool.in libgcc/mkheader.sh
sed -i 's|^\(\s*\)sh |\1/store/1-stage1/protobusybox/bin/ash |' \
	libgcc/Makefile.in
sed -i 's|LIBGCC2_DEBUG_CFLAGS = -g|LIBGCC2_DEBUG_CFLAGS = |' \
	libgcc/Makefile.in
sed -i "s|/lib/ld-musl-x86_64.so.1|$SYSROOT/lib/libc.so|" \
	gcc/config/i386/linux64.h
sed -i 's|m64=../lib64|m64=../lib|' gcc/config/i386/t-linux64
sed -i 's|"os/gnu-linux"|"os/generic"|' libstdc++-v3/configure.host
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh */ltmain.sh

echo "### $0: building GNU GCC 10"
ash configure \
	CONFIG_SHELL='/store/1-stage1/protobusybox/bin/ash' \
	SHELL='/store/1-stage1/protobusybox/bin/ash' \
	CFLAGS=-O2 CXX_FLAGS=-O2 \
	CFLAGS_FOR_TARGET=-O2 CXXFLAGS_FOR_TARGET=-O2 \
	--with-sysroot=$SYSROOT \
	--with-native-system-header-dir=/include \
	--with-build-time-tools=/store/2a1-static-binutils/bin \
	--prefix=/store/2a5-gnugcc10 \
	--with-specs='%{!static:%x{-rpath=/store/2a5-gnugcc10/lib}}' \
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
	--disable-gcov \
	--disable-checking \
	--host x86_64-linux-musl --build x86_64-linux-musl
make -j $NPROC
echo "### $0: installing GNU GCC 10"
make -j $NPROC install-strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a5 /store/2a5-gnugcc10 )
