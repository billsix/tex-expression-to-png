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

Pipeline (`src/tex_exp_to_png.c`): read expression from `--exp`/`--file` → wrap
in a minimal `\documentclass[varwidth]{standalone}` doc written to `formula.tex`
→ `latex` → `formula.dvi` → `dvipng -D <size> -T tight [-bg …] [-fg …]` → PNG. On
any subprocess failure it prints the tool's stderr and exits non-zero. The
step-by-step mechanics, the `varwidth`/`amsmath`/`xcolor` reasoning, and the
CWD-relative temp-file / `formula.log`-has-the-real-error gotcha are in
`tasks/reference/design.md`.

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
skips the sanitizer gate. (LSan is defaulted off so the gate targets corruption,
not benign exit-time leaks — see `tasks/reference/design.md`.)

`entrypoint/entrypoint.sh` is the image's app entrypoint:
`texExpToPng --exp "$1" --size "$2" --output /output/"$3"`.

## Conventions

- Clang-format: Google style, no include sorting. `lint.sh` runs `clang-tidy`.
- On shell exit, `format.sh` + `lint.sh` run automatically (a `~/.bashrc` hook).

## Reference & tasks

- **Design reference:** [`tasks/reference/design.md`](tasks/reference/design.md) —
  the standing design/rationale doc (pipeline, LaTeX template, CLI, container,
  sanitizer gate, consumers, and design history).
- **In-flight work:** see `tasks/` (each open task doc is the live record);
  completed work is under `tasks/archive/<YYYY>/<MM>/<DD>/`.
