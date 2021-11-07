#!/1/out/protobusybox/bin/ash

#> FETCH c44968b97cd86499efbc4b4ab7d98471f673e5414c554ef54afa930062dbbfcb
#>  FROM https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.gz

set -uex

export PATH='/1/out/protobusybox/bin'
export PATH="$PATH:/2/01-gnumake/out/bin"
export PATH="$PATH:/2/02-static-binutils/out/bin"
export PATH="$PATH:/2/05-gnugcc4/out/bin"

echo "### $0: unpacking binutils sources..."
mkdir -p /2/06-binutils/tmp; cd /2/06-binutils/tmp
gzip -d < /downloads/binutils-2.37.tar.gz | tar -x --strip-components=1

echo "### $0: building binutils..."
sed -i 's|/dev/null|/2/06-binutils/tmp/null|g' \
	config.* configure* */configure libtool.m4 ltmain.sh
sed -i 's|date +%Y|echo 0000|' config.guess
mkdir fakes; export PATH=/2/06-binutils/tmp/fakes:$PATH
ln -s /1/out/protobusybox/bin/true fakes/makeinfo
sed -i 's|/bin/sh|/1/out/protobusybox/bin/ash|' \
	missing install-sh mkinstalldirs
# see libtool's 74c8993c178a1386ea5e2363a01d919738402f30
sed -i 's/| \$NL2SP/| sort | $NL2SP/' ltmain.sh

mkdir tmpdir
ash configure \
	TMPDIR=/2/06-binutils/tmp/tmpdir \
	CONFIG_SHELL=/1/out/protobusybox/bin/ash \
	SHELL=/1/out/protobusybox/bin/ash \
	--enable-deterministic-archives \
	--host x86_64-linux --build x86_64-linux \
	--prefix=/2/06-binutils/out
gnumake $MKOPTS

echo "### $0: installing binutils..."
gnumake $MKOPTS install

#rm -rf /2/06-binutils/tmp
