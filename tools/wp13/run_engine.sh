#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_engine.sh ABSENT_OUTPUT ENGINE_OR_LAUNCHER [ARGS]}"
shift
[[ "$output" = /* && ! -e "$output" && "$#" -gt 0 ]] || exit 2
mkdir -p "$output"
cp "$repo/tools/wp13/engine_cases.lua" "$output/forward.lua"
sed 's/local reverse = false/local reverse = true/' \
	"$repo/tools/wp13/engine_cases.lua" >"$output/reverse.lua"
sha256sum "$repo/tools/wp13/engine_cases.lua" "$repo/tools/wp13/run_engine.sh" \
	>"$output/harness.sha256"
# Two independent fresh worlds, each followed by its own disk-only reload.
# The existing profiler snapshots game inputs before starting its engine.
run_order() {
	local order="$1" port="$2"
	WP40_PROFILE_SEED="${WP13_SEED:-531802985935182545}" \
	WP40_PROFILE_CASES="$output/$order.lua" \
	WP40_PROFILE_OUTPUT="$output/$order" WP40_PROFILE_PORT_BASE="$port" \
	WP40_PROFILE_FULL_DIGEST=0 \
		bash "$repo/tools/wp40/profile/run.sh" "${engine[@]}" \
		>"$output/$order-run.log" 2>&1
}
engine=("$@")
port_base="${WP13_PORT_BASE:-32460}"
[[ "$port_base" =~ ^[1-9][0-9]{3,4}$ && "$port_base" -le 65000 ]] || exit 2
run_order forward "$port_base" & forward_pid=$!
run_order reverse "$((port_base + 10))" & reverse_pid=$!
forward_status=0; wait "$forward_pid" || forward_status=$?
reverse_status=0; wait "$reverse_pid" || reverse_status=$?
[[ "$forward_status" -eq 0 && "$reverse_status" -eq 0 ]] || {
	echo "WP13 engine failed; inspect $output/*-run.log" >&2
	exit 1
}
for order in forward reverse; do
	for phase in cold disk; do
		rg 'GRUG_WP13_ENGINE phase=' "$output/$order/$phase/server.log" \
			>"$output/$order-$phase.tsv"
		[[ "$(wc -l <"$output/$order-$phase.tsv")" -eq 1 ]]
	done
done
awk '{for(i=1;i<=NF;i++) if($i ~ /^digest=/) print $i}' \
	"$output/forward-cold.tsv" "$output/forward-disk.tsv" \
	"$output/reverse-cold.tsv" "$output/reverse-disk.tsv" \
	>"$output/digests.txt"
[[ "$(wc -l <"$output/digests.txt")" -eq 4 &&
	"$(sort -u "$output/digests.txt" | wc -l)" -eq 1 ]]
printf 'WP13 engine PASS: forward/reverse, cold/disk: %s\n' "$output"
