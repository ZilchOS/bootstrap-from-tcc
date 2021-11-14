#!/bin/sh
set -uexo pipefail

# FIXME: compile from nixpkgs once my tcc patch gets to nixpkgs
#nixpkgs/0000000000000000000000000000000000000000#pkgsStatic.tinycc
cat $(nix-build --no-out-link recipes/0/tcc-seed/patched.nix)/bin/tcc > tcc-seed
chmod +x tcc-seed
S='46c35b3fbc8e0f432596349a48d4c8f5485902db73d0afbafef2a7bc1c2d3f39  tcc-seed'
sha256sum tcc-seed
sha256sum -c <<<$S
