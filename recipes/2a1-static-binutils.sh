#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 820d9724f020a3e69cb337893a0b63c2db161dadcb0e06fc11dc29eb1e84a32c
#>  FROM https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/1-stage1/tinycc/wrappers"
export PATH="$PATH:/store/2a0-static-gnumake/bin"

mkdir -p /tmp/2a1-static-binutils; cd /tmp/2a1-static-binutils
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking binutils sources..."
tar --strip-components=1 -xf /downloads/binutils-2.37.tar.xz

echo "### $0: building static binutils..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	missing install-sh mkinstalldirs
export lt_cv_sys_max_cmd_len=32768
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh

ash configure \
	CONFIG_SHELL=/store/1-stage1/protobusybox/bin/ash \
	SHELL=/store/1-stage1/protobusybox/bin/ash \
	CFLAGS='-D__LITTLE_ENDIAN__=1' \
	--enable-deterministic-archives \
	--host x86_64-linux --build x86_64-linux \
	--prefix=/store/2a1-static-binutils
make -j $NPROC

echo "### $0: installing static binutils..."
make -j $NPROC install
