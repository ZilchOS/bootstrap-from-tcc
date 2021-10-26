// SPDX-FileCopyrightText: 2021 Alexander Sosedkin <monk@unboiled.info>
// SPDX-License-Identifier: MIT

// syscalls (x86_64)

#include "syscall.h"
#define SYS_write 1
#define SYS_open 2
#define SYS_fork 57
#define SYS_execve 59
#define SYS_exit 60
#define SYS_wait4 61
#define SYS_getdents 78
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

int open(char *pathname, int flags, int mode) {
	return __syscall3(SYS_open, (long) pathname, flags, mode);
}

struct linux_dirent {
	long d_ino;
	long d_off;
	unsigned short d_reclen;
	char d_name[];
};
int getdents(unsigned int fd, struct linux_dirent *dirp,
		unsigned int count) {
	return __syscall3(SYS_getdents, fd, (long) dirp, count);
}


// random defines

#define NULL ((void*) 0)
#define STDOUT 1
#define STDERR 2
#define O_RDONLY 0
#define O_DIRECTORY 0200000
#define DT_REG 8


// basic QoL

unsigned strlen(char* s) {
	unsigned l;
	for (l = 0; s[l]; l++);
	return l;
}

int write_(int fd, char* msg) {
	return write(fd, msg, strlen(msg));
}

#define __quote(x) #x
#define _quote(x) __quote(x)
// real assert calls abort() -> 128 + SIGABRT = 134
#define assert(v) \
	while (!(v)) { \
		write_(STDERR, "Assertion "); \
		write_(STDERR, _quote(v)); write_(STDERR, " failed at "); \
		write_(STDERR, __FILE__); write_(STDERR, ":"); \
		write_(STDERR, __func__); write_(STDERR, ":"); \
		write_(STDERR, _quote(__LINE__)); write_(STDERR, "!\n"); \
		exit(134);  \
	}

void log_(int fd, char* msg) {
	assert(write_(fd, msg) == strlen(msg));
}

void log(int fd, char* msg) {
	log_(fd, msg);
	log_(fd, "\n");
}


// library function substitutes (besides strlen)

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


// my convenience functions: fork + exec

