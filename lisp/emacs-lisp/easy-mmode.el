;;; easy-mmode.el --- easy definition for major and minor modes.

;; Copyright (C) 1997,2000  Free Software Foundation, Inc.

;; Author:  Georges Brun-Cottan <Georges.Brun-Cottan@inria.fr>
;; Maintainer:  Stefan Monnier <monnier@gnu.org>

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
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Minor modes are useful and common.  This package makes defining a
;; minor mode easy, by focusing on the writing of the minor mode
;; functionalities themselves.  Moreover, this package enforces a
;; conventional naming of user interface primitives, making things
;; natural for the minor-mode end-users.

;; For each mode, easy-mmode defines the following:
;; <mode>      : The minor mode predicate. A buffer-local variable.
;; <mode>-map  : The keymap possibly associated to <mode>.
;; <mode>-hook : The hook run at the end of the toggle function.
;;       see `define-minor-mode' documentation
;;
;; eval
;;  (pp (macroexpand '(define-minor-mode <your-mode> <doc>)))
;; to check the result before using it.

;; The order in which minor modes are installed is important.  Keymap
;; lookup proceeds down minor-mode-map-alist, and the order there
;; tends to be the reverse of the order in which the modes were
;; installed.  Perhaps there should be a feature to let you specify
;; orderings.

;; Additionally to `define-minor-mode', the package provides convenient
;; ways to define keymaps, and other helper functions for major and minor modes.

;;; Code:

