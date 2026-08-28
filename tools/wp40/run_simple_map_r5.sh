#!/usr/bin/env bash
set -euo pipefail
set +m

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
mode="${WP40_R5_MODE:-selftest}"
lua_bin="${WP40_LUA_BIN:-}"
puc_bin="$repo/tools/bin/lua51"
luac_bin="$repo/tools/bin/luac51"
time_bin=/usr/bin/time

case "$mode" in
	selftest|quick|full|final) ;;
	*) echo "run_simple_map_r5.sh: mode must be selftest, quick, full or final" >&2; exit 1 ;;
esac

for command_name in rg chrt ionice sha256sum sort awk cmp mktemp bash cat date \
	cp mv chmod rm basename dirname hostname setsid ps sleep env kill; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "run_simple_map_r5.sh: $command_name is required" >&2
		exit 1
	}
done
[[ -x "$time_bin" ]] || {
	echo "run_simple_map_r5.sh: /usr/bin/time is required" >&2
	exit 1
}

if [[ -z "$lua_bin" ]]; then
	if [[ -x /usr/bin/luajit ]]; then
		lua_bin=/usr/bin/luajit
	else
		lua_bin="$(command -v luajit 2>/dev/null || true)"
	fi
fi
[[ -n "$lua_bin" && -x "$lua_bin" && -x "$luac_bin" ]] || {
	echo "run_simple_map_r5.sh: LuaJIT and repository luac51 are required" >&2
	exit 1
}
if [[ "$mode" == final && ! -x "$puc_bin" ]]; then
	echo "run_simple_map_r5.sh: final mode requires repository tools/bin/lua51" >&2
	exit 1
fi

scratch="$(mktemp -d /tmp/grudgelands-wp40-r5.XXXXXXXX)"
start_epoch="$(date +%s)"
declare -A active_leaders=()
declare -A active_waiters=()
declare -A provisional_ready=()
child_scratches=()
new_scratch_result=""
new_async_pid=""
promotion_tmp=""

read_ready_leader() {
	local ready_file="$1" leader line_count
	[[ -f "$ready_file" ]] || return 1
	leader="$(awk 'NR == 1 { print; exit }' "$ready_file")"
	line_count="$(awk 'END { print NR }' "$ready_file")"
	[[ "$line_count" -eq 1 && "$leader" =~ ^[0-9]+$ && "$leader" -gt 1 ]] || return 1
	printf '%s\n' "$leader"
}

fresh_wait_owner() {
	local wait_pid="$1" parent_pid
	[[ "$wait_pid" =~ ^[0-9]+$ && "$wait_pid" -gt 1 ]] || return 1
	parent_pid="$(ps -o ppid= -p "$wait_pid" 2>/dev/null | awk '{print $1}')"
	[[ "$parent_pid" =~ ^[0-9]+$ && "$parent_pid" -eq "$BASHPID" ]]
}

fresh_group_identity() {
	local wait_pid="$1" leader_pid="$2" require_stopped="$3"
	local parent_pid pgid sid state
	fresh_wait_owner "$wait_pid" || return 1
	[[ "$leader_pid" =~ ^[0-9]+$ && "$leader_pid" -gt 1 ]] || return 1
	parent_pid="$(ps -o ppid= -p "$leader_pid" 2>/dev/null | awk '{print $1}')"
	pgid="$(ps -o pgid= -p "$leader_pid" 2>/dev/null | awk '{print $1}')"
	sid="$(ps -o sid= -p "$leader_pid" 2>/dev/null | awk '{print $1}')"
	state="$(ps -o stat= -p "$leader_pid" 2>/dev/null | awk '{print $1}')"
	[[ "$parent_pid" =~ ^[0-9]+$ && "$parent_pid" -eq "$wait_pid" &&
		"$pgid" =~ ^[0-9]+$ && "$sid" =~ ^[0-9]+$ &&
		"$leader_pid" -eq "$pgid" && "$leader_pid" -eq "$sid" &&
		-n "$state" && "$state" != Z* ]] || return 1
	[[ "$require_stopped" != true || "$state" == T* ]]
}

