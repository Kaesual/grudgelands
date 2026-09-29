#!/usr/bin/env bash
# Round 24 Lane I engine run (tools/r24_fill/engine/run.sh with an
# r24-lane-i- scratch root): the Lane B coal probe (small Orc-start box), then
# emerges a housing box (timeH) and a nearby non-housing box (timeN) of the
# Redtusk Savanna, same zone and biome, and dumps a 64 x 64 core of each.
# GAME_TREE is `git archive` of main (before) or of the branch (after).
# Usage: run.sh GAME_TREE OUT; then analyze.py BEFORE_OUT AFTER_OUT
set -euo pipefail
export LC_ALL=C
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../r24_fill/engine" && pwd -P)"
repo="$1"; out="$2"
SEED=10536739806879207652
BOXES="timeH:368:1968:527:2127:-112:207;timeN:608:1968:767:2127:-112:207;H:416:2016:479:2079:-112:170;N:656:2016:719:2079:-112:120"
mkdir -p "$out"
python3 "$TOOLS/make_patch.py" "$repo" >"$out/game.patch"
cat >>"$out/game.patch" <<EOP
--- a/minetest.conf
+++ b/minetest.conf
@@ -198,1 +198,5 @@
 grug_prepare_full_world = false
+coalprobe_radius = 32
+coalprobe_stop = 120
+r24_scan = false
+r24_boxes = $BOXES
EOP
root="$(mktemp -d /tmp/grudgelands-headless.r24-lane-i-XXXXXX)"
echo "root: $root out: $out repo: $repo"
cleanup() {
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root/world/map_meta.txt" "$out/" 2>/dev/null || true
	cp "$root"/world/r24_dump_*.tsv "$out/" 2>/dev/null || true
	rm -rf "$root"
}
trap cleanup EXIT
set +e
ROOT="$root" SEED="$SEED" PROBE="$TOOLS/probe/coalprobe" GAME_PATCH="$out/game.patch" \
	chrt --idle 0 ionice -c3 "$repo/tools/luanti_headless.sh" 290 | tee "$out/launcher.txt"
set -e
