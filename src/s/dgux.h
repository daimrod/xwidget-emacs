/* Definitions file for GNU Emacs running on Data General's DG/UX
   version 4.32 and above.
   Copyright (C) 1985, 1986, 1991 Free Software Foundation, Inc.

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
the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */


/*
 *	Define symbols to identify the version of Unix this is.
 *	Define all the symbols that apply correctly.
 */

/* #define UNIPLUS */
/* #define USG5 */
/* #define USG */
/* #define HPUX */
/* #define UMAX */
/* #define BSD4_1 */
#define BSD4_2
#define BSD4_3
#define BSD4_4
#define BSD
#define SVR4

/* SYSTEM_TYPE should indicate the kind of system you are using.
 It sets the Lisp variable system-type.  */

#define SYSTEM_TYPE "dgc-unix"

/* NOMULTIPLEJOBS should be defined if your system's shell
 does not have "job control" (the ability to stop a program,
 run some other program, then continue the first one).  */

/* #define NOMULTIPLEJOBS */

/* Emacs can read input using SIGIO and buffering characters itself,
   or using CBREAK mode and making C-g cause SIGINT.
   The choice is controlled by the variable interrupt_input.
   Define INTERRUPT_INPUT to make interrupt_input = 1 the default (use SIGIO)

   SIGIO can be used only on systems that implement it (4.2 and 4.3).
   CBREAK mode has two disadvantages
     1) At least in 4.2, it is impossible to handle the Meta key properly.
        I hear that in system V this problem does not exist.
     2) Control-G causes output to be discarded.
        I do not know whether this can be fixed in system V.

   Another method of doing input is planned but not implemented.
   It would have Emacs fork off a separate process
   to read the input and send it to the true Emacs process
   through a pipe.
*/

#define INTERRUPT_INPUT

/* Letter to use in finding device name of first pty,
  if system supports pty's.  'a' means it is /dev/ptya0  */

#define FIRST_PTY_LETTER 'p'

/*
 *	Define HAVE_TIMEVAL if the system supports the BSD style clock values.
 *	Look in <sys/time.h> for a timeval structure.
 */

#define HAVE_TIMEVAL

/*
 *	Define HAVE_SELECT if the system supports the `select' system call.
 */

#define HAVE_SELECT

/*
 *	Define HAVE_SETSID if the system supports POSIX disassociate
 *      terminal.
 */
#define HAVE_SETSID
/*
 *	Define HAVE_SOCKETS if the system supports sockets.
 */

#define HAVE_SOCKETS

/*
 *	Define HAVE_UNIX_DOMAIN if the system supports Unix
 *      domain sockets.
 */
#define HAVE_UNIX_DOMAIN
/*
 *	Define HAVE_PTYS if the system supports pty devices.
 */

#define HAVE_PTYS

/*
 *	Define NONSYSTEM_DIR_LIBRARY to make Emacs emulate
 *      The 4.2 opendir, etc., library functions.
 */

/* #define NONSYSTEM_DIR_LIBRARY */

/* Define this symbol if your system has the functions bcopy, etc. */

#define BSTRING

/* subprocesses should be defined if you want to
   have code for asynchronous subprocesses
   (as used in M-x compile and M-x shell).
   This is generally OS dependent, and not supported
   under most USG systems. */

#define subprocesses

/* If your system uses COFF (Common Object File Format) then define the
   preprocessor symbol "COFF".

   DGUX can use either COFF or ELF; the default is ELF.
   To compile for COFF (or BCS) use the TARGET_BINARY_INTERFACE
   environment variable.   */

#if defined(_DGUXCOFF_TARGET) || defined(_DGUXBCS_TARGET)
#undef ELF
#ifndef COFF
#define COFF
#endif  /* COFF */
#else   /* defined(_DGUXCOFF_TARGET) || defined(_DGUXBCS_TARGET) */
#undef COFF
#ifndef ELF
#define ELF
#endif  /* ELF */
#endif  /* defined(_DGUXCOFF_TARGET) || defined(_DGUXBCS_TARGET) */

#ifndef COFF /* People will probably find this apparently unreliable
		till the NFS dumping bug is fixed.  */

/* It is possible to undump to ELF with DG/UX 5.4, but for revisions below
   5.4.1 the undump MUST be done on a local file system, or the kernel will
   panic.  ELF executables have the advantage of using shared libraries,
   while COFF executables will still work on 4.2x systems. */

#define UNEXEC unexelf.o

/* This makes sure that all segments in the executable are undumped,
   not just text, data, and bss.  In the case of Mxdb and shared
   libraries, additional information is stored in other sections.
   It does not hurt to have this defined if you don't use Mxdb or
   shared libraries.  In fact, it makes no difference. */

/* Necessary for shared libraries and Mxdb debugging information. */
#define USG_SHARED_LIBRARIES
#endif

/* define MAIL_USE_FLOCK if the mailer uses flock
   to interlock access to /usr/spool/mail/$USER.
   The alternative is that a lock file named
   /usr/spool/mail/$USER.lock.  */

/* #define MAIL_USE_FLOCK */

/* Define CLASH_DETECTION if you want lock files to be written
   so that Emacs can tell instantly when you try to modify
   a file that someone else has modified in his Emacs.  */

