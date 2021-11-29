#!/store/2b2-busybox/bin/ash

#> FETCH f0b19ff39c3c9a5898a219497ababbadab99d8178acc980155c7e1271089b5a0
#>  FROM https://libarchive.org/downloads/libarchive-3.5.2.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export PATH="$PATH:/store/3a-pkg-config/bin"

mkdir -p /tmp/3a-libarchive; cd /tmp/3a-libarchive
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking libarchive sources..."
tar --strip-components=1 -xf /downloads/libarchive-3.5.2.tar.xz

echo "### $0: fixing up libarchive sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' \
	configure build/autoconf/install-sh

echo "### $0: building libarchive..."
ash configure --prefix=/store/3a-libarchive \
	--disable-dependency-tracking
make -j $NPROC

echo "### $0: installing libarchive..."
make -j $NPROC install-strip