signal_fresh_group() {
	local wait_pid="$1" leader_pid="$2" signal="$3" require_stopped="$4"
	[[ "$signal" == CONT || "$signal" == TERM || "$signal" == KILL ]] || return 1
	fresh_group_identity "$wait_pid" "$leader_pid" "$require_stopped" || return 1
	kill "-$signal" -- "-$leader_pid"
}

active_group_live() {
	local wait_pid="$1" leader_pid="${active_leaders[$1]:-}"
	[[ "$wait_pid" =~ ^[0-9]+$ && "$wait_pid" -gt 1 &&
		"$leader_pid" =~ ^[0-9]+$ && "$leader_pid" -gt 1 &&
		"${active_waiters[$leader_pid]:-}" == "$wait_pid" ]] || return 1
	fresh_group_identity "$wait_pid" "$leader_pid" false
}

signal_active_group() {
	local wait_pid="$1" signal="$2" require_stopped="${3:-false}"
	local leader_pid="${active_leaders[$1]:-}"
	[[ "$leader_pid" =~ ^[0-9]+$ &&
		"${active_waiters[$leader_pid]:-}" == "$wait_pid" ]] || return 1
	signal_fresh_group "$wait_pid" "$leader_pid" "$signal" "$require_stopped"
}

cleanup_provisional() {
	local wait_pid="$1" ready_file="${provisional_ready[$1]:-}" leader_pid=""
	[[ "$wait_pid" =~ ^[0-9]+$ && "$wait_pid" -gt 1 && -n "$ready_file" ]] || return 1
	leader_pid="$(read_ready_leader "$ready_file" 2>/dev/null || true)"
	if [[ "$leader_pid" =~ ^[0-9]+$ ]]; then
		signal_fresh_group "$wait_pid" "$leader_pid" KILL false >/dev/null 2>&1 || true
	fi
	if fresh_wait_owner "$wait_pid"; then
		kill -KILL "$wait_pid" >/dev/null 2>&1 || true
	fi
	wait "$wait_pid" >/dev/null 2>&1 || true
	unset 'provisional_ready[$wait_pid]'
}

terminate_tracked_group() {
	local wait_pid="$1" leader_pid="${active_leaders[$1]:-}" attempt
	[[ "$leader_pid" =~ ^[0-9]+$ &&
		"${active_waiters[$leader_pid]:-}" == "$wait_pid" ]] || return 1
	if active_group_live "$wait_pid"; then
		signal_active_group "$wait_pid" TERM >/dev/null 2>&1 || true
	fi
	for attempt in {1..50}; do
		active_group_live "$wait_pid" || break
		sleep 0.02
	done
	if active_group_live "$wait_pid"; then
		signal_active_group "$wait_pid" KILL >/dev/null 2>&1 || true
	fi
	wait "$wait_pid" >/dev/null 2>&1 || true
	unset 'active_leaders[$wait_pid]'
	unset 'active_waiters[$leader_pid]'
}

cleanup() {
	local wait_pid directory
	for wait_pid in "${!provisional_ready[@]}"; do
		cleanup_provisional "$wait_pid" || true
	done
	for wait_pid in "${!active_leaders[@]}"; do
		terminate_tracked_group "$wait_pid" || true
	done
	for directory in "${child_scratches[@]}"; do
		case "$directory" in
			/tmp/grudgelands-wp40-r5.*) rm -rf -- "$directory" ;;
		esac
	done
	if [[ "$scratch" == /tmp/grudgelands-wp40-r5.* ]]; then
		rm -rf -- "$scratch"
	fi
	if [[ -n "$promotion_tmp" ]]; then rm -f -- "$promotion_tmp"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

