;; expand.el --- minor mode to make abbreviations more usable.

;; Copyright (C) 1995, 1996 Free Software Foundation, Inc.

;; Author: Frederic Lepied <Frederic.Lepied@sugix.frmug.org>
;; Maintainer: Frederic Lepied <Frederic.Lepied@sugix.frmug.org>
;; Keywords: abbrev

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
;; This package defines abbrevs which expand into structured constructs
;; for certain languages.  The construct is indented for you,
;; and contains points for you to ;; fill in other text.

;; These abbrevs expand only at the end of a line and when not in a comment
;; or a string.
;;
;;   Look at the Sample: section for emacs-lisp, perl and c expand lists.
;; For example for c-mode, you could declare your abbrev table with :
;;
;; (defconst c-expand-list
;;   '(("if" "if () {\n \n} else {\n \n}" (5 10 21))
;;     ("ifn" "if () {}" (5 8))
;;     ("uns" "unsigned ")
;;     ("for" "for(; ; ) {\n\n}" (5 7 9 13))
;;     ("switch" "switch () {\n\n}" (9 13))
;;     ("case" "case :\n\nbreak;\n" (6 8 16))
;;     ("do" "do {\n\n} while ();" (6 16))
;;     ("while" "while () {\n\n}" (8 12))
;;     ("default" "default:\n\nbreak;" 10)
;;     ("main" "int\nmain(int argc, char * argv[])\n{\n\n}\n" 37))
;;   "Expansions for C mode")
;; 
;;   and enter Expand mode with the following hook :
;;
;; (add-hook 'c-mode-hook (function (lambda ()
;; 				   (expand-add-abbrevs c-mode-abbrev-table c-expand-list)
;; 				   (expand-mode))))
;;
;;   you can also bind jump functions to some keys and init some post-process
;; hooks :
;;
;; (add-hook 'expand-mode-load-hook
;; 	  (function
;; 	   (lambda ()
;; 	     (add-hook 'expand-expand-hook 'indent-according-to-mode)
;; 	     (add-hook 'expand-jump-hook 'indent-according-to-mode)
;; 	     (define-key expand-map '[(control tab)] 'expand-jump-to-next-mark)
;; 	     (define-key expand-map '[(control shift tab)] 'expand-jump-to-previous-mark))))
;;
;; Remarks:
;;
;;   Has been tested under emacs 19.28-19.34 and XEmacs 19.11.
;;   Many thanks to Heddy Boubaker <boubaker@cenatls.cena.dgac.fr>,
;;                  Jerome Santini <santini@chambord.univ-orleans.fr>,
;;                  Jari Aalto <jaalto@tre.tele.nokia.fi>.
;;
;;   Please send me a word to give me your feeling about this mode or
;; to explain me how you use it (your expansions table for example) using
;; the function expand-mode-submit-report.

;; Expand mode is not a replacement for abbrev it is just a layer above it.

;;; Constants:

(defconst expand-mode-version "$Id: expand.el,v 1.1 1996/12/28 19:41:45 rms Exp rms $"
  "Version tag for expand.el.")

(defconst expand-mode-help-address "expand-help@sugix.frmug.org"
  "Email address to send requests, comments or bug reports.")

(defvar expand-mode nil
  "Status variable for Expand mode.")
(make-variable-buffer-local 'expand-mode)

(defvar expand-mode-name " Expand"
  "Name of mode displayed in the modeline for Expand mode.")

(defvar expand-mode-hook nil
  "Hooks run when Expand mode is enabled.")

(defvar expand-mode-load-hook nil
  "Hooks run when expand is loaded.")

(defvar expand-expand-hook nil
  "Hooks run when expansion is done.")

(defvar expand-jump-hook nil
  "Hooks run when jump to mark occurs.")

;;; Samples:

(define-skeleton expand-c-for-skeleton "For loop skeleton"
  "Loop var: "
  "for(" str _ @ "=0; " str @ "; " str @ ") {" \n
  @ _ \n
  "}" >
  )

(defconst expand-c-sample-expand-list
  '(("if" "if () {\n \n} else {\n \n}" (5 10 21))
    ("ifn" "if () {}" (5 8))
    ("uns" "unsigned ")
    ("for" expand-c-for-skeleton)
    ("switch" "switch () {\n\n}" (9 13))
    ("case" "case :\n\nbreak;\n" (6 8 16))
    ("do" "do {\n\n} while ();" (6 16))
    ("while" "while () {\n\n}" (8 12))
    ("default" "default:\n\nbreak;" 10)
    ("main" "int\nmain(int argc, char * argv[])\n{\n\n}\n" 37))
  "Expansions for C mode. See `expand-add-abbrevs'.")

