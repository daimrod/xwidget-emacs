;; etags.el --- etags facility for Emacs

;; Copyright (C) 1985, 1986, 1988, 1989, 1992 Free Software Foundation, Inc.

;; Author: Roland McGrath <roland@gnu.ai.mit.edu>
;; Keywords: tools

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Code:

;;;###autoload
(defvar tags-file-name nil "\
*File name of tags table.
To switch to a new tags table, setting this variable is sufficient.
Use the `etags' program to make a tags table file.")
;;;###autoload (put 'tags-file-name 'variable-interactive "fVisit tags table: ")

;;;###autoload
(defvar tags-table-list nil
  "*List of names of tags table files which are currently being searched.
Elements that are directories mean the file \"TAGS\" in that directory.
An element of nil means to look for a file \"TAGS\" in the current directory.
Use `visit-tags-table-buffer' to cycle through tags tables in this list.")

(defvar tags-table-list-pointer nil
  "Pointer into `tags-table-list' where the current state of searching is.
Might instead point into a list of included tags tables.
Use `visit-tags-table-buffer' to cycle through tags tables in this list.")

(defvar tags-table-list-started-at nil
  "Pointer into `tags-table-list', where the current search started.")

(defvar tags-table-parent-pointer-list nil
  "Saved state of the tags table that included this one.
Each element is (POINTER . STARTED-AT), giving the values of
 `tags-table-list-pointer' and `tags-table-list-started-at' from
 before we moved into the current table.")

(defvar tags-table-set-list nil
  "List of sets of tags table which have been used together in the past.
Each element is a list of strings which are file names.")

;;;###autoload
(defvar find-tag-hook nil
  "*Hook to be run by \\[find-tag] after finding a tag.  See `run-hooks'.
The value in the buffer in which \\[find-tag] is done is used,
not the value in the buffer \\[find-tag] goes to.")

;;;###autoload
(defvar find-tag-default-function nil
  "*A function of no arguments used by \\[find-tag] to pick a default tag.
If nil, and the symbol that is the value of `major-mode'
has a `find-tag-default-function' property (see `put'), that is used.
Otherwise, `find-tag-default' is used.")

;;;###autoload
(defvar default-tags-table-function nil
  "*If non-nil, a function of no arguments to choose a default tags file
for a particular buffer.")

;; Tags table state.
;; These variables are local in tags table buffers.

(defvar tag-lines-already-matched nil
  "List of positions of beginnings of lines within the tags table
that are already matched.")

(defvar tags-table-files nil
  "List of file names covered by current tags table.
nil means it has not yet been computed; use `tags-table-files' to do so.")

(defvar tags-completion-table nil
  "Alist of tag names defined in current tags table.")

(defvar tags-included-tables nil
  "List of tags tables included by the current tags table.")

(defvar next-file-list nil
  "List of files for \\[next-file] to process.")

;; Hooks for file formats.

(defvar tags-table-format-hooks '(etags-recognize-tags-table
				  recognize-empty-tags-table)
  "List of functions to be called in a tags table buffer to identify
the type of tags table.  The functions are called in order, with no arguments,
until one returns non-nil.  The function should make buffer-local bindings
of the format-parsing tags function variables if successful.")

(defvar file-of-tag-function nil
  "Function to do the work of `file-of-tag' (which see).")
(defvar tags-table-files-function nil
  "Function to do the work of `tags-table-files' (which see).")
(defvar tags-completion-table-function nil
  "Function to build the tags-completion-table.")
(defvar snarf-tag-function nil
  "Function to get info about a matched tag for `goto-tag-location-function'.")
(defvar goto-tag-location-function nil
  "Function of to go to the location in the buffer specified by a tag.
One argument, the tag info returned by `snarf-tag-function'.")
(defvar find-tag-regexp-search-function nil
  "Search function passed to `find-tag-in-order' for finding a regexp tag.")
(defvar find-tag-regexp-tag-order nil
  "Tag order passed to `find-tag-in-order' for finding a regexp tag.")
(defvar find-tag-regexp-next-line-after-failure-p nil
  "Flag passed to `find-tag-in-order' for finding a regexp tag.")
(defvar find-tag-search-function nil
  "Search function passed to `find-tag-in-order' for finding a tag.")
(defvar find-tag-tag-order nil
  "Tag order passed to `find-tag-in-order' for finding a tag.")
(defvar find-tag-next-line-after-failure-p nil
  "Flag passed to `find-tag-in-order' for finding a tag.")
(defvar list-tags-function nil
  "Function to do the work of `list-tags' (which see).")
(defvar tags-apropos-function nil
  "Function to do the work of `tags-apropos' (which see).")
(defvar tags-included-tables-function nil
  "Function to do the work of `tags-included-tables' (which see).")
(defvar verify-tags-table-function nil
  "Function to return t iff the current buffer vontains a valid
\(already initialized\) tags file.")

(defun initialize-new-tags-table ()
  "Initialize the tags table in the current buffer.
Returns non-nil iff it is a valid tags table."
  (make-local-variable 'tag-lines-already-matched)
  (make-local-variable 'tags-table-files)
  (make-local-variable 'tags-completion-table)
  (make-local-variable 'tags-included-tables)
  (setq tags-table-files nil
	tag-lines-already-matched nil
	tags-completion-table nil
	tags-included-tables nil)
  ;; Value is t if we have found a valid tags table buffer.
  (let ((hooks tags-table-format-hooks))
    (while (and hooks
		(not (funcall (car hooks))))
      (setq hooks (cdr hooks)))
    hooks))

;;;###autoload
(defun visit-tags-table (file &optional local)
  "Tell tags commands to use tags table file FILE.
FILE should be the name of a file created with the `etags' program.
A directory name is ok too; it means file TAGS in that directory.

Normally \\[visit-tags-table] sets the global value of `tags-file-name'.
With a prefix arg, set the buffer-local value instead.
When you find a tag with \\[find-tag], the buffer it finds the tag
in is given a local value of this variable which is the name of the tags
file the tag was in."
  (interactive (list (read-file-name "Visit tags table: (default TAGS) "
				     default-directory
				     (expand-file-name "TAGS"
						       default-directory)
				     t)
		     current-prefix-arg))
  (let ((tags-file-name file))
    (save-excursion
      (or (visit-tags-table-buffer 'same)
	  (signal 'file-error (list "Visiting tags table"
				    "file does not exist"
				    file)))
      (setq file tags-file-name)))
  (if local
      (set (make-local-variable 'tags-file-name) file)
    (setq-default tags-file-name file)))

;; Move tags-table-list-pointer along and set tags-file-name.
;; Returns nil when out of tables.
(defun tags-next-table (&optional reset no-includes)
  (if reset
      (setq tags-table-list-pointer tags-table-list)

    (if (and (not no-includes)
	     (visit-tags-table-buffer 'same)
	     (tags-included-tables))
	;; Move into the included tags tables.
	(setq tags-table-parent-pointer-list
	      (cons (cons tags-table-list-pointer tags-table-list-started-at)
		    tags-table-parent-pointer-list)
	      tags-table-list-pointer tags-included-tables
	      tags-table-list-started-at tags-included-tables)

      ;; Go to the next table in the list.
      (setq tags-table-list-pointer
	    (cdr tags-table-list-pointer))
      (or tags-table-list-pointer
	  ;; Wrap around.
	  (setq tags-table-list-pointer tags-table-list))

      (if (eq tags-table-list-pointer tags-table-list-started-at)
	  ;; We have come full circle.
	  (if tags-table-parent-pointer-list
	      ;; Pop back to the tags table which includes this one.
	      (progn
		(setq tags-table-list-pointer
		      (car (car tags-table-parent-pointer-list))
		      tags-table-list-started-at
		      (cdr (car tags-table-parent-pointer-list))
		      tags-table-parent-pointer-list
		      (cdr tags-table-parent-pointer-list))
		(tags-next-table nil t))
	    ;; All out of tags tables.
	    (setq tags-table-list-pointer nil))))

    (and tags-table-list-pointer
	 (setq tags-file-name
	       (tags-expand-table-name (car tags-table-list-pointer))))))

(defun tags-expand-table-name (file)
  (or file
      ;; nil means look for TAGS in current directory.
      (setq file default-directory))
  (setq file (expand-file-name file))
  (if (file-directory-p file)
      (expand-file-name "TAGS" file)
    file))

(defun tags-table-list-member (file &optional list)
  (or list
      (setq list tags-table-list))
  (setq file (tags-expand-table-name file))
  (while (and list
	      (not (string= file (tags-expand-table-name (car list)))))
    (setq list (cdr list)))
  list)

;; Subroutine of visit-tags-table-buffer.  Frobs its local vars.
;; Search TABLES for one that has tags for THIS-FILE.
;; Recurses on included tables.
(defun tags-table-including (this-file tables &optional recursing)
  (let ((found nil))
    (while (and (not found)
		tables)
      (let ((tags-file-name (tags-expand-table-name (car tables))))
	(if (or (get-file-buffer tags-file-name)
		(file-exists-p tags-file-name))
	    (progn
	      ;; Select the tags table buffer and get the file list up to date.
	      (visit-tags-table-buffer 'same)
	      (or tags-table-files
		  (setq tags-table-files
			(funcall tags-table-files-function)))

	      (cond ((member this-file tags-table-files)
		     ;; Found it.
		     (setq found tables))

		    ((tags-included-tables)
		     (let ((old tags-table-parent-pointer-list))
		       (unwind-protect
			   (progn
			     (or recursing
				 ;; At top level (not in an included tags
				 ;; table), set the list to nil so we can
				 ;; collect just the elts from this run.
				 (setq tags-table-parent-pointer-list nil))
			     (setq found
				   (tags-table-including this-file
							 tags-included-tables
							 t))
			     (if found
				 (progn
				   (setq tags-table-parent-pointer-list
					 (cons
					  (cons tags-table-list-pointer
						tags-table-list-started-at)
					  tags-table-parent-pointer-list)
					 tags-table-list-pointer found
					 tags-table-list-started-at found
					 ;; Don't frob lists later.
					 cont 'included))))
			 (or recursing
			     ;; Recursive calls have consed onto the front
			     ;; of the list, so it is now outermost first.
			     ;; We want it innermost first.
			     (setq tags-table-parent-pointer-list
				   (nconc (nreverse
					   tags-table-parent-pointer-list)
					  old))))))))))
      (setq tables (cdr tables)))
    found))

(defun visit-tags-table-buffer (&optional cont)
  "Select the buffer containing the current tags table.
If optional arg is t, visit the next table in `tags-table-list'.
If optional arg is the atom `same', don't look for a new table;
 just select the buffer.
If arg is nil or absent, choose a first buffer from information in
`tags-file-name', `tags-table-list', `tags-table-list-pointer'.
Returns t if it visits a tags table, or nil if there are no more in the list."
  (cond ((eq cont 'same))

	(cont
	 (if (tags-next-table)
	     ;; Skip over nonexistent files.
	     (while (and (let ((file (tags-expand-table-name tags-file-name)))
			   (not (or (get-file-buffer file)
				    (file-exists-p file))))
			 (tags-next-table)))))

	(t
	 (setq tags-file-name
	       (or (cdr (assq 'tags-file-name (buffer-local-variables)))
		   (and default-tags-table-function
			(funcall default-tags-table-function))
		   ;; Look for a tags table that contains
		   ;; tags for the current buffer's file.
		   ;; If one is found, the lists will be frobnicated,
		   ;; and CONT will be set non-nil so we don't do it below.
		   (let ((found (save-excursion
				  (tags-table-including buffer-file-name
							tags-table-list))))
		     (and found
			  ;; Expand it so it won't be nil.
			  (tags-expand-table-name (car found))))
		   (tags-expand-table-name (car tags-table-list))
		   (tags-expand-table-name tags-file-name)
		   (expand-file-name
		    (read-file-name "Visit tags table: (default TAGS) "
				    default-directory
				    "TAGS"
				    t))))))

  (setq tags-file-name (tags-expand-table-name tags-file-name))

  (if (and (eq cont t) (null tags-table-list-pointer))
      ;; All out of tables.
      nil

    (if (if (get-file-buffer tags-file-name)
	    (let (win)
	      (set-buffer (get-file-buffer tags-file-name))
	      (setq win (or verify-tags-table-function
			    (initialize-new-tags-table)))
	      (if (or (verify-visited-file-modtime (current-buffer))
		      (not (yes-or-no-p
			    "Tags file has changed, read new contents? ")))
		  (and win (funcall verify-tags-table-function))
		(revert-buffer t t)
		(initialize-new-tags-table)))
	  (set-buffer (find-file-noselect tags-file-name))
	  (or (string= tags-file-name buffer-file-name)
	      ;; find-file-noselect has changed the file name.
	      ;; Propagate change to tags-file-name and tags-table-list.
	      (let ((tail (member file tags-table-list)))
		(if tail
		    (setcar tail buffer-file-name))
		(setq tags-file-name buffer-file-name)))
	  (initialize-new-tags-table))

	;; We have a valid tags table.
	(progn
	  ;; Bury the tags table buffer so it
	  ;; doesn't get in the user's way.
	  (bury-buffer (current-buffer))
	
	  (if cont
	      ;; No list frobbing required.
	      nil

	    ;; Look in the list for the table we chose.
	    (let ((elt (tags-table-list-member tags-file-name)))
	      (or elt
		  ;; The table is not in the current set.
		  ;; Try to find it in another previously used set.
		  (let ((sets tags-table-set-list))
		    (while (and sets
				(not (setq elt (tags-table-list-member
						tags-file-name (car sets)))))
		      (setq sets (cdr sets)))
		    (if sets
			(progn
			  ;; Found in some other set.  Switch to that set.
			  (or (memq tags-table-list tags-table-set-list)
			      ;; Save the current list.
			      (setq tags-table-set-list
				    (cons tags-table-list
					  tags-table-set-list)))
			  (setq tags-table-list (car sets)))

		      ;; Not found in any existing set.
		      (if (and tags-table-list
			       (y-or-n-p (concat "Add " tags-file-name
						 " to current list"
						 " of tags tables? ")))
			  ;; Add it to the current list.
			  (setq tags-table-list (cons tags-file-name
						      tags-table-list))
			;; Make a fresh list, and store the old one.
			(or (memq tags-table-list tags-table-set-list)
			    (setq tags-table-set-list
				  (cons tags-table-list tags-table-set-list)))
			(setq tags-table-list (list tags-file-name)))
		      (setq elt tags-table-list))))

	      (setq tags-table-list-started-at elt
		    tags-table-list-pointer elt)))

	  ;; Return of t says the tags table is valid.
	  t)

      ;; The buffer was not valid.  Don't use it again.
      (kill-local-variable 'tags-file-name)
      (setq tags-file-name nil)
      (error "File %s is not a valid tags table" buffer-file-name))))

(defun file-of-tag ()
  "Return the file name of the file whose tags point is within.
Assumes the tags table is the current buffer.
File name returned is relative to tags table file's directory."
  (funcall file-of-tag-function))

;;;###autoload
(defun tags-table-files ()
  "Return a list of files in the current tags table.
File names returned are absolute."
  (or tags-table-files
      (setq tags-table-files
	    (funcall tags-table-files-function))))

(defun tags-included-tables ()
  "Return a list of tags tables included by the current table."
  (or tags-included-tables
      (setq tags-included-tables (funcall tags-included-tables-function))))

;; Build tags-completion-table on demand.  The single current tags table
;; and its included tags tables (and their included tables, etc.) have
;; their tags included in the completion table.
(defun tags-completion-table ()
  (or tags-completion-table
      (condition-case ()
	  (prog2
	   (message "Making tags completion table for %s..." buffer-file-name)
	   (let ((included (tags-included-tables))
		 (table (funcall tags-completion-table-function)))
	     (save-excursion
	       (while included
		 (let ((tags-file-name (car included)))
		   (visit-tags-table-buffer 'same))
		 (if (tags-completion-table)
		     (mapatoms (function
				(lambda (sym)
				  (intern (symbol-name sym) table)))
			       tags-completion-table))
		 (setq included (cdr included))))
	     (setq tags-completion-table table))
	   (message "Making tags completion table for %s...done"
		    buffer-file-name))
	(quit (message "Tags completion table construction aborted.")
	      (setq tags-completion-table nil)))))

;; Completion function for tags.  Does normal try-completion,
;; but builds tags-completion-table on demand.
(defun tags-complete-tag (string predicate what)
  (save-excursion
    (visit-tags-table-buffer)
    (if (eq what t)
	(all-completions string (tags-completion-table) predicate)
      (try-completion string (tags-completion-table) predicate))))

;; Return a default tag to search for, based on the text at point.
(defun find-tag-default ()
  (save-excursion
    (while (looking-at "\\sw\\|\\s_")
      (forward-char 1))
    (if (or (re-search-backward "\\sw\\|\\s_"
				(save-excursion (beginning-of-line) (point))
				t)
	    (re-search-forward "\\(\\sw\\|\\s_\\)+"
			       (save-excursion (end-of-line) (point))
			       t))
	(progn (goto-char (match-end 0))
	       (buffer-substring (point)
				 (progn (forward-sexp -1)
					(while (looking-at "\\s'")
					  (forward-char 1))
					(point))))
      nil)))

;; Read a tag name from the minibuffer with defaulting and completion.
(defun find-tag-tag (string)
  (let* ((default (funcall (or find-tag-default-function
			       (get major-mode 'find-tag-default-function)
			       'find-tag-default)))
	 (spec (completing-read (if default
				    (format "%s(default %s) " string default)
				  string)
				'tags-complete-tag)))
    (list (if (equal spec "")
	      (or default (error "There is no default tag"))
	    spec))))

(defvar last-tag nil
  "Last tag found by \\[find-tag].")

;;;###autoload
(defun find-tag-noselect (tagname &optional next-p regexp-p)
  "Find tag (in current tags table) whose name contains TAGNAME.
Returns the buffer containing the tag's definition moves its point there,
but does not select the buffer.
The default for TAGNAME is the expression in the buffer near point.

If second arg NEXT-P is non-nil (interactively, with prefix arg), search
for another tag that matches the last tagname or regexp used.  When there
are multiple matches for a tag, more exact matches are found first.

If third arg REGEXP-P is non-nil, treat TAGNAME as a regexp.

See documentation of variable `tags-file-name'."
  (interactive (if current-prefix-arg
		   '(nil t)
		 (find-tag-tag "Find tag: ")))
  (let ((local-find-tag-hook find-tag-hook))
    (if next-p
	(visit-tags-table-buffer 'same)
      (setq last-tag tagname)
      (visit-tags-table-buffer))
    (prog1
	(find-tag-in-order (if next-p last-tag tagname)
			   (if regexp-p
			       find-tag-regexp-search-function
			     find-tag-search-function)
			   (if regexp-p
			       find-tag-regexp-tag-order
			     find-tag-tag-order)
			   (if regexp-p
			       find-tag-regexp-next-line-after-failure-p
			     find-tag-next-line-after-failure-p)
			   (if regexp-p "matching" "containing")
			   (not next-p))
      (run-hooks 'local-find-tag-hook))))

;;;###autoload
(defun find-tag (tagname &optional next-p)
  "Find tag (in current tags table) whose name contains TAGNAME.
Select the buffer containing the tag's definition, and move point there.
The default for TAGNAME is the expression in the buffer around or before point.

If second arg NEXT-P is non-nil (interactively, with prefix arg), search
for another tag that matches the last tagname used.  When there are
multiple matches, more exact matches are found first.

See documentation of variable `tags-file-name'."
  (interactive (if current-prefix-arg
		   '(nil t)
		 (find-tag-tag "Find tag: ")))
  (switch-to-buffer (find-tag-noselect tagname next-p)))
;;;###autoload (define-key esc-map "." 'find-tag)

;;;###autoload
(defun find-tag-other-window (tagname &optional next-p)
  "Find tag (in current tags table) whose name contains TAGNAME.
Select the buffer containing the tag's definition
in another window, and move point there.
The default for TAGNAME is the expression in the buffer around or before point.

If second arg NEXT-P is non-nil (interactively, with prefix arg), search
for another tag that matches the last tagname used.  When there are
multiple matches, more exact matches are found first.

See documentation of variable `tags-file-name'."
  (interactive (if current-prefix-arg
		   '(nil t)
		 (find-tag-tag "Find tag other window: ")))
  (switch-to-buffer-other-window (find-tag-noselect tagname next-p)))
;;;###autoload (define-key ctl-x-4-map "." 'find-tag-other-window)

;;;###autoload
(defun find-tag-other-frame (tagname &optional next-p)
  "Find tag (in current tag table) whose name contains TAGNAME.
 Selects the buffer that the tag is contained in in another frame
and puts point at its definition.
 If TAGNAME is a null string, the expression in the buffer
around or before point is used as the tag name.
 If second arg NEXT-P is non-nil (interactively, with prefix arg),
searches for the next tag in the tag table
that matches the tagname used in the previous find-tag.

See documentation of variable `tags-file-name'."
  (interactive (if current-prefix-arg
		   '(nil t)
		   (find-tag-tag "Find tag other window: ")))
  (let ((pop-up-frames t))
    (find-tag-other-window tagname next-p)))
;;;###autoload (define-key ctl-x-5-map "." 'find-tag-other-frame)

;;;###autoload
(defun find-tag-regexp (regexp &optional next-p other-window)
  "Find tag (in current tags table) whose name matches REGEXP.
Select the buffer containing the tag's definition and move point there.

If second arg NEXT-P is non-nil (interactively, with prefix arg), search
for another tag that matches the last tagname used.

If third arg OTHER-WINDOW is non-nil, select the buffer in another window.

See documentation of variable `tags-file-name'."
  (interactive (if current-prefix-arg
		   '(nil t)
		 (read-string "Find tag regexp: ")))
  (funcall (if other-window 'switch-to-buffer-other-window 'switch-to-buffer)
	   (find-tag-noselect regexp next-p t)))

;; Internal tag finding function.

;; PATTERN is a string to pass to second arg SEARCH-FORWARD-FUNC, and to
;; any member of the function list ORDER (third arg).  If ORDER is nil,
;; use saved state to continue a previous search.

;; Fourth arg MATCHING is a string, an English '-ing' word, to be used in
;; an error message.

;; Fifth arg NEXT-LINE-AFTER-FAILURE-P is non-nil if after a failed match,
;; point should be moved to the next line.

;; Algorithm is as follows.  For each qualifier-func in ORDER, go to
;; beginning of tags file, and perform inner loop: for each naive match for
;; PATTERN found using SEARCH-FORWARD-FUNC, qualify the naive match using
;; qualifier-func.  If it qualifies, go to the specified line in the
;; specified source file and return.  Qualified matches are remembered to
;; avoid repetition.  State is saved so that the loop can be continued.

(defun find-tag-in-order (pattern search-forward-func order
				  next-line-after-failure-p matching
				  first-search)
  (let (file				;name of file containing tag
	tag-info			;where to find the tag in FILE
	tags-table-file			;name of tags file
	(first-table t)
	(tag-order order)
	goto-func
	)
    (save-excursion
      (or first-search			;find-tag-noselect has already done it.
	  (visit-tags-table-buffer 'same))

      ;; Get a qualified match.
      (catch 'qualified-match-found

	(while (or first-table
		   (visit-tags-table-buffer t))

	  (if first-search
	      (setq tag-lines-already-matched nil))

	  (and first-search first-table
	       ;; Start at beginning of tags file.
	       (goto-char (point-min)))
	  (setq first-table nil)

	  (setq tags-table-file buffer-file-name)
	  (while order
	    (while (funcall search-forward-func pattern nil t)
	      ;; Naive match found.  Qualify the match.
	      (and (funcall (car order) pattern)
		   ;; Make sure it is not a previous qualified match.
		   ;; Use of `memq' depends on numbers being eq.
		   (not (memq (save-excursion (beginning-of-line) (point))
			      tag-lines-already-matched))
		   (throw 'qualified-match-found nil))
	      (if next-line-after-failure-p
		  (forward-line 1)))
	    ;; Try the next flavor of match.
	    (setq order (cdr order))
	    (goto-char (point-min)))
	  (setq order tag-order))
	;; We throw out on match, so only get here if there were no matches.
	(error "No %stags %s %s" (if first-search "" "more ")
	       matching pattern))
      
      ;; Found a tag; extract location info.
      (beginning-of-line)
      (setq tag-lines-already-matched (cons (point)
					    tag-lines-already-matched))
      ;; Expand the filename, using the tags table buffer's default-directory.
      (setq file (expand-file-name (file-of-tag))
	    tag-info (funcall snarf-tag-function))

      ;; Get the local value in the tags table buffer.
      (setq goto-func goto-tag-location-function)

      ;; Find the right line in the specified file.
      (set-buffer (find-file-noselect file))
      (widen)
      (push-mark)
      (funcall goto-func tag-info)
      
      ;; Give this buffer a local value of tags-file-name.
      ;; The next time visit-tags-table-buffer is called,
      ;; it will use the same tags table that found a match in this buffer.
      (make-local-variable 'tags-file-name)
      (setq tags-file-name tags-table-file)
      
      ;; Return the buffer where the tag was found.
      (current-buffer))))

;; `etags' TAGS file format support.

(defun etags-recognize-tags-table ()
  (and (eq (char-after 1) ?\f)
       ;; It is annoying to flash messages on the screen briefly,
       ;; and this message is not useful.  -- rms
       ;; (message "%s is an `etags' TAGS file" buffer-file-name)
       (mapcar (function (lambda (elt)
			   (make-local-variable (car elt))
			   (set (car elt) (cdr elt))))
	       '((file-of-tag-function . etags-file-of-tag)
		 (tags-table-files-function . etags-tags-table-files)
		 (tags-completion-table-function . etags-tags-completion-table)
		 (snarf-tag-function . etags-snarf-tag)
		 (goto-tag-location-function . etags-goto-tag-location)
		 (find-tag-regexp-search-function . re-search-forward)
		 (find-tag-regexp-tag-order . (tag-re-match-p))
		 (find-tag-regexp-next-line-after-failuire-p . t)
		 (find-tag-search-function . search-forward)
		 (find-tag-tag-order . (tag-exact-match-p tag-word-match-p
							  tag-any-match-p))
		 (find-tag-next-line-after-failure-p . nil)
		 (list-tags-function . etags-list-tags)
		 (tags-apropos-function . etags-tags-apropos)
		 (tags-included-tables-function . etags-tags-included-tables)
		 (verify-tags-table-function . etags-verify-tags-table)
		 ))))

(defun etags-verify-tags-table ()
  (= (char-after 1) ?\f))

(defun etags-file-of-tag ()
  (save-excursion
    (search-backward "\f\n")
    (forward-char 2)
    (buffer-substring (point)
		      (progn (skip-chars-forward "^,") (point)))))

(defun etags-tags-completion-table ()
  (let ((table (make-vector 511 0)))
    (save-excursion
      (goto-char (point-min))
      (while (search-forward "\177" nil t)
	;; Handle multiple \177's on a line.
	(save-excursion
	  (skip-chars-backward "^-A-Za-z0-9_$\n") ;sym syntax? XXX
	  (or (bolp)
	      (intern (buffer-substring
		       (point)
		       (progn
			 (skip-chars-backward "-A-Za-z0-9_$")
			 ;; ??? New
			 ;; `::' in the middle of a C++ tag.
			 (and (= (preceding-char) ?:)
			      (= (char-after (- (point) 2)) ?:)
			      (progn
				(backward-char 2)
				(skip-chars-backward
				 "-A-Za-z0-9_$")))
			 (point)))
		      table)))))
    table))

(defun etags-snarf-tag ()
  (let (tag-text startpos)
    (search-forward "\177")
    (setq tag-text (buffer-substring (1- (point))
				     (save-excursion (beginning-of-line)
						     (point))))
    (search-forward ",")
    (setq startpos (string-to-int (buffer-substring
				   (point)
				   (progn (skip-chars-forward "0-9")
					  (point)))))
    ;; Leave point on the next line of the tags file.
    (forward-line 1)
    (cons tag-text startpos)))

(defun etags-goto-tag-location (tag-info)
  (let ((startpos (cdr tag-info))
	;; This constant is 1/2 the initial search window.
	;; There is no sense in making it too small,
	;; since just going around the loop once probably
	;; costs about as much as searching 2000 chars.
	(offset 1000)
	(found nil)
	(pat (concat "^" (regexp-quote (car tag-info)))))
    (or startpos
	(setq startpos (point-min)))
    (while (and (not found)
		(progn
		  (goto-char (- startpos offset))
		  (not (bobp))))
      (setq found
	    (re-search-forward pat (+ startpos offset) t)
	    offset (* 3 offset)))	; expand search window
    (or found
	(re-search-forward pat nil t)
	(error "`%s' not found in %s; time to rerun etags"
	       pat buffer-file-name)))
  (beginning-of-line))

(defun etags-list-tags (file)
  (goto-char 1)
  (if (not (search-forward (concat "\f\n" file ",") nil t))
      nil
    (forward-line 1)
    (while (not (or (eobp) (looking-at "\f")))
      (princ (buffer-substring (point)
			       (progn (skip-chars-forward "^\177")
				      (point))))
      (terpri)
      (forward-line 1))))

(defun etags-tags-apropos (string)
  (goto-char 1)
  (while (re-search-forward string nil t)
    (beginning-of-line)
    (princ (buffer-substring (point)
			     (progn (skip-chars-forward "^\177")
				    (point))))
    (terpri)
    (forward-line 1)))

(defun etags-tags-table-files ()
  (let ((files nil)
	beg)
    (goto-char (point-min))
    (while (search-forward "\f\n" nil t)
      (setq beg (point))
      (skip-chars-forward "^,\n")
      (or (looking-at ",include$")
	  ;; Expand in the default-directory of the tags table buffer.
	  (setq files (cons (expand-file-name (buffer-substring beg (point)))
			    files))))
    (nreverse files)))

(defun etags-tags-included-tables ()
  (let ((files nil)
	beg)
    (goto-char (point-min))
    (while (search-forward "\f\n" nil t)
      (setq beg (point))
      (skip-chars-forward "^,\n")
      (if (looking-at ",include$")
	  ;; Expand in the default-directory of the tags table buffer.
	  (setq files (cons (expand-file-name (buffer-substring beg (point)))
			    files))))
    (nreverse files)))

;; Empty tags file support.

(defun recognize-empty-tags-table ()
  (and (zerop (buffer-size))
       (mapcar (function (lambda (sym)
			   (make-local-variable sym)
			   (set sym 'ignore)))
	       '(tags-table-files-function
		 tags-completion-table-function
		 find-tag-regexp-search-function
		 find-tag-search-function
		 tags-apropos-function
		 tags-included-tables-function))
       (set (make-local-variable 'verify-tags-table-function)
	    (function (lambda ()
			(zerop (buffer-size)))))))

;;; Match qualifier functions for tagnames.

;; This might be a neat idea, but it's too hairy at the moment.
;;(defmacro tags-with-syntax (&rest body)
;;  (` (let ((current (current-buffer))
;;	   (otable (syntax-table))
;;	   (buffer (find-file-noselect (file-of-tag)))
;;	   table)
;;       (unwind-protect
;;	   (progn
;;	     (set-buffer buffer)
;;	     (setq table (syntax-table))
;;	     (set-buffer current)
;;	     (set-syntax-table table)
;;	     (,@ body))
;;	 (set-syntax-table otable)))))
;;(put 'tags-with-syntax 'edebug-form-spec '(&rest form))

;; t if point is at a tag line that matches TAG "exactly".
;; point should be just after a string that matches TAG.
(defun tag-exact-match-p (tag)
  (and (looking-at "\\Sw.*\177") (looking-at "\\S_.*\177") ;not a symbol char
       (save-excursion
	 (backward-char (1+ (length tag)))
	 (and (looking-at "\\Sw") (looking-at "\\S_")))))

;; t if point is at a tag line that matches TAG as a word.
;; point should be just after a string that matches TAG.
(defun tag-word-match-p (tag)
  (and (looking-at "\\b.*\177")
       (save-excursion (backward-char (1+ (length tag)))
		       (looking-at "\\b"))))

;; t if point is in a tag line with a tag containing TAG as a substring.
(defun tag-any-match-p (tag)
  (looking-at ".*\177"))

;; t if point is at a tag line that matches RE as a regexp.
(defun tag-re-match-p (re)
  (save-excursion
    (beginning-of-line)
    (let ((bol (point)))
      (and (search-forward "\177" (save-excursion (end-of-line) (point)) t)
	   (re-search-backward re bol t)))))

;;;###autoload
(defun next-file (&optional initialize novisit)
  "Select next file among files in current tags table.
Non-nil first argument (prefix arg, if interactive)
initializes to the beginning of the list of files in the tags table.

Non-nil second argument NOVISIT means use a temporary buffer
 to save time and avoid uninteresting warnings.

Value is nil if the file was already visited;
if the file was newly read in, the value is the filename."
  (interactive "P")
  (and initialize
       (save-excursion
	 (visit-tags-table-buffer)
	 (setq next-file-list (tags-table-files))))
  (or next-file-list
      (save-excursion
	;; Get the files from the next tags table.
	;; When doing (visit-tags-table-buffer t),
	;; the tags table buffer must be current.
	(if (and (visit-tags-table-buffer 'same)
		 (visit-tags-table-buffer t))
	    (setq next-file-list (tags-table-files))
	  (and novisit
	       (get-buffer " *next-file*")
	       (kill-buffer " *next-file*"))
	  (error "All files processed."))))
  (let ((new (not (get-file-buffer (car next-file-list)))))
    (if (not (and new novisit))
	(set-buffer (find-file-noselect (car next-file-list) novisit))
      ;; Like find-file, but avoids random warning messages.
      (set-buffer (get-buffer-create " *next-file*"))
      (kill-all-local-variables)
      (erase-buffer)
      (setq new (car next-file-list))
      (insert-file-contents new nil))
    (setq next-file-list (cdr next-file-list))
    new))

(defvar tags-loop-operate nil
  "Form for `tags-loop-continue' to eval to change one file.")

(defvar tags-loop-scan nil
  "Form for `tags-loop-continue' to eval to scan one file.
If it returns non-nil, this file needs processing by evalling
\`tags-loop-operate'.  Otherwise, move on to the next file.")

;;;###autoload
(defun tags-loop-continue (&optional first-time)
  "Continue last \\[tags-search] or \\[tags-query-replace] command.
Used noninteractively with non-nil argument to begin such a command.
Two variables control the processing we do on each file:
the value of `tags-loop-scan' is a form to be executed on each file
to see if it is interesting (it returns non-nil if so)
and `tags-loop-operate' is a form to execute to operate on an interesting file
If the latter returns non-nil, we exit; otherwise we scan the next file."
  (interactive)
  (let (new
	(messaged nil))
    (while
	(progn
	  ;; Scan files quickly for the first or next interesting one.
	  (while (or first-time
		     (save-restriction
		       (widen)
		       (not (eval tags-loop-scan))))
	    (setq new (next-file first-time t))
	    ;; If NEW is non-nil, we got a temp buffer,
	    ;; and NEW is the file name.
	    (if (or messaged
		    (and (not first-time)
			 (> baud-rate search-slow-speed)
			 (setq messaged t)))
		(message "Scanning file %s..." (or new buffer-file-name)))
	    (setq first-time nil)
	    (goto-char (point-min)))

	  ;; If we visited it in a temp buffer, visit it now for real.
	  (if new
	      (let ((pos (point)))
		(erase-buffer)
		(set-buffer (find-file-noselect new))
		(widen)
		(goto-char pos)))

	  (switch-to-buffer (current-buffer))

	  ;; Now operate on the file.
	  ;; If value is non-nil, continue to scan the next file.
	  (eval tags-loop-operate)))
    (and messaged
	 (null tags-loop-operate)
	 (message "Scanning file %s...found" buffer-file-name))))
    
;;;###autoload (define-key esc-map "," 'tags-loop-continue)

;;;###autoload
(defun tags-search (regexp)
  "Search through all files listed in tags table for match for REGEXP.
Stops when a match is found.
To continue searching for next match, use command \\[tags-loop-continue].

See documentation of variable `tags-file-name'."
  (interactive "sTags search (regexp): ")
  (if (and (equal regexp "")
	   (eq (car tags-loop-scan) 're-search-forward)
	   (eq tags-loop-operate t))
      ;; Continue last tags-search as if by M-,.
      (tags-loop-continue nil)
    (setq tags-loop-scan
	  (list 're-search-forward regexp nil t)
	  tags-loop-operate nil)
    (tags-loop-continue t)))

;;;###autoload
(defun tags-query-replace (from to &optional delimited)
  "Query-replace-regexp FROM with TO through all files listed in tags table.
Third arg DELIMITED (prefix arg) means replace only word-delimited matches.
If you exit (\\[keyboard-quit] or ESC), you can resume the query-replace
with the command \\[tags-loop-continue].

See documentation of variable `tags-file-name'."
  (interactive
   "sTags query replace (regexp): \nsTags query replace %s by: \nP")
  (setq tags-loop-scan (list 'prog1
			     (list 'if (list 're-search-forward form nil t)
				   ;; When we find a match, move back
				   ;; to the beginning of it so perform-replace
				   ;; will see it.
				   '(goto-char (match-beginning 0))))
	tags-loop-operate (list 'perform-replace from to t t delimited))
  (tags-loop-continue t))

;;;###autoload
(defun list-tags (file)
  "Display list of tags in file FILE.
FILE should not contain a directory specification
unless it has one in the tags table."
  (interactive (list (completing-read "List tags in file: " nil
				      'tags-table-files t nil)))
  (with-output-to-temp-buffer "*Tags List*"
    (princ "Tags in file ")
    (princ file)
    (terpri)
    (save-excursion
      (let ((first-time t)
	    (gotany nil))
	(while (visit-tags-table-buffer (not first-time))
	  (if (funcall list-tags-function file)
	      (setq gotany t)))
	(or gotany
	    (error "File %s not in current tags tables"))))))

;;;###autoload
(defun tags-apropos (regexp)
  "Display list of all tags in tags table REGEXP matches."
  (interactive "sTags apropos (regexp): ")
  (with-output-to-temp-buffer "*Tags List*"
    (princ "Tags matching regexp ")
    (prin1 regexp)
    (terpri)
    (save-excursion
      (let ((first-time t))
	(while (visit-tags-table-buffer (not first-time))
	  (setq first-time nil)
	  (funcall tags-apropos-function regexp))))))

;;; XXX Kludge interface.

;; XXX If a file is in multiple tables, selection may get the wrong one.
;;;###autoload
(defun select-tags-table ()
  "Select a tags table file from a menu of those you have already used.
The list of tags tables to select from is stored in `tags-table-file-list';
see the doc of that variable if you want to add names to the list."
  (interactive)
  (pop-to-buffer "*Tags Table List*")
  (setq buffer-read-only nil)
  (erase-buffer)
  (setq selective-display t
	selective-display-ellipses nil)
  (let ((set-list tags-table-set-list)
	(desired-point nil))
    (if tags-table-list
	(progn
	  (setq desired-point (point-marker))
	  (princ tags-table-list (current-buffer))
	  (insert "\C-m")
	  (prin1 (car tags-table-list) (current-buffer)) ;invisible
	  (insert "\n")))
    (while set-list
      (if (eq (car set-list) tags-table-list)
	  ;; Already printed it.
	  ()
	(princ (car set-list) (current-buffer))
	(insert "\C-m")
	(prin1 (car (car set-list)) (current-buffer)) ;invisible
	(insert "\n"))
      (setq set-list (cdr set-list)))
    (if tags-file-name
	(progn
	  (or desired-point
	      (setq desired-point (point-marker)))
	  (insert tags-file-name "\C-m")
	  (prin1 tags-file-name (current-buffer)) ;invisible
	  (insert "\n")))
    (setq set-list (delete tags-file-name
			   (apply 'nconc (cons tags-table-list
					       (mapcar 'copy-sequence
						       tags-table-set-list)))))
    (while set-list
      (insert (car set-list) "\C-m")
      (prin1 (car set-list) (current-buffer)) ;invisible
      (insert "\n")
      (setq set-list (delete (car set-list) set-list)))
    (goto-char 1)
    (insert-before-markers
     "Type `t' to select a tags table or set of tags tables:\n\n")
    (if desired-point
	(goto-char desired-point))
    (set-window-start (selected-window) 1 t))
  (set-buffer-modified-p nil)
  (setq buffer-read-only t
	mode-name "Select Tags Table")
  (let ((map (make-sparse-keymap)))
    (define-key map "t" 'select-tags-table-select)
    (define-key map " " 'next-line)
    (define-key map "\^?" 'previous-line)
    (define-key map "n" 'next-line)
    (define-key map "p" 'previous-line)
    (define-key map "q" 'select-tags-table-quit)
    (use-local-map map)))
  
(defun select-tags-table-select ()
  "Select the tags table named on this line."
  (interactive)
  (search-forward "\C-m")
  (let ((name (read (current-buffer))))
    (visit-tags-table name)
    (select-tags-table-quit)
    (message "Tags table now %s" name)))

(defun select-tags-table-quit ()
  "Kill the buffer and delete the selected window."
  (interactive)
  (kill-buffer (current-buffer))
  (or (one-window-p)
      (delete-window)))  

;;;###autoload
(defun complete-tag ()
  "Perform tags completion on the text around point.
Completes to the set of names listed in the current tags table.  
The string to complete is chosen in the same way as the default
for \\[find-tag] (which see)."
  (interactive)
  (or tags-table-list
      tags-file-name
      (error (substitute-command-keys
	      "No tags table loaded.  Try \\[visit-tags-table].")))
  (let ((pattern (funcall (or find-tag-default-function
			      (get major-mode 'find-tag-default-function)
			      'find-tag-default)))
	beg
	completion)
    (or pattern
	(error "Nothing to complete"))
    (search-backward pattern)
    (setq beg (point))
    (forward-char (length pattern))
    (setq completion (try-completion pattern 'tags-complete-tag nil))
    (cond ((eq completion t))
	  ((null completion)
	   (message "Can't find completion for \"%s\"" pattern)
	   (ding))
	  ((not (string= pattern completion))
	   (delete-region beg (point))
	   (insert completion))
	  (t
	   (message "Making completion list...")
	   (with-output-to-temp-buffer " *Completions*"
	     (display-completion-list
	      (all-completions pattern 'tags-complete-tag nil)))
	   (message "Making completion list...%s" "done")))))

;;;###autoload (define-key esc-map "\t" 'complete-tag)

(provide 'etags)

;;; etags.el ends here
