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
but I'm not as hardcore as them, so, let's start small

## How

### In brief

`tcc-seed` -> `protomusl` -> `protobusybox` -> `gnumake` -> ??? ->
`gcc` -> ??? ->
`linux`, `nix`

where each arrow adds new sources and a new buildscript into the mix

### In detail

given:

* **statically linked target tcc (`tcc-seed`, you have to provide it)**
* host `unshare` for `chroot`ing and isolation
* host `wget`, `tar`, `gzip`, `bzip2`, `sha256sum`, `tar`
  for optional convenient fetching of source files in stage 0
* host `sed` to preprocess the sources, unfortunately
* a replacement for `musl/arch/x86_64/syscall_arch.h` that works with tcc
  (`syscall.h`)
* a bunch of sources to execute along the way

`download.sh" downloads:

* musl sources (`downloads/musl-1.2.2.tar.gz`)
* busybox sources (`downloads/busybox-1.34.1.tar.bz2`)
* sash sources (`downloads/sash-3.8.tar.gz`)
* gnumake sources (`downloads/make-4.3.tar.gz`)
* linux sources (`downloads/linux-5.10.74.tar.xz`)
* `alloca.S`/`libtcc1.c`/`va_list.c` from tcc distribution

`seed.sh` seeds (populates the arena):

* unpacks sources into the arena
* FIXME: uses host `sed`/`rm` for preprocessing source code, unfortunately
* copies `seed-tcc`, the only starting binary, into the arena

`stage1.sh` builds protomusl and `sash`:

* executes `stage1.c` (including `syscalls.h`) inside the arena, which:
  * compiles a protomusl from musl sources, `va_list.c`
  * compiles, links against protomusl and executes a hello world (`test.c`)
  * compiles, links against protomusl and executes stand-alone shell (`sash`)
  * compiles and links against protomusl bits of busybox, notably `ash`

stage 2:

* configures and builds statically-linked GNU `make`

TODO (undecided):

* `gcc 4`?
* modern `gcc`?
* normal `musl`?
* normal GNU `make`?
* `clang`?
* ???
* `nix`
* ???
* non-GNU `make`?
* ???
* `linux`?
* ???
