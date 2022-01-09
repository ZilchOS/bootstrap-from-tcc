rec {
  # stage 1

  stage1 = (import ./using-nix/1-stage1.nix) {
    tcc-seed = ./tcc-seed;
    protosrcPath = ./stage/protosrc;  # TODO: building it or hash-decoupling it
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

  source-tarball-gnumake = builtins.fetchurl {
    # local = /downloads/make-4.3.tar.gz;
    url = "http://ftp.gnu.org/gnu/make/make-4.3.tar.gz";
    sha256 = "e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19";
  };
  static-gnumake = (import using-nix/2a0-static-gnumake.nix) {
    inherit mkDerivationStage2 source-tarball-gnumake stage1;
  };

  source-tarball-binutils = builtins.fetchurl {
    # local = /downloads/binutils-2.37.tar.xz;
    url = "https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.xz";
    sha256 = "820d9724f020a3e69cb337893a0b63c2db161dadcb0e06fc11dc29eb1e84a32c";
  };
  static-binutils = (import using-nix/2a1-static-binutils.nix) {
    inherit mkDerivationStage2 source-tarball-binutils stage1 static-gnumake;
  };
}
