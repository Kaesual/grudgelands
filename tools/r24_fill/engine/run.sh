#!/usr/bin/env bash
# One bounded Round 24 Lane B probe run (coal stage, optional scan, optional
# render/timing boxes). Usage:
#   GAME_REPO=<tree> SEED=<n> OUT=<dir> [SCAN=true] [BOXES=spec] run.sh RADIUS STOP_S TIMEOUT_S
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="${GAME_REPO:?GAME_REPO}"
radius="$1"; stop="$2"; timeout_s="$3"
out="${OUT:?OUT}"; mkdir -p "$out"
python3 "$here/make_patch.py" "$repo" >"$out/game.patch"
cat >>"$out/game.patch" <<EOP
--- a/minetest.conf
+++ b/minetest.conf
@@ -198,1 +198,5 @@
 grug_prepare_full_world = false
+coalprobe_radius = $radius
+coalprobe_stop = $stop
+r24_scan = ${SCAN:-false}
+r24_boxes = ${BOXES:-}
EOP
root="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
echo "root: $root out: $out repo: $repo"
cleanup() {
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	cp "$root/world/map_meta.txt" "$out/" 2>/dev/null || true
	cp "$root"/world/r24_dump_*.tsv "$out/" 2>/dev/null || true
	rm -rf "$root"
}
trap cleanup EXIT
set +e
ROOT="$root" SEED="${SEED:?SEED}" PROBE="$here/probe/coalprobe" GAME_PATCH="$out/game.patch" \
	chrt --idle 0 ionice -c3 "$repo/tools/luanti_headless.sh" "$timeout_s" | tee "$out/launcher.txt"
set -e
