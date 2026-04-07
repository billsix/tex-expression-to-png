;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "magit" "20260406.2006"
  "A Git porcelain inside Emacs."
  '((emacs         "28.1")
    (compat        "30.1")
    (cond-let      "0.2")
    (llama         "1.0")
    (magit-section "4.5")
    (seq           "2.24")
    (transient     "0.12")
    (with-editor   "3.4"))
  :url "https://github.com/magit/magit"
  :commit "61950fca5e31c9a33d839b3994d93be6d370fb4c"
  :revdesc "61950fca5e31"
  :keywords '("git" "tools" "vc")
  :authors '(("Marius Vollmer" . "marius.vollmer@gmail.com")
             ("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
                 ("Kyle Meyer" . "kyle@kyleam.com")))