wait_tracked() {
	local wait_pid="$1" leader_pid="${active_leaders[$1]:-}" status=0
	[[ "$leader_pid" =~ ^[0-9]+$ &&
		"${active_waiters[$leader_pid]:-}" == "$wait_pid" ]] || return 1
	wait "$wait_pid" || status=$?
	unset 'active_leaders[$wait_pid]'
	unset 'active_waiters[$leader_pid]'
	return "$status"
}
new_child_scratch() {
	local directory
	directory="$(mktemp -d /tmp/grudgelands-wp40-r5.XXXXXXXX)"
	child_scratches+=("$directory")
	new_scratch_result="$directory"
}
start_authenticated_session() {
	local kind="$1" interpreter="$2" resource_file ready_file wait_pid leader_pid=""
	local attempt deferred_signal=""
	shift 2
	[[ "$kind" == luajit || "$kind" == puc51 ]] || return 1
	resource_file="$(mktemp "$scratch/resource-$kind.XXXXXXXX")"
	ready_file="$(mktemp "$scratch/session-$kind.XXXXXXXX")"
	trap 'deferred_signal=INT' INT
	trap 'deferred_signal=TERM' TERM
	# The session child expands its own PID and stops before time or Lua starts.
	# shellcheck disable=SC2016
	setsid --fork --wait bash -c '
		ready_file=$1
		shift
		printf "%s\n" "$$" >"$ready_file" || exit 1
		kill -STOP "$$"
		exec "$@"
	' bash "$ready_file" env LC_ALL=C "$time_bin" -q \
		-f 'r5_resource_v1\t%U\t%S\t%M' \
		-o "$resource_file" chrt --idle 0 ionice -c3 "$interpreter" "$@" \
		&
	wait_pid=$!
	if [[ ! "$wait_pid" =~ ^[0-9]+$ || "$wait_pid" -le 1 ]]; then
		trap 'exit 130' INT
		trap 'exit 143' TERM
		return 1
	fi
	provisional_ready["$wait_pid"]="$ready_file"
	for ((attempt = 0; attempt < 200; attempt++)); do
		leader_pid="$(read_ready_leader "$ready_file" 2>/dev/null || true)"
		if [[ "$leader_pid" =~ ^[0-9]+$ ]] &&
				fresh_group_identity "$wait_pid" "$leader_pid" true; then break; fi
		fresh_wait_owner "$wait_pid" || break
		sleep 0.01
	done
	if [[ ! "$leader_pid" =~ ^[0-9]+$ ]] ||
			! fresh_group_identity "$wait_pid" "$leader_pid" true; then
		cleanup_provisional "$wait_pid" || true
		trap 'exit 130' INT
		trap 'exit 143' TERM
		return 1
	fi
	active_leaders["$wait_pid"]="$leader_pid"
	active_waiters["$leader_pid"]="$wait_pid"
	unset 'provisional_ready[$wait_pid]'
	trap 'exit 130' INT
	trap 'exit 143' TERM
	case "$deferred_signal" in
		INT) exit 130 ;;
		TERM) exit 143 ;;
	esac
	if ! signal_active_group "$wait_pid" CONT true; then
		terminate_tracked_group "$wait_pid" || true
		return 1
	fi
	new_async_pid="$wait_pid"
}

start_luajit_session() {
	start_authenticated_session luajit "$lua_bin" \
		-e '_G.wp40_ffi=require("ffi")' "$@"
}

start_puc_session() {
	start_authenticated_session puc51 "$puc_bin" "$@"
}

run_luajit() {
	local wait_pid
	start_luajit_session "$@"
	wait_pid="$new_async_pid"
	wait_tracked "$wait_pid"
}

run_puc() {
	local wait_pid
	start_puc_session "$@"
	wait_pid="$new_async_pid"
	wait_tracked "$wait_pid"
}

start_luajit_async() {
	local log="$1"
	shift
	start_luajit_session "$@" >"$log" 2>&1
}

start_puc_async() {
	local log="$1"
	shift
	start_puc_session "$@" >"$log" 2>&1
}

luajit_identity_log="$scratch/luajit-identity.log"
if ! run_luajit -v -e 'assert(type(rawget(_G,"jit"))=="table")' \
		>"$luajit_identity_log" 2>&1; then
	echo "run_simple_map_r5.sh: WP40_LUA_BIN must select LuaJIT" >&2
	exit 1
fi
cat "$luajit_identity_log"

