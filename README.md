# `bootstrap-from-tcc`

## What

Bootstrap as much of an operating system as possible
starting from a random trusted statically linked seed tcc
(+ trusted kernel on trusted hardware, of course).

~320 KB binary + ~2 GB of sources = a usable Linux userland to chroot into,
usable for building much more serious stuff.

It's not a Linux distribution as it doesn't come with a kernel.
Instead, I plan to beeline for bootstrapping Nix package manager
and then building an real Linux distribution from that bootstrapped Nix later.

Separate packages aren't just dumped into `/`, they're properly managed,
each one residing

`x86_64`-only for now.

## Why

I wanted to build a minimal distro to understand NixOS better,
so I decided to have a decent trusted binary core bootstrap as well.

Could be of use for bootstrapping other distributions.

I'm aware of https://savannah.nongnu.org/projects/stage0 which does even better,
but I'm not as hardcore as them, so, let's start small.

## How

### In brief

* stage 0: seeded binary `tcc`
* stage 1 (`1/src/stage1.c` using no libc):
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
* stage 2 (`2/*.sh`):
  * `gnumake`
  * `gnumake`
  * `binutils`
  * `gnugcc4`
  * `musl`
  * `gnugcc4`
  * `binutils`
  * `linux-headers`
  * `busybox`
* stage 3: ???
  * Nix?
  * Linux?

Compiler chain so far: `tcc` -> `gnugcc 4` -> `gnugcc 4`

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

* Performs 'compiler ascension' from tcc to GNU GCC 4:
  * `gnumake`, intermediate, built without make
  * `gnumake`, statically linked
  * `binutils`, statically linked
  * `gnugcc4`, statically linked

* Recompiles the world with GNU GCC 4:
  * `musl` usable for dynamic linking
  * `gnugcc4` that can dynamically link against it
  * `binutils`
  * `linux-headers`
  * `busybox`
  * `gnumake` (TODO)

What's next (undecided):

* rebuild gnumake dynamically over in stage 2
* try raising first `gnugcc` version within 4?
* try raising second `gnugcc` version as far as possible?
* add c++ support to second `gnugcc`?
* build `clang`?
* `nix`
* non-GNU `make`?
* `linux`?
* switch over to building in VM or UML at some point,
  so that there's at least a `/dev/null`??

### Reproducibility

Reproducibility is deeply cared about, but only lightly tested at this point.

At fd0e2b2, I've tested three configurations:

* NixOS ~21.11 master, Linux 5.14.15, btrfs filesystem, tcc built with Nix
* NixOS ~21.11 master, Linux 5.14.15, btrfs filesystem, tcc built on Alpine
* NixOS 19.09 release, Linux 5.4.33, ext4 filesystem, tcc built with Nix

Checksums of all stage 1/2 packages of the time matched up
(up to and including `2/08-busybox`).
TinyCC was built from mob branch, da11cf6 commit.

Something like a year change or a kernel version change still might break it,
more rigorous testing and stricter isolation wouldn't hurt.
