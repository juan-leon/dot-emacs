;; © Juan-Leon Lahoz 199x - 2013

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Pre-config stuff

;; Just for avoid unimportant compilation warnings
(eval-when-compile
  (setq byte-compile-warnings '(not unresolved free-vars)))

(defvar env-dir "~/personal/")
(defun env-dir (dir)
  (concat env-dir dir))

(add-to-list 'load-path (env-dir "emacs/packages"))
(add-to-list 'load-path "/usr/share/git-core/emacs")
(and (file-exists-p (env-dir "emacs/config/custom.el"))
     (load-file (setq custom-file (env-dir "emacs/config/custom.el"))))

(when (require 'package nil t)
  (add-to-list 'package-archives
               '("marmalade" . "http://marmalade-repo.org/packages/") t)
  (add-to-list 'package-archives
               '("melpa" . "http://melpa.milkbox.net/packages/") t)
  (add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") t)
  (package-initialize))

;; For shorter keybindings
(defmacro command (&rest body)
  `(lambda ()
     (interactive)
     ,@body))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Looks

(when (display-graphic-p)
  (set-face-attribute 'default nil :font "DejaVu Sans Mono" :height 98)
  (setq frame-title-format '(buffer-file-name " %f" " %b")
        default-frame-alist '((width . 160)
                              (height . 58)
                              (tool-bar-lines . 0))))

(tool-bar-mode           0)
(blink-cursor-mode       0)
(transient-mark-mode     0)
(auto-compression-mode   1)
(auto-image-file-mode    1)
(show-paren-mode         1)
(size-indication-mode    1)
(file-name-shadow-mode   1)
(temp-buffer-resize-mode 1)

(defvar toggle-theme-state nil)
(defun toggle-theme ()
  "Toggle dark/light theme"
  (interactive)
  (if (setq toggle-theme-state (not toggle-theme-state))
      (color-theme-sanityinc-solarized-light)
    (color-theme-sanityinc-solarized-dark)))

(toggle-theme)
(global-set-key [(control ~)] 'toggle-theme)

(setq font-lock-support-mode 'jit-lock-mode
      jit-lock-stealth-time 5
      jit-lock-stealth-nice 0.25)

(setq indicate-buffer-boundaries t)

(defadvice x-set-selection (after replicate-selection (type data) activate)
  "Different applications use different data sources"
  (if (equal type 'CLIPBOARD)
      (x-set-selection 'PRIMARY data)))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Backups

;; No more autosaves
(setq auto-save-list-file-prefix nil
      auto-save-interval 0
      auto-save-timeout nil
      auto-save-list-file-name nil)

;; No more backups like ~
(setq backup-directory-alist `(("" . ,(env-dir "history/autosaved/"))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Bookmarks

;; Buffers
(global-set-key [(control Scroll_Lock)] 'bm-toggle)
(global-set-key [(shift Scroll_Lock)]   'bm-previous)
(global-set-key [(Scroll_Lock)]         'bm-next)

;; Files
(defadvice bookmark-set (around load-save activate)
  "Avoid race conditions in macros when working with multiple emacs instances"
  (bookmark-load bookmark-default-file t t)
  ad-do-it
  (bookmark-save))

(global-set-key [(super b)] 'bookmark-bmenu-list)
(global-set-key [(super B)] 'bookmark-set)

;; Files again (fast bookmarks)
(global-set-key [(control meta ?1)] (command (find-file (env-dir "emacs/config"))))
(global-set-key [(control meta ?2)] (command (find-file "~/repos")))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Windows

;; Switching "windows"
(global-set-key [(control next)]     'windmove-down)
(global-set-key [(control prior)]    'windmove-up)
(global-set-key [(control kp-6)]     'windmove-right)
(global-set-key [(control kp-4)]     'windmove-left)
(global-set-key [(control kp-right)] 'windmove-right)
(global-set-key [(control kp-left)]  'windmove-left)
(defadvice windmove-do-window-select (around silent-windmove activate)
  "Do not beep when no suitable window is found."
  (condition-case () ad-do-it (error nil)))

(defun toggle-split ()
  "Toggle vertical/horizontal window split."
  (interactive)
  (let ((buff-B (window-buffer (next-window)))
        (height (window-body-height))
        (width  (window-body-width)))
    (delete-other-windows)
    (if (> height (/ width 5))
        (split-window-vertically)
      (split-window-horizontally))
    (set-window-buffer (next-window) buff-B)))

(global-set-key [(control pause)] 'toggle-split)
(global-set-key [(pause)] 'delete-other-windows)

;; Windows configurations
(winner-mode 1)
(define-key winner-mode-map [(super prior)] 'winner-undo)
(define-key winner-mode-map [(super next)]  'winner-redo)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Bufferss

(global-set-key [(control x) (control b)] 'ibuffer)
(setq ibuffer-formats '((mark modified read-only
                              " " (name 35 35)
                              " " (size 9 9 :right)
                              " " (mode 18 18 :left :elide)
                              " " filename-and-process)
                        (mark " " (name 30 -1) " " filename)))

;; Switching buffers in same "window" again
(if (require 'buffer-stack nil t)
    (progn
      (add-to-list 'buffer-stack-untracked "*Backtrace*")
      (global-set-key [(meta kp-4)]     'buffer-stack-up)
      (global-set-key [(meta kp-left)]  'buffer-stack-up)
      (global-set-key [(meta kp-6)]     'buffer-stack-down)
      (global-set-key [(meta kp-right)] 'buffer-stack-down)
      (global-set-key [(meta kp-2)]     'buffer-stack-bury)
      (global-set-key [(meta kp-down)]  'buffer-stack-bury)
      (global-set-key [(meta kp-8)]     'buffer-stack-untrack)
      (global-set-key [(meta kp-up)]    'buffer-stack-untrack)
      (defvar buffer-stack-mode)
      (defun buffer-op-by-mode (op &optional mode)
        (let ((buffer-stack-filter 'buffer-stack-filter-by-mode)
              (buffer-stack-mode (or mode major-mode)))
          (funcall op)))
      (defun buffer-stack-filter-by-mode (buffer)
        (with-current-buffer buffer
          (equal major-mode buffer-stack-mode)))
      (global-set-key [(meta kp-7)]
                      (command (buffer-op-by-mode 'buffer-stack-up)))
      (global-set-key [(meta kp-9)]
                      (command (buffer-op-by-mode 'buffer-stack-down)))
      (global-set-key [(meta kp-3)]
                      (command (buffer-op-by-mode 'buffer-stack-down 'dired-mode)))
      (global-set-key [(meta kp-1)]
                      (command (buffer-op-by-mode 'buffer-stack-up 'dired-mode))))
  (progn
   (global-set-key [(meta kp-4)]     'bury-buffer)
   (global-set-key [(meta kp-6)]     'bury-buffer)
   (global-set-key [(meta kp-left)]  'bury-buffer)
   (global-set-key [(meta kp-right)] 'bury-buffer)))

;; Better names for dups
(require 'uniquify)
(setq uniquify-buffer-name-style 'post-forward-angle-brackets)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Prog modes (C/C++/Java/python/...)

(eval-after-load "cc-mode"
  '(progn
     (defun leon-c-mode-setup()
       (setq indicate-empty-lines t)
       (c-toggle-electric-state t)
       (c-toggle-hungry-state t)
       (setq ff-search-directories '("." "include" "../include")))
     (add-hook 'c-mode-common-hook 'leon-c-mode-setup)
     (add-hook 'java-mode-hook (lambda ()
                                 (setq c-basic-offset 4
                                       tab-width 4
                                       indent-tabs-mode t)))
     (when (require 'xcscope nil t)
       (add-hook 'c-mode-hook   'cscope-minor-mode)
       (add-hook 'c++-mode-hook 'cscope-minor-mode))
     (c-set-offset 'substatement-open 0)))


(add-hook 'prog-mode-hook '(lambda ()
                             (subword-mode t)
                             (hs-minor-mode t)
                             (local-set-key [(f3)]      'hs-show-block)
                             (local-set-key [(meta f3)] 'hs-hide-block)
                             (font-lock-add-keywords
                              nil '(("\\(\\<\\|_\\)\\(FIXME\\|TODO\\|HACK\\)"
                                     2 font-lock-warning-face t)
                                    ("[{}]" 0 'font-lock-warning-face)))))

(defun indent-by-shell-command ()
  (interactive)
  (when (and buffer-read-only
             (memq major-mode '(c-mode c++-mode)))
    (let ((buffer-modified-p (buffer-modified-p))
          (inhibit-read-only t)
          (line (line-number-at-pos)))
      (shell-command-on-region (point-min) (point-max) "indent" nil t nil)
      (set-buffer-modified-p buffer-modified-p)
      (goto-char (point-min))
      (forward-line (1- line)))))

(global-set-key [(control meta return)] 'ff-find-other-file)
(global-set-key [(control kp-f3)]       'ff-find-other-file)
(global-set-key [(super ?+)]            'imenu-add-menubar-index)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Calendar stuff

(setq calendar-week-start-day     1
      calendar-mark-holidays-flag t)

(setq calendar-holidays (append
                         ;; Fixed
                         '((holiday-fixed 1 1 "New Year's Day")
                           (holiday-fixed 1 6 "Reyes")
                           (holiday-easter-etc -2 "Jueves Santo")
                           (holiday-easter-etc -3 "Viernes Santo")
                           (holiday-fixed 5 1   "Dia del Trabajador")
                           (holiday-fixed 5 2   "Comunidad del Madrid")
                           (holiday-fixed 10 12 "National Day")
                           (holiday-fixed 12 6  "Constitution")
                           (holiday-fixed 12 25 "Christmas"))
                         ;, This year
                         '((holiday-fixed 1 7   "Traslado R. Magos")
                           (holiday-fixed 3 18  "S. Jose")
                           (holiday-fixed 8 15  "Asuncion")
                           (holiday-fixed 11 1  "All Saints")
                           (holiday-fixed 11 9  "Almudena"))))

(global-set-key [(control f4)] 'calendar)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Compilation

(global-set-key [(f8)]         'compile)
(global-set-key [(control f6)] 'recompile)
(global-set-key [(control f8)]
                (command (let ((buf (get-buffer "*compilation*")))
                           (and buf (switch-to-buffer buf)))))

(global-set-key [(super f7)]      'previous-error)
(global-set-key [(super f8)]      'next-error)
(global-set-key [(super meta f7)] 'previous-error-no-select)
(global-set-key [(super meta f8)] 'next-error-no-select)

(setq next-error-highlight-no-select 2.0
      next-error-highlight 'fringe-arrow)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Debugging

(global-set-key [(f12)] 'gdb)

(eval-after-load "gdb-mi"
  '(progn
     (add-hook 'gdb-mode-hook 'leon-gud-hook)
     (global-set-key [(f5)]      'leon-gud-print)
     (global-set-key [(meta f5)] 'leon-gud-print-ref)
     (global-set-key [(f6)]      'leon-gud-up)
     (global-set-key [(meta f6)] 'leon-gud-down)
     (global-set-key [(f7)]      'leon-gud-next)
     (global-set-key [(meta f7)] 'leon-gud-step)
     (defun leon-gud-hook()
       (setq comint-input-ring-file-name (env-dir "history/gud_history"))
       (comint-read-input-ring t)
       (make-local-variable 'kill-buffer-hook)
       (add-hook 'kill-buffer-hook 'comint-write-input-ring)
       (gud-def leon-gud-print      "print %e"   nil)
       (gud-def leon-gud-print-ref  "print * %e" nil)
       (gud-def leon-gud-next       "next"       nil)
       (gud-def leon-gud-step       "step"       nil)
       (gud-def leon-gud-cont       "cont"       nil)
       (gud-def leon-gud-run        "run"        nil)
       (gud-def leon-gud-up         "up"         nil)
       (gud-def leon-gud-down       "down"       nil)
       (local-set-key  [(f4)]      'gdb-many-windows)
       (local-set-key  [(meta f4)] 'gdb-restore-windows)
       (local-set-key  [(f8)]      'leon-gud-cont)
       (local-set-key  [(meta f8)] 'leon-gud-run))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Differences

(defvar compare-map (lookup-key global-map [?\C-=]))
(unless (keymapp compare-map)
  (setq compare-map (make-sparse-keymap))
  (global-set-key [(control ?=)] compare-map)
  (define-key compare-map "b" 'ediff-buffers)
  (define-key compare-map "e" 'ediff-files)
  (define-key compare-map "f" 'ediff-files)
  (define-key compare-map "d" 'diff)
  (define-key compare-map "w" 'compare-windows))

(setq ediff-window-setup-function 'ediff-setup-windows-plain
      ediff-split-window-function 'split-window-horizontally
      ediff-diff-options          " -bB ")

(setq-default ediff-ignore-similar-regions t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Dired stuff


(eval-after-load "dired"
  '(progn
     (defun leon-dired-hide-hidden()
       (interactive)
       (let ((dired-actual-switches "-l"))
         (revert-buffer)))
     (defun leon-dired-parent-directory()
       (interactive)
       (dired (concat (dired-current-directory) "..")))
     (setq dired-copy-preserve-time nil
           dired-recursive-copies   'always)
     (autoload 'dired-efap "dired-efap")
     (autoload 'dired-efap-click "dired-efap")
     (define-key dired-mode-map [?r] 'wdired-change-to-wdired-mode)
     (define-key dired-mode-map [?U] 'dired-unmark-backward)
     (define-key dired-mode-map [?a] 'leon-dired-hide-hidden)
     (define-key dired-mode-map [f2] 'dired-efap)
     (define-key dired-mode-map [down-mouse-1] 'dired-efap-click)
     (define-key dired-mode-map [(control return)] 'dired-find-alternate-file)
     (define-key dired-mode-map [(backspace)] 'leon-dired-parent-directory)
     (define-key dired-mode-map [(control backspace)] 'dired-unmark-backward)
     (require 'dired-x)))

(add-hook 'dired-mode-hook
          (lambda ()
            (dired-omit-mode 1)))

(add-hook 'dired-after-readin-hook
          (lambda ()
            (set (make-local-variable 'frame-title-format)
                 (dired-current-directory))))

(autoload 'dired-jump "dired")
(global-set-key [(control ?x) (control ?d)] 'dired-jump)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Emacs Lisp

(define-key emacs-lisp-mode-map [(f8)]
  (command (byte-compile-file (buffer-file-name))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Minimize keystrokes for writing

(mapc #'(lambda (arg) (global-set-key arg 'hippie-expand))
      '([(super tab)] [(meta ?º)] [(meta VoidSymbol)] [(control VoidSymbol)]))

(global-set-key [C-tab]        'complete-tag)

(setq hippie-expand-try-functions-list
      '(try-expand-dabbrev
        try-complete-file-name-partially
        try-complete-file-name
        try-expand-all-abbrevs
        try-expand-dabbrev-all-buffers
        try-expand-dabbrev-from-kill
        try-complete-lisp-symbol-partially
        try-complete-lisp-symbol
        try-expand-line
        try-expand-list))

(if (require 'auto-complete-config nil t)
    (ac-config-default))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Text stuff

(add-hook 'text-mode-hook
          (lambda ()
            (auto-fill-mode 1)
            (setq tab-width 4)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; General purpose variables

(setq column-number-mode           t
      confirm-kill-emacs           'y-or-n-p ; "Fast fingers protection"
      major-mode                   'text-mode
      enable-local-eval            'query
      garbage-collection-messages  t
      x-select-enable-clipboard    t
      inhibit-startup-message      t
      message-log-max              2500
      large-file-warning-threshold 2000000
      undo-ask-before-discard      nil
      track-eol                    t
      whitespace-line-column       100
      kill-do-not-save-duplicates  t
      disabled-command-function    nil ; Warnings already read
      visible-bell                 t)

(setq-default indent-tabs-mode nil
              tab-width        2
              fill-column      80
              truncate-lines   t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Server

(setq server-window 'switch-to-buffer-other-frame
      server-done-hook 'delete-frame)

(run-with-idle-timer 5 nil (lambda ()
                             (require 'server)
                             (or (server-running-p) (server-start))))

(run-with-idle-timer 15 nil (lambda ()
                              (when (require 'edit-server nil t)
                                (edit-server-start))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Ido

(when (require 'ido nil t)
  (ido-everywhere 1)
  (ido-mode 1)
  (global-set-key [(control x) ?b]  'ido-switch-buffer)
  (global-set-key [(meta kp-5)]     'ido-switch-buffer)
  (global-set-key [(meta kp-begin)] 'ido-switch-buffer)
  (setq ido-case-fold                 nil
        ido-enable-tramp-completion   nil
        ido-save-directory-list-file (env-dir "history/ido.last")
        ido-auto-merge-delay-time     1
        ido-read-file-name-non-ido '(find-dired dired-do-copy)
        ido-slow-ftp-host-regexps    '("."))
  (define-key ido-common-completion-map [(meta kp-6)]   'ido-next-match)
  (define-key ido-common-completion-map [(meta kp-4)]   'ido-prev-match)
  (define-key ido-common-completion-map [(shift left)]  'ido-prev-work-file)
  (define-key ido-common-completion-map [(shift right)] 'ido-next-work-file)
  (define-key ido-common-completion-map [(shift up)]    'ido-prev-work-directory)
  (define-key ido-common-completion-map [(shift down)]  'ido-next-work-directory)
  (add-hook 'ido-minibuffer-setup-hook
            (lambda ()
              (if (memq ido-cur-item '(file dir))
                  (setq ido-enable-prefix t)
                (setq ido-enable-prefix nil)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Scroll stuff

;; Reduce number of surprise jumps
(setq scroll-step 1
      scroll-conservatively 1)

(require 'scroll-in-place nil t)

(when (require 'yascroll nil t)
  (set-scroll-bar-mode nil)
  (setq yascroll:delay-to-hide nil)
  (global-yascroll-bar-mode 1))

(global-set-key [(control l)] 'recenter)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Searchs

;; In the buffer
(setq isearch-allow-scroll t
      search-ring-max      32)

(set-default 'case-fold-search nil)
(set-default 'search-ring-update t)

(define-key isearch-mode-map [(control t)]    'isearch-toggle-case-fold)
(define-key isearch-mode-map [(control y)]    'isearch-yank-kill)
(define-key isearch-mode-map [(control w)]    'isearch-yank-word)
(define-key isearch-mode-map [(control up)]   'isearch-ring-retreat)
(define-key isearch-mode-map [(control down)] 'isearch-ring-advance)

(add-hook 'isearch-mode-end-hook
          (lambda () (if interprogram-cut-function
                         (funcall interprogram-cut-function isearch-string))))

(add-hook 'occur-mode-hook 'turn-on-occur-x-mode)

;; In files
(global-set-key [(super g)] 'grep)
(global-set-key [(super i)] 'rgrep)

;; At the filesystem
(global-set-key [(super l)] 'locate)
(global-set-key [(super L)] 'locate-with-filter)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Shell stuff

(eval-after-load "shell"
  '(progn
     (add-hook 'shell-mode-hook
               (lambda ()
                 (setq comint-input-ring-file-name (env-dir "history/shell_history"))
                 (add-hook 'kill-buffer-hook 'comint-write-input-ring nil t)))
     (defun shell-rename()
       (interactive)
       (if (eq major-mode 'shell-mode)
             (rename-buffer "shell" t)))
     (global-set-key            [(super z)]               'shell)
     (global-set-key            [(control x) (control z)] 'shell)
     (define-key shell-mode-map [(meta kp-up)]            'shell-rename)
     (define-key shell-mode-map [(meta kp-8)]             'shell-rename)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Git

(global-set-key [(super ?0)] 'magit-status)

(autoload 'git-blame-mode "git-blame" nil t)
(autoload 'egit           "egit" "Emacs git history" t)
(autoload 'egit-file      "egit" "Emacs git history file" t)
(autoload 'egit-dir       "egit" "Emacs git history directory" t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Generic keybindings


(global-set-key [(control return)] 'find-anything-at-point)
(global-set-key [(super r)]        'revert-buffer)
(global-set-key [(super a)]        'align)
(global-set-key [(super A)]        'align-regexp)
(global-set-key [(control f11)]    'kmacro-start-macro-or-insert-counter)
(global-set-key [(control f12)]    'kmacro-end-or-call-macro)
(global-set-key [(super y)]        'browse-kill-ring)
(global-set-key [(super h)]        'htmlize-buffer)
(global-set-key [(control delete)] 'kill-whole-line)
(global-set-key [(meta up)]        'backward-list)
(global-set-key [(meta down)]      'forward-list)
(global-set-key [(super up)]       'prev-function-name-face)
(global-set-key [(super down)]     'next-function-name-face)
(global-set-key [(control ?c) ?l]  'goto-line)
(global-set-key [(meta ?g)]        'goto-line)
(global-set-key [(super m)]        'man)
(global-set-key [(meta return)]    'find-tag)
(global-set-key [(control ?,)]     'list-tags)
(global-set-key [(control ?.)]     'tags-apropos)
(global-set-key [(super f)]        'auto-fill-mode)

(global-set-key [(control backspace)] (command (kill-line 0)))

(when (require 'subword nil t)
  (global-set-key [(meta left)]  'subword-backward)
  (global-set-key [(meta right)] 'subword-forward))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Tramp


(require 'tramp)
(add-to-list 'tramp-default-proxies-alist
             '(nil "\\`root\\'" "/ssh:%h:"))
(add-to-list 'tramp-default-proxies-alist
             '((regexp-quote (system-name)) nil nil))
(add-to-list 'tramp-default-proxies-alist
             '("localhost" nil nil))


(defun sudo-powerup ()
  (interactive)
  (if buffer-file-name
      (find-alternate-file
       (if (tramp-tramp-file-p buffer-file-name)
           (progn
             (string-match "^/\\w*:" buffer-file-name)
             (replace-match "/sudo:" nil nil buffer-file-name))
         (concat "/sudo:root@localhost:" buffer-file-name)))))

(global-set-key [(control ?x) (control ?r)] 'sudo-powerup)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; SQL stuff

(setq sql-database             "nprobe"
      sql-server               "localhost"
      sql-user                 "root"
      sql-input-ring-file-name (env-dir "history/sql_history"))

(add-to-list 'same-window-buffer-names "*SQL*")

(global-set-key [(meta f4)] 'sql-mysql)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; Misc stuff

(defun find-anything-at-point ()
  "Find the variable or function or file at point."
  (interactive)
  (cond ((not (eq (variable-at-point) 0))
         (call-interactively 'describe-variable))
        ((function-called-at-point)
         (call-interactively 'describe-function))
        (t
         (call-interactively 'find-file-at-point))))


;; Changes in the default emacs behaviour
(global-set-key [(control z)]             'undo)             ; I really hate to minimize emacs:
(global-set-key [(control x) ?k]          'kill-this-buffer) ; No more "¿which buffer?"
(global-set-key [(control x) (control k)] 'kill-this-buffer) ; No more "no keyboard macro defined"

(fset 'yes-or-no-p 'y-or-n-p)
(setq warning-suppress-types '((undo discard-info)))


;; This way is easy to choose if "_" is a word separator
(defun leon-toggle-underscore-syntax ()
  "Switch the char _ in-word behaviour."
  (interactive)
  (modify-syntax-entry ?_ (if (= (char-syntax ?_) ?_) "w" "_"))
  (message (concat "\"_\" is " (if (= (char-syntax ?_) ?_) "symbol" "word"))))

(global-set-key [(super f1)] 'leon-toggle-underscore-syntax)


;; To move the cursor to func definition
(defun next-function-name-face ()
  "Point to next `font-lock-function-name-face' text."
  (interactive)
  (let ((pos (point)))
    (if (eq (get-text-property pos 'face) 'font-lock-function-name-face)
      (setq pos (or (next-property-change pos) (point-max))))
    (setq pos (text-property-any pos (point-max) 'face
                                 'font-lock-function-name-face))
    (if pos
        (goto-char pos)
      (goto-char (point-max)))))

(defun prev-function-name-face ()
  "Point to previous `font-lock-function-name-face' text."
  (interactive)
  (let ((pos (point)))
    (if (eq (get-text-property pos 'face) 'font-lock-function-name-face)
      (setq pos (or (previous-property-change pos) (point-min))))
    (setq pos (previous-property-change pos))
    (while (and pos (not (eq (get-text-property pos 'face)
                             'font-lock-function-name-face)))
      (setq pos (previous-property-change pos)))
    (if pos
        (progn
          (setq pos (previous-property-change pos))
          (goto-char (or (and pos (1+ pos)) (point-min))))
      (goto-char (point-min)))))


;; Numbering help
(autoload 'gse-number-rectangle "gse-number-rect" "" t)
(global-set-key [(control ?x) ?r ?u] 'gse-number-rectangle)


;; Lines
(defun leon-toggle-truncate-lines ()
  (interactive)
  (setq truncate-lines (not truncate-lines))
  (redraw-frame (selected-frame))
  (message (concat "truncate lines " (if truncate-lines "enabled" "disabled"))))

(global-set-key [(super f2)] 'leon-toggle-truncate-lines)


(eval-after-load "help-mode"
  '(define-key help-mode-map [backspace] 'help-go-back))

(eval-after-load "comint"
  '(defadvice comint-previous-input (around move-free (arg) activate)
     "No more 'Not at command line'"
     (if (comint-after-pmark-p)
         ad-do-it
       (backward-paragraph arg))))

(setq Man-notify-method `pushy)

(add-hook 'latex-mode-hook (lambda () (setq fill-column 100)))
(add-hook 'elisp-mode-hook (lambda () (setq fill-column 75)))

(require 'sr-speedbar)
(setq sr-speedbar-right-side nil)
(global-set-key [(super a)] 'sr-speedbar-toggle)


(run-with-idle-timer 10 nil (lambda ()
                              (require 'midnight)
                              (setq clean-buffer-list-delay-general 3)
                              (midnight-delay-set 'midnight-delay "1:10pm")))

