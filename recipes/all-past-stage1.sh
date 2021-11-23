#!/store/1-stage1/protobusybox/bin/ash

set -uex

export SOURCE_DATE_EPOCH=0

/recipes/2a0-static-gnumake.sh
/recipes/2a1-static-binutils.sh
/recipes/2a2-static-gnugcc4-c.sh
/recipes/2a3-intermediate-musl.sh
/recipes/2a4-gnugcc4-cpp.sh
/recipes/2a5-gnugcc10.sh
/recipes/2a6-linux-headers.sh
/recipes/2a7-cmake.sh
/recipes/2a8-python.sh
/recipes/2a9-intermediate-clang.sh
/recipes/2b0-musl.sh
/recipes/2b1-clang.sh
/recipes/2b2-busybox.sh
/recipes/2b3-gnumake.sh
/recipes/3a-patchelf.sh
/recipes/3a-gnubash.sh
/recipes/3a-sqlite.sh
/recipes/3a-boost.sh
/recipes/3a-perl.sh
/recipes/3a-openssl.sh
/recipes/3a-pkg-config.sh
/recipes/3a-bzip2.sh
/recipes/3a-curl.sh
/recipes/3a-editline.sh
/recipes/3a-xz.sh
/recipes/3a-brotli.sh
/recipes/3a-gnugperf.sh
/recipes/3a-seccomp.sh
/recipes/3b-nix.sh
