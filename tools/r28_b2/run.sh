#!/usr/bin/env bash
# Round 28 Lane B2 engine probe: sub-types, zone names and tints, family
# alert and loot by band on the real registry and mobs_redo AI.
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Boots one isolated headless server through tools/luanti_headless.sh with
# the disposable probe mod staged (never shipped) and a GAME_PATCH that puts
# the test catalogue sample/data/*.json into the STAGED grug_mobs/data/ (the
# shipped files stay empty). Copies the server log to OUT_DIR, removes the
# run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/r28_b2/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
patch_file="$out/sample_data.patch"
: >"$patch_file"
for f in subtypes items drops tints; do
	rel="mods/ENTITIES/grug_mobs/data/$f.json"
	diff -u --label "a/$rel" --label "b/$rel" "$repo/$rel" "$here/sample/data/$f.json" \
		>>"$patch_file" || true
done
set +e
GAME_PATCH="$patch_file" PROBE="$here/grug_probe_r28_b2" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_b2_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 b2 probe: PASS"
	exit 0
fi
echo "r28 b2 probe: FAIL (boot status $boot)"
exit 1
