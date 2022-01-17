#!/store/2b2-busybox/bin/ash

#> FETCH c6b244e58677c4c486dbf80e35ee01b192e133876942afa07454159ba118b44e
#>  FROM https://github.com/TinyCC/tinycc/archive/da11cf651576f94486dbd043dbfcde469e497574.tar.gz
#>    AS tinycc-da11cf6.tgz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export SHELL="/store/2b2-busybox/bin/ash"

mkdir -p /tmp/3b-tinycc-static; cd /tmp/3b-tinycc-static
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking TinyCC sources..."
tar --strip-components=1 -xf /downloads/tinycc-da11cf6.tgz

#echo "### $0: fixing up TinyCC sources..."
sed -i "s|^VERSION = .*|VERSION = tcc-mob-gitda11cf6|" configure
sed -i "s|^GITHASH := .*|GITHASH = mob:da11cf6|" configure

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
