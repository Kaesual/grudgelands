#!/usr/bin/env bash
# WP40 T5-0 engine-seam probe -- fail-closed gate over ONE run's raw log.
#
# Three stages, per contract 12.5:
#   stage 1  marker-INDEX extraction, zero-record refusal, non-marker garbage
#            gate, JSON-object gate
#   stage 2  one slurped jq assertion implementing all fifteen numbered
#            assertions of 12.5, built from per-assertion error("...") calls so
#            every section-16 fragment exists literally
#   stage 3  summary generated with `jq -nc` and RE-PARSED with a second `jq -e`
#            including regex shape checks
#
# This gate covers the RUN stream (12.2/12.3) only. The comparison stream
# (12.7) has its own gate in compare_runs.sh, and stage-2 assertion 2 rejects a
# comparison record pasted into a run log. Neither gate applies the other's
# common-field set.
set -euo pipefail

usage() {
	cat >&2 <<'USAGE'
usage: verify_log.sh RAW_LOG SUMMARY_JSON ENGINE_REGEX GAME_COMMIT \
                     PAYLOAD_DIGEST MANIFEST_DIGEST \
                     [PINNED_ENGINE_VERSION] [LOG_SHAPE_REGEX]

       verify_log.sh --print-log-shape-regex
       verify_log.sh --print-pinned-engine-version

The two --print forms exist so run_t5_probe.sh can bind these committed bytes
into the manifest digest (contract 12.5 stage 1 and stage 3) without
duplicating the literals.
USAGE
}

# --- committed literals whose bytes are bound into the manifest digest --------
#
# Stage 1's non-marker garbage gate: the residual (raw log minus the extracted
# marker lines) must match this ERE line for line, or the run fails. Contract
# 12.5 permits an explicit enumeration, and this is one: it enumerates the
# engine's own known log-line shapes, and residual content that matches none of
# them -- a bare Lua traceback continuation line, a stray write to stdout, an
# unrecognised banner -- is ungated content and fails the run.
#
# What it does NOT do, stated plainly so nobody reads more into it: the second
# alternative admits EVERY line the engine level-prefixes, `ERROR[...]:`
# included. That is exactly the shape in which the engine reports a Lua error
# raised on an emerge thread, so a failing chunk callback does NOT fail this
# regex. The detector for an errored chunk is stage 2's `emerge_done`
# assertion: a chunk whose `emerge_done` is missing, or whose
# `emerge_done.action` is anything other than GENERATED, aborts the run (A-05).
# That assertion is therefore NOT redundant with this gate and must not be
# dropped as if it were -- it is the only thing standing between a silently
# errored chunk and a PASS.
#
#   ^[^A-Za-z]*$                     blank lines, dashed rules, ASCII banner art
#   ^(ACTION|INFO|VERBOSE|WARNING|ERROR|DEPRECATED)\[[^]]*\]:   level-prefixed
#   ^\[MOD\]                         mod loader lines
#   ^[[:space:]]*Separator[[:space:]]*$   the log separator block's caption
#   ^\|_\|                           the banner's final version row
WP40_T5_PROBE_LOG_SHAPE_REGEX_DEFAULT='^[^A-Za-z]*$|^(ACTION|INFO|VERBOSE|WARNING|ERROR|DEPRECATED)\[[^]]*\]:|^\[MOD\]|^[[:space:]]*Separator[[:space:]]*$|^\|_\|'

# The pinned reference engine of contract 13.3. The installed Flatpak is 5.16.1
# while the pinned reference is 5.17.0-dev df04879, so `version_match` is
# expected to be false and is labelled in-band rather than hidden.
WP40_T5_PROBE_PINNED_ENGINE_VERSION_DEFAULT='5.17.0-dev'

case "${1:-}" in
	--print-log-shape-regex)
		printf '%s\n' "${WP40_T5_PROBE_LOG_SHAPE_REGEX:-$WP40_T5_PROBE_LOG_SHAPE_REGEX_DEFAULT}"
		exit 0
		;;
	--print-pinned-engine-version)
		printf '%s\n' "${WP40_T5_PROBE_PINNED_ENGINE_VERSION:-$WP40_T5_PROBE_PINNED_ENGINE_VERSION_DEFAULT}"
		exit 0
		;;
	-h|--help)
		usage
		exit 0
		;;
esac

if [[ "$#" -lt 6 || "$#" -gt 8 ]]; then
	usage
	exit 2
fi

raw_log="$1"
summary_json="$2"
expected_engine_regex="$3"
game_archive_base="$4"
payload_digest="$5"
manifest_digest="$6"
pinned_engine_version="${7:-${WP40_T5_PROBE_PINNED_ENGINE_VERSION:-$WP40_T5_PROBE_PINNED_ENGINE_VERSION_DEFAULT}}"
log_shape_regex="${8:-${WP40_T5_PROBE_LOG_SHAPE_REGEX:-$WP40_T5_PROBE_LOG_SHAPE_REGEX_DEFAULT}}"

# Preflight is mandatory and up front: a missing rg exits 127 and would
# otherwise read as "no match".
# `rg` is preflighted because the package shell rule requires it up front (a
# missing rg exits 127 and would otherwise read as "no match"); this file does
# its own line matching with POSIX-ERE grep so the committed log-shape regex is
# matched in one fixed dialect.
for tool in jq rg awk grep; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "error: $tool is required by the WP40 t5-probe log gate" >&2
		exit 127
	}
done

[[ -f "$raw_log" ]] || {
	echo "error: raw log not found: $raw_log" >&2
	exit 2
}

scratch="$(mktemp -d /tmp/grudgelands-wp40-t5-probe.XXXXXX)"
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-t5-probe.*) rm -rf -- "$scratch" ;;
		*) echo "refusing unsafe cleanup path: $scratch" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

marker='WP40_T5_PROBE_JSON '
extracted="$scratch/extracted.jsonl"
residual="$scratch/residual.log"
ungated="$scratch/ungated.log"
canonical="$scratch/canonical.jsonl"

# ---------------------------------------------------------------------------
# Stage 1 -- marker INDEX extraction, never a prefix match.
# ---------------------------------------------------------------------------
awk -v marker="$marker" '
	{
		at = index($0, marker)
		if (at > 0)
			print substr($0, at + length(marker))
	}
' "$raw_log" > "$extracted"

# Zero marker lines is never a vacuous pass, and it fails before any jq stage.
if [[ ! -s "$extracted" ]]; then
	echo "error: no JSON records found in $raw_log" >&2
	exit 1
fi

