# Emacs packages are not installed or compiled in the Dockerfile

Done 2026-11-08 (William Emerison Six <billsix@gmail.com> asked for it). Part of github.com/billsix/runClaudeInContainer
`tasks/emacs-contract-conformance.md` (the build-time MELPA install and the run-time compile items).

## What was wrong

`entrypoint/02-install-emacs.sh` installed the Emacs binary, but the `Dockerfile` also copied
`install-melpa-packages.el` and ran `emacs --batch --load` on it under `USE_EMACS=1`: a network download
plus byte-compile of the MELPA set at image build. `make shell` then mounted the vendored
`entrypoint/dotfiles/.emacs.d/` over `/root/.emacs.d`, so the result was never used.

## What changed

- `Dockerfile`: the `emacs --batch` step and the `install-melpa-packages.el` `COPY` are gone; its comment
  and `entrypoint/02-install-emacs.sh`'s header say the packages are vendored and compiled at run time.
- `init.el` runs `(byte-recompile-directory package-user-dir 0)` after `(package-initialize)`; the first
  Emacs start in `make shell` compiles the vendored packages into the mounted host `elpa/` (gitignored).
- Kept the whole-`.emacs.d` mount: the image bakes no Emacs config, so config edits stay live.
- The Makefile's `ELPA_MOUNT` comment describes this.

## Verification (2026-11-08, nested podman in the runClaudeInContainer sandbox)

- `make image` (default flags) succeeded with no MELPA fetch; the image-build `meson test` and the
  sanitizer gate each: 2 ok, 0 fail. The image has `/usr/bin/emacs` and no `/root/.emacs.d`.
- Emacs in batch with the Makefile's `.emacs.d` mount, `--network=none`
  (runClaudeInContainer `tasks/adhoc/emacs-no-build-time-compile/emacs-start-check.sh`): exit 0, 315 `.elc`
  in the host `elpa/`; `git status` showed only this change.
- `tools/check_helm_file_at_point.sh` (runClaudeInContainer): 7/7.
- Found, not fixed:
  - Contract-level: the run-time compile logs `Cannot open load file … compat-macs.el` for compat's
    `compat-26.el`…`compat-30.el` on every start; harmless on Emacs 31.
  - Existing config issue: `init.el`'s `use-package clang-format` binds into `c-mode-base-map` before
    cc-mode loads (`Error (use-package): clang-format/:catch: … c-mode-base-map`); the contract's form is
    `:after cc-mode`.
