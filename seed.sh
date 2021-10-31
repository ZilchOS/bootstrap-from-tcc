#!/usr/bin/env bash

# Creates stage dir and its directory structure.
# Seeds stage dir with the sources from downloads/
# Post-processes stage 0 ones a bit (uses host sed, cp)

set -uex

STAGENO=${1:-ALL}
STAGEDIR=${2:-stage}


## stage 0: just tcc ###########################################################

if [[ $STAGENO == ALL || $STAGENO == 0 ]]; then
	mkdir -p $STAGEDIR/0/out
	# Seed the only input binary we need
	cp tcc-seed $STAGEDIR/0/out/tcc-seed
fi


## stage 1: protomusl, tinycc, protobusybox, all patched #######################

if [[ $STAGENO == ALL || $STAGENO == 1 ]]; then
	mkdir -p $STAGEDIR/1/src/{protomusl,hello,tinycc,protobusybox}
	cp hello.c $STAGEDIR/1/src/hello/
	tar -C $STAGEDIR/1/src/protomusl --strip-components=1 \
		-xzf downloads/musl-1.2.2.tar.gz
	tar -C $STAGEDIR/1/src/tinycc --strip-components=1 \
		-xzf downloads/tinycc-mob-gitda11cf6.tar.gz
	tar -C $STAGEDIR/1/src/protobusybox --strip-components=1 \
		-xjf downloads/busybox-1.34.1.tar.bz2

	# Seed extra sources from this repository
	cp stage1.c hello.c $STAGEDIR/1/src/
	cp syscall.h $STAGEDIR/1/src/  # dual-role: protomusl and stage1.c
	cp protobusybox.[ch] $STAGEDIR/1/src/

	# Code host-processing hacks and workarounds, stage 1 only
	pushd $STAGEDIR/1/src/protomusl/
		# original syscall_arch.h is not tcc-compatible,
		# the syscall.h we use is dual-role
		cp ../syscall.h arch/x86_64/syscall_arch.h
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
		rm src/signal/restore.c  # *BIG URGH*
		rm src/thread/__set_thread_area.c  # possible double-define
		rm src/thread/__unmapself.c  # double-define
		rm src/math/sqrtl.c  # tcc-incompatible
		rm src/math/{acoshl,acosl,asinhl,asinl,hypotl}.c  # want sqrtl
	popd

	pushd $STAGEDIR/1/src/tinycc
		:> config.h
		sed -i 's/abort();//' lib/va_list.c  # break circular dependency
	popd

	pushd $STAGEDIR/1/src/protobusybox
		:> include/NUM_APPLETS.h
		:> include/common_bufsiz.h
		# already fixed in an unreleased version
		sed -i 's/extern struct test_statics \*const test_ptr_to_statics/extern struct test_statics *BB_GLOBAL_CONST test_ptr_to_statics/' coreutils/test.c
	popd
fi


## stage 2: gnumake, ??? #######################################################

if [[ $STAGENO == ALL || $STAGENO == 2 ]]; then
	mkdir -p $STAGEDIR/2/src/gnumake
	tar -C $STAGEDIR/2/src/gnumake --strip-components=1 -xzf \
		downloads/make-4.3.tar.gz
	cp stage2.sh $STAGEDIR/2/src/
fi


## stage 3: ??? ################################################################

if [[ $STAGENO == ALL || $STAGENO == 3 ]]; then
	mkdir -p $STAGEDIR/3/src
	cp stage3.sh $STAGEDIR/3/src/
fi

exit 0
