;;; html2text.el --- a simple html to plain text converter
;; Copyright (C) 2002, 2003 Free Software Foundation, Inc.

;; Author: Joakim Hove <hove@phys.ntnu.no>

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; These functions provide a simple way to wash/clean html infected
;; mails.  Definitely do not work in all cases, but some improvement
;; in readability is generally obtained. Formatting is only done in
;; the buffer, so the next time you enter the article it will be
;; "re-htmlized".
;;
;; The main function is "html2text"

;;; Code:

;;
;; <Global variables>
;;

(eval-when-compile
  (require 'cl))

(defvar html2text-format-single-element-list '(("hr" . html2text-clean-hr)))

(defvar html2text-replace-list
  '(("&nbsp;" . " ") ("&gt;" . ">") ("&lt;" . "<") ("&quot;" . "\""))
  "The map of entity to text.

This is an alist were each element is a dotted pair consisting of an
old string, and a replacement string. This replacement is done by the
function \"html2text-substitute\" which basically performs a
replace-string operation for every element in the list. This is
completely verbatim - without any use of REGEXP.")

(defvar html2text-remove-tag-list
  '("html" "body" "p" "img" "dir" "head" "div" "br" "font" "title" "meta")
  "A list of removable tags.

This is a list of tags which should be removed, without any
formatting.  Observe that if you the tags in the list are presented
*without* any \"<\" or \">\". All occurences of a tag appearing in
this list are removed, irrespective of whether it is a closing or
opening tag, or if the tag has additional attributes. The actual
deletion is done by the function \"html2text-remove-tags\".

For instance the text:

\"Here comes something <font size\"+3\" face=\"Helvetica\"> big </font>.\"

will be reduced to:

\"Here comes something big.\"

If this list contains the element \"font\".")

(defvar html2text-format-tag-list
  '(("b" 	  . html2text-clean-bold)
    ("u" 	  . html2text-clean-underline)
    ("i" 	  . html2text-clean-italic)
    ("blockquote" . html2text-clean-blockquote)
    ("a"          . html2text-clean-anchor)
    ("ul"         . html2text-clean-ul)
    ("ol"         . html2text-clean-ol)
    ("dl"         . html2text-clean-dl)
    ("center"     . html2text-clean-center))
  "An alist of tags and processing functions.

This is an alist where each dotted pair consists of a tag, and then
the name of a function to be called when this tag is found. The
function is called with the arguments p1, p2, p3 and p4. These are
demontrated below:

\"<b> This is bold text </b>\"
 ^   ^                 ^    ^
 |   |                 |    |
p1  p2                p3   p4

Then the called function will typically format the text somewhat and
remove the tags.")

(defvar html2text-remove-tag-list2  '("li" "dt" "dd" "meta")
  "Another list of removable tags.

This is a list of tags which are removed similarly to the list
`html2text-remove-tag-list' - but these tags are retained for the
formatting, and then moved afterward.")

;;
;; </Global variables>
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; <Utility functions>
;;

(defun html2text-buffer-head ()
  (if (string= mode-name "Article")
      (beginning-of-buffer)
    (beginning-of-buffer)
    )
  )

(defun html2text-replace-string (from-string to-string p1 p2)
  (goto-char p1)
  (let ((delta (- (string-width to-string) (string-width from-string)))
	(change 0))
    (while (search-forward from-string p2 t)
      (replace-match to-string)
      (setq change (+ change delta))
      )
    change
    )
  )

;;
;; </Utility functions>
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; <Functions related to attributes> i.e. <font size=+3>
;;

(defun html2text-attr-value (attr-list attr)
  (nth 1 (assoc attr attr-list))
  )

(defun html2text-get-attr (p1 p2 tag)
  (goto-char p1)
  (re-search-forward " +[^ ]" p2 t)
  (let* ((attr-string (buffer-substring-no-properties (1- (point)) (1- p2)))
	 (tmp-list (split-string attr-string))
	 (attr-list)
	 (counter 0)
	 (prev (car tmp-list))
	 (this (nth 1 tmp-list))
	 (next (nth 2 tmp-list))
	 (index 1))

    (cond
     ;; size=3
     ((string-match "[^ ]=[^ ]" prev)
      (let ((attr  (nth 0 (split-string prev "=")))
	    (value (nth 1 (split-string prev "="))))
	(setq attr-list (cons (list attr value) attr-list))
	)
      )
     ;; size= 3
     ((string-match "[^ ]=\\'" prev)
      (setq attr-list (cons (list (substring prev 0 -1) this) attr-list))
      )
     )

    (while (< index (length tmp-list))
      (cond
       ;; size=3
       ((string-match "[^ ]=[^ ]" this)
	(let ((attr  (nth 0 (split-string this "=")))
	      (value (nth 1 (split-string this "="))))
	  (setq attr-list (cons (list attr value) attr-list))
	  )
	)
       ;; size =3
       ((string-match "\\`=[^ ]" this)
	(setq attr-list (cons (list prev (substring this 1)) attr-list)))

       ;; size= 3
       ((string-match "[^ ]=\\'" this)
	(setq attr-list (cons (list (substring this 0 -1) next) attr-list))
	)

       ;; size = 3
       ((string= "=" this)
	(setq attr-list (cons (list prev next) attr-list))
	)
       )
      (setq index (1+ index))
      (setq prev this)
      (setq this next)
      (setq next (nth (1+ index) tmp-list))
      )

    ;;
    ;; Tags with no accompanying "=" i.e. value=nil
    ;;
    (setq prev (car tmp-list))
    (setq this (nth 1 tmp-list))
    (setq next (nth 2 tmp-list))
    (setq index 1)

    (if (not (string-match "=" prev))
	(progn
	  (if (not (string= (substring this 0 1) "="))
	      (setq attr-list (cons (list prev nil) attr-list))
	    )
	  )
      )

    (while (< index (1- (length tmp-list)))
      (if (not (string-match "=" this))
	  (if (not (or (string= (substring next 0 1) "=")
		       (string= (substring prev -1) "=")))
	      (setq attr-list (cons (list this nil) attr-list))
	    )
	)
      (setq index (1+ index))
      (setq prev this)
      (setq this next)
      (setq next (nth (1+ index) tmp-list))
      )

    (if this
	(progn
	  (if (not (string-match "=" this))
	      (progn
		(if (not (string= (substring prev -1) "="))
		    (setq attr-list (cons (list this nil) attr-list))
		  )
		)
	    )
	  )
      )
    attr-list ;; return - value
    )
  )

