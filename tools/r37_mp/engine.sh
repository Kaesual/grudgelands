#!/usr/bin/env bash
# Round 37 lane MP engine restart test (grug_probe_r37_mp, staged into a
# throwaway game copy, never shipped): two boots of one world around
# Grimtusk's first route point. Boot 1 places six wild boars by a stand-in
# player and lets Grimtusk spawn, then shuts down; boot 2 checks that the
# boars and the one Grimtusk are back, that copies remove themselves and that
# a Grimtusk removed without a death is replaced by exactly one of the next
# generation. See the probe's header.
#
# Usage (worktree root): tools/r37_mp/engine.sh OUT_DIR
#   SEED defaults to 42. Two boots of at most 300 s each, one after the other
#   (one Lua process at a time: run it through lua_run.sh with 1 slot).
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r37_mp" "$probe/"
KEEP=1 SEED="${SEED:-42}" PROBE="$probe/grug_probe_r37_mp" \
	"$repo/tools/luanti_headless.sh" 300 >"$out/launcher1.txt" 2>&1
rc1=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher1.txt" | head -1)
rc2=1
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	ROOT="$root" PROBE="$probe/grug_probe_r37_mp" \
		"$repo/tools/luanti_headless.sh" 300 >"$out/launcher2.txt" 2>&1
	rc2=$?
	cp "$root/server.log" "$out/server1.log" 2>/dev/null
	cp "$root/server.2.log" "$out/server2.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -ah '\[r37mp\]' "$out/server1.log" "$out/server2.log" >"$out/probe.txt" 2>/dev/null
echo "boot1 rc=$rc1 boot2 rc=$rc2 root=$root" | tee -a "$out/launcher2.txt"
cat "$out/probe.txt"
[[ $(grep -c 'RESULT PASS' "$out/probe.txt") -eq 2 && $rc1 -eq 0 && $rc2 -eq 0 ]] && exit 0
exit 1
