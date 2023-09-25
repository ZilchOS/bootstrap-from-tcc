#!/store/2b2-busybox/bin/ash

#> FETCH f9e8d81d0405ba66d181529af42a3354f838c939095ff99930da6aa9cdf6fe46
#>  FROM https://github.com/google/brotli/archive/refs/tags/v1.0.9.tar.gz
#>    AS brotli-1.0.9.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-brotli; cd /tmp/3a-brotli
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking brotli sources..."
tar --strip-components=1 -xf /downloads/brotli-1.0.9.tar.gz

echo "### $0: building brotli..."
ash configure --prefix=/store/3a-brotli --help #--disable-dependency-tracking
CFLAGS='-fPIC'
CFLAGS="$CFLAGS -DBROTLICOMMON_SHARED_COMPILATION"
CFLAGS="$CFLAGS -DBROTLI_SHARED_COMPILATION"
make -j $NPROC lib CFLAGS="$CFLAGS"
clang -shared bin/obj/c/common/*.o -o libbrotlicommon.so
clang -shared bin/obj/c/enc/*.o libbrotlicommon.so -o libbrotlienc.so
clang -shared bin/obj/c/dec/*.o libbrotlicommon.so -o libbrotlidec.so

echo "### $0: installing brotli..."
mkdir -p /store/3a-brotli/lib /store/3a-brotli/include
cp libbrotlicommon.so libbrotlienc.so libbrotlidec.so /store/3a-brotli/lib/
cp -r c/include/brotli /store/3a-brotli/include/
mkdir -p /store/3a-brotli/lib/pkgconfig
for l in common enc dec; do
	sed < scripts/libbrotli${l}.pc.in \
		-e 's|@PACKAGE_VERSION@|1.0.9|g' \
		-e 's|@prefix@|/store/3a-brotli|g' \
		-e 's|@exec_prefix@|/store/3a-brotli/bin|g' \
		-e 's|@includedir@|/store/3a-brotli/include|g' \
		-e 's|@libdir@|/store/3a-brotli/lib|g' \
		-e 's|-R|-Wl,-rpath=|g' \
		> /store/3a-brotli/lib/pkgconfig/libbrotli${l}.pc
done

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-brotli )
