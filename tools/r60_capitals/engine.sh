#!/usr/bin/env bash
# Round 60 lane CAPITALS engine probe (grug_probe_r60_capitals, staged into
# a throwaway game copy, never shipped): chapter 2's public register in Nhal
# Veyr on the running world (its cell, the node under it, its headroom and
# a top view of the forecourt round it), the two named foremen, and a
# player stand-in who takes T3 from Ossa and holds its claim notice; the
# object, its observers and the credit logged. A plain boot (no measuring
# run).
#
# Usage (worktree root): tools/r60_capitals/engine.sh OUT_DIR
#   SEED defaults to 42 (a quest-lane seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r60_capitals" "$probe/"
KEEP=1 SEED="${SEED:-42}" PROBE="$probe/grug_probe_r60_capitals" \
	chrt --idle 0 "$repo/tools/luanti_headless.sh" 330 >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r60cap\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
cat "$out/probe.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit "$rc"
exit 1
