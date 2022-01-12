let
  # stage 0

  # these two use nixpkgs, but are fixed-output derivations with no dependencies
  tcc-seed = (import ./using-nix/0.nix).tinycc;
  protosrc = (import ./using-nix/0.nix).protosrc;
  # in bootstrapping builds,
  # 0.nix is different and they're not coming from nixpkgs,
  # see recipes/4-rebootstrap-using-nix.sh

  # stage 1

  stage1 = (import ./using-nix/1-stage1.nix) {
    inherit tcc-seed protosrc;
    recipesStage1ExtrasPath = ./recipes/1-stage1;
    stage1cPath = ./recipes/1-stage1.c;
  };  # multioutput, offers .protobusybox, .protomusl and .tinycc

  # stage 2

  mkCaDerivation = args: derivation (args // {
    system = builtins.currentSystem;
    __contentAddressed = true;
    outputHashAlgo = "sha256"; outputHashMode = "recursive";
  });

  mkDerivationStage2 = {name, script, buildInputPaths}: mkCaDerivation {
    inherit name;
    builder = "${stage1.protobusybox}/bin/ash";
    args = [ "-uexc" (
      ''
        export PATH=${builtins.concatStringsSep ":" buildInputPaths}

        if [ -e /store/_2a0-ccache ]; then
          . /store/_2a0-ccache/wrap-available
        fi

        unpack() (tar --strip-components=1 -xf "$@")

        if [ -n "$NIX_BUILD_CORES" ] && [ "$NIX_BUILD_CORES" != 0 ]; then
            NPROC=$NIX_BUILD_CORES
        elif [ "$NIX_BUILD_CORES" == 0 ] && [ -r /proc/cpuinfo ]; then
            NPROC=$(grep -c processor /proc/cpuinfo)
        else
            NPROC=1
        fi
        [ ! -e /bin/sh ]  # assert it's not present
                          # requires `sudo env "NIX_CONFIG=sandbox-paths ="`
                          # or adding your user to trusted-users. weird, right
      '' + script
    ) ];
  };

  static-gnumake = (import using-nix/2a0-static-gnumake.nix) {
    inherit mkDerivationStage2 stage1;
  };

  static-binutils = (import using-nix/2a1-static-binutils.nix) {
    inherit mkDerivationStage2 stage1 static-gnumake;
  };

  static-gnugcc4-c = (import using-nix/2a2-static-gnugcc4-c.nix) {
    inherit mkDerivationStage2 stage1 static-gnumake static-binutils;
  };

  intermediate-musl = (import using-nix/2a3-intermediate-musl.nix) {
    inherit mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils static-gnugcc4-c;
  };

  gnugcc4-cpp = (import using-nix/2a4-gnugcc4-cpp.nix) {
    inherit mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils static-gnugcc4-c;
    inherit intermediate-musl;
  };

in
  {
    inherit protosrc tcc-seed;
    inherit stage1;
    inherit static-gnumake static-binutils static-gnugcc4-c;
    inherit intermediate-musl gnugcc4-cpp;
  }
