;;; vc-svn.el --- non-resident support for Subversion version-control

;; Copyright (C) 1995,98,99,2000,2001,2002  Free Software Foundation, Inc.

;; Author:      FSF (see vc.el for full credits)
;; Maintainer:  Stefan Monnier <monnier@gnu.org>

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

;; This is preliminary support for Subversion (http://subversion.tigris.org/).
;; It started as `sed s/cvs/svn/ vc.cvs.el' (from version 1.56)
;; and hasn't been completely fixed since.

;; Sync'd with Subversion's vc-svn.el as of revision 5801.

;;; Bugs:

;; - VC-dired is either not working or (really) dog slow.
;; - vc-print-log does not always jump to the proper log entry because
;;   it tries to jump to version 1234 even if there's only an entry
;;   for 1232 (because the file hasn't changed since).

;;; Code:

(eval-when-compile
  (require 'vc))

;;;
;;; Customization options
;;;

(defcustom vc-svn-global-switches nil
  "*Global switches to pass to any SVN command."
  :type '(choice (const :tag "None" nil)
		 (string :tag "Argument String")
		 (repeat :tag "Argument List"
			 :value ("")
			 string))
  :version "21.4"
  :group 'vc)

(defcustom vc-svn-register-switches nil
  "*Extra switches for registering a file into SVN.
A string or list of strings passed to the checkin program by
\\[vc-register]."
  :type '(choice (const :tag "None" nil)
		 (string :tag "Argument String")
		 (repeat :tag "Argument List"
			 :value ("")
			 string))
  :version "21.1"
  :group 'vc)

(defcustom vc-svn-diff-switches nil
  "*A string or list of strings specifying extra switches for svn diff under VC."
    :type '(choice (const :tag "None" nil)
		 (string :tag "Argument String")
		 (repeat :tag "Argument List"
			 :value ("")
			 string))
  :version "21.1"
  :group 'vc)

(defcustom vc-svn-header (or (cdr (assoc 'SVN vc-header-alist)) '("\$Id\$"))
  "*Header keywords to be inserted by `vc-insert-headers'."
  :version "21.1"
  :type '(repeat string)
  :group 'vc)

(defcustom vc-svn-use-edit nil
  "*Non-nil means to use `svn edit' to \"check out\" a file.
This is only meaningful if you don't use the implicit checkout model
\(i.e. if you have $SVNREAD set)."
  :type 'boolean
  :version "21.1"
  :group 'vc)

(defcustom vc-svn-stay-local t
  "*Non-nil means use local operations when possible for remote repositories.
This avoids slow queries over the network and instead uses heuristics
and past information to determine the current status of a file.

The value can also be a regular expression or list of regular
expressions to match against the host name of a repository; then VC
only stays local for hosts that match it.  Alternatively, the value
can be a list of regular expressions where the first element is the 
symbol `except'; then VC always stays local except for hosts matched 
by these regular expressions."
  :type '(choice (const :tag "Always stay local" t)
                (const :tag "Don't stay local" nil)
                 (list :format "\nExamine hostname and %v" :tag "Examine hostname ..." 
                       (set :format "%v" :inline t (const :format "%t" :tag "don't" except))
                       (regexp :format " stay local,\n%t: %v" :tag "if it matches")
                       (repeat :format "%v%i\n" :inline t (regexp :tag "or"))))
  :version "21.1"
  :group 'vc)

;;;
;;; State-querying functions
;;;

;;;###autoload (defun vc-svn-registered (f)
;;;###autoload   (when (file-readable-p (expand-file-name
;;;###autoload 			  ".svn/entries" (file-name-directory f)))
;;;###autoload       (load "vc-svn")
;;;###autoload       (vc-svn-registered f)))

(defun vc-svn-registered (file)
  "Check if FILE is SVN registered."
  (when (file-readable-p (expand-file-name ".svn/entries"
					   (file-name-directory file)))
    (with-temp-buffer
      (cd (file-name-directory file))
      (condition-case nil
	  (vc-svn-command t 0 file "status" "-v")
	;; We can't find an `svn' executable.  We could also deregister SVN.
	(file-error nil))
      (vc-svn-parse-status t)
      (eq 'SVN (vc-file-getprop file 'vc-backend)))))