lua_files=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/index128.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/zones.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/counting_allocator.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/planner.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/r5.lua"
	"$repo/tools/wp40/simple_map_r5_common.lua"
	"$repo/tools/wp40/simple_map_r5_offline.lua"
	"$repo/tools/wp40/simple_map_r5_validate.lua"
	"$repo/tools/wp40/simple_map_r5_kat.lua"
	"$repo/tools/wp40/simple_map_r5_vm.lua"
	"$repo/tools/wp40/simple_map_r5_artifact.lua"
	"$repo/tools/wp40/simple_map_r5_selftest.lua"
)
for file in "${lua_files[@]}"; do
	[[ -f "$file" ]] || {
		echo "run_simple_map_r5.sh: required Lua file missing: $file" >&2
		exit 1
	}
done

"$luac_bin" -p "${lua_files[@]}"
for file in "${lua_files[@]}"; do
	if "$luac_bin" -l -p -o /dev/null "$file" | rg -n 'SETGLOBAL'; then
		echo "run_simple_map_r5.sh: unexpected global write in $file" >&2
		exit 1
	fi
done
if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${lua_files[@]}" ||
	rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${lua_files[@]}" ||
	rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${lua_files[@]}" ||
	rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${lua_files[@]}" ||
	rg -n '\brequire[[:space:]]*\(|io\.popen|os\.exit|\bminetest\.' "${lua_files[@]}"; then
	echo "run_simple_map_r5.sh: Lua 5.1/sandbox source sweep failed" >&2
	exit 1
fi
for file in "${lua_files[@]}"; do
	if [[ "$file" != "$repo/tools/wp40/simple_map_r5_offline.lua" ]] &&
			rg -n 'os\.execute' "$file"; then
		echo "run_simple_map_r5.sh: os.execute escaped the offline authority seam" >&2
		exit 1
	fi
done
[[ "$(rg -c 'os\.execute' "$repo/tools/wp40/simple_map_r5_offline.lua")" -eq 1 ]] || {
	echo "run_simple_map_r5.sh: offline authority command seam changed" >&2
	exit 1
}
if rg -n 'register_on_generated|register_mapgen_script|register_lbm|write_to_map|set_mapgen_setting|set_mapgen_params' \
		"$repo/mods/MAPGEN/grug_mapgen/wp40" --glob '*.lua'; then
	echo "run_simple_map_r5.sh: disabled R5 source contains activation API" >&2
	exit 1
fi
bash -n "$repo/tools/wp40/run_simple_map_r5.sh"

manifest=""

create_current_manifest() {
	local path="$1" label="$2" manifest_scratch log
	new_child_scratch
	manifest_scratch="$new_scratch_result"
	log="$scratch/$label-current-manifest.log"
	run_luajit "$repo/tools/wp40/simple_map_r5_artifact.lua" \
		"$repo" "$manifest_scratch" "$path" manifest >"$log" 2>&1
	cat "$log"
}

run_full_preflight() {
	local label="$1" manifest_path="$2" report_path="$3"
	local preflight_scratch log
	new_child_scratch
	preflight_scratch="$new_scratch_result"
	log="$scratch/$label-preflight.log"
	run_luajit "$repo/tools/wp40/simple_map_r5_artifact.lua" \
		"$repo" "$preflight_scratch" "$report_path" preflight \
		"$manifest_path" >"$log" 2>&1
	cat "$log"
}

verify_manifest() {
	local label="$1" check_path check_log
	check_path="$scratch/input-manifest-$label.tsv"
	check_log="$scratch/input-manifest-$label.log"
	create_current_manifest "$check_path" "$label" >"$check_log" 2>&1
	cat "$check_log"
	cmp -s "$manifest" "$check_path" || {
		echo "run_simple_map_r5.sh: immutable input manifest changed at $label" >&2
		return 1
	}
}

run_selftest() {
	local worker_scratch log
	new_child_scratch
	worker_scratch="$new_scratch_result"
	log="$scratch/selftest-luajit.log"
	run_luajit "$repo/tools/wp40/simple_map_r5_selftest.lua" \
		"$repo" "$worker_scratch" >"$log" 2>&1
	cat "$log"
}

