// SPDX-FileCopyrightText: 2021 Alexander Sosedkin <monk@unboiled.info>
// SPDX-License-Identifier: MIT

// syscalls (x86_64) //////////////////////////////////////////////////////////

#include "syscall.h"
#define SYS_write 1
#define SYS_open 2
#define SYS_fork 57
#define SYS_execve 59
#define SYS_exit 60
#define SYS_wait4 61
#define SYS_getdents 78
#define SYS_mkdir 83

long write(int fd, const void* buf, long cnt) {
	return __syscall3(SYS_write, fd, (long) buf, cnt);
}

int execve(const char* fname,
		const char* const argv[], const char* const envp[]) {
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

int mkdir(const char *pathname, unsigned mode) {
	return __syscall2(SYS_mkdir, (long) pathname, mode);
}

int open(const char *pathname, int flags, int mode) {
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


// random defines /////////////////////////////////////////////////////////////

#define NULL ((void*) 0)
#define STDOUT 1
#define STDERR 2
#define O_RDONLY 0
#define O_DIRECTORY 0200000
#define DT_REG 8


// basic QoL //////////////////////////////////////////////////////////////////

unsigned strlen(const char* s) {
	unsigned l;
	for (l = 0; s[l]; l++);
	return l;
}

int write_(int fd, const char* msg) {
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

void err(const char* msg) { assert(write_(STDERR, msg) == strlen(msg)); }

void log_begin_line(const char* msg) {
	assert(write_(STDOUT, "### 1/src/stage.c: ") == 19);
	assert(write_(STDOUT, msg) == strlen(msg));
}
void log_continue_line(const char* msg) {
	assert(write_(STDOUT, msg) == strlen(msg));
}
void log_end_line() { assert(write_(STDOUT, "\n") == 1); }
void log(const char* msg) { log_begin_line(msg); log_end_line(); };


// more library function substitutes //////////////////////////////////////////

void memset(char* ptr, int with, long len) {
	long i;
	for (i = 0; i < len; i++)
		ptr[i] = with;
}

char* strcpy(char* dest, const char* src) {
	while (*src)
		*dest++ = *src++;
	*dest = 0;
	return dest;
}

int strcmp(const char* a, const char* b) {
	for (; *a && *b; a++, b++)
		if (*a != *b)
			return (*a < *b) ? -1 : 1;
	return !a && !b;
}


// my convenience functions: mkdir'ing ////////////////////////////////////////


void mkreqdirs(const char* path) {
	char b[128], *p;
	strcpy(b, path);
	for (p = b + 1; *p; p++)
		if (*p == '/') { *p = '\0'; mkdir(b, 0777); *p = '/'; }
}
void mkreqdirs_at(const char* at, const char* subpath) {
	char b[128], *p;
	p = strcpy(b, at);
	p = strcpy(strcpy(strcpy(p, "/"), subpath), "/");
	mkreqdirs(b);
}
#define mkdirs_at(at, args...) \
	do { \
		const char* const* p; \
		for (p = (char*[]) { "/", ## args, NULL }; *p; p++) \
			mkreqdirs_at(at, *p); \
	} while (0)


// my convenience functions: fork + exec //////////////////////////////////////

int run_(const char* cmd, const char* const args[], const char* const env[]) {
	int pid, status, termsig;
	if (pid = fork()) {
		assert(wait4(pid, &status, 0, NULL) == pid);
		termsig = status & 0x7f;  // WTERMSIG
		if (!termsig) {
			return (status & 0xff00) >> 8;  // WEXITSTATUS
		} else {
			err("child has been killed");
			exit(termsig);
		}
	} else {
		exit(execve(cmd, args, env));
	}
	return 0;  // unreacheable
}

#define run(expected_retcode, first_arg, args...) \
	do { \
		const char const* __env[] = {NULL}; \
		const char const* __args[] = {(first_arg), ##args, NULL}; \
		int __i; \
		log_begin_line("run() running: "); \
		for(__i = 0; __args[__i]; __i++) { \
			log_continue_line(__args[__i]); \
			log_continue_line(" "); \
		} \
		log_end_line(); \
		assert(run_(first_arg, __args, __env) == (expected_retcode)); \
	} while (0)
#define run0(first_arg, args...) run(0, (first_arg), ## args)


// my convenience functions: dynamic args accumulation / command execution ////

struct args_accumulator {
	char* pointers[4096];
	char storage[262144];
	char** ptr_curr;
	char* char_curr;
};
void _aa_init(struct args_accumulator* aa) {
	aa->char_curr = aa->storage;
	aa->ptr_curr = aa->pointers;
	*aa->ptr_curr = NULL;
}
void aa_append(struct args_accumulator* aa, const char* new_arg) {
	*aa->ptr_curr = aa->char_curr;
	*++aa->ptr_curr = NULL;
	aa->char_curr = strcpy(aa->char_curr, new_arg);
	aa->char_curr++;
}
void _aa_extend_from_arr(struct args_accumulator* aa, const char* const* p) {
	for (; *p; p++)
		aa_append(aa, *p);
}
void aa_extend_from(struct args_accumulator* aa, const void* from) {
	// Cheat a little with void* to accept
	// both struct args_accumulator* and null-terminated string arrays.
	// Qualifiers could be stricter, but then declaring get cumbersome.
	_aa_extend_from_arr(aa, (const char* const*) from);
}
#define aa_extend(aa_ptr, args...) \
	_aa_extend_from_arr(aa_ptr, (const char*[]) { NULL, ## args, NULL } + 1)
#define aa_init(aa_ptr, args...) \
	do { _aa_init(aa_ptr); aa_extend(aa_ptr, ## args); } while (0)
void aa_sort(struct args_accumulator* aa) {
	int changes;
	char **p, **n, *t;
	if (!aa->pointers[0])
		return;
	if (!aa->pointers[1])
		return;
	do {
		changes = 0;
		for (p = aa->pointers, n = p + 1; *n; p++, n++) {
			if (strcmp(*p, *n) > 0) {
				t = *p; *p = *n; *n = t;
				changes = 1;
			}
		}
	} while (changes);
}
int aa_run(const struct args_accumulator* aa) {
	int i;
	log_begin_line("aa_run() running: ");
	for (i = 0; aa->pointers[i]; i++) {
		log_continue_line(aa->pointers[i]);
		log_continue_line(" ");
	}
	log_end_line(STDOUT, "\n");
	return run_(aa->pointers[0], aa->pointers, (char*[]) { NULL });
}
#define aa_run0(aa_ptr) do { assert(aa_run(aa_ptr) == 0); } while (0)


// my convenience functions: compiling whole directories worth of files ///////

_Bool is_compileable(char* fname) {
	int i = 0;
	while (fname[i])
		i++;
	if (i > 2)
		if (fname[i - 2] == '.')
			if (fname[i - 1] == 'c' || fname[i-1] == 's')
				return 1;
	return 0;
}

void aa_extend_from_dir(struct args_accumulator* aa_out,
		unsigned short keep_components, const char* dir_path) {
	struct args_accumulator aa;
	char d_buf[256];
	char buf[256];
	const char* prefix;
	char* out_subpath;
	struct linux_dirent* d;
	int fd, r;
	char d_type;

	aa_init(&aa);

	prefix = dir_path + strlen(dir_path);
	while (keep_components) {
		while (*prefix != '/')
			prefix--;
		keep_components--;
		prefix += keep_components ? -1 : 1;
	}

	fd = open(dir_path, O_RDONLY | O_DIRECTORY, 0);
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
				out_subpath = strcpy(buf, prefix);
				out_subpath = strcpy(out_subpath, "/");
				out_subpath = strcpy(out_subpath, d->d_name);
				aa_append(&aa, buf);
			}
			d = (struct linux_dirent*) ((char*) d + d->d_reclen);
		}
	}
	aa_sort(aa_out);  // iteration order isn't guaranteed, make stable
	aa_extend_from(aa_out, &aa);
}


void mass_compile(const char* cc, const void* compile_args,
		const char* in_dir_path, const void* fnames /* NULL=auto */,
		const char* out_obj_dir_path, const char* out_lib_file_path) {
		// qualifiers could've been stricter
		// const void* could be struct args_accumulator*,
		// NULL-terminated arrays or even just NULLs for fnames
	struct args_accumulator aa, aa_link, aa_sources;
	char in_file_path_buf[128], out_file_path_buf[128];
	char* in_file_path;
	char* out_file_path;
	char** p;

	aa_init(&aa_sources);
	if (!fnames)
		aa_extend_from_dir(&aa_sources, 0, in_dir_path);
	else
		aa_extend_from(&aa_sources, fnames);

	mkreqdirs(out_lib_file_path);
	aa_init(&aa_link, cc, "-ar", "rc", out_lib_file_path);

	for (p = (char**) &aa_sources; *p; p++) {
		in_file_path = strcpy(in_file_path_buf, in_dir_path);
		in_file_path = strcpy(in_file_path, "/");
		in_file_path = strcpy(in_file_path, *p);

		out_file_path = strcpy(out_file_path_buf, out_obj_dir_path);
		out_file_path = strcpy(out_file_path, "/");
		out_file_path = strcpy(out_file_path, *p);
		out_file_path = strcpy(out_file_path, ".o");
		mkreqdirs(out_file_path_buf);

		aa_init(&aa, cc);
		aa_extend_from(&aa, compile_args);
		aa_extend(&aa, "-c", in_file_path_buf, "-o", out_file_path_buf);
		aa_run0(&aa);

		aa_append(&aa_link, out_file_path_buf);
	}
	aa_run0(&aa_link);
}


// Kinda boring parts /////////////////////////////////////////////////////////

#define TCC_ARGS_NOSTD "-nostdlib", "-nostdinc"


void sanity_test() {
	struct args_accumulator aa1, aa2;

	log("sanity-testing run()...");
	log("* testing run() -> retcode 0...");
	run0("/0/out/tcc-seed", "--help");
	log("* testing run() -> retcode 1...");
	run(1, "/0/out/tcc-seed", "-ar", "--help");
	log("run() seems to work OK");

	log("sanity-testing args accumulator...");
	log("* testing aa_append, aa_extend, aa_sort and aa_run0...");
	aa_init(&aa1);
	aa_init(&aa2);
	aa_append(&aa1, "/0/out/tcc-seed");
	aa_append(&aa2, "-ar");
	aa_extend(&aa2, "help-must-precede-ar", "--help");
	aa_sort(&aa2);
	aa_extend_from(&aa1, &aa2);
	assert(!strcmp(((char**) &aa1)[0], "/0/out/tcc-seed"));
	assert(!strcmp(((char**) &aa1)[1], "--help"));
	assert(!strcmp(((char**) &aa1)[2], "-ar"));
	assert(!strcmp(((char**) &aa1)[3], "help-must-precede-ar"));
	assert(NULL == ((char**) &aa1)[4]);
	aa_run0(&aa1);

	log("* testing aa_multi and aa_run for 1...");
	aa_init(&aa1, "/0/out/tcc-seed", "-ar", "--help");
	assert(aa_run(&aa1) == 1);
}


// Interesting parts: libtcc1 /////////////////////////////////////////////////


void compile_libtcc1_1st_time_nostd(const char* cc) {
	log("compiling our first libtcc1.a...");
	mkdirs_at("/1", "tmp/tinycc/libtcc1", "out/tinycc/lib");
	mass_compile(cc, (char* []) { TCC_ARGS_NOSTD, "-DTCC_MUSL", NULL },
		"/1/src/tinycc/lib", (char* []) {
			"libtcc1.c", "alloca.S",
			"dsohandle.c", "stdatomic.c", "va_list.c",
		0},
		"/1/tmp/tinycc/libtcc1", "/1/out/tinycc/lib/libtcc1.a");
}  // see also compile_libtcc1 far below


// Interesting parts: protomusl ////////////////////////////////////////////////

#define PROTOMUSL_EXTRA_CFLAGS \
		"-std=c99", \
		"-D_XOPEN_SOURCE=700"
#define PROTOMUSL_INTERNAL_INCLUDES \
		"-I/1/src/protomusl/src/include", \
		"-I/1/src/protomusl/arch/x86_64", \
		"-I/1/src/protomusl/host-generated/sed1", \
		"-I/1/src/protomusl/host-generated/sed2", \
		"-I/1/src/protomusl/arch/generic", \
		"-I/1/src/protomusl/src/internal", \
		"-I/1/src/protomusl/include"
#define PROTOMUSL_NOSTD_LDFLAGS_PRE \
		"-static", \
		"/1/out/protomusl/lib/crt1.o", \
		"/1/out/protomusl/lib/crti.o"
#define PROTOMUSL_NOSTD_LDFLAGS_POST \
		"/1/out/protomusl/lib/libc.a", \
		"/1/out/protomusl/lib/crtn.o"
#define PROTOMUSL_INCLUDES \
		"-I/1/src/protomusl/include", \
		"-I/1/src/protomusl/arch/x86_64", \
		"-I/1/src/protomusl/arch/generic", \
		"-I/1/src/protomusl/host-generated/sed1", \
		"-I/1/src/protomusl/host-generated/sed2"

void compile_protomusl(const char* cc) {
	struct args_accumulator aa;
	aa_init(&aa);

	log("compiling part of musl (protomusl)...");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/conf");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/ctype");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/dirent");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/env");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/errno");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/exit");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/fcntl");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/fenv");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/internal");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/ldso");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/legacy");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/linux");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/locale");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/malloc");
	aa_extend_from_dir(&aa, 2, "/1/src/protomusl/src/malloc/mallocng");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/math");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/misc");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/mman");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/multibyte");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/network");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/passwd");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/prng");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/process");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/regex");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/select");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/setjmp");
	aa_extend_from_dir(&aa, 2, "/1/src/protomusl/src/setjmp/x86_64");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/signal");
	aa_extend_from_dir(&aa, 2, "/1/src/protomusl/src/signal/x86_64");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/stat");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/stdio");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/stdlib");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/string");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/temp");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/termios");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/thread");
	aa_extend_from_dir(&aa, 2, "/1/src/protomusl/src/thread/x86_64");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/time");
	aa_extend_from_dir(&aa, 1, "/1/src/protomusl/src/unistd");
	mass_compile(cc, (char*[]) {
			TCC_ARGS_NOSTD,
			PROTOMUSL_EXTRA_CFLAGS,
			PROTOMUSL_INTERNAL_INCLUDES,
		0},
		"/1/src/protomusl/src", &aa,
		"/1/tmp/protomusl", "/1/out/protomusl/lib/libc.a");

	log("compiling crt bits of protomusl...");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INTERNAL_INCLUDES, "-DCRT",
		"-c", "/1/src/protomusl/crt/crt1.c",
		"-o", "/1/out/protomusl/lib/crt1.o");
	run0(cc, TCC_ARGS_NOSTD, "-DCRT",
		"-c", "/1/src/protomusl/crt/crti.c",
		"-o", "/1/out/protomusl/lib/crti.o");
	run0(cc, TCC_ARGS_NOSTD, "-DCRT",
		"-c", "/1/src/protomusl/crt/crtn.c",
		"-o", "/1/out/protomusl/lib/crtn.o");
}


