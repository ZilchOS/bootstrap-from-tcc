#!/store/2b2-busybox/bin/ash

#> FETCH df223b3333a545fddbc67b49ded3d242c66fadf7a04beb3ada20957fcd1ffc0e
#>  FROM https://github.com/troglobit/editline/releases/download/1.17.1/editline-1.17.1.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-editline; cd /tmp/3a-editline
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking editline sources..."
tar --strip-components=1 -xf /downloads/editline-1.17.1.tar.xz

echo "### $0: fixing up editline sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure aux/install-sh

echo "### $0: building editline..."
ash configure --prefix=/store/3a-editline --disable-dependency-tracking
make -j $NPROC

echo "### $0: installing editline..."
make -j $NPROC install-strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-editline )
