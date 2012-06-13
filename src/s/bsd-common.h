/* Definitions file for GNU Emacs running on bsd 4.3

Copyright (C) 1985-1986, 2001-2012  Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.  */


/* Define symbols to identify the version of Unix this is.
   Define all the symbols that apply correctly.   */

/* We give these symbols the numeric values found in <sys/param.h> to
   avoid warnings about redefined macros.  */

/* Nothing in Emacs uses this any more.
   ifndef BSD4_3
   define BSD4_3 1
   endif
*/

#ifndef BSD_SYSTEM
#define BSD_SYSTEM 43
#endif /* BSD_SYSTEM */

/* For mem-limits.h.  */
#define BSD4_2

#define TABDLY OXTABS
#define TAB3 OXTABS

/* If the system's imake configuration file defines `NeedWidePrototypes'
   as `NO', we must define NARROWPROTO manually.  Such a define is
   generated in the Makefile generated by `xmkmf'.  If we don't
   define NARROWPROTO, we will see the wrong function prototypes
   for X functions taking float or double parameters.  */
#define NARROWPROTO 1

/* Do not use interrupt_input = 1 by default, because in 4.3
   we can make noninterrupt input work properly.  */
#undef INTERRUPT_INPUT

/* First pty name is /dev/ptyp0.  */
#define FIRST_PTY_LETTER 'p'

/* Define HAVE_PTYS if the system supports pty devices.  */
#define HAVE_PTYS

/* Define HAVE_SOCKETS if system supports 4.2-compatible sockets.  */
#define HAVE_SOCKETS

/* Define CLASH_DETECTION if you want lock files to be written
   so that Emacs can tell instantly when you try to modify
   a file that someone else has modified in his Emacs.  */
#define CLASH_DETECTION

/* Send signals to subprocesses by "typing" special chars at them.  */
#define SIGNALS_VIA_CHARACTERS
