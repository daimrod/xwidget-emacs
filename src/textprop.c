/* Interface code for dealing with text properties.
   Copyright (C) 1992 Free Software Foundation, Inc.

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

#include "config.h"
#include "lisp.h"
#include "intervals.h"
#include "buffer.h"


/* NOTES:  previous- and next- property change will have to skip
  zero-length intervals if they are implemented.  This could be done
  inside next_interval and previous_interval.

  It is assumed that for any interval plist, a property appears
  only once on the list.  Although some code i.e., remove_properties (),
  handles the more general case, the uniqueness of properties is
  neccessary for the system to remain consistent.  This requirement
  is enforced by the subrs installing properties onto the intervals. */


/* Types of hooks. */
Lisp_Object Qmouse_left;
Lisp_Object Qmouse_entered;
Lisp_Object Qpoint_left;
Lisp_Object Qpoint_entered;
Lisp_Object Qmodification;

/* Visual properties text (including strings) may have. */
Lisp_Object Qforeground, Qbackground, Qfont, Qunderline, Qstipple;
Lisp_Object Qinvisible, Qread_only;

/* Extract the interval at position BEGIN from OBJECT, a string
   or buffer.  Additionally, check that BEGIN and END are within
   the bounds of OBJECT.

   Note that buffer points don't correspond to interval indices.
   For example, point-max is 1 greater than the index of the last
   character.  This difference is handled in the caller, which uses
   the validated points to determine a length, and operates on that.
   Exceptions are Ftext_properties_at, Fnext_property_change, and
   Fprevious_property_change which call this function with BEGIN == END.
   Handle this case specially.

   If FORCE is soft (0), it's OK to return NULL_INTERVAL.  Otherwise,
   create an interval tree for OBJECT if one doesn't exist. */

#define soft 0
#define hard 1

static INTERVAL
validate_interval_range (object, begin, end, force)
     Lisp_Object object, *begin, *end;
     int force;
{
  register INTERVAL i;
  CHECK_STRING_OR_BUFFER (object, 0);
  CHECK_NUMBER_COERCE_MARKER (*begin, 0);
  CHECK_NUMBER_COERCE_MARKER (*end, 0);

  /* If we are asked for a point, but from a subr which operates
     on a range, then return nothing. */
  if (*begin == *end && begin != end)
    return NULL_INTERVAL;

  if (XINT (*begin) > XINT (*end))
    {
      register int n;
      n = XFASTINT (*begin);	/* This is legit even if *begin is < 0 */
      *begin = *end;
      XFASTINT (*end) = n;	/* because this is all we do with n.  */
    }

  if (XTYPE (object) == Lisp_Buffer)
    {
      register struct buffer *b = XBUFFER (object);

      /* If there's no text, there are no properties. */
      if (BUF_BEGV (b) == BUF_ZV (b))
	return NULL_INTERVAL;

      if (!(BUF_BEGV (b) <= XINT (*begin) && XINT (*begin) <= XINT (*end)
	    && XINT (*end) <= BUF_ZV (b)))
	args_out_of_range (*begin, *end);
      i = b->intervals;

      /* Special case for point-max:  return the interval for the
         last character. */
      if (*begin == *end && *begin == BUF_Z (b))
	*begin -= 1;
    }
  else
    {
      register struct Lisp_String *s = XSTRING (object);

      if (! (1 <= XINT (*begin) && XINT (*begin) <= XINT (*end)
	     && XINT (*end) <= s->size))
	args_out_of_range (*begin, *end);
      i = s->intervals;
    }

  if (NULL_INTERVAL_P (i))
    return (force ? create_root_interval (object) : i);
    
  return find_interval (i, XINT (*begin));
}

/* Validate LIST as a property list.  If LIST is not a list, then
   make one consisting of (LIST nil).  Otherwise, verify that LIST
   is even numbered and thus suitable as a plist. */

static Lisp_Object
validate_plist (list)
{
  if (NILP (list))
    return Qnil;

  if (CONSP (list))
    {
      register int i;
      register Lisp_Object tail;
      for (i = 0, tail = list; !NILP (tail); i++)
	tail = Fcdr (tail);
      if (i & 1)
	error ("Odd length text property list");
      return list;
    }

  return Fcons (list, Fcons (Qnil, Qnil));
}

