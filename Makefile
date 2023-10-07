# First-time readers, refer to `build.sh` instead, it's more clear.
#
# This Makefile is optional and is all to aid debugging and add extra isolation.
#
# None of what's below in this Makefile is needed to build the project.

all:
	@echo 'This Makefile is for debugging purposes, use ./build.sh'
	exit 1

ISO_CHECKSUM=22a6339a46c627bf761d5e90f936ac8dcf5717f8858975796959e47245a1320b

# the no-dependencies way: full bootstrap with no make
all-raw: build.sh seed.sh download.sh recipes/*.sh recipes/*/* using-nix/*
	./build.sh
	cp stage/store/5-go-beyond-using-nix/ZilchOS-core.iso \
		ZilchOS-core-raw.iso
	sha256sum -c <<<"$(ISO_CHECKSUM) ZilchOS-core-raw.iso"

# the make scaffolding way: full bootstrap with make
all-with-make: iso all-pkgs all-tests verify-all-pkgs-checksums \
	verify-all-nix-stage4-checksums verify-all-nix-stage5-checksums

# the your-nix way: build just the using-nix/ part with your nix
all-with-nix: verify-all-nix-plain-checksums

################################################################################

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:  # if only it also worked for dirs, see helpers/inject
CHROOT ?= $(shell command -v chroot 2>/dev/null || \
	PATH=/sbin:/usr/sbin/ command -v chroot 2>/dev/null || \
	echo chroot \
)
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.PHONY: all all-at-once all-with-make clean-stage clean deepclean iso \
	verify-all-pkgs-checksums verify-pkgs-checksums update-pkgs-checksums \
	verify-all-nix-stage4-checksums verify-all-nix-stage5-checksums \
	verify-all-nix-plain-checksums verify-nix-plain-checksums \
	me-suffer
NPROC ?= 1 # for inner make invocations, one can pass -j# this way
USE_CCACHE ?= 0  # for faster iterative debugging only
USE_NIX_CACHE ?= 0  # for faster iterative debugging only
USE_DISORDERFS ?= 0  # for more thorough reproducibility testing
SAVE_MISMATCHING_BUILD_TREES ?= 0  # for more thorough reproducibility testing

SOURCE_DATE_EPOCH ?= $(shell date '--date=01 Jan 1970 00:00:00 UTC' +%s)
TAR := tar
TAR_REPR = $(TAR) --sort=name '--mtime=@$(SOURCE_DATE_EPOCH)' \
	--owner=0 --group=0 --numeric-owner \
	--pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime

downloads/%:
	@echo "### Makefile: downloading required $*..."
	ONLY="$*" ./download.sh
	[[ -e downloads/$* ]]

################################################################################

stage/protosrc: seed.sh
stage/protosrc: recipes/1-stage1/syscall.h
stage/protosrc: recipes/1-stage1/seed.host-executed.sh
stage/protosrc: downloads/musl-1.2.4.tar.gz
stage/protosrc: downloads/busybox-1.36.1.tar.bz2
stage/protosrc: downloads/tinycc-mob-af1abf1.tar.gz
	env DESTDIR=stage recipes/1-stage1/seed.host-executed.sh

NIXPKGS_HASH=21f524672f25f8c3e7a0b5775e6505fee8fe43ce
TCC_CHECKSUM=05aad934985939e9997127e93d63d6a94c88739313c496f10a90176688cc9167
tcc-seed:
	@echo '### Makefile: you are supposed to supply a trusted tcc-seed'
	@echo '### Makefile: since you have not, building one from nixpkgs...'
	cat $$(nix build "nixpkgs/${NIXPKGS_HASH}#pkgsStatic.tinycc.out" \
                   --no-link --print-out-paths)/bin/tcc > tcc-seed
	chmod +x tcc-seed
	sha256sum -c <<<"$(TCC_CHECKSUM) tcc-seed"
	@echo '### Makefile: using tcc-seed built with nix'

# Stage 0 is special in that there are no sources, we just pack up tcc-seed
pkgs/0-tcc-seed.pkg: tcc-seed
	@echo '### Makefile: special stage 0: just packing up tcc-seed...'
	mkdir -p tmp/build/0-tcc-seed/store pkgs
	cp tcc-seed tmp/build/0-tcc-seed/store/0-tcc-seed
	$(TAR_REPR) -Izstd -cf pkgs/0-tcc-seed.pkg -C tmp/build/0-tcc-seed \
		store/0-tcc-seed
	rm -rf tmp/build/0-tcc-seed
	@echo '### Makefile: successfully packed up pkgs/0-tcc-seed.pkg'

# Stage 1 is special in that:
# * we patch up some sources on the host
# * we have no shell and execute 1-stage1.c with tcc-seed
pkgs/1-stage1.pkg: pkgs/0-tcc-seed.pkg
pkgs/1-stage1.pkg: recipes/1-stage1.c
pkgs/1-stage1.pkg: recipes/1-stage1/seed.host-executed.sh
pkgs/1-stage1.pkg: recipes/1-stage1/syscall.h
pkgs/1-stage1.pkg: recipes/1-stage1/protobusybox.c
pkgs/1-stage1.pkg: recipes/1-stage1/protobusybox.h
pkgs/1-stage1.pkg: recipes/1-stage1/hello.c
pkgs/1-stage1.pkg: downloads/musl-1.2.4.tar.gz
pkgs/1-stage1.pkg: downloads/tinycc-mob-af1abf1.tar.gz
pkgs/1-stage1.pkg: downloads/busybox-1.36.1.tar.bz2
pkgs/1-stage1.pkg:
	@echo "### Makefile: creating temporary builddir tmp/build/1-stage1..."
	rm -rf tmp/build/1-stage1
	DISORDER=$(USE_DISORDERFS) helpers/builddir create tmp/build/1-stage1
	@echo "### Makefile: injecting dependencies..."
	helpers/inject tmp/build/1-stage1 $^
	@echo "### Makefile: seeding special stage 1 (and patching sources)..."
	DESTDIR=tmp/build/1-stage1 recipes/1-stage1/seed.host-executed.sh
	@echo "### Makefile: special stage 1: executing stage1.c with tcc-seed"
	DISORDER=$(USE_DISORDERFS) helpers/builddir pre-build tmp/build/1-stage1
	env -i unshare -nr $(CHROOT) ./tmp/build/1-stage1 \
		/store/0-tcc-seed -nostdinc -nostdlib -Werror \
			-run recipes/1-stage1.c
	DISORDER=$(USE_DISORDERFS) \
	       helpers/builddir post-build tmp/build/1-stage1
	$(TAR_REPR) -Izstd -cf pkgs/1-stage1.pkg -C tmp/build/1-stage1 \
		store/1-stage1
	DISORDER=$(USE_DISORDERFS) helpers/builddir remove tmp/build/1-stage1
	@echo "### Makefile: 1-stage1 has been built as pkgs/1-stage1.pkg"

# Consequent stages split up into packages have it simpler:
pkgs/%.pkg: recipes/%.sh
	@echo "### Makefile: creating a temporary build area tmp/build/$*..."
	if ! rm -rf "tmp/build/$*" 2>/dev/null; then \
		chmod -R +w "tmp/build/$*"; \
		rm -rf "tmp/build/$*"; \
	fi
	[ ! -e "tmp/build/$*" ]
	DISORDER=$(USE_DISORDERFS) helpers/builddir create "tmp/build/$*"
	helpers/inject "tmp/build/$*" $^
ifeq ($(USE_CCACHE), 1)
	@echo "### Makefile: unpacking ccache from previous builds $*..."
	mkdir -p "tmp/build/$*/ccache"
	[[ ! -e "tmp/ccache/$*.tar.zstd" ]] || \
		tar -Izstd -xf "tmp/ccache/$*.tar.zstd" -C "tmp/build/$*/ccache"
	ln -sf /store/_2a0-ccache/wrap-available "tmp/build/$*/ccache/setup"
	ln -sf /store/_2a0-ccache/bin "tmp/build/$*/ccache/bin"
