#!/bin/sh
set -ue

NIXPKGS=nixpkgs/8eeae5320e741d55ec1b891853fa48419e3a5a26

mkdir -p stage/cheat

if [[ ! -e stage/cheat/make ]]; then
	nix build "$NIXPKGS#pkgsStatic.gnumake"
	cp result/bin/make stage/cheat/make
	rm result
fi

#if [[ ! -e stage/cheat/dash ]]; then
#	nix build "$NIXPKGS#pkgsStatic.dash"
#	cp result/bin/dash stage/cheat/dash
#	rm result
#fi

if [[ ! -e stage/cheat/bash ]]; then
	nix build "$NIXPKGS#pkgsStatic.bash"
	cp result/bin/bash stage/cheat/bash
	rm result
fi

if [[ ! -e stage/cheat/strace ]]; then
	nix build "$NIXPKGS#pkgsStatic.strace"
	cp result/bin/strace stage/cheat/
	rm result
fi

#if [[ ! -e stage/cheat/sed ]]; then
#	nix build "$NIXPKGS#pkgsStatic.gnused"
#	cp result/bin/sed stage/cheat/sed
#	rm result
#fi

if [[ ! -e stage/cheat/busybox ]]; then
	nix build "$NIXPKGS#pkgsStatic.busybox"
	cp result/bin/busybox stage/cheat/busybox
	for f in $(ls result/bin/); do
		[[ $(basename $f) == busybox ]] ||
			ln -s /cheat/busybox stage/cheat/$(basename $f)
	done
	rm result
fi

if [[ -n "$@" ]]; then
	mkdir -p stage/dev
	touch stage/dev/null
	_PATH='/2/out/gnugcc4/bin'
	_PATH+=':/2/out/binutils/bin'
	_PATH+=':/2/out/gnumake/bin'
	#_PATH+=':/1/out/tinycc/wrappers'
	_PATH+=':/1/out/protobusybox/bin'
	env -i PATH=$_PATH \
		$(command -v unshare) -nrR stage \
			"$@"
fi
