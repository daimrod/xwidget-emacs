
/* Generic frame functions.
   Copyright (C) 1989, 1992 Free Software Foundation.

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

#include <stdio.h>

#include "config.h"

#ifdef MULTI_FRAME

#include "lisp.h"
#include "frame.h"
#include "window.h"
#include "termhooks.h"

Lisp_Object Vemacs_iconified;
Lisp_Object Qframep;
Lisp_Object Qlive_frame_p;
Lisp_Object Vframe_list;
Lisp_Object Vterminal_frame;
Lisp_Object Vdefault_minibuffer_frame;
Lisp_Object Vdefault_frame_alist;
Lisp_Object Qminibuffer;

extern Lisp_Object Vminibuffer_list;
extern Lisp_Object get_minibuffer ();

DEFUN ("framep", Fframep, Sframep, 1, 1, 0,
  "Return non-nil if OBJECT is a frame.\n\
Value is t for a termcap frame (a character-only terminal),\n\
`x' for an Emacs frame that is really an X window.\n\
Also see `live-frame-p'.")
  (object)
     Lisp_Object object;
{
  if (XTYPE (object) != Lisp_Frame)
    return Qnil;
  switch (XFRAME (object)->output_method)
    {
    case output_termcap:
      return Qt;
    case output_x_window:
      return intern ("x");
    default:
      abort ();
    }
}

DEFUN ("live-frame-p", Flive_frame_p, Slive_frame_p, 1, 1, 0,
  "Return non-nil if OBJECT is a frame which has not been deleted.\n\
Value is nil if OBJECT is not a live frame.  If object is a live\n\
frame, the return value indicates what sort of output device it is\n\
displayed on.  Value is t for a termcap frame (a character-only\n\
terminal), `x' for an Emacs frame being displayed in an X window.")
  (object)
     Lisp_Object object;
{
  return ((FRAMEP (object)
	   && FRAME_LIVE_P (XFRAME (object)))
	  ? Fframep (object)
	  : Qnil);
}

struct frame *
make_frame (mini_p)
     int mini_p;
{
  Lisp_Object frame;
  register struct frame *f;
  register Lisp_Object root_window;
  register Lisp_Object mini_window;

  frame = Fmake_vector (((sizeof (struct frame) - (sizeof (Lisp_Vector)
						     - sizeof (Lisp_Object)))
			  / sizeof (Lisp_Object)),
			 make_number (0));
  XSETTYPE (frame, Lisp_Frame);
  f = XFRAME (frame);

  f->cursor_x = 0;
  f->cursor_y = 0;
  f->current_glyphs = 0;
  f->desired_glyphs = 0;
  f->visible = 0;
  f->display.nothing = 0;
  f->iconified = 0;
  f->wants_modeline = 1;
  f->auto_raise = 0;
  f->auto_lower = 0;
  f->no_split = 0;
  f->garbaged = 0;
  f->has_minibuffer = mini_p;
  f->focus_frame = frame;

  f->param_alist = Qnil;

  root_window = make_window (0);
  if (mini_p)
    {
      mini_window = make_window (0);
      XWINDOW (root_window)->next = mini_window;
      XWINDOW (mini_window)->prev = root_window;
      XWINDOW (mini_window)->mini_p = Qt;
      XWINDOW (mini_window)->frame = frame;
      f->minibuffer_window = mini_window;
    }
  else
    {
      mini_window = Qnil;
      XWINDOW (root_window)->next = Qnil;
      f->minibuffer_window = Qnil;
    }

  XWINDOW (root_window)->frame = frame;

  /* 10 is arbitrary,
     just so that there is "something there."
     Correct size will be set up later with change_frame_size.  */

  f->width = 10;
  f->height = 10;

  XFASTINT (XWINDOW (root_window)->width) = 10;
  XFASTINT (XWINDOW (root_window)->height) = (mini_p ? 9 : 10);

  if (mini_p)
    {
      XFASTINT (XWINDOW (mini_window)->width) = 10;
      XFASTINT (XWINDOW (mini_window)->top) = 9;
      XFASTINT (XWINDOW (mini_window)->height) = 1;
    }

  /* Choose a buffer for the frame's root window.  */
  {
    Lisp_Object buf;

    XWINDOW (root_window)->buffer = Qt;
    buf = Fcurrent_buffer ();
    /* If buf is a 'hidden' buffer (i.e. one whose name starts with
       a space), try to find another one.  */
    if (XSTRING (Fbuffer_name (buf))->data[0] == ' ')
      buf = Fother_buffer (buf);
    Fset_window_buffer (root_window, buf);
  }

  if (mini_p)
    {
      XWINDOW (mini_window)->buffer = Qt;
      Fset_window_buffer (mini_window,
			  (NILP (Vminibuffer_list)
			   ? get_minibuffer (0)
			   : Fcar (Vminibuffer_list)));
    }

  f->root_window = root_window;
  f->selected_window = root_window;
  /* Make sure this window seems more recently used than
     a newly-created, never-selected window.  */
  XFASTINT (XWINDOW (f->selected_window)->use_time) = ++window_select_count;

  Vframe_list = Fcons (frame, Vframe_list);

  return f;
}

