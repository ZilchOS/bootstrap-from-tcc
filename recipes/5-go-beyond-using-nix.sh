#!/store/2b2-busybox/bin/ash
#> FETCH ccd7332529ee29615c0e98c7d5067e51ab74b49e14201c814454ad98898fc009
#>  FROM https://github.com/ZilchOS/core/archive/2023.09.1.tar.gz
#>    AS ZilchOS-core-2023.09.1.tar.gz

#> FETCH ddd417f9caab3ef0f3031b938815a5c33367c3a50c09830138d208bd3126c98f
#>  FROM https://github.com/limine-bootloader/limine/releases/download/v5.20230830.0/limine-5.20230830.0.tar.xz

#> FETCH 1952b2a782ba576279c211ee942e341748fdb44997f704dd53def46cd055470b
#>  FROM https://github.com/NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0.tar.bz2

#> FETCH 9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2
#>  FROM https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz

#> FETCH 63aede5c6d33b6d9b13511cd0be2cac046f2e70fd0a07aa9573a04a82783af96
#>  FROM https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz

#> FETCH e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995
#>  FROM https://github.com/westes/flex/files/981163/flex-2.6.4.tar.gz

#> FETCH 541e179665dc4e272b9602f2074243591a157da89cc47064da8c5829dbd2b339
#>  FROM http://ftp.gnu.org/gnu/mtools/mtools-4.0.43.tar.bz2

#> FETCH 786f9f5df9865cc5b0c1fecee3d2c0f5e04cab8c9a859bd1c9c7ccd4964fdae1
#>  FROM https://www.gnu.org/software/xorriso/xorriso-1.5.6.pl02.tar.gz

#> FETCH c77745f4802375efeee2ec5c0ad6b7f037ea9c87c92b149a9637ff099f162558
#>  FROM https://www.nasm.us/pub/nasm/releasebuilds/2.16.01/nasm-2.16.01.tar.xz

#> FETCH 9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4
#>  FROM https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz

#> FETCH 23c2469e2a568362a62eecf1b49ed90a15621e6fa30e29947ded3436422de9b9
#>  FROM https://curl.se/ca/cacert-2023-08-22.pem

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

mkdir -p /tmp/5-go-beyond-using-nix; cd /tmp/5-go-beyond-using-nix

echo "### $0: preparing stuff for nix to work..."
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
ln -s /dev/pts/ptmx /dev/ptmx

echo "### $0: faking lots of stuff for nix to work..."
mkdir shelter
export HOME=/tmp/5-go-beyond-using-nix/shelter
export USER=notauser
echo 'oh come on' >/dev/urandom
printf '\0\0\0\0\0\0\0\0\0\0' > 10x0
cat 10x0 10x0 10x0 10x0 10x0 10x0 10x0 10x0 10x0 10x0 > 100x0
cat 100x0 100x0 100x0 100x0 100x0 100x0 100x0 100x0 100x0 100x0 > 1Kx0
cat 1Kx0 1Kx0 1Kx0 1Kx0 1Kx0 1Kx0 1Kx0 1Kx0 1Kx0 1Kx0 > 10Kx0
cat 10Kx0 10Kx0 10Kx0 10Kx0 10Kx0 10Kx0 10Kx0 10Kx0 10Kx0 10Kx0 > 100Kx0
cat 100Kx0 100Kx0 100Kx0 100Kx0 100Kx0 100Kx0 100Kx0 100Kx0 100Kx0 100Kx0 \
	> 1Mx0
cat 1Mx0 1Mx0 1Mx0 1Mx0 1Mx0 1Mx0 1Mx0 1Mx0 1Mx0 1Mx0 > 10Mx0
mv 10Mx0 /dev/zero
rm *x0

echo "### $0: fixing up paths to shell..."
sed -i 's|/bin/sh|/store/3b-busybox-static/bin/ash|' /using-nix/1-stage1.nix

if [ -e /prev/nix/store ] && [ -e /prev/nix-db.tar ]; then
	echo "### $0: restoring nix store & db from previous build..."
	mkdir -p /nix
	mv /prev/nix/store /nix
	tar -xf /prev/nix-db.tar -C /
	sqlite3 /nix/var/nix/db/db.sqlite \
		< /nix/var/nix/db/db.sqlite.dump
	rm /nix/var/nix/db/db.sqlite.dump