void test_example_1st_time_nostd(const char* cc) {
	log("linking an example (1st time)...");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"/1/src/hello.c",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/1/out/tinycc/lib/libtcc1.a",
		"-o", "/1/tmp/protomusl-hello");

	log("executing an example...");
	run(42, "/1/tmp/protomusl-hello");
}


// Interesting parts: recompiling tcc //////////////////////////////////////////

void compile_libtcc1(const char* cc) {
	log("recompiling libtcc1.a...");
	mass_compile(cc, (char*[]) { "-DTCC_MUSL", PROTOMUSL_INCLUDES, 0},
		"/1/src//tinycc/lib", (char*[]) {
			"libtcc1.c", "alloca.S",
			"dsohandle.c", "stdatomic.c", "va_list.c",
			// now we can compile more
			"tcov.c", "bcheck.c", "alloca-bt.S",
		0},
		"/1/tmp/tinycc/libtcc1", "/1/out/tinycc/lib/libtcc1.a");
}

#define TCC_CFLAGS \
		"-I/1/src/tinycc", \
		"-I/1/src/tinycc/include", \
		"-I/1/tmp/tinycc/gen", \
		"-DTCC_VERSION=\"mob-git1645616\"", \
		"-DTCC_GITHASH=\"mob:164516\"", \
		"-DTCC_TARGET_X86_64", \
		"-DTCC_MUSL", \
		"-DONE_SOURCE=0", \
		"-DCONFIG_TCCDIR=\"/1/out/tinycc/lib\"", \
		"-DCONFIG_TCC_SYSINCLUDEPATHS=\"/1/out/protomusl/include\"", \
		"-DCONFIG_TCC_LIBPATHS=\"/1/out/protomusl/lib\"", \
		"-DCONFIG_TCC_CRTPREFIX=\"/1/out/protomusl/lib\"", \
		"-DCONFIG_TCC_ELFINTERP=\"/sorry/not/yet\"", \
		"-DCONFIG_TCC_PREDEFS=1"

