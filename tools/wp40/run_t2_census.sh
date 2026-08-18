#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 census runner (plan section 6.6).
#
#   tools/wp40/run_t2_census.sh --kat                  # the five KAT seeds
#   WP40_CENSUS_OUTPUT=path run_t2_census.sh --seeds 0 7 4096
#   tools/wp40/run_t2_census.sh --merge-kat            # the M5 LuaJIT/PUC gate
#   tools/wp40/run_t2_census.sh --plan                 # derive W, print the token
#   WP40_CENSUS_GO=<token> run_t2_census.sh --full-w   # the eight-shard run
#   tools/wp40/run_t2_census.sh --merge                # publish the artifacts
#
# The free paths run anywhere; --full-w is the GO-gated one and starts nothing
# until the token matches the `W` this tree derives (section 6.6.7).  It fans
# out at full width immediately -- there is no serial pre-validation pass
# (section 5) -- and then holds six gates over the running fleet: the first
# completed record of every worker is validated against the artifact contract,
# a rolling per-shard projection of per-seed CPU is re-checked against the
# measured CPU budget at every completion, the fleet is aborted if it burns CPU
# without completing a seed, a shard already on disk is verified before it is
# resumed, anything unparseable at a census path aborts the launcher loudly
# rather than counting as an empty shard, and a worker that exits before
# completing its range aborts the whole fleet at the next poll (section 6.6.9
# -- run 3 carried three dead shards past an hourly log watch).
#
# Wall time is not one of them, since the section-6.5 re-decision of
# 2026-08-18: the host is a workstation, concurrent user load is normal
# operation, and the rolling wall projection survives as an advisory figure in
# the log and the manifest that the operator reads.  The workers run at idle
# priority for the same reason -- user work preempts the fleet and the run
# stretches instead of the user yielding the machine.

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
	"$repo/tools/wp40/t2_census_merge.lua"
	"$repo/tools/wp40/t2_census_worker.lua"
	"$repo/tools/wp40/fixtures/t2_census/scan_kat_v5.lua"
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

# Both helpers read run_full_w's locals through bash's dynamic scoping; they
# live out here only because a nested definition would leak into the global
# namespace anyway.
assert_full_coverage() {
	if (( $1 != w_total )); then
		echo "WP40 T2 census verified $1 of $w_total seeds across its eight shards" >&2
		exit 1
	fi
	echo "WP40 T2 census coverage verified seeds=$1/$w_total shards=8"
}

# An aborted or failed run leaves claim files at canonical shard paths, and the
# resume gate would then refuse to start the next one.  Those files are this
# launcher's own and known incomplete, so they are re-verified and dropped when
# they do not stand up -- a worker that did finish before the abort keeps its
# hours.
reap_started_shards() {
	local index kept=0 removed=0
	for index in "${!firsts[@]}"; do
		if (( pids[index] == 0 )) || [[ ! -e "${outputs[$index]}" ]]; then continue; fi
		if "$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" verify \
				"$w_path" "$w_digest" "$module_digest" "${firsts[$index]}" \
				"${lasts[$index]}" "${outputs[$index]}" >/dev/null 2>&1; then
			kept=$((kept + 1))
		else
			rm -f -- "${outputs[$index]}"
			removed=$((removed + 1))
		fi
	done
	echo "WP40 T2 census reaped shards removed_partial=$removed kept_complete=$kept" >&2
}

