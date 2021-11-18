#!/store/2b4-busybox/bin/ash

set -uex

export PATH='/store/2b4-busybox/bin'
export PATH="$PATH:/store/2b5-gnumake/bin"
export PATH="$PATH:/store/3a-clang/bin/generic-names"

# TODO: get rid of that $ORIGIN in clang's rpath that breaks resolving w/o /proc
export LD_LIBRARY_PATH='/store/2b1-gnugcc10/lib'

mkdir -p /tmp/_3a.test; cd /tmp/_3a.test

echo "### $0: preparing..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c

echo "### $0: testing (dynamic)..."
make va_test
grep /store/2b0-musl/lib/libc.so va_test
( ! grep /store/2a3-intermediate-musl/lib/libc.so va_test )
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (static)..."
make -B va_test LDFLAGS=-static
( ! grep libc.so va_test )
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: testing (dynamic C++)..."
cat > cpp_test.cpp <<\EOF
#include <iostream>
using namespace std;
int main() { cout << "this is c+" << "+" << endl; return 0; }
EOF
# FIXME flags!
make cpp_test CXX=c++ CXXFLAGS='-I/store/3a-clang/include/c++/v1' LDFLAGS='-L/store/3a-clang/lib -rpath /store/3a-clang/lib'
grep /store/2b0-musl/lib/libc.so cpp_test
( ! grep /store/2a3-intermediate-musl/lib/libc.so cpp_test )
( ! grep ld-linux cpp_test )
./cpp_test
[ "$(./cpp_test)" == 'this is c++' ]

touch /store/_3a.test  # indicator of successful completion
