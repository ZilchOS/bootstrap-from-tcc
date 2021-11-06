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

echo "### $0: unpacking protomusl sources..."
mkdir -p "$DESTDIR/1/src/protomusl"
tar --strip-components=1 -xzf downloads/musl-1.2.2.tar.gz \
	-C "$DESTDIR/1/src/protomusl"

echo "### $0: unpacking tinycc sources..."
mkdir -p "$DESTDIR/1/src/tinycc"
tar --strip-components=1 -xzf downloads/tinycc-mob-gitda11cf6.tar.gz \
	-C $DESTDIR/1/src/tinycc

echo "### $0: unpacking protobusybox sources..."
mkdir -p "$DESTDIR/1/src/protobusybox"
tar --strip-components=1 -xjf downloads/busybox-1.34.1.tar.bz2 \
	-C "$DESTDIR/1/src/protobusybox"

echo "### $0: patching up protomusl stage 1 sources..."
# original syscall_arch.h is not tcc-compatible, our syscall.h is dual-role
cp 1/src/syscall.h "$DESTDIR/1/src/protomusl/arch/x86_64/syscall_arch.h"
pushd "$DESTDIR/1/src/protomusl/" >/dev/null
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
	sed -i -e 's|/bin/sh|/usr/bin/env|' \
		-e 's|"sh", "-c"|"/usr/bin/env", "sh", "-c"|' \
		src/stdio/popen.c src/process/system.c
popd >/dev/null

echo "### $0: patching up tinycc stage 1 sources..."
pushd "$DESTDIR/1/src/tinycc" >/dev/null
	:> config.h
	sed -i 's/abort();//' lib/va_list.c  # break circular dependency
popd >/dev/null

echo "### $0: patching up protobusybox stage 1 sources..."
pushd "$DESTDIR/1/src/protobusybox" >/dev/null
	:> include/NUM_APPLETS.h
	:> include/common_bufsiz.h
	#sed -i 's/PACKED/__attribute__((packed))/' archival/libarchive/decompress_gunzip.c
	sed -i 's/BUILD_BUG_ON(sizeof(header) != 8);/BUILD_BUG_ON(sizeof(header) != 8);/' archival/libarchive/decompress_gunzip.c
	# already fixed in an unreleased version
	sed -i 's/extern struct test_statics \*const test_ptr_to_statics/extern struct test_statics *BB_GLOBAL_CONST test_ptr_to_statics/' coreutils/test.c
popd >/dev/null

echo "### $0: done"


### stage 2: gnumake, busybox, gcc ##############################################
#
#if [[ $STAGENO == ALL || $STAGENO == 2 ]]; then
#	untar z downloads/make-4.3.tar.gz $STAGEDIR/2/src/gnumake
#	untar j downloads/busybox-1.34.1.tar.bz2 $STAGEDIR/2/src/busybox
#	untar J downloads/binutils-2.37.tar.xz $STAGEDIR/2/src/binutils
#	untar j downloads/gcc-4.7.4.tar.bz2 $STAGEDIR/2/src/gnugcc4
#	untar j downloads/gmp-4.3.2.tar.bz2 $STAGEDIR/2/src/gnugcc4/gmp
#	untar J downloads/mpfr-2.4.2.tar.xz $STAGEDIR/2/src/gnugcc4/mpfr
#	untar z downloads/mpc-0.8.1.tar.gz $STAGEDIR/2/src/gnugcc4/mpc
#	untar z downloads/musl-1.2.2.tar.gz $STAGEDIR/2/src/musl
#	untar J downloads/linux-5.10.74.tar.xz $STAGEDIR/2/src/linux
#	untar j downloads/busybox-1.34.1.tar.bz2 $STAGEDIR/2/src/busybox
#	cp stage2.sh $STAGEDIR/2/src/
#fi
#
#
### stage 3: ??? ################################################################
#
#if [[ $STAGENO == ALL || $STAGENO == 3 ]]; then
#	mkdir -p $STAGEDIR/3/src
#	cp stage3.sh $STAGEDIR/3/src/
#fi
#
#exit 0
