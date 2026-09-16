#!/usr/bin/env bash
# Wall-clock of the WP11 phase-1 checks, so the evidence carries timings and
# not adjectives. Usage (from the repository root): bash tools/wp11/timings.sh
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"

timed() {
	local label="$1"
	shift
	local start end
	start="$(date +%s.%N)"
	"$@" >/dev/null 2>&1
	local status=$?
	end="$(date +%s.%N)"
	printf '%-34s %6.2f s  exit %d\n' "$label" \
		"$(echo "$end - $start" | bc)" "$status"
}

KAT='io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))'

timed "talent KAT, LuaJIT" luajit -e "$KAT"
timed "talent KAT, PUC 5.1" "$repo/tools/bin/lua51" -e "$KAT"
timed "eight mutations" bash tools/wp11/mutations.sh
timed "static gates" bash tools/wp11/static.sh
timed "final_micro, LuaJIT" luajit tools/wp13/final_micro.lua . \
	/tmp/wp11-timing-micro-luajit.tsv luajit
timed "final_micro, PUC 5.1" "$repo/tools/bin/lua51" \
	tools/wp13/final_micro.lua . /tmp/wp11-timing-micro-puc.tsv puc51
rm -f /tmp/wp11-timing-micro-luajit.tsv /tmp/wp11-timing-micro-puc.tsv
