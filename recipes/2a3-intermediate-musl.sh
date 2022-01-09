#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd
#>  FROM http://musl.libc.org/releases/musl-1.2.2.tar.gz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a2-static-gnugcc4-c/bin"

mkdir -p /tmp/2a3-intermediate-musl; cd /tmp/2a3-intermediate-musl
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking musl sources..."
tar --strip-components=1 -xf /downloads/musl-1.2.2.tar.gz

echo "### $0: building musl with GNU GCC..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	tools/*.sh \
# patch popen/system to search in PATH instead of hardcoding /bin/sh
sed -i 's|posix_spawn(&pid, "/bin/sh",|posix_spawnp(\&pid, "sh",|' \
	src/stdio/popen.c src/process/system.c
sed -i 's|execl("/bin/sh", "sh", "-c",|execlp("sh", "-c",|'\
	src/misc/wordexp.c
ash ./configure --prefix=/store/2a3-intermediate-musl
make -j $NPROC

echo "### $0: installing musl..."
make -j $NPROC install
