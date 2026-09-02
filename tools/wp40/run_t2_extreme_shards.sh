#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
	echo "usage: tools/wp40/run_t2_extreme_shards.sh" >&2
	exit 2
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme-orchestrator.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-extreme-orchestrator.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT
authority_commit="$(git -C "$repo" rev-parse --verify HEAD)"
authority_tree="$(git -C "$repo" rev-parse --verify "${authority_commit}^{tree}")"
launcher_authority=(
	"tools/wp40/run_t2_extreme_shards.sh"
	"tools/wp40/run_t2_extreme_shard.sh"
	"tools/wp40/t2_extreme_authority.lua"
	"tools/wp40/t2_extreme_gate_check.lua"
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua"
)
for path in "${launcher_authority[@]}"; do
	git -C "$repo" ls-files --error-unmatch "$path" >/dev/null 2>&1 || {
		echo "WP40 T2 extreme launcher authority is untracked: $path" >&2
		exit 2
	}
done
if ! git -C "$repo" diff --quiet "$authority_commit" -- \
	"${launcher_authority[@]}"; then
	echo "WP40 T2 extreme launcher authority differs from commit $authority_commit" >&2
	exit 2
fi
echo "WP40 T2 extreme launcher authority: commit=$authority_commit tree=$authority_tree"
"$repo/tools/bin/lua51" "$script_dir/t2_extreme_gate_check.lua" "$repo" "$scratch"

"$repo/tools/bin/luac51" -p \
	"$script_dir/t2_extreme_authority.lua" \
	"$script_dir/t2_extreme_gate_check.lua" \
	"$script_dir/fixtures/t2_extreme_e0/full_scan_gate.lua" \
	"$script_dir/fixtures/t2_extreme_e0/vocabulary.lua" \
	"$script_dir/t2_extreme_shard_worker.lua" \
	"$script_dir/t2_extreme_verify_shard.lua"
bash -n "$script_dir/run_t2_extreme_shard.sh" \
	"$script_dir/run_t2_extreme_shards.sh"

# The retained shard name is defined once, in t2_extreme_authority.lua. Ask it
# rather than restating the rule here: a local copy of that naming rule is
# exactly what went stale when the v3 pool moved to its own names, aborting a
# fresh launch before any seed was measured. The authority file has already
# been checked against its commit above. The hasher is a trap on purpose --
# retained_shard_path only formats a string -- and the range is validated
# there, so a non-canonical range fails here rather than reaching a worker.
retained_shard_path() {
	WP40_SHARD_REPO="$repo" WP40_SHARD_FIRST="$1" WP40_SHARD_LAST="$2" \
	"$repo/tools/bin/lua51" -e '
local repo = assert(os.getenv("WP40_SHARD_REPO"))
local first = assert(tonumber(os.getenv("WP40_SHARD_FIRST")))
local last = assert(tonumber(os.getenv("WP40_SHARD_LAST")))
local path = "tools/wp40/t2_extreme_authority.lua"
local file = assert(io.open(repo .. "/" .. path, "rb"))
local bytes = assert(file:read("*a"))
assert(file:close())
local authority = assert(loadstring(bytes, "@" .. path))()({
	raw_sha256 = function() error("the path helper must not hash", 0) end})
io.write(authority.retained_shard_path(first, last))
'
}

declare -a starts=() lasts=() outputs=() logs=() pids=()
resumed=0
for shard_index in {0..7}; do
	first=$((shard_index * 512))
	last=$((first + 511))
	output="$repo/$(retained_shard_path "$first" "$last")"
	starts[$shard_index]="$first"
	lasts[$shard_index]="$last"
	outputs[$shard_index]="$output"
	logs[$shard_index]="$scratch/shard-$shard_index.log"
	if [[ -e "$output" ]]; then
		verify_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme.XXXXXXXX)"
		"$repo/tools/bin/lua51" "$script_dir/t2_extreme_verify_shard.lua" \
			"$repo" "$verify_scratch" "$first" "$last" "$output"
		rm -rf -- "$verify_scratch"
		resumed=$((resumed + 512))
		pids[$shard_index]=0
		echo "WP40 T2 E0 shard resumed range=$(printf '%04d..%04d' "$first" "$last") global_completed=$resumed/4096"
	else
		"$script_dir/run_t2_extreme_shard.sh" "$first" "$last" "$output" \
			>"${logs[$shard_index]}" 2>&1 &
		pids[$shard_index]=$!
	fi
done

last_global=-1
start_seconds=$SECONDS
while :; do
	active=0
	global=$resumed
	active_text=""
	for shard_index in {0..7}; do
		pid="${pids[$shard_index]}"
		if (( pid == 0 )); then continue; fi
		completed=0
		current="----"
		line="$(grep '^WP40 T2 E0 shard progress ' "${logs[$shard_index]}" 2>/dev/null | tail -n 1 || true)"
		if [[ "$line" =~ current=([0-9]{4}) ]]; then current="${BASH_REMATCH[1]}"; fi
		if [[ "$line" =~ completed512=([0-9]+)/512 ]]; then completed="${BASH_REMATCH[1]}"; fi
		global=$((global + completed))
		if kill -0 "$pid" 2>/dev/null; then
			active=$((active + 1))
			active_text+=" $(printf '%04d..%04d:%s' "${starts[$shard_index]}" "${lasts[$shard_index]}" "$current")"
		fi
	done
	if (( global != last_global )); then
		elapsed=$((SECONDS - start_seconds))
		eta=0
		if (( global > 0 && global < 4096 )); then eta=$((elapsed * (4096 - global) / global)); fi
		echo "WP40 T2 E0 corpus progress global_completed=$global/4096 active=$active wall_seconds=$elapsed eta_seconds=$eta current=$active_text"
		last_global=$global
	fi
	if (( active == 0 )); then break; fi
	sleep 2
done

failed=0
for shard_index in {0..7}; do
	pid="${pids[$shard_index]}"
	if (( pid == 0 )); then continue; fi
	if wait "$pid"; then
		cat "${logs[$shard_index]}"
		echo "WP40 T2 E0 shard done range=$(printf '%04d..%04d' "${starts[$shard_index]}" "${lasts[$shard_index]}")"
	else
		status=$?
		cat "${logs[$shard_index]}" >&2
		echo "WP40 T2 E0 shard failed range=$(printf '%04d..%04d' "${starts[$shard_index]}" "${lasts[$shard_index]}") status=$status" >&2
		failed=1
	fi
done
if (( failed != 0 )); then exit 1; fi

for shard_index in {0..7}; do
	verify_scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme.XXXXXXXX)"
	"$repo/tools/bin/lua51" "$script_dir/t2_extreme_verify_shard.lua" \
		"$repo" "$verify_scratch" "${starts[$shard_index]}" \
		"${lasts[$shard_index]}" "${outputs[$shard_index]}"
	rm -rf -- "$verify_scratch"
done
echo "WP40 T2 E0 corpus progress global_completed=4096/4096 shards_done=8 stage2=pending_selected_four"
