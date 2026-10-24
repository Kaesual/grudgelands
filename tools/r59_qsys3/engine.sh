#!/usr/bin/env bash
# Round 59 lane QSYS3 engine probe (grug_probe_r59_qsys3, staged into a
# throwaway game copy, never shipped): a town place (a quest_place socket)
# inside Highcourt's Miner's Guild house, a player stand-in holding its
# quest object; the cell's roof, the object, observers and the credit logged.
# A plain boot (no measuring run).
#
# Usage (worktree root): tools/r59_qsys3/engine.sh OUT_DIR
#   SEED defaults to 42 (a quest-lane seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r59_qsys3" "$probe/"
KEEP=1 SEED="${SEED:-42}" PROBE="$probe/grug_probe_r59_qsys3" \
	chrt --idle 0 "$repo/tools/luanti_headless.sh" 300 >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r59qsys3\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
cat "$out/probe.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit "$rc"
exit 1
