#!/usr/bin/env bash
set -euo pipefail
set +m

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../../.." && pwd)"
mode="${1:-}"
shift || true
lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"
luac_bin="$repo/tools/bin/luac51"
cli="$script_dir/cli.lua"
time_bin=/usr/bin/time

case "$mode" in
	pilot|fleet|validate) ;;
	*) echo "usage: bash tools/wp40/r6/run.sh pilot|fleet|validate ..." >&2; exit 2 ;;
esac

for command_name in rg sha256sum chrt ionice setsid mktemp awk cmp mv rm ps kill \
		sort bash cat mkdir dirname basename du; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "WP40 R6 runner: missing command $command_name" >&2
		exit 1
	}
done
[[ -x "$lua_bin" && -x "$luac_bin" && -x "$time_bin" ]] || {
	echo "WP40 R6 runner: LuaJIT, luac51 and /usr/bin/time are required" >&2
	exit 1
}

scratch="$(mktemp -d /tmp/grudgelands-wp40-r6.XXXXXXXX)"
active_pids=()
promotion_tmp=""
pilot_tmp=""
run_receipt_tmp=""

cleanup() {
	local pid
	for pid in "${active_pids[@]}"; do
		if [[ "$pid" =~ ^[0-9]+$ ]] && ps -p "$pid" >/dev/null 2>&1; then
			kill -TERM -- "-$pid" 2>/dev/null || true
			kill -KILL -- "-$pid" 2>/dev/null || true
		fi
	done
	if [[ -n "$promotion_tmp" ]]; then rm -f -- "$promotion_tmp"; fi
	if [[ -n "$pilot_tmp" ]]; then rm -f -- "$pilot_tmp"; fi
	if [[ -n "$run_receipt_tmp" ]]; then rm -f -- "$run_receipt_tmp"; fi
	case "$scratch" in
		/tmp/grudgelands-wp40-r6.*) rm -rf -- "$scratch" ;;
	esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

