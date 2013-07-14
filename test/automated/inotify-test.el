;;; inotify-tests.el --- Test suite for inotify. -*- lexical-binding: t -*-

;; Copyright (C) 2012-2013 Free Software Foundation, Inc.

;; Author: Rüdiger Sonderfeld <ruediger@c-plusplus.de>
;; Keywords:       internal
;; Human-Keywords: internal

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

(require 'ert)

(declare-function inotify-add-watch "inotify.c" (file-name aspect callback))
(declare-function inotify-rm-watch "inotify.c" (watch-descriptor))

(when (featurep 'inotify)

  ;; (ert-deftest filewatch-file-watch-aspects-check ()
  ;;   "Test whether `file-watch' properly checks the aspects."
  ;;   (let ((temp-file (make-temp-file "filewatch-aspects")))
  ;;     (should (stringp temp-file))
  ;;     (should-error (file-watch temp-file 'wrong nil)
  ;;                   :type 'error)
  ;;     (should-error (file-watch temp-file '(modify t) nil)
  ;;                   :type 'error)
  ;;     (should-error (file-watch temp-file '(modify all-modify) nil)
  ;;                   :type 'error)
  ;;     (should-error (file-watch temp-file '(access wrong modify) nil)
  ;;                   :type 'error)))

  (ert-deftest inotify-file-watch-simple ()
    "Test if watching a normal file works."
    (let ((temp-file (make-temp-file "inotify-simple"))
	   (events 0))
      (let ((wd
	     (inotify-add-watch temp-file t (lambda (_ev)
                                              (setq events (1+ events))))))
	(unwind-protect
	    (progn
	      (with-temp-file temp-file
		(insert "Foo\n"))
	      (sit-for 5) ;; Hacky. Wait for 5s until events are processed
	      (should (> events 0)))
	  (inotify-rm-watch wd)))))
)

(provide 'inotify-tests)
;;; inotify-tests.el ends here.
