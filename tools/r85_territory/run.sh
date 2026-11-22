#!/usr/bin/env bash
# Round 85 lane TERRITORY: tools/r85_territory/seeds.lua over the eleven
# study seeds, JOBS (default 6) at once under idle scheduling, each with its
# own output; a summary line per seed. With BASE=<repo tree> it also writes
# each seed's placement text from that tree and from this one and names the
# seeds whose placement differs (the rare patrol rule's effect).
#
#   tools/r85_territory/run.sh OUT_DIR
#   BASE=/path/to/base/tree tools/r85_territory/run.sh OUT_DIR
#
# Through the shared queue: lua_run.sh r85-territory 6 tools/r85_territory/run.sh OUT
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
jobs="${JOBS:-6}"
seeds=(3684797457838814663 12345 17713522922938657774 5575844014311305038
	6410640627505506314 9512886083845910081 4282870288782723 2996858566870034
	6866842473207 75731352233772710 52857145422941)
mkdir -p "$out/full"
status=0
printf '%s\n' "${seeds[@]}" | xargs -P "$jobs" -I{} sh -c \
	'luajit "$1/tools/r85_territory/seeds.lua" "$1" "$2" "$3/full" >"$3/full/$2.log" 2>&1' \
	_ "$repo" {} "$out" || status=1
for seed in "${seeds[@]}"; do tail -n 1 "$out/full/$seed.log"; done
if [[ -n "${BASE:-}" ]]; then
	mkdir -p "$out/base" "$out/branch"
	printf '%s\n' "${seeds[@]}" | xargs -P "$jobs" -I{} sh -c \
		'luajit "$1/tools/r85_territory/seeds.lua" "$2" "$3" "$4" place >/dev/null' \
		_ "$repo" "$BASE" {} "$out/base" || status=1
	printf '%s\n' "${seeds[@]}" | xargs -P "$jobs" -I{} sh -c \
		'luajit "$1/tools/r85_territory/seeds.lua" "$1" "$2" "$3" place >/dev/null' \
		_ "$repo" {} "$out/branch" || status=1
	for seed in "${seeds[@]}"; do
		if cmp -s "$out/base/$seed.placement" "$out/branch/$seed.placement"; then
			echo "PLACEMENT $seed same"
		else
			echo "PLACEMENT $seed differs: $(diff "$out/base/$seed.placement" \
				"$out/branch/$seed.placement" | grep '^[<>]' | tr '\n' ' ')"
		fi
	done
fi
exit $status
