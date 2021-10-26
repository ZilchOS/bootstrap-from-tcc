#include <errno.h>
static inline int *get_perrno(void) { return &errno; }
int *const bb_errno;

#define CONFIG_FEATURE_EDITING_MAX_LEN 1024
#define CONFIG_FEATURE_COPYBUF_KB 16
#define ENABLE_ASH_ALIAS 0
#define ENABLE_ASH_BASH_COMPAT 0
#define ENABLE_ASH_CMDCMD 0
#define ENABLE_ASH_ECHO 0
#define ENABLE_ASH_GETOPTS 0
#define ENABLE_ASH_JOB_CONTROL 0
#define ENABLE_ASH_MAIL 0
#define ENABLE_ASH_PRINTF 1
#define ENABLE_ASH_TEST 1
#define ENABLE_TEST1 0
#define ENABLE_TEST2 0
#define ENABLE_HUSH_TEST 0
#define ENABLE_DEBUG 0
#define ENABLE_FEATURE_CLEAN_UP 0
#define ENABLE_FEATURE_CP_REFLINK 0
#define ENABLE_FEATURE_CROND_D 0
#define ENABLE_FEATURE_EDITING 0
#define ENABLE_FEATURE_HUMAN_READABLE 0
#define ENABLE_FEATURE_LS_COLOR 0
#define ENABLE_FEATURE_LS_FILETYPES 0
#define ENABLE_FEATURE_LS_FOLLOWLINKS 0
#define ENABLE_FEATURE_LS_RECURSIVE 0
#define ENABLE_FEATURE_LS_SORTFILES 0
#define ENABLE_FEATURE_LS_TIMESTAMPS 0
#define ENABLE_FEATURE_LS_WIDTH 0
#define ENABLE_FEATURE_NON_POSIX_CP 0
#define ENABLE_FEATURE_PRESERVE_HARDLINKS 0
#define ENABLE_FEATURE_PS_ADDITIONAL_COLUMNS 0
#define ENABLE_FEATURE_SHOW_THREADS 0
#define ENABLE_FEATURE_SH_MATH 1
#define ENABLE_FEATURE_SH_READ_FRAC 0
#define ENABLE_FEATURE_SYSLOG 0
#define ENABLE_FEATURE_TOPMEM 1
#define ENABLE_FEATURE_TOP_SMP_PROCESS 0
#define ENABLE_FEATURE_USE_SENDFILE 0
#define ENABLE_FEATURE_VERBOSE 0
#define ENABLE_FTPD 0
#define ENABLE_KILLALL 0
#define ENABLE_LONG_OPTS 1
#define ENABLE_PGREP 0
#define ENABLE_PIDOF 0
#define ENABLE_PKILL 0
#define ENABLE_SELINUX 0
#define ENABLE_SESTATUS 0
#define IF_AR(...)
#define IF_ASH_ALIAS(...)
#define IF_ASH_BASH_COMPAT(...)
#define IF_ASH_EXPAND_PRMT(...)
#define IF_ASH_HELP(...)
#define IF_ASH_OPTIMIZE_FOR_SIZE(...)
#define IF_BASENAME(...)
#define IF_BUNZIP2(...)
#define IF_BZCAT(...)
#define IF_BZIP2(...)
#define IF_CAT(...)
#define IF_CHOWN(...)
#define IF_CHMOD(...)
#define IF_CHGRP(...)
#define IF_CKSUM(...)
#define IF_CHROOT(...)
#define IF_CHVT(...)
#define IF_CLEAR(...)
#define IF_CPIO(...)
#define IF_DEALLOCVT(...)
#define IF_DESKTOP(...)
#define IF_DPKG(...)
#define IF_DPKG_DEB(...)
#define IF_DUMPKMAP(...)
#define IF_ECHO(...) __VA_ARGS__
#define IF_FEATURE_CATN(...)
#define IF_FEATURE_CATV(...)
#define IF_FEATURE_CP_REFLINK(...)
#define IF_FEATURE_HUMAN_READABLE(...)
#define IF_FEATURE_LS_COLOR(...)
#define IF_FEATURE_LS_FILETYPES(...)
#define IF_FEATURE_LS_FOLLOWLINKS(...)
#define IF_FEATURE_LS_RECURSIVE(...)
#define IF_FEATURE_LS_SORTFILES(...)
#define IF_FEATURE_LS_TIMESTAMPS(...)
#define IF_FEATURE_LS_WIDTH(...)
#define IF_FEATURE_SHOW_THREADS(...)
#define IF_FEATURE_SH_MATH(...) __VA_ARGS__
#define IF_FEATURE_TIMEZONE(...)
#define IF_FEATURE_VERBOSE(...)
#define IF_FGCONSOLE(...)
#define IF_GUNZIP(...)
#define IF_GZIP(...)
#define IF_KBD_MODE(...)
#define IF_LOADFONT(...)
#define IF_LOADKMAP(...)
#define IF_LS(...) __VA_ARGS__
#define IF_LZCAT(...)
#define IF_LZMA(...)
#define IF_LZOP(...)
#define IF_LZOPCAT(...)
#define IF_NOT_DESKTOP(...) __VA_ARGS__
#define IF_OPENVT(...)
#define IF_PRINTF(...) __VA_ARGS__
#define IF_RESET(...)
#define IF_RESIZE(...)
#define IF_RPM(...)
#define IF_SETCONSOLE(...)
#define IF_SETFONT(...)
#define IF_SETKEYCODES(...)
#define IF_SETLOGCONS(...)
#define IF_SHOWKEY(...)
#define IF_RPM2CPIO(...)
#define IF_SELINUX(...)
#define IF_SHELL_ASH(...) __VA_ARGS__
#define IF_SHELL_HUSH(...)
#define IF_TAR(...)
#define IF_UNCOMPRESS(...)
#define IF_UNLZMA(...)
#define IF_UNLZOP(...)
#define IF_UNXZ(...)
#define IF_UNZIP(...)
#define IF_XZ(...)
#define IF_XZCAT(...)
#define IF_ZCAT(...)