fleet_reports=()
run_fixture_fleet() {
	local label="$1" historical_report="$2"
	local index fixture worker_scratch report log pid failed
	local -a fixtures=(seed_0 worst_fixture matrix native_heightmap owner_order \
		dungeon disabled)
	local -a pids=() logs=()
	fleet_reports=("$historical_report")
	for index in 0 1 2 3 4 5 6; do
		fixture="${fixtures[$index]}"
		new_child_scratch
		worker_scratch="$new_scratch_result"
		report="$scratch/$label-$fixture.tsv"
		log="$scratch/$label-$fixture.log"
		start_luajit_async "$log" "$repo/tools/wp40/simple_map_r5_artifact.lua" \
			"$repo" "$worker_scratch" "$report" shard "$manifest" "$fixture" \
			|| return 1
		pid="$new_async_pid"
		pids+=("$pid")
		logs+=("$log")
		fleet_reports+=("$report")
	done
	failed=0
	for index in 0 1 2 3 4 5 6; do
		if ! wait_tracked "${pids[$index]}"; then failed=1; fi
		cat "${logs[$index]}"
	done
	[[ "$failed" -eq 0 ]] || return 1
	[[ "${#fleet_reports[@]}" -eq 8 ]] || return 1
}

validate_fleet() {
	local label="$1" receipt="$2" merge_scratch log
	shift 2
	new_child_scratch
	merge_scratch="$new_scratch_result"
	log="$scratch/$label-validate.log"
	run_luajit "$repo/tools/wp40/simple_map_r5_artifact.lua" \
		"$repo" "$merge_scratch" "$receipt" validate "$manifest" "$@" \
		>"$log" 2>&1
	cat "$log"
}

merge_fleet() {
	local label="$1" artifact="$2" merge_scratch log
	shift 2
	new_child_scratch
	merge_scratch="$new_scratch_result"
	log="$scratch/$label-merge.log"
	run_luajit "$repo/tools/wp40/simple_map_r5_artifact.lua" \
		"$repo" "$merge_scratch" "$artifact" merge "$manifest" "$@" \
		>"$log" 2>&1
	cat "$log"
}

version_digest_from_log() {
	local token="$1" log="$2" version_line version_line_count
	version_line="$(awk 'NR == 1 { print; exit }' "$log")"
	case "$token" in
		luajit)
			[[ "$version_line" == LuaJIT\ * ]] || return 1
			version_line_count="$(awk '/^LuaJIT / { count++ } END { print count + 0 }' "$log")"
			;;
		puc51)
			[[ "$version_line" == Lua\ 5.1* ]] || return 1
			version_line_count="$(awk '/^Lua 5\.1/ { count++ } END { print count + 0 }' "$log")"
			;;
		*) return 1 ;;
	esac
	[[ "$version_line_count" -eq 1 ]] || return 1
	printf '%s\n' "$version_line" | sha256sum | awk '{print $1}'
}

write_micro_status() {
	local path="$1" token="$2" interpreter="$3" exit_status="$4" output="$5" log="$6"
	local present=false body_digest file_digest version_digest executable_digest
	body_digest="$(printf '0%.0s' {1..64})"
	file_digest="$body_digest"
	if [[ "$exit_status" -eq 0 && -f "$output" ]]; then
		present=true
		body_digest="$(awk -F '\t' '$1 == "kat_sha256" {print $2}' "$output")"
		[[ "$body_digest" =~ ^[0-9a-f]{64}$ ]] || return 1
		file_digest="$(sha256sum "$output" | awk '{print $1}')"
	fi
	version_digest="$(version_digest_from_log "$token" "$log")"
	executable_digest="$(sha256sum "$interpreter" | awk '{print $1}')"
	{
		printf 'schema\tgrug_wp40_r5_micro_kat_status_v1\n'
		printf 'interpreter\t%s\n' "$token"
		printf 'executable_sha256\t%s\n' "$executable_digest"
		printf 'version_sha256\t%s\n' "$version_digest"
		printf 'input_manifest_sha256\t%s\n' "$(sha256sum "$manifest" | awk '{print $1}')"
		printf 'output_present\t%s\n' "$present"
		printf 'kat_body_sha256\t%s\n' "$body_digest"
		printf 'kat_file_sha256\t%s\n' "$file_digest"
		printf 'exit_status\t%s\n' "$exit_status"
	} >"$path"
}

