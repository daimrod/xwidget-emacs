;;; viper-macs.el --- functions implementing keyboard macros for Viper

;; Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.

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

;; Code

(provide 'viper-macs)

;; compiler pacifier
(defvar vip-ex-work-buf)
(defvar vip-custom-file-name)
(defvar vip-current-state)
(defvar vip-fast-keyseq-timeout)

;; loading happens only in non-interactive compilation
;; in order to spare non-viperized emacs from being viperized
(if noninteractive
    (eval-when-compile
      (let ((load-path (cons (expand-file-name ".") load-path)))
	(or (featurep 'viper-util)
	    (load "viper-util.el" nil nil 'nosuffix))
	(or (featurep 'viper-keym)
	    (load "viper-keym.el" nil nil 'nosuffix))
	(or (featurep 'viper-mous)
	    (load "viper-mous.el" nil nil 'nosuffix))
	(or (featurep 'viper-cmd)
	    (load "viper-cmd.el" nil nil 'nosuffix))
	)))
;; end pacifier

(require 'viper-util)
(require 'viper-keym)


;;; Variables

;; Register holding last macro.
(defvar vip-last-macro-reg nil)

;; format of the elements of kbd alists: 
;; (name ((buf . macr)...(buf . macr)) ((maj-mode . macr)...) (t . macr))
;; kbd macro alist for Vi state
(defvar vip-vi-kbd-macro-alist nil)
;; same for insert/replace state
(defvar vip-insert-kbd-macro-alist nil)
;; same for emacs state
(defvar vip-emacs-kbd-macro-alist nil)

;; Internal var that passes info between start-kbd-macro and end-kbd-macro
;; in :map and :map!
(defvar vip-kbd-macro-parameters nil)

(defvar vip-this-kbd-macro nil
  "Vector of keys representing the name of currently running Viper kbd macro.")
(defvar vip-last-kbd-macro nil
  "Vector of keys representing the name of last Viper keyboard macro.")

(defcustom vip-repeat-from-history-key 'f12
  "Prefix key for accessing previously typed Vi commands.

The previous command is accessible, as usual, via `.'. The command before this
can be invoked as `<this key> 1', and the command before that, and the command
before that one is accessible as `<this key> 2'.
The notation for these keys is borrowed from XEmacs. Basically,
a key is a symbol, e.g., `a', `\\1', `f2', etc., or a list, e.g.,
`(meta control f1)'."
  :type 'key
  :group 'viper)



;;; Code

;; Ex map command
(defun ex-map ()
  (let ((mod-char "")
	macro-name macro-body map-args ins)
    (save-window-excursion
      (set-buffer vip-ex-work-buf)
      (if (looking-at "!")
	  (progn
	    (setq ins t
		  mod-char "!")
	    (forward-char 1))))
    (setq map-args (ex-map-read-args mod-char)
	  macro-name (car map-args)
	  macro-body (cdr map-args))
    (setq vip-kbd-macro-parameters (list ins mod-char macro-name macro-body))
    (if macro-body
	(vip-end-mapping-kbd-macro 'ignore)
      (ex-fixup-history (format "map%s %S" mod-char
				(vip-display-macro macro-name)))
      ;; if defining macro for insert, switch there for authentic WYSIWYG
      (if ins (vip-change-state-to-insert))
      (start-kbd-macro nil)
      (define-key vip-vi-intercept-map "\C-x)" 'vip-end-mapping-kbd-macro)
      (define-key vip-insert-intercept-map "\C-x)" 'vip-end-mapping-kbd-macro)
      (define-key vip-emacs-intercept-map "\C-x)" 'vip-end-mapping-kbd-macro)
      (message "Mapping %S in %s state. Hit `C-x )' to complete the mapping"
	       (vip-display-macro macro-name)
	       (if ins "Insert" "Vi")))
    ))
    

;; Ex unmap
(defun ex-unmap ()
  (let ((mod-char "")
	temp macro-name ins)
    (save-window-excursion
      (set-buffer vip-ex-work-buf)
      (if (looking-at "!")
	  (progn
	    (setq ins t
		  mod-char "!")
	    (forward-char 1))))

    (setq macro-name (ex-unmap-read-args mod-char))
    (setq temp (vip-fixup-macro (vconcat macro-name))) ;; copy and fixup
    (ex-fixup-history (format "unmap%s %S" mod-char
			      (vip-display-macro temp)))
    (vip-unrecord-kbd-macro macro-name (if ins 'insert-state 'vi-state))
    ))
    

;; read arguments for ex-map
(defun ex-map-read-args (variant)
  (let ((cursor-in-echo-area t)
	(key-seq [])
	temp key event message
	macro-name macro-body args)
	
    (condition-case nil
	(setq args (concat (ex-get-inline-cmd-args ".*map[!]*[ \t]?" "\n\C-m")
			   " nil nil ")
	      temp (read-from-string args)
	      macro-name (car temp)
	      macro-body (car (read-from-string args (cdr temp))))
      (error
       (signal
	'error 
	'("map: Macro name and body must be a quoted string or a vector"))))
    
    ;; We expect macro-name to be a vector, a string, or a quoted string.
    ;; In the second case, it will emerge as a symbol when read from
    ;; the above read-from-string. So we need to convert it into a string
    (if macro-name
        (cond ((vectorp macro-name) nil)
	      ((stringp macro-name) 
	       (setq macro-name (vconcat macro-name)))
	      (t (setq macro-name (vconcat (prin1-to-string macro-name)))))
      (message ":map%s <Name>" variant)(sit-for 2)
      (while
	  (not (member key
		       '(?\C-m ?\n (control m) (control j) return linefeed)))
	(setq key-seq (vconcat key-seq (if key (vector key) [])))
	;; the only keys available for editing are these-- no help while there
	(if (member
	     key
	     '(?\b ?\d '^? '^H (control h) (control \?) backspace delete))
	    (setq key-seq (subseq key-seq 0 (- (length key-seq) 2))))
	(setq message
	      (format
	       ":map%s %s"
	       variant (if (> (length key-seq) 0)
			   (prin1-to-string (vip-display-macro key-seq))
			 "")))
	(message message)
	(setq event (vip-read-key))
	;;(setq event (vip-read-event))
	(setq key
	      (if (vip-mouse-event-p event)
		  (progn
		    (message "%s (No mouse---only keyboard keys, please)"
			     message)
		    (sit-for 2)
		    nil)
		(vip-event-key event)))
	)
      (setq macro-name key-seq))
    
    (if (= (length macro-name) 0)
	(error "Can't map an empty macro name"))
    (setq macro-name (vip-fixup-macro macro-name))
    (if (vip-char-array-p macro-name)
	(setq macro-name (vip-char-array-to-macro macro-name)))
    
    (if macro-body
	(cond ((vip-char-array-p macro-body)
	       (setq macro-body (vip-char-array-to-macro macro-body)))
	      ((vectorp macro-body) nil)
	      (t (error "map: Invalid syntax in macro definition"))))
    (setq cursor-in-echo-area nil)(sit-for 0) ; this overcomes xemacs tty bug
    (cons macro-name macro-body)))
    


;; read arguments for ex-unmap
(defun ex-unmap-read-args (variant)
  (let ((cursor-in-echo-area t)
	(macro-alist (if (string= variant "!")
			 vip-insert-kbd-macro-alist
		       vip-vi-kbd-macro-alist))
	;; these are disabled just in case, to avoid surprises when doing
	;; completing-read
	vip-vi-kbd-minor-mode vip-insert-kbd-minor-mode
	vip-emacs-kbd-minor-mode
	vip-vi-intercept-minor-mode vip-insert-intercept-minor-mode
	vip-emacs-intercept-minor-mode
	event message
	key key-seq macro-name)
    (setq macro-name (ex-get-inline-cmd-args ".*unma?p?[!]*[ \t]*"))
	  
    (if (> (length macro-name) 0)
	()
      (message ":unmap%s <Name>" variant) (sit-for 2)
      (while
	  (not
	   (member key '(?\C-m ?\n (control m) (control j) return linefeed)))
	(setq key-seq (vconcat key-seq (if key (vector key) [])))
	;; the only keys available for editing are these-- no help while there
	(cond ((member
		key
		'(?\b ?\d '^? '^H (control h) (control \?) backspace delete))
	       (setq key-seq (subseq key-seq 0 (- (length key-seq) 2))))
	      ((member key '(tab (control i) ?\t))
	       (setq key-seq (subseq key-seq 0 (1- (length key-seq))))
	       (setq message 
		     (format
		      ":unmap%s %s"
		      variant (if (> (length key-seq) 0)
				  (prin1-to-string
				   (vip-display-macro key-seq))
				"")))
	       (setq key-seq
		     (vip-do-sequence-completion key-seq macro-alist message))
	       ))
	(setq message 
	      (format
	       ":unmap%s %s"
	       variant (if (> (length key-seq) 0)
			   (prin1-to-string
			    (vip-display-macro key-seq))
			 "")))
	(message message)
	(setq event (vip-read-key))
	;;(setq event (vip-read-event))
	(setq key
	      (if (vip-mouse-event-p event)
		  (progn
		    (message "%s (No mouse---only keyboard keys, please)"
			     message)
		    (sit-for 2)
		    nil)
		(vip-event-key event)))
	)
      (setq macro-name key-seq))

    (if (= (length macro-name) 0)
	(error "Can't unmap an empty macro name"))
				  
    ;; convert macro names into vector, if starts with a `['
    (if (memq (elt macro-name 0) '(?\[ ?\"))
	(car (read-from-string macro-name))
      (vconcat macro-name))
    ))
    
    
;; Terminate a Vi kbd macro.
;; optional argument IGNORE, if t, indicates that we are dealing with an
;; existing macro that needs to be registered, but there is no need to
;; terminate a kbd macro.
(defun vip-end-mapping-kbd-macro (&optional ignore)
  (interactive)
  (define-key vip-vi-intercept-map "\C-x)" nil)
  (define-key vip-insert-intercept-map "\C-x)" nil)
  (define-key vip-emacs-intercept-map "\C-x)" nil)
  (if (and (not ignore)
	   (or (not vip-kbd-macro-parameters)
	       (not defining-kbd-macro)))
      (error "Not mapping a kbd-macro"))
  (let ((mod-char (nth 1 vip-kbd-macro-parameters))
	(ins (nth 0 vip-kbd-macro-parameters))
	(macro-name (nth 2 vip-kbd-macro-parameters))
	(macro-body (nth 3 vip-kbd-macro-parameters)))
    (setq vip-kbd-macro-parameters nil)
    (or ignore
	(progn
	  (end-kbd-macro nil)
	  (setq macro-body (vip-events-to-macro last-kbd-macro))
	  ;; always go back to Vi, since this is where we started
	  ;; defining macro
	  (vip-change-state-to-vi)))
    
    (vip-record-kbd-macro macro-name
			  (if ins 'insert-state 'vi-state)
			  (vip-display-macro macro-body))
    
    (ex-fixup-history (format "map%s %S %S" mod-char
			      (vip-display-macro macro-name)
			      (vip-display-macro macro-body)))
    ))




;;; Recording, unrecording, executing

;; accepts as macro names: strings and vectors.
;; strings must be strings of characters; vectors must be vectors of keys
;; in canonic form. the canonic form is essentially the form used in XEmacs
(defun vip-record-kbd-macro (macro-name state macro-body &optional scope)
  "Record a Vi macro. Can be used in `.vip' file to define permanent macros.
MACRO-NAME is a string of characters or a vector of keys. STATE is
either `vi-state' or `insert-state'. It specifies the Viper state in which to
define the macro. MACRO-BODY is a string that represents the keyboard macro.
Optional SCOPE says whether the macro should be global \(t\), mode-specific
\(a major-mode symbol\), or buffer-specific \(buffer name, a string\).
If SCOPE is nil, the user is asked to specify the scope."
  (let* (state-name keymap 
	 (macro-alist-var
	  (cond ((eq state 'vi-state)
		 (setq state-name "Vi state"
		       keymap vip-vi-kbd-map)
		 'vip-vi-kbd-macro-alist)
		((memq state '(insert-state replace-state))
		 (setq state-name "Insert state"
		       keymap vip-insert-kbd-map)
		 'vip-insert-kbd-macro-alist)
		(t
		 (setq state-name "Emacs state"
		       keymap vip-emacs-kbd-map)
		 'vip-emacs-kbd-macro-alist)
		 ))
	 new-elt old-elt old-sub-elt msg
	 temp lis lis2)
	 
    (if (= (length macro-name) 0)
	(error "Can't map an empty macro name"))
	
    ;; Macro-name is usually a vector. However, command history or macros
    ;; recorded in ~/.vip may be recorded as strings. So, convert to vectors.
    (setq macro-name (vip-fixup-macro macro-name))
    (if (vip-char-array-p macro-name)
	(setq macro-name (vip-char-array-to-macro macro-name)))
    (setq macro-body (vip-fixup-macro macro-body))
    (if (vip-char-array-p macro-body)
	(setq macro-body (vip-char-array-to-macro macro-body)))
	
    ;; don't ask if scope is given and is of the right type
    (or (eq scope t)
	(stringp scope)
	(and scope (symbolp scope))
	(progn
	  (setq scope
		(cond
		 ((y-or-n-p
		   (format
		    "Map this macro for buffer `%s' only? "
		    (buffer-name)))
		  (setq msg
			(format
			 "%S is mapped to %s for %s in `%s'"
			 (vip-display-macro macro-name)
			 (vip-abbreviate-string
			  (format
			   "%S"
			   (setq temp (vip-display-macro macro-body)))
			  14 "" ""
			  (if (stringp temp) "  ....\"" "  ....]"))
			 state-name (buffer-name)))
		  (buffer-name))
		 ((y-or-n-p
		   (format
		    "Map this macro for the major mode `%S' only? "
		    major-mode))
		  (setq msg
			(format
			 "%S is mapped to %s for %s in `%S'"
			 (vip-display-macro macro-name)
			 (vip-abbreviate-string
			  (format
			   "%S"
			   (setq temp (vip-display-macro macro-body)))
			  14 "" ""
			  (if (stringp macro-body) "  ....\"" "  ....]"))
			 state-name major-mode))
		  major-mode)
		 (t
		  (setq msg
			(format
			 "%S is globally mapped to %s in %s"
			 (vip-display-macro macro-name)
			 (vip-abbreviate-string
			  (format
			   "%S"
			   (setq temp (vip-display-macro macro-body)))
			  14 "" ""
			  (if (stringp macro-body) "  ....\"" "  ....]"))
			 state-name))
		  t)))
	  (if (y-or-n-p
	       (format "Save this macro in %s? "
		       (vip-abbreviate-file-name vip-custom-file-name)))
	      (vip-save-string-in-file 
	       (format "\n(vip-record-kbd-macro %S '%S %s '%S)"
		       (vip-display-macro macro-name)
		       state
		       ;; if we don't let vector macro-body through %S,
		       ;; the symbols `\.' `\[' etc will be converted into
		       ;; characters, causing invalid read  error on recorded
		       ;; macros in .vip.
		       ;; I am not sure is macro-body can still be a string at
		       ;; this point, but I am preserving this option anyway.
		       (if (vectorp macro-body)
			   (format "%S" macro-body)
			 macro-body)
		       scope) 
	       vip-custom-file-name))
	  
	  (message msg)
	  ))
	
    (setq new-elt
	  (cons macro-name
		(cond ((eq scope t) (list nil nil (cons t nil)))
		      ((symbolp scope)
		       (list nil (list (cons scope nil)) (cons t nil)))
		      ((stringp scope)
		       (list (list (cons scope nil)) nil (cons t nil))))))
    (setq old-elt (assoc macro-name (eval macro-alist-var)))

      (if (null old-elt)
	  (progn
	    ;; insert new-elt in macro-alist-var and keep the list sorted
	    (define-key
	      keymap
	      (vector (vip-key-to-emacs-key (aref macro-name 0)))
	      'vip-exec-mapped-kbd-macro)
	    (setq lis (eval macro-alist-var))
	    (while (and lis (string< (vip-array-to-string (car (car lis)))
				     (vip-array-to-string macro-name)))
	      (setq lis2 (cons (car lis) lis2))
	      (setq lis (cdr lis)))
	    
	    (setq lis2 (reverse lis2))
	    (set macro-alist-var (append lis2 (cons new-elt lis)))
	    (setq old-elt new-elt)))
    (setq old-sub-elt
	  (cond ((eq scope t) (vip-kbd-global-pair old-elt))
		((symbolp scope) (assoc scope (vip-kbd-mode-alist old-elt)))
		((stringp scope) (assoc scope (vip-kbd-buf-alist old-elt)))))
    (if old-sub-elt 
	(setcdr old-sub-elt macro-body)
      (cond ((symbolp scope) (setcar (cdr (cdr old-elt))
				     (cons (cons scope macro-body)
					   (vip-kbd-mode-alist old-elt))))
	    ((stringp scope) (setcar (cdr old-elt)
				     (cons (cons scope macro-body)
					   (vip-kbd-buf-alist old-elt))))))
    ))
  

    
;; macro name must be a vector of vip-style keys
(defun vip-unrecord-kbd-macro (macro-name state)
  "Delete macro MACRO-NAME from Viper STATE.
MACRO-NAME must be a vector of vip-style keys. This command is used by Viper
internally, but the user can also use it in ~/.vip to delete pre-defined macros
supplied with Viper. The best way to avoid mistakes in macro names to be passed
to this function is to use vip-describe-kbd-macros and copy the name from
there."
  (let* (state-name keymap 
	 (macro-alist-var
	  (cond ((eq state 'vi-state)
		 (setq state-name "Vi state"
		       keymap vip-vi-kbd-map)
		 'vip-vi-kbd-macro-alist)
		((memq state '(insert-state replace-state))
		 (setq state-name "Insert state"
		       keymap vip-insert-kbd-map)
		 'vip-insert-kbd-macro-alist)
		(t
		 (setq state-name "Emacs state"
		       keymap vip-emacs-kbd-map)
		 'vip-emacs-kbd-macro-alist)
		))
	 buf-mapping mode-mapping global-mapping
	 macro-pair macro-entry)
	 	
    ;; Macro-name is usually a vector. However, command history or macros
    ;; recorded in ~/.vip may appear as strings. So, convert to vectors.
    (setq macro-name (vip-fixup-macro macro-name))
    (if (vip-char-array-p macro-name)
	(setq macro-name (vip-char-array-to-macro macro-name)))

    (setq macro-entry (assoc macro-name (eval macro-alist-var)))
    (if (= (length macro-name) 0)
	(error "Can't unmap an empty macro name"))
    (if (null macro-entry)
	(error "%S is not mapped to a macro for %s in `%s'"
	       (vip-display-macro macro-name)
	       state-name (buffer-name)))
	
    (setq buf-mapping (vip-kbd-buf-pair macro-entry)
	  mode-mapping (vip-kbd-mode-pair macro-entry)
	  global-mapping (vip-kbd-global-pair macro-entry))
	
    (cond ((and (cdr buf-mapping)
		(or (and (not (cdr mode-mapping)) (not (cdr global-mapping)))
		    (y-or-n-p
		     (format "Unmap %S for `%s' only? "
			     (vip-display-macro macro-name)
			     (buffer-name)))))
	   (setq macro-pair buf-mapping)
	   (message "%S is unmapped for %s in `%s'" 
		    (vip-display-macro macro-name)
		    state-name (buffer-name)))
	  ((and (cdr mode-mapping)
		(or (not (cdr global-mapping))
		    (y-or-n-p
		     (format "Unmap %S for the major mode `%S' only? "
			     (vip-display-macro macro-name)
			     major-mode))))
	   (setq macro-pair mode-mapping)
	   (message "%S is unmapped for %s in %S"
		    (vip-display-macro macro-name) state-name major-mode))
	  ((cdr (setq macro-pair (vip-kbd-global-pair macro-entry)))
	   (message
	    "Global mapping for %S in %s is removed"
	    (vip-display-macro macro-name) state-name))
	  (t (error "%S is not mapped to a macro for %s in `%s'"
		    (vip-display-macro macro-name)
		    state-name (buffer-name))))
    (setcdr macro-pair nil)
    (or (cdr buf-mapping)
	(cdr mode-mapping)
	(cdr global-mapping)
	(progn
	  (set macro-alist-var (delq macro-entry (eval macro-alist-var)))
	  (if (vip-can-release-key (aref macro-name 0) 
				   (eval macro-alist-var))
	      (define-key
		keymap
		(vector (vip-key-to-emacs-key (aref macro-name 0)))
		nil))
	  ))
    ))
    
;; Check if MACRO-ALIST has an entry for a macro name starting with
;; CHAR. If not, this indicates that the binding for this char
;; in vip-vi/insert-kbd-map can be released.
(defun vip-can-release-key (char macro-alist)
  (let ((lis macro-alist)
	(can-release t)
	macro-name)
    
    (while (and lis can-release)
      (setq macro-name (car (car lis)))
      (if (eq char (aref macro-name 0))
	  (setq can-release nil))
      (setq lis (cdr lis)))
    can-release))


(defun vip-exec-mapped-kbd-macro (count)
  "Dispatch kbd macro."
  (interactive "P")
  (let* ((macro-alist (cond ((eq vip-current-state 'vi-state)
			     vip-vi-kbd-macro-alist)
			    ((memq vip-current-state
				   '(insert-state replace-state))
			     vip-insert-kbd-macro-alist)
			    (t
			     vip-emacs-kbd-macro-alist)))
	(unmatched-suffix "")
	;; Macros and keys are executed with other macros turned off
	;; For macros, this is done to avoid macro recursion
	vip-vi-kbd-minor-mode vip-insert-kbd-minor-mode
	vip-emacs-kbd-minor-mode
	next-best-match keyseq event-seq
	macro-first-char macro-alist-elt macro-body
	command)
    
    (setq macro-first-char last-command-event
	  event-seq (vip-read-fast-keysequence macro-first-char macro-alist)
	  keyseq (vip-events-to-macro event-seq)
	  macro-alist-elt (assoc keyseq macro-alist)
	  next-best-match (vip-find-best-matching-macro macro-alist keyseq))
	  
    (if (null macro-alist-elt)
	(setq macro-alist-elt (car next-best-match)
	      unmatched-suffix (subseq event-seq (cdr next-best-match))))

    (cond ((null macro-alist-elt))
	  ((setq macro-body (vip-kbd-buf-definition macro-alist-elt)))
	  ((setq macro-body (vip-kbd-mode-definition macro-alist-elt)))
	  ((setq macro-body (vip-kbd-global-definition macro-alist-elt))))
				 
    ;; when defining keyboard macro, don't use the macro mappings
    (if (and macro-body (not defining-kbd-macro))
	;; block cmd executed as part of a macro from entering command history
	(let ((command-history command-history))
	  (setq vip-this-kbd-macro (car macro-alist-elt))
	  (execute-kbd-macro (vip-macro-to-events macro-body) count)
	  (setq vip-this-kbd-macro nil
		vip-last-kbd-macro (car macro-alist-elt))
	  (vip-set-unread-command-events unmatched-suffix))
      ;; If not a macro, or the macro is suppressed while defining another
      ;; macro, put keyseq back on the event queue
      (vip-set-unread-command-events event-seq)
      ;; if the user typed arg, then use it if prefix arg is not set by
      ;; some other command (setting prefix arg can happen if we do, say,
      ;; 2dw and there is a macro starting with 2. Then control will go to
      ;; this routine
      (or prefix-arg (setq  prefix-arg count)) 
      (setq command (key-binding (read-key-sequence nil)))
      (if (commandp command)
	  (command-execute command)
	(beep 1)))
    ))



;;; Displaying and completing macros
    
(defun vip-describe-kbd-macros ()
  "Show currently defined keyboard macros."
  (interactive)
  (with-output-to-temp-buffer " *vip-info*"
    (princ "Macros in Vi state:\n===================\n")
    (mapcar 'vip-describe-one-macro vip-vi-kbd-macro-alist)
    (princ "\n\nMacros in Insert and Replace states:\n====================================\n")
    (mapcar 'vip-describe-one-macro vip-insert-kbd-macro-alist)
    (princ "\n\nMacros in Emacs state:\n======================\n")
    (mapcar 'vip-describe-one-macro vip-emacs-kbd-macro-alist)
    ))
    
(defun vip-describe-one-macro (macro)
  (princ (format "\n  *** Mappings for %S:\n      ------------\n"
		 (vip-display-macro (car macro))))
  (princ "   ** Buffer-specific:")
  (if (vip-kbd-buf-alist macro)
      (mapcar 'vip-describe-one-macro-elt (vip-kbd-buf-alist macro))
    (princ "  none\n"))
  (princ "\n   ** Mode-specific:")
  (if (vip-kbd-mode-alist macro)
      (mapcar 'vip-describe-one-macro-elt (vip-kbd-mode-alist macro))
    (princ "  none\n"))
  (princ "\n   ** Global:")
  (if (vip-kbd-global-definition macro)
      (princ (format "\n           %S" (cdr (vip-kbd-global-pair macro))))
    (princ "  none"))
  (princ "\n"))
  
(defun vip-describe-one-macro-elt (elt)
  (let ((name (car elt))
	(defn (cdr elt)))
    (princ (format "\n       * %S:\n           %S\n" name defn))))
    
    
    
;; check if SEQ is a prefix of some car of an element in ALIST
(defun vip-keyseq-is-a-possible-macro (seq alist)
  (let ((converted-seq (vip-events-to-macro seq)))
    (eval (cons 'or 
		(mapcar
		 (function (lambda (elt)
			     (vip-prefix-subseq-p converted-seq elt)))
		 (vip-this-buffer-macros alist))))))
		 
;; whether SEQ1 is a prefix of SEQ2
(defun vip-prefix-subseq-p (seq1 seq2)
  (let ((len1 (length seq1))
	(len2 (length seq2)))
    (if (<= len1 len2)
	(equal seq1 (subseq seq2 0 len1)))))
	
;; find the longest common prefix
(defun vip-common-seq-prefix (&rest seqs)
  (let* ((first (car seqs))
	 (rest (cdr seqs))
	 (pref [])
	 (idx 0)
	 len)
    (if (= (length seqs) 0)
	(setq len 0)
      (setq len (apply 'min (mapcar 'length seqs))))
    (while (< idx len)
      (if (eval (cons 'and 
		      (mapcar (function (lambda (s)
					  (equal (elt first idx)
						 (elt s idx))))
			      rest)))
	  (setq pref (vconcat pref (vector (elt first idx)))))
      (setq idx (1+ idx)))
    pref))
    
;; get all sequences that match PREFIX from a given A-LIST
(defun vip-extract-matching-alist-members (pref alist)
  (delq nil (mapcar (function (lambda (elt)
				(if (vip-prefix-subseq-p pref elt)
				    elt)))
		    (vip-this-buffer-macros alist))))
		    
(defun vip-do-sequence-completion (seq alist compl-message)
  (let* ((matches (vip-extract-matching-alist-members seq alist))
	 (new-seq (apply 'vip-common-seq-prefix matches))
	 )
    (cond ((and (equal seq new-seq) (= (length matches) 1))
	   (message "%s (Sole completion)" compl-message)
	   (sit-for 2))
	  ((null matches) 
	   (message "%s (No match)" compl-message)
	   (sit-for 2)
	   (setq new-seq seq))
	  ((member seq matches) 
	   (message "%s (Complete, but not unique)" compl-message)
	   (sit-for 2)
	   (vip-display-vector-completions matches))
	  ((equal seq new-seq)
	   (vip-display-vector-completions matches)))
    new-seq))
	
	 
(defun vip-display-vector-completions (list)
  (with-output-to-temp-buffer "*Completions*"
    (display-completion-list 
     (mapcar 'prin1-to-string
	     (mapcar 'vip-display-macro list)))))
  
				  
    
;; alist is the alist of macros
;; str is the fast key sequence entered
;; returns: (matching-macro-def . unmatched-suffix-start-index)
(defun vip-find-best-matching-macro (alist str)
  (let ((lis alist)
	(def-len 0)
	(str-len (length str))
	match unmatched-start-idx found macro-def)
    (while (and (not found) lis)
      (setq macro-def (car lis)
	    def-len (length (car macro-def)))
      (if (and (>= str-len def-len)
	       (equal (car macro-def) (subseq str 0 def-len)))
	  (if (or (vip-kbd-buf-definition macro-def)
		  (vip-kbd-mode-definition macro-def)
		  (vip-kbd-global-definition macro-def))
	      (setq found t))
	)
      (setq lis (cdr lis)))
    
    (if found
	(setq match macro-def
	      unmatched-start-idx def-len)
      (setq match nil
	    unmatched-start-idx 0))
    
    (cons match unmatched-start-idx)))
  
    
    
;; returns a list of names of macros defined for the current buffer
(defun vip-this-buffer-macros (macro-alist)
  (let (candidates)
    (setq candidates
	  (mapcar (function
		   (lambda (elt)
		     (if (or (vip-kbd-buf-definition elt)
			     (vip-kbd-mode-definition elt)
			     (vip-kbd-global-definition elt))
			 (car elt))))
		  macro-alist))
    (setq candidates (delq nil candidates))))
    
  
;; if seq of Viper key symbols (representing a macro) can be converted to a
;; string--do so. Otherwise, do nothing.
(defun vip-display-macro (macro-name-or-body)
  (cond ((vip-char-symbol-sequence-p macro-name-or-body)
	 (mapconcat 'symbol-name macro-name-or-body ""))
	((vip-char-array-p macro-name-or-body)
	 (mapconcat 'char-to-string macro-name-or-body ""))
	(t macro-name-or-body)))
    
;; convert sequence of events (that came presumably from emacs kbd macro) into
;; Viper's macro, which is a vector of the form
;; [ desc desc ... ]
;; Each desc is either a symbol of (meta symb), (shift symb), etc.
;; Here we purge events that happen to be lists. In most cases, these events
;; got into a macro definition unintentionally; say, when the user moves mouse
;; during a macro definition, then something like (switch-frame ...) might get
;; in. Another reason for purging lists-events is that we can't store them in
;; textual form (say, in .emacs) and then read them back.
(defun vip-events-to-macro (event-seq)
  (vconcat (delq nil (mapcar (function (lambda (elt)
					 (if (consp elt)
					     nil
					   (vip-event-key elt))))
			     event-seq))))
  
;; convert strings or arrays of characters to Viper macro form
(defun vip-char-array-to-macro (array)
  (let ((vec (vconcat array))
	macro)
    (if vip-xemacs-p
	(setq macro (mapcar 'character-to-event vec))
      (setq macro vec))
    (vconcat (mapcar 'vip-event-key macro))))
    
;; For macros bodies and names, goes over MACRO and checks if all members are
;; names of keys (actually, it only checks if they are symbols or lists
;; if a digit is found, it is converted into a symbol (e.g., 0 -> \0, etc).
;; If MACRO is not a list or vector -- doesn't change MACRO.
(defun vip-fixup-macro (macro)
  (let ((len (length macro))
	(idx 0)
	elt break)
    (if (or (vectorp macro) (listp macro))
	(while (and (< idx len) (not break))
	  (setq elt (elt macro idx))
	  (cond ((numberp elt)
		 ;; fix number
		 (if (and (<= 0 elt) (<= elt 9))
		     (cond ((arrayp macro)
			    (aset macro
				  idx
				  (intern (char-to-string (+ ?0 elt)))))
			   ((listp macro)
			    (setcar (nthcdr idx macro)
				    (intern (char-to-string (+ ?0 elt)))))
			   )))
		((listp elt)
		 (vip-fixup-macro elt))
		((symbolp elt) nil)
		(t (setq break t)))
	  (setq idx (1+ idx))))
      
      (if break
	  (error "Wrong type macro component, symbol-or-listp, %S" elt)
	macro)))
  
(defun vip-char-array-p (array)
  (eval (cons 'and (mapcar 'vip-characterp array))))
  
(defun vip-macro-to-events (macro-body)
  (vconcat (mapcar 'vip-key-to-emacs-key macro-body)))
	    
			 
;; check if vec is a vector of character symbols
(defun vip-char-symbol-sequence-p (vec)
  (and
   (sequencep vec)
   (eval
    (cons 'and
	  (mapcar
	   (function (lambda (elt)
		       (and (symbolp elt) (= (length (symbol-name elt)) 1))))
	   vec)))))
	       

;; Check if vec is a vector of key-press events representing characters
;; XEmacs only
(defun vip-event-vector-p (vec)
  (and (vectorp vec)
       (eval (cons 'and (mapcar '(lambda (elt) (if (eventp elt) t)) vec)))))
    

;;; Reading fast key sequences
    
;; Assuming that CHAR was the first character in a fast succession of key
;; strokes, read the rest. Return the vector of keys that was entered in
;; this fast succession of key strokes.
;; A fast keysequence is one that is terminated by a pause longer than
;; vip-fast-keyseq-timeout.
(defun vip-read-fast-keysequence (event macro-alist)
  (let ((lis (vector event))
	next-event)
    (while (and (vip-fast-keysequence-p)
		(vip-keyseq-is-a-possible-macro lis macro-alist))
      (setq next-event (vip-read-key))
      ;;(setq next-event (vip-read-event))
      (or (vip-mouse-event-p next-event)
	  (setq lis (vconcat lis (vector next-event)))))
    lis))


;;; Keyboard macros in registers

;; sets register to last-kbd-macro carefully.
(defun vip-set-register-macro (reg)
  (if (get-register reg)
      (if (y-or-n-p "Register contains data. Overwrite? ")
	  ()
	(error
	 "Macro not saved in register. Can still be invoked via `C-x e'")))
  (set-register reg last-kbd-macro))

(defun vip-register-macro (count)
  "Keyboard macros in registers - a modified \@ command."
  (interactive "P")
  (let ((reg (downcase (read-char))))
    (cond ((or (and (<= ?a reg) (<= reg ?z)))
	   (setq vip-last-macro-reg reg)
	   (if defining-kbd-macro
	       (progn
		 (end-kbd-macro)
		 (vip-set-register-macro reg))
	     (execute-kbd-macro (get-register reg) count)))
	  ((or (= ?@ reg) (= ?\^j reg) (= ?\^m reg))
	   (if vip-last-macro-reg 
	       nil
	       (error "No previous kbd macro"))
	   (execute-kbd-macro (get-register vip-last-macro-reg) count))
	  ((= ?\# reg)
	   (start-kbd-macro count))
	  ((= ?! reg)
	   (setq reg (downcase (read-char)))
	   (if (or (and (<= ?a reg) (<= reg ?z)))
	       (progn
	       (setq vip-last-macro-reg reg)
	       (vip-set-register-macro reg))))
	  (t
	   (error "`%c': Unknown register" reg)))))
	   

(defun vip-global-execute ()
  "Call last keyboad macro for each line in the region."
  (if (> (point) (mark t)) (exchange-point-and-mark))
  (beginning-of-line)
  (call-last-kbd-macro)
  (while (< (point) (mark t))
    (forward-line 1)
    (beginning-of-line)
    (call-last-kbd-macro)))


;;;  viper-macs.el ends here
