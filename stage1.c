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

void log_(int fd, const char* msg) {
	assert(write_(fd, msg) == strlen(msg));
}

void log(int fd, const char* msg) {
	log_(fd, msg);
	log_(fd, "\n");
}


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
	return (*a == *b) ? 0 : ((*a < *b) ? -1 : 1);
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
		const char* __args[] = { at, ## args, NULL }; \
		const char* const* p; \
		for (p = __args; *p; p++) \
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
			log(STDERR, "child has been killed");
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
		log_(STDOUT, "run() running: "); \
		for(__i = 0; __args[__i]; __i++) { \
			log_(STDOUT, __args[__i]); \
			log_(STDOUT, " "); \
		} \
		log_(STDOUT, "\n"); \
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
	do { \
		const char* __args[] = { NULL, ## args, NULL }; \
		_aa_extend_from_arr(aa_ptr, __args + 1); \
	} while (0)
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
				log(STDOUT, buf);
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

#define TCC_ARGS "-g"
#define TCC_ARGS_NOSTD TCC_ARGS, "-nostdlib", "-nostdinc"


void sanity_test() {
	struct args_accumulator aa1, aa2;

	log(STDOUT, "Sanity-testing run()...");
	log(STDOUT, "* testing run() -> retcode 0...");
	run0("/seed/1/bin/tcc", "--help");
	log(STDOUT, "* testing run() -> retcode 1...");
	run(1, "/seed/1/bin/tcc", "-ar", "--help");
	log(STDOUT, "run() seems to work OK");

	log(STDOUT, "Sanity-testing args accumulator...");
	log(STDOUT, "* testing aa_append, aa_extend, aa_sort and aa_run0...");
	aa_init(&aa1);
	aa_init(&aa2);
	aa_append(&aa1, "/seed/1/bin/tcc");
	aa_append(&aa2, "-ar");
	aa_extend(&aa2, "help-must-precede-ar", "--help");
	aa_sort(&aa2);
	aa_extend_from(&aa1, &aa2);
	assert(!strcmp(((char**) &aa1)[0], "/seed/1/bin/tcc"));
	assert(!strcmp(((char**) &aa1)[1], "--help"));
	assert(!strcmp(((char**) &aa1)[2], "-ar"));
	assert(!strcmp(((char**) &aa1)[3], "help-must-precede-ar"));
	assert(NULL == ((char**) &aa1)[4]);
	aa_run0(&aa1);

	log(STDOUT, "* testing aa_multi and aa_run for 1...");
	aa_init(&aa1, "/seed/1/bin/tcc", "-ar", "--help");
	assert(aa_run(&aa1) == 1);
}


// Interesting parts: libtcc1 /////////////////////////////////////////////////


void compile_libtcc1_1st_time_nostd(const char* cc) {
	log(STDOUT, "Compiling our first libtcc1.a...");
	mkdirs_at("/stage/1", "tmp/tinycc/libtcc1", "lib/tinycc");
	const char* CFLAGS_NOSTD[] = { TCC_ARGS_NOSTD, "-DTCC_MUSL", NULL };
	const char* SOURCES_NOSTD[] = {
		"libtcc1.c", "alloca.S",
		"dsohandle.c", "stdatomic.c", "va_list.c",
	0};
	mass_compile(cc, CFLAGS_NOSTD, "/seed/1/src/tinycc/lib", SOURCES_NOSTD,
			"/stage/1/tmp/tinycc/libtcc1",
			"/stage/1/lib/tinycc/libtcc1.a");
}  // see also compile_libtcc1 far below


// Interesting parts: protomusl ////////////////////////////////////////////////

#define PROTOMUSL_EXTRA_CFLAGS \
		"-std=c99", \
		"-D_XOPEN_SOURCE=700"
#define PROTOMUSL_INTERNAL_INCLUDES \
		"-I/seed/1/src/protomusl/src/include", \
		"-I/seed/1/src/protomusl/arch/x86_64", \
		"-I/seed/1/src/protomusl/stage0-generated/sed1", \
		"-I/seed/1/src/protomusl/stage0-generated/sed2", \
		"-I/seed/1/src/protomusl/arch/generic", \
		"-I/seed/1/src/protomusl/src/internal", \
		"-I/seed/1/src/protomusl/include"
#define PROTOMUSL_NOSTD_LDFLAGS_PRE \
		"-static", \
		"/stage/1/lib/protomusl/crt1.o", \
		"/stage/1/lib/protomusl/crti.o"
#define PROTOMUSL_NOSTD_LDFLAGS_POST \
		"/stage/1/lib/protomusl/libc.a", \
		"/stage/1/lib/protomusl/crtn.o"
#define PROTOMUSL_INCLUDES \
		"-I/seed/1/src/protomusl/include", \
		"-I/seed/1/src/protomusl/arch/x86_64", \
		"-I/seed/1/src/protomusl/arch/generic", \
		"-I/seed/1/src/protomusl/stage0-generated/sed1", \
		"-I/seed/1/src/protomusl/stage0-generated/sed2"

void compile_protomusl(const char* cc) {
	struct args_accumulator aa;
	aa_init(&aa);

	log(STDOUT, "Compiling part of musl (protomusl)...");
	mkdir("/stage/1/lib/protomusl", 0777);
	const char* CFLAGS[] = {
		TCC_ARGS_NOSTD,
		PROTOMUSL_EXTRA_CFLAGS,
		PROTOMUSL_INTERNAL_INCLUDES,
	0};
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/conf");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/ctype");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/dirent");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/env");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/errno");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/exit");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/fcntl");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/fenv");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/internal");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/ldso");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/legacy");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/linux");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/locale");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/malloc");
	aa_extend_from_dir(&aa, 2, "/seed/1/src/protomusl/src/malloc/mallocng");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/math");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/misc");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/mman");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/multibyte");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/network");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/passwd");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/prng");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/process");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/regex");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/select");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/setjmp");
	aa_extend_from_dir(&aa, 2, "/seed/1/src/protomusl/src/setjmp/x86_64");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/signal");
	aa_extend_from_dir(&aa, 2, "/seed/1/src/protomusl/src/signal/x86_64");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/stat");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/stdio");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/stdlib");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/string");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/temp");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/termios");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/thread");
	aa_extend_from_dir(&aa, 2, "/seed/1/src/protomusl/src/thread/x86_64");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/time");
	aa_extend_from_dir(&aa, 1, "/seed/1/src/protomusl/src/unistd");
	mass_compile(cc, CFLAGS, "/seed/1/src/protomusl/src", &aa,
			"/stage/1/tmp/protomusl",
			"/stage/1/lib/protomusl/libc.a");

	log(STDOUT, "Compiling crt bits of protomusl...");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INTERNAL_INCLUDES, "-DCRT",
		"-c", "/seed/1/src/protomusl/crt/crt1.c",
		"-o", "/stage/1/lib/protomusl/crt1.o");
	run0(cc, TCC_ARGS_NOSTD, "-DCRT",
		"-c", "/seed/1/src/protomusl/crt/x86_64/crti.s",
		"-o", "/stage/1/lib/protomusl/crti.o");
	run0(cc, TCC_ARGS_NOSTD, "-DCRT",
		"-c", "/seed/1/src/protomusl/crt/x86_64/crtn.s",
		"-o", "/stage/1/lib/protomusl/crtn.o");
}


