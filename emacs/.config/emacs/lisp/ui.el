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

;; Ghostel — match Nord palette (deferred until ghostel loads)
(with-eval-after-load 'ghostel
  (set-face-attribute 'ghostel-default nil
                       :foreground "#D8DEE9"
                       :background "#2E3440")

  (set-face-attribute 'ghostel-color-black nil          :foreground "#3B4252")
  (set-face-attribute 'ghostel-color-bright-black nil   :foreground "#4C566A")
  (set-face-attribute 'ghostel-color-red nil            :foreground "#BF616A")
  (set-face-attribute 'ghostel-color-bright-red nil     :foreground "#BF616A")
  (set-face-attribute 'ghostel-color-green nil          :foreground "#A3BE8C")
  (set-face-attribute 'ghostel-color-bright-green nil   :foreground "#A3BE8C")
  (set-face-attribute 'ghostel-color-yellow nil         :foreground "#EBCB8B")
  (set-face-attribute 'ghostel-color-bright-yellow nil  :foreground "#EBCB8B")
  (set-face-attribute 'ghostel-color-blue nil           :foreground "#81A1C1")
  (set-face-attribute 'ghostel-color-bright-blue nil    :foreground "#88C0D0")
  (set-face-attribute 'ghostel-color-magenta nil        :foreground "#B48EAD")
  (set-face-attribute 'ghostel-color-bright-magenta nil :foreground "#B48EAD")
  (set-face-attribute 'ghostel-color-cyan nil           :foreground "#8FBCBB")
  (set-face-attribute 'ghostel-color-bright-cyan nil    :foreground "#8FBCBB")
  (set-face-attribute 'ghostel-color-white nil          :foreground "#E5E9F0")
  (set-face-attribute 'ghostel-color-bright-white nil   :foreground "#ECEFF4"))

(global-display-line-numbers-mode t)
(global-hl-line-mode t)

(provide 'ui)
