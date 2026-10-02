#!/usr/bin/env bash
# Round 28 Lane W1: the world view of spawn levels, current recipes against
# the border-rule proposal, for several seeds.
#
#   tools/r28_world/run.sh [--seeds "SEED ..."] [--out ROOT] [--only current|proposed]
#
# Defaults: seeds 42 7 2026, ROOT docs/planning/round28/world. Writes
#   ROOT/border_rule.md                 every zone's from / to: today and by the rule
#   ROOT/current_seed_<s>.png|md        the shipped recipes
#   ROOT/proposed_seed_<s>.png|md       the rule's recipe copies (border_rule.py --out
#                                       into WORK/proposal; shipped data untouched)
# One LuaJIT process per seed and variant builds the analytic world once and
# every mainland zone's region map on it (world.lua, the game's own
# spawn_regions_core.lua), at most JOBS (7) at once under idle scheduling;
# then render.py per image. Dumps go to WORK (default a fresh mktemp dir).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
seeds=(42 7 2026)
root="$repo/docs/planning/round28/world"
variants=(current proposed)
while [ $# -gt 0 ]; do
	case "$1" in
		--seeds) read -r -a seeds <<< "$2"; shift 2 ;;
		--out) root="$2"; shift 2 ;;
		--only) variants=("$2"); shift 2 ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done
jobs_max="${JOBS:-7}"
work="${WORK:-$(mktemp -d /tmp/r28_world.XXXXXX)}"
mkdir -p "$root" "$work/proposal"
idle=()
command -v chrt >/dev/null && idle=(chrt --idle 0)

python3 "$here/border_rule.py" --report "$root/border_rule.md" --out "$work/proposal"

throttle() {
	while [ "$(jobs -rp | wc -l)" -ge "$jobs_max" ]; do
		sleep 0.2
	done
}
status=0
pids=()
reap() {
	local pid
	for pid in "${pids[@]}"; do
		wait "$pid" || status=1
	done
	pids=()
}

for variant in "${variants[@]}"; do
	mkdir -p "$work/$variant"
	extra=()
	[ "$variant" = proposed ] && extra=("$work/proposal")
	for seed in "${seeds[@]}"; do
		throttle
		"${idle[@]}" luajit "$here/world.lua" "$repo" "$seed" "$work/$variant" "${extra[@]}" \
			2> "$work/$variant/$seed.log" &
		pids+=($!)
	done
done
reap
for variant in "${variants[@]}"; do
	for seed in "${seeds[@]}"; do
		cat "$work/$variant/$seed.log" >&2
		[ -f "$work/$variant/world_$seed.json" ] || continue
		throttle
		python3 "$here/render.py" --dump "$work/$variant" --seed "$seed" --out "$root" \
			--name "$variant" &
		pids+=($!)
	done
done
reap
echo "images and stats written under $root (dumps in $work)"
exit "$status"