void compile_tcc_1st_time_nostd(const char* cc) {
	log("compiling tcc's conftest...");
	mkdirs_at("/1/tmp/tinycc", "gen", "lib", "bin");
	mkdirs_at("/1/out/tinycc", "lib", "bin");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"-DC2STR", "/1/src/tinycc/conftest.c",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/1/out/tinycc/lib/libtcc1.a",
		"-o", "/1/tmp/tinycc/conftest"
		);
	log("generating tccdefs_.h with conftest...");
	run0("/1/tmp/tinycc/conftest", "/1/src/tinycc/include/tccdefs.h",
		"/1/tmp/tinycc/gen/tccdefs_.h");

	log("compiling libtcc...");
	mass_compile(cc, (char*[]) {
			TCC_ARGS_NOSTD,
			PROTOMUSL_INCLUDES,
			TCC_CFLAGS,
		0},
		"/1/src/tinycc", (char*[]) {
			"libtcc.c", "tccpp.c", "tccgen.c", "tccelf.c",
			"tccasm.c", "tccrun.c",
			"x86_64-gen.c", "x86_64-link.c", "i386-asm.c",
		0},
		"/1/tmp/tinycc/libtcc", "/1/out/tinycc/lib/libtcc.a");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES, TCC_CFLAGS,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"/1/src/tinycc/tcc.c",
		"/1/out/tinycc/lib/libtcc.a",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/1/out/tinycc/lib/libtcc1.a",
		"-o", "/1/out/tinycc/bin/tcc");
	run0("/1/out/tinycc/bin/tcc", "-print-search-dirs");
}