;; lisp example from Jari Aalto <jaalto@tre.tele.nokia.fi>
(defconst expand-sample-lisp-mode-expand-list
  (list
   (list
    "defu"
    (concat
     "(defun   ()\n"
     "  \"\"\n"
     "  (interactive)\n"
     "  (let* (\n"
     "         )\n"
     "    \n"
     "    ))")
    (list 8 11 16 32 43 59))

   (list
    "defs"
    (concat
     "(defsubst   ()\n"
     "  \"\"\n"
     "  (interactive)\n"
     "  )")
    (list 11 14 19 23 39))

   (list
    "defm"
    (concat
     "(defmacro  ()\n"
     "  \"\"\n"
     "  (` \n"
     "    ))")
    (list 11 13 18 25))

   (list
    "defa"
    (concat
     "(defadvice   (around   act)\n"
     "  \"\"\n"
     "  \n"
     "  )")
    (list 12 22 32 36))

    (list
     "defc"
     "(defconst   nil\n  \"\")\n"
     (list 11 13 20))

    (list
     "defv"
     "(defvar   nil\n  \"\")\n"
     (list 9 11 18))

    (list
     "let"
     "(let* (\n)\n    "
     (list 8 13))

     (list
     "sav"
     "(save-excursion\n \n)"
     (list 18))

     (list
     "aut"
     "(autoload ' \"\" t t)\n"
     (list 12 14))

    )
   "Expansions for Lisp mode. See `expand-add-abbrevs'.")
 
;; perl example from Jari Aalto <jaalto@tre.tele.nokia.fi>
(defconst expand-sample-perl-mode-expand-list
  (list
   (list
    ;;   This is default perl4 subroutine template
    ;;
    "sub"
    (concat
     "#" (make-string 70 ?-) "\n"
     "sub   {\n"
     "    # DESCRIPTION\n"
     "    #   \n"
     "    #   \n"
     "    # INPUT\n"
     "    #   \n"
     "    #   \n"
     "    # RETURN\n"
     "    #   \n"
     "\n"
     "    local( $f ) = \"$lib.\";\n"   ;; Function name AFTER period
     "    local() = @_;\n"              ;; func arguments here
     "    \n"
     "    \n}\n"
     )
    (list 77 88 120 146 159 176))

   (list
    "for"                               ; foreach
    (concat
     "for (  )\n"
     "{\n\n\}"
     )
    (list 7 12))

   (list
    "whi"                               ; foreach
    (concat
     "while (  )\n"
     "{\n\n\}"
     )
    (list 9 15))


   ;;   The normal "if" can be used like
   ;;   print $F "xxxxxx"  if defined @arr;
   ;;
   (list
    "iff"
    (concat
     "if (  )\n"
     "{\n\n\}"
     )
    (list 6 12))

   (list "loc"  "local( $ );"   (list 9))
   (list "my"   "my( $ );"      (list 6))
   (list "ope"  "open(,\"\")\t|| die \"$f: Can't open [$]\";" (list 6 8 36))
   (list "clo"  "close ;"       7)
   (list "def"  "defined  "     (list 9))
   (list "und"  "undef ;"       (list 7))

   ;;   There is no ending colon, because they can be in statement
   ;;    defined $REXP_NOT_NEW && (print "xxxxx" );
   ;;
   (list "pr"  "print "         7)
   (list "pf"  "printf "        8)


   (list "gre"  "grep( //, );"  (list 8 11))
   (list "pus"  "push( , );"    (list 7 9))
   (list "joi"  "join( '', );"  (list 7 11))
   (list "rtu"  "return ;"      (list 8))

   )
  "Expansions for Perl mode. See `expand-add-abbrevs'.")

;;; Code:

