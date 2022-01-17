{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, static-binutils, intermediate-musl, gnugcc4-cpp }:

let
  source-tarball-gcc = fetchurl {
    # local = /downloads/gcc-10.3.0.tar.xz;
    url = "https://ftp.gnu.org/gnu/gcc/gcc-10.3.0/gcc-10.3.0.tar.xz";
    sha256 = "64f404c1a650f27fc33da242e1f2df54952e3963a49e06e73f6940f3223ac344";
  };
  source-tarball-gmp = fetchurl {
    # local = /downloads/gmp-6.1.0.tar.xz;
    url = "https://gmplib.org/download/gmp/gmp-6.1.0.tar.xz";
    sha256 = "68dadacce515b0f8a54f510edf07c1b636492bcdb8e8d54c56eb216225d16989";
  };
  source-tarball-mpfr = fetchurl {
    # local = /downloads/mpfr-3.1.4.tar.xz;
    url = "https://www.mpfr.org/mpfr-3.1.4/mpfr-3.1.4.tar.xz";
    sha256 = "761413b16d749c53e2bfd2b1dfaa3b027b0e793e404b90b5fbaeef60af6517f5";
  };
  source-tarball-mpc = fetchurl {
    # local = /downloads/mpc-1.0.3.tar.gz;
    url = "http://www.multiprecision.org/downloads/mpc-1.0.3.tar.gz";
    sha256 = "617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3";
  };
  source-tarball-isl = fetchurl {
    # local = /downloads/isl-0.18.tar.bz2;
    url = "http://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2";
    sha256 = "6b8b0fd7f81d0a957beb3679c81bbb34ccc7568d5682844d8924424a0dadcb1b";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a5-gnugcc10";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/bin"
      "${static-binutils}/bin"
      "${gnugcc4-cpp}/bin"
    ];
    script = ''
      # alias ash to sh:
        mkdir aliases; ln -s ${stage1.protobusybox}/bin/ash aliases/sh
        export PATH="$(pwd)/aliases:$PATH"
      # unpack:
        unpack ${source-tarball-gcc}
        mkdir mpfr mpc gmp isl
        unpack ${source-tarball-mpfr} -C mpfr
        unpack ${source-tarball-mpc} -C mpc
        unpack ${source-tarball-gmp} -C gmp
        unpack ${source-tarball-isl} -C isl
      # fixup:
        SYSROOT=${intermediate-musl}
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' \
          missing move-if-change mkdep mkinstalldirs symlink-tree install-sh \
          gcc/exec-tool.in libgcc/mkheader.sh
        sed -i 's|^\(\s*\)sh |\1${stage1.protobusybox}/bin/ash |' \
          libgcc/Makefile.in
        sed -i "s|/lib/ld-musl-x86_64.so.1|$SYSROOT/lib/libc.so|" \
          gcc/config/i386/linux64.h
        sed -i 's|m64=../lib64|m64=../lib|' gcc/config/i386/t-linux64
        sed -i 's|"os/gnu-linux"|"os/generic"|' libstdc++-v3/configure.host
        # see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
        sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh */ltmain.sh
      # configure:
        ash configure \
          CONFIG_SHELL='${stage1.protobusybox}/bin/ash' \
          SHELL='${stage1.protobusybox}/bin/ash' \
          --with-sysroot=$SYSROOT \
          --with-native-system-header-dir=/include \
          --with-build-time-tools=${static-binutils}/bin \
          --prefix=$out \
          --with-specs='%{!static:%x{-rpath=$out/lib}}' \
          --enable-languages=c,c++ \
          --disable-bootstrap \
          --disable-libquadmath --disable-decimal-float --disable-fixed-point \
          --disable-lto \
          --disable-libgomp \
          --disable-multilib \
          --disable-multiarch \
          --disable-libmudflap \
          --disable-libssp \
          --disable-nls \
          --disable-libitm \
          --disable-libsanitizer \
          --disable-cet \
          --disable-gnu-unique-object \
          --disable-gcov \
          --disable-checking \
          --host x86_64-linux-musl --build x86_64-linux-musl
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
    '';
  }