/* Make a frame using a separate minibuffer window on another frame.
   MINI_WINDOW is the minibuffer window to use.  nil means use the
   default (the global minibuffer).  */

struct frame *
make_frame_without_minibuffer (mini_window)
     register Lisp_Object mini_window;
{
  register struct frame *f;

  /* Choose the minibuffer window to use.  */
  if (NILP (mini_window))
    {
      if (XTYPE (Vdefault_minibuffer_frame) != Lisp_Frame)
	error ("default-minibuffer-frame must be set when creating minibufferless frames");
      if (! FRAME_LIVE_P (XFRAME (Vdefault_minibuffer_frame)))
	error ("default-minibuffer-frame must be a live frame");
      mini_window = XFRAME (Vdefault_minibuffer_frame)->minibuffer_window;
    }
  else
    {
      CHECK_WINDOW (mini_window, 0);
    }

  /* Make a frame containing just a root window.  */
  f = make_frame (0);

  /* Install the chosen minibuffer window, with proper buffer.  */
  f->minibuffer_window = mini_window;
  Fset_window_buffer (mini_window,
		      (NILP (Vminibuffer_list)
		       ? get_minibuffer (0)
		       : Fcar (Vminibuffer_list)));
  return f;
}

/* Make a frame containing only a minibuffer window.  */

struct frame *
make_minibuffer_frame ()
{
  /* First make a frame containing just a root window, no minibuffer.  */

  register struct frame *f = make_frame (0);
  register Lisp_Object mini_window;
  register Lisp_Object frame;

  XSET (frame, Lisp_Frame, f);

  /* ??? Perhaps leave it to the user program to set auto_raise.  */
  f->auto_raise = 1;
  f->auto_lower = 0;
  f->no_split = 1;
  f->wants_modeline = 0;
  f->has_minibuffer = 1;

  /* Now label the root window as also being the minibuffer.
     Avoid infinite looping on the window chain by marking next pointer
     as nil. */

  mini_window = f->minibuffer_window = f->root_window;
  XWINDOW (mini_window)->mini_p = Qt;
  XWINDOW (mini_window)->next = Qnil;
  XWINDOW (mini_window)->prev = mini_window;
  XWINDOW (mini_window)->frame = frame;

  /* Put the proper buffer in that window.  */

  Fset_window_buffer (mini_window,
		      (NILP (Vminibuffer_list)
		       ? get_minibuffer (0)
		       : Fcar (Vminibuffer_list)));
  return f;
}

/* Construct a frame that refers to the terminal (stdin and stdout).  */

struct frame *
make_terminal_frame ()
{
  register struct frame *f;

  Vframe_list = Qnil;
  f = make_frame (1);
  f->name = build_string ("terminal");
  f->visible = 1;
  f->display.nothing = 1;   /* Nonzero means frame isn't deleted.  */
  XSET (Vterminal_frame, Lisp_Frame, f);
  return f;
}

DEFUN ("select-frame", Fselect_frame, Sselect_frame, 1, 2, 0,
  "Select the frame FRAME.  FRAMES's selected window becomes \"the\"\n\
selected window.  If the optional parameter NO-ENTER is non-nil, don't\n\
focus on that frame.")
  (frame, no_enter)
     Lisp_Object frame, no_enter;
{
  CHECK_LIVE_FRAME (frame, 0);

  if (selected_frame == XFRAME (frame))
    return frame;

  selected_frame = XFRAME (frame);
  if (! FRAME_MINIBUF_ONLY_P (selected_frame))
    last_nonminibuf_frame = selected_frame;

  Fselect_window (XFRAME (frame)->selected_window);

#ifdef HAVE_X_WINDOWS
#ifdef MULTI_FRAME
  if (FRAME_IS_X (XFRAME (frame))
      && NILP (no_enter))
    {
      Ffocus_frame (frame);
    }
#endif
#endif
  choose_minibuf_frame ();

  return frame;
}

DEFUN ("selected-frame", Fselected_frame, Sselected_frame, 0, 0, 0,
  "Return the frame that is now selected.")
  ()
{
  Lisp_Object tem;
  XSET (tem, Lisp_Frame, selected_frame);
  return tem;
}

DEFUN ("window-frame", Fwindow_frame, Swindow_frame, 1, 1, 0,
  "Return the frame object that window WINDOW is on.")
  (window)
     Lisp_Object window;
{
  CHECK_WINDOW (window, 0);
  return XWINDOW (window)->frame;
}

DEFUN ("frame-root-window", Fframe_root_window, Sframe_root_window, 0, 1, 0,
       "Returns the root-window of FRAME.")
  (frame)
     Lisp_Object frame;
{
  if (NILP (frame))
    XSET (frame, Lisp_Frame, selected_frame);
  else
    CHECK_LIVE_FRAME (frame, 0);

  return XFRAME (frame)->root_window;
}

