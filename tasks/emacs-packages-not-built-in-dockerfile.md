# Emacs packages are not installed or compiled in the Dockerfile

**Status:** in progress
**Priority:** 3
**Difficulty:** 1
Created 2026-11-08 (William Emerison Six <billsix@gmail.com> asked for it).
**Part of:** github.com/billsix/runClaudeInContainer `tasks/emacs-contract-conformance.md` (item 1, the
build-time MELPA install, and item 5, the run-time compile).

## BLUF

Under `USE_EMACS=1` the image build downloads and byte-compiles the whole MELPA set
(`emacs --batch --load install-melpa-packages.el`), although `make shell` mounts the vendored packages
over it. Done = the image installs only the Emacs binary, `init.el` byte-compiles the vendored `elpa/`
on Emacs's first start, `make image` builds with no MELPA fetch, and Emacs starts cleanly against the
mount.

## Context

- The Emacs contract: the `emacs-container-contract.md` reference doc in
  github.com/billsix/runClaudeInContainer `tasks/reference/`. Worked example: github.com/billsix/Craft
  `tasks/archive/2026/11/08/emacs-packages-not-built-in-dockerfile.md`.
- Today: `entrypoint/02-install-emacs.sh` installs the binary, but the `Dockerfile` also copies
  `install-melpa-packages.el` and runs `emacs --batch --load` on it in the install `RUN`. The Makefile
  mounts the whole `.emacs.d/` over `/root/.emacs.d`, so the build-time packages are never used.
  `init.el` has no run-time compile.
- Decision: keep the whole-`.emacs.d` mount. The image bakes no Emacs config, so config edits stay live
  without `make image`.

## Plan

1. `Dockerfile`: drop the `emacs --batch` step and the `install-melpa-packages.el` `COPY`; fix the
   comments, here and in `entrypoint/02-install-emacs.sh`.
2. `init.el`: `(byte-recompile-directory package-user-dir 0)` after `(package-initialize)`.
3. Makefile comments and `CLAUDE.md`/`README.md` where they describe the build-time install.

## Verification

- `make image` (default flags): no MELPA fetch; `/usr/bin/emacs` present; no `/root/.emacs.d/elpa`.
- `make shell-exec CMD='emacs --batch -l /root/.emacs.d/init.el ...'`: exits 0, compiles `.elc` into
  the host `elpa/`, `git status` clean.
- `tools/check_helm_file_at_point.sh` (runClaudeInContainer): 7/7.

## Open questions

None.
