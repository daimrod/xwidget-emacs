;;; w32-win.el --- parse switches controlling interface with W32 window system.

;; Copyright (C) 1993, 1994 Free Software Foundation, Inc.

;; Author: Kevin Gallo
;; Keywords: terminals

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

;; w32-win.el:  this file is loaded from ../lisp/startup.el when it recognizes
;; that W32 windows are to be used.  Command line switches are parsed and those
;; pertaining to W32 are processed and removed from the command line.  The
;; W32 display is opened and hooks are set for popping up the initial window.

;; startup.el will then examine startup files, and eventually call the hooks
;; which create the first window (s).

;;; Code:


;; These are the standard X switches from the Xt Initialize.c file of
;; Release 4.

;; Command line		Resource Manager string

;; +rv			*reverseVideo
;; +synchronous		*synchronous
;; -background		*background
;; -bd			*borderColor
;; -bg			*background
;; -bordercolor		*borderColor
;; -borderwidth		.borderWidth
;; -bw			.borderWidth
;; -display		.display
;; -fg			*foreground
;; -fn			*font
;; -font		*font
;; -foreground		*foreground
;; -geometry		.geometry
;; -i			.iconType
;; -itype		.iconType
;; -iconic		.iconic
;; -name		.name
;; -reverse		*reverseVideo
;; -rv			*reverseVideo
;; -selectionTimeout    .selectionTimeout
;; -synchronous		*synchronous
;; -xrm

;; An alist of X options and the function which handles them.  See
;; ../startup.el.

