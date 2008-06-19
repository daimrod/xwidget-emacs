;;; face-remap.el --- Functions for managing `face-remapping-alist'
;;
;; Copyright (C) 2008 Free Software Foundation, Inc.
;;
;; Author: Miles Bader <miles@gnu.org>
;; Keywords: faces face display user commands
;;
;; This file is part of GNU Emacs.
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;;

;;; Commentary:

;;
;; This file defines some simple operations that can be used for
;; maintaining the `face-remapping-alist' in a cooperative way.  This is
;; especially important for the `default' face.
;;
;; Each face-remapping definition in `face-remapping-alist' added by
;; this code uses the form:
;;
;;   (face RELATIVE_SPECS_1 RELATIVE_SPECS_2 ... BASE_SPECS)
;;
;; The "specs" values are a lists of face names or face attribute-value
;; pairs, and are merged together, with earlier values taking precedence.
;;
;; The RELATIVE_SPECS_* values are added by `face-remap-add-relative'
;; (and removed by `face-remap-remove-relative', and are intended for
;; face "modifications" (such as increasing the size).  Typical users of
;; relative specs would be minor modes.
;;
;; BASE_SPECS is the lowest-priority value, and by default is just the
;; face name, which causes the global definition of that face to be used.
;;
;; A non-default value of BASE_SPECS may also be set using
;; `face-remap-set-base'.  Because this _overwrites_ the default
;; value inheriting from the global face definition, it is up to the
;; caller of face-remap-set-base to add such inheritance if it is
;; desired.  A typical use of face-remap-set-base would be a major
;; mode setting face remappings, e.g., of the default face.
;;
;; All modifications cause face-remapping-alist to be made buffer-local.
;;


;;; Code:


;; ----------------------------------------------------------------
;; Utility functions

;; Names of face attributes corresponding to lisp face-vector positions.
;; This variable should probably be defined in C code where the actual
;; definitions are available.
;;
(defvar internal-lisp-face-attributes
  [nil
   :family :foundry :swidth :height :weight :slant :underline :inverse
   :foreground :background :stipple :overline :strike :box
   :font :inherit :fontset :vector])

(defun face-attrs-more-relative-p (attrs1 attrs2)
"Return true if ATTRS1 contains a greater number of relative
face-attributes than ATTRS2.  A face attribute is considered
relative if `face-attribute-relative-p' returns non-nil.

ATTRS1 and ATTRS2 may be any value suitable for a `face' text
property, including face names, lists of face names,
face-attribute plists, etc.

This function can be used as a predicate with `sort', to sort
face lists so that more specific faces are located near the end."
  (unless (vectorp attrs1)
    (setq attrs1 (face-attributes-as-vector attrs1)))
  (unless (vectorp attrs2)
    (setq attrs2 (face-attributes-as-vector attrs2)))
  (let ((rel1-count 0) (rel2-count 0))
    (dotimes (i (length attrs1))
      (let ((attr (aref internal-lisp-face-attributes i)))
	(when attr
	  (when (face-attribute-relative-p attr (aref attrs1 i))
	    (setq rel1-count (+ rel1-count 1)))
	  (when (face-attribute-relative-p attr (aref attrs2 i))
	    (setq rel2-count (+ rel2-count 1))))))
    (< rel1-count rel2-count)))