/* #define CLASH_DETECTION */

/* Define a replacement for the baud rate switch, since DG/UX uses a different
   from BSD.  */

#define	BAUD_CONVERT    { 0, 110, 134, 150, 300, 600, 1200, 1800, 2400, \
			  4800, 9600, 19200, 38400 }

/*
 *	Define NLIST_STRUCT if the system has nlist.h
 */

#define	NLIST_STRUCT

/*
 *      Make WM Interface Compliant.
 */

#define XICCC

/* Here, on a separate page, add any special hacks needed
   to make Emacs work on this system.  For example,
   you might define certain system call names that don't
   exist on your system, or that do different things on
   your system and must be used only through an encapsulation
   (Which you should place, by convention, in sysdep.c).  */

/* Some compilers tend to put everything declared static
   into the initialized data area, which becomes pure after dumping Emacs.
   On these systems, you must #define static as nothing to foil this.
   Note that emacs carefully avoids static vars inside functions.  */

/* #define static */

/* DG/UX SPECIFIC ADDITIONS TO TEMPLATE FOLLOW: */

/* Use the Berkeley flavors of the library routines, instead of System V.  */

#define setpgrp(pid,pgrp) setpgrp2(pid,pgrp)
#define getpgrp(pid) getpgrp2(pid)

/* Act like Berkeley. */

#define _setjmp(env) sigsetjmp(env,0)
#define	_longjmp(env,val) longjmp(env,val)

/* Use TERMINFO instead of termcap */

#define	TERMINFO

/*
 *	Define HAVE_TERMIOS since this is POSIX,
 *	for terminal control.
 */

#define HAVE_TERMIOS

/*
 *	Use a Berkeley style sys/wait.h.
 *      This makes WIF* macros operate on structures instead of ints.
 */

#define _BSD_WAIT_FLAVOR

/*
 *      Use BSD and POSIX-style signals.  This is crucial!
 */

/* pmr@rock.concert.net says Emacs fails without this.  We don't know why.  */
#define SYSTEM_MALLOC

/* MAKING_MAKEFILE must be defined in "ymakefile" before including config.h */
#ifndef THIS_IS_YMAKEFILE

/* Make sure signal.h is included so macros below don't mess with it. */
/* DG/UX include files prevent multiple inclusion. */

#include <signal.h>

/* but undefine the sigmask and sigpause macros since they will get
   #define'd later. */
#undef sigmask
#undef sigpause

#define POSIX_SIGNALS

/* Define this if you use System 5 Release 4 Streams */
#define SYSV4_PTYS
#define open  sys_open
#define close sys_close
#define read  sys_read
#define write sys_write

#define INTERRUPTIBLE_OPEN
#define INTERRUPTIBLE_CLOSE
/* can't hurt to define these, even though read/write should auto restart */
#define INTERRUPTIBLE_IO

/* Can't use sys_signal because then etc/server.c would need sysdep.o.  */
extern struct sigaction act, oact;
#define signal(SIG,FUNC) berk_signal(SIG,FUNC)

#else /* THIS_IS_YMAKEFILE */
/* force gcc to be used */
CC=gcc
#endif /* not THIS_IS_YMAKEFILE */

#define LD_SWITCH_SYSTEM
/* Cannot depend on /lib/crt0.o because make does not understand an elink(1) */
#define START_FILES pre-crt0.o
#define LIBS_SYSTEM -ldgc /lib/crt0.o
#define LIB_GCC /usr/lib/gcc/libgcc.a

#ifdef _M88KBCS_TARGET
/* Karl Berry says: the environment
   recommended by gcc (88/open, a.k.a. m88kbcs) doesn't support some system
   functions, and gcc doesn't make it easy to switch environments.  */
#define NO_GET_LOAD_AVG
#endif

/* definitions for xmakefile production */
#ifdef COFF
 
#define C_COMPILER \
  TARGET_BINARY_INTERFACE=m88kdguxcoff gcc -traditional
 
#define LINKER \
  TARGET_BINARY_INTERFACE=m88kdguxcoff gcc -nostdlib

#define MAKE_COMMAND \
  TARGET_BINARY_INTERFACE=m88kdguxcoff make

#define C_DEBUG_SWITCH
#else /* not COFF */

#define C_COMPILER \
  TARGET_BINARY_INTERFACE=m88kdguxelf gcc -traditional
 
#define LINKER \
  TARGET_BINARY_INTERFACE=m88kdguxelf gcc -nostdlib

#define MAKE_COMMAND \
  TARGET_BINARY_INTERFACE=m88kdguxelf make

#define C_DEBUG_SWITCH -g -V2 -mversion-03.00 -mstandard
#endif /* COFF */
/* Define switches affecting x/ymakefile */
#define C_OPTIMIZE_SWITCH

/* Paul M Reilly <pmr@rock.concert.net> writes:
   On some systems (DGUX comes to mind real fast) FASYNC causes
   background writes to the terminal to stop all processes in the
   process group when invoked under the csh (and probably any shell
   with job control). This stops Emacs dead in its tracks when coming
   up under X11. */
#define BROKEN_FASYNC

/* (Assume) we do have vfork.  */

#define HAVE_VFORK
