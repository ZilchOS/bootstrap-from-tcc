#!/store/2b2-busybox/bin/ash

#> FETCH b17403ce670ff18d8e06fea05a9ea9accf70678c88f1b9392a2e29b51127895f
#>  FROM http://libarchive.org/downloads/libarchive-3.7.1.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export PATH="$PATH:/store/3a-pkg-config/bin"

mkdir -p /tmp/3a-libarchive; cd /tmp/3a-libarchive
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking libarchive sources..."
tar --strip-components=1 -xf /downloads/libarchive-3.7.1.tar.xz

echo "### $0: fixing up libarchive sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' \
	configure build/autoconf/install-sh

echo "### $0: building libarchive..."
ash configure --prefix=/store/3a-libarchive \
	--disable-dependency-tracking \
	--without-openssl
make -j $NPROC

echo "### $0: installing libarchive..."
make -j $NPROC install-strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-libarchive )