run_final_micro_pair() {
	local lj_scratch puc_scratch lj_output puc_output lj_log puc_log
	local lj_status puc_status lj_pid puc_pid lj_exit=0 puc_exit=0
	new_child_scratch
	lj_scratch="$new_scratch_result"
	new_child_scratch
	puc_scratch="$new_scratch_result"
	lj_output="$scratch/micro-luajit.tsv"
	puc_output="$scratch/micro-puc51.tsv"
	lj_log="$scratch/micro-luajit.log"
	puc_log="$scratch/micro-puc51.log"
	lj_status="$scratch/micro-luajit-status.tsv"
	puc_status="$scratch/micro-puc51-status.tsv"
	# The FFI SHA seam is intentionally LuaJIT-only. PUC uses Offline's command
	# backend; byte-identical canonical KAT output is the cross-engine gate.
	start_luajit_async "$lj_log" -v "$repo/tools/wp40/simple_map_r5_kat.lua" \
		"$repo" "$lj_scratch" "$manifest" "$lj_output" micro
	lj_pid="$new_async_pid"
	start_puc_async "$puc_log" -v "$repo/tools/wp40/simple_map_r5_kat.lua" \
		"$repo" "$puc_scratch" "$manifest" "$puc_output" micro
	puc_pid="$new_async_pid"
	wait_tracked "$lj_pid" || lj_exit=$?
	wait_tracked "$puc_pid" || puc_exit=$?
	write_micro_status "$lj_status" luajit "$lua_bin" "$lj_exit" "$lj_output" "$lj_log"
	write_micro_status "$puc_status" puc51 "$puc_bin" "$puc_exit" "$puc_output" "$puc_log"
	cat "$lj_log" "$puc_log" "$lj_status" "$puc_status"
	[[ "$lj_exit" -eq 0 && "$puc_exit" -eq 0 ]] || return 1
	cmp -s "$lj_output" "$puc_output" || {
		echo "run_simple_map_r5.sh: final LuaJIT/PUC micro-KAT bytes differ" >&2
		return 1
	}
	printf 'r5_micro_pair_canonical_body_sha256\t%s\n' \
		"$(awk -F '\t' '$1 == "kat_sha256" {print $2}' "$lj_output")"
	printf 'r5_micro_pair_canonical_file_sha256\t%s\n' \
		"$(sha256sum "$lj_output" | awk '{print $1}')"
}

emit_resource_summary() {
	local kind file summary process_count user_seconds system_seconds cpu_seconds peak_rss_kib
	local -a files
	for kind in luajit puc51; do
		files=()
		for file in "$scratch/resource-$kind".*; do
			[[ -f "$file" ]] && files+=("$file")
		done
		if [[ "${#files[@]}" -eq 0 ]]; then
			printf 'r5_resource_unbound\t%s\tprocess_count\t0\tuser_seconds\t0.000000\tsystem_seconds\t0.000000\tcpu_seconds\t0.000000\tpeak_rss_kib\t0\n' "$kind"
			continue
		fi
		summary="$(LC_ALL=C sort "${files[@]}" | awk -F '\t' '
			$1 != "r5_resource_v1" || NF != 4 ||
			$2 !~ /^[0-9]+([.][0-9]+)?$/ || $3 !~ /^[0-9]+([.][0-9]+)?$/ ||
			$4 !~ /^[0-9]+$/ { bad = 1; next }
			{ count++; user += $2; system += $3; if ($4 > peak) peak = $4 }
			END {
				if (bad || count == 0) exit 1
				printf "%d\t%.6f\t%.6f\t%.6f\t%d\n",
					count, user, system, user + system, peak
			}' )"
		IFS=$'\t' read -r process_count user_seconds system_seconds cpu_seconds \
			peak_rss_kib <<<"$summary"
		printf 'r5_resource_unbound\t%s\tprocess_count\t%s\tuser_seconds\t%s\tsystem_seconds\t%s\tcpu_seconds\t%s\tpeak_rss_kib\t%s\n' \
			"$kind" "$process_count" "$user_seconds" "$system_seconds" \
			"$cpu_seconds" "$peak_rss_kib"
	done
}

