#!/store/2b4-busybox/bin/ash

#> FETCH d9570a95c215f4c988dd0f0564ca4ef8d18c30750f157238ea12669c2985978
#>  FROM https://github.com/Kitware/CMake/releases/download/v3.21.4/cmake-3.21.4.tar.gz

set -uex

export PATH='/store/2b4-busybox/bin'
export PATH="$PATH:/store/2b1-gnugcc10/bin"
export PATH="$PATH:/store/2b2-binutils/bin"
export PATH="$PATH:/store/2b5-gnumake/wrappers"

export SHELL=/store/2b4-busybox/bin/ash

mkdir -p /tmp/3a-cmake; cd /tmp/3a-cmake
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking CMake sources..."
tar --strip-components=1 -xf /downloads/cmake-3.21.4.tar.gz

echo "### $0: fixing up CMake sources..."
sed -i "s|/bin/sh|$SHELL|" bootstrap

echo "### $0: building CMake..."
ash configure \
	CFLAGS="-DCPU_SETSIZE=128" \
	CXXFLAGS=-I/store/2b3-linux-headers/include \
	--prefix=/store/3a-cmake \
	--parallel=$NPROC \
	-- \
	-DCMAKE_USE_OPENSSL=OFF
make -j $NPROC
echo "### $0: installing CMake..."
make -j $NPROC install
