;;; time-stamp.el --- Maintain last change time stamps in files edited by Emacs

;; Copyright 1989, 1993, 1994, 1995 Free Software Foundation, Inc.

;; Maintainer's Time-stamp: <1997-04-28 11:51:22 gildea>
;; Maintainer: Stephen Gildea <gildea@alum.mit.edu>
;; Keywords: tools

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; A template in a file can be updated with a new time stamp when
;; you save the file.  For example:
;;     static char *ts = "sdmain.c Time-stamp: <1996-08-13 10:20:51 gildea>";
;; See the top of `time-stamp.el' for another example.

;; To use time-stamping, add this line to your .emacs file:
;;     (add-hook 'write-file-hooks 'time-stamp)
;; Now any time-stamp templates in your files will be updated automatically.

;; See the documentation for the functions `time-stamp'
;; and `time-stamp-toggle-active' for details.

;;; Code:

(defgroup time-stamp nil
  "Maintain last change time stamps in files edited by Emacs."
  :group 'data
  :group 'extensions)

(defcustom time-stamp-active t
  "*Non-nil to enable time-stamping of buffers by \\[time-stamp].
Can be toggled by \\[time-stamp-toggle-active].
See also the variable `time-stamp-warn-inactive'."
  :type 'boolean
  :group 'time-stamp)

