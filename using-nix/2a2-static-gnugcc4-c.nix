{ fetchurl, mkDerivationStage2, stage1, static-gnumake, static-binutils }:

let
  source-tarball-gcc = fetchurl {
    # local = /downloads/gcc-4.7.4.tar.bz2;
    url = "https://ftp.gnu.org/gnu/gcc/gcc-4.7.4/gcc-4.7.4.tar.bz2";
    sha256 = "92e61c6dc3a0a449e62d72a38185fda550168a86702dea07125ebd3ec3996282";
  };
  source-tarball-gmp = fetchurl {
    # local = /downloads/gmp-4.3.2.tar.xz;
    url = "https://gmplib.org/download/gmp/archive/gmp-4.3.2.tar.xz";
    sha256 = "f69eff1bc3d15d4e59011d587c57462a8d3d32cf2378d32d30d008a42a863325";
  };
  source-tarball-mpfr = fetchurl {
    # local = /downloads/mpfr-2.4.2.tar.xz;
    url = "https://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.xz";
    sha256 = "d7271bbfbc9ddf387d3919df8318cd7192c67b232919bfa1cb3202d07843da1b";
  };
  source-tarball-mpc = fetchurl {
    # local = /downloads/mpc-0.8.1.tar.gz;
    url = "http://www.multiprecision.org/downloads/mpc-0.8.1.tar.gz";
    sha256 = "e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a2-static-gnugcc4-c";
    buildInputPaths = [
      "${stage1.tinycc}/wrappers"
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/bin"
    ];
    script = ''
        mkdir build-dir; cd build-dir
      # alias ash to sh:
        mkdir aliases; ln -s ${stage1.protobusybox}/bin/ash aliases/sh
        export PATH="$(pwd)/aliases:$PATH"
      # unpack:
        unpack ${source-tarball-gcc}
        mkdir mpfr mpc gmp
        unpack ${source-tarball-mpfr} -C mpfr
        unpack ${source-tarball-mpc} -C mpc
        unpack ${source-tarball-gmp} -C gmp
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' \
          missing move-if-change mkdep mkinstalldirs symlink-tree \
          gcc/genmultilib */*.sh gcc/exec-tool.in \
          install-sh */install-sh
        sed -i 's|^\(\s*\)sh |\1${stage1.protobusybox}/bin/ash |' \
          Makefile* */Makefile*
        sed -i 's|LIBGCC2_DEBUG_CFLAGS = -g|LIBGCC2_DEBUG_CFLAGS = |' \
          libgcc/Makefile.in
        # see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
        sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh */ltmain.sh
        sed -i 's|#define HAVE_HOST_CORE2 1||' mpfr/configure
      # configure:
        export ac_cv_func_strncmp_works=no
        export ac_cv_func_alloca_works=no
        export ac_cv_prog_make_make_set=no
        ash configure \
          CONFIG_SHELL='${stage1.protobusybox}/bin/ash' \
          SHELL='${stage1.protobusybox}/bin/ash' \
          CFLAGS=-O2 CFLAGS_FOR_TARGET=-O2 \
          --with-sysroot=${stage1.protomusl} \
          --with-native-system-header-dir=/include \
          --with-build-time-tools=${static-binutils}/bin \
          --prefix=$out \
          --enable-languages=c \
          --disable-bootstrap \
          --disable-libquadmath --disable-decimal-float --disable-fixed-point \
          --disable-lto \
          --disable-libgomp \
          --disable-multilib \
          --disable-multiarch \
          --disable-libmudflap \
          --disable-libssp \
          --disable-nls \
          --host x86_64-linux --build x86_64-linux
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
    '';
  }
