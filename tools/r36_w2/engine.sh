#!/usr/bin/env bash
# Round 36 lane W2 engine probe (grug_probe_r36_w2, staged into a throwaway
# game copy, never shipped): Highcourt's square round its anchor emerged, then
# every Highcourt bench seat measured: which half the engine raises (rays onto
# the cell's quarters) against its param2, and whether the house wall stands
# behind the seat or before it. A plain probe run (no timing comparison), so it
# runs directly.
#
# Usage (worktree root): tools/r36_w2/engine.sh OUT_DIR
#   SEED defaults to 42.
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r36_w2" "$probe/"
KEEP=1 SEED="${SEED:-42}" PROBE="$probe/grug_probe_r36_w2" \
	chrt --idle 0 "$repo/tools/luanti_headless.sh" 300 >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r36w2\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
grep -q 'RESULT DONE' "$out/probe.txt" && exit "$rc"
exit 1
