# `bootstrap-from-tcc`

## What

Bootstrap a modern toolchain for [ZilchOS Core](https://github.com/ZilchOS/core)
starting from a random trusted statically linked seed tcc
(+ trusted kernel on trusted hardware, of course).

~320 KB binary + gigs of sources = a modern Clang + musl toolchain,
usable for building much more serious stuff.

My goal is to beeline for bootstrapping Nix package manager,
then bootstrap a usable toolchain using Nix.
But even if you don't care about Nix,
this repo might be of some interest for minimal binary seed bootstrappers.

Separate packages aren't just dumped into `/`, they're properly managed,
each one residing in its own prefix under `/store`.

`x86_64`-only for now, possibly forever.

## Why

I wanted to build a minimal distro to understand NixOS better,
so I decided to have a decent trusted binary core bootstrap as well.

Could be of use for bootstrapping other distributions.

I'm aware of https://savannah.nongnu.org/projects/stage0 which does even better,
but I'm not as hardcore as them, so, let's start small.

## How

### In brief

Compiler chain so far (`recipes`):
input TinyCC -> stable TinyCC -> GNU GCC 4 -> GNU GCC 10 -> -> Clang

`recipes/1-stage1.c` is the most fun, since we don't have libc yet.

Then I build Nix and start the entire bootstrapping chain all over again,
but now using that Nix I've built (`using-nix`).

### Outlined bootstrap order

* stage 0: seeded binary `tcc`
* stage 1 (`recipes/1-stage1.c` / `using-nix/1-stage1.nix`, no libc):
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
* stage 2 "compiler ascension" part (`recipes/2a*.sh` / `using-nix/2a*.nix`):
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
  * `busybox-static`
  * `tinycc-static` (1st time only)
  * `nix`

Then repeat stage 1 and most of stage 2 all over again, but under Nix.
The final exports of this flake are musl, clang toolchain and a busybox
that ZilchOS Core later bootstraps from.

* stage 4 "rebootstrap with nix" (`recipes/4-rebootstrap-using-nix.sh`):
  build the toolchain again from scratch, but using nix (`using-nix/`)

* stage 5 "go beyond using nix" (`recipes/5-go-beyond-using-nix.sh`):
  build some stale version of [ZilchOS Core](https://github.com/ZilchOS/core)
  with the nix we've built, culminating with a bootable ZilchOS ISO.

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

* Start over, build toolchain, build ZilchOS Core

### Building options

There are three major ways to build it.

If you have Nix and want to skip the first half that bootstraps Nix,
you can just `nix build`, but what's the fun in taking shortcuts =).
You'll need `experimental-features = nix-command flakes ca-derivations`.

If you want to do a full bootstrap with all imaginable speedups enabled,
try something to the tune of
`make all-pkgs all-tests verify-all-pkgs-checksums -j2 NPROC=$(nproc) USE_CCACHE=1 USE_NIX_CACHE=1`.
Dependencies: host GNU Make, host zstd, basic host stuff like sed and bash,
a target TinyCC you supply or Nix to build you one.
This is the recommended way, especially shining when you
iteratively debug reproducibility-unrelated build problems.
Consider mounting `tmp/build` as tmpfs with 8G size.

Finally, the least-dependency way is `NPROC=$(nproc) ./build.sh`.
This one doesn't even need GNU Make or zstd,
but there are zero intermediate checkpoints, you always start all over.
Very impractical, this is for increased portability only.

### Reproducibility

Reproducibility is deeply cared about,
but it's a constant struggle and one cannot foresee everything.

Hashes are checked for intermediate steps for both `make` and `nix` builds.
`raw` builds only verify the resulting ZilchOS Core ISO built during stage5.
I try to build on different machines and note down the results in `git notes`.
Commits require a specific (but adjustable) amount of successful
`make`, `raw` and `nix` before getting into the main branch.
Refer to `make all-with-make`, `make all-raw` and `make all-with-nix`
to see what exactly is being tested.

For hard mode, you can try `USE_DISORDERFS`.

For ZilchOS/core, see `.maint/hashes` and `.maint/tools/hashes`.
