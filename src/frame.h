/* Define frame-object for GNU Emacs.
   Copyright (C) 1988, 1992 Free Software Foundation, Inc.

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


/* The structure representing a frame.

   We declare this even if MULTI_FRAME is not defined, because when
   we lack multi-frame support, we use one instance of this structure
   to represent the one frame we support.  This is cleaner than
   having miscellaneous random variables scattered about.  */

enum output_method
{ output_termcap, output_x_window };

struct frame
{
  int size;
  struct Lisp_Vector *next;

  /* glyphs as they appear on the frame */
  struct frame_glyphs *current_glyphs;

  /* glyphs we'd like to appear on the frame */
  struct frame_glyphs *desired_glyphs;

  /* See do_line_insertion_deletion_costs for info on these arrays. */
  /* Cost of inserting 1 line on this frame */
  int *insert_line_cost;
  /* Cost of deleting 1 line on this frame */
  int *delete_line_cost;
  /* Cost of inserting n lines on this frame */
  int *insert_n_lines_cost;
  /* Cost of deleting n lines on this frame */
  int *delete_n_lines_cost;

  /* glyphs for the mode line */
  struct frame_glyphs *temp_glyphs;

  /* Intended cursor position of this frame.
     Measured in characters, counting from upper left corner
     within the frame.  */
  int cursor_x;
  int cursor_y;

  /* Actual cursor position of this frame, and the character under it.
     (Not used for terminal frames.)  */
  int phys_cursor_x;
  int phys_cursor_y;
  /* This is handy for undrawing the cursor, because current_glyphs is
     not always accurate when in do_scrolling.  */
  GLYPH phys_cursor_glyph;

  /* Size of this frame, in units of characters.  */
  int height;
  int width;

  /* New height and width for pending size change.  0 if no change pending.  */
  int new_height, new_width;

  /* Name of this frame: a Lisp string.  */
  Lisp_Object name;

  /* The frame which should recieve keystrokes that occur in this
     frame.  This is usually the frame itself, but if the frame is
     minibufferless, this points to the minibuffer frame when it is
     active.  */
  Lisp_Object focus_frame;

  /* This frame's root window.  Every frame has one.
     If the frame has only a minibuffer window, this is it.
     Otherwise, if the frame has a minibuffer window, this is its sibling.  */
  Lisp_Object root_window;

  /* This frame's selected window.
     Each frame has its own window hierarchy
     and one of the windows in it is selected within the frame.
     The selected window of the selected frame is Emacs's selected window.  */
  Lisp_Object selected_window;

  /* This frame's minibuffer window.
     Most frames have their own minibuffer windows,
     but only the selected frame's minibuffer window
     can actually appear to exist.  */
  Lisp_Object minibuffer_window;

  /* Parameter alist of this frame.
     These are the parameters specified when creating the frame
     or modified with modify-frame-parameters.  */
  Lisp_Object param_alist;

  /* The output method says how the contents of this frame
     are displayed.  It could be using termcap, or using an X window.  */
  enum output_method output_method;

  /* A structure of auxiliary data used for displaying the contents.
     struct x_display is used for X window frames;
     it is defined in xterm.h.  */
  union display { struct x_display *x; int nothing; } display;

  /* Nonzero if last attempt at redisplay on this frame was preempted.  */
  char display_preempted;

  /* Nonzero if frame is currently displayed.  */
  char visible;

  /* Nonzero if window is currently iconified.
     This and visible are mutually exclusive.  */
  char iconified;

  /* Nonzero if this frame should be redrawn.  */
  char garbaged;

  /* True if frame actually has a minibuffer window on it.
     0 if using a minibuffer window that isn't on this frame.  */
  char has_minibuffer;
     
  /* 0 means, if this frame has just one window,
     show no modeline for that window.  */
  char wants_modeline;

  /* Non-0 means raise this frame to the top of the heap when selected.  */
  char auto_raise;

  /* Non-0 means lower this frame to the bottom of the stack when left.  */
  char auto_lower;

  /* True if frame's root window can't be split.  */
  char no_split;

  /* Storage for messages to this frame. */
  char *message_buf;

  /* Nonnegative if current redisplay should not do scroll computation
     for lines beyond a certain vpos.  This is the vpos.  */
  int scroll_bottom_vpos;
};

#ifdef MULTI_FRAME

