# First-time readers, refer to `build.sh` instead, it's more clear.
#
# This Makefile is optional and is all to aid debugging and add extra isolation.
#
# None of what's below in this Makefile is needed to build the project.

all:
	@echo 'This Makefile is for debugging purposes, use ./build.sh'
	exit 1

all-at-once: build.sh seed.sh download.sh recipes/*.sh recipes/*/*
	./build.sh

all-with-make: all-pkgs all-tests verify-all-pkgs-checksums

################################################################################

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:  # if only it also worked for dirs, see helpers/inject
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.PHONY: all all-at-once all-with-make clean-stage clean deepclean
NPROC ?= -j1 # for inner make invocations, one can pass -j# this way
USE_CCACHE ?= 0  # for faster iterative debugging only

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

TCC_CHECKSUM=46c35b3fbc8e0f432596349a48d4c8f5485902db73d0afbafef2a7bc1c2d3f39
tcc-seed: recipes/0-tcc-seed/patched.nix
	@echo '### Makefile: you are supposed to supply a trusted tcc-seed'
	@echo '### Makefile: since you have not, building one from nixpkgs...'
	cat $$(nix-build --no-out-link recipes/0-tcc-seed/patched.nix)/bin/tcc \
		> tcc-seed
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
pkgs/1-stage1.pkg: downloads/musl-1.2.2.tar.gz
pkgs/1-stage1.pkg: downloads/tinycc-mob-gitda11cf6.tar.gz
pkgs/1-stage1.pkg: downloads/busybox-1.34.1.tar.bz2
	@echo "### Makefile: creating a temporary build area tmp/build/1..."
	rm -rf tmp/build/1-stage1; mkdir -p tmp/build/1-stage1
	@echo "### Makefile: injecting dependencies..."
	helpers/inject tmp/build/1-stage1 $^
	@echo "### Makefile: seeding special stage 1 (and patching sources)..."
	DESTDIR=tmp/build/1-stage1 recipes/1-stage1/seed.host-executed.sh
	@echo "### Makefile: special stage 1: executing stage1.c with tcc-seed"
	set +e; \
		env -i unshare -nr chroot ./tmp/build/1-stage1 \
			/store/0-tcc-seed -nostdinc -nostdlib -Werror \
				-run recipes/1-stage1.c; \
		EXIT_CODE=$$?; \
	set -e; [[ $${EXIT_CODE} == 99 ]] \
	### expecting 99, which means "all OK except for exec into next stage"
	$(TAR_REPR) -Izstd -cf pkgs/1-stage1.pkg -C tmp/build/1-stage1 \
		store/1-stage1
	rm -rf tmp/build/1-stage1
	@echo "### Makefile: 1-stage1 has been built as pkgs/1-stage1.pkg"

# Consequent stages split up into packages have it simpler:
pkgs/%.pkg: recipes/%.sh
	@echo "### Makefile: creating a temporary build area tmp/build/$*..."
	rm -rf "tmp/build/$*"; mkdir -p "tmp/build/$*"
	helpers/inject "tmp/build/$*" $^
ifeq ($(USE_CCACHE), 1)
	@echo "### Makefile: unpacking ccache from previous builds $*..."
	mkdir -p "tmp/build/$*/ccache"
	[[ ! -e "tmp/ccache/$*.tar.zstd" ]] || \
		tar -Izstd -xf "tmp/ccache/$*.tar.zstd" -C "tmp/build/$*/ccache"
endif
	@echo "### Makefile: building $*"
	env \
		DESTDIR="./tmp/build/$*" \
		NPROC="$(NPROC)" \
		SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)" \
		./helpers/chroot "/recipes/$*.sh"
	@echo "### Makefile: packing up $*"
	$(TAR_REPR) -Izstd -cf "pkgs/$*.pkg" -C "tmp/build/$*" "store/$*"
