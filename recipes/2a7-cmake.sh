#!/store/1-stage1/protobusybox/bin/ash

#> FETCH d9570a95c215f4c9886dd0f0564ca4ef8d18c30750f157238ea12669c2985978
#>  FROM https://github.com/Kitware/CMake/releases/download/v3.21.4/cmake-3.21.4.tar.gz

set -uex

export PATH='/store/1-stage1/protobusybox/bin/'
export PATH="$PATH:/store/2a0-static-gnumake/wrappers"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a5-gnugcc10/bin"

export SHELL=/store/1-stage1/protobusybox/bin/ash

mkdir -p /tmp/2a7-cmake; cd /tmp/2a7-cmake
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking CMake sources..."
tar --strip-components=1 -xf /downloads/cmake-3.21.4.tar.gz

echo "### $0: fixing up CMake sources..."
sed -i "s|/bin/sh|$SHELL|" bootstrap

echo "### $0: bundling libraries..."
# poor man's static linking, a way for cmake to be self-contained later
mkdir -p /store/2a7-cmake/bundled-runtime
cp -H /store/2a5-gnugcc10/lib/libstdc++.so.6 /store/2a7-cmake/bundled-runtime/
cp -H /store/2a5-gnugcc10/lib/libgcc_s.so.1 /store/2a7-cmake/bundled-runtime/

echo "### $0: building CMake..."
ash configure \
	CFLAGS="-DCPU_SETSIZE=128" \
	CXXFLAGS="-I/store/2a6-linux-headers/include" \
	LDFLAGS="-Wl,-rpath /store/2a7-cmake/bundled-runtime" \
	--prefix=/store/2a7-cmake \
	--parallel=$NPROC \
	-- \
	-DCMAKE_USE_OPENSSL=OFF
make -j $NPROC
echo "### $0: installing CMake..."
make -j $NPROC install/strip
