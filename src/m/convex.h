/* machine description file for convex C1.
   Copyright (C) 1987 Free Software Foundation, Inc.

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


/* The following line tells the configuration script what sort of 
   operating system this machine is likely to run.
   USUAL-OPSYS="bsd4-3"  */

/* The following three symbols give information on
 the size of various data types.  */

#define SHORTBITS 16		/* Number of bits in a short */

#define INTBITS 32		/* Number of bits in an int */

#define LONGBITS 32		/* Number of bits in a long */

/* Define BIG_ENDIAN iff lowest-numbered byte in a word
   is the most significant byte.  */

#define BIG_ENDIAN

/* Define NO_ARG_ARRAY if you cannot take the address of the first of a
 * group of arguments and treat it as an array of the arguments.
 * Maybe it would be better to simply correct the code. */

#define NO_ARG_ARRAY

/* Define WORD_MACHINE if addresses and such have
 * to be corrected before they can be used as byte counts.  */

/* #define WORD_MACHINE */

/* Now define a symbol for the cpu type, if your compiler
   does not define it automatically.  */

/* convex already defined... */

/* Use type int rather than a union, to represent Lisp_Object */
/* This is desirable for most machines.  */

#define NO_UNION_TYPE

/* crt0.c should use the vax-bsd style of entry, with no dummy args.  */

#define CRT0_DUMMIES

/* crt0.c should define a symbol `start' and do .globl with a dot.  */

#define DOT_GLOBAL_START

/* Data type of load average, as read out of kmem.  */

#define LOAD_AVE_TYPE double

/* Convert that into an integer that is 100 for a load average of 1.0  */

#define LOAD_AVE_CVT(x) (int) ((x) * 100.0)

/* Define CANNOT_DUMP on machines where unexec does not work.
   Then the function dump-emacs will not be defined
   and temacs will do (load "loadup") automatically unless told otherwise.  */

/* #define CANNOT_DUMP */

/* Define VIRT_ADDR_VARIES if the virtual addresses of
   pure and impure space as loaded can vary, and even their
   relative order cannot be relied on.

   Otherwise Emacs assumes that text space precedes data space,
   numerically.  */

/*#define VIRT_ADDR_VARIES*/

/* Define C_ALLOCA if this machine does not support a true alloca
   and the one written in C should be used instead.
   Define HAVE_ALLOCA to say that the system provides a properly
   working alloca function and it should be used.
   Define neither one if an assembler-language alloca
   in the file alloca.s should be used.  */

/*#define C_ALLOCA*/
#define HAVE_ALLOCA

/* Define NO_REMAP if memory segmentation makes it not work well
   to change the boundary between the text section and data section
   when Emacs is dumped.  If you define this, the preloaded Lisp
   code will not be sharable; but that's better than failing completely.  */

/* #define NO_REMAP */

/* Addresses on the Convex have the high bit set.  */
#define DATA_SEG_BITS (1 << (INTBITS-1))

/* Right shift is logical shift.
   And the usual way of handling such machines, which involves
   copying the number into sign_extend_temp, does not work
   for reasons as yet unknown.  */

#define XINT(a)  sign_extend_lisp_int (a)

/* Convex uses a special version of unexec.  */

#define UNEXEC unexconvex.o

/* you gotta define 'COFF' for post 6.1 unexec. */

#define COFF
#define TEXT_START 0x80001000

/* Posix stuff for Convex OS 8.1 and up. */

#define C_SWITCH_MACHINE -pcc
#define LD_SWITCH_MACHINE \
    -e__start -L /usr/lib \
    '-A__iob=___ap$$iob' '-A_use_libc_sema=___ap$$use_libc_sema'

/* Use setsid when starting up inferiors. */
#define HAVE_SETSID

/* Use <dirent.h>. */
#define SYSV_SYSTEM_DIR
#define HAVE_CLOSEDIR

#ifdef _POSIX_SOURCE

/* These symbols have been undefined to advance the state of the art. */

#define S_IFMT _S_IFMT
#define S_IFDIR _S_IFDIR

#define S_IREAD _S_IREAD
#define S_IWRITE _S_IWRITE
#define S_IEXEC _S_IEXEC

#endif

/* Ptys may start below ptyp0; call a routine to hunt for where. */

#undef FIRST_PTY_LETTER
#define FIRST_PTY_LETTER first_pty_letter()

#if 0
/*
 * Force a K&R compilation and libraries with the Convex V 4.0 C compiler
 */
#define C_SWITCH_MACHINE -pcc
#define LIB_STANDARD -lc_old
#define LIBS_MACHINE -lC2_old
#define LD_SWITCH_MACHINE -X -NL -fn -Enoposix -A__iob=___ap\$$iob \
 -A_use_libc_sema=___ap\$$use_libc_sema -L /usr/lib
#endif
