#!/usr/bin/env bash
# Round 25 Lane C engine probe: the Housing Manager in the six capitals (socket
# role, world position, the placed NPC) and the stone form, Manager form and
# Character status built with the real engine helpers.
#
# Until Lane A's claim core lands, grug_housing's mod.conf on this branch has
# `depends = grug_core` only; housing_depends.patch adds the grug_mapgen and
# grug_mobs dependencies the Manager needs to the STAGED game copy only
# (GAME_PATCH), so no repo file is changed. Drop GAME_PATCH once main carries
# the line.
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r25_interfaces/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-290}"
mkdir -p "$out"
patch_args=()
if ! grep -q 'grug_mobs' "$repo/mods/PLAYER/grug_housing/mod.conf"; then
	patch_args=(GAME_PATCH="$here/housing_depends.patch")
fi
set +e
env "${patch_args[@]}" PROBE="$here/grug_probe_r25_interfaces" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r25_interfaces_probe\]\|placed at socket \(market_counting_house\|forge_guild_house\|market_weaver\|market_shroud_house\|warren_weaver\|shore_tailor\)/' \
	"$out/server.log" 2>/dev/null | grep -v '^$' | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r25 interfaces probe: PASS"
	exit 0
fi
echo "r25 interfaces probe: FAIL (boot status $boot)"
exit 1
