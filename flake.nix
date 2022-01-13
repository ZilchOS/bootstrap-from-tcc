{
  description = "bootstrap-from-tcc";

  outputs = { self }:
    let
      allPkgs = (import ./default.nix);
    in
      {
        packages.x86_64-linux = allPkgs;

        # TODO: expose only the most usable outputs
        # TODO: solve fetching: https://discourse.nixos.org/t/17105
        hydraJobs = builtins.mapAttrs (_: drv: { x86_64-linux = drv; }) allPkgs;
      };
}
