# This is to prefetch protosrc/tinycc from github, see comment in 0.nix

let
  fetchTarball = { name, url, sha256 }: derivation {
    inherit name url;
    urls = [ url ];
    unpack = true;

    builder = "builtin:fetchurl";
    system = "builtin";
    outputHashMode = "recursive"; outputHashAlgo = "sha256";
    preferLocalBuild = true;
    outputHash = sha256;
  };
in
  {
    protosrc = fetchTarball {
      name = "protosrc";
      url = "https://github.com/ZilchOS/bootstrap-from-tcc/releases/download/seeding-files-r002/protosrc.nar";
      sha256 = "sha256-4hwx3fKNasQQXwszNQiItrmuLQE537lBfPrniBAADPE=";
    };

    tinycc = fetchTarball {
      name = "tinycc-liberated";
      url = "https://github.com/ZilchOS/bootstrap-from-tcc/releases/download/seeding-files-r002/tinycc-liberated.nar";
      sha256 = "sha256-oqeOU6SFYDwpdIj8MjcQ+bMuU63CHyoV9NYdyPLFxEQ=";
    };
  }
