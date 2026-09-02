#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verifier="$script_dir/verify_log.sh"
engine_regex='^5[.]16[.][0-9]+$'
game_commit="1111111111111111111111111111111111111111"
probe_digest="2222222222222222222222222222222222222222222222222222222222222222"
manifest_digest="3333333333333333333333333333333333333333333333333333333333333333"

scratch="$(mktemp -d /tmp/grudgelands-wp40-dungeon-json-test.XXXXXX)"
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-dungeon-json-test.*) rm -rf -- "$scratch" ;;
		*) echo "refusing unsafe cleanup path: $scratch" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

valid="$scratch/valid.log"
printf '%s\n' \
'fixture DUNGEON_PROBE_JSON {"tag":"main_api","engine_version":"5.16.1","requested_mapchunks":81,"seed":"40200517","mg_name":"v7","mg_flags":"caves, dungeons, light, decorations, biomes, ores","mgv7_spflags":"mountains, ridges, nofloatlands, caverns","chunksize":"5","water_level":"1","mgv7_dungeon_ymin":"-31000","mgv7_dungeon_ymax":"-193","mgv7_np_dungeons":"0.9|0.5|500|500|500|0|2|0.8|2|defaults"}' \
'fixture DUNGEON_PROBE_JSON {"tag":"mapgen_api","get_data":"function","get_emerged_area":"function","get_param2_data":"function","get_node_at":"function","get_flags":"nil","get_voxel_flags":"nil","get_dungeon_flags":"nil","gennotify_type":"table"}' \
'fixture DUNGEON_PROBE_JSON {"tag":"dungeon_event","blockseed":42,"minp":{"x":-32,"y":-272,"z":-32},"maxp":{"x":47,"y":-193,"z":47},"emerged_minp":{"x":-48,"y":-288,"z":-48},"emerged_maxp":{"x":63,"y":-177,"z":63},"room_count":1,"first_room":{"position":{"x":0,"y":-220,"z":0},"center":{"name":"air","param1":0,"param2":0},"above":{"name":"air","param1":0,"param2":0},"below":{"name":"default:cobble","param1":0,"param2":0}}}' \
'fixture DUNGEON_PROBE_JSON {"tag":"complete","requested_mapchunks":81}' \
	> "$valid"

"$verifier" "$valid" "$scratch/valid-summary.json" "$engine_regex" \
	"$game_commit" "$probe_digest" "$manifest_digest" >/dev/null
jq -e '.schema == 2 and .json_validation == "complete-jq" and .positive_callbacks == 1' \
	"$scratch/valid-summary.json" >/dev/null

cp "$valid" "$scratch/broken-json.log"
printf '%s\n' 'fixture DUNGEON_PROBE_JSON {"tag":"BROKEN",}' \
	>> "$scratch/broken-json.log"
if "$verifier" "$scratch/broken-json.log" "$scratch/broken-summary.json" \
	"$engine_regex" "$game_commit" "$probe_digest" "$manifest_digest" \
	>/dev/null 2>&1; then
	echo "error: malformed BROKEN JSON fixture passed verification" >&2
	exit 1
fi

awk -v marker='DUNGEON_PROBE_JSON ' '
	{
		at = index($0, marker)
		if (at > 0)
			print substr($0, at + length(marker))
	}
' "$valid" | jq -c '
	if .tag == "dungeon_event" then del(.emerged_minp.z) else . end
' | sed 's/^/fixture DUNGEON_PROBE_JSON /' > "$scratch/broken-vector.log"
if "$verifier" "$scratch/broken-vector.log" "$scratch/vector-summary.json" \
	"$engine_regex" "$game_commit" "$probe_digest" "$manifest_digest" \
	>/dev/null 2>&1; then
	echo "error: malformed vector-shape fixture passed verification" >&2
	exit 1
fi

echo "WP40 dungeon JSON verifier fixtures: PASS"
echo "- complete valid record stream and generated summary parse as JSON"
echo "- malformed BROKEN JSON and missing-vector-component fixtures fail closed"
