#!/usr/bin/env bash
# Every portable fixture in one run (Round 31 lane C): each
# tools/*/portable_test.lua and tools/*/fixture.lua under LuaJIT, with the
# repository path as its argument, a few in parallel under idle scheduling.
#   tools/run_fixtures.sh [NAME ...]   (NAME: a tools/ folder, e.g. r30_p1;
#                                       default every fixture)
#   JOBS=<n> parallel processes (default 4; tools/r30_p3 runs two seeds, so
#   it counts twice).
# Special cases: a fixture.lua next to a micro.lua returns a function and runs
# through micro.lua; tools/r30_p3 takes seeds and a scratch world, so it runs
# through its run.sh (seeds 12345 and 42). Prints one line per fixture and a
# summary, shows the end of a failed fixture's output, exits 1 on any failure.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo"
command -v luajit >/dev/null || { echo "luajit not found" >&2; exit 2; }
jobs="${JOBS:-4}"
idle=()
command -v chrt >/dev/null && idle=(chrt --idle 0)

fixtures=()
for path in $(printf '%s\n' tools/*/portable_test.lua tools/*/fixture.lua | sort); do
	name="${path#tools/}"; name="${name%%/*}"
	if [[ $# -gt 0 ]]; then
		wanted=0
		for arg in "$@"; do [[ "$arg" == "$name" ]] && wanted=1; done
		[[ $wanted -eq 1 ]] || continue
	fi
	fixtures+=("$path")
done
[[ ${#fixtures[@]} -gt 0 ]] || { echo "no fixture matches: $*" >&2; exit 2; }

out="$(mktemp -d /tmp/grug_fixtures.XXXXXX)"
trap 'rm -rf "$out"' EXIT

# One fixture: its command, its output in $out, a result line in $out.
run_one() {
	local path="$1" dir log started status
	dir="$(dirname "$path")"
	log="$out/$(echo "$path" | tr '/' '_').log"
	started="${EPOCHREALTIME//[.,]/}"
	if [[ "$path" == tools/r30_p3/portable_test.lua ]]; then
		"${idle[@]}" bash tools/r30_p3/run.sh >"$log" 2>&1
	elif [[ "$path" == */fixture.lua && -f "$dir/micro.lua" ]]; then
		"${idle[@]}" luajit "$dir/micro.lua" "$repo" >"$log" 2>&1
	else
		"${idle[@]}" luajit "$path" "$repo" >"$log" 2>&1
	fi
	status=$?
	local tenths=$(( (${EPOCHREALTIME//[.,]/} - started) / 100000 ))
	printf '%s %s %d.%d\n' "$([[ $status -eq 0 ]] && echo PASS || echo FAIL)" "$path" \
		$((tenths / 10)) $((tenths % 10)) >"$log.result"
}

running=0
for path in "${fixtures[@]}"; do
	run_one "$path" &
	running=$((running + 1))
	if [[ $running -ge $jobs ]]; then wait -n; running=$((running - 1)); fi
done
wait

passed=0; failed=0
for path in "${fixtures[@]}"; do
	log="$out/$(echo "$path" | tr '/' '_').log"
	read -r result _ seconds <"$log.result"
	printf '%-4s %-46s %7s s\n' "$result" "$path" "$seconds"
	if [[ "$result" == PASS ]]; then
		passed=$((passed + 1))
	else
		failed=$((failed + 1))
		tail -n 15 "$log" | sed 's/^/     | /'
	fi
done
echo "fixtures: $passed passed, $failed failed"
[[ $failed -eq 0 ]]