DEFUN ("frame-selected-window", Fframe_selected_window,
       Sframe_selected_window, 0, 1, 0,
  "Return the selected window of frame object FRAME.")
  (frame)
     Lisp_Object frame;
{
  if (NILP (frame))
    XSET (frame, Lisp_Frame, selected_frame);
  else
    CHECK_LIVE_FRAME (frame, 0);

  return XFRAME (frame)->selected_window;
}

DEFUN ("frame-list", Fframe_list, Sframe_list,
       0, 0, 0,
       "Return a list of all frames.")
  ()
{
  return Fcopy_sequence (Vframe_list);
}

#ifdef MULTI_FRAME

/* Return the next frame in the frame list after FRAME.
   If MINIBUF is non-nil, include all frames.
   If MINIBUF is nil, exclude minibuffer-only frames.
   If MINIBUF is a window, include only frames using that window for
   their minibuffer.  */
Lisp_Object
next_frame (frame, minibuf)
     Lisp_Object frame;
     Lisp_Object minibuf;
{
  Lisp_Object tail;
  int passed = 0;

  /* There must always be at least one frame in Vframe_list.  */
  if (! CONSP (Vframe_list))
    abort ();

  while (1)
    for (tail = Vframe_list; CONSP (tail); tail = XCONS (tail)->cdr)
      {
	if (passed)
	  {
	    Lisp_Object f = XCONS (tail)->car;

	    /* Decide whether this frame is eligible to be returned,
	       according to minibuf.  */
	    if ((NILP (minibuf) && ! FRAME_MINIBUF_ONLY_P (XFRAME (f)))
		|| XTYPE (minibuf) != Lisp_Window
		|| EQ (FRAME_MINIBUF_WINDOW (XFRAME (f)), minibuf)
		|| EQ (f, frame))
	      return f;
	  }

	if (EQ (frame, XCONS (tail)->car))
	  passed++;
      }
}

/* Return the previous frame in the frame list before FRAME.
   If MINIBUF is non-nil, include all frames.
   If MINIBUF is nil, exclude minibuffer-only frames.
   If MINIBUF is a window, include only frames using that window for
   their minibuffer.  */
Lisp_Object
prev_frame (frame, minibuf)
     Lisp_Object frame;
     Lisp_Object minibuf;
{
  Lisp_Object tail;
  Lisp_Object prev;

  /* There must always be at least one frame in Vframe_list.  */
  if (! CONSP (Vframe_list))
    abort ();

  prev = Qnil;
  while (1)
    {
      for (tail = Vframe_list; CONSP (tail); tail = XCONS (tail)->cdr)
	{
	  Lisp_Object scr = XCONS (tail)->car;

	  if (XTYPE (scr) != Lisp_Frame)
	    abort ();

	  if (EQ (frame, scr) && !NILP (prev))
	    return prev;

	  /* Decide whether this frame is eligible to be returned,
	     according to minibuf.  */
	  if ((NILP (minibuf) && ! FRAME_MINIBUF_ONLY_P (XFRAME (scr)))
	      || XTYPE (minibuf) != Lisp_Window
	      || EQ (FRAME_MINIBUF_WINDOW (XFRAME (scr)), minibuf))
	    prev = scr;
	}

      if (NILP (prev))
	/* We went through the whole frame list without finding a single
	   acceptable frame.  Return the original frame.  */
	prev = frame;
    }
	  
}

DEFUN ("next-frame", Fnext_frame, Snext_frame, 0, 2, 0,
  "Return the next frame in the frame list after FRAME.\n\
If optional argument MINIBUF is non-nil, include all frames.  If\n\
MINIBUF is nil or omitted, exclude minibuffer-only frames.  If\n\
MINIBUF is a window, include only frames using that window for their\n\
minibuffer.")
  (frame, miniframe)
Lisp_Object frame, miniframe;
{
  Lisp_Object tail;

  if (NILP (frame))
    XSET (frame, Lisp_Frame, selected_frame);
  else
    CHECK_LIVE_FRAME (frame, 0);

  return next_frame (frame, miniframe);
}
#endif /* MULTI_FRAME */