void compile_tcc(const char* cc) {
	log("recompiling libtcc...");
	mass_compile(cc, (char*[]) { PROTOMUSL_INCLUDES, TCC_CFLAGS, 0},
		"/1/src/tinycc", (char*[]) {
			"libtcc.c", "tccpp.c", "tccgen.c", "tccelf.c",
			"tccasm.c", "tccrun.c",
			"x86_64-gen.c", "x86_64-link.c", "i386-asm.c",
		0},
		"/1/tmp/tinycc/libtcc", "/1/out/tinycc/lib/libtcc.a");
	run0(cc, PROTOMUSL_INCLUDES, TCC_CFLAGS, "-static",
		"/1/src/tinycc/tcc.c", "/1/out/tinycc/lib/libtcc.a",
		"-o", "/1/out/tinycc/bin/tcc");
}

void test_example_intermediate(const char* cc) {
	log("linking an example (our tcc, includes not installed)...");
	run0(cc, PROTOMUSL_INCLUDES, "-static",
		"/1/src/hello.c", "-o", "/1/tmp/protomusl-hello");

	log("executing an example...");
	run(42, "/1/tmp/protomusl-hello");
}

void test_example_final(const char* cc_wrapper) {
	log("linking an example (wrapped tcc, includes installed)...");
	run0(cc_wrapper, "/1/src/hello.c", "-o", "/1/tmp/protomusl-hello");

	log("executing an example...");
	run(42, "/1/tmp/protomusl-hello");
}


