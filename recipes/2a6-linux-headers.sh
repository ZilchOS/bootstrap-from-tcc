#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 57b2cf6991910e3b67a1b3490022e8a0674b6965c74c12da1e99d138d1991ee8
#>  FROM https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a5-gnugcc10/bin"

mkdir -p /tmp/2a6-linux-headers; cd /tmp/2a6-linux-headers
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking Linux sources..."
tar --strip-components=1 -xf /downloads/linux-5.15.tar.xz \
	linux-5.15/Makefile \
	linux-5.15/arch/x86 \
	linux-5.15/include \
	linux-5.15/scripts \
	linux-5.15/tools

echo "### $0: building Linux headers..."
make -j $NPROC \
	CONFIG_SHELL=/store/1-stage1/protobusybox/bin/ash \
	CC=gcc HOSTCC=gcc ARCH=x86_64 \
	headers

echo "### $0: installing Linux headers..."
mkdir -p /store/2a6-linux-headers/
find usr/include -name '.*' | xargs rm
cp -rv usr/include /store/2a6-linux-headers/
