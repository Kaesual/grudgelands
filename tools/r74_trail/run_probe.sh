#!/usr/bin/env bash
# Round 74 lane TRAIL: the engine probe (grug_probe_r74_trail), no client. Boots
# tools/luanti_headless.sh with the probe; WHICH=base stages the base commit's
# aggro.lua (GAME_PATCH: the reverse diff against BASE, default 4b6a91fc).
# Usage: tools/r74_trail/run_probe.sh OUT_DIR [branch|base]
# Writes OUT_DIR/<which>.txt (the probe's lines) and keeps the server log there.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run_probe.sh OUT_DIR [branch|base]}"; which="${2:-branch}"
mkdir -p "$out"; out="$(cd "$out" && pwd -P)"
patch_env=()
if [[ "$which" == base ]]; then
	git -C "$repo" diff HEAD "${BASE:-4b6a91fc}" -- mods/ENTITIES/grug_mobs/aggro.lua >"$out/base.patch"
	patch_env=(GAME_PATCH="$out/base.patch")
fi
set +e
env KEEP=1 PROBE="$here/grug_probe_r74_trail" SEED="${SEED:-42}" "${patch_env[@]}" \
	bash "$repo/tools/luanti_headless.sh" "${TIMEOUT:-300}" >"$out/$which.headless.txt" 2>&1
set -e
root="$(sed -n 's/^kept: //p' "$out/$which.headless.txt")"
log="$(sed -n 's/^log: //p' "$out/$which.headless.txt")"
if [[ -n "$log" && -f "$log" ]]; then
	cp "$log" "$out/$which.server.log"
	grep -a '\[r74trail\]\|GRUG-SEVERE\|ERROR' "$log" >"$out/$which.txt" || true
fi
[[ -n "$root" && "$root" == /tmp/grudgelands-headless.* ]] && rm -rf "$root"
cat "$out/$which.txt" 2>/dev/null || true
