;; Packages
(use-package which-key
  :init
  (which-key-mode))

(use-package company
  :init
  (global-company-mode t)
  :config
  (setq company-idle-delay 0.1)
  (setq company-minimum-prefix-length 1)
  (setq company-selection-wrap-around t))

(provide 'packages)
