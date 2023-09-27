#!/usr/bin/env bash

# 1st stage is special
# in that we don't have any semblance of a system to start with,
# meaning we can't even unpack sources, let alone patch them or something.
# For stage 1, we pre-unpack sources on the host and then fix them up with
# host's sed.

#> FETCH 7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039
#>  FROM http://musl.libc.org/releases/musl-1.2.4.tar.gz

#> FETCH f5a71d05664340ae46cda9579c6079a0f2fa809d24386d284f0d091e4d576a4e
#>  FROM https://github.com/TinyCC/tinycc/archive/af1abf1f45d45b34f0b02437f559f4dfdba7d23c.tar.gz
#>    AS tinycc-mob-af1abf1.tar.gz

#> FETCH b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314
#>  FROM https://busybox.net/downloads/busybox-1.36.1.tar.bz2

set -ueo pipefail
TGT="$DESTDIR/tmp/1-stage1"

echo "### $0: unpacking protomusl sources..."
mkdir -p "$DESTDIR/protosrc/protomusl"
tar --strip-components=1 -xzf downloads/musl-1.2.4.tar.gz \
	-C "$DESTDIR/protosrc/protomusl"

echo "### $0: unpacking tinycc sources..."
mkdir -p "$DESTDIR/protosrc/tinycc"
tar --strip-components=1 -xzf downloads/tinycc-mob-af1abf1.tar.gz \
	-C $DESTDIR/protosrc/tinycc

echo "### $0: unpacking protobusybox sources..."
mkdir -p "$DESTDIR/protosrc/protobusybox"
tar --strip-components=1 -xjf downloads/busybox-1.36.1.tar.bz2 \
	-C "$DESTDIR/protosrc/protobusybox"

echo "### $0: patching up protomusl stage 1 sources..."
# original syscall_arch.h is not tcc-compatible, our syscall.h is dual-role
cp recipes/1-stage1/syscall.h \
	"$DESTDIR/protosrc/protomusl/arch/x86_64/syscall_arch.h"
pushd "$DESTDIR/protosrc/protomusl/" >/dev/null
	# eliminiate a source path reference
	sed -i 's/__FILE__/"__FILE__"/' include/assert.h
	# two files have to be generated with host sed
	mkdir -p host-generated/{sed1,sed2}/bits
	sed -f ./tools/mkalltypes.sed \
		./arch/x86_64/bits/alltypes.h.in \
		./include/alltypes.h.in \
		> host-generated/sed1/bits/alltypes.h
	sed -n -e s/__NR_/SYS_/p \
		< arch/x86_64/bits/syscall.h.in \
		> host-generated/sed2/bits/syscall.h
	# more frivolous patching
	echo '#define VERSION "1.2.2"' > src/internal/version.h
	sed -i 's/@PLT//' src/signal/x86_64/sigsetjmp.s
	rm -f src/signal/restore.c  # *BIG URGH*
	rm -f src/thread/clone.c  # *BIG URGH #2*
	rm -f src/thread/__set_thread_area.c  # possible double-define
	rm -f src/thread/__unmapself.c  # double-define
	rm -f src/math/sqrtl.c  # tcc-incompatible
	rm -f src/math/{acoshl,acosl,asinhl,asinl,hypotl}.c  # sqrtl dep
	sed -i 's|posix_spawn(&pid, "/bin/sh",|posix_spawnp(\&pid, "sh",|' \
		src/stdio/popen.c src/process/system.c
	sed -i 's|execl("/bin/sh", "sh", "-c",|execlp("sh", "-c",|'\
		src/misc/wordexp.c
popd >/dev/null

echo "### $0: patching up tinycc stage 1 sources..."
pushd "$DESTDIR/protosrc/tinycc" >/dev/null
	:> config.h
	# eliminate a source path reference
	sed -i 's/__FILE__/"__FILE__"/' tcc.h
	# don't hardcode paths
	sed -i 's/SHN_ABS, filename);/SHN_ABS, "FILE stub");/' tccdbg.c
	# break a circular dependency
	sed -i 's/abort();//' lib/va_list.c
popd >/dev/null

echo "### $0: patching up protobusybox stage 1 sources..."
pushd "$DESTDIR/protosrc/protobusybox" >/dev/null
	:> include/NUM_APPLETS.h
	:> include/common_bufsiz.h
	# eliminate a source path reference
	sed -i 's/__FILE__/"__FILE__"/' miscutils/fbsplash.c include/libbb.h
	# already fixed in an unreleased version
	sed -i 's/extern struct test_statics \*const test_ptr_to_statics/extern struct test_statics *BB_GLOBAL_CONST test_ptr_to_statics/' coreutils/test.c
popd >/dev/null

echo "### $0: done"
