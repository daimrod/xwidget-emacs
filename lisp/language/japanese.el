;;; japanese.el --- Japanese support

;; Copyright (C) 1995 Free Software Foundation, Inc.
;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.

;; Keywords: multilingual, Japanese

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

;; For Japanese, character sets JISX0201, JISX0208, JISX0212 are
;; supported.

;;; Code:

(define-coding-system-alias 'iso-2022-7 'iso-2022-jp)
(define-coding-system-alias 'iso-2022-7 'junet)

(make-coding-system
 'shift_jis 1 ?S
 "Coding-system of Shift-JIS used in Japan." t)

(define-coding-system-alias 'shift_jis 'sjis)

(make-coding-system
 'iso-2022-jp-1978-irv 2 ?J
 "Coding-system used for old jis terminal."
 '((ascii t) nil nil nil
   short ascii-eol ascii-cntl seven nil nil use-roman use-oldjis))

(define-coding-system-alias 'iso-2022-jp-1978-irv 'old-jis)

(make-coding-system
 'euc-japan-1990 2 ?E
 "Coding-system of Japanese EUC (Extended Unix Code)."
 '(ascii japanese-jisx0208 katakana-jisx0201 japanese-jisx0212
	 short ascii-eol ascii-cntl nil nil single-shift))

(define-coding-system-alias 'euc-japan-1990 'euc-japan)

(register-input-method
 "Japanese" '("quail-ja-hiragana" quail-use-package "quail/japanese"))
(register-input-method
 "Japanese" '("quail-ja" quail-use-package "quail/japanese"))

(set-language-info-alist
 "Japanese" '((setup-function . setup-japanese-environment)
	      (tutorial . "TUTORIAL.jp")
	      (charset . (japanese-jisx0208 japanese-jisx0208-1978
			  japanese-jisx0212 latin-jisx0201
			  katakana-jisx0201))
	      (coding-system . (euc-japan-1990 sjis
				iso-2022-jp iso-2022-jp-1978-irv))
	      (sample-text . "Japanese ($BF|K\8l(B)		$B$3$s$K$A$O(B, (I:]FAJ(B")
	      (documentation . t)))

;;; japanese.el ends here
