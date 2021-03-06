;; This file is a part of the aer forecasting system
;;
;; Copyright (c) 2010 Dmitry Matveev <dmatveev@inbox.com>

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;; THE SOFTWARE.


(defclass synoptic ()
  ((ahead :initform 1 :initarg :ahead)
   (extractor) (winter) (spring) (summer) (autumn)))

(defun worker-thread ()
  (locally (declare (special *worker* *output* *times*))
    (let ((*standard-output* *output*))
      (forecaster-train *worker* *times*))))

(defmethod initialize-instance :after ((instance synoptic) &key parameter
                                       winter-files spring-files
                                       summer-files autumn-files)
  (with-slots (winter spring summer autumn extractor ahead) instance
    (setq extractor (make-instance 'data-extractor :parameter parameter)
          winter (make-instance 'season-forecaster :parameter parameter :ahead ahead)
          spring (make-instance 'season-forecaster :parameter parameter :ahead ahead)
          summer (make-instance 'season-forecaster :parameter parameter :ahead ahead)
          autumn (make-instance 'season-forecaster :parameter parameter :ahead ahead))
    (apply #'forecaster-load-files (cons winter winter-files))
    (apply #'forecaster-load-files (cons spring spring-files))
    (apply #'forecaster-load-files (cons summer summer-files))
    (apply #'forecaster-load-files (cons autumn autumn-files))
    (forecaster-build winter)
    (forecaster-build spring)
    (forecaster-build summer)
    (forecaster-build autumn)))

(defun synoptic-train (instance out &optional (times 1500))
  (locally (declare (special *worker* *output* *times*))
    (let* ((slots '(winter spring summer autumn))
           (threads (loop :for worker :in slots :collect
                       (let ((bt:*default-special-bindings*
                              `((*worker* . ,(slot-value instance worker))
                                (*output* . ,out)
                                (*times*  . ,times))))
                         (bt:make-thread #'worker-thread)))))
      (loop while (some #'bt:thread-alive-p threads)
         do (bt:thread-yield)))))

(defun synoptic-forecaster-for (synoptic date)
  (slot-value synoptic (season-of date)))

(defun synoptic-forecast (instance target-date the-past-data &key (messages nil))
  (with-slots (extractor) instance
    (let* ((worker (synoptic-forecaster-for instance target-date))
           (policy (slot-value (slot-value worker 'store) 'policy))
           (input (encode-input-series the-past-data 7 (position-in-season target-date)
                                       extractor policy)))
      (forecaster-perform worker input :show-past messages :show-forecast messages))))
