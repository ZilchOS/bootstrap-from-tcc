// SPDX-FileCopyrightText: 2021 Alexander Sosedkin <monk@unboiled.info>
// SPDX-License-Identifier: MIT

// syscalls (x86_64) ///////////////////////////////////////////////////////////

#include "1-stage1/syscall.h"
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


// random defines //////////////////////////////////////////////////////////////

#define NULL ((void*) 0)
#define STDOUT 1
#define STDERR 2
#define O_RDONLY 0
#define O_DIRECTORY 0200000
#define DT_REG 8


// basic QoL ///////////////////////////////////////////////////////////////////

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
	assert(write_(STDOUT, "### 1-stage1.c: ") == 16);
	assert(write_(STDOUT, msg) == strlen(msg));
}
void log_continue_line(const char* msg) {
	assert(write_(STDOUT, msg) == strlen(msg));
}
void log_end_line() { assert(write_(STDOUT, "\n") == 1); }
void log(const char* msg) { log_begin_line(msg); log_end_line(); };


// more library function substitutes ///////////////////////////////////////////

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


// my convenience functions: mkdir'ing /////////////////////////////////////////


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


// my convenience functions: fork + exec ///////////////////////////////////////

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


// my convenience functions: dynamic args accumulation / command execution /////

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


// my convenience functions: compiling whole directories worth of files ////////

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
	aa_sort(&aa);  // iteration order isn't guaranteed, make stable
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


// Kinda boring parts //////////////////////////////////////////////////////////

#define TCC_ARGS_NOSTD "-nostdlib", "-nostdinc"


void sanity_test() {
	struct args_accumulator aa1, aa2;

	log("sanity-testing run()...");
	log("* testing run() -> retcode 0...");
	run0("/store/0-tcc-seed", "--help");
	log("* testing run() -> retcode 1...");
	run(1, "/store/0-tcc-seed", "-ar", "--help");
	log("run() seems to work OK");

	log("sanity-testing args accumulator...");
	log("* testing aa_append, aa_extend, aa_sort and aa_run0...");
	aa_init(&aa1);
	aa_init(&aa2);
	aa_append(&aa1, "/store/0-tcc-seed");
	aa_append(&aa2, "-ar");
	aa_extend(&aa2, "help-must-precede-ar", "--help");
	aa_sort(&aa2);
	aa_extend_from(&aa1, &aa2);
	assert(!strcmp(((char**) &aa1)[0], "/store/0-tcc-seed"));
	assert(!strcmp(((char**) &aa1)[1], "--help"));
	assert(!strcmp(((char**) &aa1)[2], "-ar"));
	assert(!strcmp(((char**) &aa1)[3], "help-must-precede-ar"));
	assert(NULL == ((char**) &aa1)[4]);
	aa_run0(&aa1);

	log("* testing aa_multi and aa_run for 1...");
	aa_init(&aa1, "/store/0-tcc-seed", "-ar", "--help");
	assert(aa_run(&aa1) == 1);
}


// Interesting parts: libtcc1 //////////////////////////////////////////////////


void compile_libtcc1_1st_time_nostd(const char* cc) {
	log("compiling our first libtcc1.a...");
	mass_compile(cc, (char* []) { TCC_ARGS_NOSTD, "-DTCC_MUSL", NULL },
		"/protosrc/tinycc/lib", (char* []) {
			"libtcc1.c", "alloca.S",
			"dsohandle.c", "stdatomic.c", "va_list.c",
		0},
		"/tmp/1-stage1/tinycc/libtcc1",
		"/store/1-stage1/tinycc/lib/libtcc1.a");
}  // see also compile_libtcc1 far below


// Interesting parts: protomusl ////////////////////////////////////////////////

#define PROTOMUSL_EXTRA_CFLAGS \
		"-std=c99", \
		"-D_XOPEN_SOURCE=700"
#define PROTOMUSL_INTERNAL_INCLUDES \
		"-I/protosrc/protomusl/src/include", \
		"-I/protosrc/protomusl/arch/x86_64", \
		"-I/protosrc/protomusl/host-generated/sed1", \
		"-I/protosrc/protomusl/host-generated/sed2", \
		"-I/protosrc/protomusl/arch/generic", \
		"-I/protosrc/protomusl/src/internal", \
		"-I/protosrc/protomusl/include"
