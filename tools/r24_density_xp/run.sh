#!/usr/bin/env bash
# Round 24 Lane F engine probe: live mobs per area by day and night at eight
# stationary probe points (six start zones, Moonfall Wood, Redtusk Savanna).
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped) and one disposable game patch:
#   after  - probe_player_shim.patch only (the current tree);
#   before - the shim plus the reverse of the Lane F grug_mobs change against
#            BASE, i.e. the Round 16 spawn rule. BASE defaults to the commit
#            before the Lane F change (the parent of the last commit touching
#            grug_mobs/density.lua), so other lanes' grug_mobs changes stay in.
# Copies the server log and the probe lines to OUT_DIR and removes the run
# directory. Exit 0 when the probe reached "RESULT DONE".
#
# Usage: tools/r24_density_xp/run.sh OUT_DIR before|after [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR before|after [TIMEOUT_SECONDS]}"
variant="${2:?usage: run.sh OUT_DIR before|after [TIMEOUT_SECONDS]}"
timeout_s="${3:-420}"
base="${BASE:-}"
if [[ -z "$base" ]]; then
	lane_f="$(git -C "$repo" log -n 1 --format=%H -- mods/ENTITIES/grug_mobs/density.lua)"
	base="$lane_f^"
fi
mkdir -p "$out"
patch_file="$out/game.patch"
cp "$here/probe_player_shim.patch" "$patch_file"
case "$variant" in
	after) ;;
	before) git -C "$repo" diff -R "$base" -- mods/ENTITIES/grug_mobs >>"$patch_file" ;;
	*) echo "variant must be before or after" >&2; exit 2 ;;
esac
set +e
SEED=4242424242 PROBE="$here/grug_probe_r24_density" GAME_PATCH="$patch_file" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r24_density_probe\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
cat "$out/probe.txt"
if grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r24 density probe ($variant): DONE (boot status $boot)"
	exit 0
fi
echo "r24 density probe ($variant): FAIL (boot status $boot)"
exit 1
