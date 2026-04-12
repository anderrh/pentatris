#!/bin/bash
set -euo pipefail

# Locate Bazel runfiles directory
if [[ -n "${RUNFILES_DIR:-}" ]]; then
    RDIR="$RUNFILES_DIR"
elif [[ -d "${BASH_SOURCE[0]}.runfiles" ]]; then
    RDIR="${BASH_SOURCE[0]}.runfiles"
else
    echo "ERROR: cannot find runfiles" >&2
    exit 1
fi

WS="$RDIR/_main"

# Find node — try the canonical bzlmod repo name
NODE="$RDIR/_main~toolchains~nodejs/bin/node"
if [[ ! -x "$NODE" ]]; then
    # Fallback: search for it
    NODE=$(find "$RDIR" -name node -path '*/bin/node' -type f -o -name node -path '*/bin/node' -type l 2>/dev/null | head -1)
fi

export SERVERBOY_PATH="$WS/third_party/serverboy/src/interface.js"

# Run all ROM arguments through the test runner
exec "$NODE" "$WS/tests/run_tests.js" "$@"
