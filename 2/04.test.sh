#!/1/out/protobusybox/bin/ash

set -uex

export PATH='/2/01-gnumake/out/bin'
export PATH="$PATH:/2/02-static-binutils/out/bin"
export PATH="$PATH:/2/03-static-gnugcc4/out/bin"
export PATH="$PATH:/1/out/protobusybox/bin"

mkdir -p /2/04.test/tmp; cd /2/04.test/tmp

echo "### $0: preparing..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c

echo "### $0: testing (dynamic)..."
SYSROOT=/2/04-musl/out
gnumake va_test \
	CC=gcc \
	LDFLAGS="-Wl,--dynamic-linker=$SYSROOT/lib/libc.so --sysroot $SYSROOT"
grep /2/04-musl/out/lib/libc.so va_test
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (static)..."
SYSROOT=/2/04-musl/out
gnumake -B va_test CC=gcc LDFLAGS="-static --sysroot $SYSROOT"
( ! grep /2/04-musl/out/lib/libc.so va_test )
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

touch /2/04.test/out  # indicator of successful completion
