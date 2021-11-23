#!/store/2b2-busybox/bin/ash

#> FETCH a132bd93188b938771135ac7c1f3ac1d3ce507c1fcbef8c471397639214ae2ab
#>  FROM https://curl.se/download/curl-7.80.0.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export PATH="$PATH:/store/3a-pkg-config/bin"
export PKG_CONFIG_PATH='/store/3a-openssl/lib64/pkgconfig'

mkdir -p /tmp/3a-curl; cd /tmp/3a-curl
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking curl sources..."
tar --strip-components=1 -xf /downloads/curl-7.80.0.tar.xz

echo "### $0: building curl..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure install-sh

ash configure --prefix=/store/3a-curl \
	--with-openssl=/store/3a-openssl \
	--disable-dependency-tracking
make -j $NPROC

echo "### $0: installing curl..."
make -j $NPROC install-strip
