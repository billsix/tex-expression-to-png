#!/bin/env bash
# The image is built at `make image` time (binary on PATH, builddir +
# compile_commands.json already present), so the shell works off the bat — no
# build needed here. To recompile after editing mounted source: meson compile -C builddir
set -e
cd /root/texExpToPng
# No args -> interactive shell (as before). Args (a `-c '...'` payload from
# `make shell-exec`) -> run them after setup, in a fresh bash not under -e.
exec bash "$@"
