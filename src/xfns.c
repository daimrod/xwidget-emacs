/* Functions for the X window system.
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

/* Completely rewritten by Richard Stallman.  */

/* Rewritten for X11 by Joseph Arceneaux */

#if 0
#include <stdio.h>
#endif
#include <signal.h>
#include "config.h"
#include "lisp.h"
#include "xterm.h"
#include "frame.h"
#include "window.h"
#include "buffer.h"
#include "dispextern.h"
#include "xscrollbar.h"
#include "keyboard.h"

#ifdef HAVE_X_WINDOWS
extern void abort ();

void x_set_frame_param ();

#define min(a,b) ((a) < (b) ? (a) : (b))
#define max(a,b) ((a) > (b) ? (a) : (b))

#ifdef HAVE_X11
/* X Resource data base */
static XrmDatabase xrdb;

/* The class of this X application.  */
#define EMACS_CLASS "Emacs"

/* Title name and application name for X stuff. */
extern char *x_id_name;
extern Lisp_Object invocation_name;

/* The background and shape of the mouse pointer, and shape when not
   over text or in the modeline. */
Lisp_Object Vx_pointer_shape, Vx_nontext_pointer_shape, Vx_mode_pointer_shape;

/* Color of chars displayed in cursor box. */
Lisp_Object Vx_cursor_fore_pixel;

/* If non-nil, use vertical bar cursor. */
Lisp_Object Vbar_cursor;

/* The X Visual we are using for X windows (the default) */
Visual *screen_visual;

/* How many screens this X display has. */
int x_screen_count;

/* The vendor supporting this X server. */
Lisp_Object Vx_vendor;

/* The vendor's release number for this X server. */
int x_release;

/* Height of this X screen in pixels. */
int x_screen_height;

/* Height of this X screen in millimeters. */
int x_screen_height_mm;

/* Width of this X screen in pixels. */
int x_screen_width;

/* Width of this X screen in millimeters. */
int x_screen_width_mm;

/* Does this X screen do backing store? */
Lisp_Object Vx_backing_store;

/* Does this X screen do save-unders? */
int x_save_under;

/* Number of planes for this screen. */
int x_screen_planes;

/* X Visual type of this screen. */
Lisp_Object Vx_screen_visual;

/* Non nil if no window manager is in use. */
Lisp_Object Vx_no_window_manager;

static char *x_visual_strings[] =
  {
    "StaticGray",
    "GrayScale",
    "StaticColor",
    "PseudoColor",
    "TrueColor",
    "DirectColor"
  };

/* `t' if a mouse button is depressed. */

Lisp_Object Vmouse_depressed;

extern unsigned int x_mouse_x, x_mouse_y, x_mouse_grabbed;
extern Lisp_Object unread_command_char;

/* Atom for indicating window state to the window manager. */
Atom Xatom_wm_change_state;

/* When emacs became the selection owner. */
extern Time x_begin_selection_own;

/* The value of the current emacs selection. */
extern Lisp_Object Vx_selection_value;

/* Emacs' selection property identifier. */
extern Atom Xatom_emacs_selection;

/* Clipboard selection atom. */
extern Atom Xatom_clipboard_selection;

/* Clipboard atom. */
extern Atom Xatom_clipboard;

/* Atom for indicating incremental selection transfer. */
extern Atom Xatom_incremental;

/* Atom for indicating multiple selection request list */
extern Atom Xatom_multiple;

/* Atom for what targets emacs handles. */
extern Atom Xatom_targets;

/* Atom for indicating timstamp selection request */
extern Atom Xatom_timestamp;

/* Atom requesting we delete our selection. */
extern Atom Xatom_delete;

/* Selection magic. */
extern Atom Xatom_insert_selection;

/* Type of property for INSERT_SELECTION. */
extern Atom Xatom_pair;

/* More selection magic. */
extern Atom Xatom_insert_property;

/* Atom for indicating property type TEXT */
extern Atom Xatom_text;

/* Communication with window managers. */
extern Atom Xatom_wm_protocols;

/* Kinds of protocol things we may receive. */
extern Atom Xatom_wm_take_focus;
extern Atom Xatom_wm_save_yourself;
extern Atom Xatom_wm_delete_window;

/* Other WM communication */
extern Atom Xatom_wm_configure_denied; /* When our config request is denied */
extern Atom Xatom_wm_window_moved;     /* When the WM moves us. */

#else	/* X10 */

/* Default size of an Emacs window without scroll bar.  */
static char *default_window = "=80x24+0+0";

#define MAXICID 80
char iconidentity[MAXICID];
#define ICONTAG "emacs@"
char minibuffer_iconidentity[MAXICID];
#define MINIBUFFER_ICONTAG "minibuffer@"

#endif /* X10 */

/* The last 23 bits of the timestamp of the last mouse button event. */
Time mouse_timestamp;

Lisp_Object Qundefined_color;
Lisp_Object Qx_frame_parameter;

extern Lisp_Object Vwindow_system_version;

/* Mouse map for clicks in windows.  */
extern Lisp_Object Vglobal_mouse_map;

/* Points to table of defined typefaces.  */
struct face *x_face_table[MAX_FACES_AND_GLYPHS];

/* Return the Emacs frame-object corresponding to an X window.
   It could be the frame's main window or an icon window.  */

struct frame *
x_window_to_frame (wdesc)
     int wdesc;
{
  Lisp_Object tail, frame;
  struct frame *f;

  for (tail = Vframe_list; CONSP (tail); tail = XCONS (tail)->cdr)
    {
      frame = XCONS (tail)->car;
      if (XTYPE (frame) != Lisp_Frame)
        continue;
      f = XFRAME (frame);
      if (f->display.x->window_desc == wdesc
          || f->display.x->icon_desc == wdesc)
        return f;
    }
  return 0;
}

/* Map an X window that implements a scroll bar to the Emacs frame it
   belongs to.  Also store in *PART a symbol identifying which part of
   the scroll bar it is.  */

struct frame *
x_window_to_scrollbar (wdesc, part_ptr, prefix_ptr)
     int wdesc;
     Lisp_Object *part_ptr;
     enum scroll_bar_prefix *prefix_ptr;
{
  Lisp_Object tail, frame;
  struct frame *f;

  for (tail = Vframe_list; CONSP (tail); tail = XCONS (tail)->cdr)
    {
      frame = XCONS (tail)->car;
      if (XTYPE (frame) != Lisp_Frame)
        continue;

      f = XFRAME (frame);
      if (part_ptr == 0 && prefix_ptr == 0)
        return f;

      if (f->display.x->v_scrollbar == wdesc)
        {
	  *part_ptr = Qvscrollbar_part;
          *prefix_ptr = VSCROLL_BAR_PREFIX;
          return f;
        }
      else if (f->display.x->v_slider == wdesc)
        {
          *part_ptr = Qvslider_part;
          *prefix_ptr = VSCROLL_SLIDER_PREFIX;
          return f;
        }
      else if (f->display.x->v_thumbup == wdesc)
        {
          *part_ptr = Qvthumbup_part;
          *prefix_ptr = VSCROLL_THUMBUP_PREFIX;
          return f;
        }
      else if (f->display.x->v_thumbdown == wdesc)
        {
          *part_ptr = Qvthumbdown_part;
          *prefix_ptr = VSCROLL_THUMBDOWN_PREFIX;
          return f;
        }
      else if (f->display.x->h_scrollbar == wdesc)
        {
          *part_ptr = Qhscrollbar_part;
          *prefix_ptr = HSCROLL_BAR_PREFIX;
          return f;
        }
      else if (f->display.x->h_slider == wdesc)
        {
          *part_ptr = Qhslider_part;
          *prefix_ptr = HSCROLL_SLIDER_PREFIX;
          return f;
        }
      else if (f->display.x->h_thumbleft == wdesc)
        {
          *part_ptr = Qhthumbleft_part;
          *prefix_ptr = HSCROLL_THUMBLEFT_PREFIX;
          return f;
        }
      else if (f->display.x->h_thumbright == wdesc)
        {
          *part_ptr = Qhthumbright_part;
          *prefix_ptr = HSCROLL_THUMBRIGHT_PREFIX;
          return f;
        }
    }
  return 0;
}

/* Connect the frame-parameter names for X frames
   to the ways of passing the parameter values to the window system.

   The name of a parameter, as a Lisp symbol,
   has an `x-frame-parameter' property which is an integer in Lisp
   but can be interpreted as an `enum x_frame_parm' in C.  */

enum x_frame_parm
{
  X_PARM_FOREGROUND_COLOR,
  X_PARM_BACKGROUND_COLOR,
  X_PARM_MOUSE_COLOR,
  X_PARM_CURSOR_COLOR,
  X_PARM_BORDER_COLOR,
  X_PARM_ICON_TYPE,
  X_PARM_FONT,
  X_PARM_BORDER_WIDTH,
  X_PARM_INTERNAL_BORDER_WIDTH,
  X_PARM_NAME,
  X_PARM_AUTORAISE,
  X_PARM_AUTOLOWER,
  X_PARM_VERT_SCROLLBAR,
  X_PARM_HORIZ_SCROLLBAR,
};


struct x_frame_parm_table
{
  char *name;
  void (*setter)( /* struct frame *frame, Lisp_Object val, oldval */ );
};

void x_set_foreground_color ();
void x_set_background_color ();
void x_set_mouse_color ();
void x_set_cursor_color ();
void x_set_border_color ();
void x_set_icon_type ();
void x_set_font ();
void x_set_border_width ();
void x_set_internal_border_width ();
void x_set_name ();
void x_set_autoraise ();
void x_set_autolower ();
void x_set_vertical_scrollbar ();
void x_set_horizontal_scrollbar ();

static struct x_frame_parm_table x_frame_parms[] =
{
  "foreground-color", x_set_foreground_color,
  "background-color", x_set_background_color,
  "mouse-color", x_set_mouse_color,
  "cursor-color", x_set_cursor_color,
  "border-color", x_set_border_color,
  "icon-type", x_set_icon_type,
  "font", x_set_font,
  "border-width", x_set_border_width,
  "internal-border-width", x_set_internal_border_width,
  "name", x_set_name,
  "autoraise", x_set_autoraise,
  "autolower", x_set_autolower,
  "vertical-scrollbar", x_set_vertical_scrollbar,
  "horizontal-scrollbar", x_set_horizontal_scrollbar,
};

/* Attach the `x-frame-parameter' properties to
   the Lisp symbol names of parameters relevant to X.  */

init_x_parm_symbols ()
{
  int i;

  Qx_frame_parameter = intern ("x-frame-parameter");

  for (i = 0; i < sizeof (x_frame_parms)/sizeof (x_frame_parms[0]); i++)
    Fput (intern (x_frame_parms[i].name), Qx_frame_parameter,
	  make_number (i));
}

/* Report to X that a frame parameter of frame F is being set or changed.
   PARAM is the symbol that says which parameter.
   VAL is the new value.
   OLDVAL is the old value.
   If the parameter is not specially recognized, do nothing;
   otherwise the `x_set_...' function for this parameter.  */

void
x_set_frame_param (f, param, val, oldval)
     register struct frame *f;
     Lisp_Object param;
     register Lisp_Object val;
     register Lisp_Object oldval;
{
  register Lisp_Object tem;
  tem = Fget (param, Qx_frame_parameter);
  if (XTYPE (tem) == Lisp_Int
      && XINT (tem) >= 0
      && XINT (tem) < sizeof (x_frame_parms)/sizeof (x_frame_parms[0]))
    (*x_frame_parms[XINT (tem)].setter)(f, val, oldval);
}

/* Insert a description of internally-recorded parameters of frame X
   into the parameter alist *ALISTPTR that is to be given to the user.
   Only parameters that are specific to the X window system
   and whose values are not correctly recorded in the frame's
   param_alist need to be considered here.  */

x_report_frame_params (f, alistptr)
     struct frame *f;
     Lisp_Object *alistptr;
{
  char buf[16];

  store_in_alist (alistptr, "left", make_number (f->display.x->left_pos));
  store_in_alist (alistptr, "top", make_number (f->display.x->top_pos));
  store_in_alist (alistptr, "border-width",
       	   make_number (f->display.x->border_width));
  store_in_alist (alistptr, "internal-border-width",
       	   make_number (f->display.x->internal_border_width));
  sprintf (buf, "%d", f->display.x->window_desc);
  store_in_alist (alistptr, "window-id",
       	   build_string (buf));
}

/* Decide if color named COLOR is valid for the display
   associated with the selected frame. */
int
defined_color (color, color_def)
     char *color;
     Color *color_def;
{
  register int foo;
  Colormap screen_colormap;

  BLOCK_INPUT;
#ifdef HAVE_X11
  screen_colormap
    = DefaultColormap (x_current_display, XDefaultScreen (x_current_display));

  foo = XParseColor (x_current_display, screen_colormap,
       	      color, color_def)
    && XAllocColor (x_current_display, screen_colormap, color_def);
#else
  foo = XParseColor (color, color_def) && XGetHardwareColor (color_def);
#endif /* not HAVE_X11 */
  UNBLOCK_INPUT;

  if (foo)
    return 1;
  else
    return 0;
}

/* Given a string ARG naming a color, compute a pixel value from it
   suitable for screen F.
   If F is not a color screen, return DEF (default) regardless of what
   ARG says.  */

int
x_decode_color (arg, def)
     Lisp_Object arg;
     int def;
{
  Color cdef;

  CHECK_STRING (arg, 0);

  if (strcmp (XSTRING (arg)->data, "black") == 0)
    return BLACK_PIX_DEFAULT;
  else if (strcmp (XSTRING (arg)->data, "white") == 0)
    return WHITE_PIX_DEFAULT;

#ifdef HAVE_X11
  if (XFASTINT (x_screen_planes) == 1)
    return def;
#else
  if (DISPLAY_CELLS == 1)
    return def;
#endif

  if (defined_color (XSTRING (arg)->data, &cdef))
    return cdef.pixel;
  else
    Fsignal (Qundefined_color, Fcons (arg, Qnil));
}

/* Functions called only from `x_set_frame_param'
   to set individual parameters.

   If f->display.x->window_desc is 0,
   the frame is being created and its X-window does not exist yet.
   In that case, just record the parameter's new value
   in the standard place; do not attempt to change the window.  */

void
x_set_foreground_color (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  f->display.x->foreground_pixel = x_decode_color (arg, BLACK_PIX_DEFAULT);
  if (f->display.x->window_desc != 0)
    {
#ifdef HAVE_X11
      BLOCK_INPUT;
      XSetForeground (x_current_display, f->display.x->normal_gc,
		      f->display.x->foreground_pixel);
      XSetBackground (x_current_display, f->display.x->reverse_gc,
		      f->display.x->foreground_pixel);
      if (f->display.x->v_scrollbar)
        {
          Pixmap  up_arrow_pixmap, down_arrow_pixmap, slider_pixmap;

          XSetWindowBorder (x_current_display, f->display.x->v_scrollbar,
			    f->display.x->foreground_pixel);

          slider_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 gray_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));
          up_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 up_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));
          down_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 down_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));

          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->v_thumbup,
				      up_arrow_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->v_thumbdown,
				      down_arrow_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->v_slider,
				      slider_pixmap);

          XClearWindow (XDISPLAY f->display.x->v_thumbup);
          XClearWindow (XDISPLAY f->display.x->v_thumbdown);
          XClearWindow (XDISPLAY f->display.x->v_slider);

          XFreePixmap (x_current_display, down_arrow_pixmap);
          XFreePixmap (x_current_display, up_arrow_pixmap);
          XFreePixmap (x_current_display, slider_pixmap);
        }
      if (f->display.x->h_scrollbar)
        {
          Pixmap left_arrow_pixmap, right_arrow_pixmap, slider_pixmap;

          XSetWindowBorder (x_current_display, f->display.x->h_scrollbar,
			    f->display.x->foreground_pixel);

          slider_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 gray_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));

          left_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 up_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));
          right_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 down_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));

          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->h_slider,
				      slider_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->h_thumbleft,
				      left_arrow_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->h_thumbright,
				      right_arrow_pixmap);

          XClearWindow (XDISPLAY f->display.x->h_thumbleft);
          XClearWindow (XDISPLAY f->display.x->h_thumbright);
          XClearWindow (XDISPLAY f->display.x->h_slider);

          XFreePixmap (x_current_display, slider_pixmap);
          XFreePixmap (x_current_display, left_arrow_pixmap);
          XFreePixmap (x_current_display, right_arrow_pixmap);
        }
      UNBLOCK_INPUT;
#endif				/* HAVE_X11 */
      if (f->visible)
        redraw_frame (f);
    }
}

void
x_set_background_color (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  Pixmap temp;
  int mask;

  f->display.x->background_pixel = x_decode_color (arg, WHITE_PIX_DEFAULT);

  if (f->display.x->window_desc != 0)
    {
      BLOCK_INPUT;
#ifdef HAVE_X11
      /* The main frame area. */
      XSetBackground (x_current_display, f->display.x->normal_gc,
		      f->display.x->background_pixel);
      XSetForeground (x_current_display, f->display.x->reverse_gc,
		      f->display.x->background_pixel);
      XSetWindowBackground (x_current_display, f->display.x->window_desc,
			    f->display.x->background_pixel);

      /* Scroll bars. */
      if (f->display.x->v_scrollbar)
        {
          Pixmap  up_arrow_pixmap, down_arrow_pixmap, slider_pixmap;

          XSetWindowBackground (x_current_display, f->display.x->v_scrollbar,
				f->display.x->background_pixel);

          slider_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 gray_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));
          up_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 up_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));
          down_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 down_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));

          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->v_thumbup,
				      up_arrow_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->v_thumbdown,
				      down_arrow_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->v_slider,
				      slider_pixmap);

          XClearWindow (XDISPLAY f->display.x->v_thumbup);
          XClearWindow (XDISPLAY f->display.x->v_thumbdown);
          XClearWindow (XDISPLAY f->display.x->v_slider);

          XFreePixmap (x_current_display, down_arrow_pixmap);
          XFreePixmap (x_current_display, up_arrow_pixmap);
          XFreePixmap (x_current_display, slider_pixmap);
        }
      if (f->display.x->h_scrollbar)
        {
          Pixmap left_arrow_pixmap, right_arrow_pixmap, slider_pixmap;

          XSetWindowBackground (x_current_display, f->display.x->h_scrollbar,
				f->display.x->background_pixel);

          slider_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 gray_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));

          left_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 up_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));
          right_arrow_pixmap =
            XCreatePixmapFromBitmapData (XDISPLAY f->display.x->window_desc,
					 down_arrow_bits, 16, 16,
					 f->display.x->foreground_pixel,
					 f->display.x->background_pixel,
					 DefaultDepth (x_current_display,
						       XDefaultScreen (x_current_display)));

          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->h_slider,
				      slider_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->h_thumbleft,
				      left_arrow_pixmap);
          XSetWindowBackgroundPixmap (XDISPLAY f->display.x->h_thumbright,
				      right_arrow_pixmap);

          XClearWindow (XDISPLAY f->display.x->h_thumbleft);
          XClearWindow (XDISPLAY f->display.x->h_thumbright);
          XClearWindow (XDISPLAY f->display.x->h_slider);

          XFreePixmap (x_current_display, slider_pixmap);
          XFreePixmap (x_current_display, left_arrow_pixmap);
          XFreePixmap (x_current_display, right_arrow_pixmap);
        }
