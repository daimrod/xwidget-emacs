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

(make-coding-system
 'iso-8859-1 2 ?X
 "Coding-system used in X as Compound Text Encoding."
 '((ascii t) (latin-iso8859-1 t) nil nil
   nil ascii-eol ascii-cntl))

;; CTEXT is an alias for ISO-8859-1
(define-coding-system-alias 'iso-8859-1 'ctext)

(make-coding-system
 'iso-8859-2 2 ?2 "MIME ISO-8859-2"
 '((ascii t) (latin-iso8859-2 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(make-coding-system
 'iso-8859-3 2 ?3 "MIME ISO-8859-3"
 '((ascii t) (latin-iso8859-3 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(make-coding-system
 'iso-8859-4 2 ?4 "MIME ISO-8859-4"
 '((ascii t) (latin-iso8859-4 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(make-coding-system
 'iso-8859-9 2 ?9 "MIME ISO-8859-9"
 '((ascii t) (latin-iso8859-9 t) nil nil
   nil ascii-eol ascii-cntl nil nil nil nil))

(register-input-method "European"
		       '("quail-latin-1" quail-use-package "quail/latin"))
(register-input-method "European"
		       '("quail-latin-2" quail-use-package "quail/latin"))
(register-input-method "European"
		       '("quail-latin-3" quail-use-package "quail/latin"))
(register-input-method "European"
		       '("quail-latin-4" quail-use-package "quail/latin"))
(register-input-method "European"
		       '("quail-latin-5" quail-use-package "quail/latin"))

(defun setup-european-environment ()
  "Setup multilingual environment (MULE) for European languages users.
It actually reset MULE to the default status, and
set quail-latin-1 as the default input method to be selected.
See also the documentation of setup-english-environment."
  (setup-english-environment)
  (setq default-input-method '("European" . "quail-latin-1")))

(set-language-info-alist
 "European" '((setup-function . setup-european-environment)
	      (charset . (ascii latin-iso8859-1 latin-iso8859-2
			  latin-iso8859-3 latin-iso8859-4 latin-iso8859-9))
	      (coding-system . (iso-8859-1 iso-8859-2 iso-8859-3
				iso-8859-4 iso-8859-9))
	      (sample-text
	       . "Hello, Hej, Tere, Hei, Bonjour, Gr,A|_(B Gott, Ciao, ,A!(BHola!")
	      (documentation . ("\
Almost all of European languages are supported by the character sets and
coding systems listed below.
To input them, LEIM (Libraries for Emacs Input Methods) should have been
installed."))
	      ))

(let ((languages '("French" "German" "Spanish" "Italian"
		   ;; We have to list much more European languages here.
		   ))
      (val '("quail-latin-1" quail-use-package "quail/latin")))
  (while languages
    (register-input-method (car languages) val)
    (setq languages (cdr languages))))

;;; european.el ends here
