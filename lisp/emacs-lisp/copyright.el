;;; copyright.el --- update the copyright notice in current buffer

;; Copyright (C) 1991, 92, 93, 94, 95, 1998 Free Software Foundation, Inc.

;; Author: Daniel Pfeiffer <occitan@esperanto.org>
;; Keywords: maint, tools

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

;; Allows updating the copyright year and above mentioned GPL version manually
;; or when saving a file.  Do (add-hook 'write-file-hooks 'copyright-update).

;;; Code:

(defgroup copyright nil
  "Update the copyright notice in current buffer."
  :group 'tools)

(defcustom copyright-limit 2000
  "*Don't try to update copyright beyond this position unless interactive.
`nil' means to search whole buffer."
  :group 'copyright
  :type '(choice (integer :tag "Limit")
		 (const :tag "No limit")))

;; Cleaner to specify Latin-1 coding for this file, and not use both
;; unibyte and multibyte copyright symbol characters?
(defcustom copyright-regexp
  "\\([\251��]\\|@copyright{}\\|[Cc]opyright\\s *:?\\s *(C)\
\\|[Cc]opyright\\s *:?\\s *[\251��]\\)\
\\s *\\([1-9][-0-9, ']*[0-9]+\\)"
  "*What your copyright notice looks like.
The second \\( \\) construct must match the years."
  :group 'copyright
  :type 'regexp)


(defcustom copyright-query 'function
  "*If non-`nil', ask user before changing copyright.
When this is `function', only ask when called non-interactively."
  :group 'copyright
  :type '(choice (const :tag "Do not ask")
		 (const :tag "Ask unless interactive" function)
		 (other :tag "Ask" t)))


;; when modifying this, also modify the comment generated by autoinsert.el
(defconst copyright-current-gpl-version "2"
  "String representing the current version of the GPL or `nil'.")

(defvar copyright-update t)

;; This is a defvar rather than a defconst, because the year can
;; change during the Emacs session.
(defvar copyright-current-year "2001"
  "String representing the current year.")


;;;###autoload
(defun copyright-update (&optional arg)
  "Update the copyright notice at the beginning of the buffer to indicate
the current year.  If optional prefix ARG is given replace the years in the
notice rather than adding the current year after them.  If necessary and
`copyright-current-gpl-version' is set, the copying permissions following the
copyright, if any, are updated as well."
  (interactive "*P")
  (if copyright-update
      (save-excursion
	(save-restriction
	  (widen)
	  (goto-char (point-min))
	  (setq copyright-current-year (substring (current-time-string) -4))
	  (if (re-search-forward copyright-regexp copyright-limit t)
	      (if (string= (buffer-substring (- (match-end 2) 2) (match-end 2))
			   (substring copyright-current-year -2))
		  ()
		(if (or (not copyright-query)
			(and (eq copyright-query 'function)
			     (eq this-command 'copyright-update))
			(y-or-n-p (if arg
				      (concat "Replace copyright year(s) by "
					      copyright-current-year "? ")
				    (concat "Add " copyright-current-year
					    " to copyright? ")))) 
		    (if arg
			(progn
			  (delete-region (match-beginning 1) (match-end 1))
			  (insert copyright-current-year))
		      (setq arg (save-excursion (skip-chars-backward "0-9")))
		      (if (and (eq (% (- (string-to-number
					  copyright-current-year)
					 (string-to-number (buffer-substring
							    (+ (point) arg)
							    (point))))
				      100)
				   1)
			       (or (eq (char-after (+ (point) arg -1)) ?-)
				   (eq (char-after (+ (point) arg -2)) ?-)))
			  (delete-char arg)
			(insert ", ")
			(if (eq (char-after (+ (point) arg -3)) ?')
			    (insert ?')))
		      (insert (substring copyright-current-year arg))))))
	  (goto-char (point-min))
	  (and copyright-current-gpl-version
	       ;; match the GPL version comment in .el files, including the
	       ;; bilingual Esperanto one in two-column, and in texinfo.tex
	       (re-search-forward "\\(the Free Software Foundation; either \\|; a\\^u eldono \\([0-9]+\\)a, ? a\\^u (la\\^u via	 \\)version \\([0-9]+\\), or (at"
				  copyright-limit t)
	       (not (string= (buffer-substring (match-beginning 3) (match-end 3))
			     copyright-current-gpl-version))
	       (or (not copyright-query)
		   (and (eq copyright-query 'function)
			(eq this-command 'copyright-update))
		   (y-or-n-p (concat "Replace GPL version by "
				     copyright-current-gpl-version "? ")))
	       (progn
		 (if (match-end 2)
		     ;; Esperanto bilingual comment in two-column.el
		     (progn
		       (delete-region (match-beginning 2) (match-end 2))
		       (goto-char (match-beginning 2))
		       (insert copyright-current-gpl-version)))
		 (delete-region (match-beginning 3) (match-end 3))
		 (goto-char (match-beginning 3))
		 (insert copyright-current-gpl-version))))
	(set (make-local-variable 'copyright-update) nil)))
  ;; If a write-file-hook returns non-nil, the file is presumed to be written.
  nil)


;;;###autoload
(define-skeleton copyright
  "Insert a copyright by $ORGANIZATION notice at cursor."
  "Company: "
  comment-start
  "Copyright (C) " `(substring (current-time-string) -4) " by "
  (or (getenv "ORGANIZATION")
      str)
  '(if (> (point) copyright-limit)
       (message "Copyright extends beyond `copyright-limit' and won't be updated automatically."))
  comment-end \n)

(provide 'copyright)

;; For the copyright sign:
;; Local Variables:
;; coding: emacs-mule
;; End:

;;; copyright.el ends here