#define set_properties(list,i) (i->plist = Fcopy_sequence (list))

/* Return nonzero if interval I has all the properties,
   with the same values, of list PLIST. */

static int
interval_has_all_properties (plist, i)
     Lisp_Object plist;
     INTERVAL i;
{
  register Lisp_Object tail1, tail2, sym1, sym2;
  register int found;

  /* Go through each element of PLIST. */
  for (tail1 = plist; ! NILP (tail1); tail1 = Fcdr (Fcdr (tail1)))
    {
      sym1 = Fcar (tail1);
      found = 0;

      /* Go through I's plist, looking for sym1 */
      for (tail2 = i->plist; ! NILP (tail2); tail2 = Fcdr (Fcdr (tail2)))
	if (EQ (sym1, Fcar (tail2)))
	  {
	    /* Found the same property on both lists.  If the
	       values are unequal, return zero. */
	    if (! EQ (Fequal (Fcar (Fcdr (tail1)), Fcar (Fcdr (tail2))),
		      Qt))
	      return 0;

	    /* Property has same value on both lists;  go to next one. */
	    found = 1;
	    break;
	  }

      if (! found)
	return 0;
    }

  return 1;
}

/* Return nonzero if the plist of interval I has any of the
   properties of PLIST, regardless of their values. */

static INLINE int
interval_has_some_properties (plist, i)
     Lisp_Object plist;
     INTERVAL i;
{
  register Lisp_Object tail1, tail2, sym;

  /* Go through each element of PLIST. */
  for (tail1 = plist; ! NILP (tail1); tail1 = Fcdr (Fcdr (tail1)))
    {
      sym = Fcar (tail1);

      /* Go through i's plist, looking for tail1 */
      for (tail2 = i->plist; ! NILP (tail2); tail2 = Fcdr (Fcdr (tail2)))
	if (EQ (sym, Fcar (tail2)))
	  return 1;
    }

  return 0;
}

/* Add the properties of PLIST to the interval I, or set
   the value of I's property to the value of the property on PLIST
   if they are different.

   Return nonzero if this changes I (i.e., if any members of PLIST
   are actually added to I's plist) */

static INLINE int
add_properties (plist, i)
     Lisp_Object plist;
     INTERVAL i;
{
  register Lisp_Object tail1, tail2, sym1, val1;
  register int changed = 0;
  register int found;

  /* Go through each element of PLIST. */
  for (tail1 = plist; ! NILP (tail1); tail1 = Fcdr (Fcdr (tail1)))
    {
      sym1 = Fcar (tail1);
      val1 = Fcar (Fcdr (tail1));
      found = 0;

      /* Go through I's plist, looking for sym1 */
      for (tail2 = i->plist; ! NILP (tail2); tail2 = Fcdr (Fcdr (tail2)))
	if (EQ (sym1, Fcar (tail2)))
	  {
	    register Lisp_Object this_cdr = Fcdr (tail2);

	    /* Found the property.  Now check its value. */
	    found = 1;

	    /* The properties have the same value on both lists.
	       Continue to the next property. */
	    if (Fequal (val1, Fcar (this_cdr)))
	      break;

	    /* I's property has a different value -- change it */
	    Fsetcar (this_cdr, val1);
	    changed++;
	    break;
	  }

      if (! found)
	{
	  i->plist = Fcons (sym1, Fcons (val1, i->plist));
	  changed++;
	}
    }

  return changed;
}

/* For any members of PLIST which are properties of I, remove them
   from I's plist. */

