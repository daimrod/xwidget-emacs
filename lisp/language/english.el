;;; english.el --- English support

;; Copyright (C) 1997 Free Software Foundation, Inc.
;; Copyright (C) 1997 Electrotechnical Laboratory, JAPAN.

;; Keywords: multibyte character, character set, syntax, category

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

;; We need nothing special to support English on Emacs.  Selecting
;; English as a language environment is one of the ways to reset
;; various multilingual environment to the original settting.

;;; Code

(defun setup-english-environment ()
  "Reset multilingual environment of Emacs to the default status.
The default status is as follows.

  The default value of enable-multibyte-characters is t.

  The default value of buffer-file-coding-system is nil.
  The coding system for terminal output is nil.
  The coding system for keyboard input is nil.

  The order of priorities of coding categories and the coding system
  bound to each category are as follows
	coding category			coding system
	--------------------------------------------------
	coding-category-iso-7		iso-2022-7
	coding-category-iso-8-2		iso-8859-1
	coding-category-iso-8-1		iso-8859-1
	coding-category-iso-else	iso-2022-lock
	coding-category-emacs-mule 	emacs-mule
	coding-category-binary		no-conversion
	coding-category-sjis		sjis
	coding-category-big5		big5
"
  (interactive)
  (setq-default enable-multibyte-characters t)

  (setq coding-category-iso-7		'iso-2022-7
	coding-category-iso-8-1		'iso-8859-1
	coding-category-iso-8-2		'iso-8859-1
	coding-category-iso-else	'iso-2022-lock
	coding-category-emacs-mule	'emacs-mule
	coding-category-sjis		'sjis
	coding-category-big5		'big5
	coding-category-binary		'no-conversion)

  (set-coding-priority
   '(coding-category-iso-7
     coding-category-iso-8-2
     coding-category-iso-8-1
     coding-category-iso-else
     coding-category-emacs-mule 
     coding-category-sjis
     coding-category-big5
     coding-category-binary))

  (setq-default buffer-file-coding-system nil)
  (set-terminal-coding-system-internal nil)
  (set-keyboard-coding-system-internal nil)

  (setq sendmail-coding-system nil
	rmail-file-coding-system nil)

  (setq nonascii-insert-offset 0)
  )

(set-language-info-alist
 "English" '((setup-function . setup-english-environment)
	     (tutorial . "TUTORIAL")
	     (charset . (ascii))
	     (sample-text . "Hello!, Hi!, How are you?")
	     (documentation . "\
Nothing special is needed to handle English.")
	     ))

(register-input-method "English"
		       '("quail-dvorak" quail-use-package "quail/latin"))

;;; english.el ends here