int run_(char* cmd, char** args, char** env) {
	int pid, status, termsig;
	if (pid = fork()) {
		assert(wait4(pid, &status, 0, NULL) == pid);
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

#define run(expected_retcode, first_arg, ...) \
	do { \
		char* __env[] = {NULL}; \
		char* __args[] = {(first_arg), __VA_ARGS__, NULL}; \
		int __i; \
		log_(STDOUT, "run() running: "); \
		for(__i = 0; __args[__i]; __i++) { \
			log_(STDOUT, __args[__i]); \
			log_(STDOUT, " "); \
		} \
		log_(STDOUT, "\n"); \
		assert(run_(first_arg, __args, __env) == (expected_retcode)); \
	} while (0)
#define run0(first_arg, ...) run(0, (first_arg), __VA_ARGS__)


// my convenience functions: dynamic args accumulation / command execution

struct args_accumulator {
	char storage[262144];
	char* pointers[4096];
	char* char_curr;
	char** ptr_curr;
};
void aa_init(struct args_accumulator* aa) {
	aa->char_curr = aa->storage;
	aa->ptr_curr = aa->pointers;
	*aa->ptr_curr = NULL;
}
void aa_add(struct args_accumulator* aa, char* new_arg) {
	*aa->ptr_curr = aa->char_curr;
	aa->ptr_curr++;
	*aa->ptr_curr = NULL;
	//*++aa->ptr_curr = 0;
	aa->char_curr = strcpy(aa->char_curr, new_arg);
	aa->char_curr++;
}
void aa_add_arr(struct args_accumulator* aa, char** p) {
	while (*p)
		aa_add(aa, *p++);
}
#define aa_add_const(aa_ptr, ...) \
	do { \
		char* __args[] = { __VA_ARGS__, NULL }; \
		aa_add_arr(aa_ptr, __args); \
	} while (0)
#define aa_init_const(aa_ptr, ...) \
	do { aa_init(aa_ptr); aa_add_const(aa_ptr, __VA_ARGS__); } while (0)
int aa_run(struct args_accumulator* aa) {
	char* __env[] = { NULL };
	int i;
	log_(STDOUT, "aa_run() running: ");
	for (i = 0; aa->pointers[i]; i++) {
		log_(STDOUT, aa->pointers[i]);
		log_(STDOUT, " ");
	}
	log_(STDOUT, "\n");
	return run_(aa->pointers[0], aa->pointers, __env);
}
#define aa_run0(aa_ptr) do { assert(aa_run(aa_ptr) == 0); } while (0)


// my convenience functions: compiling whole directories worth of files

int is_compileable(char* fname) {
	int i = 0;
	while (fname[i])
		i++;
	if (i > 2)
		if (fname[i - 2] == '.')
			if (fname[i - 1] == 'c' || fname[i-1] == 's')
				return 1;
	return 0;
}


void compile_dir(char** compile_args, struct args_accumulator* linking_aa,
		char* in_dir_path, char* out_dir_path) {
	char in_file_path_buf[128], out_file_path_buf[128];
	char* in_file_path;
	char* out_file_path;
	struct args_accumulator aa;

	char d_buf[256];
	struct linux_dirent* d;
	int fd, r;
	char d_type;

	mkdir(out_dir_path, 0777);  // the lack of error-checking is deliberate

	fd = open(in_dir_path, O_RDONLY | O_DIRECTORY, 0);
	assert(fd != -1);

	while (1) {
		d = (struct linux_dirent*) d_buf;
		r = getdents(fd, d, 256);
		assert(r != -1);
		if (!r)
			break;
		while ((char*) d - d_buf < r) {
			d_type = *((char*) d + d->d_reclen - 1);
			if (d_type == DT_REG && is_compileable(d->d_name)) {
				in_file_path = strcpy(in_file_path_buf,
						in_dir_path);
				in_file_path = strcpy(in_file_path, "/");
				in_file_path = strcpy(in_file_path, d->d_name);

				out_file_path = strcpy(out_file_path_buf,
						out_dir_path);
				out_file_path = strcpy(out_file_path, "/");
				out_file_path = strcpy(out_file_path,
						d->d_name);
				out_file_path = strcpy(out_file_path,
						".o");

				aa_init(&aa);
				aa_add_arr(&aa, compile_args);
				aa_add(&aa, "-c");
				aa_add(&aa, in_file_path_buf);
				aa_add(&aa, "-o");
				aa_add(&aa, out_file_path_buf);
				aa_run0(&aa);

				aa_add(linking_aa, out_file_path_buf);
			}
			d = (struct linux_dirent*) ((char*) d + d->d_reclen);
		}
	}
}


#define TCC "/seed/1/bin/tcc"
#define TCC_ARGS "-g", "-nostdlib", "-nostdinc", "-std=c99", \
		"-D_XOPEN_SOURCE=700"
#define PROTOMUSL_INCLUDES \
		"-I/seed/1/src/protomusl/src/include", \
		"-I/seed/1/src/protomusl/arch/x86_64", \
		"-I/seed/1/src/protomusl/stage0-generated/sed1", \
		"-I/seed/1/src/protomusl/stage0-generated/sed2", \
		"-I/seed/1/src/protomusl/arch/generic", \
		"-I/seed/1/src/protomusl/src/internal", \
		"-I/seed/1/src/protomusl/include"
#define PROTOMUSL_LINK_ARGS \
		"-Wl,-whole-archive", \
		"/stage/1/lib/protomusl.a", \
		"/stage/1/obj/protomusl/crt/crt1.o"

int _start() {
	struct args_accumulator aa;

	log(STDOUT, "Hello from stage1!");

	log(STDOUT, "Testing run()...");
	log(STDOUT, "* testing run() -> retcode 0...");
	run0(TCC, "--help");
	log(STDOUT, "* testing run() -> retcode 1...");
	run(1, TCC, "-ar", "--help");
	log(STDOUT, "run() seems to work OK");

	log(STDOUT, "Testing args accumulator...");
	log(STDOUT, "* testing aa_add and aa_run0...");
	aa_init(&aa);
	aa_add(&aa, TCC);
	aa_add(&aa, "--help");
	aa_run0(&aa);

	log(STDOUT, "* testing aa_multi and aa_run for 1...");
	aa_init_const(&aa, TCC, "-ar", "--help");
	assert(aa_run(&aa) == 1);


	// Preparing to assemble musl linking cmdline
	aa_init_const(&aa, TCC, "-ar", "/stage/1/lib/protomusl.a");


	log(STDOUT, "Compiling tcc's external runtime bits...");
	run0(TCC, TCC_ARGS,
		"-c", "/seed/1/src/alloca.S",
		"-o", "/stage/1/obj/alloca.o");
	aa_add(&aa, "/stage/1/obj/alloca.o");

	run0(TCC, TCC_ARGS,
		"-c", "/seed/1/src/libtcc1.c",
		"-o", "/stage/1/obj/libtcc1.o");
	aa_add(&aa, "/stage/1/obj/libtcc1.o");

	run0(TCC, TCC_ARGS,
		"-c", "/seed/1/src/va_list.c",
		"-o", "/stage/1/obj/va_list.o");
	aa_add(&aa, "/stage/1/obj/va_list.o");


	log(STDOUT, "Compiling the most part of musl...");
	char* MUSL_COMPILE[] = { TCC, TCC_ARGS, PROTOMUSL_INCLUDES, NULL };
	#define compile_protomusl_dir(dir) \
			compile_dir(MUSL_COMPILE, &aa, \
				"/seed/1/src/protomusl/src/" dir, \
				"/stage/1/obj/protomusl/" dir);
	compile_protomusl_dir("conf");
	compile_protomusl_dir("ctype");
	compile_protomusl_dir("dirent");
	compile_protomusl_dir("env");
	compile_protomusl_dir("errno");
	compile_protomusl_dir("exit");
	compile_protomusl_dir("fcntl");
	compile_protomusl_dir("fenv");
	compile_protomusl_dir("internal");
	compile_protomusl_dir("linux");
	compile_protomusl_dir("locale");
	compile_protomusl_dir("malloc");
	compile_protomusl_dir("malloc/mallocng");
	compile_protomusl_dir("math");
	compile_protomusl_dir("misc");
	compile_protomusl_dir("mman");
	compile_protomusl_dir("multibyte");
	compile_protomusl_dir("network");
	compile_protomusl_dir("passwd");
	compile_protomusl_dir("prng");
	compile_protomusl_dir("process");
	compile_protomusl_dir("regex");
	compile_protomusl_dir("select");
	compile_protomusl_dir("setjmp/x86_64");
	compile_protomusl_dir("signal");
	compile_protomusl_dir("signal/x86_64");
	compile_protomusl_dir("stat");
	compile_protomusl_dir("stdio");
	compile_protomusl_dir("stdlib");
	compile_protomusl_dir("string");
	compile_protomusl_dir("temp");
	compile_protomusl_dir("termios");
	compile_protomusl_dir("thread");
	compile_protomusl_dir("thread/x86_64");
	compile_protomusl_dir("time");
	compile_protomusl_dir("unistd");

	log(STDOUT, "Compiling crt bits of musl...");
	run0(TCC, TCC_ARGS, PROTOMUSL_INCLUDES, "-DCRT",
		"-c", "/seed/1/src/protomusl/crt/crt1.c",
		"-o", "/stage/1/obj/protomusl/crt/crt1.o");
	//run0(TCC, TCC_ARGS, PROTOMUSL_INCLUDES, "-DCRT",
	//	"-c", "/seed/1/src/protomusl/crt/x86_64/crti.s",
	//	"-o", "/stage/1/obj/protomusl/crt/crti.o");
	//run0(TCC, TCC_ARGS, PROTOMUSL_INCLUDES, "-DCRT",
	//	"-c", "/seed/1/src/protomusl/crt/x86_64/crtn.s",
	//	"-o", "/stage/1/obj/protomusl/crt/crtn.o");

	log(STDOUT, "Linking musl...");
	aa_run0(&aa);


	log(STDOUT, "Linking an example...");
	run0(TCC, TCC_ARGS, PROTOMUSL_INCLUDES, PROTOMUSL_LINK_ARGS, "-static",
		//"/stage/1/obj/protomusl/crt/crti.o",
		"/seed/1/src/hello.c",
		//"/stage/1/obj/protomusl/crt/crtn.o",
		"-o", "/stage/1/bin/protomusl-hello"
		);

	log(STDOUT, "Executing an example...");
	run(42, "/stage/1/bin/protomusl-hello", "1");


	log(STDOUT, "Compiling sash...");
	aa_init_const(&aa, TCC, TCC_ARGS, "-static", PROTOMUSL_LINK_ARGS,
			"-o", "/stage/1/bin/sash");
	//aa_add_const(&aa, "/stage/1/obj/protomusl/crt/crti.o");
	char* SASH_COMPILE[] = {
		TCC, TCC_ARGS, PROTOMUSL_INCLUDES, "-D_GNU_SOURCE",
		"-DHAVE_LINUX_MOUNT=0", "-DMOUNT_TYPE=\"btrfs\"",
		NULL
	};
	compile_dir(SASH_COMPILE, &aa, "/seed/1/src/sash", "/stage/1/obj/sash");
	//aa_add_const(&aa, "/stage/1/obj/protomusl/crt/crtn.o");
	aa_run0(&aa);

	log(STDOUT, "Testing sash...");
	run(1, "/stage/1/bin/sash", "--help");
	run0("/stage/1/bin/sash", "-c", "-pwd");


	log(STDOUT, "Compiling protobusybox...");
	run0(TCC, TCC_ARGS, "-static", PROTOMUSL_LINK_ARGS, PROTOMUSL_INCLUDES,
			//"/stage/1/obj/protomusl/crt/crti.o",
			"-I/seed/1/src/protobusybox/include",
			"-I/seed/1/src/protobusybox",
			"/seed/1/src/protobusybox.c",
			//"/stage/1/obj/protomusl/crt/crtn.o",
			"-o", "/stage/1/bin/ln");

	log(STDOUT, "Creating protobusybox files...");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/ash");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/cat");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/chmod");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/cp");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/echo");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/expr");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/ls");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/mkdir");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/mv");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/rm");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/rmdir");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/sed");
	run0("/stage/1/bin/ln", "-f", "/stage/1/bin/ln", "/stage/1/bin/sort");
	run0("/stage/1/bin/ln", "-f",
			"/stage/1/bin/ln", "/stage/1/bin/protobusybox");

	log(STDOUT, "Testing busybox ash...");
	run0("/stage/1/bin/ash", "-c", "/seed/1/bin/tcc;/seed/1/bin/tcc");

	log(STDOUT, "--- stage 1 cutoff point ---");

	char* STAGE2_ARGS[] = {"/seed/2/src/stage2.sh", NULL};
	assert(execve("/seed/2/src/stage2.sh", STAGE2_ARGS, NULL));
	return 1;
}
