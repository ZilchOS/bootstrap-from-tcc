{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, static-binutils, gnugcc10 }:

let
  source-tarball-python = fetchurl {
    # local = /downloads/Python-3.11.5.tar.xz;
    url = "https://www.python.org/ftp/python/3.11.5/Python-3.11.5.tar.xz";
    sha256 = "85cd12e9cf1d6d5a45f17f7afe1cebe7ee628d3282281c492e86adf636defa3f";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a8-python";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/wrappers"
      "${static-binutils}/bin"
      "${gnugcc10}/bin"
    ];
    script = ''
        mkdir build-dir; cd build-dir
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
        sed -i 's|__FILE__|"__FILE__"|' \
          Python/errors.c \
          Include/pyerrors.h \
          Include/cpython/object.h \
          Modules/pyexpat.c
      # configure:
        ash configure \
          ac_cv_broken_sem_getvalue=yes \
          ac_cv_posix_semaphores_enabled=no \
          OPT='-DNDEBUG -fwrapv -O3 -Wall' \
          --without-static-libpython \
          --build x86_64-linux-musl \
          --prefix=$out \
          --enable-shared \
          --with-ensurepip=no
        # ensure reproducibility in case of no /dev/shm
        grep 'define POSIX_SEMAPHORES_NOT_ENABLED 1' pyconfig.h
        grep 'define HAVE_BROKEN_SEM_GETVALUE 1' pyconfig.h
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
      # strip builddir mentions:
        sed -i "s|$(pwd)|...|" \
          $out/lib/python3.*/_sysconfigdata__*.py \
          $out/lib/python3.*/config-3.11-x86_64-linux-musl/Makefile
        # restore compileall just in case
        cat Lib/compileall.py.bak > $out/lib/python3.11/compileall.py
      # check for build path leaks:
        ( ! grep -RF $(pwd) $out )
    '';
  }

