;;; man.el --- browse UNIX manual pages

;; Copyright (C) 1993 Free Software Foundation, Inc.

;; Author:		Barry A. Warsaw <bwarsaw@cen.com>
;; Last-Modified:	31-Jul-1991
;; Version:		1.1
;; Keywords:		help
;; Adapted-By:		ESR

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

;;; Commentary:

;; This code provides a function, manual-entry, with which you can
;; browse UNIX manual pages.  Formatting is done in background so that
;; you can continue to use your Emacs while processing is going on.
;;
;; The mode also supports hypertext-like following of manual page SEE
;; ALSO references, and other features.  See below or do `?' in a
;; manual page buffer for details.

;; ========== Credits and History ========== 
;; In mid 1991, several people posted some interesting improvements to
;; man.el from the standard emacs 18.57 distribution.  I liked many of
;; these, but wanted everthing in one single package, so I decided
;; to encorporate them into a single manual browsing mode.  While
;; much of the code here has been rewritten, and some features added,
;; these folks deserve lots of credit for providing the initial
;; excellent packages on which this one is based.

;; Nick Duffek <duffek@chaos.cs.brandeis.edu>, posted a very nice
;; improvement which retrieved and cleaned the manpages in a
;; background process, and which correctly deciphered such options as
;; man -k.

;; Eric Rose <erose@jessica.stanford.edu>, submitted manual.el which
;; provided a very nice manual browsing mode.

;; This package was available as `superman.el' from the LCD package
;; for some time before it was accepted into Emacs 19.  The entry
;; point and some other names have been changed to make it a drop-in
;; replacement for the old man.el package.

;; ========== Features ==========
;; + Runs "man" in the background and pipes the results through a
;;   series of sed and awk scripts so that all retrieving and cleaning
;;   is done in the background. The cleaning commands are configurable.
;; + Syntax is the same as Un*x man
;; + Functionality is the same as Un*x man, including "man -k" and
;;   "man <section>, etc.
;; + Provides a manual browsing mode with keybindings for traversing
;;   the sections of a manpage, following references in the SEE ALSO
;;   section, and more.
;; + Multiple manpages created with the same man command are put into
;;   a narrowed buffer circular list.

;;; Code:

