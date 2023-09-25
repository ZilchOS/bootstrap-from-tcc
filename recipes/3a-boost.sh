#!/store/2b2-busybox/bin/ash

#> FETCH 6478edfe2f3305127cffe8caf73ea0176c53769f4bf1585be237eb30798c3b8e
#>  FROM https://boostorg.jfrog.io/artifactory/main/release/1.83.0/source/boost_1_83_0.tar.bz2

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export LD_LIBRARY_PATH=/store/2b1-clang/lib

mkdir -p /tmp/3a-boost; cd /tmp/3a-boost
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: aliasing ash to sh..."
mkdir aliases; ln -s /store/2b2-busybox/bin/ash aliases/sh
export PATH="/tmp/3a-boost/aliases:$PATH"

echo "### $0: unpacking Boost sources..."
tar --strip-components=1 -xf /downloads/boost_1_83_0.tar.bz2

echo "### $0: patching up Boost sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' \
	bootstrap.sh
sed -i 's|/usr/bin/env sh|/store/2b2-busybox/bin/ash|' \
	tools/build/src/engine/build.sh
sed -i 's|/bin/sh|sh|' \
	tools/build/src/engine/execunix.cpp \
	boost/process/detail/posix/shell_path.hpp
EXTRA_INCL='/tmp/3a-boost/extra_includes'
mkdir -p $EXTRA_INCL
cp /store/2b1-clang/lib/clang/17/include/*intrin*.h $EXTRA_INCL/
cp /store/2b1-clang/lib/clang/17/include/mm_malloc.h $EXTRA_INCL/
cp /store/2b1-clang/lib/clang/17/include/unwind.h $EXTRA_INCL/

echo "### $0: building Boost..."
ash bootstrap.sh
./b2 -j $NPROC \
	include=/store/2a6-linux-headers/include \
	include=$EXTRA_INCL \
	include=/store/2b1-clang/include/x86_64-unknown-linux-musl/c++/v1 \
	--with-context --with-thread --with-system

echo "### $0: installing Boost..."
./b2 install --prefix=/store/3a-boost \
	--with-context --with-thread --with-system

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-boost )
