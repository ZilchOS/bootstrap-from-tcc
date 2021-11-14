let
  nixpkgs = import (builtins.fetchTarball {
    name = "pinned-nixpkgs";
    url = "https://github.com/nixos/nixpkgs/archive/8eeae5320e741d55ec1b891853fa48419e3a5a26.tar.gz";
    sha256 = "sha256:18pprm729a1w1sn2rlfx7n4vc7cwwx9lcji928pdkq1k9mbz2fnf";
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
