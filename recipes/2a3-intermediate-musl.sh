#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039
#>  FROM http://musl.libc.org/releases/musl-1.2.4.tar.gz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a2-static-gnugcc4-c/bin"

mkdir -p /tmp/2a3-intermediate-musl; cd /tmp/2a3-intermediate-musl
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: unpacking musl sources..."
tar --strip-components=1 -xf /downloads/musl-1.2.4.tar.gz

echo "### $0: building musl with GNU GCC..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	tools/*.sh \
# patch popen/system to search in PATH instead of hardcoding /bin/sh
sed -i 's|posix_spawn(&pid, "/bin/sh",|posix_spawnp(\&pid, "sh",|' \
	src/stdio/popen.c src/process/system.c
sed -i 's|execl("/bin/sh", "sh", "-c",|execlp("sh", "-c",|'\
	src/misc/wordexp.c
# eliminiate a source path reference
sed -i 's/__FILE__/"__FILE__"/' include/assert.h
ash ./configure --prefix=/store/2a3-intermediate-musl
make -j $NPROC

echo "### $0: installing musl..."
make -j $NPROC install

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a3 /store/2a3-intermediate-musl )
