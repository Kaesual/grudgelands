#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
label="${1:?usage: run_rate.sh LABEL PORT_BASE}"
port_base="${2:?usage: run_rate.sh LABEL PORT_BASE}"
seed=15912857179583385436
evidence="$repo/tools/spawn_probe/evidence/$label"
probe="$repo/tools/spawn_probe/grug_spawn_probe"

[[ "$port_base" =~ ^311[0-9][0-9]$ && "$port_base" -le 31197 ]] || {
	echo "PORT_BASE must leave three ports inside 31100-31199" >&2
	exit 2
}
[[ ! -e "$evidence" ]] || {
	echo "evidence path already exists: $evidence" >&2
	exit 2
}
mkdir -p "$evidence"

root=""
for minute in 1 2 3; do
	log="$evidence/minute-$minute.launch.log"
	if [[ -z "$root" ]]; then
		KEEP=1 PORT="$((port_base + minute - 1))" SEED="$seed" PROBE="$probe" \
			nice -n 19 "$repo/tools/luanti_headless.sh" 120 >"$log" 2>&1
		root="$(sed -n 's/^kept: //p' "$log" | tail -1)"
		[[ -n "$root" ]]
	else
		ROOT="$root" PORT="$((port_base + minute - 1))" SEED="$seed" PROBE="$probe" \
			nice -n 19 "$repo/tools/luanti_headless.sh" 120 >"$log" 2>&1
	fi
	server_log="$(sed -n 's/^log: //p' "$log" | tail -1)"
	cp "$server_log" "$evidence/minute-$minute.server.log"
	done_line="$(rg 'GRUG_R5_SPAWN .*event=window_end' "$server_log" | head -1)"
	[[ -n "$done_line" ]]
	printf '%s\n' "$done_line" >>"$evidence/windows.log"
done

awk '
	match($0, /spawns=[0-9]+/) {
		value = substr($0, RSTART + 7, RLENGTH - 7)
		total += value
		printf "minute_%d=%d\n", ++minute, value
	}
	END {
		if (minute != 3) exit 1
		printf "total=%d\nrate_per_minute=%.3f\n", total, total / 3
	}
' "$evidence/windows.log" | tee "$evidence/summary.txt"

printf 'root=%s\n' "$root" >"$evidence/scratch-root.txt"
printf 'spawn-rate evidence: %s\n' "$evidence"
