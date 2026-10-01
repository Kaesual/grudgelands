#!/usr/bin/env bash
# Round 28 Lane B4 engine probe: the registry built from the per-zone quest
# files equals the deleted Lua content generators' registry, and a sample
# new-format quest runs end to end with a player stand-in. The boot itself is
# the smoke test of the load-time validation against the real registries.
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r28_b4_quests/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-180}"
mkdir -p "$out"
# The staged probe carries the oracle and the shared canonical form.
probe="$out/grug_probe_r28_quests"
rm -rf "$probe"
cp -a "$here/grug_probe_r28_quests" "$probe"
cp "$here/canonical.lua" "$here/json.lua" "$here/legacy_registry.json" "$probe/"
set +e
PROBE="$probe" KEEP=1 "$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_quests_probe\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 quests probe: PASS"
	exit 0
fi
echo "r28 quests probe: FAIL (boot status $boot)"
exit 1
