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

`tcc-seed` -> `protomusl` -> hello world -> ??? -> gcc

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
* `alloca.S`/`libtcc1.c`/`va_list.c` from tcc distribution
* a bunch of sources to execute along the way

`download.sh" downloads:

* musl sources (`downloads/musl-1.2.2.tar.gz`)
* `va_list.c` from tcc distribution (`downloads/va_list.c`)

`seed.sh` seeds (populates the arena):

* unpacks musl sources into the arena
* FIXME: uses `sed` for preprocessing musl source code (cold stare towards musl)
* copies `seed-tcc`, the only starting binary, into the arena

`stage1.sh` builds protomusl and a hello world:

* executes `stage1.c` (including `syscalls.h` inside the arena, which:
  * compiles a protomusl from musl sources, `va_list.c`
  * compiles, links against protomusl and executes a hello world (`test.c`)

stage 2 (better musl): ???

* ???
