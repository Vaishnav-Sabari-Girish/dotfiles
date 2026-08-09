;;; keybinds.el -*- lexical-binding: t; -*-

;; Open terminal buffer
(global-set-key (kbd "C-c t") (lambda () (interactive) (ansi-term "/usr/bin/env zsh")))

;; Run shell command inline
(global-set-key (kbd "C-c s") 'shell-command)

(provide 'keybinds)
