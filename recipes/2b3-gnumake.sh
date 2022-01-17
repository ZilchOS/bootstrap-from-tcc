#!/store/2b2-busybox/bin/ash

#> FETCH e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19
#>  FROM http://ftp.gnu.org/gnu/make/make-4.3.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2b1-clang/bin"

mkdir -p /tmp/2b3-gnumake; cd /tmp/2b3-gnumake
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking GNU Make sources..."
tar --strip-components=1 -xf /downloads/make-4.3.tar.gz

echo "### $0: building GNU Make..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' build-aux/install-sh
ash ./configure \
	CONFIG_SHELL=ash SHELL=ash MAKEINFO=true \
	--build x86_64-linux \
	--prefix=/store/2b3-gnumake \
	--disable-dependency-tracking
make -j $NPROC CFLAGS=-O2

echo "### $0: installing GNU Make with itself to test it..."
./make -j $NPROC SHELL=ash install-strip

echo "### $0: creating a wrapper that respects \$SHELL..."
# FIXME: patch make to use getenv?
mkdir /store/2b3-gnumake/wrappers; cd /store/2b3-gnumake/wrappers
echo "#!/store/2b2-busybox/bin/ash" > make
echo "exec /store/2b3-gnumake/bin/make SHELL=\$SHELL \"\$@\"" \ >> make
chmod +x make
