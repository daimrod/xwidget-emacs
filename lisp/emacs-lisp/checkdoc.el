;;; checkdoc --- Check documentation strings for style requirements

;;;  Copyright (C) 1997, 1998  Free Software Foundation

;; Author: Eric M. Ludlam <zappo@gnu.org>
;; Version: 0.4.3
;; Keywords: docs, maint, lisp

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
;;
;;   The emacs lisp manual has a nice chapter on how to write
;; documentation strings.  Many stylistic suggestions are fairly
;; deterministic and easy to check for syntactically, but also easy
;; to forget.  The main checkdoc engine will perform the stylistic
;; checks needed to make sure these styles are remembered.
;;
;; There are two ways to use checkdoc:
;;   1) Periodically use `checkdoc'. `checkdoc-current-buffer' and
;;      `checkdoc-defun' to check your documentation.
;;   2) Use `checkdoc-minor-mode' to automatically check your
;;      documentation whenever you evaluate lisp code with C-M-x
;;      or [menu-bar emacs-lisp eval-buffer].  Additional key-bindings
;;      are also provided under C-c ? KEY
;;        (require 'checkdoc)
;;        (add-hook 'emacs-lisp-mode-hook
;;	             '(lambda () (checkdoc-minor-mode 1)))
;;
;; Auto-fixing:
;;
;;   There are four classifications of style errors in terms of how
;; easy they are to fix.  They are simple, complex, really complex,
;; and impossible.  (Impossible really means that checkdoc does not
;; have a fixing routine yet.)  Typically white-space errors are
;; classified as simple, and are auto-fixed by default.  Typographic
;; changes are considered complex, and the user is asked if they want
;; the problem fixed before checkdoc makes the change.  These changes
;; can be done without asking if `checkdoc-autofix-flag' is properly
;; set.  Potentially redundant changes are considered really complex,
;; and the user is always asked before a change is inserted.  The
;; variable `checkdoc-autofix-flag' controls how these types of errors
;; are fixed.
;;
;; Spell checking doc-strings:
;;
;;   The variable `checkdoc-spellcheck-documentation-flag' can be set
;; to customize how spell checking is to be done.  Since spell
;; checking can be quite slow, you can optimize how best you want your
;; checking done.  The default is 'defun, which spell checks each time
;; `checkdoc-defun' or `checkdoc-eval-defun' is used.  Setting to nil
;; prevents spell checking during normal usage.
;;   Setting this variable to nil does not mean you cannot take
;; advantage of the spell checking.  You can instead use the
;; interactive functions `checkdoc-ispell-*' to check the spelling of
;; your documentation.
;;   There is a list of lisp-specific words which checkdoc will
;; install into ispell on the fly, but only if ispell is not already
;; running.  Use `ispell-kill-ispell' to make checkdoc restart it with
;; these words enabled.
;;
;; Checking parameters
;;
;;   You might not always want a function to have it's parameters listed
;; in order.  When this is the case, put the following comment just in
;; front of the documentation string: "; checkdoc-order: nil"  This
;; overrides the value of `checkdoc-arguments-in-order-flag'.
;;
;;   If you specifically wish to avoid mentioning a parameter of a
;; function in the doc string (such as a hidden parameter, or a
;; parameter which is very obvious like events), you can have checkdoc
;; skip looking for it by putting the following comment just in front
;; of the documentation string: "; checkdoc-params: (args go here)"
;;
;; Adding your own checks:
;;
;;   You can experiment with adding your own checks by setting the
;; hooks `checkdoc-style-hooks' and `checkdoc-comment-style-hooks'.
;; Return a string which is the error you wish to report.  The cursor
;; position should be preserved.
;;
;; This file requires lisp-mnt (lisp maintenance routines) for the
;; comment checkers.
;;
;; Requires custom for emacs v20.

;;; Change log:
;; 0.1   Initial revision
;; 0.2   Fixed comments in this file to match the emacs lisp standards.
;;       Added new doc checks for: variable-flags, function arguments
;;       Added autofix functionality for white-space, and quoted variables.
;;       Unquoted symbols are allowed after ( character. (Sample code)
;;       Check for use of `? ' at end of line and warn.
;;       Check for spaces at end of lines for whole file, or one defun.
;;       Check for comments standards, including headinds like Code:
;;         and use of triple semicolons versus double semicolons
;;       Check that interactive functions have a doc-string.  Optionally
;;         set `checkdoc-force-docstrings-flag' to non-nil to make all
;;         definitions have a doc-string.
;; 0.3   Regexp changse for accuracy on var checking and param checking.
;;       lm-verify check expanded to each sub-call w/ more descriptive
;;         messages, and two autofix-options.
;;       Suggestions/patches from Christoph Wedler <wedler@fmi.uni-passau.de>
;;         XEmacs support w/ extents/overlays.
;;         Better Whitespace finding regexps
;;         Added `checkdoc-arguments-in-order-flag' to optionally turn off
;;           warnings of arguments that do not appear in order in doc
;;           strings.
;; 0.4   New fix routine when two lines can be joined to make the
;;         first line a comlete sentence.
;;       Added ispell code.  Use `checkdoc-spellcheck-documentation-flag'
;;         to enable or disable this test in certain contexts.
;;       Added ispell interface functions `checkdoc-ispell',
;;         `checkdoc-ispell-continue', `checkdoc-ispell-defun'
;;         `checkdoc-ispell-interactive', `checkdoc-ispell-current-buffer'.
;;       Loop through all potential unquoted symbols.
;;       Auto-fixing no longer screws up the "end" of the doc-string.
;;       Maintain a different syntax table when examining arguments.
;;       Autofix enabled for parameters which are not uppercase iff they
;;         occur in lower case in the doc-string.
;;       Autofix enable if there is no Code: label.
;;       The comment text ";; checkdoc-order: nil|t" inside a defun to
;;         enable or disable the checking of argument order for one defun.
;;       The comment text ";; checkdoc-params: (arg1 arg2)" inside a defun
;;         (Such as just before the doc string) will list ARG1 and ARG2 as
;;         being paramters that need not show up in the doc string.
;;       Brought in suggestions from Jari Aalto <jaalto@tre.tele.nokia.fi>
;;         More robustness (comments in/around doc-strings/ arg lists)
;;         Don't offer to `quote'afy symbols or keystroke representations
;;           that are in lists (sample code) This added new fn
;;           `checkdoc-in-sample-code-p'
;;         Added more comments near the ;;; comment check about why it
;;           is being done.  ;;; Are also now allowed inside a defun.
;;           This added the function `checkdoc-outside-major-sexp'
;;         Added `checkdoc-interactive' which permits interactive
;;           perusal of document warnings, and editing of strings.
;;         Fixed `checkdoc-defun-info' to be more robust when creating
;;           the paramter list.
;;         Added list of verbs in the wrong tense, and their fixes.
;;         Added defconst/subst/advice to checked items.
;;         Added `checkdoc-style-hooks' and `checkdoc-comment-style-hooks'
;;           for adding in user tests.
;;         Added `checkdoc-continue', a version of checkdoc that continues
;;           from point.
;;         [X]Emacs 20 support for extended characters.
;;         Only check comments on real files.
;;         Put `checkdoc' and `checkdoc-continue' into keymap/menu
;; 0.4.1 Made `custom' friendly.
;;       C-m in warning buffer also goes to error.
;;       Shrink error buffer to size of text.
;;       Added `checkdoc-tripple-semi-comment-check-flag'.
;;       `checkdoc-spellcheck-documentation-flag' off by default.
;;       Re-sorted check order so white space is removed before adding a .
;; 0.4.2 Added some more comments in the commentary.
;;       You can now `quote' symbols that look like keystrokes
;;       When spell checking, meta variables can end in `th' or `s'.
;; 0.4.3 Fixed bug where multi-function checking skips defuns that
;;         have comments before the doc-string.
;;       Fixed bug where keystrokes were identified from a variable name
;;         like ASSOC-P.

;;; TO DO:
;;   Hook into the byte compiler on a defun/defver level to generate
;;     warnings in the byte-compiler's warning/error buffer.
;;   Better ways to override more typical `eval' functions.  Advice
;;     might be good but hard to turn on/off as a minor mode.
;;
;;; Maybe Do:
;;   Code sweep checks for "forbidden functions", proper use of hooks,
;;     proper keybindings, and other items from the manual that are
;;     not specifically docstring related.  Would this even be useful?

;;; Code:
(defvar checkdoc-version "0.4.3"
  "Release version of checkdoc you are currently running.")

;; From custom web page for compatibility between versions of custom:
(eval-and-compile
  (condition-case ()
      (require 'custom)
    (error nil))
  (if (and (featurep 'custom) (fboundp 'custom-declare-variable))
      nil ;; We've got what we needed
    ;; We have the old custom-library, hack around it!
    (defmacro defgroup (&rest args)
      nil)
    (defmacro custom-add-option (&rest args)
      nil)
    (defmacro defcustom (var value doc &rest args)
      (` (defvar (, var) (, value) (, doc))))))

