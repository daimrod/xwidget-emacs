/* Interface definitions for display code.
   Copyright (C) 1985, 1992 Free Software Foundation, Inc.

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

/* Nonzero means don't assume anything about current
   contents of actual terminal frame */
extern int frame_garbaged;

/* Nonzero means last display completed and cursor is really at
   cursX, cursY.  Zero means it was preempted. */
extern int display_completed;

#ifdef HAVE_X_WINDOWS
#include <X11/Xlib.h>

struct face
  {
    /* If this is non-zero, it is a GC we can use without modification
       to represent this face. */
    GC gc;
  
    /* Pixel value for foreground color. */
    int foreground;
  
    /* Pixel value for background color. */
    int background;
  
    /* Font used for this face */
    XFontStruct font;
  
    /* Background stipple or bitmap used for this face. */
    Pixmap stipple;
  
    /* Whether or not to underline text in this face. */
    char underline;
  };

typedef struct face *FACE;

#define NORMAL_FACE ((FACE *) 0)

#define FACE_HAS_GC(f) ((f)->gc)
#define FACE_GC(f) ((f)->gc)
#define FACE_FOREGROUND(f) ((f)->foreground)
#define FACE_BACKGROUND(f) ((f)->background)
#define FACE_FONT(f) ((f)->font)
#define FACE_STIPPLE(f) ((f)->stipple)
#define FACE_UNDERLINE_P(f) ((f)->underline)

#else  /* Not X */

typedef int FACE;

#define NORMAL_FACE 0x0
#define HIGHLIGHT_FACE 0x1
#define UNDERLINE_FACE 0x2
#define HIGHLIGHT_UNDERLINE_FACE 0x3

#define FACE_HIGHLIGHT(f) ((f) & 0x1)
#define FACE_UNDERLINE(f) ((f) & 0x2)
#endif /* Not X */


/* This structure is used for the actual display of text on a frame.

   There are two instantiations of it:  the glyphs currently displayed,
   and the glyphs we desire to display.  The latter object is generated
   from buffers being displayed. */

struct frame_glyphs
  {
#ifdef MULTI_FRAME
    struct  frame *frame;	/* Frame these glyphs belong to. */
#endif /* MULTI_FRAME */
    int height;
    int width;

    /* Contents of the frame.
       glyphs[V][H] is the glyph at position V, H.
       Note that glyphs[V][-1],
                 glyphs[V][used[V]],
	     and glyphs[V][frame_width] are always '\0'.  */
    GLYPH **glyphs;
    /* long vector from which the strings in `glyphs' are taken.  */
    GLYPH *total_contents;

    /* When representing a desired frame,
         enable[n] == 0 means that line n is same as current frame.
       When representing current frame contents,
         enable[n] == 0 means that line n is blank.  */
    char *enable;

    /* Everything on line n after column used[n] is considered blank.  */
    int *used;

    /* highlight[n] != 0 iff line n is highlighted.  */
    char *highlight;

    /* Buffer offset of this line's first char. */
    int   *bufp;

#ifdef HAVE_X_WINDOWS
    /* Pixel position of top left corner of line. */
    short *top_left_x;
    short *top_left_y;

    /* Pixel width of line. */
    short *pix_width;

    /* Pixel height of line. */
    short *pix_height;

    /* Largest font ascent on this line. */
    short *max_ascent;
#endif	/* HAVE_X_WINDOWS */
  };

extern void get_display_line ();
extern Lisp_Object sit_for ();
