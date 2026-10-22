#!/usr/bin/env bash
# Round 56 lane MOBAI: one engine run with the disposable probe
# grug_probe_r56_mobai (its header: a Skeleton Archer closing in on a player
# 22 m away, the aggro radius by level gap). Boots one isolated headless
# server through tools/luanti_headless.sh with mob spawning off (a game patch
# to the staged copy only), copies the server log to OUT_DIR, removes the run
# directory and exits 0 only on "RESULT PASS". Run it through the shared Lua queue (one boot).
#
# Usage: tools/r56_mobai/probe.sh OUT_DIR [TIMEOUT_SECONDS]
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
printf '\n# Round 56 MOBAI probe: no natural spawns\nmobs_spawn = false\n' \
	>>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true
set +e
PROBE="$here/grug_probe_r56_mobai" GAME_PATCH="$patchdir/probe.patch" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r56mobai\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r56 mobai probe: PASS"
	exit 0
fi
echo "r56 mobai probe: FAIL (boot status $boot)"
exit 1
