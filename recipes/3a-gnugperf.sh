#!/store/2b2-busybox/bin/ash

#> FETCH 588546b945bba4b70b6a3a616e80b4ab466e3f33024a352fc2198112cdbb3ae2
#>  FROM http://ftp.gnu.org/pub/gnu/gperf/gperf-3.1.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-gnugperf; cd /tmp/3a-gnugperf
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking GNU gperf sources..."
tar --strip-components=1 -xf /downloads/gperf-3.1.tar.gz

echo "### $0: patching up GNU gperf sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' \
	configure lib/configure src/configure tests/configure doc/configure \
	Makefile.in src/Makefile.in doc/Makefile.in

echo "### $0: building GNU gperf..."
REWRITE="-ffile-prefix-map=$(pwd)=/builddir/"
ash configure --prefix=/store/3a-gnugperf \
	CFLAGS=$REWRITE CXXFLAGS="$REWRITE -Wno-register"
make -j $NPROC

echo "### $0: installing GNU gperf..."
make -j $NPROC install

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-gnugperf )
