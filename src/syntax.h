/* Declarations having to do with GNU Emacs syntax tables.

Copyright (C) 1985, 1993-1994, 1997-1998, 2001-2013 Free Software
Foundation, Inc.

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

INLINE_HEADER_BEGIN
#ifndef SYNTAX_INLINE
# define SYNTAX_INLINE INLINE
#endif

extern void update_syntax_table (ptrdiff_t, EMACS_INT, bool, Lisp_Object);

/* The standard syntax table is stored where it will automatically
   be used in all new buffers.  */
#define Vstandard_syntax_table BVAR (&buffer_defaults, syntax_table)

/* A syntax table is a chartable whose elements are cons cells
   (CODE+FLAGS . MATCHING-CHAR).  MATCHING-CHAR can be nil if the char
   is not a kind of parenthesis.

   The low 8 bits of CODE+FLAGS is a code, as follows:  */

enum syntaxcode
  {
    Swhitespace, /* for a whitespace character */
    Spunct,	 /* for random punctuation characters */
    Sword,	 /* for a word constituent */
    Ssymbol,	 /* symbol constituent but not word constituent */
    Sopen,	 /* for a beginning delimiter */
    Sclose,      /* for an ending delimiter */
    Squote,	 /* for a prefix character like Lisp ' */
    Sstring,	 /* for a string-grouping character like Lisp " */
    Smath,	 /* for delimiters like $ in Tex.  */
    Sescape,	 /* for a character that begins a C-style escape */
    Scharquote,  /* for a character that quotes the following character */
    Scomment,    /* for a comment-starting character */
    Sendcomment, /* for a comment-ending character */
    Sinherit,    /* use the standard syntax table for this character */
    Scomment_fence, /* Starts/ends comment which is delimited on the
		       other side by any char with the same syntaxcode.  */
    Sstring_fence,  /* Starts/ends string which is delimited on the
		       other side by any char with the same syntaxcode.  */
    Smax	 /* Upper bound on codes that are meaningful */
  };


struct gl_state_s
{
  Lisp_Object object;			/* The object we are scanning. */
  ptrdiff_t start;			/* Where to stop. */
  ptrdiff_t stop;			/* Where to stop. */
  bool use_global;			/* Whether to use global_code
					   or c_s_t. */
  Lisp_Object global_code;		/* Syntax code of current char. */
  Lisp_Object current_syntax_table;	/* Syntax table for current pos. */
  Lisp_Object old_prop;			/* Syntax-table prop at prev pos. */
  ptrdiff_t b_property;			/* First index where c_s_t is valid. */
  ptrdiff_t e_property;			/* First index where c_s_t is
					   not valid. */
  INTERVAL forward_i;			/* Where to start lookup on forward */
  INTERVAL backward_i;			/* or backward movement.  The
					   data in c_s_t is valid
					   between these intervals,
					   and possibly at the
					   intervals too, depending
					   on: */
  /* Offset for positions specified to UPDATE_SYNTAX_TABLE.  */
  ptrdiff_t offset;
};

extern struct gl_state_s gl_state;

/* Fetch the information from the entry for character C
   in syntax table TABLE, or from globally kept data (gl_state).
   Does inheritance.  */

SYNTAX_INLINE Lisp_Object
SYNTAX_ENTRY (int c)
{
#ifdef SYNTAX_ENTRY_VIA_PROPERTY
  return (gl_state.use_global
	  ? gl_state.global_code
	  : CHAR_TABLE_REF (gl_state.current_syntax_table, c));
#else
  return CHAR_TABLE_REF (BVAR (current_buffer, syntax_table), c);
#endif
}

/* Extract the information from the entry for character C
   in the current syntax table.  */

SYNTAX_INLINE int
SYNTAX_WITH_FLAGS (int c)
{
  Lisp_Object ent = SYNTAX_ENTRY (c);
  return CONSP (ent) ? XINT (XCAR (ent)) : Swhitespace;
}

SYNTAX_INLINE enum syntaxcode
SYNTAX (int c)
{
  return SYNTAX_WITH_FLAGS (c) & 0xff;
}


/* Whether the syntax of the character C has the prefix flag set.  */
extern bool syntax_prefix_flag_p (int c);

/* This array, indexed by a character less than 256, contains the
   syntax code which that character signifies (as an unsigned char).
   For example, syntax_spec_code['w'] == Sword.  */

extern unsigned char const syntax_spec_code[0400];

/* Indexed by syntax code, give the letter that describes it.  */

extern char const syntax_code_spec[16];

/* Convert the byte offset BYTEPOS into a character position,
   for the object recorded in gl_state with SETUP_SYNTAX_TABLE_FOR_OBJECT.

   The value is meant for use in code that does nothing when
   parse_sexp_lookup_properties is 0, so return 0 in that case, for speed.  */

SYNTAX_INLINE ptrdiff_t
SYNTAX_TABLE_BYTE_TO_CHAR (ptrdiff_t bytepos)
{
  return (! parse_sexp_lookup_properties
	  ? 0
	  : STRINGP (gl_state.object)
	  ? string_byte_to_char (gl_state.object, bytepos)
	  : BUFFERP (gl_state.object)
	  ? ((buf_bytepos_to_charpos
	      (XBUFFER (gl_state.object),
	       (bytepos + BUF_BEGV_BYTE (XBUFFER (gl_state.object)) - 1)))
	     - BUF_BEGV (XBUFFER (gl_state.object)) + 1)
	  : NILP (gl_state.object)
	  ? BYTE_TO_CHAR (bytepos + BEGV_BYTE - 1) - BEGV + 1
	  : bytepos);
}

/* Make syntax table state (gl_state) good for CHARPOS, assuming it is
   currently good for a position before CHARPOS.  */

SYNTAX_INLINE void
UPDATE_SYNTAX_TABLE_FORWARD (ptrdiff_t charpos)
{
  if (parse_sexp_lookup_properties && charpos >= gl_state.e_property)
    update_syntax_table (charpos + gl_state.offset, 1, 0, gl_state.object);
}

/* Make syntax table state (gl_state) good for CHARPOS, assuming it is
   currently good for a position after CHARPOS.  */

SYNTAX_INLINE void
UPDATE_SYNTAX_TABLE_BACKWARD (ptrdiff_t charpos)
{
  if (parse_sexp_lookup_properties && charpos < gl_state.b_property)
    update_syntax_table (charpos + gl_state.offset, -1, 0, gl_state.object);
}

/* Make syntax table good for CHARPOS.  */

SYNTAX_INLINE void
UPDATE_SYNTAX_TABLE (ptrdiff_t charpos)
{
  UPDATE_SYNTAX_TABLE_BACKWARD (charpos);
  UPDATE_SYNTAX_TABLE_FORWARD (charpos);
}

/* Set up the buffer-global syntax table.  */

SYNTAX_INLINE void
SETUP_BUFFER_SYNTAX_TABLE (void)
{
  gl_state.use_global = 0;
  gl_state.current_syntax_table = BVAR (current_buffer, syntax_table);
}

extern ptrdiff_t scan_words (ptrdiff_t, EMACS_INT);
extern void SETUP_SYNTAX_TABLE_FOR_OBJECT (Lisp_Object, ptrdiff_t, ptrdiff_t);

INLINE_HEADER_END