(defcustom checkdoc-autofix-flag 'semiautomatic
  "*Non-nil means attempt auto-fixing of doc-strings.
If this value is the symbol 'query, then the user is queried before
any change is made. If the value is 'automatic, then all changes are
made without asking unless the change is very-complex.  If the value
is 'semiautomatic, or any other value, then simple fixes are made
without asking, and complex changes are made by asking the user first.
The value 'never is the same as nil, never ask or change anything."
  :group 'checkdoc
  :type '(choice (const automatic)
		 (const semiautomatic)
		 (const query)
		 (const never)))

(defcustom checkdoc-bouncy-flag t
  "*Non-nil means to 'bounce' to auto-fix locations.
Setting this to nil will silently make fixes that require no user
interaction.  See `checkdoc-autofix-flag' for auto-fixing details."
  :group 'checkdoc
  :type 'boolean)

(defcustom checkdoc-force-docstrings-flag t
  "*Non-nil means that all checkable definitions should have documentation.
Style guide dictates that interactive functions MUST have documentation,
and that its good but not required practice to make non user visible items
have doc-strings."
  :group 'checkdoc
  :type 'boolean)

(defcustom checkdoc-tripple-semi-comment-check-flag t
  "*Non-nil means to check for multiple adjacent occurrences of ;;; comments.
According to the style of emacs code in the lisp libraries, a block
comment can look like this:
;;; Title
;;  text
;;  text
But when inside a function, code can be commented out using the ;;;
construct for all lines.  When this variable is nil, the ;;; construct
is ignored regardless of it's location in the code."
  :group 'checkdoc
  :type 'boolean)

(defcustom checkdoc-spellcheck-documentation-flag nil
  "*Non-nil means run ispell on doc-strings based on value.
This will be automatically set to nil if ispell does not exist on your
system.  Possible values are:

  nil          - Don't spell-check during basic style checks.
  'defun       - Spell-check when style checking a single defun
  'buffer      - Spell-check only when style checking the whole buffer
  'interactive - Spell-check only during `checkdoc-interactive'
  t            - Always spell-check"
  :group 'checkdoc
  :type '(choice (const nil)
		 (const defun)
		 (const buffer)
		 (const interactive)
		 (const t)))

(defvar checkdoc-ispell-lisp-words
  '("alist" "etags" "iff" "keymap" "paren" "regexp" "sexp" "xemacs")
  "List of words that are correct when spell-checking lisp documentation.")

