#!/1/out/protobusybox/bin/ash
set -uex

# just a stub for now

export PATH=/2/out/busybox/bin:/2/out/gnugcc4/bin:/2/out/binutils/bin:/2/out/gnumake/bin

echo 'Hello from stage 3!'
mkdir -p /dev; :>/dev/null
mkdir -p /tmp; :>/dev/null
mkdir -p /3/tmp /3/out

# FIXME: move the below stage2-belonging experiments to stage2

echo 'Building GNU GCC 4 (C++ as well)'
rm -rf /3/tmp/gnugcc4
cp -ra /2/src/gnugcc4 /3/tmp/
cd /3/tmp/gnugcc4
sed -i 's|/bin/sh|/2/out/protobusybox/bin/ash|' \
	missing move-if-change mkdep mkinstalldirs symlink-tree \
	gcc/genmultilib */*.sh gcc/exec-tool.in \
	install-sh */install-sh
sed -i 's|^\(\s*\)sh |\1/2/out/protobusybox/bin/ash |' Makefile* */Makefile*
sed -i 's|/lib64/ld-linux-x86-64.so.2|/3/out/musl/lib/libc.so|' \
	gcc/config/i386/linux64.h
rm -rf /3/out/gnugcc4/sys-root; mkdir -p /3/out/gnugcc4/sys-root
ln -s /3/out/protomusl/lib /3/out/gnugcc4/sys-root/
ln -s /3/out/protomusl/include /3/out/gnugcc4/sys-root/
:> /dev/null
ash configure \
	CONFIG_SHELL='/2/out/protobusybox/bin/ash' \
	SHELL='/2/out/protobusybox/bin/ash' \
	--with-build-time-tools=/2/out/binutils/bin \
	--prefix=/3/out/gnugcc4 \
	--disable-bootstrap \
	--disable-decimal-float \
	--enable-languages=c \
	--disable-multilib \
	--disable-multiarch \
	--disable-libmudflap --disable-libsanitizer \
	--disable-libssp --disable-libmpx \
	--disable-libquadmath \
	--disable-libgomp \
	--with-sysroot=/3/out/gnugcc4/sys-root \
	--with-native-system-header-dir=/include \
	--host x86_64-linux --build x86_64-linux
/2/out/gnumake/bin/gnumake
/2/out/gnumake/bin/gnumake install

#/2/out/gnugcc4/bin/gcc /1/src/hello.c -o /2/tmp/hello
#/2/tmp/hello || hello_retcode=$?
#[ $hello_retcode == 42 ]

rm -rf /3/tmp /dev /tmp

exit 0
