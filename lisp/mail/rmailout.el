;;; rmailout.el --- "RMAIL" mail reader for Emacs: output message to a file.

;; Copyright (C) 1985, 1987 Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: mail

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

;;; Code:

;; Temporary until Emacs always has this variable.
(defvar rmail-delete-after-output nil
  "*Non-nil means automatically delete a message that is copied to a file.")

(defvar rmail-output-file-alist nil
  "*Alist matching regexps to suggested output Rmail files.
This is a list of elements of the form (REGEXP . FILENAME).")

;;; There are functions elsewhere in Emacs that use this function; check
;;; them out before you change the calling method.
(defun rmail-output-to-rmail-file (file-name &optional count)
  "Append the current message to an Rmail file named FILE-NAME.
If the file does not exist, ask if it should be created.
If file is being visited, the message is appended to the Emacs
buffer visiting that file.
A prefix argument N says to output N consecutive messages
starting with the current one.  Deleted messages are skipped and don't count."
  (interactive
   (let ((default-file
	   (let (answer tail)
	     (setq tail rmail-output-file-alist)
	     ;; Suggest a file based on a pattern match.
	     (while (and tail (not answer))
	       (save-excursion
		 (goto-char (point-min))
		 (if (re-search-forward (car (car tail)) nil t)
		     (setq answer (cdr (car tail))))
		 (setq tail (cdr tail))))
	     ;; If not suggestions, use same file as last time.
	     (or answer rmail-last-rmail-file))))
     (list (read-file-name
	    (concat "Output message to Rmail file: (default "
		    (file-name-nondirectory default-file)
		    ") ")
	    (file-name-directory rmail-last-rmail-file)
	    default-file)
	   (prefix-numeric-value current-prefix-arg))))
  (or count (setq count 1))
  (setq file-name
	(expand-file-name file-name
			  (file-name-directory rmail-last-rmail-file)))
  (setq rmail-last-rmail-file file-name)
  (rmail-maybe-set-message-counters)
  (setq file-name (abbreviate-file-name file-name))
  (or (get-file-buffer file-name)
      (file-exists-p file-name)
      (if (yes-or-no-p
	   (concat "\"" file-name "\" does not exist, create it? "))
	  (let ((file-buffer (create-file-buffer file-name)))
	    (save-excursion
	      (set-buffer file-buffer)
	      (rmail-insert-rmail-file-header)
	      (let ((require-final-newline nil))
		(write-region (point-min) (point-max) file-name t 1)))
	    (kill-buffer file-buffer))
	(error "Output file does not exist")))
  (while (> count 0)
    (let (redelete)
      (unwind-protect
	  (progn
	    (save-restriction
	      (widen)
	      (if (rmail-message-deleted-p rmail-current-message)
		  (progn (setq redelete t)
			 (rmail-set-attribute "deleted" nil)))
	      ;; Decide whether to append to a file or to an Emacs buffer.
	      (save-excursion
		(let ((buf (get-file-buffer file-name))
		      (cur (current-buffer))
		      (beg (1+ (rmail-msgbeg rmail-current-message)))
		      (end (1+ (rmail-msgend rmail-current-message))))
		  (if (not buf)
		      (append-to-file beg end file-name)
		    (if (eq buf (current-buffer))
			(error "Can't output message to same file it's already in"))
		    ;; File has been visited, in buffer BUF.
		    (set-buffer buf)
		    (let ((buffer-read-only nil)
			  (msg (and (boundp 'rmail-current-message)
				    rmail-current-message)))
		      ;; If MSG is non-nil, buffer is in RMAIL mode.
		      (if msg
			  (progn
			    (rmail-maybe-set-message-counters)
			    (widen)
			    (narrow-to-region (point-max) (point-max))
			    (insert-buffer-substring cur beg end)
			    (goto-char (point-min))
			    (widen)
			    (search-backward "\n\^_")
			    (narrow-to-region (point) (point-max))
			    (rmail-count-new-messages t)
			    (rmail-show-message msg))
	      ;; Output file not in rmail mode => just insert at the end.
	      (narrow-to-region (point-min) (1+ (buffer-size)))
	      (goto-char (point-max))
	      (insert-buffer-substring cur beg end)))))))
	    (rmail-set-attribute "filed" t))
	(if redelete (rmail-set-attribute "deleted" t))))
    (setq count (1- count))
    (if rmail-delete-after-output
	(rmail-delete-forward)
      (if (> count 0)
	  (rmail-next-undeleted-message 1)))))

;;; There are functions elsewhere in Emacs that use this function; check
;;; them out before you change the calling method.
(defun rmail-output (file-name &optional count)
  "Append this message to Unix mail file named FILE-NAME.
A prefix argument N says to output N consecutive messages
starting with the current one.  Deleted messages are skipped and don't count.
When called from lisp code, N may be omitted."
  (interactive
   (list (read-file-name
	  (concat "Output message to Unix mail file"
		  (if rmail-last-file
		      (concat " (default "
			      (file-name-nondirectory rmail-last-file)
			      "): " )
		    ": "))			
	  (and rmail-last-file (file-name-directory rmail-last-file))
	  rmail-last-file)
	 (prefix-numeric-value current-prefix-arg)))
  (or count (setq count 1))
  (setq file-name
	(expand-file-name file-name
			  (and rmail-last-file
			       (file-name-directory rmail-last-file))))
  (setq rmail-last-file file-name)
  (while (> count 0)
    (let ((rmailbuf (current-buffer))
	  (tembuf (get-buffer-create " rmail-output"))
	  (case-fold-search t))
      (save-excursion
	(set-buffer tembuf)
	(erase-buffer)
	;; If we can do it, read a little of the file
	;; to check whether it is an RMAIL file.
	;; If it is, don't mess it up.
	(if (fboundp 'insert-partial-file-contents)
	    (progn
	      (insert-partial-file-contents file-name 0 20)
	      (if (looking-at "BABYL OPTIONS:\n")
		  (error (save-excursion
			   (set-buffer rmailbuf)
			   (substitute-command-keys
			    "File %s is an RMAIL file; use the \\[rmail-output-to-rmail-file] command"))
			 file-name))
	      (erase-buffer)))
	(insert-buffer-substring rmailbuf)
	(insert "\n")
	(goto-char (point-min))
	(insert "From "
		(mail-strip-quoted-names (or (mail-fetch-field "from")
					     (mail-fetch-field "really-from")
					     (mail-fetch-field "sender")
					     "unknown"))
		" " (current-time-string) "\n")
	;; ``Quote'' "\nFrom " as "\n>From "
	;;  (note that this isn't really quoting, as there is no requirement
	;;   that "\n[>]+From " be quoted in the same transparent way.)
	(while (search-forward "\nFrom " nil t)
	  (forward-char -5)
	  (insert ?>))
	(append-to-file (point-min) (point-max) file-name))
      (kill-buffer tembuf))
    (if (equal major-mode 'rmail-mode)
	(rmail-set-attribute "filed" t))
    (setq count (1- count))
    (if rmail-delete-after-output
	(rmail-delete-forward)
      (if (> count 0)
	  (rmail-next-undeleted-message 1)))))

;;; rmailout.el ends here
