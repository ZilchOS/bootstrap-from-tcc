#!/usr/bin/env bash

# This is the straigthforward bootstrapping way.
# Prepare a directory with the initial TinyCC compiler, and a ton of sources.
# Then exec into it and let it bootstrap itself.

# You can refer to the Makefile for a more refined, totally optional approach
# with incremental builds, better build isolation etc.

set -uex

export MKOPTS=${MKOPTS:-$@}

if [[ ! -e ./0/tcc-seed ]]; then
	echo 'You need to supply a statically linked build of tinycc in ./0/.'
	echo 'You can `make 0/out/tcc-seed` if you have `nix` and trust in me.'
	exit 1
fi

# Create a stage directory
mkdir -p stage

# Download all the required source files
./download.sh

# Inject initial tcc and our scripts; pre-unpack and patch stage 1 sources,
# in a separate file because it makes sense to run it separately sometimes.
./seed.sh

# Exec into stage1.c inside stage with env unset,
# without network and with EUID=EGID=0.
# Alternatively, you can chroot if you're not a fan of user namespaces.
exec env -i "MKOPTS=$MKOPTS" unshare -nrR stage \
	/0/out/tcc-seed -nostdinc -nostdlib -Werror -run /1/src/stage1.c

# There's no next step, on completion stage 1 will chain-exec into stage 2, etc.