// Interesting parts: hacky standalone busybox applets /////////////////////////

void compile_standalone_busybox_applets(const char* cc) {
	log("compiling protolibbb...");
	mass_compile(cc, (char*[]) {
		PROTOMUSL_INCLUDES,
		"-I/1/src/protobusybox/include/",
		"-I/1/src/protobusybox/libbb/",
		"-I/1/src/",
		"-include", "protobusybox.h",
		0},
		"/1/src/protobusybox/libbb", (char*[]) {
			"ask_confirmation.c",
			"auto_string.c",
			"bb_cat.c",
			"bb_getgroups.c",
			"bb_pwd.c",
			"bb_strtonum.c",
			"compare_string_array.c",
			"concat_path_file.c",
			"concat_subpath_file.c",
			"copy_file.c",
			"copyfd.c",
			"crc32.c",
			"default_error_retval.c",
			"dump.c",
			"endofname.c",
			"executable.c",
			"fclose_nonstdin.c",
			"fflush_stdout_and_exit.c",
			"full_write.c",
			"get_last_path_component.c",
			"get_line_from_file.c",
			"getopt32.c",
			"inode_hash.c",
			"isdirectory.c",
			"isqrt.c",
			"last_char_is.c",
			"llist.c",
			"make_directory.c",
			"messages.c",
			"mode_string.c",
			"parse_mode.c",
			"perror_msg.c",
			"perror_nomsg_and_die.c",
			"printable_string.c",
			"process_escape_sequence.c",
			"procps.c",
			"ptr_to_globals.c",
			"read.c",
			"read_printf.c",
			"recursive_action.c",
			"remove_file.c",
			"safe_poll.c",
			"safe_strncpy.c",
			"safe_write.c",
			"signals.c",
			"single_argv.c",
			"skip_whitespace.c",
			"sysconf.c",
			"time.c",
			"u_signal_names.c",
			"verror_msg.c",
			"vfork_daemon_rexec.c",
			"wfopen.c",
			"wfopen_input.c",
			"xatonum.c",
			"xfunc_die.c",
			"xfuncs.c",
			"xfuncs_printf.c",
			"xgetcwd.c",
			"xreadlink.c",
			"xrealloc_vector.c",
			"xregcomp.c",
		0},
		"/1/tmp/protobusybox/libbb", "/1/tmp/protobusybox/libbb.a");


	log("compiling standalone protobusybox applets...");
	mkreqdirs("/1/out/protobusybox/bin/");
	#define compile_applet(applet_name, files...) \
			run0(cc, PROTOMUSL_INCLUDES, \
					"-D__GNUC__=2", \
					"-D__GNUC_MINOR__=7", \
					"-static", \
					"-I/1/src/protobusybox/include", \
					"-I/1/src/", \
					"-include", "protobusybox.h", \
					"-DAPPLET_MAIN=" applet_name "_main", \
					"/1/src/protobusybox.c", \
					## files, \
					"/1/tmp/protobusybox/libbb.a", \
					"-o", \
					"/1/out/protobusybox/bin/" applet_name);
	compile_applet("echo", "/1/src/protobusybox/coreutils/echo.c")
	run0("/1/out/protobusybox/bin/echo", "Hello from protobusybox!");

	compile_applet("ash",
		"/1/src/protobusybox/shell/shell_common.c",
		"/1/src/protobusybox/shell/ash_ptr_hack.c",
		"/1/src/protobusybox/shell/math.c",
		"/1/src/protobusybox/coreutils/printf.c",
		"/1/src/protobusybox/coreutils/test_ptr_hack.c",
		"/1/src/protobusybox/coreutils/test.c",
		"/1/src/protobusybox/shell/ash.c")
	run(42, "/1/out/protobusybox/bin/ash", "-c",
		"printf 'Hello from ash!\n'; exit 42");

	compile_applet("basename", "/1/src/protobusybox/coreutils/basename.c")
	compile_applet("cat", "/1/src/protobusybox/coreutils/cat.c")
	compile_applet("chmod", "/1/src/protobusybox/coreutils/chmod.c")
	compile_applet("cp",
		"/1/src/protobusybox/coreutils/libcoreutils/cp_mv_stat.c",
		"/1/src/protobusybox/coreutils/cp.c");
	compile_applet("cut", "/1/src/protobusybox/coreutils/cut.c");
	compile_applet("dirname", "/1/src/protobusybox/coreutils/dirname.c")
	compile_applet("env", "/1/src/protobusybox/coreutils/env.c");
	compile_applet("expr", "/1/src/protobusybox/coreutils/expr.c");
	compile_applet("head", "/1/src/protobusybox/coreutils/head.c");
	compile_applet("install", "/1/src/protobusybox/coreutils/install.c");
	compile_applet("ln", "/1/src/protobusybox/coreutils/ln.c");
	compile_applet("ls", "/1/src/protobusybox/coreutils/ls.c");
	compile_applet("mkdir", "/1/src/protobusybox/coreutils/mkdir.c");
	compile_applet("mktemp", "/1/src/protobusybox/coreutils/mktemp.c");
	compile_applet("mv",
		"/1/src/protobusybox/coreutils/libcoreutils/cp_mv_stat.c",
		"/1/src/protobusybox/coreutils/mv.c");
	compile_applet("od", "/1/src/protobusybox/coreutils/od.c");
	compile_applet("pwd", "/1/src/protobusybox/coreutils/pwd.c");
	compile_applet("rm", "/1/src/protobusybox/coreutils/rm.c");
	compile_applet("rmdir", "/1/src/protobusybox/coreutils/rmdir.c");
	compile_applet("sleep", "/1/src/protobusybox/coreutils/sleep.c");
	compile_applet("sort", "/1/src/protobusybox/coreutils/sort.c");
	compile_applet("touch", "/1/src/protobusybox/coreutils/touch.c");
	compile_applet("tr", "/1/src/protobusybox/coreutils/tr.c");
	compile_applet("true", "/1/src/protobusybox/coreutils/true.c");
	compile_applet("uname", "/1/src/protobusybox/coreutils/uname.c");
	compile_applet("uniq", "/1/src/protobusybox/coreutils/uniq.c");
	compile_applet("wc", "/1/src/protobusybox/coreutils/wc.c");

	#define LIBARCHIVE "/1/src/protobusybox/archival/libarchive"
	compile_applet("bzip2",
		LIBARCHIVE "/decompress_bunzip2.c",
		LIBARCHIVE "/decompress_gunzip.c",
		LIBARCHIVE "/decompress_unxz.c",
		LIBARCHIVE "/open_transformer.c",
		"/1/src/protobusybox/archival/bbunzip.c",
		"/1/src/protobusybox/archival/bzip2.c");
	compile_applet("gzip",
		LIBARCHIVE "/decompress_bunzip2.c",
		LIBARCHIVE "/decompress_gunzip.c",
		LIBARCHIVE "/open_transformer.c",
		"/1/src/protobusybox/archival/bbunzip.c",
		"/1/src/protobusybox/archival/gzip.c");
	compile_applet("tar",
		LIBARCHIVE "/data_align.c",
		LIBARCHIVE "/data_extract_all.c",
		LIBARCHIVE "/data_extract_to_stdout.c",
		LIBARCHIVE "/data_skip.c",
		LIBARCHIVE "/filter_accept_all.c",
		LIBARCHIVE "/filter_accept_reject_list.c",
		LIBARCHIVE "/find_list_entry.c",
		LIBARCHIVE "/get_header_tar.c",
		LIBARCHIVE "/header_list.c",
		LIBARCHIVE "/header_skip.c",
		LIBARCHIVE "/header_verbose_list.c",
		LIBARCHIVE "/init_handle.c",
		LIBARCHIVE "/seek_by_jump.c",
		LIBARCHIVE "/seek_by_read.c",
		LIBARCHIVE "/unsafe_prefix.c",
		LIBARCHIVE "/unsafe_symlink_target.c",
		"/1/src/protobusybox/archival/tar.c");

	compile_applet("awk", "/1/src/protobusybox/editors/awk.c");
	compile_applet("cmp", "/1/src/protobusybox/editors/cmp.c");
	compile_applet("diff", "/1/src/protobusybox/editors/diff.c");
	compile_applet("sed", "/1/src/protobusybox/editors/sed.c");

	compile_applet("grep", "/1/src/protobusybox/findutils/grep.c");
	compile_applet("find", "/1/src/protobusybox/findutils/find.c");
	compile_applet("xargs", "/1/src/protobusybox/findutils/xargs.c");
}


