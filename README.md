# `bootstrap-from-tcc`

## What

Bootstrap as much of an operating system as possible
starting from a random trusted statically linked tcc
(+ trusted kernel on trusted hardware, of course).

`x86_64`-only for now.

## Why

I wanted to build a minimal distro to understand NixOS better,
so I decided to have a decent trusted binary core bootstrap as well.

I'm aware of https://savannah.nongnu.org/projects/stage0 which does even better,
but I'm not as hardcore as them, so, let's start small

## How

### In brief

input-tcc -> protomusl -> hello world -> ??? -> gcc

where each arrow adds new sources and a new buildscript into the mix

### In detail

given:

* **statically linked tcc (`input-tcc`, you have to provide it)**
* `wget`, `tar`, `gzip`, `bzip2`, `sha256sum`, `tar`
  for optional convenient fetching of source files in stage 0
* `unshare` for optional isolation
* a replacement for `musl/arch/x86_64/syscall_arch.h` that works with tcc
  (`syscall.h`)
* `va_list.c` from tcc distribution (`downloads/va_list.c`)
* a bunch of sources to execute along the way

downloads:

* musl sources (`downloads/musl-1.2.2.tar.gz`)
* `va_list.c` from tcc distribution (`downloads/va_list.c`)

stage 0 (populating the arena):

* unpack musl sources into the arena
* FIXME: use `sed` for preprocessing musl source code (cold stare towards musl)
* copy trusted tcc into the arena

stage 1 (musl & hello world):

* musl sources, `va_list.c` -> very basic musl
* very basic musl + `test.c` -> hello world

stage 2 (better musl): ???

* ???
