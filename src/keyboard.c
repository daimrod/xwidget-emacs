/* Keyboard and mouse input; editor command loop.
   Copyright (C) 1985, 1986, 1987, 1988, 1989, 1992 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 1, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */

/* Allow config.h to undefine symbols found here.  */
#include <signal.h>

#include "config.h"
#include <stdio.h>
#undef NULL
#include "termchar.h"
#include "termopts.h"
#include "lisp.h"
#include "termhooks.h"
#include "macros.h"
#include "frame.h"
#include "window.h"
#include "commands.h"
#include "buffer.h"
#include "disptab.h"
#include "keyboard.h"
#include <setjmp.h>
#include <errno.h>

#ifndef VMS
#include <sys/ioctl.h>
#endif

#include "syssignal.h"
#include "systty.h"
#include "systime.h"

extern int errno;

#ifdef HAVE_X_WINDOWS
extern Lisp_Object Vmouse_grabbed;

/* Make all keyboard buffers much bigger when using X windows.  */
#define KBD_BUFFER_SIZE 4096
#else	/* No X-windows, character input */
#define KBD_BUFFER_SIZE 256
#endif	/* No X-windows */

/* Following definition copied from eval.c */

struct backtrace
  {
    struct backtrace *next;
    Lisp_Object *function;
    Lisp_Object *args;	/* Points to vector of args. */
    int nargs;		/* length of vector.  If nargs is UNEVALLED,
			   args points to slot holding list of
			   unevalled args */
    char evalargs;
  };

/* Non-nil disable property on a command means
   do not execute it; call disabled-command-hook's value instead.  */
Lisp_Object Qdisabled, Vdisabled_command_hook;

#define NUM_RECENT_KEYS (100)
int recent_keys_index;	/* Index for storing next element into recent_keys */
int total_keys;		/* Total number of elements stored into recent_keys */
Lisp_Object recent_keys[NUM_RECENT_KEYS]; /* Holds last 100 keystrokes */

/* Buffer holding the key that invoked the current command.  */
Lisp_Object *this_command_keys;
int this_command_key_count;	/* Size in use.  */
int this_command_keys_size;	/* Size allocated.  */

extern int minbuf_level;

extern struct backtrace *backtrace_list;

/* Nonzero means do menu prompting.  */
static int menu_prompting;

/* Character to see next line of menu prompt.  */
static Lisp_Object menu_prompt_more_char;

/* For longjmp to where kbd input is being done.  */
static jmp_buf getcjmp;

/* True while doing kbd input.  */
int waiting_for_input;

/* True while displaying for echoing.   Delays C-g throwing.  */
static int echoing;

/* Nonzero means C-G should cause immediate error-signal.  */
int immediate_quit;

/* Character to recognize as the help char.  */
Lisp_Object help_char;

/* Form to execute when help char is typed.  */
Lisp_Object Vhelp_form;

/* Character that causes a quit.  Normally C-g.

   If we are running on an ordinary terminal, this must be an ordinary
   ASCII char, since we want to make it our interrupt character.

   If we are not running on an ordinary terminal, it still needs to be
   an ordinary ASCII char.  This character needs to be recognized in
   the input interrupt handler.  At this point, the keystroke is
   represented as a struct input_event, while the desired quit
   character is specified as a lispy event.  The mapping from struct
   input_events to lispy events cannot run in an interrupt handler,
   and the reverse mapping is difficult for anything but ASCII
   keystrokes.

   FOR THESE ELABORATE AND UNSATISFYING REASONS, quit_char must be an
   ASCII character.  */
int quit_char;

extern Lisp_Object current_global_map;
extern int minibuf_level;

/* Current depth in recursive edits.  */
int command_loop_level;

/* Total number of times command_loop has read a key sequence.  */
int num_input_keys;

/* Last input character read as a command.  */
Lisp_Object last_command_char;

/* Last input character read as a command, not counting menus
   reached by the mouse.  */
Lisp_Object last_nonmenu_event;

/* Last input character read for any purpose.  */
Lisp_Object last_input_char;

/* If not Qnil, an object to be read as the next command input.  */
Lisp_Object unread_command_char;

/* Char to use as prefix when a meta character is typed in.
   This is bound on entry to minibuffer in case ESC is changed there.  */

Lisp_Object meta_prefix_char;

/* Last size recorded for a current buffer which is not a minibuffer.  */
static int last_non_minibuf_size;

/* Number of idle seconds before an auto-save and garbage collection.  */
static Lisp_Object Vauto_save_timeout;

/* Total number of times read_char has returned.  */
int num_input_chars;

/* Total number of times read_char has returned, outside of macros.  */
int num_nonmacro_input_chars;

/* Auto-save automatically when this many characters have been typed
   since the last time.  */

static int auto_save_interval;

/* Value of num_nonmacro_input_chars as of last auto save.  */

int last_auto_save;

/* Last command executed by the editor command loop, not counting
   commands that set the prefix argument.  */

Lisp_Object last_command;

/* The command being executed by the command loop.
   Commands may set this, and the value set will be copied into last_command
   instead of the actual command.  */
Lisp_Object this_command;

#ifdef MULTI_FRAME
/* The frame in which the last input event occurred.
   command_loop_1 will select this frame before running the
   command bound to an event sequence, and read_key_sequence will
   toss the existing prefix if the user starts typing at a
   new frame.  */
Lisp_Object Vlast_event_frame;
#endif

/* The timestamp of the last input event we received from the X server.
   X Windows wants this for selection ownership.  */
unsigned long last_event_timestamp;

Lisp_Object Qself_insert_command;
Lisp_Object Qforward_char;
Lisp_Object Qbackward_char;

/* read_key_sequence stores here the command definition of the
   key sequence that it reads.  */
Lisp_Object read_key_sequence_cmd;

/* Form to evaluate (if non-nil) when Emacs is started.  */
Lisp_Object Vtop_level;

/* User-supplied string to translate input characters through.  */
Lisp_Object Vkeyboard_translate_table;

/* Keymap mapping ASCII function key sequences onto their preferred forms.  */
extern Lisp_Object Vfunction_key_map;

/* File in which we write all commands we read.  */
FILE *dribble;

/* Nonzero if input is available.  */
int input_pending;

/* Nonzero if should obey 0200 bit in input chars as "Meta".  */
int meta_key;

extern char *pending_malloc_warning;

/* Circular buffer for pre-read keyboard input.  */
static struct input_event kbd_buffer[KBD_BUFFER_SIZE];

/* Pointer to next available character in kbd_buffer.
   If kbd_fetch_ptr == kbd_store_ptr, the buffer is empty.
   This may be kbd_buffer + KBD_BUFFER_SIZE, meaning that the the
   next available char is in kbd_buffer[0].  */
static struct input_event *kbd_fetch_ptr;

/* Pointer to next place to store character in kbd_buffer.  This
   may be kbd_buffer + KBD_BUFFER_SIZE, meaning that the next
   character should go in kbd_buffer[0].  */
static struct input_event *kbd_store_ptr;

/* The above pair of variables forms a "queue empty" flag.  When we
   enqueue a non-hook event, we increment kbd_write_count.  When we
   dequeue a non-hook event, we increment kbd_read_count.  We say that
   there is input available iff the two counters are equal.

   Why not just have a flag set and cleared by the enqueuing and
   dequeuing functions?  Such a flag could be screwed up by interrupts
   at inopportune times.  */

/* If this flag is non-zero, mouse movement events will appear in the
   input stream.  If is zero, mouse movement will be ignored.  */
int do_mouse_tracking;

/* The window system handling code should set this if the mouse has
   moved since the last call to the mouse_position_hook.  Calling that
   hook should clear this.  Code assumes that if this is set, it can
   call mouse_position_hook to get the promised position, so don't set
   it unless you're prepared to substantiate the claim!  */
int mouse_moved;

/* True iff there is an event in kbd_buffer, or if mouse tracking is
   enabled and there is a new mouse position in the mouse movement
   buffer.  Note that if this is false, that doesn't mean that there
   is readable input; all the events in the queue might be button-up
   events, and do_mouse_tracking might be off.  */
#define EVENT_QUEUES_EMPTY \
  ((kbd_fetch_ptr == kbd_store_ptr) && (!do_mouse_tracking || !mouse_moved))


/* Symbols to head events.  */
Lisp_Object Qmouse_movement;

Lisp_Object Qvscrollbar_part;
Lisp_Object Qvslider_part;
Lisp_Object Qvthumbup_part;
Lisp_Object Qvthumbdown_part;

Lisp_Object Qhscrollbar_part;
Lisp_Object Qhslider_part;
Lisp_Object Qhthumbleft_part;
Lisp_Object Qhthumbright_part;

/* Symbols to denote kinds of events.  */
Lisp_Object Qfunction_key;
Lisp_Object Qmouse_click;
/* Lisp_Object Qmouse_movement; - also an event header */
Lisp_Object Qscrollbar_click;

/* Properties of event headers.  */
Lisp_Object Qevent_kind;
Lisp_Object Qevent_unmodified;

/* Symbols to use for non-text mouse positions.  */
Lisp_Object Qmode_line;
Lisp_Object Qvertical_line;


/* Address (if not 0) of EMACS_TIME to zero out if a SIGIO interrupt
   happens.  */
EMACS_TIME *input_available_clear_time;

/* Nonzero means use SIGIO interrupts; zero means use CBREAK mode.
   Default is 1 if INTERRUPT_INPUT is defined.  */
int interrupt_input;

/* Nonzero while interrupts are temporarily deferred during redisplay.  */
int interrupts_deferred;

/* nonzero means use ^S/^Q for flow control.  */
int flow_control;

/* Allow m- file to inhibit use of FIONREAD.  */
#ifdef BROKEN_FIONREAD
#undef FIONREAD
#endif

/* We are unable to use interrupts if FIONREAD is not available,
   so flush SIGIO so we won't try.  */
#ifndef FIONREAD
#ifdef SIGIO
#undef SIGIO
#endif
#endif

/* If we support X Windows, and won't get an interrupt when input
   arrives from the server, poll periodically so we can detect C-g.  */
#ifdef HAVE_X_WINDOWS
#ifndef SIGIO
#define POLL_FOR_INPUT
#endif
#endif

/* Global variable declarations.  */

/* Function for init_keyboard to call with no args (if nonzero).  */
void (*keyboard_init_hook) ();

static int read_avail_input ();
static void get_input_pending ();

/* > 0 if we are to echo keystrokes.  */
static int echo_keystrokes;

/* Nonzero means echo each character as typed.  */
static int immediate_echo;

/* The text we're echoing in the modeline - partial key sequences,
   usually.  '\0'-terminated.  */
static char echobuf[100];

/* Where to append more text to echobuf if we want to.  */
static char *echoptr;

#define	min(a,b)	((a)<(b)?(a):(b))
#define	max(a,b)	((a)>(b)?(a):(b))

/* Install the string STR as the beginning of the string of echoing,
   so that it serves as a prompt for the next character.
   Also start echoing.  */

echo_prompt (str)
     char *str;
{
  int len = strlen (str);
  if (len > sizeof echobuf - 4)
    len = sizeof echobuf - 4;
  bcopy (str, echobuf, len + 1);
  echoptr = echobuf + len;

  echo ();
}

/* Add C to the echo string, if echoing is going on.  
   C can be a character, which is printed prettily ("M-C-x" and all that
   jazz), or a symbol, whose name is printed.  */

echo_char (c)
     Lisp_Object c;
{
  extern char *push_key_description ();

  if (immediate_echo)
    {
      char *ptr = echoptr;
      
      if (ptr != echobuf)
	*ptr++ = ' ';

      /* If someone has passed us a composite event, use its head symbol.  */
      if (EVENT_HAS_PARAMETERS (c))
	c = EVENT_HEAD (c);

      if (XTYPE (c) == Lisp_Int)
	{
	  if (ptr - echobuf > sizeof echobuf - 6)
	    return;

	  ptr = push_key_description (c, ptr);
	}
      else if (XTYPE (c) == Lisp_Symbol)
	{
	  struct Lisp_String *name = XSYMBOL (c)->name;
	  if (((ptr - echobuf) + name->size + 4) > sizeof echobuf)
	    return;
	  bcopy (name->data, ptr, name->size);
	  ptr += name->size;
	}

      if (echoptr == echobuf && c == help_char)
	{
	  strcpy (ptr, " (Type ? for further options)");
	  ptr += strlen (ptr);
	}

      *ptr = 0;
      echoptr = ptr;

      echo ();
    }
}

/* Temporarily add a dash to the end of the echo string if it's not
   empty, so that it serves as a mini-prompt for the very next character.  */

echo_dash ()
{
  if (!immediate_echo && echoptr == echobuf)
    return;

  /* Put a dash at the end of the buffer temporarily,
     but make it go away when the next character is added.  */
  echoptr[0] = '-';
  echoptr[1] = 0;

  echo ();
}

/* Display the current echo string, and begin echoing if not already
   doing so.  */

echo ()
{
  if (!immediate_echo)
    {
      int i;
      immediate_echo = 1;

      for (i = 0; i < this_command_key_count; i++)
	echo_char (this_command_keys[i]);
      echo_dash ();
    }

  echoing = 1;
  message1 (echobuf);
  echoing = 0;

  if (waiting_for_input && !NILP (Vquit_flag))
    quit_throw_to_read_char ();
}

/* Turn off echoing, for the start of a new command.  */

cancel_echoing ()
{
  immediate_echo = 0;
  echoptr = echobuf;
}

/* Return the length of the current echo string.  */

static int
echo_length ()
{
  return echoptr - echobuf;
}

/* Truncate the current echo message to its first LEN chars.
   This and echo_char get used by read_key_sequence when the user
   switches frames while entering a key sequence.  */

static void
echo_truncate (len)
     int len;
{
  echobuf[len] = '\0';
  echoptr = echobuf + strlen (echobuf);
}


/* Functions for manipulating this_command_keys.  */
static void
add_command_key (key)
     Lisp_Object key;
{
  if (this_command_key_count == this_command_keys_size)
    {
      this_command_keys_size *= 2;
      this_command_keys
	= (Lisp_Object *) xrealloc (this_command_keys,
				    (this_command_keys_size
				     * sizeof (Lisp_Object)));
    }
  this_command_keys[this_command_key_count++] = key;
}

