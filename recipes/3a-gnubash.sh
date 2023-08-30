#!/store/2b2-busybox/bin/ash

#> FETCH 13720965b5f4fc3a0d4b61dd37e7565c741da9a5be24edc2ae00182fc1b3588c
#>  FROM https://ftp.gnu.org/gnu/bash/bash-5.2.15.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-gnubash; cd /tmp/3a-gnubash
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking GNU Bash sources..."
tar --strip-components=1 -xf /downloads/bash-5.2.15.tar.gz

echo "### $0: building GNU Bash..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure

ash configure --prefix=/store/3a-gnubash --without-bash-malloc \
	CFLAGS=-Wno-implicit-function-declaration
make -j $NPROC

echo "### $0: installing GNU Bash..."
make -j $NPROC install-strip
