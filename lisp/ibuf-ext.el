;;; ibuf-ext.el --- extensions for ibuffer -*-byte-compile-dynamic: t;-*-

;; Copyright (C) 2000, 2001, 2002 Free Software Foundation, Inc.

;; Author: Colin Walters <walters@verbum.org>
;; Created: 2 Dec 2001
;; Keywords: buffer, convenience

;; This file is not currently part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program ; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; These functions should be automatically loaded when called, but you
;; can explicity (require 'ibuf-ext) in your ~/.emacs to have them
;; preloaded.

;;; Code:

(require 'ibuffer)

(eval-when-compile
  (require 'derived)
  (require 'ibuf-macs)
  (require 'cl))

;;; Utility functions
(defun ibuffer-delete-alist (key alist)
  "Delete all entries in ALIST that have a key equal to KEY."
  (let (entry)
    (while (setq entry (assoc key alist))
      (setq alist (delete entry alist)))
    alist))

(defun ibuffer-depropertize-string (str &optional nocopy)
  "Return a copy of STR with text properties removed.
If optional argument NOCOPY is non-nil, actually modify the string directly."
  (let ((str (if nocopy
		 str
	       (copy-sequence str))))
    (set-text-properties 0 (length str) nil str)
    str))

(defcustom ibuffer-never-show-predicates nil
  "A list of predicates (a regexp or function) for buffers not to display.
If a regexp, then it will be matched against the buffer's name.
If a function, it will be called with the buffer as an argument, and
should return non-nil if this buffer should not be shown."
  :type '(repeat (choice regexp function))
  :group 'ibuffer)

(defcustom ibuffer-always-show-predicates nil
  "A list of predicates (a regexp or function) for buffers to always display.
If a regexp, then it will be matched against the buffer's name.
If a function, it will be called with the buffer as an argument, and
should return non-nil if this buffer should be shown.
Note that buffers matching one of these predicates will be shown
regardless of any active filters in this buffer."
  :type '(repeat (choice regexp function))
  :group 'ibuffer)

(defvar ibuffer-tmp-hide-regexps nil
  "A list of regexps which should match buffer names to not show.")
  
(defvar ibuffer-tmp-show-regexps nil
  "A list of regexps which should match buffer names to always show.")

(defvar ibuffer-auto-mode nil
  "If non-nil, Ibuffer auto-mode should be enabled for this buffer.
Do not set this variable directly!  Use the function
`ibuffer-auto-mode' instead.")

(defvar ibuffer-auto-buffers-changed nil)

(defcustom ibuffer-occur-match-face 'font-lock-warning-face
  "Face used for displaying matched strings for `ibuffer-do-occur'."
  :type 'face
  :group 'ibuffer)

(defcustom ibuffer-saved-filters '(("gnus"
				    ((or (mode . message-mode)
					 (mode . mail-mode)
					 (mode . gnus-group-mode)
					 (mode . gnus-summary-mode) 
					 (mode . gnus-article-mode))))
				   ("programming"
				    ((or (mode . emacs-lisp-mode)
					 (mode . cperl-mode)
					 (mode . c-mode)
					 (mode . java-mode) 
					 (mode . idl-mode)
					 (mode . lisp-mode)))))
				  
  "An alist of filter qualifiers to switch between.

This variable should look like ((\"STRING\" QUALIFIERS)
                                (\"STRING\" QUALIFIERS) ...), where
QUALIFIERS is a list of the same form as
`ibuffer-filtering-qualifiers'.
See also the variables `ibuffer-filtering-qualifiers',
`ibuffer-filtering-alist', and the functions
`ibuffer-switch-to-saved-filters', `ibuffer-save-filters'."
  :type '(repeat sexp)
  :group 'ibuffer)

(defvar ibuffer-filtering-qualifiers nil
  "A list like (SYMBOL . QUALIFIER) which filters the current buffer list.
See also `ibuffer-filtering-alist'.")

;; This is now frobbed by `define-ibuffer-filter'.
(defvar ibuffer-filtering-alist nil
  "An alist of (SYMBOL DESCRIPTION FUNCTION) which describes a filter.

You most likely do not want to modify this variable directly; see
`define-ibuffer-filter'.

SYMBOL is the symbolic name of the filter.  DESCRIPTION is used when
displaying information to the user.  FUNCTION is given a buffer and
the value of the qualifier, and returns non-nil if and only if the
buffer should be displayed.")

(defcustom ibuffer-filter-format-alist nil
  "An alist which has special formats used when a filter is active.
The contents of this variable should look like:
 ((FILTER (FORMAT FORMAT ...)) (FILTER (FORMAT FORMAT ...)) ...)

For example, suppose that when you add a filter for buffers whose
major mode is `emacs-lisp-mode', you only want to see the mark and the
name of the buffer.  You could accomplish that by adding:
 (mode ((mark \" \" name)))
to this variable.")

(defvar ibuffer-cached-filter-formats nil)
(defvar ibuffer-compiled-filter-formats nil)  

(defcustom ibuffer-old-time 3
  "The number of days before a buffer is considered \"old\"."
  :type 'integer
  :group 'ibuffer)

(defcustom ibuffer-save-with-custom t
  "If non-nil, then use Custom to save interactively changed variables.
Currently, this only applies to `ibuffer-saved-filters'."
  :type 'boolean
  :group 'ibuffer)

(defun ibuffer-ext-visible-p (buf all &optional ibuffer-buf)
  (or
   (ibuffer-buf-matches-predicates buf ibuffer-tmp-show-regexps)
   (and (not
	 (or
	  (ibuffer-buf-matches-predicates buf ibuffer-tmp-hide-regexps)
	  (ibuffer-buf-matches-predicates buf ibuffer-never-show-predicates)))
	(or all
	    (not
	     (ibuffer-buf-matches-predicates buf ibuffer-maybe-show-predicates)))
	(or ibuffer-view-ibuffer
	    (and ibuffer-buf 
		 (not (eq ibuffer-buf buf))))
	(or
	 (ibuffer-included-in-filters-p buf ibuffer-filtering-qualifiers)
	 (ibuffer-buf-matches-predicates buf ibuffer-always-show-predicates)))))

(defun ibuffer-auto-update-changed ()
  (when ibuffer-auto-buffers-changed
    (setq ibuffer-auto-buffers-changed nil)
    (mapcar #'(lambda (buf)
		(ignore-errors
		  (with-current-buffer buf
		    (when (and ibuffer-auto-mode
			       (eq major-mode 'ibuffer-mode))
		      (ibuffer-update nil t)))))
	    (buffer-list))))

;;;###autoload
(defun ibuffer-auto-mode (&optional arg)
  "Toggle use of Ibuffer's auto-update facility.
With numeric ARG, enable auto-update if and only if ARG is positive."
  (interactive)
  (unless (eq major-mode 'ibuffer-mode)
    (error "This buffer is not in Ibuffer mode"))
  (set (make-local-variable 'ibuffer-auto-mode)
       (if arg
	   (plusp arg)
	 (not ibuffer-auto-mode)))
  (defadvice get-buffer-create (after ibuffer-notify-create activate)
    (setq ibuffer-auto-buffers-changed t))
  (defadvice kill-buffer (after ibuffer-notify-kill activate)
    (setq ibuffer-auto-buffers-changed t))
  (add-hook 'post-command-hook 'ibuffer-auto-update-changed)
  (ibuffer-update-mode-name))

;;;###autoload
(defun ibuffer-mouse-filter-by-mode (event)
  "Enable or disable filtering by the major mode chosen via mouse."
  (interactive "e")
  (ibuffer-interactive-filter-by-mode event))

;;;###autoload
(defun ibuffer-interactive-filter-by-mode (event-or-point)
  "Enable or disable filtering by the major mode at point."
  (interactive "d")
  (if (eventp event-or-point)
      (mouse-set-point event-or-point)
    (goto-char event-or-point))
  (let ((buf (ibuffer-current-buffer)))
    (if (assq 'mode ibuffer-filtering-qualifiers)
	(setq ibuffer-filtering-qualifiers
	      (ibuffer-delete-alist 'mode ibuffer-filtering-qualifiers))
      (ibuffer-push-filter (cons 'mode 
				(with-current-buffer buf
				  major-mode)))))
  (ibuffer-update nil t))

(define-ibuffer-op shell-command-pipe (command)
  "Pipe the contents of each marked buffer to shell command COMMAND."
  (:interactive "sPipe to shell command: "
   :opstring "Shell command executed on"
   :modifier-p nil)
  (shell-command-on-region
   (point-min) (point-max) command
   (get-buffer-create "* ibuffer-shell-output*")))

(define-ibuffer-op shell-command-pipe-replace (command)
  "Replace the contents of marked buffers with output of pipe to COMMAND."
  (:interactive "sPipe to shell command (replace): "
   :opstring "Buffer contents replaced in"
   :active-opstring "replace buffer contents in"
   :dangerous t
   :modifier-p t)
  (with-current-buffer buf
    (shell-command-on-region (point-min) (point-max)
			     command nil t)))

(define-ibuffer-op shell-command-file (command)
  "Run shell command COMMAND separately on files of marked buffers."
  (:interactive "sShell command on buffer's file: "
   :opstring "Shell command executed on"
   :modifier-p nil)
  (shell-command (concat command " "
			 (shell-quote-argument
			  (if buffer-file-name
			      buffer-file-name
			    (make-temp-file
			     (substring (buffer-name) 0 (min 10 (length (buffer-name))))))))))
			  
(define-ibuffer-op eval (form)
  "Evaluate FORM in each of the buffers.
Does not display the buffer during evaluation. See
`ibuffer-do-view-and-eval' for that."
  (:interactive "xEval in buffers (form): "
   :opstring "evaluated in"
   :modifier-p :maybe)
  (eval form))

(define-ibuffer-op view-and-eval (form)
  "Evaluate FORM while displaying each of the marked buffers.
To evaluate a form without viewing the buffer, see `ibuffer-do-eval'."
  (:interactive "xEval viewing buffers (form): "
   :opstring "evaluated in"
   :complex t
   :modifier-p :maybe)
  (let ((ibuffer-buf (current-buffer)))
    (unwind-protect
	(progn
	  (switch-to-buffer buf)
	  (eval form))
      (switch-to-buffer ibuffer-buf))))

(define-ibuffer-op rename-uniquely ()
  "Rename marked buffers as with `rename-uniquely'."
  (:opstring "renamed"
   :modifier-p t)
  (rename-uniquely))

(define-ibuffer-op revert ()
  "Revert marked buffers as with `revert-buffer'."
  (:dangerous t
   :opstring "reverted"
   :active-opstring "revert"
   :modifier-p :maybe)
  (revert-buffer t t))

(define-ibuffer-op replace-regexp (from-str to-str)
  "Perform a `replace-regexp' in marked buffers."
  (:interactive
   (let* ((from-str (read-from-minibuffer "Replace regexp: "))
	  (to-str (read-from-minibuffer (concat "Replace " from-str
						" with: "))))
     (list from-str to-str))
   :opstring "replaced in"
   :complex t
   :modifier-p :maybe)
  (save-window-excursion
    (switch-to-buffer buf)
    (save-excursion
      (goto-char (point-min))
      (let ((case-fold-search ibuffer-case-fold-search))
	(while (re-search-forward from-str nil t)
	  (replace-match to-str))))
    t))

(define-ibuffer-op query-replace (&rest args)
  "Perform a `query-replace' in marked buffers."
  (:interactive
   (query-replace-read-args "Query replace" t)
   :opstring "replaced in"
   :complex t
   :modifier-p :maybe)
  (save-window-excursion
    (switch-to-buffer buf)
    (save-excursion
      (let ((case-fold-search ibuffer-case-fold-search))
	(goto-char (point-min))
	(apply #'query-replace args)))
    t))

(define-ibuffer-op query-replace-regexp (&rest args)
  "Perform a `query-replace-regexp' in marked buffers."
  (:interactive
   (query-replace-read-args "Query replace regexp" t)
   :opstring "replaced in"
   :complex t
   :modifier-p :maybe)
  (save-window-excursion
    (switch-to-buffer buf)
    (save-excursion
      (let ((case-fold-search ibuffer-case-fold-search))
	(goto-char (point-min))
	(apply #'query-replace-regexp args)))
    t))

(define-ibuffer-op print ()
  "Print marked buffers as with `print-buffer'."
  (:opstring "printed"
   :modifier-p nil)
  (print-buffer))

;;;###autoload
(defun ibuffer-included-in-filters-p (buf filters)
  (not
   (memq nil ;; a filter will return nil if it failed
	 (mapcar
	  ;; filter should be like (TYPE . QUALIFIER), or
	  ;; (or (TYPE . QUALIFIER) (TYPE . QUALIFIER) ...)
	  #'(lambda (qual)
	      (ibuffer-included-in-filter-p buf qual))
	  filters))))

(defun ibuffer-included-in-filter-p (buf filter)
  (if (eq (car filter) 'not)
      (not (ibuffer-included-in-filter-p-1 buf (cdr filter)))
    (ibuffer-included-in-filter-p-1 buf filter)))

(defun ibuffer-included-in-filter-p-1 (buf filter)
  (not
   (not
    (case (car filter)
      (or
       (memq t (mapcar #'(lambda (x)
			   (ibuffer-included-in-filter-p buf x))
		       (cdr filter))))
      (saved
       (let ((data
	      (assoc (cdr filter)
		     ibuffer-saved-filters)))
	 (unless data
	   (ibuffer-filter-disable)
	   (error "Unknown saved filter %s" (cdr filter)))
	 (ibuffer-included-in-filters-p buf (cadr data))))
      (t
       (let ((filterdat (assq (car filter)
			      ibuffer-filtering-alist)))
	 ;; filterdat should be like (TYPE DESCRIPTION FUNC)
	 ;; just a sanity check
	(unless filterdat
	  (ibuffer-filter-disable)
	  (error "Undefined filter %s" (car filter)))
	(not
	 (not
	  (funcall (caddr filterdat)
		   buf
		   (cdr filter))))))))))

;;;###autoload
(defun ibuffer-filter-disable ()
  "Disable all filters currently in effect in this buffer."
  (interactive)
  (setq ibuffer-filtering-qualifiers nil)
  (ibuffer-update nil t))

;;;###autoload
(defun ibuffer-pop-filter ()
  "Remove the top filter in this buffer."
  (interactive)
  (when (null ibuffer-filtering-qualifiers)
    (error "No filters in effect"))
  (pop ibuffer-filtering-qualifiers)
  (ibuffer-update nil t))

(defun ibuffer-push-filter (qualifier)
  "Add QUALIFIER to `ibuffer-filtering-qualifiers'."
  (push qualifier ibuffer-filtering-qualifiers))

;;;###autoload
(defun ibuffer-decompose-filter ()
  "Separate the top compound filter (OR, NOT, or SAVED) in this buffer.

This means that the topmost filter on the filtering stack, which must
be a complex filter like (OR [name: foo] [mode: bar-mode]), will be
turned into two separate filters [name: foo] and [mode: bar-mode]."
  (interactive)
  (when (null ibuffer-filtering-qualifiers)
    (error "No filters in effect"))  
  (let ((lim (pop ibuffer-filtering-qualifiers)))
    (case (car lim)
      (or
       (setq ibuffer-filtering-qualifiers (append
					  (cdr lim)
					  ibuffer-filtering-qualifiers)))
      (saved
       (let ((data
	      (assoc (cdr lim)
		     ibuffer-saved-filters)))
	 (unless data
	   (ibuffer-filter-disable)
	   (error "Unknown saved filter %s" (cdr lim)))
	 (setq ibuffer-filtering-qualifiers (append
					    (cadr data)
					    ibuffer-filtering-qualifiers))))
      (not
       (push (cdr lim)
	     ibuffer-filtering-qualifiers))
      (t
       (error "Filter type %s is not compound" (car lim)))))
  (ibuffer-update nil t))

;;;###autoload
(defun ibuffer-exchange-filters ()
  "Exchange the top two filters on the stack in this buffer."
  (interactive)
  (when (< (length ibuffer-filtering-qualifiers)
	   2)
    (error "Need two filters to exchange"))
  (let ((first (pop ibuffer-filtering-qualifiers))
	(second (pop ibuffer-filtering-qualifiers)))
    (push first ibuffer-filtering-qualifiers)
    (push second ibuffer-filtering-qualifiers))
  (ibuffer-update nil t))

;;;###autoload
(defun ibuffer-negate-filter ()
  "Negate the sense of the top filter in the current buffer."
  (interactive)
  (when (null ibuffer-filtering-qualifiers)
    (error "No filters in effect"))
  (let ((lim (pop ibuffer-filtering-qualifiers)))
    (push (if (eq (car lim) 'not)
	      (cdr lim)
	    (cons 'not lim))
	  ibuffer-filtering-qualifiers))
  (ibuffer-update nil t))

;;;###autoload
(defun ibuffer-or-filter (&optional reverse)
  "Replace the top two filters in this buffer with their logical OR.
If optional argument REVERSE is non-nil, instead break the top OR
filter into parts."
  (interactive "P")
  (if reverse
      (progn
	(when (or (null ibuffer-filtering-qualifiers)
		  (not (eq 'or (caar ibuffer-filtering-qualifiers))))
	  (error "Top filter is not an OR"))
	(let ((lim (pop ibuffer-filtering-qualifiers)))
	  (setq ibuffer-filtering-qualifiers (nconc (cdr lim) ibuffer-filtering-qualifiers))))
    (when (< (length ibuffer-filtering-qualifiers) 2)
      (error "Need two filters to OR"))
    ;; If the second filter is an OR, just add to it.
    (let ((first (pop ibuffer-filtering-qualifiers))
	  (second (pop ibuffer-filtering-qualifiers)))
      (if (eq 'or (car second))
	  (push (nconc (list 'or first) (cdr second)) ibuffer-filtering-qualifiers)
	(push (list 'or first second)
	      ibuffer-filtering-qualifiers))))
  (ibuffer-update nil t))

(defun ibuffer-maybe-save-saved-filters ()
  (when ibuffer-save-with-custom
    (if (fboundp 'customize-save-variable)
	(progn
	  (customize-save-variable 'ibuffer-saved-filters
				   ibuffer-saved-filters))
      (message "Not saved permanently: Customize not available"))))

;;;###autoload
(defun ibuffer-save-filters (name filters)
  "Save FILTERS in this buffer with name NAME in `ibuffer-saved-filters'.
Interactively, prompt for NAME, and use the current filters."
  (interactive
   (if (null ibuffer-filtering-qualifiers)
       (error "No filters currently in effect")
     (list
      (read-from-minibuffer "Save current filters as: ")
      ibuffer-filtering-qualifiers)))
  (ibuffer-aif (assoc name ibuffer-saved-filters)
      (setcdr it filters)
      (push (list name filters) ibuffer-saved-filters))
  (ibuffer-maybe-save-saved-filters)
  (ibuffer-update-mode-name))

;;;###autoload
(defun ibuffer-delete-saved-filters (name)
  "Delete saved filters with NAME from `ibuffer-saved-filters'."
  (interactive
   (list
    (if (null ibuffer-saved-filters)
	(error "No saved filters")
      (completing-read "Delete saved filters: "
		       ibuffer-saved-filters nil t))))
  (setq ibuffer-saved-filters
	(ibuffer-delete-alist name ibuffer-saved-filters))
  (ibuffer-maybe-save-saved-filters)
  (ibuffer-update nil t))

;;;###autoload
(defun ibuffer-add-saved-filters (name)
  "Add saved filters from `ibuffer-saved-filters' to this buffer's filters."
  (interactive
   (list
    (if (null ibuffer-saved-filters)
	(error "No saved filters")
      (completing-read "Add saved filters: "
		       ibuffer-saved-filters nil t))))
  (push (cons 'saved name) ibuffer-filtering-qualifiers)
  (ibuffer-update nil t))

;;;###autoload
(defun ibuffer-switch-to-saved-filters (name)
  "Set this buffer's filters to filters with NAME from `ibuffer-saved-filters'.
If prefix argument ADD is non-nil, then add the saved filters instead
of replacing the current filters."
  (interactive
   (list
    (if (null ibuffer-saved-filters)
	(error "No saved filters")
      (completing-read "Switch to saved filters: "
		       ibuffer-saved-filters nil t))))
  (setq ibuffer-filtering-qualifiers (list (cons 'saved name)))
  (ibuffer-update nil t))
  
(defun ibuffer-format-qualifier (qualifier)
  (if (eq (car-safe qualifier) 'not)
      (concat " [NOT" (ibuffer-format-qualifier-1 (cdr qualifier)) "]")
    (ibuffer-format-qualifier-1 qualifier)))

(defun ibuffer-format-qualifier-1 (qualifier)
  (case (car qualifier)
    (saved
     (concat " [filter: " (cdr qualifier) "]"))
    (or
     (concat " [OR" (mapconcat #'ibuffer-format-qualifier
			       (cdr qualifier) "") "]"))
    (t
     (let ((type (assq (car qualifier) ibuffer-filtering-alist)))
       (unless qualifier
	 (error "Ibuffer: bad qualifier %s" qualifier))
       (concat " [" (cadr type) ": " (format "%s]" (cdr qualifier)))))))
  
;;; Extra operation definitions

(define-ibuffer-filter mode 
  "Toggle current view to buffers with major mode QUALIFIER."
  (:description "major mode"
   :reader
   (intern
    (completing-read "Filter by major mode: " obarray
		     #'(lambda (e)
			 (string-match "-mode$"
				       (symbol-name e)))
		     t
		     (let ((buf (ibuffer-current-buffer)))
		       (if (and buf (buffer-live-p buf))
			   (with-current-buffer buf
			     (symbol-name major-mode))
			 "")))))
  (eq qualifier (with-current-buffer buf major-mode)))

(define-ibuffer-filter name 
  "Toggle current view to buffers with name matching QUALIFIER."
  (:description "buffer name"
   :reader
   (read-from-minibuffer "Filter by name (regexp): "))
  (string-match qualifier (buffer-name buf)))

(define-ibuffer-filter filename
  "Toggle current view to buffers with filename matching QUALIFIER."
  (:description "filename"
   :reader
   (read-from-minibuffer "Filter by filename (regexp): "))
  (ibuffer-awhen (buffer-file-name buf)
    (string-match qualifier it)))

(define-ibuffer-filter size-gt 
  "Toggle current view to buffers with size greater than QUALIFIER."
  (:description "size greater than"
   :reader
   (string-to-number (read-from-minibuffer "Filter by size greater than: ")))
  (> (with-current-buffer buf (buffer-size))
     qualifier))

(define-ibuffer-filter size-lt 
   "Toggle current view to buffers with size less than QUALIFIER."
  (:description "size less than"
   :reader
   (string-to-number (read-from-minibuffer "Filter by size less than: ")))
  (< (with-current-buffer buf (buffer-size))
     qualifier))
  
(define-ibuffer-filter content
   "Toggle current view to buffers whose contents match QUALIFIER."
  (:description "content"
   :reader
   (read-from-minibuffer "Filter by content (regexp): "))
  (with-current-buffer buf
    (save-excursion
      (goto-char (point-min))
      (re-search-forward qualifier nil t))))

(define-ibuffer-filter predicate
   "Toggle current view to buffers for which QUALIFIER returns non-nil."
  (:description "predicate"
   :reader
   (read-minibuffer "Filter by predicate (form): "))
  (with-current-buffer buf
    (eval qualifier)))

;;; Sorting

;;;###autoload
(defun ibuffer-toggle-sorting-mode ()
  "Toggle the current sorting mode.
Default sorting modes are:
 Recency - the last time the buffer was viewed
 Name - the name of the buffer
 Major Mode - the name of the major mode of the buffer
 Size - the size of the buffer"
  (interactive)
  (let ((modes (mapcar 'car ibuffer-sorting-functions-alist)))
    (add-to-list 'modes 'recency)
    (setq modes (sort modes 'string-lessp))
    (let ((next (or (find-if 
                     (lambda (x) (string-lessp ibuffer-sorting-mode x)) modes)
                    (car modes))))
      (setq ibuffer-sorting-mode next)
      (message "Sorting by %s" next)))
  (ibuffer-redisplay t))

;;;###autoload
(defun ibuffer-invert-sorting ()
  "Toggle whether or not sorting is in reverse order."
  (interactive)
  (setq ibuffer-sorting-reversep (not ibuffer-sorting-reversep))
  (message "Sorting order %s"
	   (if ibuffer-sorting-reversep
	       "reversed"
	     "normal"))
  (ibuffer-redisplay t))

(define-ibuffer-sorter major-mode
  "Sort the buffers by major modes.
Ordering is lexicographic."
  (:description "major mode")
  (string-lessp (downcase
		 (symbol-name (with-current-buffer
				  (car a)
				major-mode)))
		(downcase
		 (symbol-name (with-current-buffer
				  (car b)
				major-mode)))))

(define-ibuffer-sorter alphabetic
  "Sort the buffers by their names.
Ordering is lexicographic."
  (:description "buffer name")
  (string-lessp
   (buffer-name (car a))
   (buffer-name (car b))))

(define-ibuffer-sorter size
 "Sort the buffers by their size."
  (:description "size")
  (< (with-current-buffer (car a)
       (buffer-size))
     (with-current-buffer (car b)
       (buffer-size))))

;;; Functions to emulate bs.el

;;;###autoload
(defun ibuffer-bs-show ()
  "Emulate `bs-show' from the bs.el package."
  (interactive)
  (ibuffer t "*Ibuffer-bs*" '((filename . ".*")) nil t)
  (define-key (current-local-map) "a" 'ibuffer-bs-toggle-all))

(defun ibuffer-bs-toggle-all ()
  "Emulate `bs-toggle-show-all' from the bs.el package."
  (interactive)
  (if ibuffer-filtering-qualifiers
      (ibuffer-pop-filter)
    (progn (ibuffer-push-filter '(filename . ".*"))
	   (ibuffer-update nil t))))

;;; Handy functions

;;;###autoload
(defun ibuffer-add-to-tmp-hide (regexp)
  "Add REGEXP to `ibuffer-tmp-hide-regexps'.
This means that buffers whose name matches REGEXP will not be shown
for this ibuffer session."
  (interactive
   (list
    (read-from-minibuffer "Never show buffers matching: "
			  (regexp-quote (buffer-name (ibuffer-current-buffer t))))))
  (push regexp ibuffer-tmp-hide-regexps))

;;;###autoload
(defun ibuffer-add-to-tmp-show (regexp)
  "Add REGEXP to `ibuffer-tmp-show-regexps'.
This means that buffers whose name matches REGEXP will always be shown
for this ibuffer session."
  (interactive
   (list
    (read-from-minibuffer "Always show buffers matching: "
			  (regexp-quote (buffer-name (ibuffer-current-buffer t))))))
  (push regexp ibuffer-tmp-show-regexps))

;;;###autoload
(defun ibuffer-forward-next-marked (&optional count mark direction)
  "Move forward by COUNT marked buffers (default 1).

If MARK is non-nil, it should be a character denoting the type of mark
to move by.  The default is `ibuffer-marked-char'.

If DIRECTION is non-nil, it should be an integer; negative integers
mean move backwards, non-negative integers mean move forwards."
  (interactive "P")
  (unless count
    (setq count 1))
  (unless mark
    (setq mark ibuffer-marked-char))
  (unless direction
    (setq direction 1))
  ;; Skip the title
  (ibuffer-forward-line 0)
  (let ((opos (point))
	curmark)
    (ibuffer-forward-line direction)
    (while (not (or (= (point) opos)
		    (eq (setq curmark (ibuffer-current-mark))
			mark)))
      (ibuffer-forward-line direction))
    (when (and (= (point) opos)
	       (not (eq (ibuffer-current-mark) mark)))
      (error "No buffers with mark %c" mark))))

;;;###autoload
(defun ibuffer-backwards-next-marked (&optional count mark)
   "Move backwards by COUNT marked buffers (default 1).

If MARK is non-nil, it should be a character denoting the type of mark
to move by.  The default is `ibuffer-marked-char'."
   (interactive "P")
   (ibuffer-forward-next-marked count mark -1))

;;;###autoload
(defun ibuffer-do-kill-lines ()
  "Hide all of the currently marked lines."
  (interactive)
  (if (= (ibuffer-count-marked-lines) 0)
      (message "No buffers marked; use 'm' to mark a buffer")
    (let ((count
	   (ibuffer-map-marked-lines
	    #'(lambda (buf mark beg end)
		'kill))))
      (message "Killed %s lines" count))))

;;;###autoload
(defun ibuffer-jump-to-buffer (name)
  "Move point to the buffer whose name is NAME."
  (interactive (list nil))
  (let ((table (mapcar #'(lambda (x)
			   (cons (buffer-name (car x))
				 (caddr x)))
		       (ibuffer-current-state-list t))))
    (when (null table)
      (error "No buffers!"))
    (when (interactive-p)
      (setq name (completing-read "Jump to buffer: " table nil t)))
    (ibuffer-aif (assoc name table)
	(goto-char (cdr it))
      (error "No buffer with name %s" name))))

;;;###autoload
(defun ibuffer-diff-with-file ()
  "View the differences between this buffer and its associated file.
This requires the external program \"diff\" to be in your `exec-path'."
  (interactive)
  (let* ((buf (ibuffer-current-buffer))
	 (buf-filename (with-current-buffer buf
			 buffer-file-name)))
    (unless (buffer-live-p buf)
      (error "Buffer %s has been killed" buf))
    (unless buf-filename
      (error "Buffer %s has no associated file" buf))
    (let ((diff-buf (get-buffer-create "*Ibuffer-diff*")))
      (with-current-buffer diff-buf
	(setq buffer-read-only nil)
	(erase-buffer))
      (let ((tempfile (make-temp-file "ibuffer-diff-")))
	(unwind-protect
	    (progn
	      (with-current-buffer buf
		(write-region (point-min) (point-max) tempfile nil 'nomessage))
	      (if (zerop
		   (apply #'call-process "diff" nil diff-buf nil
			  (append
			   (when (and (boundp 'ediff-custom-diff-options)
				      (stringp ediff-custom-diff-options))
			     (list ediff-custom-diff-options))
			   (list buf-filename tempfile))))
		  (message "No differences found")
		(progn
		  (with-current-buffer diff-buf
		    (goto-char (point-min))
		    (if (fboundp 'diff-mode)
			(diff-mode)
		      (fundamental-mode)))
		  (display-buffer diff-buf))))
	  (when (file-exists-p tempfile)
	    (delete-file tempfile)))))
      nil))

;;;###autoload
(defun ibuffer-copy-filename-as-kill (&optional arg)
  "Copy filenames of marked buffers into the kill ring.
The names are separated by a space.
If a buffer has no filename, it is ignored.
With a zero prefix arg, use the complete pathname of each marked file.

You can then feed the file name(s) to other commands with C-y.

 [ This docstring shamelessly stolen from the
 `dired-copy-filename-as-kill' in \"dired-x\". ]"
  ;; Add to docstring later:
  ;; With C-u, use the relative pathname of each marked file.
  (interactive "P")
  (if (= (ibuffer-count-marked-lines) 0)
      (message "No buffers marked; use 'm' to mark a buffer")
    (let ((ibuffer-copy-filename-as-kill-result "")
	  (type (cond ((eql arg 0)
		       'full)
		      ;; ((eql arg 4)
		      ;;  'relative)
		      (t
		       'name))))
      (ibuffer-map-marked-lines
       #'(lambda (buf mark beg end)
	   (setq ibuffer-copy-filename-as-kill-result
		 (concat ibuffer-copy-filename-as-kill-result
			 (let ((name (buffer-file-name buf)))
			   (if name
			       (case type
				 (full
				  name)
				 (t
				  (file-name-nondirectory name)))
			     ""))
			 " "))))
      (push ibuffer-copy-filename-as-kill-result kill-ring))))

(defun ibuffer-mark-on-buffer (func)
  (let ((count
	 (ibuffer-map-lines
	  #'(lambda (buf mark beg end)
	      (when (funcall func buf)
		(ibuffer-set-mark-1 ibuffer-marked-char)
		t)))))
    (ibuffer-redisplay t)
    (message "Marked %s buffers" count)))

;;;###autoload
(defun ibuffer-mark-by-name-regexp (regexp)
  "Mark all buffers whose name matches REGEXP."
  (interactive "sMark by name (regexp): ")
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (string-match regexp (buffer-name buf)))))

;;;###autoload
(defun ibuffer-mark-by-mode-regexp (regexp)
  "Mark all buffers whose major mode matches REGEXP."
  (interactive "sMark by major mode (regexp): ")
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (with-current-buffer buf
	 (string-match regexp mode-name)))))

;;;###autoload
(defun ibuffer-mark-by-file-name-regexp (regexp)
  "Mark all buffers whose file name matches REGEXP."
  (interactive "sMark by file name (regexp): ")
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (let ((name (or (buffer-file-name buf)
		       (with-current-buffer buf
			 (and
			  (boundp 'dired-directory)
			  (stringp dired-directory)
			  dired-directory)))))
	 (when name
	   (string-match regexp name))))))

;;;###autoload
(defun ibuffer-mark-by-mode (mode)
  "Mark all buffers whose major mode equals MODE."
  (interactive
   (list (intern (completing-read "Mark by major mode: " obarray
				  #'(lambda (e)
				      ;; kind of a hack...
                                      (and (fboundp e)
                                           (string-match "-mode$"
                                                         (symbol-name e))))
				  t
				  (let ((buf (ibuffer-current-buffer)))
				    (if (and buf (buffer-live-p buf))
					(with-current-buffer buf
					  (cons (symbol-name major-mode)
						0))
				      ""))))))
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (with-current-buffer buf
	 (eq major-mode mode)))))

;;;###autoload
(defun ibuffer-mark-modified-buffers ()
  "Mark all modified buffers."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf) (buffer-modified-p buf))))

;;;###autoload
(defun ibuffer-mark-unsaved-buffers ()
  "Mark all modified buffers that have an associated file."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf) (and (with-current-buffer buf buffer-file-name)
			(buffer-modified-p buf)))))

;;;###autoload
(defun ibuffer-mark-dissociated-buffers ()
  "Mark all buffers whose associated file does not exist."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (with-current-buffer buf
	 (or
	  (and buffer-file-name
	       (not (file-exists-p buffer-file-name)))
	  (and (eq major-mode 'dired-mode)
	       (boundp 'dired-directory)
	       (stringp dired-directory)
	       (not (file-exists-p (file-name-directory dired-directory)))))))))

;;;###autoload
(defun ibuffer-mark-help-buffers ()
  "Mark buffers like *Help*, *Apropos*, *Info*."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (with-current-buffer buf
	 (or
	  (eq major-mode 'apropos-mode)
	  (eq major-mode 'help-mode)
	  (eq major-mode 'info-mode))))))

;;;###autoload
(defun ibuffer-mark-old-buffers ()
  "Mark buffers which have not been viewed in `ibuffer-old-time' days."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (with-current-buffer buf
	 ;; hacked from midnight.el
	 (when buffer-display-time
	   (let* ((tm (current-time))
		  (now (+ (* (float (ash 1 16)) (car tm))
			  (float (cadr tm)) (* 0.0000001 (caddr tm))))
		  (then (+ (* (float (ash 1 16))
			      (car buffer-display-time))
			   (float (cadr buffer-display-time))
			   (* 0.0000001 (caddr buffer-display-time)))))
	     (> (- now then) (* 24 60 60 ibuffer-old-time))))))))

;;;###autoload
(defun ibuffer-mark-special-buffers ()
  "Mark all buffers whose name begins and ends with '*'."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf) (string-match "^\\*.+\\*$"
				 (buffer-name buf)))))

;;;###autoload
(defun ibuffer-mark-read-only-buffers ()
  "Mark all read-only buffers."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (with-current-buffer buf
	 buffer-read-only))))

;;;###autoload
(defun ibuffer-mark-dired-buffers ()
  "Mark all `dired' buffers."
  (interactive)
  (ibuffer-mark-on-buffer
   #'(lambda (buf)
       (with-current-buffer buf
	 (eq major-mode 'dired-mode)))))

;;; An implementation of multi-buffer `occur'

(defvar ibuffer-occur-props nil)

(define-derived-mode ibuffer-occur-mode occur-mode "Ibuffer-Occur"
  "A special form of Occur mode for multiple buffers.
Note this major mode is not meant for interactive use!
See also `occur-mode'."
  (define-key ibuffer-occur-mode-map (kbd "n") 'forward-line)
  (define-key ibuffer-occur-mode-map (kbd "q") 'bury-buffer)
  (define-key ibuffer-occur-mode-map (kbd "p") 'previous-line)
  (define-key ibuffer-occur-mode-map (kbd "RET") 'ibuffer-occur-display-occurence)
  (define-key ibuffer-occur-mode-map (kbd "f") 'ibuffer-occur-goto-occurence)
  (define-key ibuffer-occur-mode-map [(mouse-2)] 'ibuffer-occur-mouse-display-occurence)
  (set (make-local-variable 'revert-buffer-function)
       #'ibuffer-occur-revert-buffer-function)
  (set (make-local-variable 'ibuffer-occur-props) nil)
  (setq buffer-read-only nil)
  (erase-buffer)
  (setq buffer-read-only t)
  (message (concat
	    "Use RET "
	    (if (or (and (< 21 emacs-major-version)
			 window-system)
		    (featurep 'mouse))
	       "or mouse-2 ")
	    "to display an occurence.")))

(defun ibuffer-occur-mouse-display-occurence (e)
  "Display occurence on this line in another window."
  (interactive "e")
  (let* ((occurbuf (save-window-excursion (mouse-select-window e)
					  (selected-window)))
	 (target (with-current-buffer occurbuf
		   (get-text-property (save-excursion
					(mouse-set-point e)
					(point))
				      'ibuffer-occur-target))))
    (unless target
      (error "No occurence on this line"))
    (let ((buf (car target))
	  (line (cdr target)))
      (switch-to-buffer occurbuf)
      (delete-other-windows)
      (pop-to-buffer buf)
      (goto-line line))))

(defun ibuffer-occur-goto-occurence ()
  "Switch to the buffer which has the occurence on this line."
  (interactive)
  (ibuffer-occur-display-occurence t))

(defun ibuffer-occur-display-occurence (&optional goto)
  "Display occurence on this line in another window."
  (interactive "P")
  (let ((target (get-text-property (point) 'ibuffer-occur-target)))
    (unless target
      (error "No occurence on this line"))
    (let ((buf (car target))
	  (line (cdr target)))
      (delete-other-windows)
      (if goto
	  (switch-to-buffer buf)
	(pop-to-buffer buf))
      (goto-line line))))

;;;###autoload
(defun ibuffer-do-occur (regexp &optional nlines)
  "View lines which match REGEXP in all marked buffers.
Optional argument NLINES says how many lines of context to display: it
defaults to one."
  (interactive
   (list (let* ((default (car regexp-history))
		(input
		 (read-from-minibuffer
		  (if default
		      (format "List lines matching regexp (default `%s'): "
			      default)
		    "List lines matching regexp: ")
		  nil
		  nil
		  nil
		  'regexp-history)))
	   (if (equal input "")
	       default
	     input))
	 current-prefix-arg))
  (if (or (not (integerp nlines))
	  (< nlines 0))
      (setq nlines 1))
  (when (zerop (ibuffer-count-marked-lines))
    (ibuffer-set-mark 'ibuffer-marked-char))
  (let ((ibuffer-do-occur-bufs nil))
    ;; Accumulate a list of marked buffers
    (ibuffer-map-marked-lines
     #'(lambda (buf mark beg end)
	 (push buf ibuffer-do-occur-bufs)))
    (ibuffer-do-occur-1 regexp ibuffer-do-occur-bufs
			(get-buffer-create "*Ibuffer-occur*")
			nlines)))

(defun ibuffer-do-occur-1 (regexp buffers out-buf nlines)
  (let ((count (ibuffer-occur-engine regexp buffers out-buf nlines)))
    (if (> count 0)
	(progn
	  (switch-to-buffer out-buf)
	  (setq buffer-read-only t)
	  (delete-other-windows)
	  (goto-char (point-min))
	  (message "Found %s matches in %s buffers" count (length buffers)))
      (message "No matches found"))))


(defun ibuffer-occur-revert-buffer-function (ignore-auto noconfirm)
  "Update the *Ibuffer occur* buffer."
  (assert (eq major-mode 'ibuffer-occur-mode))
  (ibuffer-do-occur-1 (car ibuffer-occur-props)
		      (cadr ibuffer-occur-props)
		      (current-buffer)
		      (caddr ibuffer-occur-props)))

(defun ibuffer-occur-engine (regexp buffers out-buf nlines)
  (macrolet ((insert-get-point
	      (&rest args)
	      `(progn
		 (insert ,@args)
		 (point)))
	     (maybe-put-overlay
	      (over prop value)
	      `(when (ibuffer-use-fontification)
		 (overlay-put ,over ,prop ,value)))
	     (maybe-ibuffer-propertize
	      (obj &rest args)
	      (let ((objsym (gensym "--maybe-ibuffer-propertize-")))
		`(let ((,objsym ,obj))
		   (if (ibuffer-use-fontification)
		       (propertize ,objsym ,@args)
		     ,objsym)))))
    (with-current-buffer out-buf
      (ibuffer-occur-mode)
      (setq buffer-read-only nil)
      (let ((globalcount 0))
	;; Map over all the buffers
	(dolist (buf buffers)
	  (when (buffer-live-p buf)
	    (let ((c 0)	;; count of matched lines
		  (l 1)	;; line count
		  (headerpt (with-current-buffer out-buf (point))))
	      (save-excursion
		(set-buffer buf)
		(save-excursion
		  (goto-char (point-min)) ;; begin searching in the buffer
		  (while (not (eobp))
		    ;; The line we're matching against
		    (let ((curline (buffer-substring
				    (line-beginning-position)
				    (line-end-position))))
		      (when (string-match regexp curline)
			(incf c) ;; increment match count
			(incf globalcount)
			;; Depropertize the string, and maybe highlight the matches
			(setq curline
			      (progn
				(ibuffer-depropertize-string curline t)
				(when (ibuffer-use-fontification)
				  (let ((len (length curline))
					(start 0))
				    (while (and (< start len)
						(string-match regexp curline start))
				      (put-text-property (match-beginning 0)
							 (match-end 0)
							 'face ibuffer-occur-match-face
							 curline)
				      (setq start (match-end 0)))))
				curline))
			;; Generate the string to insert for this match
			(let ((data
			       (if (= nlines 1)
				   ;; The simple display style
				   (concat (maybe-ibuffer-propertize
					    (format "%-6d:" l)
					    'face 'bold)
					   curline
					   "\n")
				 ;; The complex multi-line display style
				 (let ((prevlines (nreverse
						   (ibuffer-accumulate-lines (- nlines))))
				       (nextlines (ibuffer-accumulate-lines nlines))
				       ;; The lack of `flet' seriously sucks.
				       (fun #'(lambda (lines)
						(mapcar
						 #'(lambda (line)
						     (concat "      :" line "\n"))
						 lines))))
				   (setq prevlines (funcall fun prevlines))
				   (setq nextlines (funcall fun nextlines))
				   ;; Yes, I am trying to win the award for the
				   ;; most consing.
				   (apply #'concat
					  (nconc
					   prevlines
					   (list
					    (concat
					     (maybe-ibuffer-propertize
					      (format "%-6d" l)
					      'face 'bold)
					     ":"
					     curline
					     "\n"))
					   nextlines))))))
			  ;; Actually insert the match display data
			  (with-current-buffer out-buf
			    (let ((beg (point))
				  (end (insert-get-point
					data)))
			      (unless (= nlines 1)
				(insert "-------\n"))
			      (put-text-property
			       beg (1- end) 'ibuffer-occur-target (cons buf l))
			      (put-text-property
			       beg (1- end) 'mouse-face 'highlight))))))
		    ;; On to the next line...
		    (incf l)
		    (forward-line 1))))
	      (when (not (zerop c)) ;; is the count zero?
		(with-current-buffer out-buf
		  (goto-char headerpt)
		  (let ((beg (point))
			(end (insert-get-point
			      (format "%d lines matching \"%s\" in buffer %s\n"
				      c regexp (buffer-name buf)))))
		    (let ((o (make-overlay beg end)))
		      (maybe-put-overlay o 'face 'underline)))
		  (goto-char (point-max)))))))
	(setq ibuffer-occur-props (list regexp buffers nlines))
	;; Return the number of matches
	globalcount))))

(provide 'ibuf-ext)

;;; ibuf-ext.el ends here