emit_unbound_evidence() {
	local end_epoch host_sha256 luajit_version_sha256 puc_version_sha256
	local full_buffer_cells total_buffer_cells numeric_payload_bytes
	end_epoch="$(date +%s)"
	host_sha256="$(hostname | sha256sum | awk '{print $1}')"
	luajit_version_sha256="$(version_digest_from_log luajit "$luajit_identity_log")"
	printf 'r5_timing_unbound\twall_seconds\t%s\n' "$((end_epoch - start_epoch))"
	printf 'r5_host_unbound\thostname_sha256\t%s\n' "$host_sha256"
	printf 'r5_runtime_unbound\tluajit_executable_sha256\t%s\n' \
		"$(sha256sum "$lua_bin" | awk '{print $1}')"
	printf 'r5_runtime_unbound\tluajit_version_sha256\t%s\n' "$luajit_version_sha256"
	if [[ "$mode" == final ]]; then
		puc_version_sha256="$(awk -F '\t' '$1 == "version_sha256" { print $2 }' \
			"$scratch/micro-puc51-status.tsv")"
		[[ "$puc_version_sha256" =~ ^[0-9a-f]{64}$ ]] || return 1
		[[ "$(awk -F '\t' '$1 == "version_sha256" { print $2 }' \
			"$scratch/micro-luajit-status.tsv")" == "$luajit_version_sha256" ]] || return 1
		printf 'r5_runtime_unbound\tpuc51_executable_sha256\t%s\n' \
			"$(sha256sum "$puc_bin" | awk '{print $1}')"
		printf 'r5_runtime_unbound\tpuc51_version_sha256\t%s\n' "$puc_version_sha256"
	else
		printf 'r5_runtime_unbound\tpuc51_status\tnot_run\n'
	fi
	emit_resource_summary
	full_buffer_cells=$((112 * 112 * 112))
	total_buffer_cells=$((4 * full_buffer_cells))
	numeric_payload_bytes=$((total_buffer_cells * 8))
	printf 'r5_buffer_estimate_unbound\tretained_full_buffer_formula\t4x112x112x112\tbuffer_count\t4\tcells_per_buffer\t%s\ttotal_cells\t%s\n' \
		"$full_buffer_cells" "$total_buffer_cells"
	printf 'r5_buffer_estimate_unbound\tnumeric_payload_lower_bound\tbytes_per_number\t8\ttotal_bytes\t%s\tscope\tdouble_payload_only_excludes_table_storage\n' \
		"$numeric_payload_bytes"
}

if [[ "$mode" == selftest ]]; then
	run_selftest
	echo "WP40 simple-map R5 LuaJIT selftest passed"
	exit 0
fi

if [[ "$mode" == quick ]]; then
	run_selftest
	manifest="$scratch/input-manifest-quick.tsv"
	create_current_manifest "$manifest" quick
	quick_pids=()
	quick_logs=()
	for fixture in matrix native_heightmap; do
		new_child_scratch
		worker_scratch="$new_scratch_result"
		report="$scratch/quick-$fixture.tsv"
		log="$scratch/quick-$fixture.log"
		start_luajit_async "$log" "$repo/tools/wp40/simple_map_r5_artifact.lua" \
			"$repo" "$worker_scratch" "$report" shard "$manifest" "$fixture" \
			|| exit 1
		pid="$new_async_pid"
		quick_pids+=("$pid")
		quick_logs+=("$log")
	done
	quick_failed=0
	for index in 0 1; do
		if ! wait_tracked "${quick_pids[$index]}"; then quick_failed=1; fi
		cat "${quick_logs[$index]}"
	done
	[[ "$quick_failed" -eq 0 ]] || exit 1
	verify_manifest after-quick
	echo "WP40 simple-map R5 LuaJIT quick fixtures passed"
	exit 0
