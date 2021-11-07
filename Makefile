# First-time readers, refer to `build.sh` instead, it's more clear.
#
# This Makefile is optional and is all to aid debugging and add extra isolation.
#
# None of what's below in this Makefile is needed to build the project.

all:
	@echo 'This Makefile is for debugging purposes, use ./build.sh'
	exit 1

all-at-once: build.sh seed.sh download.sh [012345]/* [012345]/*/*
	./build.sh

all-with-make: 2

################################################################################

# TODO: get rid of helpers/

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:  # if only it also worked for dirs, see helpers/add_to_arena
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.PHONY: all all-at-once all-with-make clean-stage clean deepclean

SOURCE_DATE_EPOCH := 0
TAR := tar
TAR_REPR = ${TAR} --sort=name --mtime="@${SOURCE_DATE_EPOCH}" \
	--owner=0 --group=0 --numeric-owner \
	--pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime

downloads/%:
	@echo "### Makefile: downloading required $*..."
	ONLY="$*" ./download.sh
	[[ -e downloads/$* ]]

################################################################################

TCC_CHECKSUM=46c35b3fbc8e0f432596349a48d4c8f5485902db73d0afbafef2a7bc1c2d3f39
0/tcc-seed: 0/tcc-updated.nix
	@echo "### Makefile: You are supposed to supply a trusted 0/tcc-seed."
	@echo "### Makefile: Since you have not, building one from nixpkgs..."
	cd 0; \
		nix-build tcc-updated.nix; \
		cat result/bin/tcc > tcc-seed; \
		chmod +x tcc-seed; \
		sha256sum -c <<<"$(TCC_CHECKSUM) tcc-seed"; \
		rm result

# Stage 0 is special in that there are no sources, we just add tcc-seed
pkgs/0.pkg: 0/tcc-seed
	@echo "### Makefile: creating a temporary build area tmp/build/0..."
	rm -rf tmp/build/0
	mkdir -p tmp/build/0/0
	@echo "### Makefile: special stage 0: just injecting tcc-seed..."
	mkdir -p tmp/build/0/0/out
	cp 0/tcc-seed tmp/build/0/0/out/
	@echo "### Makefile: packing up pkgs/0.pkg..."
	mkdir -p pkgs
	$(TAR_REPR) -Izstd -cf pkgs/0.pkg -C tmp/build/0 0/out
	rm -rf tmp/build/0
	@echo "### Makefile: 0 has been successfully built as pkgs/0.pkg"

# Stage 1 is special in that:
# * we patch up some sources on the host
# * we have no shell and execute stage1.c with tcc-seed

pkgs/1.pkg: 1/src/stage1.c
pkgs/1.pkg: pkgs/0.pkg
pkgs/1.pkg: 1/seed.host-executed.sh
pkgs/1.pkg: 1/src/syscall.h
pkgs/1.pkg: 1/src/protobusybox.c 1/src/protobusybox.h
pkgs/1.pkg: 1/src/hello.c
pkgs/1.pkg: downloads/musl-1.2.2.tar.gz
pkgs/1.pkg: downloads/tinycc-mob-gitda11cf6.tar.gz
pkgs/1.pkg: downloads/busybox-1.34.1.tar.bz2
	@echo "### Makefile: creating a temporary build area tmp/build/1..."
	rm -rf tmp/build/1; mkdir -p tmp/build/1
	@echo "### Makefile: injecting dependencies..."
	helpers/inject tmp/build/1 $^
	@echo "### Makefile: seeding special stage 1 (and patching sources)..."
	DESTDIR=tmp/build/1 1/seed.host-executed.sh
	@echo "### Makefile: special stage 1: executing stage1.c with tcc-seed"
	set +e; \
		env -i unshare -nrR ./tmp/build/1 \
			/0/out/tcc-seed -nostdinc -nostdlib -Werror \
				-run /1/src/stage1.c; \
		EXIT_CODE=$$?; \
	set -e; [[ $${EXIT_CODE} == 99 ]] \
	### expecting 99, which means "all OK except for exec into next stage"
	$(TAR_REPR) -Izstd -cf pkgs/1.pkg -C tmp/build/1 1/out
	rm -rf tmp/build/1
	@echo "### Makefile: 1 has been built as pkgs/1.pkg"

# Consequent stages split up into packages have it simpler:
pkgs/%.pkg: %.sh
	@echo "### Makefile: creating a temporary build area tmp/build/$*..."
	rm -rf "tmp/build/$*"; mkdir -p "tmp/build/$*"
	helpers/inject "tmp/build/$*" $^
	@echo "### Makefile: stage $*: building"
	env -i unshare -nrR "./tmp/build/$*" "/$*.sh"
	mkdir -p "$(shell dirname "pkgs/$*.pkg")"
	$(TAR_REPR) -Izstd -cf "pkgs/$*.pkg" -C "tmp/build/$*" "$*/out"
	rm -rf "tmp/build/$*"
	@echo "### Makefile: $* has been built as pkgs/$*.pkg"

# Dependency graph:

pkgs/2/00-intermediate-gnumake.pkg: downloads/make-4.3.tar.gz pkgs/1.pkg

pkgs/2/01-gnumake.pkg: downloads/make-4.3.tar.gz
pkgs/2/01-gnumake.pkg: pkgs/1.pkg pkgs/2/00-intermediate-gnumake.pkg

