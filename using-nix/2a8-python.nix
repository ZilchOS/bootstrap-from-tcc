{ mkDerivationStage2, stage1, static-gnumake, static-binutils, gnugcc10 }:

let
  source-tarball-python = builtins.fetchurl {
    # local = /downloads/Python-3.10.0.tar.xz;
    url = "https://www.python.org/ftp/python/3.10.0/Python-3.10.0.tar.xz";
    sha256 = "5a99f8e7a6a11a7b98b4e75e0d1303d3832cada5534068f69c7b6222a7b1b002";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a7-cmake";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/wrappers"
      "${static-binutils}/bin"
      "${gnugcc10}/bin"
    ];
    script = ''
        export SHELL=${stage1.protobusybox}/bin/ash
      # alias ash to sh:
        mkdir aliases; ln -s ${stage1.protobusybox}/bin/ash aliases/sh
        export PATH="$(pwd)/aliases:$PATH"
      # unpack:
        unpack ${source-tarball-python}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' configure
        # the precompiled pyc files aren't reproducible,
        # but it's not like I need to waste time on them anyway.
        # break their generation
        mv Lib/compileall.py Lib/compileall.py.bak
        echo 'import sys; sys.exit(0)' > Lib/compileall.py
        chmod +x Lib/compileall.py
      # configure:
        ash configure \
          --without-static-libpython \
          --build x86_64-linux-musl \
          --prefix=$out \
          --enable-shared \
          --with-ensurepip=no
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
        # restore compileall just in case
        cat Lib/compileall.py.bak > $out/lib/python3.10/compileall.py
    '';
  }

