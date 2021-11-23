#!/store/2b2-busybox/bin/ash

#> FETCH 7034647cb4fcfeff54134d22a0443ec4eccba8f1bc902f9ef1e6b447c5c46118
#>  FROM https://releases.nixos.org/nix/nix-2.3.13/nix-2.3.13.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export PATH="$PATH:/store/3a-gnubash/bin"
export PATH="$PATH:/store/3a-pkg-config/bin"

export SHELL='/store/2b2-busybox/bin/ash'

export PKG_CONFIG_PATH='/store/3a-openssl/lib64/pkgconfig'
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-bzip2/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-sqlite/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-curl/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-editline/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-xz/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-brotli/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-seccomp/lib/pkgconfig"
LIBDIRS="$(pkg-config --variable=libdir openssl)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir bzip2)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir sqlite3)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libeditline)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir liblzma)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libbrotlicommon)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libseccomp)"
export LD_LIBRARY_PATH=$LIBDIRS

export BOOST_ROOT=/store/3a-boost/include

mkdir -p /tmp/3b-nix; cd /tmp/3b-nix
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking Nix sources..."
tar --strip-components=1 -xf /downloads/nix-2.3.13.tar.xz

echo "### $0: building Nix..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure

PCDEPS='bzip2 libbrotlicommon libbrotlienc libbrotlidec sqlite3 libseccomp'
CFLAGS="$(pkg-config --cflags $PCDEPS) -I/store/2a6-linux-headers/include"
LDFLAGS="$(pkg-config --libs $PCDEPS) -L/store/3a-boost/lib -v"
bash configure --prefix=/store/3b-nix \
	--with-boost=$BOOST_ROOT \
	CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
make -j $NPROC

echo "### $0: installing Nix..."
make -j $NPROC install
