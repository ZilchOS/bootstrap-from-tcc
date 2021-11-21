#!/store/2b2-busybox/bin/ash

#> FETCH bd90c3eb96bee996206b83be7065c9ce19aef38c3f4fb53073ada0d0b69bbce3
#>  FROM https://www.sqlite.org/2021/sqlite-autoconf-3360000.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-sqlite; cd /tmp/3a-sqlite
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking SQLite archive..."
tar --strip-components=1 -xf /downloads/sqlite-autoconf-3360000.tar.gz

echo "### $0: building SQLite..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure install-sh

ash configure --prefix=/store/3a-sqlite
make -j $NPROC

echo "### $0: installing SQLite..."
make -j $NPROC install-strip
