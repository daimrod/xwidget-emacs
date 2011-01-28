;;; copyright.el --- update the copyright notice in current buffer

;; Copyright (C) 1991-1995, 1998, 2001-2011  Free Software Foundation, Inc.

;; Author: Daniel Pfeiffer <occitan@esperanto.org>
;; Keywords: maint, tools

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Allows updating the copyright year and above mentioned GPL version manually
;; or when saving a file.
;; Do (add-hook 'before-save-hook 'copyright-update), or use
;; M-x customize-variable RET before-save-hook RET.

;;; Code:

(defgroup copyright nil
  "Update the copyright notice in current buffer."
  :group 'tools)

(defcustom copyright-limit 2000
  "Don't try to update copyright beyond this position unless interactive.
A value of nil means to search whole buffer."
  :group 'copyright
  :type '(choice (integer :tag "Limit")
		 (const :tag "No limit")))

(defcustom copyright-at-end-flag nil
  "Non-nil means to search backwards from the end of the buffer for copyright.
This is useful for ChangeLogs."
  :group 'copyright
  :type 'boolean
  :version "23.1")
;;;###autoload(put 'copyright-at-end-flag 'safe-local-variable 'booleanp)

(defcustom copyright-regexp
 "\\(©\\|@copyright{}\\|[Cc]opyright\\s *:?\\s *\\(?:(C)\\)?\
\\|[Cc]opyright\\s *:?\\s *©\\)\
\\s *\\(?:[^0-9\n]*\\s *\\)?\
\\([1-9]\\([-0-9, ';/*%#\n\t]\\|\\s<\\|\\s>\\)*[0-9]+\\)"
  "What your copyright notice looks like.
The second \\( \\) construct must match the years."
  :group 'copyright
  :type 'regexp)

(defcustom copyright-names-regexp ""
  "Regexp matching the names which correspond to the user.
Only copyright lines where the name matches this regexp will be updated.
This allows you to avoid adding years to a copyright notice belonging to
someone else or to a group for which you do not work."
  :group 'copyright
  :type 'regexp)

;; The worst that can happen is a malicious regexp that overflows in
;; the regexp matcher, a minor nuisance.  It's a pain to be always
;; prompted if you want to put this in a dir-locals.el.
;;;###autoload(put 'copyright-names-regexp 'safe-local-variable 'stringp)

(defcustom copyright-years-regexp
 "\\(\\s *\\)\\([1-9]\\([-0-9, ';/*%#\n\t]\\|\\s<\\|\\s>\\)*[0-9]+\\)"
  "Match additional copyright notice years.
The second \\( \\) construct must match the years."
  :group 'copyright
  :type 'regexp)

;; See "Copyright Notices" in maintain.info.
;; TODO? 'end only for ranges at the end, other for all ranges.
;; Minimum limit on the size of a range?
(defcustom copyright-year-ranges nil
  "Non-nil if individual consecutive years should be replaced with a range.
For example: 2005, 2006, 2007, 2008 might be replaced with 2005-2008.
If you use ranges, you should add an explanatory note in a README file.
The function `copyright-fix-year' respects this variable."
  :group 'copyright
  :type 'boolean
  :version "24.1")

;;;###autoload(put 'copyright-year-ranges 'safe-local-variable 'booleanp)

(defcustom copyright-query 'function
  "If non-nil, ask user before changing copyright.
When this is `function', only ask when called non-interactively."
  :group 'copyright
  :type '(choice (const :tag "Do not ask")
		 (const :tag "Ask unless interactive" function)
		 (other :tag "Ask" t)))


;; when modifying this, also modify the comment generated by autoinsert.el
(defconst copyright-current-gpl-version "3"
  "String representing the current version of the GPL or nil.")

(defvar copyright-update t
  "The function `copyright-update' sets this to nil after updating a buffer.")

;; This is a defvar rather than a defconst, because the year can
;; change during the Emacs session.
(defvar copyright-current-year (substring (current-time-string) -4)
  "String representing the current year.")

(defsubst copyright-limit ()            ; re-search-forward BOUND
  (and copyright-limit
       (if copyright-at-end-flag
	   (- (point) copyright-limit)
	 (+ (point) copyright-limit))))

(defun copyright-re-search (regexp &optional bound noerror count)
  "Re-search forward or backward depending on `copyright-at-end-flag'."
  (if copyright-at-end-flag
      (re-search-backward regexp bound noerror count)
    (re-search-forward regexp bound noerror count)))

(defun copyright-start-point ()
  "Return point-min or point-max, depending on `copyright-at-end-flag'."
  (if copyright-at-end-flag
      (point-max)
    (point-min)))

(defun copyright-offset-too-large-p ()
  "Return non-nil if point is too far from the edge of the buffer."
  (when copyright-limit
    (if copyright-at-end-flag
	(< (point) (- (point-max) copyright-limit))
      (> (point) (+ (point-min) copyright-limit)))))

(defun copyright-find-copyright ()
  "Return non-nil if a copyright header suitable for updating is found.
The header must match `copyright-regexp' and `copyright-names-regexp', if set.
This function sets the match-data that `copyright-update-year' uses."
  (widen)
  (goto-char (copyright-start-point))
  (condition-case err
      ;; (1) Need the extra \\( \\) around copyright-regexp because we
      ;; goto (match-end 1) below. See note (2) below.
      (copyright-re-search (concat "\\(" copyright-regexp
				   "\\)\\([ \t]*\n\\)?.*\\(?:"
				   copyright-names-regexp "\\)")
			   (copyright-limit)
			   t)
    ;; In case the regexp is rejected.  This is useful because
    ;; copyright-update is typically called from before-save-hook where
    ;; such an error is very inconvenient for the user.
    (error (message "Can't update copyright: %s" err) nil)))

(defun copyright-find-end ()
  "Possibly adjust the search performed by `copyright-find-copyright'.
If the years continue onto multiple lines that are marked as comments,
skips to the end of all the years."
  (while (save-excursion
	   (and (eq (following-char) ?,)
		(progn (forward-char 1) t)
		(progn (skip-chars-forward " \t") (eolp))
		comment-start-skip
		(save-match-data
		  (forward-line 1)
		  (and (looking-at comment-start-skip)
		       (goto-char (match-end 0))))
		(looking-at-p copyright-years-regexp)))
    (forward-line 1)
    (re-search-forward comment-start-skip)
    ;; (2) Need the extra \\( \\) so that the years are subexp 3, as
    ;; they are at note (1) above.
    (re-search-forward (format "\\(%s\\)" copyright-years-regexp))))

(defun copyright-update-year (replace noquery)
  ;; This uses the match-data from copyright-find-copyright/end.
  (goto-char (match-end 1))
  (copyright-find-end)
  ;; Note that `current-time-string' isn't locale-sensitive.
  (setq copyright-current-year (substring (current-time-string) -4))
  (unless (string= (buffer-substring (- (match-end 3) 2) (match-end 3))
		   (substring copyright-current-year -2))
    (if (or noquery
	    (save-window-excursion
	      (switch-to-buffer (current-buffer))
	      ;; Fixes some point-moving oddness (bug#2209).
	      (save-excursion
		(y-or-n-p (if replace
			      (concat "Replace copyright year(s) by "
				      copyright-current-year "? ")
			    (concat "Add " copyright-current-year
				    " to copyright? "))))))
	(if replace
	    (replace-match copyright-current-year t t nil 3)
	  (let ((size (save-excursion (skip-chars-backward "0-9"))))
	    (if (and (eq (% (- (string-to-number copyright-current-year)
			       (string-to-number (buffer-substring
						  (+ (point) size)
						  (point))))
			    100)
			 1)
		     (or (eq (char-after (+ (point) size -1)) ?-)
			 (eq (char-after (+ (point) size -2)) ?-)))
		;; This is a range so just replace the end part.
		(delete-char size)
	      ;; Insert a comma with the preferred number of spaces.
	      (insert
	       (save-excursion
		 (if (re-search-backward "[0-9]\\( *, *\\)[0-9]"
					 (line-beginning-position) t)
		     (match-string 1)
		   ", ")))
	      ;; If people use the '91 '92 '93 scheme, do that as well.
	      (if (eq (char-after (+ (point) size -3)) ?')
		  (insert ?')))
	    ;; Finally insert the new year.
	    (insert (substring copyright-current-year size)))))))

;;;###autoload
(defun copyright-update (&optional arg interactivep)
  "Update copyright notice to indicate the current year.
With prefix ARG, replace the years in the notice rather than adding
the current year after them.  If necessary, and
`copyright-current-gpl-version' is set, any copying permissions
following the copyright are updated as well.
If non-nil, INTERACTIVEP tells the function to behave as when it's called
interactively."
  (interactive "*P\nd")
  (when (or copyright-update interactivep)
    (let ((noquery (or (not copyright-query)
		       (and (eq copyright-query 'function) interactivep))))
      (save-excursion
	(save-restriction
	  ;; If names-regexp doesn't match, we should not mess with
	  ;; the years _or_ the GPL version.
	  ;; TODO there may be multiple copyrights we should update.
	  (when (copyright-find-copyright)
	    (copyright-update-year arg noquery)
	    (goto-char (copyright-start-point))
	    (and copyright-current-gpl-version
		 ;; Match the GPL version comment in .el files.
		 ;; This is sensitive to line-breaks. :(
		 (copyright-re-search
		  "the Free Software Foundation[,;\n].*either version \
\\([0-9]+\\)\\(?: of the License\\)?, or[ \n].*any later version"
		  (copyright-limit) t)
		 ;; Don't update if the file is already using a more recent
		 ;; version than the "current" one.
		 (< (string-to-number (match-string 1))
		    (string-to-number copyright-current-gpl-version))
		 (or noquery
		     (save-match-data
		       (goto-char (match-end 1))
		       (save-window-excursion
			 (switch-to-buffer (current-buffer))
			 (y-or-n-p
			  (format "Replace GPL version %s with version %s? "
				  (match-string-no-properties 1)
				  copyright-current-gpl-version)))))
		 (replace-match copyright-current-gpl-version t t nil 1))))
	(set (make-local-variable 'copyright-update) nil)))
    ;; If a write-file-hook returns non-nil, the file is presumed to be written.
    nil))


;; FIXME heuristic should be within 50 years of present (cf calendar).
;;;###autoload
(defun copyright-fix-years ()
  "Convert 2 digit years to 4 digit years.
Uses heuristic: year >= 50 means 19xx, < 50 means 20xx.
If `copyright-year-ranges' (which see) is non-nil, also
independently replaces consecutive years with a range."
  (interactive)
  ;; TODO there may be multiple copyrights we should fix.
  (if (copyright-find-copyright)
      (let ((s (match-beginning 3))
	    (p (make-marker))
	    ;; Not line-beg-pos, so we don't mess up leading whitespace.
	    (copystart (match-beginning 0))
	    e last sep year prev-year first-year range-start range-end)
	;; In case years are continued over multiple, commented lines.
	(goto-char (match-end 1))
	(copyright-find-end)
	(setq e (copy-marker (1+ (match-end 3))))
	(goto-char s)
	(while (re-search-forward "[0-9]+" e t)
	  (set-marker p (point))
	  (goto-char (match-beginning 0))
	  (setq year (string-to-number (match-string 0)))
	  (and (setq sep (char-before))
	       (/= (char-syntax sep) ?\s)
	       (/= sep ?-)
	       (insert " "))
	  (when (< year 100)
	    (insert (if (>= year 50) "19" "20"))
	    (setq year (+ year (if (>= year 50) 1900 2000))))
	  (goto-char p)
	  (when copyright-year-ranges
	    ;; If the previous thing was a range, don't try to tack more on.
	    ;; Ie not 2000-2005 -> 2000-2005-2007
	    ;; TODO should merge into existing range if possible.
	    (if (eq sep ?-)
		(setq prev-year nil
		      year nil)
	      (if (and prev-year (= year (1+ prev-year)))
		  (setq range-end (point))
		(when (and first-year prev-year
			   (> prev-year first-year))
		  (goto-char range-end)
		  (delete-region range-start range-end)
		  (insert (format "-%d" prev-year))
		  (goto-char p))
		(setq first-year year
		      range-start (point)))))
	  (setq prev-year year
		last p))
	(when last
	  (when (and copyright-year-ranges
		     first-year prev-year
		     (> prev-year first-year))
	    (goto-char range-end)
	    (delete-region range-start range-end)
	    (insert (format "-%d" prev-year)))
	  (goto-char last)
	  ;; Don't mess up whitespace after the years.
	  (skip-chars-backward " \t")
	   (save-restriction
	     (narrow-to-region copystart (point))
	     ;; This is clearly wrong, eg what about comment markers?
 ;;;	    (let ((fill-prefix "     "))
	     ;; TODO do not break copyright owner over lines.
	     (fill-region (point-min) (point-max))))
	(set-marker e nil)
	(set-marker p nil))
    ;; Simply reformatting the years is not copyrightable, so it does
    ;; not seem right to call this.  Also it messes with ranges.
;;;	(copyright-update nil t))
    (message "No copyright message")))

;;;###autoload
(define-skeleton copyright
  "Insert a copyright by $ORGANIZATION notice at cursor."
  "Company: "
  comment-start
  "Copyright (C) " `(substring (current-time-string) -4) " by "
  (or (getenv "ORGANIZATION")
      str)
  '(if (copyright-offset-too-large-p)
       (message "Copyright extends beyond `copyright-limit' and won't be updated automatically."))
  comment-end \n)

;; TODO: recurse, exclude COPYING etc.
;;;###autoload
(defun copyright-update-directory (directory match &optional fix)
  "Update copyright notice for all files in DIRECTORY matching MATCH.
If FIX is non-nil, run `copyright-fix-years' instead."
  (interactive "DDirectory: \nMFilenames matching (regexp): ")
  (dolist (file (directory-files directory t match nil))
    (unless (file-directory-p file)
      (message "Updating file `%s'" file)
      (find-file file)
      (let ((inhibit-read-only t)
	    (enable-local-variables :safe)
	    copyright-query)
	(if fix
	    (copyright-fix-years)
	  (copyright-update)))
      (save-buffer)
      (kill-buffer (current-buffer)))))

(provide 'copyright)

;; For the copyright sign:
;; Local Variables:
;; coding: utf-8
;; End:

;;; copyright.el ends here
