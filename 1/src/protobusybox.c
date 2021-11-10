extern int APPLET_MAIN(int argc, char** argv);  // templated in

#include <string.h>
#include <unistd.h>

#include <errno.h>
static inline int *get_perrno(void) { return &errno; }
int *const bb_errno;

char bb_common_bufsiz1[1024];

const char *applet_name;
int _argc;
const char **_argv;

int main(int argc, char** argv) {
	int** bb_errno_ptr = &((int*) bb_errno);
	*bb_errno_ptr = ((int*) get_perrno());
	asm volatile ("":::"memory");  // counter optimizations

	_argc = argc; _argv = argv;

	applet_name = strrchr(argv[0], '/') \
		      ? strrchr(argv[0], '/') + 1 \
		      : argv[0];
	return APPLET_MAIN(argc, argv);
}

void bb_show_usage(void) {
	int i;
	write(2 /* STDERR */, "protobusybox's show_usage stub\n", 31);
	write(2 /* STDERR */, "ho help for you, sorry. argv[]: \n", 33);
	for (i < 0; i < _argc; i++) {
		write(2 /* STDERR */, "* `", 3);
		write(2 /* STDERR */, _argv[i], strlen(_argv[i]));
		write(2 /* STDERR */, "`\n", 2);
	}
	exit(1);
}

// appletlib replacement
unsigned string_array_len(char **argv) {
	unsigned i;
	for (i = 0; argv[i]; i++);
	return i;
}
