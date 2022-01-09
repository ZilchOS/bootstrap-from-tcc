#!/usr/bin/env bash

# 1st stage is special
# in that we don't have any semblance of a system to start with,
# meaning we can't even unpack sources, let alone patch them or something.
# For stage 1, we pre-unpack sources on the host and then fix them up with
# host's sed.

#> FETCH 9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd
#>  FROM http://musl.libc.org/releases/musl-1.2.2.tar.gz

#> FETCH c6b244e58677c4c486dbf80e35ee01b192e133876942afa07454159ba118b44e
#>  FROM https://github.com/TinyCC/tinycc/archive/da11cf651576f94486dbd043dbfcde469e497574.tar.gz
#>    AS tinycc-mob-gitda11cf6.tar.gz

#> FETCH 415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549
#>  FROM https://busybox.net/downloads/busybox-1.34.1.tar.bz2

set -ueo pipefail
TGT="$DESTDIR/tmp/1-stage1"

echo "### $0: unpacking protomusl sources..."
mkdir -p "$DESTDIR/protosrc/protomusl"
tar --strip-components=1 -xzf downloads/musl-1.2.2.tar.gz \
	-C "$DESTDIR/protosrc/protomusl"

echo "### $0: unpacking tinycc sources..."
mkdir -p "$DESTDIR/protosrc/tinycc"
tar --strip-components=1 -xzf downloads/tinycc-mob-gitda11cf6.tar.gz \
	-C $DESTDIR/protosrc/tinycc

echo "### $0: unpacking protobusybox sources..."
mkdir -p "$DESTDIR/protosrc/protobusybox"
tar --strip-components=1 -xjf downloads/busybox-1.34.1.tar.bz2 \
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
		>> host-generated/sed2/bits/syscall.h
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
	# eliminiate a source path reference
	sed -i 's/__FILE__/"__FILE__"/' tcc.h
	# don't hardcode paths when compiling asm files
	sed -i 's/SHN_ABS, file->filename);/SHN_ABS, "FILE stub");/' tccgen.c
	# break a circular dependency
	sed -i 's/abort();//' lib/va_list.c
popd >/dev/null

echo "### $0: patching up protobusybox stage 1 sources..."
pushd "$DESTDIR/protosrc/protobusybox" >/dev/null
	:> include/NUM_APPLETS.h
	:> include/common_bufsiz.h
	# eliminiate a source path reference
	sed -i 's/__FILE__/"__FILE__"/' miscutils/fbsplash.c include/libbb.h
	# already fixed in an unreleased version
	sed -i 's/extern struct test_statics \*const test_ptr_to_statics/extern struct test_statics *BB_GLOBAL_CONST test_ptr_to_statics/' coreutils/test.c
popd >/dev/null

echo "### $0: done"
