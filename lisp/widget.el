;;; widget.el --- a library of user interface components
;;
;; Copyright (C) 1996, 1997, 2002, 2003, 2004,
;;   2005 Free Software Foundation, Inc.
;;
;; Author: Per Abrahamsen <abraham@dina.kvl.dk>
;; Keywords: help, extensions, faces, hypermedia
;; Version: 1.9920
;; X-URL: http://www.dina.kvl.dk/~abraham/custom/

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
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; The widget library is partially documented in the `widget' Info
;; file.
;;
;; This file only contains the code needed to define new widget types.
;; Everything else is autoloaded from `wid-edit.el'.

;;; Code:

;; Doing this is unnecessary in Emacs 20.  Kept as dummy in case
;; external libraries call it.  We save a kb or two of purespace by
;; dummying-out such definitions generally.
(defmacro define-widget-keywords (&rest keys)
;;;  ;; Don't use backquote, since that makes trouble trying to
;;;  ;; re-bootstrap from just the .el files.
;;;  (list 'eval-and-compile
;;;    (list 'let (list (list 'keywords (list 'quote keys)))
;;;	 (list 'while 'keywords
;;;	  (list 'or (list 'boundp (list 'car 'keywords))
;;;	      (list 'set (list 'car 'keywords) (list 'car 'keywords)))
;;;	  (list 'setq 'keywords (list 'cdr 'keywords)))))
  )

;;;(define-widget-keywords :documentation-indent
;;;  :complete-function :complete :button-overlay
;;;  :field-overlay
;;;  :documentation-shown :button-prefix
;;;  :button-suffix :mouse-down-action :glyph-up :glyph-down :glyph-inactive
;;;  :prompt-internal :prompt-history :prompt-match
;;;  :prompt-value  :deactivate :active
;;;  :inactive :activate :sibling-args :delete-button-args
;;;  :insert-button-args :append-button-args :button-args
;;;  :tag-glyph :off-glyph :on-glyph :valid-regexp
;;;  :secret :sample-face :sample-face-get :case-fold
;;;  :create :convert-widget :format :value-create :offset :extra-offset
;;;  :tag :doc :from :to :args :value :action
;;;  :value-set :value-delete :match :parent :delete :menu-tag-get
;;;  :value-get :choice :void :menu-tag :on :off :on-type :off-type
;;;  :notify :entry-format :button :children :buttons :insert-before
;;;  :delete-at :format-handler :widget :value-pos :value-to-internal
;;;  :indent :size :value-to-external :validate :error :directory
;;;  :must-match :type-error :value-inline :inline :match-inline :greedy
;;;  :button-face-get :button-face :value-face :keymap :entry-from
;;;  :entry-to :help-echo :documentation-property :tab-order)

(defun define-widget (name class doc &rest args)
  "Define a new widget type named NAME from CLASS.

NAME and CLASS should both be symbols, CLASS should be one of the
existing widget types, or nil to create the widget from scratch.

After the new widget has been defined, the following two calls will
create identical widgets:

* (widget-create NAME)

* (apply 'widget-create CLASS ARGS)

The third argument DOC is a documentation string for the widget."
  (put name 'widget-type (cons class args))
  (put name 'widget-documentation doc)
  name)

;; This is used by external widget code (in W3, at least).
(defalias 'widget-plist-member 'plist-member)

;;; The End.

(provide 'widget)

;;; arch-tag: 932c71a3-9aeb-4827-a293-8b88b26d5c58
;;; widget.el ends here
