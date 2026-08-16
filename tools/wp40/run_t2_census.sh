#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 census runner (plan section 6.6).
#
#   tools/wp40/run_t2_census.sh --kat                  # seeds 0 + max-u64
#   WP40_CENSUS_OUTPUT=path run_t2_census.sh --seeds 0 7 4096
#   tools/wp40/run_t2_census.sh --plan                 # derive W, print the token
#   WP40_CENSUS_GO=<token> run_t2_census.sh --full-w   # the eight-shard run
#
# The free paths run anywhere; --full-w is the GO-gated one and starts nothing
# until the token matches the `W` this tree derives (section 6.6.7).  It fans
# out at full width immediately -- there is no serial pre-validation pass
# (section 5) -- and then holds four gates over the running fleet: the first
# completed record of every worker is validated against the artifact contract,
# the projection from the first completions is checked against the eight-hour
# wall cap, a shard already on disk is verified before it is resumed, and
# anything unparseable at a census path aborts the launcher loudly rather than
# counting as an empty shard.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

# A missing rg would make the SETGLOBAL gate below pass vacuously: exit
# status 127 in an `if` condition reads exactly like "no match found".
command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

owned_lua=(
	"$repo/tools/wp40/t2_census_authority.lua"
	"$repo/tools/wp40/t2_census_gate.lua"
	"$repo/tools/wp40/t2_census_gate_test.lua"
	"$repo/tools/wp40/t2_census_hasher.lua"
	"$repo/tools/wp40/t2_census_worker.lua"
	"$repo/tools/wp40/fixtures/t2_census/scan1_kat_v1.lua"
)
"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 census global write in $file" >&2
		exit 1
	fi
done
bash -n "$script_dir/run_t2_census.sh"

lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
lua_path="$(command -v "$lua_bin" 2>/dev/null || true)"
if [[ -z "$lua_path" || ! -x "$lua_path" ]]; then
	echo "WP40 T2 census interpreter is not executable: $lua_bin" >&2
	exit 2
fi
lua_real="$(readlink -f "$lua_path")"
lua_version="$("$lua_path" -v 2>&1 | head -n 1)"
echo "WP40 T2 census interpreter: $lua_path -> $lua_real"

declare -a scratch_dirs=()
declare -a worker_pids=()
cleanup() {
	local pid
	for pid in "${worker_pids[@]:-}"; do
		if [[ -n "$pid" && "$pid" != 0 ]]; then kill "$pid" 2>/dev/null || true; fi
	done
	local dir
	for dir in "${scratch_dirs[@]:-}"; do
		if [[ "$dir" == /tmp/grudgelands-wp40-t2-census.* ]]; then rm -rf -- "$dir"; fi
	done
}
trap cleanup EXIT

new_scratch() {
	local dir
	dir="$(mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX)"
	scratch_dirs+=("$dir")
	printf '%s' "$dir"
}

scratch="$(new_scratch)"

