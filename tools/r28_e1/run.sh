#!/usr/bin/env bash
# Round 28 Lane E1 engine probe: the shipped catalogue (sub-types, tints,
# items, drops by band, enchants) on the real registry and mobs_redo AI.
#
# First checks that the shipped data files are byte copies of the design
# catalogue (docs/planning/round28/design/catalog/). Then stages the
# disposable probe mod (never shipped) with that catalogue in its catalog/
# directory into one isolated headless server (tools/luanti_headless.sh),
# copies the server log to OUT_DIR, removes the run directory and exits 0
# only on "RESULT PASS".
#
# Usage: tools/r28_e1/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
catalog="$repo/docs/planning/round28/design/catalog"

synced=1
for f in subtypes items drops tints; do
	cmp -s "$catalog/$f.json" "$repo/mods/ENTITIES/grug_mobs/data/$f.json" ||
		{ echo "out of sync: mods/ENTITIES/grug_mobs/data/$f.json"; synced=0; }
done
cmp -s "$catalog/enchants.json" "$repo/mods/ITEMS/grug_professions/data/enchants.json" ||
	{ echo "out of sync: mods/ITEMS/grug_professions/data/enchants.json"; synced=0; }
if [[ $synced -eq 0 ]]; then
	echo "r28 e1 probe: FAIL (shipped data differs from the catalogue)"
	exit 1
fi

probe="$out/grug_probe_r28_e1"
rm -rf "$probe"
cp -r "$here/grug_probe_r28_e1" "$probe"
mkdir -p "$probe/catalog"
cp "$catalog"/{subtypes,items,drops,tints,enchants}.json "$probe/catalog/"

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
grep -h '\[r28_e1_probe\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
grep -v '^.*ACTION\[Server\]: \[r28_e1_probe\] [a-z_]* L[0-9]* drops ' "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 e1 probe: PASS"
	exit 0
fi
echo "r28 e1 probe: FAIL (boot status $boot)"
exit 1
