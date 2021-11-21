#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd
#>  FROM http://musl.libc.org/releases/musl-1.2.2.tar.gz

set -uex

export PATH='/store/1-stage1/protobusybox/bin'
export PATH="$PATH:/store/2a0-static-gnumake/bin"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a9-intermediate-clang/bin/generic-names"

mkdir -p /tmp/2b0-musl; cd /tmp/2b0-musl
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking musl sources..."
tar --strip-components=1 -xf /downloads/musl-1.2.2.tar.gz

echo "### $0: building musl..."
sed -i 's|/bin/sh|/store/1-stage1/protobusybox/bin/ash|' \
	tools/*.sh \
# Hardcode /usr/bin/env sh instead of /bin/sh for popen and system calls.
# At least one hardcode less and env is dumber than sh =(
# TODO: build and bundle an env with musl at this step?
# TODO: or make it search $PATH already?
sed -i 's|/bin/sh|/usr/bin/env|' src/stdio/popen.c src/process/system.c
sed -i 's|"sh", "-c"|"/usr/bin/env", "sh", "-c"|' \
	src/stdio/popen.c src/process/system.c
ash ./configure --prefix=/store/2b0-musl CFLAGS='-O2'
make -j $NPROC

echo "### $0: installing musl..."
make -j $NPROC install
mkdir /store/2b0-musl/bin
ln -s /store/2b0-musl/lib/libc.so /store/2b0-musl/bin/ldd