#define BB_GLOBAL_CONST

#define BB_VER "1.34.1"
#define AUTOCONF_TIMESTAMP
#define CONFIG_BUSYBOX_EXEC_PATH "/proc/self/exe"

#define _GNU_SOURCE
#define FAST_FUNC
#include <stdio.h>
#include <string.h>
#include "libbb/ask_confirmation.c"
#include "libbb/auto_string.c"
#include "libbb/bb_cat.c"
#include "libbb/bb_getgroups.c"
#include "libbb/bb_strtonum.c"
//#include "libbb/bbunit.c"
//#include "libbb/capability.c"
//#include "libbb/change_identity.c"
//#include "libbb/chomp.c"
//#include "libbb/common_bufsiz.c"
#include "libbb/compare_string_array.c"
#include "libbb/concat_path_file.c"
#include "libbb/concat_subpath_file.c"
//#include "libbb/const_hack.c"
#include "libbb/copyfd.c"
#include "libbb/copy_file.c"
//#include "libbb/correct_password.c"
//#include "libbb/crc32.c"
#include "libbb/default_error_retval.c"
//#include "libbb/device_open.c"
//#include "libbb/die_if_bad_username.c"
//#include "libbb/dump.c"
//#include "libbb/duration.c"
#include "libbb/endofname.c"
//#include "libbb/executable.c"
#include "libbb/fclose_nonstdin.c"
#include "libbb/fflush_stdout_and_exit.c"
//#include "libbb/fgets_str.c"
//#include "libbb/find_mount_point.c"
//#include "libbb/find_pid_by_name.c"
//#include "libbb/find_root_device.c"
#include "libbb/full_write.c"
//#include "libbb/get_console.c"
//#include "libbb/get_cpu_count.c"
#include "libbb/get_last_path_component.c"
#include "libbb/get_line_from_file.c"
#include "libbb/getopt32.c"
//#include "libbb/getopt_allopts.c"
//#include "libbb/getpty.c"
//#include "libbb/get_shell_name.c"
//#include "libbb/get_volsize.c"
//#include "libbb/hash_md5prime.c"
//#include "libbb/hash_md5_sha.c"
//#include "libbb/herror_msg.c"
//#include "libbb/human_readable.c"
//#include "libbb/inet_cksum.c"
//#include "libbb/inet_common.c"
//#include "libbb/in_ether.c"
#include "libbb/inode_hash.c"
#include "libbb/isdirectory.c"
//#include "libbb/isqrt.c"
//#include "libbb/iterate_on_dir.c"
//#include "libbb/kernel_version.c"
#include "libbb/last_char_is.c"
//#include "libbb/lineedit.c"
//#include "libbb/lineedit_ptr_hack.c"
#include "libbb/llist.c"
//#include "libbb/logenv.c"
//#include "libbb/login.c"
//#include "libbb/loop.c"
//#include "libbb/makedev.c"
#include "libbb/make_directory.c"
//#include "libbb/match_fstype.c"
#include "libbb/messages.c"
//#include "libbb/missing_syscalls.c"
#include "libbb/mode_string.c"
//#include "libbb/mtab.c"
//#include "libbb/nuke_str.c"
//#include "libbb/obscure.c"
//#include "libbb/parse_config.c"
#include "libbb/parse_mode.c"
//#include "libbb/percent_decode.c"
#include "libbb/perror_msg.c"
//#include "libbb/perror_nomsg_and_die.c"
//#include "libbb/perror_nomsg.c"
//#include "libbb/pidfile.c"
//#include "libbb/platform.c"
//#include "libbb/printable.c"
#include "libbb/printable_string.c"
//#include "libbb/print_flags.c"
//#include "libbb/print_numbered_lines.c"
#include "libbb/process_escape_sequence.c"
//#include "libbb/procps.c"
//#include "libbb/progress.c"
//#include "libbb/ptr_to_globals.c"
//#include "libbb/pw_encrypt.c"
//#include "libbb/pw_encrypt_des.c"
//#include "libbb/pw_encrypt_md5.c"
//#include "libbb/pw_encrypt_sha.c"
#include "libbb/read.c"
//#include "libbb/read_key.c"
#include "libbb/read_printf.c"
#include "libbb/recursive_action.c"
#include "libbb/remove_file.c"
//#include "libbb/replace.c"
//#include "libbb/rtc.c"
//#include "libbb/run_shell.c"
//#include "libbb/safe_gethostname.c"
#include "libbb/safe_poll.c"
#include "libbb/safe_strncpy.c"
#include "libbb/safe_write.c"
//#include "libbb/securetty.c"
//#include "libbb/selinux_common.c"
//#include "libbb/setup_environment.c"
#include "libbb/signals.c"
//#include "libbb/simplify_path.c"
//#include "libbb/single_argv.c"
#include "libbb/skip_whitespace.c"
//#include "libbb/speed_table.c"
//#include "libbb/strrstr.c"
//#include "libbb/str_tolower.c"
#include "libbb/sysconf.c"
#include "libbb/time.c"
//#include "libbb/trim.c"
//#include "libbb/ubi.c"
//#include "libbb/udp_io.c"
//#include "libbb/unicode.c"
//#include "libbb/update_passwd.c"
#include "libbb/u_signal_names.c"
//#include "libbb/utmp.c"
//#include "libbb/uuencode.c"
#include "libbb/verror_msg.c"
//#include "libbb/vfork_daemon_rexec.c"
//#include "libbb/warn_ignoring_args.c"
#include "libbb/wfopen.c"
#include "libbb/wfopen_input.c"
//#include "libbb/write.c"
#include "libbb/xatonum.c"
//#include "libbb/xatonum_template.c"
//#include "libbb/xconnect.c"
#include "libbb/xfunc_die.c"
#include "libbb/xfuncs.c"
#include "libbb/xfuncs_printf.c"
#include "libbb/xgetcwd.c"
//#include "libbb/xgethostbyname.c"
#include "libbb/xreadlink.c"
//#include "libbb/xrealloc_vector.c"
#include "libbb/xregcomp.c"