Lisp_Object
recursive_edit_1 ()
{
  int count = specpdl_ptr - specpdl;
  Lisp_Object val;

  if (command_loop_level > 0)
    {
      specbind (Qstandard_output, Qt);
      specbind (Qstandard_input, Qt);
    }

  val = command_loop ();
  if (EQ (val, Qt))
    Fsignal (Qquit, Qnil);

  unbind_to (count);
  return Qnil;
}

/* When an auto-save happens, record the "time", and don't do again soon.  */
record_auto_save ()
{
  last_auto_save = num_nonmacro_input_chars;
}

Lisp_Object recursive_edit_unwind (), command_loop ();

DEFUN ("recursive-edit", Frecursive_edit, Srecursive_edit, 0, 0, "",
  "Invoke the editor command loop recursively.\n\
To get out of the recursive edit, a command can do `(throw 'exit nil)';\n\
that tells this function to return.\n\
Alternately, `(throw 'exit t)' makes this function signal an error.\n\
This function is called by the editor initialization to begin editing.")
  ()
{
  int count = specpdl_ptr - specpdl;
  Lisp_Object val;

  command_loop_level++;
  update_mode_lines = 1;

  record_unwind_protect (recursive_edit_unwind,
			 (command_loop_level
			  && current_buffer != XBUFFER (XWINDOW (selected_window)->buffer))
			 ? Fcurrent_buffer ()
			 : Qnil);
  recursive_edit_1 ();
  return unbind_to (count, Qnil);
}

Lisp_Object
recursive_edit_unwind (buffer)
     Lisp_Object buffer;
{
  if (!NILP (buffer))
    Fset_buffer (buffer);

  command_loop_level--;
  update_mode_lines = 1;
  return Qnil;
}

Lisp_Object
cmd_error (data)
     Lisp_Object data;
{
  Lisp_Object errmsg, tail, errname, file_error;
  Lisp_Object stream;
  struct gcpro gcpro1;
  int i;

  Vquit_flag = Qnil;
  Vinhibit_quit = Qt;
  Vstandard_output = Qt;
  Vstandard_input = Qt;
  Vexecuting_macro = Qnil;
  echo_area_glyphs = 0;

  /* If the window system or terminal frame hasn't been initialized
     yet, or we're not interactive, it's best to dump this message out
     to stderr and exit.  */
  if (! FRAME_MESSAGE_BUF (selected_frame)
      || noninteractive)
    stream = Qexternal_debugging_output;
  else
    {
      Fdiscard_input ();
      bitch_at_user ();
      stream = Qt;
    }

  errname = Fcar (data);

  if (EQ (errname, Qerror))
    {
      data = Fcdr (data);
      if (!CONSP (data)) data = Qnil;
      errmsg = Fcar (data);
      file_error = Qnil;
    }
  else
    {
      errmsg = Fget (errname, Qerror_message);
      file_error = Fmemq (Qfile_error,
			  Fget (errname, Qerror_conditions));
    }

  /* Print an error message including the data items.
     This is done by printing it into a scratch buffer
     and then making a copy of the text in the buffer. */

  if (!CONSP (data)) data = Qnil;
  tail = Fcdr (data);
  GCPRO1 (tail);

  /* For file-error, make error message by concatenating
     all the data items.  They are all strings.  */
  if (!NILP (file_error) && !NILP (tail))
    errmsg = XCONS (tail)->car, tail = XCONS (tail)->cdr;

  if (XTYPE (errmsg) == Lisp_String)
    Fprinc (errmsg, stream);
  else
    write_string_1 ("peculiar error", -1, stream);

  for (i = 0; CONSP (tail); tail = Fcdr (tail), i++)
    {
      write_string_1 (i ? ", " : ": ", 2, stream);
      if (!NILP (file_error))
	Fprinc (Fcar (tail), stream);
      else
	Fprin1 (Fcar (tail), stream);
    }
  UNGCPRO;

  /* If the window system or terminal frame hasn't been initialized
     yet, or we're in -batch mode, this error should cause Emacs to exit.  */
  if (! FRAME_MESSAGE_BUF (selected_frame)
      || noninteractive)
    {
      Fterpri (stream);
      Fkill_emacs (make_number (-1));
    }

  Vquit_flag = Qnil;

  Vinhibit_quit = Qnil;
  return make_number (0);
}

Lisp_Object command_loop_1 ();
Lisp_Object command_loop_2 ();
Lisp_Object top_level_1 ();

/* Entry to editor-command-loop.
   This level has the catches for exiting/returning to editor command loop.
   It returns nil to exit recursive edit, t to abort it.  */

Lisp_Object
command_loop ()
{
  if (command_loop_level > 0 || minibuf_level > 0)
    {
      return internal_catch (Qexit, command_loop_2, Qnil);
    }
  else
    while (1)
      {
	internal_catch (Qtop_level, top_level_1, Qnil);
	internal_catch (Qtop_level, command_loop_2, Qnil);
	
	/* End of file in -batch run causes exit here.  */
	if (noninteractive)
	  Fkill_emacs (Qt);
      }
}

/* Here we catch errors in execution of commands within the
   editing loop, and reenter the editing loop.
   When there is an error, cmd_error runs and returns a non-nil
   value to us.  A value of nil means that cmd_loop_1 itself
   returned due to end of file (or end of kbd macro).  */

Lisp_Object
command_loop_2 ()
{
  register Lisp_Object val;

  do
    val = internal_condition_case (command_loop_1, Qerror, cmd_error);
  while (!NILP (val));

  return Qnil;
}

Lisp_Object
top_level_2 ()
{
  return Feval (Vtop_level);
}

Lisp_Object
top_level_1 ()
{
  /* On entry to the outer level, run the startup file */
  if (!NILP (Vtop_level))
    internal_condition_case (top_level_2, Qerror, cmd_error);
  else if (!NILP (Vpurify_flag))
    message ("Bare impure Emacs (standard Lisp code not loaded)");
  else
    message ("Bare Emacs (standard Lisp code not loaded)");
  return Qnil;
}

DEFUN ("top-level", Ftop_level, Stop_level, 0, 0, "",
  "Exit all recursive editing levels.")
  ()
{
  Fthrow (Qtop_level, Qnil);
}

DEFUN ("exit-recursive-edit", Fexit_recursive_edit, Sexit_recursive_edit, 0, 0, "",
  "Exit from the innermost recursive edit or minibuffer.")
  ()
{
  if (command_loop_level > 0 || minibuf_level > 0)
    Fthrow (Qexit, Qnil);

  error ("No recursive edit is in progress");
}

DEFUN ("abort-recursive-edit", Fabort_recursive_edit, Sabort_recursive_edit, 0, 0, "",
  "Abort the command that requested this recursive edit or minibuffer input.")
  ()
{
  if (command_loop_level > 0 || minibuf_level > 0)
    Fthrow (Qexit, Qt);

  error ("No recursive edit is in progress");
}

/* This is the actual command reading loop,
   sans error-handling encapsulation.  */

Lisp_Object Fcommand_execute ();
static int read_key_sequence ();

Lisp_Object
command_loop_1 ()
{
  Lisp_Object cmd;
  int lose;
  int nonundocount;
  Lisp_Object keybuf[30];
  int i;
  int no_redisplay;
  int no_direct;

  Vprefix_arg = Qnil;
  waiting_for_input = 0;
  cancel_echoing ();

  /* Don't clear out last_command at the beginning of a macro.  */
  if (XTYPE (Vexecuting_macro) != Lisp_String)
    last_command = Qt;

  nonundocount = 0;
  no_redisplay = 0;
  this_command_key_count = 0;

  while (1)
    {
      /* Install chars successfully executed in kbd macro.  */

      if (defining_kbd_macro && NILP (Vprefix_arg))
	finalize_kbd_macro_chars ();

      /* Make sure the current window's buffer is selected.  */
      if (XBUFFER (XWINDOW (selected_window)->buffer) != current_buffer)
	set_buffer_internal (XBUFFER (XWINDOW (selected_window)->buffer));

      /* Display any malloc warning that just came out.  Use while because
	 displaying one warning can cause another.  */

      while (pending_malloc_warning)
	display_malloc_warning ();

      no_direct = 0;

      /* If minibuffer on and echo area in use,
	 wait 2 sec and redraw minibufer.  */

      if (minibuf_level && echo_area_glyphs)
	{
	  /* Bind inhibit-quit to t so that C-g gets read in
	     rather than quitting back to the minibuffer.  */
	  int count = specpdl_ptr - specpdl;
	  specbind (Qinhibit_quit, Qt);
	  Fsit_for (make_number (2), Qnil, Qnil);
	  unbind_to (count);

	  echo_area_glyphs = 0;
	  no_direct = 1;
	  if (!NILP (Vquit_flag))
	    {
	      Vquit_flag = Qnil;
	      unread_command_char = make_number (quit_char);
	    }
	}

#ifdef C_ALLOCA
	  alloca (0);		/* Cause a garbage collection now */
				/* Since we can free the most stuff here.  */
#endif /* C_ALLOCA */

      /* Read next key sequence; i gets its length.  */
      i = read_key_sequence (keybuf, (sizeof keybuf / sizeof (keybuf[0])), 0);

      ++num_input_keys;

#ifdef MULTI_FRAME
      /* Select the frame that the key sequence came from.  */
      if (XTYPE (Vlast_event_frame) == Lisp_Frame
	  && XFRAME (Vlast_event_frame) != selected_frame)
	Fselect_frame (Vlast_event_frame, Qnil);
#endif

      /* Now we have read a key sequence of length I,
	 or else I is 0 and we found end of file.  */

      if (i == 0)		/* End of file -- happens only in */
	return Qnil;		/* a kbd macro, at the end.  */

      last_command_char = keybuf[i - 1];

      cmd = read_key_sequence_cmd;
      if (!NILP (Vexecuting_macro))
	{
	  if (!NILP (Vquit_flag))
	    {
	      Vexecuting_macro = Qt;
	      QUIT;		/* Make some noise. */
				/* Will return since macro now empty. */
	    }
	}

      /* Do redisplay processing after this command except in special
	 cases identified below that set no_redisplay to 1.  */
      no_redisplay = 0;

      /* Execute the command.  */

      if (NILP (cmd))
	{
	  /* nil means key is undefined.  */
	  bitch_at_user ();
	  defining_kbd_macro = 0;
	  update_mode_lines = 1;
	  Vprefix_arg = Qnil;
	}
      else
	{
	  this_command = cmd;
	  if (NILP (Vprefix_arg) && ! no_direct)
	    {
	      /* Recognize some common commands in common situations and
		 do them directly.  */
	      if (EQ (cmd, Qforward_char) && point < ZV)
		{
                  struct Lisp_Vector *dp
		    = window_display_table (XWINDOW (selected_window));
		  lose = FETCH_CHAR (point);
		  SET_PT (point + 1);
		  if (((dp == 0 && lose >= 040 && lose < 0177)
		       ||
		       (dp && (XTYPE (dp->contents[lose]) != Lisp_String
			       || XSTRING (dp->contents[lose])->size == sizeof (GLYPH))))
		      && (XFASTINT (XWINDOW (selected_window)->last_modified)
			  >= MODIFF)
		      && (XFASTINT (XWINDOW (selected_window)->last_point)
			  == point - 1)
		      && !windows_or_buffers_changed
		      && EQ (current_buffer->selective_display, Qnil)
		      && !detect_input_pending ()
		      && NILP (Vexecuting_macro))
		    no_redisplay = direct_output_forward_char (1);
		  goto directly_done;
		}
	      else if (EQ (cmd, Qbackward_char) && point > BEGV)
		{
                  struct Lisp_Vector *dp
		    = window_display_table (XWINDOW (selected_window));
		  SET_PT (point - 1);
		  lose = FETCH_CHAR (point);
		  if (((dp == 0 && lose >= 040 && lose < 0177)
		       ||
		       (dp && (XTYPE (dp->contents[lose]) != Lisp_String
			       || XSTRING (dp->contents[lose])->size == sizeof (GLYPH))))
		      && (XFASTINT (XWINDOW (selected_window)->last_modified)
			  >= MODIFF)
		      && (XFASTINT (XWINDOW (selected_window)->last_point)
			  == point + 1)
		      && !windows_or_buffers_changed
		      && EQ (current_buffer->selective_display, Qnil)
		      && !detect_input_pending ()
		      && NILP (Vexecuting_macro))
		    no_redisplay = direct_output_forward_char (-1);
		  goto directly_done;
		}
	      else if (EQ (cmd, Qself_insert_command)
		       /* Try this optimization only on ascii keystrokes.  */
		       && XTYPE (last_command_char) == Lisp_Int)
		{
		  unsigned char c = XINT (last_command_char);

		  if (NILP (Vexecuting_macro) &&
		      !EQ (minibuf_window, selected_window))
		    {
		      if (!nonundocount || nonundocount >= 20)
			{
			  Fundo_boundary ();
			  nonundocount = 0;
			}
		      nonundocount++;
		    }
		  lose = (XFASTINT (XWINDOW (selected_window)->last_modified)
			  < MODIFF)
		    || (XFASTINT (XWINDOW (selected_window)->last_point)
			  != point)
		    || MODIFF <= current_buffer->save_modified
		    || windows_or_buffers_changed
		    || !EQ (current_buffer->selective_display, Qnil)
		    || detect_input_pending ()
		    || !NILP (Vexecuting_macro);
		  if (internal_self_insert (c, 0))
		    {
		      lose = 1;
		      nonundocount = 0;
		    }
		  if (!lose &&
		      (point == ZV || FETCH_CHAR (point) == '\n'))
		    {
		      struct Lisp_Vector *dp
			= window_display_table (XWINDOW (selected_window));

		      if (dp == 0 || XTYPE (dp->contents[c]) != Lisp_String)
			no_redisplay = direct_output_for_insert (c);
		      else if (XSTRING (dp->contents[c])->size
			       == sizeof (GLYPH))
		        no_redisplay =
			  direct_output_for_insert (*(GLYPH *)XSTRING (dp->contents[c])->data);
		    }
		  goto directly_done;
		}
	    }

	  /* Here for a command that isn't executed directly */

	  nonundocount = 0;
	  if (NILP (Vprefix_arg))
	    Fundo_boundary ();
	  Fcommand_execute (cmd, Qnil);

	}
    directly_done: ;

      /* If there is a prefix argument,
	 1) We don't want last_command to be ``universal-argument''
	 (that would be dumb), so don't set last_command,
	 2) we want to leave echoing on so that the prefix will be
	 echoed as part of this key sequence, so don't call
	 cancel_echoing, and
	 3) we want to leave this_command_key_count non-zero, so that
	 read_char will realize that it is re-reading a character, and
	 not echo it a second time.  */
      if (NILP (Vprefix_arg))
	{
	  last_command = this_command;
	  cancel_echoing ();
	  this_command_key_count = 0;
	}
    }
}

