# texExpToPng — design & rationale

**Reference document** — the *why* behind how texExpToPng is built. Not a task; update in place when
the design changes. Last updated 2026-07-22. This is the agent-facing, expanded companion to
`CLAUDE.md`: read it before changing the rendering pipeline, the LaTeX template, the CLI, or the
container build.

## What it is, in one line

A ~156-line single-file C CLI (`src/tex_exp_to_png.c`) that turns a LaTeX/TeX math expression into a
PNG, by shelling out to a system TeX Live: **expression → wrap in a tiny LaTeX doc → `latex` → DVI →
`dvipng` → PNG**.

## The pipeline (and why it's shaped this way)

```
--exp / --file  ─▶  formula.tex  ─(latex)▶  formula.dvi  ─(dvipng)▶  <output>.png
```

1. **Wrap the expression in a minimal document** written to `formula.tex`:
   ```latex
   \documentclass[varwidth]{standalone}
   \usepackage{amsmath}
   \usepackage{xcolor}
   \begin{document}
   <expression>
   \end{document}
   ```
   - **`standalone`** crops the output tightly to the content (no page margins) — exactly what you
     want for an image you'll drop inline in a doc.
   - **`[varwidth]`** is load-bearing: the *bare* `standalone` class typesets its body in restricted
     horizontal mode and **rejects display math** (`\[…\]`, `align*`, `equation*` → `! Missing $
     inserted` / `Bad math environment delimiter`). `varwidth` sets a natural-width paragraph that
     admits display math **and** line breaks, while still cropping tight. Inline `$…$` renders
     identically either way (verified pixel-identical). *(Added 2026-07-22 — see
     `tasks/archive/2026/07/22/support-display-math.md`; a downstream book, modelviewprojection, needs
     matrix/aligned math.)*
   - **`amsmath`** provides `bmatrix`/`align*`/`\text`, etc. Present since the first C version.
   - **`xcolor`** provides `\textcolor{…}{…}` (colored math — the book's perspective
     chapter highlights terms in red). Added 2026-07-22.
2. **`latex formula.tex`** → `formula.dvi`. (Not `pdflatex`; DVI is what `dvipng` consumes.)
3. **`dvipng -D <size> -T tight [-bg …] [-fg …] -o <output> formula.dvi`** → the PNG. `-T tight` is the
   tight bounding box; `-D <size>` is the DPI (`--size`).

**Why shell out to TeX Live instead of a TeX library:** simplicity and fidelity. Real `latex` +
`dvipng` render exactly what the author would get, with zero TeX re-implementation; the tool is just
glue. Cost: it needs `latex` and `dvipng` on `PATH` at runtime (from TeX Live), and it forks two
subprocesses per render.

### Temp files are CWD-relative — callers must run it in a scratch dir

`formula.tex` / `formula.dvi` are written with **relative** names into the **current working
directory** (not a `mkstemp` temp dir). Consequences:
- The caller chooses the working dir; concurrent renders in the *same* dir would collide on
  `formula.*`.
- Leftover `formula.tex/.dvi/.aux/.log` accumulate in that dir. (modelviewprojection's `inlinetex`
  extension runs the tool inside `book/docs`, which is why `formula.*` show up there and its
  `git clean` lists them.) A failed `latex` run leaves `formula.log` behind — useful for debugging
  the *real* error, since the tool only prints "latex command failed" + captured stderr.

## CLI contract (`src/tex_exp_to_png.c`, glib `GOptionContext`)

| flag           | glib arg type          | required | meaning |
| -------------- | ---------------------- | -------- | ------- |
| `--exp` / `-e` | `G_OPTION_ARG_STRING`  | one of exp/file | the LaTeX expression as a string |
| `--file`/`-f`  | `G_OPTION_ARG_FILENAME`| one of exp/file | read the expression from a file |
| `--size`/`-s`  | `G_OPTION_ARG_INT`     | **yes**  | output DPI (0 ⇒ usage error) |
| `--output`/`-o`| `G_OPTION_ARG_FILENAME`| **yes**  | output PNG path |
| `--bg` / `-b`  | `G_OPTION_ARG_STRING`  | no       | dvipng background color (e.g. `Transparent`) |
| `--fg` / `-g`  | `G_OPTION_ARG_STRING`  | no       | dvipng foreground color (e.g. `"rgb 1.0 1.0 1.0"`) |

- Validation: `(!exp && !file) || size == 0 || !output` → print usage, `exit(EXIT_FAILURE)`.
- **If both `--exp` and `--file` are given, `--file` wins** (`read_file` overwrites `expression`).
- **`--bg`/`--fg` default to omitted**, so dvipng's default black-on-white is preserved for existing
  callers; they exist for transparent-overlay use (e.g. white glyphs on a transparent background).
  Each is injected as `-bg "…"` / `-fg "…"` only when set.

## Error-handling & memory model