endif
ifeq ($(USE_NIX_CACHE), 1)
	@echo "### Makefile: unpacking nix store and db from previous build..."
	if [[ $* =~ .*-using-nix ]] && [[ -e "pkgs/$*.pkg" ]]; then \
		mkdir "tmp/build/$*/prev/"; \
		tar --strip-components=2 \
			-xf "pkgs/$*.pkg" -C "tmp/build/$*/prev/"; \
	fi
endif
	DISORDER=$(USE_DISORDERFS) helpers/builddir pre-build "tmp/build/$*"
	@echo "### Makefile: building $* ..."
	env \
		DESTDIR="./tmp/build/$*" \
		NPROC="$(NPROC)" \
		SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)" \
		./helpers/chroot "/recipes/$*.sh"
	DISORDER=$(USE_DISORDERFS) helpers/builddir post-build "tmp/build/$*"
	@echo "### Makefile: packing up $* ..."
	$(TAR_REPR) -Izstd -cf "pkgs/$*.pkg" -C "tmp/build/$*" "store/$*"
ifeq ($(USE_CCACHE), 1)
	@echo "### Makefile: packing up $* ccache cache..."
	if [[ -e "tmp/build/$*/store/_2a0-ccache/bin/ccache" ]]; then \
		mkdir -p tmp/ccache; \
		unshare -nr $(CHROOT) "tmp/build/$*" \
			/store/_2a0-ccache/bin/ccache -sz; \
		$(TAR_REPR) -Izstd -cf "tmp/ccache/$*.tar.zstd" \
			-C "tmp/build/$*/ccache" .; \
	fi
	rm -rf "tmp/build/$*/store/_2a0-ccache"
	rm -rf "tmp/build/$*/ccache"
endif
ifeq ($(SAVE_MISMATCHING_BUILD_TREES), 1)
	computed_csum=$$(zstd -qcd "pkgs/$*.pkg" | sha256sum); \
	computed_csum=$$(<<<$$computed_csum tr ' ' '\t' | cut -f1); \
	if ! grep -q "$$computed_csum pkgs/$*" verify.pkgs.sha256; then \
		short_csum=$$(<<<$$computed_csum head -c7); \
		echo "### Makefile: packing up $* buildtree"; \
		mkdir -p trees; \
		$(TAR_REPR) -Izstd -cf "trees/$*-$$short_csum.pkg" \
			-C "tmp/build/$*" .; \
	fi
endif
	@echo "### Makefile: cleaning up after $*"
	DISORDER=$(USE_DISORDERFS) helpers/builddir remove "tmp/build/$*"
	@echo "### Makefile: $* has been built as pkgs/$*.pkg"

# Dependency graph:

pkgs/2a0-static-gnumake.pkg: pkgs/1-stage1.pkg
pkgs/2a0-static-gnumake.pkg: downloads/make-4.4.1.tar.gz

ifeq ($(USE_CCACHE), 1)
pkgs/_2a0-ccache.pkg: pkgs/1-stage1.pkg
pkgs/_2a0-ccache.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/_2a0-ccache.pkg: downloads/ccache-3.7.12.tar.xz
endif

pkgs/2/01-gnumake.pkg: pkgs/1-stage1.pkg
pkgs/2/01-gnumake.pkg: pkgs/2/00-intermediate-gnumake.pkg
pkgs/2/01-gnumake.pkg: downloads/make-4.4.1.tar.gz

pkgs/2a1-static-binutils.pkg: pkgs/1-stage1.pkg
pkgs/2a1-static-binutils.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a1-static-binutils.pkg: downloads/binutils-2.39.tar.xz

pkgs/2a2-static-gnugcc4-c.pkg: pkgs/1-stage1.pkg
pkgs/2a2-static-gnugcc4-c.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a2-static-gnugcc4-c.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a2-static-gnugcc4-c.pkg: downloads/gmp-4.3.2.tar.xz
pkgs/2a2-static-gnugcc4-c.pkg: downloads/mpfr-2.4.2.tar.xz
pkgs/2a2-static-gnugcc4-c.pkg: downloads/mpc-0.8.1.tar.gz
pkgs/2a2-static-gnugcc4-c.pkg: downloads/gcc-4.7.4.tar.bz2

pkgs/2a3-intermediate-musl.pkg: pkgs/1-stage1.pkg
pkgs/2a3-intermediate-musl.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a3-intermediate-musl.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a3-intermediate-musl.pkg: pkgs/2a2-static-gnugcc4-c.pkg
pkgs/2a3-intermediate-musl.pkg: downloads/musl-1.2.4.tar.gz

pkgs/2a4-gnugcc4-cpp.pkg: pkgs/1-stage1.pkg
pkgs/2a4-gnugcc4-cpp.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a4-gnugcc4-cpp.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a4-gnugcc4-cpp.pkg: pkgs/2a2-static-gnugcc4-c.pkg
pkgs/2a4-gnugcc4-cpp.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a4-gnugcc4-cpp.pkg: downloads/gmp-4.3.2.tar.xz
pkgs/2a4-gnugcc4-cpp.pkg: downloads/mpfr-2.4.2.tar.xz
pkgs/2a4-gnugcc4-cpp.pkg: downloads/mpc-0.8.1.tar.gz
pkgs/2a4-gnugcc4-cpp.pkg: downloads/gcc-4.7.4.tar.bz2

pkgs/2a5-gnugcc10.pkg: pkgs/1-stage1.pkg
pkgs/2a5-gnugcc10.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a5-gnugcc10.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a5-gnugcc10.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a5-gnugcc10.pkg: pkgs/2a4-gnugcc4-cpp.pkg
pkgs/2a5-gnugcc10.pkg: downloads/gcc-10.5.0.tar.xz
pkgs/2a5-gnugcc10.pkg: downloads/gmp-6.1.0.tar.xz
pkgs/2a5-gnugcc10.pkg: downloads/mpc-1.0.3.tar.gz
pkgs/2a5-gnugcc10.pkg: downloads/mpfr-3.1.4.tar.xz
pkgs/2a5-gnugcc10.pkg: downloads/isl-0.18.tar.bz2

pkgs/2a6-linux-headers.pkg: pkgs/1-stage1.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a6-linux-headers.pkg: downloads/linux-6.4.12.tar.xz

pkgs/2a7-cmake.pkg: pkgs/1-stage1.pkg
pkgs/2a7-cmake.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a7-cmake.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a7-cmake.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a7-cmake.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a7-cmake.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2a7-cmake.pkg: downloads/cmake-3.27.4.tar.gz

pkgs/2a8-python.pkg: pkgs/1-stage1.pkg
pkgs/2a8-python.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a8-python.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a8-python.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a8-python.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a8-python.pkg: downloads/Python-3.12.0.tar.xz

pkgs/2a9-intermediate-clang.pkg: pkgs/1-stage1.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a7-cmake.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a8-python.pkg
pkgs/2a9-intermediate-clang.pkg: downloads/llvm-project-17.0.1.src.tar.xz

pkgs/2b0-musl.pkg: pkgs/1-stage1.pkg
pkgs/2b0-musl.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b0-musl.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2b0-musl.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2b0-musl.pkg: pkgs/2a9-intermediate-clang.pkg
pkgs/2b0-musl.pkg: downloads/musl-1.2.4.tar.gz

pkgs/2b1-clang.pkg: pkgs/1-stage1.pkg
pkgs/2b1-clang.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b1-clang.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2b1-clang.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2b1-clang.pkg: pkgs/2a7-cmake.pkg
pkgs/2b1-clang.pkg: pkgs/2a8-python.pkg
pkgs/2b1-clang.pkg: pkgs/2a9-intermediate-clang.pkg
pkgs/2b1-clang.pkg: pkgs/2b0-musl.pkg
pkgs/2b1-clang.pkg: downloads/llvm-project-17.0.1.src.tar.xz

pkgs/2b2-busybox.pkg: pkgs/1-stage1.pkg
pkgs/2b2-busybox.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b2-busybox.pkg: pkgs/2b0-musl.pkg
pkgs/2b2-busybox.pkg: pkgs/2b1-clang.pkg
pkgs/2b2-busybox.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2b2-busybox.pkg: downloads/busybox-1.36.1.tar.bz2