#else
      temp = XMakeTile (f->display.x->background_pixel);
      XChangeBackground (f->display.x->window_desc, temp);
      XFreePixmap (temp);
#endif				/* not HAVE_X11 */
      UNBLOCK_INPUT;

      if (f->visible)
        redraw_frame (f);
    }
}

void
x_set_mouse_color (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  Cursor cursor, nontext_cursor, mode_cursor;
  int mask_color;

  if (!EQ (Qnil, arg))
    f->display.x->mouse_pixel = x_decode_color (arg, BLACK_PIX_DEFAULT);
  mask_color = f->display.x->background_pixel;
				/* No invisible pointers. */
  if (mask_color == f->display.x->mouse_pixel
	&& mask_color == f->display.x->background_pixel)
    f->display.x->mouse_pixel = f->display.x->foreground_pixel;

  BLOCK_INPUT;
#ifdef HAVE_X11
  if (!EQ (Qnil, Vx_pointer_shape))
    {
      CHECK_NUMBER (Vx_pointer_shape, 0);
      cursor = XCreateFontCursor (x_current_display, XINT (Vx_pointer_shape));
    }
  else
    cursor = XCreateFontCursor (x_current_display, XC_xterm);

  if (!EQ (Qnil, Vx_nontext_pointer_shape))
    {
      CHECK_NUMBER (Vx_nontext_pointer_shape, 0);
      nontext_cursor = XCreateFontCursor (x_current_display,
					  XINT (Vx_nontext_pointer_shape));
    }
  else
    nontext_cursor = XCreateFontCursor (x_current_display, XC_left_ptr);

  if (!EQ (Qnil, Vx_mode_pointer_shape))
    {
      CHECK_NUMBER (Vx_mode_pointer_shape, 0);
      mode_cursor = XCreateFontCursor (x_current_display,
					  XINT (Vx_mode_pointer_shape));
    }
  else
    mode_cursor = XCreateFontCursor (x_current_display, XC_xterm);

  {
    XColor fore_color, back_color;

    fore_color.pixel = f->display.x->mouse_pixel;
    back_color.pixel = mask_color;
    XQueryColor (x_current_display,
		 DefaultColormap (x_current_display,
				  DefaultScreen (x_current_display)),
		 &fore_color);
    XQueryColor (x_current_display,
		 DefaultColormap (x_current_display,
				  DefaultScreen (x_current_display)),
		 &back_color);
    XRecolorCursor (x_current_display, cursor,
		    &fore_color, &back_color);
    XRecolorCursor (x_current_display, nontext_cursor,
		    &fore_color, &back_color);
    XRecolorCursor (x_current_display, mode_cursor,
		    &fore_color, &back_color);
  }
#else /* X10 */
  cursor = XCreateCursor (16, 16, MouseCursor, MouseMask,
			  0, 0,
			  f->display.x->mouse_pixel,
			  f->display.x->background_pixel,
			  GXcopy);
#endif /* X10 */

  if (f->display.x->window_desc != 0)
    {
      XDefineCursor (XDISPLAY f->display.x->window_desc, cursor);
    }

  if (cursor != f->display.x->text_cursor && f->display.x->text_cursor != 0)
      XFreeCursor (XDISPLAY f->display.x->text_cursor);
  f->display.x->text_cursor = cursor;
#ifdef HAVE_X11
  if (nontext_cursor != f->display.x->nontext_cursor
      && f->display.x->nontext_cursor != 0)
      XFreeCursor (XDISPLAY f->display.x->nontext_cursor);
  f->display.x->nontext_cursor = nontext_cursor;

  if (mode_cursor != f->display.x->modeline_cursor
      && f->display.x->modeline_cursor != 0)
      XFreeCursor (XDISPLAY f->display.x->modeline_cursor);
  f->display.x->modeline_cursor = mode_cursor;
#endif	/* HAVE_X11 */

  XFlushQueue ();
  UNBLOCK_INPUT;
}

void
x_set_cursor_color (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  unsigned long fore_pixel;

  if (!EQ (Vx_cursor_fore_pixel, Qnil))
    fore_pixel = x_decode_color (Vx_cursor_fore_pixel, WHITE_PIX_DEFAULT);
  else
    fore_pixel = f->display.x->background_pixel;
  f->display.x->cursor_pixel = x_decode_color (arg, BLACK_PIX_DEFAULT);
				/* No invisible cursors */
  if (f->display.x->cursor_pixel == f->display.x->background_pixel)
    {
      f->display.x->cursor_pixel == f->display.x->mouse_pixel;
      if (f->display.x->cursor_pixel == fore_pixel)
	fore_pixel = f->display.x->background_pixel;
    }

  if (f->display.x->window_desc != 0)
    {
#ifdef HAVE_X11
      BLOCK_INPUT;
      XSetBackground (x_current_display, f->display.x->cursor_gc,
		      f->display.x->cursor_pixel);
      XSetForeground (x_current_display, f->display.x->cursor_gc,
		      fore_pixel);
      UNBLOCK_INPUT;
#endif /* HAVE_X11 */

      if (f->visible)
	{
	  x_display_cursor (f, 0);
	  x_display_cursor (f, 1);
	}
    }
}

/* Set the border-color of frame F to value described by ARG.
   ARG can be a string naming a color.
   The border-color is used for the border that is drawn by the X server.
   Note that this does not fully take effect if done before
   F has an x-window; it must be redone when the window is created.

   Note: this is done in two routines because of the way X10 works.

   Note: under X11, this is normally the province of the window manager,
   and so emacs' border colors may be overridden. */

void
x_set_border_color (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  unsigned char *str;
  int pix;

  CHECK_STRING (arg, 0);
  str = XSTRING (arg)->data;

#ifndef HAVE_X11
  if (!strcmp (str, "grey") || !strcmp (str, "Grey")
      || !strcmp (str, "gray") || !strcmp (str, "Gray"))
    pix = -1;
  else
#endif /* X10 */

    pix = x_decode_color (arg, BLACK_PIX_DEFAULT);

  x_set_border_pixel (f, pix);
}

/* Set the border-color of frame F to pixel value PIX.
   Note that this does not fully take effect if done before
   F has an x-window.  */

x_set_border_pixel (f, pix)
     struct frame *f;
     int pix;
{
  f->display.x->border_pixel = pix;

  if (f->display.x->window_desc != 0 && f->display.x->border_width > 0)
    {
      Pixmap temp;
      int mask;

      BLOCK_INPUT;
#ifdef HAVE_X11
      XSetWindowBorder (x_current_display, f->display.x->window_desc,
       		 pix);
      if (f->display.x->h_scrollbar)
        XSetWindowBorder (x_current_display, f->display.x->h_slider,
       		   pix);
      if (f->display.x->v_scrollbar)
        XSetWindowBorder (x_current_display, f->display.x->v_slider,
       		   pix);
#else
      if (pix < 0)
        temp = XMakePixmap ((Bitmap) XStoreBitmap (16, 16, gray_bits),
       		     BLACK_PIX_DEFAULT, WHITE_PIX_DEFAULT);
      else
        temp = XMakeTile (pix);
      XChangeBorder (f->display.x->window_desc, temp);
      XFreePixmap (XDISPLAY temp);
#endif /* not HAVE_X11 */
      UNBLOCK_INPUT;

      if (f->visible)
        redraw_frame (f);
    }
}

void
x_set_icon_type (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  Lisp_Object tem;
  int result;

  if (EQ (oldval, Qnil) == EQ (arg, Qnil))
    return;

  BLOCK_INPUT;
  if (NILP (arg))
    result = x_text_icon (f, 0);
  else
    result = x_bitmap_icon (f, 0);

  if (result)
    {
      error ("No icon window available.");
      UNBLOCK_INPUT;
    }

  /* If the window was unmapped (and its icon was mapped),
     the new icon is not mapped, so map the window in its stead.  */
  if (f->visible)
    XMapWindow (XDISPLAY f->display.x->window_desc);

  XFlushQueue ();
  UNBLOCK_INPUT;
}

void
x_set_font (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  unsigned char *name;
  int result;

  CHECK_STRING (arg, 1);
  name = XSTRING (arg)->data;

  BLOCK_INPUT;
  result = x_new_font (f, name);
  UNBLOCK_INPUT;
  
  if (result)
    error ("Font \"%s\" is not defined", name);
}

void
x_set_border_width (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  CHECK_NUMBER (arg, 0);

  if (XINT (arg) == f->display.x->border_width)
    return;

  if (f->display.x->window_desc != 0)
    error ("Cannot change the border width of a window");

  f->display.x->border_width = XINT (arg);
}

void
x_set_internal_border_width (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  int mask;
  int old = f->display.x->internal_border_width;

  CHECK_NUMBER (arg, 0);
  f->display.x->internal_border_width = XINT (arg);
  if (f->display.x->internal_border_width < 0)
    f->display.x->internal_border_width = 0;

  if (f->display.x->internal_border_width == old)
    return;

  if (f->display.x->window_desc != 0)
    {
      BLOCK_INPUT;
      x_set_window_size (f, f->width, f->height);
#if 0
      x_set_resize_hint (f);
#endif
      XFlushQueue ();
      UNBLOCK_INPUT;
      SET_FRAME_GARBAGED (f);
    }
}

void
x_set_name (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  CHECK_STRING (arg, 0);

  /* Don't change the name if it's already ARG.  */
  if (! NILP (Fstring_equal (arg, f->name)))
    return;

  if (f->display.x->window_desc)
    {
#ifdef HAVE_X11
      XTextProperty prop;
      prop.value = XSTRING (arg)->data;
      prop.encoding = XA_STRING;
      prop.format = 8;
      prop.nitems = XSTRING (arg)->size;
      BLOCK_INPUT;
      XSetWMName (XDISPLAY f->display.x->window_desc, &prop);
      XSetWMIconName (XDISPLAY f->display.x->window_desc, &prop);
      UNBLOCK_INPUT;
#else
      BLOCK_INPUT;
      XStoreName (XDISPLAY f->display.x->window_desc,
		  (char *) XSTRING (arg)->data);
      XSetIconName (XDISPLAY f->display.x->window_desc,
		    (char *) XSTRING (arg)->data);
      UNBLOCK_INPUT;
#endif
    }

  f->name = arg;
}

void
x_set_autoraise (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  f->auto_raise = !EQ (Qnil, arg);
}

void
x_set_autolower (f, arg, oldval)
     struct frame *f;
     Lisp_Object arg, oldval;
{
  f->auto_lower = !EQ (Qnil, arg);
}

#ifdef HAVE_X11
int n_faces;

x_set_face (scr, font, background, foreground, stipple)
     struct frame *scr;
     XFontStruct *font;
     unsigned long background, foreground;
     Pixmap stipple;
{
  XGCValues gc_values;
  GC temp_gc;
  unsigned long gc_mask;
  struct face *new_face;
  unsigned int width = 16;
  unsigned int height = 16;

  if (n_faces == MAX_FACES_AND_GLYPHS)
    return 1;

  /* Create the Graphics Context. */
  gc_values.font = font->fid;
  gc_values.foreground = foreground;
  gc_values.background = background;
  gc_values.line_width = 0;
  gc_mask = GCLineWidth | GCFont | GCForeground | GCBackground;
  if (stipple)
    {
      gc_values.stipple
	= XCreateBitmapFromData (x_current_display, ROOT_WINDOW,
				 (char *) stipple, width, height);
      gc_mask |= GCStipple;
    }

  temp_gc = XCreateGC (x_current_display, scr->display.x->window_desc,
		       gc_mask, &gc_values);
  if (!temp_gc)
    return 1;
  new_face = (struct face *) xmalloc (sizeof (struct face));
  if (!new_face)
    {
      XFreeGC (x_current_display, temp_gc);
      return 1;
    }

  new_face->font = font;
  new_face->foreground = foreground;
  new_face->background = background;
  new_face->face_gc = temp_gc;
  if (stipple)
    new_face->stipple = gc_values.stipple;

  x_face_table[++n_faces] = new_face;
  return 1;
}

x_set_glyph (scr, glyph)
{
}

#if 0
DEFUN ("x-set-face-font", Fx_set_face_font, Sx_set_face_font, 4, 2, 0,
  "Specify face table entry FACE-CODE to be the font named by FONT,\n\
   in colors FOREGROUND and BACKGROUND.")
  (face_code, font_name, foreground, background)
     Lisp_Object face_code;
     Lisp_Object font_name;
     Lisp_Object foreground;
     Lisp_Object background;
{
  register struct face *fp;	/* Current face info. */
  register int fn;		/* Face number. */
  register FONT_TYPE *f;	/* Font data structure. */
  unsigned char *newname;
  int fg, bg;
  GC temp_gc;
  XGCValues gc_values;

  /* Need to do something about this. */
  Drawable drawable = selected_frame->display.x->window_desc;

  CHECK_NUMBER (face_code, 1);
  CHECK_STRING (font_name,  2);

  if (EQ (foreground, Qnil) || EQ (background, Qnil))
    {
      fg = selected_frame->display.x->foreground_pixel;
      bg = selected_frame->display.x->background_pixel;
    }
  else
    {
      CHECK_NUMBER (foreground, 0);
      CHECK_NUMBER (background, 1);

      fg = x_decode_color (XINT (foreground), BLACK_PIX_DEFAULT);
      bg = x_decode_color (XINT (background), WHITE_PIX_DEFAULT);
    }

  fn = XINT (face_code);
  if ((fn < 1) || (fn > 255))
    error ("Invalid face code, %d", fn);

  newname = XSTRING (font_name)->data;
  BLOCK_INPUT;
  f = (*newname == 0 ? 0 : XGetFont (newname));
  UNBLOCK_INPUT;
  if (f == 0)
    error ("Font \"%s\" is not defined", newname);

  fp = x_face_table[fn];
  if (fp == 0)
    {
      x_face_table[fn] = fp = (struct face *) xmalloc (sizeof (struct face));
      bzero (fp, sizeof (struct face));
      fp->face_type = x_pixmap;
    }
  else if (FACE_IS_FONT (fn))
    {
      BLOCK_INPUT;
      XFreeGC (FACE_FONT (fn));
      UNBLOCK_INPUT;
    }
  else if (FACE_IS_IMAGE (fn)) /* This should not happen... */
    {
      BLOCK_INPUT;
      XFreePixmap (x_current_display, FACE_IMAGE (fn));
      fp->face_type = x_font;
      UNBLOCK_INPUT;
    }
  else
    abort ();

  fp->face_GLYPH.font_desc.font = f;
  gc_values.font = f->fid;
  gc_values.foreground = fg;
  gc_values.background = bg;
  fp->face_GLYPH.font_desc.face_gc = XCreateGC (x_current_display,
					       drawable, GCFont | GCForeground
					       | GCBackground, &gc_values);
  fp->face_GLYPH.font_desc.font_width = FONT_WIDTH (f);
  fp->face_GLYPH.font_desc.font_height = FONT_HEIGHT (f);

  return face_code;
}
#endif
#else	/* X10 */
DEFUN ("x-set-face", Fx_set_face, Sx_set_face, 4, 4, 0,
  "Specify face table entry FACE-CODE to be the font named by FONT,\n\
   in colors FOREGROUND and BACKGROUND.")
  (face_code, font_name, foreground, background)
     Lisp_Object face_code;
     Lisp_Object font_name;
     Lisp_Object foreground;
     Lisp_Object background;
{
  register struct face *fp;	/* Current face info. */
  register int fn;		/* Face number. */
  register FONT_TYPE *f;	/* Font data structure. */
  unsigned char *newname;

  CHECK_NUMBER (face_code, 1);
  CHECK_STRING (font_name,  2);

  fn = XINT (face_code);
  if ((fn < 1) || (fn > 255))
    error ("Invalid face code, %d", fn);

  /* Ask the server to find the specified font.  */
  newname = XSTRING (font_name)->data;
  BLOCK_INPUT;
  f = (*newname == 0 ? 0 : XGetFont (newname));
  UNBLOCK_INPUT;
  if (f == 0)
    error ("Font \"%s\" is not defined", newname);

  /* Get the face structure for face_code in the face table.
     Make sure it exists.  */
  fp = x_face_table[fn];
  if (fp == 0)
    {
      x_face_table[fn] = fp = (struct face *) xmalloc (sizeof (struct face));
      bzero (fp, sizeof (struct face));
    }

  /* If this face code already exists, get rid of the old font.  */
  if (fp->font != 0 && fp->font != f)
    {
      BLOCK_INPUT;
      XLoseFont (fp->font);
      UNBLOCK_INPUT;
    }

  /* Store the specified information in FP.  */
  fp->fg = x_decode_color (foreground, BLACK_PIX_DEFAULT);
  fp->bg = x_decode_color (background, WHITE_PIX_DEFAULT);
  fp->font = f;

  return face_code;
}
#endif	/* X10 */

#if 0
/* This is excluded because there is no painless way
   to get or to remember the name of the font.  */

