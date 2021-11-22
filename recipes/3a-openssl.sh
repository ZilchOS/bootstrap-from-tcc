#!/store/2b2-busybox/bin/ash

#> FETCH 59eedfcb46c25214c9bd37ed6078297b4df01d012267fe9e9eee31f61bc70536
#>  FROM https://www.openssl.org/source/openssl-3.0.0.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export PATH="$PATH:/store/3a-perl/bin"
export SHELL=/store/2b2-busybox/bin/ash

mkdir -p /tmp/3a-openssl; cd /tmp/3a-openssl
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking OpenSSL sources..."
tar --strip-components=1 -xf /downloads/openssl-3.0.0.tar.gz

echo "### $0: fixing up OpenSSL sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' config
sed -i 's|/usr/bin/env perl|/store/3a-perl/bin/perl|' Configure
sed -i 's|date = .*|date = "Tue Jan 01 00:00:01 UTC 1970";|' \
	util/mkbuildinf.pl

echo "### $0: building OpenSSL..."
CFLAGS='-I/store/2b1-clang/lib/clang/13.0.0/include'
CFLAGS="$CFLAGS -I/store/2a6-linux-headers"
CC=clang CFLAGS="$CFLAGS" ash config --prefix=/store/3a-openssl
make -j $NPROC

echo "### $0: installing OpenSSL..."
make -j $NPROC install_sw