(defcustom checkdoc-max-keyref-before-warn 10
  "*The number of \\ [command-to-keystroke] tokens allowed in a doc-string.
Any more than this and a warning is generated suggesting that the construct
\\ {keymap} be used instead."
  :group 'checkdoc
  :type 'integer)

(defcustom checkdoc-arguments-in-order-flag t
  "*Non-nil means warn if arguments appear out of order.
Setting this to nil will mean only checking that all the arguments
appear in the proper form in the documentation, not that they are in
the same order as they appear in the argument list.  No mention is
made in the style guide relating to order."
  :group 'checkdoc
  :type 'boolean)

(defvar checkdoc-style-hooks nil
  "Hooks called after the standard style check is completed.
All hooks must return nil or a string representing the error found.
Useful for adding new user implemented commands.

Each hook is called with two parameters, (DEFUNINFO ENDPOINT).
DEFUNINFO is the return value of `checkdoc-defun-info'.  ENDPOINT is the
location of end of the documentation string.")

(defvar checkdoc-comment-style-hooks nil
  "Hooks called after the standard comment style check is completed.
Must return nil if no errors are found, or a string describing the
problem discovered.  This is useful for adding additional checks.")

(defvar checkdoc-diagnostic-buffer "*Style Warnings*"
  "Name of warning message buffer.")

(defvar checkdoc-defun-regexp
  "^(def\\(un\\|var\\|custom\\|macro\\|const\\|subst\\|advice\\)\
\\s-+\\(\\(\\sw\\|\\s_\\)+\\)[ \t\n]+"
  "Regular expression used to identify a defun.
A search leaves the cursor in front of the parameter list.")

(defcustom checkdoc-verb-check-experimental-flag t
  "*Non-nil means to attempt to check the voice of the doc-string.
This check keys off some words which are commonly misused.  See the
variable `checkdoc-common-verbs-wrong-voice' if you wish to add your
own."
  :group 'checkdoc
  :type 'boolean)

(defvar checkdoc-common-verbs-regexp nil
  "Regular expression derived from `checkdoc-common-verbs-regexp'.")

(defvar checkdoc-common-verbs-wrong-voice
  '(("adds" . "add")
    ("allows" . "allow")
    ("appends" . "append")
    ("applies" "apply")
    ("arranges" "arrange")
    ("brings" . "bring")
    ("calls" . "call")
    ("catches" . "catch")
    ("changes" . "change")
    ("checks" . "check")
    ("contains" . "contain")
    ("creates" . "create")
    ("destroys" . "destroy")
    ("disables" . "disable")
    ("executes" . "execute")
    ("evals"   . "evaluate")
    ("evaluates" . "evaluate")
    ("finds" . "find")
    ("forces" . "force")
    ("gathers" . "gather")
    ("generates" . "generate")
    ("goes" . "go")
    ("guesses" . "guess")
    ("highlights" . "highlight")
    ("holds" . "hold")
    ("ignores" . "ignore")
    ("indents" . "indent")
    ("initializes" . "initialize")
    ("inserts" . "insert")
    ("installs" . "install")
    ("investigates" . "investigate")
    ("keeps" . "keep")
    ("kills" . "kill")
    ("leaves" . "leave")
    ("lets" . "let")
    ("loads" . "load")
    ("looks" . "look")
    ("makes" . "make")
    ("marks" . "mark")
    ("matches" . "match")
    ("notifies" . "notify")
    ("offers" . "offer")
    ("parses" . "parse")
    ("performs" . "perform")
    ("prepares" . "prepare")
    ("prepends" . "prepend")
    ("reads" . "read")
    ("raises" . "raise")
    ("removes" . "remove")
    ("replaces" . "replace")
    ("resets" . "reset")
    ("restores" . "restore")
    ("returns" . "return")
    ("runs" . "run")
    ("saves" . "save")
    ("says" . "say")
    ("searches" . "search")
    ("selects" . "select")
    ("sets" . "set")
    ("sex" . "s*x")
    ("shows" . "show")
    ("signifies" . "signify")
    ("sorts" . "sort")
    ("starts" . "start")
    ("stores" . "store")
    ("switches" . "switch")
    ("tells" . "tell")
    ("tests" . "test")
    ("toggles" . "toggle")
    ("tries"   . "try")
    ("turns" . "turn")
    ("undoes" . "undo")
    ("unloads" . "unload")
    ("unmarks" . "unmark")
    ("updates" . "update")
    ("uses" . "use")
    ("yanks" . "yank")
    )
  "Alist of common words in the wrong voice and what should be used instead.
Set `checkdoc-verb-check-experimental-flag' to nil to avoid this costly
and experimental check.  Do not modify this list without setting
the value of `checkdoc-common-verbs-regexp' to nil which cause it to
be re-created.")

(defvar checkdoc-syntax-table nil
  "Syntax table used by checkdoc in document strings.")

(if checkdoc-syntax-table
    nil
  (setq checkdoc-syntax-table (copy-syntax-table emacs-lisp-mode-syntax-table))
  ;; When dealing with syntax in doc-strings, make sure that - are encompased
  ;; in words so we can use cheap \\> to get the end of a symbol, not the
  ;; end of a word in a conglomerate.
  (modify-syntax-entry ?- "w" checkdoc-syntax-table)
  )
	

;;; Compatibility
;;
(if (string-match "X[Ee]macs" emacs-version)
    (progn
      (defalias 'checkdoc-make-overlay 'make-extent)
      (defalias 'checkdoc-overlay-put 'set-extent-property)
      (defalias 'checkdoc-delete-overlay 'delete-extent)
      (defalias 'checkdoc-overlay-start 'extent-start)
      (defalias 'checkdoc-overlay-end 'extent-end)
      (defalias 'checkdoc-mode-line-update 'redraw-modeline)
      (defalias 'checkdoc-call-eval-buffer 'eval-buffer)
      )
  (defalias 'checkdoc-make-overlay 'make-overlay)
  (defalias 'checkdoc-overlay-put 'overlay-put)
  (defalias 'checkdoc-delete-overlay 'delete-overlay)
  (defalias 'checkdoc-overlay-start 'overlay-start)
  (defalias 'checkdoc-overlay-end 'overlay-end)
  (defalias 'checkdoc-mode-line-update 'force-mode-line-update)
  (defalias 'checkdoc-call-eval-buffer 'eval-current-buffer)
  )

;; Emacs 20s have MULE characters which dont equate to numbers.
(if (fboundp 'char=)
    (defalias 'checkdoc-char= 'char=)
  (defalias 'checkdoc-char= '=))

;; Emacs 19.28 and earlier don't have the handy 'add-to-list function
(if (fboundp 'add-to-list)

    (defalias 'checkdoc-add-to-list 'add-to-list)

  (defun checkdoc-add-to-list (list-var element)
    "Add to the value of LIST-VAR the element ELEMENT if it isn't there yet."
    (if (not (member element (symbol-value list-var)))
	(set list-var (cons element (symbol-value list-var)))))
  )

;; To be safe in new emacsen, we want to read events, not characters
(if (fboundp 'read-event)
    (defalias 'checkdoc-read-event 'read-event)
  (defalias 'checkdoc-read-event 'read-char))

;;; User level commands
;;
;;;###autoload
(defun checkdoc-eval-current-buffer ()
  "Evaluate and check documentation for the current buffer.
Evaluation is done first because good documentation for something that
doesn't work is just not useful.  Comments, Doc-strings, and rogue
spacing are all verified."
  (interactive)
  (checkdoc-call-eval-buffer nil)
  (checkdoc-current-buffer t))

;;;###autoload
(defun checkdoc-current-buffer (&optional take-notes)
  "Check the current buffer for document style, comment style, and rogue spaces.
Optional argument TAKE-NOTES non-nil will store all found errors in a
warnings buffer, otherwise it stops after the first error."
  (interactive "P")
  (if (interactive-p) (message "Checking buffer for style..."))
  ;; Assign a flag to spellcheck flag
  (let ((checkdoc-spellcheck-documentation-flag
	 (memq checkdoc-spellcheck-documentation-flag '(buffer t))))
    ;; every test is responsible for returning the cursor.
    (or (and buffer-file-name ;; only check comments in a file
	     (checkdoc-comments take-notes))
	(checkdoc take-notes)
	(checkdoc-rogue-spaces take-notes)
	(not (interactive-p))
	(message "Checking buffer for style...Done."))))

;;;###autoload
(defun checkdoc-interactive (&optional start-here)
  "Interactively check the current buffers for errors.
Prefix argument START-HERE will start the checking from the current
point, otherwise the check starts at the beginning of the current
buffer.  Allows navigation forward and backwards through document
errors.  Does not check for comment or space warnings."
  (interactive "P")
  ;; Determine where to start the test
  (let* ((begin (prog1 (point)
		  (if (not start-here) (goto-char (point-min)))))
	 ;; Assign a flag to spellcheck flag
	 (checkdoc-spellcheck-documentation-flag
	  (member checkdoc-spellcheck-documentation-flag
		  '(buffer interactive t)))
	 ;; Fetch the error list
	 (err-list (list (checkdoc-next-error))))
    (if (not (car err-list)) (setq err-list nil))
    ;; Include whatever function point is in for good measure.
    (beginning-of-defun)
    (while err-list
      (goto-char (cdr (car err-list)))
      ;; The cursor should be just in front of the offending doc-string
      (let ((cdo (save-excursion
		   (checkdoc-make-overlay (point)
					  (progn (forward-sexp 1)
						 (point)))))
	    c)
	(unwind-protect
	    (progn
	      (checkdoc-overlay-put cdo 'face 'highlight)
	      ;; Make sure the whole doc-string is visible if possible.
	      (sit-for 0)
	      (if (not (pos-visible-in-window-p
			(save-excursion (forward-sexp 1) (point))
			(selected-window)))
		  (recenter))
	      (message "%s(? e n p q)" (car (car err-list)))
	      (setq c (checkdoc-read-event))
	      (if (not (integerp c)) (setq c ??))
	      (cond ((or (checkdoc-char= c ?n) (checkdoc-char= c ?\ ))
		     (let ((ne (checkdoc-next-error)))
		       (if (not ne)
			   (progn
			     (message "No More Stylistic Errors.")
			     (sit-for 2))
			 (setq err-list (cons ne err-list)))))
		    ((or (checkdoc-char= c ?p) (checkdoc-char= c ?\C-?))
		     (if (/= (length err-list) 1)
			 (progn
			   (setq err-list (cdr err-list))
			   ;; This will just re-ask fixup questions if
			   ;; it was skipped the last time.
			   (checkdoc-next-error))
		       (message "No Previous Errors.")
		       (sit-for 2)))
		    ((checkdoc-char= c ?e)
		     (message "Edit the docstring, and press C-M-c to exit.")
		     (recursive-edit)
		     (checkdoc-delete-overlay cdo)
		     (setq err-list (cdr err-list)) ;back up the error found.
		     (beginning-of-defun)
		     (let ((ne (checkdoc-next-error)))
		       (if (not ne)
			   (progn
			     (message "No More Stylistic Errors.")
			     (sit-for 2))
			 (setq err-list (cons ne err-list)))))
		    ((checkdoc-char= c ?q)
		     (setq err-list nil
			   begin (point)))
		    (t
		     (message "[E]dit [SPC|n] next error [DEL|p] prev error\
 [q]uit [?] help: ")
		     (sit-for 5))))
	  (checkdoc-delete-overlay cdo))))
    (goto-char begin)
    (message "Checkdoc: Done.")))

(defun checkdoc-next-error ()
  "Find and return the next checkdoc error list, or nil.
Add error vector is of the form (WARNING . POSITION) where WARNING
is the warning text, and POSITION is the point in the buffer where the
error was found.  We can use points and not markers because we promise
not to edit the buffer before point without re-executing this check."
  (let ((msg nil) (p (point)))
    (condition-case nil
	(while (and (not msg) (checkdoc-next-docstring))
	  (message "Searching for doc-string error...%d%%"
		   (/ (* 100 (point)) (point-max)))
	  (if (setq msg (checkdoc-this-string-valid))
	      (setq msg (cons msg (point)))))
      ;; Quit.. restore position,  Other errors, leave alone
      (quit (goto-char p)))
    msg))

;;;###autoload
(defun checkdoc (&optional take-notes)
  "Use `checkdoc-continue' starting at the beginning of the current buffer.
Prefix argument TAKE-NOTES means to collect all the warning messages into
a separate buffer."
  (interactive "P")
  (let ((p (point)))
    (goto-char (point-min))
    (checkdoc-continue take-notes)
    ;; Go back since we can't be here without success above.
    (goto-char p)
    nil))

;;;###autoload
(defun checkdoc-continue (&optional take-notes)
  "Find the next doc-string in the current buffer which is stylisticly poor.
Prefix argument TAKE-NOTES means to continue through the whole buffer and
save warnings in a separate buffer.  Second optional argument START-POINT
is the starting location.  If this is nil, `point-min' is used instead."
  (interactive "P")
  (let ((wrong nil) (msg nil) (errors nil)
	;; Assign a flag to spellcheck flag
	(checkdoc-spellcheck-documentation-flag
	 (member checkdoc-spellcheck-documentation-flag
		 '(buffer t))))
    (save-excursion
      ;; If we are taking notes, encompass the whole buffer, otherwise
      ;; the user is navigating down through the buffer.
      (if take-notes (checkdoc-start-section "checkdoc"))
      (while (and (not wrong) (checkdoc-next-docstring))
	;; OK, lets look at the doc-string.
	(setq msg (checkdoc-this-string-valid))
	(if msg
	    ;; Oops
	    (if take-notes
		(progn
		  (checkdoc-error (point) msg)
		  (setq errors t))
	      (setq wrong (point))))))
    (if wrong
	(progn
	  (goto-char wrong)
	  (error msg)))
    (if (and take-notes errors)
	(checkdoc-show-diagnostics)
      (if (interactive-p)
	  (message "No style warnings.")))))

(defun checkdoc-next-docstring ()
  "Find the next doc-string after point and return t.
Return nil if there are no more doc-strings."
  (if (not (re-search-forward checkdoc-defun-regexp nil t))
      nil
    ;; search drops us after the identifier.  The next sexp is either
    ;; the argument list or the value of the variable.  skip it.
    (forward-sexp 1)
    (skip-chars-forward " \n\t")
    t))

;;; ###autoload
(defun checkdoc-comments (&optional take-notes)
  "Find missing comment sections in the current emacs lisp file.
Prefix argument TAKE-NOTES non-nil means to save warnings in a
separate buffer.  Otherwise print a message.  This returns the error
if there is one."
  (interactive "P")
  (if take-notes (checkdoc-start-section "checkdoc-comments"))
  (if (not buffer-file-name)
     (error "Can only check comments for a file buffer."))
  (let* ((checkdoc-spellcheck-documentation-flag
	  (member checkdoc-spellcheck-documentation-flag
		  '(buffer t)))
	 (e (checkdoc-file-comments-engine)))
    (if e
	(if take-notes
	    (checkdoc-error nil e)
	  (error e)))
    (if (and e take-notes)
	(checkdoc-show-diagnostics))
    e))

;;;###autoload
(defun checkdoc-rogue-spaces (&optional take-notes)
  "Find extra spaces at the end of lines in the current file.
Prefix argument TAKE-NOTES non-nil means to save warnings in a
separate buffer.  Otherwise print a message.  This returns the error
if there is one."
  (interactive "P")
  (if take-notes (checkdoc-start-section "checkdoc-rogue-spaces"))
  (let ((e (checkdoc-rogue-space-check-engine)))
    (if e
	(if take-notes
	    (checkdoc-error nil e)
	  (message e)))
    (if (and e take-notes)
	(checkdoc-show-diagnostics))
    (if (not (interactive-p))
	e
      (if e (message e) (message "Space Check: done.")))))
      

;;;###autoload
(defun checkdoc-eval-defun ()
  "Evaluate the current form with `eval-defun' and check it's documentation.
Evaluation is done first so the form will be read before the
documentation is checked.  If there is a documentation error, then the display
of what was evaluated will be overwritten by the diagnostic message."
  (interactive)
  (eval-defun nil)
  (checkdoc-defun))

;;;###autoload
(defun checkdoc-defun (&optional no-error)
  "Examine the doc-string of the function or variable under point.
Calls `error' if the doc-string produces diagnostics.  If NO-ERROR is
non-nil, then do not call error, but call `message' instead.
If the document check passes, then check the function for rogue white
space at the end of each line."
  (interactive)
  (save-excursion
    (beginning-of-defun)
    (if (not (looking-at checkdoc-defun-regexp))
	;; I found this more annoying than useful.
	;;(if (not no-error)
	;;    (message "Cannot check this sexp's doc-string."))
	nil
      ;; search drops us after the identifier.  The next sexp is either
      ;; the argument list or the value of the variable.  skip it.
      (goto-char (match-end 0))
      (forward-sexp 1)
      (skip-chars-forward " \n\t")
      (let* ((checkdoc-spellcheck-documentation-flag
	      (member checkdoc-spellcheck-documentation-flag
		      '(defun t)))
	     (msg (checkdoc-this-string-valid)))
	(if msg (if no-error (message msg) (error msg))
	  (setq msg (checkdoc-rogue-space-check-engine
		     (save-excursion (beginning-of-defun) (point))
		     (save-excursion (end-of-defun) (point))))
	  (if msg (if no-error (message msg) (error msg))
	    (if (interactive-p) (message "Checkdoc: done."))))))))

;;; Ispell interface for forcing a spell check
;;

;;;###autoload
(defun checkdoc-ispell-current-buffer (&optional take-notes)
  "Check the style and spelling of the current buffer interactively.
Calls `checkdoc-current-buffer' with spell-checking turned on.
Prefix argument TAKE-NOTES is the same as for `checkdoc-current-buffer'"
  (interactive)
  (let ((checkdoc-spellcheck-documentation-flag t))
    (call-interactively 'checkdoc-current-buffer nil current-prefix-arg)))

;;;###autoload
(defun checkdoc-ispell-interactive (&optional take-notes)
  "Check the style and spelling of the current buffer interactively.
Calls `checkdoc-interactive' with spell-checking turned on.
Prefix argument TAKE-NOTES is the same as for `checkdoc-interacitve'"
  (interactive)
  (let ((checkdoc-spellcheck-documentation-flag t))
    (call-interactively 'checkdoc-interactive nil current-prefix-arg)))

;;;###autoload
(defun checkdoc-ispell (&optional take-notes)
  "Check the style and spelling of the current buffer.
Calls `checkdoc' with spell-checking turned on.
Prefix argument TAKE-NOTES is the same as for `checkdoc'"
  (interactive)
  (let ((checkdoc-spellcheck-documentation-flag t))
    (call-interactively 'checkdoc nil current-prefix-arg)))

;;;###autoload
(defun checkdoc-ispell-continue (&optional take-notes)
  "Check the style and spelling of the current buffer after point.
Calls `checkdoc-continue' with spell-checking turned on.
Prefix argument TAKE-NOTES is the same as for `checkdoc-continue'"
  (interactive)
  (let ((checkdoc-spellcheck-documentation-flag t))
    (call-interactively 'checkdoc-continue nil current-prefix-arg)))

;;;###autoload
(defun checkdoc-ispell-comments (&optional take-notes)
  "Check the style and spelling of the current buffer's comments.
Calls `checkdoc-comments' with spell-checking turned on.
Prefix argument TAKE-NOTES is the same as for `checkdoc-comments'"
  (interactive)
  (let ((checkdoc-spellcheck-documentation-flag t))
    (call-interactively 'checkdoc-comments nil current-prefix-arg)))

;;;###autoload
(defun checkdoc-ispell-defun (&optional take-notes)
  "Check the style and spelling of the current defun with ispell.
Calls `checkdoc-defun' with spell-checking turned on.
Prefix argument TAKE-NOTES is the same as for `checkdoc-defun'"
  (interactive)
  (let ((checkdoc-spellcheck-documentation-flag t))
    (call-interactively 'checkdoc-defun nil current-prefix-arg)))

;;; Minor Mode specification
;;
(defvar checkdoc-minor-mode nil
  "Non-nil in `emacs-lisp-mode' for automatic documentation checking.")
(make-variable-buffer-local 'checkdoc-minor-mode)

(checkdoc-add-to-list 'minor-mode-alist '(checkdoc-minor-mode " CDoc"))

(defvar checkdoc-minor-keymap
  (let ((map (make-sparse-keymap))
	(pmap (make-sparse-keymap)))
    ;; Override some bindings
    (define-key map "\C-\M-x" 'checkdoc-eval-defun)
    (if (not (string-match "XEmacs" emacs-version))
	(define-key map [menu-bar emacs-lisp eval-buffer]
	  'checkdoc-eval-current-buffer))
    (define-key pmap "x" 'checkdoc-defun)
    (define-key pmap "X" 'checkdoc-ispell-defun)
    (define-key pmap "`" 'checkdoc-continue)
    (define-key pmap "~" 'checkdoc-ispell-continue)
    (define-key pmap "d" 'checkdoc)
    (define-key pmap "D" 'checkdoc-ispell)
    (define-key pmap "i" 'checkdoc-interactive)
    (define-key pmap "I" 'checkdoc-ispell-interactive)
    (define-key pmap "b" 'checkdoc-current-buffer)
    (define-key pmap "B" 'checkdoc-ispell-current-buffer)
    (define-key pmap "e" 'checkdoc-eval-current-buffer)
    (define-key pmap "c" 'checkdoc-comments)
    (define-key pmap "C" 'checkdoc-ispell-comments)
    (define-key pmap " " 'checkdoc-rogue-spaces)

    ;; bind our submap into map
    (define-key map "\C-c?" pmap)
    map)
  "Keymap used to override evaluation key-bindings for documentation checking.")

;; Add in a menubar with easy-menu

(if checkdoc-minor-keymap
    (easy-menu-define
     checkdoc-minor-menu checkdoc-minor-keymap "Checkdoc Minor Mode Menu"
     '("CheckDoc"
       ["First Style Error" checkdoc t]
       ["First Style or Spelling Error " checkdoc-ispell t]
       ["Next Style Error" checkdoc-continue t]
       ["Next Style or Spelling  Error" checkdoc-ispell-continue t]
       ["Interactive Style Check" checkdoc-interactive t]
       ["Interactive Style and Spelling Check" checkdoc-ispell-interactive t]
       ["Check Defun" checkdoc-defun t]
       ["Check and Spell Defun" checkdoc-ispell-defun t]
       ["Check and Evaluate Defun" checkdoc-eval-defun t]
       ["Check Buffer" checkdoc-current-buffer t]
       ["Check and Spell Buffer" checkdoc-ispell-current-buffer t]
       ["Check and Evaluate Buffer" checkdoc-eval-current-buffer t]
       ["Check Comment Style" checkdoc-comments buffer-file-name]
       ["Check Comment Style and Spelling" checkdoc-ispell-comments
	buffer-file-name]
       ["Check for Rogue Spaces" checkdoc-rogue-spaces t]
       )))
;; XEmacs requires some weird stuff to add this menu in a minor mode.
;; What is it?

;; Allow re-insertion of a new keymap
(let ((a (assoc 'checkdoc-minor-mode minor-mode-map-alist)))
  (if a
      (setcdr a checkdoc-minor-keymap)
    (checkdoc-add-to-list 'minor-mode-map-alist (cons 'checkdoc-minor-mode
						      checkdoc-minor-keymap))))

;;;###autoload
(defun checkdoc-minor-mode (&optional arg)
  "Toggle checkdoc minor mode.  A mode for checking lisp doc-strings.
With prefix ARG, turn checkdoc minor mode on iff ARG is positive.

In checkdoc minor mode, the usual bindings for `eval-defun' which is
bound to \\<checkdoc-minor-keymap> \\[checkdoc-eval-defun] and `checkdoc-eval-current-buffer' are overridden to include
checking of documentation strings.

\\{checkdoc-minor-keymap}"
  (interactive "P")
  (setq checkdoc-minor-mode
	(not (or (and (null arg) checkdoc-minor-mode)
		 (<= (prefix-numeric-value arg) 0))))
  (checkdoc-mode-line-update))

;;; Subst utils
;;
(defsubst checkdoc-run-hooks (hookvar &rest args)
  "Run hooks in HOOKVAR with ARGS."
  (if (fboundp 'run-hook-with-args-until-success)
      (apply 'run-hook-with-args-until-success hookvar args)
    ;; This method was similar to above.  We ignore the warning
    ;; since we will use the above for future emacs versions
    (apply 'run-hook-with-args hookvar args)))

(defsubst checkdoc-create-common-verbs-regexp ()
  "Rebuild the contents of `checkdoc-common-verbs-regexp'."
  (or checkdoc-common-verbs-regexp
      (setq checkdoc-common-verbs-regexp
	    (concat "\\<\\("
		    (mapconcat (lambda (e) (concat (car e)))
			       checkdoc-common-verbs-wrong-voice "\\|")
		    "\\)\\>"))))

;; Profiler says this is not yet faster than just calling assoc
;;(defun checkdoc-word-in-alist-vector (word vector)
;;  "Check to see if WORD is in the car of an element of VECTOR.
;;VECTOR must be sorted.  The CDR should be a replacement.  Since the
;;word list is getting bigger, it is time for a quick bisecting search."
;;  (let ((max (length vector)) (min 0) i
;;	(found nil) (fw nil))
;;    (setq i (/ max 2))
;;    (while (and (not found) (/= min max))
;;      (setq fw (car (aref vector i)))
;;      (cond ((string= word fw) (setq found (cdr (aref vector i))))
;;	    ((string< word fw) (setq max i))
;;	    (t (setq min i)))
;;      (setq i (/ (+ max min) 2))
;;      )
;;    found))

;;; Checking engines
;;
(defun checkdoc-this-string-valid ()
  "Return a message string if the current doc-string is invalid.
Check for style only, such as the first line always being a complete
sentence, whitespace restrictions, and making sure there are no
hard-coded key-codes such as C-[char] or mouse-[number] in the comment.
See the style guide in the Emacs Lisp manual for more details."

  ;; Jump over comments between the last object and the doc-string
  (while (looking-at "[ \t\n]*;")
    (forward-line 1)
    (beginning-of-line)
    (skip-chars-forward " \n\t"))

  (if (not (looking-at "[ \t\n]*\""))
      nil
    (let ((old-syntax-table (syntax-table)))
      (unwind-protect
	  (progn
	    (set-syntax-table checkdoc-syntax-table)
	    (checkdoc-this-string-valid-engine))
	(set-syntax-table old-syntax-table)))))

(defun checkdoc-this-string-valid-engine ()
  "Return a message string if the current doc-string is invalid.
Depends on `checkdoc-this-string-valid' to reset the syntax table so that
regexp short cuts work."
  (let ((case-fold-search nil)
	;; Use a marker so if an early check modifies the text,
	;; we won't accidentally loose our place.  This could cause
	;; end-of doc-string whitespace to also delete the " char.
	(e (save-excursion (forward-sexp 1) (point-marker)))
	(fp (checkdoc-defun-info)))
    (or
     ;; * *Do not* indent subsequent lines of a documentation string so that
     ;;   the text is lined up in the source code with the text of the first
     ;;   line.  This looks nice in the source code, but looks bizarre when
     ;;   users view the documentation.  Remember that the indentation
     ;;   before the starting double-quote is not part of the string!
     (save-excursion
       (forward-line 1)
       (beginning-of-line)
       (if (and (< (point) e)
		(looking-at "\\([ \t]+\\)[^ \t\n]"))
	   (if (checkdoc-autofix-ask-replace (match-beginning 1)
					     (match-end 1)
					     "Remove this whitespace?"
					     "")
	       nil
	     "Second line should not have indentation")))
     ;; * Do not start or end a documentation string with whitespace.
     (let (start end)
       (if (or (if (looking-at "\"\\([ \t\n]+\\)")
		   (setq start (match-beginning 1)
			 end (match-end 1)))
	       (save-excursion
		 (forward-sexp 1)
		 (forward-char -1)
		 (if (/= (skip-chars-backward " \t\n") 0)
		     (setq start (point)
			   end (1- e)))))
	   (if (checkdoc-autofix-ask-replace
		start end "Remove this whitespace?" "")
	       nil
	     "Documentation strings should not start or end with whitespace")))
     ;; * Every command, function, or variable intended for users to know
     ;;   about should have a documentation string.
     ;;
     ;; * An internal variable or subroutine of a Lisp program might as well
     ;;   have a documentation string.  In earlier Emacs versions, you could
     ;;   save space by using a comment instead of a documentation string,
     ;;   but that is no longer the case.
     (if (and (not (nth 1 fp))		; not a variable
	      (or (nth 2 fp)		; is interactive
		  checkdoc-force-docstrings-flag) ;or we always complain
	      (not (checkdoc-char= (following-char) ?\"))) ; no doc-string
	 (if (nth 2 fp)
	     "All interactive functions should have documentation"
	   "All variables and subroutines might as well have a \
documentation string"))
     ;; * The first line of the documentation string should consist of one
     ;;   or two complete sentences that stand on their own as a summary.
     ;;   `M-x apropos' displays just the first line, and if it doesn't
     ;;   stand on its own, the result looks bad.  In particular, start the
     ;;   first line with a capital letter and end with a period.
     (save-excursion
       (end-of-line)
       (skip-chars-backward " \t\n")
       (if (> (point) e) (goto-char e)) ;of the form (defun n () "doc" nil)
       (forward-char -1)
       (cond
	((and (checkdoc-char= (following-char) ?\")
	      ;; A backslashed double quote at the end of a sentence
	      (not (checkdoc-char= (preceding-char) ?\\)))
	 ;; We might have to add a period in this case
	 (forward-char -1)
	 (if (looking-at "[.!]")
	     nil
	   (forward-char 1)
	   (if (checkdoc-autofix-ask-replace
		(point) (1+ (point)) "Add period to sentence?"
		".\"" t)
	       nil
	     "First sentence should end with punctuation.")))
	((looking-at "[\\!;:.)]")
	 ;; These are ok
	 nil)
	(t
	 ;; If it is not a complete sentence, lets see if we can
	 ;; predict a clever way to make it one.
	 (let ((msg "First line is not a complete sentence")
	       (e (point)))
	   (beginning-of-line)
	   (if (re-search-forward "\\. +" e t)
	       ;; Here we have found a complete sentence, but no break.
	       (if (checkdoc-autofix-ask-replace
		    (1+ (match-beginning 0)) (match-end 0)
		    "First line not a complete sentence.  Add CR here?"
		    "\n" t)
		   (let (l1 l2)
		     (forward-line 1)
		     (end-of-line)
		     (setq l1 (current-column)
			   l2 (save-excursion
				(forward-line 1)
				(end-of-line)
				(current-column)))
		     (if (> (+ l1 l2 1) 80)
			 (setq msg "Incomplete auto-fix.  Doc-string \
may require more formatting.")
		       ;; We can merge these lines!  Replace this CR
		       ;; with a space.
		       (delete-char 1) (insert " ")
		       (setq msg nil))))
	     ;; Lets see if there is enough room to draw the next
	     ;; line's sentence up here.  I often get hit w/
	     ;; auto-fill moving my words around.
	     (let ((numc (progn (end-of-line) (- 80 (current-column))))
		   (p    (point)))
	       (forward-line 1)
	       (beginning-of-line)
	       (if (and (re-search-forward "[.!:\"][ \n\"]" (save-excursion
							      (end-of-line)
							      (point))
					   t)
			(< (current-column) numc))
		   (if (checkdoc-autofix-ask-replace
			p (1+ p)
			"1st line not a complete sentence. Join these lines?"
			" " t)
		       (progn
			 ;; They said yes.  We have more fill work to do...
			 (delete-char 1)
			 (insert "\n")
			 (setq msg nil))))))
	   msg))))
     ;; Continuation of above.  Make sure our sentence is capitalized.
     (save-excursion
       (skip-chars-forward "\"\\*")
       (if (looking-at "[a-z]")
	   (if (checkdoc-autofix-ask-replace
		(match-beginning 0) (match-end 0)
		"Capitalize your sentence?" (upcase (match-string 0))
		t)
	       nil
	     "First line should be capitalized.")
	 nil))
     ;; * For consistency, phrase the verb in the first sentence of a
     ;;   documentation string as an infinitive with "to" omitted.  For
     ;;   instance, use "Return the cons of A and B." in preference to
     ;;   "Returns the cons of A and B."  Usually it looks good to do
     ;;   likewise for the rest of the first paragraph.  Subsequent
     ;;   paragraphs usually look better if they have proper subjects.
     ;;
     ;; For our purposes, just check to first sentence.  A more robust
     ;; grammar checker would be preferred for the rest of the
     ;; documentation string.
     (and checkdoc-verb-check-experimental-flag
	  (save-excursion
	    ;; Maybe rebuild the monster-regex
	    (checkdoc-create-common-verbs-regexp)
	    (let ((lim (save-excursion
			 (end-of-line)
			 ;; check string-continuation
			 (if (checkdoc-char= (preceding-char) ?\\)
			     (progn (forward-line 1)
				    (end-of-line)))
			 (point)))
		  (rs nil) replace original (case-fold-search t))
	      (while (and (not rs)
			  (re-search-forward checkdoc-common-verbs-regexp
					     lim t))
		(setq original (buffer-substring-no-properties
				(match-beginning 1) (match-end 1))
		      rs (assoc (downcase original)
				checkdoc-common-verbs-wrong-voice))
		(if (not rs) (error "Verb voice alist corrupted."))
		(setq replace (let ((case-fold-search nil))
				(save-match-data
				  (if (string-match "^[A-Z]" original)
				      (capitalize (cdr rs))
				    (cdr rs)))))
		(if (checkdoc-autofix-ask-replace
		     (match-beginning 1) (match-end 1)
		     (format "Wrong voice for verb `%s'.  Replace with `%s'?"
			     original replace)
		     replace t)
		    (setq rs nil)))
	      (if rs
		  ;; there was a match, but no replace
		  (format
		   "Incorrect voice in sentence.  Use `%s' instead of `%s'."
		   replace original)))))
     ;;   * Don't write key sequences directly in documentation strings.
     ;;     Instead, use the `\\[...]' construct to stand for them.
     (save-excursion
       (let ((f nil) (m nil) (start (point))
	     (re "[^`A-Za-z0-9_]\\([CMA]-[a-zA-Z]\\|\\(\\([CMA]-\\)?\
mouse-[0-3]\\)\\)\\>"))
	 ;; Find the first key sequence not in a sample
	 (while (and (not f) (setq m (re-search-forward re e t)))
	   (setq f (not (checkdoc-in-sample-code-p start e))))
	 (if m
	     (concat
	      "Keycode " (match-string 1)
	      " embedded in doc-string.  Use \\\\<keymap> & \\\\[function] "
	      "instead"))))
     ;; It is not practical to use `\\[...]' very many times, because
     ;; display of the documentation string will become slow.  So use this
     ;; to describe the most important commands in your major mode, and
     ;; then use `\\{...}' to display the rest of the mode's keymap.
     (save-excursion
       (if (re-search-forward "\\\\\\\\\\[\\w+" e t
			      (1+ checkdoc-max-keyref-before-warn))
	   "Too many occurrences of \\[function].  Use \\{keymap} instead"))
     ;; * Format the documentation string so that it fits in an
     ;;   Emacs window on an 80-column screen.  It is a good idea
     ;;   for most lines to be no wider than 60 characters.  The
     ;;   first line can be wider if necessary to fit the
     ;;   information that ought to be there.
     (save-excursion
       (let ((start (point)))
	 (while (and (< (point) e)
		     (or (progn (end-of-line) (< (current-column) 80))
			 (progn (beginning-of-line)
				(re-search-forward "\\\\\\\\[[<{]"
						   (save-excursion
						     (end-of-line)
						     (point)) t))
			 (checkdoc-in-sample-code-p start e)))
	   (forward-line 1))
	 (end-of-line)
	 (if (and (< (point) e) (> (current-column) 80))
	     "Some lines are over 80 columns wide")))
     ;;* When a documentation string refers to a Lisp symbol, write it as
     ;;  it would be printed (which usually means in lower case), with
     ;;  single-quotes around it.  For example: `lambda'.  There are two
     ;;  exceptions: write t and nil without single-quotes.  (In this
     ;;  manual, we normally do use single-quotes for those symbols.)
     (save-excursion
       (let ((found nil) (start (point)) (msg nil) (ms nil))
	 (while (and (not msg)
		     (re-search-forward
		      "[^([`':]\\(\\w\+[:-]\\(\\w\\|\\s_\\)+\\)[^]']"
		      e t))
	   (setq ms (match-string 1))
	   (save-match-data
	     ;; A . is a \s_ char, so we must remove periods from
	     ;; sentences more carefully.
	     (if (string-match "\\.$" ms)
		 (setq ms (substring ms 0 (1- (length ms))))))
	   (if (and (not (checkdoc-in-sample-code-p start e))
		    (setq found (intern-soft ms))
		    (or (boundp found) (fboundp found)))
	       (progn
		 (setq msg (format "Lisp symbol %s should appear in `quotes'"
				   ms))
		 (if (checkdoc-autofix-ask-replace
		      (match-beginning 1) (+ (match-beginning 1)
					     (length ms))
		      msg (concat "`" ms "'") t)
		     (setq msg nil)))))
	 msg))
     ;; t and nil case
     (save-excursion
       (if (re-search-forward "\\(`\\(t\\|nil\\)'\\)" e t)
	   (if (checkdoc-autofix-ask-replace
		(match-beginning 1) (match-end 1)
		(format "%s should not appear in quotes. Remove?"
			(match-string 2))
		(match-string 2) t)
	       nil
	     "Symbols t and nil should not appear in `quotes'")))
     ;; Here we deviate to tests based on a variable or function.
     (cond ((eq (nth 1 fp) t)
	    ;; This is if we are in a variable
	    (or
	     ;; * The documentation string for a variable that is a
	     ;;   yes-or-no flag should start with words such as "Non-nil
	     ;;   means...", to make it clear that all non-`nil' values are
	     ;;   equivalent and indicate explicitly what `nil' and non-`nil'
	     ;;   mean.
	     ;; * If a user option variable records a true-or-false
	     ;;   condition, give it a name that ends in `-flag'.

	     ;; If the variable has -flag in the name, make sure
	     (if (and (string-match "-flag$" (car fp))
		      (not (looking-at "\"\\*?Non-nil\\s-+means\\s-+")))
		 "Flag variable doc-strings should start: Non-nil means")
	     ;; If the doc-string starts with "Non-nil means"
	     (if (and (looking-at "\"\\*?Non-nil\\s-+means\\s-+")
		      (not (string-match "-flag$" (car fp))))
		 "Flag variables should end in: -flag")
	     ;; Done with variables
	     ))
	   (t
	    ;; This if we are in a function definition
	    (or
	     ;; * When a function's documentation string mentions the value
	     ;;   of an argument of the function, use the argument name in
	     ;;   capital letters as if it were a name for that value.  Thus,
	     ;;   the documentation string of the function `/' refers to its
	     ;;   second argument as `DIVISOR', because the actual argument
	     ;;   name is `divisor'.

	     ;;   Addendum:  Make sure they appear in the doc in the same
	     ;;              order that they are found in the arg list.
	     (let ((args (cdr (cdr (cdr (cdr fp)))))
		   (last-pos 0)
		   (found 1)
		   (order (and (nth 3 fp) (car (nth 3 fp))))
		   (nocheck (append '("&optional" "&rest") (nth 3 fp))))
	       (while (and args found (> found last-pos))
		 (if (member (car args) nocheck)
		     (setq args (cdr args))
		   (setq last-pos found
			 found (save-excursion
				 (re-search-forward
				  (concat "\\<" (upcase (car args))
					  ;; Require whitespace OR
					  ;; ITEMth<space> OR
					  ;; ITEMs<space>
					  "\\(\\>\\|th\\>\\|s\\>\\)")
				  e t)))
		   (if (not found)
		       (let ((case-fold-search t))
			 ;; If the symbol was not found, lets see if we
			 ;; can find it with a different capitalization
			 ;; and see if the user wants to capitalize it.
			 (if (save-excursion
			       (re-search-forward
				  (concat "\\<\\(" (car args)
					  ;; Require whitespace OR
					  ;; ITEMth<space> OR
					  ;; ITEMs<space>
					  "\\)\\(\\>\\|th\\>\\|s\\>\\)")
				  e t))
			     (if (checkdoc-autofix-ask-replace
				  (match-beginning 1) (match-end 1)
				  (format
				   "Argument `%s' should appear as `%s'. Fix?"
				   (car args) (upcase (car args)))
				  (upcase (car args)) t)
				 (setq found (match-beginning 1))))))
		   (if found (setq args (cdr args)))))
	       (if (not found)
		   (format
		    "Argument `%s' should appear as `%s' in the doc-string"
		    (car args) (upcase (car args)))
		 (if (or (and order (eq order 'yes))
			 (and (not order) checkdoc-arguments-in-order-flag))
		     (if (< found last-pos)
			 "Arguments occur in the doc-string out of order"))))
	     ;; Done with functions
	     )))
     ;; Make sure the doc-string has correctly spelled english words
     ;; in it.  This functions is extracted due to it's complexity,
     ;; and reliance on the ispell program.
     (checkdoc-ispell-docstring-engine e)
     ;; User supplied checks
     (save-excursion (checkdoc-run-hooks 'checkdoc-style-hooks fp e))
     ;; Done!
     )))

(defun checkdoc-defun-info nil
  "Return a list of details about the current sexp.
It is a list of the form:
   '( NAME VARIABLE INTERACTIVE NODOCPARAMS PARAMETERS ... )
where NAME is the name, VARIABLE is t if this is a `defvar',
INTERACTIVE is nil if this is not an interactive function, otherwise
it is the position of the `interactive' call, and PARAMETERS is a
string which is the name of each variable in the function's argument
list.  The NODOCPARAMS is a sublist of parameters specified by a checkdoc
comment for a given defun.  If the first element is not a string, then
the token checkdoc-order: <TOKEN> exists, and TOKEN is a symbol read
from the comment."
  (save-excursion
    (beginning-of-defun)
    (let ((defun (looking-at "(def\\(un\\|macro\\|subst\\|advice\\)"))
	  (is-advice (looking-at "(defadvice"))
	  (lst nil)
	  (ret nil)
	  (oo (make-vector 3 0)))	;substitute obarray for `read'
      (forward-char 1)
      (forward-sexp 1)
      (skip-chars-forward " \n\t")
      (setq ret
	    (list (buffer-substring-no-properties
		   (point) (progn (forward-sexp 1) (point)))))
      (if (not defun)
	  (setq ret (cons t ret))
	;; The variable spot
	(setq ret (cons nil ret))
	;; Interactive
	(save-excursion
	  (setq ret (cons
		     (re-search-forward "(interactive"
					(save-excursion (end-of-defun) (point))
					t)
		     ret)))
	(skip-chars-forward " \t\n")
	(let ((bss (buffer-substring (point) (save-excursion (forward-sexp 1)
							     (point))))
	      ;; Overload th main obarray so read doesn't intern the
	      ;; local symbols of the function we are checking.
	      ;; Without this we end up cluttering the symbol space w/
	      ;; useless symbols.
	      (obarray oo))
	  ;; Ok, check for checkdoc parameter comment here
	  (save-excursion
	    (setq ret
		  (cons
		   (let ((sl1 nil))
		     (if (re-search-forward ";\\s-+checkdoc-order:\\s-+"
					    (save-excursion (end-of-defun)
							    (point))
					    t)
			 (setq sl1 (list (cond ((looking-at "nil") 'no)
					       ((looking-at "t") 'yes)))))
		     (if (re-search-forward ";\\s-+checkdoc-params:\\s-+"
					    (save-excursion (end-of-defun)
							    (point))
					    t)
			 (let ((sl nil))
			   (goto-char (match-end 0))
			   (setq lst (read (current-buffer)))
			   (while lst
			     (setq sl (cons (symbol-name (car lst)) sl)
				   lst (cdr lst)))
			   (setq sl1 (append sl1 sl))))
		     sl1)
		   ret)))
	  ;; Read the list of paramters, but do not put the symbols in
	  ;; the standard obarray.
	  (setq lst (read bss)))
	;; This is because read will intern nil if it doesn't into the
	;; new obarray.
	(if (not (listp lst)) (setq lst nil))
	(if is-advice nil
	  (while lst
	    (setq ret (cons (symbol-name (car lst)) ret)
		  lst (cdr lst)))))
      (nreverse ret))))

(defun checkdoc-in-sample-code-p (start limit)
  "Return Non-nil if the current point is in a code-fragment.
A code fragment is identified by an open parenthesis followed by a
symbol which is a valid function, or a parenthesis that is quoted with the '
character.  Only the region from START to LIMIT is is allowed while
searching for the bounding parenthesis."
  (save-match-data
    (save-restriction
      (narrow-to-region start limit)
      (save-excursion
	(and (condition-case nil (progn (up-list 1) t) (error nil))
	     (condition-case nil (progn (forward-list -1) t) (error nil))
	     (or (save-excursion (forward-char -1) (looking-at "'("))
		 (and (looking-at "(\\(\\(\\w\\|[-:_]\\)+\\)[ \t\n;]")
		      (let ((ms (buffer-substring-no-properties
				 (match-beginning 1) (match-end 1))))
			;; if this string is function bound, we are in
			;; sample code.  If it has a - or : character in
			;; the name, then it is probably supposed to be bound
			;; but isn't yet.
			(or (fboundp (intern-soft ms))
			    (string-match "\\w[-:_]+\\w" ms))))))))))

;;; Ispell engine
;;
(eval-when-compile (require 'ispell))

(defun checkdoc-ispell-init ()
  "Initialize ispell process (default version) with lisp words.
The words used are from `checkdoc-ispell-lisp-words'.  If `ispell'
cannot be loaded, then set `checkdoc-spellcheck-documentation-flag' to
nil."
  (require 'ispell)
  (if (not (symbol-value 'ispell-process)) ;Silence byteCompiler
      (condition-case nil
	  (progn
	    (ispell-buffer-local-words)
	    ;; This code copied in part from ispell.el emacs 19.34
	    (let ((w checkdoc-ispell-lisp-words))
	      (while w
		(process-send-string
		 ;;  Silence byte compiler
		 (symbol-value 'ispell-process)
		 (concat "@" (car w) "\n"))
		(setq w (cdr w)))))
	(error (setq checkdoc-spellcheck-documentation-flag nil)))))

(defun checkdoc-ispell-docstring-engine (end)
  "Run the ispell tools on the doc-string between point and END.
Since ispell isn't lisp smart, we must pre-process the doc-string
before using the ispell engine on it."
  (if (not checkdoc-spellcheck-documentation-flag)
      nil
    (checkdoc-ispell-init)
    (save-excursion
      (skip-chars-forward "^a-zA-Z")
      (let ((word nil) (sym nil) (case-fold-search nil) (err nil))
	(while (and (not err) (< (point) end))
	  (if (save-excursion (forward-char -1) (looking-at "[('`]"))
	      ;; Skip lists describing meta-syntax, or bound variables
	      (forward-sexp 1)
	    (setq word (buffer-substring-no-properties
			(point) (progn
				  (skip-chars-forward "a-zA-Z-")
				  (point)))
		  sym (intern-soft word))
	    (if (and sym (or (boundp sym) (fboundp sym)))
		;; This is probably repetative in most cases, but not always.
		nil
	      ;; Find out how we spell-check this word.
	      (if (or
		   ;; All caps w/ option th, or s tacked on the end
		   ;; for pluralization or nuberthness.
		   (string-match "^[A-Z][A-Z]+\\(s\\|th\\)?$" word)
		   (looking-at "}") ; a keymap expression
		   )
		  nil
		(save-excursion
		  (if (not (eq checkdoc-autofix-flag 'never))
		      (let ((lk last-input-event))
			(ispell-word nil t)
			(if (not (equal last-input-event lk))
			    (progn
			      (sit-for 0)
			      (message "Continuing..."))))
		    ;; Nothing here.
		    )))))
	  (skip-chars-forward "^a-zA-Z"))
	err))))

;;; Rogue space checking engine
;;
(defun checkdoc-rogue-space-check-engine (&optional start end)
  "Return a message string if there is a line with white space at the end.
If `checkdoc-autofix-flag' permits, delete that whitespace instead.
If optional arguments START and END are non nil, bound the check to
this region."
  (let ((p (point))
	(msg nil))
    (if (not start) (setq start (point-min)))
    ;; If end is nil, it means end of buffer to search anyway
    (or
     ;; Checkfor and error if `? ' or `?\ ' is used at the end of a line.
     ;; (It's dangerous)
     (progn
       (goto-char start)
       (if (re-search-forward "\\?\\\\?[ \t][ \t]*$" end t)
	   (setq msg
		 "Don't use `? ' at the end of a line. \
Some editors & news agents may remove it")))
     ;; Check for, and pottentially remove whitespace appearing at the
     ;; end of different lines.
     (progn
       (goto-char start)
       ;; There is no documentation in the elisp manual about this check,
       ;; it is intended to help clean up messy code and reduce the file size.
       (while (and (not msg) (re-search-forward "[^ \t\n]\\([ \t]+\\)$" end t))
	 ;; This is not a complex activity
	 (if (checkdoc-autofix-ask-replace
	      (match-beginning 1) (match-end 1)
	      "White space at end of line. Remove?" "")
	     nil
	   (setq msg "White space found at end of line.")))))
    ;; Return an error and leave the cursor at that spot, or restore
    ;; the cursor.
    (if msg
	msg
      (goto-char p)
      nil)))

;;; Comment checking engine
;;
(eval-when-compile
  ;; We must load this to:
  ;; a) get symbols for comple and
  ;; b) determine if we have lm-history symbol which doesn't always exist
  (require 'lisp-mnt))

(defun checkdoc-file-comments-engine ()
  "Return a message string if this file does not match the emacs standard.
This checks for style only, such as the first line, Commentary:,
Code:, and others referenced in the style guide."
  (if (featurep 'lisp-mnt)
      nil
    (require 'lisp-mnt)
    ;; Old Xemacs don't have `lm-commentary-mark'
    (if (and (not (fboundp 'lm-commentary-mark)) (boundp 'lm-commentary))
	(defalias 'lm-commentary-mark 'lm-commentary)))
  (save-excursion
    (let* ((f1 (file-name-nondirectory (buffer-file-name)))
	   (fn (file-name-sans-extension f1))
	   (fe (substring f1 (length fn))))
      (goto-char (point-min))
      (or
       ;; Lisp Maintenance checks first
       ;; Was: (lm-verify) -> not flexible enough for some people
       ;; * Summary at the beginning of the file:
       (if (not (lm-summary))
	   ;; This certifies as very complex so always ask unless
	   ;; it's set to never
	   (if (and checkdoc-autofix-flag
		    (not (eq checkdoc-autofix-flag 'never))
		    (y-or-n-p "There is no first line summary!  Add one?"))
	       (progn
		 (goto-char (point-min))
		 (insert ";;; " fn fe " --- " (read-string "Summary: ") "\n"))
	     "The first line should be of the form: \";;; package --- Summary\"")
	 nil)
       ;; * Commentary Section
       (if (not (lm-commentary-mark))
	   "You should have a section marked \";;; Commentary:\""
	 nil)
       ;; * History section.  Say nothing if there is a file ChangeLog
       (if (or (file-exists-p "ChangeLog")
	       (let ((fn 'lm-history-mark)) ;bestill byte-compiler
		 (and (fboundp fn) (funcall fn))))
	   nil
	 "You should have a section marked \";;; History:\" or use a ChangeLog")
       ;; * Code section
       (if (not (lm-code-mark))
	   (let ((cont t))
	     (goto-char (point-min))
	     (while (and cont (re-search-forward "^(" nil t))
	       (setq cont (looking-at "require\\s-+")))
	     (if (and (not cont)
		      checkdoc-autofix-flag
		      (not (eq checkdoc-autofix-flag 'never))
		      (y-or-n-p "There is no ;;; Code: marker.  Insert one? "))
		 (progn (beginning-of-line)
			(insert ";;; Code:\n")
			nil)
	       "You should have a section marked \";;; Code:\""))
	 nil)
       ;; * A footer.  Not compartamentalized from lm-verify: too bad.
       ;;              The following is partially clipped from lm-verify
       (save-excursion
	 (goto-char (point-max))
	 (if (not (re-search-backward
		   (concat "^;;;[ \t]+" fn "\\(" (regexp-quote fe)
			   "\\)?[ \t]+ends here[ \t]*$"
			   "\\|^;;;[ \t]+ End of file[ \t]+"
			   fn "\\(" (regexp-quote fe) "\\)?")
		   nil t))
	     (if (and checkdoc-autofix-flag
		      (not (eq checkdoc-autofix-flag 'never))
		      (y-or-n-p "No identifiable footer!  Add one?"))
		 (progn
		   (goto-char (point-max))
		   (insert "\n(provide '" fn ")\n;;; " fn fe " ends here\n"))
	       (format "The footer should be (provide '%s)\\n;;; %s%s ends here"
		       fn fn fe))))
       ;; Ok, now lets look for multiple occurances of ;;;, and offer
       ;; to remove the extra ";" if applicable.  This pre-supposes
       ;; that the user has semiautomatic fixing on to be useful.

       ;; In the info node (elisp)Library Headers a header is three ;
       ;; (the header) followed by text of only two ;
       ;; In (elisp)Comment Tips, however it says this:
       ;; * Another use for triple-semicolon comments is for commenting out
       ;;   lines within a function.  We use triple-semicolons for this
       ;;   precisely so that they remain at the left margin.
       (let ((msg nil))
	 (goto-char (point-min))
	 (while (and checkdoc-tripple-semi-comment-check-flag
		     (not msg) (re-search-forward "^;;;[^;]" nil t))
	   ;; We found a triple, lets check all following lines.
	   (if (not (bolp)) (progn (beginning-of-line) (forward-line 1)))
	   (let ((complex-replace t))
	     (while (looking-at ";;\\(;\\)[^;]")
	       (if (and (checkdoc-outside-major-sexp) ;in code is ok.
			(checkdoc-autofix-ask-replace
			 (match-beginning 1) (match-end 1)
			 "Multiple occurances of ;;; found. Use ;; instead?" ""
			 complex-replace))
		   ;; Learn that, yea, the user did want to do this a
		   ;; whole bunch of times.
		   (setq complex-replace nil))
	       (beginning-of-line)
	       (forward-line 1)))))
       ;; Lets spellcheck the commentary section.  This is the only
       ;; section that is easy to pick out, and it is also the most
       ;; visible section (with the finder)
       (save-excursion
	 (goto-char (lm-commentary-mark))
	 ;; Spellcheck between the commentary, and the first
	 ;; non-comment line.  We could use lm-commentary, but that
	 ;; returns a string, and ispell wants to talk to a buffer.
	 ;; Since the comments talk about lisp, use the specialized
	 ;; spell-checker we also used for doc-strings.
	 (checkdoc-ispell-docstring-engine (save-excursion
					     (re-search-forward "^[^;]" nil t)
					     (point))))
;;; test comment out code
;;;       (foo 1 3)
;;;       (bar 5 7)
       ;; Generic Full-file checks (should be comment related)
       (checkdoc-run-hooks 'checkdoc-comment-style-hooks)
       ;; Done with full file comment checks
       ))))

(defun checkdoc-outside-major-sexp ()
  "Return t if point is outside the bounds of a valid sexp."
  (save-match-data
    (save-excursion
      (let ((p (point)))
	(or (progn (beginning-of-defun) (bobp))
	    (progn (end-of-defun) (< (point) p)))))))

;;; Auto-fix helper functions
;;
(defun checkdoc-autofix-ask-replace (start end question replacewith
					   &optional complex)
  "Highlight between START and END and queries the user with QUESTION.
If the user says yes, or if `checkdoc-autofix-flag' permits, replace
the region marked by START and END with REPLACEWITH.  If optional flag
COMPLEX is non-nil, then we may ask the user a question.  See the
documentation for `checkdoc-autofix-flag' for details.

If a section is auto-replaced without asking the user, this function
will pause near the fixed code so the user will briefly see what
happened.

This function returns non-nil if the text was replaced."
  (if checkdoc-autofix-flag
      (let ((o (checkdoc-make-overlay start end))
	    (ret nil))
	(unwind-protect
	    (progn
	      (checkdoc-overlay-put o 'face 'highlight)
	      (if (or (eq checkdoc-autofix-flag 'automatic)
		      (and (eq checkdoc-autofix-flag 'semiautomatic)
			   (not complex))
		      (and (or (eq checkdoc-autofix-flag 'query) complex)
			   (y-or-n-p question)))
		  (save-excursion
		    (goto-char start)
		    ;; On the off chance this is automatic, display
		    ;; the question anyway so the user knows whats
		    ;; going on.
		    (if checkdoc-bouncy-flag (message "%s -> done" question))
		    (delete-region start end)
		    (insert replacewith)
		    (if checkdoc-bouncy-flag (sit-for 0))
		    (setq ret t)))
	      (checkdoc-delete-overlay o))
	  (checkdoc-delete-overlay o))
	ret)))

;;; Warning management
;;
(defvar checkdoc-output-font-lock-keywords
  '(("\\(\\w+\\.el\\):" 1 font-lock-function-name-face)
    ("style check: \\(\\w+\\)" 1 font-lock-comment-face)
    ("^\\([0-9]+\\):" 1 font-lock-constant-face))
  "Keywords used to highlight a checkdoc diagnostic buffer.")

(defvar checkdoc-output-mode-map nil
  "Keymap used in `checkdoc-output-mode'.")

(if checkdoc-output-mode-map
    nil
  (setq checkdoc-output-mode-map (make-sparse-keymap))
  (if (not (string-match "XEmacs" emacs-version))
      (define-key checkdoc-output-mode-map [mouse-2]
	'checkdoc-find-error-mouse))
  (define-key checkdoc-output-mode-map "\C-c\C-c" 'checkdoc-find-error)
  (define-key checkdoc-output-mode-map "\C-m" 'checkdoc-find-error))

(defun checkdoc-output-mode ()
  "Create and setup the buffer used to maintain checkdoc warnings.
\\<checkdoc-output-mode-map>\\[checkdoc-find-error]  - Go to this error location
\\[checkdoc-find-error-mouse] - Goto the error clicked on."
  (if (get-buffer checkdoc-diagnostic-buffer)
      (get-buffer checkdoc-diagnostic-buffer)
    (save-excursion
      (set-buffer (get-buffer-create checkdoc-diagnostic-buffer))
      (kill-all-local-variables)
      (setq mode-name "Checkdoc"
	    major-mode 'checkdoc-output-mode)
      (set (make-local-variable 'font-lock-defaults)
	   '((checkdoc-output-font-lock-keywords) t t ((?- . "w") (?_ . "w"))))
      (use-local-map checkdoc-output-mode-map)
      (run-hooks 'checkdoc-output-mode-hook)
      (current-buffer))))

(defun checkdoc-find-error-mouse (e)
  ;; checkdoc-params: (e)
  "Call `checkdoc-find-error' where the user clicks the mouse."
  (interactive "e")
  (mouse-set-point e)
  (checkdoc-find-error))

(defun checkdoc-find-error ()
  "In a checkdoc diagnostic buffer, find the error under point."
  (interactive)
  (beginning-of-line)
  (if (looking-at "[0-9]+")
      (let ((l (string-to-int (match-string 0)))
	    (f (save-excursion
		 (re-search-backward " \\(\\(\\w+\\|\\s_\\)+\\.el\\):")
		 (match-string 1))))
	(if (not (get-buffer f))
	    (error "Can't find buffer %s" f))
	(switch-to-buffer-other-window (get-buffer f))
	(goto-line l))))

(defun checkdoc-start-section (check-type)
  "Initialize the checkdoc diagnostic buffer for a pass.
Create the header so that the string CHECK-TYPE is displayed as the
function called to create the messages."
  (checkdoc-output-to-error-buffer
   "\n\n*** " (current-time-string) " "
   (file-name-nondirectory (buffer-file-name)) ": style check: " check-type
   " V " checkdoc-version))

(defun checkdoc-error (point msg)
  "Store POINT and MSG as errors in the checkdoc diagnostic buffer."
  (checkdoc-output-to-error-buffer
   "\n" (int-to-string (count-lines (point-min) (or point 1))) ": "
   msg))

(defun checkdoc-output-to-error-buffer (&rest text)
  "Place TEXT into the checkdoc diagnostic buffer."
  (save-excursion
    (set-buffer (checkdoc-output-mode))
    (goto-char (point-max))
    (apply 'insert text)))

(defun checkdoc-show-diagnostics ()
  "Display the checkdoc diagnostic buffer in a temporary window."
  (let ((b (get-buffer checkdoc-diagnostic-buffer)))
    (if b (progn (pop-to-buffer b)
		 (beginning-of-line)))
    (other-window -1)
    (shrink-window-if-larger-than-buffer)))

(defgroup checkdoc nil
  "Support for doc-string checking in emacs lisp."
  :prefix "checkdoc"
  :group 'lisp)

(custom-add-option 'emacs-lisp-mode-hook
		   (lambda () (checkdoc-minor-mode 1)))

(provide 'checkdoc)
;;; checkdoc.el ends here
