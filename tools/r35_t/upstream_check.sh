#!/usr/bin/env bash
# Round 35 T upstream check (docs/technical/upstream-workarounds.md): boots
# the headless server of the installed engine with grug_probe_r35_t_upstream
# (staged into a throwaway game copy, never shipped) and prints whether the
# ENGINE's server raycast hits a rotated selection box at every yaw. "FIXED"
# means the rotated-box workaround in grug_core/combat_ray.lua can go.
# A plain boot (no measurement), so no semaphore.
#
# Usage (worktree or repo root): tools/r35_t/upstream_check.sh [OUT_DIR]
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:-$(mktemp -d)}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r35_t_upstream" "$probe/"
KEEP=1 PROBE="$probe/grug_probe_r35_t_upstream" \
	chrt --idle 0 "$repo/tools/luanti_headless.sh" 300 >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r35tup\]' "$out/server.log" 2>/dev/null | sed 's/.*\[r35tup\] //' >"$out/probe.txt"
cat "$out/probe.txt"
echo "rc=$rc (logs in $out)"
grep -q 'RESULT DONE' "$out/probe.txt" || exit 1
grep -q 'RESULT UPSTREAM .*FIXED' "$out/probe.txt" && exit 0
exit 3