elif [ ! -e /nix/store ]; then
	echo "### $0: restoring nix store & db from previous stage..."
	mkdir -p /nix
	cp -a /store/4-rebootstrap-using-nix/nix/store /nix/
	tar -xf /store/4-rebootstrap-using-nix/nix-db.tar -C /
	sqlite3 /nix/var/nix/db/db.sqlite \
		< /nix/var/nix/db/db.sqlite.dump
	rm /nix/var/nix/db/db.sqlite.dump
fi


echo "### $0: creating a ZilchOS/bootstrap flake..."
mkdir ZilchOS-bootstrap
cp -r /flake.nix /default.nix /using-nix /recipes \
	ZilchOS-bootstrap/

echo "### $0: pointing to local files..."
sed -i 's| url =| #remote_url =|' ZilchOS-bootstrap/using-nix/*.nix
sed -i 's|# local = \(.*\);|url = "file://\1";|' ZilchOS-bootstrap/using-nix/*.nix
echo "### $0: writing a 0.nix that simply injects what we've built..."
# Makefile bootstrap injects it as /stage/protosrc, regular --- as /protosrc
[ -e /protosrc ] && PROTOSRC="/protosrc" || PROTOSRC=/stage/protosrc
echo "{ tinycc = /store/3b-tinycc-static/bin/tcc; protosrc = $PROTOSRC; }" \
	> ZilchOS-bootstrap/using-nix/0.nix

echo "### $0: unpacking ZilchOS/core archive..."
mkdir ZilchOS-core
tar -xf /downloads/ZilchOS-core-2023.09.1.tar.gz --strip-components=1 \
	-C ZilchOS-core
[[ -e ZilchOS-core/flake.nix ]]
cd ZilchOS-core
nix flake lock \
	--extra-experimental-features 'ca-derivations flakes nix-command' \
	--update-input bootstrap-from-tcc \
	--override-input bootstrap-from-tcc path:../ZilchOS-bootstrap
pwd
cd ..
ls -l ZilchOS-core

echo "### $0: pointing to local downloads..."
sed -i 's| url =| #remote_url =|' \
	ZilchOS-core/*/*.nix ZilchOS-core/*/*/*.nix
sed -i 's|# local = \(.*\);|url = "file://\1";|' \
	ZilchOS-core/*/*.nix ZilchOS-core/*/*/*.nix

echo "### $0: building ZilchOS/core using nix..."
# can't have sandbox, need deterministic build paths
NIX_FORCE_BUILD_PATH=/build \
nix build \
	-j1 \
	--extra-experimental-features 'ca-derivations flakes nix-command' \
	--option build-users-group '' \
	--option compress-build-log false \
	--no-substitute \
	--cores $NPROC \
	--keep-failed \
	--show-trace \
	-L \
	-vvv \
	'./ZilchOS-core#nix' \
	'./ZilchOS-core#ca-bundle' \
	'./ZilchOS-core#linux^config' \
	'./ZilchOS-core#live-cd^limine_config' \
	'./ZilchOS-core#live-cd^initrd' \
	'./ZilchOS-core#live-cd^iso'
ls -l result*
sha256sum result*-iso
rm -f /dev/urandom
rm -f /dev/zero
rm /dev/ptmx
umount /dev/pts
umount /dev/pts || true
rm -r /dev/pts
rm -r shelter
rm -rf /build

# this one is special wrt how the results are saved, see Makefile/USE_NIX_CACHE
echo "### $0: exporting resulting /nix/store (reproducible)..."
mkdir -p /store/5-go-beyond-using-nix/nix
cp -a --reflink=auto /nix/store /store/5-go-beyond-using-nix/nix/

echo "### $0: exporting /nix/var/nix/db to restore it (non-reproducible)..."
cp /nix/var/nix/db/db.sqlite db.sqlite
sqlite3 db.sqlite 'UPDATE ValidPaths SET registrationTime = 1;'
sqlite3 db.sqlite .dump > /nix/var/nix/db/db.sqlite.dump
tar --exclude nix/var/nix/db/db.sqlite \
	-cf /store/5-go-beyond-using-nix/nix-db.tar /nix/var/nix/db
rm /nix/var/nix/db/db.sqlite.dump

echo "### $0: exporting the iso as well..."
cat result*-iso > /store/5-go-beyond-using-nix/ZilchOS-core.iso
