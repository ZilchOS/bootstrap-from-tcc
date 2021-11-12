#!/1/out/protobusybox/bin/ash

set -uex

export PATH="/2/08-busybox/out/bin"
export PATH="$PATH:/2/06-binutils/out/bin"
export PATH="$PATH:/2/09-gnumake/out/bin"
export PATH="$PATH:/2/90-gnugcc10/out/bin"

mkdir -p /2/90.test/tmp; cd /2/90.test/tmp

echo "### $0: preparing..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c

echo "### $0: testing (dynamic)..."
make va_test CC=gcc
grep /2/04-musl/out/lib/libc.so va_test
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (static)..."
make -B va_test CC=gcc LDFLAGS=-static
( ! grep /2/04-musl/out/lib/libc.so va_test )
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (dynamic C++)..."
cat > cpp_test.cpp <<\EOF
#include <iostream>
using namespace std;
int main() { cout << "this is c+" << "+" << endl; return 0; }
EOF
make cpp_test
grep /2/04-musl/out/lib/libc.so cpp_test
( ! grep ld-linux cpp_test )
./cpp_test
[ "$(./cpp_test)" == 'this is c++' ]

touch /2/90.test/out  # indicator of successful completion
