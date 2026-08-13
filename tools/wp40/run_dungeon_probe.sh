#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
lua51="$repo_root/tools/bin/lua51"
luac51="$repo_root/tools/bin/luac51"
probe_dir="$repo_root/tools/wp40/dungeon_probe"
# shellcheck source=/dev/null
source "$probe_dir/digest_lib.sh"

if [[ ! -x "$lua51" || ! -x "$luac51" ]]; then
	echo "error: tools/bin/lua51 and tools/bin/luac51 are required" >&2
	exit 1
fi
command -v jq >/dev/null || {
	echo "error: jq is required for complete dungeon-probe JSON validation" >&2
	exit 1
}

"$luac51" -p "$probe_dir/init.lua"
"$luac51" -p "$probe_dir/mapgen.lua"
"$luac51" -p "$probe_dir/source_audit.lua"
"$luac51" -p "$probe_dir/lattice_audit.lua"
"$lua51" "$probe_dir/source_audit.lua" "$repo_root"
"$lua51" "$probe_dir/lattice_audit.lua" "$repo_root"
bash "$probe_dir/digest_audit.sh"
bash "$probe_dir/verify_log_test.sh"

if [[ "${WP40_DUNGEON_PROBE_HEADLESS:-0}" != "1" ]]; then
	echo "Headless probe skipped; set WP40_DUNGEON_PROBE_HEADLESS=1 to run it."
	exit 0
fi

command -v flatpak >/dev/null || {
	echo "error: flatpak is required for the headless probe" >&2
	exit 1
}

temp_root="$(mktemp -d /tmp/grudgelands-wp40-dungeon-probe.XXXXXX)"
cleanup() {
	case "$temp_root" in
		/tmp/grudgelands-wp40-dungeon-probe.*) rm -rf -- "$temp_root" ;;
		*) echo "refusing unsafe cleanup path: $temp_root" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

user_root="$temp_root/user"
game_root="$user_root/games/grudgelands"
world_root="$user_root/worlds/wp40_dungeon_probe"
config_root="$temp_root/config"
cache_root="$temp_root/cache"
data_root="$temp_root/data"
raw_log="$temp_root/dungeon-probe.raw.log"
summary_json="$temp_root/summary.json"
mkdir -p "$game_root" "$world_root" "$config_root" "$cache_root" "$data_root"

game_archive_base="$(git -C "$repo_root" rev-parse HEAD)"
probe_digest="$(wp40_probe_payload_digest "$probe_dir")"
expected_version_pattern="${WP40_DUNGEON_PROBE_ENGINE_PATTERN:-^5[.]16[.][0-9]+$}"

git -C "$repo_root" archive HEAD | tar -x -C "$game_root"
mkdir -p "$game_root/mods/grug_wp40_dungeon_probe"
cp "$probe_dir/mod.conf" "$probe_dir/init.lua" "$probe_dir/mapgen.lua" \
	"$game_root/mods/grug_wp40_dungeon_probe/"
injected_digest="$(wp40_probe_payload_digest \
	"$game_root/mods/grug_wp40_dungeon_probe")"
if [[ "$injected_digest" != "$probe_digest" ]]; then
	echo "error: current working-tree probe was not injected into archived game" >&2
	exit 1
fi

printf '%s\n' \
	"gameid = grudgelands" \
	"backend = sqlite3" \
	"creative_mode = true" \
	"enable_damage = false" \
	"server_announce = false" \
	> "$world_root/world.mt"

printf '%s\n' \
	"fixed_map_seed = 40200517" \
	"mg_name = v7" \
	"chunksize = 5" \
	"water_level = 1" \
	"num_emerge_threads = 1" \
	"mg_flags = caves,dungeons,light,decorations,biomes,ores" \
	"mgv7_spflags = mountains,ridges,caverns" \
	"mgv7_dungeon_ymin = -31000" \
	"mgv7_dungeon_ymax = -193" \
	"mgv7_np_dungeons = 0.9, 0.5, (500, 500, 500), 0, 2, 0.8, 2.0" \
	"server_announce = false" \
	"enable_ipv6 = false" \
	"bind_address = 127.0.0.1" \
	"port = 30142" \
	> "$config_root/minetest.conf"

manifest_digest="$(wp40_manifest_digest "$game_archive_base" "$probe_digest" \
	"$expected_version_pattern" "$config_root/minetest.conf")"

echo "Running isolated Flatpak headless probe in $temp_root"
echo "Game archive base: $game_archive_base"
echo "Injected working-tree probe digest: $probe_digest"
echo "Evidence manifest digest: $manifest_digest"
set +e
timeout 180 flatpak run \
	--command=luanti \
	--filesystem="$temp_root" \
	--env="LUANTI_USER_PATH=$user_root" \
	--env="XDG_CONFIG_HOME=$config_root" \
	--env="XDG_CACHE_HOME=$cache_root" \
	--env="XDG_DATA_HOME=$data_root" \
	org.luanti.luanti \
	--server \
	--world "$world_root" \
	--config "$config_root/minetest.conf" \
	--terminal \
	> "$raw_log" 2>&1
runtime_status=$?
set -e

if [[ "$runtime_status" -ne 0 ]]; then
	echo "error: headless probe exited with status $runtime_status" >&2
	tail -n 80 "$raw_log" >&2
	exit "$runtime_status"
fi

set +e
bash "$probe_dir/verify_log.sh" \
	"$raw_log" \
	"$summary_json" \
	"$expected_version_pattern" \
	"$game_archive_base" \
	"$probe_digest" \
	"$manifest_digest"
verify_status=$?
set -e
if [[ "$verify_status" -ne 0 ]]; then
	echo "error: runtime evidence verification failed" >&2
	tail -n 80 "$raw_log" >&2
	exit "$verify_status"
fi

evidence_dir="$probe_dir/evidence/$manifest_digest"
mkdir -p "$evidence_dir"
cp "$raw_log" "$evidence_dir/raw.log"
cp "$summary_json" "$evidence_dir/summary.json"
cp "$config_root/minetest.conf" "$evidence_dir/minetest.conf"
echo "Accepted evidence preserved at $evidence_dir"
