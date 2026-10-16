#!/usr/bin/env bash
# 0.49.1 DOOR engine probe (fix-0.49.1-plan.md §4 DOOR): boots one isolated
# headless server through tools/luanti_headless.sh with the disposable
# grug_probe_r491_door staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and prints the probe's lines. One boot:
# run it through the shared Lua queue (1 slot).
#
# Usage: tools/r491_door/probe.sh [OUT_DIR] [TIMEOUT_SECONDS]
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:-$(mktemp -d)}"
timeout_s="${2:-300}"
mkdir -p "$out"
KEEP=1 PROBE="$here/grug_probe_r491_door" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
grep -a '\[r491door\]' "$out/server.log" 2>/dev/null | sed 's/.*\[r491door\] //' >"$out/probe.txt"
cat "$out/probe.txt"
echo "rc=$rc (logs in $out)"
grep -q 'RESULT DONE' "$out/probe.txt" || exit 1
grep -q 'RESULT FIX FAIL\|RESULT ERROR' "$out/probe.txt" && exit 1
exit 0
