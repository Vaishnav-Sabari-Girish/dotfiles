;;; packages.el --- Package management -*- lexical-binding: t; -*-
;;; which-key
(use-package which-key
  :init
  (which-key-mode))

;;; Autosuggestions
(use-package company
  :init
  (global-company-mode t)
  :config
  (setq company-idle-delay 0.1)
  (setq company-minimum-prefix-length 1)
  (setq company-selection-wrap-around t))

;;; file tree
(use-package treemacs
  :bind
  ("C-c f" . treemacs)
  ("C-c p a" . treemacs-add-project-to-workspace)
  ("C-c p r" . treemacs-remove-project-from-workspace)
  :config
  (add-hook 'treemacs-mode-hook (lambda () (treemacs-follow-mode t))))

;; Discord RPC
(use-package elcord
  :config
  (elcord-mode))

;; Rust mode
(use-package rust-mode)

;; Lua mode
(use-package lua-mode)

;; D mode
(use-package d-mode)

;; Brainfuck mode
(use-package brainfuck-mode)

;; Amber mode
(unless (version< emacs-version "26")
  (add-to-list 'load-path "~/dotfiles/emacs/.config/emacs/amber-mode/")
  (autoload 'amber-mode "amber-mode" nil t)
  (add-to-list 'auto-mode-alist '("\\.ab\\'" . amber-mode)))

;; Change ansi-term to ghostel
(use-package ghostel
  :ensure t)

;; Multiple cursors
(use-package multiple-cursors)

;; Markdown support
;; Markdown support (md-mode, Org-style)
(use-package md-mode
  :vc (:url "https://github.com/yibie/md-mode"
	    :rev :newest))
(add-to-list 'auto-mode-alist '("\\.md\\'" . md-mode))

;; Move text
(use-package move-text)
(move-text-default-bindings)

;; Git changes
(use-package diff-hl
  :ensure t
  :init
  ;; Enable it globally
  (global-diff-hl-mode)
  :config
  ;; Update the highlights on the fly
  (diff-hl-flydiff-mode 1)
  (unless (display-graphic-p)
    (diff-hl-margin-mode 1)))

(provide 'packages)