//#include "platform.h"
//#define ENABLE_FEATURE_INDIVIDUAL 1

#include "include/libbb.h"

// appletlib
unsigned string_array_len(char **argv) {
	unsigned i;
	for (i = 0; argv[i]; i++);
	return i;
}

void bb_show_usage(void) {
	write(2 /* STDERR */, "protobusybox's show_usage stub\n", 31);
}

// common_bufsiz
enum { COMMON_BUFSIZE = 1024 };
char bb_common_bufsiz1[1024];
extern char bb_common_bufsiz1[];
#define setup_common_bufsiz() ((void)0)

#include "shell/shell_common.c"
#include "shell/math.c"
#undef lookupvar
#undef setvar
#include "shell/ash.c"
#include "shell/ash_ptr_hack.c"
#undef eflag
#undef nflag
#undef arg0
#undef BASH_TEST2

#include "coreutils/libcoreutils/cp_mv_stat.c"
#include "coreutils/cat.c"
#include "coreutils/chmod.c"
#undef OPT_VERBOSE
#include "coreutils/cp.c"
#include "coreutils/echo.c"
#define globals expr_globals
#include "coreutils/expr.c"
#undef globals
#include "coreutils/ln.c"
#include "coreutils/ls.c"
#include "coreutils/mkdir.c"
#include "coreutils/mv.c"
#include "coreutils/printf.c"  // only as an ash builtin
#include "coreutils/rm.c"
#include "coreutils/test.c"  // only as an ash builtin
#include "coreutils/test_ptr_hack.c"
#define globals sed_globals
#include "editors/sed.c"

typedef int (*applet_func_t)(int, char**);
struct applet { char* name; applet_func_t func; };
struct applet applets[] = {
	{"ash", ash_main},
	{"cat", cat_main},
	{"chmod", chmod_main},
	{"cp", cp_main},
	{"echo", echo_main},
	{"expr", expr_main},
	{"ln", ln_main},
	{"ls", ls_main},
	{"mkdir", mkdir_main},
	{"mv", mv_main},
	{"rm", rm_main},
	{"sed", sed_main},
	{NULL, NULL},
};

const char *applet_name;
int main(int argc, char** argv) {
	int** bb_errno_ptr = &((int*) bb_errno);
	*bb_errno_ptr = ((int*) get_perrno());
	barrier();

	applet_name = argv[0];
	while (*applet_name)
		applet_name++;
	while (applet_name > argv[0] && *applet_name != '/')
		applet_name--;
	if (*applet_name == '/')
		applet_name ++;

	struct applet* a;
	for (a = applets; *a->name; a++)
		if (!strcmp(applet_name, a->name))
			return a->func(argc, argv);
	return 255;
}