ifeq ($(USE_CCACHE), 1)
	if ! rmdir "tmp/build/$*/ccache" 2>/dev/null; then \
		mkdir -p tmp/ccache; \
		unshare -nr chroot "tmp/build/$*" \
			/store/_2a0-ccache/bin/ccache -sz; \
		$(TAR_REPR) -Izstd -cf "tmp/ccache/$*.tar.zstd" \
			-C "tmp/build/$*/ccache" .; \
	fi
endif
	@echo "### Makefile: cleaning up after $*"
	rm -rf "tmp/build/$*"
	@echo "### Makefile: $* has been built as pkgs/$*.pkg"

# Dependency graph:

pkgs/2a0-static-gnumake.pkg: pkgs/1-stage1.pkg
pkgs/2a0-static-gnumake.pkg: downloads/make-4.3.tar.gz

ifeq ($(USE_CCACHE), 1)
pkgs/_2a0-ccache.pkg: pkgs/1-stage1.pkg
pkgs/_2a0-ccache.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/_2a0-ccache.pkg: downloads/ccache-3.7.12.tar.xz
endif

pkgs/2/01-gnumake.pkg: pkgs/1-stage1.pkg
pkgs/2/01-gnumake.pkg: pkgs/2/00-intermediate-gnumake.pkg
pkgs/2/01-gnumake.pkg: downloads/make-4.3.tar.gz

pkgs/2a1-static-binutils.pkg: pkgs/1-stage1.pkg
pkgs/2a1-static-binutils.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a1-static-binutils.pkg: downloads/binutils-2.37.tar.xz

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
pkgs/2a3-intermediate-musl.pkg: downloads/musl-1.2.2.tar.gz

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
pkgs/2a5-gnugcc10.pkg: downloads/gcc-10.3.0.tar.xz
pkgs/2a5-gnugcc10.pkg: downloads/gmp-6.1.0.tar.xz
pkgs/2a5-gnugcc10.pkg: downloads/mpc-1.0.3.tar.gz
pkgs/2a5-gnugcc10.pkg: downloads/mpfr-3.1.4.tar.xz
pkgs/2a5-gnugcc10.pkg: downloads/isl-0.18.tar.bz2

pkgs/2a6-linux-headers.pkg: pkgs/1-stage1.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a6-linux-headers.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a6-linux-headers.pkg: downloads/linux-5.15.tar.xz

pkgs/2a7-cmake.pkg: pkgs/1-stage1.pkg
pkgs/2a7-cmake.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a7-cmake.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a7-cmake.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a7-cmake.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a7-cmake.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2a7-cmake.pkg: downloads/cmake-3.21.4.tar.gz

pkgs/2a8-python.pkg: pkgs/1-stage1.pkg
pkgs/2a8-python.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a8-python.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a8-python.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a8-python.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a8-python.pkg: downloads/Python-3.10.0.tar.xz

pkgs/2a9-intermediate-clang.pkg: pkgs/1-stage1.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a5-gnugcc10.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a7-cmake.pkg
pkgs/2a9-intermediate-clang.pkg: pkgs/2a8-python.pkg
pkgs/2a9-intermediate-clang.pkg: downloads/llvm-project-13.0.0.src.tar.xz

pkgs/2b0-musl.pkg: pkgs/1-stage1.pkg
pkgs/2b0-musl.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b0-musl.pkg: pkgs/2a1-static-binutils.pkg
pkgs/2b0-musl.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2b0-musl.pkg: pkgs/2a9-intermediate-clang.pkg
pkgs/2b0-musl.pkg: downloads/musl-1.2.2.tar.gz

pkgs/2b1-clang.pkg: pkgs/1-stage1.pkg
pkgs/2b1-clang.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b1-clang.pkg: pkgs/2a3-intermediate-musl.pkg
pkgs/2b1-clang.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2b1-clang.pkg: pkgs/2a7-cmake.pkg
pkgs/2b1-clang.pkg: pkgs/2a8-python.pkg
pkgs/2b1-clang.pkg: pkgs/2a9-intermediate-clang.pkg
pkgs/2b1-clang.pkg: pkgs/2b0-musl.pkg
pkgs/2b1-clang.pkg: downloads/llvm-project-13.0.0.src.tar.xz