void test_example_1st_time_nostd(const char* cc) {
	log(STDOUT, "Linking an example (1st time)...");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"/seed/1/src/hello.c",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/stage/1/lib/tinycc/libtcc1.a",
		"-o", "/stage/1/tmp/protomusl-hello");

	log(STDOUT, "Executing an example...");
	run(42, "/stage/1/tmp/protomusl-hello");
}


// Interesting parts: recompiling tcc //////////////////////////////////////////

void compile_libtcc1(const char* cc) {
	log(STDOUT, "Recompiling libtcc1.a...");
	const char* CFLAGS[] = { TCC_ARGS, "-DTCC_MUSL", PROTOMUSL_INCLUDES, 0};
	const char* SOURCES[] = {
		"libtcc1.c", "alloca.S",
		"dsohandle.c", "stdatomic.c", "va_list.c",
		// now we can compile more
		"tcov.c", "bcheck.c", "alloca-bt.S",
	0};
	mass_compile(cc, CFLAGS, "/seed/1/src/tinycc/lib", SOURCES,
			"/stage/1/tmp/tinycc/libtcc1",
			"/stage/1/lib/tinycc/libtcc1.a");
}

#define TCC_CFLAGS \
		"-I/seed/1/src/tinycc", \
		"-I/seed/1/src/tinycc/include", \
		"-I/stage/1/tmp/tinycc/gen", \
		"-DTCC_VERSION=\"mob-git1645616\"", \
		"-DTCC_GITHASH=\"mob:164516\"", \
		"-DTCC_TARGET_X86_64", \
		"-DTCC_MUSL", \
		"-DONE_SOURCE=0", \
		"-DCONFIG_TCCDIR=\"/stage/1/lib/tinycc\"", \
		"-DCONFIG_TCC_SYSINCLUDEPATHS=\"/stage/1/include/protomusl\"", \
		"-DCONFIG_TCC_LIBPATHS=\"/stage/1/lib/protomusl\"", \
		"-DCONFIG_TCC_CRTPREFIX=\"/stage/1/lib/protomusl\"", \
		"-DCONFIG_TCC_ELFINTERP=\"/sorry/not/yet\"", \
		"-DCONFIG_TCC_PREDEFS=1"

