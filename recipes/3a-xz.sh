#!/store/2b2-busybox/bin/ash

#> FETCH 3e1e518ffc912f86608a8cb35e4bd41ad1aec210df2a47aaa1f95e7f5576ef56
#>  FROM https://tukaani.org/xz/xz-5.2.5.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-xz; cd /tmp/3a-xz
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking XZ sources..."
tar --strip-components=1 -xf /downloads/xz-5.2.5.tar.xz

echo "### $0: patching up XZ sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' \
	configure build-aux/install-sh po/Makefile.in.in

echo "### $0: building XZ..."
ash configure --prefix=/store/3a-xz --disable-dependency-tracking
make -j $NPROC

echo "### $0: installing XZ..."
make -j $NPROC install-strip
