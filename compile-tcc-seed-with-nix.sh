#!/bin/sh
set -uexo pipefail

NIXPKGS_HASH=21f524672f25f8c3e7a0b5775e6505fee8fe43ce
TCC_CHECKSUM=05aad934985939e9997127e93d63d6a94c88739313c496f10a90176688cc9167
TCC=$(nix build "nixpkgs/$NIXPKGS_HASH#pkgsStatic.tinycc.out" \
          --no-link --print-out-paths)
cat $TCC/bin/tcc > tcc-seed
chmod +x tcc-seed
S="$TCC_CHECKSUM  tcc-seed"
sha256sum tcc-seed
sha256sum -c <<<$S