(defcustom time-stamp-warn-inactive t
  "Non-nil to have \\[time-stamp] warn if a buffer did not get time-stamped.
A warning is printed if `time-stamp-active' is nil and the buffer contains
a time stamp template that would otherwise have been updated."
  :type 'boolean
  :group 'time-stamp)

(defcustom time-stamp-old-format-warn 'ask
  "Action to take if `time-stamp-format' is an old-style list.
If `error', the format is not used.  If `ask', the user is queried about
using the time-stamp-format.  If `warn', a warning is displayed.
If nil, no notification is given."
  :type '(choice (const :tag "No notification" nil)
                 (const :tag "Don't use the format" error)
                 (const ask) (const warn))
  :group 'time-stamp)

(defcustom time-stamp-format "%Y-%02m-%02d %02H:%02M:%02S %u"
  "*Format of the string inserted by \\[time-stamp].
The value may be a string or a list.  Lists are supported only for
backward compatibility; see variable `time-stamp-old-format-warn'.

A string is used with `format-time-string'.
In addition to the features of `format-time-string',
you can use the following %-constructs:

%f  file name without directory
%F  full file name
%h  mail host name
%s  system name
%u  user's login name

For example, to get the format used by the `date' command,
use \"%3a %3b %2d %02H:%02M:%02S %Z %Y\"."
  :type 'string
  :group 'time-stamp)



;;; Do not change time-stamp-line-limit, time-stamp-start, or
;;; time-stamp-end in your .emacs or you will be incompatible
;;; with other people's files!  If you must change them,
;;; do so only in the local variables section of the file itself.


(defvar time-stamp-line-limit 8	    ;Do not change!
  "Lines of a file searched; positive counts from start, negative from end.
The patterns `time-stamp-start' and `time-stamp-end' must be found on one
of the first (last) `time-stamp-line-limit' lines of the file for the
file to be time-stamped by \\[time-stamp].

Do not change `time-stamp-line-limit', `time-stamp-start', or
`time-stamp-end' for yourself or you will be incompatible
with other people's files!  If you must change them for some application,
do so in the local variables section of the time-stamped file itself.")


(defvar time-stamp-start "Time-stamp:[ \t]+\\\\?[\"<]+"    ;Do not change!
  "Regexp after which the time stamp is written by \\[time-stamp].
See also the variables `time-stamp-end' and `time-stamp-line-limit'.

Do not change `time-stamp-line-limit', `time-stamp-start', or
`time-stamp-end' for yourself or you will be incompatible
with other people's files!  If you must change them for some application,
do so in the local variables section of the time-stamped file itself.")


(defvar time-stamp-end "\\\\?[\">]"    ;Do not change!
  "Regexp marking the text after the time stamp.
\\[time-stamp] deletes the text between the first match of `time-stamp-start'
and the following match of `time-stamp-end' on the same line,
then writes the time stamp specified by `time-stamp-format' between them.

Do not change `time-stamp-line-limit', `time-stamp-start', or
`time-stamp-end' for yourself or you will be incompatible
with other people's files!  If you must change them for some application,
do so in the local variables section of the time-stamped file itself.")



;;;###autoload
(defun time-stamp ()
  "Update the time stamp string in the buffer.
A template in a file can be automatically updated with a new time stamp
every time you save the file.  Add this line to your .emacs file:
    (add-hook 'write-file-hooks 'time-stamp)
Normally the template must appear in the first 8 lines of a file and
look like one of the following:
      Time-stamp: <>
      Time-stamp: \" \"
The time stamp is written between the brackets or quotes:
      Time-stamp: <1996-07-18 10:20:51 gildea>
The time stamp is updated only if the variable `time-stamp-active' is non-nil.
The format of the time stamp is set by the variable `time-stamp-format'.
The variables `time-stamp-line-limit', `time-stamp-start',
and `time-stamp-end' control finding the template."
  (interactive)
  (let ((case-fold-search nil)
	(start nil)
	(end nil)
	search-limit
	(line-limit time-stamp-line-limit))
    (cond ((not (integerp line-limit))
	   (setq line-limit 8)
	   (message "time-stamp-line-limit is not a number")
	   (sit-for 1)))
    (save-excursion
      (save-restriction
	(widen)
	(cond ((> line-limit 0)
	       (goto-char (setq start (point-min)))
	       (forward-line line-limit)
	       (setq search-limit (point)))
	      (t
	       (goto-char (setq search-limit (point-max)))
	       (forward-line line-limit)
	       (setq start (point))))
	(goto-char start)
	(while (and (< (point) search-limit)
		    (not end)
		    (re-search-forward time-stamp-start search-limit 'move))
	  (setq start (point))
	  (end-of-line)
	  (let ((line-end (point)))
	    (goto-char start)
	    (if (re-search-forward time-stamp-end line-end 'move)
		(setq end (match-beginning 0)))))))
	(if end
	    (progn
	      ;; do all warnings outside save-excursion
	      (cond
	       ((not time-stamp-active)
		(if time-stamp-warn-inactive
		    ;; don't signal an error in a write-file-hook
		    (progn
		      (message "Warning: time-stamp-active is off; did not time-stamp buffer.")
		      (sit-for 1))))
	       ((not (and (stringp time-stamp-start)
			  (stringp time-stamp-end)))
		(message "time-stamp-start or time-stamp-end is not a string")
		(sit-for 1))
	       (t
		(let ((new-time-stamp (time-stamp-string)))
		  (if (stringp new-time-stamp)
		      (save-excursion
			(save-restriction
			  (widen)
			  (delete-region start end)
			  (goto-char start)
			  (insert new-time-stamp)
			  (setq end (point))
			  ;; remove any tabs used to format time stamp
			  (goto-char start)
			  (if (search-forward "\t" end t)
			      (untabify start end)))))))))))
  ;; be sure to return nil so can be used on write-file-hooks
  nil)

;;;###autoload
(defun time-stamp-toggle-active (&optional arg)
  "Toggle `time-stamp-active', setting whether \\[time-stamp] updates a buffer.
With arg, turn time stamping on if and only if arg is positive."
  (interactive "P")
  (setq time-stamp-active
	(if (null arg)
	    (not time-stamp-active)
	  (> (prefix-numeric-value arg) 0)))
    (message "time-stamp is now %s." (if time-stamp-active "active" "off")))

(defconst time-stamp-no-file "(no file)"
  "String to use when the buffer is not associated with a file.")

(defun time-stamp-string-preprocess (format)
  "Process occurrences in FORMAT of %f, %F, %h, %s and %u.
These are replaced with the file name (nondirectory part),
full file name, host name for mail, system name, and user name.
Do not alter other %-combinations, and do detect %%."
  (let ((result "") (pos 0) (case-fold-search nil))
    (while (string-match "%[%uhfFs]" format pos)
      (setq result (concat result (substring format pos (match-beginning 0))))
      (let ((char (aref format (1+ (match-beginning 0)))))
	(cond ((= char ?%)
	       (setq result (concat result "%%")))
	      ((= char ?u)
	       (setq result (concat result (user-login-name))))
	      ((= char ?f)
	       (setq result (concat result
				    (if buffer-file-name
					(file-name-nondirectory buffer-file-name)
				      time-stamp-no-file))))
	      ((= char ?F)
	       (setq result (concat result
				    (or buffer-file-name time-stamp-no-file))))
	      ((= char ?s)
	       (setq result (concat result (system-name))))
	      ((= char ?h)
	       (setq result (concat result (time-stamp-mail-host-name))))))
      (setq pos (match-end 0)))
    (concat result (substring format pos))))

