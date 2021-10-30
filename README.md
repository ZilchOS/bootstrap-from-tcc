# `bootstrap-from-tcc`

## What

Bootstrap as much of an operating system as possible
starting from a random trusted statically linked seed tcc
(+ trusted kernel on trusted hardware, of course).

`x86_64`-only for now.

## Why

I wanted to build a minimal distro to understand NixOS better,
so I decided to have a decent trusted binary core bootstrap as well.

I'm aware of https://savannah.nongnu.org/projects/stage0 which does even better,
but I'm not as hardcore as them, so, let's start small.

## How

### In brief

seeded binary `tcc` ->
`protomusl` -> our `tcc` -> `protomusl` -> our final `tcc` -> `protomusl` ->
`protobusybox` -> `gnumake` -> ??? ->
`gcc` -> ??? ->
`linux`, `nix`

### In detail

given:

* **statically linked target tcc (`tcc-seed`, you have to provide it)**
* host `unshare` for `chroot`ing and isolation
* host `wget`, `tar`, `gzip`, `bzip2`, `sha256sum`, `tar`
  for optional convenient fetching of source files in stage 0
* host `sed` to preprocess the sources needed for stage 1, unfortunately
* a replacement for `musl/arch/x86_64/syscall_arch.h` that works with tcc
  (`syscall.h`)
* a bunch of sources to execute along the way

`download.sh" downloads:

* `musl` sources (`downloads/musl-1.2.2.tar.gz`)
* `tinycc` sources (`downloads/tinycc-mob-git1645616.tar.gz`)
* `busybox` sources (`downloads/busybox-1.34.1.tar.bz2`)
* `gnumake` sources (`downloads/make-4.3.tar.gz`)
* `linux` sources (`downloads/linux-5.10.74.tar.xz`)

`seed.sh` seeds (populates the arena):

* unpacks sources into the arena
* FIXME: uses host `sed`/`rm` for preprocessing stage 1 source code,
  unfortunately
* copies `seed-tcc`, the only starting binary, into the arena

At the end of it we obtain
a ton of sources and a single externally seeded `tcc` binary.

`stage1.c`, executed with `tcc -run`:

* compiles a `libtcc1.a` from `tinycc` sources
* compiles a protomusl `libc.a` and others from `musl` sources
* compiles the first `tcc` that comes from our sources
* recompiles `libtcc1.a` from `tinycc` sources
* recompiles protomusl `libc.a` and others from `musl` sources
* recompiles our `tcc` with our `tcc`
* recompiles `libtcc1.a` from `tinycc` sources just in case
* recompiles protomusl `libc.a` and others from `musl` sources just in case
* compiles and links standalone applets out of busybox, notably `ash`
* copies over protomusl include files
* recompiles `tcc` once again
  and verifies that we've previously reached a stability point

At the end of stage 1 we have, all linked statically:

* a `tcc` (+ `libtcc` + `libtcc1`) that recompiles to same binary
* a protomusl `libc.a` (+ crt stuff)
* select standalone busybox applets, most notably `ash`

`stage2.sh`, executed with protobusybox `ash`:

* configures and builds statically-linked GNU `make` (`gnumake`)

TODO (undecided):

* `gcc 4`?
* modern `gcc`?
* normal `musl`?
* normal `busybox`?
* normal `gnumake`?
* `clang`?
* ???
* `nix`
* ???
* non-GNU `make`?
* ???
* `linux`?
* ???
