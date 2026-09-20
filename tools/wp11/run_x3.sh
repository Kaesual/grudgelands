#!/usr/bin/env bash
# Native LuaJIT behavioral gate; an ordinary server boot is not a test pass.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="$(mktemp /tmp/grug-x3-launch.XXXXXX)"
trap 'rm -f "$output"' EXIT
if ! KEEP=1 PROBE="$repo/tools/wp11/probe_x3" \
    chrt --idle 0 ionice -c3 "$repo/tools/luanti_headless.sh" "${1:-40}" >"$output" 2>&1; then
    cat "$output"
    exit 1
fi
cat "$output"
log="$(sed -n 's/^log: //p' "$output")"
rg '^ACTION\[Server\]: WP11X3 RESULT PASS ' "$log"
if rg 'ability punch failed|authoritative swing failed|hit callback failed|WP11X3 FAIL' "$log"; then
    exit 1
fi
