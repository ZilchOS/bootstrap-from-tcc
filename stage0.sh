#!/bin/sh
set -uex

mkdir -p arena/{musl,busybox,linux,make}

[[ ! -e arena/input-tcc ]] && cp input-tcc arena/

cp downloads/va_list.c arena/

tar -C arena/musl --strip-components=1 -xzf downloads/musl-1.2.2.tar.gz
tar -C arena/make --strip-components=1 -xzf downloads/make-4.3.tar.gz
#tar -C arena/busybox --strip-components=1 -xjf downloads/busybox-1.34.1.tar.bz2
#tar -C arena/linux --strip-components=1 -xJf downloads/linux-5.10.74.tar.xz

cp syscall.h arena/musl/arch/x86_64/syscall_arch.h

pushd arena/musl
	mkdir -p stage0-generated/{sed1,sed2,cp}/bits
	sed -f ./tools/mkalltypes.sed \
		./arch/x86_64/bits/alltypes.h.in \
		./include/alltypes.h.in \
		> stage0-generated/sed1/bits/alltypes.h
	cp arch/x86_64/bits/syscall.h.in stage0-generated/cp/bits/syscall.h
	sed -n -e s/__NR_/SYS_/p \
		< arch/x86_64/bits/syscall.h.in \
		>> stage0-generated/sed2/bits/syscall.h


        mkdir -p obj/crt/x86_64
        mkdir -p obj/include/bits
        mkdir -p obj/ldso
        mkdir -p obj/src/{aio,complex,conf,crypt,ctype,dirent,env,errno,exit}
        mkdir -p obj/src/{fctnl/fenv/x86_64,internal,ipc,ldso/x86_64,legacy}
        mkdir -p obj/src/{linux,locale,malloc/mallocng}

        mkdir -p obj/src/{thread,stdio,string,unistd,errno,multibyte,math}
        mkdir -p obj/src/signal

	#mkdir -p include/bits
	#cp arch/generic/bits/* obj/include/bits/
	#cp arch/x86_64/bits/* obj/include/bits/
	#sed -f ./tools/mkalltypes.sed \
	#	./arch/x86_64/bits/alltypes.h.in \
	#	./include/alltypes.h.in \
	#	> include/bits/alltypes.h
	#cp arch/x86_64/bits/syscall.h.in include/bits/syscall.h
	#sed -n -e s/__NR_/SYS_/p \
	#	< arch/x86_64/bits/syscall.h.in \
	#	>> include/bits/syscall.h
popd
