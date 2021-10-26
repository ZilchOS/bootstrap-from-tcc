#!/bin/sh

# Run stage1.c inside arena with env unset (+w/o network, +with EUID=EGID=0):
exec env -i unshare -nrR arena \
	/seed/1/bin/tcc -nostdinc -nostdlib -run /seed/1/src/stage1.c
