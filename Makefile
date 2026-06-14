.DEFAULT_GOAL := shell

# Modify these to 0 if you want a quicker build and don't
# need the features
USE_EMACS=1

CONTAINER_CMD = podman
CONTAINER_NAME = tex-expression-to-png

TMUX_FILE := $(HOME)/.tmux.conf
TMUX_REAL_PATH := $(shell readlink -f $(TMUX_FILE))
TMUX_MOUNT := $(shell if [ -f $(TMUX_REAL_PATH) ]; then echo "-v $(TMUX_REAL_PATH):/root/.tmux.conf:Z" ; fi)


SOURCE_FILES_TO_MOUNT = \
     -v ./meson.build:/root/texExpToPng/meson.build:Z \
     -v ./src/tex_exp_to_png.c:/root/texExpToPng/src/tex_exp_to_png.c:Z \

SHELL_SCRIPTS_TO_MOUNT = \
    -v ./entrypoint/shell.sh:/usr/local/bin/shell.sh:Z \
    -v ./entrypoint/format.sh:/usr/local/bin/format.sh:Z \
    -v ./entrypoint/lint.sh:/usr/local/bin/lint.sh:Z \

FILES_TO_MOUNT = $(SOURCE_FILES_TO_MOUNT) \
                 $(SHELL_SCRIPTS_TO_MOUNT)

PACKAGE_CACHE_ROOT = ~/.cache/packagecache/fedora/43

DNF_CACHE_TO_MOUNT = -v $(PACKAGE_CACHE_ROOT)/var/cache/libdnf5:/var/cache/libdnf5:Z \
	             -v $(PACKAGE_CACHE_ROOT)/var/lib/dnf:/var/lib/dnf:Z


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
	# cache rpm packages
	mkdir -p $(PACKAGE_CACHE_ROOT)/var/cache/libdnf5
	mkdir -p $(PACKAGE_CACHE_ROOT)/var/lib/dnf
	# build the container
	$(CONTAINER_CMD) build \
                         -t $(CONTAINER_NAME) \
                         --build-arg USE_EMACS=$(USE_EMACS) \
                         $(ELPA_MOUNT) \
	                 $(TMUX_MOUNT) \
                         $(DNF_CACHE_TO_MOUNT) \
                         .

.PHONY: shell
shell: format ## Get Shell into a ephermeral container made from the image
	$(CONTAINER_CMD) run -it --rm \
		--entrypoint /bin/bash \
		$(FILES_TO_MOUNT) \
                $(ELPA_MOUNT) \
                $(TMUX_MOUNT) \
		$(CONTAINER_NAME) \
		/usr/local/bin/shell.sh


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


.PHONY: format
format: image ## Format the C code
	$(CONTAINER_CMD) run -it --rm \
		--entrypoint /bin/bash \
		$(FILES_TO_MOUNT) \
		$(CONTAINER_NAME) \
		/usr/local/bin/format.sh

.PHONY: example
example: image ## Run an example and put the output into the output folder
	podman run -it --rm \
		-v ./output:/output/:Z \
		tex-expression-to-png '$$ E = 5 + m*c^2 $$' 800 output.png

.PHONY: help
help:
	@grep --extended-regexp '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
