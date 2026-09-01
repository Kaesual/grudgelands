#!/usr/bin/env bash
set -euo pipefail
set +m
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$script_dir/../../.." && pwd -P)"
mode="${1:-}"
shift || true
lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
luac_bin="${WP40_LUAC51_BIN:-$repo/tools/bin/luac51}"
time_bin=/usr/bin/time
cli="$script_dir/adapter_cli.lua"

case "$mode" in
unit|static|integration|freeze|pilot|fleet) ;;
	*)
		echo "usage: bash tools/wp40/r7/run.sh unit|static|integration|freeze|pilot|fleet ..." >&2
		exit 2
		;;
esac

for command_name in rg sha256sum chrt ionice setsid mktemp awk cmp mv rm ps \
	kill sort bash mkdir dirname basename du chmod env cp ln wc; do
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

validate_seed_corpus() {
	local corpus="$1"
	[[ -f "$corpus" ]] || {
		echo "WP40 R7 runner: frozen 32-seed corpus is absent" >&2
		return 1
	}
	awk -F '\t' '
		BEGIN {
			header = "slot\tclass\tlabel\tsha256\tfirst_eight_hex\tseed_decimal_text"
			failed = 0
		}
		NR == 1 {
			if ($0 != header || NF != 6) {
				print "WP40 R7 runner: frozen seed corpus header differs" > "/dev/stderr"
				failed = 1
			}
			next
		}
		{
			rows++
			if (NF != 6) {
				print "WP40 R7 runner: frozen seed corpus field count differs at line " NR > "/dev/stderr"
				failed = 1
			}
			expected = sprintf("%d", rows)
			if ("x" $1 != "x" expected) {
				print "WP40 R7 runner: frozen seed corpus slot differs at line " NR > "/dev/stderr"
				failed = 1
			}
		}
		END {
			if (NR != 33 || rows != 32) {
				print "WP40 R7 runner: frozen seed corpus population differs" > "/dev/stderr"
				failed = 1
			}
			exit failed
		}
	' "$corpus"
}

seed_corpus_validator_kat() {
	local source="$repo/docs/research/wp40-simple-map-r6-seed-corpus.tsv"
	local directory="$scratch/seed-corpus-validator-kat"
	local fixture
	mkdir -p -- "$directory"
	validate_seed_corpus "$source" >/dev/null || {
		echo "WP40 R7 runner: accepted seed corpus failed its validator KAT" >&2
		return 1
	}
	awk 'NR == 1 {sub(/^slot/, "Slot")} {print}' "$source" >"$directory/header.tsv"
	awk 'NR != 33 {print}' "$source" >"$directory/short.tsv"
	awk -F '\t' 'BEGIN {OFS="\t"} NR == 17 {$1="15"} {print}' \
		"$source" >"$directory/slot.tsv"
	awk 'NR == 2 {$0=$0 "\textra"} {print}' "$source" >"$directory/field.tsv"
	awk '{print} END {print "33\tliteral\tliteral\t-\t-\t33"}' \
		"$source" >"$directory/long.tsv"
	for fixture in header short slot field long; do
		if validate_seed_corpus "$directory/$fixture.tsv" >/dev/null 2>&1; then
			echo "WP40 R7 runner: seed corpus validator accepted $fixture fixture" >&2
			return 1
		fi
	done
	return 0
}

run_unit() {
	seed_corpus_validator_kat
	"$luac_bin" -p "$script_dir/contract.lua" \
		"$script_dir/contract_kat.lua" "$script_dir/integration_adapter.lua" \
		"$script_dir/runtime_adapter.lua" "$script_dir/adapter_cli.lua" \
		"$script_dir/native_inputs_kat.lua" "$script_dir/wp33_gathering_kat.lua" \
		"$script_dir/consumer_contract_kat.lua" "$script_dir/micro_kat.lua" \
		"$script_dir/micro_kat_fixture.lua"
	"$lua_bin" "${lua_prefix[@]}" "$script_dir/contract_kat.lua" "$repo"
	"$lua_bin" "${lua_prefix[@]}" "$script_dir/native_inputs_kat.lua" "$repo"
	"$lua_bin" "${lua_prefix[@]}" "$script_dir/wp33_gathering_kat.lua" "$repo"
	"$lua_bin" "${lua_prefix[@]}" "$script_dir/consumer_contract_kat.lua" "$repo"
}

