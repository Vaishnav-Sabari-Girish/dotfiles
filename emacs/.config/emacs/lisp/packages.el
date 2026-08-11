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

;; Discord RPC
(use-package elcord)
(elcord-mode)

;; Rust mode
(use-package rust-mode)

;; Lua mode
(use-package lua-mode)

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

;; RSS feeds
(use-package elfeed
  :bind ("C-c w" . elfeed)
  :config
  (setq-default elfeed-search-filter "@2days +unread")
  (setq elfeed-feeds
        '("https://andrewkelley.me/rss.xml"
          "https://blog.orhun.dev/rss"
          "https://blog.rust-embedded.org/rss.xml"
          "https://blog.vaishnavs.is-a.dev/atom.xml"
          "https://carlosbecker.com/index.xml"
          "https://cliffle.com/rss.xml"
          "https://corrode.dev/rss.xml"
          "https://crescentro.se/posts/rss.xml"
          "https://eli.thegreenplace.net/feeds/all.atom.xml"
          "https://embeddedartistry.com/feed/"
          "https://fabiensanglard.net/rss.xml"
          "https://fasterthanli.me/index.xml"
          "https://ferrous-systems.com/blog/feed.xml"
          "https://interrupt.memfault.com/feed.xml"
          "https://keithp.com/blog/index.rss"
          "https://kristoff.it/index.xml"
          "https://lemire.me/blog/feed/"
          "https://lwn.net/headlines/rss"
          "https://mitchellh.com/feed.xml"
          "https://nullprogram.com/feed/"
          "https://opensourcepledge.com/rss.xml"
          "https://os.phil-opp.com/rss.xml"
          "https://oxide.computer/blog/feed"
          "https://preshing.com/feed"
          "https://terminaltrove.com/blog.xml"
          "https://terminaltrove.com/new.xml"
          "https://www.pro-110-119.jp/news_cat/news_info/feed/"
          "https://xn--gckvb8fzb.com/index.xml"
          "https://rss.beehiiv.com/feeds/LyzGmG4pKl.xml"
	  "https://this-week-in-rust.org/rss.xml")))

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
