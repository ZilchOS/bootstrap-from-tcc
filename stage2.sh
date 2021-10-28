#!/stage/1/bin/ash
set -uex

export PATH=/stage/1/bin


echo 'Hi from stage 2!' | sed s/Hi/Hello/

mkdir -p /stage/2/bin

mkdir -p /dev; :>/dev/null

rm -rf /stage/2/tmp/gnumake
mkdir -p /stage/2/tmp/gnumake
cp -r /seed/2/src/gnumake/* /stage/2/tmp/gnumake/
cd /stage/2/tmp/gnumake

# this is part of stdlib, no idea how it's supposed to not clash
rm src/getopt.h
:> src/getopt.c
:> src/getopt1.c
:> lib/fnmatch.c
:> lib/glob.c
:> lib/xmalloc.c
:> lib/error.c

TCC_ARGS='-g -nostdlib -nostdinc -std=c99 -D_XOPEN_SOURCE=700'
CFLAGS='-I/stage/1/usr/include/protomusl/'
LDFLAGS='-static -Wl,-whole-archive'
LDFLAGS="$LDFLAGS /stage/1/lib/protomusl/libc.a"
LDFLAGS="$LDFLAGS /stage/1/lib/protomusl/crt1.o"


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
		--disable-posix-spawn \
		--disable-dependency-tracking

ash ./build.sh

ls -l make
./make --version

cp make /stage/2/bin/gnumake

rm -r /stage/2/tmp

echo '--- stage 2 cutoff point ---'

exec /seed/3/src/stage3.sh

exit 1
