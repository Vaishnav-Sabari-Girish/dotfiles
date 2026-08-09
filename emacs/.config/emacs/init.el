;;; init.el -*- lexical-binding: t; -*-

;; Startup screen disable
(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)

;; package-manager (MELPA)
(require 'package)
(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

;; use-package
(require 'use-package)
(setq use-package-always-ensure t)

;; Load path for split config files
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; Backup stuff (Emacs noise)
(setq auto-save-list-file-prefix "/tmp/emacs/auto-save-list/.saves-")
(setq backup-directory-alist '(("." . "/tmp/emacs/backups")))
(setq auto-save-file-name-transforms '((".*" "/tmp/emacs/auto-saves/" t)))

;; y/n instead of yes/no
(setq use-short-answers t)

;; Load split modules
(require 'ui)
(require 'custom-vars)
(require 'keybinds)
(require 'packages)
