#!/store/1-stage1/protobusybox/bin/ash

#> FETCH cca91be956fe081f8f6da72034cded96fe35a50be4bfb7e103e354aa2159a674
#>  FROM https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.4.12.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a5-gnugcc10/bin"

mkdir -p /tmp/2a6-linux-headers; cd /tmp/2a6-linux-headers
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking Linux sources..."
tar --strip-components=1 -xf /downloads/linux-6.4.12.tar.xz \
	linux-6.4.12/Makefile \
	linux-6.4.12/arch/x86 \
	linux-6.4.12/include \
	linux-6.4.12/scripts \
	linux-6.4.12/tools

echo "### $0: building Linux headers..."
make -j $NPROC \
	CONFIG_SHELL=/store/1-stage1/protobusybox/bin/ash \
	CC=gcc HOSTCC=gcc ARCH=x86_64 \
	headers

echo "### $0: installing Linux headers..."
mkdir -p /store/2a6-linux-headers/
find usr/include -name '.*' | xargs rm
cp -rv usr/include /store/2a6-linux-headers/

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a6 /store/2a6-linux-headers )