;;;###autoload
(defun expand-mode (&optional arg)
  "Toggle Expand mode.
With argument ARG, turn Expand mode on if ARG is positive.
In Expand mode, inserting an abbreviation at the end of a line
causes it to expand and be replaced by its expansion."
  (interactive "P")
  (setq expand-mode (if (null arg) (not expand-mode)
		       (> (prefix-numeric-value arg) 0)))
  (if expand-mode
      (progn
	(setq abbrev-mode nil)
	(run-hooks 'expand-mode-hook))))

;;;###autoload
(defvar expand-map (make-sparse-keymap)
  "Key map used in Expand mode.")

(or (assq 'expand-mode minor-mode-alist)
    (setq minor-mode-alist (cons (list 'expand-mode expand-mode-name)
				 minor-mode-alist)))

(or (assq 'expand-mode minor-mode-map-alist)
    (setq minor-mode-map-alist (cons (cons 'expand-mode expand-map)
				     minor-mode-map-alist)))
 
;;;###autoload
(defun expand-add-abbrevs (table abbrevs)
  "Add a list of abbrev to abbrev table TABLE.
ABBREVS is a list of abbrev definitions; each abbrev description entry
has the form (ABBREV EXPANSION ARG).

ABBREV is the abbreviation to replace.

EXPANSION is the replacement string or a function which will make the
expansion.  For example you, could use the DMacros or skeleton packages
to generate such functions.

ARG is an optional argument which can be a number or a list of
numbers.  If ARG is a number, point is placed ARG chars from the
beginning of the expanded text.

If ARG is a list of numbers, point is placed according to the first
member of the list, but you can visit the other specified positions
cyclicaly with the functions `expand-jump-to-previous-mark' and
`expand-jump-to-next-mark'.

If ARG is omitted, point is placed at the end of the expanded text."

  (if (null abbrevs)
      table
    (expand-add-abbrev table (nth 0 (car abbrevs)) (nth 1 (car abbrevs))
		       (nth 2 (car abbrevs)))
    (expand-add-abbrevs table (cdr abbrevs))))

(defvar expand-list nil "Temporary variable used by Expand mode.")

(defvar expand-pos nil
  "If non nil, stores a vector containing markers to positions defined by the last expansion.
This variable is local to a buffer.")
(make-variable-buffer-local 'expand-pos)

(defvar expand-index 0
  "Index of the last marker used in `expand-pos'.
This variable is local to a buffer.")
(make-variable-buffer-local 'expand-index)

(defvar expand-point nil
  "End of the expanded region.
This variable is local to a buffer.")
(make-variable-buffer-local 'expand-point)

(defun expand-add-abbrev (table abbrev expansion arg)
  "Add one abbreviation and provide the hook to move to the specified positions."
  (let* ((string-exp (if (and (symbolp expansion) (fboundp expansion))
			 nil
		       expansion))
         (position   (if (and arg string-exp)
			 (if (listp arg)
			     (- (length expansion) (1- (car arg)))
			   (- (length expansion) (1- arg)))
		       0)))
    (define-abbrev
      table
      abbrev
      (vector string-exp
	      position
	      (if (and (listp arg)
		       (not (null arg)))
		  (cons (length string-exp) arg)
		nil)
	      (if (and (symbolp expansion) (fboundp expansion))
		  expansion
		nil)
	      )
      'expand-abbrev-hook)))

(put 'expand-abbrev-hook 'no-self-insert t)
(defun expand-abbrev-hook ()
  "Abbrev hook used to do the expansion job of expand abbrevs.
See `expand-add-abbrevs'."
  ;; Expand only at the end of a line if we are near a word that has
  ;; an abbrev built from expand-add-abbrev.
  (if (and (eolp)
	   (not (expand-in-literal)))
      (let ((p (point)))
	(setq expand-point nil)
	;; don't expand if the preceding char isn't a word constituent
	(if (and (eq (char-syntax (preceding-char))
		     ?w)
		 (expand-do-expansion))
	    (progn
	      ;; expand-point tells us if we have inserted the text
	      ;; ourself or if it is the hook which has done the job.
	      (if expand-point
		  (progn
		    (if (vectorp expand-list)
			(expand-build-marks expand-point))
		    (indent-region p expand-point nil))
		;; an outside function can set expand-list to a list of
		;; markers in reverse order.
		(if (listp expand-list)
		    (setq expand-index 0
			  expand-pos (expand-list-to-markers expand-list)
			  expand-list nil)))
	      (run-hooks 'expand-expand-hook)
	      t))))
  )

(defun expand-do-expansion ()
  (delete-backward-char (length last-abbrev-text))
  (let* ((vect (symbol-value last-abbrev))
	 (text (aref vect 0))
	 (position (aref vect 1))
	 (jump-args (aref vect 2))
	 (hook (aref vect 3)))
    (cond (text
	   (insert text)
	   (setq expand-point (point))))
    (if jump-args
	(funcall 'expand-build-list (car jump-args) (cdr jump-args)))
    (if position
	(backward-char position))
    (if hook
	(funcall hook))
    t)
  )

(defun expand-abbrev-from-expand (word)
  "Test if an abbrev has a hook."
  (or
   (and (intern-soft word local-abbrev-table)
	(symbol-function (intern-soft word local-abbrev-table)))
   (and (intern-soft word global-abbrev-table)
	(symbol-function (intern-soft word global-abbrev-table)))))

(defun expand-previous-word ()
  "Return the previous word."
  (save-excursion
    (let ((p (point)))
      (backward-word 1)
      (buffer-substring p (point)))))

(defun expand-jump-to-previous-mark ()
  "Move the cursor to previous mark created by the expansion."
  (interactive)
  (if expand-pos
      (progn
	(setq expand-index (1- expand-index))
	(if (< expand-index 0)
	    (setq expand-index (1- (length expand-pos))))
	(goto-char (aref expand-pos expand-index))
	(run-hooks 'expand-jump-hook))))

(defun expand-jump-to-next-mark ()
  "Move the cursor to next mark created by the expansion."
  (interactive)
  (if expand-pos
      (progn
	(setq expand-index (1+ expand-index))
	(if (>= expand-index (length expand-pos))
	    (setq expand-index 0))
	(goto-char (aref expand-pos expand-index))
	(run-hooks 'expand-jump-hook))))

(defun expand-build-list (len l)
  "Build a vector of offset positions from the list of positions."
  (expand-clear-markers)
  (setq expand-list (vconcat l))
  (let ((i 0)
	(lenlist (length expand-list)))
    (while (< i lenlist)
      (aset expand-list i (- len (1- (aref expand-list i))))
      (setq i (1+ i))))
  )

(defun expand-build-marks (p)
  "Transform the offsets vector into a marker vector."
  (if expand-list
      (progn
	(setq expand-index 0)
	(setq expand-pos (make-vector (length expand-list) nil))
	(let ((i (1- (length expand-list))))
	  (while (>= i 0)
	    (aset expand-pos i (copy-marker (- p (aref expand-list i))))
	    (setq i (1- i))))
	(setq expand-list nil))))

(defun expand-clear-markers ()
  "Make the markers point nowhere."
  (if expand-pos
      (progn
    (let ((i (1- (length expand-pos))))
      (while (>= i 0)
	(set-marker (aref expand-pos i) nil)
	(setq i (1- i))))
    (setq expand-pos nil))))

(defun expand-in-literal ()
  "Test if we are in a comment or in a string."
  (save-excursion
    (let* ((lim (or (save-excursion
		      (beginning-of-defun)
		      (point))
		    (point-min)))
	   (here (point))
	   (state (parse-partial-sexp lim (point))))
      (cond
       ((nth 3 state) 'string)
       ((nth 4 state) 'comment)
       (t nil)))))

(defun expand-mode-submit-report ()
  "Report a problem, a suggestion or a comment about Expand mode."
  (interactive)
  (require 'reporter)
  (reporter-submit-bug-report
   expand-mode-help-address
    (concat "expand.el " expand-mode-version)
    '(expand-mode-name
      expand-mode-hook
      expand-mode-load-hook
      expand-map
      )
    nil
    nil
    "Dear expand.el maintainer,"))

;; support functions to add marks to jump from outside function

(defun expand-list-to-markers (l)
  "Transform a list of markers in reverse order into a vector in the correct order."
  (let* ((len (1- (length l)))
	 (loop len)
	 (v (make-vector (+ len 1) nil)))
    (while (>= loop 0)
      (aset v loop (if (markerp (car l)) (car l) (copy-marker (car l))))
      (setq l (cdr l)
	    loop (1- loop)))
    v))

;; integration with skeleton.el
;; Used in `skeleton-end-hook' to fetch the positions for  @ skeleton tags.
;; See `skeleton-insert'.
(defun expand-skeleton-end-hook ()
  (if skeleton-positions
      (setq expand-list skeleton-positions)))
  
(add-hook 'skeleton-end-hook (function expand-skeleton-end-hook))

(provide 'expand)

;; run load hooks
(run-hooks 'expand-mode-load-hook)

;;; expand.el ends here