static_gates() {
	local receipt="$1" phase="$2"
	[[ "$phase" == prefreeze || "$phase" == final ]] || return 2
	local -a tool_lua production_lua all_lua
	mapfile -t tool_lua < <(rg --files "$script_dir" | rg '[.]lua$' | sort)
	mapfile -t production_lua < <(rg --files "$repo/mods" | \
		rg '/grug_[^/]+/.*[.]lua$' | sort)
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
	# Keep the mandated textual operator sweep even though comments and TSV
	# string literals necessarily produce candidates in this codebase.  The
	# plain-5.1 parser above is the authoritative classifier: after it succeeds,
	# no candidate can be executable //, &, |, << or >> syntax.  Still fail on
	# an rg execution error so a missing/broken sweep cannot silently pass.
	local operator_sweep_status=0
	rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' \
		"${all_lua[@]}" >/dev/null || operator_sweep_status=$?
	[[ "$operator_sweep_status" -le 1 ]] || {
		echo "WP40 R7 runner: Lua 5.1 operator sweep could not run" >&2
		return 1
	}
	if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${all_lua[@]}" ||
			rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${all_lua[@]}" | \
				rg -v '^[^:]+:[0-9]+:[[:space:]]*--' ||
			rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${all_lua[@]}" ||
			rg -n 'io\.popen|os\.(execute|exit)|\bminetest\.' "${all_lua[@]}" ||
			rg -n '(^|[^[:alnum:]_.])require[[:space:]]*\(' "${production_lua[@]}" ||
			rg -n '^[[:space:]]*(local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*)?require[[:space:]]*\(' "${tool_lua[@]}"; then
		echo "WP40 R7 runner: Lua 5.1 source sweep failed" >&2
		return 1
	fi
	bash -n "$script_dir/run.sh" "$script_dir/source_audit.sh" \
		"$script_dir/final_micro.sh"
	bash "$script_dir/source_audit.sh" "$repo" "$receipt" "$phase"
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

run_sample_roster() {
	local output="$1" log="$2"
	"$lua_bin" "${lua_prefix[@]}" "$cli" sample-roster "$repo" "$output" \
		>"$log" 2>&1
	[[ "$(rg -n '^WP40 R7 sample roster PASS seeds=32 owners=4096$' "$log" | \
		awk 'END {print NR + 0}')" -eq 1 ]] || {
		cat "$log"
		echo "WP40 R7 runner: sample roster aggregation differs" >&2
		return 1
	}
	awk -F '\t' '
		NR == 1 {ok = ($0 == "schema\tgrug_wp40_r7_sample_assignment_v1"); next}
		NR == 2 {ok = ok && ($0 == "sample_schema\tgrug_wp40_r7_stratified_owner_sample_v1"); next}
		NR == 3 {ok = ok && ($0 == "seed_population\t32"); next}
		NR == 4 {ok = ok && ($0 == "owner_population_per_seed\t128"); next}
		NR == 5 {ok = ok && ($0 == "case_population\t4096"); next}
		NR >= 6 {
			rows++
			ok = ok && NF == 8 && $1 == "seed" && $2 == rows &&
				length($3) == 64 && $3 !~ /[^0-9a-f]/ && $4 == 128 &&
				$5 == 795281 && $6 == 104 && $7 == 24 && $8 == 0
		}
		END {exit !(ok && NR == 37 && rows == 32)}
	' "$output" || {
		echo "WP40 R7 runner: sample assignment receipt differs" >&2
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

docs="$repo/docs/research"
durable_integration="$docs/wp40-r7-integration-receipt.tsv"
durable_integration_log="$docs/wp40-r7-integration.log"
durable_integration_binding="$docs/wp40-r7-integration-binding.tsv"
durable_prefreeze="$docs/wp40-r7-source-audit-prefreeze.tsv"
durable_micro="$docs/wp40-r7-micro-kat-receipt.tsv"
durable_micro_output="$docs/wp40-r7-micro-kat-output.tsv"
durable_micro_lj_log="$docs/wp40-r7-micro-kat-luajit.log"
durable_micro_puc_log="$docs/wp40-r7-micro-kat-puc51.log"
durable_static="$docs/wp40-r7-source-audit-receipt.tsv"
static_receipt="$scratch/source-audit.tsv"
if [[ "$mode" == static ]]; then
	[[ "$#" -eq 0 ]] || { echo "usage: run.sh static" >&2; exit 2; }
	static_gates "$static_receipt" prefreeze
	cat "$static_receipt"
	exit 0
fi

catalog_receipt="$scratch/catalog.tsv"
catalog_log="$scratch/catalog.log"
native_log="$scratch/native.log"
sample_assignment="$scratch/sample-assignment.tsv"
sample_assignment_log="$scratch/sample-assignment.log"
integration_receipt="$scratch/integration.tsv"
integration_log="$scratch/integration.log"
if [[ "$mode" == integration ]]; then
	[[ "$#" -eq 0 ]] || { echo "usage: run.sh integration" >&2; exit 2; }
	[[ ! -e "$durable_integration" && ! -e "$durable_integration_log" &&
		! -e "$durable_integration_binding" && ! -e "$durable_prefreeze" ]] || {
		echo "WP40 R7 runner: durable integration evidence already exists" >&2
		exit 1
	}
	static_gates "$static_receipt" prefreeze
	run_catalog "$catalog_receipt" "$catalog_log"
	run_native "$native_log"
	run_integration "$integration_receipt" "$integration_log"
	integration_post_audit="$scratch/source-audit-integration-post.tsv"
	static_gates "$integration_post_audit" prefreeze
	cmp -s "$static_receipt" "$integration_post_audit" || {
		echo "WP40 R7 runner: code inputs changed during integration KAT" >&2
		exit 1
	}
	integration_partial="$(mktemp "$docs/.wp40-r7-integration-receipt.partial.XXXXXXXX")"
	integration_log_partial="$(mktemp "$docs/.wp40-r7-integration-log.partial.XXXXXXXX")"
	prefreeze_partial="$(mktemp "$docs/.wp40-r7-prefreeze.partial.XXXXXXXX")"
	binding_partial="$(mktemp "$docs/.wp40-r7-integration-binding.partial.XXXXXXXX")"
	cp -- "$integration_receipt" "$integration_partial"
	cp -- "$integration_log" "$integration_log_partial"
	cp -- "$static_receipt" "$prefreeze_partial"
	code_input_set_sha="$(awk -F '\t' '$1 == "code_input_set_sha256" {count++; result=$2}
		END {if (count == 1) print result}' "$static_receipt")"
	[[ "$code_input_set_sha" =~ ^[0-9a-f]{64}$ ]] || {
		echo "WP40 R7 runner: prefreeze code input identity differs" >&2
		exit 1
	}
	{
		printf 'schema\tgrug_wp40_r7_integration_binding_v1\n'
		printf 'code_input_set_sha256\t%s\n' "$code_input_set_sha"
		printf 'prefreeze_source_audit_sha256\t%s\n' \
			"$(sha256sum "$static_receipt" | awk '{print $1}')"
		printf 'integration_receipt_sha256\t%s\n' \
			"$(sha256sum "$integration_receipt" | awk '{print $1}')"
		printf 'integration_log_sha256\t%s\n' \
			"$(sha256sum "$integration_log" | awk '{print $1}')"
	} >"$binding_partial"
	mv -- "$integration_log_partial" "$durable_integration_log"
	mv -- "$integration_partial" "$durable_integration"
	mv -- "$prefreeze_partial" "$durable_prefreeze"
	mv -- "$binding_partial" "$durable_integration_binding"
	cat "$catalog_log" "$native_log" "$integration_log"
	cat "$catalog_receipt" "$integration_receipt"
	exit 0
fi

if [[ "$mode" == freeze ]]; then
	[[ "$#" -eq 0 ]] || { echo "usage: run.sh freeze" >&2; exit 2; }
	[[ -f "$durable_integration" && -f "$durable_integration_log" &&
		-f "$durable_integration_binding" && -f "$durable_prefreeze" &&
		! -e "$durable_micro" && ! -e "$durable_micro_output" &&
		! -e "$durable_micro_lj_log" && ! -e "$durable_micro_puc_log" &&
		! -e "$durable_static" ]] || {
		echo "WP40 R7 runner: freeze boundary/evidence state differs" >&2
		exit 1
	}
	static_gates "$static_receipt" prefreeze
	cmp -s "$static_receipt" "$durable_prefreeze" || {
		echo "WP40 R7 runner: code inputs changed after the integration freeze" >&2
		exit 1
	}
	binding_value() {
		local key="$1"
		awk -F '\t' -v wanted="$key" '$1 == wanted {count++; result=$2}
			END {if (count == 1) print result}' "$durable_integration_binding"
	}
	current_code_input_sha="$(awk -F '\t' '$1 == "code_input_set_sha256" {
		count++; result=$2} END {if (count == 1) print result}' "$static_receipt")"
	current_prefreeze_sha="$(sha256sum "$durable_prefreeze" | awk '{print $1}')"
	current_integration_sha="$(sha256sum "$durable_integration" | awk '{print $1}')"
	current_integration_log_sha="$(sha256sum "$durable_integration_log" | awk '{print $1}')"
	[[ "$(binding_value schema)" == grug_wp40_r7_integration_binding_v1 &&
		"$(binding_value code_input_set_sha256)" == "$current_code_input_sha" &&
		"$(binding_value prefreeze_source_audit_sha256)" == "$current_prefreeze_sha" &&
		"$(binding_value integration_receipt_sha256)" == "$current_integration_sha" &&
		"$(binding_value integration_log_sha256)" == "$current_integration_log_sha" ]] || {
		echo "WP40 R7 runner: integration/code binding changed before final micro" >&2
		exit 1
	}
	bash "$script_dir/final_micro.sh" "$repo" "$durable_micro"
	static_gates "$static_receipt" final
	static_partial="$(mktemp "$docs/.wp40-r7-source-audit.partial.XXXXXXXX")"
	cp -- "$static_receipt" "$static_partial"
	mv -- "$static_partial" "$durable_static"
	cat "$durable_micro" "$durable_static"
	exit 0
fi

[[ -f "$durable_integration" && -f "$durable_integration_log" &&
	-f "$durable_integration_binding" && -f "$durable_prefreeze" &&
	-f "$durable_micro" && -f "$durable_micro_output" &&
	-f "$durable_micro_lj_log" && -f "$durable_micro_puc_log" &&
	-f "$durable_static" ]] || {
	echo "WP40 R7 runner: pilot/fleet requires frozen integration, micro and final audit" >&2
	exit 1
}
static_gates "$static_receipt" final
cmp -s "$static_receipt" "$durable_static" || {
	echo "WP40 R7 runner: final source audit changed after freeze" >&2
	exit 1
}
run_catalog "$catalog_receipt" "$catalog_log"
run_native "$native_log"
run_sample_roster "$sample_assignment" "$sample_assignment_log"
integration_receipt="$durable_integration"
integration_log="$durable_integration_log"

seed_corpus="$repo/docs/research/wp40-simple-map-r6-seed-corpus.tsv"
validate_seed_corpus "$seed_corpus" || {
	echo "WP40 R7 runner: frozen seed corpus validation failed" >&2
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
	pilot_seed_output="$scratch/pilot-seed-17.tsv"
	[[ -f "$pilot_seed_output" ]] || {
		echo "WP40 R7 runner: pilot seed evidence is absent" >&2
		exit 1
	}
	pilot_post_static="$scratch/source-audit-pilot-post.tsv"
	static_gates "$pilot_post_static" final
	cmp -s "$static_receipt" "$pilot_post_static" &&
		cmp -s "$durable_static" "$pilot_post_static" || {
		echo "WP40 R7 runner: repository inputs changed during the pilot" >&2
		exit 1
	}
	static_sha="$(sha256sum "$static_receipt" | awk '{print $1}')"
	catalog_sha="$(sha256sum "$catalog_receipt" | awk '{print $1}')"
	native_sha="$(sha256sum "$native_log" | awk '{print $1}')"
	integration_sha="$(sha256sum "$integration_receipt" | awk '{print $1}')"
	roster_sha="$(sha256sum "$seed_corpus" | awk '{print $1}')"
	sample_assignment_sha="$(sha256sum "$sample_assignment" | awk '{print $1}')"
	pilot_result_sha="$(sha256sum "$pilot_result" | awk '{print $1}')"
	pilot_sample_roster_sha="$(awk -F '\t' '$1 == "sample_roster_sha256" {
		count++; result=$2} END {if (count == 1) print result}' "$pilot_seed_output")"
	pilot_sample_owner_count="$(awk -F '\t' '$1 == "sample_owner_count" {
		count++; result=$2} END {if (count == 1) print result}' "$pilot_seed_output")"
	pilot_sample_column_count="$(awk -F '\t' '$1 == "sample_column_count" {
		count++; result=$2} END {if (count == 1) print result}' "$pilot_seed_output")"
	expected_pilot_roster_sha="$(awk -F '\t' '$1 == "seed" && $2 == 17 {
		count++; result=$3} END {if (count == 1) print result}' "$sample_assignment")"
	[[ "$pilot_sample_roster_sha" =~ ^[0-9a-f]{64}$ &&
		"$pilot_sample_roster_sha" == "$expected_pilot_roster_sha" &&
		"$pilot_sample_owner_count" == 128 && "$pilot_sample_column_count" == 795281 ]] || {
		echo "WP40 R7 runner: pilot sample identity differs" >&2
		exit 1
	}
	read -r resource_schema elapsed user_time system_time peak_rss < <(
		awk -F '\t' 'NR == 1 {print $1, $2, $3, $4, $5}' "$pilot_resource")
	[[ "$resource_schema" == r7_pilot_resource_v1 ]] || {
		echo "WP40 R7 runner: pilot resource receipt differs" >&2
		exit 1
	}
	scratch_bytes="$(du -sb -- "$scratch" | awk '{print $1}')"
	receipt_output_bytes="$(du -b -- "$pilot_result" | awk '{print $1}')"
	canonical_output_rows="$(awk -F '\t' '$1 == "canonical_output_bytes" {count++}
		END {print count + 0}' "$pilot_result")"
	output_bytes="$(awk -F '\t' '$1 == "canonical_output_bytes" {print $2}' \
		"$pilot_result")"
	[[ "$canonical_output_rows" -eq 1 && "$output_bytes" =~ ^[1-9][0-9]*$ ]] || {
		echo "WP40 R7 runner: pilot canonical output byte measurement differs" >&2
		exit 1
	}
	projected_wall="$(awk -v elapsed="$elapsed" 'BEGIN {printf "%.6f", elapsed * 5}')"
	projected_budget_status="$(awk -v projected="$projected_wall" \
		'BEGIN {print projected <= 7200 ? "within_two_hour_limit" : "over_two_hour_stop"}')"
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
		printf 'sample_assignment_sha256\t%s\n' "$sample_assignment_sha"
		awk '{print "sample_assignment\t" $0}' "$sample_assignment"
		printf 'pilot_result_sha256\t%s\n' "$pilot_result_sha"
		awk '{print "pilot_result\t" $0}' "$pilot_result"
	} >"$binding_file"
	assignment_sha="$(sha256sum "$binding_file" | awk '{print $1}')"
	pilot_partial="$(mktemp "${pilot_output}.partial.XXXXXXXX")"
	{
		printf 'schema\tgrug_wp40_r7_pilot_projection_v1\n'
		printf 'acceptance_scope\t32_seed_stratified_sample_not_exhaustive\n'
		printf 'assignment_sha256\t%s\n' "$assignment_sha"
		cat "$binding_file"
		printf 'representative_seed_slot\t17\n'
		printf 'sample_schema\tgrug_wp40_r7_stratified_owner_sample_v1\n'
		printf 'sample_owner_population_per_seed\t128\n'
		printf 'sample_case_population\t4096\n'
		printf 'sample_column_population_per_seed\t795281\n'
		printf 'pilot_sample_roster_sha256\t%s\n' "$pilot_sample_roster_sha"
		printf 'measured_elapsed_seconds\t%s\n' "$elapsed"
		printf 'measured_user_seconds\t%s\n' "$user_time"
		printf 'measured_system_seconds\t%s\n' "$system_time"
		printf 'measured_peak_rss_kib\t%s\n' "$peak_rss"
		printf 'measured_output_bytes\t%s\n' "$output_bytes"
		printf 'measured_pilot_receipt_bytes\t%s\n' "$receipt_output_bytes"
		printf 'measured_scratch_bytes\t%s\n' "$scratch_bytes"
		printf 'fleet_width\t7\n'
		printf 'fleet_seed_population\t32\n'
		printf 'projected_fleet_wall_seconds\t%s\n' "$projected_wall"
		printf 'projected_fleet_budget_limit_seconds\t7200\n'
		printf 'projected_fleet_budget_status\t%s\n' "$projected_budget_status"
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
projected_wall_seconds="$(awk -F '\t' '$1 == "projected_fleet_wall_seconds" {
	count++; value=$2} END {if (count == 1) print value}' "$projection")"
