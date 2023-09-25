#!/store/2b2-busybox/bin/ash

#> FETCH a420fcf7103e54e775c383e3751729b8fb2dcd087f6165befd13f28315f754f5
#>  FROM https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v3.4.1.tar.gz
#>    AS mbedtls-3.4.1.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export SHELL=/store/2b2-busybox/bin/ash

mkdir -p /tmp/3a-mbedtls; cd /tmp/3a-mbedtls
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking mbedtls sources..."
tar --strip-components=1 -xf /downloads/mbedtls-3.4.1.tar.gz

echo "### $0: fixing up mbedtls sources..."
sed -i 's|^DESTDIR=.*|DESTDIR=/store/3a-mbedtls|' Makefile
sed -i 's|programs: lib mbedtls_test|programs: lib|' Makefile
sed -i 's|install: no_test|install: lib|' Makefile

echo "### $0: building mbedtls..."
make -j $NPROC lib

echo "### $0: installing mbedtls..."
make -j $NPROC install

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-mbedtls )
