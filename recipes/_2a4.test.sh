#!/store/1-stage1/protobusybox/bin/ash

set -uex

export PATH='/store/2a0-static-gnumake/bin'
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a4-gnugcc4-cpp/bin"
export PATH="$PATH:/store/1-stage1/protobusybox/bin"

mkdir -p /tmp/_2a4.test; cd /tmp/_2a4.test

echo "### $0: preparing..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c

echo "### $0: testing (dynamic)..."
make va_test CC=gcc  # neither linker nor sysroot need to be specified now
grep /store/2a3-intermediate-musl/lib/libc.so va_test
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (static)..."
make -B va_test CC=gcc LDFLAGS=-static  # no specifying sysroot anymore
( ! grep /store/2a3-intermediate-musl/lib/libc.so va_test )
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
grep /store/2a3-intermediate-musl/lib/libc.so cpp_test
( ! grep ld-linux cpp_test )
./cpp_test
[ "$(./cpp_test)" == 'this is c++' ]

touch /store/_2a4.test  # indicator of successful completion
