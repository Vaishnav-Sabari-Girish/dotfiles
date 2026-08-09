;;; lsp.el -*- lexical-binding: t; -*-

;; Eglot is built-in since Emacs 29, no use-package :ensure needed
(require 'eglot)

;; Auto-start eglot when opening files in these modes
(add-hook 'rust-mode-hook 'eglot-ensure)
(add-hook 'c-mode-hook 'eglot-ensure)
(add-hook 'c++-mode-hook 'eglot-ensure)
(add-hook 'sh-mode-hook 'eglot-ensure)

;; Explicitly tell eglot which server to use for bash
;; (rust-analyzer and clangd are auto-detected by eglot's defaults)
(add-to-list 'eglot-server-programs
             '(sh-mode . ("bash-language-server" "start")))

(provide 'lsp)