DEFUN ("delete-frame", Fdelete_frame, Sdelete_frame, 0, 1, "",
  "Delete FRAME, permanently eliminating it from use.\n\
If omitted, FRAME defaults to the selected frame.\n\
A frame may not be deleted if its minibuffer is used by other frames.")
  (frame)
     Lisp_Object frame;
{
  struct frame *f;
  union display displ;

  if (EQ (frame, Qnil))
    {
      f = selected_frame;
      XSET (frame, Lisp_Frame, f);
    }
  else
    {
      CHECK_FRAME (frame, 0);
      f = XFRAME (frame);
    }

  if (! FRAME_LIVE_P (f))
    return;

  /* Are there any other frames besides this one?  */
  if (f == selected_frame && EQ (next_frame (frame, Qt), frame))
    error ("Attempt to delete the only frame");

  /* Does this frame have a minibuffer, and is it the surrogate
     minibuffer for any other frame?  */
  if (FRAME_HAS_MINIBUF (XFRAME (frame)))
    {
      Lisp_Object frames;

      for (frames = Vframe_list;
	   CONSP (frames);
	   frames = XCONS (frames)->cdr)
	{
	  Lisp_Object this = XCONS (frames)->car;

	  if (! EQ (this, frame)
	      && EQ (frame,
		     (WINDOW_FRAME
		      (XWINDOW
		       (FRAME_MINIBUF_WINDOW
			(XFRAME (this)))))))
	    error ("Attempt to delete a surrogate minibuffer frame");
	}
    }

  /* Don't let the frame remain selected.  */
  if (f == selected_frame)
    Fselect_frame (next_frame (frame, Qt));

  /* Don't allow minibuf_window to remain on a deleted frame.  */
  if (EQ (f->minibuffer_window, minibuf_window))
    {
      Fset_window_buffer (selected_frame->minibuffer_window,
			  XWINDOW (minibuf_window)->buffer);
      minibuf_window = selected_frame->minibuffer_window;
    }

  Vframe_list = Fdelq (frame, Vframe_list);
  f->visible = 0;
  displ = f->display;
  f->display.nothing = 0;

#ifdef HAVE_X_WINDOWS
  if (FRAME_IS_X (f))
    x_destroy_window (f, displ);
#endif

  /* If we've deleted the last_nonminibuf_frame, then try to find
     another one.  */
  if (f == last_nonminibuf_frame)
    {
      Lisp_Object frames;

      last_nonminibuf_frame = 0;

      for (frames = Vframe_list;
	   CONSP (frames);
	   frames = XCONS (frames)->cdr)
	{
	  f = XFRAME (XCONS (frames)->car);
	  if (!FRAME_MINIBUF_ONLY_P (f))
	    {
	      last_nonminibuf_frame = f;
	      break;
	    }
	}
    }

  /* If we've deleted Vdefault_minibuffer_frame, try to find another
     one.  Prefer minibuffer-only frames, but also notice frames
     with other windows.  */
  if (EQ (frame, Vdefault_minibuffer_frame))
    {
      Lisp_Object frames;

      /* The last frame we saw with a minibuffer, minibuffer-only or not.  */
      Lisp_Object frame_with_minibuf = Qnil;

      for (frames = Vframe_list;
	   CONSP (frames);
	   frames = XCONS (frames)->cdr)
	{
	  Lisp_Object this = XCONS (frames)->car;

	  if (XTYPE (this) != Lisp_Frame)
	    abort ();
	  f = XFRAME (this);

	  if (FRAME_HAS_MINIBUF (f))
	    {
	      frame_with_minibuf = this;
	      if (FRAME_MINIBUF_ONLY_P (f))
		break;
	    }
	}

      /* We know that there must be some frame with a minibuffer out
	 there.  If this were not true, all of the frames present
	 would have to be minibufferless, which implies that at some
	 point their minibuffer frames must have been deleted, but
	 that is prohibited at the top; you can't delete surrogate
	 minibuffer frames.  */
      if (NILP (frame_with_minibuf))
	abort ();

      Vdefault_minibuffer_frame = frame_with_minibuf;
    }

  return Qnil;
}

/* Return mouse position in character cell units.  */

DEFUN ("mouse-position", Fmouse_position, Smouse_position, 0, 0, 0,
  "Return a list (FRAME X . Y) giving the current mouse frame and position.\n\
If Emacs is running on a mouseless terminal or hasn't been programmed\n\
to read the mouse position, it returns the selected frame for FRAME\n\
and nil for X and Y.")
  ()
{
  Lisp_Object x, y, dummy;
  FRAME_PTR f;

  if (mouse_position_hook)
    (*mouse_position_hook) (&f, &x, &y, &dummy);
  else
    {
      f = selected_frame;
      x = y = Qnil;
    }

  XSET (dummy, Lisp_Frame, f);
  return Fcons (dummy, Fcons (make_number (x), make_number (y)));
}

DEFUN ("set-mouse-position", Fset_mouse_position, Sset_mouse_position, 3, 3, 0,
  "Move the mouse pointer to the center of cell (X,Y) in FRAME.\n\
WARNING:  If you use this under X, you should do `unfocus-frame' afterwards.")
  (frame, x, y)
     Lisp_Object frame, x, y;
{
  CHECK_LIVE_FRAME (frame, 0);
  CHECK_NUMBER (x, 2);
  CHECK_NUMBER (y, 1);

#ifdef HAVE_X_WINDOWS
  if (FRAME_IS_X (XFRAME (frame)))
    /* Warping the mouse will cause  enternotify and focus events. */
    x_set_mouse_position (XFRAME (frame), x, y);
#endif

  return Qnil;
}

#if 0
/* ??? Can this be replaced with a Lisp function?
   It is used in minibuf.c.  Can we get rid of that?
   Yes.  All uses in minibuf.c are gone, and parallels to these
   functions have been defined in frame.el.  */

