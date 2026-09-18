#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
label="${1:?usage: run_rate.sh LABEL PORT_BASE}"
port_base="${2:?usage: run_rate.sh LABEL PORT_BASE}"
windows="${WINDOWS:-3}"
seed=15912857179583385436
evidence="$repo/tools/spawn_probe/evidence/$label"
probe="$repo/tools/spawn_probe/grug_spawn_probe"
variant_patch="${VARIANT_PATCH:-$repo/tools/spawn_probe/player_shim.patch}"

[[ "$windows" =~ ^[1-9][0-9]*$ && "$windows" -le 100 ]] || {
	echo "WINDOWS must be an integer from 1 through 100" >&2
	exit 2
}
[[ "$port_base" =~ ^31[0-9][0-9][0-9]$ &&
	$((port_base + windows - 1)) -le 31999 ]] || {
	echo "PORT_BASE must leave $windows ports inside 31000-31999" >&2
	exit 2
}
[[ -f "$variant_patch" ]] || { echo "VARIANT_PATCH is not a file" >&2; exit 2; }
[[ ! -e "$evidence" ]] || {
	echo "evidence path already exists: $evidence" >&2
	exit 2
}
mkdir -p "$evidence"

root=""
for ((minute = 1; minute <= windows; minute++)); do
	log="$evidence/minute-$minute.launch.log"
	if [[ -z "$root" ]]; then
		KEEP=1 PORT="$((port_base + minute - 1))" SEED="$seed" PROBE="$probe" \
			GAME_PATCH="$variant_patch" \
			nice -n 19 "$repo/tools/luanti_headless.sh" 120 >"$log" 2>&1
		root="$(sed -n 's/^kept: //p' "$log" | tail -1)"
		[[ -n "$root" ]]
	else
		ROOT="$root" PORT="$((port_base + minute - 1))" SEED="$seed" PROBE="$probe" \
			GAME_PATCH="$variant_patch" \
			nice -n 19 "$repo/tools/luanti_headless.sh" 120 >"$log" 2>&1
	fi
	server_log="$(sed -n 's/^log: //p' "$log" | tail -1)"
	cp "$server_log" "$evidence/minute-$minute.server.log"
	done_line="$(rg 'GRUG_R5_SPAWN .*event=window_end' "$server_log" | head -1)"
	[[ -n "$done_line" ]]
	printf '%s\n' "$done_line" >>"$evidence/windows.log"
done

awk -v expected="$windows" '
	match($0, /spawns=[0-9]+/) {
		value = substr($0, RSTART + 7, RLENGTH - 7)
		value += 0
		if (minute == 0 || value < min) min = value
		if (minute == 0 || value > max) max = value
		total += value
		total_sq += value * value
		printf "minute_%d=%d\n", ++minute, value
	}
	END {
		if (minute != expected) exit 1
		mean = total / minute
		spread = 0
		if (minute > 1) spread = sqrt((total_sq - total * total / minute) / (minute - 1))
		printf "total=%d\nmean_per_minute=%.3f\n", total, mean
		printf "sample_stddev=%.3f\nmin=%d\nmax=%d\n", spread, min, max
	}
' "$evidence/windows.log" | tee "$evidence/summary.txt"

printf 'root=%s\n' "$root" >"$evidence/scratch-root.txt"
printf 'spawn-rate evidence: %s\n' "$evidence"
