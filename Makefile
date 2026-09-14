.DEFAULT_GOAL := help

# Modify these to 0 if you want a quicker build and don't
# need the features
USE_EMACS=1

# Gate the image on a UBSan(trap)+ASan build+test of texExpToPng. Set
# RUN_SANITIZERS=0 for a quicker image that skips the sanitizer gate.
RUN_SANITIZERS ?= 1

CONTAINER_CMD ?= $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)
CONTAINER_NAME = tex-expression-to-png

# Extra flags for every container `run`. Auto-set when running nested inside a
# runClaudeInContainer/runCrushInContainer sandbox (which exports NESTED_PODMAN=1,
# making --cgroups=disabled apply so podman-in-podman works); empty — and
# byte-identical behavior — on a normal host. Overridable:
#   make shell PODMAN_RUN_FLAGS='--cgroups=disabled --network=host'
# On `run` lines only, never `build` (podman build rejects --cgroups). Convention:
# runClaudeInContainer tasks/reference/nested-podman-design.md.
PODMAN_RUN_FLAGS ?= $(if $(filter 1,$(NESTED_PODMAN)),--cgroups=disabled)

TMUX_FILE := $(HOME)/.tmux.conf
TMUX_REAL_PATH := $(shell readlink -f $(TMUX_FILE))
TMUX_MOUNT := $(shell if [ -f $(TMUX_REAL_PATH) ]; then echo "-v $(TMUX_REAL_PATH):/root/.tmux.conf:Z" ; fi)


SOURCE_FILES_TO_MOUNT = \
     -v ./meson.build:/root/texExpToPng/meson.build:Z \
     -v ./src/tex_exp_to_png.c:/root/texExpToPng/src/tex_exp_to_png.c:Z \
     -v ./tests:/root/texExpToPng/tests:Z \

SHELL_SCRIPTS_TO_MOUNT = \
    -v ./entrypoint/shell.sh:/usr/local/bin/shell.sh:Z \
    -v ./entrypoint/format.sh:/usr/local/bin/format.sh:Z \
    -v ./entrypoint/lint.sh:/usr/local/bin/lint.sh:Z \

FILES_TO_MOUNT = $(SOURCE_FILES_TO_MOUNT) \
                 $(SHELL_SCRIPTS_TO_MOUNT)

# USE_EMACS=1 (the default) bind-mounts the whole vendored .emacs.d/ into the
# container so an interactive `make shell` can *use* the vendored packages (:U
# chowns it to the container user, :z relabels for SELinux). Set USE_EMACS=0 to
# skip the mount. To *refresh* the vendored elpa packages, use `make
# update-emacs-packages` below.
ifeq ($(USE_EMACS), 1)
  ELPA_MOUNT= -v $(CURDIR)/entrypoint/dotfiles/.emacs.d/:/root/.emacs.d/:U,z
else
  ELPA_MOUNT=
endif


.PHONY: all
all: shell ## Build the image and get a shell in it

.PHONY: image
image: ## Build podman image to run the examples
	# build the container
	$(CONTAINER_CMD) build \
                         -t $(CONTAINER_NAME) \
                         --build-arg USE_EMACS=$(USE_EMACS) \
                         --build-arg RUN_SANITIZERS=$(RUN_SANITIZERS) \
                         $(ELPA_MOUNT) \
	                 $(TMUX_MOUNT) \
                         .

# --- shell / shell-exec share ONE container invocation, defined here so the two
# targets can never drift. Scoped to this pair ONLY. See runClaudeInContainer
# tasks/add-shell-exec-target.md for the design.
# NOTE: this project mounts only SELECTED files (meson.build, src/, tests/) at
# REPO_MOUNT, not the whole repo -- so shell-exec CMD='...' always works, but
# SCRIPT=path only resolves for a script under one of those mounted paths.
SHELL_RUN_FLAGS = \
		--entrypoint /bin/bash \
		$(FILES_TO_MOUNT) \
		$(ELPA_MOUNT) \
		$(TMUX_MOUNT)

# In-container mount root (matches SOURCE_FILES_TO_MOUNT + shell.sh's `cd`).
REPO_MOUNT = /root/texExpToPng

