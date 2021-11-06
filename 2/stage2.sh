#!/1/out/protobusybox/bin/ash

set -uex

/2/00-intermediate-gnumake.sh
/2/01-gnumake.sh
/2/02-static-binutils.sh
/2/03-static-gnugcc4.sh
/2/04-musl.sh
/2/05-gnugcc4.sh
/2/06-binutils.sh
/2/07-linux-headers.sh
/2/08-busybox.sh
