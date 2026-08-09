;;; ui.el -*- lexical-binding: t; -*-

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

(set-face-attribute 'default nil
                     :font "JetBrains Mono Nerd Font"
                     :height 180)

(add-to-list 'default-frame-alist '(undecorated . t))

(use-package nord-theme
  :config
  (load-theme 'nord t))

(global-display-line-numbers-mode t)
(global-hl-line-mode t)

(provide 'ui)
