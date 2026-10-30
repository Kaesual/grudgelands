#!/usr/bin/env bash
# Round 67 lane WORLD engine run (grug_probe_r67_world, staged into a
# throwaway game copy, never shipped; its header says what it measures): one
# isolated headless boot through tools/luanti_headless.sh, the probe's lines
# copied to OUT_DIR, the run directory removed. Exits 0 only on "RESULT PASS".
# Run it through the shared Lua queue (one boot).
#
# Usage: tools/r67_world/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED (default 42), WINDOW seconds per window (default 60), SPIDER_CHANCE
#   (default 300: the Giant Spider rows' chance for this probe only, through
#   mobs_redo's per-mob setting, for a larger sample; shipped 1800).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
patchdir="$(mktemp -d)"
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
{
	echo ""
	echo "# Round 67 WORLD probe"
	echo "max_forceloaded_blocks = 2000"
	echo "grug_r67_window = ${WINDOW:-60}"
	echo "grug_mobs:giant_spider = ${SPIDER_CHANCE:-300},4"
} >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r67_world" GAME_PATCH="$patchdir/probe.patch" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
rm -rf "$patchdir"
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r67world\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r67 world probe: PASS (boot status $boot)"
	exit 0
fi
echo "r67 world probe: FAIL (boot status $boot)"
exit 1
