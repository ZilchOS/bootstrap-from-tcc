#!/store/2b2-busybox/bin/ash

#> FETCH 525bfde06e024c1218047dee1c8b4c89312df1a4b5658711009086cda5dfaa55
#>  FROM https://github.com/ARMmbed/mbedtls/archive/refs/tags/v3.0.0.tar.gz
#>    AS mbedtls-3.0.0.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export SHELL=/store/2b2-busybox/bin/ash

mkdir -p /tmp/3a-mbedtls; cd /tmp/3a-mbedtls
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking mbedtls sources..."
tar --strip-components=1 -xf /downloads/mbedtls-3.0.0.tar.gz

echo "### $0: fixing up mbedtls sources..."
#sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' library/Makefile
sed -i 's|^DESTDIR=.*|DESTDIR=/store/3a-mbedtls|' Makefile

echo "### $0: building mbedtls..."
make -j $NPROC no_test

echo "### $0: installing mbedtls..."
make -j $NPROC install
