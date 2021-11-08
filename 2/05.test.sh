#!/1/out/protobusybox/bin/ash

set -uex

export PATH='/2/01-gnumake/out/bin'
export PATH="$PATH:/2/02-static-binutils/out/bin"
export PATH="$PATH:/2/05-gnugcc4/out/bin"
export PATH="$PATH:/1/out/protobusybox/bin"

mkdir -p /2/05.test/tmp; cd /2/05.test/tmp

echo "### $0: preparing..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c

echo "### $0: testing (dynamic)..."
gnumake va_test CC=gcc  # neither linker nor sysroot need to be specified now
grep /2/04-musl/out/lib/libc.so va_test
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (static)..."
gnumake -B va_test CC=gcc LDFLAGS=-static  # no specifying sysroot anymore
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
gnumake cpp_test
grep /2/04-musl/out/lib/libc.so cpp_test
( ! grep ld-linux cpp_test )
./cpp_test
[ "$(./cpp_test)" == 'this is c++' ]

touch /2/05.test/out  # indicator of successful completion
