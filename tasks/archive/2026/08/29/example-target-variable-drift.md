# `example` target drift — literal `podman run` / image name instead of the variables

**Status:** complete — applied 2026-08-29 with maintainer approval; `make -n example`
verified byte-identical before/after.
**Completed:** 2026-08-29
**Priority:** 7
**Difficulty:** 1
**Found:** 2026-08-29 (William Emerison Six <billsix@gmail.com>), during the fleet-wide
`PODMAN_RUN_FLAGS` fan-out — work record: runClaudeInContainer
(github.com/billsix/runClaudeInContainer)
`tasks/archive/2026/08/29/nested-podman-run-flags-passthrough.md`.

## BLUF

The `example` target (`Makefile:129–133`) invokes literal `podman run` and the literal image
name `tex-expression-to-png` where every other target uses `$(CONTAINER_CMD)`
(`Makefile:11`) and `$(CONTAINER_NAME)` (`Makefile:12`). Behavior is identical today — the
variables expand to exactly those strings — but a future change to either variable would
silently miss this one target. Done = the target uses the variables and `make -n example`
output is byte-identical before/after.

## Context

Found while threading `$(PODMAN_RUN_FLAGS)` into the run lines (that change is already staged,
2026-08-29, and did cover this line); the literal-vs-variable drift predates it and was left
out of that mechanical pass. No conversation context needed — the fix is two substitutions in
the `example` recipe:

- `podman run` → `$(CONTAINER_CMD) run` (`Makefile:130`);
- the image argument `tex-expression-to-png` → `$(CONTAINER_NAME)` (`Makefile:132`) — the
  image name only, not the `-v ./output:/output/:Z` mount or the TeX/size/filename arguments.

Verify: capture `make -n example` before and after — expect byte-identical output (the
variables expand to the same strings).

## Open questions

None.
