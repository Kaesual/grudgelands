#!/usr/bin/env bash
# Round 59 lane STORYQUESTS engine probe (grug_probe_r59_storyquests, staged
# into a throwaway game copy, never shipped): chapter 1's six town places on
# the running world (each cell, the node under it and its headroom), and at
# Highcourt's a player stand-in who holds story_accord_02's quest object;
# the object, its observers and the credit logged. A plain boot (no
# measuring run).
#
# Usage (worktree root): tools/r59_storyquests/engine.sh OUT_DIR
#   SEED defaults to 42 (a quest-lane seed).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r59_storyquests" "$probe/"
KEEP=1 SEED="${SEED:-42}" PROBE="$probe/grug_probe_r59_storyquests" \
	chrt --idle 0 "$repo/tools/luanti_headless.sh" 330 >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r59sq\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
cat "$out/probe.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit "$rc"
exit 1
