#!/1/out/protobusybox/bin/ash

#> FETCH 415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549
#>  FROM https://busybox.net/downloads/busybox-1.34.1.tar.bz2

set -uex

export PATH='/1/out/protobusybox/bin'
export PATH="$PATH:/2/01-gnumake/out/bin"
export PATH="$PATH:/2/05-gnugcc4/out/bin"
export PATH="$PATH:/2/06-binutils/out/bin"

echo "### $0: unpacking busybox sources..."
mkdir -p /2/08-busybox/tmp; cd /2/08-busybox/tmp
bzip2 -d < /downloads/busybox-1.34.1.tar.bz2 | tar -x --strip-components=1

# TODO: better, outer-level solution for /usr/bin/env and popen specifically
# just patch musl to search in $PATH?
echo "### $0: providing /usr/bin/env and sh in PATH for popen..."
mkdir /usr; mkdir /usr/bin
ln -s /1/out/protobusybox/bin/env /usr/bin/env
mkdir aliases; ln -s /1/out/protobusybox/bin/ash aliases/sh
export PATH="/2/08-busybox/tmp/aliases:$PATH"

echo "### $0: configuring busybox..."
BUSYBOX_FLAGS='CONFIG_SHELL=/1/out/protobusybox/bin/ash'
BUSYBOX_FLAGS="$BUSYBOX_FLAGS CC=gcc HOSTCC=gcc"
BUSYBOX_FLAGS="$BUSYBOX_FLAGS CFLAGS=-I/2/07-linux-headers/out/include"
BUSYBOX_FLAGS="$BUSYBOX_FLAGS KCONFIG_NOTIMESTAMP=y"
echo -e '#!/1/out/protobusybox/bin/ash\nprintf 9999' > scripts/gcc-version.sh
sed -i \
	-e 's|/dev/null|/2/08-busybox/tmp/null|g' \
	-e 's|/bin/sh|/1/out/protobusybox/bin/ash|g' \
	Makefile scripts/Kbuild.include arch/x86_64/Makefile \
	scripts/kconfig/*.c \
	applets/busybox.mkscripts \
	applets/usage_compressed \
	applets/install.sh \
	scripts/*/*.sh scripts/*.sh \
	scripts/mkconfigs scripts/embedded_scripts scripts/trylink
:>null
gnumake $MKOPTS $BUSYBOX_FLAGS \
	defconfig
sed -i 's|CONFIG_INSTALL_NO_USR=y|CONFIG_INSTALL_NO_USR=n|' .config

echo "### $0: building busybox..."
gnumake $MKOPTS $BUSYBOX_FLAGS busybox busybox.links
sed -i 's|^/usr/s\?bin/|/bin/|' busybox.links

echo "### $0: installing busybox..."
gnumake $MKOPTS $BUSYBOX_FLAGS install CONFIG_PREFIX=/2/08-busybox/out/

#rm -rf /2/08-busybox/tmp
rm /usr/bin/env && rmdir /usr/bin && rmdir /usr
