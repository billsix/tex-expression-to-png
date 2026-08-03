#!/bin/sh
# TeX-free test: invoking with a missing required argument (--size / --output)
# must hit the usage-error path (print_usage + fatal_error) and exit non-zero.
# Keeps the pure-C option-parsing/validation paths gated under the sanitizers
# even if latex/dvipng were unavailable.
: "${TEXEXP_BIN:?TEXEXP_BIN must point at the texExpToPng binary}"

if "$TEXEXP_BIN" --exp 'x'; then
    echo "usage_error: expected non-zero exit for missing --size/--output" >&2
    exit 1
fi
exit 0
