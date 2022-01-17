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
      url = "https://github.com/ZilchOS/bootstrap-from-tcc/releases/download/seeding-files-r001/protosrc.nar";
      sha256 = "sha256-VPbQvwJOmtld+kTBXdzwrR346L6qT7KhhpUsKu6/IfM=";
    };

    tinycc = fetchTarball {
      name = "tinycc-liberated";
      url = "https://github.com/ZilchOS/bootstrap-from-tcc/releases/download/seeding-files-r001/tinycc-liberated.nar";
      sha256 = "sha256-ADunchN4nGrE7OJ9OxkuzwsIDOW8I9/GukeiQMwhNIs=";
    };
  }
