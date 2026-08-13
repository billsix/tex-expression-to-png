#!/usr/bin/env bash
#
# 02-install-emacs.sh -- Emacs (package only). Corresponds to the Dockerfile's USE_EMACS
# flag; the Dockerfile runs this only when USE_EMACS=1. The MELPA-package bootstrap
# (`emacs --batch ...`) and the ls alias stay in the Dockerfile because they are config,
# not package installation. No options -- see 01-install-base.sh for the design.
#
# Single dnf call, so its own exit status is this script's exit status.
set -uo pipefail

dnf install -y emacs
