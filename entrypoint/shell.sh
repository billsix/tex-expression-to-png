#!/bin/env bash
# The image is built at `make image` time (binary on PATH, builddir +
# compile_commands.json already present), so the shell works off the bat — no
# build needed here. To recompile after editing mounted source: meson compile -C builddir
cd /root/texExpToPng
exec bash
