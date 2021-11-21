#!/store/2b2-busybox/bin/ash

#> FETCH 0cfb5c9bb1a29f800a97bd242d19511c997a1013815b805e0fdd32214113d6be
#>  FROM https://ftp.gnu.org/gnu/bash/bash-5.1.8.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-gnubash; cd /tmp/3a-gnubash
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking GNU Bash sources..."
tar --strip-components=1 -xf /downloads/bash-5.1.8.tar.gz

echo "### $0: building GNU Bash..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure

ash configure --prefix=/store/3a-gnubash
make -j $NPROC

echo "### $0: installing GNU Bash..."
make -j $NPROC install-strip