(defun time-stamp-string ()
  "Generate the new string to be inserted by \\[time-stamp]."
  (if (stringp time-stamp-format)
      (format-time-string (time-stamp-string-preprocess time-stamp-format))
    ;; handle version 1 compatibility
    (cond ((or (eq time-stamp-old-format-warn 'error)
	       (and (eq time-stamp-old-format-warn 'ask)
		    (not (y-or-n-p "Use non-string time-stamp-format? "))))
	   (message "Warning: no time-stamp: time-stamp-format not a string")
	   (sit-for 1)
	   nil)
	  (t
	   (cond ((eq time-stamp-old-format-warn 'warn)
		  (message "Obsolescent time-stamp-format type; should be string")
		  (sit-for 1)))
	   (time-stamp-fconcat time-stamp-format " ")))))

(defconst time-stamp-no-file "(no file)"
  "String to use when the buffer is not associated with a file.")

(defun time-stamp-mail-host-name ()
  "Return the name of the host where the user receives mail.
This is the value of `mail-host-address' if bound and a string,
otherwise the value of the function system-name."
  (or (and (boundp 'mail-host-address)
	   (stringp mail-host-address)
	   mail-host-address)
      (system-name)))

;;; the rest of this file is for version 1 compatibility

(defun time-stamp-fconcat (list sep)
  "Similar to (mapconcat 'funcall LIST SEP) but LIST allows literals.
If an element of LIST is a symbol, it is funcalled to get the string to use;
the separator SEP is used between two strings obtained by funcalling a
symbol.  Otherwise the element itself is inserted; no separator is used
around literals."
  (let ((return-string "")
	(insert-sep-p nil))
    (while list
      (cond ((symbolp (car list))
	     (if insert-sep-p
		 (setq return-string (concat return-string sep)))
	     (setq return-string (concat return-string (funcall (car list))))
	     (setq insert-sep-p t))
	    (t
	     (setq return-string (concat return-string (car list)))
	     (setq insert-sep-p nil)))
      (setq list (cdr list)))
    return-string))

;;; Some functions used in time-stamp-format

;;; Could generate most of a message-id with
;;; '(time-stamp-yymmdd "" time-stamp-hhmm "@" time-stamp-mail-host-name)

;;; pretty form, suitable for a title page

(defun time-stamp-month-dd-yyyy ()
  "Return the current date as a string in \"Month DD, YYYY\" form."
  (format-time-string "%B %e, %Y"))

(defun time-stamp-dd/mm/yyyy ()
  "Return the current date as a string in \"DD/MM/YYYY\" form."
  (format-time-string "%d/%m/%Y"))

;;; same as __DATE__ in ANSI C

(defun time-stamp-mon-dd-yyyy ()
  "Return the current date as a string in \"Mon DD YYYY\" form.
The first character of DD is space if the value is less than 10."
  (format-time-string "%b %d %Y"))

;;; RFC 822 date

(defun time-stamp-dd-mon-yy ()
  "Return the current date as a string in \"DD Mon YY\" form."
  (format-time-string "%d %b %y"))

;;; RCS 3 date

(defun time-stamp-yy/mm/dd ()
  "Return the current date as a string in \"YY/MM/DD\" form."
  (format-time-string "%y/%m/%d"))

;;; RCS 5 date

(defun time-stamp-yyyy/mm/dd ()
  "Return the current date as a string in \"YYYY/MM/DD\" form."
  (format-time-string "%Y/%m/%d"))

;;; ISO 8601 date

(defun time-stamp-yyyy-mm-dd ()
  "Return the current date as a string in \"YYYY-MM-DD\" form."
  (format-time-string "%Y-%m-%d"))

(defun time-stamp-yymmdd ()
  "Return the current date as a string in \"YYMMDD\" form."
  (format-time-string "%y%m%d"))

(defun time-stamp-hh:mm:ss ()
  "Return the current time as a string in \"HH:MM:SS\" form."
  (format-time-string "%T"))

(defun time-stamp-hhmm ()
  "Return the current time as a string in \"HHMM\" form."
  (format-time-string "%H%M"))

(provide 'time-stamp)

;;; time-stamp.el ends here
