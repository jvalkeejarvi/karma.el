;;; karma.el --- Karma Test Runner Emacs Integration
;;
;; Filename: karma.el
;; Description: karma Test Runner Emacs Integration
;; Author: Samuel Tonini
;; Maintainer: Juuso Valkeejärvi
;; URL: http://github.com/jvalkeejarvi/karma.el
;; Version: 0.6.0
;; Package-Requires: ((pkg-info "0.4") (emacs "24.4"))
;; Keywords: language, javascript, js, karma, testing

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;  Karma Test Runner Emacs Integration

;;  Usage:

;;    You need to create an `.karma` file inside your project directory to inform
;;    Karma.el where to get the Karma config file and the Karma executable.

;;    Example .karma file:

;;      {
;;        "config-file": "karma.coffee",
;;        "karma-command": "node_modules/karma/bin/karma"
;;      }

;;    The `config-file` and the `karma-command` paths need to be relative or absoulte
;;    to the your project directory.

;;; Code:

(require 'compile)
(require 'ansi-color)
(require 'json)
(require 'subr-x)
(require 'pkg-info)

(defgroup karma nil
  "Karma Test Runner Emacs Integration"
  :prefix "karma-"
  :group 'applications
  :link '(url-link :tag "Github" "https://github.com/jvalkeejarvi/karma.el")
  :link '(emacs-commentary-link :tag "Commentary" "karma"))

(defcustom karma-config-file ".karma"
  ""
  :type 'string
  :group 'karma)

(defun karma-command ()
  "Return the shell command for karma from the .karma config file"
  (expand-file-name (gethash "karma-command" (karma-project-config)) (karma-project-root)))

(defun karma-config-file-path ()
  "Return the path to the karma config file"
  (expand-file-name (gethash "config-file" (karma-project-config)) (karma-project-root)))

(defun karma-project-config ()
  (let* ((json-object-type 'hash-table)
         (karma-config (json-read-from-string
                        (with-temp-buffer
                          (insert-file-contents (format "%s/%s" (karma-project-root) karma-config-file))
                          (buffer-string)))))
    karma-config))

(defun karma-mode-hook ()
  "Hook which enables `karma-mode'"
  (karma-mode 1))

(defvar karma-start-buffer-name "*karma start*"
  "Name of the karma server output buffer.")

(defvar karma-run-buffer-name "*karma run*"
  "Name of the karma run output buffer.")

(defvar karma-buffers-to-ask-saving-for "[^*]*\.\\(js\\|html\\)"
  "Buffers name of which match this regexp will be asked to save before running tests")

(defvar karma-spec-file-extension ".spec"
  "Extension of test files")

(defun karma--flatten (alist)
  (cond ((null alist) nil)
        ((atom alist) (list alist))
        (t (append (karma--flatten (car alist))
                   (karma--flatten (cdr alist))))))

(defun karma--build-runner-cmdlist (command)
  "Build the commands list for the runner."
  (remove "" (karma--flatten
              (list (if (stringp command)
                        (split-string command)
                      command)))))

(defvar karma--project-root-indicators
  '("package.json" "bower.json")
  "list of file-/directory-names which indicate a root of a elixir project")

(defun karma-project-root ()
  (let ((file (file-name-as-directory (expand-file-name default-directory))))
    (karma--project-root-identifier file karma--project-root-indicators)))

(defun karma--project-root-identifier (file indicators)
  (let ((root-dir (if indicators (locate-dominating-file file (car indicators)) nil)))
    (cond (root-dir (directory-file-name (expand-file-name root-dir)))
          (indicators (karma--project-root-identifier file (cdr indicators)))
          (t nil))))

(defun karma--get-root-directory ()
  "Set the default-directory to the karma used project root."
  (let ((project-root (karma-project-root)))
    (if (not project-root)
        (error "Couldn't find any project root")
      project-root)))

(defvar karma-buffer--buffer-name nil
  "Used to store compilation name so recompilation works as expected.")
(make-variable-buffer-local 'karma-buffer--buffer-name)

;; (defvar karma-buffer--error-link-options
;;   '(karma "\\([-A-Za-z0-9./_]+\\):\\([0-9]+\\)\\(: warning\\)?" 1 2 nil (3) 1)
;;   "File link matcher for `compilation-error-regexp-alist-alist' (matches path/to/file:line).")

(defun karma-buffer--kill-any-orphan-proc ()
  "Ensure any dangling buffer process is killed."
  (let ((orphan-proc (get-buffer-process (buffer-name))))
    (when orphan-proc
      (kill-process orphan-proc))))

(define-compilation-mode karma-buffer-mode "Karma"
  "Karma compilation mode."
  (progn
    (font-lock-add-keywords nil
                            '(("^Finished in .*$" . font-lock-string-face)
                              ("^Karma.*$" . font-lock-string-face)))
    ;; Set any bound buffer name buffer-locally
    (setq karma-buffer--buffer-name karma-buffer--buffer-name)
    (set (make-local-variable 'kill-buffer-hook)
         'karma-buffer--kill-any-orphan-proc)))

(defvar karma-buffer--save-buffers-predicate
  (lambda ()
    (string-match karma-buffers-to-ask-saving-for (buffer-name)))) ;

(defun karma-compilation-run (cmdlist buffer-name &optional client-cmd-list)
  "Run CMDLIST in `buffer-name'.
Returns the compilation buffer.
Argument BUFFER-NAME for the compilation."
  (save-some-buffers (not compilation-ask-about-save) karma-buffer--save-buffers-predicate)
  (let* ((karma-buffer--buffer-name buffer-name)
         (compilation-filter-start (point-min))
         (command-to-run (add-client-cmd-to-list (mapconcat 'shell-quote-argument cmdlist " ") client-cmd-list)))
    (compilation-start command-to-run
                       'karma-buffer-mode
                       (lambda (b) karma-buffer--buffer-name)))
  (setq next-error-last-buffer (current-buffer)))

(defun add-client-cmd-to-list (cmd &optional client-cmd-list)
  (if client-cmd-list
    (concat cmd " -- " client-cmd-list)
    cmd))

(defun karma-start ()
  "Run `karma start CONFIG-FILE`."
  (interactive)
  (karma-execute (list "start" (karma-config-file-path))
                 karma-start-buffer-name))

(defun karma-start-single-run ()
  "Run `karma start CONFIG-FILE --single-run`"
  (interactive)
  (karma-execute (list "start" (karma-config-file-path) "--single-run")
                 karma-start-buffer-name))

(defun karma-start-no-single-run ()
  "Run `karma start CONFIG-FILE --no-single-run`"
  (interactive)
  (karma-execute (list "start" (karma-config-file-path) "--no-single-run")
                 karma-start-buffer-name))

(defun karma-previous-spec ()
  (interactive)
  (re-search-backward "^\\s-*[xf]?\\(describe\\|it\\)("))

(defun get-current-spec ()
  (interactive)
  (save-excursion
    (end-of-line)
    (re-search-backward "^\\s-*[xf]?\\(describe\\|it\\)(")
    (get-block-description)))

(defun get-block-description()
  (let ((line (thing-at-point 'line t)))
    (string-match "\\(\"\\(.*\\)\"\\|'\\(.*\\)'\\)" line)
    (let ((match1 (match-string 2 line))
          (match2 (match-string 3 line))
          )
      (if match1
          match1
        (if match2
            match2)))))

(defun get-first-describe ()
  (interactive)
  (save-excursion
    (beginning-of-buffer)
    (re-search-forward "^\\s-*[xf]?\\(describe\\)(")
    (get-block-description)))

(defun karma-run-current-test ()
  "Run `karma run` for current describe/it"
  (interactive)
  (let ((current-spec (get-current-spec)))
    (karma-run-grep current-spec "Couldn't find current it/describe")))

(defun karma-run-file ()
  "Run `karma run` for current files top level describe"
  (interactive)
  (let ((first-describe (get-first-describe)))
    (karma-run-grep first-describe "Couldn't find describe block in file")))

(defun karma-run-grep (pattern error-message)
  (if pattern
      (karma-execute (list "run"
                           (karma-config-file-path))
                     karma-run-buffer-name
                     (format "--grep=\"%s\"" pattern))
    (message "%s" (propertize error-message 'face '(:foreground "red")))))

(defun karma-run ()
  "Run `karma run`"
  (interactive)
  (karma-execute (list "run" (karma-config-file-path))
                 karma-run-buffer-name))

(defun karma-execute (cmdlist buffer-name &optional client-cmd-list)
  "Run a karma command."
  (let ((default-directory (karma--get-root-directory)))
    (message default-directory)
    (karma-compilation-run
     (karma--build-runner-cmdlist (list (karma-command) cmdlist))
     buffer-name client-cmd-list)))

(defun karma-pop-to-start-buffer ()
  (interactive)
  (let ((buffer (get-buffer karma-start-buffer-name)))
    (when buffer
      (pop-to-buffer buffer))))

(defun karma-open-related-file ()
  (interactive)
  (find-file (karma-get-related-file-name)))

(defun karma-get-related-file-name ()
  (let ((file-name (file-name-sans-extension buffer-file-name))
        (file-extension (file-name-extension buffer-file-name)))
    (if (string-suffix-p karma-spec-file-extension file-name t)
        (concat (string-remove-suffix karma-spec-file-extension file-name)  "." file-extension)
      (concat file-name karma-spec-file-extension "." file-extension))))

(defvar karma-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c , t") 'karma-start)
    (define-key map (kbd "C-c , s s") 'karma-start-single-run)
    (define-key map (kbd "C-c , n s") 'karma-start-no-single-run)
    (define-key map (kbd "C-c , r") 'karma-run)
    (define-key map (kbd "C-c , p") 'karma-pop-to-start-buffer)
    (define-key map (kbd "C-c , c") 'karma-run-current-test)
    (define-key map (kbd "C-c , f") 'karma-run-file)
    (define-key map (kbd "C-c , j") 'karma-open-related-file)
    map)
  "The keymap used when `karma-mode' is active.")

;;;###autoload
(defun karma-version (&optional show-version)
  "Get the Karma version as string.

If called interactively or if SHOW-VERSION is non-nil, show the
version in the echo area and the messages buffer.

The returned string includes both, the version from package.el
and the library version, if both a present and different.

If the version number could not be determined, signal an error,
if called interactively, or if SHOW-VERSION is non-nil, otherwise
just return nil."
  (interactive (list t))
  (let ((version (pkg-info-version-info 'karma)))
    (when show-version
      (message "Karma version: %s" version))
    version))

;;;###autoload
(define-minor-mode karma-mode
  "Toggle karma mode.

Key bindings:
\\{karma-mode-map}"
  nil
  ;; The indicator for the mode line.
  " karma"
  :group 'karma
  :global nil
  :keymap 'karma-mode-map)

(add-hook 'js-mode-hook 'karma-mode-hook)
(add-hook 'js2-mode-hook 'karma-mode-hook)
(add-hook 'coffee-mode-hook 'karma-mode-hook)
(add-hook 'typescript-mode-hook 'karma-mode-hook)

(provide 'karma)

;;; karma.el ends here