pkgs/2b3-gnumake.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b3-gnumake.pkg: pkgs/2b0-musl.pkg
pkgs/2b3-gnumake.pkg: pkgs/2b1-clang.pkg
pkgs/2b3-gnumake.pkg: pkgs/2b2-busybox.pkg
pkgs/2b3-gnumake.pkg: downloads/make-4.4.1.tar.gz

pkgs/3a-sqlite.pkg: pkgs/2b0-musl.pkg
pkgs/3a-sqlite.pkg: pkgs/2b1-clang.pkg
pkgs/3a-sqlite.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-sqlite.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-sqlite.pkg: downloads/sqlite-autoconf-3430000.tar.gz

pkgs/3a-boost.pkg: pkgs/2b0-musl.pkg
pkgs/3a-boost.pkg: pkgs/2b1-clang.pkg
pkgs/3a-boost.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-boost.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-boost.pkg: pkgs/2a6-linux-headers.pkg
pkgs/3a-boost.pkg: downloads/boost_1_83_0.tar.bz2

pkgs/3a-mbedtls.pkg: pkgs/2b0-musl.pkg
pkgs/3a-mbedtls.pkg: pkgs/2b1-clang.pkg
pkgs/3a-mbedtls.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-mbedtls.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-mbedtls.pkg: downloads/mbedtls-3.4.1.tar.gz

pkgs/3a-pkg-config.pkg: pkgs/2b0-musl.pkg
pkgs/3a-pkg-config.pkg: pkgs/2b1-clang.pkg
pkgs/3a-pkg-config.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-pkg-config.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-pkg-config.pkg: downloads/pkg-config-0.29.2.tar.gz

pkgs/3a-curl.pkg: pkgs/2b0-musl.pkg
pkgs/3a-curl.pkg: pkgs/2b1-clang.pkg
pkgs/3a-curl.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-curl.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-curl.pkg: pkgs/3a-mbedtls.pkg
pkgs/3a-curl.pkg: pkgs/3a-pkg-config.pkg
pkgs/3a-curl.pkg: downloads/curl-8.2.1.tar.xz

pkgs/3a-editline.pkg: pkgs/2b0-musl.pkg
pkgs/3a-editline.pkg: pkgs/2b1-clang.pkg
pkgs/3a-editline.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-editline.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-editline.pkg: downloads/editline-1.17.1.tar.xz

pkgs/3a-brotli.pkg: pkgs/2b0-musl.pkg
pkgs/3a-brotli.pkg: pkgs/2b1-clang.pkg
pkgs/3a-brotli.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-brotli.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-brotli.pkg: downloads/brotli-1.0.9.tar.gz

pkgs/3a-gnugperf.pkg: pkgs/2b0-musl.pkg
pkgs/3a-gnugperf.pkg: pkgs/2b1-clang.pkg
pkgs/3a-gnugperf.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-gnugperf.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-gnugperf.pkg: downloads/gperf-3.1.tar.gz

pkgs/3a-seccomp.pkg: pkgs/2b0-musl.pkg
pkgs/3a-seccomp.pkg: pkgs/2b1-clang.pkg
pkgs/3a-seccomp.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-seccomp.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-seccomp.pkg: pkgs/3a-gnugperf.pkg
pkgs/3a-seccomp.pkg: pkgs/2a6-linux-headers.pkg
pkgs/3a-seccomp.pkg: downloads/libseccomp-2.5.4.tar.gz

pkgs/3a-libarchive.pkg: pkgs/2b0-musl.pkg
pkgs/3a-libarchive.pkg: pkgs/2b1-clang.pkg
pkgs/3a-libarchive.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-libarchive.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-libarchive.pkg: pkgs/3a-pkg-config.pkg
pkgs/3a-libarchive.pkg: downloads/libarchive-3.7.1.tar.xz

pkgs/3a-libsodium.pkg: pkgs/2b0-musl.pkg
pkgs/3a-libsodium.pkg: pkgs/2b1-clang.pkg
pkgs/3a-libsodium.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-libsodium.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-libsodium.pkg: pkgs/3a-pkg-config.pkg
pkgs/3a-libsodium.pkg: downloads/libsodium-1.0.18.tar.gz

pkgs/3a-lowdown.pkg: pkgs/2b0-musl.pkg
pkgs/3a-lowdown.pkg: pkgs/2b1-clang.pkg
pkgs/3a-lowdown.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-lowdown.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-lowdown.pkg: downloads/lowdown-1.0.2.tar.gz

pkgs/3a-nlohmann-json.pkg: pkgs/2b0-musl.pkg
pkgs/3a-nlohmann-json.pkg: pkgs/2b1-clang.pkg
pkgs/3a-nlohmann-json.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-nlohmann-json.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-nlohmann-json.pkg: downloads/nlohmann-json-3.11.2.tar.xz

pkgs/3b-busybox-static.pkg: pkgs/2b0-musl.pkg
pkgs/3b-busybox-static.pkg: pkgs/2b1-clang.pkg
pkgs/3b-busybox-static.pkg: pkgs/2b2-busybox.pkg
pkgs/3b-busybox-static.pkg: pkgs/2b3-gnumake.pkg
pkgs/3b-busybox-static.pkg: pkgs/2a6-linux-headers.pkg
pkgs/3b-busybox-static.pkg: downloads/busybox-1.36.1.tar.bz2

