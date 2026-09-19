#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$script_dir/../../.." && pwd -P)"
[[ "$#" -ge 1 ]] || {
	echo "usage: run.sh ENGINE_OR_LAUNCHER [LAUNCHER_ARGS ...]" >&2
	exit 2
}
engine=("$@")

for command_name in awk bash cp find mkdir mktemp patch rg rm sha256sum sort \
	tar timeout uname wc xargs; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "WP40 profile: missing command $command_name" >&2
		exit 2
	}
done

seed="${WP40_PROFILE_SEED:-0}"
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "WP40 profile: WP40_PROFILE_SEED must be canonical nonnegative decimal" >&2
	exit 2
}
phase_timeout="${WP40_PROFILE_TIMEOUT:-900}"
if [[ ! "$phase_timeout" =~ ^[1-9][0-9]*$ ]] ||
		(( phase_timeout > 3600 )); then
	echo "WP40 profile: WP40_PROFILE_TIMEOUT must be 1..3600 seconds" >&2
	exit 2
fi
port_base="${WP40_PROFILE_PORT_BASE:-32160}"
if [[ ! "$port_base" =~ ^[1-9][0-9]*$ ]] ||
		(( port_base < 32160 || port_base > 65534 )); then
	echo "WP40 profile: WP40_PROFILE_PORT_BASE must be 32160..65534" >&2
	exit 2
fi
dedicated="${WP40_PROFILE_DEDICATED:-0}"
[[ "$dedicated" == "0" || "$dedicated" == "1" ]] || {
	echo "WP40 profile: WP40_PROFILE_DEDICATED must be 0 or 1" >&2
	exit 2
}
server_args=(--server)
if [[ "$dedicated" == "1" ]]; then server_args=(); fi
stages="${WP40_PROFILE_STAGES:-0}"
[[ "$stages" == "0" || "$stages" == "1" ]] || {
	echo "WP40 profile: WP40_PROFILE_STAGES must be 0 or 1" >&2
	exit 2
}
full_digest="${WP40_PROFILE_FULL_DIGEST:-0}"
[[ "$full_digest" == "0" || "$full_digest" == "1" ]] || {
	echo "WP40 profile: WP40_PROFILE_FULL_DIGEST must be 0 or 1" >&2
	exit 2
}

