# Document the --bg/--fg CLI options in CLAUDE.md and README.md

**Status:** proposed — needs go-ahead
**Created:** 2026-07-09

## Goal

The CLI in `src/tex_exp_to_png.c` grew two options — `--bg/-b` and `--fg/-g`
(dvipng background/foreground colors, for transparent-overlay callers) — that
neither `CLAUDE.md` nor `README.md` mentions. Bring the docs back in sync with
the code.

## Background

- `src/tex_exp_to_png.c:43-46` defines the `bg`/`fg` `GOptionEntry`s.
- `src/tex_exp_to_png.c:111-117` builds the dvipng command, appending
  `-bg "<color>"` / `-fg "<color>"` only when supplied. The comment there
  documents intent: default is omitted so existing callers keep dvipng's
  black-on-white; the options exist for overlay use
  (e.g. `-bg Transparent -fg "rgb 1.0 1.0 1.0"`).
- Docs currently listing only `--exp/--file/--size/--output`:
  - `CLAUDE.md:27-35` (CLI section)
  - `README.md:14-19` (usage bullets)

## Plan

- [ ] **README.md** — add `--bg` / `-b` and `--fg` / `-g` to the options list
      (lines 14-19), noting each is optional and defaults to dvipng's
      black-on-white. Optionally add an overlay usage example
      (`--bg Transparent --fg "rgb 1.0 1.0 1.0"`).
- [ ] **CLAUDE.md** — add the two flags to the CLI section (lines 27-35).
      Consider a one-line note in "How it works" (step 4, line 23) that the
      dvipng invocation conditionally appends `-bg`/`-fg`.

## Open questions

- None — purely descriptive doc updates; no behavior change.
