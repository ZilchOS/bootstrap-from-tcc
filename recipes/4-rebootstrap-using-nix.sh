#!/store/2b2-busybox/bin/ash

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/3a-pkg-config/bin"
export PATH="$PATH:/store/3a-sqlite/bin"
export PATH="$PATH:/store/3b-nix/bin"

export SHELL='/store/2b2-busybox/bin/ash'

export PKG_CONFIG_PATH=''
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-sqlite/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-curl/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-editline/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-seccomp/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-libarchive/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-libsodium/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-lowdown/lib/pkgconfig"
LIBDIRS=''
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir sqlite3)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libcurl)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libeditline)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libseccomp)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libarchive)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libsodium)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir lowdown)"
LIBDIRS="$LIBDIRS:/store/3a-boost/lib"
LIBDIRS="$LIBDIRS:/store/2b1-clang/lib"
export LD_LIBRARY_PATH=$LIBDIRS

mkdir -p /tmp/4-rebootstrap-using-nix; cd /tmp/4-rebootstrap-using-nix

echo "### $0: preparing stuff for nix to work..."
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
ln -s /dev/pts/ptmx /dev/ptmx

echo "### $0: faking lots of stuff for nix to work..."
mkdir shelter
export HOME=/tmp/4-rebootstrap-using-nix/shelter
export USER=notauser
echo 'oh come on' >/dev/urandom

echo "### $0: fixing up paths to shell..."
cp -a --reflink=auto /using-nix /default.nix /recipes ./
sed -i 's|/bin/sh|/store/3b-busybox-static/bin/ash|' using-nix/1-stage1.nix

echo "### $0: pointing to local downloads..."
sed -i 's| url =| #remote_url =|' using-nix/*.nix
sed -i 's|# local = \(.*\);|url = "file://\1";|' using-nix/*.nix

if [ -e /prev/nix/store ] && [ -e /prev/nix-db.tar ]; then
	echo "### $0: restoring nix store & db from previous build..."
	mkdir -p /nix
	cp -a --reflink=auto /prev/nix/store /nix
	tar -xf /prev/nix-db.tar -C /
	sqlite3 /nix/var/nix/db/db.sqlite \
		< /nix/var/nix/db/db.sqlite.dump
	rm /nix/var/nix/db/db.sqlite.dump
fi

echo "### $0: writing a 0.nix that simply injects what we've built..."
# Makefile bootstrap injects it as /stage/protosrc, regular --- as /protosrc
[ -e /protosrc ] && PROTOSRC="/protosrc" || PROTOSRC=/stage/protosrc
echo "{ tinycc = /store/3b-tinycc-static/bin/tcc; protosrc = $PROTOSRC; }" \
	> using-nix/0.nix

echo "### $0: rebuilding everything using nix..."
nix-build \
	--extra-experimental-features ca-derivations \
	--option build-users-group '' \
	--option compress-build-log false \
	--no-substitute \
	--cores $NPROC \
	--keep-failed \
	-vvv \
	default.nix
rm -f /dev/urandom
rm /dev/ptmx
umount /dev/pts
umount /dev/pts || true
rm -r /dev/pts
rm -r shelter
rm -rf /build

# this one is special wrt how the results are saved, see Makefile/USE_NIX_CACHE
echo "### $0: exporting resulting /nix/store (reproducible)..."
mkdir -p /store/4-rebootstrap-using-nix/nix
cp -a --reflink=auto /nix/store /store/4-rebootstrap-using-nix/nix/

echo "### $0: exporting /nix/var/nix/db to restore it (non-reproducible)..."
cp /nix/var/nix/db/db.sqlite db.sqlite
sqlite3 db.sqlite 'UPDATE ValidPaths SET registrationTime = 1;'
sqlite3 db.sqlite .dump > /nix/var/nix/db/db.sqlite.dump
tar --exclude nix/var/nix/db/db.sqlite \
	-cf /store/4-rebootstrap-using-nix/nix-db.tar /nix/var/nix/db
rm /nix/var/nix/db/db.sqlite.dump