;;
;; </Functions related to attributes>
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; <Functions to be called to format a tag-pair>
;;
(defun html2text-clean-list-items (p1 p2 list-type)
  (goto-char p1)
  (let ((item-nr 0)
	(items   0))
    (while (re-search-forward "<li>" p2 t)
      (setq items (1+ items)))
    (goto-char p1)
    (while (< item-nr items)
      (setq item-nr (1+ item-nr))
      (re-search-forward "<li>" (point-max) t)
      (cond
       ((string= list-type "ul") (insert " o "))
       ((string= list-type "ol") (insert (format " %s: " item-nr)))
       (t (insert " x ")))
      )
    )
  )

(defun html2text-clean-dtdd (p1 p2)
  (goto-char p1)
  (let ((items   0)
	(item-nr 0))
    (while (re-search-forward "<dt>" p2 t)
      (setq items (1+ items)))
    (goto-char p1)
    (while (< item-nr items)
      (setq item-nr (1+ item-nr))
      (re-search-forward "<dt>\\([ ]*\\)" (point-max) t)
      (when (match-string 1)
	(delete-region (point) (- (point) (string-width (match-string 1)))))
      (let ((def-p1 (point))
	    (def-p2 0))
	(re-search-forward "\\([ ]*\\)\\(</dt>\\|<dd>\\)" (point-max) t)
	(if (match-string 1)
	    (progn
	      (let* ((mw1 (string-width (match-string 1)))
		     (mw2 (string-width (match-string 2)))
		     (mw  (+ mw1 mw2)))
		(goto-char (- (point) mw))
		(delete-region (point) (+ (point) mw1))
		(setq def-p2 (point))))
	  (setq def-p2 (- (point) (string-width (match-string 2)))))
	(put-text-property def-p1 def-p2 'face 'bold)))))