DEFUN ("x-get-face", Fx_get_face, Sx_get_face, 1, 1, 0,
  "Get data defining face code FACE.  FACE is an integer.\n\
The value is a list (FONT FG-COLOR BG-COLOR).")
  (face)
     Lisp_Object face;
{
  register struct face *fp;	/* Current face info. */
  register int fn;		/* Face number. */

  CHECK_NUMBER (face, 1);
  fn = XINT (face);
  if ((fn < 1) || (fn > 255))
    error ("Invalid face code, %d", fn);

  /* Make sure the face table exists and this face code is defined.  */
  if (x_face_table == 0 || x_face_table[fn] == 0)
    return Qnil;

  fp = x_face_table[fn];

  return Fcons (build_string (fp->name),
       	 Fcons (make_number (fp->fg),
       		Fcons (make_number (fp->bg), Qnil)));
}
#endif /* 0 */

/* Subroutines of creating an X frame.  */

#ifdef HAVE_X11
extern char *x_get_string_resource ();
extern XrmDatabase x_load_resources ();

DEFUN ("x-get-resource", Fx_get_resource, Sx_get_resource, 1, 3, 0,
  "Retrieve the value of ATTRIBUTE from the X defaults database.  This\n\
searches using a key of the form \"INSTANCE.ATTRIBUTE\", with class\n\
\"Emacs\", where INSTANCE is the name under which Emacs was invoked.\n\
\n\
Optional arguments COMPONENT and CLASS specify the component for which\n\
we should look up ATTRIBUTE.  When specified, Emacs searches using a\n\
key of the form INSTANCE.COMPONENT.ATTRIBUTE, with class \"Emacs.CLASS\".")
  (attribute, name, class)
     Lisp_Object attribute, name, class;
{
  register char *value;
  char *name_key;
  char *class_key;

  CHECK_STRING (attribute, 0);
  if (!NILP (name))
    CHECK_STRING (name, 1);
  if (!NILP (class))
    CHECK_STRING (class, 2);
  if (NILP (name) != NILP (class))
    error ("x-get-resource: must specify both NAME and CLASS or neither");

  if (NILP (name))
    {
      name_key = (char *) alloca (XSTRING (invocation_name)->size + 1
				  + XSTRING (attribute)->size + 1);

      sprintf (name_key, "%s.%s",
	       XSTRING (invocation_name)->data,
	       XSTRING (attribute)->data);
      class_key = EMACS_CLASS;
    }
  else
    {
      name_key = (char *) alloca (XSTRING (invocation_name)->size + 1
				  + XSTRING (name)->size + 1
				  + XSTRING (attribute)->size + 1);

      class_key = (char *) alloca (sizeof (EMACS_CLASS)
				   + XSTRING (class)->size + 1);

      sprintf (name_key, "%s.%s.%s",
	       XSTRING (invocation_name)->data,
	       XSTRING (name)->data,
	       XSTRING (attribute)->data);
      sprintf (class_key, "%s.%s",
	       XSTRING (invocation_name)->data,
	       XSTRING (class)->data);
    }

  value = x_get_string_resource (xrdb, name_key, class_key);

  if (value != (char *) 0)
    return build_string (value);
  else
    return Qnil;
}

#else	/* X10 */

DEFUN ("x-get-default", Fx_get_default, Sx_get_default, 1, 1, 0,
       "Get X default ATTRIBUTE from the system, or nil if no default.\n\
Value is a string (when not nil) and ATTRIBUTE is also a string.\n\
The defaults are specified in the file `~/.Xdefaults'.")
  (arg)
     Lisp_Object arg;
{
  register unsigned char *value;

  CHECK_STRING (arg, 1);

  value = (unsigned char *) XGetDefault (XDISPLAY 
					 XSTRING (invocation_name)->data,
					 XSTRING (arg)->data);
  if (value == 0)
    /* Try reversing last two args, in case this is the buggy version of X.  */
    value = (unsigned char *) XGetDefault (XDISPLAY
					   XSTRING (arg)->data,
					   XSTRING (invocation_name)->data);
  if (value != 0)
    return build_string (value);
  else
    return (Qnil);
}

#define Fx_get_resource(attribute, name, class) Fx_get_default(attribute)

#endif	/* X10 */

/* Types we might convert a resource string into.  */
enum resource_types
  {
    number, boolean, string,
  };

/* Return the value of parameter PARAM.

   First search ALIST, then Vdefault_frame_alist, then the X defaults
   database, using ATTRIBUTE as the attribute name.

   Convert the resource to the type specified by desired_type.

   If no default is specified, return nil.  */

static Lisp_Object
x_get_arg (alist, param, attribute, type)
     Lisp_Object alist, param;
     char *attribute;
     enum resource_types type;
{
  register Lisp_Object tem;

  tem = Fassq (param, alist);
  if (EQ (tem, Qnil))
    tem = Fassq (param, Vdefault_frame_alist);
  if (EQ (tem, Qnil) && attribute)
    {
      tem = Fx_get_resource (build_string (attribute), Qnil, Qnil);

      if (NILP (tem))
	return Qnil;

      switch (type)
	{
	case number:
	  return make_number (atoi (XSTRING (tem)->data));

	case boolean:
	  tem = Fdowncase (tem);
	  if (!strcmp (XSTRING (tem)->data, "on")
	      || !strcmp (XSTRING (tem)->data, "true"))
	    return Qt;
	  else 
	    return Qnil;

	case string:
	  return tem;

	default:
	  abort ();
	}
    }
  return Fcdr (tem);
}

/* Record in frame F the specified or default value according to ALIST
   of the parameter named PARAM (a Lisp symbol).
   If no value is specified for PARAM, look for an X default for XPROP
   on the frame named NAME.
   If that is not found either, use the value DEFLT.  */

static Lisp_Object
x_default_parameter (f, alist, propname, deflt, xprop, type)
     struct frame *f;
     Lisp_Object alist;
     char *propname;
     Lisp_Object deflt;
     char *xprop;
     enum resource_types type;
{
  Lisp_Object propsym = intern (propname);
  Lisp_Object tem;

  tem = x_get_arg (alist, propsym, xprop, type);
  if (EQ (tem, Qnil))
    tem = deflt;
  store_frame_param (f, propsym, tem);
  x_set_frame_param (f, propsym, tem, Qnil);
  return tem;
}

DEFUN ("x-geometry", Fx_geometry, Sx_geometry, 1, 1, 0,
       "Parse an X-style geometry string STRING.\n\
Returns an alist of the form ((top . TOP), (left . LEFT) ... ).")
     (string)
{
  int geometry, x, y;
  unsigned int width, height;
  Lisp_Object values[4];

  CHECK_STRING (string, 0);

  geometry = XParseGeometry ((char *) XSTRING (string)->data,
			     &x, &y, &width, &height);

  switch (geometry & 0xf)	/* Mask out {X,Y}Negative */
    {
    case (XValue | YValue):
      /* What's one pixel among friends?
	 Perhaps fix this some day by returning symbol `extreme-top'... */
      if (x == 0 && (geometry & XNegative))
	x = -1;
      if (y == 0 && (geometry & YNegative))
	y = -1;
      values[0] = Fcons (intern ("left"), make_number (x));
      values[1] = Fcons (intern ("top"), make_number (y));
      return Flist (2, values);
      break;

    case (WidthValue | HeightValue):
      values[0] = Fcons (intern ("width"), make_number (width));
      values[1] = Fcons (intern ("height"), make_number (height));
      return Flist (2, values);
      break;

    case (XValue | YValue | WidthValue | HeightValue):
      if (x == 0 && (geometry & XNegative))
	x = -1;
      if (y == 0 && (geometry & YNegative))
	y = -1;
      values[0] = Fcons (intern ("width"), make_number (width));
      values[1] = Fcons (intern ("height"), make_number (height));
      values[2] = Fcons (intern ("left"), make_number (x));
      values[3] = Fcons (intern ("top"), make_number (y));
      return Flist (4, values);
      break;

    case 0:
	return Qnil;
      
    default:
      error ("Must specify x and y value, and/or width and height");
    }
}

#ifdef HAVE_X11
/* Calculate the desired size and position of this window,
   or set rubber-band prompting if none. */

#define DEFAULT_ROWS 40
#define DEFAULT_COLS 80

static
x_figure_window_size (f, parms)
     struct frame *f;
     Lisp_Object parms;
{
  register Lisp_Object tem0, tem1;
  int height, width, left, top;
  register int geometry;
  long window_prompting = 0;

  /* Default values if we fall through.
     Actually, if that happens we should get
     window manager prompting. */
  f->width = DEFAULT_COLS;
  f->height = DEFAULT_ROWS;
  f->display.x->top_pos = 1;
  f->display.x->left_pos = 1;

  tem0 = x_get_arg (parms, intern ("height"), 0, 0);
  tem1 = x_get_arg (parms, intern ("width"), 0, 0);
  if (! EQ (tem0, Qnil) && ! EQ (tem1, Qnil))
    {
      CHECK_NUMBER (tem0, 0);
      CHECK_NUMBER (tem1, 0);
      f->height = XINT (tem0);
      f->width = XINT (tem1);
      window_prompting |= USSize;
    }
  else if (! EQ (tem0, Qnil) || ! EQ (tem1, Qnil))
    error ("Must specify *both* height and width");

  f->display.x->pixel_width = (FONT_WIDTH (f->display.x->font) * f->width
			       + 2 * f->display.x->internal_border_width);
  f->display.x->pixel_height = (FONT_HEIGHT (f->display.x->font) * f->height
				+ 2 * f->display.x->internal_border_width);

  tem0 = x_get_arg (parms, intern ("top"), 0, 0);
  tem1 = x_get_arg (parms, intern ("left"), 0, 0);
  if (! EQ (tem0, Qnil) && ! EQ (tem1, Qnil))
    {
      CHECK_NUMBER (tem0, 0);
      CHECK_NUMBER (tem1, 0);
      f->display.x->top_pos = XINT (tem0);
      f->display.x->left_pos = XINT (tem1);
      x_calc_absolute_position (f);
      window_prompting |= USPosition;
    }
  else if (! EQ (tem0, Qnil) || ! EQ (tem1, Qnil))
    error ("Must specify *both* top and left corners");

  switch (window_prompting)
    {
    case USSize | USPosition:
      return window_prompting;
      break;

    case USSize:		/* Got the size, need the position. */
      window_prompting |= PPosition;
      return window_prompting;
      break;
	  
    case USPosition:		/* Got the position, need the size. */
      window_prompting |= PSize;
      return window_prompting;
      break;
	  
    case 0:			/* Got nothing, take both from geometry. */
      window_prompting |= PPosition | PSize;
      return window_prompting;
      break;
	  
    default:
      /* Somehow a bit got set in window_prompting that we didn't
	 put there.  */
      abort ();
    }
}

static void
x_window (f)
     struct frame *f;
{
  XSetWindowAttributes attributes;
  unsigned long attribute_mask;
  XClassHint class_hints;

  attributes.background_pixel = f->display.x->background_pixel;
  attributes.border_pixel = f->display.x->border_pixel;
  attributes.bit_gravity = StaticGravity;
  attributes.backing_store = NotUseful;
  attributes.save_under = True;
  attributes.event_mask = STANDARD_EVENT_SET;
  attribute_mask = (CWBackPixel | CWBorderPixel | CWBitGravity
#if 0
		    | CWBackingStore | CWSaveUnder
#endif
		    | CWEventMask);

  BLOCK_INPUT;
  f->display.x->window_desc
    = XCreateWindow (x_current_display, ROOT_WINDOW,
		     f->display.x->left_pos,
		     f->display.x->top_pos,
		     PIXEL_WIDTH (f), PIXEL_HEIGHT (f),
		     f->display.x->border_width,
		     CopyFromParent, /* depth */
		     InputOutput, /* class */
		     screen_visual, /* set in Fx_open_connection */
		     attribute_mask, &attributes);

  class_hints.res_name = (char *) XSTRING (f->name)->data;
  class_hints.res_class = EMACS_CLASS;
  XSetClassHint (x_current_display, f->display.x->window_desc, &class_hints);

  XDefineCursor (XDISPLAY f->display.x->window_desc,
		 f->display.x->text_cursor);
  UNBLOCK_INPUT;

  if (f->display.x->window_desc == 0)
    error ("Unable to create window.");
}

/* Handle the icon stuff for this window.  Perhaps later we might
   want an x_set_icon_position which can be called interactively as
   well. */

static void
x_icon (f, parms)
     struct frame *f;
     Lisp_Object parms;
{
  register Lisp_Object tem0,tem1;
  XWMHints hints;

  /* Set the position of the icon.  Note that twm groups all
     icons in an icon window. */
  tem0 = x_get_arg (parms, intern ("icon-left"), 0, 0);
  tem1 = x_get_arg (parms, intern ("icon-top"), 0, 0);
  if (!EQ (tem0, Qnil) && !EQ (tem1, Qnil))
    {
      CHECK_NUMBER (tem0, 0);
      CHECK_NUMBER (tem1, 0);
      hints.icon_x = XINT (tem0);
      hints.icon_x = XINT (tem0);
    }
  else if (!EQ (tem0, Qnil) || !EQ (tem1, Qnil))
    error ("Both left and top icon corners of icon must be specified");
  else
    {
      hints.icon_x = f->display.x->left_pos;
      hints.icon_y = f->display.x->top_pos;
    }

  /* Start up iconic or window? */
  tem0 = x_get_arg (parms, intern ("iconic-startup"), 0, 0);
  if (!EQ (tem0, Qnil))
    hints.initial_state = IconicState;
  else
    hints.initial_state = NormalState; /* the default, actually. */
  hints.input = False;

  BLOCK_INPUT;
  hints.flags = StateHint | IconPositionHint | InputHint;
  XSetWMHints (x_current_display, f->display.x->window_desc, &hints);
  UNBLOCK_INPUT;
}

/* Make the GC's needed for this window, setting the
   background, border and mouse colors; also create the
   mouse cursor and the gray border tile.  */

static void
x_make_gc (f)
     struct frame *f;
{
  XGCValues gc_values;
  GC temp_gc;
  XImage tileimage;
  static char cursor_bits[] =
    {
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };

  /* Create the GC's of this frame.
     Note that many default values are used. */

  /* Normal video */
  gc_values.font = f->display.x->font->fid;
  gc_values.foreground = f->display.x->foreground_pixel;
  gc_values.background = f->display.x->background_pixel;
  gc_values.line_width = 0;	/* Means 1 using fast algorithm. */
  f->display.x->normal_gc = XCreateGC (x_current_display,
				       f->display.x->window_desc,
				       GCLineWidth | GCFont
				       | GCForeground | GCBackground,
				       &gc_values);

  /* Reverse video style. */
  gc_values.foreground = f->display.x->background_pixel;
  gc_values.background = f->display.x->foreground_pixel;
  f->display.x->reverse_gc = XCreateGC (x_current_display,
					f->display.x->window_desc,
					GCFont | GCForeground | GCBackground
					| GCLineWidth,
					&gc_values);

  /* Cursor has cursor-color background, background-color foreground. */
  gc_values.foreground = f->display.x->background_pixel;
  gc_values.background = f->display.x->cursor_pixel;
  gc_values.fill_style = FillOpaqueStippled;
  gc_values.stipple
    = XCreateBitmapFromData (x_current_display, ROOT_WINDOW,
			     cursor_bits, 16, 16);
  f->display.x->cursor_gc
    = XCreateGC (x_current_display, f->display.x->window_desc,
		 (GCFont | GCForeground | GCBackground
		  | GCFillStyle | GCStipple | GCLineWidth),
		 &gc_values);

  /* Create the gray border tile used when the pointer is not in
     the frame.  Since this depends on the frame's pixel values,
     this must be done on a per-frame basis. */
  f->display.x->border_tile =
    XCreatePixmap (x_current_display, ROOT_WINDOW, 16, 16,
		   DefaultDepth (x_current_display,
				 XDefaultScreen (x_current_display)));
  gc_values.foreground = f->display.x->foreground_pixel;
  gc_values.background = f->display.x->background_pixel;
  temp_gc = XCreateGC (x_current_display,
		       (Drawable) f->display.x->border_tile,
		       GCForeground | GCBackground, &gc_values);

  /* These are things that should be determined by the server, in
     Fx_open_connection */
  tileimage.height = 16;
  tileimage.width = 16;
  tileimage.xoffset = 0;
  tileimage.format = XYBitmap;
  tileimage.data = gray_bits;
  tileimage.byte_order = LSBFirst;
  tileimage.bitmap_unit = 8;
  tileimage.bitmap_bit_order = LSBFirst;
  tileimage.bitmap_pad = 8;
  tileimage.bytes_per_line = (16 + 7) >> 3;
  tileimage.depth = 1;
  XPutImage (x_current_display, f->display.x->border_tile, temp_gc,
	     &tileimage, 0, 0, 0, 0, 16, 16);
  XFreeGC (x_current_display, temp_gc);
}
#endif /* HAVE_X11 */

