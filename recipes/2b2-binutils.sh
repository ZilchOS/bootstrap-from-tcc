#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 820d9724f020a3e69cb337893a0b63c2db161dadcb0e06fc11dc29eb1e84a32c
#>  FROM https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2b1-gnugcc10/bin"

mkdir -p /tmp/2b2-binutils; cd /tmp/2b2-binutils
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking binutils sources..."
tar --strip-components=1 -xf /downloads/binutils-2.37.tar.xz

echo "### $0: building binutils..."
sed -i 's|date +%Y|echo 0000|' config.guess
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	missing install-sh mkinstalldirs configure
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh

mkdir tmpdir
ash configure \
	TMPDIR=/2/06-binutils/tmp/tmpdir \
	--enable-deterministic-archives \
	--host x86_64-linux --build x86_64-linux \
	--prefix=/store/2b2-binutils
make -j $NPROC

echo "### $0: installing binutils..."
make -j $NPROC install
