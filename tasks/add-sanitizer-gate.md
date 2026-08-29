# Add an ASan + UBSan(trap) build gate to the image

**Status:** implemented + source-level verified 2026-08-03 — one confirmatory
containerized `make image` (default `RUN_SANITIZERS=1`) still to run (skipped
here on purpose, see "Verification" below). Not archived until that green.
**Priority:** 5
**Difficulty:** 5
**Created:** 2026-06-16

## What was done (2026-08-03)

Implemented the whole gate, closing the "nothing to gate on" prerequisite first.

- **Test harness (new `tests/`, both `meson test()` targets):**
  - `tests/smoke.sh` — renders `$E = m c^2$` at 200 DPI in a `mktemp -d` scratch
    dir (formula.tex/.dvi are CWD-relative) and asserts exit 0, non-empty output,
    and PNG magic bytes (`89504e47`). Needs `latex` + `dvipng`.
  - `tests/usage_error.sh` — TeX-free: `--exp x` with no `--size`/`--output` must
    exit non-zero (hits `print_usage` + `fatal_error`). Gates the pure-C
    option-parse/validation paths independent of TeX Live.
  - Wired in `meson.build` with `env: {TEXEXP_BIN: …full_path()}`, `depends:` the
    exe, `smoke` given `timeout: 120`. meson runs each as its own `test()` and
    reports every failure — that is the "run all, report all red" accumulator, so
    the shell scripts stay single-assertion + `set -e` (safe-by-shape, matching
    the repo's format gate).
- **Bug found + fixed in the suggested smoke expression:** the task's own
  `'E = m c^2'` is written verbatim into the LaTeX body with no math delimiters →
  `! Missing $ inserted`, latex exits 1 (real `make example` wraps its arg in
  `$$…$$`). Changed the smoke expression to `'$E = m c^2$'`. Caught precisely
  because the gate actually executes latex.
- **LSan decision — defaulted OFF** via a guarded `__asan_default_options`
  returning `detect_leaks=0` in `src/tex_exp_to_png.c`. The gate targets
  corruption, not the benign exit-time leaks on `fatal_error()` paths. **Guarded**
  (`__has_feature(address_sanitizer)` / `__SANITIZE_ADDRESS__`) so the hook is
  compiled *only* under ASan — the shipped normal build is byte-for-byte
  unaffected (confirmed: symbol present in the ASan binary, absent in the normal
  one). Did **not** rewrite the error-path frees; left as-is per "focus the gate
  on corruption."
- **Dockerfile:** `COPY tests …`, a normal `RUN meson test … builddir` gate after
  `buildDebug.sh`, then `ARG RUN_SANITIZERS=0` + the two-setup UBSan-trap/ASan
  block (`set -e`, separate `/tmp/san-*` dirs, `--no-rebuild`, cleaned up). No new
  packages (clang/meson/ninja + ASan runtime already ship).
- **Makefile:** `RUN_SANITIZERS ?= 1` + `--build-arg RUN_SANITIZERS=$(RUN_SANITIZERS)`
  in `image`; added `-v ./tests:…:Z` to `SOURCE_FILES_TO_MOUNT` so `make shell`
  can run the suite too.

## Verification (2026-08-03)

Verified at **source level in the sandbox**, which has the identical toolchain the
image uses (Fedora 44 clang 22 / gcc, meson, glib-2.0 2.88, and real
`latex`+`dvipng`). Ran the exact command sequences the Dockerfile runs, in
out-of-tree build dirs against the real source:

- Normal (gcc) build: `smoke` + `usage-error` both **OK**.
- UBSan-trap build (`-fsanitize=undefined -fsanitize-trap=undefined`): both **OK**
  — no UB trapped.
- ASan build (`-Db_sanitize=address`): both **OK** — no memory error; LSan hook
  confirmed suppressing leaks (no leak report on the leak-on-exit usage path).
- Both shipped/normal and ASan configs compile with **0 warnings** under
  `-Wall -Wextra`.

**Not run (on purpose):** the full containerized `make image` — ~10 agents share a
32G container store, so a heavy TeX Live image build was out of budget. The
Dockerfile/Makefile *wiring* (COPY tests, build-arg threading, the `if
RUN_SANITIZERS` block) is therefore un-exercised by an actual build even though the
gate *logic* it runs is verified. **Follow-up for Bill:** one `make image` (default
flags) to confirm the container assembly, then archive this doc.

## Goal

Mirror the sibling **spimulator** sanitizer gate (its `make image` default,
`RUN_SANITIZERS=1`) in texExpToPng: at image-build time, compile `texExpToPng`
a second time under **UBSan trap mode** and under **ASan**, run a test/smoke
harness under each, and **fail the image** on any undefined behavior or memory
error. This catches integer-UB and memory-safety regressions before they ship.

Primer on what ASan/UBSan are and why trap mode is the reliable gate (diagnostic
UBSan under-reports): `/billopt/spimulator/tasks/archive/2026/06/16/ubsan-sweep.md`.
Reference wiring: spimulator's `Dockerfile` (the `RUN_SANITIZERS` block) and
`Makefile` (`RUN_SANITIZERS ?= 1`, threaded as `--build-arg`).

## PREREQUISITE (the blocker): there is nothing to gate on yet

A sanitizer is a **dynamic** tool — it only catches a bug on a code path that
actually executes. **texExpToPng currently has no test suite at all:** `meson.build`
defines only the `executable()` (no `test()`), and the Dockerfile never runs
`meson test`. So before a gate is meaningful, the project needs **something to
execute under the sanitizers.** This task is blocked on adding that harness.

The program's real work is shelling out to `latex` + `dvipng` (TeX Live, present
in the image) and writing a PNG. So the natural gate is a **smoke test**: run the
binary on a known-good expression and assert it exits 0 and produces a non-empty
PNG. This exercises the C we actually own — option parsing (`GOptionEntry`),
`read_file`, the `g_strdup_printf`/`g_fopen`/`g_fprintf` document assembly, the
two `g_spawn_command_line_sync` calls and their error/exit-status handling.