// Little things we'll do now when we have a shell /////////////////////////////

void verify_tcc_stability(void) {
	run0("/1/out/protobusybox/bin/cp",
		"/1/out/tinycc/bin/tcc", "/1/tmp/tcc-bak");
	compile_tcc("/1/out/tinycc/bin/tcc");
	run0("/1/out/protobusybox/bin/diff",
		"/1/out/tinycc/bin/tcc", "/1/tmp/tcc-bak");
}

void compose_stage2(void) {
	run0("/1/out/protobusybox/bin/ash", "-uexvc", "
		# FIXME REMOVE
		/1/out/protobusybox/bin/install -m 755 /0/out/tcc-seed /x

		:> /1/tmp/empty.c
		/1/out/tinycc/bin/tcc -c /1/tmp/empty.c -o /1/tmp/empty.o
		/1/out/tinycc/bin/tcc -ar /1/tmp/empty.a /1/tmp/empty.o
		/1/out/protobusybox/bin/cp /1/tmp/empty.a \
			/1/out/protomusl/lib/libm.a
		/1/out/protobusybox/bin/cp /1/tmp/empty.a \
			/1/out/protomusl/lib/libpthread.a

		/1/out/protobusybox/bin/rm -rf /1/out/protomusl/include
		/1/out/protobusybox/bin/mkdir -p /1/out/protomusl/include
		/1/out/protobusybox/bin/cp -r \
			/1/src/protomusl/host-generated/sed1/bits \
			/1/src/protomusl/host-generated/sed2/bits \
			/1/src/protomusl/arch/generic/* \
			/1/src/protomusl/arch/x86_64/* \
			/1/src/protomusl/include/* \
			/1/out/protomusl/include/
	");
}


void wrap_tcc_tools(void) {
	#define EXECTCC "#!/1/out/protobusybox/bin/ash\n" \
			"exec /1/out/tinycc/bin/tcc"
	#define PASSTHROUGH "\\\"\\$@\\\"" //  i.e., \"\$@\", i.e, "$@"
	run0("/1/out/protobusybox/bin/ash", "-uexvc", "
		PATH=/1/out/protobusybox/bin
		mkdir -p /1/out/tinycc/wrappers; cd /1/out/tinycc/wrappers
		_CPP_ARGS=\"-I/1/out/protomusl/include\"
		_LD_ARGS='-static'
		echo -e \"" EXECTCC " $_LD_ARGS " PASSTHROUGH"\" > cc
		echo -e \"" EXECTCC " -E $_CPP_ARGS " PASSTHROUGH"\" > cpp
		echo -e \"" EXECTCC " $_LD_ARGS " PASSTHROUGH"\" > ld
		echo -e \"" EXECTCC " -ar " PASSTHROUGH "\" > ar
		chmod +x cc cpp ld ar
	");
}

void clean_up(void) {
	run0("/1/out/protobusybox/bin/rm", "-r", "/1/tmp");
}


// The main plot ///////////////////////////////////////////////////////////////

int _start() {
	struct args_accumulator aa_cmd;
	struct args_accumulator aa_link_objs;

	log("hello from stage1!");

	log("creating directories...");
	mkdirs_at("/1", "/tmp", "/out");
	sanity_test();

	// starting with the seeded TCC
	compile_libtcc1_1st_time_nostd("/0/out/tcc-seed");
	compile_protomusl("/0/out/tcc-seed");
	test_example_1st_time_nostd("/0/out/tcc-seed");

	// build the first TCC that comes from our sources
	compile_tcc_1st_time_nostd("/0/out/tcc-seed");
	test_example_intermediate("/1/out/tinycc/bin/tcc");
	// rebuild everything with it
	compile_libtcc1("/1/out/tinycc/bin/tcc");
	compile_protomusl("/1/out/tinycc/bin/tcc");
	test_example_intermediate("/1/out/tinycc/bin/tcc");

	// this is the final tcc we'll build, should not be worth repeating
	compile_tcc("/1/out/tinycc/bin/tcc");
	// recompile everything else with the final tcc (could be an overkill)
	compile_libtcc1("/1/out/tinycc/bin/tcc");
	compile_protomusl("/1/out/tinycc/bin/tcc");
	test_example_intermediate("/1/out/tinycc/bin/tcc");

	compile_standalone_busybox_applets("/1/out/tinycc/bin/tcc");

	verify_tcc_stability();
	compose_stage2();
	wrap_tcc_tools();
	test_example_final("/1/out/tinycc/wrappers/cc");
	//clean_up();

	log("done");

	assert(execve("/2/stage2.sh", (char*[]) {"stage2.sh", 0}, NULL));

	log("could not exec into stage 2 (ok when building with make)");
	return 99;
}
