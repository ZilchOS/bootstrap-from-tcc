#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549
#>  FROM https://busybox.net/downloads/busybox-1.34.1.tar.bz2

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2b1-clang/bin"

mkdir -p /tmp/2b2-busybox; cd /tmp/2b2-busybox
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: aliasing ash to sh..."
mkdir aliases; ln -s /store/1-stage1/protobusybox/bin/ash aliases/sh
export PATH="/tmp/2b2-busybox/aliases:$PATH"

echo "### $0: unpacking busybox sources..."
tar --strip-components=1 -xf /downloads/busybox-1.34.1.tar.bz2

echo "### $0: configuring busybox..."
BUSYBOX_FLAGS='CONFIG_SHELL=/store/1-stage1/protobusybox/bin/ash'
BUSYBOX_FLAGS="$BUSYBOX_FLAGS CC=cc HOSTCC=cc"
BUSYBOX_FLAGS="$BUSYBOX_FLAGS CFLAGS=-I/store/2a6-linux-headers/include"
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
make -j $NPROC $BUSYBOX_FLAGS busybox busybox.links CFLAGS=-O2
sed -i 's|^/usr/s\?bin/|/bin/|' busybox.links

echo "### $0: installing busybox..."
make -j $NPROC $BUSYBOX_FLAGS install CONFIG_PREFIX=/store/2b2-busybox
