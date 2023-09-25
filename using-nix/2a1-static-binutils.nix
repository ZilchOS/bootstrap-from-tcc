{ fetchurl, mkDerivationStage2, stage1, static-gnumake }:

let
  source-tarball-binutils = fetchurl {
    # local = /downloads/binutils-2.39.tar.xz;
    url = "https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz";
    sha256 = "645c25f563b8adc0a81dbd6a41cffbf4d37083a382e02d5d3df4f65c09516d00";
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
        mkdir build-dir; cd build-dir
      # unpack:
        unpack ${source-tarball-binutils}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' \
                missing install-sh mkinstalldirs
        # see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
        sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh
        sed -i 's|__FILE__|"__FILE__"|' \
          ld/*.c ld/*.h bfd/*.* libctf/*.* opcodes/*.*
        sed -i 's| -g | |' ld/Makefile*
      # alias makeinfo to true
        mkdir aliases
        ln -s ${stage1.protobusybox}/bin/true aliases/makeinfo
        PATH="$(pwd)/aliases/:$PATH"
      # configure:
        export lt_cv_sys_max_cmd_len=32768
        export ac_cv_func_strncmp_works=no
        ash ./configure \
                CONFIG_SHELL='${stage1.protobusybox}/bin/ash' \
                SHELL='${stage1.protobusybox}/bin/ash' \
                CFLAGS='-O2 -D__LITTLE_ENDIAN__=1' \
                CFLAGS_FOR_TARGET=-O2 \
                --enable-deterministic-archives \
                --disable-gprofng \
                --host x86_64-linux --build x86_64-linux \
                --prefix=$out
      # build:
        make -j $NPROC \
                all-libiberty all-gas all-bfd all-libctf all-zlib all-gprof
        make all-ld  # race condition on ld/.deps/ldwrite.Po, serialize
        make -j $NPROC
      # install:
        make -j $NPROC install
        rm $out/lib/*.la  # broken, reference builddir
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
    '';
  }
