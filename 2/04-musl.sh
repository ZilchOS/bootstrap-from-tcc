#!/1/out/protobusybox/bin/ash

#> FETCH 9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd
#>  FROM http://musl.libc.org/releases/musl-1.2.2.tar.gz

set -uex

export PATH='/2/01-gnumake/out/bin'
export PATH="$PATH:/2/02-static-binutils/out/bin"
export PATH="$PATH:/2/03-static-gnugcc4/out/bin"
export PATH="$PATH:/1/out/protobusybox/bin"

mkdir -p /2/04-musl/tmp; cd /2/04-musl/tmp

echo "### $0: unpacking musl sources..."
gzip -d < /downloads/musl-1.2.2.tar.gz | tar -x --strip-components=1

echo "### $0: building musl with GNU GCC..."
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' \
	tools/*.sh \
# Hardcode /usr/bin/env sh instead of /bin/sh for popen and system calls.
# At least one hardcode less and env is dumber than sh =(
# TODO: build and bundle an env with musl at this step?
sed -i 's|/dev/null|/2/04-musl/tmp/null|g' \
	configure
sed -i 's|/bin/sh|/usr/bin/env|' src/stdio/popen.c src/process/system.c
sed -i 's|"sh", "-c"|"/usr/bin/env", "sh", "-c"|' \
	src/stdio/popen.c src/process/system.c
mkdir -p /2/04-musl/out/bin
ash ./configure --target x86_64-linux --prefix=/2/04-musl/out

echo "### $0: installing musl..."
gnumake
gnumake install
#ln -sfn /2/04-musl/out/lib /2/out/gnugcc4/sys-root/lib
#ln -sfn /2/04-musl/out/include /2/out/gnugcc4/sys-root/include

#rm -rf /2/04-musl/tmp
