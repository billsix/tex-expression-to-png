#!/bin/sh
# Smoke test: render a known-good expression and assert the binary exits 0 and
# writes a real (non-empty, PNG-signature) file. Exercises the C we own —
# option parsing, the g_fprintf document assembly, both g_spawn calls and their
# exit-status handling — plus the real latex + dvipng pipeline.
#
# This is the harness the sanitizer gate runs under ASan/UBSan, so it is
# deliberately a single linear assertion chain: set -e makes every step's
# failure abort with a non-zero status (fail-fast is correct for one test; the
# "run every case, report all red" job belongs to meson's test runner, which
# runs this and usage_error.sh as separate test() targets).
set -e

: "${TEXEXP_BIN:?TEXEXP_BIN must point at the texExpToPng binary}"

# formula.tex/.dvi are written CWD-relative, so run in a throwaway scratch dir.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

out="$work/out.png"
# The expression is written verbatim into the LaTeX body, so it must carry its
# own math-mode delimiters ($...$); a bare 'E = m c^2' errors "Missing $".
"$TEXEXP_BIN" --exp '$E = m c^2$' --size 200 --output "$out"

test -s "$out"   # exists and non-empty

# PNG magic bytes: 89 50 4e 47 ("\x89PNG").
sig="$(od -An -tx1 -N4 "$out" | tr -d ' \n')"
if [ "$sig" != "89504e47" ]; then
    echo "smoke: output is not a PNG (leading bytes: $sig)" >&2
    exit 1
fi