# shell-exec payload: cd to the mount root (independent of shell.sh's own cd), then
# run the inline CMD, else the (mounted) SCRIPT. Prefers CMD when both are set.
SHELL_EXEC_ARGS = -c 'cd $(REPO_MOUNT) && $(if $(CMD),$(CMD),exec bash $(SCRIPT))'

.PHONY: shell
shell: format ## Get Shell into a ephermeral container made from the image
	$(CONTAINER_CMD) run $(PODMAN_RUN_FLAGS) -it --rm $(SHELL_RUN_FLAGS) $(CONTAINER_NAME) /usr/local/bin/shell.sh

.PHONY: shell-exec
shell-exec: image ## Run a script/command in the container env (no TTY): make shell-exec SCRIPT=path | CMD='...'
	@[ -n "$(SCRIPT)$(CMD)" ] || { echo 'usage: make shell-exec SCRIPT=<mounted path> | CMD="..."'; exit 2; }
	$(CONTAINER_CMD) run $(PODMAN_RUN_FLAGS) --rm $(SHELL_RUN_FLAGS) $(CONTAINER_NAME) /usr/local/bin/shell.sh $(SHELL_EXEC_ARGS)


# Refresh the vendored Emacs packages. Forces USE_EMACS=1 and rebuilds the image
# first. Then, in the container, wipes ONLY the elpa/ subtree (the rest of
# .emacs.d -- init.el, install-melpa-packages.el, helm.el, preferences.el -- is
# hand-written config, left untouched) and reinstalls from MELPA into the host's
# bind-mounted .emacs.d/elpa (the whole .emacs.d/ is mounted RW, so the install
# script rides along -- no separate read-only mount needed). Finally strips
# compiled *.elc/*.eln (regenerated, machine-specific artifacts) and force-stages
# just the elpa tree (git add -A -f overrides .gitignore's *.elc/*.eln/...) so it
# is ready to commit. Needs network access.
.PHONY: update-emacs-packages
update-emacs-packages: ## USE_EMACS=1: rebuild image, wipe+reinstall elpa, strip *.elc/*.eln, git add -f
	$(MAKE) image USE_EMACS=1
	$(CONTAINER_CMD) run $(PODMAN_RUN_FLAGS) --rm \
		-v $(CURDIR)/entrypoint/dotfiles/.emacs.d/:/root/.emacs.d/:U,z \
		--entrypoint /bin/bash \
		$(CONTAINER_NAME) \
		-c 'mkdir -p /root/.emacs.d/elpa; find /root/.emacs.d/elpa -mindepth 1 -delete; \
		    emacs --batch --load /root/.emacs.d/install-melpa-packages.el'
	mkdir -p $(CURDIR)/entrypoint/dotfiles/.emacs.d/elpa && cd $(CURDIR)/entrypoint/dotfiles/.emacs.d/elpa && \
		find . \( -iname '*.elc' -o -iname '*.eln' \) -delete && \
		git add -A -f .
	@echo "Done: reinstalled packages, stripped *.elc/*.eln, staged elpa -- review and commit."


.PHONY: format
format: image ## Format the C code
	$(CONTAINER_CMD) run $(PODMAN_RUN_FLAGS) -it --rm \
		--entrypoint /bin/bash \
		$(FILES_TO_MOUNT) \
		$(CONTAINER_NAME) \
		/usr/local/bin/format.sh

.PHONY: example
example: image ## Run an example and put the output into the output folder
	$(CONTAINER_CMD) run $(PODMAN_RUN_FLAGS) -it --rm \
		-v ./output:/output/:Z \
		$(CONTAINER_NAME) '$$ E = 5 + m*c^2 $$' 800 output.png

.PHONY: image-export
image-export: ## export the OCI image to a timestamped tar in the repo root
	$(CONTAINER_CMD) save $(CONTAINER_NAME) -o $(CONTAINER_NAME)-$(shell date +%m-%d-%Y_%H-%M-%S).tar

.PHONY: image-import
image-import: ## import an OCI image tar: make image-import FILE=foo.tar
	$(CONTAINER_CMD) load -i $(FILE)

.PHONY: help
help:
	@grep --extended-regexp '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
