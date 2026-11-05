# Upgrade the container base from Fedora 44 to Fedora 45 (done)

Done 2026-11-05 (William Emerison Six <billsix@gmail.com>). Part of a fleet-wide
Fedora 44 → 45 bump.

## What changed

- `Dockerfile`: `registry.fedoraproject.org/fedora:44` → `fedora:45`.

No source changes were needed. `make image` is green nested on the 45 base —
the full gate passed: CLI build + `meson test` (smoke render + TeX-free usage
error) + the UBSan-trap/ASan sanitizer gate (`RUN_SANITIZERS=1` default). Image
`localhost/tex-expression-to-png:latest`.

The LLVM 23 toolchain produced no new `-Werror`/sanitizer breakage for this
codebase (`gnu11`, single source file). TeX Live installed cleanly on the 45
base.