projected_limit_seconds="$(awk -F '\t' '$1 == "projected_fleet_budget_limit_seconds" {
	count++; value=$2} END {if (count == 1) print value}' "$projection")"
projected_budget_status="$(awk -F '\t' '$1 == "projected_fleet_budget_status" {
	count++; value=$2} END {if (count == 1) print value}' "$projection")"
[[ "$projected_wall_seconds" =~ ^(0|[1-9][0-9]*)(\.[0-9]+)?$ &&
	"$projected_limit_seconds" =~ ^[1-9][0-9]*$ &&
	"$projected_budget_status" == within_two_hour_limit ]] &&
	awk -v wall="$projected_wall_seconds" -v limit="$projected_limit_seconds" \
		'BEGIN {exit !(wall >= 0 && wall <= limit)}' || {
	echo "WP40 R7 runner: projection wall/budget arithmetic differs" >&2
	exit 1
}
[[ "$(awk -F '\t' '$1 == "schema" {print $2}' "$projection")" == \
	grug_wp40_r7_pilot_projection_v1 &&
	"$(awk -F '\t' '$1 == "acceptance_scope" {print $2}' "$projection")" == \
	32_seed_stratified_sample_not_exhaustive &&
	"$(awk -F '\t' '$1 == "fleet_width" {print $2}' "$projection")" == 7 &&
	"$(awk -F '\t' '$1 == "fleet_seed_population" {print $2}' "$projection")" == 32 &&
	"$(awk -F '\t' '$1 == "sample_schema" {print $2}' "$projection")" == \
	grug_wp40_r7_stratified_owner_sample_v1 &&
	"$(awk -F '\t' '$1 == "sample_owner_population_per_seed" {print $2}' \
		"$projection")" == 128 &&
	"$(awk -F '\t' '$1 == "sample_case_population" {print $2}' "$projection")" == 4096 &&
	"$(awk -F '\t' '$1 == "sample_column_population_per_seed" {print $2}' \
		"$projection")" == 795281 &&
	"$projected_limit_seconds" == 7200 &&
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
	"$(sha256sum "$integration_receipt" | awk '{print $1}')" &&
	"$(awk -F '\t' '$1 == "sample_assignment_sha256" {print $2}' "$projection")" == \
	"$(sha256sum "$sample_assignment" | awk '{print $1}')" ]] || {
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
first_slots=(1 6 11 16 21 25 29)
last_slots=(5 10 15 20 24 28 32)
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
static_gates "$post_static" final
cmp -s "$static_receipt" "$post_static" || {
	echo "WP40 R7 runner: repository inputs changed during the fleet" >&2
	exit 1
}
cmp -s "$durable_static" "$post_static" || {
	echo "WP40 R7 runner: post-fleet final audit differs from frozen audit" >&2
	exit 1
}

worker_paths=()
for worker_id in 1 2 3 4 5 6 7; do
	worker_paths+=("$scratch/worker-$worker_id.tsv")
done
reverse_worker_paths=()
for worker_id in 7 6 5 4 3 2 1; do
	reverse_worker_paths+=("$scratch/worker-$worker_id.tsv")
done
forward="$scratch/finalizer-forward"
reverse="$scratch/finalizer-reverse"
mkdir -p -- "$forward/internal" "$reverse/internal"
artifact_tmp="$forward/wp40-r7-artifact.tsv"
stage_a_tmp="$forward/wp40-r7-stage-a.tsv"
stage_b_tmp="$forward/wp40-r7-stage-b.tsv"
p9g_tmp="$forward/wp40-r7-p9g-ledger.tsv"
receipt_tmp="$forward/wp40-r7-run-receipt.tsv"
finalizer_log="$scratch/finalizer-forward.log"
"$lua_bin" "${lua_prefix[@]}" "$cli" finalize "$repo" \
	"$forward/unused" "$forward/internal" "$artifact_tmp" \
	"$stage_a_tmp" "$stage_b_tmp" "$p9g_tmp" \
	"$receipt_tmp" "${worker_paths[@]}" >"$finalizer_log" 2>&1
reverse_artifact="$reverse/wp40-r7-artifact.tsv"
reverse_stage_a="$reverse/wp40-r7-stage-a.tsv"
reverse_stage_b="$reverse/wp40-r7-stage-b.tsv"
reverse_p9g="$reverse/wp40-r7-p9g-ledger.tsv"
reverse_receipt="$reverse/wp40-r7-run-receipt.tsv"
reverse_finalizer_log="$scratch/finalizer-reverse.log"
"$lua_bin" "${lua_prefix[@]}" "$cli" finalize "$repo" \
	"$reverse/unused" "$reverse/internal" "$reverse_artifact" \
	"$reverse_stage_a" "$reverse_stage_b" "$reverse_p9g" \
	"$reverse_receipt" "${reverse_worker_paths[@]}" >"$reverse_finalizer_log" 2>&1
for pair in "$artifact_tmp:$reverse_artifact" "$stage_a_tmp:$reverse_stage_a" \
		"$stage_b_tmp:$reverse_stage_b" "$p9g_tmp:$reverse_p9g" \
		"$receipt_tmp:$reverse_receipt"; do
	forward_file="${pair%%:*}" reverse_file="${pair#*:}"
	cmp -s "$forward_file" "$reverse_file" || {
		echo "WP40 R7 runner: reversed-worker canonical invariance failed" >&2
		exit 1
	}
	done

finalizer_post_static="$scratch/source-audit-finalizer-post.tsv"
static_gates "$finalizer_post_static" final
cmp -s "$static_receipt" "$finalizer_post_static" &&
	cmp -s "$durable_static" "$finalizer_post_static" || {
	echo "WP40 R7 runner: repository inputs changed during finalization" >&2
	exit 1
}

docs="$repo/docs/research"
artifact="$docs/wp40-r7-artifact.tsv"
stage_a="$docs/wp40-r7-stage-a-receipt.tsv"
stage_b="$docs/wp40-r7-stage-b-receipt.tsv"
p9g="$docs/wp40-r7-p9g-ledger.tsv"
run_receipt="$docs/wp40-r7-run-receipt.tsv"
durable_projection="$docs/wp40-r7-pilot-projection.tsv"
run_log="$docs/wp40-r7-run.log"
promotion="$docs/wp40-r7-promotion-manifest.tsv"
for frozen in "$durable_static" "$durable_micro" "$durable_micro_output" \
		"$durable_micro_lj_log" "$durable_micro_puc_log" "$durable_integration" \
		"$durable_integration_log" "$durable_integration_binding" \
		"$durable_prefreeze"; do
	[[ -f "$frozen" ]] || {
		echo "WP40 R7 runner: frozen evidence disappeared: $frozen" >&2
		exit 1
	}
done
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
		for log in "$catalog_log" "$native_log" "$sample_assignment_log" \
				"$integration_log" \
			"$scratch"/worker-*.log "$scratch"/worker-*.resource.tsv \
			"$finalizer_log" "$reverse_finalizer_log"; do
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
	printf 'gate\treversed_worker_canonical_invariance\ttrue\n'
	for key in proof_scope_fleet accepted_r6_artifact_sha256 \
			production_r6_content_sha256 p9g_content_sha256 p9g_delta_sha256; do
		value="$(awk -F '\t' -v wanted="$key" '$1 == wanted {count++; result=$2}
			END {if (count == 1) print result}' "$run_receipt")"
		[[ -n "$value" ]] || {
			echo "WP40 R7 runner: run receipt identity is absent: $key" >&2
			exit 1
		}
		printf '%s\t%s\n' "$key" "$value"
	done
	for target in "$artifact" "$stage_a" "$stage_b" "$p9g" "$run_receipt" \
			"$durable_projection" "$run_log" "$durable_static" "$durable_micro" \
			"$durable_micro_output" "$durable_micro_lj_log" "$durable_micro_puc_log" \
			"$durable_integration" "$durable_integration_log" \
			"$durable_integration_binding" "$durable_prefreeze"; do
		printf 'file\t%s\t%s\n' "${target#"$repo/"}" \
			"$(sha256sum "$target" | awk '{print $1}')"
	done
} >"$promotion_partial"
mv -- "$promotion_partial" "$promotion"
[[ "$(awk -F '\t' '$1 == "schema" {count++; value=$2}
	END {if (count == 1) print value}' "$promotion")" == \
	grug_wp40_r7_promotion_manifest_v1 &&
	"$(awk -F '\t' '$1 == "gate" && $2 == "reversed_worker_canonical_invariance" &&
		$3 == "true" {count++} END {print count + 0}' "$promotion")" -eq 1 &&
	"$(awk -F '\t' '$1 == "file" {count++} END {print count + 0}' "$promotion")" -eq 16 ]] || {
	echo "WP40 R7 runner: final promotion manifest closure differs" >&2
	exit 1
}
while IFS=$'\t' read -r kind relative expected_sha extra; do
	[[ "$kind" == file ]] || continue
	[[ -z "$extra" && -f "$repo/$relative" &&
		"$(sha256sum "$repo/$relative" | awk '{print $1}')" == "$expected_sha" ]] || {
		echo "WP40 R7 runner: promoted evidence binding differs: $relative" >&2
		exit 1
	}
done <"$promotion"
printf 'r7_promotion_manifest_sha256\t%s\n' \
	"$(sha256sum "$promotion" | awk '{print $1}')"
