;; org-config.el -*- lexical-binding: t; -*-

;; To export to markdown
(require 'ox-md)
(setq org-latex-compiler "xelatex")


(setq org-latex-pdf-process
      '("xelatex -interaction nonstopmode -output-directory %o %f"
        "xelatex -interaction nonstopmode -output-directory %o %f"))

(setq org-directory "~/Desktop/org")
(setq org-default-notes-file (concat org-directory "/notes.org"))

;; Code Syntax highlighting in export
(setq org-latex-listings 'minted)
(setq org-latex-pdf-process
      '("xelatex -shell-escape -interaction nonstopmode -output-directory %o %f"
        "xelatex -shell-escape -interaction nonstopmode -output-directory %o %f"))

;; Font
(setq org-latex-packages-alist
      '(("" "xeCJK" t)
        ("" "minted" t)))

;; Bullet rendering
(setq org-startup-indented t)
(setq org-hide-emphasis-markers t)

(provide 'org-config)
