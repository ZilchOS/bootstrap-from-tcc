{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, musl, clang, linux-headers }:

let
  source-tarball-busybox = fetchurl {
    # local = /downloads/busybox-1.34.1.tar.bz2;
    url = "https://busybox.net/downloads/busybox-1.34.1.tar.bz2";
    sha256 = "415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2b2-busybox";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/bin"
      "${clang}/bin"
    ];
    script = ''
      # alias ash to sh:
        mkdir aliases; ln -s ${stage1.protobusybox}/bin/ash aliases/sh
        export PATH="$(pwd)/aliases:$PATH"
      # unpack:
        unpack ${source-tarball-busybox}
      # fixup:
        echo -e '#!${stage1.protobusybox}/bin/ash\nprintf 9999' \
          > scripts/gcc-version.sh
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|g' \
          scripts/gen_build_files.sh \
          scripts/mkconfigs scripts/embedded_scripts scripts/trylink \
          scripts/generate_BUFSIZ.sh \
          applets/usage_compressed applets/busybox.mkscripts applets/install.sh
      # configure:
        echo "### $0: configuring busybox..."
        BUSYBOX_FLAGS='CONFIG_SHELL=${stage1.protobusybox}/bin/ash'
        BUSYBOX_FLAGS="$BUSYBOX_FLAGS CC=cc HOSTCC=cc"
        BUSYBOX_FLAGS="$BUSYBOX_FLAGS CFLAGS=-I${linux-headers}/include"
        BUSYBOX_FLAGS="$BUSYBOX_FLAGS KCONFIG_NOTIMESTAMP=y"
        make -j $NPROC $BUSYBOX_FLAGS defconfig
        sed -i 's|CONFIG_INSTALL_NO_USR=y|CONFIG_INSTALL_NO_USR=n|' .config
      # build:
        make -j $NPROC $BUSYBOX_FLAGS busybox busybox.links CFLAGS=-O2
        sed -i 's|^/usr/s\?bin/|/bin/|' busybox.links
      # install:
        make -j $NPROC $BUSYBOX_FLAGS install CONFIG_PREFIX=$out
    '';
    extra.allowedRequisites = [ "out" musl clang ];
    extra.allowedReferences = [ "out" musl clang ];
  }