typedef struct frame *FRAME_PTR;

#define XFRAME(p) ((struct frame *) XPNTR (p))
#define XSETFRAME(p, v) ((struct frame *) XSETPNTR (p, v))

#define WINDOW_FRAME(w) (w)->frame

#define FRAMEP(f) (XTYPE(f) == Lisp_Frame)
#define FRAME_LIVE_P(f) ((f)->display.nothing != 0)
#define FRAME_TERMCAP_P(f) ((f)->output_method == output_termcap)
#define FRAME_X_P(f) ((f)->output_method == output_x_window)
#define FRAME_MINIBUF_ONLY_P(f) \
  EQ (FRAME_ROOT_WINDOW (f), FRAME_MINIBUF_WINDOW (f))
#define FRAME_HAS_MINIBUF_P(f) ((f)->has_minibuffer)
#define FRAME_CURRENT_GLYPHS(f) (f)->current_glyphs
#define FRAME_DESIRED_GLYPHS(f) (f)->desired_glyphs
#define FRAME_TEMP_GLYPHS(f) (f)->temp_glyphs
#define FRAME_HEIGHT(f) (f)->height
#define FRAME_WIDTH(f) (f)->width
#define FRAME_NEW_HEIGHT(f) (f)->new_height
#define FRAME_NEW_WIDTH(f) (f)->new_width
#define FRAME_CURSOR_X(f) (f)->cursor_x
#define FRAME_CURSOR_Y(f) (f)->cursor_y
#define FRAME_VISIBLE_P(f) (f)->visible
#define SET_FRAME_GARBAGED(f) (frame_garbaged = 1, f->garbaged = 1)
#define FRAME_GARBAGED_P(f) (f)->garbaged
#define FRAME_NO_SPLIT_P(f) (f)->no_split
#define FRAME_WANTS_MODELINE_P(f) (f)->wants_modeline
#define FRAME_ICONIFIED_P(f) (f)->iconified
#define FRAME_MINIBUF_WINDOW(f) (f)->minibuffer_window
#define FRAME_ROOT_WINDOW(f) (f)->root_window
#define FRAME_SELECTED_WINDOW(f) (f)->selected_window
#define SET_GLYPHS_FRAME(glyphs,frame) ((glyphs)->frame = (frame))
#define FRAME_INSERT_COST(f) (f)->insert_line_cost    
#define FRAME_DELETE_COST(f) (f)->delete_line_cost    
#define FRAME_INSERTN_COST(f) (f)->insert_n_lines_cost
#define FRAME_DELETEN_COST(f) (f)->delete_n_lines_cost
#define FRAME_MESSAGE_BUF(f) (f)->message_buf
#define FRAME_SCROLL_BOTTOM_VPOS(f) (f)->scroll_bottom_vpos
#define FRAME_FOCUS_FRAME(f) (f)->focus_frame

#define CHECK_FRAME(x, i)				\
  {							\
    if (! FRAMEP (x))					\
      x = wrong_type_argument (Qframep, (x));		\
  }

#define CHECK_LIVE_FRAME(x, i)				\
  {							\
    if (! FRAMEP (x)					\
	|| ! FRAME_LIVE_P (XFRAME (x)))		\
      x = wrong_type_argument (Qlive_frame_p, (x));	\
  }

/* FOR_EACH_FRAME (LIST_VAR, FRAME_VAR) followed by a statement is a
   `for' loop which iterates over the elements of Vframe_list.  The
   loop will set FRAME_VAR, a FRAME_PTR, to each frame in
   Vframe_list in succession and execute the statement.  LIST_VAR
   should be a Lisp_Object; it is used to iterate through the
   Vframe_list.  

   If MULTI_FRAME isn't defined, then this loop expands to something which 
   executes the statement once.  */
#define FOR_EACH_FRAME(list_var, frame_var)			\
  for ((list_var) = Vframe_list;				\
       (CONSP (list_var)					\
	&& (frame_var = XFRAME (XCONS (list_var)->car), 1));	\
       list_var = XCONS (list_var)->cdr)


extern Lisp_Object Qframep, Qlive_frame_p;

extern struct frame *selected_frame;
extern struct frame *last_nonminibuf_frame;

extern struct frame *make_terminal_frame ();
extern struct frame *make_frame ();
extern struct frame *make_minibuffer_frame ();
extern struct frame *make_frame_without_minibuffer ();

