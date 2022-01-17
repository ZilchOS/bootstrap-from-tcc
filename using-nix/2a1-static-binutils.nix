{ fetchurl, mkDerivationStage2, stage1, static-gnumake }:

let
  source-tarball-binutils = fetchurl {
    # local = /downloads/binutils-2.37.tar.xz;
    url = "https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.xz";
    sha256 = "820d9724f020a3e69cb337893a0b63c2db161dadcb0e06fc11dc29eb1e84a32c";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a1-static-binutils";
    buildInputPaths = [
      "${stage1.tinycc}/wrappers"
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/bin"
    ];
    script = ''
      # unpack:
        unpack ${source-tarball-binutils}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' \
                missing install-sh mkinstalldirs
        # see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
        sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh
      # configure:
        export lt_cv_sys_max_cmd_len=32768
        ash ./configure \
                CONFIG_SHELL='${stage1.protobusybox}/bin/ash' \
                SHELL='${stage1.protobusybox}/bin/ash' \
                CFLAGS='-D__LITTLE_ENDIAN__=1' \
                --enable-deterministic-archives \
                --host x86_64-linux --build x86_64-linux \
                --prefix=$out
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
    '';
  }
