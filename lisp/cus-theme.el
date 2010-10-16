;;; cus-theme.el -- custom theme creation user interface
;;
;; Copyright (C) 2001, 2002, 2003, 2004, 2005,
;;   2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.
;;
;; Author: Alex Schroeder <alex@gnu.org>
;; Maintainer: FSF
;; Keywords: help, faces
;; Package: emacs

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'widget)
(require 'cus-edit)

(eval-when-compile
  (require 'wid-edit))

(defvar custom-new-theme-mode-map
  (let ((map (make-keymap)))
    (set-keymap-parent map widget-keymap)
    (suppress-keymap map)
    (define-key map "\C-x\C-s" 'custom-theme-write)
    (define-key map "n" 'widget-forward)
    (define-key map "p" 'widget-backward)
    map)
  "Keymap for `custom-new-theme-mode'.")

(define-derived-mode custom-new-theme-mode nil "Custom-Theme"
  "Major mode for editing Custom themes.
Do not call this mode function yourself.  It is meant for internal use."
  (use-local-map custom-new-theme-mode-map)
  (custom--initialize-widget-variables)
  (set (make-local-variable 'revert-buffer-function) 'custom-theme-revert))
(put 'custom-new-theme-mode 'mode-class 'special)

(defvar custom-theme-name nil)
(defvar custom-theme-variables nil)
(defvar custom-theme-faces nil)
(defvar custom-theme-description nil)
(defvar custom-theme-insert-variable-marker nil)
(defvar custom-theme-insert-face-marker nil)

(defvar custom-theme--listed-faces '(default cursor fixed-pitch
  variable-pitch escape-glyph minibuffer-prompt highlight region
  shadow secondary-selection trailing-whitespace
  font-lock-builtin-face font-lock-comment-delimiter-face
  font-lock-comment-face font-lock-constant-face
  font-lock-doc-face font-lock-function-name-face
  font-lock-keyword-face font-lock-negation-char-face
  font-lock-preprocessor-face font-lock-regexp-grouping-backslash
  font-lock-regexp-grouping-construct font-lock-string-face
  font-lock-type-face font-lock-variable-name-face
  font-lock-warning-face button link link-visited fringe
  header-line tooltip mode-line mode-line-buffer-id
  mode-line-emphasis mode-line-highlight mode-line-inactive
  isearch isearch-fail lazy-highlight match next-error
  query-replace)
  "Faces listed by default in the *Custom Theme* buffer.")

(defvar custom-theme--save-name)

;;;###autoload
(defun customize-create-theme (&optional theme buffer)
  "Create or edit a custom theme.
THEME, if non-nil, should be an existing theme to edit.
BUFFER, if non-nil, should be a buffer to use; the default is
named *Custom Theme*."
  (interactive)
  (switch-to-buffer (get-buffer-create (or buffer "*Custom Theme*")))
  (let ((inhibit-read-only t))
    (erase-buffer)
    (dolist (ov (overlays-in (point-min) (point-max)))
      (delete-overlay ov)))
  (custom-new-theme-mode)
  (make-local-variable 'custom-theme-name)
  (set (make-local-variable 'custom-theme--save-name) theme)
  (set (make-local-variable 'custom-theme-faces) nil)
  (set (make-local-variable 'custom-theme-variables) nil)
  (set (make-local-variable 'custom-theme-description) "")
  (make-local-variable 'custom-theme-insert-face-marker)
  (make-local-variable 'custom-theme-insert-variable-marker)
  (make-local-variable 'custom-theme--listed-faces)

  (widget-create 'push-button
		 :tag " Visit Theme "
		 :help-echo "Insert the settings of a pre-defined theme."
		 :action (lambda (widget &optional event)
			   (call-interactively 'custom-theme-visit-theme)))
  (widget-insert "  ")
  (widget-create 'push-button
		 :tag " Merge Theme "
		 :help-echo "Merge in the settings of a pre-defined theme."
		 :action (lambda (widget &optional event)
			   (call-interactively 'custom-theme-merge-theme)))
  (widget-insert "  ")
  (widget-create 'push-button :notify 'revert-buffer " Revert ")

  (widget-insert "\n\nTheme name : ")
  (setq custom-theme-name
	(widget-create 'editable-field
		       :value (if theme (symbol-name theme) "")))
  (widget-insert "Description: ")
  (setq custom-theme-description
	(widget-create 'text
		       :value (format-time-string "Created %Y-%m-%d.")))
  (widget-insert "             ")
  (widget-create 'push-button
     		 :notify (function custom-theme-write)
     		 " Save Theme ")

  (let (vars values faces face-specs)

    ;; Load the theme settings.
    (when theme
      (load-theme theme t)
      (dolist (setting (get theme 'theme-settings))
	(if (eq (car setting) 'theme-value)
	    (progn (push (nth 1 setting) vars)
	    	   (push (nth 3 setting) values))
	  (push (nth 1 setting) faces)
	  (push (nth 3 setting) face-specs))))

    ;; If THEME is non-nil, insert all of that theme's faces.
    ;; Otherwise, insert those in `custom-theme--listed-faces'.
    (widget-insert "\n\n  Theme faces:\n ")
    (if theme
	(while faces
	  (custom-theme-add-face-1 (pop faces) (pop face-specs)))
      (dolist (face custom-theme--listed-faces)
	(custom-theme-add-face-1 face nil)))
    (setq custom-theme-insert-face-marker (point-marker))
    (widget-insert " ")
    (widget-create 'push-button
		   :tag "Insert Additional Face"
		   :help-echo "Add another face to this theme."
		   :follow-link 'mouse-face
		   :button-face 'custom-link
		   :mouse-face 'highlight
		   :pressed-face 'highlight
		   :action (lambda (widget &optional event)
			     (call-interactively 'custom-theme-add-face)))

    ;; If THEME is non-nil, insert all of that theme's variables.
    (widget-insert "\n\n  Theme variables:\n ")
    (if theme
	(while vars
	  (custom-theme-add-var-1 (pop vars) (pop values))))
    (setq custom-theme-insert-variable-marker (point-marker))
    (widget-insert " ")
    (widget-create 'push-button
		   :tag "Insert Variable"
		   :help-echo "Add another variable to this theme."
		   :follow-link 'mouse-face
		   :button-face 'custom-link
		   :mouse-face 'highlight
		   :pressed-face 'highlight
		   :action (lambda (widget &optional event)
			     (call-interactively 'custom-theme-add-variable)))
    (widget-insert ?\n)
    (widget-setup)
    (goto-char (point-min))
    (message "")))

(defun custom-theme-revert (ignore-auto noconfirm)
  (when (or noconfirm (y-or-n-p "Discard current changes? "))
    (customize-create-theme custom-theme--save-name (current-buffer))))

;;; Theme variables

(defun custom-theme-add-variable (var value)
  "Add a widget for VAR (a symbol) to the *New Custom Theme* buffer.
VALUE should be a value to which to set the widget; when called
interactively, this defaults to the current value of VAR."
  (interactive
   (let ((v (read-variable "Variable name: ")))
     (list v (symbol-value v))))
  (let ((var-and-widget (assq var custom-theme-faces)))
    (cond ((null var-and-widget)
	   ;; If VAR is not yet in the buffer, add it.
	   (save-excursion
	     (goto-char custom-theme-insert-variable-marker)
	     (custom-theme-add-var-1 var value)
	     (move-marker custom-theme-insert-variable-marker (point))
	     (widget-setup)))
	  ;; Otherwise, alter that var widget.
	  (t
	   (let ((widget (cdr var-and-widget)))
	     (widget-put widget :shown-value (list value))
	     (custom-redraw widget))))))

(defun custom-theme-add-var-1 (symbol val)
  (widget-insert " ")
  (push (cons symbol
	      (widget-create 'custom-variable
			     :tag (custom-unlispify-tag-name symbol)
			     :value symbol
			     :shown-value (list val)
			     :notify 'ignore
			     :custom-level 0
			     :custom-state 'hidden
			     :custom-style 'simple))
	custom-theme-variables)
  (widget-insert " "))

;;; Theme faces

(defun custom-theme-add-face (face &optional spec)
  "Add a widget for FACE (a symbol) to the *New Custom Theme* buffer.
SPEC, if non-nil, should be a face spec to which to set the widget."
  (interactive (list (read-face-name "Face name" nil nil) nil))
  (unless (or (facep face) spec)
    (error "`%s' has no face definition" face))
  (let ((face-and-widget (assq face custom-theme-faces)))
    (cond ((null face-and-widget)
	   ;; If FACE is not yet in the buffer, add it.
	   (save-excursion
	     (goto-char custom-theme-insert-face-marker)
	     (custom-theme-add-face-1 face spec)
	     (move-marker custom-theme-insert-face-marker (point))
	     (widget-setup)))
	  ;; Otherwise, if SPEC is supplied, alter that face widget.
	  (spec
	   (let ((widget (cdr face-and-widget)))
	     (widget-put widget :shown-value spec)
	     (custom-redraw widget)))
	  ((called-interactively-p 'interactive)
	   (error "`%s' is already present" face)))))

(defun custom-theme-add-face-1 (symbol spec)
  (widget-insert " ")
  (push (cons symbol
	      (widget-create 'custom-face
			     :tag (custom-unlispify-tag-name symbol)
			     :documentation-shown t
			     :value symbol
			     :custom-state 'hidden
			     :custom-style 'simple
			     :shown-value spec
			     :sample-indent 34))
	custom-theme-faces)
  (widget-insert " "))

;;; Reading and writing

(defun custom-theme-visit-theme (theme)
  "Load the custom theme THEME's settings into the current buffer."
  (interactive
   (list
    (intern (completing-read "Find custom theme: "
			     (mapcar 'symbol-name
				     (custom-available-themes))))))
  (unless (custom-theme-name-valid-p theme)
    (error "No valid theme named `%s'" theme))
  (cond ((not (eq major-mode 'custom-new-theme-mode))
	 (customize-create-theme theme))
	((y-or-n-p "Discard current changes? ")
	 (setq custom-theme--save-name theme)
	 (custom-theme-revert nil t))))

(defun custom-theme-merge-theme (theme)
  "Merge the custom theme THEME's settings into the current buffer."
  (interactive
   (list
    (intern (completing-read "Merge custom theme: "
			     (mapcar 'symbol-name
				     (custom-available-themes))))))
  (unless (eq theme 'user)
    (unless (custom-theme-name-valid-p theme)
      (error "Invalid theme name `%s'" theme))
    (load-theme theme t))
  (let ((settings (reverse (get theme 'theme-settings))))
    (dolist (setting settings)
      (funcall (if (eq (car setting) 'theme-value)
		   'custom-theme-add-variable
		 'custom-theme-add-face)
	       (nth 1 setting)
	       (nth 3 setting))))
  theme)

(defun custom-theme-write (&rest ignore)
  "Write the current custom theme to its theme file."
  (interactive)
  (let* ((name (widget-value custom-theme-name))
	 (doc (widget-value custom-theme-description))
	 (vars  custom-theme-variables)
	 (faces custom-theme-faces)
	 filename)
    (when (string-equal name "")
      (setq name (read-from-minibuffer "Theme name: " (user-login-name)))
      (widget-value-set custom-theme-name name))
    (unless (custom-theme-name-valid-p (intern name))
      (error "Custom themes cannot be named `%s'" name))

    (setq filename (expand-file-name (concat name "-theme.el")
				     custom-theme-directory))
    (and (file-exists-p filename)
	 (not (y-or-n-p (format "File %s exists.  Overwrite? " filename)))
	 (error "Aborted"))

    (with-temp-buffer
      (emacs-lisp-mode)
      (unless (file-directory-p custom-theme-directory)
	(make-directory (file-name-as-directory custom-theme-directory) t))
      (setq buffer-file-name filename)
      (erase-buffer)
      (insert "(deftheme " name)
      (if doc (insert "\n  \"" doc "\""))
      (insert  ")\n")
      (custom-theme-write-variables name vars)
      (custom-theme-write-faces name faces)
      (insert "\n(provide-theme '" name ")\n")
      (save-buffer))
    (dolist (var vars)
      (when (widget-get (cdr var) :children)
	(widget-put (cdr var) :custom-state 'saved)
	(custom-redraw-magic (cdr var))))
    (dolist (face custom-theme-faces)
      (when (widget-get (cdr face) :children)
	(widget-put (cdr face) :custom-state 'saved)
	(custom-redraw-magic (cdr face))))
    (message "Theme written to %s" filename)))

(defun custom-theme-write-variables (theme vars)
  "Write a `custom-theme-set-variables' command for THEME.
It includes all variables in list VARS."
  (when vars
    (let ((standard-output (current-buffer)))
      (princ "\n(custom-theme-set-variables\n")
      (princ " '")
      (princ theme)
      (princ "\n")
      (dolist (spec vars)
	(let* ((symbol (car spec))
	       (widget (cdr spec))
	       (child (car-safe (widget-get widget :children)))
	       (value (if child
			  (widget-value child)
			;; Child is null if the widget is closed (hidden).
			(car (widget-get widget :shown-value)))))
	  (when (boundp symbol)
	    (unless (bolp)
	      (princ "\n"))
	    (princ " '(")
	    (prin1 symbol)
	    (princ " ")
	    (prin1 (custom-quote value))
	    (princ ")"))))
      (if (bolp)
	  (princ " "))
      (princ ")")
      (unless (looking-at "\n")
	(princ "\n")))))

(defun custom-theme-write-faces (theme faces)
  "Write a `custom-theme-set-faces' command for THEME.
It includes all faces in list FACES."
  (when faces
    (let ((standard-output (current-buffer)))
      (princ "\n(custom-theme-set-faces\n")
      (princ " '")
      (princ theme)
      (princ "\n")
      (dolist (spec faces)
	(let* ((symbol (car spec))
	       (widget (cdr spec))
	       (value
		(if (car-safe (widget-get widget :children))
		    (custom-face-widget-to-spec widget)
		  ;; Child is null if the widget is closed (hidden).
		  (widget-get widget :shown-value))))
	  (when (and (facep symbol) value)
	    (princ (if (bolp) " '(" "\n '("))
	    (prin1 symbol)
	    (princ " ")
	    (prin1 value)
	    (princ ")"))))
      (if (bolp) (princ " "))
      (princ ")")
      (unless (looking-at "\n")
	(princ "\n")))))


;;; Describing Custom themes.

;;;###autoload
(defun describe-theme (theme)
  "Display a description of the Custom theme THEME (a symbol)."
  (interactive
   (list
    (intern (completing-read "Describe custom theme: "
			     (mapcar 'symbol-name
				     (custom-available-themes))))))
  (unless (custom-theme-name-valid-p theme)
    (error "Invalid theme name `%s'" theme))
  (help-setup-xref (list 'describe-theme theme)
		   (called-interactively-p 'interactive))
  (with-help-window (help-buffer)
    (with-current-buffer standard-output
      (describe-theme-1 theme))))

(defun describe-theme-1 (theme)
  (prin1 theme)
  (princ " is a custom theme")
  (let ((fn (locate-file (concat (symbol-name theme) "-theme.el")
			 (custom-theme--load-path)
			 '("" "c")))
	doc)
    (when fn
      (princ " in `")
      (help-insert-xref-button (file-name-nondirectory fn)
			       'help-theme-def fn)
      (princ "'"))
    (princ ".\n")
    (if (not (memq theme custom-known-themes))
	(progn
	  (princ "It is not loaded.")
	  ;; Attempt to grab the theme documentation
	  (when fn
	    (with-temp-buffer
	      (insert-file-contents fn)
	      (let ((sexp (let ((read-circle nil))
			    (condition-case nil
				(read (current-buffer))
			      (end-of-file nil)))))
		(and sexp (listp sexp)
		     (eq (car sexp) 'deftheme)
		     (setq doc (nth 2 sexp)))))))
      (if (custom-theme-enabled-p theme)
	  (princ "It is loaded and enabled.")
	(princ "It is loaded but disabled."))
      (setq doc (get theme 'theme-documentation)))

    (princ "\n\nDocumentation:\n")
    (princ (if (stringp doc)
	       doc
	     "No documentation available.")))
  (princ "\n\nYou can ")
  (help-insert-xref-button "customize" 'help-theme-edit theme)
  (princ " this theme."))


;;; Theme chooser

(defvar custom--listed-themes)

(defcustom custom-theme-allow-multiple-selections nil
  "Whether to allow multi-selections in the *Custom Themes* buffer."
  :type 'boolean
  :group 'custom-buffer)

(defvar custom-theme-choose-mode-map
  (let ((map (make-keymap)))
    (set-keymap-parent map widget-keymap)
    (suppress-keymap map)
    (define-key map "\C-x\C-s" 'custom-theme-save)
    (define-key map "n" 'widget-forward)
    (define-key map "p" 'widget-backward)
    (define-key map "?" 'custom-describe-theme)
    map)
  "Keymap for `custom-theme-choose-mode'.")

(define-derived-mode custom-theme-choose-mode nil "Themes"
  "Major mode for selecting Custom themes.
Do not call this mode function yourself.  It is meant for internal use."
  (use-local-map custom-theme-choose-mode-map)
  (custom--initialize-widget-variables)
  (set (make-local-variable 'revert-buffer-function)
       (lambda (ignore-auto noconfirm)
	 (when (or noconfirm (y-or-n-p "Discard current choices? "))
	   (customize-themes (current-buffer))))))
(put 'custom-theme-choose-mode 'mode-class 'special)

;;;###autoload
(defun customize-themes (&optional buffer)
  "Display a selectable list of Custom themes.
When called from Lisp, BUFFER should be the buffer to use; if
omitted, a buffer named *Custom Themes* is used."
  (interactive)
  (pop-to-buffer (get-buffer-create (or buffer "*Custom Themes*")))
  (let ((inhibit-read-only t))
    (erase-buffer))
  (custom-theme-choose-mode)
  (set (make-local-variable 'custom--listed-themes) nil)
  (make-local-variable 'custom-theme-allow-multiple-selections)
  (and (null custom-theme-allow-multiple-selections)
       (> (length custom-enabled-themes) 1)
       (setq custom-theme-allow-multiple-selections t))

  (widget-insert
   (substitute-command-keys
    "Type RET or click to enable/disable listed custom themes.
Type \\[custom-describe-theme] to describe the theme at point.
Theme files are named *-theme.el in `"))
  (widget-create 'link :value "custom-theme-load-path"
		 :button-face 'custom-link
		 :mouse-face 'highlight
		 :pressed-face 'highlight
		 :help-echo "Describe `custom-theme-load-path'."
		 :keymap custom-mode-link-map
		 :follow-link 'mouse-face
		 :action (lambda (widget &rest ignore)
			   (describe-variable 'custom-theme-load-path)))
  (widget-insert "'.\n\n")

  ;; If the user has made customizations, display a warning and
  ;; provide buttons to disable or convert them.
  (let ((user-settings (get 'user 'theme-settings)))
    (unless (or (null user-settings)
		(and (null (cdr user-settings))
		     (eq (caar user-settings) 'theme-value)
		     (eq (cadr (car user-settings)) 'custom-enabled-themes)))
      (widget-insert "Note: Your custom settings take precedence over theme settings.\n\n")
      ;; FIXME: Provide some way to painlessly disable or migrate
      ;; these settings.
      ))

  (widget-create 'push-button
		 :tag " Save Theme Settings "
		 :help-echo "Save the selected themes for future sessions."
		 :action 'custom-theme-save)
  (widget-insert ?\n)
  (widget-create 'checkbox
		 :value custom-theme-allow-multiple-selections
		 :action 'custom-theme-selections-toggle)
  (widget-insert (propertize " Allow more than one theme at a time"
			     'face '(variable-pitch (:height 0.9))))

  (widget-insert "\n\nAvailable Custom Themes:\n")
  (let (widget)
    (dolist (theme (custom-available-themes))
      (setq widget (widget-create 'checkbox
				  :value (custom-theme-enabled-p theme)
				  :theme-name theme
				  :action 'custom-theme-checkbox-toggle))
      (push (cons theme widget) custom--listed-themes)
      (widget-create-child-and-convert widget 'push-button
				       :button-face-get 'ignore
				       :mouse-face-get 'ignore
				       :value (format " %s" theme)
				       :action 'widget-parent-action)
      (widget-insert ?\n)))
  (goto-char (point-min))
  (widget-setup))

(defun custom-theme-checkbox-toggle (widget &optional event)
  (let ((this-theme (widget-get widget :theme-name)))
    (if (widget-value widget)
	;; Disable the theme.
	(disable-theme this-theme)
      ;; Enable the theme.
      (unless custom-theme-allow-multiple-selections
	;; If only one theme is allowed, disable all other themes and
	;; uncheck their boxes.
	(dolist (theme custom-enabled-themes)
	  (and (not (eq theme this-theme))
	       (assq theme custom--listed-themes)
	       (disable-theme theme)))
	(dolist (theme custom--listed-themes)
	  (unless (eq (car theme) this-theme)
	    (widget-value-set (cdr theme) nil)
	    (widget-apply (cdr theme) :notify (cdr theme) event))))
      (load-theme this-theme)))
  ;; Mark `custom-enabled-themes' as "set for current session".
  (put 'custom-enabled-themes 'customized-value
       (list (custom-quote custom-enabled-themes)))
  ;; Check/uncheck the widget.
  (widget-toggle-action widget event))

(defun custom-describe-theme ()
  "Describe the Custom theme on the current line."
  (interactive)
  (let ((widget (widget-at (line-beginning-position))))
    (and widget
	 (describe-theme (widget-get widget :theme-name)))))

(defun custom-theme-save (&rest ignore)
  (interactive)
  (customize-save-variable 'custom-enabled-themes custom-enabled-themes)
  (message "Custom themes saved for future sessions."))

(defun custom-theme-selections-toggle (widget &optional event)
  (when (widget-value widget)
    ;; Deactivate multiple-selections.
    (if (> (length (delq nil (mapcar (lambda (x) (widget-value (cdr x)))
				     custom--listed-themes)))
	   1)
	(error "More than one theme is currently selected")))
  (widget-toggle-action widget event)
  (setq custom-theme-allow-multiple-selections (widget-value widget)))

;; arch-tag: cd6919bc-63af-410e-bae2-b6702e762344
;;; cus-theme.el ends here