# Every path whose bytes can move a census row, plus the launcher's own.  The
# list is the authority's, asked for rather than restated: a stale second copy
# of such a list is what aborted a fresh pool launch before any seed ran.
require_committed_authority() {
	local commit="$1"
	local -a paths=()
	mapfile -t paths < <("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" \
		"$scratch" paths)
	if (( ${#paths[@]} < 10 )); then
		echo "WP40 T2 census authority path list is implausibly short" >&2
		exit 2
	fi
	local path
	for path in "${paths[@]}"; do
		git -C "$repo" ls-files --error-unmatch "$path" >/dev/null 2>&1 || {
			echo "WP40 T2 census authority is untracked: $path" >&2
			exit 2
		}
	done
	if ! git -C "$repo" diff --quiet "$commit" -- "${paths[@]}"; then
		echo "WP40 T2 census authority differs from commit $commit;" \
			"a full-W run must be reproducible from a commit" >&2
		git -C "$repo" diff --stat "$commit" -- "${paths[@]}" >&2
		exit 2
	fi
}

run_full_w() {
	local plan_only="$1"
	local commit tree
	commit="$(git -C "$repo" rev-parse --verify HEAD)"
	tree="$(git -C "$repo" rev-parse --verify "${commit}^{tree}")"
	local w_path="$scratch/w.txt"
	local plan_output
	plan_output="$("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" \
		plan "$w_path")"
	echo "$plan_output"
	local w_digest w_total
	w_digest="$(sed -n 's/^WP40 T2 census W .*digest=\([0-9a-f]\{64\}\).*/\1/p' \
		<<<"$plan_output")"
	w_total="$(sed -n 's/^WP40 T2 census W total=\([0-9]\+\) .*/\1/p' <<<"$plan_output")"
	if [[ ! "$w_digest" =~ ^[0-9a-f]{64}$ || ! "$w_total" =~ ^[0-9]+$ ]]; then
		echo "WP40 T2 census could not derive W" >&2
		exit 2
	fi

	local -a firsts=() lasts=() sizes=() outputs=() logs=()
	local line
	while IFS= read -r line; do
		[[ "$line" =~ range=([0-9]+)\.\.([0-9]+)\ seeds=([0-9]+)\ path=(.+)$ ]] || {
			echo "WP40 T2 census shard plan line is malformed: $line" >&2
			exit 2
		}
		firsts+=("${BASH_REMATCH[1]}")
		lasts+=("${BASH_REMATCH[2]}")
		sizes+=("${BASH_REMATCH[3]}")
		outputs+=("$repo/${BASH_REMATCH[4]}")
	done < <(grep '^WP40 T2 census shard [0-9]' <<<"$plan_output")
	if (( ${#firsts[@]} != 8 )); then
		echo "WP40 T2 census expects eight shards, planned ${#firsts[@]}" >&2
		exit 2
	fi

	if [[ "$plan_only" == "plan" ]]; then
		local index status
		for index in "${!firsts[@]}"; do
			status=absent
			if [[ -e "${outputs[$index]}" ]]; then status=present; fi
			printf 'WP40 T2 census shard %d state=%s path=%s\n' \
				"$((index + 1))" "$status" "${outputs[$index]}"
		done
		echo "WP40 T2 census GO token: $w_digest"
		echo "WP40 T2 census start with: WP40_CENSUS_GO=$w_digest" \
			"tools/wp40/run_t2_census.sh --full-w"
		return 0
	fi

	# Section 6.6.7.  Nothing below this line runs without the operator's
	# explicit GO, and the token is this W's digest rather than a word, so it
	# also names which seed set was approved.  Every worker re-derives W and
	# re-checks the token independently.
	local token="${WP40_CENSUS_GO:-}"
	if [[ "$token" != "$w_digest" ]]; then
		echo "WP40 T2 census full-W needs the explicit GO token (plan section 6.6.7)." >&2
		if [[ -n "$token" ]]; then
			echo "  the supplied token does not match this W" >&2
		fi
		echo "  W: total=$w_total digest=$w_digest" >&2
		echo "  start with: WP40_CENSUS_GO=$w_digest tools/wp40/run_t2_census.sh --full-w" >&2
		exit 2
	fi
	require_committed_authority "$commit"
	echo "WP40 T2 census authority: commit=$commit tree=$tree"

	local cap="${WP40_CENSUS_WALL_CAP_SECONDS:-28800}"
	local deadline="${WP40_CENSUS_FIRST_RECORD_DEADLINE:-900}"
	[[ "$cap" =~ ^[0-9]+$ && "$cap" -gt 0 ]] || {
		echo "WP40_CENSUS_WALL_CAP_SECONDS must be a positive integer" >&2
		exit 2
	}
	[[ "$deadline" =~ ^[0-9]+$ && "$deadline" -gt 0 ]] || {
		echo "WP40_CENSUS_FIRST_RECORD_DEADLINE must be a positive integer" >&2
		exit 2
	}
	mkdir -p "$repo/tools/wp40/results/t2_census"

	local -a pids=() first_ready=()
	local resumed_seeds=0 resumed_shards=0 started=0 index
	for index in "${!firsts[@]}"; do
		logs+=("$scratch/shard-$index.log")
		first_ready+=(0)
		if [[ -e "${outputs[$index]}" ]]; then
			# Section 6.6.4: a shard on disk is verified, not assumed -- including
			# the empty claim file a crashed worker leaves, which the verifier
			# refuses as unparseable instead of reading as an empty shard.
			"$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" verify \
				"$w_path" "$w_digest" "$commit" "${firsts[$index]}" "${lasts[$index]}" \
				"${outputs[$index]}"
			resumed_seeds=$((resumed_seeds + sizes[index]))
			resumed_shards=$((resumed_shards + 1))
			pids+=(0)
		else
			local worker_scratch
			worker_scratch="$(new_scratch)"
			"$lua_path" "$script_dir/t2_census_worker.lua" "$repo" "$worker_scratch" \
				"${outputs[$index]}" --range "${firsts[$index]}" "${lasts[$index]}" \
				--go-token "$token" --commit "$commit" --tree "$tree" \
				--interpreter-id luajit --interpreter-path "$lua_real" \
				--interpreter-version "$lua_version" \
				>"${logs[$index]}" 2>&1 &
			pids+=($!)
			worker_pids+=($!)
			started=$((started + 1))
		fi
	done
	echo "WP40 T2 census fan-out workers_started=$started resumed_shards=$resumed_shards" \
		"seeds=$w_total"
	# The branch already shipped a verification run that reported success with
	# zero workers started; a run that neither starts nor resumes every shard is
	# a failure, not a fast success.
	if (( started + resumed_shards != 8 )); then
		echo "WP40 T2 census planned 8 shards but started $started and resumed" \
			"$resumed_shards" >&2
		exit 1
	fi
	if (( started == 0 )); then
		echo "WP40 T2 census corpus progress global_completed=$w_total/$w_total" \
			"shards_done=8 source=resume"
		return 0
	fi

	local start_seconds=$SECONDS last_global=-1 cost_checked=0
	local failure=""
	while :; do
		local active=0 running=0 ready=0 global=$resumed_seeds
		local -a samples=()
		local elapsed=$((SECONDS - start_seconds))
		for index in "${!firsts[@]}"; do
			local pid="${pids[$index]}"
			if (( pid == 0 )); then continue; fi
			running=$((running + 1))
			if kill -0 "$pid" 2>/dev/null; then active=$((active + 1)); fi
			local completed=0 progress
			progress="$(grep '^WP40 T2 census shard progress ' "${logs[$index]}" \
				2>/dev/null | tail -n 1 || true)"
			if [[ "$progress" =~ completed=([0-9]+)/ ]]; then
				completed="${BASH_REMATCH[1]}"
			fi
			global=$((global + completed))
			if (( completed > 0 )); then
				samples+=("${sizes[$index]}:$completed:$elapsed")
				# Section 6.6.2: validated once, on the first record that closed,
				# while this worker and the other seven keep running.
				if (( first_ready[index] == 0 )); then
					local record_output record_status=0
					record_output="$("$lua_path" "$script_dir/t2_census_gate.lua" \
						"$repo" "$scratch" first_record "$w_path" "$w_digest" \
						"$commit" "${firsts[$index]}" "${lasts[$index]}" \
						"${outputs[$index]}" 2>&1)" || record_status=$?
					if (( record_status != 0 )); then
						echo "$record_output" >&2
						if (( record_status == 3 )); then
							failure="first record of shard $((index + 1)) violates the artifact contract"
						else
							failure="the first-record check of shard $((index + 1)) failed to run (status $record_status)"
						fi
						break
					fi
					echo "$record_output"
					if [[ "$record_output" == *ready=1* ]]; then first_ready[index]=1; fi
				fi
			fi
			if (( first_ready[index] == 1 )); then ready=$((ready + 1)); fi
		done
		if [[ -n "$failure" ]]; then break; fi

		if (( ready < running && elapsed > deadline )); then
			failure="only $ready of $running workers produced a validated first record within ${deadline}s"
			break
		fi
		# Section 6.6.3: projected once every worker has a completion to project
		# from, so the abort lands in the run's first minutes.
		if (( cost_checked == 0 && ${#samples[@]} == running && ready == running )); then
			local cost_output cost_status=0
			cost_output="$("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" \
				"$scratch" cost "$cap" "${samples[@]}" 2>&1)" || cost_status=$?
			if (( cost_status != 0 )); then
				echo "$cost_output" >&2
				if (( cost_status == 3 )); then
					failure="the projected wall time exceeds the ${cap}s cap"
				else
					failure="the cost gate failed to run (status $cost_status)"
				fi
				break
			fi
			echo "$cost_output"
			cost_checked=1
		fi

		if (( global != last_global )); then
			local eta=0
			if (( global > resumed_seeds && global < w_total )); then
				eta=$(((SECONDS - start_seconds) * (w_total - global) / (global - resumed_seeds)))
			fi
			echo "WP40 T2 census corpus progress global_completed=$global/$w_total" \
				"active=$active wall_seconds=$elapsed eta_seconds=$eta"
			last_global=$global
		fi
		if (( active == 0 )); then break; fi
		sleep 2
	done

	if [[ -n "$failure" ]]; then
		for index in "${!firsts[@]}"; do
			local pid="${pids[$index]}"
			if (( pid != 0 )); then kill "$pid" 2>/dev/null || true; fi
		done
		wait 2>/dev/null || true
		echo "WP40 T2 census aborted: $failure" >&2
		exit 1
	fi

	local failed=0
	for index in "${!firsts[@]}"; do
		local pid="${pids[$index]}"
		if (( pid == 0 )); then continue; fi
		if wait "$pid"; then
			echo "WP40 T2 census shard done range=$(printf '%04d..%04d' \
				"${firsts[$index]}" "${lasts[$index]}")"
		else
			local status=$?
			cat "${logs[$index]}" >&2
			echo "WP40 T2 census shard failed range=$(printf '%04d..%04d' \
				"${firsts[$index]}" "${lasts[$index]}") status=$status" >&2
			failed=1
		fi
	done
	if (( failed != 0 )); then exit 1; fi

	for index in "${!firsts[@]}"; do
		"$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" verify \
			"$w_path" "$w_digest" "$commit" "${firsts[$index]}" "${lasts[$index]}" \
			"${outputs[$index]}"
	done
	echo "WP40 T2 census corpus progress global_completed=$w_total/$w_total" \
		"shards_done=8 merge=pending_m5"
}

case "${1:-}" in
	--kat)
		shift
		if [[ $# -ne 0 ]]; then
			echo "--kat accepts no further arguments" >&2
			exit 2
		fi
		"$lua_path" "$script_dir/t2_census_worker.lua" "$repo" "$scratch" \
			"$scratch/census-kat.tsv" --kat
		;;
	--seeds)
		shift
		if [[ $# -lt 1 ]]; then
			echo "--seeds requires at least one decimal seed" >&2
			exit 2
		fi
		output="${WP40_CENSUS_OUTPUT:?set WP40_CENSUS_OUTPUT to the output TSV path}"
		"$lua_path" "$script_dir/t2_census_worker.lua" "$repo" "$scratch" \
			"$output" "$@"
		;;
	--range)
		shift
		if [[ $# -ne 2 ]]; then
			echo "--range requires FIRST and LAST indices into W" >&2
			exit 2
		fi
		output="${WP40_CENSUS_OUTPUT:?set WP40_CENSUS_OUTPUT to the output TSV path}"
		"$lua_path" "$script_dir/t2_census_worker.lua" "$repo" "$scratch" \
			"$output" --range "$1" "$2" ${WP40_CENSUS_GO:+--go-token "$WP40_CENSUS_GO"}
		;;
	--plan)
		shift
		if [[ $# -ne 0 ]]; then
			echo "--plan accepts no further arguments" >&2
			exit 2
		fi
		run_full_w plan
		;;
	--full-w)
		shift
		if [[ $# -ne 0 ]]; then
			echo "--full-w accepts no further arguments" >&2
			exit 2
		fi
		run_full_w run
		;;
	*)
		echo "usage: tools/wp40/run_t2_census.sh --kat" >&2
		echo "       WP40_CENSUS_OUTPUT=path tools/wp40/run_t2_census.sh --seeds SEED..." >&2
		echo "       WP40_CENSUS_OUTPUT=path tools/wp40/run_t2_census.sh --range FIRST LAST" >&2
		echo "       tools/wp40/run_t2_census.sh --plan" >&2
		echo "       WP40_CENSUS_GO=<token> tools/wp40/run_t2_census.sh --full-w" >&2
		exit 2
		;;
esac
