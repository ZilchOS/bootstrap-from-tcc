{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, static-binutils, gnugcc10, linux-headers }:

let
  source-tarball-cmake = fetchurl {
    # local = /downloads/cmake-3.27.4.tar.gz;
    url = "https://github.com/Kitware/CMake/releases/download/v3.27.4/cmake-3.27.4.tar.gz";
    sha256 = "0a905ca8635ca81aa152e123bdde7e54cbe764fdd9a70d62af44cad8b92967af";
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
        mkdir build-dir; cd build-dir
        export SHELL=${stage1.protobusybox}/bin/ash
      # unpack:
        unpack ${source-tarball-cmake}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' bootstrap
        sed -i 's|__FILE__|"__FILE__"|' \
          Source/CPack/IFW/cmCPackIFWCommon.h \
          Source/CPack/cmCPack*.h \
          Source/cmCTest.h
      # bundle libraries:
        # poor man's static linking, a way for cmake to be self-contained later
        mkdir -p $out/bundled-runtime
        cp -H ${gnugcc10}/lib/libstdc++.so.6 $out/bundled-runtime/
        cp -H ${gnugcc10}/lib/libgcc_s.so.1 $out/bundled-runtime/
      # configure:
        ash configure \
          CFLAGS="-DCPU_SETSIZE=128 -D_GNU_SOURCE" \
          CXXFLAGS="-isystem ${linux-headers}/include" \
          LDFLAGS="-Wl,-rpath $out/bundled-runtime" \
          --prefix=$out \
          --parallel=$NPROC \
          -- \
          -DCMAKE_USE_OPENSSL=OFF
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install/strip
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
    '';
  }
