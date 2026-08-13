#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
base_sha="7b6c8763224006630f967659047ffae88de6685d"
checkout_sha="${WP40_CHECKOUT_SHA:-$base_sha}"
seed="${WP40_SEED:-1181064378178512398}"
corpus="${WP40_CORPUS:-$script_dir/fixtures/t0_baseline_corpus.tsv}"
settings="$script_dir/fixtures/headless-baseline.conf"
results_root="${WP40_RESULTS_ROOT:-$script_dir/results/t0-baseline}"
if [[ "$results_root" != /* ]]; then
	results_root="$repo/$results_root"
fi
repetitions="${WP40_REPETITIONS:-1}"
affinity="${WP40_CPU_AFFINITY:-0-7}"
phase="${WP40_PHASE:-T0}"
comparison_role="${WP40_COMPARISON_ROLE:-post_wp43_wp18_wp36_baseline}"

if [[ ! "$repetitions" =~ ^[1-9][0-9]*$ ]]; then
	echo "WP40_REPETITIONS must be a positive integer" >&2
	exit 2
fi
for command_name in git jq sha256sum tar flatpak taskset timeout; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "T0 baseline: missing command $command_name" >&2
		exit 2
	fi
done
if ! git -C "$repo" cat-file -e "$checkout_sha^{commit}"; then
	echo "T0 baseline: checkout commit is unavailable: $checkout_sha" >&2
	exit 2
fi

mkdir -p "$results_root"
capture_root="$(mktemp -d -p /tmp grudgelands-wp40-t0.XXXXXXXX)"
cleanup() {
	if [[ "$capture_root" == /tmp/grudgelands-wp40-t0.* ]]; then
		rm -rf -- "$capture_root"
	fi
}
trap cleanup EXIT

host_json="$capture_root/host.json"
"$script_dir/collect_host.sh" "$repo" >"$host_json"

flatpak_info="$capture_root/flatpak-info.txt"
flatpak_version="$capture_root/flatpak-version.txt"
flatpak info org.luanti.luanti >"$flatpak_info"
flatpak run --command=luanti org.luanti.luanti --version >"$flatpak_version"
runtime_kind="bundled_lua51"
if rg -q 'Using LuaJIT' "$flatpak_version"; then
	runtime_kind="luajit"
fi

harness_digest="$({
	sha256sum "$script_dir/capture_t0_baseline.sh"
	sha256sum "$script_dir/collect_host.sh"
	sha256sum "$script_dir/runtime_probe/init.lua"
	sha256sum "$script_dir/runtime_probe/mod.conf"
} | sha256sum | awk '{print $1}')"
corpus_digest="$(sha256sum "$corpus" | awk '{print $1}')"
settings_digest="$(sha256sum "$settings" | awk '{print $1}')"
host_digest="$(sha256sum "$host_json" | awk '{print $1}')"
runtime_digest="$(sha256sum "$flatpak_version" | awk '{print $1}')"
capture_id="$({
	printf '%s\n' "wp40_t0_baseline_v1" "$base_sha" "$checkout_sha" \
		"$seed" \
		"$harness_digest" "$corpus_digest" "$settings_digest" \
		"$host_digest" "$runtime_digest" "$repetitions" "$affinity" \
		"$phase" "$comparison_role"
} | sha256sum | awk '{print $1}')"
result_dir="$results_root/$capture_id"
if [[ -e "$result_dir" ]]; then
	echo "T0 baseline: refusing to overwrite result $result_dir" >&2
	exit 2
fi
mkdir -p "$result_dir/raw"
cp "$host_json" "$result_dir/host.json"
cp "$flatpak_info" "$result_dir/raw/flatpak-info.txt"
cp "$flatpak_version" "$result_dir/raw/flatpak-version.txt"
cp "$corpus" "$result_dir/corpus.tsv"
cp "$settings" "$result_dir/settings.conf"

for ((run = 1; run <= repetitions; run++)); do
	run_name="$(printf 'run-%03d' "$run")"
	run_root="$(mktemp -d -p "$capture_root" "$run_name.XXXXXXXX")"
	user_path="$run_root/user"
	xdg_data="$run_root/xdg/data"
	xdg_config="$run_root/xdg/config"
	xdg_cache="$run_root/xdg/cache"
	game_dir="$user_path/games/grudgelands"
	world_dir="$run_root/world"
	mkdir -p "$game_dir" "$world_dir" "$user_path" "$xdg_data" \
		"$xdg_config" "$xdg_cache"
	git -C "$repo" archive "$checkout_sha" | tar -x -C "$game_dir"
	mkdir -p "$game_dir/mods/grug_wp40_probe"
	cp "$script_dir/runtime_probe/init.lua" \
		"$game_dir/mods/grug_wp40_probe/init.lua"
	cp "$script_dir/runtime_probe/mod.conf" \
		"$game_dir/mods/grug_wp40_probe/mod.conf"
	cat >"$world_dir/world.mt" <<'EOF'
gameid = grudgelands
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
EOF
	config="$run_root/luanti.conf"
	cp "$settings" "$config"
	cat >>"$config" <<EOF
fixed_map_seed = $seed
port = $((32000 + run))
grug_wp40_probe_output = $world_dir/probe.jsonl
grug_wp40_probe_corpus = $world_dir/corpus.tsv
grug_wp40_probe_seed = $seed
grug_wp40_probe_query_iterations = 100
grug_wp40_probe_timeout = 180
secure.trusted_mods = grug_wp40_probe
EOF
	cp "$corpus" "$world_dir/corpus.tsv"

	server_log="$result_dir/raw/$run_name.server.log"
	console_log="$result_dir/raw/$run_name.console.log"
	time_log="$result_dir/raw/$run_name.time.txt"
	set +e
	/usr/bin/time -v -o "$time_log" timeout --foreground --kill-after=10 240 \
		taskset -c "$affinity" \
		flatpak run --command=luanti \
		--filesystem="$run_root" \
		--filesystem="$result_dir" \
		--env="XDG_DATA_HOME=$xdg_data" \
		--env="XDG_CONFIG_HOME=$xdg_config" \
		--env="XDG_CACHE_HOME=$xdg_cache" \
		--env="LUANTI_USER_PATH=$user_path" \
		org.luanti.luanti --server --gameid grudgelands \
		--world "$world_dir" --config "$config" \
		--logfile "$server_log" --log-timestamp none --color never \
		>"$console_log" 2>&1
	run_status=$?
	set -e
	printf '%s\n' "$run_status" >"$result_dir/raw/$run_name.exit-status"
	if [[ $run_status -ne 0 ]]; then
		echo "T0 baseline: $run_name failed with status $run_status" >&2
		exit 1
	fi
	if [[ ! -s "$world_dir/probe.jsonl" ]] ||
			! jq -e -s 'any(.[]; .event == "complete") and
			(all(.[] | select(.event == "case");
			 ((.actions.cancelled // 0) == 0 and
			  (.actions.errored // 0) == 0)))' \
			"$world_dir/probe.jsonl" >/dev/null; then
		echo "T0 baseline: $run_name has incomplete or failed probe output" >&2
		exit 1
	fi
	cp "$world_dir/probe.jsonl" "$result_dir/raw/$run_name.probe.jsonl"
	cp "$world_dir/map_meta.txt" "$result_dir/raw/$run_name.map_meta.txt"
done

jq -s --arg schema "wp40_t0_raw_summary_v1" '
	[.[] | select(.event == "case")] as $cases |
	{schema: $schema,
	 runs: ([.[] | select(.event == "complete")] | length),
	 cases: ($cases | group_by(.id) | map({
	   id: .[0].id,
	   samples: length,
	   emerge_us: map(.emerge_us),
	   compatibility_query_us: map(.query_us),
	   compatibility_query_count: map(.compatibility_queries),
	   actions: map(.actions),
	   process: map(.process)
	 }))}' "$result_dir"/raw/run-*.probe.jsonl >"$result_dir/summary.json"

observed_cpu="$(jq -r '.cpu.model' "$result_dir/host.json")"
observed_physical="$(jq -r '.cpu.physical_cores' "$result_dir/host.json")"
observed_logical="$(jq -r '.cpu.logical_cpus' "$result_dir/host.json")"
observed_governor="$(jq -r '.cpu.governor' "$result_dir/host.json")"
host_gate="pass"
if [[ "$observed_cpu" != *"AMD Ryzen 7 9800X3D"* ]] ||
		[[ "$observed_physical" != "8" ]] ||
		[[ "$observed_logical" != "16" ]] ||
		[[ "$observed_governor" != "performance" ]] ||
		! jq -e '.. | strings | select(contains("WD_BLACK SN850X"))' \
			"$result_dir/host.json" >/dev/null; then
	host_gate="fail"
fi

map_meta_digest="$(sha256sum "$result_dir/raw/run-001.map_meta.txt" |
	awk '{print $1}')"
jq -n \
	--arg schema "wp40_benchmark_manifest_v1" \
	--arg phase "$phase" \
	--arg capture_id "$capture_id" \
	--arg base_sha "$base_sha" \
	--arg checkout_sha "$checkout_sha" \
	--arg comparison_role "$comparison_role" \
	--arg seed "$seed" \
	--arg host_gate "$host_gate" \
	--arg harness_digest "$harness_digest" \
	--arg corpus_digest "$corpus_digest" \
	--arg settings_digest "$settings_digest" \
	--arg map_meta_digest "$map_meta_digest" \
	--arg runtime_kind "$runtime_kind" \
	--arg runtime_digest "$runtime_digest" \
	--arg affinity "$affinity" \
	--argjson repetitions "$repetitions" \
	'{schema: $schema, phase: $phase, capture_id: $capture_id,
	 status: "raw_capture_complete",
	 comparison_role: $comparison_role,
	 commits: {baseline: $base_sha, checkout: $checkout_sha},
	 seed: {decimal_string: $seed, converted_to_lua_number: false},
	 host: {manifest: "host.json", gate: $host_gate,
	   designated: {cpu: "AMD Ryzen 7 9800X3D", physical_cores: 8,
	     logical_cpus: 16, memory: "58 GiB OS-visible",
	     storage: "WD_BLACK SN850X 2 TB encrypted ext4",
	     os: "Fedora Linux 44", governor: "performance"}},
	 harness: {digest: $harness_digest,
	   command: "tools/wp40/capture_t0_baseline.sh",
	   repetitions: $repetitions, cpu_affinity: $affinity,
	   controlled_shutdown: "core.request_shutdown after complete event",
	   observed_engine_exit_status: 0,
	   harness_exit_2: "preflight or immutable-result overwrite refusal; never a successful controlled shutdown"},
	 runtime: {kind: $runtime_kind, version_raw: "raw/flatpak-version.txt",
	   version_digest: $runtime_digest,
	   installed_flatpak: "5.16.1",
	   pinned_source_reference: "Luanti 5.17.0-dev df04879066de6eb94ca43996822a6dfacc74feca",
	   version_match: false},
	 settings: {source: "settings.conf", digest: $settings_digest,
	   realized_map_meta: "raw/run-001.map_meta.txt",
	   realized_map_meta_digest: $map_meta_digest,
	   production_emerge_threads: 1},
	 cache: {process: "new_process_new_disposable_world",
	   filesystem_page_cache: "unknown_uncontrolled",
	   cold_cache_claim: false},
	 corpus: {source: "corpus.tsv", digest: $corpus_digest,
	   kind: "t0_legacy_substrate",
	   chapter6_final: false,
	   replacement_gate: "T2 geometry-derived fixture required before T9 replay"},
	 raw_paths: {samples: "raw/run-*.probe.jsonl",
	   server_logs: "raw/run-*.server.log",
	   launcher_metrics: "raw/run-*.time.txt",
	   process_metrics: "raw/run-*.probe.jsonl",
	   summary: "summary.json"},
	 instrumentation: {clock: "core.get_us_time",
	   process_cpu: "insecure os.clock in trusted disposable probe",
	   process_memory: "/proc/self/status VmRSS/VmHWM/VmSize",
	   lua_heap: "collectgarbage count",
	   launcher_metrics_note: "GNU time observes the Flatpak launcher, not the engine process; engine memory/CPU values come from probe JSONL"},
	 limitations: [
	   "Flatpak runtime is LuaJIT only; bundled Lua 5.1 engine measurements remain required.",
	   "Installed Luanti 5.16.1 differs from the pinned 5.17.0-dev source checkout.",
	   "Filesystem page-cache state is uncontrolled and is not cold-cache evidence.",
	   "T2 has not yet frozen the final microcorpus or 100-requester trace; this T0 corpus cannot satisfy those T9 gates."
	 ]}' >"$result_dir/manifest.json"

(
	cd "$result_dir"
	find . -type f ! -name checksums.sha256 -print0 | sort -z |
		xargs -0 sha256sum >checksums.sha256
)

if [[ "$host_gate" != "pass" ]]; then
	echo "T0 baseline: capture complete but designated-host gate failed" >&2
	exit 1
fi

echo "$result_dir"
