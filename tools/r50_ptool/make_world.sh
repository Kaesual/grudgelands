#!/usr/bin/env bash
# Round 50 lane PTOOL: builds the engine-written test world of the pre-reset
# pass (tools/r50_ptool/world/). One run of tools/luanti_headless.sh on an
# isolated run directory, pointed at a world folder of its own (`--world`,
# the engine's last one wins) whose world.mt names SQLite for the map and
# every other backend, with the disposable probe
# tools/r50_ptool/grug_probe_r50_ptool (its header lists what it builds: two
# claims, the containers, their contents). The probe shuts the server down;
# the shutdown saves the blocks.
# Copies world.mt, map.sqlite, mod_storage.sqlite and the probe's record
# r50_ptool_probe.json to OUT_DIR and removes the run directory; trim.py
# then keeps only the map blocks the tests read.
#
# Usage: tools/r50_ptool/make_world.sh OUT_DIR
#   Start it through the round's process queue (one slot).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: make_world.sh OUT_DIR}"
root="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
cleanup() {
	if [[ "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
		rm -rf "$root"
	fi
}
trap cleanup EXIT
world="$root/w50"
mkdir -p "$world"
printf '%s\n' 'gameid = grudgelands' 'world_name = r50_ptool' 'backend = sqlite3' \
	'player_backend = sqlite3' 'auth_backend = sqlite3' 'mod_storage_backend = sqlite3' \
	>"$world/world.mt"

set +e
ROOT="$root" PROBE="$here/grug_probe_r50_ptool" SEED=42 \
	"$repo/tools/luanti_headless.sh" 280 --world "$world" >"$root/run1.txt" 2>&1
run1=$?
set -e
cat "$root/run1.txt"
grep -h 'r50_ptool_probe\|ERROR' "$root"/server*.log | head -20 || true
[[ -f "$world/r50_ptool_probe.json" && -f "$world/map.sqlite" ]] || {
	echo "make_world: the probe did not finish (status $run1)"
	exit 1
}
mkdir -p "$out"
cp "$world/world.mt" "$world/map.sqlite" "$world/mod_storage.sqlite" \
	"$world/r50_ptool_probe.json" "$out/"
ls -l "$out"
echo "make_world: PASS"
