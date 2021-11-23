#!/store/2b2-busybox/bin/ash

#> FETCH 59065c8733364725e9721ba48c3a99bbc52af921daf48df4b1e012fbc7b10a76
#>  FROM https://github.com/seccomp/libseccomp/releases/download/v2.5.3/libseccomp-2.5.3.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export PATH="$PATH:/store/3a-gnugperf/bin"

mkdir -p /tmp/3a-seccomp; cd /tmp/3a-seccomp
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking seccomp sources..."
tar --strip-components=1 -xf /downloads/libseccomp-2.5.3.tar.gz

echo "### $0: patching up seccomp sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure build-aux/install-sh

echo "### $0: building seccomp..."
ash configure --prefix=/store/3a-seccomp --disable-dependency-tracking \
	CFLAGS=-I/store/2a6-linux-headers/include
make -j $NPROC

echo "### $0: installing seccomp..."
make -j $NPROC install-strip
