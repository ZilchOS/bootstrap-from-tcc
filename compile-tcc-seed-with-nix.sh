#!/bin/sh
set -uexo pipefail

# FIXME: compile from nixpkgs once my tcc patch gets to nixpkgs
#nixpkgs/0000000000000000000000000000000000000000#pkgsStatic.tinycc
cat $(nix-build --no-out-link recipes/0-tcc-seed/patched.nix)/bin/tcc > tcc-seed
chmod +x tcc-seed
S='089ea66f63dd41d911b70967677eccded03c2db9d6f8bdb0f148edcf177becb4  tcc-seed'
sha256sum tcc-seed
sha256sum -c <<<$S
