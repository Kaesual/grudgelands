#!/usr/bin/env bash
# Re-freeze the built-geometry digests `run_capital.sh` gates on, from the engine
# passes of this lane and from nothing else.
#
#   refreeze.sh <repo> <engine root>
#
# The engine root holds one directory per pass, named `<key>-<mode>-<seed>`, each
# with the runner's own `overlay-digests.txt`. A digest is written back into
# `tools/wp13/evidence/20260915-capital-terrain/<key>/<label>-digest-<seed>.txt`
# ONLY where that file already exists: this lane re-freezes what it moved and
# does not create a gate for a capital or a seed that never had one.
set -euo pipefail
export LC_ALL=C
repo="${1:?usage: refreeze.sh REPO ENGINE_ROOT}"
root="${2:?usage: refreeze.sh REPO ENGINE_ROOT}"
main_commit="${3:-70dda602}"
package="20260916-streets"
frozen="$repo/tools/wp13/evidence/20260915-capital-terrain"

moved=0
kept=0
for pass in "$root"/*-full-*; do
	[[ -d "$pass" ]] || continue
	[[ -f "$pass/overlay-digests.txt" ]] || continue
	name="$(basename "$pass")"
	key="${name%%-full-*}"
	seed="${name##*-full-}"
	while read -r digest label _ cells; do
		[[ -n "${digest:-}" ]] || continue
		label="${label#*=}"
		target="$frozen/$key/$label-digest-$seed.txt"
		[[ -f "$target" ]] || continue
		cells="${cells#overlay_cells=}"
		old="$(awk 'NR==1 {print $1}' "$target")"
		# THE FILE IS REWRITTEN EITHER WAY, because its provenance line is part
		# of the evidence: it says which tree the value was taken on, and every
		# one of these was taken on THIS one. What is reported is whether the
		# DIGEST moved.
		printf '%s  %s seed=%s overlay_cells=%s main=%s package=%s\n' \
			"$digest" "$label" "$seed" "$cells" "$main_commit" "$package" \
			>"$target"
		if [[ "$old" == "$digest" ]]; then
			printf 'confirmed %-12s %-8s %-22s %s\n' "$key" "$label" "$seed" \
				"$digest"
			kept=$((kept + 1))
		else
			printf 're-froze  %-12s %-8s %-22s %s (was %s)\n' "$key" "$label" \
				"$seed" "$digest" "${old:0:16}"
			moved=$((moved + 1))
		fi
	done < <(sed 's/  */ /g' "$pass/overlay-digests.txt" |
		awk '{print $1, $2, $3, $4}')
done
printf '%d digests moved, %d confirmed unchanged\n' "$moved" "$kept"