(eval-when-compile (require 'cl))

(defun easy-mmode-pretty-mode-name (mode &optional lighter)
  "Turn the symbol MODE into a string intended for the user.
If provided LIGHTER will be used to help choose capitalization."
  (let* ((case-fold-search t)
	 (name (concat (replace-regexp-in-string
			"-Minor" " minor"
			(capitalize (replace-regexp-in-string
				     "-mode\\'" "" (symbol-name mode))))
		       " mode")))
    (if (not (stringp lighter)) name
      (setq lighter (replace-regexp-in-string "\\`\\s-+\\|\\-s+\\'" "" lighter))
      (replace-regexp-in-string lighter lighter name t t))))

;;;###autoload
(defalias 'easy-mmode-define-minor-mode 'define-minor-mode)
;;;###autoload
(defmacro define-minor-mode (mode doc &optional init-value lighter keymap &rest body)
  "Define a new minor mode MODE.
This function defines the associated control variable MODE, keymap MODE-map,
toggle command MODE, and hook MODE-hook.

DOC is the documentation for the mode toggle command.
Optional INIT-VALUE is the initial value of the mode's variable.
Optional LIGHTER is displayed in the modeline when the mode is on.
Optional KEYMAP is the default (defvar) keymap bound to the mode keymap.
  If it is a list, it is passed to `easy-mmode-define-keymap'
  in order to build a valid keymap.
BODY contains code that will be executed each time the mode is (dis)activated.
  It will be executed after any toggling but before running the hooks.
  BODY can start with a list of CL-style keys specifying additional arguments.
  Currently three such keyword arguments are supported:
    :group, followed by the group name to use for any generated `defcustom'.
    :global, followed by a value, which --
      If `t' specifies that the minor mode is not meant to be
	buffer-local (by default, the variable is made buffer-local).
      If non-nil, but not `t' (for instance, `:global optionally'), then
	specifies that the minor mode should be buffer-local, but that a
	corresponding `global-MODE' function should also be added, which can
	be used to turn on MODE in every buffer.
    :conditional-turn-on, followed by a function-name which turns on MODE
	only when applicable to the current buffer.  This is used in
	conjunction with any `global-MODE' function (see :global above) when
	turning on the buffer-local minor mode.  By default, any generated
	`global-MODE' function unconditionally turns on the minor mode in
	every new buffer."
  (let* ((mode-name (symbol-name mode))
	 (pretty-name (easy-mmode-pretty-mode-name mode lighter))
	 (globalp nil)
	 (define-global-mode-p nil)
	 (conditional-turn-on nil)
	 ;; We might as well provide a best-guess default group.
	 (group
	  (list 'quote
		(intern (replace-regexp-in-string "-mode\\'" "" mode-name))))
	 (keymap-sym (if (and keymap (symbolp keymap)) keymap
		       (intern (concat mode-name "-map"))))
	 (hook (intern (concat mode-name "-hook")))
	 (hook-on (intern (concat mode-name "-on-hook")))
	 (hook-off (intern (concat mode-name "-off-hook"))))

    ;; FIXME: compatibility that should be removed.
    (when (and (consp init-value) (eq (car init-value) 'global))
      (setq init-value (cdr init-value) globalp t))

    ;; Check keys.
    (while (keywordp (car body))
      (case (pop body)
	(:global (setq globalp (pop body)))
	(:group (setq group (pop body)))
	(:conditional-turn-on (setq conditional-turn-on (pop body)))
	(t (setq body (cdr body)))))

    (when (and globalp (not (eq globalp t)))
      (setq globalp nil)
      (setq define-global-mode-p t))

    ;; Add default properties to LIGHTER.
    (unless (or (not (stringp lighter)) (get-text-property 0 'local-map lighter)
		(get-text-property 0 'keymap lighter))
      (setq lighter
	    (apply 'propertize lighter
		   'local-map (make-mode-line-mouse2-map mode)
		   (unless (get-text-property 0 'help-echo lighter)
		     (list 'help-echo
			   (format "mouse-2: turn off %s" pretty-name))))))

    `(progn
       ;; Define the variable to enable or disable the mode.
       ,(if (not globalp)
	    `(progn
	       (defvar ,mode ,init-value ,(format "Non-nil if %s is enabled.
Use the function `%s' to change this variable." pretty-name mode))
	       (make-variable-buffer-local ',mode))

	  (let ((curfile (or (and (boundp 'byte-compile-current-file)
				  byte-compile-current-file)
			     load-file-name)))
	    `(defcustom ,mode ,init-value
	       ,(format "Toggle %s.
Setting this variable directly does not take effect;
use either \\[customize] or the function `%s'."
			pretty-name mode)
	       :set (lambda (symbol value) (funcall symbol (or value 0)))
	       :initialize 'custom-initialize-default
	       :group ,group
	       :type 'boolean
	       ,@(when curfile
		   (list
		    :require
		    (list 'quote
			  (intern (file-name-nondirectory
				   (file-name-sans-extension curfile)))))))))

       ;; The toggle's hook.  Wrapped in `progn' to prevent autoloading.
       (progn
	 (defcustom ,hook  nil
	   ,(format "Hook run at the end of function `%s'." mode-name)
	   :group ,group
	   :type 'hook))

       ;; The actual function.
       (defun ,mode (&optional arg)
	 ,(or doc
	      (format "With no argument, toggle %s.
With universal prefix ARG turn mode on.
With zero or negative ARG turn mode off.
\\{%s}" pretty-name keymap-sym))
	 (interactive "P")
	 (setq ,mode
	       (if arg
		   (> (prefix-numeric-value arg) 0)
		 (not ,mode)))
	 ,@body
	 ;; The on/off hooks are here for backward compatibility only.
	 (run-hooks ',hook (if ,mode ',hook-on ',hook-off))
	 ;; Return the new setting.
	 (if (interactive-p)
	     (message ,(format "%s %%sabled" pretty-name)
		      (if ,mode "en" "dis")))
	 ,mode)

       ,(unless globalp
	  (let ((turn-on (intern (concat "turn-on-" mode-name)))
		(turn-off (intern (concat "turn-off-" mode-name))))
	    `(progn
	       (defun ,turn-on ()
		 ,(format "Turn on %s.

This function is designed to be added to hooks, for example:
  (add-hook 'text-mode-hook '%s)"
			  pretty-name
			  turn-on)
		 (interactive)
		 (,mode t))
	       (defun ,turn-off ()
		 ,(format "Turn off %s." pretty-name)
		 (interactive)
		 (,mode -1))
	       ,(when define-global-mode-p
		  `(easy-mmode-define-global-mode
		    ,(intern (concat "global-" mode-name))
		    ,mode
		    ,(or conditional-turn-on turn-on)
		    :group ,group)))))

       ;; Autoloading an easy-mmode-define-minor-mode autoloads
       ;; everything up-to-here.
       :autoload-end

       ;; Define the minor-mode keymap.
       ,(unless (symbolp keymap)	;nil is also a symbol.
	  `(defvar ,keymap-sym
	     (let ((m ,keymap))
	       (cond ((keymapp m) m)
		     ((listp m) (easy-mmode-define-keymap m))
		     (t (error "Invalid keymap %S" ,keymap))))
	     ,(format "Keymap for `%s'." mode-name)))

       (add-minor-mode ',mode ',lighter
		       ,(if keymap keymap-sym
			  `(if (boundp ',keymap-sym)
			       (symbol-value ',keymap-sym))))

       ;; If the mode is global, call the function according to the default.
       ,(if globalp `(if ,mode (,mode 1))))))

;;;
;;; make global minor mode
;;;

;;;###autoload
(defmacro easy-mmode-define-global-mode (global-mode mode turn-on
						     &rest keys)
  "Make GLOBAL-MODE out of the MODE buffer-local minor mode.
TURN-ON is a function that will be called with no args in every buffer
  and that should try to turn MODE on if applicable for that buffer.
KEYS is a list of CL-style keyword arguments:
:group to specify the custom group."
  (let* ((mode-name (symbol-name mode))
	 (global-mode-name (symbol-name global-mode))
	 (pretty-name (easy-mmode-pretty-mode-name mode))
	 (pretty-global-name (easy-mmode-pretty-mode-name global-mode))
	 ;; We might as well provide a best-guess default group.
	 (group
	  (list 'quote
		(intern (replace-regexp-in-string "-mode\\'" "" mode-name))))
	 (buffers (intern (concat global-mode-name "-buffers")))
	 (cmmh (intern (concat global-mode-name "-cmmh"))))

    ;; Check keys.
    (while (keywordp (car keys))
      (case (pop keys)
	(:group (setq group (pop keys)))
	(t (setq keys (cdr keys)))))

    `(progn
       ;; The actual global minor-mode
       (define-minor-mode ,global-mode
	 ,(format "Toggle %s in every buffer.
With prefix ARG, turn %s on if and only if ARG is positive.
%s is actually not turned on in every buffer but only in those
in which `%s' turns it on."
		  pretty-name pretty-global-name pretty-name turn-on)
	 nil nil nil :global t :group ,group

	 ;; Setup hook to handle future mode changes and new buffers.
	 (if ,global-mode
	     (progn
	       (add-hook 'find-file-hooks ',buffers)
	       (add-hook 'change-major-mode-hook ',cmmh))
	   (remove-hook 'find-file-hooks ',buffers)
	   (remove-hook 'change-major-mode-hook ',cmmh))

	 ;; Go through existing buffers.
	 (dolist (buf (buffer-list))
	   (with-current-buffer buf
	     (if ,global-mode (,turn-on) (,mode -1)))))

       ;; Autoloading easy-mmode-define-global-mode
       ;; autoloads everything up-to-here.
       :autoload-end

       ;; List of buffers left to process.
       (defvar ,buffers nil)

       ;; The function that calls TURN-ON in each buffer.
       (defun ,buffers ()
	 (remove-hook 'post-command-hook ',buffers)
	 (while ,buffers
	   (let ((buf (pop ,buffers)))
	     (when (buffer-live-p buf)
	       (with-current-buffer buf (,turn-on))))))

       ;; The function that catches kill-all-local-variables.
       (defun ,cmmh ()
	 (add-to-list ',buffers (current-buffer))
	 (add-hook 'post-command-hook ',buffers)))))

;;;
;;; easy-mmode-defmap
;;;

(if (fboundp 'set-keymap-parents)
    (defalias 'easy-mmode-set-keymap-parents 'set-keymap-parents)
  (defun easy-mmode-set-keymap-parents (m parents)
    (set-keymap-parent
     m
     (cond
      ((not (consp parents)) parents)
      ((not (cdr parents)) (car parents))
      (t (let ((m (copy-keymap (pop parents))))
	   (easy-mmode-set-keymap-parents m parents)
	   m))))))

;;;###autoload
(defun easy-mmode-define-keymap (bs &optional name m args)
  "Return a keymap built from bindings BS.
BS must be a list of (KEY . BINDING) where
KEY and BINDINGS are suitable for `define-key'.
Optional NAME is passed to `make-sparse-keymap'.
Optional map M can be used to modify an existing map.
ARGS is a list of additional arguments."
  (let (inherit dense suppress)
    (while args
      (let ((key (pop args))
	    (val (pop args)))
	(case key
	 (:dense (setq dense val))
	 (:inherit (setq inherit val))
	 (:group)
	 ;;((eq key :suppress) (setq suppress val))
	 (t (message "Unknown argument %s in defmap" key)))))
    (unless (keymapp m)
      (setq bs (append m bs))
      (setq m (if dense (make-keymap name) (make-sparse-keymap name))))
    (dolist (b bs)
      (let ((keys (car b))
	    (binding (cdr b)))
	(dolist (key (if (consp keys) keys (list keys)))
	  (cond
	   ((symbolp key)
	    (substitute-key-definition key binding m global-map))
	   ((null binding)
	    (unless (keymapp (lookup-key m key)) (define-key m key binding)))
	   ((let ((o (lookup-key m key)))
	      (or (null o) (numberp o) (eq o 'undefined)))
	    (define-key m key binding))))))
    (cond
     ((keymapp inherit) (set-keymap-parent m inherit))
     ((consp inherit) (easy-mmode-set-keymap-parents m inherit)))
    m))

;;;###autoload
(defmacro easy-mmode-defmap (m bs doc &rest args)
  `(defconst ,m
     (easy-mmode-define-keymap ,bs nil (if (boundp ',m) ,m) ,(cons 'list args))
     ,doc))


;;;
;;; easy-mmode-defsyntax
;;;

(defun easy-mmode-define-syntax (css args)
  (let ((st (make-syntax-table (plist-get args :copy)))
	(parent (plist-get args :inherit)))
    (dolist (cs css)
      (let ((char (car cs))
	    (syntax (cdr cs)))
	(if (sequencep char)
	    (mapcar (lambda (c) (modify-syntax-entry c syntax st)) char)
	  (modify-syntax-entry char syntax st))))
    (if parent (set-char-table-parent
		st (if (symbolp parent) (symbol-value parent) parent)))
    st))

;;;###autoload
(defmacro easy-mmode-defsyntax (st css doc &rest args)
  "Define variable ST as a syntax-table.
CSS contains a list of syntax specifications of the form (CHAR . SYNTAX).
"
  `(progn
     (autoload 'easy-mmode-define-syntax "easy-mmode")
     (defconst ,st (easy-mmode-define-syntax ,css ,(cons 'list args)) doc)))



;;;
;;; A "macro-only" reimplementation of define-derived-mode.
;;;

;;;###autoload
(defmacro define-derived-mode (child parent name &optional docstring &rest body)
  "Create a new mode as a variant of an existing mode.

The arguments to this command are as follow:

CHILD:     the name of the command for the derived mode.
PARENT:    the name of the command for the parent mode (e.g. `text-mode').
NAME:      a string which will appear in the status line (e.g. \"Hypertext\")
DOCSTRING: an optional documentation string--if you do not supply one,
           the function will attempt to invent something useful.
BODY:      forms to execute just before running the
           hooks for the new mode.

Here is how you could define LaTeX-Thesis mode as a variant of LaTeX mode:

  (define-derived-mode LaTeX-thesis-mode LaTeX-mode \"LaTeX-Thesis\")

You could then make new key bindings for `LaTeX-thesis-mode-map'
without changing regular LaTeX mode.  In this example, BODY is empty,
and DOCSTRING is generated by default.

On a more complicated level, the following command uses `sgml-mode' as
the parent, and then sets the variable `case-fold-search' to nil:

  (define-derived-mode article-mode sgml-mode \"Article\"
    \"Major mode for editing technical articles.\"
    (setq case-fold-search nil))

Note that if the documentation string had been left out, it would have
been generated automatically, with a reference to the keymap."

  (let* ((child-name (symbol-name child))
	 (map (intern (concat child-name "-map")))
	 (syntax (intern (concat child-name "-syntax-table")))
	 (abbrev (intern (concat child-name "-abbrev-table")))
	 (hook (intern (concat child-name "-hook"))))
	 
    (unless parent (setq parent 'fundamental-mode))

    (when (and docstring (not (stringp docstring)))
      ;; DOCSTRING is really the first command and there's no docstring
      (push docstring body)
      (setq docstring nil))

    (unless (stringp docstring)
      ;; Use a default docstring.
      (setq docstring
	    (format "Major mode derived from `%s' by `define-derived-mode'.
Inherits all of the parent's attributes, but has its own keymap,
abbrev table and syntax table:

  `%s', `%s' and `%s'

which more-or-less shadow %s's corresponding tables."
		    parent map syntax abbrev parent)))

    (unless (string-match (regexp-quote (symbol-name hook)) docstring)
      ;; Make sure the docstring mentions the mode's hook
      (setq docstring
	    (concat docstring
		    (if (eq parent 'fundamental-mode)
			"\n\nThis mode "
		      (concat
		       "\n\nIn addition to any hooks its parent mode "
		       (if (string-match (regexp-quote (format "`%s'" parent))
					 docstring) nil
			 (format "`%s' " parent))
		       "might have run,\nthis mode "))
		    (format "runs the hook `%s'" hook)
		    ", as the final step\nduring initialization.")))

    (unless (string-match "\\\\[{[]" docstring)
      ;; And don't forget to put the mode's keymap
      (setq docstring (concat docstring "\n\n\\{" (symbol-name map) "}")))

    `(progn
       (defvar ,map (make-sparse-keymap))
       (defvar ,syntax (make-char-table 'syntax-table nil))
       (defvar ,abbrev)
       (define-abbrev-table ',abbrev nil)
       (put ',child 'derived-mode-parent ',parent)
     
       (defun ,child ()
	 ,docstring
	 (interactive)
					; Run the parent.
	 (combine-run-hooks

	  (,parent)
					; Identify special modes.
	  (put ',child 'special (get ',parent 'special))
					; Identify the child mode.
	  (setq major-mode ',child)
	  (setq mode-name ,name)
					; Set up maps and tables.
	  (unless (keymap-parent ,map)
	    (set-keymap-parent ,map (current-local-map)))
	  (let ((parent (char-table-parent ,syntax)))
	    (unless (and parent (not (eq parent (standard-syntax-table))))
	      (set-char-table-parent ,syntax (syntax-table))))
	  (when local-abbrev-table
	    (mapatoms
	     (lambda (symbol)
	       (or (intern-soft (symbol-name symbol) ,abbrev)
		   (define-abbrev ,abbrev (symbol-name symbol)
		     (symbol-value symbol) (symbol-function symbol))))
	     local-abbrev-table))
       
	  (use-local-map ,map)
	  (set-syntax-table ,syntax)
	  (setq local-abbrev-table ,abbrev)
					; Splice in the body (if any).
	  ,@body)
					; Run the hooks, if any.
	 (run-hooks ',hook)))))

;; Inspired from derived-mode-class in derived.el
(defun easy-mmode-derived-mode-p (mode)
  "Non-nil if the current major mode is derived from MODE.
Uses the `derived-mode-parent' property of the symbol to trace backwards."
  (let ((parent major-mode))
    (while (and (not (eq parent mode))
		(setq parent (get parent 'derived-mode-parent))))
    parent))


;;;
;;; easy-mmode-define-navigation
;;;

(defmacro easy-mmode-define-navigation (base re &optional name endfun)
  "Define BASE-next and BASE-prev to navigate in the buffer.
RE determines the places the commands should move point to.
NAME should describe the entities matched by RE and is used to build
  the docstrings of the two functions.
BASE-next also tries to make sure that the whole entry is visible by
  searching for its end (by calling ENDFUN if provided or by looking for
  the next entry) and recentering if necessary.
ENDFUN should return the end position (with or without moving point)."
  (let* ((base-name (symbol-name base))
	 (prev-sym (intern (concat base-name "-prev")))
	 (next-sym (intern (concat base-name "-next"))))
    (unless name (setq name (symbol-name base-name)))
    `(progn
       (add-to-list 'debug-ignored-errors
		    ,(concat "^No \\(previous\\|next\\) " (regexp-quote name)))
       (defun ,next-sym (&optional count)
	 ,(format "Go to the next COUNT'th %s." name)
	 (interactive)
	 (unless count (setq count 1))
	 (if (< count 0) (,prev-sym (- count))
	   (if (looking-at ,re) (incf count))
	   (unless (re-search-forward ,re nil t count)
	     (error ,(format "No next %s" name)))
	   (goto-char (match-beginning 0))
	   (when (eq (current-buffer) (window-buffer (selected-window)))
	     (let ((endpt (or (save-excursion
				,(if endfun `(,endfun)
				   `(re-search-forward ,re nil t 2)))
			      (point-max))))
	       (unless (<= endpt (window-end))
		 (recenter '(0)))))))
       (defun ,prev-sym (&optional count)
	 ,(format "Go to the previous COUNT'th %s" (or name base-name))
	 (interactive)
	 (unless count (setq count 1))
	 (if (< count 0) (,next-sym (- count))
	   (unless (re-search-backward ,re nil t count)
	     (error ,(format "No previous %s" name))))))))

(provide 'easy-mmode)

;;; easy-mmode.el ends here
