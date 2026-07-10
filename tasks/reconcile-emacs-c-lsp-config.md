# Reconcile the Emacs C LSP config (lsp-mode vs eglot; missing clang-format)

**Status:** proposed — needs go-ahead
**Created:** 2026-07-09

## Goal

The vendored Emacs config configures the C language server two ways at once and
binds a formatter whose package isn't installed. Pick one LSP client and make
the `clang-format` binding real. This is Bill's personal config that rides along
in this repo, so any fix here should also be carried back to the canonical
dotfiles — not just patched in texExpToPng.

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

- [ ] **Choose one C LSP client** and remove the other's `c-mode`/`c++-mode`
      hook. (Recommend keeping **lsp-mode** — init.el carries the fuller setup:
      explicit clangd executable, lsp-ui, company tuning. Then drop the
      `(c-mode c++-mode) . eglot-ensure` hook from preferences.el, leaving eglot
      for emacs-lisp only if desired.)
- [ ] **Add `clang-format` to the MELPA package list** in
      `install-melpa-packages.el` so the `C-c f` binding resolves — or remove
      the `use-package clang-format` block from init.el if the binding isn't
      wanted.
- [ ] **Regenerate the vendored elpa** via `make update-emacs-packages` if the
      package list changed, so the committed tree matches.
- [ ] **Port the same fixes to the canonical dotfiles** (the source of these
      files) so the drift doesn't reappear the next time this config is copied
      into a project.

## Open questions

- Keep lsp-mode or eglot for C? (Plan recommends lsp-mode; Bill's call.)
- Is the `C-c f` clang-format binding actually wanted, or should the block go?
