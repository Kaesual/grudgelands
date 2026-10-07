#!/usr/bin/env bash
# Round 41 lane UP engine test: the platform's map reset on a test world.
# Two boots of the same isolated world through tools/luanti_headless.sh with
# the disposable probe tools/r41_up/grug_probe_r41_up (never shipped):
#   boot 1  a fresh world: preparation, start NPCs, a Claim Stone for
#           "oldhero"; the probe notes what boot 2 checks and shuts down;
#   then what the platform does while the server is stopped: delete the map
#           database (map.sqlite; map_meta.txt and the rest of the world
#           folder stay) and raise grug_reset_world to 1 (a disposable patch
#           of the staged game's minetest.conf, never the repository);
#   boot 2  the reset: clears, held and moved old character, new character,
#           the starts prepared again, the old claim node gone.
# Copies both logs to OUT_DIR, removes the run directory and exits 0 only
# when both boots report "RESULT PASS" and the seed survived.
#
# Usage: tools/r41_up/engine.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> pins the first boot's seed (default 42).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-290}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
probe="$here/grug_probe_r41_up"
status=1
root=""
cleanup() {
	if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
		rm -rf "$root"
	fi
}
trap cleanup EXIT

set +e
SEED="${SEED:-42}" PROBE="$probe" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/boot1.txt" 2>&1
boot1=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/boot1.txt" | tail -n 1)"
[[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root/world" ]] || {
	cat "$out/boot1.txt"; echo "r41 up engine: no kept run directory"; exit 1; }
cp "$root/server.log" "$out/boot1.log"
grep -h '\[r41_up_probe\]' "$out/boot1.log" >"$out/probe1.txt" || true
seed_before="$(grep -h '^seed' "$root/world/map_meta.txt")"

# The platform's part, with the server stopped.
ls -la "$root/world" >"$out/world_before_reset.txt"
[[ -f "$root/world/map.sqlite" ]] || { echo "r41 up engine: no map database"; exit 1; }
rm -f "$root/world/map.sqlite" "$root/world/map.sqlite-journal" \
	"$root/world/map.sqlite-wal" "$root/world/map.sqlite-shm"
ls -la "$root/world" >"$out/world_after_reset.txt"
{ cat "$repo/minetest.conf"; printf '\n# The platform raises this for a map reset.\ngrug_reset_world = 1\n'; } \
	>"$out/minetest.conf.reset"
diff -u --label a/minetest.conf --label b/minetest.conf \
	"$repo/minetest.conf" "$out/minetest.conf.reset" >"$out/reset.patch" || true
rm -f "$out/minetest.conf.reset"

set +e
ROOT="$root" PROBE="$probe" GAME_PATCH="$out/reset.patch" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/boot2.txt" 2>&1
boot2=$?
set -e
cp "$root/server.2.log" "$out/boot2.log"
grep -h '\[r41_up_probe\]' "$out/boot2.log" >"$out/probe2.txt" || true
grep -h '\[grug_core\] map reset\|\[grug_core\] world preparation' "$out/boot2.log" \
	>"$out/reset_lines.txt" || true
seed_after="$(grep -h '^seed' "$root/world/map_meta.txt")"

cat "$out/boot1.txt" "$out/boot2.txt"
cat "$out/reset_lines.txt"
echo "seed before: $seed_before / after: $seed_after"
if [[ $boot1 -eq 0 && $boot2 -eq 0 && "$seed_before" == "$seed_after" ]] &&
		grep -q 'RESULT PASS' "$out/probe1.txt" && grep -q 'RESULT PASS' "$out/probe2.txt"; then
	status=0
	echo "r41 up engine: PASS"
else
	echo "r41 up engine: FAIL (boot statuses $boot1 $boot2)"
fi
exit $status
