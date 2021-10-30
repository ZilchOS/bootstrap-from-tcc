#!/stage/1/bin/ash
set -uexo pipefail

export PATH=/stage/1/bin


echo 'Hi from stage 2!' | sed s/Hi/Hello/
mkdir -p /stage/2/bin
mkdir -p /dev; :>/dev/null

echo 'Creating wrappers for tcc'
mkdir -p /stage/2/wrappers/tcc
cd /stage/2/wrappers/tcc
_TCC_ARGS='-g'
_CPP_ARGS="$_TCC_ARGS -I/stage/1/include/protomusl"
_LD_ARGS='-static'
echo -e "#!/stage/1/bin/ash\nexec /stage/1/bin/tcc $_TCC_ARGS $_LD_ARGS \"\$@\"" > cc
echo -e "#!/stage/1/bin/ash\nexec /stage/1/bin/tcc -E $_CPP_ARGS \"\$@\"" > cpp
echo -e "#!/stage/1/bin/ash\nexec /stage/1/bin/tcc $_LD_ARGS \"\$@\"" > ld
echo -e "#!/stage/1/bin/ash\nexec /stage/1/bin/tcc -ar \"\$@\"" > ar
chmod +x cc cpp ld ar

export PATH=/stage/2/wrappers/tcc:/stage/1/bin

echo 'Building gnumake'
rm -rf /stage/2/tmp/gnumake
mkdir -p /stage/2/tmp/gnumake
cp -r /seed/2/src/gnumake/* /stage/2/tmp/gnumake/
cd /stage/2/tmp/gnumake

# this is part of stdlib, no idea how it's supposed to not clash
rm src/getopt.h
for f in src/getopt.c src/getopt1.c; do :> $f; done
for f in lib/fnmatch.c lib/glob.c lib/xmalloc.c lib/error.c; do :> $f; done

sed -i 's|/bin/sh|/stage/1/bin/ash|' src/job.c

ash ./configure \
	--build x86_64-linux \
	--disable-posix-spawn \
	--disable-dependency-tracking \
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
