# texExpToPng

A small C CLI that renders a LaTeX/TeX math expression to a PNG. It wraps the
expression in a `standalone` LaTeX document, runs `latex` to produce a DVI, then
`dvipng` to rasterize it at a chosen DPI. Used as a helper by other projects
(e.g. modelviewprojection's Sphinx `inlinetex` extension).

## Status

- **Language:** C (`gnu11`), Meson + Ninja.
- **Deps:** `glib-2.0` (option parsing, file I/O, `g_spawn_command_line_sync`);
  libm (linked, unused). At runtime it shells out to **`latex`** and **`dvipng`**
  from TeX Live.
- Single source file: `src/tex_exp_to_png.c` (~139 lines).

## How it works

`src/tex_exp_to_png.c`:
1. reads the expression from `--exp` (string) or `--file`,
2. writes a minimal doc — `\documentclass{standalone}` + `\usepackage{amsmath}`
   around the expression — to `formula.tex`,
3. `latex formula.tex` → `formula.dvi`,
4. `dvipng -D <size> -T tight -o <output> formula.dvi`.

It checks each subprocess's exit status and prints the tool's stderr on failure.

## CLI

```
texExpToPng --exp "E = 5 + m c^2" --size 800 --output out.png
texExpToPng --file expr.tex       --size 800 --output out.png
```

`--exp/-e` expression string · `--file/-f` read from file · `--size/-s` DPI
(required) · `--output/-o` PNG path (required).

## Build / container workflow

Fedora-44 + podman family template. `make` targets:

- `make image` — build the image (`tex-expression-to-png`); installs TeX Live
  (`texlive`, `texlive-dvipng`, `texlive-standalone`, `texlive-anyfontsize`, …).
- `make shell` *(default; runs `format` first)* — dev shell, source bind-mounted.
  `buildDebug.sh` (seeded into bash history) does the meson debug build.
- `make format` — clang-format the C.
- `make example` — render `$$ E = 5 + m*c^2 $$` at 800 DPI to `./output/output.png`.

`entrypoint/entrypoint.sh` is the image's app entrypoint:
`texExpToPng --exp "$1" --size "$2" --output /output/"$3"`.

## Conventions

- Clang-format: Google style, no include sorting. `lint.sh` runs `clang-tidy`.
- On shell exit, `format.sh` + `lint.sh` run automatically (a `~/.bashrc` hook).

## Tasks (in-flight)

- [`tasks/container-build-cleanup.md`](tasks/container-build-cleanup.md) — the
  `exit()` bashrc trap drops the shell exit code; the `fedora/43` dnf cache path
  should be `44`; `buildDebug.sh`'s `ln -s` needs `-f` to be re-runnable.
