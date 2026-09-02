#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 6 ]]; then
	echo "usage: verify_log.sh RAW_LOG SUMMARY_JSON ENGINE_REGEX GAME_COMMIT PROBE_DIGEST MANIFEST_DIGEST" >&2
	exit 2
fi

raw_log="$1"
summary_json="$2"
expected_engine_regex="$3"
game_archive_base="$4"
probe_digest="$5"
manifest_digest="$6"

command -v jq >/dev/null || {
	echo "error: jq is required for complete dungeon-probe JSON validation" >&2
	exit 1
}

scratch="$(mktemp -d /tmp/grudgelands-wp40-dungeon-json.XXXXXX)"
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-dungeon-json.*) rm -rf -- "$scratch" ;;
		*) echo "refusing unsafe cleanup path: $scratch" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

extracted="$scratch/extracted.jsonl"
canonical="$scratch/canonical.jsonl"
marker='DUNGEON_PROBE_JSON '
awk -v marker="$marker" '
	{
		at = index($0, marker)
		if (at > 0)
			print substr($0, at + length(marker))
	}
' "$raw_log" > "$extracted"

if [[ ! -s "$extracted" ]]; then
	echo "error: no DUNGEON_PROBE_JSON records" >&2
	exit 1
fi

# jq parses the complete payload. Trailing garbage, truncated objects and any
# other malformed JSON fail here before a field-level assertion runs.
jq -ce 'if type == "object" then . else error("record is not an object") end' \
	"$extracted" > "$canonical"

jq -se \
	--arg engine_regex "$expected_engine_regex" \
'
	def is_integer: type == "number" and . == floor;
	def exact_keys($wanted): (keys | sort) == ($wanted | sort);
	def vector:
		type == "object" and exact_keys(["x", "y", "z"]) and
		(.x | is_integer) and (.y | is_integer) and (.z | is_integer);
	def node_sample:
		type == "object" and exact_keys(["name", "param1", "param2"]) and
		(.name | type == "string") and
		(.param1 | is_integer and . >= 0 and . <= 255) and
		(.param2 | is_integer and . >= 0 and . <= 255);
	def trim: gsub("^[[:space:]]+|[[:space:]]+$"; "");
	def flag_set: split(",") | map(trim) | sort;
	def valid_main:
		exact_keys(["tag", "engine_version", "requested_mapchunks", "seed",
			"mg_name", "mg_flags", "mgv7_spflags", "chunksize", "water_level",
			"mgv7_dungeon_ymin", "mgv7_dungeon_ymax", "mgv7_np_dungeons"]) and
		.tag == "main_api" and (.engine_version | type == "string" and test($engine_regex)) and
		(.requested_mapchunks | is_integer and . == 81) and
		(.seed | type == "string" and . == "40200517") and
		.mg_name == "v7" and .chunksize == "5" and .water_level == "1" and
		.mgv7_dungeon_ymin == "-31000" and .mgv7_dungeon_ymax == "-193" and
		(.mg_flags | type == "string" and flag_set ==
			["biomes", "caves", "decorations", "dungeons", "light", "ores"]) and
		(.mgv7_spflags | type == "string" and flag_set ==
			["caverns", "mountains", "nofloatlands", "ridges"]) and
		.mgv7_np_dungeons == "0.9|0.5|500|500|500|0|2|0.8|2|defaults";
	def valid_mapgen:
		exact_keys(["tag", "get_data", "get_emerged_area", "get_param2_data",
			"get_node_at", "get_flags", "get_voxel_flags", "get_dungeon_flags",
			"gennotify_type"]) and
		.tag == "mapgen_api" and .get_data == "function" and
		.get_emerged_area == "function" and .get_param2_data == "function" and
		.get_node_at == "function" and .get_flags == "nil" and
		.get_voxel_flags == "nil" and .get_dungeon_flags == "nil" and
		.gennotify_type == "table";
	def valid_node_event:
		exact_keys(["tag", "blockseed", "minp", "maxp", "emerged_minp",
			"emerged_maxp", "room_count", "first_room"]) and
		.tag == "dungeon_event" and
		(.blockseed | is_integer and . >= 0 and . <= 4294967295) and
		(.room_count | is_integer and . >= 1) and
		(.minp | vector) and (.maxp | vector) and
		(.emerged_minp | vector) and (.emerged_maxp | vector) and
		(.first_room | type == "object" and
			exact_keys(["position", "center", "above", "below"]) and
			(.position | vector) and (.center | node_sample) and
			(.above | node_sample) and (.below | node_sample)) and
		(.maxp.x - .minp.x == 79) and (.maxp.y - .minp.y == 79) and
		(.maxp.z - .minp.z == 79) and
		(.emerged_minp.x == .minp.x - 16) and
		(.emerged_minp.y == .minp.y - 16) and
		(.emerged_minp.z == .minp.z - 16) and
		(.emerged_maxp.x == .maxp.x + 16) and
		(.emerged_maxp.y == .maxp.y + 16) and
		(.emerged_maxp.z == .maxp.z + 16) and
		(.first_room.position.x >= .emerged_minp.x and
			.first_room.position.x <= .emerged_maxp.x) and
		(.first_room.position.y >= .emerged_minp.y and
			.first_room.position.y <= .emerged_maxp.y) and
		(.first_room.position.z >= .emerged_minp.z and
			.first_room.position.z <= .emerged_maxp.z);
	def valid_complete:
		exact_keys(["tag", "requested_mapchunks"]) and .tag == "complete" and
		(.requested_mapchunks | is_integer and . == 81);
	def valid_error:
		exact_keys(["tag", "action", "position"]) and .tag == "emerge_error" and
		(.action | is_integer) and (.position | vector);
	def valid_record:
		type == "object" and (.tag | type == "string") and
		if .tag == "main_api" then valid_main
		elif .tag == "mapgen_api" then valid_mapgen
		elif .tag == "dungeon_event" then valid_node_event
		elif .tag == "complete" then valid_complete
		elif .tag == "emerge_error" then valid_error
		else false
		end;

	length > 0 and all(.[]; valid_record) and
	([.[] | select(.tag == "main_api")] | length == 1) and
	([.[] | select(.tag == "mapgen_api")] | length == 1) and
	([.[] | select(.tag == "complete")] | length == 1) and
	([.[] | select(.tag == "emerge_error")] | length == 0) and
	([.[] | select(.tag == "dungeon_event")] | length >= 1) and
	(.[-1].tag == "complete")
