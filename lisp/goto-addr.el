;;; goto-addr.el --- click to browse URL or to send to e-mail address
;; Copyright (C) 1995 Free Software Foundation, Inc.

;; Maintainer: Eric Ding <ericding@mit.edu>
;; Created: 15 Aug 1995
;; Keywords: mh-e, www, mouse, mail

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

;; This package allows you to click or hit a key sequence while on a
;; URL or e-mail address, and either load the URL into a browser of
;; your choice using the browse-url package, or if it's an e-mail
;; address, to send an e-mail to that address.  By default, we bind to
;; the [S-mouse-1] and the [C-c return] key sequences.
;;
;; You will also need the browse-url.el package to use goto-address.
;; You can find it at <URL:http://wombat.doc.ic.ac.uk/emacs/browse-url.el>.

;; INSTALLATION
;;
;; To install goto-address, put goto-addr.el somewhere in
;; your load-path and add the following to your .emacs file:
;;
;; (autoload 'goto-address "goto-addr"
;;  "Set up buffer to click to browse URL or to send to e-mail address" t)
;;
;; To use it in a particular mode (for example, while reading mail in
;; mh-e), add something like this in your .emacs file:
;; 
;; (add-hook 'mh-show-mode-hook 'goto-address)
;;
;; By default, goto-address now sends using `mail' instead of `mh-send'.
;; To use mh-e to send mail, add the following to your .emacs file:
;;
;; (setq goto-address-mail-method 'goto-address-send-using-mhe)
;;
;; To rebind, for example, the mouse click method to [mouse-2] in
;; mh-show-mode, add the following (instead of the first add-hook example
;; above) to your .emacs file:
;;
;; (defun my-goto-address ()
;;   (goto-address)
;;   (local-unset-key [S-mouse-1])
;;   (local-set-key [mouse-2] 'goto-address-at-mouse))
;;
;; (add-hook 'mh-show-mode-hook 'my-goto-address)
;;
;; [mouse-2] is not the default mouse binding because I use goto-address in
;; some editable buffers, where [mouse-2] means mouse-yank-at-click, as well
;; as in some modes where [mouse-2] is bound to other useful functions.

;; BUG REPORTS
;;
;; Please send bug reports to me at ericding@mit.edu.

;; Known bugs/features:
;; * goto-address-mail-regexp only catches foo@bar.org style addressing,
;;   not stuff like X.400 addresses, etc.
;; * regexp also catches Message-Id line, since it is in the format of
;;   an Internet e-mail address (like Compuserve addresses)
;; * If show buffer is fontified after goto-address-fontify is run
;;   (say, using font-lock-fontify-buffer), then font-lock face will
;;   override goto-address faces.

;;; Change log:

;;; Code:

(require 'browse-url)

(defvar goto-address-fontify-p t
  "*If t, URL's and e-mail address in buffer are fontified.")

(defvar goto-address-fontify-maximum-size 30000
  "*Maximum size of file in which to fontify URL's.")

(defvar goto-address-mail-regexp
  "[-a-zA-Z0-9._]+@\\([-a-zA-z0-9_]+\\.\\)+[a-zA-Z0-9]+"
  "A regular expression probably matching an e-mail address.")

(defvar goto-address-url-regexp
  (concat "\\b\\(s?https?\\|ftp\\|file\\|gopher\\|news\\|"
	  "telnet\\|wais\\):\\(//[-a-zA-Z0-9_.]+:"
	  "[0-9]*\\)?[-a-zA-Z0-9_=?#$@~`%&*+|\\/.,]*"
	  "[-a-zA-Z0-9_=#$@~`%&*+|\\/]")
  "A regular expression probably matching a URL.")

(defvar goto-address-mail-method
  'goto-address-send-using-mail
  "*Function to compose mail.
Two pre-made functions are `goto-address-send-using-mail' (sendmail);
and `goto-address-send-using-mhe' (MH-E).")

(defun goto-address-fontify ()
  "Fontify the URL's and e-mail addresses in the current buffer."
  (save-excursion
    (let ((inhibit-read-only t)
	  (modified (buffer-modified-p)))
      (goto-char (point-min))
      (if (< (- (point-max) (point)) goto-address-fontify-maximum-size)
	  (progn
	    (while (re-search-forward goto-address-url-regexp nil t)
	      ;; if text is invisible, we ignore it
	      (and (goto-address-skip-invisible (match-beginning 0))
		   (progn
		     (goto-char (match-end 0))
		     (put-text-property (match-beginning 0) (match-end 0)
					'face 'bold)
		     (put-text-property (match-beginning 0) (match-end 0)
					'mouse-face 'highlight))))
	    (goto-char (point-min))
	    (while (re-search-forward goto-address-mail-regexp nil t)
	      ;; if text is invisible, we ignore it
	      (and (goto-address-skip-invisible (match-beginning 0))
		   (progn
		     (goto-char (match-end 0))
		     (put-text-property (match-beginning 0) (match-end 0)
					'face 'italic)
		     (put-text-property (match-beginning 0) (match-end 0)
					'mouse-face 'secondary-selection))))))
      (and (buffer-modified-p)
	   (not modified)
	   (set-buffer-modified-p nil)))))

(defun goto-address-skip-invisible (char)
  "If char is not invisible, then return t.  Otherwise, move forward in buffer
until a non-invisible char is found, goto that position, and return nil."
  (if (get-text-property char 'invisible)
      (let ((char (1+ char)))
	(while (get-text-property char 'invisible)
	  (setq char (1+ char))
	  (goto-char char)))
    t))

;;; code to find and goto addresses; much of this has been blatantly
;;; snarfed from browse-url.el

(defun goto-address-at-mouse (event)
  "Send to the e-mail address or load the URL clicked with the mouse.
Send mail to address at position of mouse click.  See documentation for
`goto-address-find-address-at-point'.  If no address is found
there, then load the URL at or before the position of the mouse click."
  (interactive "e")
  (save-excursion
    (let ((posn (event-start event)))
      (set-buffer (window-buffer (posn-window posn)))
      (goto-char (posn-point posn))
      (let ((address
	     (save-excursion (goto-address-find-address-at-point))))
	(if (string-equal address "")
	    (let ((url (browse-url-url-at-point)))
	      (if (string-equal url "")
		  (error "No e-mail address or URL found")
		(funcall browse-url-browser-function url)))
	  (funcall goto-address-mail-method address))))))

(defun goto-address-at-point ()
  "Send to the e-mail address or load the URL at point.
Send mail to address at point.  See documentation for
`goto-address-find-address-at-point'.  If no address is found
there, then load the URL at or before point."
  (interactive)
  (save-excursion
    (let ((address (save-excursion (goto-address-find-address-at-point))))
      (if (string-equal address "")
	  (let ((url (browse-url-url-at-point)))
	    (if (string-equal url "")
		(error "No e-mail address or URL found")
	      (funcall browse-url-browser-function url)))
	(funcall goto-address-mail-method address)))))

(defun goto-address-find-address-at-point ()
  "Find e-mail address around or before point.
Then search backwards to beginning of line for the start of an e-mail
address.  If no e-mail address found, return the empty string."
  (let ((bol (save-excursion (beginning-of-line) (point))))
    (re-search-backward "[^-_A-z0-9.@]" bol 'lim)
    (if (or (looking-at goto-address-mail-regexp)  ; already at start
	    (let ((eol (save-excursion (end-of-line) (point))))
	      (and (re-search-forward goto-address-mail-regexp eol 'lim)
		   (goto-char (match-beginning 0)))))
	(buffer-substring (match-beginning 0) (match-end 0))
      "")))

(defun goto-address-send-using-mhe (to)
  (mh-find-path)
  (let ((cc (mh-read-address "Cc: "))
	(subject (read-string "Subject: "))
	(config (current-window-configuration)))
    (delete-other-windows)
    (mh-send-sub to cc subject config)))

(defun goto-address-send-using-mail (to)
  (mail-other-window nil to)
  (and (goto-char (point-min))
       (end-of-line 2)))

(defun goto-address ()
  (interactive)
  (local-set-key [S-mouse-1] 'goto-address-at-mouse)
  (local-set-key "\C-c\r" 'goto-address-at-point)
  (if goto-address-fontify-p
      (goto-address-fontify)))

(provide 'goto-addr)

;;; goto-addr.el ends here.
