// SPDX-FileCopyrightText: 2021 Alexander Sosedkin <monk@unboiled.info>
// SPDX-License-Identifier: MIT

// syscalls (x86_64)

#include "syscall.h"
#define SYS_write 1
#define SYS_fork 57
#define SYS_execve 59
#define SYS_exit 60
#define SYS_wait4 61
#define SYS_mkdir 83

long write(int fd, void* buf, long cnt) {
	return __syscall3(SYS_write, fd, (long) buf, cnt);
}

int execve(const char* fname, char* const argv[], char* const envp[]) {
	return __syscall3(SYS_execve, (long) fname, (long) argv, (long) envp);
}

void exit(int code) { __syscall1(SYS_exit, code); };

int fork() { return __syscall0(SYS_fork); }

int wait4(int pid, int* status, int options, void* rusage) {
	return __syscall4(
		SYS_wait4,
		pid, (long) status, options, (long) rusage
	);
}

int mkdir(char *pathname, unsigned mode) {
	return __syscall2(SYS_mkdir, (long) pathname, mode);
}


// random defines

#define NULL ((void*) 0)
#define STDOUT 1
#define STDERR 2


// basic QoL

unsigned strlen(char* s) {
	unsigned l;
	for (l = 0; s[l]; l++);
	return l;
}

void assert_msg(long v, char* msg) {
	if (!v) {
		write(STDERR, "Assertion failed!\n", 18);
		if (msg) {
			write(STDERR, msg, strlen(msg));
			write(STDERR, "\n", 1);
		}
		exit(134);  // real assert calls abort() -> 128 + SIGABRT
	}
}

void log(int fd, char* msg) {
	assert_msg(write(fd, msg, strlen(msg)) == strlen(msg), "write#1@log");
	assert_msg(write(fd, "\n", 1) == 1, "write#2@log");
}


// library function substitutes (besides strlen)

void assert(long v) { assert_msg(v, NULL); }

void memset(char* ptr, int with, long len) {
	long i;
	for (i = 0; i < len; i++)
		ptr[i] = with;
}

char* strcpy(char* dest, char* src) {
	while (*src)
		*dest++ = *src++;
	*dest = 0;
	return dest;
}


// my functions

int run_(char* cmd, char** args, char** env) {
	int pid, status, termsig;
	if (pid = fork()) {
		assert_msg(wait4(pid, &status, 0, NULL) == pid, "wait4@run_");
		termsig = status & 0x7f;  // WTERMSIG
		if (!termsig) {
			return (status & 0xff00) >> 8;  // WEXITSTATUS
		} else {
			log(STDERR, "child has been killed");
			exit(termsig);
		}
	} else {
		exit(execve(cmd, args, env));
	}
	return 0;  // unreacheable
}

#define run(expected_retcode, first_arg, ...) do { \
	char* __env[] = {NULL}; \
	char* __args[] = {first_arg, __VA_ARGS__, NULL}; \
	int __i; \
	assert_msg(write(STDOUT, "running ", 8) == 8, "write#1@run"); \
	for(__i = 0; __args[__i]; __i++) { \
		assert_msg(write(STDOUT, __args[__i], strlen(__args[__i])) \
					== strlen(__args[__i]), \
				"write#2@run"); \
		assert_msg(write(STDOUT, " ", 1) == 1, "write#3@run"); \
	} \
	assert_msg(write(STDOUT, "\n", 1) == 1, "write#4@run"); \
	assert(run_(first_arg, __args, __env) == expected_retcode); \
} while (0)
#define run0(first_arg, ...) run(0, first_arg, __VA_ARGS__)

#define amkdir(p) do { assert_msg(mkdir(p, 0777) == 0, p); } while (0)


char linking_args_storage[8192];
char* linking_args_pointers[128] = {NULL};
char* __linking_args_char_curr = linking_args_storage;
char** __linking_args_ptr_curr = linking_args_pointers;

void linking_arg_add(char* new_arg) {
	*__linking_args_ptr_curr = __linking_args_char_curr;
	__linking_args_ptr_curr++;
	__linking_args_char_curr = strcpy(__linking_args_char_curr, new_arg);
	__linking_args_char_curr++;
}


void compile_c(char* dir, char* file) {
	char path_in[64], path_out[64];
	char* p;
	p = strcpy(path_in, "/musl/");
	p = strcpy(p, dir);
	p = strcpy(p, "/");
	p = strcpy(p, file);
	p = strcpy(p, ".c");

	p = strcpy(path_out, "/musl/obj/");
	p = strcpy(p, dir);
	p = strcpy(p, "/");
	p = strcpy(p, file);
	p = strcpy(p, ".o");

	run0("/input-tcc", "-g", "-nostdlib", "-nostdinc", "-std=c99",
		"-D_XOPEN_SOURCE=700",
		"-I/musl/src/include",
		"-I/musl/src/internal",
		"-I/musl/arch/x86_64",
		"-I/musl/stage0-generated/sed1",
		"-I/musl/stage0-generated/sed2",
		"-I/musl/arch/generic",
		"-I/musl/include",
		"-fPIC",
		"-c", path_in, "-o", path_out);
	linking_arg_add(path_out);
}

char* MUSL_STDIO_FILES[] = {
	"__lockfile",
	"__overflow",
	"__stdio_close",
	"__stdio_exit",
	"__stdio_seek",
	"__stdio_write",
	"__stdout_write",
	"__towrite",
	"fputs",
	"fwrite",
	"ofl",
	"printf",
	"putchar",
	"puts",
	"stdout",
	"vfprintf",
	NULL,
};

