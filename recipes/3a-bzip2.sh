#!/store/2b2-busybox/bin/ash

#> FETCH 167870372e0e1def1de4cea26020a5931cdc07f1075e0d2f797c2fe37665c5b0
#>  FROM http://ftp.uni-kl.de/pub/linux/suse/people/sbrabec/bzip2/tarballs/bzip2-1.0.6.0.2.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-bzip2; cd /tmp/3a-bzip2
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking bzip2 sources..."
tar --strip-components=1 -xf /downloads/bzip2-1.0.6.0.2.tar.gz

echo "### $0: building bzip2..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure install-sh

ash configure --prefix=/store/3a-bzip2
make -j $NPROC

echo "### $0: installing bzip2..."
make -j $NPROC install-strip
