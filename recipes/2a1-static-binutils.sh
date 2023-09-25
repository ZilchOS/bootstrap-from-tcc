#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 645c25f563b8adc0a81dbd6a41cffbf4d37083a382e02d5d3df4f65c09516d00
#>  FROM https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/1-stage1/tinycc/wrappers"
export PATH="$PATH:/store/2a0-static-gnumake/bin"

mkdir -p /tmp/2a1-static-binutils; cd /tmp/2a1-static-binutils
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking binutils sources..."
tar --strip-components=1 -xf /downloads/binutils-2.39.tar.xz

echo "### $0: building static binutils..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	missing install-sh mkinstalldirs
mkdir aliases
ln -s /store/1-stage1/protobusybox/bin/true aliases/makeinfo
PATH="/tmp/2a1-static-binutils/aliases:$PATH"
export lt_cv_sys_max_cmd_len=32768
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh

ash configure \
	CONFIG_SHELL=/store/1-stage1/protobusybox/bin/ash \
	SHELL=/store/1-stage1/protobusybox/bin/ash \
	CFLAGS='-O2 -D__LITTLE_ENDIAN__=1' \
	CFLAGS_FOR_TARGET=-O2 \
	MAKEINFO=/store/1-stage1/protobusybox/bin/true \
	--disable-gprofng \
	--enable-deterministic-archives \
	--host x86_64-linux --build x86_64-linux \
	--prefix=/store/2a1-static-binutils
make -j $NPROC all-libiberty all-gas all-bfd all-libctf all-zlib all-gprof
make all-ld  # race condition on ld/.deps/ldwrite.Po, serialize
make -j $NPROC

echo "### $0: installing static binutils..."
make -j $NPROC install
rm /store/2a1-static-binutils/lib/*.la  # broken, reference builddir

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a1 /store/2a1-static-binutils )
