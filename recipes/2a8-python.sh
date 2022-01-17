#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 5a99f8e7a6a11a7b98b4e75e0d1303d3832cada5534068f69c7b6222a7b1b002
#>  FROM https://www.python.org/ftp/python/3.10.0/Python-3.10.0.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin/'
export PATH="$PATH:/store/2a0-static-gnumake/wrappers"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a5-gnugcc10/bin"

export SHELL=/store/1-stage1/protobusybox/bin/ash

mkdir -p /tmp/2a8-python; cd /tmp/2a8-python
if [ -e /ccache/setup ]; then . /ccache/setup; fi

echo "### $0: aliasing ash to sh..."
mkdir aliases; ln -s /store/1-stage1/protobusybox/bin/ash aliases/sh
export PATH="/tmp/2a8-python/aliases:$PATH"

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
	--without-static-libpython \
	--build x86_64-linux-musl \
	--prefix=/store/2a8-python \
	--enable-shared \
	--with-ensurepip=no
make -j $NPROC

echo "### $0: installing CPython..."
make -j $NPROC install
# restore compileall just in case
cat Lib/compileall.py.bak > /store/2a8-python/lib/python3.10/compileall.py
