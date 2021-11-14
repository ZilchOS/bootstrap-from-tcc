#!/store/1-stage1/protobusybox/bin/ash

set -uex

/recipes/2a0-static-gnumake.sh
/recipes/2a1-static-binutils.sh
/recipes/2a2-static-gnugcc4-c.sh
/recipes/2a3-intermediate-musl.sh
/recipes/2a4-gnugcc4-cpp.sh
/recipes/2a5-gnugcc10.sh
/recipes/2b0-musl.sh
/recipes/2b1-gnugcc10.sh
/recipes/2b2-binutils.sh
/recipes/2b3-linux-headers.sh
/recipes/2b4-busybox.sh
/recipes/2b5-gnumake.sh
