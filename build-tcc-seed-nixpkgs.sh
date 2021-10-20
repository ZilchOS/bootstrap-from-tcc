#!/bin/sh
set -ue

nix build 'nixpkgs/8eeae5320e741d55ec1b891853fa48419e3a5a26#pkgsStatic.tinycc'
cat result/bin/tcc > tcc-seed
chmod +x tcc-seed
sha256sum tcc-seed
S='aabd6dbf1360c52f94e72864ea66d75b330c40a01a76ece24d11c899ca3a8c57  tcc-seed'
if [[ "$(sha256sum tcc-seed)" != $S ]]; then
	echo 'hash mismatch'
	exit 1
fi
