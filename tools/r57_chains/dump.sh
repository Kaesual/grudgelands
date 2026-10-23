#!/usr/bin/env bash
# Round 57 lane CHAINDEPTH: boots the game headless once with the disposable
# probe mod grug_probe_r57_chains and copies the recipe dump it writes into
# the world directory to OUT (default: OUT_DIR/dump.lua of run.sh).
#
# Usage: tools/r57_chains/dump.sh OUT_FILE [TIMEOUT_SECONDS]
# One engine boot: run it through the shared Lua queue.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
target="${1:?usage: dump.sh OUT_FILE [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
set +e
PROBE="$here/grug_probe_r57_chains" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
status=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
dump=""
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	grep -h "\[r57chains_probe\]\|ERROR\|GRUG-SEVERE" "$root/server.log" || true
	[[ -f "$root/world/r57_chains_dump.lua" ]] &&
		cp "$root/world/r57_chains_dump.lua" "$out/dump.lua" && dump="$out/dump.lua"
	rm -rf "$root"
fi
tail -n 5 "$out/headless.txt"
if [[ -z "$dump" ]]; then
	echo "r57 chains dump: FAIL"
	exit 1
fi
{
	echo "-- Commit: $(git -C "$repo" rev-parse --short HEAD)$(git -C "$repo" diff --quiet HEAD -- mods || echo ' (mods modified)')"
	cat "$dump"
} >"$target"
echo "r57 chains dump: wrote $target (launcher status $status)"
