#!/1/out/protobusybox/bin/ash
set -uex

export PATH=/1/out/tinycc/wrappers:/1/out/protobusybox/bin


echo 'Hi from stage 2!' | sed s/Hi/Hello/
mkdir -p /2/out /2/tmp
mkdir -p /dev; :>/dev/null


echo 'Preparing to build make twice over'
rm -rf /2/tmp/protognumake /2/tmp/gnumake

echo 'Building protognumake'
cp -ra /2/src/gnumake /2/tmp/protognumake
cd /2/tmp/protognumake
# FIXME this is part of stdlib, no idea how it's supposed to not clash
rm src/getopt.h
for f in src/getopt.c src/getopt1.c; do :> $f; done
for f in lib/fnmatch.c lib/glob.c lib/xmalloc.c lib/error.c; do :> $f; done
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' src/job.c
ash ./configure \
	--build x86_64-linux \
	--disable-posix-spawn \
	--disable-dependency-tracking \
	CONFIG_SHELL='/1/out/protobusybox/bin/ash' \
	SHELL='/1/out/protobusybox/bin/ash'
ash ./build.sh
./make --version

echo 'Building gnumake with protognumake'
cp -ra /2/src/gnumake /2/tmp/gnumake
cd /2/tmp/gnumake
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' src/job.c build-aux/install-sh
ash ./configure \
	--build x86_64-linux \
	--disable-posix-spawn \
	--disable-dependency-tracking \
	CONFIG_SHELL='/1/out/protobusybox/bin/ash' \
	SHELL='/1/out/protobusybox/bin/ash'
/2/tmp/protognumake/make
mkdir -p /2/out/gnumake/bin
cp make /2/out/gnumake/bin/gnumake

echo 'Cleaning up stage 2'
rm -r /2/tmp
echo '--- stage 2 cutoff point ---'
exec /3/src/stage3.sh
exit 99
