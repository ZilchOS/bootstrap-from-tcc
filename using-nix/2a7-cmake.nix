{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, static-binutils, gnugcc10, linux-headers }:

let
  source-tarball-cmake = fetchurl {
    # local = /downloads/cmake-3.21.4.tar.gz;
    url = "https://github.com/Kitware/CMake/releases/download/v3.21.4/cmake-3.21.4.tar.gz";
    sha256 = "d9570a95c215f4c9886dd0f0564ca4ef8d18c30750f157238ea12669c2985978";
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
      # unpack:
        unpack ${source-tarball-cmake}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' bootstrap
      # bundle libraries:
        # poor man's static linking, a way for cmake to be self-contained later
        mkdir -p $out/bundled-runtime
        cp -H ${gnugcc10}/lib/libstdc++.so.6 $out/bundled-runtime/
        cp -H ${gnugcc10}/lib/libgcc_s.so.1 $out/bundled-runtime/
      # configure:
        ash configure \
          CFLAGS="-DCPU_SETSIZE=128" \
          CXXFLAGS="-I${linux-headers}/include" \
          LDFLAGS="-Wl,-rpath $out/bundled-runtime" \
          --prefix=$out \
          --parallel=$NPROC \
          -- \
          -DCMAKE_USE_OPENSSL=OFF
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install/strip
    '';
  }
