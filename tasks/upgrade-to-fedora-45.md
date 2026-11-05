# Upgrade the container base from Fedora 44 to Fedora 45

**Status:** in progress
**Priority:** 3
**Difficulty:** 3

## BLUF

Bump `Dockerfile` from `registry.fedoraproject.org/fedora:44` to `fedora:45` and
get `make image` green nested (build the CLI + `meson test` + the UBSan/ASan
sanitizer gate, which `make image` turns on). "Done" = the image builds and all
build-time gates pass on the 45 base.

## Context (read first)

Part of a fleet-wide Fedora 44 → 45 bump (William Emerison Six
<billsix@gmail.com>, 2026-11-05). Fedora 45 ships **GCC 16.2 / clang from LLVM
23, glibc 2.44, Python 3.15**. This repo is C (meson + clang, `warning_level=3`,
plus a UBSan-trap/ASan gate), so the real risk is the toolchain bump surfacing a
new `-Werror`/sanitizer diagnostic. TeX Live version drift (the base install) is
a secondary risk. (Sibling repo spimulator hit clang's new
`-Wunused-but-set-global` — watch for the same class here.)

- Build gate: `make image` nested (`PODMAN_RUN_FLAGS` auto-adds
  `--cgroups=disabled` from `NESTED_PODMAN=1`).

## Plan

1. `Dockerfile`: `fedora:44` → `fedora:45`.
2. `make image` nested; read `--print-errorlogs` on failure.
3. Fix any new toolchain diagnostic minimally (discretion; log decisions here).
4. Re-run until green; stage by path; archive.

## Notes / findings

(appended as the build runs)
