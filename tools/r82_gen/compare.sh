#!/usr/bin/env bash
# Round 82 lane BASE: the round's yardstick for world generation. Runs the
# reference seed set (tools/r82_gen/seeds.txt, 20 seeds) through the seed
# fleet in digest mode with the dense chunks (tools/seed_fleet/seed.lua) on
# the CURRENT tree, eight in parallel through the shared Lua queue, and
# compares every seed's digest with the committed reference
# (tools/r82_gen/reference/<seed>.txt).
#
#   tools/r82_gen/compare.sh             compare; exit 0 only when every seed
#                                        is identical
#   tools/r82_gen/compare.sh --capture   write the reference instead (BASE and
#                                        an accepted output change only)
#
# Prints per seed "identical" or the first differing item (a layout, the
# roster, or a chunk "minp (label)" with which of nodes, light, meta differ)
# and a summary line. The run directory (digests, the fleet's output and
# logs) is printed and kept when a seed differs or KEEP=1; compare.lua then
# compares it again without a new run:
#   luajit tools/r82_gen/compare.lua tools/r82_gen/reference RUN/digests tools/r82_gen/seeds.txt
# Environment: QUEUE=<script> the queue (default the workstation's
# lua_run.sh; runs unqueued when it is missing), REF=<dir> another reference.
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
mode="${1:-compare}"
[[ "$mode" == compare || "$mode" == --capture ]] || {
	echo "usage: $0 [--capture]" >&2
	exit 2
}
ref="${REF:-$here/reference}"
queue="${QUEUE:-$HOME/projects/grudgelands-orchestration/r45/lua_run.sh}"
run=()
[[ -x "$queue" ]] && run=("$queue" r82-gen 8)
out="$(mktemp -d /tmp/r82_gen.XXXXXX)"
started=$SECONDS
SEEDS="$here/seeds.txt" DIGEST="$out/digests" DENSE=1 JOBS=8 RESULTS="$out/results.tsv" \
	"${run[@]}" "$repo/tools/seed_fleet/run.sh" full >"$out/fleet.txt" 2>&1
fleet=$?
echo "fleet: $(tail -n 1 "$out/fleet.txt") (exit $fleet, $((SECONDS - started)) s with the queue wait)"
if [[ "$mode" == --capture ]]; then
	if [[ $fleet -ne 0 ]]; then
		echo "not captured: a seed failed; run directory $out" >&2
		exit 1
	fi
	mkdir -p "$ref"
	rm -f "$ref"/*.txt
	cp "$out"/digests/*.txt "$ref"/
	cp "$out/results.tsv" "$ref/results.tsv"
	echo "captured $(ls "$ref"/*.txt | wc -l) digests to $ref"
	rm -rf "$out"
	exit 0
fi
luajit "$here/compare.lua" "$ref" "$out/digests" "$here/seeds.txt"
status=$?
if [[ $status -ne 0 || "${KEEP:-0}" == 1 ]]; then
	echo "run directory kept: $out"
else
	rm -rf "$out"
fi
exit $status
