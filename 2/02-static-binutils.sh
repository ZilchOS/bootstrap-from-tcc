#!/1/out/protobusybox/bin/ash

#> FETCH c44968b97cd86499efbc4b4ab7d98471f673e5414c554ef54afa930062dbbfcb
#>  FROM https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.gz

set -uex

export PATH='/2/00.ccache/out/wrappers/cc-only'  # may or may not exist
export PATH="$PATH:/1/out/tinycc/wrappers"
export PATH="$PATH:/1/out/protobusybox/bin"
export PATH="$PATH:/2/01-gnumake/out/bin"

echo "### $0: unpacking binutils sources..."
mkdir -p /2/02-static-binutils/tmp; cd /2/02-static-binutils/tmp
gzip -d < /downloads/binutils-2.37.tar.gz | tar -x --strip-components=1

echo "### $0: building static binutils..."
mkdir fakes; export PATH=/2/02-static-binutils/tmp/fakes:$PATH
ln -s /1/out/protobusybox/bin/true fakes/makeinfo
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' \
	missing install-sh mkinstalldirs
export lt_cv_sys_max_cmd_len=32768
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh

ash configure \
	CONFIG_SHELL=/1/out/protobusybox/bin/ash \
	SHELL=/1/out/protobusybox/bin/ash \
	CFLAGS='-D__LITTLE_ENDIAN__=1' \
	--enable-deterministic-archives \
	--host x86_64-linux --build x86_64-linux \
	--disable-bootstrap --disable-libquadmath \
	--prefix=/2/02-static-binutils/out
gnumake $MKOPTS

echo "### $0: installing static binutils..."
gnumake $MKOPTS install

[ ! -e /2/00.ccache/out/bin/ccache ] || /2/00.ccache/out/bin/ccache -sz
#rm -rf /2/02-static-binutils/tmp
