#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039
#>  FROM http://musl.libc.org/releases/musl-1.2.4.tar.gz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a9-intermediate-clang/bin/generic-names"

mkdir -p /tmp/2b0-musl; cd /tmp/2b0-musl
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking musl sources..."
tar --strip-components=1 -xf /downloads/musl-1.2.4.tar.gz

echo "### $0: building musl..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	tools/*.sh \
# patch popen/system to search in PATH instead of hardcoding /bin/sh
sed -i 's|posix_spawn(&pid, "/bin/sh",|posix_spawnp(\&pid, "sh",|' \
	src/stdio/popen.c src/process/system.c
# avoid absolute path references
sed -i 's/__FILE__/__FILE_NAME__/' include/assert.h
ash ./configure --prefix=/store/2b0-musl CFLAGS=-O2
make -j $NPROC

echo "### $0: installing musl..."
make -j $NPROC install
mkdir /store/2b0-musl/bin
ln -s /store/2b0-musl/lib/libc.so /store/2b0-musl/bin/ldd

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2b0 /store/2b0-musl )
