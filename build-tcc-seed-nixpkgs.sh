#!/bin/sh
set -uexvo pipefail

# FIXME: restore once my tcc patch gets to nixpkgs
#nix build 'nixpkgs/8eeae5320e741d55ec1b891853fa48419e3a5a26#pkgsStatic.tinycc'
#cat result/bin/tcc > tcc-seed
cat $(nix-build tcc-updated.nix)/bin/tcc > tcc-seed

chmod +x tcc-seed
sha256sum tcc-seed
S='46c35b3fbc8e0f432596349a48d4c8f5485902db73d0afbafef2a7bc1c2d3f39  tcc-seed'
if [[ "$(sha256sum tcc-seed)" != $S ]]; then
	echo 'hash mismatch'
	exit 1
fi
echo 'OK'
