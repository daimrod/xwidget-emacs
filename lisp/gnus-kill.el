;;; gnus-kill.el --- kill commands for Gnus

;; Copyright (C) 1995 Free Software Foundation, Inc.

;; Author: Masanobu UMEDA <umerin@flab.flab.fujitsu.junet>
;;	Lars Magne Ingebrigtsen <larsi@ifi.uio.no>
;; Keywords: news

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

;;; Code:

(require 'gnus)

(defvar gnus-kill-file-mode-hook nil
  "*A hook for Gnus kill file mode.")

(defvar gnus-kill-expiry-days 7
  "*Number of days before expiring unused kill file entries.")

(defvar gnus-kill-save-kill-file nil
  "*If non-nil, will save kill files after processing them.")

(defvar gnus-winconf-kill-file nil)



(defmacro gnus-raise (field expression level)
  (` (gnus-kill (, field) (, expression)
		(function (gnus-summary-raise-score (, level))) t)))

(defmacro gnus-lower (field expression level)
  (` (gnus-kill (, field) (, expression)
		(function (gnus-summary-raise-score (- (, level)))) t)))

;;;
;;; Gnus Kill File Mode
;;;

(defvar gnus-kill-file-mode-map nil)

(if gnus-kill-file-mode-map
    nil
  (setq gnus-kill-file-mode-map (copy-keymap emacs-lisp-mode-map))
  (define-key gnus-kill-file-mode-map 
    "\C-c\C-k\C-s" 'gnus-kill-file-kill-by-subject)
  (define-key gnus-kill-file-mode-map
    "\C-c\C-k\C-a" 'gnus-kill-file-kill-by-author)
  (define-key gnus-kill-file-mode-map
    "\C-c\C-k\C-t" 'gnus-kill-file-kill-by-thread)
  (define-key gnus-kill-file-mode-map 
    "\C-c\C-k\C-x" 'gnus-kill-file-kill-by-xref)
  (define-key gnus-kill-file-mode-map
    "\C-c\C-a" 'gnus-kill-file-apply-buffer)
  (define-key gnus-kill-file-mode-map
    "\C-c\C-e" 'gnus-kill-file-apply-last-sexp)
  (define-key gnus-kill-file-mode-map 
    "\C-c\C-c" 'gnus-kill-file-exit))

(defun gnus-kill-file-mode ()
  "Major mode for editing kill files.

If you are using this mode - you probably shouldn't.  Kill files
perform badly and paint with a pretty broad brush.  Score files, on
the other hand, are vastly faster (40x speedup) and give you more
control over what to do.

In addition to Emacs-Lisp Mode, the following commands are available:

\\{gnus-kill-file-mode-map}

  A kill file contains Lisp expressions to be applied to a selected
newsgroup.  The purpose is to mark articles as read on the basis of
some set of regexps.  A global kill file is applied to every newsgroup,
and a local kill file is applied to a specified newsgroup.  Since a
global kill file is applied to every newsgroup, for better performance
use a local one.

  A kill file can contain any kind of Emacs Lisp expressions expected
to be evaluated in the Summary buffer.  Writing Lisp programs for this
purpose is not so easy because the internal working of Gnus must be
well-known.  For this reason, Gnus provides a general function which
does this easily for non-Lisp programmers.

  The `gnus-kill' function executes commands available in Summary Mode
by their key sequences. `gnus-kill' should be called with FIELD,
REGEXP and optional COMMAND and ALL.  FIELD is a string representing
the header field or an empty string.  If FIELD is an empty string, the
entire article body is searched for.  REGEXP is a string which is
compared with FIELD value. COMMAND is a string representing a valid
key sequence in Summary mode or Lisp expression. COMMAND defaults to
'(gnus-summary-mark-as-read nil \"X\").  Make sure that COMMAND is
executed in the Summary buffer.  If the second optional argument ALL
is non-nil, the COMMAND is applied to articles which are already
marked as read or unread.  Articles which are marked are skipped over
by default.

  For example, if you want to mark articles of which subjects contain
the string `AI' as read, a possible kill file may look like:

	(gnus-kill \"Subject\" \"AI\")

  If you want to mark articles with `D' instead of `X', you can use
the following expression:

	(gnus-kill \"Subject\" \"AI\" \"d\")

In this example it is assumed that the command
`gnus-summary-mark-as-read-forward' is assigned to `d' in Summary Mode.

  It is possible to delete unnecessary headers which are marked with
`X' in a kill file as follows:

	(gnus-expunge \"X\")

  If the Summary buffer is empty after applying kill files, Gnus will
exit the selected newsgroup normally.  If headers which are marked
with `D' are deleted in a kill file, it is impossible to read articles
which are marked as read in the previous Gnus sessions.  Marks other
than `D' should be used for articles which should really be deleted.

Entry to this mode calls emacs-lisp-mode-hook and
gnus-kill-file-mode-hook with no arguments, if that value is non-nil."
  (interactive)
  (kill-all-local-variables)
  (use-local-map gnus-kill-file-mode-map)
  (set-syntax-table emacs-lisp-mode-syntax-table)
  (setq major-mode 'gnus-kill-file-mode)
  (setq mode-name "Kill")
  (lisp-mode-variables nil)
  (run-hooks 'emacs-lisp-mode-hook 'gnus-kill-file-mode-hook))

(defun gnus-kill-file-edit-file (newsgroup)
  "Begin editing a kill file for NEWSGROUP.
If NEWSGROUP is nil, the global kill file is selected."
  (interactive "sNewsgroup: ")
  (let ((file (gnus-newsgroup-kill-file newsgroup)))
    (gnus-make-directory (file-name-directory file))
    ;; Save current window configuration if this is first invocation.
    (or (and (get-file-buffer file)
	     (get-buffer-window (get-file-buffer file)))
	(setq gnus-winconf-kill-file (current-window-configuration)))
    ;; Hack windows.
    (let ((buffer (find-file-noselect file)))
      (cond ((get-buffer-window buffer)
	     (pop-to-buffer buffer))
	    ((eq major-mode 'gnus-group-mode)
	     (gnus-configure-windows 'group) ;Take all windows.
	     (pop-to-buffer buffer))
	    ((eq major-mode 'gnus-summary-mode)
	     (gnus-configure-windows 'article)
	     (pop-to-buffer gnus-article-buffer)
	     (bury-buffer gnus-article-buffer)
	     (switch-to-buffer buffer))
	    (t				;No good rules.
	     (find-file-other-window file))))
    (gnus-kill-file-mode)))

;; Fix by Sudish Joseph <joseph@cis.ohio-state.edu>.
(defun gnus-kill-set-kill-buffer ()
  (let* ((file (gnus-newsgroup-kill-file gnus-newsgroup-name))
	 (buffer (find-file-noselect file)))
    (set-buffer buffer)
    (gnus-kill-file-mode)
    (bury-buffer buffer)))

(defun gnus-kill-file-enter-kill (field regexp)
  ;; Enter kill file entry.
  ;; FIELD: String containing the name of the header field to kill.
  ;; REGEXP: The string to kill.
  (save-excursion
    (let (string)
      (or (eq major-mode 'gnus-kill-file-mode)
	  (gnus-kill-set-kill-buffer))
      (current-buffer)
      (goto-char (point-max))
      (insert (setq string (format "(gnus-kill %S %S)\n" field regexp)))
      (gnus-kill-file-apply-string string))))
    
(defun gnus-kill-file-kill-by-subject ()
  "Kill by subject."
  (interactive)
  (gnus-kill-file-enter-kill
   "Subject" 
   (if (vectorp gnus-current-headers)
       (regexp-quote 
	(gnus-simplify-subject (mail-header-subject gnus-current-headers)))
     "")))
  
(defun gnus-kill-file-kill-by-author ()
  "Kill by author."
  (interactive)
  (gnus-kill-file-enter-kill
   "From" 
   (if (vectorp gnus-current-headers)
       (regexp-quote (mail-header-from gnus-current-headers))
     "")))
 
(defun gnus-kill-file-kill-by-thread ()
  "Kill by author."
  (interactive)
  (gnus-kill-file-enter-kill
   "References" 
   (if (vectorp gnus-current-headers)
       (regexp-quote (mail-header-id gnus-current-headers))
     "")))
 
(defun gnus-kill-file-kill-by-xref ()
  "Kill by Xref."
  (interactive)
  (let ((xref (and (vectorp gnus-current-headers) 
		   (mail-header-xref gnus-current-headers)))
	(start 0)
	group)
    (if xref
	(while (string-match " \\([^ \t]+\\):" xref start)
	  (setq start (match-end 0))
	  (if (not (string= 
		    (setq group 
			  (substring xref (match-beginning 1) (match-end 1)))
		    gnus-newsgroup-name))
	      (gnus-kill-file-enter-kill 
	       "Xref" (concat " " (regexp-quote group) ":"))))
      (gnus-kill-file-enter-kill "Xref" ""))))

(defun gnus-kill-file-raise-followups-to-author (level)
  "Raise score for all followups to the current author."
  (interactive "p")
  (let ((name (mail-header-from gnus-current-headers))
	string)
    (save-excursion
      (gnus-kill-set-kill-buffer)
      (goto-char (point-min))
      (setq name (read-string (concat "Add " level
				      " to followup articles to: ")
			      (regexp-quote name)))
      (setq 
       string
       (format
	"(gnus-kill %S %S '(gnus-summary-temporarily-raise-by-thread %S))\n"
	"From" name level))
      (insert string)
      (gnus-kill-file-apply-string string))
    (message "Added temporary score file entry for followups to %s." name)))

(defun gnus-kill-file-apply-buffer ()
  "Apply current buffer to current newsgroup."
  (interactive)
  (if (and gnus-current-kill-article
	   (get-buffer gnus-summary-buffer))
      ;; Assume newsgroup is selected.
      (gnus-kill-file-apply-string (buffer-string))
    (ding) (message "No newsgroup is selected.")))

(defun gnus-kill-file-apply-string (string)
  "Apply STRING to current newsgroup."
  (interactive)
  (let ((string (concat "(progn \n" string "\n)")))
    (save-excursion
      (save-window-excursion
	(pop-to-buffer gnus-summary-buffer)
	(eval (car (read-from-string string)))))))

(defun gnus-kill-file-apply-last-sexp ()
  "Apply sexp before point in current buffer to current newsgroup."
  (interactive)
  (if (and gnus-current-kill-article
	   (get-buffer gnus-summary-buffer))
      ;; Assume newsgroup is selected.
      (let ((string
	     (buffer-substring
	      (save-excursion (forward-sexp -1) (point)) (point))))
	(save-excursion
	  (save-window-excursion
	    (pop-to-buffer gnus-summary-buffer)
	    (eval (car (read-from-string string))))))
    (ding) (message "No newsgroup is selected.")))

(defun gnus-kill-file-exit ()
  "Save a kill file, then return to the previous buffer."
  (interactive)
  (save-buffer)
  (let ((killbuf (current-buffer)))
    ;; We don't want to return to article buffer.
    (and (get-buffer gnus-article-buffer)
	 (bury-buffer gnus-article-buffer))
    ;; Delete the KILL file windows.
    (delete-windows-on killbuf)
    ;; Restore last window configuration if available.
    (and gnus-winconf-kill-file
	 (set-window-configuration gnus-winconf-kill-file))
    (setq gnus-winconf-kill-file nil)
    ;; Kill the KILL file buffer.  Suggested by tale@pawl.rpi.edu.
    (kill-buffer killbuf)))

;; For kill files

(defun gnus-Newsgroup-kill-file (newsgroup)
  "Return the name of a kill file for NEWSGROUP.
If NEWSGROUP is nil, return the global kill file instead."
  (cond ((or (null newsgroup)
	     (string-equal newsgroup ""))
	 ;; The global kill file is placed at top of the directory.
	 (expand-file-name gnus-kill-file-name
			   (or gnus-kill-files-directory "~/News")))
	(gnus-use-long-file-name
	 ;; Append ".KILL" to capitalized newsgroup name.
	 (expand-file-name (concat (gnus-capitalize-newsgroup newsgroup)
				   "." gnus-kill-file-name)
			   (or gnus-kill-files-directory "~/News")))
	(t
	 ;; Place "KILL" under the hierarchical directory.
	 (expand-file-name (concat (gnus-newsgroup-directory-form newsgroup)
				   "/" gnus-kill-file-name)
			   (or gnus-kill-files-directory "~/News")))))

(defun gnus-expunge (marks)
  "Remove lines marked with MARKS."
  (save-excursion
    (set-buffer gnus-summary-buffer)
    (gnus-summary-remove-lines-marked-with marks)))

(defun gnus-apply-kill-file-internal ()
  "Apply a kill file to the current newsgroup.
Returns the number of articles marked as read."
  (let* ((kill-files (list (gnus-newsgroup-kill-file nil)
			   (gnus-newsgroup-kill-file gnus-newsgroup-name)))
	 (unreads (length gnus-newsgroup-unreads))
	 (gnus-summary-inhibit-highlight t)
	 beg)
    (setq gnus-newsgroup-kill-headers nil)
    (or gnus-newsgroup-headers-hashtb-by-number
	(gnus-make-headers-hashtable-by-number))
    ;; If there are any previously scored articles, we remove these
    ;; from the `gnus-newsgroup-headers' list that the score functions
    ;; will see. This is probably pretty wasteful when it comes to
    ;; conses, but is, I think, faster than having to assq in every
    ;; single score function.
    (let ((files kill-files))
      (while files
	(if (file-exists-p (car files))
	    (let ((headers gnus-newsgroup-headers))
	      (if gnus-kill-killed
		  (setq gnus-newsgroup-kill-headers
			(mapcar (lambda (header) (mail-header-number header))
				headers))
		(while headers
		  (or (gnus-member-of-range 
		       (mail-header-number (car headers)) 
		       gnus-newsgroup-killed)
		      (setq gnus-newsgroup-kill-headers 
			    (cons (mail-header-number (car headers))
				  gnus-newsgroup-kill-headers)))
		  (setq headers (cdr headers))))
	      (setq files nil))
 	  (setq files (cdr files)))))
    (if (not gnus-newsgroup-kill-headers)
	()
      (save-window-excursion
	(save-excursion
	  (while kill-files
	    (if (not (file-exists-p (car kill-files)))
		()
	      (message "Processing kill file %s..." (car kill-files))
	      (find-file (car kill-files))
	      (gnus-add-current-to-buffer-list)
	      (goto-char (point-min))

	      (if (consp (condition-case nil (read (current-buffer)) 
			   (error nil)))
		  (gnus-kill-parse-gnus-kill-file)
		(gnus-kill-parse-rn-kill-file))
	    
	      (message "Processing kill file %s...done" (car kill-files)))
	    (setq kill-files (cdr kill-files)))))

      (gnus-set-mode-line 'summary)

      (if beg
	  (let ((nunreads (- unreads (length gnus-newsgroup-unreads))))
	    (or (eq nunreads 0)
		(message "Marked %d articles as read" nunreads))
	    nunreads)
	0))))

;; Parse a Gnus killfile.
(defun gnus-score-insert-help (string alist idx)
  (save-excursion
    (pop-to-buffer "*Score Help*")
    (buffer-disable-undo (current-buffer))
    (erase-buffer)
    (insert string ":\n\n")
    (while alist
      (insert (format " %c: %s\n" (car (car alist)) (nth idx (car alist))))
      (setq alist (cdr alist)))))

(defun gnus-kill-parse-gnus-kill-file ()
  (goto-char (point-min))
  (gnus-kill-file-mode)
  (let (beg form)
    (while (progn 
	     (setq beg (point))
	     (setq form (condition-case () (read (current-buffer))
			  (error nil))))
      (or (listp form)
	  (error "Illegal kill entry (possibly rn kill file?): %s" form))
      (if (or (eq (car form) 'gnus-kill)
	      (eq (car form) 'gnus-raise)
	      (eq (car form) 'gnus-lower))
	  (progn
	    (delete-region beg (point))
	    (insert (or (eval form) "")))
	(save-excursion
	  (set-buffer gnus-summary-buffer)
	  (condition-case () (eval form) (error nil)))))
    (and (buffer-modified-p) 
	 gnus-kill-save-kill-file
	 (save-buffer))
    (set-buffer-modified-p nil)))

;; Parse an rn killfile.
(defun gnus-kill-parse-rn-kill-file ()
  (goto-char (point-min))
  (gnus-kill-file-mode)
  (let ((mod-to-header
	 '((?a . "")
	   (?h . "")
	   (?f . "from")
	   (?: . "subject")))
	(com-to-com
	 '((?m . " ")
	   (?j . "X")))
	pattern modifier commands)
    (while (not (eobp))
      (if (not (looking-at "[ \t]*/\\([^/]*\\)/\\([ahfcH]\\)?:\\([a-z=:]*\\)"))
	  ()
	(setq pattern (buffer-substring (match-beginning 1) (match-end 1)))
	(setq modifier (if (match-beginning 2) (char-after (match-beginning 2))
			 ?s))
	(setq commands (buffer-substring (match-beginning 3) (match-end 3)))

	;; The "f:+" command marks everything *but* the matches as read,
	;; so we simply first match everything as read, and then unmark
	;; PATTERN later. 
	(and (string-match "\\+" commands)
	     (progn
	       (gnus-kill "from" ".")
	       (setq commands "m")))

	(gnus-kill 
	 (or (cdr (assq modifier mod-to-header)) "subject")
	 pattern 
	 (if (string-match "m" commands) 
	     '(gnus-summary-mark-as-unread nil " ")
	   '(gnus-summary-mark-as-read nil "X")) 
	 nil t))
      (forward-line 1))))

;; Kill changes and new format by suggested by JWZ and Sudish Joseph
;; <joseph@cis.ohio-state.edu>.  
(defun gnus-kill (field regexp &optional exe-command all silent)
  "If FIELD of an article matches REGEXP, execute COMMAND.
Optional 1st argument COMMAND is default to
	(gnus-summary-mark-as-read nil \"X\").
If optional 2nd argument ALL is non-nil, articles marked are also applied to.
If FIELD is an empty string (or nil), entire article body is searched for.
COMMAND must be a lisp expression or a string representing a key sequence."
  ;; We don't want to change current point nor window configuration.
  (let ((old-buffer (current-buffer)))
    (save-excursion
      (save-window-excursion
	;; Selected window must be summary buffer to execute keyboard
	;; macros correctly. See command_loop_1.
	(switch-to-buffer gnus-summary-buffer 'norecord)
	(goto-char (point-min))		;From the beginning.
	(let ((kill-list regexp)
	      (date (current-time-string))
	      (command (or exe-command '(gnus-summary-mark-as-read 
					 nil gnus-kill-file-mark)))
	      kill kdate prev)
	  (if (listp kill-list)
	      ;; It is a list.
	      (if (not (consp (cdr kill-list)))
		  ;; It's on the form (regexp . date).
		  (if (zerop (gnus-execute field (car kill-list) 
					   command nil (not all)))
		      (if (> (gnus-days-between date (cdr kill-list))
			     gnus-kill-expiry-days)
			  (setq regexp nil))
		    (setcdr kill-list date))
		(while (setq kill (car kill-list))
		  (if (consp kill)
		      ;; It's a temporary kill.
		      (progn
			(setq kdate (cdr kill))
			(if (zerop (gnus-execute 
				    field (car kill) command nil (not all)))
			    (if (> (gnus-days-between date kdate)
				   gnus-kill-expiry-days)
				;; Time limit has been exceeded, so we
				;; remove the match.
				(if prev
				    (setcdr prev (cdr kill-list))
				  (setq regexp (cdr regexp))))
			  ;; Successful kill. Set the date to today.
			  (setcdr kill date)))
		    ;; It's a permanent kill.
		    (gnus-execute field kill command nil (not all)))
		  (setq prev kill-list)
		  (setq kill-list (cdr kill-list))))
	    (gnus-execute field kill-list command nil (not all))))))
    (switch-to-buffer old-buffer)
    (if (and (eq major-mode 'gnus-kill-file-mode) regexp (not silent))
	(gnus-pp-gnus-kill
	 (nconc (list 'gnus-kill field 
		      (if (consp regexp) (list 'quote regexp) regexp))
		(if (or exe-command all) (list (list 'quote exe-command)))
		(if all (list t) nil))))))

(defun gnus-pp-gnus-kill (object)
  (if (or (not (consp (nth 2 object)))
	  (not (consp (cdr (nth 2 object))))
	  (and (eq 'quote (car (nth 2 object)))
	       (not (consp (cdr (car (cdr (nth 2 object))))))))
      (concat "\n" (prin1-to-string object))
    (save-excursion
      (set-buffer (get-buffer-create "*Gnus PP*"))
      (buffer-disable-undo (current-buffer))
      (erase-buffer)
      (insert (format "\n(%S %S\n  '(" (nth 0 object) (nth 1 object)))
      (let ((klist (car (cdr (nth 2 object))))
	    (first t))
	(while klist
	  (insert (if first (progn (setq first nil) "")  "\n    ")
		  (prin1-to-string (car klist)))
	  (setq klist (cdr klist))))
      (insert ")")
      (and (nth 3 object)
	   (insert "\n  " 
		   (if (and (consp (nth 3 object))
			    (not (eq 'quote (car (nth 3 object))))) 
		       "'" "")
		   (prin1-to-string (nth 3 object))))
      (and (nth 4 object)
	   (insert "\n  t"))
      (insert ")")
      (prog1
	  (buffer-substring (point-min) (point-max))
	(kill-buffer (current-buffer))))))

(defun gnus-execute-1 (function regexp form header)
  (save-excursion
    (let (did-kill)
      (if (null header)
	  nil				;Nothing to do.
	(if function
	    ;; Compare with header field.
	    (let (value)
	      (and header
		   (progn
		     (setq value (funcall function header))
		     ;; Number (Lines:) or symbol must be converted to string.
		     (or (stringp value)
			 (setq value (prin1-to-string value)))
		     (setq did-kill (string-match regexp value)))
		   (if (stringp form)	;Keyboard macro.
		       (execute-kbd-macro form)
		     (funcall form))))
	  ;; Search article body.
	  (let ((gnus-current-article nil) ;Save article pointer.
		(gnus-last-article nil)
		(gnus-break-pages nil)	;No need to break pages.
		(gnus-mark-article-hook nil)) ;Inhibit marking as read.
	    (message "Searching for article: %d..." (mail-header-number header))
	    (gnus-article-setup-buffer)
	    (gnus-article-prepare (mail-header-number header) t)
	    (if (save-excursion
		  (set-buffer gnus-article-buffer)
		  (goto-char (point-min))
		  (setq did-kill (re-search-forward regexp nil t)))
		(if (stringp form)	;Keyboard macro.
		    (execute-kbd-macro form)
		  (eval form))))))
      did-kill)))

(defun gnus-execute (field regexp form &optional backward ignore-marked)
  "If FIELD of article header matches REGEXP, execute lisp FORM (or a string).
If FIELD is an empty string (or nil), entire article body is searched for.
If optional 1st argument BACKWARD is non-nil, do backward instead.
If optional 2nd argument IGNORE-MARKED is non-nil, articles which are
marked as read or ticked are ignored."
  (save-excursion
    (let ((killed-no 0)
	  function article header)
      (if (or (null field) (string-equal field ""))
	  (setq function nil)
	;; Get access function of header filed.
	(setq function (intern-soft (concat "gnus-header-" (downcase field))))
	(if (and function (fboundp function))
	    (setq function (symbol-function function))
	  (error "Unknown header field: \"%s\"" field))
	;; Make FORM funcallable.
	(if (and (listp form) (not (eq (car form) 'lambda)))
	    (setq form (list 'lambda nil form))))
      ;; Starting from the current article.
      (while (or (and (not article)
		      (setq article (gnus-summary-article-number))
		      t)
		 (setq article 
		       (gnus-summary-search-subject 
			backward (not ignore-marked))))
	(and (or (null gnus-newsgroup-kill-headers)
		 (memq article gnus-newsgroup-kill-headers))
	     (vectorp (setq header (gnus-get-header-by-number article)))
	     (gnus-execute-1 function regexp form header)
	     (setq killed-no (1+ killed-no))))
      killed-no)))