static_gates() {
	local receipt="$1" receipt_tmp="${1}.partial"
	local file relative digest common_require_count common_execute_count
	local activation_match_count=0 writer_match_count=0
	local require_pattern="\\brequire[[:space:]]*[(\"']|pcall[[:space:]]*[(][[:space:]]*require\\b"
	local -a production_lua tool_lua all_lua tool_without_common receipt_files
	mapfile -t production_lua < <(rg --files \
		"$repo/mods/MAPGEN/grug_mapgen/wp40" | rg '/r6[^/]*[.]lua$' | sort)
	mapfile -t tool_lua < <(rg --files "$script_dir" | rg '[.]lua$' | sort)
	[[ "${#production_lua[@]}" -eq 6 && "${#tool_lua[@]}" -gt 0 ]] || {
		echo "WP40 R6 runner: R6 Lua file population differs" >&2
		return 1
	}
	all_lua=("${production_lua[@]}" "${tool_lua[@]}")
	"$luac_bin" -p "${all_lua[@]}"
	for file in "${all_lua[@]}"; do
		if "$luac_bin" -l -p -o /dev/null "$file" | rg -n 'SETGLOBAL'; then
			echo "WP40 R6 runner: unexpected global write in $file" >&2
			return 1
		fi
	done
	if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${all_lua[@]}" ||
			rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${all_lua[@]}" ||
			rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${all_lua[@]}" ||
			rg -n ':(match|gmatch|gsub)[(][^)]*\\0|string[.](match|gmatch|gsub)[(][^)]*\\0' "${all_lua[@]}" ||
			rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${all_lua[@]}"; then
		echo "WP40 R6 runner: Lua 5.1 source sweep failed" >&2
		return 1
	fi
	if rg -n "$require_pattern|io\.popen|os\.(execute|exit)|\\bminetest\." \
			"${production_lua[@]}"; then
		echo "WP40 R6 runner: production sandbox sweep failed" >&2
		return 1
	fi
	for file in "${tool_lua[@]}"; do
		[[ "$file" == "$script_dir/common.lua" ]] || tool_without_common+=("$file")
	done
	if rg -n "$require_pattern|io\.popen|os\.(execute|exit)|\\bminetest\." \
			"${tool_without_common[@]}"; then
		echo "WP40 R6 runner: tool sandbox sweep escaped the offline common seam" >&2
		return 1
	fi
	if rg -n 'io\.popen|os\.exit|\bminetest\.' "$script_dir/common.lua"; then
		echo "WP40 R6 runner: offline common contains an unapproved sandbox call" >&2
		return 1
	fi
	common_require_count="$( (rg -o "$require_pattern" "$script_dir/common.lua" || true) |
		awk 'END { print NR + 0 }' )"
	common_execute_count="$(rg -c 'os\.execute' "$script_dir/common.lua" || true)"
	[[ "$common_require_count" -eq 2 && "$common_execute_count" -eq 1 ]] || {
		echo "WP40 R6 runner: offline common command/FFI seam differs" >&2
		return 1
	}
	activation_match_count="$( (rg -n \
		'register_on_generated|register_mapgen_script|register_decoration|register_ore' \
		"${production_lua[@]}" || true) | awk 'END { print NR + 0 }' )"
	if [[ "$activation_match_count" -ne 0 ]]; then
		rg -n 'register_on_generated|register_mapgen_script|register_decoration|register_ore' \
			"${production_lua[@]}" || true
		echo "WP40 R6 runner: disabled production source contains activation registration" >&2
		return 1
	fi
	writer_match_count="$( (rg -n \
		'place_schematic|write_to_map|set_mapgen_setting|set_mapgen_params' \
		"${production_lua[@]}" || true) | awk 'END { print NR + 0 }' )"
	if [[ "$writer_match_count" -ne 0 ]]; then
		rg -n 'place_schematic|write_to_map|set_mapgen_setting|set_mapgen_params' \
			"${production_lua[@]}" || true
		echo "WP40 R6 runner: disabled production source contains a map writer" >&2
		return 1
	fi
	bash -n "$script_dir/run.sh"
	mapfile -t receipt_files < <("$lua_bin" "$cli" static-file-list "$repo")
	[[ "${#receipt_files[@]}" -gt "${#all_lua[@]}" ]] || {
		echo "WP40 R6 runner: static receipt input population differs" >&2
		return 1
	}
	local -A receipt_set=()
	for relative in "${receipt_files[@]}"; do
		[[ -n "$relative" && "$relative" != /* && -f "$repo/$relative" &&
			-z "${receipt_set[$relative]:-}" ]] || {
			echo "WP40 R6 runner: invalid static receipt input $relative" >&2
			return 1
		}
		receipt_set[$relative]=1
	done
	for file in "${all_lua[@]}" "$script_dir/run.sh" \
			"$repo/tools/wp40/run_simple_map_r6.sh"; do
		relative="${file#"$repo/"}"
		[[ -n "${receipt_set[$relative]:-}" ]] || {
			echo "WP40 R6 runner: static receipt omits $relative" >&2
			return 1
		}
	done
	{
		printf 'schema\tgrug_wp40_r6_static_gate_receipt_v1\n'
		printf 'gate\tluac51_parse\ttrue\n'
		printf 'gate\tsetglobal\ttrue\n'
		printf 'gate\tlua51_source_sweeps\ttrue\n'
		printf 'gate\tsandbox_boundary\ttrue\n'
		printf 'gate\tdisabled_writer\ttrue\n'
		printf 'gate\tbash_syntax\ttrue\n'
		printf 'metric\tactivation_api_matches\t%s\n' "$activation_match_count"
		printf 'metric\tmap_writer_matches\t%s\n' "$writer_match_count"
		for relative in "${receipt_files[@]}"; do
			file="$repo/$relative"
			digest="$(sha256sum "$file" | awk '{print $1}')"
			printf 'file\t%s\t%s\n' "$relative" "$digest"
		done
	} >"$receipt_tmp"
	mv -- "$receipt_tmp" "$receipt"
}

assignment_sha() {
	local value="${WP40_R6_ASSIGNMENT_SHA256:-814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f}"
	[[ "$value" =~ ^[0-9a-f]{64}$ ]] || {
		echo "WP40 R6 runner: WP40_R6_ASSIGNMENT_SHA256 is required" >&2
		return 1
	}
	printf '%s\n' "$value"
}

start_session() {
	local engine="$1" worker_id="$2" worker_scratch="$3" log="$4" resource="$5"
	shift 5
	local interpreter="$lua_bin"
	local -a prefix=(-e '_G.wp40_ffi=require("ffi")')
	[[ "${#active_pids[@]}" -lt 7 ]] || {
		echo "WP40 R6 runner: seven-process cap would be exceeded" >&2
		return 1
	}
	local process_snapshot visible_lua pending_active=0 tracked_pid tracked_has_lua
	local new_pid
	process_snapshot="$(ps -eo pgid=,comm=)"
	visible_lua="$(awk '$2 == "luajit" || $2 == "lua51" { count++ }
		END { print count + 0 }' <<<"$process_snapshot")"
	for tracked_pid in "${active_pids[@]}"; do
		tracked_has_lua="$(awk -v pgid="$tracked_pid" '$1 == pgid &&
				($2 == "luajit" || $2 == "lua51") { found = 1 }
				END { print found + 0 }' <<<"$process_snapshot")"
		if [[ "$tracked_has_lua" -eq 0 ]] && ps -p "$tracked_pid" >/dev/null 2>&1; then
			pending_active=$((pending_active + 1))
		fi
	done
	[[ $((visible_lua + pending_active)) -lt 7 ]] || {
		echo "WP40 R6 runner: workstation-wide seven-process cap is exhausted" >&2
		return 1
	}
	if [[ "$engine" == puc51 ]]; then interpreter="$puc_bin"; prefix=(); fi
	mkdir -p -- "$worker_scratch"
	# With job control disabled, setsid does not fork: $! remains this pgid leader.
	setsid env LC_ALL=C "$time_bin" -q \
		-f "r6_resource_v1\t$engine\t$worker_id\t%e\t%U\t%S\t%M" \
		-o "$resource" chrt --idle 0 ionice -c3 "$interpreter" \
		"${prefix[@]}" "$cli" "$@" >"$log" 2>&1 &
	new_pid=$!
	active_pids+=("$new_pid")
}

wait_sessions() {
	local failed=0 pid log index
	local -a wait_pids=("${active_pids[@]}")
	for index in "${!wait_pids[@]}"; do
		pid="${wait_pids[$index]}"
		wait "$pid" || failed=1
	done
	active_pids=()
	for log in "$@"; do [[ -f "$log" ]] && cat "$log"; done
	[[ "$failed" -eq 0 ]]
}

static_gates "$scratch/static-gates.tsv"

if [[ "$mode" == validate ]]; then
	[[ "$#" -eq 1 || "$#" -eq 2 ]] || {
		echo "usage: bash tools/wp40/r6/run.sh validate ARTIFACT [FILE_SHA256]" >&2
		exit 2
	}
	args=(validate "$repo" "$1")
	[[ "$#" -eq 1 ]] || args+=("$2")
	start_session luajit 0 "$scratch/validate" "$scratch/validate.log" \
		"$scratch/validate.resource" "${args[@]}"
	wait_sessions "$scratch/validate.log"
	exit 0
fi

assignment="$(assignment_sha)"

if [[ "$mode" == pilot ]]; then
	[[ "$#" -eq 1 && "$1" == /tmp/* ]] || {
		echo "usage: bash tools/wp40/r6/run.sh pilot /tmp/PILOT-PROJECTION.tsv" >&2
		exit 2
	}
	pilot_dir="$(cd "$(dirname "$1")" && pwd -P)"
	[[ "$pilot_dir" == /tmp || "$pilot_dir" == /tmp/* ]] || {
		echo "WP40 R6 runner: resolved pilot output directory is outside /tmp" >&2
		exit 1
	}
	pilot_output="$pilot_dir/$(basename "$1")"
	[[ ! -e "$pilot_output" ]] || {
		echo "WP40 R6 runner: pilot output already exists" >&2
		exit 1
	}
	pilot_tmp="$(mktemp "${pilot_output}.partial.XXXXXXXX")"
	start_session luajit 0 "$scratch/roster-verify" "$scratch/roster-verify.log" \
		"$scratch/roster-verify.resource" roster-verify "$repo" \
		"$scratch/roster-verify.tsv"
	wait_sessions "$scratch/roster-verify.log"
	declare -a shard_paths shard_logs shard_digests
	for residue in 0 1 2 3 4 5 6; do
		worker_id=$((residue + 1))
		worker_scratch="$scratch/pilot-$worker_id"
		shard_paths[$worker_id]="$scratch/pilot-$worker_id.bytes"
		shard_logs[$worker_id]="$scratch/pilot-$worker_id.log"
		start_session luajit "$worker_id" "$worker_scratch" \
			"${shard_logs[$worker_id]}" "$scratch/pilot-$worker_id.resource" \
			pilot-shard "$repo" "$worker_scratch" "${shard_paths[$worker_id]}" \
			"$worker_id" 7 "$residue" "$assignment"
	done
	wait_sessions "${shard_logs[@]}"

	reference_path="$scratch/pilot-reference.bytes"
	start_session luajit 1 "$scratch/pilot-reference" "$scratch/pilot-reference.log" \
		"$scratch/pilot-reference.resource" pilot-reference "$repo" \
		"$scratch/pilot-reference" "$reference_path" "$assignment"
	wait_sessions "$scratch/pilot-reference.log"
	du -sb -- "$scratch" | awk '{print $1}' >"$scratch/pilot-scratch-bytes.txt"
	reference_digest="$(sha256sum "$reference_path" | awk '{print $1}')"
	combine_args=(pilot-combine "$repo" "$scratch" "$pilot_tmp" "$assignment" \
		"$reference_digest" "$reference_path")
	for worker_id in 1 2 3 4 5 6 7; do
		shard_digests[$worker_id]="$(sha256sum "${shard_paths[$worker_id]}" | awk '{print $1}')"
		combine_args+=("${shard_digests[$worker_id]}" "${shard_paths[$worker_id]}")
	done
	start_session luajit 0 "$scratch/pilot-combine" "$scratch/pilot-combine.log" \
		"$scratch/pilot-combine.resource" "${combine_args[@]}"
	wait_sessions "$scratch/pilot-combine.log"
	mv -- "$pilot_tmp" "$pilot_output"
	pilot_tmp=""
	printf 'r6_pilot_projection_file_sha256\t%s\n' \
		"$(sha256sum "$pilot_output" | awk '{print $1}')"
	cat "$pilot_output"
	echo "WP40 R6 runner: unconditional pilot stop; do not start the fleet in this invocation" >&2
	exit 0
fi

[[ "$mode" == fleet && "$#" -eq 3 ]] || {
	echo "usage: WP40_R6_APPROVED_PROJECTION_SHA256=... bash tools/wp40/r6/run.sh fleet CANONICAL-ARTIFACT.tsv PILOT-PROJECTION.tsv APPROVED-SHA256" >&2
	exit 2
}
output="$1"
projection_path="$2"
projection_argument_sha="$3"
approved_sha="${WP40_R6_APPROVED_PROJECTION_SHA256:-}"
[[ "$output" == "$repo/docs/research/wp40-simple-map-r6-artifact.tsv" ]] || {
	echo "WP40 R6 runner: fleet promotes only the canonical R6 artifact" >&2
	exit 1
}
[[ "$projection_argument_sha" =~ ^[0-9a-f]{64}$ &&
	"$approved_sha" == "$projection_argument_sha" ]] || {
	echo "WP40 R6 runner: explicit approved projection digest is absent or differs" >&2
	exit 1
}
actual_projection_sha="$(sha256sum "$projection_path" | awk '{print $1}')"
[[ "$actual_projection_sha" == "$approved_sha" ]] || {
	echo "WP40 R6 runner: approved projection file digest differs" >&2
	exit 1
}
projection_assignment="$(awk -F '\t' '$1 == "assignment_sha256" {print $2}' \
	"$projection_path")"
projection_static="$(awk -F '\t' '$1 == "static_gate_receipt_sha256" {print $2}' \
	"$projection_path")"
current_static="$(sha256sum "$scratch/static-gates.tsv" | awk '{print $1}')"
[[ "$projection_assignment" == "$assignment" && "$projection_static" == "$current_static" ]] || {
	echo "WP40 R6 runner: assignment or static source receipt changed after pilot" >&2
	exit 1
}
[[ -x "$puc_bin" ]] || {
	echo "WP40 R6 runner: final fleet requires tools/bin/lua51 for the micro-KAT" >&2
	exit 1
}
output_dir="$(cd "$(dirname "$output")" && pwd -P)"
promotion_tmp="$(mktemp "$output_dir/.wp40-r6-artifact.XXXXXXXX")"
rm -f -- "$promotion_tmp"
run_receipt="$repo/docs/research/wp40-simple-map-r6-run-receipt.tsv"
run_receipt_tmp="$(mktemp "$output_dir/.wp40-r6-run-receipt.XXXXXXXX")"
rm -f -- "$run_receipt_tmp"

declare -a first_slots=(1 6 11 16 21 26 31)
declare -a last_slots=(5 10 15 20 25 30 32)
declare -a worker_paths worker_logs worker_digests
for index in 0 1 2 3 4 5 6; do
	worker_id=$((index + 1))
	worker_scratch="$scratch/fleet-$worker_id"
	worker_paths[$worker_id]="$scratch/fleet-$worker_id.tsv"
	worker_logs[$worker_id]="$scratch/fleet-$worker_id.log"
	start_session luajit "$worker_id" "$worker_scratch" \
		"${worker_logs[$worker_id]}" "$scratch/fleet-$worker_id.resource" \
		fleet-worker "$repo" "$worker_scratch" "${worker_paths[$worker_id]}" \
		"$worker_id" "${first_slots[$index]}" "${last_slots[$index]}" \
		"$assignment" "$approved_sha" "$projection_path"
done
wait_sessions "${worker_logs[@]}"
for worker_id in 1 2 3 4 5 6 7; do
	worker_digests[$worker_id]="$(sha256sum "${worker_paths[$worker_id]}" | awk '{print $1}')"
done

production_kat="$scratch/production-kat.tsv"
start_session luajit 0 "$scratch/production-kat" "$scratch/production-kat.log" \
	"$scratch/production-kat.resource" production-kat "$repo" "$production_kat"
wait_sessions "$scratch/production-kat.log"
production_kat_sha="$(sha256sum "$production_kat" | awk '{print $1}')"

micro_lj="$scratch/micro-luajit.tsv"
micro_puc="$scratch/micro-puc51.tsv"
start_session luajit 0 "$scratch/micro-luajit" "$scratch/micro-luajit.log" \
	"$scratch/micro-luajit.resource" micro "$repo" "$scratch/micro-luajit" \
	"$micro_lj" luajit final_bytes "$assignment"
start_session puc51 0 "$scratch/micro-puc51" "$scratch/micro-puc51.log" \
	"$scratch/micro-puc51.resource" micro "$repo" "$scratch/micro-puc51" \
	"$micro_puc" puc51 final_bytes "$assignment"
wait_sessions "$scratch/micro-luajit.log" "$scratch/micro-puc51.log"
cmp -s "$micro_lj" "$micro_puc" || {
	echo "WP40 R6 runner: LuaJIT/PUC micro-KAT bytes differ" >&2
	exit 1
}
micro_lj_sha="$(sha256sum "$micro_lj" | awk '{print $1}')"
micro_puc_sha="$(sha256sum "$micro_puc" | awk '{print $1}')"

global_path="$scratch/global.tsv"
global_args=(finalize-global "$repo" "$scratch" "$global_path" \
	"$assignment" "$approved_sha" "$projection_path")
for worker_id in 1 2 3 4 5 6 7; do
	global_args+=("${worker_digests[$worker_id]}" "${worker_paths[$worker_id]}")
done
global_args+=("$micro_lj_sha" "$micro_lj" "$micro_puc_sha" "$micro_puc")
global_args+=("$production_kat_sha" "$production_kat")
start_session luajit 0 "$scratch/global" "$scratch/global.log" \
	"$scratch/global.resource" "${global_args[@]}"
wait_sessions "$scratch/global.log"
global_digest="$(sha256sum "$global_path" | awk '{print $1}')"

combine_args=(combine-fleet "$repo" "$promotion_tmp" 8)
for worker_id in 1 2 3 4 5 6 7; do
	combine_args+=("${worker_digests[$worker_id]}" "${worker_paths[$worker_id]}")
done
combine_args+=("$global_digest" "$global_path")
start_session luajit 0 "$scratch/combine" "$scratch/combine.log" \
	"$scratch/combine.resource" "${combine_args[@]}"
wait_sessions "$scratch/combine.log"
artifact_sha="$(sha256sum "$promotion_tmp" | awk '{print $1}')"
start_session luajit 0 "$scratch/final-validate" "$scratch/final-validate.log" \
	"$scratch/final-validate.resource" validate "$repo" "$promotion_tmp" "$artifact_sha"
wait_sessions "$scratch/final-validate.log"
{
	printf 'schema\tgrug_wp40_r6_run_receipt_v1\n'
	printf 'assignment_sha256\t%s\n' "$assignment"
	printf 'approved_projection_sha256\t%s\n' "$approved_sha"
	awk '{print "pilot_projection\t" $0}' "$projection_path"
	printf 'artifact_file_sha256\t%s\n' "$artifact_sha"
	printf 'static_gate_receipt_sha256\t%s\n' "$current_static"
	printf 'global_fragment_sha256\t%s\n' "$global_digest"
	for worker_id in 1 2 3 4 5 6 7; do
		printf 'worker\t%s\t%s\t%s\t%s\n' "$worker_id" \
			"${first_slots[$((worker_id - 1))]}" \
			"${last_slots[$((worker_id - 1))]}" "${worker_digests[$worker_id]}"
		awk -v label="worker_$worker_id" '{print "resource\t" label "\t" $0}' \
			"$scratch/fleet-$worker_id.resource"
	done
	printf 'production_kat_sha256\t%s\n' "$production_kat_sha"
	awk '{print "production_kat\t" $0}' "$production_kat"
	printf 'micro_luajit_sha256\t%s\n' "$micro_lj_sha"
	printf 'micro_puc51_sha256\t%s\n' "$micro_puc_sha"
	awk '{print "micro_kat\t" $0}' "$micro_lj"
	awk '{print "static_gate\t" $0}' "$scratch/static-gates.tsv"
	for log in "$scratch/global.log" "$scratch/combine.log" \
			"$scratch/final-validate.log"; do
		label="$(basename "$log" .log)"
		printf 'log_sha256\t%s\t%s\n' "$label" "$(sha256sum "$log" | awk '{print $1}')"
		awk -v value="$label" '{print "log\t" value "\t" $0}' "$log"
	done
} >"$run_receipt_tmp"
run_receipt_sha="$(sha256sum "$run_receipt_tmp" | awk '{print $1}')"
mv -- "$run_receipt_tmp" "$run_receipt"
run_receipt_tmp=""
mv -- "$promotion_tmp" "$output"
promotion_tmp=""
printf 'r6_final_artifact_sha256\t%s\n' "$artifact_sha"
printf 'r6_run_receipt_sha256\t%s\n' "$run_receipt_sha"