#define PROTOMUSL_NOSTD_LDFLAGS_PRE \
		"-static", \
		"/store/1-stage1/protomusl/lib/crt1.o", \
		"/store/1-stage1/protomusl/lib/crti.o"
#define PROTOMUSL_NOSTD_LDFLAGS_POST \
		"/store/1-stage1/protomusl/lib/libc.a", \
		"/store/1-stage1/protomusl/lib/crtn.o"
#define PROTOMUSL_INCLUDES \
		"-I/protosrc/protomusl/include", \
		"-I/protosrc/protomusl/arch/x86_64", \
		"-I/protosrc/protomusl/arch/generic", \
		"-I/protosrc/protomusl/host-generated/sed1", \
		"-I/protosrc/protomusl/host-generated/sed2"

void compile_protomusl(const char* cc) {
	struct args_accumulator aa;
	aa_init(&aa);

	log("compiling part of musl (protomusl)...");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/conf");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/ctype");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/dirent");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/env");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/errno");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/exit");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/fcntl");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/fenv");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/internal");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/ldso");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/legacy");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/linux");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/locale");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/malloc");
	aa_extend_from_dir(&aa, 2, "/protosrc/protomusl/src/malloc/mallocng");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/math");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/misc");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/mman");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/multibyte");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/network");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/passwd");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/prng");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/process");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/regex");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/select");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/setjmp");
	aa_extend_from_dir(&aa, 2, "/protosrc/protomusl/src/setjmp/x86_64");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/signal");
	aa_extend_from_dir(&aa, 2, "/protosrc/protomusl/src/signal/x86_64");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/stat");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/stdio");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/stdlib");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/string");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/temp");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/termios");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/thread");
	aa_extend_from_dir(&aa, 2, "/protosrc/protomusl/src/thread/x86_64");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/time");
	aa_extend_from_dir(&aa, 1, "/protosrc/protomusl/src/unistd");
	mass_compile(cc, (char*[]) {
			TCC_ARGS_NOSTD,
			PROTOMUSL_EXTRA_CFLAGS,
			PROTOMUSL_INTERNAL_INCLUDES,
		0},
		"/protosrc/protomusl/src", &aa,
		"/tmp/1-stage1/protomusl",
		"/store/1-stage1/protomusl/lib/libc.a");

	log("compiling crt bits of protomusl...");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INTERNAL_INCLUDES, "-DCRT",
		"-c", "/protosrc/protomusl/crt/crt1.c",
		"-o", "/store/1-stage1/protomusl/lib/crt1.o");
	run0(cc, TCC_ARGS_NOSTD, "-DCRT",
		"-c", "/protosrc/protomusl/crt/crti.c",
		"-o", "/store/1-stage1/protomusl/lib/crti.o");
	run0(cc, TCC_ARGS_NOSTD, "-DCRT",
		"-c", "/protosrc/protomusl/crt/crtn.c",
		"-o", "/store/1-stage1/protomusl/lib/crtn.o");
}


void test_example_1st_time_nostd(const char* cc) {
	log("linking an example (1st time)...");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"/recipes/1-stage1/hello.c",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/store/1-stage1/tinycc/lib/libtcc1.a",
		"-o", "/tmp/1-stage1/protomusl-hello");

	log("executing an example...");
	run(42, "/tmp/1-stage1/protomusl-hello");
}


// Interesting parts: recompiling tcc //////////////////////////////////////////

void compile_libtcc1(const char* cc) {
	log("recompiling libtcc1.a...");
	mass_compile(cc, (char*[]) { "-DTCC_MUSL", PROTOMUSL_INCLUDES, 0},
		"/protosrc/tinycc/lib", (char*[]) {
			"libtcc1.c", "alloca.S",
			"dsohandle.c", "stdatomic.c", "va_list.c",
			// now we can compile more
			"tcov.c", "bcheck.c", "alloca-bt.S",
		0},
		"/tmp/1-stage1/tinycc/libtcc1",
		"/store/1-stage1/tinycc/lib/libtcc1.a");
}