static INLINE int
remove_properties (plist, i)
     Lisp_Object plist;
     INTERVAL i;
{
  register Lisp_Object tail1, tail2, sym;
  register Lisp_Object current_plist = i->plist;
  register int changed = 0;

  /* Go through each element of plist. */
  for (tail1 = plist; ! NILP (tail1); tail1 = Fcdr (Fcdr (tail1)))
    {
      sym = Fcar (tail1);

      /* First, remove the symbol if its at the head of the list */
      while (! NILP (current_plist) && EQ (sym, Fcar (current_plist)))
	{
	  current_plist = Fcdr (Fcdr (current_plist));
	  changed++;
	}

      /* Go through i's plist, looking for sym */
      tail2 = current_plist;
      while (! NILP (tail2))
	{
	  register Lisp_Object this = Fcdr (Fcdr (tail2));
	  if (EQ (sym, Fcar (this)))
	    {
	      Fsetcdr (Fcdr (tail2), Fcdr (Fcdr (this)));
	      changed++;
	    }
	  tail2 = this;
	}
    }

  if (changed)
    i->plist = current_plist;
  return changed;
}

/* Remove all properties from interval I.  Return non-zero
   if this changes the interval. */

static INLINE int
erase_properties (i)
     INTERVAL i;
{
  if (NILP (i->plist))
    return 0;

  i->plist = Qnil;
  return 1;
}


DEFUN ("text-properties-at", Ftext_properties_at,
       Stext_properties_at, 1, 2, 0,
  "Return the list of properties held by the character at POSITION\n\
in optional argument OBJECT, a string or buffer.  If nil, OBJECT\n\
defaults to the current buffer.")
  (pos, object)
     Lisp_Object pos, object;
{
  register INTERVAL i;
  register int p;

  if (NILP (object))
    XSET (object, Lisp_Buffer, current_buffer);

  i = validate_interval_range (object, &pos, &pos, soft);
  if (NULL_INTERVAL_P (i))
    return Qnil;

  return i->plist;
}

DEFUN ("next-property-change", Fnext_property_change,
       Snext_property_change, 2, 2, 0,
  "Return the position after POSITION in OBJECT which has properties\n\
different from those at POSITION.  OBJECT may be a string or buffer.\n\
Returns nil if unsuccessful.")
  (pos, object)
     Lisp_Object pos, object;
{
  register INTERVAL i, next;

  i = validate_interval_range (object, &pos, &pos, soft);
  if (NULL_INTERVAL_P (i))
    return Qnil;

  next = next_interval (i);
  while (! NULL_INTERVAL_P (next) && intervals_equal (i, next))
    next = next_interval (next);

  if (NULL_INTERVAL_P (next))
    return Qnil;

  return next->position;
}

DEFUN ("previous-property-change", Fprevious_property_change,
       Sprevious_property_change, 2, 2, 0,
  "Return the position before POSITION in OBJECT which has properties\n\
different from those at POSITION.  OBJECT may be a string or buffer.\n\
Returns nil if unsuccessful.")
  (pos, object)
     Lisp_Object pos, object;
{
  register INTERVAL i, previous;

  i = validate_interval_range (object, &pos, &pos, soft);
  if (NULL_INTERVAL_P (i))
    return Qnil;

  previous = previous_interval (i);
  while (! NULL_INTERVAL_P (previous) && intervals_equal (previous, i))
    previous = previous_interval (previous);
  if (NULL_INTERVAL_P (previous))
    return Qnil;

  return previous->position + LENGTH (previous) - 1;
}

