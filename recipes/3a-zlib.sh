#!/store/2b4-busybox/bin/ash

#> FETCH c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1
#>  FROM http://zlib.net/zlib-1.2.11.tar.gz

set -uex

export PATH='/store/2b4-busybox/bin'
export PATH="$PATH:/store/2b1-gnugcc10/bin"
export PATH="$PATH:/store/2b2-binutils/bin"
export PATH="$PATH:/store/2b5-gnumake/wrappers"

export SHELL=/store/2b4-busybox/bin/ash

mkdir -p /tmp/3a-zlib; cd /tmp/3a-zlib
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking zlib sources..."
tar --strip-components=1 -xf /downloads/zlib-1.2.11.tar.gz

echo "### $0: fixing up zlib sources..."
sed -i "s|/bin/sh|$SHELL|" configure

echo "### $0: building zlib..."
ash configure --prefix=/store/3a-zlib
make -j $NPROC

echo "### $0: installing zlib..."
make -j $NPROC install