pkgs/3b-tinycc-static.pkg: pkgs/2b0-musl.pkg
pkgs/3b-tinycc-static.pkg: pkgs/2b1-clang.pkg
pkgs/3b-tinycc-static.pkg: pkgs/2b2-busybox.pkg
pkgs/3b-tinycc-static.pkg: pkgs/2b3-gnumake.pkg
pkgs/3b-tinycc-static.pkg: downloads/tinycc-mob-af1abf1.tar.gz

pkgs/3b-nix.pkg: pkgs/2b0-musl.pkg
pkgs/3b-nix.pkg: pkgs/2b1-clang.pkg
pkgs/3b-nix.pkg: pkgs/2b2-busybox.pkg
pkgs/3b-nix.pkg: pkgs/2b3-gnumake.pkg
pkgs/3b-nix.pkg: pkgs/2a6-linux-headers.pkg
pkgs/3b-nix.pkg: pkgs/3a-sqlite.pkg
pkgs/3b-nix.pkg: pkgs/3a-boost.pkg
pkgs/3b-nix.pkg: pkgs/3a-pkg-config.pkg
pkgs/3b-nix.pkg: pkgs/3a-curl.pkg
pkgs/3b-nix.pkg: pkgs/3a-editline.pkg
pkgs/3b-nix.pkg: pkgs/3a-brotli.pkg
pkgs/3b-nix.pkg: pkgs/3a-seccomp.pkg
pkgs/3b-nix.pkg: pkgs/3a-libarchive.pkg
pkgs/3b-nix.pkg: pkgs/3a-libsodium.pkg
pkgs/3b-nix.pkg: pkgs/3a-lowdown.pkg
pkgs/3b-nix.pkg: pkgs/3a-nlohmann-json.pkg
pkgs/3b-nix.pkg: pkgs/3b-busybox-static.pkg
pkgs/3b-nix.pkg: downloads/queue.h
pkgs/3b-nix.pkg: downloads/nix-2.17.0-zilched.tar.xz

pkgs/4-rebootstrap-using-nix.pkg: pkgs/2b0-musl.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/2b1-clang.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/2b2-busybox.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-boost.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-pkg-config.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-sqlite.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-curl.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-editline.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-brotli.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-seccomp.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-libarchive.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-libsodium.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-lowdown.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3a-nlohmann-json.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3b-tinycc-static.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3b-busybox-static.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/3b-nix.pkg
###
pkgs/4-rebootstrap-using-nix.pkg: stage/protosrc
###
pkgs/4-rebootstrap-using-nix.pkg: recipes/1-stage1.c
pkgs/4-rebootstrap-using-nix.pkg: recipes/1-stage1/seed.host-executed.sh
pkgs/4-rebootstrap-using-nix.pkg: recipes/1-stage1/syscall.h
pkgs/4-rebootstrap-using-nix.pkg: recipes/1-stage1/protobusybox.c
pkgs/4-rebootstrap-using-nix.pkg: recipes/1-stage1/protobusybox.h
pkgs/4-rebootstrap-using-nix.pkg: recipes/1-stage1/hello.c
###
pkgs/4-rebootstrap-using-nix.pkg: default.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/1-stage1.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a0-static-gnumake.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a1-static-binutils.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a2-static-gnugcc4-c.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a3-intermediate-musl.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a4-gnugcc4-cpp.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a5-gnugcc10.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a6-linux-headers.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a7-cmake.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a8-python.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2a9-intermediate-clang.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2b0-musl.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2b1-clang.nix
pkgs/4-rebootstrap-using-nix.pkg: using-nix/2b2-busybox.nix
###
pkgs/4-rebootstrap-using-nix.pkg: downloads/make-4.4.1.tar.gz
pkgs/4-rebootstrap-using-nix.pkg: downloads/binutils-2.39.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/gcc-4.7.4.tar.bz2
pkgs/4-rebootstrap-using-nix.pkg: downloads/gmp-4.3.2.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/mpfr-2.4.2.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/mpc-0.8.1.tar.gz
pkgs/4-rebootstrap-using-nix.pkg: downloads/musl-1.2.4.tar.gz
pkgs/4-rebootstrap-using-nix.pkg: downloads/gcc-10.5.0.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/gmp-6.1.0.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/mpfr-3.1.4.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/mpc-1.0.3.tar.gz
pkgs/4-rebootstrap-using-nix.pkg: downloads/isl-0.18.tar.bz2
pkgs/4-rebootstrap-using-nix.pkg: downloads/linux-6.4.12.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/cmake-3.27.4.tar.gz
pkgs/4-rebootstrap-using-nix.pkg: downloads/Python-3.12.0.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/llvm-project-17.0.1.src.tar.xz
pkgs/4-rebootstrap-using-nix.pkg: downloads/busybox-1.36.1.tar.bz2

