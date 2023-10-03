#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 795c34f44df45a0e9b9710c8c71c15c671871524cd412ca14def212e8ccb155d
#>  FROM https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tar.xz

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
tar --strip-components=1 -xf /downloads/Python-3.12.0.tar.xz

echo "### $0: fixing up CPython sources..."
sed -i "s|/bin/sh|$SHELL|" configure install-sh
sed -i 's|ac_sys_system=`uname -s`|ac_sys_system=Linux|' configure
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
sed -i 's|TIME __TIME__|TIME "xx:xx:xx"|' Modules/getbuildinfo.c
sed -i 's|DATE __DATE__|DATE "xx/xx/xx"|' Modules/getbuildinfo.c
# different build path length leads to different wrapping. avoid
sed -i 's|vars, stream=f|vars, stream=f, width=2**24|' Lib/sysconfig.py

echo "### $0: building CPython..."
mkdir -p /store/2a8-python/lib
ash configure \
	ac_cv_broken_sem_getvalue=yes \
	ac_cv_posix_semaphores_enabled=no \
	OPT='-DNDEBUG -fwrapv -O3 -Wall' \
	LDFLAGS='-Wl,-rpath /store/2a8-python/lib' \
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
sed -i "s|/tmp/2a8-python|...|g" \
	/store/2a8-python/lib/python3.*/_sysconfigdata__*.py \
	/store/2a8-python/lib/python3.*/config-3.*-x86_64-linux-musl/Makefile
# restore compileall just in case
cat Lib/compileall.py.bak > /store/2a8-python/lib/python3.12/compileall.py

echo "### $0: checking for build path leaks..."
( ! grep -rF /tmp/2a8 /store/2a8-python )
