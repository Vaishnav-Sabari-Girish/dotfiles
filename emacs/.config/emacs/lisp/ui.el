;;; ui.el -*- lexical-binding: t; -*-

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

(set-face-attribute 'default nil
                     :font "JetBrainsMono Nerd Font"
                     :height 160)

;; Ensure Nerd Font icons (Private Use Area glyphs) render correctly
(set-fontset-font t '(#xe000 . #xf8ff) "JetBrainsMono Nerd Font")
(set-fontset-font t '(#xf0000 . #xffffd) "JetBrainsMono Nerd Font")
(set-fontset-font t '(#x100000 . #x10fffd) "JetBrainsMono Nerd Font")

(add-to-list 'default-frame-alist '(undecorated . t))

(use-package nord-theme
  :config
  (load-theme 'nord t))

(global-display-line-numbers-mode t)
(global-hl-line-mode t)

(provide 'ui)
