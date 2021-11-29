#!/store/2b2-busybox/bin/ash

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/3a-pkg-config/bin"
export PATH="$PATH:/store/3b-nix/bin"

export SHELL='/store/2b2-busybox/bin/ash'

export PKG_CONFIG_PATH=''
#export PKG_CONFIG_PATH='/store/3a-openssl/lib64/pkgconfig'
#export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-bzip2/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-sqlite/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-curl/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-editline/lib/pkgconfig"
#export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-xz/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-seccomp/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-libarchive/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-libsodium/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/store/3a-lowdown/lib/pkgconfig"
LIBDIRS=''
#LIBDIRS="$(pkg-config --variable=libdir openssl)"
#LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir bzip2)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir sqlite3)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libcurl)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libeditline)"
#LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir liblzma)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libseccomp)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libarchive)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir libsodium)"
LIBDIRS="$LIBDIRS:$(pkg-config --variable=libdir lowdown)"
LIBDIRS="$LIBDIRS:/store/3a-boost/lib"
LIBDIRS="$LIBDIRS:/store/2b1-clang/lib"
export LD_LIBRARY_PATH=$LIBDIRS

mkdir -p /tmp/_3b.test; cd /tmp/_3b.test

echo "### $0: faking lots of stuff for nix to work..."
mkdir shelter
export HOME=/tmp/_3b.test/shelter
export USER=notauser
echo 'oh come on' >/dev/urandom

echo "### $0: testing that derivation assumes a known input hash..."
nix repl > known-drv-hash.output <<\EOF
  # see https://nixos.org/guides/nix-pills/our-first-derivation.html
  derivation { name = "myname"; builder = "mybuilder"; system = "mysystem"; }
EOF
grep -Fx '«derivation /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv»' \
  known-drv-hash.output

rm -f /dev/urandom
touch /store/_3b.test  # indicator of successful completion
