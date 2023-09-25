#!/store/2b2-busybox/bin/ash

#> FETCH 049b7883874f8a8e528dc7c4ed7b27cf7ceeb9ecf8fe71c3a8d51d574fddf84b
#>  FROM https://github.com/kristapsdz/lowdown/archive/refs/tags/VERSION_1_0_2.tar.gz
#>    AS lowdown-1.0.2.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export PATH="$PATH:/store/3a-pkg-config/bin"
export PKG_CONFIG_PATH='/store/3a-openssl/lib64/pkgconfig'
export SHELL='/store/2b2-busybox/bin/ash'

mkdir -p /tmp/3a-lowdown; cd /tmp/3a-lowdown
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking lowdown sources..."
tar --strip-components=1 -xf /downloads/lowdown-1.0.2.tar.gz

echo "### $0: fixing up lowdown sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure

echo "### $0: building lowdown..."
ash configure PREFIX=/store/3a-lowdown
make -j $NPROC CFLAGS=-ffile-prefix-map=$(pwd)=/builddir/

echo "### $0: installing lowdown..."
make -j $NPROC install_shared

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-lowdown )