DEFUN ("x-create-frame", Fx_create_frame, Sx_create_frame,
       1, 1, 0,
  "Make a new X window, which is called a \"frame\" in Emacs terms.\n\
Return an Emacs frame object representing the X window.\n\
ALIST is an alist of frame parameters.\n\
If the parameters specify that the frame should not have a minibuffer,\n\
and do not specify a specific minibuffer window to use,\n\
then `default-minibuffer-frame' must be a frame whose minibuffer can\n\
be shared by the new frame.")
  (parms)
     Lisp_Object parms;
{
#ifdef HAVE_X11
  struct frame *f;
  Lisp_Object frame, tem;
  Lisp_Object name;
  int minibuffer_only = 0;
  long window_prompting = 0;
  int width, height;

  if (x_current_display == 0)
    error ("X windows are not in use or not initialized");

  name = x_get_arg (parms, intern ("name"), "Title", string);
  if (NILP (name))
    name = build_string (x_id_name);
  if (XTYPE (name) != Lisp_String)
    error ("x-create-frame: name parameter must be a string");

  tem = x_get_arg (parms, intern ("minibuffer"), 0, 0);
  if (EQ (tem, intern ("none")))
    f = make_frame_without_minibuffer (Qnil);
  else if (EQ (tem, intern ("only")))
    {
      f = make_minibuffer_frame ();
      minibuffer_only = 1;
    }
  else if (EQ (tem, Qnil) || EQ (tem, Qt))
    f = make_frame (1);
  else
    f = make_frame_without_minibuffer (tem);

  /* Set the name; the functions to which we pass f expect the
     name to be set.  */
  XSET (f->name, Lisp_String, name);

  XSET (frame, Lisp_Frame, f);
  f->output_method = output_x_window;
  f->display.x = (struct x_display *) xmalloc (sizeof (struct x_display));
  bzero (f->display.x, sizeof (struct x_display));

  /* Note that the frame has no physical cursor right now.  */
  f->phys_cursor_x = -1;

  /* Extract the window parameters from the supplied values
     that are needed to determine window geometry.  */
  x_default_parameter (f, parms, "font",
		       build_string ("9x15"), "font", string);
  x_default_parameter (f, parms, "background-color",
		      build_string ("white"), "background", string);
  x_default_parameter (f, parms, "border-width",
		      make_number (2), "BorderWidth", number);
  /* This defaults to 2 in order to match XTerms.  */
  x_default_parameter (f, parms, "internal-border-width",
		      make_number (2), "InternalBorderWidth", number);

  /* Also do the stuff which must be set before the window exists. */
  x_default_parameter (f, parms, "foreground-color",
		       build_string ("black"), "foreground", string);
  x_default_parameter (f, parms, "mouse-color",
		      build_string ("black"), "mouse", string);
  x_default_parameter (f, parms, "cursor-color",
		      build_string ("black"), "cursor", string);
  x_default_parameter (f, parms, "border-color",
		      build_string ("black"), "border", string);

  /* Need to do icon type, auto-raise, auto-lower. */

  f->display.x->parent_desc = ROOT_WINDOW;
  window_prompting = x_figure_window_size (f, parms);

  x_window (f);
  x_icon (f, parms);
  x_make_gc (f);

  /* Dimensions, especially f->height, must be done via change_frame_size.
     Change will not be effected unless different from the current
     f->height. */
  width = f->width;
  height = f->height;
  f->height = f->width = 0;
  change_frame_size (f, height, width, 1);
  BLOCK_INPUT;
  x_wm_set_size_hint (f, window_prompting);
  UNBLOCK_INPUT;

  tem = x_get_arg (parms, intern ("unsplittable"), 0, 0);
  f->no_split = minibuffer_only || EQ (tem, Qt);

  /* Now handle the rest of the parameters. */
  x_default_parameter (f, parms, "horizontal-scroll-bar",
		       Qnil, "?HScrollBar", string);
  x_default_parameter (f, parms, "vertical-scroll-bar",
		       Qnil, "?VScrollBar", string);

  /* Make the window appear on the frame and enable display.  */
  if (!EQ (x_get_arg (parms, intern ("suppress-initial-map"), 0, 0), Qt))
    x_make_frame_visible (f);

  return frame;
#else /* X10 */
  struct frame *f;
  Lisp_Object frame, tem;
  Lisp_Object name;
  int pixelwidth, pixelheight;
  Cursor cursor;
  int height, width;
  Window parent;
  Pixmap temp;
  int minibuffer_only = 0;
  Lisp_Object vscroll, hscroll;

  if (x_current_display == 0)
    error ("X windows are not in use or not initialized");

  name = Fassq (intern ("name"), parms);

  tem = x_get_arg (parms, intern ("minibuffer"), 0, 0);
  if (EQ (tem, intern ("none")))
    f = make_frame_without_minibuffer (Qnil);
  else if (EQ (tem, intern ("only")))
    {
      f = make_minibuffer_frame ();
      minibuffer_only = 1;
    }
  else if (! EQ (tem, Qnil))
    f = make_frame_without_minibuffer (tem);
  else
    f = make_frame (1);

  parent = ROOT_WINDOW;

  XSET (frame, Lisp_Frame, f);
  f->output_method = output_x_window;
  f->display.x = (struct x_display *) xmalloc (sizeof (struct x_display));
  bzero (f->display.x, sizeof (struct x_display));

  /* Some temprorary default values for height and width. */
  width = 80;
  height = 40;
  f->display.x->left_pos = -1;
  f->display.x->top_pos = -1;

  /* Give the frame a default name (which may be overridden with PARMS).  */

  strncpy (iconidentity, ICONTAG, MAXICID);
  if (gethostname (&iconidentity[sizeof (ICONTAG) - 1],
		   (MAXICID - 1) - sizeof (ICONTAG)))
    iconidentity[sizeof (ICONTAG) - 2] = '\0';
  f->name = build_string (iconidentity);

  /* Extract some window parameters from the supplied values.
     These are the parameters that affect window geometry.  */

  tem = x_get_arg (parms, intern ("font"), "BodyFont", string);
  if (EQ (tem, Qnil))
    tem = build_string ("9x15");
  x_set_font (f, tem);
  x_default_parameter (f, parms, "border-color",
		      build_string ("black"), "Border", string);
  x_default_parameter (f, parms, "background-color",
		      build_string ("white"), "Background", string);
  x_default_parameter (f, parms, "foreground-color",
		      build_string ("black"), "Foreground", string);
  x_default_parameter (f, parms, "mouse-color",
		      build_string ("black"), "Mouse", string);
  x_default_parameter (f, parms, "cursor-color",
		      build_string ("black"), "Cursor", string);
  x_default_parameter (f, parms, "border-width",
		      make_number (2), "BorderWidth", number);
  x_default_parameter (f, parms, "internal-border-width",
		      make_number (4), "InternalBorderWidth", number);
  x_default_parameter (f, parms, "auto-raise",
		       Qnil, "AutoRaise", boolean);

  hscroll = x_get_arg (parms, intern ("horizontal-scroll-bar"), 0, 0);
  vscroll = x_get_arg (parms, intern ("vertical-scroll-bar"), 0, 0);

  if (f->display.x->internal_border_width < 0)
    f->display.x->internal_border_width = 0;

  tem = x_get_arg (parms, intern ("window-id"), 0, 0);
  if (!EQ (tem, Qnil))
    {
      WINDOWINFO_TYPE wininfo;
      int nchildren;
      Window *children, root;

      CHECK_STRING (tem, 0);
      f->display.x->window_desc = (Window) atoi (XSTRING (tem)->data);

      BLOCK_INPUT;
      XGetWindowInfo (f->display.x->window_desc, &wininfo);
      XQueryTree (f->display.x->window_desc, &parent, &nchildren, &children);
      free (children);
      UNBLOCK_INPUT;

      height = (wininfo.height - 2 * f->display.x->internal_border_width)
	/ FONT_HEIGHT (f->display.x->font);
      width = (wininfo.width - 2 * f->display.x->internal_border_width)
	/ FONT_WIDTH (f->display.x->font);
      f->display.x->left_pos = wininfo.x;
      f->display.x->top_pos = wininfo.y;
      f->visible = wininfo.mapped != 0;
      f->display.x->border_width = wininfo.bdrwidth;
      f->display.x->parent_desc = parent;
    }
  else
    {
      tem = x_get_arg (parms, intern ("parent-id"), 0, 0);
      if (!EQ (tem, Qnil))
	{
	  CHECK_STRING (tem, 0);
	  parent = (Window) atoi (XSTRING (tem)->data);
	}
      f->display.x->parent_desc = parent;
      tem = x_get_arg (parms, intern ("height"), 0, 0);
      if (EQ (tem, Qnil))
	{
	  tem = x_get_arg (parms, intern ("width"), 0, 0);
	  if (EQ (tem, Qnil))
	    {
	      tem = x_get_arg (parms, intern ("top"), 0, 0);
	      if (EQ (tem, Qnil))
		tem = x_get_arg (parms, intern ("left"), 0, 0);
	    }
	}
      /* Now TEM is nil if no edge or size was specified.
	 In that case, we must do rubber-banding.  */
      if (EQ (tem, Qnil))
	{
	  tem = x_get_arg (parms, intern ("geometry"), 0, 0);
	  x_rubber_band (f,
			 &f->display.x->left_pos, &f->display.x->top_pos,
			 &width, &height,
			 (XTYPE (tem) == Lisp_String
			  ? (char *) XSTRING (tem)->data : ""),
			 XSTRING (f->name)->data,
			 !NILP (hscroll), !NILP (vscroll));
	}
      else
	{
	  /* Here if at least one edge or size was specified.
	     Demand that they all were specified, and use them.  */
	  tem = x_get_arg (parms, intern ("height"), 0, 0);
	  if (EQ (tem, Qnil))
	    error ("Height not specified");
	  CHECK_NUMBER (tem, 0);
	  height = XINT (tem);

	  tem = x_get_arg (parms, intern ("width"), 0, 0);
	  if (EQ (tem, Qnil))
	    error ("Width not specified");
	  CHECK_NUMBER (tem, 0);
	  width = XINT (tem);

	  tem = x_get_arg (parms, intern ("top"), 0, 0);
	  if (EQ (tem, Qnil))
	    error ("Top position not specified");
	  CHECK_NUMBER (tem, 0);
	  f->display.x->left_pos = XINT (tem);

	  tem = x_get_arg (parms, intern ("left"), 0, 0);
	  if (EQ (tem, Qnil))
	    error ("Left position not specified");
	  CHECK_NUMBER (tem, 0);
	  f->display.x->top_pos = XINT (tem);
	}

      pixelwidth = (width * FONT_WIDTH (f->display.x->font)
		    + 2 * f->display.x->internal_border_width
		    + (!NILP (vscroll) ? VSCROLL_WIDTH : 0));
      pixelheight = (height * FONT_HEIGHT (f->display.x->font)
		     + 2 * f->display.x->internal_border_width
		     + (!NILP (hscroll) ? HSCROLL_HEIGHT : 0));
      
      BLOCK_INPUT;
      f->display.x->window_desc
	= XCreateWindow (parent,
			 f->display.x->left_pos,   /* Absolute horizontal offset */
			 f->display.x->top_pos,    /* Absolute Vertical offset */
			 pixelwidth, pixelheight,
			 f->display.x->border_width,
			 BLACK_PIX_DEFAULT, WHITE_PIX_DEFAULT);
      UNBLOCK_INPUT;
      if (f->display.x->window_desc == 0)
	error ("Unable to create window.");
    }

  /* Install the now determined height and width
     in the windows and in phys_lines and desired_lines.  */
  /* ??? jla version had 1 here instead of 0.  */
  change_frame_size (f, height, width, 1);
  XSelectInput (f->display.x->window_desc, KeyPressed | ExposeWindow
		| ButtonPressed | ButtonReleased | ExposeRegion | ExposeCopy
		| EnterWindow | LeaveWindow | UnmapWindow );
  x_set_resize_hint (f);

  /* Tell the server the window's default name.  */
#ifdef HAVE_X11
  {
    XTextProperty prop;
    prop.value = XSTRING (f->name)->data;
    prop.encoding = XA_STRING;
    prop.format = 8;
    prop.nitems = XSTRING (f->name)->size;
    XSetWMName (XDISPLAY f->display.x->window_desc, &prop);
  }
#else
  XStoreName (XDISPLAY f->display.x->window_desc, XSTRING (f->name)->data);
#endif

  /* Now override the defaults with all the rest of the specified
     parms.  */
  tem = x_get_arg (parms, intern ("unsplittable"), 0, 0);
  f->no_split = minibuffer_only || EQ (tem, Qt);

  /* Do not create an icon window if the caller says not to */
  if (!EQ (x_get_arg (parms, intern ("suppress-icon"), 0, 0), Qt)
      || f->display.x->parent_desc != ROOT_WINDOW)
    {
      x_text_icon (f, iconidentity);
      x_default_parameter (f, parms, "icon-type", Qnil,
			   "BitmapIcon", boolean);
    }

  /* Tell the X server the previously set values of the
     background, border and mouse colors; also create the mouse cursor.  */
  BLOCK_INPUT;
  temp = XMakeTile (f->display.x->background_pixel);
  XChangeBackground (f->display.x->window_desc, temp);
  XFreePixmap (temp);
  UNBLOCK_INPUT;
  x_set_border_pixel (f, f->display.x->border_pixel);

  x_set_mouse_color (f, Qnil, Qnil);

  /* Now override the defaults with all the rest of the specified parms.  */

  Fmodify_frame_parameters (frame, parms);

  if (!NILP (vscroll))
    install_vertical_scrollbar (f, pixelwidth, pixelheight);
  if (!NILP (hscroll))
    install_horizontal_scrollbar (f, pixelwidth, pixelheight);

  /* Make the window appear on the frame and enable display.  */

  if (!EQ (x_get_arg (parms, intern ("suppress-initial-map"), 0, 0), Qt))
    x_make_window_visible (f);
  FRAME_GARBAGED (f);

  return frame;
#endif /* X10 */
}

DEFUN ("focus-frame", Ffocus_frame, Sfocus_frame, 1, 1, 0,
  "Set the focus on FRAME.")
  (frame)
     Lisp_Object frame;
{
  CHECK_LIVE_FRAME (frame, 0);

  if (FRAME_IS_X (XFRAME (frame)))
    {
      BLOCK_INPUT;
      x_focus_on_frame (XFRAME (frame));
      UNBLOCK_INPUT;
      return frame;
    }

  return Qnil;
}

DEFUN ("unfocus-frame", Funfocus_frame, Sunfocus_frame, 0, 0, 0,
  "If a frame has been focused, release it.")
  ()
{
  if (x_focus_frame)
    {
      BLOCK_INPUT;
      x_unfocus_frame (x_focus_frame);
      UNBLOCK_INPUT;
    }

  return Qnil;
}

#ifndef HAVE_X11
/* Computes an X-window size and position either from geometry GEO
   or with the mouse.

   F is a frame.  It specifies an X window which is used to
   determine which display to compute for.  Its font, borders
   and colors control how the rectangle will be displayed.

   X and Y are where to store the positions chosen.
   WIDTH and HEIGHT are where to store the sizes chosen.

   GEO is the geometry that may specify some of the info.
   STR is a prompt to display.
   HSCROLL and VSCROLL say whether we have horiz and vert scroll bars.  */

int
x_rubber_band (f, x, y, width, height, geo, str, hscroll, vscroll)
     struct frame *f;
     int *x, *y, *width, *height;
     char *geo;
     char *str;
     int hscroll, vscroll;
{
  OpaqueFrame frame;
  Window tempwindow;
  WindowInfo wininfo;
  int border_color;
  int background_color;
  Lisp_Object tem;
  int mask;

  BLOCK_INPUT;

  background_color = f->display.x->background_pixel;
  border_color = f->display.x->border_pixel;

  frame.bdrwidth = f->display.x->border_width;
  frame.border = XMakeTile (border_color);
  frame.background = XMakeTile (background_color);
  tempwindow = XCreateTerm (str, "emacs", geo, default_window, &frame, 10, 5,
			    (2 * f->display.x->internal_border_width
			     + (vscroll ? VSCROLL_WIDTH : 0)),
			    (2 * f->display.x->internal_border_width
			     + (hscroll ? HSCROLL_HEIGHT : 0)),
			    width, height, f->display.x->font,
			    FONT_WIDTH (f->display.x->font),
			    FONT_HEIGHT (f->display.x->font));
  XFreePixmap (frame.border);
  XFreePixmap (frame.background);

  if (tempwindow != 0)
    {
      XQueryWindow (tempwindow, &wininfo);
      XDestroyWindow (tempwindow);
      *x = wininfo.x;
      *y = wininfo.y;
    }

  /* Coordinates we got are relative to the root window.
     Convert them to coordinates relative to desired parent window
     by scanning from there up to the root.  */
  tempwindow = f->display.x->parent_desc;
  while (tempwindow != ROOT_WINDOW)
    {
      int nchildren;
      Window *children;
      XQueryWindow (tempwindow, &wininfo);
      *x -= wininfo.x;
      *y -= wininfo.y;
      XQueryTree (tempwindow, &tempwindow, &nchildren, &children);
      free (children);
    }

  UNBLOCK_INPUT;
  return tempwindow != 0;
}
#endif /* not HAVE_X11 */

/* Set whether frame F has a horizontal scroll bar.
   VAL is t or nil to specify it. */

static void
x_set_horizontal_scrollbar (f, val, oldval)
     struct frame *f;
     Lisp_Object val, oldval;
{
  if (!NILP (val))
    {
      if (f->display.x->window_desc != 0)
	{
	  BLOCK_INPUT;
	  f->display.x->h_scrollbar_height = HSCROLL_HEIGHT;
	  x_set_window_size (f, f->width, f->height);
	  install_horizontal_scrollbar (f);
	  SET_FRAME_GARBAGED (f);
	  UNBLOCK_INPUT;
	}
    }
  else
    if (f->display.x->h_scrollbar)
      {
	BLOCK_INPUT;
	f->display.x->h_scrollbar_height = 0;
	XDestroyWindow (XDISPLAY f->display.x->h_scrollbar);
	f->display.x->h_scrollbar = 0;
	x_set_window_size (f, f->width, f->height);
	f->garbaged++;
	frame_garbaged++;
	BLOCK_INPUT;
      }
}

/* Set whether frame F has a vertical scroll bar.
   VAL is t or nil to specify it. */

static void
x_set_vertical_scrollbar (f, val, oldval)
     struct frame *f;
     Lisp_Object val, oldval;
{
  if (!NILP (val))
    {
      if (f->display.x->window_desc != 0)
	{
	  BLOCK_INPUT;
	  f->display.x->v_scrollbar_width = VSCROLL_WIDTH;
	  x_set_window_size (f, f->width, f->height);
	  install_vertical_scrollbar (f);
	  SET_FRAME_GARBAGED (f);
	  UNBLOCK_INPUT;
	}
    }
  else
    if (f->display.x->v_scrollbar != 0)
      {
	BLOCK_INPUT;
	f->display.x->v_scrollbar_width = 0;
	XDestroyWindow (XDISPLAY f->display.x->v_scrollbar);
	f->display.x->v_scrollbar = 0;
	x_set_window_size (f, f->width, f->height);
	SET_FRAME_GARBAGED (f);
	UNBLOCK_INPUT;
      }
}

/* Create the X windows for a vertical scroll bar
   for a frame X that already has an X window but no scroll bar.  */

static void
install_vertical_scrollbar (f)
     struct frame *f;
{
  int ibw = f->display.x->internal_border_width;
  Window parent;
  XColor fore_color, back_color;
  Pixmap up_arrow_pixmap, down_arrow_pixmap, slider_pixmap;
  int pix_x, pix_y, width, height, border;

