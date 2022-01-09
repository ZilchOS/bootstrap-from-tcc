#!/store/2b2-busybox/bin/ash

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/3a-pkg-config/bin"
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

echo "### $0: fixing up paths to shell"
sed -i 's|/bin/sh|/store/3b-busybox-static/bin/ash|' /using-nix/1-stage1.nix

echo "### $0: pointing to local downloads"
sed -i 's|url =|#remote_url =|' /using-nix/*.nix
sed -i 's|# local = \(.*\);|url = "file://\1";|' /using-nix/*.nix

echo "### $0: rebuilding everything using nix"
nix-build \
	--extra-experimental-features ca-derivations \
	--option build-users-group '' \
	--option sandbox false \
	--option compress-build-log false \
	--no-substitute -vvv /default.nix

ls /nix/store

rm -f /dev/urandom
# touch /store/4-rebootstrap-using-nix  # indicator of successful completion