void compile_tcc_1st_time_nostd(const char* cc) {
	log(STDOUT, "Compiling tcc's conftest...");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"-DC2STR", "/seed/1/src/tinycc/conftest.c",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/stage/1/lib/tinycc/libtcc1.a",
		"-o", "/stage/1/tmp/tinycc/tcc-conftest"
		);
	log(STDOUT, "Generating tccdefs_.h with conftest...");
	mkdir("/stage/1/tmp/tinycc/gen/", 0777);
	run0("/stage/1/tmp/tinycc/tcc-conftest",
		"/seed/1/src/tinycc/include/tccdefs.h",
		"/stage/1/tmp/tinycc/gen/tccdefs_.h");

	log(STDOUT, "Compiling libtcc...");
	const char* CFLAGS[] = {
		TCC_ARGS_NOSTD,
		PROTOMUSL_INCLUDES,
		TCC_CFLAGS,
	0};
	const char* SOURCES[] = {
		"libtcc.c", "tccpp.c", "tccgen.c", "tccelf.c", "tccasm.c",
		"tccrun.c", "x86_64-gen.c", "x86_64-link.c", "i386-asm.c",
	0};
	mass_compile(cc, CFLAGS, "/seed/1/src/tinycc", SOURCES,
		"/stage/1/tmp/tinycc/libtcc",
		"/stage/1/lib/tinycc/libtcc.a");
	run0(cc, TCC_ARGS_NOSTD, PROTOMUSL_INCLUDES, TCC_CFLAGS,
		PROTOMUSL_NOSTD_LDFLAGS_PRE,
		"/seed/1/src/tinycc/tcc.c",
		"/stage/1/lib/tinycc/libtcc.a",
		PROTOMUSL_NOSTD_LDFLAGS_POST,
		"/stage/1/lib/tinycc/libtcc1.a",
		"-o", "/stage/1/bin/tcc"
		);
	run0("/stage/1/bin/tcc", "-print-search-dirs");
}


void compile_tcc(const char* cc) {
	log(STDOUT, "Recompiling libtcc...");
	const char* CFLAGS[] = {
		TCC_ARGS,
		PROTOMUSL_INCLUDES,
		TCC_CFLAGS,
	0};
	const char* SOURCES[] = {
		"libtcc.c", "tccpp.c", "tccgen.c", "tccelf.c", "tccasm.c",
		"tccrun.c", "x86_64-gen.c", "x86_64-link.c", "i386-asm.c",
	0};
	mass_compile(cc, CFLAGS, "/seed/1/src/tinycc", SOURCES,
		"/stage/1/tmp/tinycc/libtcc", "/stage/1/lib/tinycc/libtcc.a");
	run0(cc, TCC_ARGS, PROTOMUSL_INCLUDES, TCC_CFLAGS, "-static",
		"/seed/1/src/tinycc/tcc.c", "/stage/1/lib/tinycc/libtcc.a",
		"-o", "/stage/1/bin/tcc");
}

void test_example_intermediate(const char* cc) {
	log(STDOUT, "Linking an example (our tcc, includes not installed)...");
	run0(cc, TCC_ARGS, PROTOMUSL_INCLUDES, "-static",
		"/seed/1/src/hello.c", "-o", "/stage/1/tmp/protomusl-hello");

	log(STDOUT, "Executing an example...");
	run(42, "/stage/1/tmp/protomusl-hello");
}

void test_example_final(const char* cc) {
	log(STDOUT, "Linking an example (final tcc, includes installed)...");
	run0(cc, TCC_ARGS, "-static",
		"/seed/1/src/hello.c", "-o", "/stage/1/tmp/protomusl-hello");

	log(STDOUT, "Executing an example...");
	run(42, "/stage/1/tmp/protomusl-hello");
}


