# This is to support building protosrc/tinycc from nixpkgs, see comment in 0.nix

let
  nixpkgs = import (builtins.fetchTarball {
    name = "pinned-nixpkgs";
    url = "https://github.com/nixos/nixpkgs/archive/21f524672f25f8c3e7a0b5775e6505fee8fe43ce.tar.gz";
    sha256 = "sha256:00pwazjld0bj2sp33gwiz1h8krkyf2nyid7injv5cqz5bz5jjw99";
  }) { system = "x86_64-linux"; };

  tinycc-unliberated = nixpkgs.pkgsStatic.tinycc;

  tinycc-liberated = derivation {
    name = "tinycc-liberated";
    builder = "/bin/sh";
    args = [ "-uexc" ''
      ${nixpkgs.pkgs.gnused}/bin/sed \
        's|/nix/store/.\{32\}-|!nix!store/................................-|g' \
        < ${tinycc-unliberated}/bin/tcc \
        > $out
      ! ${nixpkgs.pkgs.gnugrep}/bin/grep -i /nix/store $out
      ${nixpkgs.pkgs.coreutils}/bin/chmod +x $out
    ''];
    allowedReferences = [ ];
    allowedRequisites = [ ];
    system = "x86_64-linux";
    __contentAddressed = true;
    outputHashAlgo = "sha256"; outputHashMode = "recursive";
    outputHash = "sha256-oqeOU6SFYDwpdIj8MjcQ+bMuU63CHyoV9NYdyPLFxEQ=";
  };

  source-tarball-musl = builtins.fetchurl {
    url = "http://musl.libc.org/releases/musl-1.2.2.tar.gz";
    sha256 = "9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd";
  };

  source-tarball-busybox = builtins.fetchurl {
    url = "https://busybox.net/downloads/busybox-1.34.1.tar.bz2";
    sha256 = "415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549";
  };

  source-tarball-tinycc = builtins.fetchurl {
    url = "https://github.com/TinyCC/tinycc/archive/af1abf1f45d45b34f0b02437f559f4dfdba7d23c.tar.gz";
    sha256 = "sha256:0kkaax6iw28d9wl6sf14kn0gmwm0g5h9qmx9rm3awh23cq2iv9zm";
  };

  protosrc = derivation {
    name = "protosrc";
    builder = "/bin/sh";
    args = [ "-uexc" ''
      PATH=${nixpkgs.coreutils}/bin
      PATH=$PATH:${nixpkgs.gnused}/bin
      PATH=$PATH:${nixpkgs.gnutar}/bin
      PATH=$PATH:${nixpkgs.gzip}/bin
      PATH=$PATH:${nixpkgs.bzip2}/bin
      export PATH
      mkdir downloads/
      cp ${source-tarball-musl} downloads/musl-1.2.2.tar.gz
      cp ${source-tarball-busybox} downloads/busybox-1.34.1.tar.bz2
      cp ${source-tarball-tinycc} downloads/tinycc-mob-af1abf1.tar.gz
      mkdir -p recipes
      cp -r ${../recipes/1-stage1} recipes/1-stage1
      DESTDIR=$out ${nixpkgs.bash}/bin/bash \
        ${../recipes/1-stage1/seed.host-executed.sh}
      mv $out/protosrc/* $out/; rm -d $out/protosrc
    ''];
    allowedReferences = [ ];
    allowedRequisites = [ ];
    system = "x86_64-linux";
    __contentAddressed = true;
    outputHashAlgo = "sha256"; outputHashMode = "recursive";
    outputHash = "sha256-4hwx3fKNasQQXwszNQiItrmuLQE537lBfPrniBAADPE=";
  };
in
  {
    tinycc = tinycc-liberated;
    inherit protosrc;
  }