(require 'assoc)
(provide 'man)

;; vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
;; user variables

(defvar Man-notify 'friendly
  "*Selects the behavior when manpage is ready.
This variable may have one of the following values:

bully      -- make the manpage the current buffer and only window
aggressive -- make the manpage the current buffer in the other window
friendly   -- display manpage in other window but don't make current
polite     -- don't display manpage, but prints message when ready (beeps)
quiet      -- like `polite', but don't beep
meek       -- make no indication that manpage is ready

Any other value of `Man-notify' is equivalent to `meek'.")

(defvar Man-reuse-okay-p t
  "*Reuse a manpage buffer if possible.
When t, and a manpage buffer already exists with the same invocation,
man just indicates the manpage is ready according to the value of
Man-notify. When nil, it always fires off a background process, putting
the results in a uniquely named buffer.")

(defvar Man-downcase-section-letters-p t
  "*Letters in sections are converted to lower case.
Some Un*x man commands can't handle uppercase letters in sections, for
example \"man 2V chmod\", but they are often displayed in the manpage
with the upper case letter. When this variable is t, the section
letter (e.g., \"2V\") is converted to lowercase (e.g., \"2v\") before
being sent to the man background process.")

(defvar Man-circular-pages-p t
  "*If t, the manpage list is treated as circular for traversal.")

(defvar Man-auto-section-alist
  '((c-mode . ("2" "3"))
    (c++-mode . ("2" "3"))
    (shell-mode . ("1" "8"))
    (cmushell-mode . ("1" "8"))
    (text-mode . "1")
    )
  "*Association list of major modes and their default section numbers.
List is of the form: (MAJOR-MODE . [SECTION | (SECTION*)]). If current
major mode is not in list, then the default is to check for manpages
in all sections.")

(defvar Man-section-translations-alist
  '(("3C++" . "3")
    ("1-UCB" . ""))
  "*Association list of bogus sections to real section numbers.
Some manpages (e.g. the Sun C++ 2.1 manpages) have section numbers in
their references which Un*x man(1) does not recognize.  This
association list is used to translate those sections, when found, to
the associated section number.")

(defvar Man-filter-list
  '(("sed "
     ("-e 's/.\010//g'"
      "-e '/[Nn]o such file or directory/d'"
      "-e '/Reformatting page.  Wait... done/d'"
      "-e '/^\\([A-Z][A-Z.]*([0-9A-Za-z][-0-9A-Za-z+]*)\\).*\\1$/d'"
      "-e '/^[ \\t]*Hewlett-Packard Company[ \\t]*- [0-9]* -.*$/d'"
      "-e '/^[ \\t]*Hewlett-Packard[ \\t]*- [0-9]* -.*$/d'"
      "-e '/^ *Page [0-9]*.*(printed [0-9\\/]*)$/d'"
      "-e '/^Printed [0-9].*[0-9]$/d'"
      "-e '/^Sun Microsystems.*Last change:/d'"
      "-e '/^Sun Release [0-9].*[0-9]$/d'"
      "-e '/^\\n$/D'"
      ))
    ("awk '"
     ("BEGIN { blankline=0; anonblank=0; }"
      "/^$/ { if (anonblank==0) next; }"
      "{ anonblank=1; }"
      "/^$/ { blankline++; next; }"
      "{ if (blankline>0) { print \"\"; blankline=0; } print $0; }"
      "'"
      ))
     )
  "*Manpage cleaning filter command phrases.
This variable contains an association list of the following form:

'((command-string (phrase-string*))*)

Each phrase-string is concatenated onto the command-string to form a
command filter. The (standard) output (and standard error) of the Un*x
man command is piped through each command filter in the order the
commands appear in the association list. The final output is placed in
the manpage buffer.")

(defvar Man-mode-line-format
  '("" mode-line-modified
       mode-line-buffer-identification "   "
       global-mode-string
       Man-page-mode-string
       "    %[(" mode-name minor-mode-alist mode-line-process ")%]----"
       (-3 . "%p") "-%-")
  "*Mode line format for manual mode buffer.")

(defvar Man-mode-map nil
  "*Keymap for Man-mode.")

(defvar Man-mode-hooks nil
  "*Hooks for Man-mode.")

(defvar Man-section-regexp "[0-9][a-zA-Z+]*"
  "*Regular expression describing a manpage section within parentheses.")

(defvar Man-heading-regexp "^[A-Z]"
  "*Regular expression describing a manpage heading entry.")

(defvar Man-see-also-regexp "SEE ALSO"
  "*Regular expression for SEE ALSO heading (or your equivalent).
This regexp should not start with a `^' character.")

(defvar Man-first-heading-regexp "^NAME$\\|^No manual entry for .*$"
  "*Regular expression describing first heading on a manpage.
This regular expression should start with a `^' character.")

(defvar Man-reference-regexp "[-a-zA-Z0-9_.]+\\(([0-9][a-zA-Z+]*)\\)?"
  "*Regular expression describing a reference in the SEE ALSO section.")


;; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
;; end user variables

(defconst Man-version-number "1.1"
  "man's version number.")


;; other variables and keymap initializations
(make-variable-buffer-local 'Man-sections-alist)
(make-variable-buffer-local 'Man-refpages-alist)
(make-variable-buffer-local 'Man-page-list)
(make-variable-buffer-local 'Man-current-page)
(make-variable-buffer-local 'Man-page-mode-string)

(setq-default Man-sections-alist nil)
(setq-default Man-refpages-alist nil)
(setq-default Man-page-list nil)
(setq-default Man-current-page 0)
(setq-default Man-page-mode-string "1 (of 1)")

(if Man-mode-map
    nil
  (setq Man-mode-map (make-keymap))
  (suppress-keymap Man-mode-map)
  (define-key Man-mode-map " "    'scroll-up)
  (define-key Man-mode-map "\177" 'scroll-down)
  (define-key Man-mode-map "n"    'Man-next-section)
  (define-key Man-mode-map "p"    'Man-previous-section)
  (define-key Man-mode-map "\en"  'Man-next-manpage)
  (define-key Man-mode-map "\ep"  'Man-previous-manpage)
  (define-key Man-mode-map ","    'beginning-of-buffer)
  (define-key Man-mode-map "."    'end-of-buffer)
  (define-key Man-mode-map "r"    'Man-follow-manual-reference)
  (define-key Man-mode-map "t"    'toggle-truncate-lines)
  (define-key Man-mode-map "g"    'Man-goto-section)
  (define-key Man-mode-map "s"    'Man-goto-see-also-section)
  (define-key Man-mode-map "q"    'Man-quit)
  (define-key Man-mode-map "m"    'manual-entry)
  (define-key Man-mode-map "v"    'Man-version)
  (define-key Man-mode-map "?"    'describe-mode)
  )


;; ======================================================================
;; utilities

(defun Man-page-mode-string ()
  "Formats part of the mode line for manual mode."
  (format "%d (of %d)" Man-current-page (length Man-page-list)))

(defun Man-delete-trailing-newline (str)
  (if (string= (substring str (1- (length str))) "\n")
      (substring str 0 (1- (length str)))
    str))

(defun Man-build-man-command ()
  "Builds the entire background manpage and cleaning command."
  (let ((command "man %s 2>&1 | ")
	(flist Man-filter-list))
    (while flist
      (let ((pcom (car (car flist)))
	    (pargs (car (cdr (car flist)))))
	(setq flist (cdr flist))
	(if (or (not (stringp pcom))
		(not (listp pargs)))
	    (error "malformed Man-filter-list."))
	(setq command (concat command pcom
			      (mapconcat '(lambda (phrase) phrase)
					 pargs " "))))
      (if flist
	  (setq command (concat command " | " ))))
    command))

(defun Man-downcase (man-args)
  "Downcases section letters in MAN-ARGS."
  (let ((newargs "")
	(s 0)
	mstart mend
	(len (length man-args)))
    (while (and (< s len)
		(setq mstart (string-match Man-section-regexp man-args s)))
      (setq mend (match-end 0)
	    newargs (concat newargs (substring man-args s mstart)))
      (setq newargs (concat newargs (downcase
				     (substring man-args mstart mend)))
	    s mend))
    (concat newargs (substring man-args s len))))

(defun Man-translate-references (ref)
  "Translates REF from \"chmod(2V)\" to \"2v chmod\" style."
  (if (string-match (concat "(" Man-section-regexp ")$") ref)
      (let* ((word (progn (string-match "(" ref)
			  (substring ref 0 (1- (match-end 0)))))
	     (section-re (concat "(\\(" Man-section-regexp "\\))"))
	     (section (if (string-match section-re ref)
			  (substring ref (match-beginning 1) (match-end 1))
			""))
	     (slist Man-section-translations-alist)
	     )
	(if Man-downcase-section-letters-p
	    (setq section (Man-downcase section)))
	(while slist
	  (let ((s1 (car (car slist)))
		(s2 (cdr (car slist))))
	    (setq slist (cdr slist))
	    (if Man-downcase-section-letters-p
		(setq s1 (Man-downcase s1)))
	    (if (not (string= s1 section)) nil
	      (setq section (if Man-downcase-section-letters-p
				(Man-downcase s2)
			      s2)
		    slist nil))))
	(concat section " " word))
    ref))

(defun Man-linepos (&optional position col-p)
  "Return the character position at various line/buffer positions.
Preserves the state of point, mark, etc. Optional POSITION can be one
of the following symbols:
     bol == beginning of line
     boi == beginning of indentation
     eol == end of line [default]
     bob == beginning of buffer
     eob == end of buffer

Optional COL-P non-nil returns current-column instead of character position."
  (let ((tpnt (point))
	rval)
    (cond
     ((eq position 'bol) (beginning-of-line))
     ((eq position 'boi) (back-to-indentation))
     ((eq position 'bob) (goto-char (point-min)))
     ((eq position 'eob) (goto-char (point-max)))
     (t (end-of-line)))
    (setq rval (if col-p (current-column) (point)))
    (goto-char tpnt)
    rval))


;; ======================================================================
;; default man entry and get word under point

(defun Man-default-man-args (manword)
  "Build the default man args from MANWORD and major-mode."
  (let ((mode major-mode)
	(slist Man-auto-section-alist))
    (while (and slist
		(not (eq (car (car slist)) mode)))
      (setq slist (cdr slist)))
    (if (not slist)
	manword
      (let ((sections (cdr (car slist))))
	(if (not (listp sections))
	    (concat sections " " manword)
	  (let ((manarg ""))
	    (while sections
	      (setq manarg (concat manarg " " (car sections) " " manword))
	      (setq sections (cdr sections)))
	    manarg)
	  )))))

(defun Man-default-man-entry ()
  "Make a guess at a default manual entry.
This guess is based on the text surrounding the cursor, and the
default section number is selected from Man-auto-section-alist."
  (let ((default-section nil)
	default-title)
    (save-excursion
      
      ;; Default man entry title is any word the cursor is on,
      ;; or if cursor not on a word, then nearest preceding
      ;; word.
      (and (not (looking-at "[a-zA-Z_]"))
	   (skip-chars-backward "^a-zA-Z_"))
      (skip-chars-backward "(a-zA-Z_0-9")
      (and (looking-at "(") (forward-char 1))
      (setq default-title
	    (buffer-substring
	     (point)
	     (progn (skip-chars-forward "a-zA-Z0-9_") (point))))
      
      ;; If looking at something like ioctl(2) or brc(1M), include
      ;; section number in default-entry
      (if (looking-at "[ \t]*([ \t]*[0-9][a-zA-Z]?[ \t]*)")
	  (progn (skip-chars-forward "^0-9")
		 (setq default-section
		       (buffer-substring
			(point)
			(progn
			  (skip-chars-forward "0-9a-zA-Z")
			  (point)))))
	
	;; Otherwise, assume section number to be 2 if we're
	;; in C code
	(and (eq major-mode 'c-mode)
	     (setq default-section "2")))
      (if default-section
	  (format "%s %s" default-section default-title)
	default-title))))
	 

;; ======================================================================
;; top level command and background process sentinel

;;;###autoload
(defun manual-entry (arg)
  "Get a Un*x manual page and put it in a buffer.
This command is the top-level command in the man package. It runs a Un*x
command to retrieve and clean a manpage in the background and places the
results in a Man-mode (manpage browsing) buffer. See variable
Man-notify for what happens when the buffer is ready.
Universal argument ARG, is passed to Man-getpage-in-background."
  (interactive "P")
  (let* ((default-entry (Man-default-man-entry))
	 (man-args
	  (read-string (format "Manual-entry: %s"
			(if (string= default-entry "") ""
			  (format "(default: %s) "
				  default-entry))))))
    (and (string= man-args "")
	 (if (string= default-entry "")
	     (error "No man args given.")
	   (setq man-args default-entry)))
    (if Man-downcase-section-letters-p
	(setq man-args (Man-downcase man-args)))
    (Man-getpage-in-background man-args (consp arg))
    ))

(defun Man-getpage-in-background (man-args &optional override-reuse-p)
  "Uses MAN-ARGS to build and fire off the manpage and cleaning command.
Optional OVERRIDE-REUSE-P, when supplied non-nil forces man to
start a background process even if a buffer already exists and
Man-reuse-okay-p is non-nil."
  (let* ((bufname (concat "*man " man-args "*"))
	 (buffer  (get-buffer bufname)))
    (if (and Man-reuse-okay-p
	     (not override-reuse-p)
	     buffer)
	(Man-notify-when-ready buffer)
      (message "Invoking man %s in background..." man-args)
      (setq buffer (generate-new-buffer bufname))
      (set-process-sentinel
       (start-process "man" buffer "sh" "-c"
		      (format (Man-build-man-command) man-args))
       'Man-bgproc-sentinel))
    ))

(defun Man-notify-when-ready (man-buffer)
  "Notify the user when MAN-BUFFER is ready.
See the variable `Man-notify' for the different notification behaviors."
  (cond
   ((eq Man-notify 'bully)
    (pop-to-buffer man-buffer)
    (delete-other-windows))
   ((eq Man-notify 'aggressive)
    (pop-to-buffer man-buffer))
   ((eq Man-notify 'friendly)
    (display-buffer man-buffer 'not-this-window))
   ((eq Man-notify 'polite)
    (beep)
    (message "Manual buffer %s is ready." (buffer-name man-buffer)))
   ((eq Man-notify 'quiet)
    (message "Manual buffer %s is ready." (buffer-name man-buffer)))
   ((or (eq Man-notify 'meek)
	t)
    (message ""))
   ))

(defun Man-bgproc-sentinel (process msg)
  "Manpage background process sentinel."
  (let ((Man-buffer (process-buffer process))
	(delete-buff nil)
	(err-mess nil))
    (if (null (buffer-name Man-buffer)) ;; deleted buffer
	(set-process-buffer process nil)
      (save-excursion
	(set-buffer Man-buffer)
	(goto-char (point-min))
	(cond ((or (looking-at "No \\(manual \\)*entry for")
		   (looking-at "[^\n]*: nothing appropriate$"))
	       (setq err-mess (buffer-substring (point) (Man-linepos 'eol))
		     delete-buff t)
	       )
	      ((not (and (eq (process-status process) 'exit)
			 (= (process-exit-status process) 0)))
	       (setq err-mess
		     (concat (buffer-name Man-buffer)
			     ": process "
			     (let ((eos (1- (length msg))))
			       (if (= (aref msg eos) ?\n)
				   (substring msg 0 eos) msg))))
	       (goto-char (point-max))
	       (insert (format "\nprocess %s" msg))
	       )))
      (if delete-buff
	  (kill-buffer Man-buffer)
	(save-window-excursion
	  (save-excursion
	    (set-buffer Man-buffer)
	    (Man-mode)
	    (set-buffer-modified-p nil)))
	(Man-notify-when-ready Man-buffer))

      (if err-mess
	  (error err-mess))
      )))


;; ======================================================================
;; set up manual mode in buffer and build alists

(defun Man-mode ()
  "SUPERMAN 1.1: A mode for browsing Un*x manual pages.

The following man commands are available in the buffer. Try
\"\\[describe-key] <key> RET\" for more information:

\\[manual-entry]       Prompt to retrieve a new manpage.
\\[Man-follow-manual-reference]       Retrieve reference in SEE ALSO section.
\\[Man-next-manpage]   Jump to next manpage in circular list.
\\[Man-previous-manpage]   Jump to previous manpage in circular list.
\\[Man-next-section]       Jump to next manpage section.
\\[Man-previous-section]       Jump to previous manpage section.
\\[Man-goto-section]       Go to a manpage section.
\\[Man-goto-see-also-section]       Jumps to the SEE ALSO manpage section.
\\[Man-quit]       Deletes the manpage, its buffer, and window.
\\[Man-version]       Prints man's version number.
\\[describe-mode]       Prints this help text.

The following variables may be of some use. Try
\"\\[describe-variable] <variable-name> RET\" for more information:

Man-notify                      What happens when manpage formatting is done.
Man-reuse-okay-p                Okay to reuse already formatted buffer?
Man-downcase-section-letters-p  Force section letters to lower case?
Man-circular-pages-p            Multiple manpage list treated as circular?
Man-auto-section-alist          List of major modes and their section numbers.
Man-section-translations-alist  List of section numbers and their Un*x equiv.
Man-filter-list                 Background manpage filter command.
Man-mode-line-format            Mode line format for Man-mode buffers.
Man-mode-map                    Keymap bindings for Man-mode buffers.
Man-mode-hooks                  Hooks for Man-mode.
Man-section-regexp              Regexp describing manpage section letters.
Man-heading-regexp              Regexp describing section headers.
Man-see-also-regexp             Regexp for SEE ALSO section (or your equiv).
Man-first-heading-regexp        Regexp for first heading on a manpage.
Man-reference-regexp            Regexp matching a references in SEE ALSO.
Man-version-number              Superman version number.

The following key bindings are currently in effect in the buffer:
\\{Man-mode-map}"
  (interactive)
  (setq major-mode 'Man-mode
	mode-name "Manual"
	buffer-auto-save-file-name nil
	mode-line-format Man-mode-line-format
	truncate-lines t
	buffer-read-only t)
  (buffer-disable-undo (current-buffer))
  (auto-fill-mode -1)
  (use-local-map Man-mode-map)
  (goto-char (point-min))
  (Man-build-page-list)
  (Man-goto-page 1)
  (run-hooks 'Man-mode-hook))

(defun Man-build-section-alist ()
  "Build the association list of manpage sections."
  (setq Man-sections-alist nil)
  (goto-char (point-min))
  (while (re-search-forward Man-heading-regexp (point-max) t)
    (aput 'Man-sections-alist
	  (buffer-substring (Man-linepos 'bol) (Man-linepos)))
    (forward-line 1)
    ))

(defun Man-build-references-alist ()
  "Build the association list of references (in the SEE ALSO section)."
  (setq Man-refpages-alist nil)
  (save-excursion
    (if (Man-find-section Man-see-also-regexp)
	(let ((start (progn (forward-line 1) (point)))
	      (end (progn
		     (Man-next-section 1)
		     (point)))
	      hyphenated
	      (runningpoint -1))
	  (narrow-to-region start end)
	  (goto-char (point-min))
	  (back-to-indentation)
	  (while (and (not (eobp)) (/= (point) runningpoint))
	    (setq runningpoint (point))
	    (let* ((bow (point))
		   (eow (re-search-forward Man-reference-regexp end t))
		   (word (buffer-substring bow (match-end 0)))
		   (len (1- (length word))))
	      (if (not eow) nil
		(if hyphenated
		    (setq word (concat hyphenated word)
			  hyphenated nil))
		(if (= (aref word len) ?-)
		    (setq hyphenated (substring word 0 len))
		  (aput 'Man-refpages-alist word))))
	    (skip-chars-forward " \t\n,"))
	  ))))

(defun Man-build-page-list ()
  "Build the list of separate manpages in the buffer."
  (setq Man-page-list nil)
  (save-excursion
    (let ((page-start (Man-linepos 'bob))
	  (page-end (Man-linepos 'eob))
	  (regexp Man-first-heading-regexp))
      (goto-char (point-min))
      (re-search-forward regexp (point-max) t)
      (while (not (eobp))
	(if (re-search-forward regexp (point-max) t)
	    (progn
	      (setq page-end (Man-linepos 'bol))
	      (end-of-line))
	  (goto-char (point-max))
	  (setq page-end (point)))
	(setq Man-page-list (append Man-page-list
				   (list (cons page-start page-end)))
	      page-start page-end)
	))))  


;; ======================================================================
;; Man-mode commands

(defun Man-next-section (n)
  "Move point to Nth next section (default 1)."
  (interactive "p")
  (if (looking-at Man-heading-regexp)
      (forward-line 1))
  (if (re-search-forward Man-heading-regexp (point-max) t n)
      (beginning-of-line)
    (goto-char (point-max))))

(defun Man-previous-section (n)
  "Move point to Nth previous section (default 1)."
  (interactive "p")
  (if (looking-at Man-heading-regexp)
      (forward-line -1))
  (if (re-search-backward Man-heading-regexp (point-min) t n)
      (beginning-of-line)
    (goto-char (point-min))))

(defun Man-find-section (section)
  "Move point to SECTION if it exists, otherwise don't move point.
Returns t if section is found, nil otherwise."
  (let ((curpos (point)))
    (goto-char (point-min))
    (if (re-search-forward (concat "^" section) (point-max) t)
	(progn (beginning-of-line) t)
      (goto-char curpos)
      nil)
    ))

(defun Man-goto-section ()
  "Query for section to move point to."
  (interactive)
  (aput 'Man-sections-alist
	(let* ((default (aheadsym Man-sections-alist))
	       (completion-ignore-case t)
	       chosen
	       (prompt (concat "Go to section: (default " default ") ")))
	  (setq chosen (completing-read prompt Man-sections-alist))
	  (if (or (not chosen)
		  (string= chosen ""))
	      default
	    chosen)))
  (Man-find-section (aheadsym Man-sections-alist)))

(defun Man-goto-see-also-section ()
  "Move point the the \"SEE ALSO\" section.
Actually the section moved to is described by Man-see-also-regexp."
  (interactive)
  (if (not (Man-find-section Man-see-also-regexp))
      (error (concat "No " Man-see-also-regexp
		     " section found in current manpage."))))

(defun Man-follow-manual-reference (arg)
  "Get one of the manpages referred to in the \"SEE ALSO\" section.
Queries you for the page to retrieve. Of course it does this in the
background. Universal argument ARG is passed to Man-getpage-in-background."
  (interactive "P")
  (if (not Man-refpages-alist)
      (error (concat "No references found in current manpage."))
    (aput 'Man-refpages-alist
	  (let* ((default (aheadsym Man-refpages-alist))
		 chosen
		 (prompt (concat "Refer to: (default " default ") ")))
	    (setq chosen (completing-read prompt Man-refpages-alist nil t))
	    (if (or (not chosen)
		    (string= chosen ""))
		default
	      chosen)))
    (Man-getpage-in-background
     (Man-translate-references (aheadsym Man-refpages-alist))
     (consp arg))))

(defun Man-quit ()
  "Kill the buffer containing the manpage."
  (interactive)
  (let ((buff (current-buffer)))
    (delete-windows-on buff)
    (kill-buffer buff)))

(defun Man-goto-page (page)
  "Go to the manual page on page PAGE."
  (interactive
   (if (not Man-page-list)
       (error "You're looking at the only manpage in the buffer.")
     (format "nGo to manpage [1-%d]: " (length Man-page-list))))
  (if (or (< page 1)
	  (> page (length Man-page-list)))
      (error "No manpage %d found" page))
  (let* ((page-range (nth (1- page) Man-page-list))
	 (page-start (car page-range))
	 (page-end (cdr page-range)))
    (setq Man-current-page page
	  Man-page-mode-string (Man-page-mode-string))
    (widen)
    (goto-char page-start)
    (narrow-to-region page-start page-end)
    (Man-build-section-alist)
    (Man-build-references-alist)
    (widen)
    (narrow-to-region page-start page-end)
    (goto-char (point-min))))


(defun Man-next-manpage ()
  "Find the next manpage entry in the buffer."
  (interactive)
  (if (= (length Man-page-list) 1)
      (error "This is the only manpage in the buffer."))
  (if (< Man-current-page (length Man-page-list))
      (Man-goto-page (1+ Man-current-page))
    (if Man-circular-pages-p
	(Man-goto-page 1)
      (error "You're looking at the last manpage in the buffer."))))

(defun Man-previous-manpage ()
  "Find the previous manpage entry in the buffer."
  (interactive)
  (if (= (length Man-page-list) 1)
      (error "This is the only manpage in the buffer."))
  (if (> Man-current-page 1)
      (Man-goto-page (1- Man-current-page))
    (if Man-circular-pages-p
	(Man-goto-page (length Man-page-list))
      (error "You're looking at the first manpage in the buffer."))))

(defun Man-version (arg)
  "Show man's version.
Universal argument (\\[universal-argument]) ARG inserts version
information in the current buffer instead of printing the message in
the echo area."
  (interactive "P")
  (if (consp arg)
      (insert "Using Superman version " Man-version-number ".")
    (message "Using Superman version %s." Man-version-number)))

;;; man.el ends here
