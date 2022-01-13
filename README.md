# `bootstrap-from-tcc`

## What

Bootstrap a modern toolchain
starting from a random trusted statically linked seed tcc
(+ trusted kernel on trusted hardware, of course).

~320 KB binary + gigs of sources = a modern Clang + musl toolchain,
usable for building much more serious stuff.

My goal is to beeline for bootstrapping Nix package manager,
and later buildan real Linux distribution using that bootstrapped Nix.
But even if you don't care about Nix,
this repo might interest minimal binary seed bootstrappers.

Separate packages aren't just dumped into `/`, they're properly managed,
each one residing in its own prefix under `/store`.

`x86_64`-only for now, maybe forever.

## Why

I wanted to build a minimal distro to understand NixOS better,
so I decided to have a decent trusted binary core bootstrap as well.

Could be of use for bootstrapping other distributions.

I'm aware of https://savannah.nongnu.org/projects/stage0 which does even better,
but I'm not as hardcore as them, so, let's start small.

## How

### In brief

Compiler chain so far:
input TinyCC -> stable TinyCC -> GNU GCC 4 -> GNU GCC 10 -> -> Clang

### Outlined

* stage 0: seeded binary `tcc`
* stage 1 (`recipes/1-stage1.c` using no libc):
  * `libtcc1`
  * `protomusl`
  * `tcc`
  * `libtcc1`
  * `protomusl`
  * `tcc` that is gonna be the final one
  * `libtcc1`
  * `protomusl`
  * `tcc` that we build just to prove the finality of the previous one
  * `protobusybox`
* stage 2 "compiler ascension" part (`recipes/2a*.sh`):
  * `gnumake`
  * `binutils`
  * `gnugcc4`
  * `musl`
  * `gnugcc4`
  * `gnugcc10`
  * `linux-headers`
  * `cmake`
  * `python`
  * `clang`
* stage 2 "build with the new compiler" part (`recipes/2b*.sh`):
  * `musl`
  * `clang`
  * `busybox`
  * `gnumake`
* stage 3 "dependencies of useful stuff" (`recipes/3a*.sh`): ???
  * `gnubash`
  * `sqlite`
  * `boost`
  * `mbedtls`
  * `pkg-config`
  * `curl`
  * `editline`
  * `brotli`
  * `gnugperf`
  * `seccomp`
  * `libarchive`
  * `libsodium`
  * `lowdown`
* stage 3 "useful stuff" (`recipes/3b*.sh`): ???
  * `nix`

### In more detail

given:

* **statically linked target tcc (`tcc-seed`, you have to provide it)**
* host `unshare` for `chroot`ing and isolation
* host `wget`, `tar`, `gzip`, `bzip2`, `sha256sum`, `tar`
  for optional convenient fetching of source files in stage 0
* host `sed` to preprocess the sources needed for stage 1, unfortunately
* a replacement for `musl/arch/x86_64/syscall_arch.h` that works with tcc
  (`syscall.h`)
* a bunch of sources to execute along the way

`download.sh" downloads a ton of sources, scraping hashes/URLs from recipes

`seed.sh` seeds:

* unpacks sources into the stage area
* FIXME: uses host `sed`/`rm` for preprocessing stage 1 source code,
  unfortunately
* copies `seed-tcc`, the only starting binary, into the stage area

At the end of it we obtain
a ton of sources and a single externally seeded `tcc` binary.

`recipes/1-stage1.c`, executed with `tcc -run`:

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

* Performs 'compiler ascension' from tcc to GNU GCC 4:
  * `gnumake`, intermediate, built without make
  * `gnumake`, statically linked
  * `binutils`, statically linked
  * `gnugcc4`, statically linked
  * `musl`, now a shared library as well
  * `gnugcc4` with C++ support and linking to a shared musl
  * `gnugcc10`
  * `linux-headers` (clang & cmake dependency)
  * `cmake` (clang dependency)
  * `python` (clang dependency, presumably)
  * `clang`, intermediate, 2-stage

* Recompile the world with clang, free of GNU runtime libs:
  * `musl`, final
  * `clang`, final
  * `busybox`, final
  * `gnumake`, final

* Build a bunch of Nix dependencies
* Build Nix

### Reproducibility

Reproducibility is deeply cared about, but only lightly tested at this point.

At 8a1ecde, I've tested two configurations:

* NixOS ~21.11 master, Linux 5.14.15, btrfs filesystem, tcc built with Nix
* NixOS 19.09 release, Linux 5.4.33, ext4 filesystem, tcc built on Alpine

Checksums of all available packages of the time past stage0 matched up
TinyCC was built from mob branch, da11cf6 commit.

Something like a year change or a kernel version change still might break it,
more rigorous testing and stricter isolation wouldn't hurt.
