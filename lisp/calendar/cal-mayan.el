;;; cal-mayan.el --- calendar functions for the Mayan calendars.

;; Copyright (C) 1992 Free Software Foundation, Inc.

;; Author: Stewart M. Clamen <clamen@cs.cmu.edu>
;;	Edward M. Reingold <reingold@cs.uiuc.edu>
;; Keywords: calendar
;; Human-Keywords: Mayan calendar, Maya, calendar, diary

;; This file is part of GNU Emacs.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY.  No author or distributor
;; accepts responsibility to anyone for the consequences of using it
;; or for whether it serves any particular purpose or works at all,
;; unless he says so in writing.  Refer to the GNU Emacs General Public
;; License for full details.

;; Everyone is granted permission to copy, modify and redistribute
;; GNU Emacs, but only under the conditions described in the
;; GNU Emacs General Public License.   A copy of this license is
;; supposed to have been given to you along with GNU Emacs so you
;; can know your rights and responsibilities.  It should be in a
;; file named COPYING.  Among other things, the copyright notice
;; and this notice must be preserved on all copies.

;;; Commentary:

;; This collection of functions implements the features of calendar.el and
;; diary.el that deal with the Mayan calendar.  It was written jointly by

;;  Stewart M. Clamen                School of Computer Science
;;  clamen@cs.cmu.edu                Carnegie Mellon University
;;                                   5000 Forbes Avenue
;;                                   Pittsburgh, PA 15213

;; and

;;  Edward M. Reingold               Department of Computer Science
;;  (217) 333-6733                   University of Illinois at Urbana-Champaign
;;  reingold@cs.uiuc.edu             1304 West Springfield Avenue
;;                                   Urbana, Illinois 61801

;; Comments, improvements, and bug reports should be sent to Reingold.

;; Technical details of the Mayan calendrical calculations can be found in
;; ``Calendrical Calculations, Part II: Three Historical Calendars''
;; by E. M. Reingold,  N. Dershowitz, and S. M. Clamen,
;; Software--Practice and Experience, Volume 23, Number 4 (April, 1993),
;; pages 383-404.

;;; Code:

