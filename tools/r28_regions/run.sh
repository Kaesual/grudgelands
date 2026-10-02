#!/usr/bin/env bash
# Round 28 Lanes S1/S2: render zones' spawn regions for several seeds.
#
#   tools/r28_regions/run.sh [ZONE ...] [--seeds "SEED ..."] [--out ROOT]
#
# Defaults: elandor_dawnmere_fields, seeds 42 7 1234 2026 99999 314159, ROOT
# docs/planning/round28/regions. Each zone goes to ROOT/<short>/seed_<seed>.png
# and seed_<seed>.md, <short> being the zone id without its region prefix,
# first word only unless that word has three letters or fewer
# (elandor_dawnmere_fields -> dawnmere, kragmar_gor_drazhak -> gor_drazhak).
# One LuaJIT process per seed builds the analytic world once and renders
# every zone of the list on it (regions.lua: the world, each zone's shipped
# recipe and the game's own spawn_regions_core.lua), at most JOBS (8) at once
# under idle scheduling; then render.py per zone and seed, also up to JOBS at
# once. The dumps go to a scratch directory (WORK, default a fresh mktemp
# dir). Thin lines are drawn only between different kinds (render.py
# --kind-borders); BORDERS=regions draws every region border instead.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
zones=()
seeds=(42 7 1234 2026 99999 314159)
root="$repo/docs/planning/round28/regions"
while [ $# -gt 0 ]; do
	case "$1" in
		--seeds) read -r -a seeds <<< "$2"; shift 2 ;;
		--out) root="$2"; shift 2 ;;
		-*) echo "unknown option $1" >&2; exit 2 ;;
		*) zones+=("$1"); shift ;;
	esac
done
[ ${#zones[@]} -gt 0 ] || zones=(elandor_dawnmere_fields)
for zone in "${zones[@]}"; do
	if [ ! -f "$repo/mods/ENTITIES/grug_mobs/data/zones/$zone.spawns.json" ]; then
		echo "no spawns file for zone $zone" >&2
		exit 2
	fi
done
jobs_max="${JOBS:-8}"
work="${WORK:-$(mktemp -d /tmp/r28_regions.XXXXXX)}"
render_args=(--kind-borders)
[ "${BORDERS:-kinds}" = regions ] && render_args=()
mkdir -p "$work"
idle=()
command -v chrt >/dev/null && idle=(chrt --idle 0)

short_name() {
	local rest="${1#*_}"
	local first="${rest%%_*}"
	if [ ${#first} -le 3 ]; then echo "$rest"; else echo "$first"; fi
}

# Waits until fewer than jobs_max background jobs run (finished jobs keep
# their exit status for the `wait PID` in reap).
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

for seed in "${seeds[@]}"; do
	throttle
	"${idle[@]}" luajit "$here/regions.lua" "$repo" "$seed" "$work" "${zones[@]}" \
		2> "$work/$seed.log" &
	pids+=($!)
done
reap
for seed in "${seeds[@]}"; do
	cat "$work/$seed.log" >&2
done
for zone in "${zones[@]}"; do
	out="$root/$(short_name "$zone")"
	mkdir -p "$out"
	for seed in "${seeds[@]}"; do
		[ -f "$work/${zone}_${seed}.json" ] || continue
		throttle
		python3 "$here/render.py" --dump "$work" --zone "$zone" --seed "$seed" --out "$out" \
			"${render_args[@]}" &
		pids+=($!)
	done
done
reap
echo "images and stats written under $root (dumps in $work)"
# Quest targets against the regions of these seeds (quest_targets.py): a
# target (objective, quest drop, leader, placeholder) that forms no region or
# leader spot on a seed fails the run; stats missing for other zones or seeds
# (a partial run) skip the check.
qt=0
python3 "$here/quest_targets.py" --root "$root" --seeds "${seeds[*]}" > "$work/quest_targets.txt" || qt=$?
case "$qt" in
	0) head -n 2 "$work/quest_targets.txt" ;;
	1) cat "$work/quest_targets.txt"; status=1 ;;
	*) echo "quest target check skipped: not every recipe zone has stats for seeds ${seeds[*]} (see $work/quest_targets.txt)" ;;
esac
exit "$status"
