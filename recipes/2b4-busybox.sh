#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549
#>  FROM https://busybox.net/downloads/busybox-1.34.1.tar.bz2

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2b1-gnugcc10/bin"
export PATH="$PATH:/store/2b2-binutils/bin"

mkdir -p /tmp/2b4-busybox; cd /tmp/2b4-busybox
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking busybox sources..."
tar --strip-components=1 -xf /downloads/busybox-1.34.1.tar.bz2

# TODO: better, outer-level solution for /usr/bin/env and popen specifically
# just patch musl to search in $PATH?
echo "### $0: providing /usr/bin/env and sh in PATH for popen..."
mkdir /usr; mkdir /usr/bin
ln -s /store/1-stage1/protobusybox/bin/env /usr/bin/env
mkdir aliases; ln -s /store/1-stage1/protobusybox/bin/ash aliases/sh
export PATH="/tmp/2b4-busybox/aliases:$PATH"

echo "### $0: configuring busybox..."
BUSYBOX_FLAGS='CONFIG_SHELL=/store/1-stage1/protobusybox/bin/ash'
BUSYBOX_FLAGS="$BUSYBOX_FLAGS CC=gcc HOSTCC=gcc"
BUSYBOX_FLAGS="$BUSYBOX_FLAGS CFLAGS=-I/store/2b3-linux-headers/include"
BUSYBOX_FLAGS="$BUSYBOX_FLAGS KCONFIG_NOTIMESTAMP=y"
echo -e '#!/store/1-stage1/protobusybox/bin/ash\nprintf 9999' \
	> scripts/gcc-version.sh
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|g' \
	scripts/gen_build_files.sh \
	scripts/mkconfigs scripts/embedded_scripts scripts/trylink \
	scripts/generate_BUFSIZ.sh \
	applets/usage_compressed applets/busybox.mkscripts applets/install.sh
make -j $NPROC $BUSYBOX_FLAGS defconfig
sed -i 's|CONFIG_INSTALL_NO_USR=y|CONFIG_INSTALL_NO_USR=n|' .config

echo "### $0: building busybox..."
make -j $NPROC $BUSYBOX_FLAGS busybox busybox.links
sed -i 's|^/usr/s\?bin/|/bin/|' busybox.links

echo "### $0: installing busybox..."
make -j $NPROC $BUSYBOX_FLAGS install CONFIG_PREFIX=/store/2b4-busybox

rm /usr/bin/env && rmdir /usr/bin && rmdir /usr
