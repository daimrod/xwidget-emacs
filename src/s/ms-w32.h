/* System description file for Windows NT.
   Copyright (C) 1993, 1994, 1995 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */

/*
 *      Define symbols to identify the version of Unix this is.
 *      Define all the symbols that apply correctly.
 */

/* #define UNIPLUS */
/* #define USG5 */
/* #define USG */
/* #define HPUX */
/* #define UMAX */
/* #define BSD4_1 */
/* #define BSD4_2 */
/* #define BSD4_3 */
/* #define BSD */
/* #define VMS */
#ifndef WINDOWSNT
#define WINDOWSNT
#endif
#ifndef DOS_NT
#define DOS_NT 	/* MSDOS or WINDOWSNT */
#endif

/* If you are compiling with a non-C calling convention but need to
   declare vararg routines differently, put it here */
#define _VARARGS_ __cdecl

/* If you are providing a function to something that will call the
   function back (like a signal handler and signal, or main) its calling
   convention must be whatever standard the libraries expect */
#define _CALLBACK_ __cdecl

/* SYSTEM_TYPE should indicate the kind of system you are using.
 It sets the Lisp variable system-type.  */

#define SYSTEM_TYPE "windows-nt"
#define SYMS_SYSTEM syms_of_ntterm ()

#define NO_MATHERR
#define HAVE_FREXP
#define HAVE_FMOD

/* NOMULTIPLEJOBS should be defined if your system's shell
 does not have "job control" (the ability to stop a program,
 run some other program, then continue the first one).  */

/* #define NOMULTIPLEJOBS */

/* Emacs can read input using SIGIO and buffering characters itself,
   or using CBREAK mode and making C-g cause SIGINT.
   The choice is controlled by the variable interrupt_input.

   Define INTERRUPT_INPUT to make interrupt_input = 1 the default (use SIGIO)

   Emacs uses the presence or absence of the SIGIO macro to indicate
   whether or not signal-driven I/O is possible.  It uses
   INTERRUPT_INPUT to decide whether to use it by default.

   SIGIO can be used only on systems that implement it (4.2 and 4.3).
   CBREAK mode has two disadvantages
     1) At least in 4.2, it is impossible to handle the Meta key properly.
	I hear that in system V this problem does not exist.
     2) Control-G causes output to be discarded.
	I do not know whether this can be fixed in system V.

   Another method of doing input is planned but not implemented.
   It would have Emacs fork off a separate process
   to read the input and send it to the true Emacs process
   through a pipe. */

#define INTERRUPT_INPUT

/* Letter to use in finding device name of first pty,
  if system supports pty's.  'a' means it is /dev/ptya0  */

#define FIRST_PTY_LETTER 'a'

/*
 *      Define HAVE_TERMIOS if the system provides POSIX-style
 *      functions and macros for terminal control.
 *
 *      Define HAVE_TERMIO if the system provides sysV-style ioctls
 *      for terminal control.
 *
 *      Do not define both.  HAVE_TERMIOS is preferred, if it is
 *      supported on your system.
 */

/* #define HAVE_TERMIOS */
/* #define HAVE_TERMIO */

/*
 *      Define HAVE_TIMEVAL if the system supports the BSD style clock values.
 *      Look in <sys/time.h> for a timeval structure.
 */

#define HAVE_TIMEVAL
struct timeval 
  {
    long tv_sec;	/* seconds */
    long tv_usec;	/* microseconds */
  };
struct timezone 
  {
    int	tz_minuteswest;	/* minutes west of Greenwich */
    int	tz_dsttime;	/* type of dst correction */
  };

void gettimeofday (struct timeval *, struct timezone *);


/*
 *      Define HAVE_SELECT if the system supports the `select' system call.
 */

/* #define HAVE_SELECT */

/*
 *      Define HAVE_PTYS if the system supports pty devices.
 */

/* #define HAVE_PTYS */

/*
 *      Define NONSYSTEM_DIR_LIBRARY to make Emacs emulate
 *      The 4.2 opendir, etc., library functions.
 */

/* #define NONSYSTEM_DIR_LIBRARY */

/* Define this symbol if your system has the functions bcopy, etc. */

#define BSTRING
#define bzero(b, l) memset(b, 0, l)
#define bcopy(s, d, l) memcpy(d, s, l)
#define bcmp(a, b, l) memcmp(a, b, l)

/* subprocesses should be defined if you want to
   have code for asynchronous subprocesses
   (as used in M-x compile and M-x shell).
   This is generally OS dependent, and not supported
   under most USG systems. */

#define subprocesses

/* If your system uses COFF (Common Object File Format) then define the
   preprocessor symbol "COFF". */

#define COFF

/* define MAIL_USE_FLOCK if the mailer uses flock
   to interlock access to /usr/spool/mail/$USER.
   The alternative is that a lock file named
   /usr/spool/mail/$USER.lock.  */

/* #define MAIL_USE_FLOCK */

/* Define CLASH_DETECTION if you want lock files to be written
   so that Emacs can tell instantly when you try to modify
   a file that someone else has modified in his Emacs.  */

/* #define CLASH_DETECTION */

