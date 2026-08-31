#!/usr/bin/env bash
set -euo pipefail
set +m

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$script_dir/../../.." && pwd -P)"
mode="${1:-}"
shift || true
lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
luac_bin="${WP40_LUAC51_BIN:-$repo/tools/bin/luac51}"
time_bin=/usr/bin/time
cli="$script_dir/adapter_cli.lua"

case "$mode" in
	unit|static|integration|pilot|fleet) ;;
	*)
		echo "usage: bash tools/wp40/r7/run.sh unit|static|integration|pilot|fleet ..." >&2
		exit 2
		;;
esac

for command_name in rg sha256sum chrt ionice setsid mktemp awk cmp mv rm ps \
	kill sort bash mkdir dirname basename du chmod env cp; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "WP40 R7 runner: missing command $command_name" >&2
		exit 1
	}
done
[[ -x "$lua_bin" && -x "$luac_bin" && -x "$time_bin" ]] || {
	echo "WP40 R7 runner: LuaJIT, luac51 and /usr/bin/time are required" >&2
	exit 1
}

scratch="$(mktemp -d /tmp/grudgelands-wp40-r7.XXXXXXXX)"
active_pids=()
keep_scratch=false

cleanup() {
	local status=$? pid
	for pid in "${active_pids[@]}"; do
		if [[ "$pid" =~ ^[0-9]+$ ]] && ps -p "$pid" >/dev/null 2>&1; then
			kill -TERM -- "-$pid" 2>/dev/null || true
			kill -KILL -- "-$pid" 2>/dev/null || true
		fi
	done
	if [[ "$status" -eq 0 && "$keep_scratch" == false ]]; then
		case "$scratch" in
			/tmp/grudgelands-wp40-r7.*) rm -rf -- "$scratch" ;;
		esac
	else
		printf 'WP40 R7 runner: retained scratch at %s\n' "$scratch" >&2
	fi
	return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

lua_prefix=(-e '_G.wp40_ffi=require("ffi")')

run_unit() {
	"$luac_bin" -p "$script_dir/contract.lua" \
		"$script_dir/contract_kat.lua" "$script_dir/integration_adapter.lua" \
		"$script_dir/adapter_cli.lua" "$script_dir/native_inputs_kat.lua"
	"$lua_bin" "${lua_prefix[@]}" "$script_dir/contract_kat.lua" "$repo"
	"$lua_bin" "${lua_prefix[@]}" "$script_dir/native_inputs_kat.lua" "$repo"
}

static_gates() {
	local receipt="$1"
	local -a tool_lua production_lua all_lua
	mapfile -t tool_lua < <(rg --files "$script_dir" | rg '[.]lua$' | sort)
	mapfile -t production_lua < <(rg --files \
		"$repo/mods/MAPGEN/grug_mapgen/wp40" "$repo/mods/ITEMS/grug_gathering" \
		"$repo/mods/CORE/grug_core" "$repo/mods/PLAYER/grug_factions" \
		"$repo/mods/ENTITIES/grug_mobs" | rg '[.]lua$' | sort)
	[[ "${#tool_lua[@]}" -gt 0 && "${#production_lua[@]}" -gt 0 ]] || {
		echo "WP40 R7 runner: static Lua population is incomplete" >&2
		return 1
	}
	all_lua=("${tool_lua[@]}" "${production_lua[@]}")
	"$luac_bin" -p "${all_lua[@]}"
	for file in "${tool_lua[@]}"; do
		if "$luac_bin" -l -p -o /dev/null "$file" | rg -n 'SETGLOBAL'; then
			echo "WP40 R7 runner: tool global write in $file" >&2
			return 1
		fi
	done
	local -a pure_lua
	mapfile -t pure_lua < <(rg --files "$repo/mods/MAPGEN/grug_mapgen/wp40" \
		"$repo/mods/ITEMS/grug_gathering" | rg '/(r6[^/]*|r7[^/]*|catalog|harvest|nodes)[.]lua$' | sort)
	for file in "${pure_lua[@]}"; do
		if "$luac_bin" -l -p -o /dev/null "$file" | rg -n 'SETGLOBAL'; then
			echo "WP40 R7 runner: pure production module writes a global: $file" >&2
			return 1
		fi
	done
	local gathering_global_count
	gathering_global_count="$("$luac_bin" -l -p -o /dev/null \
		"$repo/mods/ITEMS/grug_gathering/init.lua" | rg -n 'SETGLOBAL' | awk 'END {print NR + 0}')"
	[[ "$gathering_global_count" -eq 1 ]] || {
		echo "WP40 R7 runner: grug_gathering global-table declaration differs" >&2
		return 1
	}
	if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${all_lua[@]}" ||
			rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${all_lua[@]}" ||
			rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${all_lua[@]}" ||
			rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${all_lua[@]}" ||
			rg -n 'io\.popen|os\.(execute|exit)|\bminetest\.' "${all_lua[@]}" ||
			rg -n '(^|[^[:alnum:]_.])require[[:space:]]*\(' "${production_lua[@]}" ||
			rg -n '^[[:space:]]*(local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*)?require[[:space:]]*\(' "${tool_lua[@]}"; then
		echo "WP40 R7 runner: Lua 5.1 source sweep failed" >&2
		return 1
	fi
	bash -n "$script_dir/run.sh" "$script_dir/source_audit.sh"
	bash "$script_dir/source_audit.sh" "$repo" "$receipt"
}

