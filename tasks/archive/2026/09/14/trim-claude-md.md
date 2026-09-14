# Trim texExpToPng's CLAUDE.md (5,170 B ≈ 1.3K tok, loaded every session)

**Status:** Done — trimmed 2026-09-13 (archived 2026-09-14)
**Priority:** 6
**Difficulty:** 3

**Result:** CLAUDE.md 5,170 B → 4,001 B (−1,169 B, ~23%). Pointerized the "How
it works" walkthrough (fully duplicated in `tasks/reference/design.md`, including
the CWD/`formula.log` gotcha — verified — so no re-copy needed; kept a one-line
pipeline quick-ref); shrank the LSan rationale to a `design.md` pointer; replaced
the "Recently done" history + per-task detail with pointers to `tasks/` and
`design.md`. No new reference doc needed.

## BLUF
texExpToPng's `CLAUDE.md` is just over the 5 KB lean threshold, and the excess is
two blocks that duplicate other docs: a step-by-step "How it works" walkthrough that
repeats `tasks/reference/design.md` (which the same file already tells readers to read
first), and a "Recently done" history plus in-flight task detail that duplicate
`tasks/`. Trim both to pointers and the file drops to roughly 4 KB, comfortably lean.

## Context
- Why: `CLAUDE.md` loads every session; deep mechanics and history belong in
  `tasks/reference/` and `tasks/`. Method/numbers: runCrushInContainer
  `tasks/reference/crush-context-assembly.md`.
- Current size: 5,170 B ≈ 1.3K tok. `@`-imports: **none**.
- Convention: `CLAUDE.md` lean + operational; detail in `tasks/reference/`.
- Existing `tasks/reference/` docs: `design.md` (the standing design/rationale doc —
  pipeline, LaTeX template, CLI, container; the destination for the "How it works"
  mechanics, and already cited twice in CLAUDE.md).

## Stay vs move (section-by-section)
| section (heading) | ~bytes | Verdict | Destination |
|---|---|---|---|
| Title + intro (L1–6) | ~400 | STAY | CLAUDE.md (what this is) |
| `## Status` (L8–14) | ~350 | STAY | CLAUDE.md (lang, deps, single source file) |
| Design deep-dive callout (L16–19) | ~250 | STAY | CLAUDE.md (pointer to `design.md`) |
| `## How it works` (L21–37) | ~950 | MOVE/TRIM | `tasks/reference/design.md` — the 4-step pipeline + `varwidth`/`amsmath`/`xcolor` reasoning + the "`formula.tex`/`.dvi` written to CWD, `formula.log` has the real error" mechanics are exactly its content; replace with a one-line pointer (verify the CWD/log gotcha is captured in `design.md` before deleting from CLAUDE.md) |
| `## CLI` (L39–53) | ~850 | STAY | CLAUDE.md (operational usage; keep the `--file` wins / `--bg`/`--fg` optional notes) |
| `## Build / container workflow` (L55–79) | ~1,300 | TRIM | keep targets + the `RUN_SANITIZERS=0` opt-out; the LSan/`__asan_default_options` "benign exit-time leaks" rationale can shrink to a pointer to `design.md` |
| `## Conventions` (L81–84) | ~200 | STAY | CLAUDE.md |
| `## Reference & tasks` (L86–101) | ~900 | TRIM | keep the `design.md` pointer + a one-line "in-flight work: see `tasks/`"; delete the per-task detail and the "Recently done (2026-07-22)" history (that lives in `tasks/` and `tasks/archive/`) |

## Projected result
- Moving the ~0.95 KB "How it works" block into `design.md` and trimming ~0.6 KB of
  sanitizer/history prose brings the file to roughly **4.0 KB ≈ 1.0K tok** — lean,
  with the mechanics preserved one hop away in the design doc it already points to.
- Only destination needed is the existing `tasks/reference/design.md`; no new doc.

## Open questions
1. Before deleting "How it works" from CLAUDE.md, confirm `design.md` already carries
   the CWD-relative-output + `formula.log` gotcha; if not, port that one paragraph in
   the same edit. Recommendation: fold it in — it is the most operationally useful
   line in the section.

## Related
- runCrushInContainer `tasks/reference/crush-context-assembly.md` — measurement + method.
- `tasks/reference/design.md` — destination for the moved mechanics.
