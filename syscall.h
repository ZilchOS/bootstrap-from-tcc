// SPDX-FileCopyrightText: 2021 Alexander Sosedkin <monk@unboiled.info>
// SPDX-License-Identifier: MIT


// constants/macro for this file to serve as a drop-in replacement
// for musl-1.2.2's arch/x86_64/syscall_arch.h

#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define VDSO_USEFUL
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_2.6"
#define VDSO_GETCPU_SYM "__vdso_getcpu"
#define VDSO_GETCPU_VER "LINUX_2.6"

#define IPC_64 0


// a different, tcc-compatible implementation of syscall invocations functions

static long __syscall6(long n, long a1, long a2, long a3, long a4, long a5, long a6);
asm (
	//".globl __syscall6;"
        ".type __syscall6, @function;"
        "__syscall6:;"
	"movq %rdi, %rax;"
	"movq %rsi, %rdi;"
	"movq %rdx, %rsi;"
	"movq %rcx, %rdx;"
	"movq %r8, %r10;"
	"movq %r9, %r8;"
	"movq 8(%rsp),%r9;"
	"syscall;"
	"ret"
);

static __inline long __syscall5(long n, long a1, long a2, long a3, long a4, long a5) {
	return __syscall6(n, a1, a2, a3, a4, a5, 0);
}

static __inline long __syscall4(long n, long a1, long a2, long a3, long a4) {
	return __syscall6(n, a1, a2, a3, a4, 0, 0);
}

static __inline long __syscall3(long n, long a1, long a2, long a3) {
	return __syscall6(n, a1, a2, a3, 0, 0, 0);
}

static __inline long __syscall2(long n, long a1, long a2) {
	return __syscall6(n, a1, a2, 0, 0, 0, 0);
}

static __inline long __syscall1(long n, long a1) {
	return __syscall6(n, a1, 0, 0, 0, 0, 0);
}

static __inline long __syscall0(long n) {
	return __syscall6(n, 0, 0, 0, 0, 0, 0);
}
