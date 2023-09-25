#!/store/1-stage1/protobusybox/bin/ash

#> FETCH dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3
#>  FROM http://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz

set -uex

export PATH=/store/1-stage1/tinycc/wrappers:/store/1-stage1/protobusybox/bin

mkdir -p /store/2a0-static-gnumake /tmp/2a0-static-gnumake
cd /tmp/2a0-static-gnumake

echo "### $0: unpacking static GNU Make sources..."
tar --strip-components=1 -xf /downloads/make-4.4.1.tar.gz

echo "### $0: fixing up static GNU Make sources..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	src/job.c build-aux/install-sh po/Makefile.in.in
# this is part of stdlib, no idea how it's supposed to not clash
rm src/getopt.h
for f in src/getopt.c src/getopt1.c; do :> $f; done
for f in lib/fnmatch.c lib/glob.c lib/xmalloc.c lib/error.c; do :> $f; done
# embrace chaos
shuffle_comment='\/\* Handle shuffle mode argument.  \*\/'
shuffle_default='if (!shuffle_mode) shuffle_mode = xstrdup(\"random\");'
sed -i "s|$shuffle_comment|$shuffle_comment\n$shuffle_default|" src/main.c
grep 'if (!shuffle_mode) shuffle_mode = xstrdup("random");' src/main.c

echo "### $0: building static GNU Make..."
ash ./configure \
	--build x86_64-linux \
	--disable-dependency-tracking \
	--prefix=/store/2a0-static-gnumake \
	CONFIG_SHELL='/store/1-stage1/protobusybox/bin/ash' \
	SHELL='/store/1-stage1/protobusybox/bin/ash'
ash ./build.sh

echo "### $0: testing static GNU Make by remaking it with itself..."
mv make make-intermediate
./make-intermediate -j $NPROC clean
./make-intermediate -j $NPROC CFLAGS=-O2

echo "### $0: installing static GNU Make..."
./make -j $NPROC install

echo "### $0: creating a wrapper that respects \$SHELL..."
# FIXME: patch make to use getenv?
mkdir /store/2a0-static-gnumake/wrappers; cd /store/2a0-static-gnumake/wrappers
echo "#!/store/1-stage1/protobusybox/bin/ash" > make
echo "exec /store/2a0-static-gnumake/bin/make SHELL=\$SHELL \"\$@\"" \ >> make
chmod +x make

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a0 /store/2a0-static-gnumake )