#define TCC_CFLAGS \
		"-I/protosrc/tinycc", \
		"-I/protosrc/tinycc/include", \
		"-I/tmp/1-stage1/tinycc/gen", \
		"-DTCC_VERSION=\"mob-gitda11cf6\"", \
		"-DTCC_GITHASH=\"mob:da11cf6\"", \
		"-DTCC_TARGET_X86_64", \
		"-DTCC_MUSL", \
		"-DONE_SOURCE=0", \
		"-DCONFIG_TCCDIR=\"/store/1-stage1/tinycc/lib\"", \
		"-DCONFIG_TCC_SYSINCLUDEPATHS=" \
			"\"/store/1-stage1/protomusl/include\"", \
		"-DCONFIG_TCC_LIBPATHS=\"/store/1-stage1/protomusl/lib\"", \
		"-DCONFIG_TCC_CRTPREFIX=\"/store/1-stage1/protomusl/lib\"", \
		"-DCONFIG_TCC_ELFINTERP=\"/sorry/not/yet\"", \
		"-DCONFIG_TCC_PREDEFS=1"

void compile_tcc_1st_time_nostd(const char* cc) {
	log("compiling tcc's conftest...");
	mkdirs_at("/tmp/1-stage1/tinycc", "gen", "lib", "bin");
	mkdirs_at("/store/1-stage1/tinycc", "lib", "bin");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"-DC2STR", "/protosrc/tinycc/conftest.c",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/store/1-stage1/tinycc/lib/libtcc1.a",
		"-o", "/tmp/1-stage1/tinycc/conftest"
		);
	log("generating tccdefs_.h with conftest...");
	run0("/tmp/1-stage1/tinycc/conftest",
		"/protosrc/tinycc/include/tccdefs.h",
		"/tmp/1-stage1/tinycc/gen/tccdefs_.h");

	log("compiling libtcc...");
	mass_compile(cc, (char*[]) {
			TCC_ARGS_NOSTD,
			PROTOMUSL_INCLUDES,
			TCC_CFLAGS,
		0},
		"/protosrc/tinycc", (char*[]) {
			"libtcc.c", "tccpp.c", "tccgen.c", "tccelf.c",
			"tccasm.c", "tccrun.c",
			"x86_64-gen.c", "x86_64-link.c", "i386-asm.c",
		0},
		"/tmp/1-stage1/tinycc/libtcc",
		"/store/1-stage1/tinycc/lib/libtcc.a");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES, TCC_CFLAGS,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"/protosrc/tinycc/tcc.c",
		"/store/1-stage1/tinycc/lib/libtcc.a",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/store/1-stage1/tinycc/lib/libtcc1.a",
		"-o", "/store/1-stage1/tinycc/bin/tcc");
	run0("/store/1-stage1/tinycc/bin/tcc", "-print-search-dirs");
}


void compile_tcc(const char* cc) {
	log("recompiling libtcc...");
	mass_compile(cc, (char*[]) { PROTOMUSL_INCLUDES, TCC_CFLAGS, 0},
		"/protosrc/tinycc", (char*[]) {
			"libtcc.c", "tccpp.c", "tccgen.c", "tccelf.c",
			"tccasm.c", "tccrun.c",
			"x86_64-gen.c", "x86_64-link.c", "i386-asm.c",
		0},
		"/tmp/1-stage1/tinycc/libtcc",
		"/store/1-stage1/tinycc/lib/libtcc.a");
	run0(cc, PROTOMUSL_INCLUDES, TCC_CFLAGS, "-static",
		"/protosrc/tinycc/tcc.c",
		"/store/1-stage1/tinycc/lib/libtcc.a",
		"-o", "/store/1-stage1/tinycc/bin/tcc");
}

void test_example_intermediate(const char* cc) {
	log("linking an example (our tcc, includes not installed)...");
	run0(cc, PROTOMUSL_INCLUDES, "-static", "/recipes/1-stage1/hello.c",
		"-o", "/tmp/1-stage1/protomusl-hello");

	log("executing an example...");
	run(42, "/tmp/1-stage1/protomusl-hello");
}