/* Number of seconds between polling for input.  */
int polling_period;

/* Nonzero means polling for input is temporarily suppresed.  */
int poll_suppress_count;

#ifdef POLL_FOR_INPUT
int polling_for_input;

/* Handle an alarm once each second and read pending input
   so as to handle a C-g if it comces in.  */

SIGTYPE
input_poll_signal ()
{
#ifdef HAVE_X_WINDOWS
  extern int x_input_blocked;
  if (x_input_blocked == 0)
#endif
    if (!waiting_for_input)
      read_avail_input (0);
  signal (SIGALRM, input_poll_signal);
  alarm (polling_period);
}

#endif

/* Begin signals to poll for input, if they are appropriate.
   This function is called unconditionally from various places.  */

start_polling ()
{
#ifdef POLL_FOR_INPUT
  if (read_socket_hook)
    {
      poll_suppress_count--;
      if (poll_suppress_count == 0)
	{
	  signal (SIGALRM, input_poll_signal);
	  polling_for_input = 1;
	  alarm (polling_period);
	}
    }
#endif
}

/* Turn off polling.  */

stop_polling ()
{
#ifdef POLL_FOR_INPUT
  if (read_socket_hook)
    {
      if (poll_suppress_count == 0)
	{
	  polling_for_input = 0;
	  alarm (0);
	}
      poll_suppress_count++;
    }
#endif
}

/* Input of single characters from keyboard */

Lisp_Object print_help ();
static Lisp_Object kbd_buffer_get_event ();

/* read a character from the keyboard; call the redisplay if needed */
/* commandflag 0 means do not do auto-saving, but do do redisplay.
   -1 means do not do redisplay, but do do autosaving.
   1 means do both.  */

/* The arguments MAPS and NMAPS are for menu prompting.
   MAPS is an array of keymaps;  NMAPS is the length of MAPS.

   PREV_EVENT is the previous input event, or nil if we are reading
   the first event of a key sequence.

   If we use a mouse menu to read the input, we store 1 into *USED_MOUSE_MENU.
   Otherwise we store 0 there.  */

Lisp_Object
read_char (commandflag, nmaps, maps, prev_event, used_mouse_menu)
     int commandflag;
     int nmaps;
     Lisp_Object *maps;
     Lisp_Object prev_event;
     int *used_mouse_menu;
{
  register Lisp_Object c;
  int count;
  jmp_buf save_jump;

  if (!NILP (unread_command_char))
    {
      c = unread_command_char;
      unread_command_char = Qnil;

      if (this_command_key_count == 0)
	goto reread_first;
      else
	goto reread;
    }

  if (!NILP (Vexecuting_macro))
    {
      if (executing_macro_index >= Flength (Vexecuting_macro))
	{
	  XSET (c, Lisp_Int, -1);
	  return c;
	}
      
      c = Faref (Vexecuting_macro, make_number (executing_macro_index));
      executing_macro_index++;

      goto from_macro;
    }

  /* Save outer setjmp data, in case called recursively.  */
  save_getcjmp (save_jump);

  stop_polling ();

  if (commandflag >= 0 && !input_pending && !detect_input_pending ())
    redisplay ();

  if (_setjmp (getcjmp))
    {
      XSET (c, Lisp_Int, quit_char);
#ifdef MULTI_FRAME
      XSET (Vlast_event_frame, Lisp_Frame, selected_frame);
#endif

      goto non_reread;
    }

  /* Message turns off echoing unless more keystrokes turn it on again. */
  if (echo_area_glyphs && *echo_area_glyphs && echo_area_glyphs != echobuf)
    cancel_echoing ();
  else
    /* If already echoing, continue.  */
    echo_dash ();

  /* If in middle of key sequence and minibuffer not active,
     start echoing if enough time elapses.  */
  if (minibuf_level == 0 && !immediate_echo && this_command_key_count > 0
      && echo_keystrokes > 0
      && (echo_area_glyphs == 0 || *echo_area_glyphs == 0))
    {
      Lisp_Object tem0;

      /* After a mouse event, start echoing right away.
	 This is because we are probably about to display a menu,
	 and we don't want to delay before doing so.  */
      if (XTYPE (prev_event) == Lisp_Cons)
	echo ();
      else
	{
	  tem0 = sit_for (echo_keystrokes, 0, 1, 1);
	  if (EQ (tem0, Qt))
	    echo ();
	}
    }

  /* Maybe auto save due to number of keystrokes or idle time.  */

  if (commandflag != 0
      && auto_save_interval > 0
      && num_nonmacro_input_chars - last_auto_save > max (auto_save_interval, 20)
      && !detect_input_pending ())
    {
      jmp_buf temp;
      save_getcjmp (temp);
      Fdo_auto_save (Qnil, Qnil);
      restore_getcjmp (temp);
    }

  /* Try reading a character via menu prompting.
     Try this before the sit-for, because the sit-for
     would do the wrong thing if we are supposed to do
     menu prompting.  */
  c = Qnil;
  if (INTERACTIVE && !NILP (prev_event))
    c = read_char_menu_prompt (nmaps, maps, prev_event, used_mouse_menu);

  /* Slow down auto saves logarithmically in size of current buffer,
     and garbage collect while we're at it.  */
  if (NILP (c))
    {
      int delay_level, buffer_size;

      if (! MINI_WINDOW_P (XWINDOW (selected_window)))
	last_non_minibuf_size = Z - BEG;
      buffer_size = (last_non_minibuf_size >> 8) + 1;
      delay_level = 0;
      while (buffer_size > 64)
	delay_level++, buffer_size -= buffer_size >> 2;
      if (delay_level < 4) delay_level = 4;
      /* delay_level is 4 for files under around 50k, 7 at 100k,
	 9 at 200k, 11 at 300k, and 12 at 500k.  It is 15 at 1 meg.  */

      /* Auto save if enough time goes by without input.  */
      if (commandflag != 0
	  && num_nonmacro_input_chars > last_auto_save
	  && XTYPE (Vauto_save_timeout) == Lisp_Int
	  && XINT (Vauto_save_timeout) > 0)
	{
	  Lisp_Object tem0;
	  int delay = delay_level * XFASTINT (Vauto_save_timeout) / 4;
	  tem0 = sit_for (delay, 0, 1, 1);
	  if (EQ (tem0, Qt))
	    {
	      jmp_buf temp;
	      save_getcjmp (temp);
	      Fdo_auto_save (Qnil, Qnil);
	      restore_getcjmp (temp);

	      /* If we have auto-saved and there is still no input
		 available, garbage collect if there has been enough
		 consing going on to make it worthwhile.  */
	      if (!detect_input_pending ()
		  && consing_since_gc > gc_cons_threshold / 2)
		Fgarbage_collect ();
	    }
	}
    }

  /* Actually read a character, waiting if necessary.  */
  if (NILP (c))
    c = kbd_buffer_get_event ();

  if (NILP (c))
    abort ();			/* Don't think this can happen. */

  /* Terminate Emacs in batch mode if at eof.  */
  if (noninteractive && XTYPE (c) == Lisp_Int && XINT (c) < 0)
    Fkill_emacs (make_number (1));

 non_reread:

  restore_getcjmp (save_jump);

  start_polling ();

  echo_area_glyphs = 0;

  /* Handle things that only apply to characters.  */
  if (XTYPE (c) == Lisp_Int)
    {
      /* If kbd_buffer_get_event gave us an EOF, return that.  */
      if (XINT (c) < 0)
	return c;

      /* Strip the high bits, and maybe the meta bit too.  */
      XSETINT (c, c & (meta_key ? 0377 : 0177));

      if (XTYPE (Vkeyboard_translate_table) == Lisp_String
	  && XSTRING (Vkeyboard_translate_table)->size > XINT (c))
	XSETINT (c, XSTRING (Vkeyboard_translate_table)->data[c]);
    }

  total_keys++;
  recent_keys[recent_keys_index] = c;
  if (++recent_keys_index >= (sizeof (recent_keys)/sizeof(recent_keys[0])))
    recent_keys_index = 0;

  /* Write c to the dribble file.  If c is a lispy event, write
     the event's symbol to the dribble file, in <brackets>.  Bleaugh.
     If you, dear reader, have a better idea, you've got the source.  :-) */
  if (dribble)
    {
      if (XTYPE (c) == Lisp_Int)
	putc (c, dribble);
      else
	{
	  Lisp_Object dribblee = c;

	  /* If it's a structured event, take the event header.  */
	  if (EVENT_HAS_PARAMETERS (dribblee))
	    dribblee = EVENT_HEAD (dribblee);

	  if (XTYPE (c) == Lisp_Symbol)
	    {
	      putc ('<', dribble);
	      fwrite (XSYMBOL (c)->name->data, sizeof (char),
		      XSYMBOL (c)->name->size,
		      dribble);
	      putc ('>', dribble);
	    }
	}

      fflush (dribble);
    }

  store_kbd_macro_char (c);

  num_nonmacro_input_chars++;

 from_macro:
 reread_first:
  echo_char (c);

  /* Record this character as part of the current key.  */
  add_command_key (c);

  /* Re-reading in the middle of a command */
 reread:
  last_input_char = c;
  num_input_chars++;

  /* Process the help character specially if enabled */
  if (EQ (c, help_char) && !NILP (Vhelp_form))
    {
      Lisp_Object tem0;
      count = specpdl_ptr - specpdl;

      record_unwind_protect (Fset_window_configuration,
			     Fcurrent_window_configuration (Qnil));

      tem0 = Feval (Vhelp_form);
      if (XTYPE (tem0) == Lisp_String)
	internal_with_output_to_temp_buffer ("*Help*", print_help, tem0);

      cancel_echoing ();
      c = read_char (0);
      /* Remove the help from the frame */
      unbind_to (count, Qnil);
      redisplay ();
      if (EQ (c, make_number (040)))
	{
	  cancel_echoing ();
	  c = read_char (0, 0, 0, Qnil, 0);
	}
    }

  return c;
}

Lisp_Object
print_help (object)
     Lisp_Object object;
{
  Fprinc (object, Qnil);
  return Qnil;
}

/* Copy out or in the info on where C-g should throw to.
   This is used when running Lisp code from within get_char,
   in case get_char is called recursively.
   See read_process_output.  */

save_getcjmp (temp)
     jmp_buf temp;
{
  bcopy (getcjmp, temp, sizeof getcjmp);
}

restore_getcjmp (temp)
     jmp_buf temp;
{
  bcopy (temp, getcjmp, sizeof getcjmp);
}


/* Low level keyboard/mouse input.
   kbd_buffer_store_event places events in kbd_buffer, and
   kbd_buffer_get_event retrieves them.
   mouse_moved indicates when the mouse has moved again, and
   *mouse_position_hook provides the mouse position.  */

/* Set this for debugging, to have a way to get out */
int stop_character;

extern int frame_garbaged;

/* Return true iff there are any events in the queue that read-char
   would return.  If this returns false, a read-char would block.  */
static int
readable_events ()
{
  struct input_event *ep;

  if (EVENT_QUEUES_EMPTY)
    return 0;

  if (do_mouse_tracking)
    return 1;

  /* Mouse tracking is disabled, so we need to actually scan the
     input queue to see if any events are currently readable.  */
  for (ep = kbd_fetch_ptr; ep != kbd_store_ptr; ep++)
    {
      if (ep == kbd_buffer + KBD_BUFFER_SIZE)
	ep = kbd_buffer;
	
      /* Skip button-up events.  */
      if ((ep->kind == mouse_click || ep->kind == scrollbar_click)
	  && (ep->modifiers & up_modifier))
	continue;

      return 1;
    }
    
  return 0;
}


/* Restore mouse tracking enablement.  See Ftrack_mouse for the only use
   of this function.  */
static Lisp_Object
tracking_off (old_value)
     Lisp_Object old_value;
{
  if (! XFASTINT (old_value))
    {
      do_mouse_tracking = 0;

      /* Redisplay may have been preempted because there was input
	 available, and it assumes it will be called again after the
	 input has been processed.  If the only input available was
	 the sort that we have just disabled, then we need to call
	 redisplay.  */
      if (!readable_events ())
	{
	  redisplay_preserve_echo_area ();
	  get_input_pending (&input_pending);
	}
    }
}

DEFUN ("track-mouse", Ftrack_mouse, Strack_mouse, 0, UNEVALLED, 0,
  "Evaluate BODY with mouse movement and button release events enabled.\n\
Within a `track-mouse', mouse motion and button releases generate input\n\
events that you can read with `read-event'.\n\
Normally, these occurrences don't generate events.")
  (args)
     Lisp_Object args;
{
  int count = specpdl_ptr - specpdl;
  Lisp_Object val;

  XSET (val, Lisp_Int, do_mouse_tracking);
  record_unwind_protect (tracking_off, val);

  do_mouse_tracking = 1;
  
  val = Fprogn (args);
  return unbind_to (count, val);
}

/* Store an event obtained at interrupt level into kbd_buffer, fifo */

