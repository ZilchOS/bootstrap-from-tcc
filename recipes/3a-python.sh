#!/store/2b4-busybox/bin/ash

#> FETCH 5a99f8e7a6a11a7b98b4e75e0d1303d3832cada5534068f69c7b6222a7b1b002
#>  FROM https://www.python.org/ftp/python/3.10.0/Python-3.10.0.tar.xz

set -uex

export PATH='/store/2b4-busybox/bin'
export PATH="$PATH:/store/2b1-gnugcc10/bin"
export PATH="$PATH:/store/2b2-binutils/bin"
export PATH="$PATH:/store/2b5-gnumake/wrappers"

export SHELL=/store/2b4-busybox/bin/ash
export LD_LIBRARY_PATH=/store/3a-zlib/lib

mkdir -p /tmp/3a-python; cd /tmp/3a-python
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

# TODO: better, outer-level solution for /usr/bin/env and popen specifically
# just patch musl to search in $PATH?
echo "### $0: providing /usr/bin/env and sh in PATH for popen..."
mkdir /usr; mkdir /usr/bin
ln -s /store/2b4-busybox/bin/env /usr/bin/env
mkdir aliases; ln -s /store/2b4-busybox/bin/ash aliases/sh
export PATH="/tmp/3a-python/aliases:$PATH"

echo "### $0: unpacking CPython sources..."
tar --strip-components=1 -xf /downloads/Python-3.10.0.tar.xz

echo "### $0: fixing up CPython sources..."
sed -i "s|/bin/sh|$SHELL|" configure
# the precompiled pyc files aren't reproducible,
# but it's not like I need to waste time on them anyway.
# break their generation
mv Lib/compileall.py Lib/compileall.py.bak
echo 'import sys; sys.exit(0)' > Lib/compileall.py; chmod +x Lib/compileall.py

echo "### $0: building CPython..."
ash configure \
	CPPFLAGS='-I/store/3a-zlib/include' \
	LDFLAGS='-L/store/3a-zlib/lib' \
	--without-static-libpython \
	--enable-shared \
	--build x86_64-linux-musl \
	--prefix=/store/3a-python
make -j $NPROC

echo "### $0: installing CPython..."
make -j $NPROC install
# restore compileall just in case
cat Lib/compileall.py.bak > /store/3a-python/lib/python3.10/compileall.py

rm /usr/bin/env && rmdir /usr/bin && rmdir /usr