fi

manifest_a="$scratch/input-manifest-a.tsv"
historical_a="$scratch/fleet-a-historical_r4.tsv"
run_full_preflight fleet-a "$manifest_a" "$historical_a"
manifest="$manifest_a"
run_selftest
verify_manifest after-selftest
run_fixture_fleet fleet-a "$historical_a"
fleet_a=("${fleet_reports[@]}")
validate_fleet fleet-a "$scratch/fleet-a-valid.tsv" "${fleet_a[@]}"
verify_manifest after-fleet-a

if [[ "$mode" == full ]]; then
	merge_fleet fleet-a "$scratch/simple-map-r5-untrusted.tsv" "${fleet_a[@]}"
	verify_manifest after-full-merge
	printf 'r5_untrusted_staged_artifact_sha256\t%s\n' \
		"$(sha256sum "$scratch/simple-map-r5-untrusted.tsv" | awk '{print $1}')"
	emit_unbound_evidence
	echo "WP40 simple-map R5 full LuaJIT evidence passed; staged output is untrusted"
	exit 0
fi

output="${1:-}"
[[ -n "$output" ]] || {
	echo "usage: WP40_R5_MODE=final tools/wp40/run_simple_map_r5.sh OUTPUT.tsv" >&2
	exit 1
}
output_dir="$(cd "$(dirname -- "$output")" && pwd -P)"
output_base="$(basename -- "$output")"
output="$output_dir/$output_base"
[[ "$output" == "$repo/docs/research/wp40-simple-map-r5-artifact.tsv" ]] || {
	echo "run_simple_map_r5.sh: final mode promotes only the canonical R5 artifact" >&2
	exit 1
}

manifest_b="$scratch/input-manifest-b.tsv"
historical_b="$scratch/fleet-b-historical_r4.tsv"
run_full_preflight fleet-b "$manifest_b" "$historical_b"
cmp -s "$manifest_a" "$manifest_b" || {
	echo "run_simple_map_r5.sh: independent preflight manifests differ" >&2
	exit 1
}
manifest="$manifest_b"
run_fixture_fleet fleet-b "$historical_b"
fleet_b=("${fleet_reports[@]}")
validate_fleet fleet-b "$scratch/fleet-b-valid.tsv" "${fleet_b[@]}"
verify_manifest after-fleet-b
run_final_micro_pair
verify_manifest after-micro-pair

artifact_a="$scratch/simple-map-r5-a.tsv"
artifact_b="$scratch/simple-map-r5-b.tsv"
manifest="$manifest_a"
merge_fleet fleet-a "$artifact_a" "${fleet_a[@]}"
manifest="$manifest_b"
merge_fleet fleet-b "$artifact_b" "${fleet_b[@]}"
cmp -s "$artifact_a" "$artifact_b" || {
	echo "run_simple_map_r5.sh: repeated canonical artifact bytes differ" >&2
	exit 1
}
verify_manifest before-promotion

promotion_tmp="$(mktemp "$output_dir/.${output_base}.wp40-r5.XXXXXXXX")"
cp "$artifact_a" "$promotion_tmp"
cmp -s "$artifact_a" "$promotion_tmp" || {
	echo "run_simple_map_r5.sh: staged promotion bytes differ" >&2
	exit 1
}
chmod 0644 "$promotion_tmp"
artifact_file_sha256="$(sha256sum "$promotion_tmp" | awk '{print $1}')"
input_manifest_sha256="$(sha256sum "$manifest" | awk '{print $1}')"
[[ "$artifact_file_sha256" =~ ^[0-9a-f]{64}$ &&
	"$input_manifest_sha256" =~ ^[0-9a-f]{64}$ ]] || exit 1
printf 'r5_artifact_file_sha256\t%s\n' "$artifact_file_sha256"
printf 'r5_input_manifest_sha256\t%s\n' "$input_manifest_sha256"
emit_unbound_evidence
echo "WP40 simple-map R5 final evidence and micro parity passed; atomic promotion is the final operation"
mv -f -- "$promotion_tmp" "$output"
