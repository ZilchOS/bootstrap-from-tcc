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

[[ -h arena/cheat/tcc ]] || ln -s /seed/bin/tcc arena/cheat/tcc
[[ -h arena/cheat/cc ]] || ln -s /seed/bin/tcc arena/cheat/cc

if [[ $# == 1 && $1 == 'sh' ]]; then
	env -i CC='tcc -nostdlib -nostdinc' 'AR=tcc -ar' PATH=/cheat:/ \
		$(command -v unshare) -nrR arena \
			/cheat/busybox ash
fi
