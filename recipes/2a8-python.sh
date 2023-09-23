#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 85cd12e9cf1d6d5a45f17f7afe1cebe7ee628d3282281c492e86adf636defa3f
#>  FROM https://www.python.org/ftp/python/3.11.5/Python-3.11.5.tar.xz

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
tar --strip-components=1 -xf /downloads/Python-3.11.5.tar.xz

echo "### $0: fixing up CPython sources..."
sed -i "s|/bin/sh|$SHELL|" configure
# the precompiled pyc files aren't reproducible,
# but it's not like I need to waste time on them anyway.
# break their generation
mv Lib/compileall.py Lib/compileall.py.bak
echo 'import sys; sys.exit(0)' > Lib/compileall.py; chmod +x Lib/compileall.py
sed -i 's|__FILE__|"__FILE__"|' \
	Python/errors.c \
	Include/pyerrors.h \
	Include/cpython/object.h \
	Modules/pyexpat.c

echo "### $0: building CPython..."
ash configure \
	ac_cv_broken_sem_getvalue=yes \
	ac_cv_posix_semaphores_enabled=no \
	OPT='-DNDEBUG -fwrapv -O3 -Wall' \
	--without-static-libpython \
	--build x86_64-linux-musl \
	--prefix=/store/2a8-python \
	--enable-shared \
	--with-ensurepip=no
# ensure reproducibility in case of no /dev/shm
grep 'define POSIX_SEMAPHORES_NOT_ENABLED 1' pyconfig.h
grep 'define HAVE_BROKEN_SEM_GETVALUE 1' pyconfig.h
make -j $NPROC

echo "### $0: installing CPython..."
make -j $NPROC install
# strip builddir mentions
sed -i "s|/tmp/2a8-python|...|" \
	/store/2a8-python/lib/python3.*/_sysconfigdata__*.py \
	/store/2a8-python/lib/python3.*/config-3.11-x86_64-linux-musl/Makefile
# restore compileall just in case
cat Lib/compileall.py.bak > /store/2a8-python/lib/python3.11/compileall.py

echo "### $0: checking for build path leaks..."
( ! grep -RF /tmp/2a8 /store/2a8-python )
