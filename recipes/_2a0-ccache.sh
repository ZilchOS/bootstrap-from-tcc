#!/store/1-stage1/protobusybox/bin/ash

#> FETCH a02f4e8360dc6618bc494ca35b0ae21cea080f804a4898eab1ad3fcd108eb400
#>  FROM https://github.com/ccache/ccache/releases/download/v3.7.12/ccache-3.7.12.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/1-stage1/tinycc/wrappers"
export PATH="$PATH:/store/2a0-static-gnumake/bin"

echo "### $0: unpacking ccache sources..."
mkdir -p /tmp/_2a0-ccache; cd /tmp/_2a0-ccache
tar --strip-components=1 -xf /downloads/ccache-3.7.12.tar.xz

echo "### $0: building ccache..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' configure
ash configure \
	--host x86_64-linux --build x86_64-linux \
	--prefix=/store/_2a0-ccache
make -j $NPROC

echo "### $0: installing ccache..."
make -j $NPROC install

cat > /store/_2a0-ccache/wrap-available <<\EOF
mkdir -p .ccache-wrappers
for prefix in '' x86_64-linux- x86_64-linux-musl- x86_64-linux-unknown-; do
	for name in cc c++ gcc g++ clang clang++ tcc; do
		if command -v $prefix$name; then
			ln -s /store/_2a0-ccache/bin/ccache \
				.ccache-wrappers/$prefix$name
		fi
	done
done
pwd
export PATH="$(pwd)/.ccache-wrappers:$PATH"
EOF
chmod +x /store/_2a0-ccache/wrap-available

. /store/_2a0-ccache/wrap-available

mkdir /store/_2a0-ccache/etc
cat > /store/_2a0-ccache/etc/ccache.conf <<\EOF
cache_dir = /ccache
compiler_check = content
compression = false
sloppiness = include_file_ctime,include_file_mtime
max_size = 0
EOF
export PATH="/store/_2a0-ccache/wrappers/cc-only:$PATH"

echo "### $0: testing ccache on itself..."
/store/_2a0-ccache/bin/ccache -z
/store/_2a0-ccache/bin/ccache -s > _stats; cat _stats
grep '^cache miss                             0$' _stats
grep '^cache hit rate                      0.00 %$' _stats
ash configure --host x86_64-linux --build x86_64-linux CC=cc
make -j $NPROC -B
/store/_2a0-ccache/bin/ccache -z
make -j $NPROC -B
/store/_2a0-ccache/bin/ccache -s > _stats; cat _stats
grep '^cache miss                             0$' _stats
grep '^cache hit rate                    100.00 %' _stats
/store/_2a0-ccache/bin/ccache -z
