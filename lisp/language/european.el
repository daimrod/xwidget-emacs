;;; european.el --- Support for European languages

;; Copyright (C) 1995 Free Software Foundation, Inc.
;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.

;; Keywords: multilingual, European

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

;; For Europeans, five character sets ISO8859-1,2,3,4,9 are supported.

;;; Code:

(define-prefix-command 'describe-european-environment-map)
(define-key-after describe-language-environment-map [European]
  '("European" . describe-european-environment-map)
  t)

(define-prefix-command 'setup-european-environment-map)
(define-key-after setup-language-environment-map [European]
  '("European" . setup-european-environment-map)
  t)

;; Setup for a langauge which uses one-byte 8-bit CHARSET, one-byte
;; 8-bit CODING-SYSTEM, and INPUT-METHOD.
(defun setup-8-bit-environment (charset coding-system input-method)
  (setup-english-environment)
  (setq-default buffer-file-coding-system coding-system)
  (setq coding-category-iso-8-1 coding-system
	coding-category-iso-8-2 coding-system)
  (set-terminal-coding-system-internal coding-system)
  (set-keyboard-coding-system-internal coding-system)
  (setq sendmail-coding-system nil
	rmail-file-coding-system coding-system)

  (if charset
      (let ((nonascii-offset (- (make-char charset) 128)))
	;; Set up for insertion of characters in this character set
	;; when codes 0200 - 0377 are typed in.
	(setq nonascii-insert-offset nonascii-offset)))

  (if input-method
      (let ((latin-name (car input-method)))
	(setq default-input-method input-method)
	;; If this is a Latin-N character set, set up syntax for it
	;; in single-byte mode.
	(when (and latin-name
		   (string-match "^Latin-\\([1-9]\\)$" latin-name))
	  (require (intern (downcase latin-name)))))))

;; Latin-1 (ISO-8859-1)

(make-coding-system
 'iso-8859-1 2 ?1
 "MIME ISO-8859-1 Compound Text Encoding."
 '((ascii t) (latin-iso8859-1 t) nil nil
   nil ascii-eol ascii-cntl))

;; CTEXT is an alias for ISO-8859-1
(define-coding-system-alias 'iso-8859-1 'ctext)

(register-input-method "Latin-1"
		       '("quail-latin-1" quail-use-package "quail/latin"))

(defun setup-latin1-environment ()
  "Set up multilingual environment (MULE) for European Latin-1 users."
  (interactive)
  (setup-8-bit-environment 'latin-iso8859-1 'iso-8859-1
			   '("Latin-1" . "quail-latin-1")))

(set-language-info-alist
 "Latin-1" '((setup-function . (setup-latin1-environment
				. setup-european-environment-map))
	     (charset . (ascii latin-iso8859-1))
	     (coding-system . (iso-8859-1))
	     (sample-text
	      . "Hello, Hej, Tere, Hei, Bonjour, Gr,A|_(B Gott, Ciao, ,A!(BHola!")
	     (documentation . ("\
These languages are supported with the Latin-1 (ISO-8859-1) character set:
 Danish, Dutch, English, Faeroese, Finnish, French, German, Icelandic,
 Irish, Italian, Norwegian, Portuguese, Spanish, and Swedish.
" . describe-european-environment-map))
	     ))

;; Latin-2 (ISO-8859-2)

(make-coding-system
 'iso-8859-2 2 ?2 "MIME ISO-8859-2"
 '((ascii t) (latin-iso8859-2 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(register-input-method "Latin-2"
		       '("quail-latin-2" quail-use-package "quail/latin"))

(defun setup-latin2-environment ()
  "Set up multilingual environment (MULE) for European Latin-2 users."
  (interactive)
  (setup-8-bit-environment 'latin-iso8859-2 'iso-8859-2
			   '("Latin-2" . "quail-latin-2")))

(set-language-info-alist
 "Latin-2" '((setup-function . (setup-latin2-environment
				. setup-european-environment-map))
	     (charset . (ascii latin-iso8859-2))
	     (coding-system . (iso-8859-2))
	     (documentation . ("\
These languages are supported with the Latin-2 (ISO-8859-2) character set:
 Albanian, Czech, English, German, Hungarian, Polish, Romanian,
 Serbo-Croatian, Slovak, Slovene, and Swedish.
" . describe-european-environment-map))
	     ))

;; Latin-3 (ISO-8859-3)

(make-coding-system
 'iso-8859-3 2 ?3 "MIME ISO-8859-3"
 '((ascii t) (latin-iso8859-3 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(register-input-method "Latin-3"
		       '("quail-latin-3" quail-use-package "quail/latin"))

(defun setup-latin3-environment ()
  "Set up multilingual environment (MULE) for European Latin-3 users."
  (interactive)
  (setup-8-bit-environment 'latin-iso8859-3 'iso-8859-3
			   '("Latin-3" . "quail-latin-3")))

(set-language-info-alist
 "Latin-3" '((setup-function . (setup-latin3-environment
				. setup-european-environment-map))
	     (charset . (ascii latin-iso8859-3))
	     (coding-system . (iso-8859-3))
	     (documentation . ("\
These languages are supported with the Latin-3 (ISO-8859-3) character set:
 Afrikaans, Catalan, Dutch, English, Esperanto, French, Galician,
 German, Italian, Maltese, Spanish, and Turkish.
" . describe-european-environment-map))
	     ))

;; Latin-4 (ISO-8859-4)

(make-coding-system
 'iso-8859-4 2 ?4 "MIME ISO-8859-4"
 '((ascii t) (latin-iso8859-4 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(register-input-method "Latin-4"
		       '("quail-latin-4" quail-use-package "quail/latin"))

(defun setup-latin4-environment ()
  "Set up multilingual environment (MULE) for European Latin-4 users."
  (interactive)
  (setup-8-bit-environment 'latin-iso8859-4 'iso-8859-4
			   '("Latin-4" . "quail-latin-4")))

(set-language-info-alist
 "Latin-4" '((setup-function . (setup-latin4-environment
				. setup-european-environment-map))
	     (charset . (ascii latin-iso8859-4))
	     (coding-system . (iso-8859-4))
	     (documentation . ("\
These languages are supported with the Latin-4 (ISO-8859-4) character set:
 Danish, English, Estonian, Finnish, German, Greenlandic, Lappish,
 Latvian, Lithuanian, and Norwegian.
" . describe-european-environment-map))
	     ))

;; Latin-5 (ISO-8859-9)

(make-coding-system
 'iso-8859-9 2 ?9 "MIME ISO-8859-9"
 '((ascii t) (latin-iso8859-9 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(register-input-method "Latin-5"
		       '("quail-latin-5" quail-use-package "quail/latin"))

(defun setup-latin5-environment ()
  "Set up multilingual environment (MULE) for European Latin-5 users."
  (interactive)
  (setup-8-bit-environment 'latin-iso8859-9 'iso-8859-9
			   '("Latin-5" . "quail-latin-5")))

(set-language-info-alist
 "Latin-5" '((setup-function . (setup-latin5-environment
				. setup-european-environment-map))
	     (charset . (ascii latin-iso8859-9))
	     (coding-system . (iso-8859-9))
	     (documentation . ("\
These languages are supported with the Latin-5 (ISO-8859-9) character set.
" . describe-european-environment-map))
	     ))

(let ((languages '("French" "German" "Spanish" "Italian"
		   ;; We have to list much more European languages here.
		   ))
      (val '("quail-latin-1" quail-use-package "quail/latin")))
  (while languages
    (register-input-method (car languages) val)
    (setq languages (cdr languages))))

;;; european.el ends here
