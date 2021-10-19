#!/bin/sh
set -uex

cp test.c arena/test.c
cp stage1.c arena/stage1.c
cp syscall.h arena/syscall.h
#exec \
set +e
env -i $(command -v unshare) -nrR arena \
	/input-tcc -nostdinc -nostdlib -run /stage1.c;
EX=$?
echo exit code $EX
exit $EX