DEFUN ("frame-configuration", Fframe_configuration, Sframe_configuration,
       0, 0, 0,
  "Return object describing current frame configuration.\n\
The frame configuration is the current mouse position and selected frame.\n\
This object can be given to `restore-frame-configuration'\n\
to restore this frame configuration.")
  ()
{
  Lisp_Object c, time;
  
  c = Fmake_vector (make_number(4), Qnil);
  XVECTOR (c)->contents[0] = Fselected_frame();
  if (mouse_position_hook)
    (*mouse_position_hook) (&XVECTOR (c)->contents[1]
			    &XVECTOR (c)->contents[2],
			    &XVECTOR (c)->contents[3],
			    &time);
  return c;
}

DEFUN ("restore-frame-configuration", Frestore_frame_configuration,
       Srestore_frame_configuration,
       1, 1, 0,
  "Restores frame configuration CONFIGURATION.")
  (config)
  Lisp_Object config;
{
  Lisp_Object x_pos, y_pos, frame;

  CHECK_VECTOR (config, 0);
  if (XVECTOR (config)->size != 3)
    {
      error ("Wrong size vector passed to restore-frame-configuration");
    }
  frame = XVECTOR (config)->contents[0];
  CHECK_LIVE_FRAME (frame, 0);

  Fselect_frame (frame, Qnil);

#if 0
  /* This seems to interfere with the frame selection mechanism. jla */
  x_pos = XVECTOR (config)->contents[2];
  y_pos = XVECTOR (config)->contents[3];
  set_mouse_position (frame, XINT (x_pos), XINT (y_pos));
#endif

  return frame;
}    
#endif

DEFUN ("make-frame-visible", Fmake_frame_visible, Smake_frame_visible,
       0, 1, 0,
  "Make the frame FRAME visible (assuming it is an X-window).\n\
Also raises the frame so that nothing obscures it.")
  (frame)
     Lisp_Object frame;
{
  if (NILP (frame))
    frame = selected_frame;

  CHECK_LIVE_FRAME (frame, 0);

  if (FRAME_IS_X (XFRAME (frame)))
    x_make_frame_visible (XFRAME (frame));

  return frame;
}

DEFUN ("make-frame-invisible", Fmake_frame_invisible, Smake_frame_invisible,
       0, 1, "",
  "Make the frame FRAME invisible (assuming it is an X-window).")
  (frame)
     Lisp_Object frame;
{
  if (NILP (frame))
    frame = selected_frame;

  CHECK_LIVE_FRAME (frame, 0);

  if (FRAME_IS_X (XFRAME (frame)))
    x_make_frame_invisible (XFRAME (frame));

  return Qnil;
}

DEFUN ("iconify-frame", Ficonify_frame, Siconify_frame,
       0, 1, "",
  "Make the frame FRAME into an icon.")
  (frame)
     Lisp_Object frame;
{
  if (NILP (frame))
    frame = selected_frame;
  
  CHECK_LIVE_FRAME (frame, 0);

  if (FRAME_IS_X (XFRAME (frame)))
      x_iconify_frame (XFRAME (frame));

  return Qnil;
}

DEFUN ("frame-visible-p", Fframe_visible_p, Sframe_visible_p,
       1, 1, 0,
       "Return t if FRAME is now \"visible\" (actually in use for display).\n\
A frame that is not \"visible\" is not updated and, if it works through\n\
a window system, it may not show at all.\n\
Return the symbol `icon' if window is visible only as an icon.")
  (frame)
     Lisp_Object frame;
{
  CHECK_LIVE_FRAME (frame, 0);

  if (XFRAME (frame)->visible)
    return Qt;
  if (XFRAME (frame)->iconified)
    return intern ("icon");
  return Qnil;
}

DEFUN ("visible-frame-list", Fvisible_frame_list, Svisible_frame_list,
       0, 0, 0,
       "Return a list of all frames now \"visible\" (being updated).")
  ()
{
  Lisp_Object tail, frame;
  struct frame *f;
  Lisp_Object value;

  value = Qnil;
  for (tail = Vframe_list; CONSP (tail); tail = XCONS (tail)->cdr)
    {
      frame = XCONS (tail)->car;
      if (XTYPE (frame) != Lisp_Frame)
	continue;
      f = XFRAME (frame);
      if (f->visible)
	value = Fcons (frame, value);
    }
  return value;
}



DEFUN ("redirect-frame-focus", Fredirect_frame_focus, Sredirect_frame_focus,
       1, 2, 0,
  "Arrange for keystrokes typed at FRAME to be sent to FOCUS-FRAME.\n\
This means that, after reading a keystroke typed at FRAME,\n\
`last-event-frame' will be FOCUS-FRAME.\n\
\n\
If FOCUS-FRAME is omitted or eq to FRAME, any existing redirection is\n\
cancelled, and the frame again receives its own keystrokes.\n\
\n\
The redirection lasts until the next call to `redirect-frame-focus'\n\
or `select-frame'.\n\
\n\
This is useful for temporarily redirecting keystrokes to the minibuffer\n\
window when a frame doesn't have its own minibuffer.")
  (frame, focus_frame)
    Lisp_Object frame, focus_frame;
{
  CHECK_LIVE_FRAME (frame, 0);

  if (NILP (focus_frame))
    focus_frame = frame;
  else
    CHECK_LIVE_FRAME (focus_frame, 1);

  XFRAME (frame)->focus_frame = focus_frame;

  if (frame_rehighlight_hook)
    (*frame_rehighlight_hook) ();
  
  return Qnil;
}


