#!/usr/bin/env bash
# Round 84 lane ELITE engine probe (grug_probe_r84_elite, staged into a
# throwaway game copy, never shipped): at one leader's spot, a few forceloaded
# blocks and no player, an object made unsaved after its add, a leader added
# the 0.83.0 way and a leader added through grug_mobs.add_mob_unsaved; the
# blocks are unloaded with all three alive and loaded again, and the probe
# counts what comes back. Also the lane's smoke boot (the launcher's PASS).
#
# Usage (worktree root): tools/r84_elite/engine.sh OUT_DIR
#   Through the shared queue, one slot:
#   ~/projects/grudgelands-orchestration/r45/lua_run.sh r84-elite 1 tools/r84_elite/engine.sh OUT
#   SEED defaults to 12345.
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r84_elite" "$probe/"
KEEP=1 SEED="${SEED:-12345}" PROBE="$probe/grug_probe_r84_elite" \
	"$repo/tools/luanti_headless.sh" 300 >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r84elite\]\|StaticObjectList::remove' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
grep -q 'RESULT PASS' "$out/probe.txt" && exit "$rc"
exit 1
