#!/store/2b2-busybox/bin/ash

#> FETCH dd322f6bd0a20e6cebdfd388f69e98c3d183bed792cf4713c8a7ef498cba4894
#>  FROM https://curl.se/download/curl-8.2.1.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export PATH="$PATH:/store/3a-pkg-config/bin"

mkdir -p /tmp/3a-curl; cd /tmp/3a-curl
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking curl sources..."
tar --strip-components=1 -xf /downloads/curl-8.2.1.tar.xz

echo "### $0: building curl..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure install-sh

ash configure --prefix=/store/3a-curl \
	--with-mbedtls=/store/3a-mbedtls \
	--disable-dependency-tracking
make -j $NPROC

echo "### $0: installing curl..."
make -j $NPROC install-strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-curl )
