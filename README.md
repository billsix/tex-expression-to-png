# texExpToPng

A tiny C command-line tool that turns a LaTeX/TeX math expression into a PNG
image. It wraps the expression in a `standalone` LaTeX document, compiles it with
`latex`, and rasterizes the result with `dvipng`.

## Usage

```sh
texExpToPng --exp "E = 5 + m c^2" --size 800 --output out.png
# or read the expression from a file:
texExpToPng --file expr.tex --size 800 --output out.png
```

- `--exp` / `-e` — the LaTeX expression (or `--file` / `-f` to read from a file)
- `--size` / `-s` — output DPI (required)
- `--output` / `-o` — PNG path (required)

Requires `latex` and `dvipng` (TeX Live) on `PATH`.

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