/* Define this if your operating system declares signal handlers to
   have a type other than the usual.  `The usual' is `void' for ANSI C
   systems (i.e. when the __STDC__ macro is defined), and `int' for
   pre-ANSI systems.  If you're using GCC on an older system, __STDC__
   will be defined, but the system's include files will still say that
   signal returns int or whatever; in situations like that, define
   this to be what the system's include files want.  */
/* #define SIGTYPE int */

/* If the character used to separate elements of the executable path
   is not ':', #define this to be the appropriate character constant.  */
#define SEPCHAR ';'

/* ============================================================ */

/* Here, add any special hacks needed
   to make Emacs work on this system.  For example,
   you might define certain system call names that don't
   exist on your system, or that do different things on
   your system and must be used only through an encapsulation
   (Which you should place, by convention, in sysdep.c).  */

/* Define this to be the separator between path elements */
#define DIRECTORY_SEP '\\'

/* Define this to be the separator between devices and paths */
#define DEVICE_SEP ':'

/* We'll support either convention on NT.  */
#define IS_DIRECTORY_SEP(_c_) ((_c_) == '/' || (_c_) == '\\')
#define IS_ANY_SEP(_c_) (IS_DIRECTORY_SEP (_c_) || IS_DEVICE_SEP (_c_))

/* The null device on Windows NT. */
#define NULL_DEVICE     "NUL:"
#define EXEC_SUFFIXES   ".exe:.com:.bat:"

#ifndef MAXPATHLEN
#define MAXPATHLEN      _MAX_PATH
#endif

#define LISP_FLOAT_TYPE

#define HAVE_DUP2       	1
#define HAVE_RENAME     	1
#define HAVE_RMDIR      	1
#define HAVE_MKDIR      	1
#define HAVE_GETHOSTNAME	1
#define HAVE_RANDOM		1
#define USE_UTIME		1
#define HAVE_MOUSE		1
#define HAVE_TZNAME		1

#ifdef HAVE_NTGUI
#define HAVE_WINDOW_SYSTEM
#define HAVE_FACES
#endif

#define MODE_LINE_BINARY_TEXT(_b_) (NILP ((_b_)->buffer_file_type) ? "T" : "B")

/* These have to be defined because our compilers treat __STDC__ as being
   defined (most of them anyway). */

#define access  _access
#define chdir   _chdir
#define chmod   _chmod
#define close   _close
#define creat   _creat
#define dup     _dup
#define dup2    _dup2
#define execlp  _execlp
#define execvp  _execvp
#define getpid  _getpid
#define index   strchr
#define isatty  _isatty
#define link    _link
#define lseek   _lseek
#define mkdir   _mkdir
#define mktemp  _mktemp
#define open    _open
#define pipe    _pipe
#define read    _read
#define rmdir   _rmdir
#define sleep   nt_sleep
#define unlink  _unlink
#define umask	_umask
#define utime	_utime
#define write   _write
#define _longjmp        longjmp
#define spawnve win32_spawnve
#define wait    win32_wait
#define signal  win32_signal
#define rindex  strrchr
#define ctime	nt_ctime	/* Place a wrapper around ctime (see nt.c).  */

#ifdef HAVE_NTGUI
#define abort	win32_abort
#endif

/* Defines that we need that aren't in the standard signal.h  */
#define SIGHUP  1               /* Hang up */
#define SIGQUIT 3               /* Quit process */
#define SIGTRAP 5               /* Trace trap */
#define SIGKILL 9               /* Die, die die */
#define SIGPIPE 13              /* Write on pipe with no readers */
#define SIGALRM 14              /* Alarm */
#define SIGCHLD 18              /* Death of child */

/* For integration with MSDOS support.  */
#define getdisk()               (_getdrive () - 1)
#define getdefdir(_drv, _buf)   _getdcwd (_drv, _buf, MAXPATHLEN)

#define EMACS_CONFIGURATION 	get_emacs_configuration ()
#define EMACS_CONFIG_OPTIONS	"NT"	/* Not very meaningful yet.  */

/* Define this so that winsock.h definitions don't get included when windows.h
   is...  I don't know if they do the right thing for emacs.  For this to
   have proper effect, config.h must always be included before windows.h.  */
#define _WINSOCKAPI_    1

/* Defines size_t and alloca ().  */
#include <malloc.h>

/* We have to handle stat specially.  However, #defining stat to
   something else not only redefines uses of the function, but also
   redefines uses of the type struct stat.  What unfortunate parallel
   naming.  */
#include <sys/stat.h>
struct nt_stat 
  {
    struct _stat statbuf;
  };

#ifdef stat
#undef stat
#endif
#define stat nt_stat
#define st_dev statbuf.st_dev
#define st_ino statbuf.st_ino
#define st_mode statbuf.st_mode
#define st_nlink statbuf.st_nlink
#define st_uid statbuf.st_uid
#define st_gid statbuf.st_gid
#define st_rdev statbuf.st_rdev
#define st_size statbuf.st_size
#define st_atime statbuf.st_atime
#define st_mtime statbuf.st_mtime
#define st_ctime statbuf.st_ctime

/* Define for those source files that do not include enough NT 
   system files.  */
#ifndef NULL
#ifdef __cplusplus
#define NULL	0
#else
#define NULL	((void *)0)
#endif
#endif

/* For proper declaration of environ.  */
#include <stdlib.h>

/* Emacs takes care of ensuring that these are defined.  */
#ifdef max
#undef max
#undef min
#endif

/* ============================================================ */