void
kbd_buffer_store_event (event)
     register struct input_event *event;
{
  if (event->kind == no_event)
    abort ();

  if (event->kind == ascii_keystroke)
    {
      register int c = XFASTINT (event->code) & 0377;

      if (c == quit_char
	  || ((c == (0200 | quit_char)) && !meta_key))
	{
	  extern SIGTYPE interrupt_signal ();

#ifdef MULTI_FRAME
	  /* If this results in a quit_char being returned to Emacs as
	     input, set last-event-frame properly.  If this doesn't
	     get returned to Emacs as an event, the next event read
	     will set Vlast_event_frame again, so this is safe to do.  */
	  Vlast_event_frame = FRAME_FOCUS_FRAME (event->frame);
#endif

	  last_event_timestamp = event->timestamp;
	  interrupt_signal ();
	  return;
	}

      if (c && c == stop_character)
	{
	  sys_suspend ();
	  return;
	}

      XSET (event->code, Lisp_Int, c);
    }

  if (kbd_store_ptr - kbd_buffer == KBD_BUFFER_SIZE)
    kbd_store_ptr = kbd_buffer;

  /* Don't let the very last slot in the buffer become full,
     since that would make the two pointers equal,
     and that is indistinguishable from an empty buffer.
     Discard the event if it would fill the last slot.  */
  if (kbd_fetch_ptr - 1 != kbd_store_ptr)
    {
      kbd_store_ptr->kind = event->kind;
      kbd_store_ptr->code = event->code;
      kbd_store_ptr->part = event->part;
      kbd_store_ptr->frame = event->frame;
      kbd_store_ptr->modifiers = event->modifiers;
      kbd_store_ptr->x = event->x;
      kbd_store_ptr->y = event->y;
      kbd_store_ptr->timestamp = event->timestamp;

      kbd_store_ptr++;
    }
}

static Lisp_Object make_lispy_event ();
static Lisp_Object make_lispy_movement ();
static Lisp_Object modify_event_symbol ();

static Lisp_Object
kbd_buffer_get_event ()
{
  register int c;
  Lisp_Object obj;

  if (noninteractive)
    {
      c = getchar ();
      XSET (obj, Lisp_Int, c);
      return obj;
    }

  /* Wait until there is input available.  */
  for (;;)
    {

      /* Process or toss any events that we don't want to return as
	 input.  The fact that we remove undesirable events here
	 allows us to use EVENT_QUEUES_EMPTY in the rest of this loop.  */
      if (! do_mouse_tracking)
	while (kbd_fetch_ptr != kbd_store_ptr)
	  {
	    if (kbd_fetch_ptr == kbd_buffer + KBD_BUFFER_SIZE)
	      kbd_fetch_ptr = kbd_buffer;

	    if (kbd_fetch_ptr->kind == mouse_click
		|| kbd_fetch_ptr->kind == scrollbar_click)
	      {
		if ((kbd_fetch_ptr->modifiers & up_modifier) == 0)
		  break;
	      }
	    else
	      break;

	    kbd_fetch_ptr++;
	  }

      if (!EVENT_QUEUES_EMPTY)
	break;

      /* If the quit flag is set, then read_char will return
	 quit_char, so that counts as "available input."  */
      if (!NILP (Vquit_flag))
	quit_throw_to_read_char ();

      /* One way or another, wait until input is available; then, if
	 interrupt handlers have not read it, read it now.  */

#ifdef OLDVMS
      wait_for_kbd_input ();
#else
/* Note SIGIO has been undef'd if FIONREAD is missing.  */
#ifdef SIGIO
      gobble_input (0);
#endif /* SIGIO */
      if (EVENT_QUEUES_EMPTY)
	{
	  Lisp_Object minus_one;

	  XSET (minus_one, Lisp_Int, -1);
	  wait_reading_process_input (0, 0, minus_one, 1);

	  if (!interrupt_input && EVENT_QUEUES_EMPTY)
	    {
	      read_avail_input (0);
	    }
	}
#endif /* not VMS */
    }

  /* At this point, we know that there is a readable event available
     somewhere.  If the event queue is empty, then there must be a
     mouse movement enabled and available.  */
  if (kbd_fetch_ptr != kbd_store_ptr)
    {
      if (kbd_fetch_ptr == kbd_buffer + KBD_BUFFER_SIZE)
	kbd_fetch_ptr = kbd_buffer;

#ifdef MULTI_FRAME
      XSET (Vlast_event_frame, Lisp_Frame,
	    XFRAME (FRAME_FOCUS_FRAME (kbd_fetch_ptr->frame)));
#endif

      last_event_timestamp = kbd_fetch_ptr->timestamp;
      obj = make_lispy_event (kbd_fetch_ptr);
      kbd_fetch_ptr->kind = no_event;
      kbd_fetch_ptr++;
      if (XTYPE (obj) == Lisp_Int)
	XSET (obj, Lisp_Int, XINT (obj) & (meta_key ? 0377 : 0177));
    }
  else if (do_mouse_tracking && mouse_moved)
    {
      FRAME_PTR frame;
      Lisp_Object x, y;
      unsigned long time;

      (*mouse_position_hook) (&frame, &x, &y, &time);
#ifdef MULTI_FRAME
      XSET (Vlast_event_frame, Lisp_Frame, frame);
#endif

      obj = make_lispy_movement (frame, x, y, time);
    }
  else
    /* We were promised by the above while loop that there was
       something for us to read!  */
    abort ();

  input_pending = readable_events ();

  return (obj);
}

/* Caches for modify_event_symbol.  */
static Lisp_Object func_key_syms;
static Lisp_Object mouse_syms;

/* You'll notice that this table is arranged to be conveniently
   indexed by X Windows keysym values.  */
static char *lispy_function_keys[] =
  {
    /* X Keysym value */

    "home",			/* 0xff50 */	/* IsCursorKey */
    "left",
    "up",
    "right",
    "down",
    "prior",
    "next",
    "end",
    "begin",
    0,				/* 0xff59 */
    0, 0, 0, 0, 0, 0,
    "select",			/* 0xff60 */	/* IsMiscFunctionKey */
    "print",
    "execute",
    "insert",
    0,		/* 0xff64 */
    "undo",
    "redo",
    "menu",
    "find",
    "cancel",
    "help",
    "break",			/* 0xff6b */

    /* Here are some keys found mostly on HP keyboards.  The X event
       handling code will strip bit 29, which flags vendor-specific
       keysyms.  */
    "reset",			/* 0x1000ff6c */
    "system",
    "user",
    "clearline",
    "insertline",
    "deleteline",
    "insertchar",
    "deletechar",
    "backtab",
    "kp_backtab",		/* 0x1000ff75 */
    0,				/* 0xff76 */
    0, 0, 0, 0, 0, 0, 0, 0, 0,	/* 0xff7f */
    "kp-space",			/* 0xff80 */	/* IsKeypadKey */
    0, 0, 0, 0, 0, 0, 0, 0,
    "kp-tab",			/* 0xff89 */
    0, 0, 0,
    "kp-enter",			/* 0xff8d */
    0, 0, 0,
    "kp-f1",			/* 0xff91 */
    "kp-f2",
    "kp-f3",
    "kp-f4",
    0,		/* 0xff95 */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    "kp-multiply",		/* 0xffaa */
    "kp-add",
    "kp-separator",
    "kp-subtract",
    "kp-decimal",
    "kp-divide",		/* 0xffaf */
    "kp-0",			/* 0xffb0 */
    "kp-1",	"kp-2",	"kp-3",	"kp-4",	"kp-5",	"kp-6",	"kp-7",	"kp-8",	"kp-9",
    0,		/* 0xffba */
    0, 0,
    "kp-equal",			/* 0xffbd */
    "f1",			/* 0xffbe */	/* IsFunctionKey */
    "f2",	"f3",	"f4",
    "f5",	"f6",	"f7",	"f8",	"f9",	"f10",	"f11",	"f12",
    "f13",	"f14",	"f15",	"f16",	"f17",	"f18",	"f19",	"f20",
    "f21",	"f22",	"f23",	"f24",	"f25",	"f26",	"f27",	"f28",
    "f29",	"f30",	"f31",	"f32",	"f33",	"f34",	"f35"	/* 0xffe0 */
    };

static char *lispy_mouse_names[] = 
{
  "mouse-1", "mouse-2", "mouse-3", "mouse-4", "mouse-5"
};

/* Given a struct input_event, build the lisp event which represents
   it.  If EVENT is 0, build a mouse movement event from the mouse
   movement buffer, which should have a movement event in it.  */

static Lisp_Object
make_lispy_event (event)
     struct input_event *event;
{
#ifdef SWITCH_ENUM_BUG
  switch ((int) event->kind)
#else
  switch (event->kind)
#endif
    {

      /* A simple keystroke.  */
    case ascii_keystroke:
      return event->code;
      break;

      /* A function key.  The symbol may need to have modifier prefixes
	 tacked onto it.  */
    case non_ascii_keystroke:
      return modify_event_symbol (XFASTINT (event->code), event->modifiers,
				  Qfunction_key,
				  lispy_function_keys, &func_key_syms,
				  (sizeof (lispy_function_keys)
				   / sizeof (lispy_function_keys[0])));
      break;

      /* A mouse click - build a list of the relevant information.  */
    case mouse_click:
      {
	int part;
	Lisp_Object window =
	  window_from_coordinates (event->frame,
				   XINT (event->x), XINT (event->y),
				   &part);
	Lisp_Object posn;

	if (XTYPE (window) != Lisp_Window)
	  posn = Qnil;
	else
	  {
	    XSETINT (event->x, (XINT (event->x)
				- XINT (XWINDOW (window)->left)));
	    XSETINT (event->y, (XINT (event->y)
				- XINT (XWINDOW (window)->top)));

	    if (part == 1)
	      posn = Qmode_line;
	    else if (part == 2)
	      posn = Qvertical_line;
	    else
	      XSET (posn, Lisp_Int,
		    buffer_posn_from_coords (XWINDOW (window),
					     XINT (event->x),
					     XINT (event->y)));
	  }

	return Fcons (modify_event_symbol (XFASTINT (event->code) - 1,
					   event->modifiers,
					   Qmouse_click,
					   lispy_mouse_names, &mouse_syms,
					   (sizeof (lispy_mouse_names)
					    / sizeof (lispy_mouse_names[0]))),
		      Fcons (window,
			     Fcons (posn,
				    Fcons (Fcons (event->x, event->y),
					   Fcons (make_number
						  (event->timestamp),
						  Qnil)))));
      }

      /* A scrollbar click.  Build a list containing the relevant
	 information.  */
    case scrollbar_click:
      {
	Lisp_Object button
	  = modify_event_symbol (XFASTINT (event->code) - 1,
				 event->modifiers,
				 Qmouse_click,
				 lispy_mouse_names, &mouse_syms,
				 (sizeof (lispy_mouse_names)
				  / sizeof (lispy_mouse_names[0])));
	return Fcons (event->part,
		      Fcons (FRAME_SELECTED_WINDOW (event->frame),
			     Fcons (button,
				    Fcons (Fcons (event->x, event->y),
					   Fcons (make_number
						  (event->timestamp),
						  Qnil)))));
      }

      /* The 'kind' field of the event is something we don't recognize.  */
    default:
      abort();
    }
}

static Lisp_Object
make_lispy_movement (frame, x, y, time)
     FRAME_PTR frame;
     Lisp_Object x, y;
     unsigned long time;
{
  Lisp_Object window;
  int ix, iy;
  Lisp_Object posn;
  int part;

  ix = XINT (x);
  iy = XINT (y);
  window = (frame
	    ? window_from_coordinates (frame, ix, iy, &part)
	    : Qnil);
  if (XTYPE (window) != Lisp_Window)
    posn = Qnil;
  else
    {
      ix -= XINT (XWINDOW (window)->left);
      iy -= XINT (XWINDOW (window)->top);
      if (part == 1)
	posn = Qmode_line;
      else if (part == 2)
	posn = Qvertical_line;
      else
	XSET (posn, Lisp_Int, buffer_posn_from_coords (XWINDOW (window),
						       ix, iy));
    }

  XSETINT (x, ix);
  XSETINT (y, iy);
  return Fcons (Qmouse_movement,
		Fcons (window,
		       Fcons (posn,
			      Fcons (Fcons (x, y),
				     Fcons (make_number (time), Qnil)))));
}



/* Place the written representation of MODIFIERS in BUF, '\0'-terminated,
   and return its length.  */

static int
format_modifiers (modifiers, buf)
     int modifiers;
     char *buf;
{
  char *p = buf;

  if (modifiers & ctrl_modifier) { *p++ = 'C'; *p++ = '-'; }
  if (modifiers & meta_modifier) { *p++ = 'M'; *p++ = '-'; }
  if (modifiers & shift_modifier) { *p++ = 'S'; *p++ = '-'; }
  if (modifiers & up_modifier) { *p++ = 'U'; *p++ = '-'; }
  *p = '\0';

  return p - buf;
}


/* Given a symbol whose name begins with modifiers ("C-", "M-", etc),
   return a symbol with the modifiers placed in the canonical order.

   Fdefine_key calls this to make sure that (for example) C-M-foo
   and M-C-foo end up being equivalent in the keymap.  */

Lisp_Object
reorder_modifiers (symbol)
     Lisp_Object symbol;
{
  struct Lisp_String *name;
  int i;
  int modifiers;
  int not_canonical;

  CHECK_SYMBOL (symbol, 1);
  
  modifiers = 0;
  name = XSYMBOL (symbol)->name;

  /* Special case for things with only one modifier, which is
     (hopefully) the vast majority of cases.  */
  if (! (name->size >= 4 && name->data[1] == '-' && name->data[3] == '-'))
    return symbol;

  for (i = 0; i + 1 < name->size && name->data[i + 1] == '-'; i += 2)
    switch (name->data[i])
      {
      case 'M':
	not_canonical |= (modifiers & (meta_modifier|ctrl_modifier
				      |shift_modifier|up_modifier));
	modifiers |= meta_modifier;
	break;

      case 'C':
	not_canonical |= (modifiers &
			 (ctrl_modifier|shift_modifier|up_modifier));
	modifiers |= ctrl_modifier;
	break;

      case 'S':
	not_canonical |= (modifiers & (shift_modifier|up_modifier));
	modifiers |= shift_modifier;
	break;

      case 'U':
	not_canonical |= (modifiers & (up_modifier));
	modifiers |= up_modifier;
	break;

      default:
	goto no_more_modifiers;
      }
 no_more_modifiers:

  if (!not_canonical)
    return symbol;

  /* The modifiers were out of order, so find a new symbol with the
     mods in order.  Since the symbol name could contain nulls, we can't
     use intern here; we have to use Fintern, which expects a genuine
     Lisp_String, and keeps a reference to it.  */
  {
    char *new_mods = (char *) alloca (sizeof ("C-M-S-U-"));
    int len = format_modifiers (modifiers, new_mods);
    Lisp_Object new_name = make_uninit_string (len + name->size - i);

    bcopy (new_mods, XSTRING (new_name)->data, len);
    bcopy (name->data + i, XSTRING (new_name)->data + len, name->size - i);

    return Fintern (new_name, Qnil);
  }
}


