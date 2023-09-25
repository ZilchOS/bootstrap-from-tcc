{ fetchurl, mkDerivationStage2, stage1 }:

let
  source-tarball-gnumake = fetchurl {
    # local = /downloads/make-4.4.1.tar.gz;
    url = "http://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz";
    sha256 = "dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a0-static-gnumake";
    buildInputPaths = [
      "${stage1.tinycc}/wrappers"
      "${stage1.protobusybox}/bin"
    ];
    script = ''
        mkdir build-dir; cd build-dir
      # unpack:
        unpack ${source-tarball-gnumake}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' \
                src/job.c build-aux/install-sh po/Makefile.in.in
        # this is part of stdlib, no idea how it's supposed to not clash
        rm src/getopt.h
        for f in src/getopt.c src/getopt1.c lib/fnmatch.c; do :> $f; done
        for f in lib/glob.c lib/xmalloc.c lib/error.c; do :> $f; done
      # embrace chaos
        shuffle_comment='\/\* Handle shuffle mode argument.  \*\/'
        shuffle_default='if (!shuffle_mode) shuffle_mode = xstrdup(\"random\");'
        sed -i "s|$shuffle_comment|$shuffle_comment\n$shuffle_default|" \
               src/main.c
        grep 'if (!shuffle_mode) shuffle_mode = xstrdup("random");' src/main.c
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
        ./make-intermediate -j $NPROC CFLAGS=-O2
      # install:
        ./make -j $NPROC install
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
      # wrap:
        # FIXME: patch make to use getenv?
        mkdir -p $out/wrappers; cd $out/wrappers
        echo "#!${stage1.protobusybox}/bin/ash" > make
        echo "exec $out/bin/make SHELL=\$SHELL \"\$@\"" \ >> make
        chmod +x make
    '';
  }
