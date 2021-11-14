#!/store/1-stage1/protobusybox/bin/ash

set -uex

export PATH='/store/2a0-static-gnumake/bin'
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a2-static-gnugcc4-c/bin"
export PATH="$PATH:/store/1-stage1/protobusybox/bin"

mkdir -p /tmp/_2a3.test; cd /tmp/_2a3.test

echo "### $0: preparing..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c

echo "### $0: testing (dynamic)..."
SYSROOT=/store/2a3-intermediate-musl
make va_test \
	CC=gcc \
	LDFLAGS="-Wl,--dynamic-linker=$SYSROOT/lib/libc.so --sysroot $SYSROOT"
grep /store/2a3-intermediate-musl/lib/libc.so va_test
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (static)..."
make -B va_test CC=gcc LDFLAGS="-static --sysroot $SYSROOT"
( ! grep /store/2a3-intermediate-musl/lib/libc.so va_test )
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

touch /store/_2a3.test  # indicator of successful completion
