#!/stage/1/bin/ash
set -uex

export PATH=/stage/1/bin

echo 'Hi from stage 2!' | sed s/Hi/Hello/
ls

mkdir -p /dev; :>/null

rm -rf /stage/2/build/make
mkdir -p /stage/2/build/make
cp -r /seed/2/src/make/* /stage/2/build/make/
cd /stage/2/build/make

# this is part of stdlib, no idea how it's supposed to not clash
rm src/getopt.h
:> src/getopt.c
:> src/getopt1.c
:> lib/fnmatch.c
:> lib/glob.c
:> lib/xmalloc.c
:> lib/error.c

TCC_ARGS='-g -nostdlib -nostdinc -std=c99 -D_XOPEN_SOURCE=700'
INCLUDES='-I/seed/1/src/protomusl/src/include'
INCLUDES="$INCLUDES -I/seed/1/src/protomusl/arch/x86_64"
INCLUDES="$INCLUDES -I/seed/1/src/protomusl/stage0-generated/sed1"
INCLUDES="$INCLUDES -I/seed/1/src/protomusl/stage0-generated/sed2"
INCLUDES="$INCLUDES -I/seed/1/src/protomusl/arch/generic"
INCLUDES="$INCLUDES -I/seed/1/src/protomusl/src/internal"
INCLUDES="$INCLUDES -I/seed/1/src/protomusl/include"
CFLAGS="$INCLUDES"
LDFLAGS='-static -Wl,-whole-archive'
LDFLAGS="$LDFLAGS /stage/1/lib/protomusl.a"
LDFLAGS="$LDFLAGS /stage/1/obj/protomusl/crt/crt1.o"

CC=/seed/1/bin/tcc \
LD=/seed/1/bin/tcc \
CPP="/seed/1/bin/tcc -E" \
CFLAGS="$TCC_ARGS $CFLAGS" \
CPPFLAGS="$TCC_ARGS $CFLAGS" \
LDFLAGS="$LDFLAGS" \
CONFIG_SHELL="/stage/1/bin/ash" \
SHELL="/stage/1/bin/ash" \
	ash ./configure \
		--build x86_64-linux \
		--disable-dependency-tracking

ash ./build.sh

ls -l make
./make --version

exit 0
