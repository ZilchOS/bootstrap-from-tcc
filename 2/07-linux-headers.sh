#!/1/out/protobusybox/bin/ash

#> FETCH 4d7908da75ad50a70a0141721e259c2589b7bdcc317f7bd885b80c2ffa689211
#>  FROM https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.gz

set -uex

export PATH='/2/01-gnumake/out/bin'
export PATH="$PATH:/2/05-gnugcc4/out/bin"  # could be something older
export PATH="$PATH:/2/06-binutils/out/bin" # could be something older
export PATH="$PATH:/1/out/protobusybox/bin"

mkdir -p /2/07-linux-headers/tmp; cd /2/07-linux-headers/tmp

echo "### $0: unpacking Linux sources..."
mkdir -p /2/07-linux-headers/tmp; cd /2/07-linux-headers/tmp
gzip -d < /downloads/linux-5.15.tar.gz | tar -x --strip-components=1

echo "### $0: building Linux headers..."
sed -i 's|/dev/null|/2/07-linux-headers/tmp/null|g' Makefile
gnumake $MKOPTS \
	CONFIG_SHELL=/1/out/protobusybox/bin/ash CC=gcc HOSTCC=gcc ARCH=x86_64 \
	headers

echo "### $0: installing Linux headers..."
mkdir -p /2/07-linux-headers/out/
cp -rv usr/include /2/07-linux-headers/out/
find /2/07-linux-headers/out/include -name '.*' -delete
rm /2/07-linux-headers/out/include/Makefile

#rm -rf /2/07-linux-headers/tmp