(defun face-remap-order (entry)
  "Order ENTRY so that more relative face specs are near the beginning.
The list structure of ENTRY may be destructively modified."
  (setq entry (nreverse entry))
  (setcdr entry (sort (cdr entry) 'face-attrs-more-relative-p))
  (nreverse entry))

;;;### autoload
(defun face-remap-add-relative (face &rest specs)
  "Add a face remapping entry of FACE to SPECS in the current buffer.

Return a cookie which can be used to delete the remapping with
`face-remap-remove-relative'.

SPECS can be any value suitable for the `face' text property,
including a face name, a list of face names, or a face-attribute
property list.  The attributes given by SPECS will be merged with
any other currently active face remappings of FACE, and with the
global definition of FACE.  An attempt is made to sort multiple
entries so that entries with relative face-attributes are applied
after entries with absolute face-attributes.

The base (lowest priority) remapping may be set to a specific
value, instead of the default of the global face definition,
using `face-remap-set-base'."
  (make-local-variable 'face-remapping-alist)
  (let ((entry (assq face face-remapping-alist)))
    (when (null entry)
      (setq entry (list face face))	; explicitly merge with global def
      (push entry face-remapping-alist))
    (setcdr entry (face-remap-order (cons specs (cdr entry))))
    (cons face specs)))

(defun face-remap-remove-relative (cookie)
  "Remove a face remapping previously added by `face-remap-add-relative'.
COOKIE should be the return value from that function."
  (let ((remapping (assq (car cookie) face-remapping-alist)))
    (when remapping
      (let ((updated-entries (remq (cdr cookie) (cdr remapping))))
	(unless (eq updated-entries (cdr remapping))
	  (setcdr remapping updated-entries)
	  (when (or (null updated-entries)
		    (and (eq (car-safe updated-entries) (car cookie))
			 (null (cdr updated-entries))))
	    (setq face-remapping-alist
		  (remq remapping face-remapping-alist)))
	  (cdr cookie))))))

;;;### autoload
(defun face-remap-reset-base (face)
  "Set the base remapping of FACE to inherit from FACE's global definition."
  (let ((entry (assq face face-remapping-alist)))
    (when entry
      ;; If there's nothing except a base remapping, we simply remove
      ;; the entire remapping entry, as setting the base to the default
      ;; would be the same as the global definition.  Otherwise, we
      ;; modify the base remapping.
      (if (null (cddr entry))		; nothing except base remapping
	  (setq face-remapping-alist	; so remove entire entry
		(remq entry face-remapping-alist))
	(setcar (last entry) face)))))  ; otherwise, just inherit global def

;;;### autoload
(defun face-remap-set-base (face &rest specs)
  "Set the base remapping of FACE in the current buffer to SPECS.
If SPECS is empty, the default base remapping is restored, which
inherits from the global definition of FACE; note that this is
different from SPECS containing a single value `nil', which does
not inherit from the global definition of FACE."
  (if (or (null specs)
	  (and (eq (car specs) face) (null (cdr specs)))) ; default
      ;; Set entry back to default
      (face-remap-reset-base face)
    ;; Set the base remapping
    (make-local-variable 'face-remapping-alist)
    (let ((entry (assq face face-remapping-alist)))
      (if entry
	  (setcar (last entry) specs)	; overwrite existing base entry
	(push (list face specs) face-remapping-alist)))))


;; ----------------------------------------------------------------
;; text-scale-mode

(defcustom text-scale-mode-step 1.2
  "Scale factor used by `text-scale-mode'.
Each positive or negative step scales the default face height by this amount."
  :group 'display
  :type 'number)

;; current remapping cookie for text-scale-mode
(defvar text-scale-mode-remapping nil)
(make-variable-buffer-local 'text-scale-mode-remapping)

;; Lighter displayed for text-scale-mode in mode-line minor-mode list
(defvar text-scale-mode-lighter "+0")
(make-variable-buffer-local 'text-scale-mode-lighter)

;; Number of steps that text-scale-mode will increase/decrease text height
(defvar text-scale-mode-amount 0)
(make-variable-buffer-local 'text-scale-mode-amount)

(define-minor-mode text-scale-mode
  "Minor mode for displaying buffer text in a larger/smaller font than usual.

The amount of scaling is determined by the variable
`text-scale-mode-amount': one step scales the global default
face size by the value of the variable `text-scale-mode-step'
\(a negative amount shrinks the text).

The `text-scale-increase' and `text-scale-decrease' functions may
be used to interactively modify the variable
`text-scale-mode-amount' (they also enable or disable
`text-scale-mode' as necessary)."
  :lighter (" " text-scale-mode-lighter)
  (when text-scale-mode-remapping
    (face-remap-remove-relative text-scale-mode-remapping))
  (setq text-scale-mode-lighter
	(format (if (>= text-scale-mode-amount 0) "+%d" "%d")
		text-scale-mode-amount))
  (setq text-scale-mode-remapping
	(and text-scale-mode
	     (face-remap-add-relative 'default
					  :height
					  (expt text-scale-mode-step
						text-scale-mode-amount))))
  (force-window-update (current-buffer)))

;;;###autoload
(defun text-scale-increase (&optional inc)
  "Increase the height of the default face in the current buffer by INC steps.
If the new height is other than the default, `text-scale-mode' is enabled.

Each step scales the height of the default face by the variable
`text-scale-mode-step' (a negative number of steps decreases the
height by the same amount).  As a special case, an argument of 0
will remove any scaling currently active."
  (interactive "p")
  (setq text-scale-mode-amount
	(if (= inc 0) 0 (+ (if text-scale-mode text-scale-mode-amount 0) inc)))
  (text-scale-mode (if (zerop text-scale-mode-amount) -1 1)))

;;;###autoload
(defun text-scale-decrease (&optional dec)
  "Decrease the height of the default face in the current buffer by DEC steps.
See `text-scale-increase' for more details."
  (interactive "p")
  (text-scale-increase (- dec)))

;;;###autoload (define-key ctl-x-map [(control ?+)] 'text-scale-adjust)
;;;###autoload (define-key ctl-x-map [(control ?-)] 'text-scale-adjust)
;;;###autoload (define-key ctl-x-map [(control ?=)] 'text-scale-adjust)
;;;###autoload (define-key ctl-x-map [(control ?0)] 'text-scale-adjust)
;;;###autoload
(defun text-scale-adjust (&optional inc)
  "Increase or decrease the height of the default face in the current buffer.

The actual adjustment made depends on the final component of the
key-binding used to invoke the command, with all modifiers removed:

   +, =   Increase the default face height by one step
   -      Decrease the default face height by one step
   0      Reset the default face height to the global default

Then, continue to read input events and further adjust the face
height as long as the input event read (with all modifiers removed)
is one of the above.

Each step scales the height of the default face by the variable
`text-scale-mode-step' (a negative number of steps decreases the
height by the same amount).  As a special case, an argument of 0
will remove any scaling currently active.

This command is a special-purpose wrapper around the
`text-scale-increase' command which makes repetition convenient
even when it is bound in a non-top-level keymap.  For binding in
a top-level keymap, `text-scale-increase' or
`text-scale-decrease' may be more appropriate."
  (interactive "p")
  (let ((first t)
	(step t)
	(ev last-command-event))
    (while step
      (let ((base (event-basic-type ev)))
	(cond ((or (eq base ?+) (eq base ?=))
	       (setq step inc))
	      ((eq base ?-)
	       (setq step (- inc)))
	      ((eq base ?0)
	       (setq step 0))
	      (first
	       (setq step inc))
	      (t
	       (setq step nil))))
      (when step
	(text-scale-increase step)
	(setq inc 1 first nil)
	(setq ev (read-event))))
    (push ev unread-command-events)))


;; ----------------------------------------------------------------
;; buffer-face-mode

(defcustom buffer-face-mode-face 'variable-pitch
  "The face specification used by `buffer-face-mode'.
It may contain any value suitable for a `face' text property,
including a face name, a list of face names, a face-attribute
plist, etc."
  :group 'display)

;; current remapping cookie for  buffer-face-mode
(defvar buffer-face-mode-remapping nil)
(make-variable-buffer-local 'buffer-face-mode-remapping)

;;;###autoload
(define-minor-mode buffer-face-mode
  "Minor mode for a buffer-specific default face.
When enabled, the face specified by the variable
`buffer-face-mode-face' is used to display the buffer text."
  :lighter " BufFace"
  (when buffer-face-mode-remapping
    (face-remap-remove-relative buffer-face-mode-remapping))
  (setq buffer-face-mode-remapping
	(and buffer-face-mode
	     (face-remap-add-relative 'default buffer-face-mode-face)))
  (force-window-update (current-buffer)))

;;;###autoload
(defun buffer-face-set (face)
  "Enable `buffer-face-mode', using the face FACE.
If FACE is nil, then `buffer-face-mode' is disabled.  This
function will make the variable `buffer-face-mode-face' buffer
local, and set it to FACE."
  (interactive (list (read-face-name "Set buffer face")))
  (if (null face)
      (buffer-face-mode 0)
    (set (make-local-variable 'buffer-face-mode-face) face)
    (buffer-face-mode t)))

;;;###autoload
(defun buffer-face-toggle (face)
  "Toggle `buffer-face-mode', using the face FACE.

If `buffer-face-mode' is already enabled, and is currently using
the face FACE, then it is disabled; if buffer-face-mode is
disabled, or is enabled and currently displaying some other face,
then is left enabled, but the face changed to FACE.  This
function will make the variable `buffer-face-mode-face' buffer
local, and set it to FACE."
  (interactive (list buffer-face-mode-face))
  (if (or (null face)
	  (and buffer-face-mode (equal buffer-face-mode-face face)))
      (buffer-face-mode 0)
    (set (make-local-variable 'buffer-face-mode-face) face)
    (buffer-face-mode t)))

(defun buffer-face-mode-invoke (face arg &optional interactive)
  "Enable or disable `buffer-face-mode' using the face FACE, and argument ARG.
ARG is interpreted in the usual manner for minor-mode commands.
Besides the choice of face, this is the same as the `buffer-face-mode' command.
If INTERACTIVE is non-nil, a message will be displayed describing the result."
  (let ((last-message (current-message)))
    (if (or (eq arg 'toggle) (not arg))
	(buffer-face-toggle face)
      (buffer-face-set (and (> (prefix-numeric-value arg) 0) face)))
    (when interactive
      (unless (and (current-message)
		   (not (equal last-message (current-message))))
	(message "Buffer-Face mode %sabled"
		 (if buffer-face-mode "en" "dis"))))))


;; ----------------------------------------------------------------
;; variable-pitch-mode

;;;###autoload
(defun variable-pitch-mode (&optional arg)
  "Variable-pitch default-face mode.
An interface to `buffer-face-mode' which uses the `variable-pitch' face.
Besides the choice of face, it is the same as `buffer-face-mode'."
  (interactive (list (or current-prefix-arg 'toggle)))
  (buffer-face-mode-invoke 'variable-pitch arg (interactive-p)))


(provide 'face-remap)

;; arch-tag: 5c5f034b-8d58-4967-82bd-d61fd364e686
;;; face-remap.el ends here
