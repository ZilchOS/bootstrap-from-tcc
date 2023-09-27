# Where do tcc-seed and protosrc come from if you build with Nix?

# When building with `make` or `build.sh` you'll have tcc-seed and protosrc
# long long before you have Nix,
# so there's no question of where to take them from, you just inject'em.
# In this case this file isn't used at all and a simpler 0.nix is generated,
# see recipes/4-rebootstrap-using-nix.sh

# But not everyone wants to go the full bootstrap route.
# This file is for when you already have Nix and want to jump into the middle,
# starting from the second, `using-nix` half of the bootstrap.
# Cases like hydra or flake-building.

# One option is to build them using nixpkgs (see 0-from-nixpkgs.nix),
# but then you need nixpkgs, IFD and stuff.

# Alternatively we could download them prebuilt from github:ZilchOS,
# but then there's the question of falling back to another method
# when recipes/1-stage1/seed.host-executed.sh or recipes/1-stage1/syscall.h
# are updated.

# Here's one weird combined approach:

let
  and = builtins.all (x: x);
  syscall_h_ours = "${../recipes/1-stage1/syscall.h}";
  syscall_h_reference = "/nix/store/678g5j997qzp0srprfg4gqqxcp8mr3g9-syscall.h";
  syscall_h_is_unmodified = (syscall_h_ours == syscall_h_reference);
  stage1_seeder_ours = "${../recipes/1-stage1/seed.host-executed.sh}";
  stage1_seeder_reference = "/nix/store/qv4rmbdclws5nrx3m1vw1pb98qacw226-seed.host-executed.sh";
  stage1_seeder_is_unmodified = (stage1_seeder_ours == stage1_seeder_reference);
in
  if (and [ syscall_h_is_unmodified stage1_seeder_is_unmodified ])
  then import ./0-prebuilt.nix
  else import ./0-from-nixpkgs.nix