# The awk extractor silently DROPS every non-marker line, so corrupt non-marker
# content would never be gated at all. The residual must match the committed
# engine log-line shapes above, or the run fails.
grep -vF -- "$marker" "$raw_log" > "$residual" || true
grep -Ev -- "$log_shape_regex" "$residual" > "$ungated" || true
if [[ -s "$ungated" ]]; then
	echo "error: raw log contains ungated non-marker content" >&2
	head -5 "$ungated" >&2
	exit 1
fi

# jq parses the complete payload. Malformed JSON fails here with jq's own
# `parse error`; valid JSON of the wrong type fails with `record is not an
# object` (section 16 rows 2 and 3 are distinct on purpose).
jq -ce 'if type == "object" then . else error("record is not an object") end' \
	"$extracted" > "$canonical"

# ---------------------------------------------------------------------------
# Stage 2 -- one slurped assertion over the whole stream (contract 12.5).
# Every assertion is `if <predicate> then . else error("<fragment>") end` so
# each section-16 row has a distinct literal `grep -qF` fragment.
# ---------------------------------------------------------------------------
jq -se '
	def is_integer: type == "number" and . == floor;
	def exact_keys($wanted): (keys) == ($wanted | sort);
	def vector:
		type == "object" and exact_keys(["x", "y", "z"]) and
		(.x | is_integer) and (.y | is_integer) and (.z | is_integer);
	def opt_vector: . == null or vector;
	def hex64: type == "string" and test("^[0-9a-f]{64}$");
	def hex64_or_empty: . == "" or hex64;
	def trim: gsub("^[[:space:]]+|[[:space:]]+$"; "");
	def in_set($set): . as $v | ($set | index($v)) != null;

	# ---- contract literals (10.3, 10.10, 12.3; coordinator pin section 4) ----
	def run_tags:
		["manifest", "mapgen_state_init", "chunk_callback", "case_baseline",
		 "main_on_generated", "emerge_done", "ipc_readback", "digest",
		 "digest_excl", "digest_incl", "process_metrics", "settling", "abort",
		 "complete"];
	def vm_methods:
		["get_data", "set_data", "get_param2_data", "set_param2_data",
		 "get_light_data", "set_light_data", "calc_lighting", "set_lighting",
		 "update_liquids", "get_emerged_area", "write_to_map", "read_from_map",
		 "initialize", "close", "update_map", "was_modified", "get_node_at",
		 "set_node_at"];
	def forbidden_methods:
		["write_to_map", "read_from_map", "initialize", "close", "update_map",
		 "was_modified", "get_node_at", "set_node_at"];
	def measured_kx: [8, 10, 11];
	def lanes: ["content", "param2", "light_day", "light_night"];
	def named_boxes: ["cut", "fill", "water", "facedir", "4lo", "4hi"];
	def case_of($kx):
		if $kx == 8 then "bounded"
		elif $kx == 10 then "4lo"
		elif $kx == 11 then "4hi"
		else null end;
	def central_min($kx): {x: (80 * $kx - 32), y: -32, z: 688};
	def central_max($kx): {x: (80 * $kx + 47), y: 47, z: 767};
	def core_box($kx):
		{min: {x: (80 * $kx - 16), y: -16, z: 704},
		 max: {x: (80 * $kx + 31), y: 31, z: 751}};
	def seam_box:
		{min: {x: 824, y: -16, z: 696}, max: {x: 871, y: 23, z: 735}};
	def region_box($region; $kx):
		if $region == "core" then core_box($kx)
		elif $region == "seam" then seam_box
		else null end;
	def named_box($n):
		if $n == "cut" then {min: {x: 628, y: 0, z: 712}, max: {x: 635, y: 7, z: 719}}
		elif $n == "fill" then {min: {x: 628, y: -8, z: 712}, max: {x: 635, y: -1, z: 719}}
		elif $n == "water" then {min: {x: 644, y: 0, z: 712}, max: {x: 651, y: 7, z: 719}}
		elif $n == "facedir" then {min: {x: 660, y: 0, z: 712}, max: {x: 667, y: 7, z: 719}}
		elif $n == "4lo" then {min: {x: 840, y: 0, z: 712}, max: {x: 847, y: 7, z: 719}}
		elif $n == "4hi" then {min: {x: 848, y: 0, z: 712}, max: {x: 855, y: 7, z: 719}}
		else null end;
	def box_region($n):
		if $n == "4lo" or $n == "4hi" then {region: "seam", kx: -1}
		else {region: "core", kx: 8} end;
	def light_box($case):
		if $case == "bounded" then {min: {x: 613, y: -23, z: 697}, max: {x: 682, y: 22, z: 734}}
		elif $case == "4lo" then {min: {x: 825, y: -15, z: 697}, max: {x: 847, y: 22, z: 734}}
		elif $case == "4hi" then {min: {x: 848, y: -15, z: 697}, max: {x: 870, y: 22, z: 734}}
		else null end;
	def light_voxels($case):
		if $case == "bounded" then 122360 else 33212 end;
	def content_extent($case):
		if $case == "bounded" then 2048 else 512 end;
	def param2_extent($case):
		if $case == "bounded" then 512 else 0 end;
	def content_boxes($case):
		if $case == "bounded" then ["cut", "fill", "water", "facedir"]
		else [$case] end;
	def param2_boxes($case):
		if $case == "bounded" then ["facedir"] else [] end;
	# The excluded region is a box LIST, never a bounding box (12.3, reviewer 11).
	def excl_boxes($kx; $kind):
		if $kind == "write_extent"
		then [content_boxes(case_of($kx))[] | named_box(.)]
		elif $kind == "light_write_box"
		then [light_box(case_of($kx))]
		else null end;
	def excl_voxels($kx; $kind):
		if $kind == "write_extent" then (if $kx == 8 then 2048 else 0 end)
		elif $kind == "light_write_box" then (if $kx == 8 then 58032 else 8246 end)
		else null end;
	def ipc_keys:
		["grug_wp40_t5_probe:chunk:10", "grug_wp40_t5_probe:chunk:11",
		 "grug_wp40_t5_probe:chunk:8", "grug_wp40_t5_probe:mapgen_state"] | sort;
	def abort_codes:
		["A-01", "A-02", "A-03", "A-04", "A-05", "A-06", "A-07", "A-08",
		 "A-09", "A-10", "A-11", "A-12", "A-13", "A-14", "A-15", "A-16"];
	def emerge_generated: ["generated", "EMERGE_GENERATED"];
	def emerge_actions:
		["generated", "memory", "disk", "cancelled", "errored",
		 "EMERGE_GENERATED", "EMERGE_FROM_MEMORY", "EMERGE_FROM_DISK",
		 "EMERGE_CANCELLED", "EMERGE_ERRORED"];
	def contains_box($outer): . as $b
		| $b.min.x >= $outer.min.x and $b.max.x <= $outer.max.x
		and $b.min.y >= $outer.min.y and $b.max.y <= $outer.max.y
		and $b.min.z >= $outer.min.z and $b.max.z <= $outer.max.z;

	def common_keys: ["schema", "tag", "arm", "order", "run_id", "state", "seq"];
	def tag_keys($t): common_keys + (
		if $t == "manifest" then
			["engine_string", "engine_hash", "engine_is_dev", "lua_runtime",
			 "game_id", "seed", "mapgen_settings", "mapgen_noiseparams_sha256",
			 "content_id_table_sha256", "content_id_count", "mod_list_sha256",
			 "payload_digest", "arm_switch_value", "emerge_order", "t0_us"]
		elif $t == "mapgen_state_init" then
			["load_us", "ipc_get_us", "ipc_set_us", "ipc_get_ok", "ipc_set_key",
			 "seed", "chunksize", "mapgen_edges_min", "mapgen_edges_max",
			 "callback_index", "vmanip_ctor_type", "vmanip_ctor_return_count",
			 "has_request_insecure_environment", "has_get_gametime",
			 "has_get_timeofday", "has_get_server_uptime",
			 "registered_nodes_available", "lua_bytes"]
		elif $t == "chunk_callback" then
			["case", "kx", "minp", "maxp", "emin", "emax", "blockseed", "ops",
			 "op_us", "callback_us", "write_extent_content",
			 "write_extent_param2", "param2_extent_min", "param2_extent_max",
			 "dirty_content", "dirty_param2", "dirty_content_by_box",
			 "dirty_param2_by_box", "dirty_liquid", "dirty_light",
			 "light_write_box_min", "light_write_box_max", "light_write_voxels",
			 "restored_outside_dirty_mismatch_count",
			 "light_outside_box_snapshot_sha256",
			 "light_outside_box_restored_sha256", "lua_bytes_before",
			 "lua_bytes_after", "ipc_set_us", "ipc_set_key",
			 "production_adopted"]
		elif $t == "main_on_generated" then
			["minp", "maxp", "blockseed", "callback_us"]
		elif $t == "emerge_done" then
			["kx", "action", "calls_remaining", "elapsed_us", "deadline_us",
			 "generated_us"]
		elif $t == "ipc_readback" then
			["keys_expected", "keys_found", "keys", "poll_used", "total_us",
			 "values_sha256"]
		elif $t == "digest" then
			["pass", "region", "kx", "lane", "node_count", "sha256", "box_min",
			 "box_max", "content_ignore_count", "readback_us"]
		elif $t == "digest_excl" then
			["pass", "region", "kx", "lane", "node_count", "sha256", "box_min",
			 "box_max", "content_ignore_count", "readback_us", "excluded_kind",
			 "excluded_boxes", "excluded_voxels"]
		elif $t == "digest_incl" then
			["pass", "region", "kx", "lane", "node_count", "sha256", "box_min",
			 "box_max", "content_ignore_count", "readback_us",
			 "included_extent_min", "included_extent_max", "box_name"]
		elif $t == "case_baseline" then
			["case", "anchor_column", "native_surface_y",
			 "native_content_at_extent", "native_air_count",
			 "native_liquid_count"]
		elif $t == "process_metrics" then
			["available", "rss_bytes", "rss_peak_bytes", "virtual_bytes",
			 "cpu_seconds", "lua_bytes_main", "reason"]
		elif $t == "settling" then
			["liquid_update_s", "periodic_drain_suppressed", "interpass_wait_s",
			 "quiescent", "settling_is_probe_local"]
		elif $t == "abort" then ["code", "reason", "detail"]
		elif $t == "complete" then
			["ok", "chunks_generated", "records_emitted", "total_us",
			 "emerge_deadline_us", "run_deadline_us", "emerge_deadline_met",
			 "run_deadline_met"]
		else [] end);

	def cbs: [.[] | select(.tag == "chunk_callback")];
	def digests: [.[] | select(.tag == "digest")];
	def excls: [.[] | select(.tag == "digest_excl")];
	def incls: [.[] | select(.tag == "digest_incl")];
	def all_digests: [.[] | select(.tag == "digest" or .tag == "digest_excl" or .tag == "digest_incl")];
	def arm_of: .[0].arm;
	def order_of: .[0].order;
	def count_tag($t): [.[] | select(.tag == $t)] | length;

	# ===== assertion 1a -- schema present and correct ========================
	(if all(.[]; has("schema")) then . else error("record is missing schema") end)
	| (if all(.[]; .schema == "grug_wp40_t5_probe_synthetic_v0")
		then . else error("unexpected record schema") end)

	# ===== assertion 2 -- the comparison stream is not this stream ===========
	| (if all(.[]; (has("stream") | not) and .tag != "verdict" and .tag != "first_diff")
		then . else error("comparison record in a run log") end)

	# ===== assertion 1b -- closed tag set and exact_keys per tag =============
	| (if all(.[]; (.tag | type == "string") and (.tag | in_set(run_tags)))
		then . else error("unknown record tag") end)
	| (if all(.[]; exact_keys(tag_keys(.tag)))
		then . else error("record has unexpected keys") end)

	# --- three cardinality/shape facts hoisted ahead of the seq and terminal
	# checks, each GUARDED so a truncated log still fails on its own terminal
	# record. Without the hoist a fixture that adds or removes a record would
	# fail on seq contiguity and hide the fragment section 16 names.
	| (if (count_tag("chunk_callback")) == 0 or (count_tag("chunk_callback")) == 3
		then . else error("chunk_callback cardinality is not 3") end)
	| (if (all_digests | length) == 0
			or (all_digests | map(.pass) | unique | sort) == [1, 2]
		then . else error("quiescence proof failed") end)
	| (if all(.[] | select(.tag == "abort"); (.code | in_set(abort_codes)))
		then . else error("abort code is not in the closed set") end)

	# ===== assertion 3 -- arm / order / run_id ==============================
	| (if all(.[]; .arm == "A1" or .arm == "B")
		then . else error("arm is not in the closed set") end)
	| (if ([.[] | .arm] | unique | length) == 1
		then . else error("arm is not constant within a run") end)
	| (if all(.[]; .order == "O1" or .order == "O2")
		then . else error("order is not in the closed set") end)
	| (if ([.[] | .order] | unique | length) == 1
		then . else error("order is not constant within a run") end)
	| (if all(.[]; .run_id == (.arm + "-" + .order))
		then . else error("run_id does not match arm and order") end)
	| (if all(.[]; .state == "main" or .state == "mapgen")
		then . else error("state is not in the closed set") end)

	# ===== assertion 4 -- seq, first main record, terminal record ===========
	| (if all(.[]; .seq | is_integer)
		then . else error("seq is not an integer") end)
	| (if ([.[] | select(.state == "main") | .seq] == [range(1; 1 + ([.[] | select(.state == "main")] | length))])
		and ([.[] | select(.state == "mapgen") | .seq] == [range(1; 1 + ([.[] | select(.state == "mapgen")] | length))])
		then . else error("seq is not contiguous") end)
	| (if ([.[] | select(.state == "main")][0].tag) == "manifest"
		then . else error("first main record is not the manifest") end)
	| (if (.[-1].tag) == "complete"
		then . else error("terminal record is not complete") end)
	| (if ([.[] | select(.tag == "complete")] | length) == 1 and (.[-1].tag) == "complete"
		then . else error("terminal record is not complete") end)

	# ===== assertion 5 -- per-tag cardinality, conditioned on the arm =======
	| (if count_tag("chunk_callback") == 3
		then . else error("chunk_callback cardinality is not 3") end)
	| (if count_tag("manifest") == 1
		then . else error("manifest cardinality is not 1") end)
	| (if count_tag("mapgen_state_init") == 1
		then . else error("mapgen_state_init cardinality is not 1") end)
	| (if count_tag("case_baseline") == (if arm_of == "B" then 3 else 0 end)
		then . else error("case_baseline cardinality is wrong for this arm") end)
	| (if count_tag("main_on_generated") == 3
		then . else error("main_on_generated cardinality is not 3") end)
	| (if count_tag("emerge_done") == 3
		then . else error("emerge_done cardinality is not 3") end)
	| (if count_tag("ipc_readback") == 1
		then . else error("ipc_readback cardinality is not 1") end)
	| (if count_tag("digest") == 32
		then . else error("digest cardinality is not 32") end)
	| (if count_tag("digest_excl") == 24
		then . else error("digest_excl cardinality is not 24") end)
	| (if count_tag("digest_incl") == 24
		then . else error("digest_incl cardinality is not 24") end)
	| (if count_tag("process_metrics") == 1
		then . else error("process_metrics cardinality is not 1") end)
	| (if count_tag("settling") == 1
		then . else error("settling cardinality is not 1") end)
	| (if count_tag("abort") <= 1
		then . else error("abort cardinality is not 0 or 1") end)
	# digest / digest_excl / digest_incl are present in BOTH arms over
	# identical regions -- an arm-B-only emission would make V-01/V-02
	# unrunnable (12.3).
	| (if (digests | map([.pass, .region, .kx, .lane]) | sort)
			== ([[1, 2][] as $p | ([8, 10, 11][] as $k | (lanes[] as $l | [$p, "core", $k, $l])),
				 (lanes[] as $l | [$p, "seam", -1, $l])] | sort)
		then . else error("digest region set is not the declared set") end)
	| (if (excls | map([.pass, .kx, .lane, .excluded_kind]) | sort)
			== ([[1, 2][] as $p | (measured_kx[] as $k |
				(["content", "param2"][] as $l | [$p, $k, $l, "write_extent"]),
				(["light_day", "light_night"][] as $l | [$p, $k, $l, "light_write_box"]))] | sort)
		then . else error("digest_excl region set is not the declared set") end)
	| (if (incls | map([.pass, .lane, .box_name]) | sort)
			== ([[1, 2][] as $p | (["content", "param2"][] as $l |
				(named_boxes[] as $b | [$p, $l, $b]))] | sort)
		then . else error("digest_incl box set is not the declared set") end)

	# ===== assertion 6 -- geometry ==========================================
	| (if all(.[] | select(.tag == "chunk_callback" or .tag == "main_on_generated");
			(.minp | vector) and (.maxp | vector))
		and all(.[] | select(.tag == "chunk_callback");
			(.emin | opt_vector) and (.emax | opt_vector) and
			(.param2_extent_min | opt_vector) and (.param2_extent_max | opt_vector) and
			(.light_write_box_min | opt_vector) and (.light_write_box_max | opt_vector))
		and all(.[] | select(.tag == "case_baseline"); .anchor_column | vector)
		and all(.[] | select(.tag == "mapgen_state_init");
			(.mapgen_edges_min | vector) and (.mapgen_edges_max | vector))
		and all(.[] | select(.tag == "digest" or .tag == "digest_excl" or .tag == "digest_incl");
			(.box_min | vector) and (.box_max | vector))
		and all(.[] | select(.tag == "digest_incl");
			(.included_extent_min | vector) and (.included_extent_max | vector))
		and all(.[] | select(.tag == "digest_excl");
			(.excluded_boxes | type == "array") and
			all(.excluded_boxes[]; type == "object" and exact_keys(["min", "max"]) and
				(.min | vector) and (.max | vector)))
		then . else error("vector shape invalid") end)
	| (if all(.[] | select(.tag == "chunk_callback" or .tag == "main_on_generated");
			(.maxp.x - .minp.x) == 79 and (.maxp.y - .minp.y) == 79 and
			(.maxp.z - .minp.z) == 79)
		then . else error("central chunk extent is not 80 nodes") end)
	| (if all(cbs[]; (.kx | in_set(measured_kx)) and .case == case_of(.kx) and
			.minp == central_min(.kx) and .maxp == central_max(.kx))
		then . else error("central chunk is not at its contract coordinates") end)
	# emin/emax: SKIPPED, not inverted, where they are null by contract.
	| (if all(cbs[]; if .emin == null and .emax == null then true
			else .emin == {x: (.minp.x - 16), y: (.minp.y - 16), z: (.minp.z - 16)} and
				 .emax == {x: (.maxp.x + 16), y: (.maxp.y + 16), z: (.maxp.z + 16)} end)
		then . else error("emerged box is not minp-16 to maxp+16") end)
	| (if arm_of != "A1" or all(cbs[]; .emin == null and .emax == null)
		then . else error("arm A1 callback reported an emerged area") end)
	| (if arm_of != "B" or all(cbs[]; .emin != null and .emax != null)
		then . else error("arm B callback did not report an emerged area") end)
	# containment of every declared write extent and of the light write box
	| (if all(cbs[]; . as $c
			| (content_boxes(.case) | all(.[]; named_box(.) | contains_box({min: $c.minp, max: $c.maxp})))
			and ($c.write_extent_content <= content_extent($c.case))
			and (if $c.param2_extent_min == null then true
				else ({min: $c.param2_extent_min, max: $c.param2_extent_max}
					| contains_box({min: $c.minp, max: $c.maxp})) end)
			and (if $c.light_write_box_min == null then true
				else ({min: $c.light_write_box_min, max: $c.light_write_box_max}
					| contains_box({min: $c.minp, max: $c.maxp})
					and contains_box({min: {x: ($c.minp.x - 16), y: ($c.minp.y - 16), z: ($c.minp.z - 16)},
						max: {x: ($c.maxp.x + 16), y: ($c.maxp.y + 16), z: ($c.maxp.z + 16)}})) end))
		then . else error("payload wrote outside its central owner slice") end)
	| (if all(cbs[]; .write_extent_content == content_extent(.case))
		then . else error("declared content write extent is not the case literal") end)

	# ===== assertion 7 -- compared regions pinned to contract coordinates ====
	| (if all(all_digests[];
			(.region | in_set(["core", "seam"])) and
			(if .region == "core" then (.kx | in_set(measured_kx)) else .kx == -1 end) and
			(if .tag == "digest_incl"
				then (.box_min == region_box(.region; .kx).min and .box_max == region_box(.region; .kx).max)
					or (.box_min == named_box(.box_name).min and .box_max == named_box(.box_name).max)
				else .box_min == region_box(.region; .kx).min and
					 .box_max == region_box(.region; .kx).max end))
		then . else error("compared box is not at its contract coordinates") end)
	| (if all(incls[]; . as $r
			| ($r.box_name | in_set(named_boxes))
			and $r.included_extent_min == named_box($r.box_name).min
			and $r.included_extent_max == named_box($r.box_name).max
			and $r.region == box_region($r.box_name).region
			and $r.kx == box_region($r.box_name).kx
			and $r.node_count == 512)
		then . else error("compared box is not at its contract coordinates") end)
	# The excluded region is the declared box LIST, element for element, in order.
	| (if all(excls[]; . as $r
			| ($r.excluded_kind | in_set(["write_extent", "light_write_box"]))
			and ($r.lane | if . == "content" or . == "param2"
				then $r.excluded_kind == "write_extent"
				else $r.excluded_kind == "light_write_box" end)
			and $r.excluded_boxes == excl_boxes($r.kx; $r.excluded_kind))
		then . else error("excluded region is not the declared box list") end)

	# ===== assertion 8 -- union semantics are checkable, not declared ========
	| (if all(excls[]; (.node_count + .excluded_voxels) == 110592)
		then . else error("CORE residual and excluded voxels do not sum to 110592") end)
	| (if all(excls[]; .excluded_voxels == excl_voxels(.kx; .excluded_kind))
		then . else error("excluded voxel count is not the tabulated value") end)
	| (if all(digests[]; .node_count == (if .region == "core" then 110592 else 76800 end))
		then . else error("compared region node count is not the tabulated value") end)
	# excluded_voxels == 0 means the residual IS the full CORE box, so the two
	# digests over the same lane, chunk and pass must be byte-identical.
	| (. as $r | if all($r | excls[] | select(.excluded_voxels == 0); . as $e
			| ($r | digests[] | select(.pass == $e.pass and .region == "core"
				and .kx == $e.kx and .lane == $e.lane) | .sha256) == $e.sha256)
		then $r else error("empty exclusion does not reproduce the CORE digest") end)

	# ===== assertion 9 -- the operation-count matrix of 10.11 ===============
	| (if all(cbs[]; (.ops | type == "object" and exact_keys(vm_methods)) and
			all(.ops[]; is_integer and . >= 0))
		then . else error("ops key set is not the eighteen VoxelManip methods") end)
	| (if all(cbs[]; (.op_us | type == "object" and exact_keys(vm_methods)) and
			all(.op_us[]; is_integer and . >= 0))
		then . else error("op_us key set is not the eighteen VoxelManip methods") end)
	| (if all(cbs[]; . as $c | forbidden_methods | all(.[]; ($c.ops[.]) == 0))
		then . else error("forbidden VoxelManip method was called") end)
	# arm A1: every counter is zero for every case, so the arm-B matrix below
	# applies only in arm B.
	| (if arm_of != "A1" or all(cbs[]; all(.ops[]; . == 0))
		then . else error("arm A1 performed a VoxelManip call") end)
	| (if all(cbs[]; (.dirty_content > 0) or (.dirty_light == false and .dirty_liquid == false))
		then . else error("light or liquid dirty set is nonempty with an empty content dirty set") end)
	| (if arm_of != "B" or all(cbs[]; .ops.get_emerged_area == 1)
		then . else error("get_emerged_area count is not 1") end)
	| (if arm_of != "B" or all(cbs[]; .ops.get_data == 1)
		then . else error("get_data count is not 1") end)
	| (if arm_of != "B" or all(cbs[]; .ops.get_param2_data == (if .case == "bounded" then 1 else 0 end))
		then . else error("get_param2_data count does not match the case") end)
	| (if arm_of != "B" or all(cbs[] | select(.case == "bounded" and .dirty_content > 0); .ops.set_data == 1)
		then . else error("bounded set_data count is not 1") end)
	| (if arm_of != "B" or all(cbs[] | select(.case == "bounded" and .dirty_content == 0); .ops.set_data == 0)
		then . else error("bounded set_data count is not 0 for an empty content dirty set") end)
	| (if arm_of != "B" or all(cbs[] | select(.case != "bounded");
			.ops.set_data == (if .dirty_content > 0 then 1 else 0 end))
		then . else error("set_data count does not match the realized content dirty set") end)
	| (if arm_of != "B" or all(cbs[];
			.ops.set_param2_data == (if .case == "bounded" and .dirty_param2 > 0 then 1 else 0 end))
		then . else error("set_param2_data count does not match the realized param2 dirty set") end)
	| (if all(cbs[] | select(.dirty_light == false);
			.ops.get_light_data == 0 and .ops.set_light_data == 0 and
			.ops.set_lighting == 0 and .ops.calc_lighting == 0)
		then . else error("lighting call performed with an empty light dirty set") end)
	| (if arm_of != "B" or all(cbs[] | select(.dirty_light == true); .ops.set_light_data == 1)
		then . else error("light dirty set is nonempty but set_light_data was not called") end)
	| (if arm_of != "B" or all(cbs[] | select(.dirty_light == true); .ops.get_light_data == 2)
		then . else error("get_light_data count is not 2 for a lighting callback") end)
	| (if arm_of != "B" or all(cbs[] | select(.dirty_light == true); .ops.set_lighting == 1)
		then . else error("set_lighting count is not 1 for a lighting callback") end)
	| (if arm_of != "B" or all(cbs[] | select(.dirty_light == true); .ops.calc_lighting == 1)
		then . else error("calc_lighting count is not 1 for a lighting callback") end)
	| (if all(cbs[] | select(.dirty_liquid == false); .ops.update_liquids == 0)
		then . else error("update_liquids called with an empty liquid dirty set") end)
	| (if arm_of != "B" or all(cbs[] | select(.dirty_liquid == true); .ops.update_liquids >= 1)
		then . else error("liquid dirty set is nonempty but update_liquids was not called") end)
	| (if arm_of != "B" or all(cbs[] | select(.dirty_liquid == true); .ops.update_liquids == 1)
		then . else error("update_liquids count is not 1 for a liquid callback") end)

	# ===== assertion 10 -- by-box dirty counts ==============================
	# core.write_json renders an EMPTY Lua table as JSON null, never as {} --
	# reference_projects/luanti/doc/lua_api.md:8112-8113, and
	# reference_projects/luanti/src/script/common/c_content.cpp:2260-2295 leaves
	# Json::Value default-constructed as nullValue when the table has no
	# entries. 12.3 says dirty_param2_by_box "is {} for the case-4 chunks", so
	# on the wire that key necessarily arrives as null: the empty JSON OBJECT is
	# not expressible from Lua at all. Normalise null to {} before the key-set
	# comparison. This does NOT weaken the gate, because the comparison is made
	# against the expected key set for that very case -- a null on a "bounded"
	# record, which declares a param2 write, still fails, and a non-empty
	# object on a case-4 record still fails.
	# (No apostrophe may appear anywhere in this jq program: it is single-quoted
	# in bash, so one would close the quote and break the script.)
	| (if all(cbs[]; (.dirty_content_by_box | type == "object") and
			((.dirty_param2_by_box // {}) | type == "object") and
			all(.dirty_content_by_box[]; is_integer and . >= 0) and
			all((.dirty_param2_by_box // {})[]; is_integer and . >= 0) and
			(.dirty_content_by_box | keys) == (content_boxes(.case) | sort) and
			((.dirty_param2_by_box // {}) | keys) == (param2_boxes(.case) | sort))
		then . else error("dirty by-box key set is wrong for this case") end)
	| (if all(cbs[]; .dirty_content == ([.dirty_content_by_box[]] | add // 0) and
			.dirty_param2 == ([(.dirty_param2_by_box // {})[]] | add // 0))
		then . else error("dirty counts by box do not sum to the scalar") end)

	# ===== assertion 11 -- the light-restore proof ==========================
	| (if all(cbs[] | select(.dirty_light == true);
			.restored_outside_dirty_mismatch_count == 0 and
			.light_outside_box_snapshot_sha256 == .light_outside_box_restored_sha256 and
			(.light_outside_box_snapshot_sha256 | hex64) and
			(.light_outside_box_restored_sha256 | hex64))
		then . else error("param1 outside the light write box was not restored") end)
	| (if all(cbs[] | select(.dirty_light == false);
			.restored_outside_dirty_mismatch_count == 0 and
			.light_outside_box_snapshot_sha256 == "" and
			.light_outside_box_restored_sha256 == "" and
			.light_write_box_min == null and .light_write_box_max == null and
			.light_write_voxels == 0)
		then . else error("light fields are not null for an empty light dirty set") end)
	| (if all(cbs[] | select(.dirty_light == true);
			.light_write_box_min == light_box(.case).min and
			.light_write_box_max == light_box(.case).max and
			.light_write_voxels == light_voxels(.case))
		then . else error("light write box is not the declared box") end)

	# ===== assertion 12 -- the param2 mask identity (NOT arm-conditioned) ====
	| (if all(cbs[] | select(.case == "bounded");
			.param2_extent_min == named_box("facedir").min and
			.param2_extent_max == named_box("facedir").max and
			.write_extent_param2 == 512)
		then . else error("param2 write mask is not the declared facedir box") end)
	| (if all(cbs[] | select(.case != "bounded");
			.param2_extent_min == null and .param2_extent_max == null and
			.write_extent_param2 == 0)
		then . else error("case 4 declares no param2 write mask") end)

	# ===== assertion 13 -- every measured chunk was GENERATED by this run ====
	| (if all(.[] | select(.tag == "emerge_done");
			(.action | in_set(emerge_actions)))
		then . else error("measured chunk was not generated by this run") end)
	| (if all(.[] | select(.tag == "emerge_done");
			(.action | in_set(emerge_generated)) and .calls_remaining == 0)
		then . else error("measured chunk was not generated by this run") end)
	| (if ([.[] | select(.tag == "emerge_done") | .kx] | sort) == measured_kx
		then . else error("emerge_done chunk set is not the three measured chunks") end)

	# ===== assertion 14 -- the vacuous-readback hole ========================
	| (if all(all_digests[]; .content_ignore_count == 0)
		then . else error("compared region contains CONTENT_IGNORE") end)

	# ===== assertion 15 -- two passes, quiescence, adoption flag, IPC keys ===
	| (. as $r | if (all_digests | map(.pass) | unique | sort) == [1, 2]
			and all($r | all_digests[] | select(.pass == 1); . as $d
				| [$r | all_digests[] | select(.pass == 2 and .tag == $d.tag and .region == $d.region
					and .kx == $d.kx and .lane == $d.lane
					and (.box_name // "") == ($d.box_name // "")
					and (.excluded_kind // "") == ($d.excluded_kind // ""))]
				| length == 1 and (.[0].sha256 == $d.sha256) and (.[0].node_count == $d.node_count))
			and all($r | .[] | select(.tag == "settling"); .quiescent == true)
		then $r else error("quiescence proof failed") end)
	| (if all(cbs[]; .production_adopted == false)
		then . else error("probe IPC telemetry must not be marked production adopted") end)
	| (if all(.[] | select(.tag == "settling"); .settling_is_probe_local == true)
		then . else error("settling is not marked probe local") end)
	| (if all(.[] | select(.tag == "settling");
			.liquid_update_s == 86400 and .periodic_drain_suppressed == true and
			.interpass_wait_s >= 2.0)
		then . else error("liquid_update is not pinned with a two second interpass wait") end)
	| (if all(.[] | select(.tag == "ipc_readback");
			.keys_expected == 4 and .keys_found == 4 and
			(.keys | type == "array") and (.keys | sort) == ipc_keys and
			(.keys | length) == 4)
		and all(cbs[]; .ipc_set_key == ("grug_wp40_t5_probe:chunk:" + (.kx | tostring)))
		and all(.[] | select(.tag == "mapgen_state_init");
			.ipc_set_key == "grug_wp40_t5_probe:mapgen_state")
		then . else error("ipc key set is not the four declared keys") end)

	# ===== abort record, deadlines, manifest and terminal shape =============
	| (if all(.[] | select(.tag == "abort"); (.code | in_set(abort_codes)))
		then . else error("abort code is not in the closed set") end)
	| (if count_tag("abort") == 0
		then . else error("run reported an abort code") end)
	| (if all(.[] | select(.tag == "complete"); .run_deadline_met == true)
		then . else error("run deadline exceeded") end)
	| (if all(.[] | select(.tag == "complete"); .emerge_deadline_met == true)
		then . else error("emerge deadline exceeded") end)
	| (if all(.[] | select(.tag == "complete"); .ok == true and .chunks_generated == 3)
		then . else error("run did not complete with three generated chunks") end)
	| (. as $r | if all($r | .[] | select(.tag == "complete"); .records_emitted == ($r | length))
		then $r else error("records_emitted does not match the record count") end)
	| (order_of) as $ord
	| (if all(.[] | select(.tag == "manifest");
			.seq == 1 and .state == "main" and
			(.emerge_order | type == "array") and (.emerge_order | length) == 3 and
			.emerge_order == (if $ord == "O1" then [8, 10, 11] else [11, 10, 8] end))
		then . else error("emerge order does not match the requested order") end)
	| (if all(.[] | select(.tag == "manifest");
			(.mapgen_noiseparams_sha256 | hex64) and
			(.content_id_table_sha256 | hex64) and (.mod_list_sha256 | hex64) and
			(.payload_digest | hex64) and (.content_id_count | is_integer) and
			(.mapgen_settings | type == "object") and
			all(.mapgen_settings[]; type == "string") and
			.arm_switch_value == .arm)
		then . else error("manifest identity fields are not well formed") end)
	| (if all(all_digests[]; (.sha256 | hex64) and (.pass == 1 or .pass == 2) and
			(.lane | in_set(lanes)))
		then . else error("digest record shape is invalid") end)
	| (if all(.[] | select(.tag == "case_baseline");
			(.case | in_set(["bounded", "4lo", "4hi"])))
		and (([.[] | select(.tag == "case_baseline") | .case] | sort)
			== (if arm_of == "B" then ["4hi", "4lo", "bounded"] else [] end))
		then . else error("case_baseline case set is not the three measured cases") end)
	| (if all(.[] | select(.tag == "mapgen_state_init"); .chunksize == 5)
		then . else error("chunksize is not 5") end)
	| (if all(.[] | select(.tag == "process_metrics");
			(.rss_bytes | is_integer or . == "unavailable") and
			(.rss_peak_bytes | is_integer or . == "unavailable") and
			(.virtual_bytes | is_integer or . == "unavailable") and
			(.cpu_seconds | type == "number" or . == "unavailable") and
			(.reason | type == "string"))
		then . else error("process metrics are neither an integer nor the unavailable marker") end)
	| true
' "$canonical" >/dev/null

# ---------------------------------------------------------------------------
# Stage 3 -- generate the summary with `jq -nc`, then RE-PARSE it.
# ---------------------------------------------------------------------------
manifest_rec="$(jq -sc '[.[] | select(.tag == "manifest")][0]' "$canonical")"
run_id="$(jq -r '.run_id' <<<"$manifest_rec")"
arm="$(jq -r '.arm' <<<"$manifest_rec")"
order="$(jq -r '.order' <<<"$manifest_rec")"
record_count="$(jq -s 'length' "$canonical")"

chunks_json="$(jq -sc '[.[] | select(.tag == "chunk_callback")
	| {kx, case, emin_emax_ok: (if .emin == null then null else true end),
	   dirty_content, dirty_param2, dirty_liquid, dirty_light,
	   dirty_content_by_box, dirty_param2_by_box}] | sort_by(.kx)' "$canonical")"
digests_json="$(jq -sc '[.[] | select(.tag == "digest")
	| {pass, region, kx, lane, node_count, sha256}]
	| sort_by([.pass, .region, .kx, .lane])' "$canonical")"
excl_json="$(jq -sc '[.[] | select(.tag == "digest_excl")
	| {pass, kx, lane, excluded_kind, node_count, excluded_voxels, sha256}]
	| sort_by([.pass, .kx, .lane, .excluded_kind])' "$canonical")"
incl_json="$(jq -sc '[.[] | select(.tag == "digest_incl")
	| {pass, lane, box_name, region, kx, node_count, sha256}]
	| sort_by([.pass, .lane, .box_name])' "$canonical")"

# Contract 3.2 non-claim 11 ends "and the summary says it in those words", so
# the words are a literal, defined once and passed to jq as data. It carries
# apostrophes and must never be pasted inside a single-quoted jq program; both
# the generator and the re-parse below receive the same shell variable, so the
# emitted sentence and the sentence the gate demands cannot drift apart.
containment_statement="A containment pass means 'no difference in the compared regions', not 'no difference in the chunk'."

jq -nc \
	--arg run_id "$run_id" --arg arm "$arm" --arg order "$order" \
	--arg containment_statement "$containment_statement" \
	--arg engine_regex "$expected_engine_regex" \
	--arg pinned_engine_version "$pinned_engine_version" \
	--arg log_shape_regex "$log_shape_regex" \
	--arg game_archive_base "$game_archive_base" \
	--arg payload_digest "$payload_digest" \
	--arg manifest_digest "$manifest_digest" \
	--argjson record_count "$record_count" \
	--argjson manifest "$manifest_rec" \
	--argjson chunks "$chunks_json" \
	--argjson digests "$digests_json" \
	--argjson digests_excl "$excl_json" \
	--argjson digests_incl "$incl_json" \
'{
	schema: "wp40-t5-probe-summary-v1",
	status: "PASS",
	json_validation: "complete-jq",
	run_id: $run_id,
	arm: $arm,
	order: $order,
	engine_string: $manifest.engine_string,
	engine_hash: $manifest.engine_hash,
	engine_is_dev: $manifest.engine_is_dev,
	lua_runtime: $manifest.lua_runtime,
	expected_engine_regex: $engine_regex,
	pinned_engine_version: $pinned_engine_version,
	version_match: ($manifest.engine_string == $pinned_engine_version),
	log_shape_regex: $log_shape_regex,
	game_archive_base: $game_archive_base,
	payload_digest: $payload_digest,
	manifest_digest: $manifest_digest,
	record_count: $record_count,
	game_id: $manifest.game_id,
	seed: $manifest.seed,
	mapgen_settings: $manifest.mapgen_settings,
	mapgen_noiseparams_sha256: $manifest.mapgen_noiseparams_sha256,
	content_id_table_sha256: $manifest.content_id_table_sha256,
	content_id_count: $manifest.content_id_count,
	mod_list_sha256: $manifest.mod_list_sha256,
	emerge_order: $manifest.emerge_order,
	chunks: $chunks,
	digests: $digests,
	digests_excl: $digests_excl,
	digests_incl: $digests_incl,
	ops_matrix_ok: true,
	two_pass_identical: true,
	quiescent: true,
	emerge_actions_generated: true,
	abort_code: null,
	chunks_generated: 3,
	complete_ok: true,
	timings_are_golden: false,
	timing_replicates: 1,
	settling_is_probe_local: true,
	# The honest cache disclaimer, copied verbatim from
	# tools/wp40/capture_t0_baseline.sh:239-241. Contract 13.1 requires it in
	# the run summary, so it is emitted here and not only in capture.json:
	# README.md says every run summary carries it, and this is what makes that
	# sentence true of the artefact rather than only of the prose.
	cache: {process: "new_process_new_disposable_world",
	  filesystem_page_cache: "unknown_uncontrolled",
	  cold_cache_claim: false},
	# Contract 3.2 non-claim 11 ends "and the summary says it in those words".
	# Quoting the sentence inside the non-claim does not discharge it; the
	# summary has to carry it. These are those words, verbatim.
	containment_scope_statement: $containment_statement
}' > "$summary_json"

# Re-parse the emitted summary and require its complete schema/type shape,
# including the regex gates. The engine-version regex is committed bytes bound
# into the manifest digest; `version_match` labels the non-golden value in-band
# instead of hiding it.
jq -e \
	--arg engine_regex "$expected_engine_regex" \
	--arg containment_statement "$containment_statement" \
	--arg pinned_engine_version "$pinned_engine_version" \
	--arg game_archive_base "$game_archive_base" \
	--arg payload_digest "$payload_digest" \
	--arg manifest_digest "$manifest_digest" \
	--argjson record_count "$record_count" \
'
	def hex64: type == "string" and test("^[0-9a-f]{64}$");
	type == "object" and
	(keys) == (["schema", "status", "json_validation", "run_id", "arm", "order",
		"engine_string", "engine_hash", "engine_is_dev", "lua_runtime",
		"expected_engine_regex", "pinned_engine_version", "version_match",
		"log_shape_regex", "game_archive_base", "payload_digest",
		"manifest_digest", "record_count", "game_id", "seed", "mapgen_settings",
		"mapgen_noiseparams_sha256", "content_id_table_sha256",
		"content_id_count", "mod_list_sha256", "emerge_order", "chunks",
		"digests", "digests_excl", "digests_incl", "ops_matrix_ok",
		"two_pass_identical", "quiescent", "emerge_actions_generated",
		"abort_code", "chunks_generated", "complete_ok", "timings_are_golden",
		"timing_replicates", "settling_is_probe_local", "cache",
		"containment_scope_statement"] | sort) and
	.schema == "wp40-t5-probe-summary-v1" and .status == "PASS" and
	.json_validation == "complete-jq" and
	(.run_id | test("^(A1|B)-(O1|O2)$")) and
	(.arm | test("^(A1|B)$")) and (.order | test("^(O1|O2)$")) and
	.run_id == (.arm + "-" + .order) and
	(.engine_string | type == "string" and test($engine_regex)) and
	(.engine_hash | type == "string") and
	(.engine_is_dev | type == "boolean") and
	(.lua_runtime | type == "string") and
	.expected_engine_regex == $engine_regex and
	.pinned_engine_version == $pinned_engine_version and
	(.version_match | type == "boolean") and
	.version_match == (.engine_string == $pinned_engine_version) and
	(.log_shape_regex | type == "string" and length > 0) and
	.game_archive_base == $game_archive_base and
	(.game_archive_base | test("^[0-9a-f]{40}$")) and
	.payload_digest == $payload_digest and (.payload_digest | hex64) and
	.manifest_digest == $manifest_digest and (.manifest_digest | hex64) and
	(.record_count | type == "number" and . == floor and . == $record_count) and
	(.game_id | type == "string") and
	(.mapgen_settings | type == "object") and
	(.mapgen_noiseparams_sha256 | hex64) and
	(.content_id_table_sha256 | hex64) and
	(.mod_list_sha256 | hex64) and
	(.content_id_count | type == "number" and . == floor) and
	(.emerge_order | type == "array" and length == 3) and
	(.chunks | type == "array" and length == 3) and
	(.digests | type == "array" and length == 32) and
	(.digests_excl | type == "array" and length == 24) and
	(.digests_incl | type == "array" and length == 24) and
	all(.digests[]; .sha256 | hex64) and
	all(.digests_excl[]; .sha256 | hex64) and
	all(.digests_incl[]; .sha256 | hex64) and
	.ops_matrix_ok == true and .two_pass_identical == true and
	.quiescent == true and .emerge_actions_generated == true and
	.abort_code == null and .chunks_generated == 3 and .complete_ok == true and
	.timings_are_golden == false and .timing_replicates == 1 and
	.settling_is_probe_local == true and
	# Re-checked value for value: a disclaimer that can be silently emptied is
	# not a disclaimer, and a summary that "carries" it as an empty object
	# would still satisfy a mere type check.
	(.cache | type == "object") and
	(.cache | keys) == ["cold_cache_claim", "filesystem_page_cache", "process"] and
	.cache.process == "new_process_new_disposable_world" and
	.cache.filesystem_page_cache == "unknown_uncontrolled" and
	.cache.cold_cache_claim == false and
	.containment_scope_statement == $containment_statement
' "$summary_json" >/dev/null

echo "WP40 t5-probe log gate: $run_id PASS ($record_count records, stages 1-3)"
jq -c '{run_id, arm, order, record_count, version_match, timings_are_golden,
	timing_replicates, settling_is_probe_local}' "$summary_json"
