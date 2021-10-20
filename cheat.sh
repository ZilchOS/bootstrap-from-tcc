#!/bin/sh
set -ue

mkdir -p arena/cheat

if [[ ! -e arena/cheat/make ]]; then
	nix build 'nixpkgs#pkgsStatic.gnumake'
	cp result/bin/make arena/cheat/make
	rm result
fi

#if [[ ! -e arena/cheat/dash ]]; then
#	nix build 'nixpkgs#pkgsStatic.dash'
#	cp result/bin/dash arena/cheat/dash
#	rm result
#fi

if [[ ! -e arena/cheat/bash ]]; then
	nix build 'nixpkgs#pkgsStatic.bash'
	cp result/bin/bash arena/cheat/bash
	rm result
fi

#if [[ ! -e arena/cheat/sed ]]; then
#	nix build 'nixpkgs#pkgsStatic.gnused'
#	cp result/bin/sed arena/cheat/sed
#	rm result
#fi

if [[ ! -e arena/cheat/busybox ]]; then
	nix build 'nixpkgs#pkgsStatic.busybox'
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