scratch="$(mktemp -d /tmp/grudgelands-wp40-profile-run.XXXXXXXX)"
result_dir="${WP40_PROFILE_OUTPUT:-}"
if [[ -n "$result_dir" ]]; then
	[[ "$result_dir" = /* && ! -e "$result_dir" ]] || {
		echo "WP40 profile: WP40_PROFILE_OUTPUT must be an absent absolute path" >&2
		exit 2
	}
	mkdir -p "$result_dir"
else
	result_dir="$(mktemp -d /tmp/grudgelands-wp40-profile-result.XXXXXXXX)"
fi
cleanup() {
	case "$scratch" in
	/tmp/grudgelands-wp40-profile-run.*) rm -rf -- "$scratch" ;;
	esac
}
trap 'exit 130' HUP INT TERM
trap cleanup EXIT

source_game="${WP40_PROFILE_GAME_ROOT:-$repo}"
archive="${WP40_PROFILE_GAME_ARCHIVE:-}"
if [[ -n "$archive" ]]; then
	[[ -f "$archive" && "${WP40_PROFILE_GAME_ROOT:-}" == "" ]] || {
		echo "WP40 profile: archive must exist and cannot be combined with GAME_ROOT" >&2
		exit 2
	}
	mkdir "$scratch/archive"
	tar -xf "$archive" -C "$scratch/archive"
	mapfile -t game_roots < <(find "$scratch/archive" -maxdepth 3 -type f \
		-name game.conf -printf '%h\n' | sort -u)
	[[ "${#game_roots[@]}" -eq 1 ]] || {
		echo "WP40 profile: archive must contain exactly one shallow game.conf" >&2
		exit 2
	}
	source_game="${game_roots[0]}"
fi
[[ -f "$source_game/game.conf" && -d "$source_game/mods" ]] || {
	echo "WP40 profile: source game lacks game.conf or mods" >&2
	exit 2
}

user_path="$scratch/user"
game_dir="$user_path/games/grudgelands"
world_dir="$scratch/world"
mkdir -p "$game_dir" "$world_dir" "$result_dir/cold" "$result_dir/disk"
cp -a "$source_game/game.conf" "$source_game/mods" "$game_dir/"
for optional in menu minetest.conf settingtypes.txt textures; do
	if [[ -e "$source_game/$optional" ]]; then
		cp -a "$source_game/$optional" "$game_dir/"
	fi
done
bash "$script_dir/patch_snapshot.sh" "$game_dir"
if [[ "$stages" == "1" ]]; then
	bash "$script_dir/patch_settlement_stages.sh" "$game_dir"
fi
cases_file="${WP40_PROFILE_CASES:-$script_dir/probe/cases.lua}"
[[ "$cases_file" = /* && -f "$cases_file" && -r "$cases_file" ]] || {
	echo "WP40 profile: cases must be an absolute readable Lua file" >&2
	exit 2
}
cp -a "$script_dir/probe" "$game_dir/mods/grug_wp40_profile_probe"
cp -- "$cases_file" "$game_dir/mods/grug_wp40_profile_probe/cases.lua"

(
	cd "$game_dir"
	find . -type f -print0 | sort -z | xargs -0 sha256sum
) >"$result_dir/snapshot-files.sha256"
sha256sum "$result_dir/snapshot-files.sha256" >"$result_dir/snapshot.digest"
sha256sum "$script_dir/run.sh" "$script_dir/patch_snapshot.sh" \
	"$script_dir/instrument-mapgen.patch" "$script_dir/probe/init.lua" \
	"$cases_file" "$script_dir/probe/mod.conf" \
	"$script_dir/summarize_callbacks.awk" "$script_dir/patch_settlement_stages.sh" \
	"$script_dir/instrument-settlement-stages.patch" \
	>"$result_dir/harness.sha256"

cat >"$world_dir/world.mt" <<EOF
gameid = grudgelands
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
load_mod_grug_wp40_profile_probe = true
EOF

{
	printf 'kernel\t%s\n' "$(uname -srmo)"
	printf 'processors\t%s\n' "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"
	awk '/^MemTotal:/ {print "memory_kib\t" $2}' /proc/meminfo 2>/dev/null || true
	printf 'seed\t%s\n' "$seed"
	printf 'cases_file\t%s\n' "$cases_file"
	printf 'port_base\t%s\n' "$port_base"
	printf 'phase_timeout_seconds\t%s\n' "$phase_timeout"
	printf 'dedicated_binary\t%s\n' "$dedicated"
	printf 'settlement_stages\t%s\n' "$stages"
	printf 'full_digest\t%s\n' "$full_digest"
	printf 'source_game\t%s\n' "$source_game"
	printf 'source_archive\t%s\n' "$archive"
	printf 'luanti_user_path\t%s\n' "$user_path"
} >"$result_dir/environment.tsv"

set +e
LUANTI_USER_PATH="$user_path" "${engine[@]}" --version \
	>"$result_dir/engine-version.txt" 2>&1
version_status=$?
set -e
[[ $version_status -eq 0 ]] || {
	echo "WP40 profile: launcher failed its --version preflight" >&2
	exit 1
}
rg -q '5\.17\.' "$result_dir/engine-version.txt" || {
	echo "WP40 profile: launcher is not Luanti 5.17.x" >&2
	exit 1
}

{
	printf 'LUANTI_USER_PATH=%q' "$user_path"
	for argument in "${engine[@]}"; do printf ' %q' "$argument"; done
	for argument in "${server_args[@]}"; do printf ' %q' "$argument"; done
	printf ' --gameid grudgelands --world %q --config PHASE.conf\n' \
		"$world_dir"
} >"$result_dir/invocation.txt"

run_phase() {
	local phase="$1"
	local port="$2"
	local output="$result_dir/$phase"
	local config="$scratch/$phase.conf"
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
liquid_update = 3631
dedicated_server_step = 0.05
server_map_save_interval = 1
max_block_generate_distance = 5
max_block_send_distance = 5
active_block_range = 4
server_announce = false
enable_ipv6 = false
bind_address = 127.0.0.1
port = $port
secure.enable_security = true
deprecated_lua_api_handling = error
debug_log_level = info
profiler.load = false
profiler_print_interval = 1
server_unload_unused_data_timeout = 3600
grug_wp40_profile_phase = $phase
grug_wp40_profile_seed = $seed
grug_wp40_profile_probe_timeout = $phase_timeout
grug_wp40_profile_full_digest = $([[ "$full_digest" == "1" ]] && printf true || printf false)
EOF
	cp "$config" "$output/luanti.conf"
	cp "$world_dir/world.mt" "$output/world.mt"
	local host_timeout=$((phase_timeout + 20))
	local command_prefix=()
	if command -v chrt >/dev/null 2>&1 && command -v ionice >/dev/null 2>&1; then
		command_prefix=(chrt --idle 0 ionice -c3)
	fi
	set +e
	LUANTI_USER_PATH="$user_path" timeout --foreground --kill-after=10 \
		"$host_timeout" "${command_prefix[@]}" "${engine[@]}" \
		"${server_args[@]}" \
		--gameid grudgelands --world "$world_dir" --config "$config" \
		--logfile "$output/server.log" --log-timestamp none --color never \
		>"$output/console.log" 2>&1
	local status=$?
	set -e
	printf '%s\n' "$status" >"$output/exit-status"
	[[ $status -eq 0 ]] || {
		echo "WP40 profile: $phase engine process exited with $status" >&2
		return 1
	}
	rg 'GRUG_WP40_PROFILE_(CALLBACK|PROBE|STAGE)' "$output/server.log" \
		>"$output/profile-events.log" || true
	awk -f "$script_dir/summarize_callbacks.awk" "$output/server.log" \
		>"$output/callback-summary.tsv"
	rg 'EmergeThread|Server::RunStep|Server: map saving|Profiler' \
		"$output/server.log" >"$output/native-profiler.log" || true
	set +e
	rg -n -i '(^|[^[:alpha:]])(ERROR|LuaError|FATAL|assertion failed|stack traceback|segmentation fault|SIGABRT)([^[:alpha:]]|$)' \
		"$output/server.log" "$output/console.log" >"$output/errors.log"
	local error_scan=$?
	set -e
	[[ $error_scan -eq 1 ]] || {
		echo "WP40 profile: $phase error scan found failures or itself failed" >&2
		return 1
	}
}

run_phase cold "$port_base"
run_phase disk "$((port_base + 1))"

field() {
	local line="$1"
	local name="$2"
	awk -v wanted="$name" '{for (i = 1; i <= NF; i++) {
		split($i, pair, "="); if (pair[1] == wanted) {print pair[2]; exit}}}' \
		<<<"$line"
}
complete_line() {
	local phase="$1"
	rg 'GRUG_WP40_PROFILE_PROBE .*event=complete' \
		"$result_dir/$phase/server.log"
}
cold_complete="$(complete_line cold)"
disk_complete="$(complete_line disk)"
[[ "$(printf '%s\n' "$cold_complete" | wc -l)" -eq 1 &&
	"$(printf '%s\n' "$disk_complete" | wc -l)" -eq 1 ]] || {
	echo "WP40 profile: each phase must emit exactly one completion record" >&2
	exit 1
}
cold_callbacks="$(field "$cold_complete" callbacks)"
disk_callbacks="$(field "$disk_complete" callbacks)"
cold_callback_lines="$(rg -c 'GRUG_WP40_PROFILE_CALLBACK' \
	"$result_dir/cold/server.log" || true)"
disk_callback_lines="$(rg -c 'GRUG_WP40_PROFILE_CALLBACK' \
	"$result_dir/disk/server.log" || true)"
[[ "$(field "$cold_complete" generated)" -gt 0 &&
	"$(field "$cold_complete" disk)" -eq 0 &&
	"$(field "$cold_complete" cancelled)" -eq 0 &&
	"$(field "$cold_complete" errored)" -eq 0 &&
	"$cold_callbacks" -gt 0 && "$cold_callback_lines" -eq "$cold_callbacks" ]] || {
	echo "WP40 profile: cold phase did not prove clean generated callbacks" >&2
	exit 1
}
[[ "$(field "$disk_complete" generated)" -eq 0 &&
	"$(field "$disk_complete" disk)" -gt 0 &&
	"$(field "$disk_complete" cancelled)" -eq 0 &&
	"$(field "$disk_complete" errored)" -eq 0 &&
	"$disk_callbacks" -eq 0 && "$disk_callback_lines" -eq 0 ]] || {
	echo "WP40 profile: restart phase did not prove DISK-only loading" >&2
	exit 1
}
cold_digest="$(field "$cold_complete" digest)"
disk_digest="$(field "$disk_complete" digest)"
[[ "$cold_digest" =~ ^[0-9a-f]{64}$ && "$cold_digest" == "$disk_digest" ]] || {
	echo "WP40 profile: post-timing sample digests differ" >&2
	exit 1
}
cold_full_digest="$(field "$cold_complete" full_digest)"
disk_full_digest="$(field "$disk_complete" full_digest)"
cold_vocabulary_digest="$(field "$cold_complete" full_vocabulary_digest)"
disk_vocabulary_digest="$(field "$disk_complete" full_vocabulary_digest)"
cold_full_voxels="$(field "$cold_complete" full_voxels)"
disk_full_voxels="$(field "$disk_complete" full_voxels)"
if [[ "$full_digest" == "1" ]]; then
	[[ "$cold_full_digest" =~ ^[0-9a-f]{64}$ &&
		"$cold_full_digest" == "$disk_full_digest" &&
		"$cold_vocabulary_digest" =~ ^[0-9a-f]{64}$ &&
		"$cold_vocabulary_digest" == "$disk_vocabulary_digest" &&
		"$(field "$cold_complete" full_owners)" -eq "$cold_callbacks" &&
		"$(field "$disk_complete" full_owners)" -eq "$cold_callbacks" &&
		"$cold_full_voxels" -eq "$((cold_callbacks * 512000))" &&
		"$disk_full_voxels" -eq "$cold_full_voxels" ]] || {
		echo "WP40 profile: post-timing full owner digests differ" >&2
		exit 1
	}
else
	[[ "$cold_full_digest" == "disabled" &&
		"$disk_full_digest" == "disabled" &&
		"$cold_vocabulary_digest" == "-" &&
		"$disk_vocabulary_digest" == "-" &&
		"$cold_full_voxels" -eq 0 && "$disk_full_voxels" -eq 0 ]] || {
		echo "WP40 profile: disabled full digest fields differ" >&2
		exit 1
	}
fi
[[ -s "$result_dir/cold/native-profiler.log" &&
	-s "$result_dir/disk/native-profiler.log" ]] || {
	echo "WP40 profile: native profiler output is absent" >&2
	exit 1
}
{
	printf 'schema\tgrug_wp40_real_engine_profile_v2\n'
	printf 'cold_generated_blocks\t%s\n' "$(field "$cold_complete" generated)"
	printf 'cold_mapgen_callbacks\t%s\n' "$cold_callbacks"
	printf 'disk_loaded_blocks\t%s\n' "$(field "$disk_complete" disk)"
	printf 'disk_mapgen_callbacks\t%s\n' "$disk_callbacks"
	printf 'sample_digest\t%s\n' "$cold_digest"
	printf 'full_digest\t%s\n' "$cold_full_digest"
	printf 'full_vocabulary_digest\t%s\n' "$cold_vocabulary_digest"
	printf 'full_voxels\t%s\n' "$cold_full_voxels"
	printf 'full_owners\t%s\n' "$(field "$cold_complete" full_owners)"
	printf 'snapshot_manifest_sha256\t%s\n' \
		"$(awk '{print $1}' "$result_dir/snapshot.digest")"
} >"$result_dir/summary.tsv"

printf 'WP40 real-engine profile PASS result=%s\n' "$result_dir"