DEFUN ("frame-focus", Fframe_focus, Sframe_focus, 1, 1, 0,
  "Return the frame to which FRAME's keystrokes are currently being sent.\n\
See `redirect-frame-focus'.")
  (frame)
    Lisp_Object frame;
{
  CHECK_LIVE_FRAME (frame, 0);
  return FRAME_FOCUS_FRAME (XFRAME (frame));
}



Lisp_Object
get_frame_param (frame, prop)
     register struct frame *frame;
     Lisp_Object prop;
{
  register Lisp_Object tem;

  tem = Fassq (prop, frame->param_alist);
  if (EQ (tem, Qnil))
    return tem;
  return Fcdr (tem);
}

void
store_in_alist (alistptr, propname, val)
     Lisp_Object *alistptr, val;
     char *propname;
{
  register Lisp_Object tem;
  register Lisp_Object prop;

  prop = intern (propname);
  tem = Fassq (prop, *alistptr);
  if (EQ (tem, Qnil))
    *alistptr = Fcons (Fcons (prop, val), *alistptr);
  else
    Fsetcdr (tem, val);
}

void
store_frame_param (f, prop, val)
     struct frame *f;
     Lisp_Object prop, val;
{
  register Lisp_Object tem;

  tem = Fassq (prop, f->param_alist);
  if (EQ (tem, Qnil))
    f->param_alist = Fcons (Fcons (prop, val), f->param_alist);
  else
    Fsetcdr (tem, val);

  if (EQ (prop, Qminibuffer)
      && XTYPE (val) == Lisp_Window)
    {
      if (! MINI_WINDOW_P (XWINDOW (val)))
	error ("Surrogate minibuffer windows must be minibuffer windows.");

      if (FRAME_HAS_MINIBUF (f) || FRAME_MINIBUF_ONLY_P (f))
	error ("Can't change the surrogate minibuffer of a frame with its own minibuffer.");

      /* Install the chosen minibuffer window, with proper buffer.  */
      f->minibuffer_window = val;
    }
}

DEFUN ("frame-parameters", Fframe_parameters, Sframe_parameters, 0, 1, 0,
  "Return the parameters-alist of frame FRAME.\n\
It is a list of elements of the form (PARM . VALUE), where PARM is a symbol.\n\
The meaningful PARMs depend on the kind of frame.\n\
If FRAME is omitted, return information on the currently selected frame.")
  (frame)
     Lisp_Object frame;
{
  Lisp_Object alist;
  struct frame *f;

  if (EQ (frame, Qnil))
    f = selected_frame;
  else
    {
      CHECK_FRAME (frame, 0);
      f = XFRAME (frame);
    }

  if (f->display.nothing == 0)
    return Qnil;

  alist = Fcopy_alist (f->param_alist);
  store_in_alist (&alist, "name", f->name);
  store_in_alist (&alist, "height", make_number (f->height));
  store_in_alist (&alist, "width", make_number (f->width));
  store_in_alist (&alist, "modeline", (f->wants_modeline ? Qt : Qnil));
  store_in_alist (&alist, "minibuffer",
		  (FRAME_HAS_MINIBUF (f)
		   ? (FRAME_MINIBUF_ONLY_P (f) ? intern ("only") : Qt)
		   : FRAME_MINIBUF_WINDOW (f)));
  store_in_alist (&alist, "unsplittable", (f->no_split ? Qt : Qnil));

  if (FRAME_IS_X (f))
    x_report_frame_params (f, &alist);
  return alist;
}

DEFUN ("modify-frame-parameters", Fmodify_frame_parameters, 
       Smodify_frame_parameters, 2, 2, 0,
  "Modify the parameters of frame FRAME according to ALIST.\n\
ALIST is an alist of parameters to change and their new values.\n\
Each element of ALIST has the form (PARM . VALUE), where PARM is a symbol.\n\
The meaningful PARMs depend on the kind of frame; undefined PARMs are ignored.")
  (frame, alist)
     Lisp_Object frame, alist;
{
  register struct frame *f;
  register Lisp_Object tail, elt, prop, val;

  if (EQ (frame, Qnil))
    f = selected_frame;
  else
    {
      CHECK_LIVE_FRAME (frame, 0);
      f = XFRAME (frame);
    }

  if (FRAME_IS_X (f))
    for (tail = alist; !EQ (tail, Qnil); tail = Fcdr (tail))
      {
	elt = Fcar (tail);
	prop = Fcar (elt);
	val = Fcdr (elt);
	x_set_frame_param (f, prop, val,
			    get_frame_param (f, prop));
	store_frame_param (f, prop, val);
      }

  return Qnil;
}


