let
  nixpkgs = import (builtins.fetchTarball {
    name = "pinned-nixpkgs";
    url = "https://github.com/nixos/nixpkgs/archive/a898a9d1f0503d3b2c66a5bbf8ac459003d3c843.tar.gz";
    sha256 = "sha256:0m70w5rw5adz3riwh4m4x0vh5z8w0w8nlr1ajwi43ridma30vs8f";
  }) {};
in
  nixpkgs.pkgsStatic.tinycc.overrideAttrs(oa: {
    version = "unstable-2021-10-30";
    src = nixpkgs.fetchFromRepoOrCz {
      repo = "tinycc";
      rev = "da11cf651576f94486dbd043dbfcde469e497574";
      sha256 = "sha256-LWdM/1fjx88eCj+Bz4YN9zLEWhSjlX4ULZiPx82nocA=";
    };
    configureFlags = nixpkgs.lib.remove "--enable-cross" oa.configureFlags;
  })
