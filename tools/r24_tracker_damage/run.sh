#!/usr/bin/env bash
# Round 24 Lane E engine probe: the real hp-change modifier chain against the
# real lava/water registrations, and quest-tracker lines built from the real
# quest/NPC/item registry. A headless server has no client, so the probe
# drives the registered modifiers with a player stand-in exactly as builtin's
# dispatcher does (builtin/game/register.lua:546-564).
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r24_tracker_damage/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-120}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_tracker_damage" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[tracker_damage_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "tracker/damage probe: PASS"
	exit 0
fi
echo "tracker/damage probe: FAIL (boot status $boot)"
exit 1
