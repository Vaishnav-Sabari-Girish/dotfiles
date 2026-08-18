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

;; Background-only transparency (text stays fully opaque)
;; 0 = fully transparent, 100 = fully opaque. 70–85 is a good range.
(set-frame-parameter nil 'alpha-background 85)
(add-to-list 'default-frame-alist '(alpha-background . 85))

(add-hook 'after-make-frame-functions
          (lambda (frame)
            (set-frame-parameter frame 'alpha-background 85)))

(setq nord-region-highlight "snowstorm")

(use-package nord-theme
  :config
  (defun my/load-nord-theme (&optional frame)
    "Load Nord theme, optionally for a specific FRAME (daemon-safe)."
    (when frame
      (select-frame frame))
    (load-theme 'nord t))

  ;; Load immediately for non-daemon, and on every new frame for daemon
  (if (daemonp)
      (add-hook 'after-make-frame-functions #'my/load-nord-theme)
    (my/load-nord-theme)))

;; Startup screen
;; Startup screen variables
(setq inhibit-startup-screen t)
(setq inhibit-startup-message t)
(setq inhibit-startup-echo-area-message (user-login-name))
(setq initial-scratch-message nil)

(defun my-draw-startup-screen (&rest _)
  "Calculate terminal dimensions and draw the centered text."
  (let ((w (get-buffer-window "*startup*")))
    ;; Only execute if the *startup* buffer is actively visible in a window
    (when w
      (with-current-buffer "*startup*"
        (let ((inhibit-read-only t)
              (text "Vaishnav's Emacs"))
          (erase-buffer)
          
          ;; Fetch the true dimensions of the specific window displaying the buffer
          (let* ((w-height (window-body-height w))
                 (w-width (window-body-width w))
                 (v-pad (max 0 (/ w-height 2)))
                 (text-len (length text))
                 (h-pad (max 0 (/ (- w-width text-len) 2))))
            
            ;; Insert the precise amount of padding
            (insert (make-string v-pad ?\n))
            (insert (make-string h-pad ?\s))
            (insert text)))))))

(defun my-minimal-startup-screen ()
  "Initialize the stripped-down startup buffer."
  (let ((buf (get-buffer-create "*startup*")))
    (with-current-buffer buf
      (fundamental-mode)
      
      ;; Strip away UI elements
      (when (bound-and-true-p display-line-numbers-mode)
        (display-line-numbers-mode -1))
      (setq-local cursor-type nil)
      (setq-local mode-line-format nil)
      
      (setq buffer-read-only t))
    buf))

;; Set the initial buffer
(setq initial-buffer-choice #'my-minimal-startup-screen)

;; Hook the drawing function to run after the frame fully initializes
(add-hook 'window-setup-hook #'my-draw-startup-screen)

;; Hook the drawing function to run whenever the window is resized
(add-hook 'window-size-change-functions #'my-draw-startup-screen)

;; Ghostel — match Nord palette (deferred until ghostel loads)
(with-eval-after-load 'ghostel
  (set-face-attribute 'ghostel-default nil
                      :foreground "#D8DEE9"
                      :background "#2E3440")
  (set-face-attribute 'ghostel-color-black nil :foreground "#3B4252")
  (set-face-attribute 'ghostel-color-bright-black nil :foreground "#4C566A")
  (set-face-attribute 'ghostel-color-red nil :foreground "#BF616A")
  (set-face-attribute 'ghostel-color-bright-red nil :foreground "#BF616A")
  (set-face-attribute 'ghostel-color-green nil :foreground "#A3BE8C")
  (set-face-attribute 'ghostel-color-bright-green nil :foreground "#A3BE8C")
  (set-face-attribute 'ghostel-color-yellow nil :foreground "#EBCB8B")
  (set-face-attribute 'ghostel-color-bright-yellow nil :foreground "#EBCB8B")
  (set-face-attribute 'ghostel-color-blue nil :foreground "#81A1C1")
  (set-face-attribute 'ghostel-color-bright-blue nil :foreground "#88C0D0")
  (set-face-attribute 'ghostel-color-magenta nil :foreground "#B48EAD")
  (set-face-attribute 'ghostel-color-bright-magenta nil :foreground "#B48EAD")
  (set-face-attribute 'ghostel-color-cyan nil :foreground "#8FBCBB")
  (set-face-attribute 'ghostel-color-bright-cyan nil :foreground "#8FBCBB")
  (set-face-attribute 'ghostel-color-white nil :foreground "#E5E9F0")
  (set-face-attribute 'ghostel-color-bright-white nil :foreground "#ECEFF4"))

(global-display-line-numbers-mode t)
(global-hl-line-mode t)

(provide 'ui)
