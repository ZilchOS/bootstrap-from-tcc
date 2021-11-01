#!/usr/bin/env bash

# Theoretically all that it does could be
#     ./seed.sh
#     exec env -i unshare -nrR stage \
#         /0/out/tcc-seed -nostdinc -nostdlib -run /1/src/stage1.c
# e.g., just running stage1.c inside stage with env unset, no net and E[UG]ID=0.

# But during debugging it's useful to re-run just parts of that,
# so, here's a smarter version.

set -ue
shopt -s globstar

[[ -t 1 ]] && COLOR_DIM='\e[2m' || COLOR_DIM=
[[ -t 1 ]] && COLOR_RESET='\e[0m' || COLOR_RESET=

cut_log_up_to_stage() {
	if [[ -e log ]]; then
		:> log.tmp
		echo -ne "Previous log:\n$COLOR_DIM"
		while read -r line; do
			echo "$line"
			echo "$line" >> log.tmp
			[[ "$line" =~ ---.stage.$1.cutoff.point.*--- ]] && break
		done < log
		echo -ne "$COLOR_RESET"
		mv log.tmp log
	fi
}


## stages 0 and 1 ##############################################################

STAGE_1_NEEDS_REBUILD=false
STAGE_1_SOME_INPUTS=( tcc-seed syscall.h stage1.c hello.c protobusybox.{c,h} )
STAGE_1_SOME_OUTPUTS=(
	stage/1/out/protomusl/lib/{libc.a,crt{1,i,n}.o}
	stage/1/out/protomusl/include
	stage/1/out/tinycc/bin/tcc
	stage/1/out/tinycc/lib/libtcc{,1}.a
	stage/1/out/tinycc/wrappers/{cc,cpp,ld,ar}
	stage/1/out/protobusybox/bin/{ash,chmod,cp,grep,ln,mkdir,mv}
)
for o in ${STAGE_1_SOME_OUTPUTS[@]}; do
	[[ -e $o ]] || { STAGE_1_NEEDS_REBUILD=true; break; }
	for f in ${STAGE_1_SOME_INPUTS[@]}; do
		[[ $o -nt $f ]] || { STAGE_1_NEEDS_REBUILD=true; break; }
	done
done

if $STAGE_1_NEEDS_REBUILD; then
	./seed.sh
	env -i unshare -nrR stage \
		/0/out/tcc-seed -nostdinc -nostdlib -run /1/src/stage1.c \
			| tee log
	EX=${PIPESTATUS[0]}; echo "--- stage 1+ exit code $EX ---"; exit $EX
fi


## stage 2 #####################################################################

STAGE_2_NEEDS_REBUILD=false
STAGE_2_SOME_INPUTS=( stage2.sh )
STAGE_2_SOME_OUTPUTS=( stage/2/out/gnumake/bin/gnumake )
for o in ${STAGE_2_SOME_OUTPUTS[@]}; do
	[[ -e $o ]] || { STAGE_2_NEEDS_REBUILD=true; break; }
	for f in ${STAGE_2_SOME_INPUTS[@]}; do
		[[ $o -nt $f ]] || { STAGE_2_NEEDS_REBUILD=true; break; }
	done
done

if $STAGE_2_NEEDS_REBUILD; then
	./seed.sh 2; ./seed.sh 3
	cut_log_up_to_stage 1
	env -i unshare -nrR stage /2/src/stage2.sh 2>&1 | tee -a log
	EX=${PIPESTATUS[0]}; echo "--- stage 2+ exit code $EX ---"; exit $EX
fi


## stage 3 #####################################################################

./seed.sh 3
cut_log_up_to_stage 2
env -i unshare -nrR stage /3/src/stage3.sh 2>&1 | tee -a log
EX=${PIPESTATUS[0]}; echo "--- stage 3+ exit code $EX ---"; exit $EX
