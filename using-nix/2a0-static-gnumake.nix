{ fetchurl, mkDerivationStage2, stage1 }:

let
  source-tarball-gnumake = fetchurl {
    # local = /downloads/make-4.3.tar.gz;
    url = "http://ftp.gnu.org/gnu/make/make-4.3.tar.gz";
    sha256 = "e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a0-static-gnumake";
    buildInputPaths = [
      "${stage1.tinycc}/wrappers"
      "${stage1.protobusybox}/bin"
    ];
    script = ''
      # unpack:
        unpack ${source-tarball-gnumake}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' \
                src/job.c build-aux/install-sh po/Makefile.in.in
        # this is part of stdlib, no idea how it's supposed to not clash
        rm src/getopt.h
        for f in src/getopt.c src/getopt1.c lib/fnmatch.c; do :> $f; done
        for f in lib/glob.c lib/xmalloc.c lib/error.c; do :> $f; done
      # configure:
        ash ./configure \
                --build x86_64-linux \
                --disable-dependency-tracking \
                --prefix=$out \
                CONFIG_SHELL='${stage1.protobusybox}/bin/ash' \
                SHELL='${stage1.protobusybox}/bin/ash'
      # bootstrap build:
        ash ./build.sh
      # test static GNU Make by remaking it with itself:
        mv make make-intermediate
        ./make-intermediate -j $NPROC clean
        ./make-intermediate -j $NPROC
      # reconfigure:
        ash ./configure \
                --build x86_64-linux \
                --disable-dependency-tracking \
                --prefix=$out \
                CONFIG_SHELL='${stage1.protobusybox}/bin/ash' \
                SHELL='${stage1.protobusybox}/bin/ash'
      # rebuild:
        ash ./build.sh
      # test:
        mv make make-intermediate
        ./make-intermediate -j $NPROC clean
        ./make-intermediate -j $NPROC
      # install:
        ./make -j $NPROC install
      # wrap:
        # FIXME: patch make to use getenv?
        mkdir -p $out/wrappers; cd $out/wrappers
        echo "#!${stage1.protobusybox}/bin/ash" > make
        echo "exec $out/bin/make SHELL=\$SHELL \"\$@\"" \ >> make
        chmod +x make
    '';
  }
