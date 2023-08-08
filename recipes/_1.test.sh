#!/store/1-stage1/protobusybox/bin/ash

set -uex

export PATH=/store/1-stage1/tinycc/wrappers:/store/1-stage1/protobusybox/bin

mkdir -p /tmp/_1.test; cd /tmp/_1.test


echo "### $0: checking that /protosrc has not leaked into outputs..."
! grep -R /protosrc /store/1-stage1

echo "### $0: checking compilation..."
cat > va_test.c <<\EOF
#include <stdio.h>
int main(int _, char* argv[]) { printf("%sargs\n", argv[1]); return 0; }
EOF

cat va_test.c
cc -o va_test va_test.c
( ! grep /store/2a3-intermediate-musl/lib/libc.so va_test )
( ! grep ld-linux va_test )
./va_test var
[ "$(./va_test var)" == varargs ]

touch /store/_1.test  # indicator of successful completion
