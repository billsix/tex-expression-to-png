# Add a `make update-emacs-packages` target (vendored Emacs refresh)

**Status:** proposed — needs go-ahead
**Created:** 2026-06-13

## Goal

Give texExpToPng the same one-command "refresh + re-vendor the Emacs `elpa/` tree" workflow that
**geometricalgebra** already has: a `make update-emacs-packages` target that rebuilds the image,
wipes + reinstalls the MELPA packages into the host's bind-mounted `elpa/`, strips the
machine-specific compiled artifacts, and force-stages the tree so it's ready to commit.

texExpToPng vendors a real `elpa/` tree (541 files tracked in git) and has the `USE_EMACS`/`ELPA_MOUNT`
plumbing, but there is **no ergonomic way to update the vendored packages**. This task adds it.

## Reference implementation (copy from here)

geometricalgebra is the worked precedent. Read, in that repo:
- `Makefile` — the `update-emacs-packages` target and the comment block above `ELPA_MOUNT`.
- `tasks/archive/2026/06/07/emacs-package-install-strategy.md` — full rationale (why strip `*.elc`
  **and** `*.eln`; the Dockerfile build-time-install reconciliation).

## How texExpToPng currently stands (what differs from the reference — read carefully)

texExpToPng diverges from geometricalgebra/spimulator in **two** ways that change the recipe:

- **`ELPA_MOUNT` mounts the WHOLE `.emacs.d/`, not just `elpa/`** (`Makefile:33-37`):
  `-v $(CURDIR)/entrypoint/dotfiles/.emacs.d/:/root/.emacs.d/:U,z`. Consequences:
  - The wipe must be **scoped to the `elpa/` subdirectory only** —
    `find /root/.emacs.d/elpa -mindepth 1 -delete`. **Never** wipe the whole `.emacs.d/`, which also
    holds `init.el`, `install-melpa-packages.el`, `helm.el`, `preferences.el` (all tracked, hand-written).
  - The install script is **already inside the mount** (the whole `.emacs.d/` is bind-mounted RW), so
    — unlike geometricalgebra — there is **no need for a separate read-only mount** of
    `install-melpa-packages.el`. You can edit it on the host and the mounted copy reflects it.
  - The host-side strip + `git add -f` must target **`.emacs.d/elpa`** specifically, so you don't
    accidentally stage churn in the other `.el` files.
- **The Dockerfile does NOT copy the elpa tree into the image.** `Dockerfile:7` copies only
  `install-melpa-packages.el`; `Dockerfile:21-24` then runs
  `emacs --batch --load /root/.emacs.d/install-melpa-packages.el` at build time when `USE_EMACS=1`.
  So the image's packages come **entirely from the build-time install** (online w.r.t. MELPA), and the
  vendored git tree is used **only at runtime** via the whole-`.emacs.d/` mount. This is already
  halfway to geometricalgebra's end state (tree not baked in) but still does a build-time fetch.

Other facts:
- `Makefile:5` — `USE_EMACS=1` (defaults on). `Dockerfile:3` — `ARG USE_EMACS=0` (standard mirror).
- `CONTAINER_NAME = tex-expression-to-png`; the Makefile also threads `TMUX_MOUNT`.
- No `.dockerignore` elpa exclusion (and none needed, since the tree isn't copied).

## Proposed target (tailored to texExpToPng's whole-`.emacs.d/` mount)

```make
.PHONY: update-emacs-packages
update-emacs-packages: ## USE_EMACS=1: rebuild image, wipe+reinstall elpa, strip *.elc/*.eln, git add -f
	$(MAKE) image USE_EMACS=1
	$(CONTAINER_CMD) run --rm \
		-v $(CURDIR)/entrypoint/dotfiles/.emacs.d/:/root/.emacs.d/:U,z \
		--entrypoint /bin/bash \
		$(CONTAINER_NAME) \
		-c 'set -e; find /root/.emacs.d/elpa -mindepth 1 -delete; \
		    emacs --batch --load /root/.emacs.d/install-melpa-packages.el'
	cd $(CURDIR)/entrypoint/dotfiles/.emacs.d/elpa && \
		find . \( -iname '*.elc' -o -iname '*.eln' \) -delete && \
		git add -A -f .
	@echo "Done: reinstalled packages, stripped *.elc/*.eln, staged elpa -- review and commit."
```

Differences from the spimulator/geometricalgebra version, by design:
- Mounts the **whole `.emacs.d/`** (matching this repo's `ELPA_MOUNT`), so there's **no separate RO
  mount** of the install script — it rides along in the mount.
- The in-container wipe is scoped to `/root/.emacs.d/elpa` (the rest of `.emacs.d/` is config, leave it).
- Host strip + `git add -A -f` run **inside `.emacs.d/elpa`** so only the package tree is staged.
- If `elpa/` may be missing on a fresh checkout, optionally prefix the wipe with
  `mkdir -p /root/.emacs.d/elpa;` (the bind mount needs the host dir to exist; it's tracked here, so
  normally fine).

## Decisions to make (do not implement until chosen)

1. **Scope.** Just the `update-emacs-packages` target (recommended first), or also reconcile the
   build (#2)?
2. **Offline build?** Unlike spimulator, texExpToPng already doesn't bake the elpa tree into the image
   — but it *does* fetch from MELPA at build time. Options:
   (a) leave as-is (build stays online for Emacs packages, vendored tree used only at runtime — simplest);
   (b) follow geometricalgebra fully: drop the build-time `emacs --batch --load …` so the build is
   offline w.r.t. MELPA and the vendored tree is the sole source (then an interactive `USE_EMACS=1`
   session relies entirely on the runtime mount). Pick (a) or (b).
3. **Mount shape consistency.** Optionally narrow `ELPA_MOUNT` to `elpa/` only (like the other two
   repos) for consistency — but that's a separate change with its own blast radius (the rest of
   `.emacs.d/` would then need to come from the image, not the mount). **Out of scope unless asked**;
   the target above is written to match the *current* whole-`.emacs.d/` mount.

## Operational notes

- **Nested podman (running inside the sandbox):** the in-container `podman run` needs
  `--cgroups=disabled` to work nested. Per the standing arrangement, add it transiently at run time;
  don't commit it into the Makefile.
- **Off-limits:** the vendored `elpa/` *contents* are build artifacts — don't read/edit/reformat them;
  this task only adds the *mechanism* that regenerates them. The author runs it and commits the result
  deliberately (it rewrites a ~17M tree).
- **Not executed as part of this task** — parse/dry-run-verify only; actually running it rebuilds the
  image and rewrites the vendored tree, the author's call.

## Acceptance

- `make help` lists `update-emacs-packages` with its `##` description.
- The target parses and (dry-run) issues the expected `podman run` (whole-`.emacs.d/` mount, elpa-scoped
  wipe) + host strip/`git add` steps.
- The hand-written `.emacs.d/*.el` config files are **untouched** by a run (only `elpa/` changes).
- `ELPA_MOUNT` comment documents the use vs refresh split.