DEFUN ("add-text-properties", Fadd_text_properties,
       Sadd_text_properties, 4, 4, 0,
  "Add the PROPERTIES (a property list) to the text of OBJECT\n\
(a string or buffer) in the range START to END.  Returns t if any change\n\
was made, nil otherwise.")
  (object, start, end, properties)
     Lisp_Object object, start, end, properties;
{
  register INTERVAL i, unchanged;
  register int s, len, modified;

  properties = validate_plist (properties);
  if (NILP (properties))
    return Qnil;

  i = validate_interval_range (object, &start, &end, hard);
  if (NULL_INTERVAL_P (i))
    return Qnil;

  s = XINT (start);
  len = XINT (end) - s;

  /* If we're not starting on an interval boundary, we have to
    split this interval. */
  if (i->position != s)
    {
      /* If this interval already has the properties, we can
         skip it. */
      if (interval_has_all_properties (properties, i))
	{
	  int got = (LENGTH (i) - (s - i->position));
	  if (got >= len)
	    return Qnil;
	  len -= got;
	}
      else
	{
	  unchanged = i;
	  i = split_interval_right (unchanged, s - unchanged->position + 1);
	  copy_properties (unchanged, i);
	  if (LENGTH (i) > len)
	    {
	      i = split_interval_left (i, len + 1);
	      copy_properties (unchanged, i);
	      add_properties (properties, i);
	      return Qt;
	    }

	  add_properties (properties, i);
	  modified = 1;
	  len -= LENGTH (i);
	  i = next_interval (i);
	}
    }

  /* We are at the beginning of an interval, with len to scan */
  while (1)
    {
      if (LENGTH (i) >= len)
	{
	  if (interval_has_all_properties (properties, i))
	    return modified ? Qt : Qnil;

	  if (LENGTH (i) == len)
	    {
	      add_properties (properties, i);
	      return Qt;
	    }

	  /* i doesn't have the properties, and goes past the change limit */
	  unchanged = i;
	  i = split_interval_left (unchanged, len + 1);
	  copy_properties (unchanged, i);
	  add_properties (properties, i);
	  return Qt;
	}

      len -= LENGTH (i);
      modified += add_properties (properties, i);
      i = next_interval (i);
    }
}

DEFUN ("set-text-properties", Fset_text_properties,
       Sset_text_properties, 4, 4, 0,
  "Make the text of OBJECT (a string or buffer) have precisely\n\
PROPERTIES (a list of properties) in the range START to END.\n\
\n\
If called with a valid property list, return t (text was changed).\n\
Otherwise return nil.")
  (object, start, end, properties)
     Lisp_Object object, start, end, properties;
{
  register INTERVAL i, unchanged;
  register int s, len;

  properties = validate_plist (properties);
  if (NILP (properties))
    return Qnil;

  i = validate_interval_range (object, &start, &end, hard);
  if (NULL_INTERVAL_P (i))
    return Qnil;

  s = XINT (start);
  len = XINT (end) - s;

  if (i->position != s)
    {
      unchanged = i;
      i = split_interval_right (unchanged, s - unchanged->position + 1);
      copy_properties (unchanged, i);
      if (LENGTH (i) > len)
	{
	  i = split_interval_left (i, len);
	  set_properties (properties, i);
	  return Qt;
	}

      set_properties (properties, i);
      len -= LENGTH (i);
      i = next_interval (i);
    }

  while (1)
    {
      if (LENGTH (i) >= len)
	{
	  if (LENGTH (i) == len)
	    {
	      set_properties (properties, i);
	      return Qt;
	    }

	  i = split_interval_left (i, len + 1);
	  set_properties (properties, i);
	  return Qt;
	}

      len -= LENGTH (i);
      set_properties (properties, i);
      i = next_interval (i);
    }

  return Qt;
}

DEFUN ("remove-text-properties", Fremove_text_properties,
       Sremove_text_properties, 4, 4, 0,
  "Remove the PROPERTIES (a property list) from the text of OBJECT\n\
(a string or buffer) in the range START to END.  Returns t if any change\n\
was made, nil otherwise.")
  (object, start, end, properties)
     Lisp_Object object, start, end, properties;
{
  register INTERVAL i, unchanged;
  register int s, len, modified;

  i = validate_interval_range (object, &start, &end, soft);
  if (NULL_INTERVAL_P (i))
    return Qnil;

  s = XINT (start);
  len = XINT (end) - s;
  if (i->position != s)
    {
      /* No properties on this first interval -- return if
         it covers the entire region. */
      if (! interval_has_some_properties (properties, i))
	{
	  int got = (LENGTH (i) - (s - i->position));
	  if (got >= len)
	    return Qnil;
	  len -= got;
	}
      /* Remove the properties from this interval.  If it's short
         enough, return, splitting it if it's too short. */
      else
	{
	  unchanged = i;
	  i = split_interval_right (unchanged, s - unchanged->position + 1);
	  copy_properties (unchanged, i);
	  if (LENGTH (i) > len)
	    {
	      i = split_interval_left (i, len + 1);
	      copy_properties (unchanged, i);
	      remove_properties (properties, i);
	      return Qt;
	    }

	  remove_properties (properties, i);
	  modified = 1;
	  len -= LENGTH (i);
	  i = next_interval (i);
	}
    }

  /* We are at the beginning of an interval, with len to scan */
  while (1)
    {
      if (LENGTH (i) >= len)
	{
	  if (! interval_has_some_properties (properties, i))
	    return modified ? Qt : Qnil;

	  if (LENGTH (i) == len)
	    {
	      remove_properties (properties, i);
	      return Qt;
	    }

	  /* i has the properties, and goes past the change limit */
	  unchanged = split_interval_right (i, len + 1);
	  copy_properties (unchanged, i);
	  remove_properties (properties, i);
	  return Qt;
	}

      len -= LENGTH (i);
      modified += remove_properties (properties, i);
      i = next_interval (i);
    }
}

