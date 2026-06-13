# Fix bashrc exit() trap, dnf cache path, buildDebug symlink

**Status:** proposed — not started
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
- [ ] **Stale cache path.** `PACKAGE_CACHE_ROOT = ~/.cache/packagecache/fedora/43`
      vs base image `fedora:44`. **Fix:** bump to `…/fedora/44`.
- [ ] **`buildDebug.sh` non-idempotent symlink.** Ends with
      `ln -s builddir/compile_commands.json` (no `-f`), which works on first run
      but fails "File exists" on re-run. **Fix:** `ln -sf … compile_commands.json`
      with an explicit destination, matching spimulator's `buildDebug.sh`.

## Notes / decisions

- The earlier `%-30m` awk "typo" in the `help` target was a misread — the file
  has the correct `%-30s`. No change needed there.

## Open questions

- None.
