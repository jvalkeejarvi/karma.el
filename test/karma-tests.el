;;; karma-tests.el --- karma.el ert unit tests
;;
;; Author: Samuel Tonini
;; Maintainer: Samuel Tonini
;; Description: karma Test Runner Emacs Integration
;; Maintainer: Juuso Valkeejärvi
;; URL: https://github.com/jvalkeejarvi/karma.el

;; This file is NOT part of GNU Emacs.

;; The MIT License (MIT)
;;
;; Copyright (c) Samuel Tonini
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy of
;; this software and associated documentation files (the "Software"), to deal in
;; the Software without restriction, including without limitation the rights to
;; use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
;; the Software, and to permit persons to whom the Software is furnished to do so,
;; subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
;; FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
;; COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
;; IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


;;; Commentary:

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'karma)

(ert-deftest test-karma-project-root/npm-file-exists ()
  (within-sandbox "lib/npm"
                  (f-touch "../../package.json")
                  (should (equal (karma-project-root) karma-sandbox-path))))

(ert-deftest test-karma-project-root/bower-file-exists ()
  (within-sandbox "lib"
                  (f-touch "../bower.json")
                  (should (equal (karma-project-root) karma-sandbox-path))))

(ert-deftest test-karma-project-root/npm-file-dont-exists ()
  (within-sandbox
   (should (equal (karma-project-root) nil))))

(ert-deftest test-flatten-of-list ()
  (should (equal (karma--flatten '(1 2 (3 4) 5))
                 '(1 2 3 4 5)))
  (should (equal (karma--flatten '(1 2 ("dude" "hero" (3)) 4 5))
                 '(1 2 "dude" "hero" 3 4 5))))

(ert-deftest test-establish-root-directory/no-root-exists ()
  (within-sandbox
   (should-error (karma--establish-root-directory))))

(ert-deftest test-build-compile-cmdlist ()
  (should (equal (karma--build-runner-cmdlist "karma")
                 '("karma")))
  (should (equal (karma--build-runner-cmdlist '("karma" "run"))
                 '("karma" "run")))
  (should (equal (karma--build-runner-cmdlist "karma start --help")
                 '("karma" "start" "--help")))
  (should (equal (karma--build-runner-cmdlist '("karma" "run" ""))
                 '("karma" "run"))))

(ert-deftest test-karma-get-related-file ()
  (let ((buffer-file-name "/home/user/test.file.spec.js"))
    (should (equal (karma-get-related-file-name) "/home/user/test.file.js"))
    )
  (let ((buffer-file-name "/home/user/test.file.js"))
    (should (equal (karma-get-related-file-name) "/home/user/test.file.spec.js"))
    )
  (let ((buffer-file-name "/home/user/test.file.ts"))
    (should (equal (karma-get-related-file-name) "/home/user/test.file.spec.ts"))
    )
  )

(ert-deftest test-get-current-spec ()
  (with-temp-buffer
    (insert "describe('test', )")
    (should (equal (get-current-spec) "test"))
    )
  (with-temp-buffer
    (insert "describe('test with spaces', )")
    (should (equal (get-current-spec) "test with spaces"))
    )
  (with-temp-buffer
    (insert "describe('test with spaces', function() {\n  it('sub test')\n  })")
    (should (equal (get-current-spec) "sub test"))
    )
  (with-temp-buffer
    (insert "describe('test with spaces', function() {\n  it('sub test not in current line', function() {)\n  var jee = 2\n}  \)")
    (should (equal (get-current-spec) "sub test not in current line"))
    )
  (with-temp-buffer
    (insert "describe('test containing \"quotes\"', )")
    (should (equal (get-current-spec) "test containing \"quotes\""))
    )
  (with-temp-buffer
    (insert "describe(\"test inside double quotes\", )")
    (should (equal (get-current-spec) "test inside double quotes"))
    )
  )

(provide 'karma-tests)

;;; karma-tests.el ends here
