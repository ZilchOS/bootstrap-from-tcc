#!/usr/bin/env bash

# This is the straigthforward bootstrapping way.
# Prepare a directory with the initial TinyCC compiler, and a ton of sources.
# Then exec into it and let it bootstrap itself.

# You can refer to the Makefile for a more refined, totally optional approach
# with incremental builds, better build isolation etc.

set -uex

export NPROC=${NPROC:-${1:-1}}

if [[ ! -e tcc-seed ]]; then
	echo 'You need to supply a statically linked TinyCC as `tcc-seed`.'
	echo -n 'You can `./compile-tcc-seed-with-nix.sh` '
	echo 'if you have `nix` and trust in me.'
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

exec env -i "NPROC=$NPROC" unshare -nrm bash -uexs <<EOF
	$MKDIR stage/dev; :> stage/dev/null
	$MOUNT --bind /dev/null stage/dev/null

	exec $CHROOT stage \
		/store/0-tcc-seed -nostdinc -nostdlib -Werror -run \
			/recipes/1-stage1.c
EOF

# There's no next step,
# upon completion stage1.c will exec into recipes/all-past-stage1.sh
