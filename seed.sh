#!/usr/bin/env bash
set -uex

if [[ ! -e ./tcc-seed ]]; then
	echo 'You need to supply a statically linked TinyCC as `tcc-seed`.'
	echo -n 'You can `./compile-tcc-seed-with-nix.sh` '
	echo 'if you have `nix` and trust in me.'
	exit 1
fi

rm -rf stage
mkdir -p stage/store
cp -raL --reflink=auto downloads recipes default.nix flake.nix stage/

# I'm too lazy to pass it through stage1
sed -i "s|\$NPROC|$NPROC|" stage/recipes/*.sh

DESTDIR=stage recipes/0-tcc-seed/seed.host-executed.sh  # copy tcc-seed
DESTDIR=stage recipes/1-stage1/seed.host-executed.sh    # unpack stage1 sources
# Everything past stage1 will unpack sources from downloads/ all by itself
# all the way until
cp -r using-nix stage/