/* For handling events, we often want to produce a symbol whose name
   is a series of modifier key prefixes ("M-", "C-", etcetera) attached
   to some base, like the name of a function key or mouse button.
   modify_event_symbol produces symbols of this sort.

   NAME_TABLE should point to an array of strings, such that NAME_TABLE[i]
   is the name of the i'th symbol.  TABLE_SIZE is the number of elements
   in the table.

   SYMBOL_TABLE should be a pointer to a Lisp_Object whose value will
   persist between calls to modify_event_symbol that it can use to
   store a cache of the symbols it's generated for this NAME_TABLE
   before.

   SYMBOL_NUM is the number of the base name we want from NAME_TABLE.
   
   MODIFIERS is a set of modifier bits (as given in struct input_events)
   whose prefixes should be applied to the symbol name.

   SYMBOL_KIND is the value to be placed in the event_kind property of
   the returned symbol.  */

static Lisp_Object
modify_event_symbol (symbol_num, modifiers, symbol_kind, name_table,
                     symbol_table, table_size)
     int symbol_num;
     unsigned modifiers;
     Lisp_Object symbol_kind;
     char **name_table;
     Lisp_Object *symbol_table;
     int table_size;
{
  Lisp_Object *slot, *unmodified_slot;

  /* Is this a request for a valid symbol?  */
  if (symbol_num < 0 || symbol_num >= table_size
      || modifiers >= NUM_MODIFIER_COMBOS)
    abort ();

  /* If *symbol_table is not a vector of the appropriate size,
     set it to one.  */
  if (XTYPE (*symbol_table) != Lisp_Vector
      || XVECTOR (*symbol_table)->size != table_size)
    *symbol_table = Fmake_vector (make_number (table_size), Qnil);

  unmodified_slot = slot = & XVECTOR (*symbol_table)->contents[symbol_num];

  /* If there are modifier keys, there had better be a vector in
     this symbol's position of the symbol_table.  */
  if (modifiers != 0)
    {
      Lisp_Object slot_contents = *slot;

      /* If there isn't the right sort of vector there, put one in.  */
      if (XTYPE (slot_contents) != Lisp_Vector
	  || XVECTOR (slot_contents)->size != NUM_MODIFIER_COMBOS)
	{
	  *slot = Fmake_vector (make_number (NUM_MODIFIER_COMBOS), Qnil);

	  /* Make sure that the vector has an entry for the unmodified
	     symbol, so we can put it on the event_unmodified property.  */
	  if (! NILP (slot_contents))
	    XVECTOR (*slot)->contents[0] = slot_contents;
	  else
	    XVECTOR (*slot)->contents[0] = intern (name_table [symbol_num]);
	}
    }

  /* If this entry has been filled in with a modified symbol vector,
     point to the appropriate slot within that.  */
  if (XTYPE (*slot) == Lisp_Vector)
    {
      unmodified_slot = & XVECTOR (*slot)->contents[0];
      slot = & XVECTOR (*slot)->contents[modifiers];
    }

  /* Make sure we have an unmodified version of the symbol in its
     proper place?  */
  if (NILP (*unmodified_slot))
    {
      *unmodified_slot = intern (name_table [symbol_num]);
      Fput (*unmodified_slot, Qevent_kind, symbol_kind);
      Fput (*unmodified_slot, Qevent_unmodified, *unmodified_slot);
    }

  /* Have we already created a symbol for this combination of modifiers?  */
  if (NILP (*slot))
    {
      /* No, let's create one.  */
      char *modified_name
	= (char *) alloca (sizeof ("C-M-S-U-")
			   + strlen (name_table [symbol_num]));

      strcpy (modified_name + format_modifiers (modifiers, modified_name),
	      name_table [symbol_num]);

      *slot = intern (modified_name);
      Fput (*slot, Qevent_kind, symbol_kind);
      Fput (*slot, Qevent_unmodified, *unmodified_slot);
    }
  
  return *slot;
}

DEFUN ("mouse-click-p", Fmouse_click_p, Smouse_click_p, 1, 1, 0,
  "Return non-nil iff OBJECT is a representation of a mouse event.\n\
A mouse event is a list of five elements whose car is a symbol of the\n\
form <MODIFIERS>mouse-<DIGIT>.  I hope this is a temporary hack.")
  (object)
     Lisp_Object object;
{
  if (EVENT_HAS_PARAMETERS (object)
      && EQ (EVENT_HEAD_KIND (EVENT_HEAD (object)),
	     Qmouse_click))
    return Qt;
  else
    return Qnil;
}

/* Store into *addr a value nonzero if terminal input chars are available.
   Serves the purpose of ioctl (0, FIONREAD, addr)
   but works even if FIONREAD does not exist.
   (In fact, this may actually read some input.)  */

static void
get_input_pending (addr)
     int *addr;
{
  /* First of all, have we already counted some input?  */
  *addr = !NILP (Vquit_flag) || readable_events ();

  /* If input is being read as it arrives, and we have none, there is none.  */
  if (*addr > 0 || (interrupt_input && ! interrupts_deferred))
    return;

  /* Try to read some input and see how much we get.  */
  gobble_input (0);
  *addr = !NILP (Vquit_flag) || readable_events ();
}

/* Interface to read_avail_input, blocking SIGIO if necessary.  */

int
gobble_input (expected)
     int expected;
{
#ifndef VMS
#ifdef SIGIO
  if (interrupt_input)
    {
      SIGMASKTYPE mask;
      mask = sigblockx (SIGIO);
      read_avail_input (expected);
      sigsetmask (mask);
    }
  else
#endif
    read_avail_input (expected);
#endif
}

#ifndef VMS

/* Read any terminal input already buffered up by the system
   into the kbd_buffer, but do not wait.

   EXPECTED should be nonzero if the caller knows there is some input.

   Except on VMS, all input is read by this function.
   If interrupt_input is nonzero, this function MUST be called
   only when SIGIO is blocked.

   Returns the number of keyboard chars read, or -1 meaning
   this is a bad time to try to read input.  */

static int
read_avail_input (expected)
     int expected;
{
  struct input_event buf[KBD_BUFFER_SIZE];
  register int i;
  int nread;

  if (read_socket_hook)
    /* No need for FIONREAD or fcntl; just say don't wait.  */
    nread = (*read_socket_hook) (0, buf, KBD_BUFFER_SIZE, expected, expected);
  else
    {
      unsigned char cbuf[KBD_BUFFER_SIZE];

#ifdef FIONREAD
      /* Find out how much input is available.  */
      if (ioctl (0, FIONREAD, &nread) < 0)
	/* Formerly simply reported no input, but that sometimes led to
	   a failure of Emacs to terminate.
	   SIGHUP seems appropriate if we can't reach the terminal.  */
	kill (getpid (), SIGHUP);
      if (nread == 0)
	return 0;
      if (nread > sizeof cbuf)
	nread = sizeof cbuf;
#else /* no FIONREAD */
#ifdef USG
      /* Read some input if available, but don't wait.  */
      nread = sizeof cbuf;
      fcntl (fileno (stdin), F_SETFL, O_NDELAY);
#else
      you lose;
#endif
#endif

      /* Now read; for one reason or another, this will not block.  */
      while (1)
	{
	  nread = read (fileno (stdin), cbuf, nread);
#ifdef AIX
	  /* The kernel sometimes fails to deliver SIGHUP for ptys.
	     This looks incorrect, but it isn't, because _BSD causes
	     O_NDELAY to be defined in fcntl.h as O_NONBLOCK,
	     and that causes a value other than 0 when there is no input.  */
	  if (nread == 0)
	    kill (SIGHUP, 0);
#endif
	  /* Retry the read if it is interrupted.  */
	  if (nread >= 0
	      || ! (errno == EAGAIN || errno == EFAULT
#ifdef EBADSLT
		    || errno == EBADSLT
#endif
		    ))
	    break;
	}

#ifndef FIONREAD
#ifdef USG
      fcntl (fileno (stdin), F_SETFL, 0);
#endif /* USG */
#endif /* no FIONREAD */
      for (i = 0; i < nread; i++)
	{
	  buf[i].kind = ascii_keystroke;
	  XSET (buf[i].code, Lisp_Int, cbuf[i]);
	  buf[i].frame = selected_frame;
	}
    }

  /* Scan the chars for C-g and store them in kbd_buffer.  */
  for (i = 0; i < nread; i++)
    {
      kbd_buffer_store_event (&buf[i]);
      /* Don't look at input that follows a C-g too closely.
	 This reduces lossage due to autorepeat on C-g.  */
      if (buf[i].kind == ascii_keystroke
	  && XINT(buf[i].code) == quit_char)
	break;
    }

  return nread;
}
#endif /* not VMS */

#ifdef SIGIO   /* for entire page */
/* Note SIGIO has been undef'd if FIONREAD is missing.  */

SIGTYPE
input_available_signal (signo)
     int signo;
{
  /* Must preserve main program's value of errno.  */
  int old_errno = errno;
#ifdef BSD4_1
  extern int select_alarmed;
#endif

#ifdef USG
  /* USG systems forget handlers when they are used;
     must reestablish each time */
  signal (signo, input_available_signal);
#endif /* USG */

#ifdef BSD4_1
  sigisheld (SIGIO);
#endif

  if (input_available_clear_time)
    EMACS_SET_SECS_USECS (*input_available_clear_time, 0, 0);

  while (1)
    {
      int nread;
      nread = read_avail_input (1);
      /* -1 means it's not ok to read the input now.
	 UNBLOCK_INPUT will read it later; now, avoid infinite loop.
	 0 means there was no keyboard input available.  */
      if (nread <= 0)
	break;

#ifdef BSD4_1
      select_alarmed = 1;  /* Force the select emulator back to life */
#endif
    }

#ifdef BSD4_1
  sigfree ();
#endif
  errno = old_errno;
}
#endif /* SIGIO */

/* Return the prompt-string of a sparse keymap.
   This is the first element which is a string.
   Return nil if there is none.  */

Lisp_Object
map_prompt (map)
     Lisp_Object map;
{
  while (CONSP (map))
    {
      register Lisp_Object tem;
      tem = Fcar (map);
      if (XTYPE (tem) == Lisp_String)
	return tem;
      map = Fcdr (map);
    }
  return Qnil;
}

static int echo_flag;
static int echo_now;

/* Read a character like read_char but optionally prompt based on maps
   in the array MAPS.  NMAPS is the length of MAPS.

   PREV_EVENT is the previous input event, or nil if we are reading
   the first event of a key sequence.

   If we use a mouse menu to read the input, we store 1 into *USED_MOUSE_MENU.
   Otherwise we store 0 there.

   The prompting is done based on the prompt-string of the map
   and the strings associated with various map elements.  */

Lisp_Object
read_char_menu_prompt (nmaps, maps, prev_event, used_mouse_menu)
     int nmaps;
     Lisp_Object *maps;
     Lisp_Object prev_event;
     int *used_mouse_menu;
{
  int mapno;
  register Lisp_Object name;
  int nlength;
  int width = FRAME_WIDTH (selected_frame) - 4;
  char *menu = (char *) alloca (width + 4);
  int idx = -1;
  Lisp_Object rest, vector;

  *used_mouse_menu = 0;

  /* Use local over global Menu maps */

  if (! menu_prompting)
    return Qnil;

  /* Get the menu name from the first map that has one (a prompt string).  */
  for (mapno = 0; mapno < nmaps; mapno++)
    {
      name = map_prompt (maps[mapno]);
      if (!NILP (name))
	break;
    }

  /* If we don't have any menus, just read a character normally.  */
  if (NILP (name))
    return Qnil;

#ifdef HAVE_X_WINDOW
#ifndef NO_X_MENU
  /* If we got to this point via a mouse click,
     use a real menu for mouse selection.  */
  if (XTYPE (prev_event) == Lisp_Cons)
    {
      /* Display the menu and get the selection.  */
      Lisp_Object *realmaps
	= (Lisp_Object *) alloca (nmaps * sizeof (Lisp_Object));
      Lisp_Object value;
      int nmaps1 = 0;

      /* Use the maps that are not nil.  */
      for (mapno = 0; mapno < nmaps; mapno++)
	if (!NILP (maps[mapno]))
	  realmaps[nmaps1++] = maps[mapno];

      value = Fx_popup_menu (prev_event, Flist (nmaps1, realmaps));
      if (NILP (value))
	XSET (value, Lisp_Int, quit_char);
      *used_mouse_menu = 1;
      return value;
    }
#endif /* not NO_X_MENU */
#endif /* HAVE_X_WINDOW */

  /* Prompt string always starts with map's prompt, and a space.  */
  strcpy (menu, XSTRING (name)->data);
  nlength = XSTRING (name)->size;
  menu[nlength++] = ':';
  menu[nlength++] = ' ';
  menu[nlength] = 0;

  /* Start prompting at start of first map.  */
  mapno = 0;
  rest = maps[mapno];

  /* Present the documented bindings, a line at a time.  */
  while (1)
    {
      int notfirst = 0;
      int i = nlength;
      Lisp_Object obj;
      int ch;

      /* Loop over elements of map.  */
      while (i < width)
	{
	  Lisp_Object s, elt;

	  /* If reached end of map, start at beginning of next map.  */
	  if (NILP (rest))
	    {
	      mapno++;
	      /* At end of last map, wrap around to first map if just starting,
		 or end this line if already have something on it.  */
	      if (mapno == nmaps)
		{
		  if (notfirst)
		    break;
		  else
		    mapno = 0;
		}
	      rest = maps[mapno];
	    }

	  /* Look at the next element of the map.  */
	  if (idx >= 0)
	    elt = XVECTOR (vector)->contents[idx];
	  else
	    elt = Fcar_safe (rest);

	  if (idx < 0 && XTYPE (elt) == Lisp_Vector)
	    {
	      /* If we found a dense table in the keymap,
		 advanced past it, but start scanning its contents.  */
	      rest = Fcdr_safe (rest);
	      vector = elt;
	      idx = 0;
	    }
	  else
	    {
	      /* An ordinary element.  */
	      s = Fcar_safe (Fcdr_safe (elt));
	      if (XTYPE (s) != Lisp_String)
		/* Ignore the element if it has no prompt string.  */
		;
	      /* If we have room for the prompt string, add it to this line.
		 If this is the first on the line, always add it.  */
	      else if (XSTRING (s)->size + i < width
		       || !notfirst)
		{
		  int thiswidth;

		  /* Punctuate between strings.  */
		  if (notfirst)
		    {
		      strcpy (menu + i, ", ");
		      i += 2;
		    }
		  notfirst = 1;

		  /* Add as much of string as fits.  */
		  thiswidth = XSTRING (s)->size;
		  if (thiswidth + i > width)
		    thiswidth = width - i;
		  bcopy (XSTRING (s)->data, menu + i, thiswidth);
		  i += thiswidth;
		}
	      else
		{
		  /* If this element does not fit, end the line now,
		     and save the element for the next line.  */
		  strcpy (menu + i, "...");
		  break;
		}

	      /* Move past this element.  */
	      if (idx >= 0 && idx + 1 >= XVECTOR (rest)->size)
		/* Handle reaching end of dense table.  */
		idx = -1;
	      if (idx >= 0)
		idx++;
	      else
		rest = Fcdr_safe (rest);
	    }
	}

      /* Prompt with that and read response.  */
      message1 (menu);
      obj = read_char (1, 0, 0, Qnil, 0);

      if (XTYPE (obj) != Lisp_Int)
	return obj;
      else
	ch = XINT (obj);

      if (obj != menu_prompt_more_char
	  && (XTYPE (menu_prompt_more_char) != Lisp_Int
	      || obj != make_number (Ctl (XINT (menu_prompt_more_char)))))
	return obj;
    }
}