/* Nonzero means FRAME_MESSAGE_BUF (selected_frame) is being used by
   print.  */
extern int message_buf_print;

extern Lisp_Object Vframe_list;
extern Lisp_Object Vdefault_frame_alist;

extern Lisp_Object Vterminal_frame;

#else /* not MULTI_FRAME */

/* These definitions are used in a single-frame version of Emacs.  */

#define FRAME_PTR int

/* A frame we use to store all the data concerning the screen when we
   don't have multiple frames.  Remember, if you store any data in it
   which needs to be protected from GC, you should staticpro that
   element explicitly.  */
extern struct frame the_only_frame;

extern int selected_frame;
extern int last_nonminibuf_frame;

/* Nonzero means FRAME_MESSAGE_BUF (selected_frame) is being used by
   print.  */
extern int message_buf_print;

#define XFRAME(f) selected_frame
#define WINDOW_FRAME(w) selected_frame

#define FRAMEP(f) (XTYPE(f) == Lisp_Frame)
#define FRAME_LIVE_P(f) 1
#define FRAME_TERMCAP_P(f) 1
#define FRAME_X_P(f) 0
#define FRAME_MINIBUF_ONLY_P(f) 0
#define FRAME_HAS_MINIBUF_P(f) 1
#define FRAME_CURRENT_GLYPHS(f) (the_only_frame.current_glyphs)
#define FRAME_DESIRED_GLYPHS(f) (the_only_frame.desired_glyphs)
#define FRAME_TEMP_GLYPHS(f) (the_only_frame.temp_glyphs)
#define FRAME_HEIGHT(f) (the_only_frame.height)
#define FRAME_WIDTH(f) (the_only_frame.width)
#define FRAME_NEW_HEIGHT(f) (the_only_frame.new_height)
#define FRAME_NEW_WIDTH(f) (the_only_frame.new_width)
#define FRAME_CURSOR_X(f) (the_only_frame.cursor_x)
#define FRAME_CURSOR_Y(f) (the_only_frame.cursor_y)
#define FRAME_VISIBLE_P(f) 1
#define SET_FRAME_GARBAGED(f) (frame_garbaged = 1)
#define FRAME_GARBAGED_P(f) (frame_garbaged)
#define FRAME_NO_SPLIT_P(f) 0
#define FRAME_WANTS_MODELINE_P(f) 1
#define FRAME_ICONIFIED_P(f) 0
#define FRAME_MINIBUF_WINDOW(f) (minibuf_window)
#define FRAME_ROOT_WINDOW(f) (XWINDOW (minibuf_window)->prev)
#define FRAME_SELECTED_WINDOW(f) (selected_window)
#define SET_GLYPHS_FRAME(glyphs,frame) do ; while (0)
#define FRAME_INSERT_COST(frame)  (the_only_frame.insert_line_cost)
#define FRAME_DELETE_COST(frame)  (the_only_frame.delete_line_cost)
#define FRAME_INSERTN_COST(frame) (the_only_frame.insert_n_lines_cost)
#define FRAME_DELETEN_COST(frame) (the_only_frame.delete_n_lines_cost)
#define FRAME_MESSAGE_BUF(f) (the_only_frame.message_buf)
#define FRAME_SCROLL_BOTTOM_VPOS(f) (the_only_frame.scroll_bottom_vpos)
#define FRAME_FOCUS_FRAME(f) (0)

#define CHECK_FRAME(x, i) do; while (0)
#define CHECK_LIVE_FRAME(x, y) do; while (0)

/* FOR_EACH_FRAME (LIST_VAR, FRAME_VAR) followed by a statement is a
   `for' loop which iterates over the elements of Vframe_list.  The
   loop will set FRAME_VAR, a FRAME_PTR, to each frame in
   Vframe_list in succession and execute the statement.  LIST_VAR
   should be a Lisp_Object; it is used to iterate through the
   Vframe_list.  

   If MULTI_FRAME _is_ defined, then this loop expands to a real
   `for' loop which traverses Vframe_list using LIST_VAR and
   FRAME_VAR.  */
#define FOR_EACH_FRAME(list_var, frame_var)			\
  for (frame_var = (FRAME_PTR) 1; frame_var; frame_var = (FRAME_PTR) 0)

#endif /* not MULTI_FRAME */