(if (not (eq window-system 'w32))
    (error "%s: Loading w32-win.el but not compiled for w32" (invocation-name)))
	 
(require 'frame)
(require 'mouse)
(require 'scroll-bar)
(require 'faces)
(require 'select)
(require 'menu-bar)
(if (fboundp 'new-fontset)
    (require 'fontset))

;; FIXME: this is temporary for v21.1, since many redisplay problems
;; happen if redisplay-dont-pause is nil.
(setq redisplay-dont-pause t)

;; Because Windows scrollbars look and act quite differently compared
;; with the standard X scroll-bars, we don't try to use the normal
;; scroll bar routines.

(defun w32-handle-scroll-bar-event (event)
  "Handle W32 scroll bar EVENT to do normal Window style scrolling."
  (interactive "e")
  (let ((old-window (selected-window)))
    (unwind-protect
	(let* ((position (event-start event))
	       (window (nth 0 position))
	       (portion-whole (nth 2 position))
	       (bar-part (nth 4 position)))
	  (save-excursion
	    (select-window window)
	    (cond
	     ((eq bar-part 'up)
	      (goto-char (window-start window))
	      (scroll-down 1))
	     ((eq bar-part 'above-handle)
	      (scroll-down))
	     ((eq bar-part 'handle)
	      (scroll-bar-maybe-set-window-start event))
	     ((eq bar-part 'below-handle)
	      (scroll-up))
	     ((eq bar-part 'down)
	      (goto-char (window-start window))
	      (scroll-up 1))
	     )))
      (select-window old-window))))

;; The following definition is used for debugging.
;(defun w32-handle-scroll-bar-event (event) (interactive "e") (princ event))

(global-set-key [vertical-scroll-bar mouse-1] 'w32-handle-scroll-bar-event)

;; (scroll-bar-mode nil)

(defvar mouse-wheel-scroll-amount 4
  "*Number of lines to scroll per click of the mouse wheel.")

(defun mouse-wheel-scroll-line (event)
  "Scroll the window in which EVENT occurred by `mouse-wheel-scroll-amount'."
  (interactive "e")
  (condition-case nil
      (if (< (car (cdr (cdr event))) 0)
	  (scroll-up mouse-wheel-scroll-amount)
	(scroll-down mouse-wheel-scroll-amount))
    (error nil)))

;; for scroll-in-place.el, this way the -scroll-line and -scroll-screen
;; commands won't interact
(setq scroll-command-groups (list '(mouse-wheel-scroll-line)))

(defun mouse-wheel-scroll-screen (event)
  "Scroll the window in which EVENT occurred by `mouse-wheel-scroll-amount'."
  (interactive "e")
  (condition-case nil
      (if (< (car (cdr (cdr event))) 0)
          (scroll-up)
        (scroll-down))
    (error nil)))

;; Bind the mouse-wheel event:
(global-set-key [mouse-wheel] 'mouse-wheel-scroll-line)
(global-set-key [C-mouse-wheel] 'mouse-wheel-scroll-screen)

(defun w32-drag-n-drop-debug (event)
  "Print the drag-n-drop EVENT in a readable form."
  (interactive "e")
  (princ event))

(defun w32-drag-n-drop (event)
  "Edit the files listed in the drag-n-drop EVENT.
Switch to a buffer editing the last file dropped."
  (interactive "e")
  (save-excursion
    ;; Make sure the drop target has positive co-ords
    ;; before setting the selected frame - otherwise it
    ;; won't work.  <skx@tardis.ed.ac.uk>
    (let* ((window (posn-window (event-start event)))
	   (coords (posn-x-y (event-start event)))
	   (x (car coords))
	   (y (cdr coords)))
      (if (and (> x 0) (> y 0))
	  (set-frame-selected-window nil window))
    (mapcar 'find-file (car (cdr (cdr event)))))
  (raise-frame)))

(defun w32-drag-n-drop-other-frame (event)
  "Edit the files listed in the drag-n-drop EVENT, in other frames.
May create new frames, or reuse existing ones.  The frame editing
the last file dropped is selected."
  (interactive "e")
  (mapcar 'find-file-other-frame (car (cdr (cdr event)))))

;; Bind the drag-n-drop event.
(global-set-key [drag-n-drop] 'w32-drag-n-drop)
(global-set-key [C-drag-n-drop] 'w32-drag-n-drop-other-frame)

;; Keyboard layout/language change events
;; For now ignore language-change events; in the future
;; we should switch the Emacs Input Method to match the
;; new layout/language selected by the user.
(global-set-key [language-change] 'ignore)

(defvar x-invocation-args)

(defvar x-command-line-resources nil)

(defconst x-option-alist
  '(("-bw" .	x-handle-numeric-switch)
    ("-d" .		x-handle-display)
    ("-display" .	x-handle-display)
    ("-name" .	x-handle-name-rn-switch)
    ("-rn" .	x-handle-name-rn-switch)
    ("-T" .		x-handle-switch)
    ("-r" .		x-handle-switch)
    ("-rv" .	x-handle-switch)
    ("-reverse" .	x-handle-switch)
    ("-fn" .	x-handle-switch)
    ("-font" .	x-handle-switch)
    ("-ib" .	x-handle-numeric-switch)
    ("-g" .		x-handle-geometry)
    ("-geometry" .	x-handle-geometry)
    ("-fg" .	x-handle-switch)
    ("-foreground".	x-handle-switch)
    ("-bg" .	x-handle-switch)
    ("-background".	x-handle-switch)
    ("-ms" .	x-handle-switch)
    ("-itype" .	x-handle-switch)
    ("-i" 	.	x-handle-switch)
    ("-iconic" .	x-handle-iconic)
    ("-xrm" .       x-handle-xrm-switch)
    ("-cr" .	x-handle-switch)
    ("-vb" .	x-handle-switch)
    ("-hb" .	x-handle-switch)
    ("-bd" .	x-handle-switch)))

(defconst x-long-option-alist
  '(("--border-width" .	"-bw")
    ("--display" .	"-d")
    ("--name" .		"-name")
    ("--title" .	"-T")
    ("--reverse-video" . "-reverse")
    ("--font" .		"-font")
    ("--internal-border" . "-ib")
    ("--geometry" .	"-geometry")
    ("--foreground-color" . "-fg")
    ("--background-color" . "-bg")
    ("--mouse-color" .	"-ms")
    ("--icon-type" .	"-itype")
    ("--iconic" .	"-iconic")
    ("--xrm" .		"-xrm")
    ("--cursor-color" .	"-cr")
    ("--vertical-scroll-bars" . "-vb")
    ("--border-color" .	"-bd")))

(defconst x-switch-definitions
  '(("-name" name)
    ("-T" name)
    ("-r" reverse t)
    ("-rv" reverse t)
    ("-reverse" reverse t)
    ("-fn" font)
    ("-font" font)
    ("-ib" internal-border-width)
    ("-fg" foreground-color)
    ("-foreground" foreground-color)
    ("-bg" background-color)
    ("-background" background-color)
    ("-ms" mouse-color)
    ("-cr" cursor-color)
    ("-itype" icon-type t)
    ("-i" icon-type t)
    ("-vb" vertical-scroll-bars t)
    ("-hb" horizontal-scroll-bars t)
    ("-bd" border-color)
    ("-bw" border-width)))


(defun x-handle-switch (switch)
  "Handle SWITCH of the form \"-switch value\" or \"-switch\"."
  (let ((aelt (assoc switch x-switch-definitions)))
    (if aelt
	(if (nth 2 aelt)
	    (setq default-frame-alist
		  (cons (cons (nth 1 aelt) (nth 2 aelt))
			default-frame-alist))
	  (setq default-frame-alist
		(cons (cons (nth 1 aelt)
			    (car x-invocation-args))
		      default-frame-alist)
		x-invocation-args (cdr x-invocation-args))))))

(defun x-handle-iconic (switch)
  "Make \"-iconic\" SWITCH apply only to the initial frame."
  (setq initial-frame-alist
	(cons '(visibility . icon) initial-frame-alist)))


(defun x-handle-numeric-switch (switch)
  "Handle SWITCH of the form \"-switch n\"."
  (let ((aelt (assoc switch x-switch-definitions)))
    (if aelt
	(setq default-frame-alist
	      (cons (cons (nth 1 aelt)
			  (string-to-int (car x-invocation-args)))
		    default-frame-alist)
	      x-invocation-args
	      (cdr x-invocation-args)))))

(defun x-handle-xrm-switch (switch)
  "Handle the \"-xrm\" SWITCH."
  (or (consp x-invocation-args)
      (error "%s: missing argument to `%s' option" (invocation-name) switch))
  (setq x-command-line-resources (car x-invocation-args))
  (setq x-invocation-args (cdr x-invocation-args)))

(defun x-handle-geometry (switch)
  "Handle the \"-geometry\" SWITCH."
  (let ((geo (x-parse-geometry (car x-invocation-args))))
    (setq initial-frame-alist
	  (append initial-frame-alist
		  (if (or (assq 'left geo) (assq 'top geo))
		      '((user-position . t)))
		  (if (or (assq 'height geo) (assq 'width geo))
		      '((user-size . t)))
		  geo)
	  x-invocation-args (cdr x-invocation-args))))

(defun x-handle-name-rn-switch (switch)
  "Handle a \"-name\" or \"-rn\" SWITCH."
;; Handle the -name and -rn options.  Set the variable x-resource-name
;; to the option's operand; if the switch was `-name', set the name of
;; the initial frame, too.
  (or (consp x-invocation-args)
      (error "%s: missing argument to `%s' option" (invocation-name) switch))
  (setq x-resource-name (car x-invocation-args)
	x-invocation-args (cdr x-invocation-args))
  (if (string= switch "-name")
      (setq initial-frame-alist (cons (cons 'name x-resource-name)
				      initial-frame-alist))))

(defvar x-display-name nil
  "The display name specifying server and frame.")

(defun x-handle-display (switch)
  "Handle the \"-display\" SWITCH."
  (setq x-display-name (car x-invocation-args)
	x-invocation-args (cdr x-invocation-args)))

(defvar x-invocation-args nil)

(defun x-handle-args (args)
  "Process the X-related command line options in ARGS.
This is done before the user's startup file is loaded.  They are copied to
x-invocation args from which the X-related things are extracted, first
the switch (e.g., \"-fg\") in the following code, and possible values
\(e.g., \"black\") in the option handler code (e.g., x-handle-switch).
This returns ARGS with the arguments that have been processed removed."
  (setq x-invocation-args args
	args nil)
  (while x-invocation-args
    (let* ((this-switch (car x-invocation-args))
	   (orig-this-switch this-switch)
	   completion argval aelt)
      (setq x-invocation-args (cdr x-invocation-args))
      ;; Check for long options with attached arguments
      ;; and separate out the attached option argument into argval.
      (if (string-match "^--[^=]*=" this-switch)
	  (setq argval (substring this-switch (match-end 0))
		this-switch (substring this-switch 0 (1- (match-end 0)))))
      (setq completion (try-completion this-switch x-long-option-alist))
      (if (eq completion t)
	  ;; Exact match for long option.
	  (setq this-switch (cdr (assoc this-switch x-long-option-alist)))
	(if (stringp completion)
	    (let ((elt (assoc completion x-long-option-alist)))
	      ;; Check for abbreviated long option.
	      (or elt
		  (error "Option `%s' is ambiguous" this-switch))
	      (setq this-switch (cdr elt)))
	  ;; Check for a short option.
	  (setq argval nil this-switch orig-this-switch)))
      (setq aelt (assoc this-switch x-option-alist))
      (if aelt
	  (if argval
	      (let ((x-invocation-args
		     (cons argval x-invocation-args)))
		(funcall (cdr aelt) this-switch))
	    (funcall (cdr aelt) this-switch))
	(setq args (cons this-switch args)))))
  (setq args (nreverse args)))



;;
;; Available colors
;;

(defvar x-colors '("aquamarine"
		   "Aquamarine"
		   "medium aquamarine"
		   "MediumAquamarine"
		   "black"
		   "Black"
		   "blue"
		   "Blue"
		   "cadet blue"
		   "CadetBlue"
		   "cornflower blue"
		   "CornflowerBlue"
		   "dark slate blue"
		   "DarkSlateBlue"
		   "light blue"
		   "LightBlue"
		   "light steel blue"
		   "LightSteelBlue"
		   "medium blue"
		   "MediumBlue"
		   "medium slate blue"
		   "MediumSlateBlue"
		   "midnight blue"
		   "MidnightBlue"
		   "navy blue"
		   "NavyBlue"
		   "navy"
		   "Navy"
		   "sky blue"
		   "SkyBlue"
		   "slate blue"
		   "SlateBlue"
		   "steel blue"
		   "SteelBlue"
		   "coral"
		   "Coral"
		   "cyan"
		   "Cyan"
		   "firebrick"
		   "Firebrick"
		   "brown"
		   "Brown"
		   "gold"
		   "Gold"
		   "goldenrod"
		   "Goldenrod"
		   "green"
		   "Green"
		   "dark green"
		   "DarkGreen"
		   "dark olive green"
		   "DarkOliveGreen"
		   "forest green"
		   "ForestGreen"
		   "lime green"
		   "LimeGreen"
		   "medium sea green"
		   "MediumSeaGreen"
		   "medium spring green"
		   "MediumSpringGreen"
		   "pale green"
		   "PaleGreen"
		   "sea green"
		   "SeaGreen"
		   "spring green"
		   "SpringGreen"
		   "yellow green"
		   "YellowGreen"
		   "dark slate grey"
		   "DarkSlateGrey"
		   "dark slate gray"
		   "DarkSlateGray"
		   "dim grey"
		   "DimGrey"
		   "dim gray"
		   "DimGray"
		   "light grey"
		   "LightGrey"
		   "light gray"
		   "LightGray"
		   "gray"
		   "grey"
		   "Gray"
		   "Grey"
		   "khaki"
		   "Khaki"
		   "magenta"
		   "Magenta"
		   "maroon"
		   "Maroon"
		   "orange"
		   "Orange"
		   "orchid"
		   "Orchid"
		   "dark orchid"
		   "DarkOrchid"
		   "medium orchid"
		   "MediumOrchid"
		   "pink"
		   "Pink"
		   "plum"
		   "Plum"
		   "red"
		   "Red"
		   "indian red"
		   "IndianRed"
		   "medium violet red"
		   "MediumVioletRed"
		   "orange red"
		   "OrangeRed"
		   "violet red"
		   "VioletRed"
		   "salmon"
		   "Salmon"
		   "sienna"
		   "Sienna"
		   "tan"
		   "Tan"
		   "thistle"
		   "Thistle"
		   "turquoise"
		   "Turquoise"
		   "dark turquoise"
		   "DarkTurquoise"
		   "medium turquoise"
		   "MediumTurquoise"
		   "violet"
		   "Violet"
		   "blue violet"
		   "BlueViolet"
		   "wheat"
		   "Wheat"
		   "white"
		   "White"
		   "yellow"
		   "Yellow"
		   "green yellow"
		   "GreenYellow")
  "The full list of X colors from the `rgb.text' file.")

(defun xw-defined-colors (&optional frame)
  "Internal function called by `defined-colors', which see."
  (or frame (setq frame (selected-frame)))
  (let* ((color-map-colors (mapcar (lambda (clr) (car clr)) w32-color-map))
	 (all-colors (or color-map-colors x-colors))
	 (this-color nil)
	 (defined-colors nil))
    (message "Defining colors...")
    (while all-colors
      (setq this-color (car all-colors)
	    all-colors (cdr all-colors))
      (and (color-supported-p this-color frame t)
	   (setq defined-colors (cons this-color defined-colors))))
    defined-colors))


;;;; Function keys

;;; make f10 activate the real menubar rather than the mini-buffer menu
;;; navigation feature.
(global-set-key [f10] (lambda ()
			(interactive) (w32-send-sys-command ?\xf100)))

(defun iconify-or-deiconify-frame ()
  "Iconify the selected frame, or deiconify if it's currently an icon."
  (interactive)
  (if (eq (cdr (assq 'visibility (frame-parameters))) t)
      (iconify-frame)
    (make-frame-visible)))

(substitute-key-definition 'suspend-emacs 'iconify-or-deiconify-frame
			   global-map)


;;; Do the actual Windows setup here; the above code just defines
;;; functions and variables that we use now.

(setq command-line-args (x-handle-args command-line-args))

;;; Make sure we have a valid resource name.
(or (stringp x-resource-name)
    (let (i)
      (setq x-resource-name (invocation-name))

      ;; Change any . or * characters in x-resource-name to hyphens,
      ;; so as not to choke when we use it in X resource queries.
      (while (setq i (string-match "[.*]" x-resource-name))
	(aset x-resource-name i ?-))))

;; For the benefit of older Emacses (19.27 and earlier) that are sharing
;; the same lisp directory, don't pass the third argument unless we seem
;; to have the multi-display support.
(if (fboundp 'x-close-connection)
    (x-open-connection ""
		       x-command-line-resources
		       ;; Exit Emacs with fatal error if this fails.
		       t)
  (x-open-connection ""
		     x-command-line-resources))

(setq frame-creation-function 'x-create-frame-with-faces)

(setq x-cut-buffer-max (min (- (/ (x-server-max-request-size) 2) 100)
			    x-cut-buffer-max))

;; W32 expects the menu bar cut and paste commands to use the clipboard.
;; This has ,? to match both on Sunos and on Solaris.
(menu-bar-enable-clipboard)

;; W32 systems have different fonts than commonly found on X, so
;; we define our own standard fontset here.
(defvar w32-standard-fontset-spec
 "-*-Courier New-normal-r-*-*-13-*-*-*-c-*-fontset-standard"
 "String of fontset spec of the standard fontset.
This defines a fontset consisting of the Courier New variations for
European languages which are distributed with Windows as
\"Multilanguage Support\".

See the documentation of `create-fontset-from-fontset-spec for the format.")

(if (fboundp 'new-fontset)
    (progn
      ;; Create the standard fontset.
      (create-fontset-from-fontset-spec w32-standard-fontset-spec t)
      ;; Create fontset specified in X resources "Fontset-N" (N is 0, 1,...).
      (create-fontset-from-x-resource)
      ;; Try to create a fontset from a font specification which comes
      ;; from initial-frame-alist, default-frame-alist, or X resource.
      ;; A font specification in command line argument (i.e. -fn XXXX)
      ;; should be already in default-frame-alist as a `font'
      ;; parameter.  However, any font specifications in site-start
      ;; library, user's init file (.emacs), and default.el are not
      ;; yet handled here.

      (let ((font (or (cdr (assq 'font initial-frame-alist))
                      (cdr (assq 'font default-frame-alist))
                      (x-get-resource "font" "Font")))
            xlfd-fields resolved-name)
        (if (and font
                 (not (query-fontset font))
                 (setq resolved-name (x-resolve-font-name font))
                 (setq xlfd-fields (x-decompose-font-name font)))
            (if (string= "fontset"
                         (aref xlfd-fields xlfd-regexp-registry-subnum))
                (new-fontset font
                             (x-complement-fontset-spec xlfd-fields nil))
              ;; Create a fontset from FONT.  The fontset name is
              ;; generated from FONT.
              (create-fontset-from-ascii-font font
					      resolved-name "startup"))))))

;; Apply a geometry resource to the initial frame.  Put it at the end
;; of the alist, so that anything specified on the command line takes
;; precedence.
(let* ((res-geometry (x-get-resource "geometry" "Geometry"))
       parsed)
  (if res-geometry
      (progn
	(setq parsed (x-parse-geometry res-geometry))
	;; If the resource specifies a position,
	;; call the position and size "user-specified".
	(if (or (assq 'top parsed) (assq 'left parsed))
	    (setq parsed (cons '(user-position . t)
			       (cons '(user-size . t) parsed))))
	;; All geometry parms apply to the initial frame.
	(setq initial-frame-alist (append initial-frame-alist parsed))
	;; The size parms apply to all frames.
	(if (assq 'height parsed)
	    (setq default-frame-alist
		  (cons (cons 'height (cdr (assq 'height parsed)))
			default-frame-alist)))
	(if (assq 'width parsed)
	    (setq default-frame-alist
		  (cons (cons 'width (cdr (assq 'width parsed)))
			default-frame-alist))))))

;; Check the reverseVideo resource.
(let ((case-fold-search t))
  (let ((rv (x-get-resource "reverseVideo" "ReverseVideo")))
    (if (and rv
	     (string-match "^\\(true\\|yes\\|on\\)$" rv))
	(setq default-frame-alist
	      (cons '(reverse . t) default-frame-alist)))))

(defun x-win-suspend-error ()
  "Report an error when a suspend is attempted."
  (error "Suspending an Emacs running under W32 makes no sense"))
(add-hook 'suspend-hook 'x-win-suspend-error)

;;; Turn off window-splitting optimization; w32 is usually fast enough
;;; that this is only annoying.
(setq split-window-keep-point t)

;; Don't show the frame name; that's redundant.
(setq-default mode-line-frame-identification "  ")

;;; Set to a system sound if you want a fancy bell.
(set-message-beep 'ok)

;; Remap some functions to call w32 common dialogs

(defun internal-face-interactive (what &optional bool)
  (let* ((fn (intern (concat "face-" what)))
	 (prompt (concat "Set " what " of face "))
	 (face (read-face-name prompt))
	 (default (if (fboundp fn)
		      (or (funcall fn face (selected-frame))
			  (funcall fn 'default (selected-frame)))))
	 (fn-win (intern (concat (symbol-name window-system) "-select-" what)))
	 value)
    (setq value
	  (cond ((fboundp fn-win)
		 (funcall fn-win))
		((eq bool 'color)
		 (completing-read (concat prompt " " (symbol-name face) " to: ")
				  (mapcar (function (lambda (color)
						      (cons color color)))
					  x-colors)
				  nil nil nil nil default))
		(bool
		 (y-or-n-p (concat "Should face " (symbol-name face)
				   " be " bool "? ")))
		(t
		 (read-string (concat prompt " " (symbol-name face) " to: ")
			      nil nil default))))
    (list face (if (equal value "") nil value))))

;; Redefine the font selection to use the standard W32 dialog
(defvar w32-use-w32-font-dialog t
  "*Use the standard font dialog if 't'.
Otherwise pop up a menu of some standard fonts like X does - including
fontsets.")

(defvar w32-fixed-font-alist
  '("Font menu"
    ("Misc"
     ;; For these, we specify the pixel height and width.
     ("fixed" "Fixedsys")
     ("")
     ("Terminal 5x4"
      "-*-Terminal-normal-r-*-*-*-45-*-*-c-40-*-oem")
     ("Terminal 6x8"
      "-*-Terminal-normal-r-*-*-*-60-*-*-c-80-*-oem")
     ("Terminal 9x5"
      "-*-Terminal-normal-r-*-*-*-90-*-*-c-50-*-oem")
     ("Terminal 9x7"
      "-*-Terminal-normal-r-*-*-*-90-*-*-c-70-*-oem")
     ("Terminal 9x8"
      "-*-Terminal-normal-r-*-*-*-90-*-*-c-80-*-oem")
     ("Terminal 12x12"
      "-*-Terminal-normal-r-*-*-*-120-*-*-c-120-*-oem")
     ("Terminal 14x10"
      "-*-Terminal-normal-r-*-*-*-135-*-*-c-100-*-oem")
     ("Terminal 6x6 Bold"
      "-*-Terminal-bold-r-*-*-*-60-*-*-c-60-*-oem")
     ("")
     ("Lucida Sans Typewriter.8"
      "-*-Lucida Sans Typewriter-normal-r-*-*-11-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.9"
      "-*-Lucida Sans Typewriter-normal-r-*-*-12-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.10"
      "-*-Lucida Sans Typewriter-normal-r-*-*-13-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.11"
      "-*-Lucida Sans Typewriter-normal-r-*-*-15-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.12"
      "-*-Lucida Sans Typewriter-normal-r-*-*-16-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.8 Bold"
      "-*-Lucida Sans Typewriter-semibold-r-*-*-11-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.9 Bold"
      "-*-Lucida Sans Typewriter-semibold-r-*-*-12-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.10 Bold"
      "-*-Lucida Sans Typewriter-semibold-r-*-*-13-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.11 Bold"
      "-*-Lucida Sans Typewriter-semibold-r-*-*-15-*-*-*-c-*-iso8859-1")
     ("Lucida Sans Typewriter.12 Bold"
      "-*-Lucida Sans Typewriter-semibold-r-*-*-16-*-*-*-c-*-iso8859-1"))
    ("Courier"
     ("Courier 10x8"
      "-*-Courier-*normal-r-*-*-*-97-*-*-c-80-iso8859-1")
     ("Courier 12x9"
      "-*-Courier-*normal-r-*-*-*-120-*-*-c-90-iso8859-1")
     ("Courier 15x12"
      "-*-Courier-*normal-r-*-*-*-150-*-*-c-120-iso8859-1")
     ;; For these, we specify the point height.
     ("")
     ("8" "-*-Courier New-normal-r-*-*-11-*-*-*-c-*-iso8859-1")
     ("9" "-*-Courier New-normal-r-*-*-12-*-*-*-c-*-iso8859-1")
     ("10" "-*-Courier New-normal-r-*-*-13-*-*-*-c-*-iso8859-1")
     ("11" "-*-Courier New-normal-r-*-*-15-*-*-*-c-*-iso8859-1")
     ("12" "-*-Courier New-normal-r-*-*-16-*-*-*-c-*-iso8859-1")
     ("8 bold" "-*-Courier New-bold-r-*-*-11-*-*-*-c-*-iso8859-1")
     ("9 bold" "-*-Courier New-bold-r-*-*-12-*-*-*-c-*-iso8859-1")
     ("10 bold" "-*-Courier New-bold-r-*-*-13-*-*-*-c-*-iso8859-1")
     ("11 bold" "-*-Courier New-bold-r-*-*-15-*-*-*-c-*-iso8859-1")
     ("12 bold" "-*-Courier New-bold-r-*-*-16-*-*-*-c-*-iso8859-1")
     ("8 italic" "-*-Courier New-normal-i-*-*-11-*-*-*-c-*-iso8859-1")
     ("9 italic" "-*-Courier New-normal-i-*-*-12-*-*-*-c-*-iso8859-1")
     ("10 italic" "-*-Courier New-normal-i-*-*-13-*-*-*-c-*-iso8859-1")
     ("11 italic" "-*-Courier New-normal-i-*-*-15-*-*-*-c-*-iso8859-1")
     ("12 italic" "-*-Courier New-normal-i-*-*-16-*-*-*-c-*-iso8859-1")
     ("8 bold italic" "-*-Courier New-bold-i-*-*-11-*-*-*-c-*-iso8859-1")
     ("9 bold italic" "-*-Courier New-bold-i-*-*-12-*-*-*-c-*-iso8859-1")
     ("10 bold italic" "-*-Courier New-bold-i-*-*-13-*-*-*-c-*-iso8859-1")
     ("11 bold italic" "-*-Courier New-bold-i-*-*-15-*-*-*-c-*-iso8859-1")
     ("12 bold italic" "-*-Courier New-bold-i-*-*-16-*-*-*-c-*-iso8859-1")
     ))
    "Fonts suitable for use in Emacs.
Initially this is a list of some fixed width fonts that most people
will have like Terminal and Courier. These fonts are used in the font
menu if the variable `w32-use-w32-font-dialog' is nil.")

;;; Enable Japanese fonts on Windows to be used by default.
(set-fontset-font t (make-char 'katakana-jisx0201) '("*" . "JISX0208-SJIS"))
(set-fontset-font t (make-char 'latin-jisx0201) '("*" . "JISX0208-SJIS"))
(set-fontset-font t (make-char 'japanese-jisx0208) '("*" . "JISX0208-SJIS"))
(set-fontset-font t (make-char 'japanese-jisx0208-1978) '("*" . "JISX0208-SJIS"))

(defun mouse-set-font (&rest fonts)
  "Select a font.
If `w32-use-w32-font-dialog' is non-nil (the default), use the Windows
font dialog to get the matching FONTS. Otherwise use a pop-up menu
(like Emacs on other platforms) initialized with the fonts in
`w32-fixed-font-alist'."
  (interactive
   (if w32-use-w32-font-dialog
       (let ((chosen-font (w32-select-font)))
	 (and chosen-font (list chosen-font)))
     (x-popup-menu
      last-nonmenu-event
    ;; Append list of fontsets currently defined.
      (if (fboundp 'new-fontset)
      (append w32-fixed-font-alist (list (generate-fontset-menu)))))))
  (if fonts
      (let (font)
	(while fonts
	  (condition-case nil
	      (progn
                (setq font (car fonts))
		(set-default-font font)
                (setq fonts nil))
	    (error (setq fonts (cdr fonts)))))
	(if (null font)
	    (error "Font not found")))))

;;; w32-win.el ends here
