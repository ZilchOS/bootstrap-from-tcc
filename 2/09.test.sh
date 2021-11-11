#!/2/08-busybox/out/bin/ash

set -uex

export PATH='/2/05-gnugcc4/out/bin:/2/06-binutils/out/bin'
export PATH="$PATH:/2/08-busybox/out/bin"
export PATH="$PATH:/2/09-gnumake/out/bin"

mkdir -p /2/09.test/tmp; cd /2/09.test/tmp
echo -e '#include <stdio.h>\nint main() { printf("hi"); return 0; }' > hi.c
cat hi.c
make hi CC=gcc
( grep /2/04-musl/out/lib/libc.so hi )
( ! grep ld-linux hi )
./hi
[ "$(./hi)" == hi ]

touch /2/09.test/out  # indicator of successful completion
