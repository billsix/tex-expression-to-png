# texExpToPng

A tiny C command-line tool that turns a LaTeX/TeX math expression into a PNG
image. It wraps the expression in a `standalone` (`varwidth`) LaTeX document,
compiles it with `latex`, and rasterizes the result with `dvipng`. The `varwidth`
option lets display math (`\[…\]`, `align*`) render, not just inline `$…$`.

## Usage

```sh
texExpToPng --exp "E = 5 + m c^2" --size 800 --output out.png
# or read the expression from a file:
texExpToPng --file expr.tex --size 800 --output out.png
# transparent background with white glyphs (for overlaying on dark UI):
texExpToPng --file expr.tex --size 800 --bg Transparent --fg "rgb 1 1 1" -o out.png
```

- `--exp` / `-e` — the LaTeX expression (or `--file` / `-f` to read it from a
  file; if both are given, `--file` wins)
- `--size` / `-s` — output DPI (required)
- `--output` / `-o` — PNG path (required)
- `--bg` / `-b`, `--fg` / `-g` — dvipng background / foreground colors (optional;
  default is dvipng's black-on-white). Use them for transparent-overlay output.

The expression may be inline (`$…$`) or display math (`\[…\]`, `align*`,
`equation*`) — `amsmath` (matrices, aligned equations) is available.

Requires `latex` and `dvipng` (TeX Live) on `PATH`.

## How it works

It writes a tiny LaTeX document — `\documentclass[varwidth]{standalone}` +
`\usepackage{amsmath}` wrapped around your expression — to `formula.tex` in the
current directory, runs `latex` to get a DVI, then `dvipng -D <size> -T tight` to
crop and rasterize it to the PNG. Because the temp files are written to the
working directory, run it in a scratch dir. See `tasks/reference/design.md` for
the full design.

## Build

Built with Meson + Ninja; depends on `glib-2.0`.

```sh
meson setup builddir
meson compile -C builddir
```

Or use the bundled Fedora podman container (TeX Live included):

```sh
make image     # build the image
make example   # render a sample expression to ./output/
make shell     # dev shell
```

## License

MIT © William Emerison Six. See `LICENSE`.
