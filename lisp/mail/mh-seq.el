;;; mh-seq.el --- MH-E sequences support

;; Copyright (C) 1993, 1995, 2001, 2002 Free Software Foundation, Inc.

;; Author: Bill Wohler <wohler@newt.com>
;; Maintainer: Bill Wohler <wohler@newt.com>
;; Keywords: mail
;; See: mh-e.el

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
;;
;;   This tries to implement the algorithm described at:
;;     http://www.jwz.org/doc/threading.html
;;   It is also a start to implementing the IMAP Threading extension RFC. The
;;   implementation lacks the reference and subject canonicalization of the
;;   RFC.
;;
;;   In the presentation buffer, children messages are shown indented with
;;   either [ ] or < > around them. Square brackets ([ ]) denote that the
;;   algorithm can point out some headers which when taken together implies
;;   that the unindented message is an ancestor of the indented message. If
;;   no such proof exists then angles (< >) are used.
;;
;;   Some issues and problems are as follows:
;;
;;    (1) Scan truncates the fields at length 512. So longer references:
;;        headers get mutilated. The same kind of MH format string works when
;;        composing messages. Is there a way to avoid this? My scan command
;;        is as follows:
;;          scan +folder -width 10000 \
;;               -format "%(msg)\n%{message-id}\n%{references}\n%{subject}\n"
;;        I would really appreciate it if someone would help me with this.
;;
;;    (2) Implement heuristics to recognize message-id's in In-Reply-To:
;;        header. Right now it just assumes that the last text between angles
;;        (< and >) is the message-id. There is the chance that this will
;;        incorrectly use an email address like a message-id.
;;
;;    (3) Error checking of found message-id's should be done.
;;
;;    (4) Since this breaks the assumption that message indices increase as
;;        one goes down the buffer, the binary search based mh-goto-msg
;;        doesn't work. I have a simpler replacement which may be less
;;        efficient.
;;
;;    (5) Better canonicalizing for message-id and subject strings.
;;

;; Internal support for MH-E package.

;;; Change Log:

;; $Id: mh-seq.el,v 1.71 2002/11/14 20:41:12 wohler Exp $

;;; Code:

(require 'cl)
(require 'mh-e)

;; Shush the byte-compiler
(defvar tool-bar-mode)

;;; Data structures (used in message threading)...
(defstruct (mh-thread-message (:conc-name mh-message-)
                              (:constructor mh-thread-make-message))
  (id nil)
  (references ())
  (subject "")
  (subject-re-p nil))

(defstruct (mh-thread-container (:conc-name mh-container-)
                                (:constructor mh-thread-make-container))
  message parent children
  (real-child-p t))


;;; Internal variables:
(defvar mh-last-seq-used nil
  "Name of seq to which a msg was last added.")

(defvar mh-non-seq-mode-line-annotation nil
  "Saved value of `mh-mode-line-annotation' when narrowed to a seq.")

;;; Maps and hashes...
(defvar mh-thread-id-hash nil
  "Hashtable used to canonicalize message-id strings.")
(defvar mh-thread-subject-hash nil
  "Hashtable used to canonicalize subject strings.")
(defvar mh-thread-id-table nil
  "Thread ID table maps from message-id's to message containers.")
(defvar mh-thread-id-index-map nil
  "Table to lookup message index number from message-id.")
(defvar mh-thread-index-id-map nil
  "Table to lookup message-id from message index.")
(defvar mh-thread-scan-line-map nil
  "Map of message index to various parts of the scan line.")
(defvar mh-thread-old-scan-line-map nil
  "Old map of message index to various parts of the scan line.
This is the original map that is stored when the folder is narrowed.")
(defvar mh-thread-subject-container-hash nil
  "Hashtable used to group messages by subject.")
(defvar mh-thread-duplicates nil
  "Hashtable used to remember multiple messages with the same message-id.")
(defvar mh-thread-history ()
  "Variable to remember the transformations to the thread tree.
When new messages are added, these transformations are rewound, then the
links are added from the newly seen messages. Finally the transformations are
redone to get the new thread tree. This makes incremental threading easier.")
(defvar mh-thread-body-width nil
  "Width of scan substring that contains subject and body of message.")

(make-variable-buffer-local 'mh-thread-id-hash)
(make-variable-buffer-local 'mh-thread-subject-hash)
(make-variable-buffer-local 'mh-thread-id-table)
(make-variable-buffer-local 'mh-thread-id-index-map)
(make-variable-buffer-local 'mh-thread-index-id-map)
(make-variable-buffer-local 'mh-thread-scan-line-map)
(make-variable-buffer-local 'mh-thread-old-scan-line-map)
(make-variable-buffer-local 'mh-thread-subject-container-hash)
(make-variable-buffer-local 'mh-thread-duplicates)
(make-variable-buffer-local 'mh-thread-history)

(defun mh-delete-seq (sequence)
  "Delete the SEQUENCE."
  (interactive (list (mh-read-seq-default "Delete" t)))
  (mh-map-to-seq-msgs 'mh-notate-if-in-one-seq sequence ?  (1+ mh-cmd-note)
		      sequence)
  (mh-undefine-sequence sequence '("all"))
  (mh-delete-seq-locally sequence))

;; Avoid compiler warnings
(defvar view-exit-action)

(defun mh-list-sequences (folder)
  "List the sequences defined in FOLDER."
  (interactive (list (mh-prompt-for-folder "List sequences in"
					   mh-current-folder t)))
  (let ((temp-buffer mh-temp-sequences-buffer)
	(seq-list mh-seq-list))
    (with-output-to-temp-buffer temp-buffer
      (save-excursion
	(set-buffer temp-buffer)
	(erase-buffer)
	(message "Listing sequences ...")
	(insert "Sequences in folder " folder ":\n")
	(while seq-list
	  (let ((name (mh-seq-name (car seq-list)))
		(sorted-seq-msgs
		 (sort (copy-sequence (mh-seq-msgs (car seq-list))) '<))
		(last-col (- (window-width) 4))
		name-spec)
	    (insert (setq name-spec (format "%20s:" name)))
	    (while sorted-seq-msgs
	      (if (> (current-column) last-col)
		  (progn
		    (insert "\n")
		    (move-to-column (length name-spec))))
	      (insert (format " %s" (car sorted-seq-msgs)))
	      (setq sorted-seq-msgs (cdr sorted-seq-msgs)))
	    (insert "\n"))
	  (setq seq-list (cdr seq-list)))
	(goto-char (point-min))
	(view-mode 1)
	(setq view-exit-action 'kill-buffer)
	(message "Listing sequences...done")))))

(defun mh-msg-is-in-seq (message)
  "Display the sequences that contain MESSAGE (default: current message)."
  (interactive (list (mh-get-msg-num t)))
  (let* ((dest-folder (loop for seq in mh-refile-list
                               when (member message (cdr seq))
                               return (car seq)))
         (deleted-flag (unless dest-folder (member message mh-delete-list))))
    (message "Message %d%s is in sequences: %s"
             message
             (cond (dest-folder (format " (to be refiled to %s)" dest-folder))
                   (deleted-flag (format " (to be deleted)"))
                   (t ""))
             (mapconcat 'concat
                        (mh-list-to-string (mh-seq-containing-msg message t))
                        " "))))

(defun mh-narrow-to-seq (sequence)
  "Restrict display of this folder to just messages in SEQUENCE.
Use \\<mh-folder-mode-map>\\[mh-widen] to undo this command."
  (interactive (list (mh-read-seq "Narrow to" t)))
  (with-mh-folder-updating (t)
    (cond ((mh-seq-to-msgs sequence)
	   (mh-widen)
           (mh-remove-all-notation)
	   (let ((eob (point-max))
                 (msg-at-cursor (mh-get-msg-num nil)))
             (setq mh-thread-old-scan-line-map mh-thread-scan-line-map)
             (setq mh-thread-scan-line-map (make-hash-table :test #'eql))
	     (mh-copy-seq-to-eob sequence)
             (narrow-to-region eob (point-max))
             (mh-notate-user-sequences)
             (mh-notate-deleted-and-refiled)
             (mh-notate-seq 'cur mh-note-cur mh-cmd-note)
             (when msg-at-cursor (mh-goto-msg msg-at-cursor t t))
	     (make-variable-buffer-local 'mh-non-seq-mode-line-annotation)
	     (setq mh-non-seq-mode-line-annotation mh-mode-line-annotation)
	     (setq mh-mode-line-annotation (symbol-name sequence))
	     (mh-make-folder-mode-line)
	     (mh-recenter nil)
             (if (and (boundp 'tool-bar-mode) tool-bar-mode)
                 (set (make-local-variable 'tool-bar-map)
                      mh-folder-seq-tool-bar-map))
	     (setq mh-narrowed-to-seq sequence)
             (push 'widen mh-view-ops)))
	  (t
	   (error "No messages in sequence `%s'" (symbol-name sequence))))))

(defun mh-put-msg-in-seq (msg-or-seq sequence)
  "Add MSG-OR-SEQ (default: displayed message) to SEQUENCE.
If optional prefix argument provided, then prompt for the message sequence.
If variable `transient-mark-mode' is non-nil and the mark is active, then
the selected region is added to the sequence."
  (interactive (list (cond
                      ((mh-mark-active-p t)
                       (mh-region-to-sequence (region-beginning) (region-end))
                       'region)
                      (current-prefix-arg
                       (mh-read-seq-default "Add messages from" t))
                      (t
		       (mh-get-msg-num t)))
		     (mh-read-seq-default "Add to" nil)))
  (if (not (mh-internal-seq sequence))
      (setq mh-last-seq-used sequence))
  (mh-add-msgs-to-seq (if (numberp msg-or-seq)
			  msg-or-seq
			(mh-seq-to-msgs msg-or-seq))
		      sequence))

(defun mh-valid-view-change-operation-p (op)
  "Check if the view change operation can be performed.
OP is one of 'widen and 'unthread."
  (cond ((eq (car mh-view-ops) op)
         (pop mh-view-ops))
        (t nil)))

(defun mh-widen ()
  "Remove restrictions from current folder, thereby showing all messages."
  (interactive)
  (let ((msg (mh-get-msg-num nil)))
    (when mh-narrowed-to-seq
      (cond ((mh-valid-view-change-operation-p 'widen) nil)
            ((memq 'widen mh-view-ops)
             (while (not (eq (car mh-view-ops) 'widen))
               (setq mh-view-ops (cdr mh-view-ops)))
             (pop mh-view-ops))
            (t (error "Widening is not applicable")))
      (when (memq 'unthread mh-view-ops)
        (setq mh-thread-scan-line-map mh-thread-old-scan-line-map))
      (with-mh-folder-updating (t)
        (delete-region (point-min) (point-max))
        (widen)
        (setq mh-mode-line-annotation mh-non-seq-mode-line-annotation)
        (mh-make-folder-mode-line))
      (if msg
          (mh-goto-msg msg t t))
      (mh-notate-deleted-and-refiled)
      (mh-notate-user-sequences)
      (mh-notate-seq 'cur mh-note-cur mh-cmd-note)
      (mh-recenter nil)))
  (if (and (boundp 'tool-bar-mode) tool-bar-mode)
      (set (make-local-variable 'tool-bar-map) mh-folder-tool-bar-map))
  (setq mh-narrowed-to-seq nil))

;; FIXME?  We may want to clear all notations and add one for current-message
;;         and process user sequences.
(defun mh-notate-deleted-and-refiled ()
  "Notate messages marked for deletion or refiling.
Messages to be deleted are given by `mh-delete-list' while messages to be
refiled are present in `mh-refile-list'."
  (mh-mapc #'(lambda (msg) (mh-notate msg mh-note-deleted mh-cmd-note))
           mh-delete-list)
  (mh-mapc #'(lambda (dest-msg-list)
               ;; foreach folder name, get the keyed sequence from mh-seq-list
               (let ((msg-list (cdr dest-msg-list)))
                 (mh-mapc #'(lambda (msg)
                              (mh-notate msg mh-note-refiled mh-cmd-note))
                          msg-list)))
           mh-refile-list))



;;; Commands to manipulate sequences.  Sequences are stored in an alist
;;; of the form:
;;;	((seq-name msgs ...) (seq-name msgs ...) ...)

(defun mh-read-seq-default (prompt not-empty)
  "Read and return sequence name with default narrowed or previous sequence.
PROMPT is the prompt to use when reading. If NOT-EMPTY is non-nil then a
non-empty sequence is read."
  (mh-read-seq prompt not-empty
	       (or mh-narrowed-to-seq
		   mh-last-seq-used
		   (car (mh-seq-containing-msg (mh-get-msg-num nil) nil)))))

(defun mh-read-seq (prompt not-empty &optional default)
  "Read and return a sequence name.
Prompt with PROMPT, raise an error if the sequence is empty and the NOT-EMPTY
flag is non-nil, and supply an optional DEFAULT sequence. A reply of '%'
defaults to the first sequence containing the current message."
  (let* ((input (completing-read (format "%s %s %s" prompt "sequence:"
					 (if default
					     (format "[%s] " default)
					     ""))
				 (mh-seq-names mh-seq-list)))
	 (seq (cond ((equal input "%")
		     (car (mh-seq-containing-msg (mh-get-msg-num t) nil)))
		    ((equal input "") default)
		    (t (intern input))))
	 (msgs (mh-seq-to-msgs seq)))
    (if (and (null msgs) not-empty)
	(error "No messages in sequence `%s'" seq))
    seq))

(defun mh-seq-names (seq-list)
  "Return an alist containing the names of the SEQ-LIST."
  (mapcar (lambda (entry) (list (symbol-name (mh-seq-name entry))))
	  seq-list))

(defun mh-rename-seq (sequence new-name)
  "Rename SEQUENCE to have NEW-NAME."
  (interactive (list (mh-read-seq "Old" t)
		     (intern (read-string "New sequence name: "))))
  (let ((old-seq (mh-find-seq sequence)))
    (or old-seq
	(error "Sequence %s does not exist" sequence))
    ;; create new sequence first, since it might raise an error.
    (mh-define-sequence new-name (mh-seq-msgs old-seq))
    (mh-undefine-sequence sequence (mh-seq-msgs old-seq))
    (rplaca old-seq new-name)))

(defun mh-map-to-seq-msgs (func seq &rest args)
"Invoke the FUNC at each message in the SEQ.
The remaining ARGS are passed as arguments to FUNC."
  (save-excursion
    (let ((msgs (mh-seq-to-msgs seq)))
      (while msgs
	(if (mh-goto-msg (car msgs) t t)
	    (apply func (car msgs) args))
	(setq msgs (cdr msgs))))))

(defun mh-notate-seq (seq notation offset)
  "Mark the scan listing.
All messages in SEQ are marked with NOTATION at OFFSET from the beginning of
the line."
  (mh-map-to-seq-msgs 'mh-notate seq notation offset))

(defun mh-add-to-sequence (seq msgs)
  "The sequence SEQ is augmented with the messages in MSGS."
  ;; Add to a SEQUENCE each message the list of MSGS.
  (if (not (mh-folder-name-p seq))
      (if msgs
	  (apply 'mh-exec-cmd "mark" mh-current-folder "-add"
		 "-sequence" (symbol-name seq)
		 (mh-coalesce-msg-list msgs)))))

;; This has a tricky bug. mh-map-to-seq-msgs uses mh-goto-msg, which assumes
;; that the folder buffer is sorted. However in this case that assumption
;; doesn't hold. So we will do this the dumb way.
;(defun mh-copy-seq-to-point (seq location)
;  ;; Copy the scan listing of the messages in SEQUENCE to after the point
;  ;; LOCATION in the current buffer.
;  (mh-map-to-seq-msgs 'mh-copy-line-to-point seq location))

(defun mh-copy-seq-to-eob (seq)
  "Copy SEQ to the end of the buffer."
  ;; It is quite involved to write something which will work at any place in
  ;; the buffer, so we will write something which works only at the end of
  ;; the buffer. If we ever need to insert sequences in the middle of the
  ;; buffer, this will need to be fixed.
  (save-excursion
    (let* ((msgs (mh-seq-to-msgs seq))
           (coalesced-msgs (mh-coalesce-msg-list msgs)))
      (goto-char (point-max))
      (save-restriction
        (narrow-to-region (point) (point))
        (mh-regenerate-headers coalesced-msgs t)
        (when (memq 'unthread mh-view-ops)
          ;; Populate restricted scan-line map
          (goto-char (point-min))
          (while (not (eobp))
            (setf (gethash (mh-get-msg-num nil) mh-thread-scan-line-map)
                  (mh-thread-parse-scan-line))
            (forward-line))
          ;; Remove scan lines and read results from pre-computed thread tree
          (delete-region (point-min) (point-max))
          (let ((thread-tree (mh-thread-generate mh-current-folder ()))
                (mh-thread-body-width
                  (- (window-width) mh-cmd-note
                     (1- mh-scan-field-subject-start-offset))))
            (mh-thread-generate-scan-lines thread-tree -2)))))))

(defun mh-copy-line-to-point (msg location)
  "Copy current message line to a specific location.
The argument MSG is not used. The message in the current line is copied to
LOCATION."
  ;; msg is not used?
  ;; Copy the current line to the LOCATION in the current buffer.
  (beginning-of-line)
  (save-excursion
    (let ((beginning-of-line (point))
	  end)
      (forward-line 1)
      (setq end (point))
      (goto-char location)
      (insert-buffer-substring (current-buffer) beginning-of-line end))))

(defun mh-region-to-sequence (begin end)
  "Define sequence 'region as the messages between point and mark.
When called programmatically, use arguments BEGIN and END to define region."
  (interactive "r")
  (mh-delete-seq-locally 'region)
  (save-excursion
    ;; If end is end of buffer back up one position
    (setq end (if (equal end (point-max)) (1- end) end))
    (goto-char begin)
    (while (<= (point) end)
      (mh-add-msgs-to-seq (mh-get-msg-num t) 'region t)
      (forward-line 1))))



;;; Commands to handle new 'subject sequence.
;;; Or "Poor man's threading" by psg.

(defun mh-subject-to-sequence (all)
  "Put all following messages with same subject in sequence 'subject.
If arg ALL is t, move to beginning of folder buffer to collect all messages.
If arg ALL is nil, collect only messages fron current one on forward.

Return number of messages put in the sequence:

 nil -> there was no subject line.
 0   -> there were no later messages with the same subject (sequence not made)
 >1  -> the total number of messages including current one."
  (if (not (eq major-mode 'mh-folder-mode))
      (error "Not in a folder buffer"))
  (save-excursion
    (beginning-of-line)
    (if (or (not (looking-at mh-scan-subject-regexp))
            (not (match-string 3))
            (string-equal "" (match-string 3)))
        (progn (message "No subject line.")
               nil)
      (let ((subject (match-string-no-properties 3))
            (list))
        (if (> (length subject) 41)
            (setq subject (substring subject 0 41)))
        (save-excursion
          (if all
              (goto-char (point-min)))
          (while (re-search-forward mh-scan-subject-regexp nil t)
            (let ((this-subject (match-string-no-properties 3)))
              (if (> (length this-subject) 41)
                  (setq this-subject (substring this-subject 0 41)))
              (if (string-equal this-subject subject)
                  (setq list (cons (mh-get-msg-num t) list))))))
        (cond
         (list
          ;; If we created a new sequence, add the initial message to it too.
          (if (not (member (mh-get-msg-num t) list))
              (setq list (cons (mh-get-msg-num t) list)))
          (if (member '("subject") (mh-seq-names mh-seq-list))
              (mh-delete-seq 'subject))
          ;; sort the result into a sequence
          (let ((sorted-list (sort (copy-sequence list) 'mh-lessp)))
            (while sorted-list
              (mh-add-msgs-to-seq (car sorted-list) 'subject nil)
              (setq sorted-list (cdr sorted-list)))
            (safe-length list)))
         (t
          0))))))

(defun mh-narrow-to-subject ()
  "Narrow to a sequence containing all following messages with same subject."
  (interactive)
  (let ((num (mh-get-msg-num nil))
        (count (mh-subject-to-sequence t)))
    (cond
     ((not count)                       ; No subject line, delete msg anyway
      nil)
     ((= 0 count)                       ; No other msgs, delete msg anyway.
      (message "No other messages with same Subject following this one.")
      nil)
     (t                                 ; We have a subject sequence.
      (message "Found %d messages for subject sequence." count)
      (mh-narrow-to-seq 'subject)
      (if (numberp num)
          (mh-goto-msg num t t))))))

(defun mh-delete-subject ()
  "Mark all following messages with same subject to be deleted.
This puts the messages in a sequence named subject.  You can undo the last
deletion marks using `mh-undo' with a prefix argument and then specifying the
subject sequence."
  (interactive)
  (let ((count (mh-subject-to-sequence nil)))
    (cond
     ((not count)                       ; No subject line, delete msg anyway
      (mh-delete-msg (mh-get-msg-num t)))
     ((= 0 count)                       ; No other msgs, delete msg anyway.
      (message "No other messages with same Subject following this one.")
      (mh-delete-msg (mh-get-msg-num t)))
     (t                                 ; We have a subject sequence.
      (message "Marked %d messages for deletion" count)
      (mh-delete-msg 'subject)))))

;;; Message threading:

(defun mh-thread-initialize ()
  "Make hash tables, otherwise clear them."
  (cond
    (mh-thread-id-hash
     (clrhash mh-thread-id-hash)
     (clrhash mh-thread-subject-hash)
     (clrhash mh-thread-id-table)
     (clrhash mh-thread-id-index-map)
     (clrhash mh-thread-index-id-map)
     (clrhash mh-thread-scan-line-map)
     (clrhash mh-thread-subject-container-hash)
     (clrhash mh-thread-duplicates)
     (setq mh-thread-history ()))
    (t (setq mh-thread-id-hash (make-hash-table :test #'equal))
       (setq mh-thread-subject-hash (make-hash-table :test #'equal))
       (setq mh-thread-id-table (make-hash-table :test #'eq))
       (setq mh-thread-id-index-map (make-hash-table :test #'eq))
       (setq mh-thread-index-id-map (make-hash-table :test #'eql))
       (setq mh-thread-scan-line-map (make-hash-table :test #'eql))
       (setq mh-thread-subject-container-hash (make-hash-table :test #'eq))
       (setq mh-thread-duplicates (make-hash-table :test #'eq))
       (setq mh-thread-history ()))))

(defsubst mh-thread-id-container (id)
  "Given ID, return the corresponding container in `mh-thread-id-table'.
If no container exists then a suitable container is created and the id-table
is updated."
  (when (not id)
    (error "1"))
  (or (gethash id mh-thread-id-table)
      (setf (gethash id mh-thread-id-table)
            (let ((message (mh-thread-make-message :id id)))
              (mh-thread-make-container :message message)))))

(defsubst mh-thread-remove-parent-link (child)
  "Remove parent link of CHILD if it exists."
  (let* ((child-container (if (mh-thread-container-p child)
                              child (mh-thread-id-container child)))
         (parent-container (mh-container-parent child-container)))
    (when parent-container
      (setf (mh-container-children parent-container)
            (remove* child-container (mh-container-children parent-container)
                     :test #'eq))
      (setf (mh-container-parent child-container) nil))))

(defsubst mh-thread-add-link (parent child &optional at-end-p)
  "Add links so that PARENT becomes a parent of CHILD.
Doesn't make any changes if CHILD is already an ancestor of PARENT. If
optional argument AT-END-P is non-nil, the CHILD is added to the end of the
children list of PARENT."
  (let ((parent-container (cond ((null parent) nil)
                                ((mh-thread-container-p parent) parent)
                                (t (mh-thread-id-container parent))))
        (child-container (if (mh-thread-container-p child)
                             child (mh-thread-id-container child))))
    (when (and parent-container
               (not (mh-thread-ancestor-p child-container parent-container))
               (not (mh-thread-ancestor-p parent-container child-container)))
      (mh-thread-remove-parent-link child-container)
      (cond ((not at-end-p)
             (push child-container (mh-container-children parent-container)))
            ((null (mh-container-children parent-container))
             (push child-container (mh-container-children parent-container)))
            (t (let ((last-child (mh-container-children parent-container)))
                 (while (cdr last-child)
                   (setq last-child (cdr last-child)))
                 (setcdr last-child (cons child-container nil)))))
      (setf (mh-container-parent child-container) parent-container))
    (unless parent-container
      (mh-thread-remove-parent-link child-container))))

(defun mh-thread-ancestor-p (ancestor successor)
  "Return t if ANCESTOR is really an ancestor of SUCCESSOR and nil otherwise.
In the limit, the function returns t if ANCESTOR and SUCCESSOR are the same
containers."
  (block nil
    (while successor
      (when (eq ancestor successor) (return t))
      (setq successor (mh-container-parent successor)))
    nil))

(defsubst mh-thread-get-message-container (message)
  "Return container which has MESSAGE in it.
If there is no container present then a new container is allocated."
  (let* ((id (mh-message-id message))
         (container (gethash id mh-thread-id-table)))
    (cond (container (setf (mh-container-message container) message)
                     container)
          (t (setf (gethash id mh-thread-id-table)
                   (mh-thread-make-container :message message))))))

(defsubst mh-thread-get-message (id subject-re-p subject refs)
  "Return appropriate message.
Otherwise update message already present to have the proper ID, SUBJECT-RE-P,
SUBJECT and REFS fields."
  (let* ((container (gethash id mh-thread-id-table))
         (message (if container (mh-container-message container) nil)))
    (cond (message
           (setf (mh-message-subject-re-p message) subject-re-p)
           (setf (mh-message-subject message) subject)
           (setf (mh-message-id message) id)
           (setf (mh-message-references message) refs)
           message)
          (container
           (setf (mh-container-message container)
                 (mh-thread-make-message :subject subject
                                         :subject-re-p subject-re-p
                                         :id id :references refs)))
          (t (let ((message (mh-thread-make-message
                             :subject subject
                             :subject-re-p subject-re-p
                             :id id :references refs)))
               (prog1 message
                 (mh-thread-get-message-container message)))))))

(defsubst mh-thread-canonicalize-id (id)
  "Produce canonical string representation for ID.
This allows cheap string comparison with EQ."
  (or (and (equal id "") (copy-sequence ""))
      (gethash id mh-thread-id-hash)
      (setf (gethash id mh-thread-id-hash) id)))

(defsubst mh-thread-prune-subject (subject)
  "Prune leading Re:'s, Fwd:'s etc. and trailing (fwd)'s from SUBJECT.
If the result after pruning is not the empty string then it is canonicalized
so that subjects can be tested for equality with eq. This is done so that all
the messages without a subject are not put into a single thread."
  (let ((case-fold-search t)
        (subject-pruned-flag nil))
    ;; Prune subject leader
    (while (or (string-match "^[ \t]*\\(re\\|fwd?\\)\\(\\[[0-9]*\\]\\)?:[ \t]*"
                             subject)
               (string-match "^[ \t]*\\[[^\\]][ \t]*" subject))
      (setq subject-pruned-flag t)
      (setq subject (substring subject (match-end 0))))
    ;; Prune subject trailer
    (while (or (string-match "(fwd)$" subject)
               (string-match "[ \t]+$" subject))
      (setq subject-pruned-flag t)
      (setq subject (substring subject 0 (match-beginning 0))))
    ;; Canonicalize subject only if it is non-empty
    (cond ((equal subject "") (values subject subject-pruned-flag))
          (t (values
              (or (gethash subject mh-thread-subject-hash)
                  (setf (gethash subject mh-thread-subject-hash) subject))
              subject-pruned-flag)))))

(defun mh-thread-container-subject (container)
  "Return the subject of CONTAINER.
If CONTAINER is empty return the subject info of one of its children."
  (cond ((and (mh-container-message container)
              (mh-message-id (mh-container-message container)))
         (mh-message-subject (mh-container-message container)))
        (t (block nil
             (dolist (kid (mh-container-children container))
               (when (and (mh-container-message kid)
                          (mh-message-id (mh-container-message kid)))
                 (let ((kid-message (mh-container-message kid)))
                   (return (mh-message-subject kid-message)))))
             (error "This can't happen!")))))

(defun mh-thread-rewind-pruning ()
  "Restore the thread tree to its state before pruning."
  (while mh-thread-history
    (let ((action (pop mh-thread-history)))
      (cond ((eq (car action) 'DROP)
             (mh-thread-remove-parent-link (cadr action))
             (mh-thread-add-link (caddr action) (cadr action)))
            ((eq (car action) 'PROMOTE)
             (let ((node (cadr action))
                   (parent (caddr action))
                   (children (cdddr action)))
               (dolist (child children)
                 (mh-thread-remove-parent-link child)
                 (mh-thread-add-link node child))
               (mh-thread-add-link parent node)))
            ((eq (car action) 'SUBJECT)
             (let ((node (cadr action)))
               (mh-thread-remove-parent-link node)
               (setf (mh-container-real-child-p node) t)))))))

(defun mh-thread-prune-containers (roots)
"Prune empty containers in the containers ROOTS."
  (let ((dfs-ordered-nodes ())
        (work-list roots))
    (while work-list
      (let ((node (pop work-list)))
        (dolist (child (mh-container-children node))
          (push child work-list))
        (push node dfs-ordered-nodes)))
    (while dfs-ordered-nodes
      (let ((node (pop dfs-ordered-nodes)))
        (cond ((gethash (mh-message-id (mh-container-message node))
                        mh-thread-id-index-map)
               ;; Keep it
               (setf (mh-container-children node)
                     (mh-thread-sort-containers (mh-container-children node))))
              ((and (mh-container-children node)
                    (or (null (cdr (mh-container-children node)))
                        (mh-container-parent node)))
               ;; Promote kids
               (let ((children ()))
                 (dolist (kid (mh-container-children node))
                   (mh-thread-remove-parent-link kid)
                   (mh-thread-add-link (mh-container-parent node) kid)
                   (push kid children))
                 (push `(PROMOTE ,node ,(mh-container-parent node) ,@children)
                       mh-thread-history)
                 (mh-thread-remove-parent-link node)))
              ((mh-container-children node)
               ;; Promote the first orphan to parent and add the other kids as
               ;; his children
               (setf (mh-container-children node)
                     (mh-thread-sort-containers (mh-container-children node)))
               (let ((new-parent (car (mh-container-children node)))
                     (other-kids (cdr (mh-container-children node))))
                 (mh-thread-remove-parent-link new-parent)
                 (dolist (kid other-kids)
                   (mh-thread-remove-parent-link kid)
                   (setf (mh-container-real-child-p kid) nil)
                   (mh-thread-add-link new-parent kid t))
                 (push `(PROMOTE ,node ,(mh-container-parent node)
                                 ,new-parent ,@other-kids)
                       mh-thread-history)
                 (mh-thread-remove-parent-link node)))
              (t
               ;; Drop it
               (push `(DROP ,node ,(mh-container-parent node))
                     mh-thread-history)
               (mh-thread-remove-parent-link node)))))
    (let ((results ()))
      (maphash #'(lambda (k v)
                   (declare (ignore k))
                   (when (and (null (mh-container-parent v))
                              (gethash (mh-message-id (mh-container-message v))
                                       mh-thread-id-index-map))
                     (push v results)))
               mh-thread-id-table)
      (mh-thread-sort-containers results))))

(defun mh-thread-sort-containers (containers)
  "Sort a list of message CONTAINERS to be in ascending order wrt index."
  (sort containers
        #'(lambda (x y)
            (when (and (mh-container-message x) (mh-container-message y))
              (let* ((id-x (mh-message-id (mh-container-message x)))
                     (id-y (mh-message-id (mh-container-message y)))
                     (index-x (gethash id-x mh-thread-id-index-map))
                     (index-y (gethash id-y mh-thread-id-index-map)))
                (and (integerp index-x) (integerp index-y)
                     (< index-x index-y)))))))

(defsubst mh-thread-group-by-subject (roots)
  "Group the set of message containers, ROOTS based on subject.
Bug: Check for and make sure that something without Re: is made the parent in
preference to something that has it."
  (clrhash mh-thread-subject-container-hash)
  (let ((results ()))
    (dolist (root roots)
      (let* ((subject (mh-thread-container-subject root))
             (parent (gethash subject mh-thread-subject-container-hash)))
        (cond (parent (mh-thread-remove-parent-link root)
                      (mh-thread-add-link parent root t)
                      (setf (mh-container-real-child-p root) nil)
                      (push `(SUBJECT ,root) mh-thread-history))
              (t
               (setf (gethash subject mh-thread-subject-container-hash) root)
               (push root results)))))
    (nreverse results)))

(defsubst mh-thread-process-in-reply-to (reply-to-header)
  "Extract message id's from REPLY-TO-HEADER.
Ideally this should have some regexp which will try to guess if a string
between < and > is a message id and not an email address. For now it will
take the last string inside angles."
  (let ((end (search ">" reply-to-header :from-end t)))
    (when (numberp end)
      (let ((begin (search "<" reply-to-header :from-end t :end2 end)))
        (when (numberp begin)
          (list (substring reply-to-header begin (1+ end))))))))

(defun mh-thread-set-tables (folder)
  "Use the tables of FOLDER in current buffer."
  (flet ((mh-get-table (symbol)
           (save-excursion (set-buffer folder) (symbol-value symbol))))
    (setq mh-thread-id-hash (mh-get-table 'mh-thread-id-hash))
    (setq mh-thread-subject-hash (mh-get-table 'mh-thread-subject-hash))
    (setq mh-thread-id-table (mh-get-table 'mh-thread-id-table))
    (setq mh-thread-id-index-map (mh-get-table 'mh-thread-id-index-map))
    (setq mh-thread-index-id-map (mh-get-table 'mh-thread-index-id-map))
    (setq mh-thread-scan-line-map (mh-get-table 'mh-thread-scan-line-map))
    (setq mh-thread-subject-container-hash
          (mh-get-table 'mh-thread-subject-container-hash))
    (setq mh-thread-duplicates (mh-get-table 'mh-thread-duplicates))
    (setq mh-thread-history (mh-get-table 'mh-thread-history))))

(defsubst mh-thread-update-id-index-maps (id index)
  "Message with id, ID is the message in INDEX.
The function also checks for duplicate messages (that is multiple messages
with the same ID). These messages are put in the `mh-thread-duplicates' hash
table."
  (let ((old-index (gethash id mh-thread-id-index-map)))
    (when old-index (push old-index (gethash id mh-thread-duplicates)))
    (setf (gethash id mh-thread-id-index-map) index)
    (setf (gethash index mh-thread-index-id-map) id)))



;;; Generate Threads...

(defun mh-thread-generate (folder msg-list)
  "Scan FOLDER to get info for threading.
Only information about messages in MSG-LIST are added to the tree."
  (save-excursion
    (set-buffer (get-buffer-create "*mh-thread*"))
    (mh-thread-set-tables folder)
    (erase-buffer)
    (when msg-list
      (apply
       #'call-process (expand-file-name mh-scan-prog mh-progs) nil '(t nil) nil
       "-width" "10000" "-format"
       "%(msg)\n%{message-id}\n%{references}\n%{in-reply-to}\n%{subject}\n"
       (mapcar #'(lambda (x) (format "%s" x)) msg-list)))
    (goto-char (point-min))
    (let ((roots ())
          (case-fold-search t))
      (block nil
        (while (not (eobp))
          (block process-message
            (let* ((index-line
                     (prog1 (buffer-substring (point) (line-end-position))
                       (forward-line)))
                   (index (car (read-from-string index-line)))
                   (id (prog1 (buffer-substring (point) (line-end-position))
                         (forward-line)))
                   (refs (prog1 (buffer-substring (point) (line-end-position))
                           (forward-line)))
                   (in-reply-to (prog1 (buffer-substring (point)
                                                         (line-end-position))
                                  (forward-line)))
                   (subject (prog1
                                (buffer-substring (point) (line-end-position))
                              (forward-line)))
                   (subject-re-p nil))
              (unless (gethash index mh-thread-scan-line-map)
                (return-from process-message))
              (unless (integerp index) (return)) ;Error message here
              (multiple-value-setq (subject subject-re-p)
                (mh-thread-prune-subject subject))
              (setq in-reply-to (mh-thread-process-in-reply-to in-reply-to))
              (setq refs (append (split-string refs) in-reply-to))
              (setq id (mh-thread-canonicalize-id id))
              (mh-thread-update-id-index-maps id index)
              (setq refs (mapcar #'mh-thread-canonicalize-id refs))
              (mh-thread-get-message id subject-re-p subject refs)
              (do ((ancestors refs (cdr ancestors)))
                  ((null (cdr ancestors))
                   (when (car ancestors)
                     (mh-thread-remove-parent-link id)
                     (mh-thread-add-link (car ancestors) id)))
                (mh-thread-add-link (car ancestors) (cadr ancestors)))))))
      (maphash #'(lambda (k v)
                   (declare (ignore k))
                   (when (null (mh-container-parent v))
                     (push v roots)))
               mh-thread-id-table)
      (setq roots (mh-thread-prune-containers roots))
      (prog1 (setq roots (mh-thread-group-by-subject roots))
        (let ((history mh-thread-history))
          (set-buffer folder)
          (setq mh-thread-history history))))))

(defun mh-thread-inc (folder start-point)
  "Update thread tree for FOLDER.
All messages after START-POINT are added to the thread tree."
  (mh-thread-rewind-pruning)
  (goto-char start-point)
  (let ((msg-list ()))
    (while (not (eobp))
      (let ((index (mh-get-msg-num nil)))
        (push index msg-list)
        (setf (gethash index mh-thread-scan-line-map)
              (mh-thread-parse-scan-line))
        (forward-line)))
    (let ((thread-tree (mh-thread-generate folder msg-list))
          (buffer-read-only nil)
          (old-buffer-modified-flag (buffer-modified-p)))
      (delete-region (point-min) (point-max))
      (let ((mh-thread-body-width (- (window-width) mh-cmd-note
                                     (1- mh-scan-field-subject-start-offset))))
        (mh-thread-generate-scan-lines thread-tree -2))
      (mh-notate-user-sequences)
      (mh-notate-deleted-and-refiled)
      (mh-notate-seq 'cur mh-note-cur mh-cmd-note)
      (set-buffer-modified-p old-buffer-modified-flag))))

(defun mh-thread-generate-scan-lines (tree level)
  "Generate scan lines.
TREE is the hierarchical tree of messages, SCAN-LINE-MAP maps message indices
to the corresponding scan lines and LEVEL used to determine indentation of
the message."
  (cond ((null tree) nil)
        ((mh-thread-container-p tree)
         (let* ((message (mh-container-message tree))
                (id (mh-message-id message))
                (index (gethash id mh-thread-id-index-map))
                (duplicates (gethash id mh-thread-duplicates))
                (new-level (+ level 2))
                (dupl-flag t)
                (increment-level-flag nil))
           (dolist (scan-line (mapcar (lambda (x)
                                        (gethash x mh-thread-scan-line-map))
                                      (reverse (cons index duplicates))))
             (when scan-line
               (insert (car scan-line)
                       (format (format "%%%ss"
				       (if dupl-flag level new-level)) "")
                       (if (and (mh-container-real-child-p tree) dupl-flag)
                           "[" "<")
                       (cadr scan-line)
                       (if (and (mh-container-real-child-p tree) dupl-flag)
                           "]" ">")
                       (truncate-string-to-width
                        (caddr scan-line) (- mh-thread-body-width
                                             (if dupl-flag level new-level)))
                       "\n")
               (setq increment-level-flag t)
               (setq dupl-flag nil)))
           (unless increment-level-flag (setq new-level level))
           (dolist (child (mh-container-children tree))
             (mh-thread-generate-scan-lines child new-level))))
        (t (let ((nlevel (+ level 2)))
             (dolist (ch tree)
               (mh-thread-generate-scan-lines ch nlevel))))))

;; Another and may be better approach would be to generate all the info from
;; the scan which generates the threading info. For now this will have to do.
(defun mh-thread-parse-scan-line (&optional string)
  "Parse a scan line.
If optional argument STRING is given then that is assumed to be the scan line.
Otherwise uses the line at point as the scan line to parse."
  (let* ((string (or string
                     (buffer-substring-no-properties (line-beginning-position)
                                                     (line-end-position))))
         (first-string (substring string 0 (+ mh-cmd-note 8))))
    (setf (elt first-string mh-cmd-note) ? )
    (when (equal (elt first-string (1+ mh-cmd-note)) (elt mh-note-seq 0))
      (setf (elt first-string (1+ mh-cmd-note)) ? ))
    (list first-string
          (substring string
                     (+ mh-cmd-note mh-scan-field-from-start-offset)
                     (+ mh-cmd-note mh-scan-field-from-end-offset -2))
          (substring string (+ mh-cmd-note mh-scan-field-from-end-offset))
          string)))

(defun mh-thread-add-spaces (count)
  "Add COUNT spaces to each scan line in `mh-thread-scan-line-map'."
  (let ((spaces (format (format "%%%ss" count) "")))
    (while (not (eobp))
      (let* ((msg-num (mh-get-msg-num nil))
             (old-line (nth 3 (gethash msg-num mh-thread-scan-line-map))))
        (setf (gethash msg-num mh-thread-scan-line-map)
              (mh-thread-parse-scan-line (format "%s%s" spaces old-line))))
      (forward-line 1))))

(defun mh-thread-folder ()
  "Generate thread view of folder."
  (message "Threading %s..." (buffer-name))
  (mh-thread-initialize)
  (goto-char (point-min))
  (while (not (eobp))
    (setf (gethash (mh-get-msg-num nil) mh-thread-scan-line-map)
          (mh-thread-parse-scan-line))
    (forward-line))
  (let* ((range (format "%s-%s" mh-first-msg-num mh-last-msg-num))
         (thread-tree (mh-thread-generate (buffer-name) (list range)))
         (buffer-read-only nil)
         (old-buffer-modified-p (buffer-modified-p)))
    (delete-region (point-min) (point-max))
    (let ((mh-thread-body-width (- (window-width) mh-cmd-note
                                   (1- mh-scan-field-subject-start-offset))))
      (mh-thread-generate-scan-lines thread-tree -2))
    (mh-notate-user-sequences)
    (mh-notate-deleted-and-refiled)
    (mh-notate-seq 'cur mh-note-cur mh-cmd-note)
    (set-buffer-modified-p old-buffer-modified-p)
    (message "Threading %s...done" (buffer-name))))

(defun mh-toggle-threads ()
  "Toggle threaded view of folder.
The conversion of normal view to threaded view is exact, that is the same
messages are displayed in the folder buffer before and after threading. However
the conversion from threaded view to normal view is inexact. So more messages
than were originally present may be shown as a result."
  (interactive)
  (let ((msg-at-point (mh-get-msg-num nil)))
    (cond ((and (memq 'unthread mh-view-ops) mh-narrowed-to-seq)
           (unless (mh-valid-view-change-operation-p 'unthread)
             (error "Can't unthread folder"))
           (mh-scan-folder mh-current-folder
                           (format "%s" mh-narrowed-to-seq)
                           t))
          ((memq 'unthread mh-view-ops)
           (unless (mh-valid-view-change-operation-p 'unthread)
             (error "Can't unthread folder"))
           (mh-scan-folder mh-current-folder
                           (format "%s-%s" mh-first-msg-num mh-last-msg-num)
                           t))
          (t (mh-thread-folder)
             (push 'unthread mh-view-ops)))
    (when msg-at-point (mh-goto-msg msg-at-point t t))
    (mh-recenter nil)))

(defun mh-thread-forget-message (index)
  "Forget the message INDEX from the threading tables."
  (let* ((id (gethash index mh-thread-index-id-map))
         (id-index (gethash id mh-thread-id-index-map))
         (duplicates (gethash id mh-thread-duplicates)))
    (remhash index mh-thread-index-id-map)
    (cond ((and (eql index id-index) (null duplicates))
           (remhash id mh-thread-id-index-map))
          ((eql index id-index)
           (setf (gethash id mh-thread-id-index-map) (car duplicates))
           (setf (gethash (car duplicates) mh-thread-index-id-map) id)
           (setf (gethash id mh-thread-duplicates) (cdr duplicates)))
          (t
           (setf (gethash id mh-thread-duplicates)
                 (remove index duplicates))))))

(provide 'mh-seq)

;;; Local Variables:
;;; sentence-end-double-space: nil
;;; End:

;;; mh-seq.el ends here
