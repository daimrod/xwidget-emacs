;; Non-primitive commands for keyboard macros.
;; Copyright (C) 1985, 1986, 1987 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 1, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.


;;;###autoload
(defun name-last-kbd-macro (symbol)
  "Assign a name to the last keyboard macro defined.
Argument SYMBOL is the name to define.
The symbol's function definition becomes the keyboard macro string.
Such a \"function\" cannot be called from Lisp, but it is a valid editor command."
  (interactive "SName for last kbd macro: ")
  (or last-kbd-macro
      (error "No keyboard macro defined"))
  (and (fboundp symbol)
       (not (stringp (symbol-function symbol)))
       (error "Function %s is already defined and not a keyboard macro."
	      symbol))
  (fset symbol last-kbd-macro))

;;;###autoload
(defun insert-kbd-macro (macroname &optional keys)
  "Insert in buffer the definition of kbd macro NAME, as Lisp code.
Optional second arg KEYS means also record the keys it is on
(this is the prefix argument, when calling interactively).

This Lisp code will, when executed, define the kbd macro with the same
definition it has now.  If you say to record the keys, the Lisp code
will also rebind those keys to the macro.  Only global key bindings
are recorded since executing this Lisp code always makes global
bindings.

To save a kbd macro, visit a file of Lisp code such as your ~/.emacs,
use this command, and then save the file."
  (interactive "CInsert kbd macro (name): \nP")
  (insert "(fset '")
  (prin1 macroname (current-buffer))
  (insert "\n   ")
  (prin1 (symbol-function macroname) (current-buffer))
  (insert ")\n")
  (if keys
      (let ((keys (where-is-internal macroname nil)))
	(while keys
	  (insert "(global-set-key ")
	  (prin1 (car keys) (current-buffer))
	  (insert " '")
	  (prin1 macroname (current-buffer))
	  (insert ")\n")
	  (setq keys (cdr keys))))))

;;;###autoload
(defun kbd-macro-query (flag)
  "Query user during kbd macro execution.
  With prefix argument, enters recursive edit, reading keyboard
commands even within a kbd macro.  You can give different commands
each time the macro executes.
  Without prefix argument, reads a character.  Your options are:
Space -- execute the rest of the macro.
DEL -- skip the rest of the macro; start next repetition.
C-d -- skip rest of the macro and don't repeat it any more.
C-r -- enter a recursive edit, then on exit ask again for a character
C-l -- redisplay screen and ask again."
  (interactive "P")
  (or executing-macro
      defining-kbd-macro
      (error "Not defining or executing kbd macro"))
  (if flag
      (let (executing-macro defining-kbd-macro)
	(recursive-edit))
    (if (not executing-macro)
	nil
      (let ((loop t))
	(while loop
	  (let ((char (let ((executing-macro nil)
			    (defining-kbd-macro nil))
			(message "Proceed with macro? (Space, DEL, C-d, C-r or C-l) ")
			(read-char))))
	    (cond ((= char ? )
		   (setq loop nil))
		  ((= char ?\177)
		   (setq loop nil)
		   (setq executing-macro ""))
		  ((= char ?\C-d)
		   (setq loop nil)
		   (setq executing-macro t))
		  ((= char ?\C-l)
		   (recenter nil))
		  ((= char ?\C-r)
		   (let (executing-macro defining-kbd-macro)
		     (recursive-edit))))))))))

;;;###autoload
(defun apply-macro-to-region-lines (top bottom &optional macro)
  "For each complete line in the current region, move to the beginning of
the line, and run the last keyboard macro.

When called from lisp, this function takes two arguments TOP and
BOTTOM, describing the current region.  TOP must be before BOTTOM.
The optional third argument MACRO specifies a keyboard macro to
execute.

This is useful for quoting or unquoting included text, adding and
removing comments, or producing tables where the entries are regular.

For example, in Usenet articles, sections of text quoted from another
author are indented, or have each line start with `>'.  To quote a
section of text, define a keyboard macro which inserts `>', put point
and mark at opposite ends of the quoted section, and use
`\\[apply-macro-to-region-lines]' to mark the entire section.

Suppose you wanted to build a keyword table in C where each entry
looked like this:

    { \"foo\", foo_data, foo_function }, 
    { \"bar\", bar_data, bar_function },
    { \"baz\", baz_data, baz_function },

You could enter the names in this format:

    foo
    bar
    baz

and write a macro to massage a word into a table entry:

    \\C-x (
       \\M-d { \"\\C-y\", \\C-y_data, \\C-y_function },
    \\C-x )

and then select the region of un-tablified names and use
`\\[apply-macro-to-region-lines]' to build the table from the names.
"
  (interactive "r")
  (if (null last-kbd-macro)
      (error "No keyboard macro has been defined."))
  (save-excursion
    (let ((end-marker (progn
			(goto-char bottom)
			(beginning-of-line)
			(point-marker))))
      (goto-char top)
      (if (not (bolp))
	  (forward-line 1))
      (while (< (point) end-marker)
	(execute-kbd-macro (or macro last-kbd-macro))
	(forward-line 1)))))

;;;###autoload
(define-key ctl-x-map "q" 'kbd-macro-query)