(defun html2text-delete-tags (p1 p2 p3 p4)
  (delete-region p1 p2)
  (delete-region (- p3 (- p2 p1)) (- p4 (- p2 p1))))

(defun html2text-delete-single-tag (p1 p2)
  (delete-region p1 p2))

(defun html2text-clean-hr (p1 p2)
  (html2text-delete-single-tag p1 p2)
  (goto-char p1)
  (newline 1)
  (insert (make-string fill-column ?-))
  )

(defun html2text-clean-ul (p1 p2 p3 p4)
  (html2text-delete-tags p1 p2 p3 p4)
  (html2text-clean-list-items p1 (- p3 (- p1 p2)) "ul")
  )

(defun html2text-clean-ol (p1 p2 p3 p4)
  (html2text-delete-tags p1 p2 p3 p4)
  (html2text-clean-list-items p1 (- p3 (- p1 p2)) "ol")
  )

(defun html2text-clean-dl (p1 p2 p3 p4)
  (html2text-delete-tags p1 p2 p3 p4)
  (html2text-clean-dtdd p1 (- p3 (- p1 p2)))
  )

(defun html2text-clean-center (p1 p2 p3 p4)
  (html2text-delete-tags p1 p2 p3 p4)
  (center-region p1 (- p3 (- p2 p1)))
  )

(defun html2text-clean-bold (p1 p2 p3 p4)
  (put-text-property p2 p3 'face 'bold)
  (html2text-delete-tags p1 p2 p3 p4)
  )

(defun html2text-clean-title (p1 p2 p3 p4)
  (put-text-property p2 p3 'face 'bold)
  (html2text-delete-tags p1 p2 p3 p4)
  )

(defun html2text-clean-underline (p1 p2 p3 p4)
  (put-text-property p2 p3 'face 'underline)
  (html2text-delete-tags p1 p2 p3 p4)
  )

(defun html2text-clean-italic (p1 p2 p3 p4)
  (put-text-property p2 p3 'face 'italic)
  (html2text-delete-tags p1 p2 p3 p4)
  )

(defun html2text-clean-font (p1 p2 p3 p4)
  (html2text-delete-tags p1 p2 p3 p4)
  )

(defun html2text-clean-blockquote (p1 p2 p3 p4)
  (html2text-delete-tags p1 p2 p3 p4)
  )

(defun html2text-clean-anchor (p1 p2 p3 p4)
  ;; If someone can explain how to make the URL clickable I will
  ;; surely improve upon this.
  (let* ((attr-list (html2text-get-attr p1 p2 "a"))
	 (href (html2text-attr-value attr-list "href")))
    (delete-region p1 p4)
    (when href
      (goto-char p1)
      (insert (substring href 1 -1 ))
      (put-text-property p1 (point) 'face 'bold))))

;;
;; </Functions to be called to format a tag-pair>
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; <Functions to be called to fix up paragraphs>
;;

(defun html2text-fix-paragraph (p1 p2)
  (goto-char p1)
  (let ((has-br-line)
	(refill-start)
	(refill-stop))
    (if (re-search-forward "<br>$" p2 t)
	(setq has-br-line t)
      )
    (if has-br-line
	(progn
	  (goto-char p1)
	  (if (re-search-forward ".+[^<][^b][^r][^>]$" p2 t)
	      (progn
		(beginning-of-line)
		(setq refill-start (point))
		(goto-char p2)
		(re-search-backward ".+[^<][^b][^r][^>]$" refill-start t)
		(next-line 1)
		(end-of-line)
		;; refill-stop should ideally be adjusted to
		;; accomodate the "<br>" strings which are removed
		;; between refill-start and refill-stop.  Can simply
		;; be returned from my-replace-string
		(setq refill-stop (+ (point)
				     (html2text-replace-string
				      "<br>" ""
				      refill-start (point))))
		;; (message "Point = %s  refill-stop = %s" (point) refill-stop)
		;; (sleep-for 4)
		(fill-region refill-start refill-stop)
		)
	    )
	  )
      )
    )
  (html2text-replace-string "<br>" "" p1 p2)
  )

