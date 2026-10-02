#!/usr/bin/env bash
# Round 28 Lane W1: the world view of spawn levels for several seeds, in one
# or two variants, side by side when two.
#
#   tools/r28_world/run.sh [--seeds "SEED ..."] [--out ROOT] [--variants "A [B]"] [--before REF]
#
# Defaults: seeds 42 7 2026, ROOT docs/planning/round28/world, variants
# "current proposed". A variant is
#   current, final  the recipes of this tree (two names for the same thing:
#                   `final` once the border rule is applied);
#   proposed        the border rule's recipe copies (border_rule.py --out into
#                   WORK/proposal; shipped data untouched);
#   before          the tree of git REF (--before): its mods and tools,
#                   extracted with `git archive` into WORK; this world.lua
#                   runs on it, so the image shows that commit's recipes,
#                   bands and region builder.
# Writes ROOT/<variant>_seed_<s>.png|md per variant and seed, ROOT/
# compare_seed_<s>.png (the two variants side by side) when two are given,
# and ROOT/border_rule.md (every zone's from / to: today and by the rule).
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
before=""
while [ $# -gt 0 ]; do
	case "$1" in
		--seeds) read -r -a seeds <<< "$2"; shift 2 ;;
		--out) root="$2"; shift 2 ;;
		--variants) read -r -a variants <<< "$2"; shift 2 ;;
		--before) before="$2"; shift 2 ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done
jobs_max="${JOBS:-7}"
work="${WORK:-$(mktemp -d /tmp/r28_world.XXXXXX)}"
mkdir -p "$root" "$work/proposal"
idle=()
command -v chrt >/dev/null && idle=(chrt --idle 0)

python3 "$here/border_rule.py" --report "$root/border_rule.md" --out "$work/proposal"

# Per variant: the tree world.lua runs in, its optional zones directory and
# the label in the titles.
tree_of() {
	case "$1" in
		before) echo "$work/before_tree" ;;
		*) echo "$repo" ;;
	esac
}
label_of() {
	case "$1" in
		current) echo "shipped recipes" ;;
		final) echo "final recipes (border rule applied)" ;;
		proposed) echo "border-rule proposal" ;;
		before) echo "recipes of $before" ;;
		*) echo "unknown variant $1" >&2; exit 2 ;;
	esac
}
for variant in "${variants[@]}"; do
	label_of "$variant" >/dev/null
	if [ "$variant" = before ]; then
		[ -n "$before" ] || { echo "variant before needs --before REF" >&2; exit 2; }
		rm -rf "$work/before_tree"
		mkdir -p "$work/before_tree"
		git -C "$repo" archive "$before" mods tools | tar -x -C "$work/before_tree"
	fi
done

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
	tree="$(tree_of "$variant")"
	for seed in "${seeds[@]}"; do
		throttle
		"${idle[@]}" luajit "$here/world.lua" "$tree" "$seed" "$work/$variant" \
			"${extra[@]}" 2> "$work/$variant/$seed.log" &
		pids+=($!)
	done
done
reap
for variant in "${variants[@]}"; do
	label="$(label_of "$variant")"
	for seed in "${seeds[@]}"; do
		cat "$work/$variant/$seed.log" >&2
		[ -f "$work/$variant/world_$seed.json" ] || continue
		throttle
		python3 "$here/render.py" --dump "$work/$variant" --seed "$seed" --out "$root" \
			--name "$variant" --label "$label" &
		pids+=($!)
	done
done
reap
# The two variants side by side.
if [ ${#variants[@]} -eq 2 ]; then
	a="${variants[0]}"
	b="${variants[1]}"
	for seed in "${seeds[@]}"; do
		[ -f "$root/${a}_seed_$seed.png" ] && [ -f "$root/${b}_seed_$seed.png" ] || continue
		throttle
		python3 "$here/pair.py" --out "$root" --seed "$seed" \
			--left "$a" "$work/$a" "$(label_of "$a")" --right "$b" "$work/$b" "$(label_of "$b")" &
		pids+=($!)
	done
	reap
fi
echo "images and stats written under $root (dumps in $work)"
exit "$status"