/* Reading key sequences.  */

/* Follow KEY in the maps in CURRENT[0..NMAPS-1], placing its bindings
   in DEFS[0..NMAPS-1].  Set NEXT[i] to DEFS[i] if DEFS[i] is a
   keymap, or nil otherwise.  Return the index of the first keymap in
   which KEY has any binding, or NMAPS if no map has a binding.

   If KEY is a meta ASCII character, treat it like meta-prefix-char
   followed by the corresponding non-meta character.  Keymaps in
   CURRENT with non-prefix bindings for meta-prefix-char become nil in
   NEXT.

   When KEY is not defined in any of the keymaps, if it is an upper
   case letter and there are bindings for the corresponding lower-case
   letter, return the bindings for the lower-case letter.

   NEXT may == CURRENT.  */

static int
follow_key (key, nmaps, current, defs, next)
     Lisp_Object key;
     Lisp_Object *current, *defs, *next;
     int nmaps;
{
  int i, first_binding;

  /* If KEY is a meta ASCII character, treat it like meta-prefix-char
     followed by the corresponding non-meta character.  */
  if (XTYPE (key) == Lisp_Int
      && XINT (key) >= 0200)
    {
      for (i = 0; i < nmaps; i++)
	if (! NILP (current[i]))
	  {
	    next[i] = get_keyelt (access_keymap (current[i],
						 meta_prefix_char));

	    /* Note that since we pass the resulting bindings through
	       get_keymap_1, non-prefix bindings for meta-prefix-char
	       disappear.  */
	    next[i] = get_keymap_1 (next[i], 0);
	  }
	else
	  next[i] = Qnil;

      current = next;
      XSET (key, Lisp_Int, XFASTINT (key) & 0177);
    }

  first_binding = nmaps;
  for (i = nmaps - 1; i >= 0; i--)
    {
      if (! NILP (current[i]))
	{
	  defs[i] = get_keyelt (access_keymap (current[i], key));
	  if (! NILP (defs[i]))
	    first_binding = i;
	}
      else
	defs[i] = Qnil;
    }

  /* When KEY is not defined in any of the keymaps, if it is an upper
     case letter and there are bindings for the corresponding
     lower-case letter, return the bindings for the lower-case letter.  */
  if (first_binding == nmaps
      && XTYPE (key) == Lisp_Int
      && UPPERCASEP (XINT (key)))
    {
      XSETINT (key, DOWNCASE (XINT (key)));

      first_binding = nmaps;
      for (i = nmaps - 1; i >= 0; i--)
	{
	  if (! NILP (current[i]))
	    {
	      defs[i] = get_keyelt (access_keymap (current[i], key));
	      if (! NILP (defs[i]))
		first_binding = i;
	    }
	  else
	    defs[i] = Qnil;
	}
    }
  
  /* Given the set of bindings we've found, produce the next set of maps.  */
  for (i = 0; i < nmaps; i++)
    next[i] = NILP (defs[i]) ? Qnil : get_keymap_1 (defs[i], 0);

  return first_binding;
}

/* Read a sequence of keys that ends with a non prefix character
   according to the keymaps in KEYMAPS[0..nmaps-1].  Keymaps appearing
   earlier in KEYMAPS take precidence over those appearing later.

   Store the sequence in KEYBUF, a buffer of size BUFSIZE.  Prompt
   with PROMPT.  Echo starting immediately unless `prompt' is 0.
   Return the length of the key sequence stored.

   If the user switches frames in the midst of a key sequence, we
   throw away any prefix we have read so far, and start afresh.  For
   mouse clicks, we look up the click in the keymap of the buffer
   clicked on, throwing away any prefix if it is not the same buffer
   we used to be reading from.  */

static int
read_key_sequence (keybuf, bufsize, prompt)
     Lisp_Object *keybuf;
     int bufsize;
     Lisp_Object prompt;
{
  /* How many keys there are in the current key sequence.  */
  int t;

  /* The buffer that the most recently read event was typed at.  This
     helps us read mouse clicks according to the buffer clicked in,
     and notice when the mouse has moved from one frame to another.  */
  struct buffer *last_event_buffer = current_buffer;

  /* The length of the echo buffer when we started reading, and
     the length of this_command_keys when we started reading.  */
  int echo_start;
  int keys_start = this_command_key_count;

  /* The number of keymaps we're scanning right now, and the number of
     keymaps we have allocated space for.  */
  int nmaps;
  int nmaps_allocated = 0;

  /* submaps[0..nmaps-1] are the prefix definitions of KEYBUF[0..t-1]
     in the current keymaps, or nil where it is not a prefix.  */
  Lisp_Object *submaps;

  /* defs[0..nmaps-1] are the definitions of KEYBUF[0..t-1] in
     the current keymaps.  */
  Lisp_Object *defs;

  /* The index of the first keymap that has a binding for this key
     sequence.  In other words, the lowest i such that defs[i] is
     non-nil.*/
  int first_binding;

  /* If mock_input > t, then KEYBUF[t] should be read as the next
     input key.

     We use this to recover after recognizing a function key.  Once we
     realize that a suffix of the current key sequence is actually a
     function key's escape sequence, we replace the suffix with the
     function key's binding from Vfunction_key_map.  Now keybuf
     contains a new and different key sequence, so the echo area and
     the submaps and defs arrays are wrong.  In this situation, we set
     mock_input to t, set t to 0, and jump to restart; the loop will
     read keys from keybuf up until mock_input, which rebuilds the
     state, and then it will resume reading characters from the keyboard.  */
  int mock_input = 0;

  /* If the sequence is unbound in submaps[], then
     keymap[fkey_start..fkey_end-1] is a prefix in Vfunction_key_map,
     and fkey_map is its binding.  If mock_input is in use, these
     might be > t, indicating that all function key scanning should
     hold off until t reaches them.  */

  int fkey_start = 0, fkey_end = 0;
  Lisp_Object fkey_map = Vfunction_key_map;

  last_nonmenu_event = Qnil;

  if (INTERACTIVE)
    {
      if (prompt)
	echo_prompt (prompt);
      else if (cursor_in_echo_area)
	/* This doesn't put in a dash if the echo buffer is empty, so
	   you don't always see a dash hanging out in the minibuffer.  */
	echo_dash ();
      echo_start = echo_length ();
    }

  /* If there is no function key map, turn off function key scanning.  */
  if (NILP (Fkeymapp (Vfunction_key_map)))
    fkey_start = fkey_end = bufsize + 1;

 restart:
  t = 0;
  this_command_key_count = keys_start;

  { 
    Lisp_Object *maps;

    nmaps = current_minor_maps (0, &maps) + 2;
    if (nmaps > nmaps_allocated)
      {
	submaps = (Lisp_Object *) alloca (nmaps * sizeof (submaps[0]));
	defs    = (Lisp_Object *) alloca (nmaps * sizeof (defs[0]));
	nmaps_allocated = nmaps;
      }
    bcopy (maps, submaps, (nmaps - 2) * sizeof (submaps[0]));
    submaps[nmaps-2] = last_event_buffer->keymap;
    submaps[nmaps-1] = global_map;
  }

  /* Find an accurate initial value for first_binding.  */
  for (first_binding = 0; first_binding < nmaps; first_binding++)
    if (! NILP (submaps[first_binding]))
      break;

  while ((first_binding < nmaps && ! NILP (submaps[first_binding]))
	 || (first_binding >= nmaps && fkey_start < t))
    {
      Lisp_Object key;
      int used_mouse_menu = 0;

      if (t >= bufsize)
	error ("key sequence too long");

      /* Are we re-reading a key sequence, as indicated by mock_input?  */
      if (t < mock_input)
	{
	  key = keybuf[t];
	  add_command_key (key);
	  echo_char (key);
	}

      /* If not, we should actually read a character.  */
      else
	{
	  struct buffer *buf;

	  key = read_char (!prompt, nmaps, submaps, last_nonmenu_event,
			   &used_mouse_menu);

	  /* The above routines return -1 at the end of a macro.
	     Emacs 18 handles this by returning immediately with a
	     zero, so that's what we'll do.  */
	  if (XTYPE (key) == Lisp_Int && XINT (key) < 0)
	    return 0;
	  
	  Vquit_flag = Qnil;

#ifdef MULTI_FRAME
	  /* What buffer was this event typed/moused at?  */
	  if (used_mouse_menu)
	    /* Never change last_event_buffer for using a menu.  */
	    buf = last_event_buffer;
	  else if (XTYPE (key) == Lisp_Int || XTYPE (key) == Lisp_Symbol)
	    buf = (XBUFFER
		   (XWINDOW
		    (FRAME_SELECTED_WINDOW
		     (XFRAME (Vlast_event_frame)))->buffer));
	  else if (EVENT_HAS_PARAMETERS (key))
	    {
	      Lisp_Object window = EVENT_WINDOW (key);

	      if (NILP (window))
		abort ();

	      buf = XBUFFER (XWINDOW (window)->buffer);
	    }
	  else
	    abort ();

	  /* If this event came to a different buffer than the one
	     we're currently in, switch buffers and start a new key
	     sequence, starting with key.  */
	  if (buf != last_event_buffer)
	    {
	      last_event_buffer = buf;
	      Fselect_frame (Vlast_event_frame, Qnil);

	      /* Arrange to read key as the next event.  */
	      keybuf[0] = key;
	      mock_input = 1;

	      /* Truncate the key sequence in the echo area.  */
	      if (INTERACTIVE)
		echo_truncate (echo_start);

	      goto restart;
	    }
#endif
	}

      first_binding = (follow_key (key,
				   nmaps   - first_binding,
				   submaps + first_binding,
				   defs    + first_binding,
				   submaps + first_binding)
		       + first_binding);
      keybuf[t++] = key;
      /* Normally, last_nonmenu_event gets the previous key we read.
	 But when a mouse popup menu is being used,
	 we don't update last_nonmenu_event; it continues to hold the mouse
	 event that preceded the first level of menu.  */
      if (!used_mouse_menu)
	last_nonmenu_event = key;

      /* If the sequence is unbound, see if we can hang a function key
	 off the end of it.  We only want to scan real keyboard input
	 for function key sequences, so if mock_input says that we're
	 re-scanning after expanding a function key, don't examine it.  */
      if (first_binding >= nmaps
	  && t >= mock_input)
	{
	  Lisp_Object fkey_next;

	  /* Scan from fkey_end until we find a bound suffix.  */
	  while (fkey_end < t)
	    {
	      /* Look up meta-characters by prefixing them
		 with meta_prefix_char.  I hate this.  */
	      if (keybuf[fkey_end] & 0x80)
		fkey_next =
		  get_keymap_1 (get_keyelt
				(access_keymap (fkey_map, meta_prefix_char)),
				0);
	      else
		fkey_next = fkey_map;

	      fkey_next =
		get_keyelt (access_keymap
			    (fkey_next, keybuf[fkey_end++] & 0x7f));

	      /* If keybuf[fkey_start..fkey_end] is bound in the
		 function key map and it's a suffix of the current
		 sequence (i.e. fkey_end == t), replace it with
		 the binding and restart with fkey_start at the end. */
	      if (XTYPE (fkey_next) == Lisp_Vector
		  && fkey_end == t)
		{
		  t = fkey_start + XVECTOR (fkey_next)->size;
		  if (t >= bufsize)
		    error ("key sequence too long");

		  bcopy (XVECTOR (fkey_next)->contents,
			 keybuf + fkey_start,
			 (t - fkey_start) * sizeof (keybuf[0]));
		  
		  mock_input = t;
		  fkey_start = fkey_end = t;

		  /* Truncate the key sequence in the echo area.  */
		  if (INTERACTIVE)
		    echo_truncate (echo_start);

		  goto restart;
		}
	      
	      fkey_map = get_keymap_1 (fkey_next, 0);

	      /* If we no longer have a bound suffix, try a new positions for 
		 fkey_start.  */
	      if (NILP (fkey_map))
		{
		  fkey_end = ++fkey_start;
		  fkey_map = Vfunction_key_map;
		}
	    }
	}
    }

  read_key_sequence_cmd = (first_binding < nmaps
			   ? defs[first_binding]
			   : Qnil);

  return t;
}

