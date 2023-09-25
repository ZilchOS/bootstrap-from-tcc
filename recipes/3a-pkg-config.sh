#!/store/2b2-busybox/bin/ash

#> FETCH 6fc69c01688c9458a57eb9a1664c9aba372ccda420a02bf4429fe610e7e7d591
#>  FROM https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-pkg-config; cd /tmp/3a-pkg-config
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking pkg-config sources..."
tar --strip-components=1 -xf /downloads/pkg-config-0.29.2.tar.gz

echo "### $0: patching pkg-config..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' \
	configure glib/configure \
	install-sh glib/install-sh

echo "### $0: building pkg-config..."
ash configure --prefix=/store/3a-pkg-config --with-internal-glib \
	CFLAGS=-Wno-int-conversion
make -j $NPROC

echo "### $0: installing pkg-config..."
make -j $NPROC install-strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-pkg-config )
