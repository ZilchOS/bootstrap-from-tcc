#!/bin/sh
set -uex

#exec \
set +e
env -i $(command -v unshare) -nrR arena \
	/seed/bin/tcc -nostdinc -nostdlib -run /seed/src/stage1.c;
EX=$?
echo exit code $EX
exit $EX
