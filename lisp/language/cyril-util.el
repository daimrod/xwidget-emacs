;;; cyril-util.el ---  utilities for Cyrillic scripts

;; Copyright (C) 1997 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.

;; Keywords: mule, multilingual, Cyrillic

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

;;; Code:

;;;###autoload
(defun setup-cyrillic-environment ()
  "Setup multilingual environment (MULE) for Cyrillic users."
  (interactive)
  (setup-8-bit-environment "Cyrillic" 'cyrillic-iso8859-5 'cyrillic-iso-8bit
			   "cyrillic-yawerty")
  (setq primary-language "Cyrillic"))

;; Display 

;; Written by Valery Alexeev <valery@math.uga.edu>.

(defun standard-display-cyrillic-translit (cyrillic-language)
  "Display a cyrillic buffer using a transliteration.
For readability, the table is slightly
different from the one used for the input method `cyrillic-translit'.

The argument specifies which language you are using;
that affects the choice of transliterations slightly.
Possible values are `ukranian', `bulgarian' or t (any other language).
If the argument is nil, we return the display table to its standard state."
  (if (null cyrillic-language)
      (setq standard-display-table (make-display-table))
    (aset standard-display-table ?��  [?a])
    (aset standard-display-table ?��  [?b])
    (aset standard-display-table ?��  [?v])
    (aset standard-display-table ?��  [?g])
    (aset standard-display-table ?��  [?d])
    (aset standard-display-table ?��  [?e])
    (aset standard-display-table ?��  [?y?o])
    (aset standard-display-table ?��  [?z?h])
    (aset standard-display-table ?��  [?z])
    (aset standard-display-table ?��  [?i])
    (aset standard-display-table ?��  [?j])
    (aset standard-display-table ?��  [?k])
    (aset standard-display-table ?��  [?l])
    (aset standard-display-table ?��  [?m])
    (aset standard-display-table ?��  [?n])
    (aset standard-display-table ?��  [?o])
    (aset standard-display-table ?��  [?p])
    (aset standard-display-table ?��  [?r])
    (aset standard-display-table ?��  [?s])
    (aset standard-display-table ?��  [?t])
    (aset standard-display-table ?��  [?u])
    (aset standard-display-table ?��  [?f])
    (aset standard-display-table ?��  [?k?h])
    (aset standard-display-table ?��  [?t?s])
    (aset standard-display-table ?��  [?c?h])
    (aset standard-display-table ?��  [?s?h])
    (aset standard-display-table ?��  [?s?c?h])
    (aset standard-display-table ?��  [?~])
    (aset standard-display-table ?��  [?y])
    (aset standard-display-table ?��  [?'])
    (aset standard-display-table ?��  [?e?'])
    (aset standard-display-table ?��  [?y?u])
    (aset standard-display-table ?��  [?y?a])
  
    (aset standard-display-table ?��  [?A])
    (aset standard-display-table ?��  [?B])
    (aset standard-display-table ?��  [?V])
    (aset standard-display-table ?��  [?G])
    (aset standard-display-table ?��  [?D])
    (aset standard-display-table ?��  [?E])
    (aset standard-display-table ?��  [?Y?o])
    (aset standard-display-table ?��  [?Z?h])
    (aset standard-display-table ?��  [?Z])
    (aset standard-display-table ?��  [?I])
    (aset standard-display-table ?��  [?J])
    (aset standard-display-table ?��  [?K])
    (aset standard-display-table ?\��  [?L])
    (aset standard-display-table ?��  [?M])
    (aset standard-display-table ?��  [?N])
    (aset standard-display-table ?��  [?O])
    (aset standard-display-table ?��  [?P])
    (aset standard-display-table ?��  [?R])
    (aset standard-display-table ?��  [?S])
    (aset standard-display-table ?��  [?T])
    (aset standard-display-table ?��  [?U])
    (aset standard-display-table ?��  [?F])
    (aset standard-display-table ?��  [?K?h])
    (aset standard-display-table ?��  [?T?s])
    (aset standard-display-table ?��  [?C?h])
    (aset standard-display-table ?��  [?S?h])
    (aset standard-display-table ?��  [?S?c?h])
    (aset standard-display-table ?��  [?~])
    (aset standard-display-table ?��  [?Y])
    (aset standard-display-table ?��  [?'])
    (aset standard-display-table ?��  [?E?'])
    (aset standard-display-table ?��  [?Y?u])
    (aset standard-display-table ?��  [?Y?a])

    (aset standard-display-table ?��  [?i?e])
    (aset standard-display-table ?��  [?i])
    (aset standard-display-table ?��  [?u])
    (aset standard-display-table ?��  [?d?j])
    (aset standard-display-table ?��  [?c?h?j])
    (aset standard-display-table ?��  [?g?j])
    (aset standard-display-table ?��  [?s])
    (aset standard-display-table ?��  [?k])
    (aset standard-display-table ?��  [?i])
    (aset standard-display-table ?��  [?j])
    (aset standard-display-table ?��  [?l?j])
    (aset standard-display-table ?��  [?n?j])
    (aset standard-display-table ?��  [?d?z])

    (aset standard-display-table ?��  [?Y?e])
    (aset standard-display-table ?��  [?Y?i])
    (aset standard-display-table ?��  [?U])
    (aset standard-display-table ?��  [?D?j])
    (aset standard-display-table ?\��  [?C?h?j])
    (aset standard-display-table ?��  [?G?j])
    (aset standard-display-table ?��  [?S])
    (aset standard-display-table ?��  [?K])
    (aset standard-display-table ?��  [?I])
    (aset standard-display-table ?��  [?J])
    (aset standard-display-table ?��  [?L?j])
    (aset standard-display-table ?��  [?N?j])
    (aset standard-display-table ?��  [?D?j])

    (when (eq cyrillic-language 'bulgarian)
      (aset standard-display-table ?�� [?s?h?t])
      (aset standard-display-table ?�� [?S?h?t])
      (aset standard-display-table ?�� [?i?u])
      (aset standard-display-table ?�� [?I?u])
      (aset standard-display-table ?�� [?i?a])
      (aset standard-display-table ?�� [?I?a]))

    (when (eq cyrillic-language 'ukranian) ; based on the official
					; transliteration table
      (aset standard-display-table ?�� [?y])
      (aset standard-display-table ?�� [?Y])
      (aset standard-display-table ?�� [?i])
      (aset standard-display-table ?�� [?Y])
      (aset standard-display-table ?�� [?i?u])
      (aset standard-display-table ?�� [?i?a]))))

;;
(provide 'cyril-util)

;;; cyril-util.el ends here
