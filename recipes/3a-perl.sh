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

echo "### $0: fixing up Perl sources..."
sed -i 's|$date|$echo Thu Jan  1 00:00:01 UTC 1970|' Configure
sed -i 's|$uname -a|$echo Linux x86_64|' Configure
sed -i 's|$uname -r|$echo 0.0.0|' Configure
sed -i 's|$uname -n|$echo hostname|' Configure
sed -i 's|sh -c hostname|echo hostname|' Configure
sed -i 's|start_time= time|start_time=0|' lib/unicore/mktables
sed -i 's|PERL_BUILD_DATE)|"Thu Jan  1 00:00:01 UTC 1970")|' perl.c

sed -i 's|/bin/pwd|/store/2b2-busybox/bin/pwd|' dist/PathTools/Cwd.pm

echo "### $0: configuring Perl..."
ash Configure -des -Dprefix=/store/3a-perl -Duseshrplib

echo "### $0: building Perl..."
make -j $NPROC

echo "### $0: installing Perl..."
make -j $NPROC install-strip