void test_example_final(const char* cc_wrapper) {
	log("linking an example (wrapped tcc, includes installed)...");
	run0(cc_wrapper, "/recipes/1-stage1/hello.c",
			"-o", "/tmp/1-stage1/protomusl-hello");

	log("executing an example...");
	run(42, "/tmp/1-stage1/protomusl-hello");
}


// Interesting parts: hacky standalone busybox applets /////////////////////////

void compile_standalone_busybox_applets(const char* cc) {
	log("compiling protolibbb...");
	mass_compile(cc, (char*[]) {
		PROTOMUSL_INCLUDES,
		"-I/protosrc/protobusybox/include/",
		"-I/protosrc/protobusybox/libbb/",
		"-include", "/recipes/1-stage1/protobusybox.h",
		0},
		"/protosrc/protobusybox/libbb", (char*[]) {
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
		"/tmp/1-stage1/protobusybox/libbb",
		"/tmp/1-stage1/protobusybox/libbb.a");


	log("compiling standalone protobusybox applets...");
	mkreqdirs("/store/1-stage1/protobusybox/bin/");
	#define compile_applet(applet_name, files...) \
		run0(cc, PROTOMUSL_INCLUDES, \
			"-D__GNUC__=2", "-D__GNUC_MINOR__=7", \
			"-static", \
			"-I/protosrc/protobusybox/include", \
			"-include", "/recipes/1-stage1/protobusybox.h", \
			"-DAPPLET_MAIN=" applet_name "_main", \
			"/recipes/1-stage1/protobusybox.c", \
			## files, \
			"/tmp/1-stage1/protobusybox/libbb.a", \
			"-o", "/store/1-stage1/protobusybox/bin/" applet_name);
	compile_applet("echo", "/protosrc/protobusybox/coreutils/echo.c")
	run0("/store/1-stage1/protobusybox/bin/echo",
		"Hello from protobusybox!");

	compile_applet("ash",
		"/protosrc/protobusybox/shell/shell_common.c",
		"/protosrc/protobusybox/shell/ash_ptr_hack.c",
		"/protosrc/protobusybox/shell/math.c",
		"/protosrc/protobusybox/coreutils/printf.c",
		"/protosrc/protobusybox/coreutils/test_ptr_hack.c",
		"/protosrc/protobusybox/coreutils/test.c",
		"/protosrc/protobusybox/shell/ash.c")
	run(42, "/store/1-stage1/protobusybox/bin/ash", "-c",
		"printf 'Hello from ash!\n'; exit 42");

	compile_applet("basename",
		"/protosrc/protobusybox/coreutils/basename.c")
	compile_applet("cat", "/protosrc/protobusybox/coreutils/cat.c")
	compile_applet("chmod", "/protosrc/protobusybox/coreutils/chmod.c")
	compile_applet("cp",
		"/protosrc/protobusybox/coreutils/libcoreutils/cp_mv_stat.c",
		"/protosrc/protobusybox/coreutils/cp.c");
	compile_applet("cut", "/protosrc/protobusybox/coreutils/cut.c");
	compile_applet("dirname", "/protosrc/protobusybox/coreutils/dirname.c")
	compile_applet("env", "/protosrc/protobusybox/coreutils/env.c");
	compile_applet("expr", "/protosrc/protobusybox/coreutils/expr.c");
	compile_applet("head", "/protosrc/protobusybox/coreutils/head.c");
	compile_applet("install", "/protosrc/protobusybox/coreutils/install.c");
	compile_applet("ln", "/protosrc/protobusybox/coreutils/ln.c");
	compile_applet("ls", "/protosrc/protobusybox/coreutils/ls.c");
	compile_applet("mkdir", "/protosrc/protobusybox/coreutils/mkdir.c");
	compile_applet("mktemp", "/protosrc/protobusybox/coreutils/mktemp.c");
	compile_applet("mv",
		"/protosrc/protobusybox/coreutils/libcoreutils/cp_mv_stat.c",
		"/protosrc/protobusybox/coreutils/mv.c");
	compile_applet("od", "/protosrc/protobusybox/coreutils/od.c");
	compile_applet("pwd", "/protosrc/protobusybox/coreutils/pwd.c");
	compile_applet("rm", "/protosrc/protobusybox/coreutils/rm.c");
	compile_applet("rmdir", "/protosrc/protobusybox/coreutils/rmdir.c");
	compile_applet("sleep", "/protosrc/protobusybox/coreutils/sleep.c");
	compile_applet("sort", "/protosrc/protobusybox/coreutils/sort.c");
	compile_applet("touch", "/protosrc/protobusybox/coreutils/touch.c");
	compile_applet("tr", "/protosrc/protobusybox/coreutils/tr.c");
	compile_applet("true", "/protosrc/protobusybox/coreutils/true.c");
	compile_applet("uname", "/protosrc/protobusybox/coreutils/uname.c");
	compile_applet("uniq", "/protosrc/protobusybox/coreutils/uniq.c");
	compile_applet("wc", "/protosrc/protobusybox/coreutils/wc.c");

	#define LIBARCHIVE "/protosrc/protobusybox/archival/libarchive"
	compile_applet("tar",
		LIBARCHIVE "/data_align.c",
		LIBARCHIVE "/data_extract_all.c",
		LIBARCHIVE "/data_extract_to_stdout.c",
		LIBARCHIVE "/data_skip.c",
		LIBARCHIVE "/decompress_bunzip2.c",
		LIBARCHIVE "/decompress_gunzip.c",
		LIBARCHIVE "/decompress_unxz.c",
		LIBARCHIVE "/filter_accept_all.c",
		LIBARCHIVE "/filter_accept_reject_list.c",
		LIBARCHIVE "/find_list_entry.c",
		LIBARCHIVE "/get_header_tar.c",
		LIBARCHIVE "/header_list.c",
		LIBARCHIVE "/header_skip.c",
		LIBARCHIVE "/header_verbose_list.c",
		LIBARCHIVE "/init_handle.c",
		LIBARCHIVE "/open_transformer.c",
		LIBARCHIVE "/seek_by_jump.c",
		LIBARCHIVE "/seek_by_read.c",
		LIBARCHIVE "/unsafe_prefix.c",
		LIBARCHIVE "/unsafe_symlink_target.c",
		"/protosrc/protobusybox/archival/tar.c");

	compile_applet("awk", "/protosrc/protobusybox/editors/awk.c");
	compile_applet("cmp", "/protosrc/protobusybox/editors/cmp.c");
	compile_applet("diff", "/protosrc/protobusybox/editors/diff.c");
	compile_applet("sed", "/protosrc/protobusybox/editors/sed.c");

	compile_applet("grep", "/protosrc/protobusybox/findutils/grep.c");
	compile_applet("find", "/protosrc/protobusybox/findutils/find.c");
	compile_applet("xargs", "/protosrc/protobusybox/findutils/xargs.c");
}


// Little things we'll do now when we have a shell /////////////////////////////

void verify_tcc_stability(void) {
	run0("/store/1-stage1/protobusybox/bin/cp",
		"/store/1-stage1/tinycc/bin/tcc", "/tmp/1-stage1/tcc-bak");
	compile_tcc("/store/1-stage1/tinycc/bin/tcc");
	run0("/store/1-stage1/protobusybox/bin/diff",
		"/store/1-stage1/tinycc/bin/tcc", "/tmp/1-stage1/tcc-bak");
}

void tweak_output_in_store(void) {
	run0("/store/1-stage1/protobusybox/bin/ash", "-uexvc", "
		:> /tmp/1-stage1/empty.c
		/store/1-stage1/tinycc/bin/tcc -c /tmp/1-stage1/empty.c \
			-o /tmp/1-stage1/empty.o
		/store/1-stage1/tinycc/bin/tcc -ar /tmp/1-stage1/empty.a \
			/tmp/1-stage1/empty.o
		/store/1-stage1/protobusybox/bin/cp /tmp/1-stage1/empty.a \
			/store/1-stage1/protomusl/lib/libm.a
		/store/1-stage1/protobusybox/bin/cp /tmp/1-stage1/empty.a \
			/store/1-stage1/protomusl/lib/libpthread.a

		/store/1-stage1/protobusybox/bin/rm -rf \
			/store/1-stage1/protomusl/include
		/store/1-stage1/protobusybox/bin/mkdir -p \
			/store/1-stage1/protomusl/include
		/store/1-stage1/protobusybox/bin/cp -r \
			/protosrc/protomusl/host-generated/sed1/bits \
			/protosrc/protomusl/host-generated/sed2/bits \
			/protosrc/protomusl/arch/generic/* \
			/protosrc/protomusl/arch/x86_64/* \
			/protosrc/protomusl/include/* \
			/store/1-stage1/protomusl/include/
	");
}


void wrap_tcc_tools(void) {
	#define EXECTCC "#!/store/1-stage1/protobusybox/bin/ash\n" \
			"exec /store/1-stage1/tinycc/bin/tcc"
	#define PASSTHROUGH "\\\"\\$@\\\"" //  i.e., \"\$@\", i.e, "$@"
	run0("/store/1-stage1/protobusybox/bin/ash", "-uexvc", "
		PATH=/store/1-stage1/protobusybox/bin
		mkdir -p /store/1-stage1/tinycc/wrappers
		cd /store/1-stage1/tinycc/wrappers
		_CPP_ARGS=\"-I/store/1-stage1/protomusl/include\"
		_LD_ARGS='-static'
		echo -e \"" EXECTCC " $_LD_ARGS " PASSTHROUGH"\" > cc
		echo -e \"" EXECTCC " -E $_CPP_ARGS " PASSTHROUGH"\" > cpp
		echo -e \"" EXECTCC " $_LD_ARGS " PASSTHROUGH"\" > ld
		echo -e \"" EXECTCC " -ar " PASSTHROUGH "\" > ar
		chmod +x cc cpp ld ar
	");
}

void clean_up(void) {
	run0("/store/1-stage1/protobusybox/bin/rm", "-r", "/tmp/1-stage1");
}


// The main plot ///////////////////////////////////////////////////////////////

int _start() {
	struct args_accumulator aa_cmd;
	struct args_accumulator aa_link_objs;

	log("hello from stage1!");

	log("creating directories...");
	mkdirs_at("/", "/store/1-stage1", "/tmp/1-stage1");

	sanity_test();

	// starting with the seeded TCC
	compile_libtcc1_1st_time_nostd("/store/0-tcc-seed");
	compile_protomusl("/store/0-tcc-seed");
	test_example_1st_time_nostd("/store/0-tcc-seed");

	// build the first TCC that comes from our sources
	compile_tcc_1st_time_nostd("/store/0-tcc-seed");
	test_example_intermediate("/store/1-stage1/tinycc/bin/tcc");
	// rebuild everything with it
	compile_libtcc1("/store/1-stage1/tinycc/bin/tcc");
	compile_protomusl("/store/1-stage1/tinycc/bin/tcc");
	test_example_intermediate("/store/1-stage1/tinycc/bin/tcc");

	// this is the final tcc we'll build, should not be worth repeating
	compile_tcc("/store/1-stage1/tinycc/bin/tcc");
	// recompile everything else with the final tcc (could be an overkill)
	compile_libtcc1("/store/1-stage1/tinycc/bin/tcc");
	compile_protomusl("/store/1-stage1/tinycc/bin/tcc");
	test_example_intermediate("/store/1-stage1/tinycc/bin/tcc");

	compile_standalone_busybox_applets("/store/1-stage1/tinycc/bin/tcc");

	verify_tcc_stability();
	tweak_output_in_store();
	wrap_tcc_tools();
	test_example_final("/store/1-stage1/tinycc/wrappers/cc");
	//clean_up();

	log("done");

	assert(execve("/recipes/all-past-stage1.sh",
		(char*[]) {"/recipes/all-past-stage1.sh", 0}, NULL));

	log("could not exec into stage 2 (ok when building with make)");
	return 99;
}