### Concrete smoke-test suggestion

Add a `meson test()` driven by a small shell script, e.g. `tests/smoke.sh`:

```sh
#!/bin/sh
set -e
out="$(mktemp -d)/out.png"
"$TEXEXP_BIN" --exp 'E = m c^2' --size 200 --output "$out"
test -s "$out"            # exists and non-empty
# (optional) `file "$out"` matches 'PNG image'
```

Wire it in `meson.build`:

```meson
test('smoke', find_program('tests/smoke.sh'),
     env: {'TEXEXP_BIN': texExpToPng_exe.full_path()},
     depends: texExpToPng_exe)
```

Consider a second, **TeX-free** case that drives the pure-C paths without needing
`latex`/`dvipng` to succeed — e.g. invoking with missing required args to hit
`print_usage` + `fatal_error` (expect non-zero exit). That keeps a chunk of
coverage even if TeX Live were ever absent, and still runs under the sanitizers.

Note: `tests/` should be added to `SOURCE_FILES_TO_MOUNT` in the Makefile (or the
mount switched to a directory mount) so a dev `make shell` can run it too; the
image COPYs the whole tree at build time so the gate sees it regardless.

## Meson sanitizer-flag changes (the gate itself)

Same shape as spimulator — no permanent change to `meson.build`'s defaults; the
sanitized builds are **separate `meson setup` dirs** with sanitizer flags passed
in, so the normal install build is untouched.

- **UBSan (trap) — the pass/fail gate:**
  ```sh
  CC=clang meson setup /tmp/san-ubsan /<src> --buildtype=debug -Dwarning_level=3 \
      -Dc_args='-fsanitize=undefined -fsanitize-trap=undefined' \
      -Dc_link_args='-fsanitize=undefined -fsanitize-trap=undefined'
  meson compile -C /tmp/san-ubsan
  meson test    -C /tmp/san-ubsan --no-rebuild --print-errorlogs
  ```
  Trap mode links no runtime (low friction in the Fedora image) and is the
  reliable gate; a surviving UB kills the process with SIGILL → test fails →
  image fails.