// Interesting parts: hacky standalone busybox applets /////////////////////////

void compile_standalone_busybox_applets(const char* cc) {
	log(STDOUT, "Compiling protolibbb...");
	const char* CFLAGS[] = {
		TCC_ARGS, PROTOMUSL_INCLUDES,
		"-I/seed/1/src/protobusybox/include/",
		"-I/seed/1/src/protobusybox/libbb/",
		"-I/seed/1/src/",
		"-include", "protobusybox.h",
	0};
	const char* SOURCES[] = {
		"ask_confirmation.c",
		"auto_string.c",
		"bb_cat.c",
		"bb_getgroups.c",
		"bb_strtonum.c",
		"compare_string_array.c",
		"concat_path_file.c",
		"concat_subpath_file.c",
		"copy_file.c",
		"copyfd.c",
		"default_error_retval.c",
		"endofname.c",
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
		"printable_string.c",
		"process_escape_sequence.c",
		"ptr_to_globals.c",
		"read.c",
		"read_printf.c",
		"recursive_action.c",
		"remove_file.c",
		"safe_poll.c",
		"safe_strncpy.c",
		"safe_write.c",
		"signals.c",
		"skip_whitespace.c",
		"sysconf.c",
		"time.c",
		"u_signal_names.c",
		"verror_msg.c",
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
	0};
	mass_compile(cc, CFLAGS,
			"/seed/1/src/protobusybox/libbb", SOURCES,
			"/stage/1/tmp/protobusybox/libbb",
			"/stage/1/tmp/protobusybox/libbb.a");


	log(STDOUT, "Compiling standalone protobusybox applets...");
	#define compile_applet(applet_name, files...) \
			run0(cc, TCC_ARGS, PROTOMUSL_INCLUDES, \
					"-static", \
					"-I/seed/1/src/protobusybox/include", \
					"-I/seed/1/src/", \
					"-include", "protobusybox.h", \
					"-DAPPLET_MAIN=" applet_name "_main", \
					"/seed/1/src/protobusybox.c", \
					## files, \
					"/stage/1/tmp/protobusybox/libbb.a", \
					"-o", "/stage/1/bin/" applet_name);
compile_applet("uname", "/seed/1/src/protobusybox/coreutils/uname.c");
run0("/stage/1/bin/uname");

	compile_applet("echo", "/seed/1/src/protobusybox/coreutils/echo.c")
	run0("/stage/1/bin/echo", "Hello from protobusybox!");

	#define BB_SRC "/seed/1/src/protobusybox"
	compile_applet("ash",
			BB_SRC "/shell/shell_common.c",
			BB_SRC "/shell/ash_ptr_hack.c",
			BB_SRC "/shell/math.c",
			BB_SRC "/coreutils/printf.c",
			BB_SRC "/coreutils/test_ptr_hack.c",
			BB_SRC "/coreutils/test.c",
			BB_SRC "/shell/ash.c")
	run(42, "/stage/1/bin/ash", "-c",
			"printf 'Hello from ash!\n'; exit 42");

	compile_applet("cat", BB_SRC "/coreutils/cat.c")
	compile_applet("chmod", BB_SRC "/coreutils/chmod.c")
	compile_applet("cp",
			BB_SRC "/coreutils/libcoreutils/cp_mv_stat.c",
			BB_SRC "/coreutils/cp.c");
	compile_applet("cut", BB_SRC "/coreutils/cut.c");
	compile_applet("expr", BB_SRC "/coreutils/expr.c");
	compile_applet("head", BB_SRC "/coreutils/head.c");
	compile_applet("ln", BB_SRC "/coreutils/ln.c");
	compile_applet("ls", BB_SRC "/coreutils/ls.c");
	compile_applet("mkdir", BB_SRC "/coreutils/mkdir.c");
	compile_applet("mv",
			BB_SRC "/coreutils/libcoreutils/cp_mv_stat.c",
			BB_SRC "/coreutils/mv.c");
	compile_applet("rm", BB_SRC "/coreutils/rm.c");
	compile_applet("rmdir", BB_SRC "/coreutils/rmdir.c");
	compile_applet("sleep", BB_SRC "/coreutils/sleep.c");
	compile_applet("sort", BB_SRC "/coreutils/sort.c");
	compile_applet("tr", BB_SRC "/coreutils/tr.c");
	compile_applet("uname", BB_SRC "/coreutils/uname.c");
	compile_applet("uniq", BB_SRC "/coreutils/uniq.c");

	compile_applet("ar",
			BB_SRC "/archival/libarchive/data_extract_all.c",
			BB_SRC "/archival/libarchive/data_extract_to_stdout.c",
			BB_SRC "/archival/libarchive/data_skip.c",
			BB_SRC "/archival/libarchive/filter_accept_all.c",
			BB_SRC "/archival/libarchive/filter_accept_list.c",
			BB_SRC "/archival/libarchive/find_list_entry.c",
			BB_SRC "/archival/libarchive/get_header_ar.c",
			BB_SRC "/archival/libarchive/header_list.c",
			BB_SRC "/archival/libarchive/header_skip.c",
			BB_SRC "/archival/libarchive/init_handle.c",
			BB_SRC "/archival/libarchive/seek_by_jump.c",
			BB_SRC "/archival/libarchive/seek_by_read.c",
			BB_SRC "/archival/libarchive/unpack_ar_archive.c",
			BB_SRC "/archival/libarchive/unsafe_symlink_target.c",
			BB_SRC "/archival/ar.c");

	compile_applet("awk", BB_SRC "/editors/awk.c");
	compile_applet("diff", BB_SRC "/editors/diff.c");
	compile_applet("sed", BB_SRC "/editors/sed.c");

	compile_applet("grep", BB_SRC "/findutils/grep.c");
}