(defun vc-svn-state (file &optional localp)
  "SVN-specific version of `vc-state'."
  (setq localp (or localp (vc-svn-stay-local-p file)))
  (with-temp-buffer
    (cd (file-name-directory file))
    (vc-svn-command t 0 file "status" (if localp "-v" "-u"))
    (vc-svn-parse-status localp)
    (vc-file-getprop file 'vc-state)))

(defun vc-svn-state-heuristic (file)
  "SVN-specific state heuristic."
  (vc-svn-state file 'local))

(defun vc-svn-dir-state (dir &optional localp)
  "Find the SVN state of all files in DIR."
  (setq localp (or localp (vc-svn-stay-local-p dir)))
  (let ((default-directory dir))
    ;; Don't specify DIR in this command, the default-directory is
    ;; enough.  Otherwise it might fail with remote repositories.
    (with-temp-buffer
      (vc-svn-command t 0 nil "status" (if localp "-v" "-u"))
      (vc-svn-parse-status localp))))

(defun vc-svn-workfile-version (file)
  "SVN-specific version of `vc-workfile-version'."
  ;; There is no need to consult RCS headers under SVN, because we
  ;; get the workfile version for free when we recognize that a file
  ;; is registered in SVN.
  (vc-svn-registered file)
  (vc-file-getprop file 'vc-workfile-version))

(defun vc-svn-checkout-model (file)
  "SVN-specific version of `vc-checkout-model'."
  ;; It looks like Subversion has no equivalent of CVSREAD.
  'implicit)

(defun vc-svn-mode-line-string (file)
  "Return string for placement into the modeline for FILE.
Compared to the default implementation, this function does two things:
Handle the special case of a SVN file that is added but not yet
committed and support display of sticky tags."
  (let* ((state   (vc-state file))
	 (rev     (vc-workfile-version file))
	 (sticky-tag (vc-file-getprop file 'vc-svn-sticky-tag))
 	 (sticky-tag-printable (and sticky-tag
				    (not (string= sticky-tag ""))
 				    (concat "[" sticky-tag "]"))))
    (cond ((string= rev "0")
	   ;; A file that is added but not yet committed.
	   "SVN @@")
	  ((or (eq state 'up-to-date)
	       (eq state 'needs-patch))
	   (concat "SVN-" rev sticky-tag-printable))
          ((stringp state)
	   (concat "SVN:" state ":" rev sticky-tag-printable))
          (t
           ;; Not just for the 'edited state, but also a fallback
           ;; for all other states.  Think about different symbols
           ;; for 'needs-patch and 'needs-merge.
           (concat "SVN:" rev sticky-tag-printable)))))

(defun vc-svn-dired-state-info (file)
  "SVN-specific version of `vc-dired-state-info'."
  (let* ((svn-state (vc-state file))
	 (state (cond ((eq svn-state 'edited)	"modified")
		      ((eq svn-state 'needs-patch)	"patch")
		      ((eq svn-state 'needs-merge)	"merge")
		      ;; FIXME: those two states cannot occur right now
		      ((eq svn-state 'unlocked-changes)	"conflict")
		      ((eq svn-state 'locally-added)	"added")
		      )))
    (if state (concat "(" state ")"))))


;;;
;;; State-changing functions
;;;

(defun vc-svn-register (file &optional rev comment)
  "Register FILE into the SVN version-control system.
COMMENT can be used to provide an initial description of FILE.

`vc-register-switches' and `vc-svn-register-switches' are passed to
the SVN command (in that order)."
  (let ((switches (append
		   (if (stringp vc-register-switches)
		       (list vc-register-switches)
		     vc-register-switches)
		   (if (stringp vc-svn-register-switches)
		       (list vc-svn-register-switches)
		     vc-svn-register-switches))))

    (apply 'vc-svn-command nil 0 file
	   "add"
	   ;; (and comment (string-match "[^\t\n ]" comment)
	   ;; 	(concat "-m" comment))
	   switches)))

(defun vc-svn-responsible-p (file)
  "Return non-nil if SVN thinks it is responsible for FILE."
  (file-directory-p (expand-file-name ".svn"
				      (if (file-directory-p file)
					  file
					(file-name-directory file)))))

(defalias 'vc-svn-could-register 'vc-svn-responsible-p
  "Return non-nil if FILE could be registered in SVN.
This is only possible if SVN is responsible for FILE's directory.")

(defun vc-svn-checkin (file rev comment)
  "SVN-specific version of `vc-backend-checkin'."
  (let ((switches (if (stringp vc-checkin-switches)
		      (list vc-checkin-switches)
		    vc-checkin-switches))
	status)
    (setq status (apply 'vc-svn-command nil 1 file
			"ci" (list* "-m" comment switches)))
    (set-buffer "*vc*")
    (goto-char (point-min))
    (unless (equal status 0)
      ;; Check checkin problem.
      (cond
       ((re-search-forward "Up-to-date check failed" nil t)
        (vc-file-setprop file 'vc-state 'needs-merge)
        (error (substitute-command-keys
                (concat "Up-to-date check failed: "
                        "type \\[vc-next-action] to merge in changes"))))
       (t
        (pop-to-buffer (current-buffer))
        (goto-char (point-min))
        (shrink-window-if-larger-than-buffer)
        (error "Check-in failed"))))
    ;; Update file properties
    ;; (vc-file-setprop
    ;;  file 'vc-workfile-version
    ;;  (vc-parse-buffer "^\\(new\\|initial\\) revision: \\([0-9.]+\\)" 2))
    ))

(defun vc-svn-find-version (file rev buffer)
  (apply 'vc-svn-command
	 buffer 0 file
	 "cat"
	 (and rev (not (string= rev ""))
	      (concat "-r" rev))
	 (if (stringp vc-checkout-switches)
	     (list vc-checkout-switches)
	   vc-checkout-switches)))

(defun vc-svn-checkout (file &optional editable rev)
  (message "Checking out %s..." file)
  (with-current-buffer (or (get-file-buffer file) (current-buffer))
    (let ((switches (if (stringp vc-checkout-switches)
			(list vc-checkout-switches)
		      vc-checkout-switches)))
      (vc-call update file editable rev switches)))
  (vc-mode-line file)
  (message "Checking out %s...done" file))

(defun vc-svn-update (file editable rev switches)
  (if (and (file-exists-p file) (not rev))
      ;; If no revision was specified, just make the file writable
      ;; if necessary (using `svn-edit' if requested).
      (and editable (not (eq (vc-svn-checkout-model file) 'implicit))
	   (if vc-svn-use-edit
	       (vc-svn-command nil 0 file "edit")
	     (set-file-modes file (logior (file-modes file) 128))
	     (if (equal file buffer-file-name) (toggle-read-only -1))))
    ;; Check out a particular version (or recreate the file).
    (vc-file-setprop file 'vc-workfile-version nil)
    (apply 'vc-svn-command nil 0 file
	   "-w"
	   "update"
	   ;; default for verbose checkout: clear the sticky tag so
	   ;; that the actual update will get the head of the trunk
	   (if (or (not rev) (string= rev ""))
	       "-A"
	     (concat "-r" rev))
	   switches)))

(defun vc-svn-revert (file &optional contents-done)
  "Revert FILE to the version it was based on."
  (unless contents-done
    (vc-svn-command nil 0 file "revert"))
  (unless (eq (vc-checkout-model file) 'implicit)
    (if vc-svn-use-edit
        (vc-svn-command nil 0 file "unedit")
      ;; Make the file read-only by switching off all w-bits
      (set-file-modes file (logand (file-modes file) 3950)))))

(defun vc-svn-merge (file first-version &optional second-version)
  "Merge changes into current working copy of FILE.
The changes are between FIRST-VERSION and SECOND-VERSION."
  (vc-svn-command nil 0 file
                 "merge"
		 "-r" (if second-version
			(concat first-version ":" second-version)
		      first-version))
  (vc-file-setprop file 'vc-state 'edited)
  (with-current-buffer (get-buffer "*vc*")
    (goto-char (point-min))
    (if (looking-at "C  ")
        1				; signal conflict
      0)))				; signal success

(defun vc-svn-merge-news (file)
  "Merge in any new changes made to FILE."
  (message "Merging changes into %s..." file)
  ;; (vc-file-setprop file 'vc-workfile-version nil)
  (vc-file-setprop file 'vc-checkout-time 0)
  (vc-svn-command nil 0 file "update")
  ;; Analyze the merge result reported by SVN, and set
  ;; file properties accordingly.
  (with-current-buffer (get-buffer "*vc*")
    (goto-char (point-min))
    ;; get new workfile version
    (if (re-search-forward
	 "^\\(Updated to\\|At\\) revision \\([0-9]+\\)" nil t)
	(vc-file-setprop file 'vc-workfile-version (match-string 2))
      (vc-file-setprop file 'vc-workfile-version nil))
    ;; get file status
    (goto-char (point-min))
    (prog1
        (if (looking-at "At revision")
            0 ;; there were no news; indicate success
          (if (re-search-forward
               (concat "^\\([CGDU]  \\)?"
                       (regexp-quote (file-name-nondirectory file)))
               nil t)
              (cond
               ;; Merge successful, we are in sync with repository now
               ((string= (match-string 1) "U  ")
                (vc-file-setprop file 'vc-state 'up-to-date)
                (vc-file-setprop file 'vc-checkout-time
                                 (nth 5 (file-attributes file)))
                0);; indicate success to the caller
               ;; Merge successful, but our own changes are still in the file
               ((string= (match-string 1) "G  ")
                (vc-file-setprop file 'vc-state 'edited)
                0);; indicate success to the caller
               ;; Conflicts detected!
               (t
                (vc-file-setprop file 'vc-state 'edited)
                1);; signal the error to the caller
               )
            (pop-to-buffer "*vc*")
            (error "Couldn't analyze svn update result")))
      (message "Merging changes into %s...done" file))))


;;;
;;; History functions
;;;

(defun vc-svn-print-log (file)
  "Get change log associated with FILE."
  (save-current-buffer
    (vc-setup-buffer nil)
    (let ((inhibit-read-only t))
      (goto-char (point-min))
      ;; Add a line to tell log-view-mode what file this is.
      (insert "Working file: " (file-relative-name file) "\n"))
    (vc-svn-command
     t
     (if (and (vc-svn-stay-local-p file) (fboundp 'start-process)) 'async 0)
     file "log")))

(defun vc-svn-diff (file &optional oldvers newvers)
  "Get a difference report using SVN between two versions of FILE."
  (let (status (diff-switches-list (vc-diff-switches-list 'SVN)))
    (if (string= (vc-workfile-version file) "0")
	;; This file is added but not yet committed; there is no master file.
	(if (or oldvers newvers)
	    (error "No revisions of %s exist" file)
	  ;; We regard this as "changed".
	  ;; Diff it against /dev/null.
          ;; Note: this is NOT a "svn diff".
          (apply 'vc-do-command "*vc-diff*"
                 1 "diff" file
                 (append diff-switches-list '("/dev/null"))))
      (setq status
            (apply 'vc-svn-command "*vc-diff*"
                   (if (and (vc-svn-stay-local-p file)
			    (or oldvers newvers) ; Svn diffs those locally.
			    (fboundp 'start-process))
		       'async
		     1)
                   file "diff"
		   (append
		    (when oldvers
		      (list "-r"
			    (if newvers (concat oldvers ":" newvers) oldvers)))
		    (when diff-switches-list
		      (list "-x" (mapconcat 'identity diff-switches-list " "))))))
      (if (vc-svn-stay-local-p file)
          1 ;; async diff, pessimistic assumption
        status))))

(defun vc-svn-diff-tree (dir &optional rev1 rev2)
  "Diff all files at and below DIR."
  (with-current-buffer "*vc-diff*"
    (setq default-directory dir)
    (if (vc-svn-stay-local-p dir)
        ;; local diff: do it filewise, and only for files that are modified
        (vc-file-tree-walk
         dir
         (lambda (f)
           (vc-exec-after
            `(let ((coding-system-for-read (vc-coding-system-for-diff ',f)))
               ;; possible optimization: fetch the state of all files
               ;; in the tree via vc-svn-dir-state-heuristic
               (unless (vc-up-to-date-p ',f)
                 (message "Looking at %s" ',f)
                 (vc-diff-internal ',f ',rev1 ',rev2))))))
      ;; svn diff: use a single call for the entire tree
      (let ((coding-system-for-read (or coding-system-for-read 'undecided))
	    (diff-switches-list (vc-diff-switches-list 'SVN)))
        (apply 'vc-svn-command "*vc-diff*" 1 nil "diff"
	       (append
		(when rev1
		  (list "-r"
			(if rev2 (concat rev1 ":" rev2) rev1)))
		(when diff-switches-list
		  (list "-x" (mapconcat 'identity diff-switches-list " ")))))))))

;;;
;;; Snapshot system
;;;

(defun vc-svn-create-snapshot (dir name branchp)
  "Assign to DIR's current version a given NAME.
If BRANCHP is non-nil, the name is created as a branch (and the current
workspace is immediately moved to that new branch)."
  (vc-svn-command nil 0 dir "tag" "-c" (if branchp "-b") name)
  (when branchp (vc-svn-command nil 0 dir "update" "-r" name)))

(defun vc-svn-retrieve-snapshot (dir name update)
  "Retrieve a snapshot at and below DIR.
NAME is the name of the snapshot; if it is empty, do a `svn update'.
If UPDATE is non-nil, then update (resynch) any affected buffers."
  (with-current-buffer (get-buffer-create "*vc*")
    (let ((default-directory dir)
	  (sticky-tag))
      (erase-buffer)
      (if (or (not name) (string= name ""))
	  (vc-svn-command t 0 nil "update")
	(vc-svn-command t 0 nil "update" "-r" name)
	(setq sticky-tag name))
      (when update
	(goto-char (point-min))
	(while (not (eobp))
	  (if (looking-at "\\([CMUP]\\) \\(.*\\)")
	      (let* ((file (expand-file-name (match-string 2) dir))
		     (state (match-string 1))
		     (buffer (find-buffer-visiting file)))
		(when buffer
		  (cond
		   ((or (string= state "U")
			(string= state "P"))
		    (vc-file-setprop file 'vc-state 'up-to-date)
		    (vc-file-setprop file 'vc-workfile-version nil)
		    (vc-file-setprop file 'vc-checkout-time
				     (nth 5 (file-attributes file))))
		   ((or (string= state "M")
			(string= state "C"))
		    (vc-file-setprop file 'vc-state 'edited)
		    (vc-file-setprop file 'vc-workfile-version nil)
		    (vc-file-setprop file 'vc-checkout-time 0)))
		  (vc-file-setprop file 'vc-svn-sticky-tag sticky-tag)
		  (vc-resynch-buffer file t t))))
	  (forward-line 1))))))


;;;
;;; Miscellaneous
;;;

;; Subversion makes backups for us, so don't bother.
;; (defalias 'vc-svn-make-version-backups-p 'vc-svn-stay-local-p
;;   "Return non-nil if version backups should be made for FILE.")

(defun vc-svn-check-headers ()
  "Check if the current file has any headers in it."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward "\\$[A-Za-z\300-\326\330-\366\370-\377]+\
\\(: [\t -#%-\176\240-\377]*\\)?\\$" nil t)))


;;;
;;; Internal functions
;;;

(defun vc-svn-command (buffer okstatus file &rest flags)
  "A wrapper around `vc-do-command' for use in vc-svn.el.
The difference to vc-do-command is that this function always invokes `svn',
and that it passes `vc-svn-global-switches' to it before FLAGS."
  (apply 'vc-do-command buffer okstatus "svn" file
         (if (stringp vc-svn-global-switches)
             (cons vc-svn-global-switches flags)
           (append vc-svn-global-switches
                   flags))))

(defun vc-svn-stay-local-p (file)
  "Return non-nil if VC should stay local when handling FILE.
See `vc-svn-stay-local'."
  (when vc-svn-stay-local
    (let* ((dirname (if (file-directory-p file)
			(directory-file-name file)
		      (file-name-directory file)))
	   (prop
	    (or (vc-file-getprop dirname 'vc-svn-stay-local-p)
		(vc-file-setprop
		 dirname 'vc-svn-stay-local-p
		 (let ((rootname (expand-file-name ".svn/entries" dirname)))
		   (cond
		    ((not (file-readable-p rootname)) 'no)
		    ((stringp vc-svn-stay-local)
		     (with-temp-buffer
		       (let ((coding-system-for-read
			      (or file-name-coding-system
				  default-file-name-coding-system)))
			 (vc-insert-file rootname))
		       (goto-char (point-min))
		       (when (re-search-forward
			      (concat "name=\"svn:this_dir\"[\n\t ]*"
				      "url=\"\\([^\"]+\\)\"") nil t)
			 (let ((hostname (match-string 1)))
			   (if (not hostname)
			       'no
			     (let* ((stay-local t)
				    (rx
				     (cond
				      ;; vc-svn-stay-local: rx
				      ((stringp vc-svn-stay-local)
				       vc-svn-stay-local)
				      ;; vc-svn-stay-local: '( [except] rx ... )
				      ((consp vc-svn-stay-local)
				       (mapconcat
					'identity
					(if (not (eq (car vc-svn-stay-local)
						     'except))
					    vc-svn-stay-local
					  (setq stay-local nil)
					  (cdr vc-svn-stay-local))
					"\\|")))))
			       (if (not rx)
				   'yes
				 (if (not (string-match rx hostname))
				     (setq stay-local (not stay-local)))
				 (if stay-local
				     'yes
				   'no))))))))))))))
      (if (eq prop 'yes) t nil))))

(defun vc-svn-parse-status (localp)
  "Parse output of \"svn status\" command in the current buffer.
Set file properties accordingly.  Unless FULL is t, parse only
essential information."
  (let (file status)
    (goto-char (point-min))
    (while (re-search-forward
	    "^[ ADMCI?!~][ MC][ L][ +][ S]..\\([ *]\\) +\\([0-9]+\\) +\\([0-9?]+\\) +\\([^ ]+\\) +" nil t)
      (setq file (expand-file-name
		  (buffer-substring (point) (line-end-position))))
      (setq status (char-after (line-beginning-position)))
      (unless (eq status ??)
	(vc-file-setprop file 'vc-backend 'SVN)
	(vc-file-setprop file 'vc-workfile-version (match-string 2))
	(vc-file-setprop
	 file 'vc-state
	 (cond
	  ((eq status ?\ )
	   (if (eq (char-after (match-beginning 1)) ?*)
	       'needs-patch
             (vc-file-setprop file 'vc-checkout-time
                              (nth 5 (file-attributes file)))
	     'up-to-date))
	  ((eq status ?A)
	   (vc-file-setprop file 'vc-checkout-time 0)
	   'edited)
	  ((memq status '(?M ?C))
	   (if (eq (char-after (match-beginning 1)) ?*)
	       'needs-merge
	     'edited))
	  (t 'edited)))))))

(defun vc-svn-dir-state-heuristic (dir)
  "Find the SVN state of all files in DIR, using only local information."
  (vc-svn-dir-state dir 'local))

(defun vc-svn-valid-symbolic-tag-name-p (tag)
  "Return non-nil if TAG is a valid symbolic tag name."
  ;; According to the SVN manual, a valid symbolic tag must start with
  ;; an uppercase or lowercase letter and can contain uppercase and
  ;; lowercase letters, digits, `-', and `_'.
  (and (string-match "^[a-zA-Z]" tag)
       (not (string-match "[^a-z0-9A-Z-_]" tag))))

(defun vc-svn-valid-version-number-p (tag)
  "Return non-nil if TAG is a valid version number."
  (and (string-match "^[0-9]" tag)
       (not (string-match "[^0-9]" tag))))

(provide 'vc-svn)

;;; vc-svn.el ends here
