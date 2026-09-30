#!/usr/bin/env bash
# Round 27 Lane Q engine probe: grug_core.item_name over the real item
# registry and every quest rendered through the real dialogue, quest-log and
# tracker code. A headless server has no client, so the probe uses a player
# stand-in.
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r27_quest_item_names/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-120}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_quest_item_names" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[quest_item_names_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "quest item names probe: PASS"
	exit 0
fi
echo "quest item names probe: FAIL (boot status $boot)"
exit 1