- `_Noreturn void fatal_error(void)` = `exit(EXIT_FAILURE)`. **Every** failure path calls it after
  printing a message: file-read failure, `latex` spawn failure, non-zero `latex` exit, `dvipng` spawn
  failure, non-zero `dvipng` exit. On a tool's non-zero exit, its captured **stderr is surfaced** to
  the user.
- glib memory discipline: `g_free` on each captured stdout/stderr after use, on the built
  `dvipng_cmd`, and on `expression`/`filename`/`output` at the end. (Frees on the `fatal_error` paths
  are skipped — the process is exiting anyway.)
- Only two libraries: **glib-2.0** (option parsing, file I/O `g_file_get_contents`/`g_fopen`/
  `g_fprintf`, subprocess `g_spawn_command_line_sync`, `g_strdup_printf`) and **libm** (linked,
  currently unused — see `meson.build`).

## Build & container design (Fedora-44 + podman template)

- **Compiled at image-build time, not at run time.** The `Dockerfile` `COPY`s `meson.build` + `src/`
  and `RUN`s `entrypoint/buildDebug.sh`, so the image ships a ready binary on `PATH` (via
  `meson install` → `/usr/local/bin`) plus `builddir/` and a symlinked `compile_commands.json` (for
  clangd). `make example` / a plain run therefore **never build** — they just execute.
- **`buildDebug.sh`**: `CC=clang meson setup builddir --buildtype=debug -Dwarning_level=3`, then
  `-Dcpp_args=-Wall`, `meson compile`, `meson install`, and `ln -s builddir/compile_commands.json`.
  (Dev builds are clang/debug/high-warnings; a plain `gcc` build also works — that's what a host or a
  non-clang image uses.)
- **`meson.build`**: `project('texExpToPng','c', c_std=gnu11)`, deps `glib-2.0` + `find_library('m')`,
  one source, `install: true`.
- **Dockerfile toolchain**: Fedora 44 with the dnf-cache mount idiom; installs
  clang/clang-tools-extra/gcc/gdb/lldb/meson/ninja/glib2-devel and **TeX Live** (`texlive`,
  `texlive-dvipng`, `texlive-standalone`, `texlive-anyfontsize`, `texlive-dvisvgm`). `ARG USE_EMACS`
  defaults **0** in the Dockerfile / **1** in the Makefile. A `~/.bashrc` `exit()` trap runs
  `format.sh` + `lint.sh` on shell exit. `ENTRYPOINT ["/entrypoint.sh"]`.
- **`entrypoint.sh`** is a positional-arg wrapper (`texExpToPng --exp "$1" --size "$2" --output
  /output/"$3"`) that `make example` drives (`… '$$ E = 5 + m*c^2 $$' 800 output.png`). Interactive
  work goes through **`shell.sh`** (cd + `exec bash`; recompile with `meson compile -C builddir`).
- **Makefile** (`CONTAINER_NAME=tex-expression-to-png`): `image`, `shell` (runs `format` first),
  `format` (clang-format), `lint` is folded into the shell-exit trap, `example`, `update-emacs-packages`,
  `image-export`/`image-import` (timestamped OCI tar; gitignored), `help`. Source is bind-mounted RW
  for `make shell` so edits recompile in place.
- **Conventions**: clang-format **google** style, `SortIncludes: Never` (`.clang-format`); `lint.sh`
  is `run-clang-tidy . -fix` (no `.clang-tidy` config → clang-tidy defaults). Format + lint run
  automatically on shell exit.
- **Off-limits**: the vendored `entrypoint/dotfiles/.emacs.d/elpa/` tree (MELPA packages, marked
  `linguist-vendored`, refreshed only via `make update-emacs-packages`) — not project source.

## Consumers

- **modelviewprojection** — its Sphinx `inlinetex` extension calls `texExpToPng --file …` to render
  inline/display math for the book. It bakes texExpToPng from a **SHA-pinned git clone** in its
  `Dockerfile` (so a texExpToPng change reaches the book only when mvp bumps that SHA). This is why
  the `--bg/--fg` flags and the `varwidth` fix each mattered downstream.
- **multivariate-math** uses the same SHA-pinned-clone scheme.

## Design limits / gotchas worth knowing

- **Runtime dep on TeX Live** (`latex` + `dvipng`); no bundling.
- **CWD-relative temp files** (above) — not reentrant within one directory.
- **Only `latex`→`dvipng`** (DVI path); no PDF/SVG output despite `texlive-dvisvgm` being installed.
- The tool reports `latex`/`dvipng` failures by **surfacing their stderr**; the real LaTeX error for a
  bad expression is in the leftover **`formula.log`** in the CWD, not in the one-line "command failed"
  message.

## Relationships

- `CLAUDE.md` (lean overview; this doc is the deep version) and `README.md` (user-facing).
- `tasks/archive/2026/07/22/support-display-math.md` (the `varwidth` fix that this doc's LaTeX-template
  section records the rationale for).
- Open tasks touching the design: `tasks/add-sanitizer-gate.md` (ASan/UBSan image gate),
  `tasks/container-build-cleanup.md` (bashrc `exit()` trap / `buildDebug` symlink).
