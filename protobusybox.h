#define NUM_APPLETS 1
#define BB_GLOBAL_CONST
#define BB_VER "1.34.1"
#define AUTOCONF_TIMESTAMP
#define _GNU_SOURCE

extern char bb_common_bufsiz1[];
#define setup_common_bufsiz() ((void)0)
enum { COMMON_BUFSIZE = 1024 };

#define CONFIG_BUSYBOX_EXEC_PATH "/proc/self/exe"
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
#define ENABLE_DEBUG 0
#define ENABLE_DESKTOP 0
#define ENABLE_EGREP 0
#define ENABLE_FEATURE_ALLOW_EXEC 0
#define ENABLE_FEATURE_AWK_LIBM 0
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
#define ENABLE_FEATURE_TR_CLASSES 0
#define ENABLE_FEATURE_TR_EQUIV 0
#define ENABLE_FEATURE_USE_SENDFILE 0
#define ENABLE_FEATURE_VERBOSE 0
#define ENABLE_FGREP 0
#define ENABLE_FTPD 0
#define ENABLE_HUSH_TEST 0
#define ENABLE_KILLALL 0
#define ENABLE_LOCALE_SUPPORT 1
#define ENABLE_LONG_OPTS 1
#define ENABLE_PGREP 0
#define ENABLE_PIDOF 0
#define ENABLE_PKILL 0
#define ENABLE_SELINUX 0
#define ENABLE_SESTATUS 0
#define ENABLE_TEST1 0
#define ENABLE_TEST2 0
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
#define IF_CHGRP(...)
#define IF_CHMOD(...)
#define IF_CHOWN(...)
#define IF_CHROOT(...)
#define IF_CHVT(...)
#define IF_CKSUM(...)
#define IF_CLEAR(...)
#define IF_CPIO(...)
#define IF_DEALLOCVT(...)
#define IF_DESKTOP(...)
#define IF_DPKG(...)
#define IF_DPKG_DEB(...)
#define IF_DUMPKMAP(...)
#define IF_ECHO(...) __VA_ARGS__
#define IF_EXTRA_COMPAT(...)
#define IF_FEATURE_AWK_GNU_EXTENSIONS(...)
#define IF_FEATURE_CATN(...)
#define IF_FEATURE_CATV(...)
#define IF_FEATURE_CP_REFLINK(...)
#define IF_FEATURE_GREP_CONTEXT(...)
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
#define IF_RPM2CPIO(...)
#define IF_SELINUX(...)
#define IF_SETCONSOLE(...)
#define IF_SETFONT(...)
#define IF_SETKEYCODES(...)
#define IF_SETLOGCONS(...)
#define IF_SHELL_ASH(...) __VA_ARGS__
#define IF_SHELL_HUSH(...)
#define IF_SHOWKEY(...)
#define IF_TAR(...)
#define IF_UNCOMPRESS(...)
#define IF_UNLZMA(...)
#define IF_UNLZOP(...)
#define IF_UNXZ(...)
#define IF_UNZIP(...)
#define IF_XZ(...)
#define IF_XZCAT(...)
#define IF_ZCAT(...)