// Little things we'll do now when we have a shell /////////////////////////////

void verify_tcc_stability(void) {
	run0("/stage/1/bin/cp", "/stage/1/bin/tcc", "/stage/1/tmp/tcc-bak");
	compile_tcc("/stage/1/bin/tcc");
	run0("/stage/1/bin/diff", "/stage/1/bin/tcc", "/stage/1/tmp/tcc-bak");
}

void compose_stage2(void) {
	run0("/stage/1/bin/mkdir", "-p", "/seed/1/include/protomusl");
	run0("/stage/1/bin/ash", "-uexvc", "
		/stage/1/bin/rm -rf /stage/1/include
		/stage/1/bin/mkdir -p /stage/1/include/protomusl
		/stage/1/bin/cp -r \
			/seed/1/src/protomusl/stage0-generated/sed1/bits \
			/seed/1/src/protomusl/stage0-generated/sed2/bits \
			/seed/1/src/protomusl/arch/generic/* \
			/seed/1/src/protomusl/arch/x86_64/* \
			/seed/1/src/protomusl/include/* \
			/stage/1/include/protomusl/
	");
}

// The main plot ///////////////////////////////////////////////////////////////

int _start() {
	struct args_accumulator aa_cmd;
	struct args_accumulator aa_link_objs;

	log(STDOUT, "Hello from stage1!");

	log(STDOUT, "Creating directories...");
	mkdirs_at("/stage/1", "bin", "lib", "include", "tmp");
	sanity_test();

	// starting with the seeded TCC
	compile_libtcc1_1st_time_nostd("/seed/1/bin/tcc");
	compile_protomusl("/seed/1/bin/tcc");
	test_example_1st_time_nostd("/seed/1/bin/tcc");

	// build the first TCC that comes from our sources
	compile_tcc_1st_time_nostd("/seed/1/bin/tcc");
	test_example_intermediate("/stage/1/bin/tcc");
	// rebuild everything with it
	compile_libtcc1("/stage/1/bin/tcc");
	compile_protomusl("/stage/1/bin/tcc");
	test_example_intermediate("/stage/1/bin/tcc");

	// this is the final tcc we'll build, should not be worth repeating
	compile_tcc("/stage/1/bin/tcc");
	// recompile everything else with the final tcc (could be an overkill)
	compile_libtcc1("/stage/1/bin/tcc");
	compile_protomusl("/stage/1/bin/tcc");
	test_example_intermediate("/stage/1/bin/tcc");

	compile_standalone_busybox_applets("/stage/1/bin/tcc");

	verify_tcc_stability();
	compose_stage2();
	test_example_final("/stage/1/bin/tcc");
	run0("/stage/1/bin/rm", "-r", "/stage/1/tmp");

	log(STDOUT, "--- stage 1 cutoff point ---");

	char* STAGE2_ARGS[] = {"/seed/2/src/stage2.sh", NULL};
	assert(execve("/seed/2/src/stage2.sh", STAGE2_ARGS, NULL));

	return 99;  // should be unreacheable
}