(require 'calendar)

(defun mayan-adjusted-mod (m n)
  "Non-negative remainder of M/N with N instead of 0."
  (1+ (mod (1- m) n)))

(defconst calendar-mayan-days-before-absolute-zero 1137140
  "Number of days of the Mayan calendar epoch before absolute day 0.
According to the Goodman-Martinez-Thompson correlation.  This correlation is
not universally accepted, as it still a subject of astro-archeological
research.  Using 1232041 will give you the correlation used by Spinden.")

(defconst calendar-mayan-haab-at-epoch '(8 . 18)
  "Mayan haab date at the epoch.")

(defconst calendar-mayan-haab-month-name-array
  ["Pop" "Uo" "Zip" "Zotz" "Tzec" "Xul" "Yaxkin" "Mol" "Chen" "Yax"
   "Zac" "Ceh" "Mac" "Kankin" "Muan" "Pax" "Kayab" "Cumku"])

(defconst calendar-mayan-tzolkin-at-epoch '(4 . 20)
  "Mayan tzolkin date at the epoch.")

(defconst calendar-mayan-tzolkin-names-array
  ["Imix" "Ik" "Akbal" "Kan" "Chicchan" "Cimi" "Manik" "Lamat" "Muluc" "Oc"
   "Chuen" "Eb" "Ben" "Ix" "Men" "Cib" "Caban" "Etznab" "Cauac" "Ahau"])

(defun calendar-mayan-long-count-from-absolute (date)
  "Compute the Mayan long count corresponding to the absolute DATE."
  (let ((long-count (+ date calendar-mayan-days-before-absolute-zero)))
    (let* ((baktun (/ long-count 144000))
           (remainder (% long-count 144000))
           (katun (/ remainder 7200))
           (remainder (% remainder 7200))
           (tun (/ remainder 360))
           (remainder (% remainder 360))
           (uinal (/ remainder 20))
           (kin (% remainder 20)))
      (list baktun katun tun uinal kin))))

(defun calendar-mayan-long-count-to-string (mayan-long-count)
  "Convert MAYAN-LONG-COUNT into traditional written form."
  (apply 'format (cons "%s.%s.%s.%s.%s" mayan-long-count)))

(defun calendar-string-to-mayan-long-count (str)
  "Given STR, a string of format \"%d.%d.%d.%d.%d\", return list of nums."
  (let ((rlc nil)
        (c (length str))
        (cc 0))
    (condition-case condition
        (progn
          (while (< cc c)
            (let ((datum (read-from-string str cc)))
              (if (not (integerp (car datum)))
                  (signal 'invalid-read-syntax (car datum))
                (setq rlc (cons (car datum) rlc))
                (setq cc (cdr datum)))))
          (if (not (= (length rlc) 5)) (signal 'invalid-read-syntax nil)))
      (invalid-read-syntax nil))
    (reverse rlc)))

(defun calendar-mayan-haab-from-absolute (date)
  "Convert absolute DATE into a Mayan haab date (a pair)."
  (let* ((long-count (+ date calendar-mayan-days-before-absolute-zero))
         (day-of-haab
          (% (+ long-count
                (car calendar-mayan-haab-at-epoch)
                (* 20 (1- (cdr calendar-mayan-haab-at-epoch))))
             365))
         (day (% day-of-haab 20))
         (month (1+ (/ day-of-haab 20))))
    (cons day month)))

(defun calendar-mayan-haab-difference (date1 date2)
  "Number of days from Mayan haab DATE1 to next occurrence of haab date DATE2."
  (mod (+ (* 20 (- (cdr date2) (cdr date1)))
	  (- (car date2) (car date1)))
       365))

(defun calendar-mayan-haab-on-or-before (haab-date date)
  "Absolute date of latest HAAB-DATE on or before absolute DATE."
  (- date
     (% (- date
	   (calendar-mayan-haab-difference
	    (calendar-mayan-haab-from-absolute 0) haab-date))
	365)))

(defun calendar-next-haab-date (haab-date &optional noecho)
  "Move cursor to next instance of Mayan HAAB-DATE. 
Echo Mayan date if NOECHO is t."
  (interactive (list (calendar-read-mayan-haab-date)))
  (calendar-goto-date
   (calendar-gregorian-from-absolute
    (calendar-mayan-haab-on-or-before
     haab-date
     (+ 365
        (calendar-absolute-from-gregorian (calendar-cursor-to-date))))))
  (or noecho (calendar-print-mayan-date)))

(defun calendar-previous-haab-date (haab-date &optional noecho)
  "Move cursor to previous instance of Mayan HAAB-DATE. 
Echo Mayan date if NOECHO is t."
  (interactive (list (calendar-read-mayan-haab-date)))
  (calendar-goto-date
   (calendar-gregorian-from-absolute
    (calendar-mayan-haab-on-or-before
     haab-date
     (1- (calendar-absolute-from-gregorian (calendar-cursor-to-date))))))
  (or noecho (calendar-print-mayan-date)))

(defun calendar-mayan-haab-to-string (haab)
  "Convert Mayan haab date (a pair) into its traditional written form."
  (let ((month (cdr haab))
        (day (car haab)))
  ;; 19th month consists of 5 special days
  (if (= month 19)
      (format "%d Uayeb" day)
    (format "%d %s"
            day
            (aref calendar-mayan-haab-month-name-array (1- month))))))

(defun calendar-mayan-tzolkin-from-absolute (date)
  "Convert absolute DATE into a Mayan tzolkin date (a pair)."
  (let* ((long-count (+ date calendar-mayan-days-before-absolute-zero))
         (day (mayan-adjusted-mod
               (+ long-count (car calendar-mayan-tzolkin-at-epoch))
               13))
         (name (mayan-adjusted-mod
                (+ long-count (cdr calendar-mayan-tzolkin-at-epoch))
                20)))
    (cons day name)))

(defun calendar-mayan-tzolkin-difference (date1 date2)
  "Number of days from Mayan tzolkin DATE1 to next occurrence of tzolkin DATE2."
  (let ((number-difference (- (car date2) (car date1)))
        (name-difference (- (cdr date2) (cdr date1))))
    (mod (+ number-difference
	    (* 13 (mod (* 3 (- number-difference name-difference))
		       20)))
	 260)))

(defun calendar-mayan-tzolkin-on-or-before (tzolkin-date date)
  "Absolute date of latest TZOLKIN-DATE on or before absolute DATE."
  (- date
     (% (- date (calendar-mayan-tzolkin-difference
		 (calendar-mayan-tzolkin-from-absolute 0)
		 tzolkin-date))
	260)))

(defun calendar-next-tzolkin-date (tzolkin-date &optional noecho)
  "Move cursor to next instance of Mayan TZOLKIN-DATE. 
Echo Mayan date if NOECHO is t."
  (interactive (list (calendar-read-mayan-tzolkin-date)))
  (calendar-goto-date
   (calendar-gregorian-from-absolute
    (calendar-mayan-tzolkin-on-or-before
     tzolkin-date
     (+ 260
        (calendar-absolute-from-gregorian (calendar-cursor-to-date))))))
  (or noecho (calendar-print-mayan-date)))

(defun calendar-previous-tzolkin-date (tzolkin-date &optional noecho)
  "Move cursor to previous instance of Mayan TZOLKIN-DATE. 
Echo Mayan date if NOECHO is t."
  (interactive (list (calendar-read-mayan-tzolkin-date)))
  (calendar-goto-date
   (calendar-gregorian-from-absolute
    (calendar-mayan-tzolkin-on-or-before
     tzolkin-date
     (1- (calendar-absolute-from-gregorian (calendar-cursor-to-date))))))
  (or noecho (calendar-print-mayan-date)))

(defun calendar-mayan-tzolkin-to-string (tzolkin)
  "Convert Mayan tzolkin date (a pair) into its traditional written form."
  (format "%d %s"
          (car tzolkin)
          (aref calendar-mayan-tzolkin-names-array (1- (cdr tzolkin)))))

(defun calendar-mayan-tzolkin-haab-on-or-before (tzolkin-date haab-date date)
  "Absolute date that is Mayan TZOLKIN-DATE and HAAB-DATE.
Latest such date on or before DATE.
Returns nil if such a tzolkin-haab combination is impossible." 
  (let* ((haab-difference
          (calendar-mayan-haab-difference
           (calendar-mayan-haab-from-absolute 0)
           haab-date))
         (tzolkin-difference
          (calendar-mayan-tzolkin-difference
           (calendar-mayan-tzolkin-from-absolute 0)
           tzolkin-date))
         (difference (- tzolkin-difference haab-difference)))
    (if (= (% difference 5) 0)
        (- date
           (mod (- date
		   (+ haab-difference (* 365 difference)))
		18980))
      nil)))

(defun calendar-read-mayan-haab-date ()
  "Prompt for a Mayan haab date"
  (let* ((completion-ignore-case t)
         (haab-day (calendar-read
                    "Haab kin (0-19): "
                    '(lambda (x) (and (>= x 0) (< x 20)))))
         (haab-month-list (append calendar-mayan-haab-month-name-array 
                                  (and (< haab-day 5) '("Uayeb"))))
         (haab-month (cdr
                      (assoc
                       (capitalize
                        (completing-read "Haab uinal: "
                                         (mapcar 'list haab-month-list)
                                         nil t))
                       (calendar-make-alist
                        haab-month-list 1 'capitalize)))))
    (cons haab-day haab-month)))

(defun calendar-read-mayan-tzolkin-date ()
  "Prompt for a Mayan tzolkin date"
  (let* ((completion-ignore-case t)
         (tzolkin-count (calendar-read
                         "Tzolkin kin (1-13): "
                         '(lambda (x) (and (> x 0) (< x 14)))))
         (tzolkin-name-list (append calendar-mayan-tzolkin-names-array nil))
         (tzolkin-name (cdr
                        (assoc
                         (capitalize
                          (completing-read "Tzolkin uinal: " 
                                           (mapcar 'list tzolkin-name-list)
                                           nil t))
                         (calendar-make-alist
                          tzolkin-name-list 1 'capitalize)))))
    (cons tzolkin-count tzolkin-name)))

(defun calendar-next-calendar-round-date
  (tzolkin-date haab-date &optional noecho)
  "Move cursor to next instance of Mayan HAAB-DATE TZOKLIN-DATE combination.
Echo Mayan date if NOECHO is t."
  (interactive (list (calendar-read-mayan-tzolkin-date)
                     (calendar-read-mayan-haab-date)))
  (let ((date (calendar-mayan-tzolkin-haab-on-or-before
               tzolkin-date haab-date
               (+ 18980 (calendar-absolute-from-gregorian
                         (calendar-cursor-to-date))))))
    (if (not date)
        (error "%s, %s does not exist in the Mayan calendar round"
               (calendar-mayan-tzolkin-to-string tzolkin-date)
               (calendar-mayan-haab-to-string haab-date))
      (calendar-goto-date (calendar-gregorian-from-absolute date))
      (or noecho (calendar-print-mayan-date)))))

(defun calendar-previous-calendar-round-date
  (tzolkin-date haab-date &optional noecho)
  "Move to previous instance of Mayan TZOKLIN-DATE HAAB-DATE combination.
Echo Mayan date if NOECHO is t."
  (interactive (list (calendar-read-mayan-tzolkin-date)
                     (calendar-read-mayan-haab-date)))
  (let ((date (calendar-mayan-tzolkin-haab-on-or-before
               tzolkin-date haab-date
               (1- (calendar-absolute-from-gregorian
                    (calendar-cursor-to-date))))))
    (if (not date)
        (error "%s, %s does not exist in the Mayan calendar round"
               (calendar-mayan-tzolkin-to-string tzolkin-date)
               (calendar-mayan-haab-to-string haab-date))
      (calendar-goto-date (calendar-gregorian-from-absolute date))
      (or noecho (calendar-print-mayan-date)))))

(defun calendar-absolute-from-mayan-long-count (c)
  "Compute the absolute date corresponding to the Mayan Long Count C.
Long count is a list (baktun katun tun uinal kin)"
  (+ (* (nth 0 c) 144000)        ; baktun
     (* (nth 1 c) 7200)          ; katun
     (* (nth 2 c) 360)           ; tun
     (* (nth 3 c) 20)            ; uinal
     (nth 4 c)                   ; kin (days)
     (-                          ; days before absolute date 0
      calendar-mayan-days-before-absolute-zero)))

(defun calendar-print-mayan-date ()
  "Show the Mayan long count, tzolkin, and haab equivalents of date."
  (interactive)
  (let* ((d (calendar-absolute-from-gregorian
            (or (calendar-cursor-to-date)
                (error "Cursor is not on a date!"))))
         (tzolkin (calendar-mayan-tzolkin-from-absolute d))
         (haab (calendar-mayan-haab-from-absolute d))
         (long-count (calendar-mayan-long-count-from-absolute d)))
      (message "Mayan date: Long count = %s; tzolkin = %s; haab = %s"
               (calendar-mayan-long-count-to-string long-count)
               (calendar-mayan-tzolkin-to-string tzolkin)
               (calendar-mayan-haab-to-string haab))))

(defun calendar-goto-mayan-long-count-date (date &optional noecho)
  "Move cursor to Mayan long count DATE.  Echo Mayan date unless NOECHO is t."
  (interactive
   (let (lc)
     (while (not lc)
       (let ((datum
              (calendar-string-to-mayan-long-count 
               (read-string "Mayan long count (baktun.katun.tun.uinal.kin): "
                            (calendar-mayan-long-count-to-string
                             (calendar-mayan-long-count-from-absolute
                               (calendar-absolute-from-gregorian
                                (calendar-current-date))))))))
         (if (calendar-mayan-long-count-common-era datum)
             (setq lc datum))))
     (list lc)))
  (calendar-goto-date
   (calendar-gregorian-from-absolute
    (calendar-absolute-from-mayan-long-count date)))
  (or noecho (calendar-print-mayan-date)))
              
(defun calendar-mayan-long-count-common-era (lc)
  "T if long count represents date in the Common Era."
  (let ((base (calendar-mayan-long-count-from-absolute 1)))
    (while (and (not (null base)) (= (car lc) (car base)))
      (setq lc (cdr lc)
            base (cdr base)))
    (or (null lc) (> (car lc) (car base)))))

(defun diary-mayan-date ()
  "Show the Mayan long count, haab, and tzolkin dates as a diary entry."
  (let* ((d (calendar-absolute-from-gregorian date))
         (tzolkin (calendar-mayan-tzolkin-from-absolute d))
         (haab (calendar-mayan-haab-from-absolute d))
         (long-count (calendar-mayan-long-count-from-absolute d)))
    (format "Mayan date: Long count = %s; tzolkin = %s; haab = %s"
            (calendar-mayan-long-count-to-string  long-count)
            (calendar-mayan-tzolkin-to-string haab)
            (calendar-mayan-haab-to-string tzolkin))))

(provide 'cal-mayan)

;;; cal-mayan.el ends here