#if 0
/* This function isn't useful enough by itself to include; we need to
   add functions to allow the user to find the size of a font before
   this is actually useful.  */

DEFUN ("frame-pixel-size", Fframe_pixel_size, 
       Sframe_pixel_size, 1, 1, 0,
  "Return a cons (width . height) of FRAME's size in pixels.")
  (frame)
     Lisp_Object frame;
{
  register struct frame *f;
  int width, height;

  CHECK_LIVE_FRAME (frame, 0);
  f = XFRAME (frame);
  
  return Fcons (make_number (x_pixel_width (f)),
		make_number (x_pixel_height (f)));
}
#endif

#if 0
/* These functions have no C callers, and can be written nicely in lisp.  */

DEFUN ("frame-height", Fframe_height, Sframe_height, 0, 0, 0,
  "Return number of lines available for display on selected frame.")
  ()
{
  return make_number (FRAME_HEIGHT (selected_frame));
}

DEFUN ("frame-width", Fframe_width, Sframe_width, 0, 0, 0,
  "Return number of columns available for display on selected frame.")
  ()
{
  return make_number (FRAME_WIDTH (selected_frame));
}
#endif

DEFUN ("set-frame-height", Fset_frame_height, Sset_frame_height, 2, 3, 0,
  "Specify that the frame FRAME has LINES lines.\n\
Optional third arg non-nil means that redisplay should use LINES lines\n\
but that the idea of the actual height of the frame should not be changed.")
  (frame, rows, pretend)
     Lisp_Object rows, pretend;
{
  register struct frame *f;

  CHECK_NUMBER (rows, 0);
  if (NILP (frame))
    f = selected_frame;
  else
    {
      CHECK_LIVE_FRAME (frame, 0);
      f = XFRAME (frame);
    }

  if (FRAME_IS_X (f))
    {
      if (XINT (rows) != f->width)
	x_set_window_size (f, f->width, XINT (rows));
    }
  else
    change_frame_size (f, XINT (rows), 0, !NILP (pretend));
  return Qnil;
}

DEFUN ("set-frame-width", Fset_frame_width, Sset_frame_width, 2, 3, 0,
  "Specify that the frame FRAME has COLS columns.\n\
Optional third arg non-nil means that redisplay should use COLS columns\n\
but that the idea of the actual width of the frame should not be changed.")
  (frame, cols, pretend)
     Lisp_Object cols, pretend;
{
  register struct frame *f;
  CHECK_NUMBER (cols, 0);
  if (NILP (frame))
    f = selected_frame;
  else
    {
      CHECK_LIVE_FRAME (frame, 0);
      f = XFRAME (frame);
    }

  if (FRAME_IS_X (f))
    {
      if (XINT (cols) != f->width)
	x_set_window_size (f, XINT (cols), f->height);
    }
  else
    change_frame_size (selected_frame, 0, XINT (cols), !NILP (pretend));
  return Qnil;
}

DEFUN ("set-frame-size", Fset_frame_size, Sset_frame_size, 3, 3, 0,
  "Sets size of FRAME to COLS by ROWS, measured in characters.")
  (frame, cols, rows)
     Lisp_Object frame, cols, rows;
{
  register struct frame *f;
  int mask;

  CHECK_LIVE_FRAME (frame, 0);
  CHECK_NUMBER (cols, 2);
  CHECK_NUMBER (rows, 1);
  f = XFRAME (frame);

  if (FRAME_IS_X (f))
    {
      if (XINT (rows) != f->height || XINT (cols) != f->width)
	x_set_window_size (f, XINT (cols), XINT (rows));
    }
  else
    change_frame_size (f, XINT (rows), XINT (cols), 0);

  return Qnil;
}

DEFUN ("set-frame-position", Fset_frame_position, 
       Sset_frame_position, 3, 3, 0,
  "Sets position of FRAME in pixels to XOFFSET by YOFFSET.\n\
If XOFFSET or YOFFSET are negative, they are interpreted relative to\n\
the leftmost or bottommost position FRAME could occupy without going\n\
off the frame.")
  (frame, xoffset, yoffset)
     Lisp_Object frame, xoffset, yoffset;
{
  register struct frame *f;
  int mask;

  CHECK_LIVE_FRAME (frame, 0);
  CHECK_NUMBER (xoffset, 1);
  CHECK_NUMBER (yoffset, 2);
  f = XFRAME (frame);

  if (FRAME_IS_X (f))
    x_set_offset (f, XINT (xoffset), XINT (yoffset));

  return Qt;
}


