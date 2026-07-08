# Fix bashrc exit() trap, dnf cache path, buildDebug symlink

**Status:** in progress — cache-path item resolved 2026-07-07; two items remain
**Created:** 2026-06-13

## Goal

Three small container-plumbing fixes in texExpToPng, mirroring the spimulator
cleanup plus one local script bug.

## Plan

- [ ] **`exit()` trap drops the exit code.** Same bug as spimulator: the
      Dockerfile assembles the `~/.bashrc` function with nested double-quotes
      (`echo "    builtin exit "$@"" >> ~/.bashrc`), so `$@` is expanded empty at
      build time and `exit 1` becomes `exit 0`. **Fix:** quote so `"$@"` lands
      literally, or `COPY` a real bashrc fragment.
- [x] **Stale cache path.** Resolved 2026-07-07, differently than planned:
      instead of bumping `PACKAGE_CACHE_ROOT` to `…/fedora/44`, the host
      package-cache scheme was removed entirely — Bill converged all projects
      on podman-internal `--mount=type=cache` (mvp style) so that
      `podman system reset` wipes the package caches too. `make image` gate
      passed after the removal.
- [ ] **`buildDebug.sh` non-idempotent symlink.** Ends with
      `ln -s builddir/compile_commands.json` (no `-f`), which works on first run
      but fails "File exists" on re-run. **Fix:** `ln -sf … compile_commands.json`
      with an explicit destination, matching spimulator's `buildDebug.sh`.

## Notes / decisions

- The earlier `%-30m` awk "typo" in the `help` target was a misread — the file
  has the correct `%-30s`. No change needed there.

## Open questions

- None.