pkgs/5-go-beyond-using-nix.pkg: pkgs/2b0-musl.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/2b1-clang.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/2b2-busybox.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-boost.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-pkg-config.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-sqlite.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-curl.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-editline.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-brotli.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-seccomp.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-libarchive.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-libsodium.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-lowdown.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3a-nlohmann-json.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3b-tinycc-static.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3b-busybox-static.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/3b-nix.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/4-rebootstrap-using-nix.pkg
###
pkgs/5-go-beyond-using-nix.pkg: stage/protosrc
###
pkgs/5-go-beyond-using-nix.pkg: recipes/1-stage1.c
pkgs/5-go-beyond-using-nix.pkg: recipes/1-stage1/seed.host-executed.sh
pkgs/5-go-beyond-using-nix.pkg: recipes/1-stage1/syscall.h
pkgs/5-go-beyond-using-nix.pkg: recipes/1-stage1/protobusybox.c
pkgs/5-go-beyond-using-nix.pkg: recipes/1-stage1/protobusybox.h
pkgs/5-go-beyond-using-nix.pkg: recipes/1-stage1/hello.c
###
pkgs/5-go-beyond-using-nix.pkg: default.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/1-stage1.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a0-static-gnumake.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a1-static-binutils.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a2-static-gnugcc4-c.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a3-intermediate-musl.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a4-gnugcc4-cpp.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a5-gnugcc10.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a6-linux-headers.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a7-cmake.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a8-python.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2a9-intermediate-clang.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2b0-musl.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2b1-clang.nix
pkgs/5-go-beyond-using-nix.pkg: using-nix/2b2-busybox.nix
###
pkgs/5-go-beyond-using-nix.pkg: downloads/make-4.4.1.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/binutils-2.39.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/gcc-4.7.4.tar.bz2
pkgs/5-go-beyond-using-nix.pkg: downloads/gmp-4.3.2.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/mpfr-2.4.2.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/mpc-0.8.1.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/musl-1.2.4.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/gcc-10.5.0.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/gmp-6.1.0.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/mpfr-3.1.4.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/mpc-1.0.3.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/isl-0.18.tar.bz2
pkgs/5-go-beyond-using-nix.pkg: downloads/linux-6.4.12.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/cmake-3.27.4.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/Python-3.11.5.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/llvm-project-17.0.1.src.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/curl-8.2.1.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/mbedtls-3.4.1.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/boost_1_83_0.tar.bz2
pkgs/5-go-beyond-using-nix.pkg: downloads/editline-1.17.1.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/brotli-1.0.9.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/gperf-3.1.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/libsodium-1.0.18.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/libarchive-3.7.1.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/lowdown-1.0.2.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/libseccomp-2.5.4.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/nlohmann-json-3.11.2.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/nix-2.17.0-zilched.tar.xz
pkgs/5-go-beyond-using-nix.pkg: flake.nix
pkgs/5-go-beyond-using-nix.pkg: downloads/queue.h
pkgs/5-go-beyond-using-nix.pkg: downloads/ZilchOS-core-2023.10.1.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/limine-5.20230830.0.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/patchelf-0.18.0.tar.bz2
pkgs/5-go-beyond-using-nix.pkg: downloads/pkg-config-0.29.2.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/sqlite-autoconf-3430000.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/bison-3.8.2.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/m4-1.4.19.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/flex-2.6.4.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/mtools-4.0.43.tar.bz2
pkgs/5-go-beyond-using-nix.pkg: downloads/xorriso-1.5.6.pl02.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/nasm-2.16.01.tar.xz
pkgs/5-go-beyond-using-nix.pkg: downloads/zstd-1.5.5.tar.gz
pkgs/5-go-beyond-using-nix.pkg: downloads/cacert-2023-08-22.pem

iso: ZilchOS-core.iso

ZilchOS-core.iso: pkgs/5-go-beyond-using-nix.pkg
	tar --strip-components=2 -xf pkgs/5-go-beyond-using-nix.pkg \
		store/5-go-beyond-using-nix/ZilchOS-core.iso
	sha256sum -c <<<"$(ISO_CHECKSUM) ZilchOS-core.iso"

################################################################################

# Separate one for tests to help readability of the above

pkgs/_1.test.pkg: pkgs/1-stage1.pkg

pkgs/_2a3.test.pkg: pkgs/1-stage1.pkg
pkgs/_2a3.test.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/_2a3.test.pkg: pkgs/2a1-static-binutils.pkg
pkgs/_2a3.test.pkg: pkgs/2a2-static-gnugcc4-c.pkg
pkgs/_2a3.test.pkg: pkgs/2a3-intermediate-musl.pkg

pkgs/_2a4.test.pkg: pkgs/1-stage1.pkg
pkgs/_2a4.test.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/_2a4.test.pkg: pkgs/2a1-static-binutils.pkg
pkgs/_2a4.test.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/_2a4.test.pkg: pkgs/2a4-gnugcc4-cpp.pkg

pkgs/_2a5.test.pkg: pkgs/1-stage1.pkg
pkgs/_2a5.test.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/_2a5.test.pkg: pkgs/2a1-static-binutils.pkg
pkgs/_2a5.test.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/_2a5.test.pkg: pkgs/2a5-gnugcc10.pkg

pkgs/_2a9.test.pkg: pkgs/1-stage1.pkg
pkgs/_2a9.test.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/_2a9.test.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/_2a9.test.pkg: pkgs/2a9-intermediate-clang.pkg

pkgs/_2b1.test.pkg: pkgs/1-stage1.pkg
pkgs/_2b1.test.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/_2b1.test.pkg: pkgs/2b0-musl.pkg
pkgs/_2b1.test.pkg: pkgs/2b1-clang.pkg