#ifndef HAVE_X11
DEFUN ("rubber-band-rectangle", Frubber_band_rectangle, Srubber_band_rectangle,
       3, 3, "",
  "Ask user to specify a window position and size on FRAME with the mouse.\n\
Arguments are FRAME, NAME and GEO.  NAME is a name to be displayed as\n\
the purpose of this rectangle.  GEO is an X-windows size spec that can\n\
specify defaults for some sizes/positions.  If GEO specifies everything,\n\
the mouse is not used.\n\
Returns a list of five values: (FRAME LEFT TOP WIDTH HEIGHT).")
  (frame, name, geo)
     Lisp_Object frame;
     Lisp_Object name;
     Lisp_Object geo;
{
  int vals[4];
  Lisp_Object nums[4];
  int i;

  CHECK_FRAME (frame, 0);
  CHECK_STRING (name, 1);
  CHECK_STRING (geo, 2);

  switch (XFRAME (frame)->output_method)
    {
    case output_x_window:
      x_rubber_band (XFRAME (frame), &vals[0], &vals[1], &vals[2], &vals[3],
		     XSTRING (geo)->data, XSTRING (name)->data);
      break;

    default:
      return Qnil;
    }

  for (i = 0; i < 4; i++)
    XFASTINT (nums[i]) = vals[i];
  return Fcons (frame, Flist (4, nums));
  return Qnil;
}
#endif /* not HAVE_X11 */

choose_minibuf_frame ()
{
  /* For lowest-level minibuf, put it on currently selected frame
     if frame has a minibuffer.  */
  if (minibuf_level == 0
      && selected_frame != 0
      && !EQ (minibuf_window, selected_frame->minibuffer_window)
      && !EQ (Qnil, selected_frame->minibuffer_window))
    {
      Fset_window_buffer (selected_frame->minibuffer_window,
			  XWINDOW (minibuf_window)->buffer);
      minibuf_window = selected_frame->minibuffer_window;
    }
}

syms_of_frame ()
{
  Qframep = intern ("framep");
  Qlive_frame_p = intern ("live_frame_p");
  Qminibuffer = intern ("minibuffer");

  staticpro (&Qframep);
  staticpro (&Qlive_frame_p);
  staticpro (&Qminibuffer);

  staticpro (&Vframe_list);

  DEFVAR_LISP ("terminal-frame", &Vterminal_frame,
    "The initial frame-object, which represents Emacs's stdout.");

  DEFVAR_LISP ("emacs-iconified", &Vemacs_iconified,
    "Non-nil if all of emacs is iconified and frame updates are not needed.");
  Vemacs_iconified = Qnil;

  DEFVAR_LISP ("default-minibuffer-frame", &Vdefault_minibuffer_frame,
    "Minibufferless frames use this frame's minibuffer.\n\
\n\
Emacs cannot create minibufferless frames unless this is set to an\n\
appropriate surrogate.\n\
\n\
Emacs consults this variable only when creating minibufferless\n\
frames; once the frame is created, it sticks with its assigned\n\
minibuffer, no matter what this variable is set to.  This means that\n\
this variable doesn't necessarily say anything meaningful about the\n\
current set of frames, or where the minibuffer is currently being\n\
displayed.");
  Vdefault_minibuffer_frame = Qnil;

  DEFVAR_LISP ("default-frame-alist", &Vdefault_frame_alist,
    "Alist of default values for frame creation.\n\
These may be set in your init file, like this:\n\
  (setq default-frame-alist '((width . 80) (height . 55)))\n\
These override values given in window system configuration data, like\n\
X Windows' defaults database.\n\
For values specific to the first Emacs frame, see `initial-frame-alist'.\n\
For values specific to the separate minibuffer frame, see\n\
`minibuffer-frame-alist'.");
  Vdefault_frame_alist = Qnil;

  defsubr (&Sframep);
  defsubr (&Slive_frame_p);
  defsubr (&Sselect_frame);
  defsubr (&Sselected_frame);
  defsubr (&Swindow_frame);
  defsubr (&Sframe_root_window);
  defsubr (&Sframe_selected_window);
  defsubr (&Sframe_list);
  defsubr (&Snext_frame);
  defsubr (&Sdelete_frame);
  defsubr (&Smouse_position);
  defsubr (&Sset_mouse_position);
#if 0
  defsubr (&Sframe_configuration);
  defsubr (&Srestore_frame_configuration);
#endif
  defsubr (&Smake_frame_visible);
  defsubr (&Smake_frame_invisible);
  defsubr (&Siconify_frame);
  defsubr (&Sframe_visible_p);
  defsubr (&Svisible_frame_list);
  defsubr (&Sredirect_frame_focus);
  defsubr (&Sframe_focus);
  defsubr (&Sframe_parameters);
  defsubr (&Smodify_frame_parameters);
#if 0
  defsubr (&Sframe_pixel_size);
  defsubr (&Sframe_height);
  defsubr (&Sframe_width);
#endif
  defsubr (&Sset_frame_height);
  defsubr (&Sset_frame_width);
  defsubr (&Sset_frame_size);
  defsubr (&Sset_frame_position);
#ifndef HAVE_X11
  defsubr (&Srubber_band_rectangle);
#endif	/* HAVE_X11 */
}

#endif
