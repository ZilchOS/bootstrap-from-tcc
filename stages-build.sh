#!/bin/sh

# rm -rf stage
# mkdir stage && ./download.sh && ./seed.sh

# Run stage1.c inside stage with env unset (+w/o network, +with EUID=EGID=0):
exec env -i unshare -nrR stage \
	/0/out/tcc-seed -nostdinc -nostdlib -run /1/src/stage1.c