# Section 6.5's liveness gate reads the fleet's CPU here (another reader of
# run_full_w's locals).  `/proc/<pid>/stat` fields 14 and 15 are the process's
# utime and stime in clock ticks; they are counted off the remainder after the
# comm field, because comm is parenthesised and may itself hold spaces.  Only
# live workers are summed, so a worker that exits takes its ticks out of the
# total: the sum can fall at a completion but never rise without a worker having
# burned CPU, which makes this gate under-report rather than false-fire.  The
# python SHA responder is a child process and its CPU appears neither here nor
# in the worker's own os.clock telemetry -- the same quantity on both sides.
fleet_cpu_seconds() {
	local total=0 pid stat rest
	for pid in "${pids[@]}"; do
		if (( pid == 0 )); then continue; fi
		read -r stat <"/proc/$pid/stat" 2>/dev/null || continue
		rest="${stat##*') '}"
		local -a fields=($rest)
		# A worker that exits between the poll and this read leaves nothing to
		# count; a stat line too short to hold both counters is that race, not a
		# fleet that burned no CPU, and either way it contributes zero.
		if (( ${#fields[@]} < 13 )); then continue; fi
		total=$((total + fields[11] + fields[12]))
	done
	printf '%s' "$((total / clock_ticks))"
}

# Section 6.6.5 and the M5 gate: the same merge runs twice on the same inputs,
# under LuaJIT and under the vendored PUC 5.1, and the five artifacts must come
# out byte for byte identical.  Only the PUC run is ever allowed to publish, so
# the comparison is between the artifact that will be committed and one an
# independent runtime produced -- not between two runs of the same interpreter.
#
# The LuaJIT half runs first and its artifacts digest is handed to the PUC half,
# which checks it before it writes anything.  Comparing only afterwards would
# leave six unvetted files in the committed tree whenever the gate fired, and
# the retry would then abort on "already exists" instead of on the divergence.
puc_bin="$repo/tools/bin/lua51"
# Gitignored, like the shards it sits beside: it describes one run of `W` and
# is regenerated by the next one.
cost_note_path="$repo/tools/wp40/results/t2_census/cost-projection.txt"
# Section 6.6.3's projection is re-taken at every completion, which over a full
# `W` is 4,123 near-identical lines of arithmetic.  The log keeps what a
# babysitter has to see -- the first verdict, every change of verdict (a
# deferral is the gate reporting that it saw an over-budget observation and held),
# and the drift as the estimate converges -- and the cost note keeps the rest.
cost_reported_wall=-1
cost_reported_verdict=""
report_cost_projection() {
	local wall_line="$1" cpu_line="$2" wall="" verdict=""
	if [[ "$wall_line" =~ wall_seconds=([0-9]+) ]]; then wall="${BASH_REMATCH[1]}"; fi
	# The verdict is the CPU gate's -- the wall line carries `verdict=advisory`
	# and always will, so throttling on it would collapse every change of state
	# the log is kept for.
	if [[ "$cpu_line" =~ verdict=([a-z]+) ]]; then verdict="${BASH_REMATCH[1]}"; fi
	if [[ -n "$wall" && "$verdict" == "$cost_reported_verdict" ]] &&
			(( cost_reported_wall >= 0 &&
				wall * 20 >= cost_reported_wall * 19 &&
				wall * 20 <= cost_reported_wall * 21 )); then
		return 0
	fi
	cost_reported_verdict="$verdict"
	cost_reported_wall="${wall:--1}"
	printf '%s\n%s\n' "$wall_line" "$cpu_line"
}
run_merge_pair() {
	local out_luajit="$1" out_puc="$2"
	shift 2
	mkdir -p "$out_luajit" "$out_puc"
	local luajit_scratch puc_scratch
	luajit_scratch="$(new_scratch)"
	puc_scratch="$(new_scratch)"
	"$lua_path" "$script_dir/t2_census_merge.lua" "$repo" "$luajit_scratch" \
		"$out_luajit" "$@"
	local luajit_digest
	luajit_digest="$(sed -n 's/^artifacts_digest\t\([0-9a-f]\{64\}\)$/\1/p' \
		"$out_luajit/census-manifest-v1.tsv")"
	if [[ ! "$luajit_digest" =~ ^[0-9a-f]{64}$ ]]; then
		echo "WP40 T2 census LuaJIT merge wrote no artifacts digest" >&2
		exit 1
	fi
	"$puc_bin" "$script_dir/t2_census_merge.lua" "$repo" "$puc_scratch" \
		"$out_puc" "$@" --expect-artifacts-digest "$luajit_digest"
	local artifact
	for artifact in census-occupied-classes-v1.tsv census-vacuous-branches-v1.tsv \
			census-scan4-seed-set-v1.tsv census-prefilter-discharge-v1.tsv \
			census-histograms-v1.tsv; do
		if ! cmp -s "$out_luajit/$artifact" "$out_puc/$artifact"; then
			echo "WP40 T2 census merge artifact $artifact differs between LuaJIT" \
				"and PUC (plan section 6.6.5)" >&2
			diff <(head -c 4096 "$out_luajit/$artifact") \
				<(head -c 4096 "$out_puc/$artifact") >&2 || true
			exit 1
		fi
	done
	merge_digest="$(sed -n 's/^artifacts_digest\t\([0-9a-f]\{64\}\)$/\1/p' \
		"$out_puc/census-manifest-v1.tsv")"
	if [[ ! "$merge_digest" =~ ^[0-9a-f]{64}$ ]]; then
		echo "WP40 T2 census merge wrote no artifacts digest" >&2
		exit 1
	fi
	echo "WP40 T2 census merge LuaJIT/PUC artifacts identical digest=$merge_digest"
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
	local module_digest
	module_digest="$("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" \
		module_digest)"
	[[ "$module_digest" =~ ^[0-9a-f]{64}$ ]] || {
		echo "WP40 T2 census could not pin the module bytes" >&2
		exit 2
	}
	echo "WP40 T2 census authority: commit=$commit tree=$tree modules=$module_digest"

	# Section 6.5 (2026-08-18): the run-cost budget is measured, never restated
	# here.  The conf is the contention probe's output and the gate refuses a
	# missing one and one older than the commit this run is reproducible from,
	# so no number in this file can drift from the measurement it claims.
	local head_date conf_line conf_status=0
	head_date="$(git -C "$repo" show -s --format=%cs "$commit")"
	conf_line="$("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" \
		cpu_gate "$head_date" 2>&1)" || conf_status=$?
	if (( conf_status != 0 )); then
		echo "$conf_line" >&2
		exit 2
	fi
	echo "$conf_line"
	local budget liveness_allowance
	budget="$(sed -n 's/.* budget_seconds=\([0-9.]\+\) .*/\1/p' <<<"$conf_line")"
	liveness_allowance="$(sed -n 's/.* liveness_x_seconds=\([0-9.]\+\) .*/\1/p' \
		<<<"$conf_line")"
	# The two overrides exist for the gate suite, which has to drive both gates
	# to their refusal in under two minutes; a real run takes both from the conf.
	budget="${WP40_CENSUS_CPU_BUDGET_SECONDS:-$budget}"
	liveness_allowance="${WP40_CENSUS_LIVENESS_X_SECONDS:-$liveness_allowance}"
	local deadline="${WP40_CENSUS_FIRST_RECORD_DEADLINE:-900}"
	[[ "$budget" =~ ^[0-9]+(\.[0-9]+)?$ ]] || {
		echo "WP40 T2 census could not read a CPU budget: $budget" >&2
		exit 2
	}
	[[ "$liveness_allowance" =~ ^[0-9]+(\.[0-9]+)?$ ]] || {
		echo "WP40 T2 census could not read a liveness allowance:" \
			"$liveness_allowance" >&2
		exit 2
	}
	[[ "$deadline" =~ ^[0-9]+$ && "$deadline" -gt 0 ]] || {
		echo "WP40_CENSUS_FIRST_RECORD_DEADLINE must be a positive integer" >&2
		exit 2
	}

	# The kernel counts process CPU in clock ticks and the gate decides in
	# seconds; fleet_cpu_seconds reads this local.
	local clock_ticks
	clock_ticks="$(getconf CLK_TCK)"
	[[ "$clock_ticks" =~ ^[0-9]+$ && "$clock_ticks" -gt 0 ]] || {
		echo "WP40 T2 census could not read CLK_TCK" >&2
		exit 2
	}

	# Section 6.5 (2026-08-18): the fleet yields to the user rather than the
	# other way round.  Detected here rather than assumed -- SCHED_IDLE and the
	# idle I/O class need no privilege on Linux, but a foreign kernel or a
	# container can still refuse either, and a launcher that silently dropped
	# the prefix would run a nine-hour fleet at normal priority.
	local -a idle_prefix=()
	local idle_label="none"
	if chrt --idle 0 true >/dev/null 2>&1; then
		idle_prefix=(chrt --idle 0)
		idle_label="chrt --idle 0"
		if ionice -c3 true >/dev/null 2>&1; then
			idle_prefix+=(ionice -c3)
			idle_label="$idle_label + ionice -c3"
		fi
	elif nice -n19 true >/dev/null 2>&1; then
		idle_prefix=(nice -n19)
		idle_label="nice -n19"
	fi
	if [[ "$idle_label" == "none" ]]; then
		echo "WP40 T2 census scheduling: none -- chrt, ionice and nice all" \
			"refused, so the fleet runs at normal priority" >&2
	else
		echo "WP40 T2 census scheduling: $idle_label"
	fi
	mkdir -p "$repo/tools/wp40/results/t2_census"

	local -a pids=() first_ready=() reaped=() statuses=()
	local resumed_seeds=0 resumed_shards=0 started=0 index
	for index in "${!firsts[@]}"; do
		logs+=("$scratch/shard-$index.log")
		first_ready+=(0)
		reaped+=(0)
		statuses+=(0)
		if [[ -e "${outputs[$index]}" ]]; then
			# Section 6.6.4: a shard on disk is verified, not assumed -- including
			# the empty claim file a crashed worker leaves, which the verifier
			# refuses as unparseable instead of reading as an empty shard.
			"$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" verify \
				"$w_path" "$w_digest" "$module_digest" "${firsts[$index]}" \
				"${lasts[$index]}" "${outputs[$index]}"
			resumed_seeds=$((resumed_seeds + sizes[index]))
			resumed_shards=$((resumed_shards + 1))
			pids+=(0)
		else
			local worker_scratch
			worker_scratch="$(new_scratch)"
			"${idle_prefix[@]}" \
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
	# `started + resumed_shards == 8` would be tautological here -- the loop runs
	# over eight indices and each one increments exactly one counter -- and this
	# branch has shipped a verification run that reported success with zero
	# workers started, so a guard that cannot fail is worse than none.  What
	# actually forbids that outcome is at the end of the run: every shard is
	# re-read from disk and the seed counts the verifier reports must add up to
	# |W|, which no amount of shell bookkeeping can fake.
	if (( started == 0 )); then
		assert_full_coverage "$resumed_seeds"
		echo "WP40 T2 census corpus progress global_completed=$w_total/$w_total" \
			"shards_done=8 source=resume"
		return 0
	fi

	local start_seconds=$SECONDS last_global=-1 cost_samples=""
	local failure="" worker_death=0
	# Section 6.6.3: each shard's own clocks at its own latest completion.  The
	# launcher's wall clock was read here until 2026-08-16 and gave every shard
	# with one completion the same rate -- the age of the fleet -- which turned
	# eight cold first seeds into a single 71 s/seed projection.  Since
	# 2026-08-18 the same line carries the shard's own CPU seconds beside its
	# wall seconds, and the CPU pair is the one that can abort the run.
	local progress_pattern='completed=([0-9]+)/[0-9]+ wall_seconds=([0-9]+) cpu_seconds=([0-9]+)'
	local liveness_mark=0 liveness_global=$resumed_seeds liveness_armed=0
	local liveness_checked=$SECONDS liveness_reported=0
	while :; do
		local active=0 running=0 ready=0 global=$resumed_seeds
		local -a samples=()
		local elapsed=$((SECONDS - start_seconds))
		for index in "${!firsts[@]}"; do
			local pid="${pids[$index]}"
			if (( pid == 0 )); then continue; fi
			running=$((running + 1))
			local alive=0
			if kill -0 "$pid" 2>/dev/null; then active=$((active + 1)); alive=1; fi
			local completed=0 shard_elapsed=0 shard_cpu=0 progress
			progress="$(grep '^WP40 T2 census shard progress ' "${logs[$index]}" \
				2>/dev/null | tail -n 1 || true)"
			if [[ "$progress" =~ $progress_pattern ]]; then
				completed="${BASH_REMATCH[1]}"
				shard_elapsed="${BASH_REMATCH[2]}"
				shard_cpu="${BASH_REMATCH[3]}"
			fi
			global=$((global + completed))
			if (( completed > 0 )); then
				samples+=("${sizes[$index]}:$completed:$shard_elapsed:$shard_cpu")
				# Section 6.6.2: validated once, on the first record that closed,
				# while this worker and the other seven keep running.
				if (( first_ready[index] == 0 )); then
					local record_output record_status=0
					record_output="$("$lua_path" "$script_dir/t2_census_gate.lua" \
						"$repo" "$scratch" first_record "$w_path" "$w_digest" \
						"$module_digest" "${firsts[$index]}" "${lasts[$index]}" \
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
			# Section 6.6.9: an exited worker is reaped at this poll, and any exit
			# short of a complete range -- crash, kill or a zero-status bug alike
			# -- aborts the fleet now instead of surfacing when the last survivor
			# finishes hours later.  Run 3 carried three dead shards past an
			# hourly log watch because worker errors reach the main log only at
			# run end.  The log is complete here: the process was already gone
			# before this iteration read it, and exit flushes the worker's
			# buffers.
			if (( alive == 0 && reaped[index] == 0 )); then
				local worker_status=0
				wait "$pid" 2>/dev/null || worker_status=$?
				reaped[index]=1
				statuses[index]=$worker_status
				if (( worker_status != 0 || completed != sizes[index] )); then
					worker_death=1
					failure="shard $((index + 1)) worker exited status=$worker_status at completed=$completed/${sizes[$index]} seeds"
					break
				fi
			fi
		done
		if [[ -n "$failure" ]]; then break; fi

		if (( ready < running && elapsed > deadline )); then
			failure="only $ready of $running workers produced a validated first record within ${deadline}s"
			break
		fi
		# Section 6.6.3: first projected once every worker has a completion to
		# project from -- so the abort still lands in the run's first minutes --
		# and re-projected at every completion after that.  A single completion
		# per shard is a cold-start observation; the estimate only becomes a rate
		# once a shard has answered twice, and the gate says which it has.
		if (( ${#samples[@]} == running && ready == running )) &&
				[[ "${samples[*]}" != "$cost_samples" ]]; then
			cost_samples="${samples[*]}"
			local cost_output cost_status=0
			cost_output="$("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" \
				"$scratch" cost "$budget" "${samples[@]}" 2>&1)" || cost_status=$?
			if (( cost_status != 0 )); then
				echo "$cost_output" >&2
				if (( cost_status == 3 )); then
					failure="the projected CPU per seed exceeds the ${budget}s budget"
				else
					failure="the cost gate failed to run (status $cost_status)"
				fi
				break
			fi
			local projection_line cpu_projection_line
			projection_line="$(grep '^WP40 T2 census cost projection ' \
				<<<"$cost_output" || true)"
			cpu_projection_line="$(grep '^WP40 T2 census cpu projection ' \
				<<<"$cost_output" || true)"
			if [[ -n "$projection_line" ]]; then
				# Section 6.5 requires the run manifest to state the measured
				# single-seed cost and the projected total, in wall time at a stated
				# worker count.  The merge is a separate process hours later, so the
				# projection is persisted beside the shards it describes rather than
				# left to die with this launcher's scratch directory.  The note
				# carries the newest evaluation: by the last completion the rolling
				# estimate has stopped being a projection and is a measurement.  The
				# wall line stays first: the merge reads one line and that value is
				# the manifest's, now stated as the advisory figure it is.
				printf '%s\n%s\n' "$projection_line" "$cpu_projection_line" \
					>"$cost_note_path"
				report_cost_projection "$projection_line" "$cpu_projection_line"
			fi
		fi

		if (( global != last_global )); then
			local eta=0
			if (( global > resumed_seeds && global < w_total )); then
				eta=$(((SECONDS - start_seconds) * (w_total - global) / (global - resumed_seeds)))
			fi
			echo "WP40 T2 census corpus progress global_completed=$global/$w_total" \
				"active=$active wall_seconds=$elapsed eta_seconds=$eta"
			last_global=$global
			# Section 6.5's liveness gate re-marks here and nowhere else: the span
			# it measures is "since the last completed seed", so a completion is
			# the only thing that may reset it.  It arms at the first completion
			# because before that there is no such span -- and the run's first
			# seeds are its most expensive, so a fleet-CPU allowance applied to
			# them would fire on a cold start.  The window before the first
			# completion belongs to gate 2's first-record deadline.
			if (( global > resumed_seeds )); then
				liveness_mark="$(fleet_cpu_seconds)"
				liveness_global=$global
				liveness_armed=1
			fi
		fi
		# Asked on a ten-second throttle rather than at every two-second poll:
		# the allowance is a fleet-CPU figure that a healthy fleet needs minutes
		# to approach, so a verdict per poll would only spend CPU on the gate
		# that measures CPU.
		if (( liveness_armed == 1 && active > 0 && SECONDS - liveness_checked >= 10 )); then
			liveness_checked=$SECONDS
			local consumed=$(($(fleet_cpu_seconds) - liveness_mark))
			if (( consumed < 0 )); then consumed=0; fi
			local liveness_output liveness_status=0
			liveness_output="$("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" \
				"$scratch" liveness "$consumed" "$((global - liveness_global))" \
				"$liveness_allowance" 2>&1)" || liveness_status=$?
			if (( liveness_status != 0 )); then
				echo "$liveness_output" >&2
				if (( liveness_status == 3 )); then
					failure="the fleet consumed ${consumed}s CPU without completing a seed"
				else
					failure="the liveness gate failed to run (status $liveness_status)"
				fi
				break
			fi
			# The first verdict is printed and the rest are not.  A gate that
			# never says anything is indistinguishable from a gate that never
			# ran, which this branch has shipped twice; a gate that says
			# something every ten seconds for nine hours is a log nobody reads.
			if (( liveness_reported == 0 )); then
				printf '%s\n' "$liveness_output"
				liveness_reported=1
			fi
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
		# A multi-hour run that aborts must leave the operator more than one
		# sentence: the scratch directory goes with the EXIT trap, so the logs
		# have to be surfaced here or they are gone.
		for index in "${!firsts[@]}"; do
			if (( pids[index] == 0 )); then continue; fi
			echo "--- WP40 T2 census shard $((index + 1)) log (tail) ---" >&2
			tail -n 20 "${logs[$index]}" >&2 2>/dev/null || true
		done
		if (( worker_death == 1 )); then
			# Section 6.6.9: deterministic workers die at the same seed on a
			# blind resume, so a worker death is triaged, never relaunched.  The
			# partial shards stay on disk as evidence -- the reaper serves the
			# resumable aborts, and this is not one.
			echo "WP40 T2 census partial shards left for triage under" \
				"tools/wp40/results/t2_census/; remove them before the next" \
				"full-W start" >&2
		else
			reap_started_shards
		fi
		echo "WP40 T2 census aborted: $failure" >&2
		exit 1
	fi

	local failed=0
	for index in "${!firsts[@]}"; do
		local pid="${pids[$index]}"
		if (( pid == 0 )); then continue; fi
		local status=0
		if (( reaped[index] == 1 )); then
			status="${statuses[$index]}"
		else
			wait "$pid" || status=$?
		fi
		if (( status == 0 )); then
			echo "WP40 T2 census shard done range=$(printf '%04d..%04d' \
				"${firsts[$index]}" "${lasts[$index]}")"
		else
			cat "${logs[$index]}" >&2
			echo "WP40 T2 census shard failed range=$(printf '%04d..%04d' \
				"${firsts[$index]}" "${lasts[$index]}") status=$status" >&2
			failed=1
		fi
	done
	if (( failed != 0 )); then
		reap_started_shards
		exit 1
	fi

	local verified_seeds=0 summary
	for index in "${!firsts[@]}"; do
		summary="$("$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" \
			verify "$w_path" "$w_digest" "$module_digest" "${firsts[$index]}" \
			"${lasts[$index]}" "${outputs[$index]}")"
		echo "$summary"
		[[ "$summary" =~ seeds=([0-9]+) ]] ||
			{ echo "WP40 T2 census verifier printed no seed count" >&2; exit 1; }
		verified_seeds=$((verified_seeds + BASH_REMATCH[1]))
	done
	assert_full_coverage "$verified_seeds"
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
	--merge-kat)
		shift
		if [[ $# -ne 0 ]]; then
			echo "--merge-kat accepts no further arguments" >&2
			exit 2
		fi
		# The worker KAT first, so the merge KAT always reads records this tree
		# just produced and its pinned artifact digest can never outlive the
		# record digest it was measured from.
		"$lua_path" "$script_dir/t2_census_worker.lua" "$repo" "$scratch" \
			"$scratch/census-kat.tsv" --kat
		run_merge_pair "$scratch/merge-luajit" "$scratch/merge-puc" \
			--records "$scratch/census-kat.tsv"
		"$lua_path" "$script_dir/t2_census_gate.lua" "$repo" "$scratch" \
			merge_kat "$merge_digest"
		;;
	--merge)
		shift
		if [[ $# -ne 0 ]]; then
			echo "--merge accepts no further arguments" >&2
			exit 2
		fi
		# Section 6.3 publishes into the committed fixtures; the merge itself
		# refuses to write there under anything but the vendored PUC, so the
		# LuaJIT half of the pair runs into scratch and is the comparison.
		# Section 6.5's cost statement comes from the run that measured it,
		# persisted beside the shards; the environment override exists for a
		# merge of shards whose run predates that file.
		cost_projection="${WP40_CENSUS_COST_PROJECTION:-}"
		if [[ -z "$cost_projection" && -s "$cost_note_path" ]]; then
			cost_projection="$(head -n 1 "$cost_note_path")"
		fi
		if [[ -n "$cost_projection" ]]; then
			run_merge_pair "$scratch/merge-luajit" "$repo/tools/wp40/fixtures/t2_census" \
				--full-w --cost-projection "$cost_projection"
		else
			run_merge_pair "$scratch/merge-luajit" "$repo/tools/wp40/fixtures/t2_census" \
				--full-w
		fi
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
		echo "       tools/wp40/run_t2_census.sh --merge-kat" >&2
		echo "       tools/wp40/run_t2_census.sh --plan" >&2
		echo "       WP40_CENSUS_GO=<token> tools/wp40/run_t2_census.sh --full-w" >&2
		echo "       tools/wp40/run_t2_census.sh --merge" >&2
		exit 2
		;;
esac