DEFUN ("erase-text-properties", Ferase_text_properties,
       Serase_text_properties, 3, 3, 0,
  "Remove all text properties from OBJECT (a string or buffer), in the\n\
range START to END. Returns t if any change was made, nil otherwise.")
  (object, start, end)
     Lisp_Object object, start, end;
{
  register INTERVAL i, unchanged;
  register int s, len, modified;

  i = validate_interval_range (object, &start, &end, soft);
  if (NULL_INTERVAL_P (i))
    return Qnil;

  s = XINT (start);
  len = XINT (end) - s;
  if (i->position != s)
    {
      int got = LENGTH (i) - (s - i->position);

      if (got > len)
	{
	  if (NILP (i->plist))
	    return Qnil;

	  unchanged = i;
	  i = split_interval_right (unchanged, s - unchanged->position + 1);
	  i = split_interval_right (i, len + 1);
	  copy_properties (unchanged, i);
	  return Qt;
	}

      if (! NILP (i->plist))
	{
	  i = split_interval_right (i, s - i->position + 1);
	  modified++;
	}

      len -= got;
      i = next_interval (i);
    }

  /* We are starting at the beginning of an interval */
  while (len > 0)
    {
      if (LENGTH (i) > len)
	{
	  if (NILP (i->plist))
	    return modified ? Qt : Qnil;

	  i = split_interval_left (i, len + 1);
	  return Qt;
	}

      len -= LENGTH (i);
      modified += erase_properties (i);
      i = next_interval (i);
    }

  return modified ? Qt : Qnil;
}

void
syms_of_textprop ()
{
  DEFVAR_INT ("interval-balance-threshold", &interval_balance_threshold,
	      "Threshold for rebalancing interval trees, expressed as the
percentage by which the left interval tree should not differ from the right.");
  interval_balance_threshold = 8;

  /* Common attributes one might give text */

  staticpro (&Qforeground);
  Qforeground = intern ("foreground");
  staticpro (&Qbackground);
  Qbackground = intern ("background");
  staticpro (&Qfont);
  Qfont = intern ("font");
  staticpro (&Qstipple);
  Qstipple = intern ("stipple");
  staticpro (&Qunderline);
  Qunderline = intern ("underline");
  staticpro (&Qread_only);
  Qread_only = intern ("read-only");
  staticpro (&Qinvisible);
  Qinvisible = intern ("invisible");

  /* Properties that text might use to specify certain actions */

  staticpro (&Qmouse_left);
  Qmouse_left = intern ("mouse-left");
  staticpro (&Qmouse_entered);
  Qmouse_entered = intern ("mouse-entered");
  staticpro (&Qpoint_left);
  Qpoint_left = intern ("point-left");
  staticpro (&Qpoint_entered);
  Qpoint_entered = intern ("point-entered");
  staticpro (&Qmodification);
  Qmodification = intern ("modification");

  defsubr (&Stext_properties_at);
  defsubr (&Snext_property_change);
  defsubr (&Sprevious_property_change);
  defsubr (&Sadd_text_properties);
  defsubr (&Sset_text_properties);
  defsubr (&Sremove_text_properties);
  defsubr (&Serase_text_properties);
}
