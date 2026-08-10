;;; init.el -*- lexical-binding: t; -*-

;; font stuff
(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)
(setq locale-coding-system 'utf-8)

;; Redirect Custom-generated code to lisp/custom-vars.el instead of init.el
(setq custom-file (expand-file-name "lisp/custom-vars.el" user-emacs-directory))
(load custom-file 'noerror)

;; Startup screen disable
(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)

;; Emacs server
(require 'server)
(unless (server-running-p)
  (server-start))

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
(let ((auto-save-dir "/tmp/emacs/auto-saves/")
      (auto-save-list-dir "/tmp/emacs/auto-save-list/")
      (backup-dir "/tmp/emacs/backups/"))
  (make-directory auto-save-dir t)
  (make-directory auto-save-list-dir t)
  (make-directory backup-dir t))
     
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
(require 'lsp)
(require 'org-config)
