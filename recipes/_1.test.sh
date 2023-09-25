#!/store/1-stage1/protobusybox/bin/ash

set -uex

export PATH=/store/1-stage1/tinycc/wrappers:/store/1-stage1/protobusybox/bin

mkdir -p /tmp/_1.test; cd /tmp/_1.test


echo "### $0: checking that /protosrc has not leaked into outputs..."
! grep -rF /protosrc /store/1-stage1

echo "### $0: checking compilation..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c
cc -o va_test.o va_test.c
cc -o va_test va_test.c
( ! grep /store/2a3-intermediate-musl/lib/libc.so va_test.o va_test )
( ! grep ld-linux va_test.o va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

echo "### $0: checking that we've got bzip2..."

hello=$(echo hello | bzip2 -1 | bzip2 -d)
[ "$hello" == hello ]

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/_1.test . )
( ! grep -rF /tmp/1-stage1 . )
( ! grep -rF /store/1-stage1 . )
( ! grep -rF va_test . )
( ! grep -rF /tmp/1-stage1 /store/1-stage1 )
( ! grep -rF /tmp/_1.test /store/1-stage1 )

touch /store/_1.test  # indicator of successful completion
