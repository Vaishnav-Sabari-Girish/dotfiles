;;; amber-mode.el --- A major mode for the Amber programming language -*- lexical-binding: t -*-

;; Author: Georgios Davakos (GeorgGD) <georgios.davakos@protonmail.com>
;; Maintainer: Georgios Davakos (GeorgGD) <georgios.davakos@protonmail.com>
;; Created: 2026
;; Version: 1.1.0
;; Package-Requires: ((emacs "26.1"))
;; URL: https://codeberg.org/GeorgGD/amber-mode
;; Keywords: amber, languages

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; A major mode for the Amber programming languages.

;; See documentation on https://codeberg.org/GeorgGD/amber-mode

;;; Code:

(require 'syntax)

(defcustom amber-amber-bin "amber"
  "Path to Amber executable."
  :type 'file
  :safe #'stringp)

(defun amber--run-cmd (cmd &optional source &rest args)
  "Use compile command to execute an Amber CMD with ARGS if given.
If given a SOURCE, execute the CMD on it."
  (let ((cmd-args (if source (cons source args) args))
        (default-directory (project-root (project-current))))
    (save-some-buffers)
    (compilation-start (mapconcat 'shell-quote-argument
                                  `(,amber-amber-bin ,cmd ,@cmd-args) " "))))

(defun amber-relative-path ()
  "Return the relative path from project root to current buffer."
  (let* ((root (project-root (project-current)))
         (file (buffer-file-name))
         (relative-path (file-relative-name file root)))
    (if (and root file)
        (file-relative-name file root)
      (error "Not in a project or buffer is not visiting a file"))))

;;;###autoload
(defun amber-check ()
  "Checks the Amber script for error."
  (interactive)
  (amber--run-cmd "check" (amber-relative-path)))

;;;###autoload
(defun amber-test ()
  "Runs the Amber tests."
  (interactive)
  (amber--run-cmd "test" (amber-relative-path)))

;;;###autoload
(defun amber-run ()
  "Executes the Amber script."
  (interactive)
  (amber--run-cmd "run" (amber-relative-path)))

;;;###autoload
(defun amber-build ()
  "Compile the Amber script to Bash."
  (interactive)
  (amber--run-cmd "build" (amber-relative-path)))

(defvar amber-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c c") #'amber-check)
    (define-key map (kbd "C-c C-c t") #'amber-test)
    (define-key map (kbd "C-c C-c r") #'amber-run)
    (define-key map (kbd "C-c C-c b") #'amber-build)
    map)
  "Keymap for Amber major mode.")

(defconst amber-keywords
  '("fun" "let" "return" "const" "ref" "pub" "import" "from" "main" "as" "test"
    "if" "else" "and" "not" "then" "is" "or"
    "fail" "failed" "trust" "silent" "succeeded" "exited"
    "loop" "for" "in" "break" "continue" "while"))

(defconst amber-types
  '("Text" "Num" "Bool" "Null" "Int"))

(defconst amber-consts
  '("true" "false" "null"))

(defconst amber-builtins
  '("cd" "echo" "exit" "len" "lines" "mv" "nameof" "await" "cp" "rm" "sleep"
    "touch" "lock" "clear" "pwd" "pid" "disown" "shellname" "shellversion"))

(defconst amber--font-lock-defaults
  `(((,(regexp-opt amber-keywords 'symbols) . font-lock-keyword-face)
     (,(regexp-opt amber-consts 'symbols) . font-lock-constant-face)
     (,(regexp-opt amber-types 'symbols) . font-lock-type-face)
     (,(regexp-opt amber-builtins 'symbols) . font-lock-builtin-face)

     ("\\_<fun\\_>[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1 font-lock-function-name-face)
     ("\\_<\\([A-Za-z_][A-Za-z0-9_]*\\)[ \t]*(" 1 font-lock-function-name-face)
     ("\\_<let\\_>[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1 font-lock-variable-name-face)
     ("\\_<const\\_>[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" 1 font-lock-variable-name-face)
     ("\\([[:alpha:]_][[:alnum:]_]*\\)\\(?:\\s-*:\\s-*\\([^,)]*\\)\\)?" 1 font-lock-variable-name-face)
     ("//[/!][^/]" 1 font-lock-doc-face)
     )))

(defun amber-calculate-indentation ()
  "Return the column to which the current line should be indented."
  (* tab-width (min (car (syntax-ppss (line-beginning-position)))
                    (car (syntax-ppss (line-end-position))))))

(defun amber-indent-line ()
  "Indent current line."
  (interactive)
  (let ((savep (> (current-column) (current-indentation)))
        (indent (condition-case nil (max (amber-calculate-indentation) 0)
                  (error 0))))
    (if savep
        (save-excursion (indent-line-to indent))
      (indent-line-to indent))))

(defun amber-mode-syntax-table ()
  "Syntax table for `amber-mode'."
  (let ((table (make-syntax-table)))

    (dolist (i '(?+ ?- ?* ?/ ?% ?| ?= ?< ?> ?,))
      (modify-syntax-entry i "." table))

    (modify-syntax-entry ?/  ". 12" table)
    (modify-syntax-entry ?\n ">" table)

    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\' "\"" table)
    (modify-syntax-entry ?\\ "\\" table)

    ;; Curly braces for interpolation
    (modify-syntax-entry ?{ "(}" table)
    (modify-syntax-entry ?} "){" table)

    (modify-syntax-entry ?$ "\"" table)
    table))

;;;###autoload
(define-derived-mode amber-mode prog-mode "Amber"
  "A major mode for the Amber programming language."
  :syntax-table (amber-mode-syntax-table)
  (setq-local comment-start "// ")
  (setq-local comment-start-skip "//+ *")
  (setq-local comment-end "")
  (setq font-lock-defaults amber--font-lock-defaults)
  (setq-local indent-line-function 'amber-indent-line)
  (setq-local tab-width 4)
  (setq-local indent-tabs-mode t))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ab\\'" . amber-mode))

(provide 'amber-mode)

;;; amber-mode.el ends here
