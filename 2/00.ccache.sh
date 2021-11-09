#!/1/out/protobusybox/bin/ash

#> FETCH d2abe88d4c283ce960e233583061127b156ffb027c6da3cf10770fc0c7244194
#>  FROM https://github.com/ccache/ccache/releases/download/v3.7.12/ccache-3.7.12.tar.gz

set -uex

export PATH='/1/out/protobusybox/bin'
#export PATH="$PATH:/2/01-gnumake/out/bin"
#export PATH="$PATH:/2/02-static-binutils/out/bin"
#export PATH="$PATH:/2/03-static-gnugcc4/out/bin"
export PATH='/2/00-intermediate-gnumake/out/bin'
export PATH="$PATH:/1/out/tinycc/wrappers:/1/out/protobusybox/bin"

echo "### $0: unpacking ccache sources..."
mkdir -p /2/00.ccache/tmp; cd /2/00.ccache/tmp
gzip -d < /downloads/ccache-3.7.12.tar.gz | tar -x --strip-components=1

echo "### $0: building ccache..."
sed -i 's|/dev/null|/2/00.ccache/tmp/null|g' \
	configure
:> null
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' \
	configure
ash configure \
	--host x86_64-linux --build x86_64-linux \
	--prefix=/2/00.ccache/out
/2/00-intermediate-gnumake/out/bin/gnumake $MKOPTS

echo "### $0: installing ccache..."
gnumake $MKOPTS install

mkdir -p /2/00.ccache/out/wrappers/c++
for n in cc c++ gcc g++; do
	ln -s /2/00.ccache/out/bin/ccache /2/00.ccache/out/wrappers/c++/$n
	ln -s /2/00.ccache/out/bin/ccache \
		/2/00.ccache/out/wrappers/c++/x86_64-linux-$n
done
mkdir -p /2/00.ccache/out/wrappers/c
cp -d /2/00.ccache/out/wrappers/c++/*cc /2/00.ccache/out/wrappers/c/
mkdir -p /2/00.ccache/out/wrappers/cc-only
ln -s /2/00.ccache/out/bin/ccache /2/00.ccache/out/wrappers/cc-only/cc

mkdir /2/00.ccache/out/etc
cat > /2/00.ccache/out/etc/ccache.conf <<\EOF
cache_dir = /ccache
compiler_check = content
compression = false
sloppiness = include_file_ctime,include_file_mtime
max_size = 0
EOF
export PATH="/2/00.ccache/out/wrappers/cc-only:$PATH"

echo "### $0: testing ccache on itself..."
/2/00.ccache/out/bin/ccache -z
/2/00.ccache/out/bin/ccache -s > /2/00.ccache/tmp/stats
cat /2/00.ccache/tmp/stats
grep '^cache miss                             0$' /2/00.ccache/tmp/stats
grep '^cache hit rate                      0.00 %$' /2/00.ccache/tmp/stats
ash configure --host x86_64-linux --build x86_64-linux CC=cc
gnumake $MKOPTS -B
/2/00.ccache/out/bin/ccache -z
gnumake $MKOPTS -B
/2/00.ccache/out/bin/ccache -s > /2/00.ccache/tmp/stats
cat /2/00.ccache/tmp/stats
grep '^cache miss                             0$' /2/00.ccache/tmp/stats
grep '^cache hit rate                    100.00 %' /2/00.ccache/tmp/stats
/2/00.ccache/out/bin/ccache -z

#rm -rf /2/00.ccache/tmp
