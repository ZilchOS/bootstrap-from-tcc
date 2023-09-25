#!/store/2b2-busybox/bin/ash

#> FETCH d82902400405cf0068574ef3dc1fe5f5926207543ba1ae6f8e7a1576351dcbdb
#>  FROM https://github.com/seccomp/libseccomp/releases/download/v2.5.4/libseccomp-2.5.4.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export PATH="$PATH:/store/3a-gnugperf/bin"

mkdir -p /tmp/3a-seccomp; cd /tmp/3a-seccomp
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking seccomp sources..."
tar --strip-components=1 -xf /downloads/libseccomp-2.5.4.tar.gz

echo "### $0: patching up seccomp sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure build-aux/install-sh

echo "### $0: building seccomp..."
ash configure --prefix=/store/3a-seccomp --disable-dependency-tracking \
	CFLAGS=-I/store/2a6-linux-headers/include
make -j $NPROC

echo "### $0: installing seccomp..."
make -j $NPROC install-strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-seccomp )
