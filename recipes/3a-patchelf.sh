#!/store/2b2-busybox/bin/ash

#> FETCH 4c7ed4bcfc1a114d6286e4a0d3c1a90db147a4c3adda1814ee0eee0f9ee917ed
#>  FROM https://github.com/NixOS/patchelf/releases/download/0.13/patchelf-0.13.tar.bz2

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-patchelf; cd /tmp/3a-patchelf
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking patchelf sources..."
tar --strip-components=1 -xf /downloads/patchelf-0.13.tar.bz2

echo "### $0: building patchelf..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure build-aux/install-sh

mkdir tmpdir
ash configure --disable-dependency-tracking --prefix=/store/3a-patchelf
make -j $NPROC

echo "### $0: installing patchelf..."
make -j $NPROC install-strip