pkgs/2/02-static-binutils.pkg: downloads/binutils-2.37.tar.gz
pkgs/2/02-static-binutils.pkg: pkgs/1.pkg pkgs/2/01-gnumake.pkg

pkgs/2/03-static-gnugcc4.pkg: pkgs/1.pkg
pkgs/2/03-static-gnugcc4.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/03-static-gnugcc4.pkg: pkgs/2/02-static-binutils.pkg
pkgs/2/03-static-gnugcc4.pkg: downloads/gmp-4.3.2.tar.bz2
pkgs/2/03-static-gnugcc4.pkg: downloads/mpfr-2.4.2.tar.gz
pkgs/2/03-static-gnugcc4.pkg: downloads/mpc-0.8.1.tar.gz
pkgs/2/03-static-gnugcc4.pkg: downloads/gcc-4.7.4.tar.gz

pkgs/2/04-musl.pkg: pkgs/1.pkg
pkgs/2/04-musl.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/04-musl.pkg: pkgs/2/02-static-binutils.pkg
pkgs/2/04-musl.pkg: pkgs/2/03-static-gnugcc4.pkg
pkgs/2/04-musl.pkg: downloads/musl-1.2.2.tar.gz

pkgs/2/05-gnugcc4.pkg: pkgs/1.pkg
pkgs/2/05-gnugcc4.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/05-gnugcc4.pkg: pkgs/2/02-static-binutils.pkg
pkgs/2/05-gnugcc4.pkg: pkgs/2/03-static-gnugcc4.pkg
pkgs/2/05-gnugcc4.pkg: pkgs/2/04-musl.pkg
pkgs/2/05-gnugcc4.pkg: downloads/gmp-4.3.2.tar.bz2
pkgs/2/05-gnugcc4.pkg: downloads/mpfr-2.4.2.tar.gz
pkgs/2/05-gnugcc4.pkg: downloads/mpc-0.8.1.tar.gz
pkgs/2/05-gnugcc4.pkg: downloads/gcc-4.7.4.tar.gz

pkgs/2/06-binutils.pkg: pkgs/1.pkg
pkgs/2/06-binutils.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/06-binutils.pkg: pkgs/2/02-static-binutils.pkg
pkgs/2/06-binutils.pkg: pkgs/2/04-musl.pkg
pkgs/2/06-binutils.pkg: pkgs/2/05-gnugcc4.pkg
pkgs/2/06-binutils.pkg: downloads/binutils-2.37.tar.gz

pkgs/2/07-linux-headers.pkg: pkgs/1.pkg
pkgs/2/07-linux-headers.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/07-linux-headers.pkg: pkgs/2/04-musl.pkg
pkgs/2/07-linux-headers.pkg: pkgs/2/05-gnugcc4.pkg
pkgs/2/07-linux-headers.pkg: pkgs/2/06-binutils.pkg
pkgs/2/07-linux-headers.pkg: downloads/linux-5.15.tar.gz

pkgs/2/08-busybox.pkg: pkgs/1.pkg
pkgs/2/08-busybox.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/08-busybox.pkg: pkgs/2/04-musl.pkg
pkgs/2/08-busybox.pkg: pkgs/2/05-gnugcc4.pkg
pkgs/2/08-busybox.pkg: pkgs/2/06-binutils.pkg
pkgs/2/08-busybox.pkg: pkgs/2/07-linux-headers.pkg
pkgs/2/08-busybox.pkg: downloads/busybox-1.34.1.tar.bz2

################################################################################

# Separate one for tests to help readability of the above

pkgs/2/04.test.pkg:
pkgs/2/04.test.pkg: pkgs/1.pkg
pkgs/2/04.test.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/04.test.pkg: pkgs/2/02-static-binutils.pkg
pkgs/2/04.test.pkg: pkgs/2/03-static-gnugcc4.pkg
pkgs/2/04.test.pkg: pkgs/2/04-musl.pkg

pkgs/2/05.test.pkg:
pkgs/2/05.test.pkg: pkgs/1.pkg
pkgs/2/05.test.pkg: pkgs/2/01-gnumake.pkg
pkgs/2/05.test.pkg: pkgs/2/02-static-binutils.pkg
pkgs/2/05.test.pkg: pkgs/2/04-musl.pkg
pkgs/2/05.test.pkg: pkgs/2/05-gnugcc4.pkg

#tests/%: tests/%.sh
#	@echo "### Makefile: creating a temporary test area for $*..."
#	rm -rf "tmp/build/tests/$*"; mkdir -p "tmp/build/tests/$*"
#	helpers/inject "tmp/build/tests/$*" $^
#	@echo "### Makefile: stage $*: building"
#	set +e; env -i unshare -nrR "./tmp/build/tests/$*" "/tests/$*.sh" \
#	set -e; [[ $${EXIT_CODE} == 77 ]]
#	@echo "### Makefile: test $* has passed successfully"

################################################################################

.PHONY: 2
2: pkgs/2/08-busybox.pkg
2: pkgs/2/04.test.pkg
2: pkgs/2/05.test.pkg

################################################################################

clean-tmp:
	@echo "### Makefile: cleaning up tmp, keeping pkgs and downloads..."
	rm -rf tmp

clean:
	@echo "### Makefile: cleaning up tmp and pkgs, keeping downloads..."
	rm -rf tmp pkgs

deepclean:
	@echo "### Makefile: cleaning up tmp, pkgs and downloads..."
	rm -rf tmp pkgs downloads
