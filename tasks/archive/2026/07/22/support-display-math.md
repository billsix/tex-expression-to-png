# Support display math — `standalone` rejects `\[…\]` / `align*`; use `[varwidth]`

**Status:** complete
**Completed:** 2026-07-22 (fix applied + build-verified in this repo). The downstream **mvp rollout**
(bump the SHA-pin + rebuild) is a separate, already-tracked task in
`github.com/billsix/modelviewprojection` (`tasks/texexptopng-standalone-display-math.md`); Bill's
commit/push of this repo is his routine git step. Nothing further is owed *here*.
Created 2026-07-22. Found downstream in `github.com/billsix/modelviewprojection` (its Sphinx
`inlinetex` extension calls this tool): the book's ch04/ch06/ch14 matrix/aligned math fails to render.

**Durable knowledge** ("why `varwidth`") is preserved in-repo where it's always seen — the code
comment at `src/tex_exp_to_png.c` and `CLAUDE.md` "How it works" step 2 — so no separate reference doc
is warranted for this single-file tool.

## Applied + verified (2026-07-22)

`src/tex_exp_to_png.c` now emits `\documentclass[varwidth]{standalone}` (with an explaining comment);
`CLAUDE.md` + `README.md` updated to match. Built the patched binary (`meson`/gcc) and ran it against
the OLD pinned binary in mvp's image:

| expression                        | OLD (bare `standalone`)      | NEW (`standalone[varwidth]`) |
| --------------------------------- | ---------------------------- | ---------------------------- |
| inline `$x^2$`                    | OK (38×34 px)                | OK (**38×34 px** — identical) |
| display `\[ bmatrix … \vec … \]`  | FAILED (`Missing $ inserted`)| **OK (220×101 px)**          |
| `align*`                          | FAILED (`Missing \endgroup`) | **OK (213×163 px)**          |

Display math now renders; **inline crop is pixel-identical**, so `varwidth` doesn't regress existing
expressions. Remaining: commit + push this repo, then the mvp rollout below.

## Problem

texExpToPng renders **inline** math (`$…$`) fine but **fails on display math** — `\[…\]` blocks and
`align*`/`equation*` environments:

```
$…$ bmatrix (inline)   -> latex rc=0, PNG produced
\[…\] bmatrix (display)-> "latex command failed";  formula.log: "! Missing $ inserted." / "Bad math environment delimiter."
\begin{align*}…\end{}  -> "latex command failed";  "! Missing \endgroup inserted."
```

## Root cause (instrumented)

We wrap every expression in **`\documentclass{standalone}`** (`src/tex_exp_to_png.c:79`, also
described in `CLAUDE.md` "How it works" step 2). The bare `standalone` class typesets its body in a
restricted **horizontal** mode that does **not permit display-math delimiters** — so `\[…\]`,
`align*`, `equation*` all error out. It is **not** an `amsmath` problem: `\usepackage{amsmath}` has
been in the preamble since the first C version (`d3cb7a0`) and is present; only *display* math fails.

Confirmed the class option is the entire story (same amsmath preamble in every row):

| documentclass                | `$…$` | `\[…\]` | `align*` |
| ---------------------------- | ----- | ------- | -------- |
| `standalone` (current)       | ✅    | ❌      | ❌       |
| `standalone[varwidth]`       | ✅    | ✅      | ✅       |
| `standalone[preview]`        | ✅    | ✅      | ✅       |
| `article` (baseline)         | ✅    | ✅      | ✅       |

## Fix (one line)

`src/tex_exp_to_png.c` — the `g_fprintf(tex_file, …)` document template (line ~79):

```c
-            "\\documentclass{standalone}\n"
+            "\\documentclass[varwidth]{standalone}\n"
```

`varwidth` sets the body in a natural-width paragraph, which supports display math **and** line breaks
(needed by the multi-line `align*`/`bmatrix` expressions), while still cropping tightly to the content
— so single inline expressions stay tight too. (`[preview]` also works and needs the `preview`
package; `varwidth` is built into `standalone`, so it needs no extra `\usepackage`.)

**Also update `CLAUDE.md`** "How it works" step 2 (it names `\documentclass{standalone}`) and the top
paragraph ("wraps the expression in a `standalone` LaTeX document") to say `standalone` with the
`varwidth` option, so the doc doesn't drift from the code.

## Verify

1. `make image` (or `meson compile -C builddir` in `make shell`), then render one of each:
   - inline: `texExpToPng --exp '$x^2$' -s 300 -o /tmp/i.png` → PNG, `formula.log` clean.
   - display: a `--file` containing `\[ \begin{bmatrix} a \\ b \end{bmatrix} \]` → PNG (currently
     fails).
   - `align*`: a `--file` containing `\begin{align*} x &= a \\ &= b \end{align*}` → PNG.
2. **Regression check — existing inline renders must not change adversely.** Run `make example`
   (`$$ E = 5 + m*c^2 $$`) and eyeball the crop/baseline; `varwidth` should keep it tight, but confirm
   the PNG isn't padded or shifted vs the current output.

## Consumer rollout (modelviewprojection)

mvp bakes texExpToPng into its book image from a **SHA-pinned clone** (its `Dockerfile` `BUILD_DOCS`
block does `git checkout <SHA>`; currently `fbbd9a3f…`). After this lands + is pushed:

1. mvp bumps that pinned SHA to the new commit and rebuilds its image.
2. Confirm the tool still carries the `--bg/--fg` dvipng flags mvp depends on (the reason that SHA was
   pinned in the first place).

Tracked on the mvp side by `tasks/texexptopng-standalone-display-math.md` in
`github.com/billsix/modelviewprojection` (it points here for the actual fix).

## Why fix it here (not only in mvp)

texExpToPng's contract is to render *arbitrary* LaTeX math; failing on display math is a real defect
that any consumer hits. Fixing the documentclass here fixes it for every caller and keeps the tool's
promise, rather than pushing per-expression workarounds into each book.
