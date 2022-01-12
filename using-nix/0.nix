# When building with `make` or `build.sh` you'll have tcc-seed and protosrc
# long long before you have Nix,
# so there's no question of where to take them from, you just inject'em.
# In this case this file isn't used at all and a simpler 0.nix is generated,
# see recipes/4-rebootstrap-using-nix.sh

# This file is for when you already have Nix and want to jump into the middle,
# starting from the second, `using-nix` half of the bootstrap.
# Cases like hydra or flake-building.

# You ought to start from some tcc
# and do the initial source patching with something.

# Hope in the future there'll be neater ways to do that,
# or at least a tarball published somewhere,
# but currently it just builds both using nixpkgs
# and ensures they have no dependencies:

let
  nixpkgs = import (builtins.fetchTarball {
    name = "pinned-nixpkgs";
    url = "https://github.com/nixos/nixpkgs/archive/a898a9d1f0503d3b2c66a5bbf8ac459003d3c843.tar.gz";
    sha256 = "sha256:0m70w5rw5adz3riwh4m4x0vh5z8w0w8nlr1ajwi43ridma30vs8f";
  }) {};

  tinycc-unliberated = nixpkgs.pkgsStatic.tinycc.overrideAttrs(oa: {
    version = "unstable-2021-10-30";
    src = nixpkgs.fetchFromRepoOrCz {
      repo = "tinycc";
      rev = "da11cf651576f94486dbd043dbfcde469e497574";
      sha256 = "sha256-LWdM/1fjx88eCj+Bz4YN9zLEWhSjlX4ULZiPx82nocA=";
    };
    configureFlags = nixpkgs.lib.remove "--enable-cross" oa.configureFlags;
  });

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
    system = builtins.currentSystem;
    __contentAddressed = true;
    outputHashAlgo = "sha256"; outputHashMode = "recursive";
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
    url = "https://github.com/TinyCC/tinycc/archive/da11cf651576f94486dbd043dbfcde469e497574.tar.gz";
    sha256 = "c6b244e58677c4c486dbf80e35ee01b192e133876942afa07454159ba118b44e";
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
      cp ${source-tarball-tinycc} downloads/tinycc-mob-gitda11cf6.tar.gz
      mkdir -p recipes
      cp -r ${../recipes/1-stage1} recipes/1-stage1
      DESTDIR=$out ${nixpkgs.bash}/bin/bash \
        ${../recipes/1-stage1/seed.host-executed.sh}
      mv $out/protosrc/* $out/; rm -d $out/protosrc
    ''];
    allowedReferences = [ ];
    allowedRequisites = [ ];
    system = builtins.currentSystem;
    __contentAddressed = true;
    outputHashAlgo = "sha256"; outputHashMode = "recursive";
  };
in
  {
    tinycc = tinycc-liberated;
    inherit protosrc;
  }
