# Reconcile the Emacs C LSP config (lsp-mode vs eglot; missing clang-format)

**Status:** in progress — both source edits applied 2026-07-09; elpa regen pending
**Created:** 2026-07-09

## Goal

The vendored Emacs config configures the C language server two ways at once and
binds a formatter whose package isn't installed. Pick one LSP client and make
the `clang-format` binding real.

**Correction (2026-07-09):** this is *not* shared with Bill's canonical dotfiles.
The canonical config at `/foo/opt/dotfiles/.emacs.d/` is clean — `bills-preferences.el`
hooks eglot only to `python-mode`/`emacs-lisp-mode`, and it drives C via a separate
`c++-mode.el` (`add-hook 'c-mode-hook 'lsp`), with no clang-format block. The
double-hook and the dangling clang-format binding are **local to texExpToPng's
diverged copy** of `init.el`/`preferences.el`. So the fix is texExpToPng-only;
there is nothing to port back to canonical.

## Findings

1. **Two LSP clients both hook `c-mode`/`c++-mode`.**
   - `entrypoint/dotfiles/.emacs.d/init.el` — `use-package lsp-mode :hook
     ((c-mode c++-mode) . lsp)` (plus `lsp-deferred` on `prog-mode-hook`, and
     `lsp-clients-clangd-executable "clangd"`).
   - `entrypoint/dotfiles/.emacs.d/preferences.el` — `use-package eglot :hook
     ((c-mode c++-mode) . eglot-ensure)`.
   - Both attach to the same C buffer. `init.el` already
     `(remove-hook 'python-mode-hook 'eglot-ensure)`, showing eglot was meant to
     be backed out — but preferences.el re-adds it for C/C++ (and emacs-lisp).

2. **`clang-format` package is never installed.** `init.el` has
   `use-package clang-format :bind (... "C-c f" . clang-format-buffer)`, but
   `clang-format` is not in the `package-selected-packages` list in
   `entrypoint/dotfiles/.emacs.d/install-melpa-packages.el`, so the binding can
   silently no-op.

## Plan

- [x] **Kept lsp-mode as the sole C client.** Removed the
      `(c-mode c++-mode) . eglot-ensure` hook from `preferences.el` (eglot now
      hooks emacs-lisp only). lsp-mode + clangd from `init.el` owns C/C++.
- [x] **Added `clang-format` to the MELPA package list** in
      `install-melpa-packages.el` so the `C-c f` binding resolves.
- [ ] **Regenerate the vendored elpa** via `make update-emacs-packages` so the
      committed `elpa/` actually contains `clang-format`. **Required for fix #2
      to work at runtime:** the Makefile bind-mounts the host `.emacs.d/elpa`
      over the image's, so the newly-added package is invisible until the
      committed tree is regenerated. Needs nested podman (available) + a full
      image rebuild — **not run yet; awaiting go-ahead** (it restages the whole
      vendored elpa tree via `git add -f`).

## Open questions

- Run `make update-emacs-packages` now to land clang-format in the committed
  elpa? (Heavy: rebuilds the image and restages the elpa tree.)