pkgs/_3b.test.pkg: pkgs/2b0-musl.pkg
pkgs/_3b.test.pkg: pkgs/2b1-clang.pkg
pkgs/_3b.test.pkg: pkgs/2b2-busybox.pkg
pkgs/_3b.test.pkg: pkgs/3a-boost.pkg
pkgs/_3b.test.pkg: pkgs/3a-pkg-config.pkg
pkgs/_3b.test.pkg: pkgs/3a-sqlite.pkg
pkgs/_3b.test.pkg: pkgs/3a-curl.pkg
pkgs/_3b.test.pkg: pkgs/3a-editline.pkg
pkgs/_3b.test.pkg: pkgs/3a-brotli.pkg
pkgs/_3b.test.pkg: pkgs/3a-seccomp.pkg
pkgs/_3b.test.pkg: pkgs/3a-libarchive.pkg
pkgs/_3b.test.pkg: pkgs/3a-libsodium.pkg
pkgs/_3b.test.pkg: pkgs/3a-lowdown.pkg
pkgs/_3b.test.pkg: pkgs/3b-nix.pkg

all-tests: pkgs/_1.test.pkg
all-tests: pkgs/_2a3.test.pkg
all-tests: pkgs/_2a4.test.pkg
all-tests: pkgs/_2a5.test.pkg
all-tests: pkgs/_2a9.test.pkg
all-tests: pkgs/_2b1.test.pkg
all-tests: pkgs/_3b.test.pkg

################################################################################

.PHONY: all-pkgs
all-pkgs: pkgs/0-tcc-seed.pkg
all-pkgs: pkgs/1-stage1.pkg
all-pkgs: pkgs/2a0-static-gnumake.pkg
all-pkgs: pkgs/2a1-static-binutils.pkg
all-pkgs: pkgs/2a2-static-gnugcc4-c.pkg
all-pkgs: pkgs/2a3-intermediate-musl.pkg
all-pkgs: pkgs/2a4-gnugcc4-cpp.pkg
all-pkgs: pkgs/2a5-gnugcc10.pkg
all-pkgs: pkgs/2a6-linux-headers.pkg
all-pkgs: pkgs/2a7-cmake.pkg
all-pkgs: pkgs/2a8-python.pkg
all-pkgs: pkgs/2a9-intermediate-clang.pkg
all-pkgs: pkgs/2b0-musl.pkg
all-pkgs: pkgs/2b1-clang.pkg
all-pkgs: pkgs/2b2-busybox.pkg
all-pkgs: pkgs/2b3-gnumake.pkg
all-pkgs: pkgs/3a-sqlite.pkg
all-pkgs: pkgs/3a-boost.pkg
all-pkgs: pkgs/3a-mbedtls.pkg
all-pkgs: pkgs/3a-pkg-config.pkg
all-pkgs: pkgs/3a-curl.pkg
all-pkgs: pkgs/3a-editline.pkg
all-pkgs: pkgs/3a-brotli.pkg
all-pkgs: pkgs/3a-gnugperf.pkg
all-pkgs: pkgs/3a-seccomp.pkg
all-pkgs: pkgs/3a-libarchive.pkg
all-pkgs: pkgs/3a-libsodium.pkg
all-pkgs: pkgs/3a-lowdown.pkg
all-pkgs: pkgs/3a-nlohmann-json.pkg
all-pkgs: pkgs/3b-busybox-static.pkg
all-pkgs: pkgs/3b-tinycc-static.pkg
all-pkgs: pkgs/3b-nix.pkg
all-pkgs: pkgs/4-rebootstrap-using-nix.pkg
all-pkgs: pkgs/5-go-beyond-using-nix.pkg

################################################################################

ifeq ($(USE_CCACHE), 1)
pkgs/2a1-static-binutils.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a2-static-gnugcc4-c.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a3-intermediate-musl.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a4-gnugcc4-cpp.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a5-gnugcc10.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a6-linux-headers.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a7-cmake.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a8-python.pkg: pkgs/_2a0-ccache.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/_2a0-ccache.pkg
pkgs/2b0-musl.pkg: pkgs/_2a0-ccache.pkg
pkgs/2b1-clang.pkg: pkgs/_2a0-ccache.pkg
pkgs/2b2-busybox.pkg: pkgs/_2a0-ccache.pkg
pkgs/2b3-gnumake.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-sqlite.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-boost.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-mbedtls.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-pkg-config.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-curl.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-editline.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-brotli.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-gnugperf.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-seccomp.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-libarchive.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-libsodium.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-lowdown.pkg: pkgs/_2a0-ccache.pkg
pkgs/3b-busybox-static.pkg: pkgs/_2a0-ccache.pkg
pkgs/3b-tinycc-static.pkg: pkgs/_2a0-ccache.pkg
pkgs/3b-nix.pkg: pkgs/_2a0-ccache.pkg
pkgs/4-rebootstrap-using-nix.pkg: pkgs/_2a0-ccache.pkg
pkgs/5-go-beyond-using-nix.pkg: pkgs/_2a0-ccache.pkg
endif

################################################################################

