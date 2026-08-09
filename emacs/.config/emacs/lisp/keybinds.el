;;; keybinds.el -*- lexical-binding: t; -*-

;; Open terminal buffer
(global-set-key (kbd "C-c t") 'ghostel)

;; Run shell command inline
(global-set-key (kbd "C-c s") 'shell-command)

;; Jump between delimiters
(global-set-key (kbd "C-%")
		(lambda () (interactive)
		  (cond ((looking-at "\\s(") (forward-sexp 1) (backward-char 1))
			((looking-at "\\s)") (forward-char 1) (backward-sexp 1))
			(t (message "Not on a bracket")))))

;; org-capture - note taking from anywhere
(global-set-key (kbd "C-c n") 'org-capture)

(provide 'keybinds)
