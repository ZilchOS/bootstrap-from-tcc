#!/bin/sh
set -ue

NIXPKGS=nixpkgs/8eeae5320e741d55ec1b891853fa48419e3a5a26
: ${DESTDIR:=stage}

mkdir -p $DESTDIR/cheat

if [[ ! -e $DESTDIR/cheat/make ]]; then
	nix build "$NIXPKGS#pkgsStatic.gnumake"
	cp result/bin/make $DESTDIR/cheat/make
	rm result
fi

if [[ ! -e $DESTDIR/cheat/bash ]]; then
	nix build "$NIXPKGS#pkgsStatic.bash"
	cp result/bin/bash $DESTDIR/cheat/bash
	rm result
fi

if [[ ! -e $DESTDIR/cheat/strace ]]; then
	nix build "$NIXPKGS#pkgsStatic.strace"
	cp result/bin/strace $DESTDIR/cheat/
	rm result
fi

if [[ ! -e $DESTDIR/cheat/busybox ]]; then
	nix build "$NIXPKGS#pkgsStatic.busybox"
	cp result/bin/busybox $DESTDIR/cheat/busybox
	for f in $(ls result/bin/); do
		[[ $(basename $f) == busybox ]] ||
			ln -s /cheat/busybox $DESTDIR/cheat/$(basename $f)
	done
	rm result
fi

if [[ -n "$@" ]]; then
	_PATH='/1/out/protobusybox/bin'
	_PATH+=':/2/01-gnumake/out/bin'
	_PATH+=":/2/02-static-binutils/out/bin"
	_PATH+=":/2/03-static-gnugcc4/out/bin"
	env -i PATH=$_PATH \
		$(command -v unshare) -nrR $DESTDIR \
			"$@"
fi