  height = f->display.x->pixel_height - ibw - 2;
  width = VSCROLL_WIDTH - 2;
  pix_x = f->display.x->pixel_width - ibw/2;
  pix_y = ibw / 2;
  border = 1;

#ifdef HAVE_X11
  up_arrow_pixmap =
    XCreatePixmapFromBitmapData (x_current_display, f->display.x->window_desc,
				 up_arrow_bits, 16, 16,
				 f->display.x->foreground_pixel,
				 f->display.x->background_pixel,
				 DefaultDepth (x_current_display,
					       XDefaultScreen (x_current_display)));

  down_arrow_pixmap =
    XCreatePixmapFromBitmapData (x_current_display, f->display.x->window_desc,
				 down_arrow_bits, 16, 16,
				 f->display.x->foreground_pixel,
				 f->display.x->background_pixel,
				 DefaultDepth (x_current_display,
					       XDefaultScreen (x_current_display)));

  slider_pixmap =
    XCreatePixmapFromBitmapData (x_current_display, f->display.x->window_desc,
				 gray_bits, 16, 16,
				 f->display.x->foreground_pixel,
				 f->display.x->background_pixel,
				 DefaultDepth (x_current_display,
					       XDefaultScreen (x_current_display)));

  /* These cursor shapes will be installed when the mouse enters
     the appropriate window.  */

  up_arrow_cursor = XCreateFontCursor (x_current_display, XC_sb_up_arrow);
  down_arrow_cursor = XCreateFontCursor (x_current_display, XC_sb_down_arrow);
  v_double_arrow_cursor = XCreateFontCursor (x_current_display, XC_sb_v_double_arrow);

  f->display.x->v_scrollbar =
    XCreateSimpleWindow (x_current_display, f->display.x->window_desc,
			 pix_x, pix_y, width, height, border,
			 f->display.x->foreground_pixel,
			 f->display.x->background_pixel);
  XFlush (x_current_display);
  XDefineCursor (x_current_display, f->display.x->v_scrollbar,
		 v_double_arrow_cursor);
  
  /* Create slider window */
  f->display.x->v_slider =
    XCreateSimpleWindow (x_current_display, f->display.x->v_scrollbar,
			 0, VSCROLL_WIDTH - 2,
			 VSCROLL_WIDTH - 4, VSCROLL_WIDTH - 4,
			 1, f->display.x->border_pixel,
			 f->display.x->foreground_pixel);
  XFlush (x_current_display);
  XDefineCursor (x_current_display, f->display.x->v_slider,
		 v_double_arrow_cursor);
  XSetWindowBackgroundPixmap (x_current_display, f->display.x->v_slider,
			      slider_pixmap);

  f->display.x->v_thumbup =
    XCreateSimpleWindow (x_current_display, f->display.x->v_scrollbar,
			 0, 0,
			 VSCROLL_WIDTH - 2, VSCROLL_WIDTH - 2,
			 0, f->display.x->foreground_pixel,
			 f->display.x-> background_pixel);
  XFlush (x_current_display);
  XDefineCursor (x_current_display, f->display.x->v_thumbup,
		 up_arrow_cursor);
  XSetWindowBackgroundPixmap (x_current_display, f->display.x->v_thumbup,
			      up_arrow_pixmap);

  f->display.x->v_thumbdown =
    XCreateSimpleWindow (x_current_display, f->display.x->v_scrollbar,
			 0, height - VSCROLL_WIDTH + 2,
			 VSCROLL_WIDTH - 2, VSCROLL_WIDTH - 2,
			 0, f->display.x->foreground_pixel,
			 f->display.x->background_pixel);
  XFlush (x_current_display);
  XDefineCursor (x_current_display, f->display.x->v_thumbdown,
		 down_arrow_cursor);
  XSetWindowBackgroundPixmap (x_current_display, f->display.x->v_thumbdown,
			      down_arrow_pixmap);
  
  fore_color.pixel = f->display.x->mouse_pixel;
  back_color.pixel = f->display.x->background_pixel;
  XQueryColor (x_current_display,
	       DefaultColormap (x_current_display,
				DefaultScreen (x_current_display)),
	       &fore_color);
  XQueryColor (x_current_display,
	       DefaultColormap (x_current_display,
				DefaultScreen (x_current_display)),
	       &back_color);
  XRecolorCursor (x_current_display, up_arrow_cursor,
		  &fore_color, &back_color);
  XRecolorCursor (x_current_display, down_arrow_cursor,
		  &fore_color, &back_color);
  XRecolorCursor (x_current_display, v_double_arrow_cursor,
		  &fore_color, &back_color);

  XFreePixmap (x_current_display, slider_pixmap);
  XFreePixmap (x_current_display, up_arrow_pixmap);
  XFreePixmap (x_current_display, down_arrow_pixmap);
  XFlush (x_current_display);

  XSelectInput (x_current_display, f->display.x->v_scrollbar,
		ButtonPressMask | ButtonReleaseMask
		| PointerMotionMask | PointerMotionHintMask
		| EnterWindowMask);
  XSelectInput (x_current_display, f->display.x->v_slider,
		ButtonPressMask | ButtonReleaseMask);
  XSelectInput (x_current_display, f->display.x->v_thumbdown,
		ButtonPressMask | ButtonReleaseMask);
  XSelectInput (x_current_display, f->display.x->v_thumbup,
		ButtonPressMask | ButtonReleaseMask);
  XFlush (x_current_display);

  /* This should be done at the same time as the main window. */
  XMapWindow (x_current_display, f->display.x->v_scrollbar);
  XMapSubwindows (x_current_display, f->display.x->v_scrollbar);
  XFlush (x_current_display);
#else /* not HAVE_X11 */
  Bitmap b;
  Pixmap fore_tile, back_tile, bord_tile;
  static short up_arrow_bits[] = {
    0x0000, 0x0180, 0x03c0, 0x07e0,
    0x0ff0, 0x1ff8, 0x3ffc, 0x7ffe,
    0x0180, 0x0180, 0x0180, 0x0180,
    0x0180, 0x0180, 0x0180, 0xffff};
  static short down_arrow_bits[] = {
    0xffff, 0x0180, 0x0180, 0x0180,
    0x0180, 0x0180, 0x0180, 0x0180,
    0x7ffe, 0x3ffc, 0x1ff8, 0x0ff0,
    0x07e0, 0x03c0, 0x0180, 0x0000};

  fore_tile = XMakeTile (f->display.x->foreground_pixel);
  back_tile = XMakeTile (f->display.x->background_pixel);
  bord_tile = XMakeTile (f->display.x->border_pixel);

  b = XStoreBitmap (VSCROLL_WIDTH - 2, VSCROLL_WIDTH - 2, up_arrow_bits);
  up_arrow_pixmap = XMakePixmap (b, 
				 f->display.x->foreground_pixel,
				 f->display.x->background_pixel);
  XFreeBitmap (b);

  b = XStoreBitmap (VSCROLL_WIDTH - 2, VSCROLL_WIDTH - 2, down_arrow_bits);
  down_arrow_pixmap = XMakePixmap (b,
				   f->display.x->foreground_pixel,
				   f->display.x->background_pixel);
  XFreeBitmap (b);

  ibw = f->display.x->internal_border_width;

  f->display.x->v_scrollbar = XCreateWindow (f->display.x->window_desc,
					     width - VSCROLL_WIDTH - ibw/2,
					     ibw/2,
					     VSCROLL_WIDTH - 2,
					     height - ibw - 2,
					     1, bord_tile, back_tile);

  f->display.x->v_scrollbar_width = VSCROLL_WIDTH;

  f->display.x->v_thumbup = XCreateWindow (f->display.x->v_scrollbar,
					   0, 0,
					   VSCROLL_WIDTH - 2,
					   VSCROLL_WIDTH - 2,
					   0, 0, up_arrow_pixmap);
  XTileAbsolute (f->display.x->v_thumbup);

  f->display.x->v_thumbdown = XCreateWindow (f->display.x->v_scrollbar,
					     0,
					     height - ibw - VSCROLL_WIDTH,
					     VSCROLL_WIDTH - 2,
					     VSCROLL_WIDTH - 2,
					     0, 0, down_arrow_pixmap);
  XTileAbsolute (f->display.x->v_thumbdown);

  f->display.x->v_slider = XCreateWindow (f->display.x->v_scrollbar,
					  0, VSCROLL_WIDTH - 2,
					  VSCROLL_WIDTH - 4,
					  VSCROLL_WIDTH - 4,
					  1, back_tile, fore_tile);

  XSelectInput (f->display.x->v_scrollbar,
		(ButtonPressed | ButtonReleased | KeyPressed));
  XSelectInput (f->display.x->v_thumbup,
		(ButtonPressed | ButtonReleased | KeyPressed));

  XSelectInput (f->display.x->v_thumbdown,
		(ButtonPressed | ButtonReleased | KeyPressed));

  XMapWindow (f->display.x->v_thumbup);
  XMapWindow (f->display.x->v_thumbdown);
  XMapWindow (f->display.x->v_slider);
  XMapWindow (f->display.x->v_scrollbar);

  XFreePixmap (fore_tile);
  XFreePixmap (back_tile);
  XFreePixmap (up_arrow_pixmap);
  XFreePixmap (down_arrow_pixmap);
#endif /* not HAVE_X11 */
}				       

static void
install_horizontal_scrollbar (f)
     struct frame *f;
{
  int ibw = f->display.x->internal_border_width;
  Window parent;
  Pixmap left_arrow_pixmap, right_arrow_pixmap, slider_pixmap;
  int pix_x, pix_y;
  int width;

  pix_x = ibw;
  pix_y = PIXEL_HEIGHT (f) - HSCROLL_HEIGHT - ibw ;
  width = PIXEL_WIDTH (f) - 2 * ibw;
  if (f->display.x->v_scrollbar_width)
    width -= (f->display.x->v_scrollbar_width + 1);

#ifdef HAVE_X11
  left_arrow_pixmap =
    XCreatePixmapFromBitmapData (x_current_display, f->display.x->window_desc,
				 left_arrow_bits, 16, 16,
				 f->display.x->foreground_pixel,
				 f->display.x->background_pixel,
				 DefaultDepth (x_current_display,
					       XDefaultScreen (x_current_display)));

  right_arrow_pixmap =
    XCreatePixmapFromBitmapData (x_current_display, f->display.x->window_desc,
				 right_arrow_bits, 16, 16,
				 f->display.x->foreground_pixel,
				 f->display.x->background_pixel,
				 DefaultDepth (x_current_display,
					       XDefaultScreen (x_current_display)));

  slider_pixmap =
    XCreatePixmapFromBitmapData (x_current_display, f->display.x->window_desc,
				 gray_bits, 16, 16,
				 f->display.x->foreground_pixel,
				 f->display.x->background_pixel,
				 DefaultDepth (x_current_display,
					       XDefaultScreen (x_current_display)));

  left_arrow_cursor = XCreateFontCursor (x_current_display, XC_sb_left_arrow);
  right_arrow_cursor = XCreateFontCursor (x_current_display, XC_sb_right_arrow);
  h_double_arrow_cursor = XCreateFontCursor (x_current_display, XC_sb_h_double_arrow);

  f->display.x->h_scrollbar =
    XCreateSimpleWindow (x_current_display, f->display.x->window_desc,
			 pix_x, pix_y,
			 width - ibw - 2, HSCROLL_HEIGHT - 2, 1,
			 f->display.x->foreground_pixel,
			 f->display.x->background_pixel);
  XDefineCursor (x_current_display, f->display.x->h_scrollbar,
		 h_double_arrow_cursor);

  f->display.x->h_slider =
    XCreateSimpleWindow (x_current_display, f->display.x->h_scrollbar,
			 0, 0,
			 HSCROLL_HEIGHT - 4, HSCROLL_HEIGHT - 4,
			 1, f->display.x->foreground_pixel,
			 f->display.x->background_pixel);
  XDefineCursor (x_current_display, f->display.x->h_slider,
		 h_double_arrow_cursor);
  XSetWindowBackgroundPixmap (x_current_display, f->display.x->h_slider,
			      slider_pixmap);

  f->display.x->h_thumbleft =
    XCreateSimpleWindow (x_current_display, f->display.x->h_scrollbar,
			 0, 0,
			 HSCROLL_HEIGHT - 2, HSCROLL_HEIGHT - 2,
			 0, f->display.x->foreground_pixel,
			 f->display.x->background_pixel);
  XDefineCursor (x_current_display, f->display.x->h_thumbleft,
		 left_arrow_cursor);
  XSetWindowBackgroundPixmap (x_current_display, f->display.x->h_thumbleft,
			      left_arrow_pixmap);

  f->display.x->h_thumbright =
    XCreateSimpleWindow (x_current_display, f->display.x->h_scrollbar,
			 width - ibw - HSCROLL_HEIGHT, 0,
			 HSCROLL_HEIGHT - 2, HSCROLL_HEIGHT -2,
			 0, f->display.x->foreground_pixel,
			 f->display.x->background_pixel);
  XDefineCursor (x_current_display, f->display.x->h_thumbright,
		 right_arrow_cursor);
  XSetWindowBackgroundPixmap (x_current_display, f->display.x->h_thumbright,
			      right_arrow_pixmap);

  XFreePixmap (x_current_display, slider_pixmap);
  XFreePixmap (x_current_display, left_arrow_pixmap);
  XFreePixmap (x_current_display, right_arrow_pixmap);

  XSelectInput (x_current_display, f->display.x->h_scrollbar,
		ButtonPressMask | ButtonReleaseMask
		| PointerMotionMask | PointerMotionHintMask
		| EnterWindowMask);
  XSelectInput (x_current_display, f->display.x->h_slider,
		ButtonPressMask | ButtonReleaseMask);
  XSelectInput (x_current_display, f->display.x->h_thumbright,
		ButtonPressMask | ButtonReleaseMask);
  XSelectInput (x_current_display, f->display.x->h_thumbleft,
		ButtonPressMask | ButtonReleaseMask);

  XMapWindow (x_current_display, f->display.x->h_scrollbar);
  XMapSubwindows (x_current_display, f->display.x->h_scrollbar);
#else /* not HAVE_X11 */
  Bitmap b;
  Pixmap fore_tile, back_tile, bord_tile;
#endif
}

#ifndef HAVE_X11			/* X10 */
#define XMoveResizeWindow XConfigureWindow
#endif /* not HAVE_X11 */

/* Adjust the displayed position in the scroll bar for window W.  */

void
adjust_scrollbars (f)
     struct frame *f;
{
  int pos;
  int first_char_in_window, char_beyond_window, chars_in_window;
  int chars_in_buffer, buffer_size;
  struct window *w = XWINDOW (FRAME_SELECTED_WINDOW (f));

  if (! FRAME_IS_X (f))
    return;

  if (f->display.x->v_scrollbar != 0)
    {
      int h, height;
      struct buffer *b = XBUFFER (w->buffer);

      buffer_size = Z - BEG;
      chars_in_buffer = ZV - BEGV;
      first_char_in_window = marker_position (w->start);
      char_beyond_window = buffer_size + 1 - XFASTINT (w->window_end_pos);
      chars_in_window = char_beyond_window - first_char_in_window;

      /* Calculate height of scrollbar area */

      height = f->height * FONT_HEIGHT (f->display.x->font)
	+ f->display.x->internal_border_width
	  - 2 * (f->display.x->v_scrollbar_width);

      /* Figure starting position for the scrollbar slider */

      if (chars_in_buffer <= 0)
	pos = 0;
      else
	pos = ((first_char_in_window - BEGV - BEG) * height
	       / chars_in_buffer);
      pos = max (0, pos);
      pos = min (pos, height - 2);

      /* Figure length of the slider */

      if (chars_in_buffer <= 0)
	h = height;
      else
	h = (chars_in_window * height) / chars_in_buffer;
      h = min (h, height - pos);
      h = max (h, 1);

      /* Add thumbup offset to starting position of slider */

      pos += (f->display.x->v_scrollbar_width - 2);

      XMoveResizeWindow (XDISPLAY
			 f->display.x->v_slider,
			 0, pos,
			 f->display.x->v_scrollbar_width - 4, h);
    }
      
  if (f->display.x->h_scrollbar != 0)
    {
      int l, length;      /* Length of the scrollbar area */

      length = f->width * FONT_WIDTH (f->display.x->font)
	+ f->display.x->internal_border_width
	  - 2 * (f->display.x->h_scrollbar_height);

      /* Starting position for horizontal slider */
      if (! w->hscroll)
	pos = 0;
      else
	pos = (w->hscroll * length) / (w->hscroll + f->width);
      pos = max (0, pos);
      pos = min (pos, length - 2);

      /* Length of slider */
      l = length - pos;

      /* Add thumbup offset */
      pos += (f->display.x->h_scrollbar_height - 2);

      XMoveResizeWindow (XDISPLAY
			 f->display.x->h_slider,
			 pos, 0,
			 l, f->display.x->h_scrollbar_height - 4);
    }
}

/* Adjust the size of the scroll bars of frame F,
   when the frame size has changed.  */

void
x_resize_scrollbars (f)
     struct frame *f;
{
  int ibw = f->display.x->internal_border_width;
  int pixelwidth, pixelheight;

  if (f == 0
      || f->display.x == 0
      || (f->display.x->v_scrollbar == 0
	  && f->display.x->h_scrollbar == 0))
    return;

  /* Get the size of the frame.  */
  pixelwidth = (f->width * FONT_WIDTH (f->display.x->font)
		+ 2 * ibw + f->display.x->v_scrollbar_width);
  pixelheight = (f->height * FONT_HEIGHT (f->display.x->font)
		 + 2 * ibw + f->display.x->h_scrollbar_height);

  if (f->display.x->v_scrollbar_width && f->display.x->v_scrollbar)
    {
      BLOCK_INPUT;
      XMoveResizeWindow (XDISPLAY
			 f->display.x->v_scrollbar,
			 pixelwidth - f->display.x->v_scrollbar_width - ibw/2,
			 ibw/2,
			 f->display.x->v_scrollbar_width - 2,
			 pixelheight - ibw - 2);
      XMoveWindow (XDISPLAY
		   f->display.x->v_thumbdown, 0,
		   pixelheight - ibw - f->display.x->v_scrollbar_width);
      UNBLOCK_INPUT;
    }