' "$canonical" >/dev/null

engine_version="$(jq -sr '[.[] | select(.tag == "main_api")][0].engine_version' "$canonical")"
positive_callbacks="$(jq -sr '[.[] | select(.tag == "dungeon_event")] | length' "$canonical")"
record_count="$(jq -sr 'length' "$canonical")"

jq -nc \
	--arg engine_version "$engine_version" \
	--arg expected_engine_regex "$expected_engine_regex" \
	--arg game_archive_base "$game_archive_base" \
	--arg probe_digest "$probe_digest" \
	--arg manifest_digest "$manifest_digest" \
	--argjson record_count "$record_count" \
	--argjson positive_callbacks "$positive_callbacks" \
'{
	schema: 2,
	status: "PASS",
	json_validation: "complete-jq",
	engine_version: $engine_version,
	expected_engine_regex: $expected_engine_regex,
	game_archive_base: $game_archive_base,
	probe_digest: $probe_digest,
	manifest_digest: $manifest_digest,
	record_count: $record_count,
	requested_mapchunks: 81,
	complete_records: 1,
	emerge_errors: 0,
	positive_callbacks: $positive_callbacks,
	positive_count_is_golden: false,
	mg_name: "v7",
	chunksize: 5,
	water_level: 1,
	mg_flags: "caves,dungeons,light,decorations,biomes,ores",
	mgv7_spflags: "mountains,ridges,nofloatlands,caverns",
	mgv7_dungeon_ymin: -31000,
	mgv7_dungeon_ymax: -193,
	mgv7_np_dungeons: "0.9|0.5|500|500|500|0|2|0.8|2|defaults"
}' > "$summary_json"

# Parse the emitted summary again and require its complete schema/type shape.
jq -e \
	--arg engine_version "$engine_version" \
	--arg expected_engine_regex "$expected_engine_regex" \
	--arg game_archive_base "$game_archive_base" \
	--arg probe_digest "$probe_digest" \
	--arg manifest_digest "$manifest_digest" \
	--argjson record_count "$record_count" \
	--argjson positive_callbacks "$positive_callbacks" \
'
	type == "object" and
	(keys | sort) == (["schema", "status", "json_validation", "engine_version",
		"expected_engine_regex", "game_archive_base", "probe_digest",
		"manifest_digest", "record_count", "requested_mapchunks",
		"complete_records", "emerge_errors", "positive_callbacks",
		"positive_count_is_golden", "mg_name", "chunksize", "water_level",
		"mg_flags", "mgv7_spflags", "mgv7_dungeon_ymin", "mgv7_dungeon_ymax",
		"mgv7_np_dungeons"] | sort) and
	.schema == 2 and .status == "PASS" and .json_validation == "complete-jq" and
	.engine_version == $engine_version and
	.expected_engine_regex == $expected_engine_regex and
	.game_archive_base == $game_archive_base and
	.probe_digest == $probe_digest and .manifest_digest == $manifest_digest and
	(.engine_version | type == "string" and test($expected_engine_regex)) and
	(.game_archive_base | test("^[0-9a-f]{40}$")) and
	(.probe_digest | test("^[0-9a-f]{64}$")) and
	(.manifest_digest | test("^[0-9a-f]{64}$")) and
	(.record_count | type == "number" and . == floor and . == $record_count) and
	.requested_mapchunks == 81 and .complete_records == 1 and .emerge_errors == 0 and
	(.positive_callbacks | type == "number" and . == floor and
		. == $positive_callbacks and . >= 1) and
	.positive_count_is_golden == false and .mg_name == "v7" and
	.chunksize == 5 and .water_level == 1 and
	.mg_flags == "caves,dungeons,light,decorations,biomes,ores" and
	.mgv7_spflags == "mountains,ridges,nofloatlands,caverns" and
	.mgv7_dungeon_ymin == -31000 and .mgv7_dungeon_ymax == -193 and
	.mgv7_np_dungeons == "0.9|0.5|500|500|500|0|2|0.8|2|defaults"
' "$summary_json" >/dev/null

jq -c . "$summary_json"
