;;; xml-lite.el --- an indentation-engine for XML

;; Copyright (C) 2002  Free Software Foundation, Inc.

;; Author:     Mike Williams <mdub@bigfoot.com>
;; Created:    February 2001
;; Keywords:   xml

;; This file is part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; This package provides a simple indentation engine for XML.  It is
;; intended for use in situations where the full power of the popular PSGML
;; package (DTD parsing, syntax checking) is not required.
;;
;; xml-lite is designed to be used in conjunction with the default GNU
;; Emacs sgml-mode, to provide a lightweight XML-editing environment.

;;; Thanks:
;;
;;    Jens Schmidt <Jens.Schmidt@oracle.com>
;;        for his feedback and suggestions

;;; Code:

(eval-when-compile (require 'cl))
(require 'sgml-mode)


;; Variables

(defgroup xml-lite nil
  "Customizable variables for XML-Lite mode."
  :group 'languages
  )

(defcustom xml-lite-basic-offset 2
  "*Specifies the basic indentation level for `xml-lite-indent-line'."
  :type 'integer
  :group 'xml-lite
  )

(defcustom xml-lite-electric-slash 'close
  "*If non-nil, inserting a '/' after a '<' behaves electrically.
If set to `indent', typing '</' just triggers reindentation.
If set to `close', typing '</' inserts an end-tag for the
enclosing XML element."
  :type '(choice (const :tag "Indent" indent)

                 (const :tag "Close" close)
                 (const :tag "No" nil))

  :group 'xml-lite
  )

(defcustom xml-lite-mode-line-string " XML"
  "*String to display in the modeline when `xml-lite-mode' is active.
Set this to nil if you don't want a modeline indicator for xml-lite-mode."
  :type 'string
  :group 'xml-lite)

(defcustom xml-lite-mode-hook nil
  "*Hook called by `xml-lite-mode'."
  :type 'hook
  :group 'xml-lite)

;;;###autoload
(defvar xml-lite-mode nil
  "Non-nil if `xml-lite-mode' is enabled.")
(make-variable-buffer-local 'xml-lite-mode)


;; Syntax analysis

(defsubst xml-lite-at-indentation-p ()
  "Return true if point is at the first non-whitespace character on the line."
  (save-excursion
    (skip-chars-backward " \t")
    (bolp)))

(defun xml-lite-in-string-p (&optional limit)
  "Determine whether point is inside a string.  If it is, return the
position of the character starting the string, else return nil.

Parse begins from LIMIT, which defaults to the preceding occurence of a tag
at the beginning of a line."
  (let ((context (sgml-lexical-context limit)))
    (if (eq (car context) 'string) (cdr context))))


;; Parsing
(defstruct (xml-lite-tag
            (:constructor xml-lite-make-tag (type start end name name-end)))
  type start end name name-end)
(defsubst xml-lite-parse-tag-name ()
  "Skip past a tag-name, and return the name."
  (buffer-substring-no-properties
   (point) (progn (skip-syntax-forward "w_") (point))))

(defsubst xml-lite-looking-back-at (s)
  (let ((limit (max (- (point) (length s)) (point-min))))
    (equal s (buffer-substring-no-properties limit (point)))))

(defsubst xml-lite-looking-at (s)
  (let ((limit (min (+ (point) (length s)))))
    (equal s (buffer-substring-no-properties (point) limit))))

(defun xml-lite-parse-tag-backward ()
  "Get information about the parent tag."
  (let ((limit (point))
        tag-type tag-start tag-end name name-end)
    (with-syntax-table sgml-tag-syntax-table
      (cond

       ((null (re-search-backward "[<>]" nil t)))
     
       ((= ?> (char-after))		;--- found tag-end ---
	(setq tag-end (1+ (point)))
	(goto-char tag-end)
	(cond
	 ((xml-lite-looking-back-at "--") ; comment
	  (setq tag-type 'comment
		tag-start (search-backward "<!--" nil t)))
	 ((xml-lite-looking-back-at "]]>") ; cdata
	  (setq tag-type 'cdata
		tag-start (search-backward "![CDATA[" nil t)))
	 (t
	  (setq tag-start (ignore-errors (backward-sexp) (point))))))
       
       ((= ?< (char-after))		;--- found tag-start ---
	;; !!! This should not happen because the caller should be careful
	;; that we do not start from within a tag !!!
	(setq tag-start (point))
	(goto-char (1+ tag-start))
	(cond
	 ((xml-lite-looking-at "!--")	; comment
	  (setq tag-type 'comment
		tag-end (search-forward "-->" nil t)))
	 ((xml-lite-looking-at "![CDATA[") ; cdata
	  (setq tag-type 'cdata
		tag-end (search-forward "]]>" nil t)))
	 (t
	  (goto-char tag-start)
	  (setq tag-end (ignore-errors (forward-sexp) (point)))))))
     
      (cond

       ((or tag-type (null tag-start)))
     
       ((= ?! (char-after (1+ tag-start))) ; declaration
	(setq tag-type 'decl))
     
       ((= ?? (char-after (1+ tag-start))) ; processing-instruction
	(setq tag-type 'pi))
     
       ((= ?/ (char-after (1+ tag-start))) ; close-tag
	(goto-char (+ 2 tag-start))
	(setq tag-type 'close
	      name (xml-lite-parse-tag-name)
	      name-end (point)))

       ((member				; JSP tags etc
	 (char-after (1+ tag-start))
	 '(?% ?#))
	(setq tag-type 'unknown))

       (t
	(goto-char (1+ tag-start))
	(setq tag-type 'open
	      name (xml-lite-parse-tag-name)
	      name-end (point))
	;; check whether it's an empty tag
	(if (or (and tag-end (eq ?/ (char-before (- tag-end 1))))
		(and (not sgml-xml-mode)
		     (member-ignore-case name sgml-empty-tags)))
	    (setq tag-type 'empty))))

      (cond
       (tag-start
	(goto-char tag-start)
	(xml-lite-make-tag tag-type tag-start tag-end name name-end))))))

(defsubst xml-lite-inside-tag-p (tag-info &optional point)
  "Return true if TAG-INFO contains the POINT."
  (let ((end (xml-lite-tag-end tag-info))
        (point (or point (point))))
    (or (null end)
        (> end point))))

(defun xml-lite-get-context (&optional full)
  "Determine the context of the current position.
If FULL is non-nil, parse back to the beginning of the buffer, otherwise
parse until we find a start-tag as the first thing on a line.

The context is a list of tag-info structures.  The last one is the tag
immediately enclosing the current position."
  (let ((here (point))
        (ignore nil)
        tag-info context)
    ;; CONTEXT keeps track of the tag-stack
    ;; IGNORE keeps track of the nesting level of point relative to the
    ;;   first (outermost) tag on the context.  This is the list of
    ;;   enclosing start-tags we'll have to ignore.
    (save-excursion

      (while
          (and (or (not context)
		   ignore
                   full
                   (not (xml-lite-at-indentation-p)))
               (setq tag-info (xml-lite-parse-tag-backward)))

        ;; This tag may enclose things we thought were tags.  If so,
        ;; discard them.
        (while (and context
                    (> (xml-lite-tag-end tag-info)
                       (xml-lite-tag-end (car context))))
          (setq context (cdr context)))
           
        (cond

         ;; inside a tag ...
         ((xml-lite-inside-tag-p tag-info here)
          (push tag-info context))

         ;; start-tag
         ((eq (xml-lite-tag-type tag-info) 'open)
	  (cond
	   ((null ignore) (push tag-info context))
	   ((eq t (compare-strings (xml-lite-tag-name tag-info) nil nil
				   (car ignore) nil nil t))
	    (setq ignore (cdr ignore)))
	   (t
	    ;; The open and close tags don't match.
	    (if (not sgml-xml-mode)
		;; Assume the open tag is simply not closed.
		(message "Unclosed tag <%s>" (xml-lite-tag-name tag-info))
	      (message "Unmatched tags <%s> and </%s>"
		       (xml-lite-tag-name tag-info) (pop ignore))))))

	 ;; end-tag
         ((eq (xml-lite-tag-type tag-info) 'close)
          (push (xml-lite-tag-name tag-info) ignore))
         
         )))

    ;; return context
    context
    ))

(defun xml-lite-show-context (&optional full)
  "Display the current context.
If FULL is non-nil, parse back to the beginning of the buffer."
  (interactive "P")
  (with-output-to-temp-buffer "*XML Context*"
    (pp (xml-lite-get-context full))))


;; Indenting

(defun xml-lite-calculate-indent ()
  "Calculate the column to which this line should be indented."
  (let* ((here (point))
         (context (xml-lite-get-context))
         (ref-tag-info (car context))
         (last-tag-info (car (last context))))

    (save-excursion
      (cond

       ;; no context
       ((null context) 0)

       ;; inside a comment
       ((eq 'comment (xml-lite-tag-type last-tag-info))
        (let ((mark (looking-at "--")))
          (goto-char (xml-lite-tag-start last-tag-info))
	  (forward-char 2)
	  (if mark (current-column)
	    (forward-char 2)
	    (+ (if (zerop (skip-chars-forward " \t")) 1 0)
	       (current-column)))))

       ;; inside a tag
       ((xml-lite-inside-tag-p last-tag-info here)
        
        (let ((start-of-enclosing-string
               (xml-lite-in-string-p (xml-lite-tag-start last-tag-info))))
          (cond
           ;; inside an attribute value
           (start-of-enclosing-string
            (goto-char start-of-enclosing-string)
            (1+ (current-column)))
           ;; if we have a tag-name, base indent on that
           ((and (xml-lite-tag-name-end last-tag-info)
                 (progn
                   (goto-char (xml-lite-tag-name-end last-tag-info))
                   (not (looking-at "[ \t]*$"))))
            (1+ (current-column)))
           ;; otherwise, add indent-offset
           (t
            (goto-char (xml-lite-tag-start last-tag-info))
            (+ (current-column) xml-lite-basic-offset)))))

       ;; inside an element
       (t
        ;; indent to start of tag
        (let ((indent-offset xml-lite-basic-offset))
          ;; add xml-lite-basic-offset, unless we're looking at the
          ;; matching end-tag
          (if (and (eq (length context) 1)
                   (xml-lite-looking-at "</"))
              (setq indent-offset 0))
          (goto-char (xml-lite-tag-start ref-tag-info))
          (+ (current-column) indent-offset)))

       ))))

(defun xml-lite-indent-line ()
  "Indent the current line as XML."
  (interactive)
  (let* ((savep (point))
	 (indent-col
	  (save-excursion
	    (beginning-of-line)
	    (skip-chars-forward " \t")
	    (if (>= (point) savep) (setq savep nil))
	    ;; calculate basic indent
	    (xml-lite-calculate-indent))))
    (if savep
	(save-excursion (indent-line-to indent-col))
      (indent-line-to indent-col))))


;; Editing shortcuts

(defun xml-lite-insert-end-tag ()
  "Insert an end-tag for the current element."
  (interactive)
  (let* ((context (xml-lite-get-context))
         (tag-info (car (last context)))
         (type (and tag-info (xml-lite-tag-type tag-info))))

    (cond

     ((null context)
      (error "Nothing to close"))

     ;; inside a tag
     ((xml-lite-inside-tag-p tag-info)
      (insert (cond
	       ((eq type 'open) 	" />")
	       ((eq type 'comment)	" -->")
	       ((eq type 'cdata)	"]]>")
	       ((eq type 'jsp) 		"%>")
	       ((eq type 'pi) 		"?>")
	       (t 			">"))))

     ;; inside an element
     ((eq type 'open)
      (insert "</" (xml-lite-tag-name tag-info) ">")
      (indent-according-to-mode))

     (t
      (error "Nothing to close")))))

(defun xml-lite-slash (arg)
  "Insert ARG slash characters.
Behaves electrically if `xml-lite-electric-slash' is non-nil."
  (interactive "p")
  (cond
   ((not (and (eq (char-before) ?<) (= arg 1)))
    (insert-char ?/ arg))
   ((eq xml-lite-electric-slash 'indent)
    (insert-char ?/ 1)
    (indent-according-to-mode))
   ((eq xml-lite-electric-slash 'close)
    (delete-backward-char 1)
    (xml-lite-insert-end-tag))
   (t
    (insert-char ?/ arg))))


;; Keymap

(defvar xml-lite-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c/" 'xml-lite-insert-end-tag)
    (define-key map "\C-c\C-s" 'xml-lite-show-context)
    (define-key map "/" 'xml-lite-slash)
    map)
  "Key bindings for `xml-lite-mode'.")


;; Minor mode

;;;###autoload
(define-minor-mode xml-lite-mode
  "Toggle `xml-lite-mode'.
With ARG, enable xml-lite-mode if and only if ARG is positive.

xml-lite-mode provides indentation for XML tags.  The value of
`xml-lite-basic-offset' determines the amount of indentation.

Key bindings:
\\{xml-lite-mode-map}"
  nil                                   ; initial value
  " XML"                                ; mode indicator
  'xml-lite-mode-map                    ; keymap
  (if xml-lite-mode
      (progn
        (if (eq major-mode 'fundamental-mode) (sgml-mode))
	(set (make-local-variable 'sgml-xml-mode) t)
        (set (make-local-variable 'xml-lite-orig-indent-line-function)
	     indent-line-function)
	(set (make-local-variable 'indent-line-function) 'xml-lite-indent-line))
    (kill-local-variable 'sgml-xml-mode)
    (setq indent-line-function xml-lite-orig-indent-line-function)))

(provide 'xml-lite)

;;; xml-lite.el ends here