pkgs/2b2-busybox.pkg: pkgs/1-stage1.pkg
pkgs/2b2-busybox.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b2-busybox.pkg: pkgs/2b0-musl.pkg
pkgs/2b2-busybox.pkg: pkgs/2b1-clang.pkg
pkgs/2b2-busybox.pkg: pkgs/2a6-linux-headers.pkg
pkgs/2b2-busybox.pkg: downloads/busybox-1.34.1.tar.bz2

pkgs/2b3-gnumake.pkg: pkgs/2a0-static-gnumake.pkg
pkgs/2b3-gnumake.pkg: pkgs/2b0-musl.pkg
pkgs/2b3-gnumake.pkg: pkgs/2b1-clang.pkg
pkgs/2b3-gnumake.pkg: pkgs/2b2-busybox.pkg
pkgs/2b3-gnumake.pkg: downloads/make-4.3.tar.gz

pkgs/3a-patchelf.pkg: pkgs/2b0-musl.pkg
pkgs/3a-patchelf.pkg: pkgs/2b1-clang.pkg
pkgs/3a-patchelf.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-patchelf.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-patchelf.pkg: downloads/patchelf-0.13.tar.bz2

pkgs/3a-gnubash.pkg: pkgs/2b0-musl.pkg
pkgs/3a-gnubash.pkg: pkgs/2b1-clang.pkg
pkgs/3a-gnubash.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-gnubash.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-gnubash.pkg: downloads/bash-5.1.8.tar.gz

pkgs/3a-sqlite.pkg: pkgs/2b0-musl.pkg
pkgs/3a-sqlite.pkg: pkgs/2b1-clang.pkg
pkgs/3a-sqlite.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-sqlite.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-sqlite.pkg: downloads/sqlite-autoconf-3360000.tar.gz

pkgs/3a-boost.pkg: pkgs/2b0-musl.pkg
pkgs/3a-boost.pkg: pkgs/2b1-clang.pkg
pkgs/3a-boost.pkg: pkgs/2b2-busybox.pkg
pkgs/3a-boost.pkg: pkgs/2b3-gnumake.pkg
pkgs/3a-boost.pkg: pkgs/2a6-linux-headers.pkg
pkgs/3a-boost.pkg: downloads/boost_1_77_0.tar.bz2
################################################################################

# Separate one for tests to help readability of the above

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

all-tests: pkgs/_2a3.test.pkg
all-tests: pkgs/_2a4.test.pkg
all-tests: pkgs/_2a5.test.pkg
all-tests: pkgs/_2a9.test.pkg
all-tests: pkgs/_2b1.test.pkg

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
all-pkgs: pkgs/3a-patchelf.pkg
all-pkgs: pkgs/3a-gnubash.pkg
all-pkgs: pkgs/3a-sqlite.pkg
all-pkgs: pkgs/3a-boost.pkg

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
pkgs/3a-patchelf.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-gnubash.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-sqlite.pkg: pkgs/_2a0-ccache.pkg
pkgs/3a-boost.pkg: pkgs/_2a0-ccache.pkg
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

################################################################################

clean-tmp:
	@echo "### Makefile: removing tmp, keeping stage, pkgs and downloads..."
	rm -rf tmp

clean-stage:
	@echo "### Makefile: removing stage, keeping tmp, pkgs and downloads..."
	rm -rf stage

clean:
	@echo "### Makefile: removing stage, tmp, pkgs, keeping downloads..."
	rm -rf stage tmp pkgs

deepclean:
	@echo "### Makefile: removing stage, tmp, pkgs and downloads..."
	rm -rf tmp pkgs downloads