  if (f->display.x->h_scrollbar_height && f->display.x->h_scrollbar)
    {
      if (f->display.x->v_scrollbar_width)
	pixelwidth -= f->display.x->v_scrollbar_width + 1;

      BLOCK_INPUT;
      XMoveResizeWindow (XDISPLAY
			 f->display.x->h_scrollbar,
			 ibw / 2,
			 pixelheight - f->display.x->h_scrollbar_height - ibw / 2,
			 pixelwidth - ibw - 2,
			 f->display.x->h_scrollbar_height - 2);
      XMoveWindow (XDISPLAY
		   f->display.x->h_thumbright,
		   pixelwidth - ibw - f->display.x->h_scrollbar_height, 0);
      UNBLOCK_INPUT;
    }
}

x_pixel_width (f)
     register struct frame *f;
{
  return PIXEL_WIDTH (f);
}

x_pixel_height (f)
     register struct frame *f;
{
  return PIXEL_HEIGHT (f);
}

DEFUN ("x-defined-color", Fx_defined_color, Sx_defined_color, 1, 1, 0,
  "Return t if the current X display supports the color named COLOR.")
  (color)
     Lisp_Object color;
{
  Color foo;
  
  CHECK_STRING (color, 0);

  if (defined_color (XSTRING (color)->data, &foo))
    return Qt;
  else
    return Qnil;
}

DEFUN ("x-color-display-p", Fx_color_display_p, Sx_color_display_p, 0, 0, 0,
  "Return t if the X display used currently supports color.")
  ()
{
  if (XINT (x_screen_planes) <= 2)
    return Qnil;

  switch (screen_visual->class)
    {
    case StaticColor:
    case PseudoColor:
    case TrueColor:
    case DirectColor:
      return Qt;

    default:
      return Qnil;
    }
}

DEFUN ("x-pixel-width", Fx_pixel_width, Sx_pixel_width, 1, 1, 0,
  "Return the width in pixels of FRAME.")
  (frame)
     Lisp_Object frame;
{
  CHECK_LIVE_FRAME (frame, 0);
  return make_number (XFRAME (frame)->display.x->pixel_width);
}

DEFUN ("x-pixel-height", Fx_pixel_height, Sx_pixel_height, 1, 1, 0,
  "Return the height in pixels of FRAME.")
  (frame)
     Lisp_Object frame;
{
  CHECK_LIVE_FRAME (frame, 0);
  return make_number (XFRAME (frame)->display.x->pixel_height);
}

#if 0  /* These no longer seem like the right way to do things.  */

/* Draw a rectangle on the frame with left top corner including
   the character specified by LEFT_CHAR and TOP_CHAR.  The rectangle is
   CHARS by LINES wide and long and is the color of the cursor. */

void
x_rectangle (f, gc, left_char, top_char, chars, lines)
     register struct frame *f;
     GC gc;
     register int top_char, left_char, chars, lines;
{
  int width;
  int height;
  int left = (left_char * FONT_WIDTH (f->display.x->font)
		    + f->display.x->internal_border_width);
  int top = (top_char *  FONT_HEIGHT (f->display.x->font)
		   + f->display.x->internal_border_width);

  if (chars < 0)
    width = FONT_WIDTH (f->display.x->font) / 2;
  else
    width = FONT_WIDTH (f->display.x->font) * chars;
  if (lines < 0)
    height = FONT_HEIGHT (f->display.x->font) / 2;
  else
    height = FONT_HEIGHT (f->display.x->font) * lines;

  XDrawRectangle (x_current_display, f->display.x->window_desc,
		  gc, left, top, width, height);
}

DEFUN ("x-draw-rectangle", Fx_draw_rectangle, Sx_draw_rectangle, 5, 5, 0,
  "Draw a rectangle on FRAME between coordinates specified by\n\
numbers X0, Y0, X1, Y1 in the cursor pixel.")
  (frame, X0, Y0, X1, Y1)
     register Lisp_Object frame, X0, X1, Y0, Y1;
{
  register int x0, y0, x1, y1, top, left, n_chars, n_lines;

  CHECK_LIVE_FRAME (frame, 0);
  CHECK_NUMBER (X0, 0);
  CHECK_NUMBER (Y0, 1);
  CHECK_NUMBER (X1, 2);
  CHECK_NUMBER (Y1, 3);

  x0 = XINT (X0);
  x1 = XINT (X1);
  y0 = XINT (Y0);
  y1 = XINT (Y1);

  if (y1 > y0)
    {
      top = y0;
      n_lines = y1 - y0 + 1;
    }
  else
    {
      top = y1;
      n_lines = y0 - y1 + 1;
    }

  if (x1 > x0)
    {
      left = x0;
      n_chars = x1 - x0 + 1;
    }
  else
    {
      left = x1;
      n_chars = x0 - x1 + 1;
    }

  BLOCK_INPUT;
  x_rectangle (XFRAME (frame), XFRAME (frame)->display.x->cursor_gc,
	       left, top, n_chars, n_lines);
  UNBLOCK_INPUT;

  return Qt;
}

DEFUN ("x-erase-rectangle", Fx_erase_rectangle, Sx_erase_rectangle, 5, 5, 0,
  "Draw a rectangle drawn on FRAME between coordinates\n\
X0, Y0, X1, Y1 in the regular background-pixel.")
  (frame, X0, Y0, X1, Y1)
  register Lisp_Object frame, X0, Y0, X1, Y1;
{
  register int x0, y0, x1, y1, top, left, n_chars, n_lines;

  CHECK_FRAME (frame, 0);
  CHECK_NUMBER (X0, 0);
  CHECK_NUMBER (Y0, 1);
  CHECK_NUMBER (X1, 2);
  CHECK_NUMBER (Y1, 3);

  x0 = XINT (X0);
  x1 = XINT (X1);
  y0 = XINT (Y0);
  y1 = XINT (Y1);

  if (y1 > y0)
    {
      top = y0;
      n_lines = y1 - y0 + 1;
    }
  else
    {
      top = y1;
      n_lines = y0 - y1 + 1;
    }

  if (x1 > x0)
    {
      left = x0;
      n_chars = x1 - x0 + 1;
    }
  else
    {
      left = x1;
      n_chars = x0 - x1 + 1;
    }

  BLOCK_INPUT;
  x_rectangle (XFRAME (frame), XFRAME (frame)->display.x->reverse_gc,
	       left, top, n_chars, n_lines);
  UNBLOCK_INPUT;

  return Qt;
}

/* Draw lines around the text region beginning at the character position
   TOP_X, TOP_Y and ending at BOTTOM_X and BOTTOM_Y.  GC specifies the
   pixel and line characteristics. */

#define line_len(line) (FRAME_CURRENT_GLYPHS (f)->used[(line)])

static void
outline_region (f, gc, top_x, top_y, bottom_x, bottom_y)
     register struct frame *f;
     GC gc;
     int  top_x, top_y, bottom_x, bottom_y;
{
  register int ibw = f->display.x->internal_border_width;
  register int font_w = FONT_WIDTH (f->display.x->font);
  register int font_h = FONT_HEIGHT (f->display.x->font);
  int y = top_y;
  int x = line_len (y);
  XPoint *pixel_points = (XPoint *)
    alloca (((bottom_y - top_y + 2) * 4) * sizeof (XPoint));
  register XPoint *this_point = pixel_points;

  /* Do the horizontal top line/lines */
  if (top_x == 0)
    {
      this_point->x = ibw;
      this_point->y = ibw + (font_h * top_y);
      this_point++;
      if (x == 0)
	this_point->x = ibw + (font_w / 2); /* Half-size for newline chars. */
      else
	this_point->x = ibw + (font_w * x);
      this_point->y = (this_point - 1)->y;
    }
  else
    {
      this_point->x = ibw;
      this_point->y = ibw + (font_h * (top_y + 1));
      this_point++;
      this_point->x = ibw + (font_w * top_x);
      this_point->y = (this_point - 1)->y;
      this_point++;
      this_point->x = (this_point - 1)->x;
      this_point->y = ibw + (font_h * top_y);
      this_point++;
      this_point->x = ibw + (font_w * x);
      this_point->y = (this_point - 1)->y;
    }

  /* Now do the right side. */
  while (y < bottom_y)
    {				/* Right vertical edge */
      this_point++;
      this_point->x = (this_point - 1)->x;
      this_point->y = ibw + (font_h * (y + 1));
      this_point++;

      y++;			/* Horizontal connection to next line */
      x = line_len (y);
      if (x == 0)
	this_point->x = ibw + (font_w / 2);
      else
	this_point->x = ibw + (font_w * x);

      this_point->y = (this_point - 1)->y;
    }

  /* Now do the bottom and connect to the top left point. */
  this_point->x = ibw + (font_w * (bottom_x + 1));

  this_point++;
  this_point->x = (this_point - 1)->x;
  this_point->y = ibw + (font_h * (bottom_y + 1));
  this_point++;
  this_point->x = ibw;
  this_point->y = (this_point - 1)->y;
  this_point++;
  this_point->x = pixel_points->x;
  this_point->y = pixel_points->y;

  XDrawLines (x_current_display, f->display.x->window_desc,
	      gc, pixel_points,
	      (this_point - pixel_points + 1), CoordModeOrigin);
}

DEFUN ("x-contour-region", Fx_contour_region, Sx_contour_region, 1, 1, 0,
  "Highlight the region between point and the character under the mouse\n\
selected frame.")
  (event)
     register Lisp_Object event;
{
  register int x0, y0, x1, y1;
  register struct frame *f = selected_frame;
  register int p1, p2;

  CHECK_CONS (event, 0);

  BLOCK_INPUT;
  x0 = XINT (Fcar (Fcar (event)));
  y0 = XINT (Fcar (Fcdr (Fcar (event))));

  /* If the mouse is past the end of the line, don't that area. */
  /* ReWrite this... */

  x1 = f->cursor_x;
  y1 = f->cursor_y;

  if (y1 > y0)			/* point below mouse */
    outline_region (f, f->display.x->cursor_gc,
		    x0, y0, x1, y1);
  else if (y1 < y0)		/* point above mouse */
    outline_region (f, f->display.x->cursor_gc,
		    x1, y1, x0, y0);
  else				/* same line: draw horizontal rectangle */
    {
      if (x1 > x0)
	x_rectangle (f, f->display.x->cursor_gc,
		     x0, y0, (x1 - x0 + 1), 1);
      else if (x1 < x0)
	  x_rectangle (f, f->display.x->cursor_gc,
		       x1, y1, (x0 - x1 + 1), 1);
    }

  XFlush (x_current_display);
  UNBLOCK_INPUT;

  return Qnil;
}

DEFUN ("x-uncontour-region", Fx_uncontour_region, Sx_uncontour_region, 1, 1, 0,
  "Erase any highlighting of the region between point and the character\n\
at X, Y on the selected frame.")
  (event)
     register Lisp_Object event;
{
  register int x0, y0, x1, y1;
  register struct frame *f = selected_frame;

  BLOCK_INPUT;
  x0 = XINT (Fcar (Fcar (event)));
  y0 = XINT (Fcar (Fcdr (Fcar (event))));
  x1 = f->cursor_x;
  y1 = f->cursor_y;

  if (y1 > y0)			/* point below mouse */
    outline_region (f, f->display.x->reverse_gc,
		      x0, y0, x1, y1);
  else if (y1 < y0)		/* point above mouse */
    outline_region (f, f->display.x->reverse_gc,
		      x1, y1, x0, y0);
  else				/* same line: draw horizontal rectangle */
    {
      if (x1 > x0)
	x_rectangle (f, f->display.x->reverse_gc,
		     x0, y0, (x1 - x0 + 1), 1);
      else if (x1 < x0)
	x_rectangle (f, f->display.x->reverse_gc,
		     x1, y1, (x0 - x1 + 1), 1);
    }
  UNBLOCK_INPUT;

  return Qnil;
}

#if 0
int contour_begin_x, contour_begin_y;
int contour_end_x, contour_end_y;
int contour_npoints;

/* Clip the top part of the contour lines down (and including) line Y_POS.
   If X_POS is in the middle (rather than at the end) of the line, drop
   down a line at that character. */

static void
clip_contour_top (y_pos, x_pos)
{
  register XPoint *begin = contour_lines[y_pos].top_left;
  register XPoint *end;
  register int npoints;
  register struct display_line *line = selected_frame->phys_lines[y_pos + 1];

  if (x_pos >= line->len - 1)	/* Draw one, straight horizontal line. */
    {
      end = contour_lines[y_pos].top_right;
      npoints = (end - begin + 1);
      XDrawLines (x_current_display, contour_window,
		  contour_erase_gc, begin_erase, npoints, CoordModeOrigin);

      bcopy (end, begin + 1, contour_last_point - end + 1);
      contour_last_point -= (npoints - 2);
      XDrawLines (x_current_display, contour_window,
		  contour_erase_gc, begin, 2, CoordModeOrigin);
      XFlush (x_current_display);

      /* Now, update contour_lines structure. */
    }
				/* ______.         */
  else				/*       |________*/
    {
      register XPoint *p = begin + 1;
      end = contour_lines[y_pos].bottom_right;
      npoints = (end - begin + 1);
      XDrawLines (x_current_display, contour_window,
		  contour_erase_gc, begin_erase, npoints, CoordModeOrigin);

      p->y = begin->y;
      p->x = ibw + (font_w * (x_pos + 1));
      p++;
      p->y = begin->y + font_h;
      p->x = (p - 1)->x;
      bcopy (end, begin + 3, contour_last_point - end + 1);
      contour_last_point -= (npoints - 5);
      XDrawLines (x_current_display, contour_window,
		  contour_erase_gc, begin, 4, CoordModeOrigin);
      XFlush (x_current_display);

      /* Now, update contour_lines structure. */
    }
}

/* Erase the top horzontal lines of the contour, and then extend
   the contour upwards. */

static void
extend_contour_top (line)
{
}

static void
clip_contour_bottom (x_pos, y_pos)
     int x_pos, y_pos;
{
}

static void
extend_contour_bottom (x_pos, y_pos)
{
}

DEFUN ("x-select-region", Fx_select_region, Sx_select_region, 1, 1, "e",
  "")
  (event)
     Lisp_Object event;
{
 register struct frame *f = selected_frame;
 register int point_x = f->cursor_x;
 register int point_y = f->cursor_y;
 register int mouse_below_point;
 register Lisp_Object obj;
 register int x_contour_x, x_contour_y;

 x_contour_x = x_mouse_x;
 x_contour_y = x_mouse_y;
 if (x_contour_y > point_y || (x_contour_y == point_y
			       && x_contour_x > point_x))
   {
     mouse_below_point = 1;
     outline_region (f, f->display.x->cursor_gc, point_x, point_y,
		     x_contour_x, x_contour_y);
   }
 else
   {
     mouse_below_point = 0;
     outline_region (f, f->display.x->cursor_gc, x_contour_x, x_contour_y,
		     point_x, point_y);
   }

 while (1)
   {
     obj = read_char (-1);
     if (XTYPE (obj) != Lisp_Cons)
       break;

     if (mouse_below_point)
       {
	 if (x_mouse_y <= point_y)                /* Flipped. */
	   {
	     mouse_below_point = 0;

	     outline_region (f, f->display.x->reverse_gc, point_x, point_y,
			     x_contour_x, x_contour_y);
	     outline_region (f, f->display.x->cursor_gc, x_mouse_x, x_mouse_y,
			     point_x, point_y);
	   }
	 else if (x_mouse_y < x_contour_y)	  /* Bottom clipped. */
	   {
	     clip_contour_bottom (x_mouse_y);
	   }
	 else if (x_mouse_y > x_contour_y)	  /* Bottom extended. */
	   {
	     extend_bottom_contour (x_mouse_y);
	   }

	 x_contour_x = x_mouse_x;
	 x_contour_y = x_mouse_y;
       }
     else  /* mouse above or same line as point */
       {
	 if (x_mouse_y >= point_y)		  /* Flipped. */
	   {
	     mouse_below_point = 1;

	     outline_region (f, f->display.x->reverse_gc,
			     x_contour_x, x_contour_y, point_x, point_y);
	     outline_region (f, f->display.x->cursor_gc, point_x, point_y,
			     x_mouse_x, x_mouse_y);
	   }
	 else if (x_mouse_y > x_contour_y)	  /* Top clipped. */
	   {
	     clip_contour_top (x_mouse_y);
	   }
	 else if (x_mouse_y < x_contour_y)	  /* Top extended. */
	   {
	     extend_contour_top (x_mouse_y);
	   }
       }
   }

 unread_command_char = obj;
 if (mouse_below_point)
   {
     contour_begin_x = point_x;
     contour_begin_y = point_y;
     contour_end_x = x_contour_x;
     contour_end_y = x_contour_y;
   }
 else
   {
     contour_begin_x = x_contour_x;
     contour_begin_y = x_contour_y;
     contour_end_x = point_x;
     contour_end_y = point_y;
   }
}
#endif

