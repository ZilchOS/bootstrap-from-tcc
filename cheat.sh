#!/bin/sh
set -ue

NIXPKGS=nixpkgs/8eeae5320e741d55ec1b891853fa48419e3a5a26

mkdir -p arena/cheat

if [[ ! -e arena/cheat/make ]]; then
	nix build "$NIXPKGS#pkgsStatic.gnumake"
	cp result/bin/make arena/cheat/make
	rm result
fi

#if [[ ! -e arena/cheat/dash ]]; then
#	nix build "$NIXPKGS#pkgsStatic.dash"
#	cp result/bin/dash arena/cheat/dash
#	rm result
#fi

if [[ ! -e arena/cheat/bash ]]; then
	nix build "$NIXPKGS#pkgsStatic.bash"
	cp result/bin/bash arena/cheat/bash
	rm result
fi

if [[ ! -e arena/cheat/strace ]]; then
	nix build "$NIXPKGS#pkgsStatic.strace"
	cp result/bin/strace arena/cheat/
	rm result
fi

#if [[ ! -e arena/cheat/sed ]]; then
#	nix build "$NIXPKGS#pkgsStatic.gnused"
#	cp result/bin/sed arena/cheat/sed
#	rm result
#fi

if [[ ! -e arena/cheat/busybox ]]; then
	nix build "$NIXPKGS#pkgsStatic.busybox"
	cp result/bin/busybox arena/cheat/busybox
	for f in $(ls result/bin/); do
		[[ $(basename $f) == busybox ]] ||
			ln -s /cheat/busybox arena/cheat/$(basename $f)
	done
	rm result
fi

[[ -h arena/cheat/tcc ]] || ln -s /seed/1/bin/tcc arena/cheat/tcc
[[ -h arena/cheat/cc ]] || ln -s /seed/1/bin/tcc arena/cheat/cc

if [[ -n "$@" ]]; then
	mkdir -p arena/dev
	touch arena/dev/null
	mkdir -p arena/bin
	[[ -h arena/bin/sh ]] || ln -s /cheat/sh arena/bin/sh
	INCL+="-I/seed/1/src/protomusl/include "
	INCL+="-I/seed/1/src/protomusl/src/include "
	INCL+="-I/seed/1/src/protomusl/arch/x86_64 "
	INCL+="-I/seed/1/src/protomusl/arch/generic "
	INCL+="-I/seed/1/src/protomusl/stage0-generated/sed1 "
	LNKF+="-static -Wl,-whole-archive "
	LNKF+="/stage/1/lib/protomusl.a "
	LNKF+="/stage/1/tmp/protomusl/crt/crt1.o "
	CFLG=""
	env -i \
		PATH=/cheat:/ \
		CC='tcc -nostdlib -nostdinc' \
		CFLAGS="$INCL $CFLG" \
		LDFLAGS="$LNKF" \
		AR='tcc -ar' \
		CPP='tcc -E' \
		CPPFLAGS="$INCL $CFLG" \
		LD="tcc" \
		$(command -v unshare) -nrR arena \
			"$@"
fi