run_catalog() {
	local output="$1" log="$2"
	"$lua_bin" "${lua_prefix[@]}" "$cli" catalog "$repo" "$output" \
		>"$log" 2>&1
}

run_native() {
	local log="$1"
	"$lua_bin" "${lua_prefix[@]}" "$script_dir/native_inputs_kat.lua" "$repo" \
		>"$log" 2>&1
	[[ "$(rg -n '^WP40 R7 native inputs KAT PASS ' "$log" | awk 'END {print NR + 0}')" -eq 1 ]] || {
		cat "$log"
		echo "WP40 R7 runner: native KAT aggregation differs" >&2
		return 1
	}
}

run_integration() {
	local output="$1" log="$2"
	"$lua_bin" "${lua_prefix[@]}" "$cli" integration-kat "$repo" "$output" \
		>"$log" 2>&1
}

start_worker() {
	local worker_id="$1" first_slot="$2" last_slot="$3" projection_sha="$4"
	local worker_scratch="$scratch/worker-$worker_id"
	local output="$scratch/worker-$worker_id.tsv"
	local log="$scratch/worker-$worker_id.log"
	local resource="$scratch/worker-$worker_id.resource.tsv"
	local process_snapshot visible_lua pending_active=0 tracked_pid tracked_has_lua
	process_snapshot="$(ps -eo pgid=,comm=)"
	visible_lua="$(awk '$2 == "luajit" || $2 == "lua51" {count++}
		END {print count + 0}' <<<"$process_snapshot")"
	for tracked_pid in "${active_pids[@]}"; do
		tracked_has_lua="$(awk -v pgid="$tracked_pid" '$1 == pgid &&
				($2 == "luajit" || $2 == "lua51") {found = 1}
			END {print found + 0}' <<<"$process_snapshot")"
		if [[ "$tracked_has_lua" -eq 0 ]] && ps -p "$tracked_pid" >/dev/null 2>&1; then
			pending_active=$((pending_active + 1))
		fi
	done
	[[ "${#active_pids[@]}" -lt 7 && $((visible_lua + pending_active)) -lt 7 ]] || {
		echo "WP40 R7 runner: workstation-wide seven-process cap is exhausted" >&2
		return 1
	}
	mkdir -p -- "$worker_scratch"
	setsid env LC_ALL=C "$time_bin" -q \
		-f "r7_worker_resource_v1\t$worker_id\t%e\t%U\t%S\t%M" \
		-o "$resource" chrt --idle 0 ionice -c3 "$lua_bin" \
		"${lua_prefix[@]}" "$cli" worker "$repo" "$output" "$worker_scratch" \
		"$first_slot" "$last_slot" "$projection_sha" >"$log" 2>&1 &
	active_pids+=("$!")
}

wait_workers() {
	local failed=0 pid
	for pid in "${active_pids[@]}"; do wait "$pid" || failed=1; done
	active_pids=()
	if [[ "$failed" -ne 0 ]]; then
		for log in "$scratch"/worker-*.log; do [[ -f "$log" ]] && cat "$log"; done
		return 1
	fi
}

run_unit
if [[ "$mode" == unit ]]; then
	[[ "$#" -eq 0 ]] || { echo "usage: run.sh unit" >&2; exit 2; }
	exit 0
fi

static_receipt="$scratch/source-audit.tsv"
static_gates "$static_receipt"
if [[ "$mode" == static ]]; then
	[[ "$#" -eq 0 ]] || { echo "usage: run.sh static" >&2; exit 2; }
	cat "$static_receipt"
	exit 0
fi

