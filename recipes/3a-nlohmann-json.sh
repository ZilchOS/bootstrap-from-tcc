#!/store/2b2-busybox/bin/ash

#> FETCH 8c4b26bf4b422252e13f332bc5e388ec0ab5c3443d24399acb675e68278d341f
#>  FROM https://github.com/nlohmann/json/releases/download/v3.11.2/json.tar.xz
#>    AS nlohmann-json-3.11.2.tar.xz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-nlohmann-json; cd /tmp/3a-nlohmann-json

echo "### $0: unpacking nlohmann-json sources..."
tar --strip-components=1 -xf /downloads/nlohmann-json-3.11.2.tar.xz

echo "### $0: installing nlohmann-json..."
mkdir /store/3a-nlohmann-json
cp -rv include /store/3a-nlohmann-json
mkdir -p /store/3a-nlohmann-json/lib/pkgconfig
sed < cmake/pkg-config.pc.in \
	-e 's|${PROJECT_NAME}|nlohmann_json|' \
	-e 's|${PROJECT_VERSION}|3.11.2|' \
	-e 's|${CMAKE_INSTALL_FULL_INCLUDEDIR}|/store/3a-nlohmann-json/include|' \
	> /store/3a-nlohmann-json/lib/pkgconfig/nlohmann_json.pc

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/3a /store/3a-nlohmann-json )
