;;; env.el --- functions to manipulate environment variables

;; Copyright (C) 1991, 1994, 2000, 2001, 2002, 2003, 2004,
;;   2005 Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: processes, unix

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
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; UNIX processes inherit a list of name-to-string associations from their
;; parents called their `environment'; these are commonly used to control
;; program options.  This package permits you to set environment variables
;; to be passed to any sub-process run under Emacs.

;; Note that the environment string `process-environment' is not
;; decoded, but the args of `setenv' and `getenv' are normally
;; multibyte text and get coding conversion.

;;; Code:

(eval-when-compile (require 'cl))

;; History list for environment variable names.
(defvar read-envvar-name-history nil)

(defun read-envvar-name (prompt &optional mustmatch)
  "Read environment variable name, prompting with PROMPT.
Optional second arg MUSTMATCH, if non-nil, means require existing envvar name.
If it is also not t, RET does not exit if it does non-null completion."
  (completing-read prompt
		   (mapcar (lambda (enventry)
			     (list (if enable-multibyte-characters
				       (decode-coding-string
					(substring enventry 0
						   (string-match "=" enventry))
					locale-coding-system t)
				     (substring enventry 0
						(string-match "=" enventry)))))
			   (append process-environment
				   (terminal-parameter nil 'environment)
				   global-environment))
		   nil mustmatch nil 'read-envvar-name-history))

;; History list for VALUE argument to setenv.
(defvar setenv-history nil)


(defun substitute-env-vars (string)
  "Substitute environment variables referred to in STRING.
`$FOO' where FOO is an environment variable name means to substitute
the value of that variable.  The variable name should be terminated
with a character not a letter, digit or underscore; otherwise, enclose
the entire variable name in braces.  For instance, in `ab$cd-x',
`$cd' is treated as an environment variable.

Use `$$' to insert a single dollar sign."
  (let ((start 0))
    (while (string-match
	    (eval-when-compile
	      (rx (or (and "$" (submatch (1+ (regexp "[[:alnum:]_]"))))
		      (and "${" (submatch (minimal-match (0+ anything))) "}")
		      "$$")))
	    string start)
      (cond ((match-beginning 1)
	     (let ((value (getenv (match-string 1 string))))
	       (setq string (replace-match (or value "") t t string)
		     start (+ (match-beginning 0) (length value)))))
	    ((match-beginning 2)
	     (let ((value (getenv (match-string 2 string))))
	       (setq string (replace-match (or value "") t t string)
		     start (+ (match-beginning 0) (length value)))))
	    (t
	     (setq string (replace-match "$" t t string)
		   start (+ (match-beginning 0) 1)))))
    string))

;; Fixme: Should the environment be recoded if LC_CTYPE &c is set?

(defun setenv (variable &optional value unset substitute-env-vars terminal)
  "Set the value of the environment variable named VARIABLE to VALUE.
VARIABLE should be a string.  VALUE is optional; if not provided or
nil, the environment variable VARIABLE will be removed.  UNSET
if non-nil means to remove VARIABLE from the environment.
SUBSTITUTE-ENV-VARS, if non-nil, means to substitute environment
variables in VALUE with `substitute-env-vars', where see.
Value is the new value if VARIABLE, or nil if removed from the
environment.

Interactively, a prefix argument means to unset the variable.
Interactively, the current value (if any) of the variable
appears at the front of the history list when you type in the new value.
Interactively, always replace environment variables in the new value.

If VARIABLE is set in `process-environment', then this function
modifies its value there.  Otherwise, this function works by
modifying either `global-environment' or the environment
belonging to the terminal device of the selected frame, depending
on the value of `local-environment-variables'.

If optional parameter TERMINAL is non-nil, then it should be a
terminal id or a frame.  If the specified terminal device has its own
set of environment variables, this function will modify VAR in it.

As a special case, setting variable `TZ' calls `set-time-zone-rule' as
a side-effect."
  (interactive
   (if current-prefix-arg
       (list (read-envvar-name "Clear environment variable: " 'exact) nil t)
     (let* ((var (read-envvar-name "Set environment variable: " nil))
	    (value (getenv var)))
       (when value
	 (push value setenv-history))
       ;; Here finally we specify the args to give call setenv with.
       (list var
	     (read-from-minibuffer (format "Set %s to value: " var)
				   nil nil nil 'setenv-history
				   value)
	     nil
	     t))))
  (if (and (multibyte-string-p variable) locale-coding-system)
      (let ((codings (find-coding-systems-string (concat variable value))))
	(unless (or (eq 'undecided (car codings))
		    (memq (coding-system-base locale-coding-system) codings))
	  (error "Can't encode `%s=%s' with `locale-coding-system'"
		 variable (or value "")))))
  (if unset
      (setq value nil)
    (if substitute-env-vars
	(setq value (substitute-env-vars value))))
  (if (multibyte-string-p variable)
      (setq variable (encode-coding-string variable locale-coding-system)))
  (if (and value (multibyte-string-p value))
      (setq value (encode-coding-string value locale-coding-system)))
  (if (string-match "=" variable)
      (error "Environment variable name `%s' contains `='" variable))
  (let ((pattern (concat "\\`" (regexp-quote variable) "\\(=\\|\\'\\)"))
	(case-fold-search nil)
	(terminal-env (terminal-parameter terminal 'environment))
	(scan process-environment)
	found)
    (if (string-equal "TZ" variable)
	(set-time-zone-rule value))
    (block nil
      ;; Look for an existing entry for VARIABLE; try `process-environment' first.
      (while (and scan (stringp (car scan)))
	(when (string-match pattern (car scan))
	  (if value
	      (setcar scan (concat variable "=" value))
	    ;; Leave unset variables in `process-environment',
	    ;; otherwise the overridden value in `global-environment'
	    ;; or terminal-env would become unmasked.
	    (setcar scan variable))
	  (return value))
	(setq scan (cdr scan)))

      ;; Look in the local or global environment, whichever is relevant.
      (let ((local-var-p (and terminal-env
			      (or terminal
				  (eq t local-environment-variables)
				  (member variable local-environment-variables)))))
	(setq scan (if local-var-p
		       terminal-env
		     global-environment))
	(while scan
	  (when (string-match pattern (car scan))
	    (if value
		(setcar scan (concat variable "=" value))
	      (if local-var-p
		  (set-terminal-parameter terminal 'environment
					  (delq (car scan) terminal-env))
		(setq global-environment (delq (car scan) global-environment)))
	      (return value)))
	  (setq scan (cdr scan)))

	;; VARIABLE is not in any environment list.
	(if value
	    (if local-var-p
		(set-terminal-parameter nil 'environment
					(cons (concat variable "=" value)
					      terminal-env))
	      (setq global-environment
		    (cons (concat variable "=" value)
			  global-environment))))
	(return value)))))

(defun getenv (variable &optional terminal)
  "Get the value of environment variable VARIABLE.
VARIABLE should be a string.  Value is nil if VARIABLE is undefined in
the environment.  Otherwise, value is a string.

If optional parameter TERMINAL is non-nil, then it should be a
terminal id or a frame.  If the specified terminal device has its own
set of environment variables, this function will look up VARIABLE in
it.

Otherwise, this function searches `process-environment' for VARIABLE.
If it was not found there, then it continues the search in either
`global-environment' or the local environment list of the current
terminal device, depending on the value of
`local-environment-variables'."
  (interactive (list (read-envvar-name "Get environment variable: " t)))
  (let ((value (getenv-internal (if (multibyte-string-p variable)
				    (encode-coding-string
				     variable locale-coding-system)
				  variable))))
    (if (and enable-multibyte-characters value)
	(setq value (decode-coding-string value locale-coding-system)))
    (when (interactive-p)
      (message "%s" (if value value "Not set")))
    value))

(defun environment ()
  "Return a list of environment variables with their values.
Each entry in the list is a string of the form NAME=VALUE.

The returned list can not be used to change environment
variables, only read them.  See `setenv' to do that.

The list is constructed from elements of `process-environment',
`global-environment' and the local environment list of the
current terminal, as specified by `local-environment-variables'.

Non-ASCII characters are encoded according to the initial value of
`locale-coding-system', i.e. the elements must normally be decoded for use.
See `setenv' and `getenv'."
  (let ((env (cond ((or (not local-environment-variables)
			(not (terminal-parameter nil 'environment)))
		    (append process-environment global-environment nil))
		   ((consp local-environment-variables)
		    (let ((e (reverse process-environment)))
		      (dolist (entry local-environment-variables)
			(setq e (cons (getenv entry) e)))
		      (append (nreverse e) global-environment nil)))
		   (t
		    (append process-environment (terminal-parameter nil 'environment) nil))))
	scan seen)
    ;; Find the first valid entry in env.
    (while (and env (stringp (car env))
		(or (not (string-match "=" (car env)))
		    (member (substring (car env) 0 (string-match "=" (car env))) seen)))
      (setq seen (cons (car env) seen)
	    env (cdr env)))
    (setq scan env)
    (while (and (cdr scan) (stringp (cadr scan)))
      (let* ((match (string-match "=" (cadr scan)))
	     (name (substring (cadr scan) 0 match)))
	(cond ((not match)
	       ;; Unset variable.
	       (setq seen (cons name seen))
	       (setcdr scan (cddr scan)))
	      ((member name seen)
	       ;; Duplicate variable.
	       (setcdr scan (cddr scan)))
	      (t
	       ;; New variable.
	       (setq seen (cons name seen)
		     scan (cdr scan))))))
    env))

(defmacro let-environment (varlist &rest body)
  "Evaluate BODY with environment variables set according to VARLIST.
The environment variables are then restored to their previous
values.
The value of the last form in BODY is returned.

Each element of VARLIST is either a string (which variable is
then removed from the environment), or a list (NAME
VALUEFORM) (which sets NAME to the value of VALUEFORM, a string).
All the VALUEFORMs are evaluated before any variables are set."
  (declare (indent 2))
  (let ((old-env (make-symbol "old-env"))
	(name (make-symbol "name"))
	(value (make-symbol "value"))
	(entry (make-symbol "entry"))
	(frame (make-symbol "frame")))
    `(let ((,frame (selected-frame))
	    ,old-env)
       ;; Evaluate VALUEFORMs and replace them in VARLIST with their values.
       (dolist (,entry ,varlist)
	 (unless (stringp ,entry)
	   (if (cdr (cdr ,entry))
	       (error "`let-environment' bindings can have only one value-form"))
	   (setcdr ,entry (eval (cadr ,entry)))))
       ;; Set the variables.
       (dolist (,entry ,varlist)
	 (let ((,name (if (stringp ,entry) ,entry (car ,entry)))
	       (,value (if (consp ,entry) (cdr ,entry))))
	   (setq ,old-env (cons (cons ,name (getenv ,name)) ,old-env))
	   (setenv ,name ,value)))
       (unwind-protect
	   (progn ,@body)
	 ;; Restore old values.
	 (with-selected-frame (if (frame-live-p ,frame)
				  ,frame
				(selected-frame))
	   (dolist (,entry ,old-env)
	     (setenv (car ,entry) (cdr ,entry))))))))

(provide 'env)

;;; arch-tag: b7d6a8f7-bc81-46db-8e39-8d721d4ed0b8
;;; env.el ends here