catalog_receipt="$scratch/catalog.tsv"
catalog_log="$scratch/catalog.log"
native_log="$scratch/native.log"
integration_receipt="$scratch/integration.tsv"
integration_log="$scratch/integration.log"
run_catalog "$catalog_receipt" "$catalog_log"
run_native "$native_log"
run_integration "$integration_receipt" "$integration_log"
if [[ "$mode" == integration ]]; then
	[[ "$#" -eq 0 ]] || { echo "usage: run.sh integration" >&2; exit 2; }
	cat "$catalog_log" "$native_log" "$integration_log"
	cat "$catalog_receipt" "$integration_receipt"
	exit 0
fi

seed_corpus="$repo/docs/research/wp40-simple-map-r6-seed-corpus.tsv"
[[ -f "$seed_corpus" ]] || {
	echo "WP40 R7 runner: frozen 32-seed corpus is absent" >&2
	exit 1
}
seed_population="$(rg -n '^seed\t' "$seed_corpus" | awk 'END {print NR + 0}')"
[[ "$seed_population" -eq 32 ]] || {
	echo "WP40 R7 runner: frozen seed population differs" >&2
	exit 1
}

if [[ "$mode" == pilot ]]; then
	[[ "$#" -eq 1 && "$1" == /tmp/* ]] || {
		echo "usage: bash tools/wp40/r7/run.sh pilot /tmp/R7-PILOT-PROJECTION.tsv" >&2
		exit 2
	}
	resolved_dir="$(cd "$(dirname "$1")" && pwd -P)"
	[[ "$resolved_dir" == /tmp || "$resolved_dir" == /tmp/* ]] || {
		echo "WP40 R7 runner: pilot projection must resolve below /tmp" >&2
		exit 1
	}
	pilot_output="$resolved_dir/$(basename "$1")"
	[[ ! -e "$pilot_output" ]] || {
		echo "WP40 R7 runner: pilot output already exists" >&2
		exit 1
	}
	pilot_result="$scratch/pilot-result.tsv"
	pilot_log="$scratch/pilot.log"
	pilot_resource="$scratch/pilot.resource.tsv"
	setsid env LC_ALL=C "$time_bin" -q \
		-f 'r7_pilot_resource_v1\t%e\t%U\t%S\t%M' -o "$pilot_resource" \
		chrt --idle 0 ionice -c3 "$lua_bin" "${lua_prefix[@]}" "$cli" pilot \
		"$repo" "$pilot_result" "$scratch/pilot" 17 >"$pilot_log" 2>&1
	static_sha="$(sha256sum "$static_receipt" | awk '{print $1}')"
	catalog_sha="$(sha256sum "$catalog_receipt" | awk '{print $1}')"
	native_sha="$(sha256sum "$native_log" | awk '{print $1}')"
	integration_sha="$(sha256sum "$integration_receipt" | awk '{print $1}')"
	roster_sha="$(sha256sum "$seed_corpus" | awk '{print $1}')"
	pilot_result_sha="$(sha256sum "$pilot_result" | awk '{print $1}')"
	read -r resource_schema elapsed user_time system_time peak_rss < <(
		awk -F '\t' 'NR == 1 {print $1, $2, $3, $4, $5}' "$pilot_resource")
	[[ "$resource_schema" == r7_pilot_resource_v1 ]] || {
		echo "WP40 R7 runner: pilot resource receipt differs" >&2
		exit 1
	}
	scratch_bytes="$(du -sb -- "$scratch" | awk '{print $1}')"
	output_bytes="$(du -b -- "$pilot_result" | awk '{print $1}')"
	projected_wall="$(awk -v elapsed="$elapsed" 'BEGIN {printf "%.6f", elapsed * 5}')"
	projected_rss="$(awk -v rss="$peak_rss" 'BEGIN {printf "%.0f", rss * 7}')"
	projected_output="$((output_bytes * 32))"
	projected_scratch="$((scratch_bytes * 32))"
	binding_file="$scratch/pilot-binding.tsv"
	{
		printf 'source_audit_sha256\t%s\n' "$static_sha"
		printf 'catalog_receipt_sha256\t%s\n' "$catalog_sha"
		printf 'native_kat_sha256\t%s\n' "$native_sha"
		printf 'integration_kat_sha256\t%s\n' "$integration_sha"
		printf 'seed_roster_sha256\t%s\n' "$roster_sha"
		printf 'pilot_result_sha256\t%s\n' "$pilot_result_sha"
		awk '{print "pilot_result\t" $0}' "$pilot_result"
	} >"$binding_file"
	assignment_sha="$(sha256sum "$binding_file" | awk '{print $1}')"
	pilot_partial="$(mktemp "${pilot_output}.partial.XXXXXXXX")"
	{
		printf 'schema\tgrug_wp40_r7_pilot_projection_v1\n'
		printf 'assignment_sha256\t%s\n' "$assignment_sha"
		cat "$binding_file"
		printf 'representative_seed_slot\t17\n'
		printf 'measured_elapsed_seconds\t%s\n' "$elapsed"
		printf 'measured_user_seconds\t%s\n' "$user_time"
		printf 'measured_system_seconds\t%s\n' "$system_time"
		printf 'measured_peak_rss_kib\t%s\n' "$peak_rss"
		printf 'measured_output_bytes\t%s\n' "$output_bytes"
		printf 'measured_scratch_bytes\t%s\n' "$scratch_bytes"
		printf 'fleet_width\t7\n'
		printf 'fleet_seed_population\t32\n'
		printf 'projected_fleet_wall_seconds\t%s\n' "$projected_wall"
		printf 'projected_fleet_peak_rss_kib\t%s\n' "$projected_rss"
		printf 'projected_fleet_output_bytes\t%s\n' "$projected_output"
		printf 'projected_fleet_scratch_bytes\t%s\n' "$projected_scratch"
		printf 'stop_boundary\tunconditional_before_fleet\n'
	} >"$pilot_partial"
	mv -- "$pilot_partial" "$pilot_output"
	projection_sha="$(sha256sum "$pilot_output" | awk '{print $1}')"
	printf 'r7_pilot_projection_file_sha256\t%s\n' "$projection_sha"
	cat "$pilot_output"
	echo "WP40 R7 runner: unconditional pilot stop; fleet requires a new invocation and approval of this exact SHA-256" >&2
	exit 0
fi

[[ "$mode" == fleet && "$#" -eq 2 ]] || {
	echo "usage: WP40_R7_APPROVED_PROJECTION_SHA256=... bash tools/wp40/r7/run.sh fleet PILOT.tsv APPROVED-SHA256" >&2
	exit 2
}
projection="$1"
approved_argument="$2"
approved_environment="${WP40_R7_APPROVED_PROJECTION_SHA256:-}"
[[ "$approved_argument" =~ ^[0-9a-f]{64}$ &&
	"$approved_environment" == "$approved_argument" ]] || {
	echo "WP40 R7 runner: explicit approved projection SHA-256 is absent or differs" >&2
	exit 1
}
actual_projection="$(sha256sum "$projection" | awk '{print $1}')"
[[ "$actual_projection" == "$approved_argument" ]] || {
	echo "WP40 R7 runner: approved projection file bytes differ" >&2
	exit 1
}
[[ "$(awk -F '\t' '$1 == "schema" {print $2}' "$projection")" == \
	grug_wp40_r7_pilot_projection_v1 &&
	"$(awk -F '\t' '$1 == "fleet_width" {print $2}' "$projection")" == 7 &&
	"$(awk -F '\t' '$1 == "fleet_seed_population" {print $2}' "$projection")" == 32 &&
	"$(awk -F '\t' '$1 == "stop_boundary" {print $2}' "$projection")" == \
	unconditional_before_fleet ]] || {
	echo "WP40 R7 runner: projection schema/schedule differs" >&2
	exit 1
}
[[ "$(awk -F '\t' '$1 == "source_audit_sha256" {print $2}' "$projection")" == \
	"$(sha256sum "$static_receipt" | awk '{print $1}')" &&
	"$(awk -F '\t' '$1 == "catalog_receipt_sha256" {print $2}' "$projection")" == \
	"$(sha256sum "$catalog_receipt" | awk '{print $1}')" &&
	"$(awk -F '\t' '$1 == "native_kat_sha256" {print $2}' "$projection")" == \
	"$(sha256sum "$native_log" | awk '{print $1}')" &&
	"$(awk -F '\t' '$1 == "integration_kat_sha256" {print $2}' "$projection")" == \
	"$(sha256sum "$integration_receipt" | awk '{print $1}')" ]] || {
	echo "WP40 R7 runner: source/evidence bytes changed after the approved pilot" >&2
	exit 1
}

# Frozen, private copies prevent a worker from observing another worker's
# mutable output. Repository inputs are rebound by the post-fleet source audit.
for worker_id in 1 2 3 4 5 6 7; do
	mkdir -p -- "$scratch/worker-$worker_id/input"
	cp -- "$projection" "$scratch/worker-$worker_id/input/projection.tsv"
	chmod 0444 "$scratch/worker-$worker_id/input/projection.tsv"
done
first_slots=(1 6 11 16 21 26 31)
last_slots=(5 10 15 20 25 30 32)
for index in 0 1 2 3 4 5 6; do
	start_worker "$((index + 1))" "${first_slots[$index]}" "${last_slots[$index]}" \
		"$approved_argument"
done
wait_workers
for worker_id in 1 2 3 4 5 6 7; do
	[[ "$(sha256sum "$scratch/worker-$worker_id/input/projection.tsv" | awk '{print $1}')" == \
		"$approved_argument" ]] || {
		echo "WP40 R7 runner: immutable worker input changed" >&2
		exit 1
	}
done

post_static="$scratch/source-audit-post.tsv"
static_gates "$post_static"
cmp -s "$static_receipt" "$post_static" || {
	echo "WP40 R7 runner: repository inputs changed during the fleet" >&2
	exit 1
}

artifact_tmp="$scratch/wp40-r7-artifact.tsv"
stage_a_tmp="$scratch/wp40-r7-stage-a.tsv"
stage_b_tmp="$scratch/wp40-r7-stage-b.tsv"
p9g_tmp="$scratch/wp40-r7-p9g-ledger.tsv"
receipt_tmp="$scratch/wp40-r7-run-receipt.tsv"
finalizer_log="$scratch/finalizer.log"
worker_paths=()
for worker_id in 1 2 3 4 5 6 7; do
	worker_paths+=("$scratch/worker-$worker_id.tsv")
done
"$lua_bin" "${lua_prefix[@]}" "$cli" finalize "$repo" \
	"$scratch/finalizer-unused" "$scratch/finalizer" "$artifact_tmp" \
	"$stage_a_tmp" "$stage_b_tmp" "$p9g_tmp" \
	"$receipt_tmp" "${worker_paths[@]}" >"$finalizer_log" 2>&1

docs="$repo/docs/research"
artifact="$docs/wp40-r7-artifact.tsv"
stage_a="$docs/wp40-r7-stage-a-receipt.tsv"
stage_b="$docs/wp40-r7-stage-b-receipt.tsv"
p9g="$docs/wp40-r7-p9g-ledger.tsv"
run_receipt="$docs/wp40-r7-run-receipt.tsv"
durable_projection="$docs/wp40-r7-pilot-projection.tsv"
run_log="$docs/wp40-r7-run.log"
promotion="$docs/wp40-r7-promotion-manifest.tsv"
for target in "$artifact" "$stage_a" "$stage_b" "$p9g" "$run_receipt" \
		"$durable_projection" "$run_log" "$promotion"; do
	[[ ! -e "$target" ]] || {
		echo "WP40 R7 runner: durable promotion target already exists: $target" >&2
		exit 1
	}
done
projection_tmp="$scratch/wp40-r7-pilot-projection.tsv"
cp -- "$projection" "$projection_tmp"
run_log_tmp="$scratch/wp40-r7-run.log"
{
	printf 'schema\tgrug_wp40_r7_run_log_v1\n'
	for log in "$catalog_log" "$native_log" "$integration_log" \
			"$scratch"/worker-*.log "$scratch"/worker-*.resource.tsv \
			"$finalizer_log"; do
		label="$(basename "$log")"
		printf 'file\t%s\t%s\n' "$label" "$(sha256sum "$log" | awk '{print $1}')"
		awk -v value="$label" '{print "line\t" value "\t" $0}' "$log"
	done
} >"$run_log_tmp"
mv -- "$artifact_tmp" "$artifact"
mv -- "$stage_a_tmp" "$stage_a"
mv -- "$stage_b_tmp" "$stage_b"
mv -- "$p9g_tmp" "$p9g"
mv -- "$receipt_tmp" "$run_receipt"
mv -- "$projection_tmp" "$durable_projection"
mv -- "$run_log_tmp" "$run_log"
promotion_partial="$scratch/wp40-r7-promotion-manifest.tsv"
{
	printf 'schema\tgrug_wp40_r7_promotion_manifest_v1\n'
	printf 'approved_projection_sha256\t%s\n' "$approved_argument"
	printf 'source_audit_sha256\t%s\n' "$(sha256sum "$static_receipt" | awk '{print $1}')"
	for target in "$artifact" "$stage_a" "$stage_b" "$p9g" "$run_receipt" \
			"$durable_projection" "$run_log"; do
		printf 'file\t%s\t%s\n' "${target#"$repo/"}" \
			"$(sha256sum "$target" | awk '{print $1}')"
	done
} >"$promotion_partial"
mv -- "$promotion_partial" "$promotion"
printf 'r7_promotion_manifest_sha256\t%s\n' \
	"$(sha256sum "$promotion" | awk '{print $1}')"
