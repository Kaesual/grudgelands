#!/usr/bin/env bash
# Round 51 lane MOBS, step M1: one engine run with the disposable probe
# grug_probe_r51_mobs (its header: the new water mobs spawned by command in a
# test arena, amphibians chasing ashore and back, the swimmer reset, fish
# drops). Boots one isolated headless server through tools/luanti_headless.sh
# with mob spawning off (a game patch to the staged copy only), copies the
# server log to OUT_DIR, removes the run directory and exits 0 only on
# "RESULT PASS". Run it through the shared Lua queue (one boot).
#
# Usage: tools/r51_mobs/probe.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: probe.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
patchdir="$(mktemp -d)"
trap 'rm -rf "$patchdir"' EXIT
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
printf '\n# Round 51 MOBS probe: no natural spawns in the arena\nmobs_spawn = false\n' \
	>>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true
set +e
PROBE="$here/grug_probe_r51_mobs" GAME_PATCH="$patchdir/probe.patch" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r51mobs\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r51 mobs probe: PASS"
	exit 0
fi
echo "r51 mobs probe: FAIL (boot status $boot)"
exit 1
