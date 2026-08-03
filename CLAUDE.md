# texExpToPng

A small C CLI that renders a LaTeX/TeX math expression to a PNG. It wraps the
expression in a `standalone` (`varwidth`) LaTeX document, runs `latex` to produce
a DVI, then `dvipng` to rasterize it at a chosen DPI. Used as a helper by other
projects (e.g. modelviewprojection's Sphinx `inlinetex` extension).

## Status

- **Language:** C (`gnu11`), Meson + Ninja.
- **Deps:** `glib-2.0` (option parsing, file I/O, `g_spawn_command_line_sync`);
  libm (linked, unused). At runtime it shells out to **`latex`** and **`dvipng`**
  from TeX Live.
- Single source file: `src/tex_exp_to_png.c` (~156 lines).

> **Design deep-dive:** `tasks/reference/design.md` — the *why* behind the
> pipeline, the LaTeX template, the CLI, and the container build. Read it before
> changing any of those.

## How it works

`src/tex_exp_to_png.c`:
1. reads the expression from `--exp` (string) or `--file`,
2. writes a minimal doc — `\documentclass[varwidth]{standalone}` +
   `\usepackage{amsmath}` + `\usepackage{xcolor}` around the expression — to
   `formula.tex` (the `varwidth` option lets display math — `\[…\]`, `align*` —
   typeset, which bare `standalone` rejects; `amsmath` gives matrices/aligned
   environments; `xcolor` gives `\textcolor{…}{…}`),
3. `latex formula.tex` → `formula.dvi`,
4. `dvipng -D <size> -T tight [-bg …] [-fg …] -o <output> formula.dvi`.

It checks each subprocess's exit status and, on failure, prints the tool's
stderr and `exit(EXIT_FAILURE)`s. **`formula.tex`/`.dvi` are written in the
current working directory** (relative paths, not a temp dir) — so callers run it
in a scratch dir, and a failed `latex` leaves `formula.log` there with the *real*
LaTeX error (the tool itself only prints a one-line "latex command failed").

## CLI

```
texExpToPng --exp "E = 5 + m c^2" --size 800 --output out.png
texExpToPng --file expr.tex       --size 800 --output out.png
# transparent white glyphs (for overlay use):
texExpToPng --file expr.tex --size 800 --bg Transparent --fg "rgb 1 1 1" -o out.png
```

- `--exp/-e` expression string · `--file/-f` read from file (**`--file` wins if
  both are given**) · `--size/-s` DPI *(required)* · `--output/-o` PNG path
  *(required)*.
- `--bg/-b` · `--fg/-g` — dvipng background / foreground colors, passed through as
  `-bg`/`-fg`. **Optional**, omitted by default so dvipng's black-on-white is
  preserved for existing callers; set them for transparent-overlay rendering
  (e.g. `--bg Transparent --fg "rgb 1 1 1"`).

## Build / container workflow

Fedora-44 + podman family template. `make` targets:

- `make help` *(default)* — list the documented targets.
- `make image` — build the image (`tex-expression-to-png`); installs TeX Live
  (`texlive`, `texlive-dvipng`, `texlive-standalone`, `texlive-anyfontsize`, …),
  then compiles + installs the CLI as an image-build stage (COPYs `meson.build` +
  `src/` and runs `buildDebug.sh`), so the image ships a ready-to-run binary
  plus `builddir`/`compile_commands.json`.
- `make shell` *(runs `format` first)* — dev shell, source bind-mounted. The
  binary + clangd's `compile_commands.json` are already built into the image, so
  it works off the bat; recompile edited source with `meson compile -C builddir`.
- `make format` — clang-format the C.
- `make example` — render `$$ E = 5 + m*c^2 $$` at 800 DPI to `./output/output.png`.

`make image` gates the build on `meson test` (a `smoke` render + a TeX-free
`usage-error` case in `tests/`) and, by default (`RUN_SANITIZERS=1`), rebuilds and
re-runs that suite under **UBSan-trap** and **ASan**; `make image RUN_SANITIZERS=0`
skips the sanitizer gate. LSan is defaulted off (guarded `__asan_default_options`
in the source, ASan-only) so the gate targets corruption, not benign exit-time
leaks.

`entrypoint/entrypoint.sh` is the image's app entrypoint:
`texExpToPng --exp "$1" --size "$2" --output /output/"$3"`.

## Conventions

- Clang-format: Google style, no include sorting. `lint.sh` runs `clang-tidy`.
- On shell exit, `format.sh` + `lint.sh` run automatically (a `~/.bashrc` hook).

## Reference & tasks

- **Design reference:** [`tasks/reference/design.md`](tasks/reference/design.md) —
  the standing design/rationale doc (pipeline, LaTeX template, CLI, container).
- In-flight (`tasks/`):
  - [`tasks/container-build-cleanup.md`](tasks/container-build-cleanup.md) — the
    `exit()` bashrc trap drops the shell exit code; `buildDebug.sh`'s `ln -s`
    needs `-f` to be re-runnable (the `fedora/43`→`44` dnf-cache item is done).
  - [`tasks/add-sanitizer-gate.md`](tasks/add-sanitizer-gate.md) — ASan/UBSan(trap)
    image-build gate, mirroring spimulator's. Implemented + source-verified
    2026-08-03 (`tests/` harness, meson/Dockerfile/Makefile wiring); one
    confirmatory containerized `make image` still to run before archiving.
- Recently done (2026-07-22): the `standalone[varwidth]` display-math fix, a
  `\usepackage{xcolor}` add (for `\textcolor` in the book's perspective chapter),
  and the `--bg/--fg` docs — all folded into this file + `tasks/reference/design.md`
  (`tasks/archive/2026/07/22/support-display-math.md`).
