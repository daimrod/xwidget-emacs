;;; mouse.el --- window system-independent mouse support.

;;; Copyright (C) 1993 Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: hardware

;;; This file is part of GNU Emacs.

;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.

;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.

;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; This package provides various useful commands (including help
;; system access) through the mouse.  All this code assumes that mouse
;; interpretation has been abstracted into Emacs input events.
;;
;; The code is rather X-dependent.

;;; Code:

;;; Utility functions.

;;; Indent track-mouse like progn.
(put 'track-mouse 'lisp-indent-function 0)


(defun mouse-delete-window (click)
  "Delete the window you click on.
This must be bound to a mouse click."
  (interactive "e")
  (delete-window (posn-window (event-start click))))

(defun mouse-tear-off-window (click)
  "Delete the window clicked on, and create a new frame displaying its buffer."
  (interactive "e")
  (let* ((window (posn-window (event-start click)))
	 (buf (window-buffer window))
	 (frame (new-frame)))
    (select-frame frame)
    (switch-to-buffer buf)
    (delete-window window)))

(defun mouse-delete-other-windows ()
  "Delete all window except the one you click on."
  (interactive "@")
  (delete-other-windows))

(defun mouse-split-window-vertically (click)
  "Select Emacs window mouse is on, then split it vertically in half.
The window is split at the line clicked on.
This command must be bound to a mouse click."
  (interactive "@e")
  (let ((start (event-start click)))
    (select-window (posn-window start))
    (let ((new-height (if (eq (posn-point start) 'vertical-scroll-bar)
			  (scroll-bar-scale (posn-col-row start)
					    (1- (window-height)))
			(1+ (cdr (posn-col-row (event-end click))))))
	  (first-line window-min-height)
	  (last-line (- (window-height) window-min-height)))
      (if (< last-line first-line)
	  (error "window too short to split")
	(split-window-vertically
	 (min (max new-height first-line) last-line))))))

(defun mouse-split-window-horizontally (click)
  "Select Emacs window mouse is on, then split it horizontally in half.
The window is split at the column clicked on.
This command must be bound to a mouse click."
  (interactive "@e")
  (let ((start (event-start click)))
    (select-window (posn-window start))
    (let ((new-width (1+ (car (posn-col-row (event-end click)))))
	  (first-col window-min-width)
	  (last-col (- (window-width) window-min-width)))
      (if (< last-col first-col)
	  (error "window too narrow to split")
	(split-window-horizontally
	 (min (max new-width first-col) last-col))))))

(defun mouse-set-point (event)
  "Move point to the position clicked on with the mouse.
This should be bound to a mouse click event type."
  (interactive "e")
  ;; Use event-end in case called from mouse-drag-region.
  ;; If EVENT is a click, event-end and event-start give same value.
  (let ((posn (event-end event)))
    (and (window-minibuffer-p (posn-window posn))
	 (not (minibuffer-window-active-p (posn-window posn)))
	 (error "Minibuffer window is not active"))
    (select-window (posn-window posn))
    (if (numberp (posn-point posn))
	(goto-char (posn-point posn)))))

(defun mouse-set-region (click)
  "Set the region to the text dragged over, and copy to kill ring.
This should be bound to a mouse drag event."
  (interactive "e")
  (let ((posn (event-start click))
	(end (event-end click)))
    (select-window (posn-window posn))
    (if (numberp (posn-point posn))
	(goto-char (posn-point posn)))
    ;; If mark is highlighted, no need to bounce the cursor.
    (or (and transient-mark-mode
	     (eq (framep (selected-frame)) 'x))
	(sit-for 1))
    (push-mark)
    (set-mark (point))
    (if (numberp (posn-point end))
	(goto-char (posn-point end)))
    ;; Don't set this-command to kill-region, so that a following
    ;; C-w will not double the text in the kill ring.
    (let (this-command)
      (copy-region-as-kill (mark) (point)))))

(defvar mouse-scroll-delay 0.25
  "*The pause between scroll steps caused by mouse drags, in seconds.
If you drag the mouse beyond the edge of a window, Emacs scrolls the
window to bring the text beyond that edge into view, with a delay of
this many seconds between scroll steps.  Scrolling stops when you move
the mouse back into the window, or release the button.
This variable's value may be non-integral.
Setting this to zero causes Emacs to scroll as fast as it can.")

(defun mouse-scroll-subr (jump &optional overlay start)
  "Scroll the selected window JUMP lines at a time, until new input arrives.
If OVERLAY is an overlay, let it stretch from START to the far edge of
the newly visible text.
Upon exit, point is at the far edge of the newly visible text."
  (while (progn
	   (goto-char (window-start))
	   (if (not (zerop (vertical-motion jump)))
	       (progn
		 (set-window-start (selected-window) (point))
		 (if (natnump jump)
		     (progn
		       (goto-char (window-end (selected-window)))
		       ;; window-end doesn't reflect the window's new
		       ;; start position until the next redisplay.  Hurrah.
		       (vertical-motion (1- jump)))
		   (goto-char (window-start (selected-window))))
		 (if overlay
		     (move-overlay overlay start (point)))
		 (if (not (eobp))
		     (sit-for mouse-scroll-delay))))))
  (point))

(defvar mouse-drag-overlay (make-overlay 1 1))
(overlay-put mouse-drag-overlay 'face 'region)

(defun mouse-drag-region (start-event)
  "Set the region to the text that the mouse is dragged over.
Highlight the drag area as you move the mouse.
This must be bound to a button-down mouse event.
In Transient Mark mode, the highlighting remains once you
release the mouse button.  Otherwise, it does not."
  (interactive "e")
  (let* ((start-posn (event-start start-event))
	 (start-point (posn-point start-posn))
	 (start-window (posn-window start-posn))
	 (start-frame (window-frame start-window))
	 (bounds (window-edges start-window))
	 (top (nth 1 bounds))
	 (bottom (if (window-minibuffer-p start-window)
		     (nth 3 bounds)
		   ;; Don't count the mode line.
		   (1- (nth 3 bounds))))
	 (click-count (1- (event-click-count start-event))))
    (mouse-set-point start-event)
    (let ((range (mouse-start-end start-point start-point click-count)))
      (move-overlay mouse-drag-overlay (car range) (nth 1 range)
		    (window-buffer start-window)))
    (deactivate-mark)
    (let (event end end-point)
      (track-mouse
	(while (progn
		 (setq event (read-event))
		 (or (mouse-movement-p event)
		     (eq (car-safe event) 'switch-frame)))

	  (if (eq (car-safe event) 'switch-frame)
	      nil
	    (setq end (event-end event)
		  end-point (posn-point end))

	    (cond

	     ;; Ignore switch-frame events.
	     ((eq (car-safe event) 'switch-frame))

	     ;; Are we moving within the original window?
	     ((and (eq (posn-window end) start-window)
		   (integer-or-marker-p end-point))
	      (goto-char end-point)
	      (let ((range (mouse-start-end start-point (point) click-count)))
		(move-overlay mouse-drag-overlay (car range) (nth 1 range))))

	     ;; Are we moving on a different window on the same frame?
	     ((and (windowp (posn-window end))
		   (eq (window-frame (posn-window end)) start-frame))
	      (let ((mouse-row
		     (+ (nth 1 (window-edges (posn-window end)))
			(cdr (posn-col-row end)))))
		(cond
		 ((< mouse-row top)
		  (mouse-scroll-subr
		   (- mouse-row top) mouse-drag-overlay start-point))
		 ((and (not (eobp))
		       (>= mouse-row bottom))
		  (mouse-scroll-subr (1+ (- mouse-row bottom))
				     mouse-drag-overlay start-point)))))

	     (t
	      (let ((mouse-y (cdr (cdr (mouse-position))))
		    (menu-bar-lines (or (cdr (assq 'menu-bar-lines
						   (frame-parameters)))
					0)))

		;; Are we on the menu bar?
		(and (integerp mouse-y) (< mouse-y menu-bar-lines)
		     (mouse-scroll-subr (- mouse-y menu-bar-lines)
					mouse-drag-overlay start-point))))))))

      (if (and (eq (get (event-basic-type event) 'event-kind) 'mouse-click)
	       (eq (posn-window (event-end event)) start-window)
	       (numberp (posn-point (event-end event))))
	  (let ((fun (key-binding (vector (car event)))))
	    (if (memq fun '(mouse-set-region mouse-set-point))
		(progn
		  (push-mark (overlay-start mouse-drag-overlay) t t)
		  (goto-char (overlay-end mouse-drag-overlay)))
	      (if (fboundp fun)
		  (funcall fun event)))))
      (delete-overlay mouse-drag-overlay))))

;; Commands to handle xterm-style multiple clicks.

(defun mouse-skip-word (dir)
  "Skip over word, over whitespace, or over identical punctuation.
If DIR is positive skip forward; if negative, skip backward."
  (let* ((char (following-char))
	 (syntax (char-to-string (char-syntax char))))
    (if (or (string= syntax "w") (string= syntax " "))
	(if (< dir 0)
	    (skip-syntax-backward syntax)
	  (skip-syntax-forward syntax))
      (if (< dir 0)
	  (while (= (preceding-char) char)
	    (forward-char -1))
	(while (= (following-char) char)
	  (forward-char 1))))))

;; Return a list of region bounds based on START and END according to MODE.
;; If MODE is 0 then set point to (min START END), mark to (max START END).
;; If MODE is 1 then set point to start of word at (min START END),
;; mark to end of word at (max START END).
;; If MODE is 2 then do the same for lines.
;; Optional KEEP-END if non-nil means do not change end.
(defun mouse-start-end (start end mode &optional keep-end)
  (if (> start end)
      (let ((temp start))
        (setq start end
              end temp)))
  (cond ((= mode 0)
	 (list start end))
        ((and (= mode 1)
              (= start end)
              (= (char-syntax (char-after start)) ?\())
	 (list start (save-excursion (forward-sexp 1) (point))))
        ((and (= mode 1)
              (= start end)
              (= (char-syntax (char-after start)) ?\)))
	 (list (save-excursion 
		 (goto-char (1+ start))
		 (backward-sexp 1))
	       (1+ start)))
        ((= mode 1)
	 (list (save-excursion
		 (goto-char start)
		 (mouse-skip-word -1)
		 (point))
	       (save-excursion
		 (goto-char end)
		 (mouse-skip-word 1)
		 (point))))
        ((= mode 2)
	 (list (save-excursion
		 (goto-char start)
		 (beginning-of-line 1)
		 (point))
	       (save-excursion
		 (goto-char end)
		 (forward-line 1)
		 (point))))))

;; Subroutine: set the mark where CLICK happened,
;; but don't do anything else.
(defun mouse-set-mark-fast (click)
  (let ((posn (event-start click)))
    (select-window (posn-window posn))
    (if (numberp (posn-point posn))
	(push-mark (posn-point posn) t t))))

;; Momentarily show where the mark is, if highlighting doesn't show it. 
(defun mouse-show-mark ()
  (or transient-mark-mode
      (save-excursion
	(goto-char (mark t))
	(sit-for 1))))

(defun mouse-set-mark (click)
  "Set mark at the position clicked on with the mouse.
Display cursor at that position for a second.
This must be bound to a mouse click."
  (interactive "e")
  (let ((point-save (point)))
    (unwind-protect
	(progn (mouse-set-point click)
	       (push-mark nil t t)
	       (or transient-mark-mode
		   (sit-for 1)))
      (goto-char point-save))))

(defun mouse-kill (click)
  "Kill the region between point and the mouse click.
The text is saved in the kill ring, as with \\[kill-region]."
  (interactive "e")
  (let ((click-posn (posn-point (event-start click))))
    (if (numberp click-posn)
	(kill-region (min (point) click-posn)
		     (max (point) click-posn)))))

(defun mouse-yank-at-click (click arg)
  "Insert the last stretch of killed text at the position clicked on.
Prefix arguments are interpreted as with \\[yank]."
  (interactive "e\nP")
  (mouse-set-point click)
  (yank arg))

(defun mouse-kill-ring-save (click)
  "Copy the region between point and the mouse click in the kill ring.
This does not delete the region; it acts like \\[kill-ring-save]."
  (interactive "e")
  (mouse-set-mark-fast click)
  (kill-ring-save (point) (mark t))
  (mouse-show-mark))

;;; This function used to delete the text between point and the mouse
;;; whenever it was equal to the front of the kill ring, but some
;;; people found that confusing.

;;; A list (TEXT START END), describing the text and position of the last
;;; invocation of mouse-save-then-kill.
(defvar mouse-save-then-kill-posn nil)

(defun mouse-save-then-kill (click)
  "Save text to point in kill ring; the second time, kill the text.
If the text between point and the mouse is the same as what's
at the front of the kill ring, this deletes the text.
Otherwise, it adds the text to the kill ring, like \\[kill-ring-save],
which prepares for a second click to delete the text."
  (interactive "e")
  (let ((click-posn (posn-point (event-start click)))
	;; Don't let a subsequent kill command append to this one:
	;; prevent setting this-command to kill-region.
	(this-command this-command))
    (if (and (eq last-command 'mouse-save-then-kill)
	     mouse-save-then-kill-posn
	     (eq (car mouse-save-then-kill-posn) (car kill-ring))
	     (equal (cdr mouse-save-then-kill-posn) (list (point) click-posn)))
	;; If this is the second time we've called
	;; mouse-save-then-kill, delete the text from the buffer.
	(progn
	  ;; Delete just one char, so in case buffer is being modified
	  ;; for the first time, the undo list records that fact.
	  (delete-region (point)
			 (+ (point) (if (> (mark) (point)) 1 -1)))
	  ;; Now delete the rest of the specified region,
	  ;; but don't record it.
	  (let ((buffer-undo-list t))
	    (delete-region (point) (mark)))
	  (if (not (eq buffer-undo-list t))
	      (let ((tail buffer-undo-list))
		;; Search back in buffer-undo-list for the string
		;; that came from the first delete-region.
		(while (and tail (not (stringp (car (car tail)))))
		  (setq tail (cdr tail)))
		;; Replace it with an entry for the entire deleted text.
		(and tail
		     (setcar tail (cons (car kill-ring) (point)))))))
      ;; Otherwise, save this region.
      (mouse-set-mark-fast click)
      (kill-ring-save (point) (mark t))
      (mouse-show-mark)
      (setq mouse-save-then-kill-posn
	    (list (car kill-ring) (point) click-posn)))))

(global-set-key [M-mouse-1] 'mouse-start-secondary)
(global-set-key [M-drag-mouse-1] 'mouse-set-secondary)
(global-set-key [M-down-mouse-1] 'mouse-drag-secondary)
(global-set-key [M-mouse-3] 'mouse-secondary-save-then-kill)
(global-set-key [M-mouse-2] 'mouse-kill-secondary)

;; An overlay which records the current secondary selection
;; or else is deleted when there is no secondary selection.
;; May be nil.
(defvar mouse-secondary-overlay nil)

;; A marker which records the specified first end for a secondary selection.
;; May be nil.
(defvar mouse-secondary-start nil)

(defun mouse-start-secondary (click)
  "Set one end of the secondary selection to the position clicked on.
Use \\[mouse-secondary-save-then-kill] to set the other end
and complete the secondary selection."
  (interactive "e")
  (let ((posn (event-start click)))
    (save-excursion
      (set-buffer (window-buffer (posn-window posn)))
      ;; Cancel any preexisting secondary selection.
      (if mouse-secondary-overlay
	  (delete-overlay mouse-secondary-overlay))
      (if (numberp (posn-point posn))
	  (progn
	    (or mouse-secondary-start
		(setq mouse-secondary-start (make-marker)))
	    (move-marker mouse-secondary-start (posn-point posn)))))))

(defun mouse-set-secondary (click)
  "Set the secondary selection to the text that the mouse is dragged over.
This must be bound to a mouse drag event."
  (interactive "e")
  (let ((posn (event-start click))
	beg
	(end (event-end click)))
    (save-excursion
      (set-buffer (window-buffer (posn-window posn)))
      (if (numberp (posn-point posn))
	  (setq beg (posn-point posn)))
      (if mouse-secondary-overlay
	  (move-overlay mouse-secondary-overlay beg (posn-point end))
	(setq mouse-secondary-overlay (make-overlay beg (posn-point end))))
      (overlay-put mouse-secondary-overlay 'face 'secondary-selection))))

(defun mouse-drag-secondary (click)
  "Set the secondary selection to the text that the mouse is dragged over.
This must be bound to a button-down mouse event."
  (interactive "e")
  (let ((posn (event-start click)))
    (save-window-excursion
      (select-window (posn-window posn))
      ;; Set point temporarily, so user sees where it is.
      (save-excursion
	(if (numberp (posn-point posn))
	    (goto-char (posn-point posn)))
	(setq unread-command-events
	      (cons (read-event) unread-command-events))))))

(defun mouse-kill-secondary ()
  "Kill the text in the secondary selection."
  (interactive "*")
  (kill-region (overlay-start mouse-secondary-overlay)
	       (overlay-end mouse-secondary-overlay))
  (delete-overlay mouse-secondary-overlay)
  (setq mouse-secondary-overlay nil))

(defun mouse-secondary-save-then-kill (click)
  "Save text to secondary start point in kill ring; if twice, kill it.
If the text between secondary start point and the mouse is the same as what's
at the front of the kill ring, this deletes the text.
Otherwise, it adds the text to the kill ring, like \\[kill-ring-save],
which prepares for a second click to delete the text."
  (interactive "e")
  (let ((click-posn (posn-point (event-start click)))
	(start (+ 0 mouse-secondary-start))
	;; Don't let a subsequent kill command append to this one:
	;; prevent setting this-command to kill-region.
	(this-command this-command))
    (if (and (eq last-command 'mouse-secondary-save-then-kill)
	     mouse-save-then-kill-posn
	     (eq (car mouse-save-then-kill-posn) (car kill-ring))
	     (equal (cdr mouse-save-then-kill-posn)
		    (list start click-posn)))
	;; If this is the second time we've called
	;; mouse-save-then-kill, delete the text from the buffer.
	(progn
	  (let ((buffer-undo-list t))
	    (delete-overlay mouse-secondary-overlay)
	    (delete-region start click-posn))
	  ;; Make the undo list by hand so it is shared.
	  (if (not (eq buffer-undo-list t))
	      (setq buffer-undo-list
		    (cons (cons (car kill-ring) (marker-position start))
			  buffer-undo-list))))
      ;; Otherwise, save this region.
      (save-excursion
	(set-buffer (window-buffer (posn-window (event-start click))))
	(kill-ring-save start click-posn)
	(if mouse-secondary-overlay
	    (move-overlay mouse-secondary-overlay start click-posn)
	  (setq mouse-secondary-overlay (make-overlay start click-posn)))
	(overlay-put mouse-secondary-overlay 'face 'secondary-selection)
	(setq mouse-save-then-kill-posn
	      (list (car kill-ring) start click-posn))))))

(defun mouse-buffer-menu (event)
  "Pop up a menu of buffers for selection with the mouse.
This switches buffers in the window that you clicked on,
and selects that window."
  (interactive "e")
  (let ((menu
	 (list "Buffer Menu"
	       (cons "Select Buffer"
		     (let ((tail (buffer-list))
			   (maxbuf 0)
			   head)
		       (while tail
			 (or (eq ?\ (aref (buffer-name (car tail)) 0))
			     (setq maxbuf
				   (max maxbuf
					(length (buffer-name (car tail))))))
			 (setq tail (cdr tail)))
		       (setq tail (buffer-list))
		       (while tail
			 (let ((elt (car tail)))
			   (if (not (string-match "^ "
						  (buffer-name elt)))
			       (setq head (cons
					   (cons
					    (format
					     (format "%%%ds  %%s%%s  %%s"
						     maxbuf)
					     (buffer-name elt)
					     (if (buffer-modified-p elt)
						 "*" " ")
					     (save-excursion
					       (set-buffer elt)
					       (if buffer-read-only "%" " "))
					     (or (buffer-file-name elt) ""))
					    elt)
					   head))))
			 (setq tail (cdr tail)))
		       (reverse head))))))
    (let ((buf (x-popup-menu event menu))
	  (window (posn-window (event-start event))))
      (if buf
	  (progn
	    (or (framep window) (select-window window))
	    (switch-to-buffer buf))))))

;;; These need to be rewritten for the new scroll bar implementation.

;;;!! ;; Commands for the scroll bar.
;;;!! 
;;;!! (defun mouse-scroll-down (click)
;;;!!   (interactive "@e")
;;;!!   (scroll-down (1+ (cdr (mouse-coords click)))))
;;;!! 
;;;!! (defun mouse-scroll-up (click)
;;;!!   (interactive "@e")
;;;!!   (scroll-up (1+ (cdr (mouse-coords click)))))
;;;!! 
;;;!! (defun mouse-scroll-down-full ()
;;;!!   (interactive "@")
;;;!!   (scroll-down nil))
;;;!! 
;;;!! (defun mouse-scroll-up-full ()
;;;!!   (interactive "@")
;;;!!   (scroll-up nil))
;;;!! 
;;;!! (defun mouse-scroll-move-cursor (click)
;;;!!   (interactive "@e")
;;;!!   (move-to-window-line (1+ (cdr (mouse-coords click)))))
;;;!! 
;;;!! (defun mouse-scroll-absolute (event)
;;;!!   (interactive "@e")
;;;!!   (let* ((pos (car event))
;;;!! 	 (position (car pos))
;;;!! 	 (length (car (cdr pos))))
;;;!!     (if (<= length 0) (setq length 1))
;;;!!     (let* ((scale-factor (max 1 (/ length (/ 8000000 (buffer-size)))))
;;;!! 	   (newpos (* (/ (* (/ (buffer-size) scale-factor)
;;;!! 			    position)
;;;!! 			 length)
;;;!! 		      scale-factor)))
;;;!!       (goto-char newpos)
;;;!!       (recenter '(4)))))
;;;!! 
;;;!! (defun mouse-scroll-left (click)
;;;!!   (interactive "@e")
;;;!!   (scroll-left (1+ (car (mouse-coords click)))))
;;;!! 
;;;!! (defun mouse-scroll-right (click)
;;;!!   (interactive "@e")
;;;!!   (scroll-right (1+ (car (mouse-coords click)))))
;;;!! 
;;;!! (defun mouse-scroll-left-full ()
;;;!!   (interactive "@")
;;;!!   (scroll-left nil))
;;;!! 
;;;!! (defun mouse-scroll-right-full ()
;;;!!   (interactive "@")
;;;!!   (scroll-right nil))
;;;!! 
;;;!! (defun mouse-scroll-move-cursor-horizontally (click)
;;;!!   (interactive "@e")
;;;!!   (move-to-column (1+ (car (mouse-coords click)))))
;;;!! 
;;;!! (defun mouse-scroll-absolute-horizontally (event)
;;;!!   (interactive "@e")
;;;!!   (let* ((pos (car event))
;;;!! 	 (position (car pos))
;;;!! 	 (length (car (cdr pos))))
;;;!!   (set-window-hscroll (selected-window) 33)))
;;;!! 
;;;!! (global-set-key [scroll-bar mouse-1] 'mouse-scroll-up)
;;;!! (global-set-key [scroll-bar mouse-2] 'mouse-scroll-absolute)
;;;!! (global-set-key [scroll-bar mouse-3] 'mouse-scroll-down)
;;;!! 
;;;!! (global-set-key [vertical-slider mouse-1] 'mouse-scroll-move-cursor)
;;;!! (global-set-key [vertical-slider mouse-2] 'mouse-scroll-move-cursor)
;;;!! (global-set-key [vertical-slider mouse-3] 'mouse-scroll-move-cursor)
;;;!! 
;;;!! (global-set-key [thumbup mouse-1] 'mouse-scroll-up-full)
;;;!! (global-set-key [thumbup mouse-2] 'mouse-scroll-up-full)
;;;!! (global-set-key [thumbup mouse-3] 'mouse-scroll-up-full)
;;;!! 
;;;!! (global-set-key [thumbdown mouse-1] 'mouse-scroll-down-full)
;;;!! (global-set-key [thumbdown mouse-2] 'mouse-scroll-down-full)
;;;!! (global-set-key [thumbdown mouse-3] 'mouse-scroll-down-full)
;;;!! 
;;;!! (global-set-key [horizontal-scroll-bar mouse-1] 'mouse-scroll-left)
;;;!! (global-set-key [horizontal-scroll-bar mouse-2]
;;;!! 		'mouse-scroll-absolute-horizontally)
;;;!! (global-set-key [horizontal-scroll-bar mouse-3] 'mouse-scroll-right)
;;;!! 
;;;!! (global-set-key [horizontal-slider mouse-1]
;;;!! 		'mouse-scroll-move-cursor-horizontally)
;;;!! (global-set-key [horizontal-slider mouse-2]
;;;!! 		'mouse-scroll-move-cursor-horizontally)
;;;!! (global-set-key [horizontal-slider mouse-3]
;;;!! 		'mouse-scroll-move-cursor-horizontally)
;;;!! 
;;;!! (global-set-key [thumbleft mouse-1] 'mouse-scroll-left-full)
;;;!! (global-set-key [thumbleft mouse-2] 'mouse-scroll-left-full)
;;;!! (global-set-key [thumbleft mouse-3] 'mouse-scroll-left-full)
;;;!! 
;;;!! (global-set-key [thumbright mouse-1] 'mouse-scroll-right-full)
;;;!! (global-set-key [thumbright mouse-2] 'mouse-scroll-right-full)
;;;!! (global-set-key [thumbright mouse-3] 'mouse-scroll-right-full)
;;;!! 
;;;!! (global-set-key [horizontal-scroll-bar S-mouse-2]
;;;!! 		'mouse-split-window-horizontally)
;;;!! (global-set-key [mode-line S-mouse-2]
;;;!! 		'mouse-split-window-horizontally)
;;;!! (global-set-key [vertical-scroll-bar S-mouse-2]
;;;!! 		'mouse-split-window)

;;;!! ;;;;
;;;!! ;;;; Here are experimental things being tested.  Mouse events
;;;!! ;;;; are of the form:
;;;!! ;;;;	((x y) window screen-part key-sequence timestamp)
;;;!! ;;
;;;!! ;;;;
;;;!! ;;;; Dynamically track mouse coordinates
;;;!! ;;;;
;;;!! ;;
;;;!! ;;(defun track-mouse (event)
;;;!! ;;  "Track the coordinates, absolute and relative, of the mouse."
;;;!! ;;  (interactive "@e")
;;;!! ;;  (while mouse-grabbed
;;;!! ;;    (let* ((pos (read-mouse-position (selected-screen)))
;;;!! ;;	   (abs-x (car pos))
;;;!! ;;	   (abs-y (cdr pos))
;;;!! ;;	   (relative-coordinate (coordinates-in-window-p
;;;!! ;;				 (list (car pos) (cdr pos))
;;;!! ;;				 (selected-window))))
;;;!! ;;      (if (consp relative-coordinate)
;;;!! ;;	  (message "mouse: [%d %d], (%d %d)" abs-x abs-y
;;;!! ;;		   (car relative-coordinate)
;;;!! ;;		   (car (cdr relative-coordinate)))
;;;!! ;;	(message "mouse: [%d %d]" abs-x abs-y)))))
;;;!! 
;;;!! ;;
;;;!! ;; Dynamically put a box around the line indicated by point
;;;!! ;;
;;;!! ;;
;;;!! ;;(require 'backquote)
;;;!! ;;
;;;!! ;;(defun mouse-select-buffer-line (event)
;;;!! ;;  (interactive "@e")
;;;!! ;;  (let ((relative-coordinate
;;;!! ;;	 (coordinates-in-window-p (car event) (selected-window)))
;;;!! ;;	(abs-y (car (cdr (car event)))))
;;;!! ;;    (if (consp relative-coordinate)
;;;!! ;;	(progn
;;;!! ;;	  (save-excursion
;;;!! ;;	    (move-to-window-line (car (cdr relative-coordinate)))
;;;!! ;;	    (x-draw-rectangle
;;;!! ;;	     (selected-screen)
;;;!! ;;	     abs-y 0
;;;!! ;;	     (save-excursion
;;;!! ;;		 (move-to-window-line (car (cdr relative-coordinate)))
;;;!! ;;		 (end-of-line)
;;;!! ;;		 (push-mark nil t)
;;;!! ;;		 (beginning-of-line)
;;;!! ;;		 (- (region-end) (region-beginning))) 1))
;;;!! ;;	  (sit-for 1)
;;;!! ;;	  (x-erase-rectangle (selected-screen))))))
;;;!! ;;
;;;!! ;;(defvar last-line-drawn nil)
;;;!! ;;(defvar begin-delim "[^ \t]")
;;;!! ;;(defvar end-delim   "[^ \t]")
;;;!! ;;
;;;!! ;;(defun mouse-boxing (event)
;;;!! ;;  (interactive "@e")
;;;!! ;;  (save-excursion
;;;!! ;;    (let ((screen (selected-screen)))
;;;!! ;;      (while (= (x-mouse-events) 0)
;;;!! ;;	(let* ((pos (read-mouse-position screen))
;;;!! ;;	       (abs-x (car pos))
;;;!! ;;	       (abs-y (cdr pos))
;;;!! ;;	       (relative-coordinate
;;;!! ;;		(coordinates-in-window-p (` ((, abs-x) (, abs-y)))
;;;!! ;;					 (selected-window)))
;;;!! ;;	       (begin-reg nil)
;;;!! ;;	       (end-reg nil)
;;;!! ;;	       (end-column nil)
;;;!! ;;	       (begin-column nil))
;;;!! ;;	  (if (and (consp relative-coordinate)
;;;!! ;;		   (or (not last-line-drawn)
;;;!! ;;		       (not (= last-line-drawn abs-y))))
;;;!! ;;	      (progn
;;;!! ;;		(move-to-window-line (car (cdr relative-coordinate)))
;;;!! ;;		(if (= (following-char) 10)
;;;!! ;;		    ()
;;;!! ;;		  (progn
;;;!! ;;		    (setq begin-reg (1- (re-search-forward end-delim)))
;;;!! ;;		    (setq begin-column (1- (current-column)))
;;;!! ;;		    (end-of-line)
;;;!! ;;		    (setq end-reg (1+ (re-search-backward begin-delim)))
;;;!! ;;		    (setq end-column (1+ (current-column)))
;;;!! ;;		    (message "%s" (buffer-substring begin-reg end-reg))
;;;!! ;;		    (x-draw-rectangle screen
;;;!! ;;				      (setq last-line-drawn abs-y)
;;;!! ;;				      begin-column
;;;!! ;;				      (- end-column begin-column) 1))))))))))
;;;!! ;;
;;;!! ;;(defun mouse-erase-box ()
;;;!! ;;  (interactive)
;;;!! ;;  (if last-line-drawn
;;;!! ;;      (progn
;;;!! ;;	(x-erase-rectangle (selected-screen))
;;;!! ;;	(setq last-line-drawn nil))))
;;;!! 
;;;!! ;;; (defun test-x-rectangle ()
;;;!! ;;;   (use-local-mouse-map (setq rectangle-test-map (make-sparse-keymap)))
;;;!! ;;;   (define-key rectangle-test-map mouse-motion-button-left 'mouse-boxing)
;;;!! ;;;   (define-key rectangle-test-map mouse-button-left-up 'mouse-erase-box))
;;;!! 
;;;!! ;;
;;;!! ;; Here is how to do double clicking in lisp.  About to change.
;;;!! ;;
;;;!! 
;;;!! (defvar double-start nil)
;;;!! (defconst double-click-interval 300
;;;!!   "Max ticks between clicks")
;;;!! 
;;;!! (defun double-down (event)
;;;!!   (interactive "@e")
;;;!!   (if double-start
;;;!!       (let ((interval (- (nth 4 event) double-start)))
;;;!! 	(if (< interval double-click-interval)
;;;!! 	    (progn
;;;!! 	      (backward-up-list 1)
;;;!! 	      ;;      (message "Interval %d" interval)
;;;!! 	      (sleep-for 1)))
;;;!! 	(setq double-start nil))
;;;!!     (setq double-start (nth 4 event))))
;;;!!     
;;;!! (defun double-up (event)
;;;!!   (interactive "@e")
;;;!!   (and double-start
;;;!!        (> (- (nth 4 event ) double-start) double-click-interval)
;;;!!        (setq double-start nil)))
;;;!! 
;;;!! ;;; (defun x-test-doubleclick ()
;;;!! ;;;   (use-local-mouse-map (setq doubleclick-test-map (make-sparse-keymap)))
;;;!! ;;;   (define-key doubleclick-test-map mouse-button-left 'double-down)
;;;!! ;;;   (define-key doubleclick-test-map mouse-button-left-up 'double-up))
;;;!! 
;;;!! ;;
;;;!! ;; This scrolls while button is depressed.  Use preferable in scroll bar.
;;;!! ;;
;;;!! 
;;;!! (defvar scrolled-lines 0)
;;;!! (defconst scroll-speed 1)
;;;!! 
;;;!! (defun incr-scroll-down (event)
;;;!!   (interactive "@e")
;;;!!   (setq scrolled-lines 0)
;;;!!   (incremental-scroll scroll-speed))
;;;!! 
;;;!! (defun incr-scroll-up (event)
;;;!!   (interactive "@e")
;;;!!   (setq scrolled-lines 0)
;;;!!   (incremental-scroll (- scroll-speed)))
;;;!! 
;;;!! (defun incremental-scroll (n)
;;;!!   (while (= (x-mouse-events) 0)
;;;!!     (setq scrolled-lines (1+ (* scroll-speed scrolled-lines)))
;;;!!     (scroll-down n)
;;;!!     (sit-for 300 t)))
;;;!! 
;;;!! (defun incr-scroll-stop (event)
;;;!!   (interactive "@e")
;;;!!   (message "Scrolled %d lines" scrolled-lines)
;;;!!   (setq scrolled-lines 0)
;;;!!   (sleep-for 1))
;;;!! 
;;;!! ;;; (defun x-testing-scroll ()
;;;!! ;;;   (let ((scrolling-map (function mouse-vertical-scroll-bar-prefix)))
;;;!! ;;;     (define-key scrolling-map mouse-button-left 'incr-scroll-down)
;;;!! ;;;     (define-key scrolling-map mouse-button-right 'incr-scroll-up)
;;;!! ;;;     (define-key scrolling-map mouse-button-left-up 'incr-scroll-stop)
;;;!! ;;;     (define-key scrolling-map mouse-button-right-up 'incr-scroll-stop)))
;;;!! 
;;;!! ;;
;;;!! ;; Some playthings suitable for picture mode?  They need work.
;;;!! ;;
;;;!! 
;;;!! (defun mouse-kill-rectangle (event)
;;;!!   "Kill the rectangle between point and the mouse cursor."
;;;!!   (interactive "@e")
;;;!!   (let ((point-save (point)))
;;;!!     (save-excursion
;;;!!       (mouse-set-point event)
;;;!!       (push-mark nil t)
;;;!!       (if (> point-save (point))
;;;!! 	  (kill-rectangle (point) point-save)
;;;!! 	(kill-rectangle point-save (point))))))
;;;!! 
;;;!! (defun mouse-open-rectangle (event)
;;;!!   "Kill the rectangle between point and the mouse cursor."
;;;!!   (interactive "@e")
;;;!!   (let ((point-save (point)))
;;;!!     (save-excursion
;;;!!       (mouse-set-point event)
;;;!!       (push-mark nil t)
;;;!!       (if (> point-save (point))
;;;!! 	  (open-rectangle (point) point-save)
;;;!! 	(open-rectangle point-save (point))))))
;;;!! 
;;;!! ;; Must be a better way to do this.
;;;!! 
;;;!! (defun mouse-multiple-insert (n char)
;;;!!   (while (> n 0)
;;;!!     (insert char)
;;;!!     (setq n (1- n))))
;;;!! 
;;;!! ;; What this could do is not finalize until button was released.
;;;!! 
;;;!! (defun mouse-move-text (event)
;;;!!   "Move text from point to cursor position, inserting spaces."
;;;!!   (interactive "@e")
;;;!!   (let* ((relative-coordinate
;;;!! 	  (coordinates-in-window-p (car event) (selected-window))))
;;;!!     (if (consp relative-coordinate)
;;;!! 	(cond ((> (current-column) (car relative-coordinate))
;;;!! 	       (delete-char
;;;!! 		(- (car relative-coordinate) (current-column))))
;;;!! 	      ((< (current-column) (car relative-coordinate))
;;;!! 	       (mouse-multiple-insert
;;;!! 		(- (car relative-coordinate) (current-column)) " "))
;;;!! 	      ((= (current-column) (car relative-coordinate)) (ding))))))

;; Choose a completion with the mouse.

(defun mouse-choose-completion (event)
  "Click on an alternative in the `*Completions*' buffer to choose it."
  (interactive "e")
  (let (choice)
    (save-excursion
      (set-buffer (window-buffer (posn-window (event-start event))))
      (save-excursion
	(goto-char (posn-point (event-start event)))
	(skip-chars-backward "^ \t\n")
	(let ((beg (point)))
	  (skip-chars-forward "^ \t\n")
	  (setq choice (buffer-substring beg (point))))))
    (set-buffer (window-buffer (minibuffer-window)))
    (goto-char (max (point-min) (- (point-max) (length choice))))
    (while (and (not (eobp))
		(let ((tail (buffer-substring (point) (point-max))))
		  (not (string= tail (substring choice 0 (length tail))))))
      (forward-char 1))
    (insert choice)
    (delete-region (point) (point-max))
    (minibuffer-complete-and-exit)))

;; Font selection.

(defun font-menu-add-default ()
  (let* ((default (cdr (assq 'font (frame-parameters (selected-frame)))))
	 (font-alist x-fixed-font-alist)
	 (elt (or (assoc "Misc" font-alist) (nth 1 font-alist))))
    (if (assoc "Default" elt)
	(delete (assoc "Default" elt) elt))
    (setcdr elt
	    (cons (list "Default"
			(cdr (assq 'font (frame-parameters (selected-frame)))))
		  (cdr elt)))))

(defvar x-fixed-font-alist
  '("Font menu"
    ("Misc"
     ("6x10" "-misc-fixed-medium-r-semicondensed--10-110-75-75-c-60-*-1")
     ("6x12" "-misc-fixed-medium-r-semicondensed--12-110-75-75-c-60-*-1")
     ("6x13" "-misc-fixed-medium-r-semicondensed--13-120-75-75-c-60-*-1")
     ("lucida 13"
      "-b&h-lucidatypewriter-medium-r-normal-sans-0-0-0-0-m-0-*-1")
     ("7x13" "-misc-fixed-medium-r-normal--13-120-75-75-c-70-*-1")
     ("7x14" "-misc-fixed-medium-r-normal--14-130-75-75-c-70-*-1")
     ("9x15" "-misc-fixed-medium-r-normal--15-140-*-*-c-*-*-1")
     ("")
     ("clean 8x8" "-schumacher-clean-medium-r-normal--*-80-*-*-c-*-*-1")
     ("clean 8x14" "-schumacher-clean-medium-r-normal--*-140-*-*-c-*-*-1")
     ("clean 8x10" "-schumacher-clean-medium-r-normal--*-100-*-*-c-*-*-1")
     ("clean 8x16" "-schumacher-clean-medium-r-normal--*-160-*-*-c-*-*-1")
     ("")
     ("sony 8x16" "-sony-fixed-medium-r-normal--16-120-100-100-c-80-*-1")
     ("")
     ("fixed" "fixed")
     ("10x20" "10x20")
     ("11x18" "11x18")
     ("12x24" "12x24"))
;;; We don't seem to have these; who knows what they are.
;;;    ("fg-18" "fg-18")
;;;    ("fg-25" "fg-25")
;;;    ("lucidasanstypewriter-12" "lucidasanstypewriter-12")
;;;    ("lucidasanstypewriter-bold-14" "lucidasanstypewriter-bold-14")
;;;    ("lucidasanstypewriter-bold-24" "lucidasanstypewriter-bold-24")
;;;    ("lucidatypewriter-bold-r-24" "-b&h-lucidatypewriter-bold-r-normal-sans-24-240-75-75-m-140-iso8859-1")
;;;    ("fixed-medium-20" "-misc-fixed-medium-*-*-*-20-*-*-*-*-*-*-*")
    ("Courier"
     ("8" "-adobe-courier-medium-r-normal--*-80-*-*-m-*-iso8859-1")
     ("10" "-adobe-courier-medium-r-normal--*-100-*-*-m-*-iso8859-1")
     ("12" "-adobe-courier-medium-r-normal--*-120-*-*-m-*-iso8859-1")
     ("14" "-adobe-courier-medium-r-normal--*-140-*-*-m-*-iso8859-1")
     ("18" "-adobe-courier-medium-r-normal--*-180-*-*-m-*-iso8859-1")
     ("24" "-adobe-courier-medium-r-normal--*-240-*-*-m-*-iso8859-1")
     ("8 bold" "-adobe-courier-bold-r-normal--*-80-*-*-m-*-iso8859-1")
     ("10 bold" "-adobe-courier-bold-r-normal--*-100-*-*-m-*-iso8859-1")
     ("12 bold" "-adobe-courier-bold-r-normal--*-120-*-*-m-*-iso8859-1")
     ("14 bold" "-adobe-courier-bold-r-normal--*-140-*-*-m-*-iso8859-1")
     ("18 bold" "-adobe-courier-bold-r-normal--*-180-*-*-m-*-iso8859-1")
     ("24 bold" "-adobe-courier-bold-r-normal--*-240-*-*-m-*-iso8859-1")
     ("8 slant" "-adobe-courier-medium-o-normal--*-80-*-*-m-*-iso8859-1")
     ("10 slant" "-adobe-courier-medium-o-normal--*-100-*-*-m-*-iso8859-1")
     ("12 slant" "-adobe-courier-medium-o-normal--*-120-*-*-m-*-iso8859-1")
     ("14 slant" "-adobe-courier-medium-o-normal--*-140-*-*-m-*-iso8859-1")
     ("18 slant" "-adobe-courier-medium-o-normal--*-180-*-*-m-*-iso8859-1")
     ("24 slant" "-adobe-courier-medium-o-normal--*-240-*-*-m-*-iso8859-1")
     ("8 bold slant" "-adobe-courier-bold-o-normal--*-80-*-*-m-*-iso8859-1")
     ("10 bold slant" "-adobe-courier-bold-o-normal--*-100-*-*-m-*-iso8859-1")
     ("12 bold slant" "-adobe-courier-bold-o-normal--*-120-*-*-m-*-iso8859-1")
     ("14 bold slant" "-adobe-courier-bold-o-normal--*-140-*-*-m-*-iso8859-1")
     ("18 bold slant" "-adobe-courier-bold-o-normal--*-180-*-*-m-*-iso8859-1")
     ("24 bold slant" "-adobe-courier-bold-o-normal--*-240-*-*-m-*-iso8859-1"))
    )
  "X fonts suitable for use in Emacs.")

(defun mouse-set-font (&optional font)
  "Select an emacs font from a list of known good fonts"
  (interactive
   (x-popup-menu last-nonmenu-event x-fixed-font-alist))
  (if font
      (progn (modify-frame-parameters (selected-frame)
				      (list (cons 'font font)))
	     ;; Update some standard faces too.
	     (set-face-font 'bold nil (selected-frame)) 
	     (make-face-bold 'bold (selected-frame) t)
	     (set-face-font 'italic nil (selected-frame))
	     (make-face-italic 'italic (selected-frame) t)
	     (set-face-font 'bold-italic nil (selected-frame))
	     (make-face-bold-italic 'bold-italic (selected-frame) t))))

;;; Bindings for mouse commands.

(define-key global-map [down-mouse-1] 'mouse-drag-region)
(global-set-key [mouse-1]	'mouse-set-point)
(global-set-key [drag-mouse-1]	'mouse-set-region)

;; These are tested for in mouse-drag-region.
(global-set-key [double-mouse-1] 'mouse-set-point)
(global-set-key [triple-mouse-1] 'mouse-set-point)

(global-set-key [mouse-2]	'mouse-yank-at-click)
(global-set-key [mouse-3]	'mouse-save-then-kill)

;; By binding these to down-going events, we let the user use the up-going
;; event to make the selection, saving a click.
(global-set-key [C-down-mouse-1]	'mouse-buffer-menu)
(global-set-key [C-down-mouse-3]	'mouse-set-font)

;; Replaced with dragging mouse-1
;; (global-set-key [S-mouse-1]	'mouse-set-mark)

(global-set-key [mode-line mouse-1] 'mouse-delete-other-windows)
(global-set-key [mode-line mouse-3] 'mouse-delete-window)
(global-set-key [mode-line S-mouse-2] 'mouse-split-window-horizontally)

;; Define the mouse help menu tree.

(defvar help-menu-map '(keymap "Help"))
(global-set-key [C-down-mouse-2] help-menu-map)

(defvar help-apropos-map (make-sparse-keymap "Is there a command that..."))
(defvar help-keys-map (make-sparse-keymap "Key Commands <==> Functions"))
(defvar help-manual-map (make-sparse-keymap "Manual and tutorial"))
(defvar help-misc-map (make-sparse-keymap "Odds and ends"))
(defvar help-modes-map (make-sparse-keymap "Modes"))
(defvar help-admin-map (make-sparse-keymap "Administrivia"))

(define-key help-menu-map [apropos]
  (cons "@Is there a command that..." help-apropos-map))
(define-key help-menu-map [keys]
  (cons "@Key Commands <==> Functions" help-keys-map))
(define-key help-menu-map [manuals]
  (cons "@Manual and tutorial" help-manual-map))
(define-key help-menu-map [misc]
  (cons "@Odds and ends" help-misc-map))
(define-key help-menu-map [modes]
  (cons "@Modes" help-modes-map))
(define-key help-menu-map [admin]
  (cons "@Administrivia" help-admin-map))

(define-key help-apropos-map "c" '("Command Apropos" . command-apropos))
(define-key help-apropos-map "a" '("Apropos" . apropos))

(define-key help-keys-map "b"
  '("List all keystroke commands" . describe-bindings))
(define-key help-keys-map "c"
  '("Describe key briefly" . describe-key-briefly))
(define-key help-keys-map "k"
  '("Describe key verbose" . describe-key))
(define-key help-keys-map "f"
  '("Describe Lisp function" . describe-function))
(define-key help-keys-map "w"
  '("Where is this command" . where-is))

(define-key help-manual-map "i" '("Info system" . info))
(define-key help-manual-map "t"
  '("Invoke Emacs tutorial" . help-with-tutorial))

(define-key help-misc-map "l" '("Last 100 Keystrokes" . view-lossage))
(define-key help-misc-map "s" '("Describe syntax table" . describe-syntax))

(define-key help-modes-map "m"
  '("Describe current major mode" . describe-mode))
(define-key help-modes-map "b"
  '("List all keystroke commands" . describe-bindings))

(define-key help-admin-map "n"
  '("View Emacs news" . view-emacs-news))
(define-key help-admin-map "l"
  '("View Emacs copying conditions" . describe-copying))
(define-key help-admin-map "d"
  '("Describe distribution" . describe-distribution))
(define-key help-admin-map "w"
  '("Describe (non)warranty" . describe-no-warranty))

(provide 'mouse)

;;; mouse.el ends here
