#!/store/2b2-busybox/bin/ash

#> FETCH 551efc818b968b05216024fb0b727ef2ad4c100f8cb6b43fab615fa78ae5be9a
#>  FROM https://www.cpan.org/src/5.0/perl-5.34.0.tar.gz

set -uex

export PATH='/store/2b2-busybox/bin'
export PATH="$PATH:/store/2b1-clang/bin"
export PATH="$PATH:/store/2b3-gnumake/bin"

mkdir -p /tmp/3a-perl; cd /tmp/3a-perl
if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi

echo "### $0: unpacking Perl sources..."
tar --strip-components=1 -xf /downloads/perl-5.34.0.tar.gz

echo "### $0: building Perl..."
sed -i 's|/bin/sh|/store/2b2-busybox/bin/ash|' configure.gnu
sed -i 's|/bin/pwd|/store/2b2-busybox/bin/pwd|' dist/PathTools/Cwd.pm

ash configure.gnu --prefix=/store/3a-perl
make -j $NPROC

echo "### $0: installing Perl..."
make -j $NPROC install-strip