DEFUN ("x-horizontal-line", Fx_horizontal_line, Sx_horizontal_line, 1, 1, "e",
  "")
  (event)
     Lisp_Object event;
{
  register Lisp_Object obj;
  struct frame *f = selected_frame;
  register struct window *w = XWINDOW (selected_window);
  register GC line_gc = f->display.x->cursor_gc;
  register GC erase_gc = f->display.x->reverse_gc;
#if 0
  char dash_list[] = {6, 4, 6, 4};
  int dashes = 4;
  XGCValues gc_values;
#endif
  register int previous_y;
  register int line = (x_mouse_y + 1) * FONT_HEIGHT (f->display.x->font)
    + f->display.x->internal_border_width;
  register int left = f->display.x->internal_border_width
    + (w->left
       * FONT_WIDTH (f->display.x->font));
  register int right = left + (w->width
			       * FONT_WIDTH (f->display.x->font))
    - f->display.x->internal_border_width;

#if 0
  BLOCK_INPUT;
  gc_values.foreground = f->display.x->cursor_pixel;
  gc_values.background = f->display.x->background_pixel;
  gc_values.line_width = 1;
  gc_values.line_style = LineOnOffDash;
  gc_values.cap_style = CapRound;
  gc_values.join_style = JoinRound;

  line_gc = XCreateGC (x_current_display, f->display.x->window_desc,
		       GCLineStyle | GCJoinStyle | GCCapStyle
		       | GCLineWidth | GCForeground | GCBackground,
		       &gc_values);
  XSetDashes (x_current_display, line_gc, 0, dash_list, dashes);
  gc_values.foreground = f->display.x->background_pixel;
  gc_values.background = f->display.x->foreground_pixel;
  erase_gc = XCreateGC (x_current_display, f->display.x->window_desc,
		       GCLineStyle | GCJoinStyle | GCCapStyle
		       | GCLineWidth | GCForeground | GCBackground,
		       &gc_values);
  XSetDashes (x_current_display, erase_gc, 0, dash_list, dashes);
#endif

  while (1)
    {
      BLOCK_INPUT;
      if (x_mouse_y >= XINT (w->top)
	  && x_mouse_y < XINT (w->top) + XINT (w->height) - 1)
	{
	  previous_y = x_mouse_y;
	  line = (x_mouse_y + 1) * FONT_HEIGHT (f->display.x->font)
	    + f->display.x->internal_border_width;
	  XDrawLine (x_current_display, f->display.x->window_desc,
		     line_gc, left, line, right, line);
	}
      XFlushQueue ();
      UNBLOCK_INPUT;

      do
	{
	  obj = read_char (-1);
	  if ((XTYPE (obj) != Lisp_Cons)
	      || (! EQ (Fcar (Fcdr (Fcdr (obj))),
		       intern ("vertical-scroll-bar")))
	      || x_mouse_grabbed)
	    {
	      BLOCK_INPUT;
	      XDrawLine (x_current_display, f->display.x->window_desc,
			 erase_gc, left, line, right, line);
	      UNBLOCK_INPUT;
	      unread_command_char = obj;
#if 0
	      XFreeGC (x_current_display, line_gc);
	      XFreeGC (x_current_display, erase_gc);
#endif 
	      return Qnil;
	    }
	}
      while (x_mouse_y == previous_y);

      BLOCK_INPUT;
      XDrawLine (x_current_display, f->display.x->window_desc,
		 erase_gc, left, line, right, line);
      UNBLOCK_INPUT;
    }
}
#endif

/* Offset in buffer of character under the pointer, or 0. */
int mouse_buffer_offset;

#if 0
/* These keep track of the rectangle following the pointer. */
int mouse_track_top, mouse_track_left, mouse_track_width;

DEFUN ("x-track-pointer", Fx_track_pointer, Sx_track_pointer, 0, 0, 0,
  "Track the pointer.")
  ()
{
  static Cursor current_pointer_shape;
  FRAME_PTR f = x_mouse_frame;

  BLOCK_INPUT;
  if (EQ (Vmouse_frame_part, Qtext_part)
      && (current_pointer_shape != f->display.x->nontext_cursor))
    {
      unsigned char c;
      struct buffer *buf;

      current_pointer_shape = f->display.x->nontext_cursor;
      XDefineCursor (x_current_display,
		     f->display.x->window_desc,
		     current_pointer_shape);

      buf = XBUFFER (XWINDOW (Vmouse_window)->buffer);
      c = *(BUF_CHAR_ADDRESS (buf, mouse_buffer_offset));
    }
  else if (EQ (Vmouse_frame_part, Qmodeline_part)
	   && (current_pointer_shape != f->display.x->modeline_cursor))
    {
      current_pointer_shape = f->display.x->modeline_cursor;
      XDefineCursor (x_current_display,
		     f->display.x->window_desc,
		     current_pointer_shape);
    }

  XFlushQueue ();
  UNBLOCK_INPUT;
}
#endif

#if 0
DEFUN ("x-track-pointer", Fx_track_pointer, Sx_track_pointer, 1, 1, "e",
  "Draw rectangle around character under mouse pointer, if there is one.")
  (event)
     Lisp_Object event;
{
  struct window *w = XWINDOW (Vmouse_window);
  struct frame *f = XFRAME (WINDOW_FRAME (w));
  struct buffer *b = XBUFFER (w->buffer);
  Lisp_Object obj;

  if (! EQ (Vmouse_window, selected_window))
      return Qnil;

  if (EQ (event, Qnil))
    {
      int x, y;

      x_read_mouse_position (selected_frame, &x, &y);
    }

  BLOCK_INPUT;
  mouse_track_width = 0;
  mouse_track_left = mouse_track_top = -1;

  do
    {
      if ((x_mouse_x != mouse_track_left
	   && (x_mouse_x < mouse_track_left
	       || x_mouse_x > (mouse_track_left + mouse_track_width)))
	  || x_mouse_y != mouse_track_top)
	{
	  int hp = 0;		/* Horizontal position */
	  int len = FRAME_CURRENT_GLYPHS (f)->used[x_mouse_y];
	  int p = FRAME_CURRENT_GLYPHS (f)->bufp[x_mouse_y];
	  int tab_width = XINT (b->tab_width);
	  int ctl_arrow_p = !NILP (b->ctl_arrow);
	  unsigned char c;
	  int mode_line_vpos = XFASTINT (w->height) + XFASTINT (w->top) - 1;
	  int in_mode_line = 0;

	  if (! FRAME_CURRENT_GLYPHS (f)->enable[x_mouse_y])
	    break;

	  /* Erase previous rectangle. */
	  if (mouse_track_width)
	    {
	      x_rectangle (f, f->display.x->reverse_gc,
			   mouse_track_left, mouse_track_top,
			   mouse_track_width, 1);

	      if ((mouse_track_left == f->phys_cursor_x
		   || mouse_track_left == f->phys_cursor_x - 1)
		  && mouse_track_top == f->phys_cursor_y)
		{
		  x_display_cursor (f, 1);
		}
	    }

	  mouse_track_left = x_mouse_x;
	  mouse_track_top = x_mouse_y;
	  mouse_track_width = 0;

	  if (mouse_track_left > len) /* Past the end of line. */
	    goto draw_or_not;

	  if (mouse_track_top == mode_line_vpos)
	    {
	      in_mode_line = 1;
	      goto draw_or_not;
	    }

	  if (tab_width <= 0 || tab_width > 20) tab_width = 8;
	  do
	    {
	      c = FETCH_CHAR (p);
	      if (len == f->width && hp == len - 1 && c != '\n')
		goto draw_or_not;

	      switch (c)
		{
		case '\t':
		  mouse_track_width = tab_width - (hp % tab_width);
		  p++;
		  hp += mouse_track_width;
		  if (hp > x_mouse_x)
		    {
		      mouse_track_left = hp - mouse_track_width;
		      goto draw_or_not;
		    }
		  continue;

		case '\n':
		  mouse_track_width = -1;
		  goto draw_or_not;

		default:
		  if (ctl_arrow_p && (c < 040 || c == 0177))
		    {
		      if (p > ZV)
			goto draw_or_not;

		      mouse_track_width = 2;
		      p++;
		      hp +=2;
		      if (hp > x_mouse_x)
			{
			  mouse_track_left = hp - mouse_track_width;
			  goto draw_or_not;
			}
		    }
		  else
		    {
		      mouse_track_width = 1;
		      p++;
		      hp++;
		    }
		  continue;
		}
	    }
	  while (hp <= x_mouse_x);

	draw_or_not:
	  if (mouse_track_width) /* Over text; use text pointer shape. */
	    {
	      XDefineCursor (x_current_display,
			     f->display.x->window_desc,
			     f->display.x->text_cursor);
	      x_rectangle (f, f->display.x->cursor_gc,
			   mouse_track_left, mouse_track_top,
			   mouse_track_width, 1);
	    }
	  else if (in_mode_line)
	    XDefineCursor (x_current_display,
			   f->display.x->window_desc,
			   f->display.x->modeline_cursor);
	  else
	    XDefineCursor (x_current_display,
			   f->display.x->window_desc,
			   f->display.x->nontext_cursor);
	}

      XFlush (x_current_display);
      UNBLOCK_INPUT;

      obj = read_char (-1);
      BLOCK_INPUT;
    }
  while (XTYPE (obj) == Lisp_Cons		   /* Mouse event */
	 && EQ (Fcar (Fcdr (Fcdr (obj))), Qnil)	   /* Not scrollbar */
	 && EQ (Vmouse_depressed, Qnil)              /* Only motion events */
	 && EQ (Vmouse_window, selected_window)	   /* In this window */
	 && x_mouse_frame);

  unread_command_char = obj;

  if (mouse_track_width)
    {
      x_rectangle (f, f->display.x->reverse_gc,
		   mouse_track_left, mouse_track_top,
		   mouse_track_width, 1);
      mouse_track_width = 0;
      if ((mouse_track_left == f->phys_cursor_x
	   || mouse_track_left - 1 == f->phys_cursor_x)
	  && mouse_track_top == f->phys_cursor_y)
	{
	  x_display_cursor (f, 1);
	}
    }
  XDefineCursor (x_current_display,
		 f->display.x->window_desc,
		 f->display.x->nontext_cursor);
  XFlush (x_current_display);
  UNBLOCK_INPUT;

  return Qnil;
}
#endif

#if 0
#include "glyphs.h"

/* Draw a pixmap specified by IMAGE_DATA of dimensions WIDTH and HEIGHT
   on the frame F at position X, Y. */

x_draw_pixmap (f, x, y, image_data, width, height)
     struct frame *f;
     int x, y, width, height;
     char *image_data;
{
  Pixmap image;

  image = XCreateBitmapFromData (x_current_display,
				 f->display.x->window_desc, image_data,
				 width, height);
  XCopyPlane (x_current_display, image, f->display.x->window_desc,
	      f->display.x->normal_gc, 0, 0, width, height, x, y);
}
#endif

#if 0

#ifdef HAVE_X11
#define XMouseEvent XEvent
#define WhichMouseButton xbutton.button
#define MouseWindow xbutton.window
#define MouseX xbutton.x
#define MouseY xbutton.y
#define MouseTime xbutton.time
#define ButtonReleased ButtonRelease
#define ButtonPressed ButtonPress
#else
#define XMouseEvent XButtonEvent
#define WhichMouseButton detail
#define MouseWindow window
#define MouseX x
#define MouseY y
#define MouseTime time
#endif /* X11 */

DEFUN ("x-mouse-events", Fx_mouse_events, Sx_mouse_events, 0, 0, 0,
  "Return number of pending mouse events from X window system.")
  ()
{
  return make_number (queue_event_count (&x_mouse_queue));
}

/* Encode the mouse button events in the form expected by the
   mouse code in Lisp.  For X11, this means moving the masks around. */

static int
encode_mouse_button (mouse_event)
     XMouseEvent mouse_event;
{
  register int event_code;
  register char key_mask;

  event_code = mouse_event.detail & 3;
  key_mask = (mouse_event.detail >> 8) & 0xf0;
  event_code |= key_mask >> 1;
  if (mouse_event.type == ButtonReleased) event_code |= 0x04;
  return event_code;
}

DEFUN ("x-get-mouse-event", Fx_get_mouse_event, Sx_get_mouse_event,
  0, 1, 0,
  "Get next mouse event out of mouse event buffer.\n\
Optional ARG non-nil means return nil immediately if no pending event;\n\
otherwise, wait for an event.  Returns a four-part list:\n\
  ((X-POS Y-POS) WINDOW FRAME-PART KEYSEQ TIMESTAMP).\n\
Normally X-POS and Y-POS are the position of the click on the frame\n\
 (measured in characters and lines), and WINDOW is the window clicked in.\n\
KEYSEQ is a string, the key sequence to be looked up in the mouse maps.\n\
If FRAME-PART is non-nil, the event was on a scrollbar;\n\
then Y-POS is really the total length of the scrollbar, while X-POS is\n\
the relative position of the scrollbar's value within that total length,\n\
and a third element OFFSET appears in that list: the height of the thumb-up\n\
area at the top of the scroll bar.\n\
FRAME-PART is one of the following symbols:\n\
 `vertical-scrollbar', `vertical-thumbup', `vertical-thumbdown',\n\
 `horizontal-scrollbar', `horizontal-thumbleft', `horizontal-thumbright'.\n\
TIMESTAMP is the lower 23 bits of the X-server's timestamp for\n\
the mouse event.")
  (arg)
     Lisp_Object arg;
{
  XMouseEvent xrep;
  register int com_letter;
  register Lisp_Object tempx;
  register Lisp_Object tempy;
  Lisp_Object part, pos, timestamp;
  int prefix;
  struct frame *f;
  
  int tem;
  
  while (1)
    {
      BLOCK_INPUT;
      tem = dequeue_event (&xrep, &x_mouse_queue);
      UNBLOCK_INPUT;
      
      if (tem)
	{
	  switch (xrep.type)
	    {
	    case ButtonPressed:
	    case ButtonReleased:

	      com_letter = encode_mouse_button (xrep);
	      mouse_timestamp = xrep.MouseTime;

	      if ((f = x_window_to_frame (xrep.MouseWindow)) != 0)
		{
		  Lisp_Object frame;
		  
		  if (f->display.x->icon_desc == xrep.MouseWindow)
		    {
		      x_make_frame_visible (f);
		      continue;
		    }

		  XSET (tempx, Lisp_Int,
			min (f->width-1, max (0, (xrep.MouseX - f->display.x->internal_border_width)/FONT_WIDTH (f->display.x->font))));
		  XSET (tempy, Lisp_Int,
			min (f->height-1, max (0, (xrep.MouseY - f->display.x->internal_border_width)/FONT_HEIGHT (f->display.x->font))));
		  XSET (timestamp, Lisp_Int, (xrep.MouseTime & 0x7fffff));
		  XSET (frame, Lisp_Frame, f);
		  
		  pos = Fcons (tempx, Fcons (tempy, Qnil));
		  Vmouse_window
		    = Flocate_window_from_coordinates (frame, pos);
		  
		  Vmouse_event
		    = Fcons (pos,
			     Fcons (Vmouse_window,
				    Fcons (Qnil,
					   Fcons (Fchar_to_string (make_number (com_letter)),
						  Fcons (timestamp, Qnil)))));
		  return Vmouse_event;
		}
	      else if ((f = x_window_to_scrollbar (xrep.MouseWindow, &part, &prefix)) != 0)
		{
		  int pos, len;
		  Lisp_Object keyseq;
		  char *partname;
		  
		  keyseq = concat2 (Fchar_to_string (make_number (prefix)),
				    Fchar_to_string (make_number (com_letter)));
		  
		  pos = xrep.MouseY - (f->display.x->v_scrollbar_width - 2);
		  XSET (tempx, Lisp_Int, pos);
		  len = ((FONT_HEIGHT (f->display.x->font) * f->height)
			 + f->display.x->internal_border_width
			 - (2 * (f->display.x->v_scrollbar_width - 2)));
		  XSET (tempy, Lisp_Int, len);
		  XSET (timestamp, Lisp_Int, (xrep.MouseTime & 0x7fffff));
		  Vmouse_window = f->selected_window;
		  Vmouse_event
		    = Fcons (Fcons (tempx, Fcons (tempy, 
						  Fcons (make_number (f->display.x->v_scrollbar_width - 2),
							 Qnil))),
			     Fcons (Vmouse_window,
				    Fcons (intern (part),
					   Fcons (keyseq, Fcons (timestamp,
								 Qnil)))));
		  return Vmouse_event;
		}
	      else
		continue;

#ifdef HAVE_X11
	    case MotionNotify:

	      com_letter = x11_encode_mouse_button (xrep);
	      if ((f = x_window_to_frame (xrep.MouseWindow)) != 0)
		{
		  Lisp_Object frame;
		  
		  XSET (tempx, Lisp_Int,
			min (f->width-1,
			     max (0, (xrep.MouseX - f->display.x->internal_border_width)
				  / FONT_WIDTH (f->display.x->font))));
		  XSET (tempy, Lisp_Int,
			min (f->height-1,
			     max (0, (xrep.MouseY - f->display.x->internal_border_width)
				  / FONT_HEIGHT (f->display.x->font))));
		  		  
		  XSET (frame, Lisp_Frame, f);
		  XSET (timestamp, Lisp_Int, (xrep.MouseTime & 0x7fffff));
		  
		  pos = Fcons (tempx, Fcons (tempy, Qnil));
		  Vmouse_window
		    = Flocate_window_from_coordinates (frame, pos);
		  
		  Vmouse_event
		    = Fcons (pos,
			     Fcons (Vmouse_window,
				    Fcons (Qnil,
					   Fcons (Fchar_to_string (make_number (com_letter)),
						  Fcons (timestamp, Qnil)))));
		  return Vmouse_event;
		}

	      break;
#endif /* HAVE_X11 */

	    default:
	      if (f = x_window_to_frame (xrep.MouseWindow))
		Vmouse_window = f->selected_window;
	      else if (f = x_window_to_scrollbar (xrep.MouseWindow, &part, &prefix))
		Vmouse_window = f->selected_window;
	      return Vmouse_event = Qnil;
	    }
	}
      
      if (!NILP (arg))
	return Qnil;

      /* Wait till we get another mouse event.  */
      wait_reading_process_input (0, 0, 2, 0);
    }
}
#endif


#ifndef HAVE_X11
DEFUN ("x-store-cut-buffer", Fx_store_cut_buffer, Sx_store_cut_buffer,
  1, 1, "sStore text in cut buffer: ",
  "Store contents of STRING into the cut buffer of the X window system.")
  (string)
     register Lisp_Object string;
{
  int mask;

  CHECK_STRING (string, 1);
  if (! FRAME_IS_X (selected_frame))
    error ("Selected frame does not understand X protocol.");

  BLOCK_INPUT;
  XStoreBytes ((char *) XSTRING (string)->data, XSTRING (string)->size);
  UNBLOCK_INPUT;

  return Qnil;
}

DEFUN ("x-get-cut-buffer", Fx_get_cut_buffer, Sx_get_cut_buffer, 0, 0, 0,
  "Return contents of cut buffer of the X window system, as a string.")
  ()
{
  int len;
  register Lisp_Object string;
  int mask;
  register char *d;

  BLOCK_INPUT;
  d = XFetchBytes (&len);
  string = make_string (d, len);
  XFree (d);
  UNBLOCK_INPUT;
  return string;
}
#endif	/* X10 */

