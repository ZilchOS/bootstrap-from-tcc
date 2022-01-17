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
    system = "x86_64-linux";
    __contentAddressed = true;
    outputHashAlgo = "sha256"; outputHashMode = "recursive";
  });

  mkDerivationStage2 =
    {name, script, buildInputPaths, extra ? {}}: mkCaDerivation {
      inherit name;
      builder = "${stage1.protobusybox}/bin/ash";
      args = [ "-uexc" (
        ''
          export PATH=${builtins.concatStringsSep ":" buildInputPaths}

          if [ -e /ccache/setup ]; then
            . /ccache/setup bootstrap-from-tcc/${name}
          fi

          unpack() (tar --strip-components=1 -xf "$@")

          if [ -n "$NIX_BUILD_CORES" ] && [ "$NIX_BUILD_CORES" != 0 ]; then
            NPROC=$NIX_BUILD_CORES
          elif [ "$NIX_BUILD_CORES" == 0 ] && [ -r /proc/cpuinfo ]; then
            NPROC=$(grep -c processor /proc/cpuinfo)
          else
            NPROC=1
          fi
        '' + script
      ) ];
    } // extra;

  fetchurl = { url, sha256 }: derivation {
    name = builtins.baseNameOf url;
    inherit url;
    urls = [ url ];
    unpack = false;

    builder = "builtin:fetchurl";
    system = "builtin";
    outputHashMode = "flat"; outputHashAlgo = "sha256";
    preferLocalBuild = true;
    outputHash = sha256;
  };

  static-gnumake = (import using-nix/2a0-static-gnumake.nix) {
    inherit fetchurl mkDerivationStage2 stage1;
  };

  static-binutils = (import using-nix/2a1-static-binutils.nix) {
    inherit fetchurl mkDerivationStage2 stage1 static-gnumake;
  };

  static-gnugcc4-c = (import using-nix/2a2-static-gnugcc4-c.nix) {
    inherit fetchurl mkDerivationStage2 stage1 static-gnumake static-binutils;
  };

  intermediate-musl = (import using-nix/2a3-intermediate-musl.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils static-gnugcc4-c;
  };

  gnugcc4-cpp = (import using-nix/2a4-gnugcc4-cpp.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils static-gnugcc4-c;
    inherit intermediate-musl;
  };

  gnugcc10 = (import using-nix/2a5-gnugcc10.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils gnugcc4-cpp intermediate-musl;
  };

  linux-headers = (import using-nix/2a6-linux-headers.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils gnugcc10;
  };

  cmake = (import using-nix/2a7-cmake.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils gnugcc10 linux-headers;
  };

  python = (import using-nix/2a8-python.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils gnugcc10;
  };

  intermediate-clang = (import using-nix/2a9-intermediate-clang.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake static-binutils intermediate-musl gnugcc10;
    inherit linux-headers cmake python;
  };

  musl = (import using-nix/2b0-musl.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake intermediate-clang;
  };

  clang = (import using-nix/2b1-clang.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake musl intermediate-clang;
    inherit linux-headers cmake python;
  };

  busybox = (import using-nix/2b2-busybox.nix) {
    inherit fetchurl mkDerivationStage2;
    inherit stage1 static-gnumake musl clang linux-headers;
  };

in
  {
    # exposed just because; don't rely on these
    inherit protosrc tcc-seed;
    inherit stage1;
    inherit static-gnumake static-binutils static-gnugcc4-c;
    inherit intermediate-musl gnugcc4-cpp gnugcc10;
    inherit linux-headers cmake python intermediate-clang;
    inherit musl clang;

    # public interface:
    libc = musl;        # some libc that TODO: doesn't depend on anything else
    toolchain = clang;  # some modern C/C++ compiler targeting this libc
    busybox = busybox;  # a freebie busybox TODO: depending on just libc
  }
