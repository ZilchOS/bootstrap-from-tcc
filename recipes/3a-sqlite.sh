#!/store/2b2-busybox/bin/ash

#> FETCH 49008dbf3afc04d4edc8ecfc34e4ead196973034293c997adad2f63f01762ae1
#>  FROM https://sqlite.org/2023/sqlite-autoconf-3430000.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-sqlite; cd /tmp/3a-sqlite
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking SQLite archive..."
tar --strip-components=1 -xf /downloads/sqlite-autoconf-3430000.tar.gz

echo "### $0: building SQLite..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure install-sh

ash configure --prefix=/store/3a-sqlite
make -j $NPROC

echo "### $0: installing SQLite..."
make -j $NPROC install-strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-sqlite )
