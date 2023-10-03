{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, static-binutils, gnugcc10 }:

let
  source-tarball-python = fetchurl {
    # local = /downloads/Python-3.12.0.tar.xz;
    url = "https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tar.xz";
    sha256 = "795c34f44df45a0e9b9710c8c71c15c671871524cd412ca14def212e8ccb155d";
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
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' configure install-sh
        sed -i 's|ac_sys_system=`uname -s`|ac_sys_system=Linux|' configure
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
        sed -i 's|TIME __TIME__|TIME "xx:xx:xx"|' Modules/getbuildinfo.c
        sed -i 's|DATE __DATE__|DATE "xx/xx/xx"|' Modules/getbuildinfo.c
        # different build path length leads to different wrapping. avoid
        sed -i 's|vars, stream=f|vars, stream=f, width=2**24|' Lib/sysconfig.py
      # configure:
        mkdir -p $out/lib
        ash configure \
          ac_cv_broken_sem_getvalue=yes \
          ac_cv_posix_semaphores_enabled=no \
          OPT='-DNDEBUG -fwrapv -O3 -Wall' \
          LDFLAGS="-Wl,-rpath $out/lib" \
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
        sed -i "s|$(pwd)|...|g" \
          $out/lib/python3.*/_sysconfigdata__*.py \
          $out/lib/python3.*/config-3.*-x86_64-linux-musl/Makefile
        # restore compileall just in case
        cat Lib/compileall.py.bak > $out/lib/python3.12/compileall.py
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
    '';
  }