char* MUSL_STRING_FILES[] = {
	"memchr",
	"memcpy",
	"memmove",
	"memset",
	"strlen",
	"strnlen",
	NULL,
};

#define compile_c_multi(dir, ...) do { \
	char* __filelist[] = { __VA_ARGS__, NULL }; \
	char** __p; \
	for (__p = __filelist; *__p; __p++) \
		compile_c(dir, *__p); \
} while (0)


int _start() {
	log(STDOUT, "Hello from stage1!");

	log(STDOUT, "Testing run()...");
	log(STDOUT, "* testing run() -> retcode 0...");
	run0("/input-tcc", "--help");
	log(STDOUT, "* testing run() -> retcode 1...");
	run(1, "/input-tcc", "-ar", "--help");
	log(STDOUT, "run() seems to work OK");

	log(STDOUT, "Compiling va_list.c...");
	run0("/input-tcc", "-c", "/va_list.c", "-o", "/va_list.o");

	log(STDOUT, "Compiling bits of musl with tcc...");

	linking_arg_add("/input-tcc");
	linking_arg_add("-ar");
	linking_arg_add("/musl/obj/libc.a");
	linking_arg_add("/va_list.o");

	/*
	run0(TCC, "-fPIC", "-DCRT",
		"-c", "/musl/crt/Scrt1.c",
		"-o", "/musl/obj/crt/Scrt1.o");
	run0(TCC, "-DCRT",
		"-c", "/musl/crt/crt1.c",
		"-o", "/musl/obj/crt/crt1.o");
	*/
	run0("/input-tcc", "-g", "-nostdlib", "-nostdinc", "-std=c99",
		"-I/musl/src/include",
		"-I/musl/src/internal",
		"-I/musl/arch/x86_64",
		"-I/musl/stage0-generated/sed1",
		"-I/musl/include",
		"-DCRT",
		"-c", "/musl/crt/crt1.c",
		"-o", "/musl/obj/crt/crt1.o");
	/*
	run0("/input-tcc", "-g", "-nostdlib", "-nostdinc", "-std=c99",
		"-I/musl/src/include",
		"-I/musl/src/internal",
		"-I/musl/arch/x86_64",
		"-I/musl/stage0-generated/sed1",
		"-I/musl/include",
		"-DCRT",
		"-c", "/musl/crt/x86_64/crti.s",
		"-o", "/musl/obj/crt/crti.o");
	run0("/input-tcc", "-g", "-nostdlib", "-nostdinc", "-std=c99",
		"-I/musl/src/include",
		"-I/musl/src/internal",
		"-I/musl/arch/x86_64",
		"-I/musl/stage0-generated/sed1",
		"-I/musl/include",
		"-DCRT",
		"-c", "/musl/crt/x86_64/crtn.s",
		"-o", "/musl/obj/crt/crtn.o");
	*/

	run0("/input-tcc", "-g", "-nostdlib", "-nostdinc", "-std=c99",
		"-I/musl/src/include",
		"-I/musl/src/internal",
		"-I/musl/arch/x86_64",
		"-I/musl/stage0-generated/sed1",
		"-I/musl/include",
		"-DCRT",
		"-c", "/musl/src/thread/x86_64/__set_thread_area.s",
		"-o", "/musl/obj/__set_thread_area.o");
	linking_arg_add("/musl/obj/__set_thread_area.o");

	compile_c_multi("src/env",
			"__environ", "__init_tls", "__libc_start_main");
	compile_c_multi("src/errno",
			"__errno_location", "strerror");
	compile_c_multi("src/exit",
			"_Exit", "abort", "abort_lock", "exit");
	compile_c_multi("src/internal",
			"defsysinfo", "libc", "syscall_ret");
	compile_c("src/locale", "__lctrans");
	compile_c_multi("src/math",
			"__fpclassifyl", "__signbitl", "frexpl");
	compile_c_multi("src/multibyte",
			"wcrtomb", "wctomb");
	compile_c_multi("src/signal",
			"block", "raise");
	compile_c_multi("src/thread",
			"__lock", "default_attr");
	compile_c("src/unistd", "lseek");
	char** p;
	for (p = MUSL_STDIO_FILES; *p; p++)
		compile_c("src/stdio", *p);
	for (p = MUSL_STRING_FILES; *p; p++)
		compile_c("src/string", *p);

	log(STDOUT, "Linking...");
	char* env[] = {NULL};
	long __i;
	for(__i = 0; linking_args_pointers[__i]; __i++)
		log(STDOUT, linking_args_pointers[__i]);
	assert_msg(run_("/input-tcc", linking_args_pointers, env) == 0, "link");

	log(STDOUT, "Executing an example...");
	run0("/input-tcc", "-g", "-nostdlib", "-nostdinc", "-std=c99", "-static",
		"-D_XOPEN_SOURCE=700",
		"-I/musl/src/include",
		"-I/musl/stage0-generated/sed1",
		"-Wl,-whole-archive",
		"/musl/obj/libc.a",
		"/musl/obj/crt/crt1.o",
		//"/musl/obj/crt/crti.o",
		"/test.c",
		//"/musl/obj/crt/crtn.o",
		"-o", "/test"
		);
	run(42, "/test", "1");
	return 0;
}
