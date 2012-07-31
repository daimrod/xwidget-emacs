/* Definitions file for GNU Emacs running on AT&T's System V Release 4

Copyright (C) 1987, 1990, 1999-2012  Free Software Foundation, Inc.

Written by James Van Artsdalen of Dell Computer Corp. james@bigtex.cactus.org.
Subsequently improved for Dell 2.2 by Eric S. Raymond <esr@snark.thyrsus.com>.

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

/* Get FIONREAD from <sys/filio.h>.  Get <sys/ttold.h> to get struct tchars.
   But get <termio.h> first to make sure ttold.h doesn't interfere.  */
#include <sys/wait.h>

#ifdef emacs
#include <sys/filio.h>
#include <termio.h>
#include <sys/ttold.h>
#include <signal.h>
#include <sys/stream.h>
#include <sys/stropts.h>
#include <sys/termios.h>
#endif
