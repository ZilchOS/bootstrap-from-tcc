#!/store/2b2-busybox/bin/ash

#> FETCH fc9f85fc030e233142908241af7a846e60630aa7388de9a5fafb1f3a26840854
#>  FROM https://boostorg.jfrog.io/artifactory/main/release/1.77.0/source/boost_1_77_0.tar.bz2

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"
export LD_LIBRARY_PATH=/store/2b1-clang/lib

mkdir -p /tmp/3a-boost; cd /tmp/3a-boost
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: aliasing ash to sh..."
mkdir aliases; ln -s /store/2b2-busybox/bin/ash aliases/sh
export PATH="/tmp/3a-boost/aliases:$PATH"

echo "### $0: unpacking Boost sources..."
tar --strip-components=1 -xf /downloads/boost_1_77_0.tar.bz2

echo "### $0: patching up Boost sources..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' \
	bootstrap.sh \
	tools/build/src/engine/build.sh
sed -i 's|/bin/sh|sh|' \
	tools/build/src/engine/execunix.cpp \
	boost/process/detail/posix/shell_path.hpp
EXTRA_INCL='/tmp/2b1-clang/extra_includes'
mkdir -p $EXTRA_INCL
cp /store/2b1-clang/lib/clang/13.0.0/include/*mmintrin.h $EXTRA_INCL/
cp /store/2b1-clang/lib/clang/13.0.0/include/mm_malloc.h $EXTRA_INCL/
cp /store/2b1-clang/lib/clang/13.0.0/include/unwind.h $EXTRA_INCL/

echo "### $0: building Boost..."
ash bootstrap.sh
./b2 --without-python -j $NPROC \
	include=/store/2a6-linux-headers/include \
	include=$EXTRA_INCL

echo "### $0: installing Boost..."
./b2 install --prefix=/store/3a-boost
