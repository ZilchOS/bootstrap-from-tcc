#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 0a905ca8635ca81aa152e123bdde7e54cbe764fdd9a70d62af44cad8b92967af
#>  FROM https://github.com/Kitware/CMake/releases/download/v3.27.4/cmake-3.27.4.tar.gz

set -uex

export PATH='/store/1-stage1/protobusybox/bin/'
export PATH="$PATH:/store/2a0-static-gnumake/wrappers"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a5-gnugcc10/bin"

export SHELL=/store/1-stage1/protobusybox/bin/ash

mkdir -p /tmp/2a7-cmake; cd /tmp/2a7-cmake
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking CMake sources..."
tar --strip-components=1 -xf /downloads/cmake-3.27.4.tar.gz

echo "### $0: fixing up CMake sources..."
sed -i "s|/bin/sh|$SHELL|" bootstrap
sed -i 's|__FILE__|"__FILE__"|' \
	Source/CPack/IFW/cmCPackIFWCommon.h \
	Source/CPack/cmCPack*.h \
	Source/cmCTest.h

echo "### $0: bundling libraries..."
# poor man's static linking, a way for cmake to be self-contained later
mkdir -p /store/2a7-cmake/bundled-runtime
cp -H /store/2a5-gnugcc10/lib/libstdc++.so.6 /store/2a7-cmake/bundled-runtime/
cp -H /store/2a5-gnugcc10/lib/libgcc_s.so.1 /store/2a7-cmake/bundled-runtime/

echo "### $0: building CMake..."
ash configure \
	CFLAGS="-DCPU_SETSIZE=128 -D_GNU_SOURCE" \
	CXXFLAGS="-isystem /store/2a6-linux-headers/include" \
	LDFLAGS="-Wl,-rpath /store/2a7-cmake/bundled-runtime" \
	--prefix=/store/2a7-cmake \
	--parallel=$NPROC \
	-- \
	-DCMAKE_USE_OPENSSL=OFF
make -j $NPROC
echo "### $0: installing CMake..."
make -j $NPROC install/strip

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a7 /store/2a7-cmake )
