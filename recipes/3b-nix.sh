#!/store/2b2-busybox/bin/ash

#> FETCH f3f8016621cf3971e0768404f05b89d4a7fc1911dddae5a9a7ed4bf62519302c
#>  FROM https://github.com/ZilchOS/nix/releases/download/nix-2.17.0-zilched/nix-2.17.0-zilched.tar.xz

#> FETCH 3659cd137c320991a78413dd370a92fd18e0a8bc36d017d554f08677a37d7d5a
#>  FROM https://raw.githubusercontent.com/somasis/musl-compat/c12ea3af4e6ee53158a175d992049c2148db5ff6/include/sys/queue.h

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/wrappers"
export PATH="$PATH:/store/3a-pkg-config/bin"
export PATH="$PATH:/store/3a-lowdown/bin"

export SHELL='/store/2b2-busybox/bin/ash'

#export PKG_CONFIG_PATH='/store/3a-openssl/lib64/pkgconfig'
export PKG_CONFIG_PATH=''
#export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-bzip2/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-sqlite/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-curl/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-editline/lib/pkgconfig"
#export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-xz/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-brotli/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-seccomp/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-libarchive/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-libsodium/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-lowdown/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-nlohmann-json/lib/pkgconfig"
#LIBDIRS="$(pkg-config --variable=libdir openssl)"
LIBDIRS=""
#LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir bzip2)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir sqlite3)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libeditline)"
#LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir liblzma)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libbrotlicommon)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libseccomp)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libarchive)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libsodium)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir lowdown)"
export LD_LIBRARY_PATH=$LIBDIRS

export BOOST_ROOT=/store/3a-boost/include

mkdir -p /tmp/3b-nix; cd /tmp/3b-nix
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking Nix sources..."
tar --strip-components=1 \
	-xf /downloads/nix-2.17.0-zilched.tar.xz

echo "### $0: copying queue.h..."
mkdir -p compat-includes/sys
cp /downloads/queue.h compat-includes/sys/

echo "### $0: stubbing out commands..."
mkdir stubs; export PATH="$(pwd)/stubs:$PATH"
ln -s /store/2b2-busybox/bin/true stubs/jq
ln -s /store/2b2-busybox/bin/true stubs/expr
ln -s /store/2b2-busybox/bin/ash stubs/bash

echo "### $0: patching up Nix sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure
sed -i 's|/bin/sh|${stdenv.busybox}/bin/ash|' configure
# avoid an expression confusing ash
nl configure | grep 7217 | tee configure-problematic-line
grep -F "'X\(//\)$'" configure-problematic-line
sed -i '7217d' configure
nl configure | grep 7217 | tee configure-problematic-line
! grep -F "'X\(//\)$'" configure-problematic-line
# replace the declare confusing ash
sed -i 's|declare \$name=.*|:|' configure

echo "### $0: building Nix..."
PCDEPS='libbrotlicommon libbrotlienc libbrotlidec sqlite3 libseccomp lowdown'
PCDEPS="$PCDEPS nlohmann_json"
INC="-I/store/2a6-linux-headers/include -I$(pwd)/compat-includes"
REWRITE="-ffile-prefix-map=$(pwd)=/builddir/"
export CFLAGS="$(pkg-config --cflags $PCDEPS) $INC $REWRITE"
export CXXFLAGS="$CFLAGS"
export GLOBAL_CXXFLAGS="$CFLAGS"
export LDFLAGS="$(pkg-config --libs $PCDEPS) -L/store/3a-boost/lib -v"
ash configure --prefix=/store/3b-nix \
	--with-boost=$BOOST_ROOT \
	--disable-doc-gen \
	--disable-gc \
	--disable-cpuid \
	--disable-gtest \
	--with-sandbox-shell=/store/3b-busybox-static/bin/busybox
sed -i "s|\${prefix}|/store/3b-nix|g" config.status
sed -i "s|\${exec_prefix}|/store/3b-nix|g" config.status
make -j $NPROC V=1

echo "### $0: installing Nix..."
make -j $NPROC install

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3b /store/3b-nix )
