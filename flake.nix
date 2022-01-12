{
  description = "bootstrap-from-tcc";

  outputs = { self }: {
    packages.x86_64-linux = (import ./default.nix);
  };
}
