;;; fringe.el --- change fringes appearance in various ways

;; Copyright (C) 2002, 2003 Free Software Foundation, Inc.

;; Author: Simon Josefsson <simon@josefsson.org>
;; Maintainer: FSF
;; Keywords: frames

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

;; This file contains helpful functions for customizing the appearance
;; of the fringe.

;; The code is influenced by scroll-bar.el and avoid.el.  The author
;; gratefully acknowledge comments and suggestions made by Miles
;; Bader, Eli Zaretski, Richard Stallman, Pavel Janík and others which
;; improved this package.

;;; Code:

(defgroup fringe nil
  "Window fringes."
  :version "21.4"
  :group 'frames)

;; Standard fringe bitmaps

(defmacro fringe-bitmap-p (symbol)
  "Return non-nil if SYMBOL is a fringe bitmap."
  `(get ,symbol 'fringe))

(defvar fringe-bitmaps)

(unless (or (not (boundp 'fringe-bitmaps))
	    (get 'left-truncation 'fringe))
  (let ((bitmaps '(left-truncation right-truncation
		   up-arrow down-arrow
		   continued-line continuation-line
		   overlay-arrow
		   top-left-angle top-right-angle
		   bottom-left-angle bottom-right-angle
		   left-bracket right-bracket
		   filled-box-cursor hollow-box-cursor hollow-square
		   bar-cursor hbar-cursor
		   empty-line))
	(bn 2))
    (while bitmaps
      (push (car bitmaps) fringe-bitmaps)
      (put (car bitmaps) 'fringe bn)
      (setq bitmaps (cdr bitmaps)
	    bn (1+ bn)))))


;; Control presence of fringes

(defvar fringe-mode)

(defun set-fringe-mode-1 (ignore value)
  "Call `set-fringe-mode' with VALUE.
See `fringe-mode' for valid values and their effect.
This is usually invoked when setting `fringe-mode' via customize."
  (set-fringe-mode value))

(defun set-fringe-mode (value)
  "Set `fringe-mode' to VALUE and put the new value into effect.
See `fringe-mode' for possible values and their effect."
  (setq fringe-mode value)

  ;; Apply it to default-frame-alist.
  (let ((parameter (assq 'left-fringe default-frame-alist)))
    (if (consp parameter)
	(setcdr parameter (if (consp fringe-mode)
			      (car fringe-mode)
			    fringe-mode))
      (setq default-frame-alist
	    (cons (cons 'left-fringe (if (consp fringe-mode)
					 (car fringe-mode)
				       fringe-mode))
		  default-frame-alist))))
  (let ((parameter (assq 'right-fringe default-frame-alist)))
    (if (consp parameter)
	(setcdr parameter (if (consp fringe-mode)
			      (cdr fringe-mode)
			    fringe-mode))
      (setq default-frame-alist
	    (cons (cons 'right-fringe (if (consp fringe-mode)
					  (cdr fringe-mode)
					fringe-mode))
		  default-frame-alist))))

  ;; Apply it to existing frames.
  (let ((frames (frame-list)))
    (while frames
      (modify-frame-parameters
       (car frames)
       (list (cons 'left-fringe (if (consp fringe-mode)
				    (car fringe-mode)
				  fringe-mode))
	     (cons 'right-fringe (if (consp fringe-mode)
				     (cdr fringe-mode)
				   fringe-mode))))
      (setq frames (cdr frames)))))

;; For initialization of fringe-mode, take account of changes
;; made explicitly to default-frame-alist.
(defun fringe-mode-initialize (symbol value)
  (let* ((left-pair (assq 'left-fringe default-frame-alist))
	 (right-pair (assq 'right-fringe default-frame-alist))
	 (left (cdr left-pair))
	 (right (cdr right-pair)))
    (if (or left-pair right-pair)
	;; If there's something in default-frame-alist for fringes,
	;; don't change it, but reflect that into the value of fringe-mode.
	(progn
	  (setq fringe-mode (cons left right))
	  (if (equal fringe-mode '(nil . nil))
	      (setq fringe-mode nil))
	  (if (equal fringe-mode '(0 . 0))
	      (setq fringe-mode 0)))
      ;; Otherwise impose the user-specified value of fringe-mode.
      (custom-initialize-reset symbol value))))

;;;###autoload
(defcustom fringe-mode nil
  "*Specify appearance of fringes on all frames.
This variable can be nil (the default) meaning the fringes should have
the default width (8 pixels), it can be an integer value specifying
the width of both left and right fringe (where 0 means no fringe), or
a cons cell where car indicates width of left fringe and cdr indicates
width of right fringe (where again 0 can be used to indicate no
fringe).
To set this variable in a Lisp program, use `set-fringe-mode' to make
it take real effect.
Setting the variable with a customization buffer also takes effect.
If you only want to modify the appearance of the fringe in one frame,
you can use the interactive function `toggle-fringe'"
  :type '(choice (const :tag "Default width" nil)
		 (const :tag "No fringes" 0)
		 (const :tag "Only right" (0 . nil))
		 (const :tag "Only left" (nil . 0))
		 (const :tag "Half width" (5 . 5))
		 (const :tag "Minimal" (1 . 1))
		 (integer :tag "Specific width")
		 (cons :tag "Different left/right sizes"
		       (integer :tag "Left width")
		       (integer :tag "Right width")))
  :group 'fringe
  :require 'fringe
  :initialize 'fringe-mode-initialize
  :set 'set-fringe-mode-1)

(defun fringe-query-style (&optional all-frames)
  "Query user for fringe style.
Returns values suitable for left-fringe and right-fringe frame parameters.
If ALL-FRAMES, the negation of the fringe values in
`default-frame-alist' is used when user enters the empty string.
Otherwise the negation of the fringe value in the currently selected
frame parameter is used."
  (let ((mode (intern (completing-read
		       "Select fringe mode for all frames (type ? for list): "
		       '(("none") ("default") ("left-only")
			 ("right-only") ("half") ("minimal"))
		       nil t))))
    (cond ((eq mode 'none) 0)
	  ((eq mode 'default) nil)
	  ((eq mode 'left-only) '(nil . 0))
	  ((eq mode 'right-only) '(0 . nil))
	  ((eq mode 'half) '(5 . 5))
	  ((eq mode 'minimal) '(1 . 1))
	  ((eq mode (intern ""))
	   (if (eq 0 (cdr (assq 'left-fringe
				(if all-frames
				    default-frame-alist
				  (frame-parameters (selected-frame))))))
	       nil
	     0)))))

;;;###autoload
(defun fringe-mode (&optional mode)
  "Set the default appearance of fringes on all frames.

When called interactively, query the user for MODE.  Valid values
for MODE include `none', `default', `left-only', `right-only',
`minimal' and `half'.

When used in a Lisp program, MODE can be a cons cell where the
integer in car specifies the left fringe width and the integer in
cdr specifies the right fringe width.  MODE can also be a single
integer that specifies both the left and the right fringe width.
If a fringe width specification is nil, that means to use the
default width (8 pixels).  This command may round up the left and
right width specifications to ensure that their sum is a multiple
of the character width of a frame.  It never rounds up a fringe
width of 0.

Fringe widths set by `set-window-fringes' override the default
fringe widths set by this command.  This command applies to all
frames that exist and frames to be created in the future.  If you
want to set the default appearance of fringes on the selected
frame only, see the command `set-fringe-style'."
  (interactive (list (fringe-query-style 'all-frames)))
  (set-fringe-mode mode))

;;;###autoload
(defun set-fringe-style (&optional mode)
  "Set the default appearance of fringes on the selected frame.

When called interactively, query the user for MODE.  Valid values
for MODE include `none', `default', `left-only', `right-only',
`minimal' and `half'.

When used in a Lisp program, MODE can be a cons cell where the
integer in car specifies the left fringe width and the integer in
cdr specifies the right fringe width.  MODE can also be a single
integer that specifies both the left and the right fringe width.
If a fringe width specification is nil, that means to use the
default width (8 pixels).  This command may round up the left and
right width specifications to ensure that their sum is a multiple
of the character width of a frame.  It never rounds up a fringe
width of 0.

Fringe widths set by `set-window-fringes' override the default
fringe widths set by this command.  If you want to set the
default appearance of fringes on all frames, see the command
`fringe-mode'."
  (interactive (list (fringe-query-style)))
  (modify-frame-parameters
   (selected-frame)
   (list (cons 'left-fringe (if (consp mode) (car mode) mode))
	 (cons 'right-fringe (if (consp mode) (cdr mode) mode)))))

(defsubst fringe-columns (side &optional real)
  "Return the width, measured in columns, of the fringe area on SIDE.
If optional argument REAL is non-nil, return a real floating point
number instead of a rounded integer value.
SIDE must be the symbol `left' or `right'."
  (funcall (if real '/ 'ceiling)
	   (or (funcall (if (eq side 'left) 'car 'cadr)
			(window-fringes))
	       0)
           (float (frame-char-width))))


;;;###autoload
(defcustom fringe-indicators nil
  "Visually indicate buffer boundaries and scrolling.
Setting this variable, changes `default-indicate-buffer-boundaries'."
  :type '(choice (const :tag "No indicators" nil)
		 (const :tag "On left" left)
		 (const :tag "On right" right)
		 (const :tag "Opposite, no arrows" box)
		 (const :tag "Opposite, arrows right" mixed)
		 (const :tag "Empty lines" empty))
  :group 'fringe
  :require 'fringe
  :set 'set-fringe-indicators-1)

(defun set-fringe-indicators-1 (ignore value)
  "Set fringe indicators according to VALUE.
This is usually invoked when setting `fringe-indicators' via customize."
  (setq fringe-indicators value)
  (setq default-indicate-empty-lines nil)
  (setq default-indicate-buffer-boundaries
	(cond
	 ((memq value '(left right t))
	  value)
	 ((eq value 'box)
	  '((top . left) (bottom . right)))
	 ((eq value 'mixed)
	  '((top . left) (t . right)))
	 ((eq value 'empty)
	  (setq default-indicate-empty-lines t)
	  nil)
	 (t nil))))

(provide 'fringe)

;;; arch-tag: 6611ef60-0869-47ed-8b93-587ee7d3ff5d
;;; fringe.el ends here