DEFUN ("read-key-sequence", Fread_key_sequence, Sread_key_sequence, 1, 2, 0,
  "Read a sequence of keystrokes and return as a string or vector.\n\
The sequence is sufficient to specify a non-prefix command in the\n\
current local and global maps.\n\
\n\
First arg PROMPT is a prompt string.  If nil, do not prompt specially.\n\
Second (optional) arg CONTINUE-ECHO, if non-nil, means this key echos\n\
as a continuation of the previous key.\n\
\n\
If Emacs is running on multiple frames, switching between frames in\n\
the midst of a keystroke will toss any prefix typed so far.  A C-g\n\
typed while in this function is treated like any other character, and\n\
`quit-flag' is not set.")
  (prompt, continue_echo)
     Lisp_Object prompt, continue_echo;
{
  Lisp_Object keybuf[30];
  register int i;
  struct gcpro gcpro1, gcpro2;

  if (!NILP (prompt))
    CHECK_STRING (prompt, 0);
  QUIT;

  bzero (keybuf, sizeof keybuf);
  GCPRO1 (keybuf[0]);
  gcpro1.nvars = (sizeof keybuf/sizeof (keybuf[0]));

  if (NILP (continue_echo))
    this_command_key_count = 0;

  i = read_key_sequence (keybuf, (sizeof keybuf/sizeof (keybuf[0])),
			 NILP (prompt)  ? 0 : XSTRING (prompt)->data);

  UNGCPRO;
  return make_array (i, keybuf);
}

DEFUN ("command-execute", Fcommand_execute, Scommand_execute, 1, 2, 0,
 "Execute CMD as an editor command.\n\
CMD must be a symbol that satisfies the `commandp' predicate.\n\
Optional second arg RECORD-FLAG non-nil\n\
means unconditionally put this command in `command-history'.\n\
Otherwise, that is done only if an arg is read using the minibuffer.")
     (cmd, record)
     Lisp_Object cmd, record;
{
  register Lisp_Object final;
  register Lisp_Object tem;
  Lisp_Object prefixarg;
  struct backtrace backtrace;
  extern int debug_on_next_call;

  prefixarg = Vprefix_arg, Vprefix_arg = Qnil;
  Vcurrent_prefix_arg = prefixarg;
  debug_on_next_call = 0;

  if (XTYPE (cmd) == Lisp_Symbol)
    {
      tem = Fget (cmd, Qdisabled);
      if (!NILP (tem))
	return call1 (Vrun_hooks, Vdisabled_command_hook);
    }

  while (1)
    {
      final = Findirect_function (cmd);

      if (CONSP (final) && (tem = Fcar (final), EQ (tem, Qautoload)))
	do_autoload (final, cmd);
      else
	break;
    }

  if (XTYPE (final) == Lisp_String
      || XTYPE (final) == Lisp_Vector)
    {
      /* If requested, place the macro in the command history.  For
	 other sorts of commands, call-interactively takes care of
	 this.  */
      if (!NILP (record))
	Vcommand_history
	  = Fcons (Fcons (Qexecute_kbd_macro,
			  Fcons (final, Fcons (prefixarg, Qnil))),
		   Vcommand_history);

      return Fexecute_kbd_macro (final, prefixarg);
    }
  if (CONSP (final) || XTYPE (final) == Lisp_Subr
      || XTYPE (final) == Lisp_Compiled)
    {
      backtrace.next = backtrace_list;
      backtrace_list = &backtrace;
      backtrace.function = &Qcall_interactively;
      backtrace.args = &cmd;
      backtrace.nargs = 1;
      backtrace.evalargs = 0;

      tem = Fcall_interactively (cmd, record);

      backtrace_list = backtrace.next;
      return tem;
    }
  return Qnil;
}

DEFUN ("execute-extended-command", Fexecute_extended_command, Sexecute_extended_command,
  1, 1, "P",
  "Read function name, then read its arguments and call it.")
  (prefixarg)
     Lisp_Object prefixarg;
{
  Lisp_Object function;
  char buf[40];
  Lisp_Object saved_keys;
  struct gcpro gcpro1;

  saved_keys = Fthis_command_keys ();
  buf[0] = 0;
  GCPRO1 (saved_keys);

  if (EQ (prefixarg, Qminus))
    strcpy (buf, "- ");
  else if (CONSP (prefixarg) && XINT (XCONS (prefixarg)->car) == 4)
    strcpy (buf, "C-u ");
  else if (CONSP (prefixarg) && XTYPE (XCONS (prefixarg)->car) == Lisp_Int)
    sprintf (buf, "%d ", XINT (XCONS (prefixarg)->car));
  else if (XTYPE (prefixarg) == Lisp_Int)
    sprintf (buf, "%d ", XINT (prefixarg));

  /* This isn't strictly correct if execute-extended-command
     is bound to anything else.  Perhaps it should use
     this_command_keys?  */
  strcat (buf, "M-x ");

  /* Prompt with buf, and then read a string, completing from and
     restricting to the set of all defined commands.  Don't provide
     any initial input.  The last Qnil says not to perform a 
     peculiar hack on the initial input.  */
  function = Fcompleting_read (build_string (buf),
			       Vobarray, Qcommandp,
			       Qt, Qnil, Qnil);

  /* Set this_command_keys to the concatenation of saved_keys and
     function, followed by a RET.  */
  {
    struct Lisp_String *str;
    int i;
    Lisp_Object tem;

    this_command_key_count = 0;

    str = XSTRING (saved_keys);
    for (i = 0; i < str->size; i++)
      {
	XFASTINT (tem) = str->data[i];
	add_command_key (tem);
      }

    str = XSTRING (function);
    for (i = 0; i < str->size; i++)
      {
	XFASTINT (tem) = str->data[i];
	add_command_key (tem);
      }

    XFASTINT (tem) = '\015';
    add_command_key (tem);
  }

  UNGCPRO;

  function = Fintern (function, Vobarray);
  Vprefix_arg = prefixarg;
  this_command = function;

  return Fcommand_execute (function, Qt);
}


detect_input_pending ()
{
  if (!input_pending)
    get_input_pending (&input_pending);

  return input_pending;
}

/* This is called in some cases before a possible quit.
   It cases the next call to detect_input_pending to recompute input_pending.
   So calling this function unnecessarily can't do any harm.  */
clear_input_pending ()
{
  input_pending = 0;
}

DEFUN ("input-pending-p", Finput_pending_p, Sinput_pending_p, 0, 0, 0,
  "T if command input is currently available with no waiting.\n\
Actually, the value is nil only if we can be sure that no input is available.")
  ()
{
  if (!NILP (unread_command_char))
    return (Qt);

  return detect_input_pending () ? Qt : Qnil;
}

DEFUN ("recent-keys", Frecent_keys, Srecent_keys, 0, 0, 0,
  "Return vector of last 100 chars read from terminal.")
  ()
{
  Lisp_Object val;

  if (total_keys < NUM_RECENT_KEYS)
    return Fvector (total_keys, recent_keys);
  else
    {
      val = Fvector (NUM_RECENT_KEYS, recent_keys);
      bcopy (recent_keys + recent_keys_index,
	     XVECTOR (val)->contents,
	     (NUM_RECENT_KEYS - recent_keys_index) * sizeof (Lisp_Object));
      bcopy (recent_keys,
	     XVECTOR (val)->contents + NUM_RECENT_KEYS - recent_keys_index,
	     recent_keys_index * sizeof (Lisp_Object));
      return val;
    }
}

DEFUN ("this-command-keys", Fthis_command_keys, Sthis_command_keys, 0, 0, 0,
  "Return string of the keystrokes that invoked this command.")
  ()
{
  return make_array (this_command_key_count, this_command_keys);
}

DEFUN ("recursion-depth", Frecursion_depth, Srecursion_depth, 0, 0, 0,
  "Return the current depth in recursive edits.")
  ()
{
  Lisp_Object temp;
  XFASTINT (temp) = command_loop_level + minibuf_level;
  return temp;
}

DEFUN ("open-dribble-file", Fopen_dribble_file, Sopen_dribble_file, 1, 1,
  "FOpen dribble file: ",
  "Start writing all keyboard characters to FILE.")
  (file)
     Lisp_Object file;
{
  if (NILP (file))
    {
      fclose (dribble);
      dribble = 0;
    }
  else
    {
      file = Fexpand_file_name (file, Qnil);
      dribble = fopen (XSTRING (file)->data, "w");
    }
  return Qnil;
}

DEFUN ("discard-input", Fdiscard_input, Sdiscard_input, 0, 0, 0,
  "Discard the contents of the terminal input buffer.\n\
Also cancel any kbd macro being defined.")
  ()
{
  defining_kbd_macro = 0;
  update_mode_lines++;

  unread_command_char = Qnil;

  discard_tty_input ();

  kbd_fetch_ptr = kbd_store_ptr;
  input_pending = 0;

  return Qnil;
}

DEFUN ("suspend-emacs", Fsuspend_emacs, Ssuspend_emacs, 0, 1, "",
  "Stop Emacs and return to superior process.  You can resume later.\n\
On systems that don't have job control, run a subshell instead.\n\n\
If optional arg STUFFSTRING is non-nil, its characters are stuffed\n\
to be read as terminal input by Emacs's superior shell.\n\
Before suspending, if `suspend-hook' is bound and value is non-nil\n\
call the value as a function of no args.  Don't suspend if it returns non-nil.\n\
Otherwise, suspend normally and after resumption call\n\
`suspend-resume-hook' if that is bound and non-nil.\n\
\n\
Some operating systems cannot stop the Emacs process and resume it later.\n\
On such systems, Emacs will start a subshell and wait for it to exit.")
  (stuffstring)
     Lisp_Object stuffstring;
{
  register Lisp_Object tem;
  int count = specpdl_ptr - specpdl;
  int old_height, old_width;
  int width, height;
  struct gcpro gcpro1;
  extern init_sys_modes ();

  if (!NILP (stuffstring))
    CHECK_STRING (stuffstring, 0);
  GCPRO1 (stuffstring);

  /* Call value of suspend-hook
     if it is bound and value is non-nil.  */
  if (!NILP (Vrun_hooks))
    {
      tem = call1 (Vrun_hooks, intern ("suspend-hook"));
      if (!EQ (tem, Qnil)) return Qnil;
    }

  get_frame_size (&old_width, &old_height);
  reset_sys_modes ();
  /* sys_suspend can get an error if it tries to fork a subshell
     and the system resources aren't available for that.  */
  record_unwind_protect (init_sys_modes, 0);
  stuff_buffered_input (stuffstring);
  sys_suspend ();
  unbind_to (count, Qnil);

  /* Check if terminal/window size has changed.
     Note that this is not useful when we are running directly
     with a window system; but suspend should be disabled in that case.  */
  get_frame_size (&width, &height);
  if (width != old_width || height != old_height)
    change_frame_size (0, height, width, 0, 0);

  /* Call value of suspend-resume-hook
     if it is bound and value is non-nil.  */
  if (!NILP (Vrun_hooks))
    call1 (Vrun_hooks, intern ("suspend-resume-hook"));
  
  UNGCPRO;
  return Qnil;
}

/* If STUFFSTRING is a string, stuff its contents as pending terminal input.
   Then in any case stuff anthing Emacs has read ahead and not used.  */

stuff_buffered_input (stuffstring)
     Lisp_Object stuffstring;
{
  register unsigned char *p;

/* stuff_char works only in BSD, versions 4.2 and up.  */
#ifdef BSD
#ifndef BSD4_1
  if (XTYPE (stuffstring) == Lisp_String)
    {
      register int count;

      p = XSTRING (stuffstring)->data;
      count = XSTRING (stuffstring)->size;
      while (count-- > 0)
	stuff_char (*p++);
      stuff_char ('\n');
    }
  /* Anything we have read ahead, put back for the shell to read.  */
  while (kbd_fetch_ptr != kbd_store_ptr)
    {
      if (kbd_fetch_ptr == kbd_buffer + KBD_BUFFER_SIZE)
	kbd_fetch_ptr = kbd_buffer;
      if (kbd_fetch_ptr->kind == ascii_keystroke)
	stuff_char (XINT (kbd_fetch_ptr->code));
      kbd_fetch_ptr++;
    }
  input_pending = 0;
#endif
#endif /* BSD and not BSD4_1 */
}

set_waiting_for_input (time_to_clear)
     EMACS_TIME *time_to_clear;
{
  input_available_clear_time = time_to_clear;

  /* Tell interrupt_signal to throw back to read_char,  */
  waiting_for_input = 1;

  /* If interrupt_signal was called before and buffered a C-g,
     make it run again now, to avoid timing error. */
  if (!NILP (Vquit_flag))
    quit_throw_to_read_char ();

  /* If alarm has gone off already, echo now.  */
  if (echo_flag)
    {
      echo ();
      echo_flag = 0;
    }
}

clear_waiting_for_input ()
{
  /* Tell interrupt_signal not to throw back to read_char,  */
  waiting_for_input = 0;
  input_available_clear_time = 0;
}

/* This routine is called at interrupt level in response to C-G.
 If interrupt_input, this is the handler for SIGINT.
 Otherwise, it is called from kbd_buffer_store_event,
 in handling SIGIO or SIGTINT.

 If `waiting_for_input' is non zero, then unless `echoing' is nonzero,
 immediately throw back to read_char.

 Otherwise it sets the Lisp variable  quit-flag  not-nil.
 This causes  eval  to throw, when it gets a chance.
 If  quit-flag  is already non-nil, it stops the job right away.  */