;;
;; This one is interactive ...
;;
(defun html2text-fix-paragraphs ()
  "This _tries_ to fix up the paragraphs - this is done in quite a ad-hook
fashion, quite close to pure guess-work. It does work in some cases though."
  (interactive)
  (html2text-buffer-head)
  (replace-regexp "^<br>$" "")
  ;; Removing lonely <br> on a single line, if they are left intact we
  ;; dont have any paragraphs at all.
  (html2text-buffer-head)
  (while (not (eobp))
    (let ((p1 (point)))
      (forward-paragraph 1)
      ;;(message "Kaller fix med p1=%s  p2=%s " p1 (1- (point))) (sleep-for 5)
      (html2text-fix-paragraph p1 (1- (point)))
      (goto-char p1)
      (when (not (eobp))
	(forward-paragraph 1)))))

;;
;; </Functions to be called to fix up paragraphs>
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; <Interactive functions>
;;

(defun html2text-remove-tags (tag-list)
  "Removes the tags listed in the list \"html2text-remove-tag-list\".
See the documentation for that variable."
  (interactive)
  (dolist (tag tag-list)
    (html2text-buffer-head)
    (while (re-search-forward (format "\\(</?%s[^>]*>\\)" tag) (point-max) t)
      (delete-region (match-beginning 0) (match-end 0)))))

(defun html2text-format-tags ()
  "See the variable \"html2text-format-tag-list\" for documentation"
  (interactive)
  (dolist (tag-and-function html2text-format-tag-list)
    (let ((tag      (car tag-and-function))
	  (function (cdr tag-and-function)))
      (html2text-buffer-head)
      (while (re-search-forward (format "\\(<%s\\( [^>]*\\)?>\\)" tag)
				(point-max) t)
	(let ((p1)
	      (p2 (point))
	      (p3) (p4)
	      (attr (match-string 1)))
	  (search-backward "<" (point-min) t)
	  (setq p1 (point))
	  (re-search-forward (format "</%s>" tag) (point-max) t)
	  (setq p4 (point))
	  (search-backward "</" (point-min) t)
	  (setq p3 (point))
	  (funcall function p1 p2 p3 p4)
	  (goto-char p1)
	  )
	)
      )
    )
  )

(defun html2text-substitute ()
  "See the variable \"html2text-replace-list\" for documentation"
  (interactive)
  (dolist (e html2text-replace-list)
    (html2text-buffer-head)
    (let ((old-string (car e))
	  (new-string (cdr e)))
      (html2text-replace-string old-string new-string (point-min) (point-max))
      )
    )
  )

(defun html2text-format-single-elements ()
  ""
  (interactive)
  (dolist (tag-and-function html2text-format-single-element-list)
    (let ((tag      (car tag-and-function))
	  (function (cdr tag-and-function)))
      (html2text-buffer-head)
      (while (re-search-forward (format "\\(<%s\\( [^>]*\\)?>\\)" tag)
				(point-max) t)
	(let ((p1)
	      (p2 (point)))
	  (search-backward "<" (point-min) t)
	  (setq p1 (point))
	  (funcall function p1 p2)
	  )
	)
      )
    )
  )

;;
;; Main function
;;

;;;###autoload
(defun html2text ()
  "Convert HTML to plain text in the current buffer."
  (interactive)
  (save-excursion
    (let ((case-fold-search t)
	  (buffer-read-only))
      (html2text-remove-tags html2text-remove-tag-list)
      (html2text-format-tags)
      (html2text-remove-tags html2text-remove-tag-list2)
      (html2text-substitute)
      (html2text-format-single-elements)
      (html2text-fix-paragraphs))))

;;
;; </Interactive functions>
;;

;;; arch-tag: e9e57b79-35d4-4de1-a647-e7e01fe56d1e
;;; html2text.el ends here