- **ASan — memory-safety gate:**
  ```sh
  CC=clang meson setup /tmp/san-asan /<src> --buildtype=debug -Dwarning_level=3 \
      -Db_sanitize=address
  meson compile -C /tmp/san-asan
  meson test    -C /tmp/san-asan --no-rebuild --print-errorlogs
  rm -rf /tmp/san-ubsan /tmp/san-asan
  ```

Only one executable target here (no `-nostdlib` demos to exclude, unlike
spimulator), so no target-scoping needed — build everything.

### Dockerfile / Makefile wiring

- **Dockerfile:** add `ARG RUN_SANITIZERS=0` (lean default, per the family
  contract) and a `RUN if [ "$RUN_SANITIZERS" = "1" ]; then … fi` block with the
  two setups/compiles/tests above (`set -e`), placed **after** the normal build
  and after a (new) normal `meson test` step. Image already installs `clang` and
  `meson`/`ninja`, so no new packages.
- **Makefile:** add `RUN_SANITIZERS ?= 1` near the top with a comment, and pass
  `--build-arg RUN_SANITIZERS=$(RUN_SANITIZERS)` in the `image` target — exactly
  as spimulator does. `make image RUN_SANITIZERS=0` skips the gate.

## ASan leak note (likely relevant)

`main()` in `src/tex_exp_to_png.c` has **leak-on-error paths**: every
`fatal_error()` call `exit()`s without freeing the glib allocations live at that
point (`expression`, `output`, `stdout_output`/`stderr_output`, `dvipng_cmd`,
the `GOptionContext` in some branches). The success path frees most things but
LSan may still flag glib's internal/one-time allocations. Since the gate is for
**corruption, not intentional/benign exit-time leaks**, default LSan off the same
way spimulator does — an ASan-guarded weak hook in the source:

```c
#if defined(__SANITIZE_ADDRESS__) || defined(__has_feature)
const char* __asan_default_options(void);
const char* __asan_default_options(void) { return "detect_leaks=0"; }
#endif
```

(spimulator places this unconditionally in `spim.c`; guarding it keeps the
non-ASan build clean. Decide whether to instead **fix** the error-path frees —
small and arguably worth doing — but defaulting LSan off keeps the gate focused
on memory *corruption*, which is the point.)

## Constraints

- **In-container only**, per the working arrangement. Trap UBSan needs no extra
  packages; ASan's runtime ships with clang — both already in the image. No
  permanent change to what the image ships beyond the opt-in gate itself.
- Nested-podman: `make image` needs no flags (`podman build` doesn't take `--cgroups`);
  run targets auto-apply `--cgroups=disabled` via `PODMAN_RUN_FLAGS` when nested.
- Don't touch `meson.build`'s default options; sanitized builds are separate
  setup dirs.

## Acceptance criteria

- A smoke/test harness exists and is a `meson test()` (the thing the gate runs);
  `meson test` is green in the normal build.
- `make image` (default `RUN_SANITIZERS=1`) builds + tests texExpToPng under
  **both** UBSan-trap and ASan and the image **fails** if any UB traps or any
  ASan error fires; `make image RUN_SANITIZERS=0` skips the gate and still builds.
- Any UB/memory issue surfaced is fixed (smallest-diff, behavior-preserving) or
  explicitly documented here before archiving.
- LSan decision recorded (defaulted off via the hook, vs. error-path frees fixed).
- Normal install build and `make example` output are unchanged.

## Open questions — resolved

- PNG content vs non-empty? **Both** — smoke.sh checks non-empty *and* the PNG
  magic bytes (`89504e47`) via `od`. Cheap and catches a truncated/garbage write.
- TeX-free usage-error case? **Added** (`tests/usage_error.sh`), as recommended.
