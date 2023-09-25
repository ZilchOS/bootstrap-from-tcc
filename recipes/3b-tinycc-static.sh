#!/store/2b2-busybox/bin/ash

#> FETCH f5a71d05664340ae46cda9579c6079a0f2fa809d24386d284f0d091e4d576a4e
#>  FROM https://github.com/TinyCC/tinycc/archive/af1abf1f45d45b34f0b02437f559f4dfdba7d23c.tar.gz
#>    AS tinycc-mob-af1abf1.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export SHELL="/store/2b2-busybox/bin/ash"

mkdir -p /tmp/3b-tinycc-static; cd /tmp/3b-tinycc-static
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking TinyCC sources..."
tar --strip-components=1 -xf /downloads/tinycc-mob-af1abf1.tar.gz

#echo "### $0: fixing up TinyCC sources..."
sed -i "s|^VERSION = .*|VERSION = mob-af1abf1|" configure
sed -i "s|^GITHASH := .*|GITHASH = mob:af1abf1|" configure

echo "### $0: configuring TinyCC..."
$SHELL configure \
	--prefix=/store/3b-tinycc-static \
	--cc=cc \
	--extra-cflags="-O3 -static" \
	--extra-ldflags="-static" \
	--enable-static \
	--config-musl

echo "### $0: building TinyCC..."

make -j $NPROC tcc

echo "### $0: installing TinyCC..."
mkdir -p /store/3b-tinycc-static/bin
cp tcc /store/3b-tinycc-static/bin/

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3b /store/3b-tinycc-static )
