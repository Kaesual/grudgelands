#!/usr/bin/env bash
set -euo pipefail

# Minimal real-engine R8 smoke runner. It deliberately owns only two fresh
# worlds and a small externally supplied mapchunk corpus.
command -v rg >/dev/null 2>&1 || {
	echo "WP40 R8: ripgrep (rg) is required" >&2
	exit 2
}
for command_name in awk cat chrt find flatpak git ionice jq setsid sha256sum \
	tar timeout xargs; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "WP40 R8: missing command $command_name" >&2
		exit 2
	fi
done
if [[ ! -x /usr/bin/time ]]; then
	echo "WP40 R8: /usr/bin/time is required for walltime/RSS" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../../.." && pwd)"
mode="${WP40_R8_MODE:-final}"
if [[ "$mode" != "pilot" && "$mode" != "final" ]]; then
	echo "WP40 R8: WP40_R8_MODE must be pilot or final" >&2
	exit 2
fi
min_cases=10
max_cases=15
default_corpus="$script_dir/smoke-corpus.tsv"
if [[ "$mode" == "pilot" ]]; then
	min_cases=2
	max_cases=3
	default_corpus="$script_dir/pilot-corpus.tsv"
fi
corpus="${1:-${WP40_R8_CORPUS:-$default_corpus}}"
if [[ "$corpus" != /* ]]; then corpus="$repo/$corpus"; fi
[[ -f "$corpus" ]] || { echo "WP40 R8: corpus not found: $corpus" >&2; exit 2; }
native_corpus="${WP40_R8_NATIVE_CORPUS:-}"
if [[ -z "$native_corpus" ]]; then
	native_default="$script_dir/native-witness-corpus.tsv"
	if [[ "$mode" == "pilot" ]]; then
		native_default="$script_dir/native-pilot-corpus.tsv"
	fi
	if [[ -f "$native_default" ]]; then native_corpus="$native_default"; fi
fi
if [[ "$mode" == "final" && -z "$native_corpus" ]]; then
	echo "WP40 R8: final mode requires WP40_R8_NATIVE_CORPUS" >&2
	exit 2
fi
if [[ -n "$native_corpus" ]]; then
	if [[ "$native_corpus" != /* ]]; then native_corpus="$repo/$native_corpus"; fi
	[[ -f "$native_corpus" ]] || {
		echo "WP40 R8: native witness corpus not found: $native_corpus" >&2
		exit 2
	}
fi
native_row_count="$(awk 'NF && $1 !~ /^#/ {count++} END {print count + 0}' \
	"$native_corpus")"
expected_native_rows=32
if [[ "$mode" == "pilot" ]]; then expected_native_rows=1; fi
if [[ "$native_row_count" != "$expected_native_rows" ]]; then
	echo "WP40 R8: native corpus row count differs from frozen mode" >&2
	exit 2
fi

checkout_input="${WP40_CHECKOUT_SHA:-HEAD}"
checkout_sha="$(git -C "$repo" rev-parse --verify "${checkout_input}^{commit}")"
if [[ ! "$checkout_sha" =~ ^[0-9a-f]{40}$ ]]; then
	echo "WP40 R8: rev-parse did not return a canonical 40-hex commit" >&2
	exit 2
fi
seed="${WP40_SEED:-0}"
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "WP40 R8: WP40_SEED must be a canonical nonnegative decimal string" >&2
	exit 2
}
seed_sha256="$(printf '%s' "$seed" | sha256sum | awk '{print $1}')"
timeout_seconds="${WP40_R8_TIMEOUT:-900}"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || {
	echo "WP40 R8: WP40_R8_TIMEOUT must be a positive integer" >&2
	exit 2
}
if [[ ${#timeout_seconds} -gt 5 ]] || (( timeout_seconds > 86400 )); then
	echo "WP40 R8: WP40_R8_TIMEOUT must not exceed 86400 seconds" >&2
	exit 2
fi
if [[ "$mode" == "final" && "$timeout_seconds" != "7170" ]]; then
	echo "WP40 R8: final mode requires WP40_R8_TIMEOUT=7170" >&2
	exit 2
fi
liquid_update_seconds=$((timeout_seconds + 31))
parallel_orders="${WP40_R8_PARALLEL:-0}"
if [[ "$parallel_orders" != "0" && "$parallel_orders" != "1" ]]; then
	echo "WP40 R8: WP40_R8_PARALLEL must be 0 or 1" >&2
	exit 2
fi
if [[ "$mode" == "final" && "$parallel_orders" != "1" ]]; then
	echo "WP40 R8: final mode requires WP40_R8_PARALLEL=1" >&2
	exit 2
fi

for relative_path in tools/wp40/r8/run.sh tools/wp40/r8/probe/init.lua \
		tools/wp40/r8/probe/mod.conf tools/wp40/r8/seed-candidates.tsv \
		tools/wp40/r8/pilot-corpus.tsv tools/wp40/r8/smoke-corpus.tsv \
		tools/wp40/r8/native-pilot-corpus.tsv \
		tools/wp40/r8/native-witness-corpus.tsv; do
	if ! git -C "$repo" cat-file -e "$checkout_sha:$relative_path"; then
		echo "WP40 R8: selected commit lacks $relative_path" >&2
		exit 2
	fi
	if ! git -C "$repo" diff --quiet "$checkout_sha" -- "$relative_path"; then
		echo "WP40 R8: $relative_path differs from selected commit" >&2
		exit 2
	fi
done

candidate_table="$script_dir/seed-candidates.tsv"
offline_r7_manifest="$(awk -F '\t' -v seed="$seed" \
	'NR > 1 && ("x" $2) == ("x" seed) {print $7}' "$candidate_table")"
promotion_status="$(awk -F '\t' -v seed="$seed" \
	'NR > 1 && ("x" $2) == ("x" seed) {print $14}' "$candidate_table")"
if [[ ! "$offline_r7_manifest" =~ ^[0-9a-f]{64}$ ]]; then
	echo "WP40 R8: seed is not one of the frozen candidates: $seed" >&2
	exit 2
fi
if [[ "$promotion_status" != "automated_release_candidate" ]]; then
	echo "WP40 R8: seed lacks a reviewed candidate-specific resource witness: $seed" >&2
	exit 2
fi

flatpak_info_text="$(flatpak info org.luanti.luanti)"
flatpak_version_text="$(flatpak run --command=luanti \
	org.luanti.luanti --version)"
engine_digest="$({
	printf '%s\n' "$flatpak_info_text"
	printf '%s\n' "$flatpak_version_text"
} | sha256sum | awk '{print $1}')"

runner_digest="$({
	sha256sum "$script_dir/run.sh" | awk '{print $1}'
	sha256sum "$script_dir/probe/init.lua" | awk '{print $1}'
	sha256sum "$script_dir/probe/mod.conf" | awk '{print $1}'
} | sha256sum | awk '{print $1}')"
corpus_digest="$(sha256sum "$corpus" | awk '{print $1}')"
native_corpus_digest=""
if [[ -n "$native_corpus" ]]; then
	native_corpus_digest="$(sha256sum "$native_corpus" | awk '{print $1}')"
fi
candidate_table_digest="$(sha256sum "$candidate_table" | awk '{print $1}')"
capture_id="$({
	printf '%s\n' "grug_wp40_r8_headless_smoke_v2" "$checkout_sha" \
		"$mode" "$parallel_orders" "$seed" "$offline_r7_manifest" \
		"$timeout_seconds" \
		"$runner_digest" "$corpus_digest" "$native_corpus_digest" \
		"$candidate_table_digest" \
		"$engine_digest" "$seed_sha256"
} | sha256sum | awk '{print $1}')"
results_root="${WP40_R8_RESULTS_ROOT:-$repo/tools/wp40/results/r8}"
if [[ "$results_root" != /* ]]; then results_root="$repo/$results_root"; fi
mkdir -p "$results_root"
result_dir="$results_root/$capture_id"
if [[ -e "$result_dir" ]]; then
	echo "WP40 R8: refusing to overwrite immutable result $result_dir" >&2
	exit 2
fi
mkdir "$result_dir" "$result_dir/forward" "$result_dir/reverse" \
	"$result_dir/inputs"
cp "$corpus" "$result_dir/corpus.tsv"
if [[ -n "$native_corpus" ]]; then cp "$native_corpus" "$result_dir/native-witness-corpus.tsv"; fi
cp "$script_dir/run.sh" "$result_dir/inputs/run.sh"
cp "$script_dir/probe/init.lua" "$result_dir/inputs/probe-init.lua"
cp "$script_dir/probe/mod.conf" "$result_dir/inputs/probe-mod.conf"
cp "$candidate_table" "$result_dir/inputs/seed-candidates.tsv"
if [[ -n "$native_corpus" ]]; then cp "$native_corpus" "$result_dir/inputs/native-witness-corpus.tsv"; fi
printf '%s\n' "$flatpak_info_text" >"$result_dir/flatpak-info.txt"
printf '%s\n' "$flatpak_version_text" >"$result_dir/flatpak-version.txt"

capture_flatpak_identity() {
	local prefix="$1"
	flatpak info org.luanti.luanti >"$result_dir/${prefix}-deployment.txt"
	flatpak run --command=luanti org.luanti.luanti --version \
		>"$result_dir/${prefix}-version.txt"
}
identity_digest() {
	local prefix="$1"
	{
		cat "$result_dir/${prefix}-deployment.txt"
		cat "$result_dir/${prefix}-version.txt"
	} | sha256sum | awk '{print $1}'
}
capture_root="$(mktemp -d -p /tmp grudgelands-wp40-r8.XXXXXXXX)"
runner_pid="$BASHPID"
forward_pid=""
reverse_pid=""
terminate_engine_group() {
	local order="$1"
	local pgid_file="$result_dir/$order/engine-pgid"
	local pgid=""
	if [[ -f "$pgid_file" ]]; then read -r pgid <"$pgid_file" || true; fi
	if [[ "$pgid" =~ ^[1-9][0-9]*$ ]]; then
		kill -- "-$pgid" 2>/dev/null || true
		for _ in 1 2 3 4 5; do
			if ! kill -0 -- "-$pgid" 2>/dev/null; then return; fi
			sleep 0.1
		done
		kill -KILL -- "-$pgid" 2>/dev/null || true
	fi
}
cleanup() {
	terminate_engine_group forward
	terminate_engine_group reverse
	if [[ -n "$forward_pid" ]]; then
		kill "$forward_pid" 2>/dev/null || true
		wait "$forward_pid" 2>/dev/null || true
	fi
	if [[ -n "$reverse_pid" ]]; then
		kill "$reverse_pid" 2>/dev/null || true
		wait "$reverse_pid" 2>/dev/null || true
	fi
	# A wrapper can publish its detached engine PGID between the first check
	# above and its termination. Recheck only after no wrapper can launch one.
	terminate_engine_group forward
	terminate_engine_group reverse
	if [[ "$capture_root" == /tmp/grudgelands-wp40-r8.* ]]; then
		rm -rf -- "$capture_root"
	fi
}
trap 'exit 130' HUP INT TERM
trap cleanup EXIT

run_order() {
	if [[ "$BASHPID" != "$runner_pid" ]]; then
		trap - EXIT HUP INT TERM
	fi
	local order="$1"
	local run_root="$capture_root/$order"
	local user_path="$run_root/user"
	local game_dir="$user_path/games/grudgelands"
	local world_dir="$run_root/world"
	local xdg_data="$run_root/xdg/data"
	local xdg_config="$run_root/xdg/config"
	local xdg_cache="$run_root/xdg/cache"
	local config="$run_root/luanti.conf"
	local output_dir="$result_dir/$order"
	local server_log="$output_dir/server.log.partial"
	local console_log="$output_dir/console.log.partial"
	local time_log="$output_dir/time.txt.partial"
	local events_path="$output_dir/events.jsonl.partial"
	local host_timeout_seconds=$((timeout_seconds + 30))
	local native_required=false
	if [[ "$mode" == "final" ]]; then native_required=true; fi
	mkdir -p "$game_dir" "$world_dir" "$xdg_data" "$xdg_config" "$xdg_cache"
	git -C "$repo" archive "$checkout_sha" | tar -x -C "$game_dir"
	mkdir -p "$game_dir/mods/grug_wp40_r8_probe"
	cp "$result_dir/inputs/probe-init.lua" \
		"$game_dir/mods/grug_wp40_r8_probe/init.lua"
	cp "$result_dir/inputs/probe-mod.conf" \
		"$game_dir/mods/grug_wp40_r8_probe/mod.conf"
	cat >"$world_dir/world.mt" <<'EOF'
gameid = grudgelands
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
EOF
	local port=32001
	if [[ "$order" == "reverse" ]]; then port=32002; fi
	cat >"$config" <<EOF
mg_name = v7
fixed_map_seed = $seed
mapgen_limit = 31007
chunksize = 5
water_level = 1
mg_flags = caves,dungeons,light,decorations,biomes,ores
mgv7_spflags = mountains,ridges,caverns,nofloatlands
mgv7_dungeon_ymin = -31000
mgv7_dungeon_ymax = -193
num_emerge_threads = 1
liquid_update = $liquid_update_seconds
dedicated_server_step = 0.09
max_block_generate_distance = 5
max_block_send_distance = 5
active_block_range = 4
server_announce = false
enable_ipv6 = false
bind_address = 127.0.0.1
port = $port
enable_damage = true
creative_mode = false
secure.enable_security = true
deprecated_lua_api_handling = error
debug_log_level = action
grug_wp40_r8_output = $events_path
grug_wp40_r8_corpus = $world_dir/corpus.tsv
grug_wp40_r8_native_corpus = ${native_corpus:+$world_dir/native-witness-corpus.tsv}
grug_wp40_r8_native_required = $native_required
grug_wp40_r8_seed = $seed
grug_wp40_r8_order = $order
grug_wp40_r8_min_cases = $min_cases
grug_wp40_r8_max_cases = $max_cases
grug_wp40_r8_timeout = $timeout_seconds
secure.trusted_mods = grug_wp40_r8_probe
EOF
	cp "$result_dir/corpus.tsv" "$world_dir/corpus.tsv"
	if [[ -n "$native_corpus" ]]; then cp "$result_dir/native-witness-corpus.tsv" "$world_dir/native-witness-corpus.tsv"; fi
	cp "$config" "$output_dir/luanti.conf"
	cp "$world_dir/world.mt" "$output_dir/world.mt"
	set +e
	setsid /usr/bin/time -v -o "$time_log" timeout --foreground \
		--kill-after=10 "$host_timeout_seconds" chrt --idle 0 ionice -c3 \
		flatpak run \
		--command=luanti --filesystem="$run_root" \
		--filesystem="$output_dir" \
		--env="XDG_DATA_HOME=$xdg_data" \
		--env="XDG_CONFIG_HOME=$xdg_config" \
		--env="XDG_CACHE_HOME=$xdg_cache" \
		--env="LUANTI_USER_PATH=$user_path" \
		org.luanti.luanti --server --gameid grudgelands \
		--world "$world_dir" --config "$config" \
		--logfile "$server_log" --log-timestamp none --color never \
		>"$console_log" 2>&1 &
	local engine_pgid=$!
	printf '%s\n' "$engine_pgid" >"$output_dir/engine-pgid"
	wait "$engine_pgid"
	local status=$?
	mv "$output_dir/engine-pgid" "$output_dir/engine-pgid.finished"
	set -e
	printf '%s\n' "$status" >"$output_dir/exit-status"
	for file in server.log console.log time.txt; do
		if [[ -f "$output_dir/$file.partial" ]]; then
			mv "$output_dir/$file.partial" "$output_dir/$file"
		fi
	done
	if [[ -f "$events_path" ]]; then
		mv "$events_path" "$output_dir/events.jsonl"
	fi
	if [[ -f "$output_dir/server.log" && -f "$output_dir/console.log" ]]; then
		set +e
		rg -n -i '(^|[^[:alpha:]])(ERROR|LuaError|FATAL|assertion failed|stack traceback|segmentation fault|SIGABRT)([^[:alpha:]]|$)' \
			"$output_dir/server.log" "$output_dir/console.log" \
			>"$output_dir/errors.log"
		local scan_status=$?
		set -e
		if [[ $scan_status -gt 1 ]]; then
			echo "WP40 R8: error scan failed for $order" >&2
			return 1
		fi
	else
		echo "WP40 R8: $order did not retain both engine logs" >&2
		return 1
	fi
	if [[ $status -ne 0 ]]; then
		echo "WP40 R8: $order Luanti process exited with $status" >&2
		return 1
	fi
	[[ -s "$output_dir/events.jsonl" ]] || {
		echo "WP40 R8: $order produced no probe events" >&2
		return 1
	}
}

capture_flatpak_identity flatpak-before-pair
initial_flatpak_digest="$(identity_digest flatpak-before-pair)"
if [[ "$initial_flatpak_digest" != "$engine_digest" ]]; then
	echo "WP40 R8: Flatpak identity changed while preparing the capture" >&2
	exit 1
fi
if [[ "$parallel_orders" == "1" ]]; then
	run_order forward &
	forward_pid=$!
	run_order reverse &
	reverse_pid=$!
	fleet_status=0
	if ! wait "$forward_pid"; then fleet_status=1; fi
	forward_pid=""
	if ! wait "$reverse_pid"; then fleet_status=1; fi
	reverse_pid=""
	if [[ $fleet_status -ne 0 ]]; then
		echo "WP40 R8: one or both parallel orders failed" >&2
		exit 1
	fi
else
	run_order forward
	run_order reverse
fi
capture_flatpak_identity flatpak-after-pair
final_flatpak_digest="$(identity_digest flatpak-after-pair)"
if [[ "$final_flatpak_digest" != "$initial_flatpak_digest" ]]; then
	echo "WP40 R8: Flatpak deployment/origin/version changed during the pair" >&2
	exit 1
fi

jq -n --arg expected_seed "$seed" \
	--arg expected_seed_sha256 "$seed_sha256" \
	--arg expected_liquid_update "$liquid_update_seconds" \
	--slurpfile forward "$result_dir/forward/events.jsonl" \
	--slurpfile reverse "$result_dir/reverse/events.jsonl" '
	def cases: map(select(.event == "case")) | sort_by(.id) |
		map({id, mapchunk, central_min, central_max, content_sha256,
			param2_sha256, light_sha256, central_voxels, node_counts,
			light_stats, semantic_checks, semantic_evidence, semantic_ok});
	def native_census: map(select(.event == "native_census")) | sort_by(.id) |
		map({id, mapchunk, central_min, central_max, content_sha256,
			central_voxels, node_counts, native_census, semantic_checks,
			semantic_ok});
	def start: map(select(.event == "start"));
	def complete: map(select(.event == "complete"));
	def shutdown: map(select(.event == "shutdown"));
	def emerge: map(select(.event == "emerge"));
	def errors: map(select(.event == "emerge") | .actions |
			((.cancelled // 0) + (.errored // 0)));
	($forward | cases) as $f |
	($reverse | cases) as $r |
	($forward | native_census) as $fn |
	($reverse | native_census) as $rn |
	($forward | start) as $fst |
	($reverse | start) as $rst |
	($forward | complete) as $fc |
	($reverse | complete) as $rc |
	($forward | shutdown) as $fs |
	($reverse | shutdown) as $rs |
	($forward | emerge) as $fe |
	($reverse | emerge) as $re |
	{schema: "grug_wp40_r8_order_comparison_v1",
	 forward_cases: $f, reverse_cases: $r,
	 forward_native_census: $fn, reverse_native_census: $rn,
	 equal: ($f == $r),
	 semantic_ok: (all($f[]; .semantic_ok == true) and
		all($r[]; .semantic_ok == true) and
		all($fn[]; .semantic_ok == true) and
		all($rn[]; .semantic_ok == true)),
	 native_census_equal: ($fn == $rn),
	 native_gate_equal: (($fc | length) == 1 and ($rc | length) == 1 and
		$fc[0].native_gate == $rc[0].native_gate),
	 start_engine_equal: (($fst | length) == 1 and ($rst | length) == 1 and
		$fst[0].engine == $rst[0].engine and
		$fst[0].lua_runtime == $rst[0].lua_runtime),
	 start_seed_equal: (($fst | length) == 1 and ($rst | length) == 1 and
		$fst[0].seed == $rst[0].seed and
		$fst[0].seed == $expected_seed and
		$fst[0].seed_sha256 == $rst[0].seed_sha256 and
		$fst[0].seed_sha256 == $expected_seed_sha256),
	 request_orders_reversed: (($fst | length) == 1 and ($rst | length) == 1 and
		$fst[0].request_order == ($rst[0].request_order | reverse)),
	 forward_start: (($fst | length) == 1 and
		$fst[0].mapgen == "v7" and $fst[0].chunksize == "5" and
		$fst[0].water_level == "1" and
		$fst[0].num_emerge_threads == "1" and
		$fst[0].liquid_update == $expected_liquid_update and
		$fst[0].production.enabled == true and
		$fst[0].production.production_enabled == true and
		$fst[0].production.writer_count == 1 and
		$fst[0].production.full_seed == $expected_seed and
		$fst[0].production.manifest_sha256 ==
			$rst[0].production.manifest_sha256),
	 reverse_start: (($rst | length) == 1 and
		$rst[0].mapgen == "v7" and $rst[0].chunksize == "5" and
		$rst[0].water_level == "1" and
		$rst[0].num_emerge_threads == "1" and
		$rst[0].liquid_update == $expected_liquid_update and
		$rst[0].production.enabled == true and
		$rst[0].production.production_enabled == true and
		$rst[0].production.writer_count == 1 and
		$rst[0].production.full_seed == $expected_seed and
		$rst[0].production.manifest_sha256 ==
			$fst[0].production.manifest_sha256),
	 forward_complete: (($fc | length) == 1 and
		$fc[0].request_count == ($fe | length) and
		$fc[0].emerged_case_count == ($fe | length) and
		$fc[0].feature_case_count == ($f | length) and
		$fc[0].native_census_case_count == ($fn | length) and
		$fc[0].snapshot_count == (($f | length) + ($fn | length))),
	 reverse_complete: (($rc | length) == 1 and
		$rc[0].request_count == ($re | length) and
		$rc[0].emerged_case_count == ($re | length) and
		$rc[0].feature_case_count == ($r | length) and
		$rc[0].native_census_case_count == ($rn | length) and
		$rc[0].snapshot_count == (($r | length) + ($rn | length))),
	 forward_native_gate: (($fc | length) == 1 and
		$fc[0].native_gate.ok == true),
	 reverse_native_gate: (($rc | length) == 1 and
		$rc[0].native_gate.ok == true),
	 forward_clean_shutdown: (($fs | length) == 1 and $fs[0].clean == true),
	 reverse_clean_shutdown: (($rs | length) == 1 and $rs[0].clean == true),
	 forward_emerge_errors: ($forward | errors | add // 0),
	 reverse_emerge_errors: ($reverse | errors | add // 0)}' \
	>"$result_dir/comparison.json"

if ! jq -e '(.equal and .semantic_ok and .native_census_equal and
	.native_gate_equal and
	.start_seed_equal and
	.forward_native_gate and .reverse_native_gate and
	.start_engine_equal and
	.request_orders_reversed and
	.forward_start and .reverse_start and
	.forward_complete and .reverse_complete and
	.forward_clean_shutdown and .reverse_clean_shutdown and
	.forward_emerge_errors == 0 and .reverse_emerge_errors == 0)' \
	"$result_dir/comparison.json" >/dev/null; then
	echo "WP40 R8: order comparison or clean-shutdown gate failed" >&2
	exit 1
fi
if [[ -s "$result_dir/forward/errors.log" || -s "$result_dir/reverse/errors.log" ]]; then
	echo "WP40 R8: startup/runtime error lines were found" >&2
	exit 1
fi

forward_start="$(jq -s 'map(select(.event == "start"))[0]' "$result_dir/forward/events.jsonl")"
reverse_start="$(jq -s 'map(select(.event == "start"))[0]' "$result_dir/reverse/events.jsonl")"
forward_elapsed="$(jq -s '[.[] | select(.event == "complete") | .elapsed_us][0] // null' "$result_dir/forward/events.jsonl")"
reverse_elapsed="$(jq -s '[.[] | select(.event == "complete") | .elapsed_us][0] // null' "$result_dir/reverse/events.jsonl")"
forward_rss="$(jq -s '[.[] | select(.process.rss_peak_bytes != null) | .process.rss_peak_bytes] | max // null' "$result_dir/forward/events.jsonl")"
reverse_rss="$(jq -s '[.[] | select(.process.rss_peak_bytes != null) | .process.rss_peak_bytes] | max // null' "$result_dir/reverse/events.jsonl")"
jq -n --arg capture_id "$capture_id" --arg checkout_sha "$checkout_sha" \
	--arg mode "$mode" --arg seed "$seed" --arg corpus_digest "$corpus_digest" \
	--arg native_corpus_digest "$native_corpus_digest" \
	--arg seed_sha256 "$seed_sha256" \
	--arg parallel_orders "$parallel_orders" \
	--arg runner_digest "$runner_digest" \
	--arg candidate_table_digest "$candidate_table_digest" \
	--arg offline_r7_manifest "$offline_r7_manifest" \
	--arg engine_digest "$engine_digest" \
	--arg final_engine_digest "$final_flatpak_digest" \
	--arg timeout "$timeout_seconds" \
	--arg liquid_update "$liquid_update_seconds" \
	--argjson forward_start "$forward_start" \
	--argjson reverse_start "$reverse_start" \
	--argjson forward_elapsed "$forward_elapsed" \
	--argjson reverse_elapsed "$reverse_elapsed" \
	--argjson forward_rss "$forward_rss" \
	--argjson reverse_rss "$reverse_rss" \
	'{schema: "grug_wp40_r8_headless_smoke_v2",
	 status: ($mode + "_smoke_complete"),
	 capture_id: $capture_id, mode: $mode,
	 parallel_orders: ($parallel_orders == "1"),
	 snapshot: {checkout_sha: $checkout_sha, source: "git archive",
		game_snapshot_isolation: "fresh archive under per-order LUANTI_USER_PATH"},
	 input_identity: {runner_sha256: $runner_digest,
		candidate_table_sha256: $candidate_table_digest,
		engine_sha256_before: $engine_digest,
		engine_sha256_after: $final_engine_digest,
		offline_r7_manifest_sha256: $offline_r7_manifest,
		runtime_manifest_note:
			"offline mocked-engine provenance; actual runtime manifest is in startup"},
	 settings: {mg_name: "v7", chunksize: 5, water_level: 1,
		num_emerge_threads: 1, liquid_update_seconds: ($liquid_update | tonumber),
		liquid_capture_boundary: "mapgen plus immediate finishBlockMake; periodic server liquid transforms deferred beyond the host timeout",
		seed_decimal_string: $seed,
		seed_string_sha256: $seed_sha256},
	 corpus: {path: "corpus.tsv", digest: $corpus_digest,
		rows: ($forward_start.feature_case_count // null),
		schema: "id\\tx\\t(surface|y)\\tz",
		coordinates: "each row is canonicalized to one 80-node mapchunk"},
	 native_corpus: {path: "native-witness-corpus.tsv",
		digest: $native_corpus_digest,
		rows: ($forward_start.native_corpus_count // null),
		schema: "id\\tx\\ty\\tz",
		coordinates: "fixed event grid plus seven content-census slices"},
	 orders: ["forward", "reverse"],
	 startup: {forward: $forward_start, reverse: $reverse_start},
	 measured: {forward_probe_elapsed_us: $forward_elapsed,
		reverse_probe_elapsed_us: $reverse_elapsed,
		forward_engine_peak_rss_bytes: $forward_rss,
		reverse_engine_peak_rss_bytes: $reverse_rss},
	outputs: {comparison: "comparison.json",
		per_order: "{forward,reverse}/{events.jsonl,server.log,console.log,time.txt,luanti.conf,world.mt,errors.log,exit-status}",
		flatpak: ["flatpak-info.txt", "flatpak-version.txt",
			"flatpak-before-pair-*", "flatpak-after-pair-*"]},
	 telemetry: {walltime: "GNU time -v raw file plus probe elapsed_us",
		peak_rss: "GNU time launcher plus probe /proc VmHWM",
		lights: "one digest over the engine packed light-data array"},
	 limitations: [
		"This is a focused smoke runner, not an exhaustive seed, capacity or visual gate.",
		"The one-writer signal is the production status plus a read-only probe callback count; it is not a second writer audit.",
		"Order equality covers the deterministic post-mapgen state before periodic wall-clock liquid simulation.",
		"No historical T2/PCC/F1/F2 claim is reproduced."
	 ]}' >"$result_dir/manifest.json"

checksums_tmp="$capture_root/checksums.sha256"
(
	cd "$result_dir"
	find . -type f ! -name checksums.sha256 -print0 | sort -z |
		xargs -0 sha256sum
) >"$checksums_tmp"
mv "$checksums_tmp" "$result_dir/checksums.sha256"

echo "$result_dir"