#ifdef HAVE_X11
DEFUN ("x-rebind-key", Fx_rebind_key, Sx_rebind_key, 3, 3, 0,
"Rebind X keysym KEYSYM, with MODIFIERS, to generate NEWSTRING.\n\
KEYSYM is a string which conforms to the X keysym definitions found\n\
in X11/keysymdef.h, sans the initial XK_. MODIFIERS is nil or a\n\
list of strings specifying modifier keys such as Control_L, which must\n\
also be depressed for NEWSTRING to appear.")
  (x_keysym, modifiers, newstring)
     register Lisp_Object x_keysym;
     register Lisp_Object modifiers;
     register Lisp_Object newstring;
{
  char *rawstring;
  register KeySym keysym;
  KeySym modifier_list[16];

  CHECK_STRING (x_keysym, 1);
  CHECK_STRING (newstring, 3);

  keysym = XStringToKeysym ((char *) XSTRING (x_keysym)->data);
  if (keysym == NoSymbol)
    error ("Keysym does not exist");

  if (NILP (modifiers))
    XRebindKeysym (x_current_display, keysym, modifier_list, 0,
		   XSTRING (newstring)->data, XSTRING (newstring)->size);
  else
    {
      register Lisp_Object rest, mod;
      register int i = 0;

      for (rest = modifiers; !NILP (rest); rest = Fcdr (rest))
	{
	  if (i == 16)
	    error ("Can't have more than 16 modifiers");

	  mod = Fcar (rest);
	  CHECK_STRING (mod, 3);
	  modifier_list[i] = XStringToKeysym ((char *) XSTRING (mod)->data);
	  if (modifier_list[i] == NoSymbol
	      || !IsModifierKey (modifier_list[i]))
	    error ("Element is not a modifier keysym");
	  i++;
	}

      XRebindKeysym (x_current_display, keysym, modifier_list, i,
		     XSTRING (newstring)->data, XSTRING (newstring)->size);
    }

  return Qnil;
}
  
DEFUN ("x-rebind-keys", Fx_rebind_keys, Sx_rebind_keys, 2, 2, 0,
  "Rebind KEYCODE to list of strings STRINGS.\n\
STRINGS should be a list of 16 elements, one for each shift combination.\n\
nil as element means don't change.\n\
See the documentation of `x-rebind-key' for more information.")
  (keycode, strings)
     register Lisp_Object keycode;
     register Lisp_Object strings;
{
  register Lisp_Object item;
  register unsigned char *rawstring;
  KeySym rawkey, modifier[1];
  int strsize;
  register unsigned i;

  CHECK_NUMBER (keycode, 1);
  CHECK_CONS (strings, 2);
  rawkey = (KeySym) ((unsigned) (XINT (keycode))) & 255;
  for (i = 0; i <= 15; strings = Fcdr (strings), i++)
    {
      item = Fcar (strings);
      if (!NILP (item))
	{
	  CHECK_STRING (item, 2);
	  strsize = XSTRING (item)->size;
	  rawstring = (unsigned char *) xmalloc (strsize);
	  bcopy (XSTRING (item)->data, rawstring, strsize);
	  modifier[1] = 1 << i;
	  XRebindKeysym (x_current_display, rawkey, modifier, 1,
			 rawstring, strsize);
	}
    }
  return Qnil;
}
#else
DEFUN ("x-rebind-key", Fx_rebind_key, Sx_rebind_key, 3, 3, 0,
  "Rebind KEYCODE, with shift bits SHIFT-MASK, to new string NEWSTRING.\n\
KEYCODE and SHIFT-MASK should be numbers representing the X keyboard code\n\
and shift mask respectively.  NEWSTRING is an arbitrary string of keystrokes.\n\
If SHIFT-MASK is nil, then KEYCODE's key will be bound to NEWSTRING for\n\
all shift combinations.\n\
Shift Lock  1	   Shift    2\n\
Meta	    4	   Control  8\n\
\n\
For values of KEYCODE, see /usr/lib/Xkeymap.txt (remember that the codes\n\
in that file are in octal!)\n\
\n\
NOTE: due to an X bug, this function will not take effect unless one has\n\
a `~/.Xkeymap' file.  (See the documentation for the `keycomp' program.)\n\
This problem will be fixed in X version 11.")

  (keycode, shift_mask, newstring)
     register Lisp_Object keycode;
     register Lisp_Object shift_mask;
     register Lisp_Object newstring;
{
  char *rawstring;
  int keysym, rawshift;
  int i, strsize;
  
  CHECK_NUMBER (keycode, 1);
  if (!NILP (shift_mask))
    CHECK_NUMBER (shift_mask, 2);
  CHECK_STRING (newstring, 3);
  strsize = XSTRING (newstring)->size;
  rawstring = (char *) xmalloc (strsize);
  bcopy (XSTRING (newstring)->data, rawstring, strsize);

  keysym = ((unsigned) (XINT (keycode))) & 255;

  if (NILP (shift_mask))
    {
      for (i = 0; i <= 15; i++)
	XRebindCode (keysym, i<<11, rawstring, strsize);
    }
  else
    {
      rawshift = (((unsigned) (XINT (shift_mask))) & 15) << 11;
      XRebindCode (keysym, rawshift, rawstring, strsize);
    }
  return Qnil;
}
  
DEFUN ("x-rebind-keys", Fx_rebind_keys, Sx_rebind_keys, 2, 2, 0,
  "Rebind KEYCODE to list of strings STRINGS.\n\
STRINGS should be a list of 16 elements, one for each shift combination.\n\
nil as element means don't change.\n\
See the documentation of `x-rebind-key' for more information.")
  (keycode, strings)
     register Lisp_Object keycode;
     register Lisp_Object strings;
{
  register Lisp_Object item;
  register char *rawstring;
  KeySym rawkey, modifier[1];
  int strsize;
  register unsigned i;

  CHECK_NUMBER (keycode, 1);
  CHECK_CONS (strings, 2);
  rawkey = (KeySym) ((unsigned) (XINT (keycode))) & 255;
  for (i = 0; i <= 15; strings = Fcdr (strings), i++)
    {
      item = Fcar (strings);
      if (!NILP (item))
	{
	  CHECK_STRING (item, 2);
	  strsize = XSTRING (item)->size;
	  rawstring = (char *) xmalloc (strsize);
	  bcopy (XSTRING (item)->data, rawstring, strsize);
	  XRebindCode (rawkey, i << 11, rawstring, strsize);
	}
    }
  return Qnil;
}
#endif /* not HAVE_X11 */

#ifdef HAVE_X11
Visual *
select_visual (screen, depth)
     Screen *screen;
     unsigned int *depth;
{
  Visual *v;
  XVisualInfo *vinfo, vinfo_template;
  int n_visuals;

  v = DefaultVisualOfScreen (screen);
  vinfo_template.visualid = XVisualIDFromVisual (v);
  vinfo = XGetVisualInfo (x_current_display, VisualIDMask, &vinfo_template,
			  &n_visuals);
  if (n_visuals != 1)
    fatal ("Can't get proper X visual info");

  if ((1 << vinfo->depth) == vinfo->colormap_size)
    *depth = vinfo->depth;
  else
    {
      int i = 0;
      int n = vinfo->colormap_size - 1;
      while (n)
	{
	  n = n >> 1;
	  i++;
	}
      *depth = i;
    }

  XFree ((char *) vinfo);
  return v;
}
#endif /* HAVE_X11 */

DEFUN ("x-open-connection", Fx_open_connection, Sx_open_connection,
       1, 2, 0, "Open a connection to an X server.\n\
DISPLAY is the name of the display to connect to.  Optional second\n\
arg XRM_STRING is a string of resources in xrdb format.")
  (display, xrm_string)
     Lisp_Object display, xrm_string;
{
  unsigned int n_planes;
  register Screen *x_screen;
  unsigned char *xrm_option;

  CHECK_STRING (display, 0);
  if (x_current_display != 0)
    error ("X server connection is already initialized");

  /* This is what opens the connection and sets x_current_display.
     This also initializes many symbols, such as those used for input. */
  x_term_init (XSTRING (display)->data);

#ifdef HAVE_X11
  XFASTINT (Vwindow_system_version) = 11;

  if (!EQ (xrm_string, Qnil))
    {
      CHECK_STRING (xrm_string, 1);
      xrm_option = (unsigned char *) XSTRING (xrm_string);
    }
  else
    xrm_option = (unsigned char *) 0;
  xrdb = x_load_resources (x_current_display, xrm_option, EMACS_CLASS);
  x_current_display->db = xrdb;

  x_screen = DefaultScreenOfDisplay (x_current_display);

  x_screen_count = make_number (ScreenCount (x_current_display));
  Vx_vendor = build_string (ServerVendor (x_current_display));
  x_release = make_number (VendorRelease (x_current_display));
                    
  x_screen_height = make_number (HeightOfScreen (x_screen));
  x_screen_height_mm = make_number (HeightMMOfScreen (x_screen));
  x_screen_width = make_number (WidthOfScreen (x_screen));
  x_screen_width_mm = make_number (WidthMMOfScreen (x_screen));

  switch (DoesBackingStore (x_screen))
    {
    case Always:
      Vx_backing_store = intern ("Always");
      break;

    case WhenMapped:
      Vx_backing_store = intern ("WhenMapped");
      break;

    case NotUseful:
      Vx_backing_store = intern ("NotUseful");
      break;

    default:
      error ("Strange value for BackingStore.");
      break;
    }

  if (DoesSaveUnders (x_screen) == True)
    x_save_under = Qt;
  else
    x_save_under = Qnil;

  screen_visual = select_visual (x_screen, &n_planes);
  x_screen_planes = make_number (n_planes);
  Vx_screen_visual = intern (x_visual_strings [screen_visual->class]);

  /* X Atoms used by emacs. */
  BLOCK_INPUT;
  Xatom_emacs_selection =  XInternAtom (x_current_display, "_EMACS_SELECTION_",
					False);
  Xatom_clipboard =	   XInternAtom (x_current_display, "CLIPBOARD",
					False);
  Xatom_clipboard_selection = XInternAtom (x_current_display, "_EMACS_CLIPBOARD_",
					False);
  Xatom_wm_change_state =  XInternAtom (x_current_display, "WM_CHANGE_STATE",
					False);
  Xatom_incremental =	   XInternAtom (x_current_display, "INCR",
					False);
  Xatom_multiple =	   XInternAtom (x_current_display, "MULTIPLE",
					False);
  Xatom_targets =	   XInternAtom (x_current_display, "TARGETS",
					False);
  Xatom_timestamp =	   XInternAtom (x_current_display, "TIMESTAMP",
					False);
  Xatom_delete =	   XInternAtom (x_current_display, "DELETE",
					False);
  Xatom_insert_selection = XInternAtom (x_current_display, "INSERT_SELECTION",
					False);
  Xatom_pair =             XInternAtom (x_current_display, "XA_ATOM_PAIR",
					False);
  Xatom_insert_property =  XInternAtom (x_current_display, "INSERT_PROPERTY",
					False);
  Xatom_text =             XInternAtom (x_current_display, "TEXT",
					False);
  Xatom_wm_protocols =     XInternAtom (x_current_display, "WM_PROTOCOLS",
					False);
  Xatom_wm_take_focus =    XInternAtom (x_current_display, "WM_TAKE_FOCUS",
					False);
  Xatom_wm_save_yourself = XInternAtom (x_current_display, "WM_SAVE_YOURSELF",
					False);
  Xatom_wm_delete_window = XInternAtom (x_current_display, "WM_DELETE_WINDOW",
					False);
  Xatom_wm_change_state =  XInternAtom (x_current_display, "WM_CHANGE_STATE",
					False);
  Xatom_wm_configure_denied =  XInternAtom (x_current_display,
					    "WM_CONFIGURE_DENIED", False);
  Xatom_wm_window_moved =  XInternAtom (x_current_display, "WM_MOVED",
					False);
  UNBLOCK_INPUT;
#else /* not HAVE_X11 */
  XFASTINT (Vwindow_system_version) = 10;
#endif /* not HAVE_X11 */
  return Qnil;
}

DEFUN ("x-close-current-connection", Fx_close_current_connection,
       Sx_close_current_connection,
       0, 0, 0, "Close the connection to the current X server.")
  ()
{
#ifdef HAVE_X11
  /* This is ONLY used when killing emacs;  For switching displays
     we'll have to take care of setting CloseDownMode elsewhere. */

  if (x_current_display)
    {
      BLOCK_INPUT;
      XSetCloseDownMode (x_current_display, DestroyAll);
      XCloseDisplay (x_current_display);
    }
  else
    fatal ("No current X display connection to close\n");
#endif
  return Qnil;
}

DEFUN ("x-synchronize", Fx_synchronize, Sx_synchronize,
       1, 1, 0, "If ON is non-nil, report X errors as soon as the erring request is made.\n\
If ON is nil, allow buffering of requests.\n\
Turning on synchronization prohibits the Xlib routines from buffering\n\
requests and seriously degrades performance, but makes debugging much\n\
easier.")
  (on)
    Lisp_Object on;
{
  XSynchronize (x_current_display, !EQ (on, Qnil));

  return Qnil;
}


syms_of_xfns ()
{
  init_x_parm_symbols ();

  /* This is zero if not using X windows.  */
  x_current_display = 0;

  Qundefined_color = intern ("undefined-color");
  Fput (Qundefined_color, Qerror_conditions,
	Fcons (Qundefined_color, Fcons (Qerror, Qnil)));
  Fput (Qundefined_color, Qerror_message,
	build_string ("Undefined color"));

  DEFVAR_INT ("mouse-x-position", &x_mouse_x,
	      "The X coordinate of the mouse position, in characters.");
  x_mouse_x = Qnil;

  DEFVAR_INT ("mouse-y-position", &x_mouse_y,
	      "The Y coordinate of the mouse position, in characters.");
  x_mouse_y = Qnil;

  DEFVAR_INT ("mouse-buffer-offset", &mouse_buffer_offset,
	      "The buffer offset of the character under the pointer.");
  mouse_buffer_offset = Qnil;

  DEFVAR_INT ("x-pointer-shape", &Vx_pointer_shape,
	      "The shape of the pointer when over text.");
  Vx_pointer_shape = Qnil;

  DEFVAR_INT ("x-nontext-pointer-shape", &Vx_nontext_pointer_shape,
	      "The shape of the pointer when not over text.");
  Vx_nontext_pointer_shape = Qnil;

  DEFVAR_INT ("x-mode-pointer-shape", &Vx_mode_pointer_shape,
	      "The shape of the pointer when over the mode line.");
  Vx_mode_pointer_shape = Qnil;

  DEFVAR_LISP ("x-bar-cursor", &Vbar_cursor,
	       "*If non-nil, use a vertical bar cursor.  Otherwise, use the traditional box.");
  Vbar_cursor = Qnil;

  DEFVAR_LISP ("x-cursor-fore-pixel", &Vx_cursor_fore_pixel,
	       "A string indicating the foreground color of the cursor box.");
  Vx_cursor_fore_pixel = Qnil;

  DEFVAR_LISP ("mouse-grabbed", &Vmouse_depressed,
	       "Non-nil if a mouse button is currently depressed.");
  Vmouse_depressed = Qnil;

  DEFVAR_INT ("x-screen-count", &x_screen_count,
	      "The number of screens associated with the current display.");
  DEFVAR_INT ("x-release", &x_release,
	      "The release number of the X server in use.");
  DEFVAR_LISP ("x-vendor", &Vx_vendor,
	       "The vendor supporting the X server in use.");
  DEFVAR_INT ("x-screen-height", &x_screen_height,
	      "The height of this X screen in pixels.");
  DEFVAR_INT ("x-screen-height-mm", &x_screen_height_mm,
	      "The height of this X screen in millimeters.");
  DEFVAR_INT ("x-screen-width", &x_screen_width,
	      "The width of this X screen in pixels.");
  DEFVAR_INT ("x-screen-width-mm", &x_screen_width_mm,
	      "The width of this X screen in millimeters.");
  DEFVAR_LISP ("x-backing-store", &Vx_backing_store,
	       "The backing store capability of this screen.\n\
Values can be the symbols Always, WhenMapped, or NotUseful.");
  DEFVAR_BOOL ("x-save-under", &x_save_under,
	       "*Non-nil means this X screen supports the SaveUnder feature.");
  DEFVAR_INT ("x-screen-planes", &x_screen_planes,
	      "The number of planes this monitor supports.");
  DEFVAR_LISP ("x-screen-visual", &Vx_screen_visual,
	       "The default X visual for this X screen.");
  DEFVAR_LISP ("x-no-window-manager", &Vx_no_window_manager,
	       "t if no X window manager is in use.");

#ifdef HAVE_X11
  defsubr (&Sx_get_resource);
  defsubr (&Sx_pixel_width);
  defsubr (&Sx_pixel_height);
#if 0
  defsubr (&Sx_draw_rectangle);
  defsubr (&Sx_erase_rectangle);
  defsubr (&Sx_contour_region);
  defsubr (&Sx_uncontour_region);
#endif
  defsubr (&Sx_color_display_p);
  defsubr (&Sx_defined_color);
#if 0
  defsubr (&Sx_track_pointer);
  defsubr (&Sx_grab_pointer);
  defsubr (&Sx_ungrab_pointer);
#endif
#else
  defsubr (&Sx_get_default);
  defsubr (&Sx_store_cut_buffer);
  defsubr (&Sx_get_cut_buffer);
  defsubr (&Sx_set_face);
#endif
  defsubr (&Sx_geometry);
  defsubr (&Sx_create_frame);
  defsubr (&Sfocus_frame);
  defsubr (&Sunfocus_frame);
#if 0
  defsubr (&Sx_horizontal_line);
#endif
  defsubr (&Sx_rebind_key);
  defsubr (&Sx_rebind_keys);
  defsubr (&Sx_open_connection);
  defsubr (&Sx_close_current_connection);
  defsubr (&Sx_synchronize);

  /* This was used in the old event interface which used a separate
     event queue.*/
#if 0
  defsubr (&Sx_mouse_events);
  defsubr (&Sx_get_mouse_event);
#endif
}

#endif /* HAVE_X_WINDOWS */
