/* Manipulation of keymaps
   Copyright (C) 1985, 1986, 1987, 1988 Free Software Foundation, Inc.

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
#include <stdio.h>
#undef NULL
#include "lisp.h"
#include "commands.h"
#include "buffer.h"

#define min(a, b) ((a) < (b) ? (a) : (b))

/* Dense keymaps look like (keymap VECTOR . ALIST), where VECTOR is a
   128-element vector used to look up bindings for ASCII characters,
   and ALIST is an assoc list for looking up symbols.  */
#define DENSE_TABLE_SIZE (0200)

/* Actually allocate storage for these variables */

Lisp_Object current_global_map;	/* Current global keymap */

Lisp_Object global_map;		/* default global key bindings */

Lisp_Object meta_map;		/* The keymap used for globally bound
				   ESC-prefixed default commands */

Lisp_Object control_x_map;	/* The keymap used for globally bound
				   C-x-prefixed default commands */

/* was MinibufLocalMap */
Lisp_Object Vminibuffer_local_map;
				/* The keymap used by the minibuf for local
				   bindings when spaces are allowed in the
				   minibuf */

/* was MinibufLocalNSMap */
Lisp_Object Vminibuffer_local_ns_map;			
				/* The keymap used by the minibuf for local
				   bindings when spaces are not encouraged
				   in the minibuf */

/* keymap used for minibuffers when doing completion */
/* was MinibufLocalCompletionMap */
Lisp_Object Vminibuffer_local_completion_map;

/* keymap used for minibuffers when doing completion and require a match */
/* was MinibufLocalMustMatchMap */
Lisp_Object Vminibuffer_local_must_match_map;

Lisp_Object Qkeymapp, Qkeymap;

/* A char over 0200 in a key sequence
   is equivalent to prefixing with this character.  */

extern Lisp_Object meta_prefix_char;

void describe_map_tree ();
static Lisp_Object describe_buffer_bindings ();
static void describe_command ();
static void describe_map ();
static void describe_alist ();

DEFUN ("make-keymap", Fmake_keymap, Smake_keymap, 0, 0, 0,
  "Construct and return a new keymap, of the form (keymap VECTOR . ALIST).\n\
VECTOR is a 128-element vector which holds the bindings for the ASCII\n\
characters.  ALIST is an assoc-list which holds bindings for function keys,\n\
mouse events, and any other things that appear in the input stream.\n\
All entries in it are initially nil, meaning \"command undefined\".")
  ()
{
  return Fcons (Qkeymap,
		Fcons (Fmake_vector (make_number (DENSE_TABLE_SIZE), Qnil),
		       Qnil));
}

DEFUN ("make-sparse-keymap", Fmake_sparse_keymap, Smake_sparse_keymap, 0, 0, 0,
  "Construct and return a new sparse-keymap list.\n\
Its car is `keymap' and its cdr is an alist of (CHAR . DEFINITION),\n\
which binds the character CHAR to DEFINITION, or (SYMBOL . DEFINITION),\n\
which binds the function key or mouse event SYMBOL to DEFINITION.\n\
Initially the alist is nil.")
  ()
{
  return Fcons (Qkeymap, Qnil);
}

/* This function is used for installing the standard key bindings
   at initialization time.

   For example:

   initial_define_key (control_x_map, Ctl('X'), "exchange-point-and-mark");

   I haven't extended these to allow the initializing code to bind
   function keys and mouse events; since they are called by many files,
   I'd have to fix lots of callers, and nobody right now would be using
   the new functionality, so it seems like a waste of time.  But there's
   no technical reason not to.  -JimB */

void
initial_define_key (keymap, key, defname)
     Lisp_Object keymap;
     int key;
     char *defname;
{
  store_in_keymap (keymap, make_number (key), intern (defname));
}

/* Define character fromchar in map frommap as an alias for character
   tochar in map tomap.  Subsequent redefinitions of the latter WILL
   affect the former. */

#if 0
void
synkey (frommap, fromchar, tomap, tochar)
     struct Lisp_Vector *frommap, *tomap;
     int fromchar, tochar;
{
  Lisp_Object v, c;
  XSET (v, Lisp_Vector, tomap);
  XFASTINT (c) = tochar;
  frommap->contents[fromchar] = Fcons (v, c);
}
#endif /* 0 */

