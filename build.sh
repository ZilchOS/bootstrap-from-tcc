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
# without network, with EUID=EGID=0 and with /dev/null being a /dev/null.
# See helpers/chroot and helpers/chroot-inner for more explanations
# Alternatively, you can chroot if you're not a fan of user namespaces.
MOUNT=$(command -v mount)
if [[ -e /run/wrappers/bin/mount.real ]]; then  # NixOS wrapper might be buggy
	MOUNT=$(cat /run/wrappers/bin/mount.real)
fi
MKDIR=$(command -v mkdir)
CHROOT=$(command -v chroot)

exec env -i "MKOPTS=$MKOPTS" unshare -nrm bash -uexs <<EOF
	$MKDIR stage/dev; :> stage/dev/null
	$MOUNT --bind /dev/null stage/dev/null

	exec $CHROOT stage \
		/0/out/tcc-seed -nostdinc -nostdlib -Werror -run /1/src/stage1.c
EOF

# There's no next step, on completion stage 1 will chain-exec into stage 2, etc.
