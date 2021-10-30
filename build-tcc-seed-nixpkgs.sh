#!/bin/sh
set -uexvo pipefail

# FIXME: restore once my tcc patch gets to nixpkgs
#nix build 'nixpkgs/8eeae5320e741d55ec1b891853fa48419e3a5a26#pkgsStatic.tinycc'
#cat result/bin/tcc > tcc-seed
cat $(nix-build tcc-patched.nix)/bin/tcc > tcc-seed

chmod +x tcc-seed
sha256sum tcc-seed
S='f7c7f61b5ef5676306e5c58688e783eae1c0c8156ff29be4b5ae43bf6afb4970  tcc-seed'
if [[ "$(sha256sum tcc-seed)" != $S ]]; then
	echo 'hash mismatch'
	exit 1
fi
echo 'OK'
