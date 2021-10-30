#!/stage/1/bin/ash
set -uexo pipefail

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

TCC_ARGS='-g -std=c99 -D_XOPEN_SOURCE=700'

sed -i 's|/bin/sh|/stage/1/bin/ash|' src/job.c

ash ./configure \
	--build x86_64-linux \
	--disable-posix-spawn \
	--disable-dependency-tracking \
	CC=/stage/1/bin/tcc \
	LD=/stage/1/bin/tcc \
	CPP='/seed/1/bin/tcc -E'\
	CFLAGS="$TCC_ARGS" \
	CPPFLAGS="$TCC_ARGS -I/stage/1/include/protomusl" \
	LDFLAGS='-static -Wl,-whole-archive -lc' \
	CONFIG_SHELL='/stage/1/bin/ash' \
	SHELL='/stage/1/bin/ash'
# TODO: why the need to specify include dir in CPPFLAGS?

ash ./build.sh

ls -l make
./make --version

cp make /stage/2/bin/gnumake

rm -r /stage/2/tmp

echo '--- stage 2 cutoff point ---'

exec /seed/3/src/stage3.sh

exit 1
