#!/usr/bin/env bash
set -uex

if [[ ! -e ./0/tcc-seed ]]; then
	echo 'You need to supply a statically linked build of tinycc in ./0/.'
	echo 'You can `make 0/out/tcc-seed` if you have `nix` and trust in me.'
	exit 1
fi

rm -rf stage
mkdir -p stage/0/out
cp 0/tcc-seed stage/0/out/tcc-seed

cp -raL --reflink=auto downloads 0 1 2 stage/
sed -i "s|\$MKOPTS|$MKOPTS|" stage/2/*.sh  # too lazy to pass it through stage1
DESTDIR=stage 1/seed.host-executed.sh