DEFUN ("keymapp", Fkeymapp, Skeymapp, 1, 1, 0,
  "Return t if ARG is a keymap.\n\
A keymap is list (keymap . ALIST),  where alist elements look like
(CHAR . DEFN) or (SYMBOL . DEFN), or a list (keymap VECTOR . ALIST)
where VECTOR is a 128-element vector of bindings for ASCII characters,
and ALIST is as above.")
  (object)
     Lisp_Object object;
{
  return (NULL (get_keymap_1 (object, 0)) ? Qnil : Qt);
}

/* Check that OBJECT is a keymap (after dereferencing through any
   symbols).  If it is, return it; otherwise, return nil, or signal an
   error if ERROR != 0.  */
Lisp_Object
get_keymap_1 (object, error)
     Lisp_Object object;
     int error;
{
  register Lisp_Object tem;

  tem = object;
  while (XTYPE (tem) == Lisp_Symbol && !EQ (tem, Qunbound))
    {
      tem = XSYMBOL (tem)->function;
      QUIT;
    }
  if (CONSP (tem) && EQ (XCONS (tem)->car, Qkeymap))
    return tem;
  if (error)
    wrong_type_argument (Qkeymapp, object);
  else return Qnil;
}

Lisp_Object
get_keymap (object)
     Lisp_Object object;
{
  return get_keymap_1 (object, 1);
}


/* If KEYMAP is a dense keymap, return the vector from its cadr.
   Otherwise, return nil.  */

static Lisp_Object
keymap_table (keymap)
     Lisp_Object keymap;
{
  Lisp_Object cadr;

  if (CONSP (XCONS (keymap)->cdr)
      && XTYPE (cadr = XCONS (XCONS (keymap)->cdr)->car) == Lisp_Vector
      && XVECTOR (cadr)->size == DENSE_TABLE_SIZE)
    return cadr;
  else
    return Qnil;
}


/* Look up IDX in MAP.  IDX may be any sort of event.
   Note that this does only one level of lookup; IDX must
   be a single event, not a sequence.  */

Lisp_Object
access_keymap (map, idx)
     Lisp_Object map;
     Lisp_Object idx;
{
  /* If idx is a list (some sort of mouse click, perhaps?),
     the index we want to use is the car of the list, which
     ought to be a symbol.  */
  if (XTYPE (idx) == Lisp_Cons)
    idx = XCONS (idx)->car;

  if (XTYPE (idx) == Lisp_Int
      && (XINT (idx) < 0 || XINT (idx) >= DENSE_TABLE_SIZE))
    error ("Command key is not an ASCII character");

  {
    Lisp_Object table = keymap_table (map);

    /* A dense keymap indexed by a character?  */
    if (XTYPE (idx) == Lisp_Int
	&& ! NULL (table))
      return XVECTOR (table)->contents[XFASTINT (idx)];

    /* This lookup will not involve a vector reference.  */
    else
      {
	/* If idx is a symbol, it might have modifiers, which need to
	   be put in the canonical order.  */
	if (XTYPE (idx) == Lisp_Symbol)
	  idx = reorder_modifiers (idx);
	
	return Fcdr (Fassq (idx, map));
      }
  }
}

/* Given OBJECT which was found in a slot in a keymap,
   trace indirect definitions to get the actual definition of that slot.
   An indirect definition is a list of the form
   (KEYMAP . INDEX), where KEYMAP is a keymap or a symbol defined as one
   and INDEX is the object to look up in KEYMAP to yield the definition.

   Also if OBJECT has a menu string as the first element,
   remove that.  */

Lisp_Object
get_keyelt (object)
     register Lisp_Object object;
{
  while (1)
    {
      register Lisp_Object map, tem;

      map = get_keymap_1 (Fcar_safe (object), 0);
      tem = Fkeymapp (map);

      /* If the contents are (KEYMAP . ELEMENT), go indirect.  */
      if (!NULL (tem))
	object = access_keymap (map, Fcdr (object));
      
      /* If the keymap contents looks like (STRING . DEFN),
	 use DEFN.
	 Keymap alist elements like (CHAR MENUSTRING . DEFN)
	 will be used by HierarKey menus.  */
      else if (XTYPE (object) == Lisp_Cons
	       && XTYPE (XCONS (object)->car) == Lisp_String)
	object = XCONS (object)->cdr;

      else
	/* Anything else is really the value.  */
	return object;
    }
}

Lisp_Object
store_in_keymap (keymap, idx, def)
     Lisp_Object keymap;
     register Lisp_Object idx;
     register Lisp_Object def;
{
  /* If idx is a list (some sort of mouse click, perhaps?),
     the index we want to use is the car of the list, which
     ought to be a symbol.  */
  if (XTYPE (idx) == Lisp_Cons)
    idx = Fcar (idx);

  if (XTYPE (idx) == Lisp_Int
      && (XINT (idx) < 0 || XINT (idx) >= DENSE_TABLE_SIZE))
    error ("Command key is a character outside of the ASCII set.");
  
  {
    Lisp_Object table = keymap_table (keymap);

    /* A dense keymap indexed by a character?  */
    if (XTYPE (idx) == Lisp_Int	&& !NULL (table))
      XVECTOR (table)->contents[XFASTINT (idx)] = def;

    /* Must be a sparse keymap, or a dense keymap indexed by a symbol.  */
    else
      {
	/* Point to the pointer to the start of the assoc-list part
	   of the keymap.  */
	register Lisp_Object *assoc_head
	  = (NULL (table)
	     ? & XCONS (keymap)->cdr
	     : & XCONS (XCONS (keymap)->cdr)->cdr);
	register Lisp_Object defining_pair;

	/* If idx is a symbol, it might have modifiers, which need to
	   be put in the canonical order.  */
	if (XTYPE (idx) == Lisp_Symbol)
	  idx = reorder_modifiers (idx);

	/* Point to the pair where idx is bound, if any.  */
	defining_pair = Fassq (idx, *assoc_head);

	if (NULL (defining_pair))
	  *assoc_head = Fcons (Fcons (idx, def), *assoc_head);
	else
	  Fsetcdr (defining_pair, def);
      }
  }

  return def;
}

DEFUN ("copy-keymap", Fcopy_keymap, Scopy_keymap, 1, 1, 0,
  "Return a copy of the keymap KEYMAP.\n\
The copy starts out with the same definitions of KEYMAP,\n\
but changing either the copy or KEYMAP does not affect the other.\n\
Any key definitions that are subkeymaps are recursively copied.")
  (keymap)
     Lisp_Object keymap;
{
  register Lisp_Object copy, tail;

  copy = Fcopy_alist (get_keymap (keymap));
  tail = XCONS (copy)->cdr;

  /* If this is a dense keymap, copy the vector.  */
  if (CONSP (tail))
    {
      register Lisp_Object table = XCONS (tail)->car;

      if (XTYPE (table) == Lisp_Vector
	  && XVECTOR (table)->size == DENSE_TABLE_SIZE)
	{
	  register int i;

	  table = Fcopy_sequence (table);

	  for (i = 0; i < DENSE_TABLE_SIZE; i++)
	    if (! NULL (Fkeymapp (XVECTOR (table)->contents[i])))
	      XVECTOR (table)->contents[i]
		= Fcopy_keymap (XVECTOR (table)->contents[i]);
	  XCONS (tail)->car = table;
      
	  tail = XCONS (tail)->cdr;
	}
    }

  /* Copy the alist portion of the keymap.  */
  while (CONSP (tail))
    {
      register Lisp_Object elt;

      elt = XCONS (tail)->car;
      if (CONSP (elt) && ! NULL (Fkeymapp (XCONS (elt)->cdr)))
	XCONS (elt)->cdr = Fcopy_keymap (XCONS (elt)->cdr);

      tail = XCONS (tail)->cdr;
    }

  return copy;
}

DEFUN ("define-key", Fdefine_key, Sdefine_key, 3, 3, 0,
  "Args KEYMAP, KEY, DEF.  Define key sequence KEY, in KEYMAP, as DEF.\n\
KEYMAP is a keymap.  KEY is a string or a vector of symbols and characters\n\
meaning a sequence of keystrokes and events.\n\
DEF is anything that can be a key's definition:\n\
 nil (means key is undefined in this keymap),\n\
 a command (a Lisp function suitable for interactive calling)\n\
 a string (treated as a keyboard macro),\n\
 a keymap (to define a prefix key),\n\
 a symbol.  When the key is looked up, the symbol will stand for its\n\
    function definition, which should at that time be one of the above,\n\
    or another symbol whose function definition is used, etc.\n\
 a cons (STRING . DEFN), meaning that DEFN is the definition\n\
    (DEFN should be a valid definition in its own right),\n\
 or a cons (KEYMAP . CHAR), meaning use definition of CHAR in map KEYMAP.")
  (keymap, key, def)
     register Lisp_Object keymap;
     Lisp_Object key;
     Lisp_Object def;
{
  register int idx;
  register Lisp_Object c;
  register Lisp_Object tem;
  register Lisp_Object cmd;
  int metized = 0;
  int length;

  keymap = get_keymap (keymap);

  if (XTYPE (key) != Lisp_Vector
      && XTYPE (key) != Lisp_String)
    key = wrong_type_argument (Qarrayp, key);

  length = Flength (key);
  if (length == 0)
    return Qnil;

  idx = 0;
  while (1)
    {
      c = Faref (key, make_number (idx));

      if (XTYPE (c) == Lisp_Int
	  && XINT (c) >= 0200
	  && !metized)
	{
	  c = meta_prefix_char;
	  metized = 1;
	}
      else
	{
	  if (XTYPE (c) == Lisp_Int)
	    XSETINT (c, XINT (c) & 0177);

	  metized = 0;
	  idx++;
	}

      if (idx == length)
	return store_in_keymap (keymap, c, def);

      cmd = get_keyelt (access_keymap (keymap, c));

      if (NULL (cmd))
	{
	  cmd = Fmake_sparse_keymap ();
	  store_in_keymap (keymap, c, cmd);
	}

      tem = Fkeymapp (cmd);
      if (NULL (tem))
	error ("Key sequence %s uses invalid prefix characters",
	       XSTRING (key)->data);

      keymap = get_keymap (cmd);
    }
}

/* Value is number if KEY is too long; NIL if valid but has no definition. */

DEFUN ("lookup-key", Flookup_key, Slookup_key, 2, 2, 0,
  "In keymap KEYMAP, look up key sequence KEY.  Return the definition.\n\
nil means undefined.  See doc of `define-key' for kinds of definitions.\n\
A number as value means KEY is \"too long\";\n\
that is, characters or symbols in it except for the last one\n\
fail to be a valid sequence of prefix characters in KEYMAP.\n\
The number is how many characters at the front of KEY\n\
it takes to reach a non-prefix command.")
  (keymap, key)
     register Lisp_Object keymap;
     Lisp_Object key;
{
  register int idx;
  register Lisp_Object tem;
  register Lisp_Object cmd;
  register Lisp_Object c;
  int metized = 0;
  int length;

  keymap = get_keymap (keymap);

  if (XTYPE (key) != Lisp_Vector
      && XTYPE (key) != Lisp_String)
    key = wrong_type_argument (Qarrayp, key);

  length = Flength (key);
  if (length == 0)
    return keymap;

  idx = 0;
  while (1)
    {
      c = Faref (key, make_number (idx));

      if (XTYPE (c) == Lisp_Int
	  && XINT (c) >= 0200
	  && !metized)
	{
	  c = meta_prefix_char;
	  metized = 1;
	}
      else
	{
	  if (XTYPE (c) == Lisp_Int)
	    XSETINT (c, XINT (c) & 0177);

	  metized = 0;
	  idx++;
	}

      cmd = get_keyelt (access_keymap (keymap, c));
      if (idx == length)
	return cmd;

      tem = Fkeymapp (cmd);
      if (NULL (tem))
	return make_number (idx);

      keymap = get_keymap (cmd);
      QUIT;
    }
}

/* Append a key to the end of a key sequence.  If key_sequence is a
   string and key is a character, the result will be another string;
   otherwise, it will be a vector.  */
Lisp_Object
append_key (key_sequence, key)
     Lisp_Object key_sequence, key;
{
  Lisp_Object args[2];

  args[0] = key_sequence;

  if (XTYPE (key_sequence) == Lisp_String
      && XTYPE (key) == Lisp_Int)
    {
      args[1] = Fchar_to_string (key);
      return Fconcat (2, args);
    }
  else
    {
      args[1] = Fcons (key, Qnil);
      return Fvconcat (2, args);
    }
}


DEFUN ("key-binding", Fkey_binding, Skey_binding, 1, 1, 0,
  "Return the binding for command KEY in current keymaps.\n\
KEY is a string, a sequence of keystrokes.\n\
The binding is probably a symbol with a function definition.")
  (key)
     Lisp_Object key;
{
  register Lisp_Object map, value, value1;
  map = current_buffer->keymap;
  if (!NULL (map))
    {
      value = Flookup_key (map, key);
      if (NULL (value))
	{
	  value1 = Flookup_key (current_global_map, key);
	  if (XTYPE (value1) == Lisp_Int)
	    return Qnil;
	  return value1;
	}
      else if (XTYPE (value) != Lisp_Int)
	return value;
    }
  return Flookup_key (current_global_map, key);
}

DEFUN ("local-key-binding", Flocal_key_binding, Slocal_key_binding, 1, 1, 0,
  "Return the binding for command KEYS in current local keymap only.\n\
KEYS is a string, a sequence of keystrokes.\n\
The binding is probably a symbol with a function definition.")
  (keys)
     Lisp_Object keys;
{
  register Lisp_Object map;
  map = current_buffer->keymap;
  if (NULL (map))
    return Qnil;
  return Flookup_key (map, keys);
}

DEFUN ("global-key-binding", Fglobal_key_binding, Sglobal_key_binding, 1, 1, 0,
  "Return the binding for command KEYS in current global keymap only.\n\
KEYS is a string, a sequence of keystrokes.\n\
The binding is probably a symbol with a function definition.")
  (keys)
     Lisp_Object keys;
{
  return Flookup_key (current_global_map, keys);
}

DEFUN ("global-set-key", Fglobal_set_key, Sglobal_set_key, 2, 2,
  "kSet key globally: \nCSet key %s to command: ",
  "Give KEY a global binding as COMMAND.\n\
COMMAND is a symbol naming an interactively-callable function.\n\
KEY is a string representing a sequence of keystrokes.\n\
Note that if KEY has a local binding in the current buffer\n\
that local binding will continue to shadow any global binding.")
  (keys, function)
     Lisp_Object keys, function;
{
  if (XTYPE (keys) != Lisp_Vector
      && XTYPE (keys) != Lisp_String)
    keys = wrong_type_argument (Qarrayp, keys);

  Fdefine_key (current_global_map, keys, function);
  return Qnil;
}

DEFUN ("local-set-key", Flocal_set_key, Slocal_set_key, 2, 2,
  "kSet key locally: \nCSet key %s locally to command: ",
  "Give KEY a local binding as COMMAND.\n\
COMMAND is a symbol naming an interactively-callable function.\n\
KEY is a string representing a sequence of keystrokes.\n\
The binding goes in the current buffer's local map,\n\
which is shared with other buffers in the same major mode.")
  (keys, function)
     Lisp_Object keys, function;
{
  register Lisp_Object map;
  map = current_buffer->keymap;
  if (NULL (map))
    {
      map = Fmake_sparse_keymap ();
      current_buffer->keymap = map;
    }

  if (XTYPE (keys) != Lisp_Vector
      && XTYPE (keys) != Lisp_String)
    keys = wrong_type_argument (Qarrayp, keys);

  Fdefine_key (map, keys, function);
  return Qnil;
}

DEFUN ("global-unset-key", Fglobal_unset_key, Sglobal_unset_key,
  1, 1, "kUnset key globally: ",
  "Remove global binding of KEY.\n\
KEY is a string representing a sequence of keystrokes.")
  (keys)
     Lisp_Object keys;
{
  return Fglobal_set_key (keys, Qnil);
}

DEFUN ("local-unset-key", Flocal_unset_key, Slocal_unset_key, 1, 1,
  "kUnset key locally: ",
  "Remove local binding of KEY.\n\
KEY is a string representing a sequence of keystrokes.")
  (keys)
     Lisp_Object keys;
{
  if (!NULL (current_buffer->keymap))
    Flocal_set_key (keys, Qnil);
  return Qnil;
}

DEFUN ("define-prefix-command", Fdefine_prefix_command, Sdefine_prefix_command, 1, 2, 0,
  "Define COMMAND as a prefix command.\n\
A new sparse keymap is stored as COMMAND's function definition and its value.\n\
If a second optional argument MAPVAR is given, the map is stored as its\n\
value instead of as COMMAND's value; but COMMAND is still defined as a function.")
  (name, mapvar)
     Lisp_Object name, mapvar;
{
  Lisp_Object map;
  map = Fmake_sparse_keymap ();
  Ffset (name, map);
  if (!NULL (mapvar))
    Fset (mapvar, map);
  else
    Fset (name, map);
  return name;
}

DEFUN ("use-global-map", Fuse_global_map, Suse_global_map, 1, 1, 0,
  "Select KEYMAP as the global keymap.")
  (keymap)
     Lisp_Object keymap;
{
  keymap = get_keymap (keymap);
  current_global_map = keymap;
  return Qnil;
}

DEFUN ("use-local-map", Fuse_local_map, Suse_local_map, 1, 1, 0,
  "Select KEYMAP as the local keymap.\n\
If KEYMAP is nil, that means no local keymap.")
  (keymap)
     Lisp_Object keymap;
{
  if (!NULL (keymap))
    keymap = get_keymap (keymap);

  current_buffer->keymap = keymap;

  return Qnil;
}

DEFUN ("current-local-map", Fcurrent_local_map, Scurrent_local_map, 0, 0, 0,
  "Return current buffer's local keymap, or nil if it has none.")
  ()
{
  return current_buffer->keymap;
}

DEFUN ("current-global-map", Fcurrent_global_map, Scurrent_global_map, 0, 0, 0,
  "Return the current global keymap.")
  ()
{
  return current_global_map;
}

DEFUN ("accessible-keymaps", Faccessible_keymaps, Saccessible_keymaps,
  1, 1, 0,
  "Find all keymaps accessible via prefix characters from KEYMAP.\n\
Returns a list of elements of the form (KEYS . MAP), where the sequence\n\
KEYS starting from KEYMAP gets you to MAP.  These elements are ordered\n\
so that the KEYS increase in length.  The first element is (\"\" . KEYMAP).")
  (startmap)
     Lisp_Object startmap;
{
  Lisp_Object maps, tail;

  maps = Fcons (Fcons (build_string (""), get_keymap (startmap)), Qnil);
  tail = maps;

  /* For each map in the list maps,
     look at any other maps it points to,
     and stick them at the end if they are not already in the list.

     This is a breadth-first traversal, where tail is the queue of
     nodes, and maps accumulates a list of all nodes visited.  */

  while (!NULL (tail))
    {
      register Lisp_Object thisseq = Fcar (Fcar (tail));
      register Lisp_Object thismap = Fcdr (Fcar (tail));
      Lisp_Object last = make_number (XINT (Flength (thisseq)) - 1);

      /* Does the current sequence end in the meta-prefix-char?  */
      int is_metized = (XINT (last) >= 0
			&& EQ (Faref (thisseq, last), meta_prefix_char));

      /* Skip the 'keymap element of the list.  */
      thismap = Fcdr (thismap);

      if (CONSP (thismap))
	{
	  register Lisp_Object table = XCONS (thismap)->car;

	  if (XTYPE (table) == Lisp_Vector)
	    {
	      register int i;

	      /* Vector keymap.  Scan all the elements.  */
	      for (i = 0; i < DENSE_TABLE_SIZE; i++)
		{
		  register Lisp_Object tem;
		  register Lisp_Object cmd;

		  cmd = get_keyelt (XVECTOR (table)->contents[i]);
		  if (NULL (cmd)) continue;
		  tem = Fkeymapp (cmd);
		  if (!NULL (tem))
		    {
		      cmd = get_keymap (cmd);
		      /* Ignore keymaps that are already added to maps.  */
		      tem = Frassq (cmd, maps);
		      if (NULL (tem))
			{
			  /* If the last key in thisseq is meta-prefix-char,
			     turn it into a meta-ized keystroke.  We know
			     that the event we're about to append is an
			     ascii keystroke.  */
			  if (is_metized)
			    {
			      tem = Fcopy_sequence (thisseq);
			      Faset (tem, last, make_number (i | 0200));
			      
			      /* This new sequence is the same length as
				 thisseq, so stick it in the list right
				 after this one.  */
			      XCONS (tail)->cdr =
				Fcons (Fcons (tem, cmd), XCONS (tail)->cdr);
			    }
			  else
			    {
			      tem = append_key (thisseq, make_number (i));
			      nconc2 (tail, Fcons (Fcons (tem, cmd), Qnil));
			    }
			}
		    }
		}

	      /* Once finished with the lookup elements of the dense
		 keymap, go on to scan its assoc list.  */
	      thismap = XCONS (thismap)->cdr;
	    }
	}

      /* The rest is an alist.  Scan all the alist elements.  */
      while (CONSP (thismap))
	{
	  Lisp_Object elt = XCONS (thismap)->car;

	  /* Ignore elements that are not conses.  */
	  if (CONSP (elt))
	    {
	      register Lisp_Object cmd = get_keyelt (XCONS (elt)->cdr);
	      register Lisp_Object tem;

	      /* Ignore definitions that aren't keymaps themselves.  */
	      tem = Fkeymapp (cmd);
	      if (!NULL (tem))
		{
		  /* Ignore keymaps that have been seen already.  */
		  cmd = get_keymap (cmd);
		  tem = Frassq (cmd, maps);
		  if (NULL (tem))
		    {
		      /* let elt be the event defined by this map entry.  */
		      elt = XCONS (elt)->car;

		      /* If the last key in thisseq is meta-prefix-char, and
			 this entry is a binding for an ascii keystroke,
			 turn it into a meta-ized keystroke.  */
		      if (is_metized && XTYPE (elt) == Lisp_Int)
			{
			  tem = Fcopy_sequence (thisseq);
			  Faset (tem, last, make_number (XINT (elt) | 0200));

			  /* This new sequence is the same length as
			     thisseq, so stick it in the list right
			     after this one.  */
			  XCONS (tail)->cdr =
			    Fcons (Fcons (tem, cmd), XCONS (tail)->cdr);
			}
		      else
			nconc2 (tail,
				Fcons (Fcons (append_key (thisseq, elt), cmd),
				       Qnil));
		    }
		}
	    }
	  
	  thismap = XCONS (thismap)->cdr;
	}

      tail = Fcdr (tail);
    }

  return maps;
}

Lisp_Object Qsingle_key_description, Qkey_description;

DEFUN ("key-description", Fkey_description, Skey_description, 1, 1, 0,
  "Return a pretty description of key-sequence KEYS.\n\
Control characters turn into \"C-foo\" sequences, meta into \"M-foo\"\n\
spaces are put between sequence elements, etc.")
  (keys)
     Lisp_Object keys;
{
  return Fmapconcat (Qsingle_key_description, keys, build_string (" "));
}

char *
push_key_description (c, p)
     register unsigned int c;
     register char *p;
{
  if (c >= 0200)
    {
      *p++ = 'M';
      *p++ = '-';
      c -= 0200;
    }
  if (c < 040)
    {
      if (c == 033)
	{
	  *p++ = 'E';
	  *p++ = 'S';
	  *p++ = 'C';
	}
      else if (c == Ctl('I'))
	{
	  *p++ = 'T';
	  *p++ = 'A';
	  *p++ = 'B';
	}
      else if (c == Ctl('J'))
	{
	  *p++ = 'L';
	  *p++ = 'F';
	  *p++ = 'D';
	}
      else if (c == Ctl('M'))
	{
	  *p++ = 'R';
	  *p++ = 'E';
	  *p++ = 'T';
	}
      else
	{
	  *p++ = 'C';
	  *p++ = '-';
	  if (c > 0 && c <= Ctl ('Z'))
	    *p++ = c + 0140;
	  else
	    *p++ = c + 0100;
	}
    }
  else if (c == 0177)
    {
      *p++ = 'D';
      *p++ = 'E';
      *p++ = 'L';
    }
  else if (c == ' ')
    {
      *p++ = 'S';
      *p++ = 'P';
      *p++ = 'C';
    }
  else
    *p++ = c;

  return p;  
}

DEFUN ("single-key-description", Fsingle_key_description, Ssingle_key_description, 1, 1, 0,
  "Return a pretty description of command character KEY.\n\
Control characters turn into C-whatever, etc.")
  (key)
     Lisp_Object key;
{
  register unsigned char c;
  char tem[6];

  switch (XTYPE (key))
    {
    case Lisp_Int:		/* Normal character */
      c = XINT (key) & 0377;
      *push_key_description (c, tem) = 0;
      return build_string (tem);

    case Lisp_Symbol:		/* Function key or event-symbol */
      return Fsymbol_name (key);

    case Lisp_Cons:		/* Mouse event */
      key = XCONS (key)->cdr;
      if (XTYPE (key) == Lisp_Symbol)
	return Fsymbol_name (key);
      /* Mouse events should have an identifying symbol as their car;
	 fall through when this isn't the case.  */
      
    default:
      error ("KEY must be an integer, cons, or symbol.");
    }
}

char *
push_text_char_description (c, p)
     register unsigned int c;
     register char *p;
{
  if (c >= 0200)
    {
      *p++ = 'M';
      *p++ = '-';
      c -= 0200;
    }
  if (c < 040)
    {
      *p++ = '^';
      *p++ = c + 64;		/* 'A' - 1 */
    }
  else if (c == 0177)
    {
      *p++ = '^';
      *p++ = '?';
    }
  else
    *p++ = c;
  return p;  
}

DEFUN ("text-char-description", Ftext_char_description, Stext_char_description, 1, 1, 0,
  "Return a pretty description of file-character CHAR.\n\
Control characters turn into \"^char\", etc.")
  (chr)
     Lisp_Object chr;
{
  char tem[6];

  CHECK_NUMBER (chr, 0);

  *push_text_char_description (XINT (chr) & 0377, tem) = 0;

  return build_string (tem);
}

DEFUN ("where-is-internal", Fwhere_is_internal, Swhere_is_internal, 1, 5, 0,
  "Return list of keys that invoke DEFINITION in KEYMAP or KEYMAP1.\n\
If KEYMAP is nil, search only KEYMAP1.\n\
If KEYMAP1 is nil, use the current global map.\n\
\n\
If optional 4th arg FIRSTONLY is non-nil,\n\
return a string representing the first key sequence found,\n\
rather than a list of all possible key sequences.\n\
\n\
If optional 5th arg NOINDIRECT is non-nil, don't follow indirections\n\
to other keymaps or slots.  This makes it possible to search for an\n\
indirect definition itself.")
  (definition, local_keymap, global_keymap, firstonly, noindirect)
     Lisp_Object definition, local_keymap, global_keymap;
     Lisp_Object firstonly, noindirect;
{
  register Lisp_Object maps;
  Lisp_Object found;

  if (NULL (global_keymap))
    global_keymap = current_global_map;

  if (!NULL (local_keymap))
    maps = nconc2 (Faccessible_keymaps (get_keymap (local_keymap)),
		   Faccessible_keymaps (get_keymap (global_keymap)));
  else
    maps = Faccessible_keymaps (get_keymap (global_keymap));

  found = Qnil;

  for (; !NULL (maps); maps = Fcdr (maps))
    {
      register this = Fcar (Fcar (maps)); /* Key sequence to reach map */
      register map = Fcdr (Fcar (maps)); /* The map that it reaches */
      register dense_alist;
      register int i = 0;

      /* In order to fold [META-PREFIX-CHAR CHAR] sequences into
	 [M-CHAR] sequences, check if last character of the sequence
	 is the meta-prefix char.  */
      Lisp_Object last = make_number (XINT (Flength (this)) - 1);
      int last_is_meta = (XINT (last) >= 0
			  && EQ (Faref (this, last), meta_prefix_char));
	 
      /* Skip the 'keymap element of the list.  */
      map = Fcdr (map);

      /* If the keymap is sparse, map traverses the alist to the end.

	 If the keymap is dense, we set map to the vector and
	 dense_alist to the assoc-list portion of the keymap.  When we
	 are finished dealing with the vector portion, we set map to
	 dense_alist, and handle the rest like a sparse keymap.  */
      if (XTYPE (XCONS (map)->car) == Lisp_Vector)
	{
	  dense_alist = XCONS (map)->cdr;
	  map = XCONS (map)->car;
	}

      while (1)
	{
	  register Lisp_Object key, binding, sequence;
	  
	  QUIT;
	  if (XTYPE (map) == Lisp_Vector)
	    {
	      /* In a vector, look at each element.  */
	      binding = XVECTOR (map)->contents[i];
	      XFASTINT (key) = i;
	      i++;

	      /* If we've just finished scanning a vector, switch map to
		 the assoc-list at the end of the vector.  */
	      if (i >= DENSE_TABLE_SIZE)
		map = dense_alist;
	    }
	  else if (CONSP (map))
	    {
	      /* In an alist, ignore elements that aren't conses.  */
	      if (! CONSP (XCONS (map)->car))
		{
		  /* Ignore other elements.  */
		  map = Fcdr (map);
		  continue;
		}
	      binding = Fcdr (Fcar (map));
	      key = Fcar (Fcar (map));
	      map = Fcdr (map);
	    }
	  else
	    break;

	  /* Search through indirections unless that's not wanted.  */
	  if (NULL (noindirect))
	    binding = get_keyelt (binding);

	  /* End this iteration if this element does not match
	     the target.  */

	  if (XTYPE (definition) == Lisp_Cons)
	    {
	      Lisp_Object tem;
	      tem = Fequal (binding, definition);
	      if (NULL (tem))
		continue;
	    }
	  else
	    if (!EQ (binding, definition))
	      continue;

	  /* We have found a match.
	     Construct the key sequence where we found it.  */
	  if (XTYPE (key) == Lisp_Int && last_is_meta)
	    {
	      sequence = Fcopy_sequence (this);
	      Faset (sequence, last, make_number (XINT (key) | 0200));
	    }
	  else
	    sequence = append_key (this, key);

	  /* Verify that this key binding is not shadowed by another
	     binding for the same key, before we say it exists.

	     Mechanism: look for local definition of this key and if
	     it is defined and does not match what we found then
	     ignore this key.

	     Either nil or number as value from Flookup_key
	     means undefined.  */
	  if (!NULL (local_keymap))
	    {
	      binding = Flookup_key (local_keymap, sequence);
	      if (!NULL (binding) && XTYPE (binding) != Lisp_Int)
		{
		  if (XTYPE (definition) == Lisp_Cons)
		    {
		      Lisp_Object tem;
		      tem = Fequal (binding, definition);
		      if (NULL (tem))
			continue;
		    }
		  else
		    if (!EQ (binding, definition))
		      continue;
		}
	    }

	  /* It is a true unshadowed match.  Record it.  */

	  if (!NULL (firstonly))
	    return sequence;
	  found = Fcons (sequence, found);
	}
    }
  return Fnreverse (found);
}

/* Return a string listing the keys and buttons that run DEFINITION.  */

static Lisp_Object
where_is_string (definition)
     Lisp_Object definition;
{
  register Lisp_Object keys, keys1;

  keys = Fwhere_is_internal (definition,
			     current_buffer->keymap, Qnil, Qnil, Qnil);
  keys1 = Fmapconcat (Qkey_description, keys, build_string (", "));

  return keys1;
}

DEFUN ("where-is", Fwhere_is, Swhere_is, 1, 1, "CWhere is command: ",
  "Print message listing key sequences that invoke specified command.\n\
Argument is a command definition, usually a symbol with a function definition.")
  (definition)
     Lisp_Object definition;
{
  register Lisp_Object string;

  CHECK_SYMBOL (definition, 0);
  string = where_is_string (definition);
 
  if (XSTRING (string)->size)
    message ("%s is on %s", XSYMBOL (definition)->name->data,
	     XSTRING (string)->data);
  else
    message ("%s is not on any key", XSYMBOL (definition)->name->data);
  return Qnil;
}

DEFUN ("describe-bindings", Fdescribe_bindings, Sdescribe_bindings, 0, 0, "",
  "Show a list of all defined keys, and their definitions.\n\
The list is put in a buffer, which is displayed.")
  ()
{
  register Lisp_Object thisbuf;
  XSET (thisbuf, Lisp_Buffer, current_buffer);
  internal_with_output_to_temp_buffer ("*Help*",
				       describe_buffer_bindings,
				       thisbuf);
  return Qnil;
}

static Lisp_Object
describe_buffer_bindings (descbuf)
     Lisp_Object descbuf;
{
  register Lisp_Object start1, start2;

  char *heading
    = "key                     binding\n---                     -------\n";

  Fset_buffer (Vstandard_output);

  start1 = XBUFFER (descbuf)->keymap;
  if (!NULL (start1))
    {
      insert_string ("Local Bindings:\n");
      insert_string (heading);
      describe_map_tree (start1, 0, Qnil, Qnil);
      insert_string ("\n");
    }

  insert_string ("Global Bindings:\n");
  insert_string (heading);

  describe_map_tree (current_global_map, 0, XBUFFER (descbuf)->keymap, Qnil);

  Fset_buffer (descbuf);
  return Qnil;
}

/* Insert a desription of the key bindings in STARTMAP,
    followed by those of all maps reachable through STARTMAP.
   If PARTIAL is nonzero, omit certain "uninteresting" commands
    (such as `undefined').
   If SHADOW is non-nil, it is another map;
    don't mention keys which would be shadowed by it.  */

void
describe_map_tree (startmap, partial, shadow)
     Lisp_Object startmap, shadow;
     int partial;
{
  register Lisp_Object elt, sh;
  Lisp_Object maps;
  struct gcpro gcpro1;

  maps = Faccessible_keymaps (startmap);
  GCPRO1 (maps);

  for (; !NULL (maps); maps = Fcdr (maps))
    {
      elt = Fcar (maps);
      sh = Fcar (elt);

      /* If there is no shadow keymap given, don't shadow.  */
      if (NULL (shadow))
	sh = Qnil;

      /* If the sequence by which we reach this keymap is zero-length,
	 then the shadow map for this keymap is just SHADOW.  */
      else if ((XTYPE (sh) == Lisp_String
		&& XSTRING (sh)->size == 0)
	       || (XTYPE (sh) == Lisp_Vector
		   && XVECTOR (sh)->size == 0))
	sh = shadow;

      /* If the sequence by which we reach this keymap actually has
	 some elements, then the sequence's definition in SHADOW is
	 what we should use.  */
      else
	{
	  sh = Flookup_key (shadow, Fcar (elt));
	  if (XTYPE (sh) == Lisp_Int)
	    sh = Qnil;
	}

      /* If sh is null (meaning that the current map is not shadowed),
	 or a keymap (meaning that bindings from the current map might
	 show through), describe the map.  Otherwise, sh is a command
	 that completely shadows the current map, and we shouldn't
	 bother.  */
      if (NULL (sh) || !NULL (Fkeymapp (sh)))
	describe_map (Fcdr (elt), Fcar (elt), partial, sh);
    }

  UNGCPRO;
}

static void
describe_command (definition)
     Lisp_Object definition;
{
  register Lisp_Object tem1;

  Findent_to (make_number (16), make_number (1));

  if (XTYPE (definition) == Lisp_Symbol)
    {
      XSET (tem1, Lisp_String, XSYMBOL (definition)->name);
      insert1 (tem1);
      insert_string ("\n");
    }
  else
    {
      tem1 = Fkeymapp (definition);
      if (!NULL (tem1))
	insert_string ("Prefix Command\n");
      else
	insert_string ("??\n");
    }
}

/* Describe the contents of map MAP, assuming that this map itself is
   reached by the sequence of prefix keys KEYS (a string or vector).
   PARTIAL, SHADOW is as in `describe_map_tree' above.  */

static void
describe_map (map, keys, partial, shadow)
     Lisp_Object map, keys;
     int partial;
     Lisp_Object shadow;
{
  register Lisp_Object keysdesc;

  if (!NULL (keys) && Flength (keys) > 0)
    keysdesc = concat2 (Fkey_description (keys),
			build_string (" "));
  else
    keysdesc = Qnil;

  /* Skip the 'keymap element of the list.  */
  map = Fcdr (map);

  /* If this is a dense keymap, take care of the table.  */
  if (CONSP (map)
      && XTYPE (XCONS (map)->car) == Lisp_Vector)
    {
      describe_vector (XCONS (map)->car, keysdesc, describe_command,
		       partial, shadow);
      map = XCONS (map)->cdr;
    }

  /* Now map is an alist.  */
  describe_alist (map, keysdesc, describe_command, partial, shadow);
}

/* Insert a description of ALIST into the current buffer. 
   Note that ALIST is just a plain association list, not a keymap.  */

static void
describe_alist (alist, elt_prefix, elt_describer, partial, shadow)
     register Lisp_Object alist;
     Lisp_Object elt_prefix;
     int (*elt_describer) ();
     int partial;
     Lisp_Object shadow;
{
  Lisp_Object this;
  Lisp_Object tem1, tem2 = Qnil;
  Lisp_Object suppress;
  Lisp_Object kludge;
  int first = 1;
  struct gcpro gcpro1, gcpro2, gcpro3;

  if (partial)
    suppress = intern ("suppress-keymap");

  /* This vector gets used to present single keys to Flookup_key.  Since
     that is done once per alist element, we don't want to cons up a
     fresh vector every time.  */
  kludge = Fmake_vector (make_number (1), Qnil);

  GCPRO3 (elt_prefix, tem2, kludge);

  for (; CONSP (alist); alist = Fcdr (alist))
    {
      QUIT;
      tem1 = Fcar_safe (Fcar (alist));
      tem2 = get_keyelt (Fcdr_safe (Fcar (alist)));

      /* Don't show undefined commands or suppressed commands.  */
      if (NULL (tem2)) continue;
      if (XTYPE (tem2) == Lisp_Symbol && partial)
	{
	  this = Fget (tem2, suppress);
	  if (!NULL (this))
	    continue;
	}

      /* Don't show a command that isn't really visible
	 because a local definition of the same key shadows it.  */

      if (!NULL (shadow))
	{
	  Lisp_Object tem;

	  XVECTOR (kludge)->contents[0] = tem1;
	  tem = Flookup_key (shadow, kludge);
	  if (!NULL (tem)) continue;
	}

      if (first)
	{
	  insert ("\n", 1);
	  first = 0;
	}

      if (!NULL (elt_prefix))
	insert1 (elt_prefix);

      /* THIS gets the string to describe the character TEM1.  */
      this = Fsingle_key_description (tem1);
      insert1 (this);

      /* Print a description of the definition of this character.
	 elt_describer will take care of spacing out far enough
	 for alignment purposes.  */
      (*elt_describer) (tem2);
    }

  UNGCPRO;
}

static int
describe_vector_princ (elt)
     Lisp_Object elt;
{
  Fprinc (elt, Qnil);
}

DEFUN ("describe-vector", Fdescribe_vector, Sdescribe_vector, 1, 1, 0,
  "Print on `standard-output' a description of contents of VECTOR.\n\
This is text showing the elements of vector matched against indices.")
  (vector)
     Lisp_Object vector;
{
  CHECK_VECTOR (vector, 0);
  describe_vector (vector, Qnil, describe_vector_princ, 0, Qnil, Qnil);
}

describe_vector (vector, elt_prefix, elt_describer, partial, shadow)
     register Lisp_Object vector;
     Lisp_Object elt_prefix;
     int (*elt_describer) ();
     int partial;
     Lisp_Object shadow;
{
  Lisp_Object this;
  Lisp_Object dummy;
  Lisp_Object tem1, tem2;
  register int i;
  Lisp_Object suppress;
  Lisp_Object kludge;
  int first = 1;
  struct gcpro gcpro1, gcpro2, gcpro3;

  tem1 = Qnil;

  /* This vector gets used to present single keys to Flookup_key.  Since
     that is done once per vector element, we don't want to cons up a
     fresh vector every time.  */
  kludge = Fmake_vector (make_number (1), Qnil);
  GCPRO3 (elt_prefix, tem1, kludge);

  if (partial)
    suppress = intern ("suppress-keymap");

  for (i = 0; i < DENSE_TABLE_SIZE; i++)
    {
      QUIT;
      tem1 = get_keyelt (XVECTOR (vector)->contents[i]);

      if (NULL (tem1)) continue;      

      /* Don't mention suppressed commands.  */
      if (XTYPE (tem1) == Lisp_Symbol && partial)
	{
	  this = Fget (tem1, suppress);
	  if (!NULL (this))
	    continue;
	}

      /* If this command in this map is shadowed by some other map,
	 ignore it.  */
      if (!NULL (shadow))
	{
	  Lisp_Object tem;
	  
	  XVECTOR (kludge)->contents[0] = make_number (i);
	  tem = Flookup_key (shadow, kludge);

	  if (!NULL (tem)) continue;
	}

      if (first)
	{
	  insert ("\n", 1);
	  first = 0;
	}

      /* Output the prefix that applies to every entry in this map.  */
      if (!NULL (elt_prefix))
	insert1 (elt_prefix);

      /* Get the string to describe the character I, and print it.  */
      XFASTINT (dummy) = i;

      /* THIS gets the string to describe the character DUMMY.  */
      this = Fsingle_key_description (dummy);
      insert1 (this);

      /* Find all consecutive characters that have the same definition.  */
      while (i + 1 < DENSE_TABLE_SIZE
	     && (tem2 = get_keyelt (XVECTOR (vector)->contents[i+1]),
		 EQ (tem2, tem1)))
	i++;

      /* If we have a range of more than one character,
	 print where the range reaches to.  */

      if (i != XINT (dummy))
	{
	  insert (" .. ", 4);
	  if (!NULL (elt_prefix))
	    insert1 (elt_prefix);

	  XFASTINT (dummy) = i;
	  insert1 (Fsingle_key_description (dummy));
	}

      /* Print a description of the definition of this character.
	 elt_describer will take care of spacing out far enough
	 for alignment purposes.  */
      (*elt_describer) (tem1);
    }

  UNGCPRO;
}

/* Apropos */
Lisp_Object apropos_predicate;
Lisp_Object apropos_accumulate;

static void
apropos_accum (symbol, string)
     Lisp_Object symbol, string;
{
  register Lisp_Object tem;

  tem = Fstring_match (string, Fsymbol_name (symbol), Qnil);
  if (!NULL (tem) && !NULL (apropos_predicate))
    tem = call1 (apropos_predicate, symbol);
  if (!NULL (tem))
    apropos_accumulate = Fcons (symbol, apropos_accumulate);
}

DEFUN ("apropos-internal", Fapropos_internal, Sapropos_internal, 1, 2, 0, 
  "Show all symbols whose names contain match for REGEXP.\n\
If optional 2nd arg PRED is non-nil, (funcall PRED SYM) is done\n\
for each symbol and a symbol is mentioned only if that returns non-nil.\n\
Return list of symbols found.")
  (string, pred)
     Lisp_Object string, pred;
{
  struct gcpro gcpro1, gcpro2;
  CHECK_STRING (string, 0);
  apropos_predicate = pred;
  GCPRO2 (apropos_predicate, apropos_accumulate);
  apropos_accumulate = Qnil;
  map_obarray (Vobarray, apropos_accum, string);
  apropos_accumulate = Fsort (apropos_accumulate, Qstring_lessp);
  UNGCPRO;
  return apropos_accumulate;
}

syms_of_keymap ()
{
  Lisp_Object tem;

  Qkeymap = intern ("keymap");
  staticpro (&Qkeymap);

/* Initialize the keymaps standardly used.
   Each one is the value of a Lisp variable, and is also
   pointed to by a C variable */

  global_map = Fmake_keymap ();
  Fset (intern ("global-map"), global_map);

  meta_map = Fmake_keymap ();
  Fset (intern ("esc-map"), meta_map);
  Ffset (intern ("ESC-prefix"), meta_map);

  control_x_map = Fmake_keymap ();
  Fset (intern ("ctl-x-map"), control_x_map);
  Ffset (intern ("Control-X-prefix"), control_x_map);

  DEFVAR_LISP ("minibuffer-local-map", &Vminibuffer_local_map,
    "Default keymap to use when reading from the minibuffer.");
  Vminibuffer_local_map = Fmake_sparse_keymap ();

  DEFVAR_LISP ("minibuffer-local-ns-map", &Vminibuffer_local_ns_map,
    "Local keymap for the minibuffer when spaces are not allowed.");
  Vminibuffer_local_ns_map = Fmake_sparse_keymap ();

  DEFVAR_LISP ("minibuffer-local-completion-map", &Vminibuffer_local_completion_map,
    "Local keymap for minibuffer input with completion.");
  Vminibuffer_local_completion_map = Fmake_sparse_keymap ();

  DEFVAR_LISP ("minibuffer-local-must-match-map", &Vminibuffer_local_must_match_map,
    "Local keymap for minibuffer input with completion, for exact match.");
  Vminibuffer_local_must_match_map = Fmake_sparse_keymap ();

  current_global_map = global_map;

  Qsingle_key_description = intern ("single-key-description");
  staticpro (&Qsingle_key_description);

  Qkey_description = intern ("key-description");
  staticpro (&Qkey_description);

  Qkeymapp = intern ("keymapp");
  staticpro (&Qkeymapp);

  defsubr (&Skeymapp);
  defsubr (&Smake_keymap);
  defsubr (&Smake_sparse_keymap);
  defsubr (&Scopy_keymap);
  defsubr (&Skey_binding);
  defsubr (&Slocal_key_binding);
  defsubr (&Sglobal_key_binding);
  defsubr (&Sglobal_set_key);
  defsubr (&Slocal_set_key);
  defsubr (&Sdefine_key);
  defsubr (&Slookup_key);
  defsubr (&Sglobal_unset_key);
  defsubr (&Slocal_unset_key);
  defsubr (&Sdefine_prefix_command);
  defsubr (&Suse_global_map);
  defsubr (&Suse_local_map);
  defsubr (&Scurrent_local_map);
  defsubr (&Scurrent_global_map);
  defsubr (&Saccessible_keymaps);
  defsubr (&Skey_description);
  defsubr (&Sdescribe_vector);
  defsubr (&Ssingle_key_description);
  defsubr (&Stext_char_description);
  defsubr (&Swhere_is_internal);
  defsubr (&Swhere_is);
  defsubr (&Sdescribe_bindings);
  defsubr (&Sapropos_internal);
}

keys_of_keymap ()
{
  Lisp_Object tem;

  initial_define_key (global_map, 033, "ESC-prefix");
  initial_define_key (global_map, Ctl('X'), "Control-X-prefix");
}