SIGTYPE
interrupt_signal ()
{
  char c;
  /* Must preserve main program's value of errno.  */
  int old_errno = errno;
  extern Lisp_Object Vwindow_system;

#ifdef USG
  /* USG systems forget handlers when they are used;
     must reestablish each time */
  signal (SIGINT, interrupt_signal);
  signal (SIGQUIT, interrupt_signal);
#endif /* USG */

  cancel_echoing ();

  if (!NILP (Vquit_flag) && FRAME_TERMCAP_P (selected_frame))
    {
      fflush (stdout);
      reset_sys_modes ();
      sigfree ();
#ifdef SIGTSTP			/* Support possible in later USG versions */
/*
 * On systems which can suspend the current process and return to the original
 * shell, this command causes the user to end up back at the shell.
 * The "Auto-save" and "Abort" questions are not asked until
 * the user elects to return to emacs, at which point he can save the current
 * job and either dump core or continue.
 */
      sys_suspend ();
#else
#ifdef VMS
      if (sys_suspend () == -1)
	{
	  printf ("Not running as a subprocess;\n");
	  printf ("you can continue or abort.\n");
	}
#else /* not VMS */
      /* Perhaps should really fork an inferior shell?
	 But that would not provide any way to get back
	 to the original shell, ever.  */
      printf ("No support for stopping a process on this operating system;\n");
      printf ("you can continue or abort.\n");
#endif /* not VMS */
#endif /* not SIGTSTP */
      printf ("Auto-save? (y or n) ");
      fflush (stdout);
      if (((c = getchar ()) & ~040) == 'Y')
	Fdo_auto_save (Qnil, Qnil);
      while (c != '\n') c = getchar ();
#ifdef VMS
      printf ("Abort (and enter debugger)? (y or n) ");
#else /* not VMS */
      printf ("Abort (and dump core)? (y or n) ");
#endif /* not VMS */
      fflush (stdout);
      if (((c = getchar ()) & ~040) == 'Y')
	abort ();
      while (c != '\n') c = getchar ();
      printf ("Continuing...\n");
      fflush (stdout);
      init_sys_modes ();
    }
  else
    {
      /* If executing a function that wants to be interrupted out of
	 and the user has not deferred quitting by binding `inhibit-quit'
	 then quit right away.  */
      if (immediate_quit && NILP (Vinhibit_quit))
	{
	  immediate_quit = 0;
          sigfree ();
	  Fsignal (Qquit, Qnil);
	}
      else
	/* Else request quit when it's safe */
	Vquit_flag = Qt;
    }

  if (waiting_for_input && !echoing)
    quit_throw_to_read_char ();

  errno = old_errno;
}

/* Handle a C-g by making read_char return C-g.  */

quit_throw_to_read_char ()
{
  quit_error_check ();
  sigfree ();
  /* Prevent another signal from doing this before we finish.  */
  clear_waiting_for_input ();
  input_pending = 0;

  unread_command_char = Qnil;

  _longjmp (getcjmp, 1);
}

DEFUN ("set-input-mode", Fset_input_mode, Sset_input_mode, 3, 4, 0,
  "Set mode of reading keyboard input.\n\
First arg INTERRUPT non-nil means use input interrupts;\n\
 nil means use CBREAK mode.\n\
Second arg FLOW non-nil means use ^S/^Q flow control for output to terminal\n\
 (no effect except in CBREAK mode).\n\
Third arg META non-nil means accept 8-bit input (for a Meta key).\n\
 Otherwise, the top bit is ignored, on the assumption it is parity.\n\
Optional fourth arg QUIT if non-nil specifies character to use for quitting.")
  (interrupt, flow, meta, quit)
     Lisp_Object interrupt, flow, meta, quit;
{
  if (!NILP (quit)
      && (XTYPE (quit) != Lisp_Int
	  || XINT (quit) < 0 || XINT (quit) > 0400))
    error ("set-input-mode: QUIT must be an ASCII character.");

  reset_sys_modes ();
#ifdef SIGIO
/* Note SIGIO has been undef'd if FIONREAD is missing.  */
#ifdef NO_SOCK_SIGIO
  if (read_socket_hook)
    interrupt_input = 0;	/* No interrupts if reading from a socket.  */
  else
#endif /* NO_SOCK_SIGIO */
    interrupt_input = !NILP (interrupt);
#else /* not SIGIO */
  interrupt_input = 0;
#endif /* not SIGIO */
/* Our VMS input only works by interrupts, as of now.  */
#ifdef VMS
  interrupt_input = 1;
#endif
  flow_control = !NILP (flow);
  meta_key = !NILP (meta);
  if (!NILP (quit))
    /* Don't let this value be out of range.  */
    quit_char = XINT (quit) & (meta_key ? 0377 : 0177);

  init_sys_modes ();
  return Qnil;
}

init_keyboard ()
{
  this_command_keys_size = 40;
  this_command_keys =
    (Lisp_Object *) xmalloc (this_command_keys_size * sizeof (Lisp_Object));

  /* This is correct before outermost invocation of the editor loop */
  command_loop_level = -1;
  immediate_quit = 0;
  quit_char = Ctl ('g');
  unread_command_char = Qnil;
  recent_keys_index = 0;
  total_keys = 0;
  kbd_fetch_ptr = kbd_buffer;
  kbd_store_ptr = kbd_buffer;
  do_mouse_tracking = 0;
  input_pending = 0;

  if (!noninteractive)
    {
      signal (SIGINT, interrupt_signal);
#ifdef HAVE_TERMIO
      /* For systems with SysV TERMIO, C-g is set up for both SIGINT and
	 SIGQUIT and we can't tell which one it will give us.  */
      signal (SIGQUIT, interrupt_signal);
#endif /* HAVE_TERMIO */
/* Note SIGIO has been undef'd if FIONREAD is missing.  */
#ifdef SIGIO
      signal (SIGIO, input_available_signal);
#endif /* SIGIO */
    }

/* Use interrupt input by default, if it works and noninterrupt input
   has deficiencies.  */

#ifdef INTERRUPT_INPUT
  interrupt_input = 1;
#else
  interrupt_input = 0;
#endif

/* Our VMS input only works by interrupts, as of now.  */
#ifdef VMS
  interrupt_input = 1;
#endif

  sigfree ();
  dribble = 0;

  if (keyboard_init_hook)
    (*keyboard_init_hook) ();

#ifdef POLL_FOR_INPUT
  poll_suppress_count = 1;
  start_polling ();
#endif
}

/* This type's only use is in syms_of_keyboard, to initialize the 
   event header symbols and put properties on them.  */
struct event_head {
  Lisp_Object *var;
  char *name;
  Lisp_Object *kind;
};

struct event_head head_table[] = {
  &Qmouse_movement,  "mouse-movement",   &Qmouse_movement,
  &Qvscrollbar_part, "vscrollbar-part",  &Qscrollbar_click,
  &Qvslider_part,    "vslider-part",     &Qscrollbar_click,
  &Qvthumbup_part,   "vthumbup-part",    &Qscrollbar_click,
  &Qvthumbdown_part, "vthumbdown-part",  &Qscrollbar_click,
  &Qhscrollbar_part, "hscrollbar-part",  &Qscrollbar_click,
  &Qhslider_part,    "hslider-part",     &Qscrollbar_click,
  &Qhthumbleft_part, "hthumbleft-part",  &Qscrollbar_click,
  &Qhthumbright_part,"hthumbright-part", &Qscrollbar_click
};

syms_of_keyboard ()
{
  Qself_insert_command = intern ("self-insert-command");
  staticpro (&Qself_insert_command);

  Qforward_char = intern ("forward-char");
  staticpro (&Qforward_char);

  Qbackward_char = intern ("backward-char");
  staticpro (&Qbackward_char);

  Qdisabled = intern ("disabled");
  staticpro (&Qdisabled);

  Qfunction_key = intern ("function-key");
  staticpro (&Qfunction_key);
  Qmouse_movement = intern ("mouse-click");
  staticpro (&Qmouse_click);
  Qmouse_movement = intern ("scrollbar-click");
  staticpro (&Qmouse_movement);

  Qmode_line = intern ("mode-line");
  staticpro (&Qmode_line);
  Qvertical_line = intern ("vertical-line");
  staticpro (&Qvertical_line);

  Qevent_kind = intern ("event-type");
  staticpro (&Qevent_kind);
  Qevent_unmodified = intern ("event-unmodified");
  staticpro (&Qevent_unmodified);

  {
    struct event_head *p;

    for (p = head_table;
	 p < head_table + (sizeof (head_table) / sizeof (head_table[0]));
	 p++)
      {
	*p->var = intern (p->name);
	staticpro (p->var);
	Fput (*p->var, Qevent_kind, *p->kind);
	Fput (*p->var, Qevent_unmodified, *p->var);
      }
  }

  func_key_syms = Qnil;
  staticpro (&func_key_syms);

  mouse_syms = Qnil;
  staticpro (&mouse_syms);

  defsubr (&Sread_key_sequence);
  defsubr (&Srecursive_edit);
  defsubr (&Strack_mouse);
  defsubr (&Smouse_click_p);
  defsubr (&Sinput_pending_p);
  defsubr (&Scommand_execute);
  defsubr (&Srecent_keys);
  defsubr (&Sthis_command_keys);
  defsubr (&Ssuspend_emacs);
  defsubr (&Sabort_recursive_edit);
  defsubr (&Sexit_recursive_edit);
  defsubr (&Srecursion_depth);
  defsubr (&Stop_level);
  defsubr (&Sdiscard_input);
  defsubr (&Sopen_dribble_file);
  defsubr (&Sset_input_mode);
  defsubr (&Sexecute_extended_command);

  DEFVAR_LISP ("disabled-command-hook", &Vdisabled_command_hook,
    "Value is called instead of any command that is disabled\n\
\(has a non-nil `disabled' property).");

  DEFVAR_LISP ("last-command-char", &last_command_char,
    "Last terminal input key that was part of a command.");

  DEFVAR_LISP ("last-nonmenu-event", &last_nonmenu_event,
    "Last terminal input key in a command, except for mouse menus.\n\
Mouse menus give back keys that don't look like mouse events;\n\
this variable holds the actual mouse event that led to the menu,\n\
so that you can determine whether the command was run by mouse or not.");

  DEFVAR_LISP ("last-input-char", &last_input_char,
    "Last terminal input key.");

  DEFVAR_LISP ("unread-command-char", &unread_command_char,
    "Object to be read as next input from input stream, or nil if none.");

  DEFVAR_LISP ("meta-prefix-char", &meta_prefix_char,
    "Meta-prefix character code.  Meta-foo as command input\n\
turns into this character followed by foo.");
  XSET (meta_prefix_char, Lisp_Int, 033);

  DEFVAR_LISP ("last-command", &last_command,
    "The last command executed.  Normally a symbol with a function definition,\n\
but can be whatever was found in the keymap, or whatever the variable\n\
`this-command' was set to by that command.");
  last_command = Qnil;

  DEFVAR_LISP ("this-command", &this_command,
    "The command now being executed.\n\
The command can set this variable; whatever is put here\n\
will be in `last-command' during the following command.");
  this_command = Qnil;

  DEFVAR_INT ("auto-save-interval", &auto_save_interval,
    "*Number of keyboard input characters between auto-saves.\n\
Zero means disable autosaving due to number of characters typed.");
  auto_save_interval = 300;

  DEFVAR_LISP ("auto-save-timeout", &Vauto_save_timeout,
    "*Number of seconds idle time before auto-save.\n\
Zero or nil means disable auto-saving due to idleness.\n\
After auto-saving due to this many seconds of idle time,\n\
Emacs also does a garbage collection if that seems to be warranted.");
  XFASTINT (Vauto_save_timeout) = 30;

  DEFVAR_INT ("echo-keystrokes", &echo_keystrokes,
    "*Nonzero means echo unfinished commands after this many seconds of pause.");
  echo_keystrokes = 1;

  DEFVAR_INT ("polling-period", &polling_period,
    "*Interval between polling for input during Lisp execution.\n\
The reason for polling is to make C-g work to stop a running program.\n\
Polling is needed only when using X windows and SIGIO does not work.\n\
Polling is automatically disabled in all other cases.");
  polling_period = 2;
  
  DEFVAR_INT ("num-input-keys", &num_input_keys,
    "*Number of complete keys read from the keyboard so far.");
  num_input_keys = 0;

#ifdef MULTI_FRAME
  DEFVAR_LISP ("last-event-frame", &Vlast_event_frame,
    "*The frame in which the most recently read event occurred.");
  Vlast_event_frame = Qnil;
#endif

  DEFVAR_LISP ("help-char", &help_char,
    "Character to recognize as meaning Help.\n\
When it is read, do `(eval help-form)', and display result if it's a string.\n\
If the value of `help-form' is nil, this char can be read normally.");
  XSET (help_char, Lisp_Int, Ctl ('H'));

  DEFVAR_LISP ("help-form", &Vhelp_form,
    "Form to execute when character help-char is read.\n\
If the form returns a string, that string is displayed.\n\
If `help-form' is nil, the help char is not recognized.");
  Vhelp_form = Qnil;

  DEFVAR_LISP ("top-level", &Vtop_level,
    "Form to evaluate when Emacs starts up.\n\
Useful to set before you dump a modified Emacs.");
  Vtop_level = Qnil;

  DEFVAR_LISP ("keyboard-translate-table", &Vkeyboard_translate_table,
    "String used as translate table for keyboard input, or nil.\n\
Each character is looked up in this string and the contents used instead.\n\
If string is of length N, character codes N and up are untranslated.");
  Vkeyboard_translate_table = Qnil;

  DEFVAR_BOOL ("menu-prompting", &menu_prompting,
    "Non-nil means prompt with menus when appropriate.\n\
This is done when reading from a keymap that has a prompt string,\n\
for elements that have prompt strings.\n\
The menu is displayed on the screen\n\
if X menus were enabled at configuration\n\
time and the previous event was a mouse click prefix key.\n\
Otherwise, menu prompting uses the echo area.");
  menu_prompting = 1;

  DEFVAR_LISP ("menu-prompt-more-char", &menu_prompt_more_char,
    "Character to see next line of menu prompt.\n\
Type this character while in a menu prompt to rotate around the lines of it.");
  XSET (menu_prompt_more_char, Lisp_Int, ' ');
}

keys_of_keyboard ()
{
  initial_define_key (global_map, Ctl ('Z'), "suspend-emacs");
  initial_define_key (control_x_map, Ctl ('Z'), "suspend-emacs");
  initial_define_key (meta_map, Ctl ('C'), "exit-recursive-edit");
  initial_define_key (global_map, Ctl (']'), "abort-recursive-edit");
  initial_define_key (meta_map, 'x', "execute-extended-command");
}
