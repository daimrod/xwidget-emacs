;;; em-term.el --- running visual commands

;; Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004,
;;   2005, 2006, 2007 Free Software Foundation, Inc.

;; Author: John Wiegley <johnw@gnu.org>

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

(provide 'em-term)

(eval-when-compile (require 'esh-maint))

(defgroup eshell-term nil
  "This module causes visual commands (e.g., 'vi') to be executed by
the `term' package, which comes with Emacs.  This package handles most
of the ANSI control codes, allowing curses-based applications to run
within an Emacs window.  The variable `eshell-visual-commands' defines
which commands are considered visual in nature."
  :tag "Running visual commands"
  :group 'eshell-module)

;;; Commentary:

;; At the moment, eshell is stream-based in its interactive input and
;; output.  This means that full-screen commands, such as "vi" or
;; "lynx", will not display correctly.  These are therefore thought of
;; as "visual" programs.  In order to run these progrem under Emacs,
;; Eshell uses the term.el package, and invokes them in a separate
;; buffer, giving the illusion that Eshell itself is allowing these
;; visual processes to execute.

(require 'term)

;;; User Variables:

(defcustom eshell-term-load-hook '(eshell-term-initialize)
  "*A list of functions to call when loading `eshell-term'."
  :type 'hook
  :group 'eshell-term)

(defcustom eshell-visual-commands
  '("vi"                                ; what is going on??
    "screen" "top"                      ; ok, a valid program...
    "less" "more"                       ; M-x view-file
    "lynx" "ncftp"                      ; w3.el, ange-ftp
    "pine" "tin" "trn" "elm")           ; GNUS!!
  "*A list of commands that present their output in a visual fashion."
  :type '(repeat string)
  :group 'eshell-term)

(defcustom eshell-term-name "eterm"
  "*Name to use for the TERM variable when running visual commands.
See `term-term-name' in term.el for more information on how this is
used."
  :type 'string
  :group 'eshell-term)

(defcustom eshell-escape-control-x t
  "*If non-nil, allow <C-x> to be handled by Emacs key in visual buffers.
See the variable `eshell-visual-commands'.  If this variable is set to
nil, <C-x> will send that control character to the invoked process."
  :type 'boolean
  :group 'eshell-term)

;;; Internal Variables:

(defvar eshell-parent-buffer)

;;; Functions:

(defun eshell-term-initialize ()
  "Initialize the `term' interface code."
  (make-local-variable 'eshell-interpreter-alist)
  (setq eshell-interpreter-alist
	(cons (cons (function
		     (lambda (command)
		       (member (file-name-nondirectory command)
			       eshell-visual-commands)))
		    'eshell-exec-visual)
	      eshell-interpreter-alist)))

(defun eshell-exec-visual (&rest args)
  "Run the specified PROGRAM in a terminal emulation buffer.
ARGS are passed to the program.  At the moment, no piping of input is
allowed."
  (let* (eshell-interpreter-alist
	 (interp (eshell-find-interpreter (car args)))
	 (program (car interp))
	 (args (eshell-flatten-list
		(eshell-stringify-list (append (cdr interp)
					       (cdr args)))))
	 (term-buf
	  (generate-new-buffer
	   (concat "*" (file-name-nondirectory program) "*")))
	 (eshell-buf (current-buffer)))
    (save-current-buffer
      (switch-to-buffer term-buf)
      (term-mode)
      (set (make-local-variable 'term-term-name) eshell-term-name)
      (make-local-variable 'eshell-parent-buffer)
      (setq eshell-parent-buffer eshell-buf)
      (term-exec term-buf program program nil args)
      (let ((proc (get-buffer-process term-buf)))
	(if (and proc (eq 'run (process-status proc)))
	    (set-process-sentinel proc 'eshell-term-sentinel)
	  (error "Failed to invoke visual command")))
      (term-char-mode)
      (if eshell-escape-control-x
	  (term-set-escape-char ?\C-x))))
  nil)

(defun eshell-term-sentinel (proc string)
  "Destroy the buffer visiting PROC."
  (let ((proc-buf (process-buffer proc)))
    (when (and proc-buf (buffer-live-p proc-buf)
	       (not (eq 'run (process-status proc)))
	       (= (process-exit-status proc) 0))
      (if (eq (current-buffer) proc-buf)
	  (let ((buf (and (boundp 'eshell-parent-buffer)
			  eshell-parent-buffer
			  (buffer-live-p eshell-parent-buffer)
			  eshell-parent-buffer)))
	    (if buf
		(switch-to-buffer buf))))
      (kill-buffer proc-buf))))

;; jww (1999-09-17): The code below will allow Eshell to send input
;; characters directly to the currently running interactive process.
;; However, since this would introduce other problems that would need
;; solutions, I'm going to let it wait until after 2.1.

; (defvar eshell-term-raw-map nil
;   "Keyboard map for sending characters directly to the inferior process.")
; (defvar eshell-term-escape-char nil
;   "Escape character for char-sub-mode of term mode.
; Do not change it directly;  use term-set-escape-char instead.")
; (defvar eshell-term-raw-escape-map nil)

; (defun eshell-term-send-raw-string (chars)
;   (goto-char eshell-last-output-end)
;   (process-send-string (eshell-interactive-process) chars))

; (defun eshell-term-send-raw ()
;   "Send the last character typed through the terminal-emulator
; without any interpretation."
;   (interactive)
;   ;; Convert `return' to C-m, etc.
;   (if (and (symbolp last-input-char)
;	   (get last-input-char 'ascii-character))
;       (setq last-input-char (get last-input-char 'ascii-character)))
;   (eshell-term-send-raw-string (make-string 1 last-input-char)))

; (defun eshell-term-send-raw-meta ()
;   (interactive)
;   (if (symbolp last-input-char)
;       ;; Convert `return' to C-m, etc.
;       (let ((tmp (get last-input-char 'event-symbol-elements)))
;	(if tmp
;	    (setq last-input-char (car tmp)))
;	(if (symbolp last-input-char)
;	    (progn
;	      (setq tmp (get last-input-char 'ascii-character))
;	      (if tmp (setq last-input-char tmp))))))
;   (eshell-term-send-raw-string (if (and (numberp last-input-char)
;					(> last-input-char 127)
;					(< last-input-char 256))
;				   (make-string 1 last-input-char)
;				 (format "\e%c" last-input-char))))

; (defun eshell-term-mouse-paste (click arg)
;   "Insert the last stretch of killed text at the position clicked on."
;   (interactive "e\nP")
;   (if (boundp 'xemacs-logo)
;       (eshell-term-send-raw-string
;        (or (condition-case () (x-get-selection) (error ()))
;	   (x-get-cutbuffer)
;	   (error "No selection or cut buffer available")))
;     ;; Give temporary modes such as isearch a chance to turn off.
;     (run-hooks 'mouse-leave-buffer-hook)
;     (setq this-command 'yank)
;     (eshell-term-send-raw-string
;      (current-kill (cond ((listp arg) 0)
;			 ((eq arg '-) -1)
;			 (t (1- arg)))))))

; ;; Which would be better:  "\e[A" or "\eOA"? readline accepts either.
; ;; For my configuration it's definitely better \eOA but YMMV. -mm
; ;; For example: vi works with \eOA while elm wants \e[A ...
; (defun eshell-term-send-up    () (interactive) (eshell-term-send-raw-string "\eOA"))
; (defun eshell-term-send-down  () (interactive) (eshell-term-send-raw-string "\eOB"))
; (defun eshell-term-send-right () (interactive) (eshell-term-send-raw-string "\eOC"))
; (defun eshell-term-send-left  () (interactive) (eshell-term-send-raw-string "\eOD"))
; (defun eshell-term-send-home  () (interactive) (eshell-term-send-raw-string "\e[1~"))
; (defun eshell-term-send-end   () (interactive) (eshell-term-send-raw-string "\e[4~"))
; (defun eshell-term-send-prior () (interactive) (eshell-term-send-raw-string "\e[5~"))
; (defun eshell-term-send-next  () (interactive) (eshell-term-send-raw-string "\e[6~"))
; (defun eshell-term-send-del   () (interactive) (eshell-term-send-raw-string "\C-?"))
; (defun eshell-term-send-backspace  () (interactive) (eshell-term-send-raw-string "\C-H"))

; (defun eshell-term-set-escape-char (c)
;   "Change term-escape-char and keymaps that depend on it."
;   (if eshell-term-escape-char
;       (define-key eshell-term-raw-map eshell-term-escape-char 'eshell-term-send-raw))
;   (setq c (make-string 1 c))
;   (define-key eshell-term-raw-map c eshell-term-raw-escape-map)
;   ;; Define standard bindings in eshell-term-raw-escape-map
;   (define-key eshell-term-raw-escape-map "\C-x"
;     (lookup-key (current-global-map) "\C-x"))
;   (define-key eshell-term-raw-escape-map "\C-v"
;     (lookup-key (current-global-map) "\C-v"))
;   (define-key eshell-term-raw-escape-map "\C-u"
;     (lookup-key (current-global-map) "\C-u"))
;   (define-key eshell-term-raw-escape-map c 'eshell-term-send-raw))

; (defun eshell-term-char-mode ()
;   "Switch to char (\"raw\") sub-mode of term mode.
; Each character you type is sent directly to the inferior without
; intervention from Emacs, except for the escape character (usually C-c)."
;   (interactive)
;   (if (not eshell-term-raw-map)
;       (let* ((map (make-keymap))
;	     (esc-map (make-keymap))
;	     (i 0))
;	(while (< i 128)
;	  (define-key map (make-string 1 i) 'eshell-term-send-raw)
;	  (define-key esc-map (make-string 1 i) 'eshell-term-send-raw-meta)
;	  (setq i (1+ i)))
;	(define-key map "\e" esc-map)
;	(setq eshell-term-raw-map map)
;	(setq eshell-term-raw-escape-map
;	      (copy-keymap (lookup-key (current-global-map) "\C-x")))
;	(if (boundp 'xemacs-logo)
;	    (define-key eshell-term-raw-map [button2] 'eshell-term-mouse-paste)
;	  (define-key eshell-term-raw-map [mouse-2] 'eshell-term-mouse-paste))
;	(define-key eshell-term-raw-map [up] 'eshell-term-send-up)
;	(define-key eshell-term-raw-map [down] 'eshell-term-send-down)
;	(define-key eshell-term-raw-map [right] 'eshell-term-send-right)
;	(define-key eshell-term-raw-map [left] 'eshell-term-send-left)
;	(define-key eshell-term-raw-map [delete] 'eshell-term-send-del)
;	(define-key eshell-term-raw-map [backspace] 'eshell-term-send-backspace)
;	(define-key eshell-term-raw-map [home] 'eshell-term-send-home)
;	(define-key eshell-term-raw-map [end] 'eshell-term-send-end)
;	(define-key eshell-term-raw-map [prior] 'eshell-term-send-prior)
;	(define-key eshell-term-raw-map [next] 'eshell-term-send-next)
;	(eshell-term-set-escape-char ?\C-c))))

; (defun eshell-term-line-mode  ()
;   "Switch to line (\"cooked\") sub-mode of eshell-term mode."
;  (use-local-map term-old-mode-map))

;;; Code:

;;; arch-tag: ab7c8fe4-3101-4257-925b-1354c6b2fe9d
;;; em-term.el ends here