.PHONY: verify-pkgs-checksums verify-all-pkgs-checksums update-pkgs-checksums
verify-pkgs-checksums:
	@status=true; \
	while read expected_csum pkgname; do \
		pkg=$${pkgname%%.tar}.pkg; \
		if [[ ! -e "$$pkg" ]]; then \
			status=false; \
			echo "MISSING $$pkgname"; \
			continue; \
		fi; \
		computed_csum=$$(zstd -qcd "$$pkg" | sha256sum); \
		computed_csum=$$(<<<$$computed_csum tr ' ' '\t' | cut -f1); \
		short_csum=$$(<<<$$computed_csum head -c7); \
		if [[ "$$pkg" == pkgs/0-tcc-seed.pkg ]]; then \
			if ! sha256sum -c <<<"$(TCC_CHECKSUM) tcc-seed" \
					>/dev/null; then \
				echo "$$short_csum pkgs/0.tar CUSTOM"; \
				continue; \
			fi; \
		fi; \
		if make -sq "$$pkg"; then \
			dated=''; \
		else \
			status=false; \
			dated=" OUTDATED"; \
		fi; \
		if [[ "$$expected_csum" == "$$computed_csum" ]]; then \
			echo "$$short_csum $$pkgname OK$$dated"; \
		else \
			status=false; \
			echo "$$short_csum $$pkgname NOT OK$$dated"; \
			echo "    computed: $$computed_csum"; \
			echo "    expected: $$expected_csum"; \
		fi; \
	done < verify.pkgs.sha256; $$status\

verify-all-pkgs-checksums: all-pkgs
	$(MAKE) verify-pkgs-checksums

update-pkgs-checksums:
	@:> verify.pkgs.sha256
	@find pkgs | grep '\.pkg$$' | grep -v '\/_' | sort | \
	while read p; do \
		name=$${p%%.pkg}.tar; \
		csum=$$(zstd -qcd "$$p" | sha256sum | tr ' ' '\t' | cut -f1); \
		short_csum=$$(<<<$$csum head -c7); \
		echo "$$csum $$name" >> verify.pkgs.sha256; \
		echo "$$short_csum $$name"; \
	done
verify.pkgs.sha256: all-pkgs update-pkgs-checksums

nix-checksums-stage4: pkgs/4-rebootstrap-using-nix.pkg
	tar tf pkgs/4-rebootstrap-using-nix.pkg store \
		| grep -E 'store/[a-z0-9]{32}-[^/]*/?$$' \
		| sed -E 's|.*/([a-z0-9]{32}-[^/]*)/?|\1|' \
		| sort \
		> nix-checksums-stage4

nix-checksums-stage5: pkgs/5-go-beyond-using-nix.pkg
	tar Oxf pkgs/5-go-beyond-using-nix.pkg \
		store/5-go-beyond-using-nix/hashes \
		> nix-checksums-stage5

verify-all-nix-stage4-checksums: nix-checksums-stage4 verify.nix
	@status=true; \
	while IFS=" " read ref_hash pkg; do \
		if grep -Fq "$$ref_hash-bootstrap" nix-checksums-stage4; then \
			echo "  $$ref_hash $$pkg"; \
		else \
			status=false; \
			echo "! $$ref_hash $$pkg MISSING"; \
		fi; \
	done < verify.nix; $$status

verify-all-nix-stage5-checksums: downloads/ZilchOS-core-2023.10.1.tar.gz
verify-all-nix-stage5-checksums: nix-checksums-stage5 verify.nix
	@status=true; \
	tar -Oxf downloads/ZilchOS-core-2023.10.1.tar.gz \
		--wildcards */.maint/hashes | \
	while IFS=' ' read ref_hash pkg; do \
		stage5_hash=$$(grep " $$pkg$$" nix-checksums-stage5 \
				| sed -E 's|^([a-z0-9]{32}) .*|\1|'); \
		if [[ "$$ref_hash" == "$$stage5_hash" ]]; then \
			echo "  $$ref_hash $$pkg"; \
		else \
			status=false; \
			echo "- $$ref_hash $$pkg"; \
			echo "+ $$stage5_hash $$pkg"; \
		fi; \
	done; $$status
NIX_BUILD_X = nix build --no-warn-dirty --option substitute false --no-link
verify-nix-plain-checksums: verify.nix
	@status=true; \
	while IFS=" " read ref_hash pkg; do \
		plain_hash=$$($(NIX_BUILD_X) ".#$$pkg" --print-out-paths \
				| sed -E 's|.*/([a-z0-9]{32})-.*|\1|'); \
		if [[ "$$ref_hash" == "$$plain_hash" ]]; then \
			echo "  $$ref_hash $$pkg"; \
		else \
			status=false; \
			echo "- $$ref_hash $$pkg"; \
			echo "+ $$plain_hash $$pkg"; \
		fi; \
	done < verify.nix; $$status

verify-all-nix-plain-checksums: verify.nix
	@$(NIX_BUILD_X) '.#toolchain' '.#libc' '.#musl'
	@$(MAKE) verify-nix-plain-checksums

################################################################################

clean-tmp:
	@echo "### Makefile: removing tmp, keeping stage, pkgs and downloads..."
	rm -rf tmp

clean-stage:
	@echo "### Makefile: removing stage, keeping tmp, pkgs and downloads..."
	rm -rf stage

clean:
	@echo "### Makefile: removing stage, tmp, pkgs, iso, keeping downloads..."
	rm -rf stage tmp pkgs \
		nix-checksums-stage4 nix-checksums-stage5 \
		nix-checksums-stage5-custom \
		ZilchOS-core.iso ZilchOS-core-raw.iso

deepclean:
	@echo "### Makefile: removing stage, tmp, pkgs, iso and downloads..."
	rm -rf stage tmp pkgs downloads \
		nix-checksums-stage4 nix-checksums-stage5 \
		nix-checksums-stage5-custom \
		ZilchOS-core.iso ZilchOS-core-raw.iso
