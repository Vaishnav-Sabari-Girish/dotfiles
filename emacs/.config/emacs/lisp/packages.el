;; Packages
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

;; Rust mode
(use-package rust-mode)

(provide 'packages)
