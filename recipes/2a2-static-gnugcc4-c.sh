#!/store/1-stage1/protobusybox/bin/ash

#> FETCH f69eff1bc3d15d4e59011d587c57462a8d3d32cf2378d32d30d008a42a863325
#>  FROM https://gmplib.org/download/gmp/archive/gmp-4.3.2.tar.xz

#> FETCH d7271bbfbc9ddf387d3919df8318cd7192c67b232919bfa1cb3202d07843da1b
#>  FROM https://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.xz

#> FETCH e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4
#>  FROM http://www.multiprecision.org/downloads/mpc-0.8.1.tar.gz

#> FETCH 92e61c6dc3a0a449e62d72a38185fda550168a86702dea07125ebd3ec3996282
#>  FROM https://ftp.gnu.org/gnu/gcc/gcc-4.7.4/gcc-4.7.4.tar.bz2

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/1-stage1/tinycc/wrappers"
export PATH="$PATH:/store/2a0-static-gnumake/bin"

mkdir -p /tmp/2a2-static-gnugcc4-c; cd /tmp/2a2-static-gnugcc4-c
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: aliasing ash to sh..."
mkdir aliases; ln -s /store/1-stage1/protobusybox/bin/ash aliases/sh
export PATH="/tmp/2a2-static-gnugcc4-c/aliases:$PATH"

echo "### $0: unpacking GNU GCC sources..."
mkdir mpfr mpc gmp
tar --strip-components=1 -xf /downloads/gcc-4.7.4.tar.bz2
tar --strip-components=1 -xf /downloads/mpfr-2.4.2.tar.xz -C mpfr
tar --strip-components=1 -xf /downloads/mpc-0.8.1.tar.gz -C mpc
tar --strip-components=1 -xf /downloads/gmp-4.3.2.tar.xz -C gmp

echo "### $0: building static GNU GCC 4 (statically linked, C only)"
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	missing move-if-change mkdep mkinstalldirs symlink-tree \
	gcc/genmultilib */*.sh gcc/exec-tool.in \
	install-sh */install-sh
sed -i 's|^\(\s*\)sh |\1/store/1-stage1/protobusybox/bin/ash |' \
	Makefile* */Makefile*
sed -i 's|LIBGCC2_DEBUG_CFLAGS = -g|LIBGCC2_DEBUG_CFLAGS = |' \
	libgcc/Makefile.in
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh */ltmain.sh
ash configure \
	CONFIG_SHELL='/store/1-stage1/protobusybox/bin/ash' \
	SHELL='/store/1-stage1/protobusybox/bin/ash' \
	CFLAGS=-O2 CFLAGS_FOR_TARGET=-O2 \
	--with-sysroot=/store/1-stage1/protomusl \
	--with-native-system-header-dir=/include \
	--with-build-time-tools=/store/2a1-static-binutils/bin \
	--prefix=/store/2a2-static-gnugcc4-c \
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
make -j $NPROC

echo "### $0: installing static GNU GCC 4 (statically linked, C only)"
make -j $NPROC install

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a2 /store/2a2-static-gnugcc4-c )
