#!/usr/bin/env bash
# One headless boot of the real game with the disposable HUD probe staged in.
#
# A headless server has NO client, so nothing about the HUD can be SEEN here.
# What this proves is the whole server side of it: the game loads with the new
# grug_core module in it, grug_core.hud_layout is what the fixture says it is
# inside the real engine, and the shipped join callbacks of grug_abilities,
# grug_xp and grug_money hand the engine the element definitions they should
# -- read back through `hud_get` on a fake player object.
#
# Lane H port block: 31300-31399. Writes only under /tmp; the user's personal
# Luanti folder is never touched (tools/luanti_headless.sh owns that rule).
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo" || exit 1

port="${PORT:-31307}"
out="$(KEEP=1 PORT="$port" PROBE="$repo/tools/ui/probe/grug_hud_probe" \
	nice -n 19 tools/luanti_headless.sh 120 2>&1)"
echo "$out"
root="$(printf '%s\n' "$out" | sed -n 's/^kept: //p' | tail -1)"
if [[ -z "$root" ]]; then
	echo "no run directory was kept -- nothing to read"
	exit 1
fi
echo "== probe output =="
grep -h 'HUDPROBE' "$root"/server.log 2>/dev/null | sed 's/.*HUDPROBE /HUDPROBE /'
echo "== errors =="
grep -h 'ERROR\|ModError\|WARNING\[Server\]' "$root"/server.log 2>/dev/null |
	head -20
echo "run directory: $root (delete it when the evidence is written)"
