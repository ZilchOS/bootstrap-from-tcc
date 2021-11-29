#!/store/2b2-busybox/bin/ash

#> FETCH 1b1896b334861db1c588adc6b72ecd88b9e143a397f04d96a6fdeb633f915208
#>  FROM https://github.com/kristapsdz/lowdown/archive/refs/tags/VERSION_0_10_0.tar.gz
#>    AS lowdown-0.10.0.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export PATH="$PATH:/store/3a-pkg-config/bin"
export PKG_CONFIG_PATH='/store/3a-openssl/lib64/pkgconfig'
export SHELL='/store/2b2-busybox/bin/ash'

mkdir -p /tmp/3a-lowdown; cd /tmp/3a-lowdown
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking lowdown sources..."
tar --strip-components=1 -xf /downloads/lowdown-0.10.0.tar.gz

echo "### $0: fixing up lowdown sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure

echo "### $0: building lowdown..."
ash configure PREFIX=/store/3a-lowdown
make -j $NPROC

echo "### $0: installing lowdown..."
make -j $NPROC install
