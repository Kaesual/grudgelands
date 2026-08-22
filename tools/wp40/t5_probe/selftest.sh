#!/usr/bin/env bash
# WP40 T5-0 engine-seam probe -- offline negative-test suite (contract 16).
#
# It proves that every one of the 45 negative rows of contract section 16
# aborts with its exact stated fragment, plus the two checks section 16 names
# as NOT being corruptions of an emitted stream:
#
#   * the injected-payload digest refusal (A-02, `injected probe payload digest
#     differs`), exercised against a mutated flattened injected tree;
#   * the manifest-digest fixture (`digest is path sensitive` /
#     `digest did not change`), in the shape of
#     tools/wp40/dungeon_probe/digest_audit.sh:17-43.
#
# NONE of these needs an engine capture: every fixture is generated inline, no
# fixture file is committed, and the whole suite runs in the cheap half of
# run_t5_probe.sh (step 4), before the four opt-in captures.
#
# A negative proof counts only when the run aborts FOR THE STATED REASON. The
# harness is the shape of tools/wp40/run_t2_census_gates.sh:35-51: non-zero exit
# AND `grep -qF` on the literal fragment. An abort on an unrelated typo must not
# read as the gate working.
#
# The valid baselines are asserted to PASS first. Without that every negative is
# vacuous: a fixture that fails for a reason present in the baseline too proves
# nothing about the corruption.
#
# ---------------------------------------------------------------------------
# The voxel model, and why the fixtures are not opaque strings
# ---------------------------------------------------------------------------
# Rows 27, 28 and 39 are only meaningful if the compared digests behave like
# digests over real compared bytes. So the baseline digests are NOT invented
# hex: each one is a sha256 over a canonical text listing the VISIBLE WRITTEN
# VOXELS of that lane in that compared region -- the arm's write boxes,
# intersected with the compared region, minus the union of the record's
# declared excluded boxes, emitted as maximal x-runs in ascending z, y, x.
# Unwritten voxels are identical across arms and runs by construction and
# therefore contribute nothing; a digest over the visible written set
# distinguishes exactly the cases a byte-level digest would.
#
# The model is checked against the contract's own literals before it is used:
# |CORE(8) union(cut,fill,water,facedir)| == 2048, |CORE(8) bounding box|
# == 5120, |CORE(8) light box| == 58032, |CORE(10) light box| == 8246. That is
# the union-versus-bounding-box distinction of reviewer item 11 computed rather
# than asserted, and it is what makes row 27 fire for the contract's reason: a
# write at x = 636 is inside the four boxes' 5,120-voxel bounding box and
# outside their 2,048-voxel union, so it survives into the residual and the
# residual digests of the two arms diverge. Row 27 also checks the converse --
# under bounding-box exclusion the same write is invisible and the gate would
# NOT fire -- so the out-of-extent detector is demonstrated, not assumed.
#
# Exit codes: 0 pass, 1 failed gate, 2 preflight, 127 missing tool.
set -euo pipefail

self_name="${BASH_SOURCE[0]##*/}"
probe_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verify_log="$probe_dir/verify_log.sh"
compare_runs="$probe_dir/compare_runs.sh"
digest_lib="$probe_dir/digest_lib.sh"
runner="$probe_dir/run_t5_probe.sh"

fail() { printf '%s: %s\n' "$self_name" "$*" >&2; exit 1; }
fail_preflight() { printf '%s: %s\n' "$self_name" "$*" >&2; exit 2; }
fail_missing_tool() { printf '%s: %s\n' "$self_name" "$*" >&2; exit 127; }

# ---------------------------------------------------------------------------
# Preflight -- mandatory and up front. A missing rg exits 127 and would
# otherwise read as "no match".
# ---------------------------------------------------------------------------
for tool in rg jq awk grep sed sha256sum; do
	command -v "$tool" >/dev/null 2>&1 ||
		fail_missing_tool "$tool is required by the WP40 t5-probe selftest"
done

for required in "$verify_log" "$compare_runs" "$digest_lib"; do
	[[ -f "$required" ]] ||
		fail_preflight "required probe file is missing: ${required##*/}"
done

# shellcheck source=/dev/null
source "$digest_lib"

scratch="$(mktemp -d /tmp/grudgelands-wp40-t5-selftest.XXXXXX)"
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-t5-selftest.*) rm -rf -- "$scratch" ;;
		*) echo "refusing unsafe cleanup path: $scratch" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Harness -- run_t2_census_gates.sh:37-50
# ---------------------------------------------------------------------------
fixtures=0
section16_fixtures=0
rows_covered=""
table=()

record_row() {
	table+=("$(printf '%-5s %-11s %-56s %s' "$1" "$2" "$3" "$4")")
}

note_row() {
	case " $rows_covered " in
		*" $1 "*) ;;
		*) rows_covered="$rows_covered $1" ;;
	esac
}

expect_failure() {
	local row="$1" stream="$2" label="$3" fragment="$4"
	shift 4
	local output status=0
	output="$("$@" 2>&1)" || status=$?
	fixtures=$((fixtures + 1))
	case "$row" in
		''|*[!0-9]*) ;;
		*) section16_fixtures=$((section16_fixtures + 1)) ;;
	esac
	note_row "$row"
	if (( status == 0 )); then
		printf '%s\n' "$output" >&2
		fail "row $row ($label) did not abort"
	fi
	if ! grep -qF -- "$fragment" <<<"$output"; then
		printf '%s\n' "$output" >&2
		fail "row $row ($label) aborted on the wrong reason (wanted: $fragment)"
	fi
	record_row "$row" "$stream" "$fragment" "FIRED (exit $status) -- $label"
}

expect_pass() {
	local label="$1"
	shift
	local output status=0
	output="$("$@" 2>&1)" || status=$?
	if (( status != 0 )); then
		printf '%s\n' "$output" >&2
		fail "baseline check must pass but exited $status: $label"
	fi
}

expect_equal() {
	local label="$1" want="$2" got="$3"
	[[ "$want" == "$got" ]] || fail "$label: expected $want, measured $got"
}

# ---------------------------------------------------------------------------
# Contract literals (10.3, 10.10, 12.3; coordinator pin section 4).
# Boxes are "x0,y0,z0,x1,y1,z1", inclusive.
# ---------------------------------------------------------------------------
declare -A BOX=(
	[cut]="628,0,712,635,7,719"
	[fill]="628,-8,712,635,-1,719"
	[water]="644,0,712,651,7,719"
	[facedir]="660,0,712,667,7,719"
	[4lo]="840,0,712,847,7,719"
	[4hi]="848,0,712,855,7,719"
)
declare -A CORE=(
	[8]="624,-16,704,671,31,751"
	[10]="784,-16,704,831,31,751"
	[11]="864,-16,704,911,31,751"
)
SEAM_BOX="824,-16,696,871,23,735"
BBOX8="628,-8,712,667,7,719"           # the 5,120-voxel bounding box
CUT_WIDE="628,0,712,636,7,719"         # row 27: one node further in +x
declare -A LIGHT=(
	[8]="613,-23,697,682,22,734"
	[10]="825,-15,697,847,22,734"
	[11]="848,-15,697,870,22,734"
)
declare -A EXCL_WRITE=(
	[8]="${BOX[cut]} ${BOX[fill]} ${BOX[water]} ${BOX[facedir]}"
	[10]="${BOX[4lo]}"
	[11]="${BOX[4hi]}"
)

W_CONTENT_B="${BOX[cut]} ${BOX[fill]} ${BOX[water]} ${BOX[facedir]} ${BOX[4lo]} ${BOX[4hi]}"
W_PARAM2_B="${BOX[facedir]}"
W_LIGHT_B="${LIGHT[8]} ${LIGHT[10]} ${LIGHT[11]}"

ENGINE_REGEX='^5[.]16[.][0-9]+$'
GAME_COMMIT='0123456789abcdef0123456789abcdef01234567'
PAYLOAD_DIGEST='1111111111111111111111111111111111111111111111111111111111111111'
MANIFEST_DIGEST='2222222222222222222222222222222222222222222222222222222222222222'

# ---------------------------------------------------------------------------
# The lane-digest model.
# ---------------------------------------------------------------------------
cat >"$scratch/lane_digest.awk" <<'AWK'
function clipbox(b0, b1, b2, b3, b4, b5) {
	cx0 = (b0 > RX0 ? b0 : RX0); cx1 = (b3 < RX1 ? b3 : RX1)
	cy0 = (b1 > RY0 ? b1 : RY0); cy1 = (b4 < RY1 ? b4 : RY1)
	cz0 = (b2 > RZ0 ? b2 : RZ0); cz1 = (b5 < RZ1 ? b5 : RZ1)
	return (cx0 <= cx1 && cy0 <= cy1 && cz0 <= cz1)
}
BEGIN {
	split(region, R, ",")
	RX0 = R[1] + 0; RY0 = R[2] + 0; RZ0 = R[3] + 0
	RX1 = R[4] + 0; RY1 = R[5] + 0; RZ1 = R[6] + 0
	m = 0
	n = split(writes, WS, " ")
	for (i = 1; i <= n; i++) {
		if (WS[i] == "") continue
		split(WS[i], b, ",")
		if (clipbox(b[1] + 0, b[2] + 0, b[3] + 0, b[4] + 0, b[5] + 0, b[6] + 0)) {
			m++
			AX0[m] = cx0; AX1[m] = cx1
			AY0[m] = cy0; AY1[m] = cy1
			AZ0[m] = cz0; AZ1[m] = cz1
			if (m == 1) {
				bx0 = cx0; bx1 = cx1; by0 = cy0; by1 = cy1; bz0 = cz0; bz1 = cz1
			} else {
				if (cx0 < bx0) bx0 = cx0
				if (cx1 > bx1) bx1 = cx1
				if (cy0 < by0) by0 = cy0
				if (cy1 > by1) by1 = cy1
				if (cz0 < bz0) bz0 = cz0
				if (cz1 > bz1) bz1 = cz1
			}
		}
	}
	k = 0
	n = split(excl, ES, " ")
	for (i = 1; i <= n; i++) {
		if (ES[i] == "") continue
		split(ES[i], b, ",")
		if (clipbox(b[1] + 0, b[2] + 0, b[3] + 0, b[4] + 0, b[5] + 0, b[6] + 0)) {
			k++
			BX0[k] = cx0; BX1[k] = cx1
			BY0[k] = cy0; BY1[k] = cy1
			BZ0[k] = cz0; BZ1[k] = cz1
		}
	}
	total = 0
	nout = 0
	if (m > 0) {
		for (z = bz0; z <= bz1; z++) {
			for (y = by0; y <= by1; y++) {
				for (x = bx0; x <= bx1; x++) cov[x] = 0
				for (i = 1; i <= m; i++)
					if (y >= AY0[i] && y <= AY1[i] && z >= AZ0[i] && z <= AZ1[i])
						for (x = AX0[i]; x <= AX1[i]; x++) cov[x] = 1
				for (i = 1; i <= k; i++)
					if (y >= BY0[i] && y <= BY1[i] && z >= BZ0[i] && z <= BZ1[i])
						for (x = BX0[i]; x <= BX1[i]; x++) cov[x] = 0
				start = -1
				for (x = bx0; x <= bx1; x++) {
					if (cov[x] && start < 0) start = x
					if (!cov[x] && start >= 0) {
						total += x - start
						out[++nout] = sprintf("%d,%d,%d-%d", z, y, start, x - 1)
						start = -1
					}
				}
				if (start >= 0) {
					total += bx1 - start + 1
					out[++nout] = sprintf("%d,%d,%d-%d", z, y, start, bx1)
				}
			}
		}
	}
	if (mode == "volume") {
		print total
		exit
	}
	printf "schema=wp40-t5-probe-selftest-lane-v1\n"
	printf "lane=%s\n", lane
	printf "region=%s\n", region
	if (nout == 0)
		printf "visible=empty\n"
	else
		for (i = 1; i <= nout; i++) print out[i]
}
AWK

lane_text() { # OUTFILE LANE REGION WRITES EXCLUDES
	awk -v lane="$2" -v region="$3" -v writes="$4" -v excl="$5" -v mode=text \
		-f "$scratch/lane_digest.awk" >"$1"
}

lane_volume() { # REGION BOXES [EXCLUDED_BOXES]
	awk -v lane=x -v region="$1" -v writes="$2" -v excl="${3:-}" -v mode=volume \
		-f "$scratch/lane_digest.awk"
}

writes_for_lane() { # LANE CONTENT PARAM2 LIGHT
	case "$1" in
		content) printf '%s' "$2" ;;
		param2) printf '%s' "$3" ;;
		*) printf '%s' "$4" ;;
	esac
}

build_table() { # DIR CONTENT_WRITES PARAM2_WRITES LIGHT_WRITES
	local dir="$1" wc="$2" wp="$3" wl="$4" kx lane box w
	mkdir -p "$dir"
	for kx in 8 10 11; do
		for lane in content param2 light_day light_night; do
			w="$(writes_for_lane "$lane" "$wc" "$wp" "$wl")"
			lane_text "$dir/dig__core${kx}__${lane}.txt" "$lane" "${CORE[$kx]}" "$w" ""
			case "$lane" in
				content|param2)
					lane_text "$dir/excl__${kx}__${lane}.txt" "$lane" "${CORE[$kx]}" \
						"$w" "${EXCL_WRITE[$kx]}" ;;
				*)
					lane_text "$dir/excl__${kx}__${lane}.txt" "$lane" "${CORE[$kx]}" \
						"$w" "${LIGHT[$kx]}" ;;
			esac
		done
	done
	for lane in content param2 light_day light_night; do
		w="$(writes_for_lane "$lane" "$wc" "$wp" "$wl")"
		lane_text "$dir/dig__seam__${lane}.txt" "$lane" "$SEAM_BOX" "$w" ""
	done
	for box in cut fill water facedir 4lo 4hi; do
		for lane in content param2; do
			w="$(writes_for_lane "$lane" "$wc" "$wp" "$wl")"
			lane_text "$dir/incl__${box}__${lane}.txt" "$lane" "${BOX[$box]}" "$w" ""
		done
	done
}

table_json() { # DIR
	sha256sum -- "$1"/*.txt |
		awk '{ n = $2; sub(/.*\//, "", n); sub(/[.]txt$/, "", n); printf "%s %s\n", n, $1 }' |
		jq -R -s '[splits("\n") | select(length > 0) | split(" ")]
			| map({key: .[0], value: .[1]}) | from_entries'
}

# ---- the model reproduces the contract literals before it is trusted -------
expect_equal "union of the four kx=8 write boxes inside CORE(8)" 2048 \
	"$(lane_volume "${CORE[8]}" "${EXCL_WRITE[8]}")"
expect_equal "bounding box of the four kx=8 write boxes inside CORE(8)" 5120 \
	"$(lane_volume "${CORE[8]}" "$BBOX8")"
expect_equal "light write box inside CORE(8)" 58032 \
	"$(lane_volume "${CORE[8]}" "${LIGHT[8]}")"
expect_equal "light write box inside CORE(10)" 8246 \
	"$(lane_volume "${CORE[10]}" "${LIGHT[10]}")"
expect_equal "light write box inside CORE(11)" 8246 \
	"$(lane_volume "${CORE[11]}" "${LIGHT[11]}")"

build_table "$scratch/tbl/A1" "" "" ""
build_table "$scratch/tbl/B" "$W_CONTENT_B" "$W_PARAM2_B" "$W_LIGHT_B"
TABLE_A1="$(table_json "$scratch/tbl/A1")"
TABLE_B="$(table_json "$scratch/tbl/B")"

# ---------------------------------------------------------------------------
# The run-stream emitter (contract 12.2/12.3, pin section 6).
# ---------------------------------------------------------------------------
cat >"$scratch/emit_run.jq" <<'JQ'
def vec($x; $y; $z): {x: $x, y: $y, z: $z};
def lanes: ["content", "param2", "light_day", "light_night"];
def named_boxes: ["cut", "fill", "water", "facedir", "4lo", "4hi"];
def named_box($n):
	if $n == "cut" then {min: vec(628; 0; 712), max: vec(635; 7; 719)}
	elif $n == "fill" then {min: vec(628; -8; 712), max: vec(635; -1; 719)}
	elif $n == "water" then {min: vec(644; 0; 712), max: vec(651; 7; 719)}
	elif $n == "facedir" then {min: vec(660; 0; 712), max: vec(667; 7; 719)}
	elif $n == "4lo" then {min: vec(840; 0; 712), max: vec(847; 7; 719)}
	else {min: vec(848; 0; 712), max: vec(855; 7; 719)} end;
def core_box($kx):
	{min: vec(80 * $kx - 16; -16; 704), max: vec(80 * $kx + 31; 31; 751)};
def seam_box: {min: vec(824; -16; 696), max: vec(871; 23; 735)};
def central_min($kx): vec(80 * $kx - 32; -32; 688);
def central_max($kx): vec(80 * $kx + 47; 47; 767);
def case_of($kx): if $kx == 8 then "bounded" elif $kx == 10 then "4lo" else "4hi" end;
def light_box($case):
	if $case == "bounded" then {min: vec(613; -23; 697), max: vec(682; 22; 734)}
	elif $case == "4lo" then {min: vec(825; -15; 697), max: vec(847; 22; 734)}
	else {min: vec(848; -15; 697), max: vec(870; 22; 734)} end;
def light_voxels($case): if $case == "bounded" then 122360 else 33212 end;
def content_boxes($case):
	if $case == "bounded" then ["cut", "fill", "water", "facedir"] else [$case] end;
def kind_of($lane):
	if $lane == "content" or $lane == "param2" then "write_extent"
	else "light_write_box" end;
def excl_boxes($kx; $kind):
	if $kind == "write_extent" then [content_boxes(case_of($kx))[] | named_box(.)]
	else [light_box(case_of($kx))] end;
def excl_voxels($kx; $kind):
	if $kind == "write_extent" then (if $kx == 8 then 2048 else 0 end)
	else (if $kx == 8 then 58032 else 8246 end) end;
def box_region($n):
	if $n == "4lo" or $n == "4hi" then {region: "seam", kx: -1}
	else {region: "core", kx: 8} end;
def vm_methods:
	["get_data", "set_data", "get_param2_data", "set_param2_data",
	 "get_light_data", "set_light_data", "calc_lighting", "set_lighting",
	 "update_liquids", "get_emerged_area", "write_to_map", "read_from_map",
	 "initialize", "close", "update_map", "was_modified", "get_node_at",
	 "set_node_at"];
def zero_ops: reduce vm_methods[] as $m ({}; .[$m] = 0);
def kx_order: if $order == "O1" then [8, 10, 11] else [11, 10, 8] end;
def treated: $arm == "B";
def hex($c): ($c * 64);

def rec($state; $tag; $fields):
	{schema: "grug_wp40_t5_probe_synthetic_v0", tag: $tag, arm: $arm,
	 order: $order, run_id: ($arm + "-" + $order), state: $state} + $fields;

def ops_for($case):
	if treated | not then zero_ops
	else zero_ops + {
		get_data: 1, set_data: 1, get_emerged_area: 1,
		get_param2_data: (if $case == "bounded" then 1 else 0 end),
		set_param2_data: (if $case == "bounded" then 1 else 0 end),
		get_light_data: 2, set_light_data: 1, calc_lighting: 1, set_lighting: 1,
		update_liquids: (if $case == "bounded" then 1 else 0 end)
	} end;
def op_us_for($case): ops_for($case) | with_entries(.value = (.value * 37));

def manifest_rec:
	rec("main"; "manifest"; {
		engine_string: "5.16.1",
		engine_hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		engine_is_dev: false,
		lua_runtime: "LuaJIT 2.1.1700000000",
		game_id: "grudgelands",
		seed: 40200517,
		mapgen_settings: {mg_name: "v7", chunksize: "5", water_level: "1"},
		mapgen_noiseparams_sha256: hex("3"),
		content_id_table_sha256: hex("4"),
		content_id_count: 1024,
		mod_list_sha256: hex("5"),
		payload_digest: $payload_digest,
		arm_switch_value: $arm,
		emerge_order: kx_order,
		t0_us: 1000
	});

def mapgen_state_init_rec:
	rec("mapgen"; "mapgen_state_init"; {
		load_us: 900, ipc_get_us: 4, ipc_set_us: 6, ipc_get_ok: true,
		ipc_set_key: "grug_wp40_t5_probe:mapgen_state",
		seed: 40200517, chunksize: 5,
		mapgen_edges_min: vec(-31000; -31000; -31000),
		mapgen_edges_max: vec(31000; 31000; 31000),
		callback_index: 1, vmanip_ctor_type: "userdata",
		vmanip_ctor_return_count: 1,
		has_request_insecure_environment: false, has_get_gametime: false,
		has_get_timeofday: false, has_get_server_uptime: false,
		registered_nodes_available: true, lua_bytes: 900000
	});

def baseline_rec($kx):
	rec("mapgen"; "case_baseline"; {
		case: case_of($kx),
		anchor_column: vec(80 * $kx + 8; 0; 720),
		native_surface_y: 12,
		native_content_at_extent: "default:stone",
		native_air_count: 208,
		native_liquid_count: 0
	});

def cb_rec($kx):
	case_of($kx) as $case
	| rec("mapgen"; "chunk_callback"; {
		case: $case, kx: $kx,
		minp: central_min($kx), maxp: central_max($kx),
		emin: (if treated then vec(80 * $kx - 48; -48; 672) else null end),
		emax: (if treated then vec(80 * $kx + 63; 63; 783) else null end),
		blockseed: (7000000 + $kx),
		ops: ops_for($case), op_us: op_us_for($case), callback_us: 4321,
		write_extent_content: (if $case == "bounded" then 2048 else 512 end),
		write_extent_param2: (if $case == "bounded" then 512 else 0 end),
		param2_extent_min: (if $case == "bounded" then named_box("facedir").min else null end),
		param2_extent_max: (if $case == "bounded" then named_box("facedir").max else null end),
		dirty_content: (if treated then (if $case == "bounded" then 2048 else 512 end) else 0 end),
		dirty_param2: (if treated and $case == "bounded" then 512 else 0 end),
		dirty_content_by_box: (reduce content_boxes($case)[] as $n
			({}; .[$n] = (if treated then 512 else 0 end))),
		dirty_param2_by_box: (if $case == "bounded"
			then {facedir: (if treated then 512 else 0 end)} else null end),
		dirty_liquid: (treated and $case == "bounded"),
		dirty_light: treated,
		light_write_box_min: (if treated then light_box($case).min else null end),
		light_write_box_max: (if treated then light_box($case).max else null end),
		light_write_voxels: (if treated then light_voxels($case) else 0 end),
		restored_outside_dirty_mismatch_count: 0,
		light_outside_box_snapshot_sha256: (if treated then hex("6") else "" end),
		light_outside_box_restored_sha256: (if treated then hex("6") else "" end),
		lua_bytes_before: 1000000, lua_bytes_after: 1000512,
		ipc_set_us: 11,
		ipc_set_key: ("grug_wp40_t5_probe:chunk:" + ($kx | tostring)),
		production_adopted: false
	});

def mog_rec($kx):
	rec("main"; "main_on_generated"; {
		minp: central_min($kx), maxp: central_max($kx),
		blockseed: (7000000 + $kx), callback_us: 44
	});

def ed_rec($kx):
	rec("main"; "emerge_done"; {
		kx: $kx, action: "EMERGE_GENERATED", calls_remaining: 0,
		elapsed_us: 5000000, deadline_us: 600000000, generated_us: 4900000
	});

def ipc_rec:
	rec("main"; "ipc_readback"; {
		keys_expected: 4, keys_found: 4,
		keys: ["grug_wp40_t5_probe:mapgen_state", "grug_wp40_t5_probe:chunk:8",
		       "grug_wp40_t5_probe:chunk:10", "grug_wp40_t5_probe:chunk:11"],
		poll_used: 1, total_us: 900, values_sha256: hex("7")
	});

def dig_rec($pass; $region; $kx; $lane):
	(if $region == "core" then core_box($kx) else seam_box end) as $bx
	| (if $region == "core" then "core" + ($kx | tostring) else "seam" end) as $rk
	| rec("main"; "digest"; {
		pass: $pass, region: $region, kx: $kx, lane: $lane,
		node_count: (if $region == "core" then 110592 else 76800 end),
		sha256: $D["dig__" + $rk + "__" + $lane],
		box_min: $bx.min, box_max: $bx.max,
		content_ignore_count: 0, readback_us: 90000
	});

def excl_rec($pass; $kx; $lane):
	kind_of($lane) as $kind
	| core_box($kx) as $bx
	| rec("main"; "digest_excl"; {
		pass: $pass, region: "core", kx: $kx, lane: $lane,
		node_count: (110592 - excl_voxels($kx; $kind)),
		sha256: $D["excl__" + ($kx | tostring) + "__" + $lane],
		box_min: $bx.min, box_max: $bx.max,
		content_ignore_count: 0, readback_us: 90000,
		excluded_kind: $kind, excluded_boxes: excl_boxes($kx; $kind),
		excluded_voxels: excl_voxels($kx; $kind)
	});

def incl_rec($pass; $lane; $box):
	named_box($box) as $nb
	| box_region($box) as $br
	| rec("main"; "digest_incl"; {
		pass: $pass, region: $br.region, kx: $br.kx, lane: $lane,
		node_count: 512,
		sha256: $D["incl__" + $box + "__" + $lane],
		box_min: $nb.min, box_max: $nb.max,
		content_ignore_count: 0, readback_us: 800,
		included_extent_min: $nb.min, included_extent_max: $nb.max,
		box_name: $box
	});

def pm_rec:
	rec("main"; "process_metrics"; {
		available: true, rss_bytes: 402653184, rss_peak_bytes: 419430400,
		virtual_bytes: 2147483648, cpu_seconds: 41.5,
		lua_bytes_main: 2000000, reason: ""
	});

def settling_rec:
	rec("main"; "settling"; {
		liquid_update_s: 86400, periodic_drain_suppressed: true,
		interpass_wait_s: 2.5, quiescent: true, settling_is_probe_local: true
	});

def complete_rec:
	rec("main"; "complete"; {
		ok: true, chunks_generated: 3, records_emitted: 0, total_us: 60000000,
		emerge_deadline_us: 600000000, run_deadline_us: 1800000000,
		emerge_deadline_met: true, run_deadline_met: true
	});

([manifest_rec]
	+ [kx_order[] as $k | mog_rec($k)]
	+ [kx_order[] as $k | ed_rec($k)]
	+ [ipc_rec]
	+ [[1, 2][] as $p
		| (([8, 10, 11][] as $k | lanes[] as $l | dig_rec($p; "core"; $k; $l)),
		   (lanes[] as $l | dig_rec($p; "seam"; -1; $l)))]
	+ [[1, 2][] as $p | [8, 10, 11][] as $k | lanes[] as $l | excl_rec($p; $k; $l)]
	+ [[1, 2][] as $p | ["content", "param2"][] as $l | named_boxes[] as $b
		| incl_rec($p; $l; $b)]
	+ [pm_rec, settling_rec, complete_rec]) as $main
| ([mapgen_state_init_rec]
	+ [kx_order[] as $k
		| (if treated then (baseline_rec($k), cb_rec($k)) else cb_rec($k) end)]) as $mg
| (($main | length) + ($mg | length)) as $total
| ($main | to_entries | map(.value + {seq: (.key + 1)})) as $M
| ($mg | to_entries | map(.value + {seq: (.key + 1)})) as $G
| ($M | .[0:-1] + [(.[-1] + {records_emitted: $total})]) as $M2
| ([$M2[0]] + $G + $M2[1:])[]
JQ

marker='WP40_T5_PROBE_JSON '

wrap_records() { # reads records on stdin, writes a raw log on stdout
	printf '\n'
	printf '%s\n' '[MOD] grug_wp40_t5_probe'
	printf '%s\n' 'INFO[Main]: Server for gameid="grudgelands" listening on 0.0.0.0:32001.'
	sed "s|^|ACTION[Main]: ${marker}|"
	printf '%s\n' 'ACTION[Main]: Server: Shutting down'
}

make_log() { # ARM ORDER TABLE OUTFILE
	jq -c -n --arg arm "$1" --arg order "$2" --argjson D "$3" \
		--arg payload_digest "$PAYLOAD_DIGEST" -f "$scratch/emit_run.jq" |
		wrap_records >"$4"
}

extract_records() { # RAW_LOG
	awk -v marker="$marker" \
		'{ at = index($0, marker); if (at > 0) print substr($0, at + length(marker)) }' "$1"
}

corrupt_log() { # SRC DST JQ_PROGRAM_OVER_THE_ARRAY
	extract_records "$1" | jq -c -s "$3 | .[]" | wrap_records >"$2"
}

gate_log() { # RAW_LOG SUMMARY_OUT
	"$verify_log" "$1" "$2" "$ENGINE_REGEX" "$GAME_COMMIT" \
		"$PAYLOAD_DIGEST" "$MANIFEST_DIGEST"
}

# ---------------------------------------------------------------------------
# Valid baselines. Every negative below is vacuous unless these pass.
# ---------------------------------------------------------------------------
mkdir -p "$scratch/base"
make_log A1 O1 "$TABLE_A1" "$scratch/base/A1-O1.log"
make_log A1 O2 "$TABLE_A1" "$scratch/base/A1-O2.log"
make_log B O1 "$TABLE_B" "$scratch/base/B-O1.log"
make_log B O2 "$TABLE_B" "$scratch/base/B-O2.log"

for run in A1-O1 A1-O2 B-O1 B-O2; do
	expect_pass "baseline run stream $run passes verify_log.sh" \
		gate_log "$scratch/base/$run.log" "$scratch/base/$run.summary.json"
done

expect_equal "baseline A1 record count" 95 "$(extract_records "$scratch/base/A1-O1.log" | wc -l)"
expect_equal "baseline B record count" 98 "$(extract_records "$scratch/base/B-O1.log" | wc -l)"

expect_pass "baseline four-run comparison passes compare_runs.sh" \
	"$compare_runs" "$scratch/base/comparison.jsonl" \
	"$scratch/base/A1-O1.summary.json" "$scratch/base/A1-O2.summary.json" \
	"$scratch/base/B-O1.summary.json" "$scratch/base/B-O2.summary.json"

gate_only() { # COMPARISON_JSONL
	"$compare_runs" --gate-only "$1" \
		"$scratch/base/A1-O1.summary.json" "$scratch/base/A1-O2.summary.json" \
		"$scratch/base/B-O1.summary.json" "$scratch/base/B-O2.summary.json"
}
expect_pass "baseline comparison stream passes its own gate" \
	gate_only "$scratch/base/comparison.jsonl"

compare_with() { # SUM_A1_O1 SUM_A1_O2 SUM_B_O1 SUM_B_O2
	"$compare_runs" "$scratch/work/comparison.jsonl" "$1" "$2" "$3" "$4"
}

mkdir -p "$scratch/work"
sum() { printf '%s' "$scratch/base/$1.summary.json"; }

corrupt_summary() { # SRC DST JQ_PROGRAM
	jq -c "$3" "$1" >"$2"
}

corrupt_comparison() { # DST JQ_PROGRAM_OVER_THE_ARRAY
	jq -c -s "$2 | .[]" "$scratch/base/comparison.jsonl" >"$1"
}

# A raw-log fixture: corrupt, then gate, then assert the stated fragment.
row_log() { # ROW LABEL FRAGMENT JQ_PROGRAM [ARM-ORDER, default B-O1]
	local row="$1" label="$2" fragment="$3" prog="$4" run="${5:-B-O1}"
	local dst="$scratch/work/row$row.log"
	corrupt_log "$scratch/base/$run.log" "$dst" "$prog"
	expect_failure "$row" "raw log" "$label" "$fragment" \
		gate_log "$dst" "$scratch/work/row$row.summary.json"
}

# ===========================================================================
# The 45 rows of contract section 16
# ===========================================================================

# ---- 1: empty file --------------------------------------------------------
: >"$scratch/work/row1.log"
expect_failure 1 "raw log" "empty raw log" "no JSON records found" \
	gate_log "$scratch/work/row1.log" "$scratch/work/row1.summary.json"

# ---- 2: marker line whose payload is not valid JSON (two fixtures) --------
cp "$scratch/base/B-O1.log" "$scratch/work/row2a.log"
printf '%s%s\n' "ACTION[Main]: $marker" '{"tag":"BROKEN",}' >>"$scratch/work/row2a.log"
expect_failure 2 "raw log" "marker payload is not valid JSON" "parse error" \
	gate_log "$scratch/work/row2a.log" "$scratch/work/row2a.summary.json"

{
	printf '%s%s\n' "ACTION[Main]: $marker" 'aGVsbG8gd29ybGQgZnJvbSB0aGUgcHJvYmU='
	printf '%s%s\n' "ACTION[Main]: $marker" 'd3A0MCB0NSBuZWdhdGl2ZSByb3cgdHdv'
	printf '%s%s\n' "ACTION[Main]: $marker" 'bm90IEpTT04gYXQgYWxsLCBieSBkZXNpZ24='
} >"$scratch/work/row2b.log"
expect_failure 2 "raw log" "base64 behind the marker prefix" "parse error" \
	gate_log "$scratch/work/row2b.log" "$scratch/work/row2b.summary.json"

# ---- 3: valid JSON of the wrong type -------------------------------------
cp "$scratch/base/B-O1.log" "$scratch/work/row3.log"
printf '%s%s\n' "ACTION[Main]: $marker" '[1,2,3]' >>"$scratch/work/row3.log"
expect_failure 3 "raw log" "valid JSON, wrong type" "record is not an object" \
	gate_log "$scratch/work/row3.log" "$scratch/work/row3.summary.json"

# ---- 4: truncated after the manifest record ------------------------------
extract_records "$scratch/base/B-O1.log" | awk 'NR == 1' | wrap_records >"$scratch/work/row4.log"
expect_failure 4 "raw log" "truncated after the manifest" \
	"terminal record is not complete" \
	gate_log "$scratch/work/row4.log" "$scratch/work/row4.summary.json"

# ---- 5: base64 appended with NO marker prefix ----------------------------
cp "$scratch/base/B-O1.log" "$scratch/work/row5.log"
printf '%s\n' 'aGVsbG8gd29ybGQgZnJvbSB0aGUgcHJvYmU=' >>"$scratch/work/row5.log"
expect_failure 5 "raw log" "ungated non-marker garbage" \
	"raw log contains ungated non-marker content" \
	gate_log "$scratch/work/row5.log" "$scratch/work/row5.summary.json"

# ---- 6 .. 43 (raw log rows) ----------------------------------------------
row_log 6 "schema deleted from one record" "record is missing schema" \
	'map(if .tag == "settling" then del(.schema) else . end)'

row_log 7 "schema set to a v1 value" "unexpected record schema" \
	'map(if .tag == "settling" then .schema = "grug_wp40_t5_probe_synthetic_v1" else . end)'

row_log 8 "emin.z deleted from an arm-B chunk_callback" "vector shape invalid" \
	'map(if .tag == "chunk_callback" and .kx == 8 then del(.emin.z) else . end)'

row_log 9 "extra key on a chunk_callback" "record has unexpected keys" \
	'map(if .tag == "chunk_callback" and .kx == 8 then .extra_probe_key = 1 else . end)'
row_log 9 "process_metrics.rss_bytes deleted instead of unavailable" \
	"record has unexpected keys" \
	'map(if .tag == "process_metrics" then del(.rss_bytes) else . end)'

row_log 10 "verdict record pasted into a run log" "comparison record in a run log" \
	'.[0:-1] + [{schema: "grug_wp40_t5_probe_synthetic_v0", stream: "comparison",
	  tag: "verdict", seq: 1, run_id_a: "A1-O1", run_id_b: "B-O1", id: "V-01",
	  lane: "content", result: "pass", predicates: {}, outcome: "",
	  detail: "pasted into the wrong stream"}] + .[-1:]'
row_log 10 "first_diff record pasted into a run log" "comparison record in a run log" \
	'.[0:-1] + [{schema: "grug_wp40_t5_probe_synthetic_v0", stream: "comparison",
	  tag: "first_diff", seq: 1, run_id_a: "A1-O1", run_id_b: "B-O1",
	  comparison: "SEAM:O1:A1-vs-B", lane: "content", region: "seam",
	  flat_index: 1, pos: {x: 840, y: 0, z: 712}, value_a: -1, value_b: -1}]
	  + .[-1:]'

row_log 11 "seq 4 dropped from the main partition" "seq is not contiguous" \
	'map(select((.state == "main" and .seq == 4) | not))'

row_log 12 "arm A1 on one record of a B run" "arm is not constant within a run" \
	'map(if .tag == "settling" then .arm = "A1" else . end)'

row_log 13 "non-zero ops counter on an arm-A1 chunk_callback" \
	"arm A1 performed a VoxelManip call" \
	'map(if .tag == "chunk_callback" and .kx == 8 then .ops.get_data = 1 else . end)' \
	A1-O1

row_log 14 "ops.set_data = 2 for case bounded" "bounded set_data count is not 1" \
	'map(if .tag == "chunk_callback" and .case == "bounded" then .ops.set_data = 2 else . end)'

row_log 15 "set_param2_data = 0 with dirty_param2 > 0" \
	"set_param2_data count does not match the realized param2 dirty set" \
	'map(if .tag == "chunk_callback" and .case == "bounded" then .ops.set_param2_data = 0 else . end)'

row_log 16 "param2 extent set to the content bounding box" \
	"param2 write mask is not the declared facedir box" \
	'map(if .tag == "chunk_callback" and .case == "bounded"
	  then .param2_extent_min = {x: 628, y: -8, z: 712}
	     | .param2_extent_max = {x: 667, y: 7, z: 719}
	  else . end)'

# ---- 17: comparison -- the param2 mask, proven by digest_incl ------------
# A param2 write inside the `water` box is INVISIBLE to the residual: `water`
# is one of the four boxes the kx=8 write_extent exclusion removes. Only the
# per-box digest_incl comparison of 10.10 can see it, which is reviewer item 10.
lane_text "$scratch/work/row17.txt" param2 "${BOX[water]}" \
	"${BOX[facedir]} ${BOX[water]}" ""
ROW17_SHA="$(sha256sum -- "$scratch/work/row17.txt" | awk '{print $1}')"
corrupt_summary "$(sum B-O1)" "$scratch/work/row17.summary.json" \
	"$(printf '%s' '.digests_incl = (.digests_incl | map(if .lane == "param2" and .box_name == "water" then .sha256 = "'"$ROW17_SHA"'" else . end))')"
expect_failure 17 "comparison" "param2 lane differs over the water box" \
	"param2 lane changed outside the declared param2 write mask" \
	compare_with "$(sum A1-O1)" "$(sum A1-O2)" "$scratch/work/row17.summary.json" "$(sum B-O2)"

row_log 18 "update_liquids = 1 with dirty_liquid false" \
	"update_liquids called with an empty liquid dirty set" \
	'map(if .tag == "chunk_callback" and .kx == 10 then .ops.update_liquids = 1 else . end)'

row_log 19 "update_liquids = 0 with dirty_liquid true" \
	"liquid dirty set is nonempty but update_liquids was not called" \
	'map(if .tag == "chunk_callback" and .kx == 8 then .ops.update_liquids = 0 else . end)'

# Rows 20a/20b need a chunk whose light dirty set is empty. Every arm-B
# callback of the baseline has dirty_light = true and every arm-A1 callback
# would fail the earlier arm-A1 zero-ops assertion first, so the fixture also
# clears dirty_light on the arm-B case-4 chunk and zeroes the other three
# lighting counters -- leaving exactly the one counter the row names.
row_log 20 "calc_lighting = 1 with dirty_light false" \
	"lighting call performed with an empty light dirty set" \
	'map(if .tag == "chunk_callback" and .kx == 10
	  then .dirty_light = false | .ops.get_light_data = 0
	     | .ops.set_light_data = 0 | .ops.set_lighting = 0 | .ops.calc_lighting = 1
	  else . end)'
row_log 20 "set_light_data = 1 with dirty_light false" \
	"lighting call performed with an empty light dirty set" \
	'map(if .tag == "chunk_callback" and .kx == 10
	  then .dirty_light = false | .ops.get_light_data = 0
	     | .ops.calc_lighting = 0 | .ops.set_lighting = 0 | .ops.set_light_data = 1
	  else . end)'

row_log 21 "set_light_data = 0 with dirty_light true" \
	"light dirty set is nonempty but set_light_data was not called" \
	'map(if .tag == "chunk_callback" and .kx == 10 then .ops.set_light_data = 0 else . end)'

row_log 22 "restored_outside_dirty_mismatch_count = 1" \
	"param1 outside the light write box was not restored" \
	'map(if .tag == "chunk_callback" and .kx == 8
	  then .restored_outside_dirty_mismatch_count = 1 else . end)'
row_log 22 "the two outside-box light hashes differ" \
	"param1 outside the light write box was not restored" \
	'map(if .tag == "chunk_callback" and .kx == 8
	  then .light_outside_box_restored_sha256 = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
	  else . end)'

row_log 23 "one by-box entry no longer sums to the scalar" \
	"dirty counts by box do not sum to the scalar" \
	'map(if .tag == "chunk_callback" and .kx == 8
	  then .dirty_content_by_box.cut = 511 else . end)'

# The four values sum to the record scalar, so ONLY the key-set assertion can
# fire: the fixture isolates the gate section 16 names.
row_log 24 "case-4 record keyed like a bounded record" \
	"dirty by-box key set is wrong for this case" \
	'map(if .tag == "chunk_callback" and .case == "4lo"
	  then .dirty_content_by_box = {cut: 128, fill: 128, water: 128, facedir: 128}
	  else . end)'

row_log 25 "maxp.x = minp.x + 80" "central chunk extent is not 80 nodes" \
	'map(if .tag == "chunk_callback" and .kx == 8 then .maxp.x = (.minp.x + 80) else . end)'

# The case-4 write extents are gate literals, so the record-carried extent that
# can be widened past maxp.x is the light write box: 928 > maxp.x = 927 while
# still inside the emerged box (943), which is what isolates this assertion
# from the emerged-containment half of the same predicate.
row_log 26 "case-4 light write extent widened past maxp.x" \
	"payload wrote outside its central owner slice" \
	'map(if .tag == "chunk_callback" and .kx == 11 then .light_write_box_max.x = 928 else . end)'

# ---- 27: comparison -- union versus bounding box ------------------------
# `cut` is widened by one node in +x to x = 636. That voxel is INSIDE the four
# boxes' 5,120-voxel bounding box and OUTSIDE their 2,048-voxel union, so:
#   * excluding the UNION leaves it in the residual -> the two arms diverge;
#   * excluding the BOUNDING BOX hides it -> the two arms agree and no gate
#     fires. Both are asserted, so the detector is demonstrated, not assumed.
lane_text "$scratch/work/row27-union.txt" content "${CORE[8]}" \
	"$CUT_WIDE ${BOX[fill]} ${BOX[water]} ${BOX[facedir]} ${BOX[4lo]} ${BOX[4hi]}" \
	"${EXCL_WRITE[8]}"
lane_text "$scratch/work/row27-bbox.txt" content "${CORE[8]}" \
	"$CUT_WIDE ${BOX[fill]} ${BOX[water]} ${BOX[facedir]} ${BOX[4lo]} ${BOX[4hi]}" \
	"$BBOX8"
ROW27_UNION="$(sha256sum -- "$scratch/work/row27-union.txt" | awk '{print $1}')"
ROW27_BBOX="$(sha256sum -- "$scratch/work/row27-bbox.txt" | awk '{print $1}')"
ROW27_CLEAN="$(jq -r '.digests_excl[] | select(.kx == 8 and .lane == "content"
	and .excluded_kind == "write_extent" and .pass == 1) | .sha256' "$(sum A1-O1)")"
expect_equal "row 27 control: the out-of-union write is visible in the union residual" \
	"different" "$(if [[ "$ROW27_UNION" == "$ROW27_CLEAN" ]]; then echo same; else echo different; fi)"
expect_equal "row 27 control: the same write is invisible under bounding-box exclusion" \
	"same" "$(if [[ "$ROW27_BBOX" == "$ROW27_CLEAN" ]]; then echo same; else echo different; fi)"
expect_equal "row 27 control: 64 written voxels survive the union exclusion" 64 \
	"$(lane_volume "${CORE[8]}" "$CUT_WIDE ${BOX[fill]} ${BOX[water]} ${BOX[facedir]}" \
		"${EXCL_WRITE[8]}")"
expect_equal "row 27 control: none survives the bounding-box exclusion" 0 \
	"$(lane_volume "${CORE[8]}" "$CUT_WIDE ${BOX[fill]} ${BOX[water]} ${BOX[facedir]}" \
		"$BBOX8")"
corrupt_summary "$(sum B-O1)" "$scratch/work/row27.summary.json" \
	"$(printf '%s' '.digests_excl = (.digests_excl | map(if .kx == 8 and .lane == "content" and .excluded_kind == "write_extent" then .sha256 = "'"$ROW27_UNION"'" else . end))')"
expect_failure 27 "comparison" "cut widened to x = 636, outside the declared union" \
	"payload wrote outside its declared extent" \
	compare_with "$(sum A1-O1)" "$(sum A1-O2)" "$scratch/work/row27.summary.json" "$(sum B-O2)"

# ---- 28: the excluded region replaced by its bounding box ---------------
row_log 28 "kx=8 excluded_boxes replaced by the 5,120-voxel bounding box" \
	"excluded region is not the declared box list" \
	'map(if .tag == "digest_excl" and .kx == 8 and .lane == "content" and .pass == 1
	  then .excluded_boxes = [{min: {x: 628, y: -8, z: 712}, max: {x: 667, y: 7, z: 719}}]
	  else . end)'

row_log 29 "excluded_voxels no longer complements node_count" \
	"CORE residual and excluded voxels do not sum to 110592" \
	'map(if .tag == "digest_excl" and .kx == 8 and .lane == "content" and .pass == 1
	  then .excluded_voxels = 2049 else . end)'

row_log 30 "compared box displaced by 64 nodes in +y" \
	"compared box is not at its contract coordinates" \
	'map(if .tag == "digest" and .region == "core" and .kx == 8
	     and .lane == "content" and .pass == 1
	  then .box_min.y += 64 | .box_max.y += 64 else . end)'

row_log 31 "emerge_done served FROM_DISK" "measured chunk was not generated by this run" \
	'map(if .tag == "emerge_done" and .kx == 10 then .action = "EMERGE_FROM_DISK" else . end)'

row_log 32 "content_ignore_count = 1 on a CORE record" \
	"compared region contains CONTENT_IGNORE" \
	'map(if .tag == "digest" and .region == "core" and .kx == 8
	     and .lane == "content" and .pass == 1
	  then .content_ignore_count = 1 else . end)'

row_log 33 "only pass 1 digests emitted" "quiescence proof failed" \
	'map(select(((.tag == "digest" or .tag == "digest_excl" or .tag == "digest_incl")
	  and .pass == 2) | not))'
row_log 33 "the two passes disagree on one box" "quiescence proof failed" \
	'map(if .tag == "digest_incl" and .pass == 2 and .lane == "content"
	     and .box_name == "cut"
	  then .sha256 = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
	  else . end)'

row_log 34 "production_adopted = true on a chunk_callback" \
	"probe IPC telemetry must not be marked production adopted" \
	'map(if .tag == "chunk_callback" and .kx == 8 then .production_adopted = true else . end)'

row_log 35 "one ipc_readback key renamed" "ipc key set is not the four declared keys" \
	'map(if .tag == "ipc_readback"
	  then .keys = (.keys | map(if . == "grug_wp40_t5_probe:chunk:11"
	       then "grug_wp40_t5_probe:chunk:12" else . end))
	  else . end)'

# shellcheck disable=SC2016  # $c and $rest are jq bindings; shell expansion here would destroy the program
row_log 36 "abort record carrying code A-99" "abort code is not in the closed set" \
	'(map(select(.tag == "complete")) | .[0]) as $c
	 | (map(select(.tag != "complete"))) as $rest
	 | $rest
	   + [($c | del(.ok, .chunks_generated, .records_emitted, .total_us,
	        .emerge_deadline_us, .run_deadline_us, .emerge_deadline_met,
	        .run_deadline_met)
	      + {tag: "abort", code: "A-99", reason: "synthetic", detail: "row 36"}),
	      ($c + {seq: ($c.seq + 1), records_emitted: (($rest | length) + 2)})]'

row_log 37 "complete.run_deadline_met = false" "run deadline exceeded" \
	'map(if .tag == "complete" then .run_deadline_met = false else . end)'
row_log 37 "complete.emerge_deadline_met = false" "emerge deadline exceeded" \
	'map(if .tag == "complete" then .emerge_deadline_met = false else . end)'

row_log 38 "chunk_callback cardinality of 2" "chunk_callback cardinality is not 3" \
	'map(select((.tag == "chunk_callback" and .kx == 10) | not))'

# ---- 39: comparison -- CORE decomposition consistency -------------------
# compare_runs.sh implements `core digest mismatch` as: when the residual AND
# every named box inside CORE agree between the arms, the full CORE digest must
# agree too. For kx = 8 the named boxes legitimately differ between arms, so a
# flipped CORE(8) digest leaves the antecedent false and nothing fires. CORE(10)
# has no named box inside it, so its antecedent is true in the baseline and a
# single flipped hex character is caught.
ROW39_SHA="$(jq -r '.digests[] | select(.region == "core" and .kx == 10
	and .lane == "content" and .pass == 1) | .sha256' "$(sum B-O1)" |
	sed 's/^./f/; s/^f\(.\)/f\1/')"
if [[ "$ROW39_SHA" == "$(jq -r '.digests[] | select(.region == "core" and .kx == 10 and .lane == "content" and .pass == 1) | .sha256' "$(sum B-O1)")" ]]; then
	ROW39_SHA="0${ROW39_SHA:1}"
fi
corrupt_summary "$(sum B-O1)" "$scratch/work/row39.summary.json" \
	"$(printf '%s' '.digests = (.digests | map(if .region == "core" and .kx == 10 and .lane == "content" and .pass == 1 then .sha256 = "'"$ROW39_SHA"'" else . end))')"
expect_failure 39 "comparison" "one hex character flipped in the CORE(10) digest" \
	"core digest mismatch" \
	compare_with "$(sum A1-O1)" "$(sum A1-O2)" "$scratch/work/row39.summary.json" "$(sum B-O2)"

# ---- 40: comparison -- content id table --------------------------------
corrupt_summary "$(sum B-O1)" "$scratch/work/row40.summary.json" \
	'.content_id_table_sha256 = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"'
expect_failure 40 "comparison" "content id table changed in one run" \
	"content id table is not identical across arms" \
	compare_with "$(sum A1-O1)" "$(sum A1-O2)" "$scratch/work/row40.summary.json" "$(sum B-O2)"

# ---- 41: comparison -- three of four predicates true --------------------
# P1..P4 are the four edges of a 4-cycle over an equivalence relation, so no
# assignment of digest VALUES can make exactly three true. The corruption is
# therefore sited where section 16 sites it -- a synthetic verdict input -- and
# is proven against the emitted stream, where compare_runs.sh re-checks the
# combination independently of the generator that computed it.
corrupt_comparison "$scratch/work/row41.jsonl" \
	'map(if .tag == "verdict" and .id == "V-05" and .lane == "content"
	  then .predicates.P3 = true else . end)'
expect_failure 41 "comparison" "three of P1..P4 true in a synthetic verdict" \
	"impossible predicate combination" \
	gate_only "$scratch/work/row41.jsonl"

# ---- 42: comparison -- V-05 pass on a non-persisted outcome -------------
corrupt_comparison "$scratch/work/row42.jsonl" \
	'map(if .tag == "verdict" and .id == "V-05" and .lane == "content"
	  then .outcome = "no_delta" else . end)'
expect_failure 42 "comparison" "V-05 reports pass on outcome no_delta" \
	"inconclusive row reported as a pass" \
	gate_only "$scratch/work/row42.jsonl"

# ---- 43: comparison -- a differing pair with no first_diff --------------
# seq is renumbered so the cardinality assertion is what fires, not contiguity.
# shellcheck disable=SC2016  # $n is a jq binding; shell expansion here would destroy the program
corrupt_comparison "$scratch/work/row43.jsonl" \
	'([.[] | select(.tag == "first_diff" and .comparison == "SEAM:O1:A1-vs-B"
	    and .lane == "content")] | length) as $n
	 | (if $n == 1 then . else error("row 43 fixture found " + ($n | tostring)
	    + " first_diff records to delete") end)
	 | map(select((.tag == "first_diff" and .comparison == "SEAM:O1:A1-vs-B"
	    and .lane == "content") | not))
	 | to_entries | map(.value + {seq: (.key + 1)})'
expect_failure 43 "comparison" "first_diff deleted for a differing pair" \
	"differing digest pair has no first_diff record" \
	gate_only "$scratch/work/row43.jsonl"

# ---- 44: comparison -- a localized first_diff moved off its named box ----
# The moved record is INTERNALLY CONSISTENT: pos goes one voxel in +x and the
# flat index goes with it, so x-fastest self-consistency still holds and a
# self-consistency check alone would accept it. Only the recomputation from the
# digest_incl evidence catches it -- 4lo is the first seam half whose content
# digest differs between A1-O1 and B-O1, and its minimum corner is 840,0,712.
# shellcheck disable=SC2016  # $hit is a jq binding; shell expansion here would destroy the program
corrupt_comparison "$scratch/work/row44.jsonl" \
	'([.[] | select(.tag == "first_diff" and .comparison == "SEAM:O1:A1-vs-B"
	    and .lane == "content")]) as $hit
	 | (if ($hit | length) == 1 and $hit[0].flat_index == 31505
	      and $hit[0].pos == {x: 840, y: 0, z: 712} then .
	    else error("row 44 fixture premise: the baseline SEAM:O1:A1-vs-B content record is not the localized 31505 record at 840,0,712") end)
	 | map(if .tag == "first_diff" and .comparison == "SEAM:O1:A1-vs-B"
	       and .lane == "content"
	    then .pos = {x: 841, y: 0, z: 712} | .flat_index = 31506
	    else . end)'
expect_failure 44 "comparison" "localized first_diff moved one voxel, its index moved to match" \
	"first_diff localization is not the recomputed named-box minimum" \
	gate_only "$scratch/work/row44.jsonl"

# ---- 45: comparison -- an unlocalized first_diff off the sentinel --------
# flat_index -1 says "no named box is implicated and this coordinate was never
# measured"; the only coordinate admissible under that claim is the compared
# box minimum. A -1 record parked on any other well-formed vector publishes a
# number nothing measured, wearing the sentinel as cover.
# shellcheck disable=SC2016  # $hit and $target are jq bindings; shell expansion here would destroy the program
corrupt_comparison "$scratch/work/row45.jsonl" \
	'([.[] | select(.tag == "first_diff" and .flat_index == -1)]) as $hit
	 | (if ($hit | length) >= 1
	      and ($hit | map(.pos == {x: 824, y: -16, z: 696}) | all) then .
	    else error("row 45 fixture premise: the baseline carries no unlocalized first_diff at the SEAM minimum 824,-16,696") end)
	 | ($hit[0].seq) as $target
	 | map(if .tag == "first_diff" and .seq == $target
	    then .pos = {x: 830, y: -8, z: 700} else . end)'
expect_failure 45 "comparison" "unlocalized first_diff parked away from the SEAM minimum" \
	"unlocalized first_diff is not at the compared box minimum" \
	gate_only "$scratch/work/row45.jsonl"

# ===========================================================================
# The two checks section 16 names as NOT corruptions of an emitted stream
# ===========================================================================

# ---- A-02: the injected-payload digest refusal --------------------------
# The refusal itself lives in run_t5_probe.sh's injection step, which is inside
# the opt-in expensive half. This suite runs BEFORE that half and must not
# invoke it, so the refusal PREDICATE is exercised here directly against
# digest_lib.sh -- which documents exactly this use -- over a mutated flattened
# injected tree, and the runner's literal message is bound so the two cannot
# drift apart silently.
a02_message='injected probe payload digest differs from the working-tree digest (A-02)'
grep -qF -- "$a02_message" "$runner" ||
	fail "run_t5_probe.sh no longer carries the A-02 refusal message: $a02_message"

mkdir -p "$scratch/a02/tree" "$scratch/a02/injected"
printf '%s\n' 'name = grug_wp40_t5_probe' 'description = fixture' \
	>"$scratch/a02/tree/mod.conf"
printf '%s\n' '-- fixture init' >"$scratch/a02/tree/init.lua"
printf '%s\n' '-- fixture mapgen' >"$scratch/a02/tree/mapgen.lua"
printf '%s\n' '-- fixture proxy' >"$scratch/a02/tree/vm_proxy.lua"
cp "$scratch/a02/tree/mod.conf" "$scratch/a02/tree/init.lua" \
	"$scratch/a02/tree/mapgen.lua" "$scratch/a02/tree/vm_proxy.lua" \
	"$scratch/a02/injected/"

a02_refusal() { # WORKING_TREE_DIR INJECTED_DIR
	local wanted injected
	wanted="$(wp40_t5_probe_payload_digest_dir "$1")"
	injected="$(wp40_t5_probe_payload_digest_dir "$2")"
	if [[ "$injected" != "$wanted" ]]; then
		printf 'working tree: %s\n' "$wanted" >&2
		printf 'injected:     %s\n' "$injected" >&2
		printf '%s\n' "$a02_message" >&2
		return 1
	fi
	return 0
}

expect_pass "an unmutated injected tree reproduces the working-tree payload digest" \
	a02_refusal "$scratch/a02/tree" "$scratch/a02/injected"
printf '%s\n' '-- mutated after injection' >>"$scratch/a02/injected/mapgen.lua"
expect_failure "A-02" "injected" "mutated injected payload tree" \
	"injected probe payload digest differs" \
	a02_refusal "$scratch/a02/tree" "$scratch/a02/injected"

# ---- the manifest-digest fixture (13.2, digest_audit.sh:17-43) ----------
mkdir -p "$scratch/mfd/one" "$scratch/mfd/two"
for run_id in A1-O1 A1-O2 B-O1 B-O2; do
	printf '%s\n' "fixed_map_seed = 40200517" "mg_name = v7" "chunksize = 5" \
		"liquid_update = 86400" "port = 32001" "run_id = $run_id" \
		>"$scratch/mfd/one/$run_id.conf"
	cp "$scratch/mfd/one/$run_id.conf" "$scratch/mfd/two/renamed-$run_id.conf"
done
coordinate_text="$(printf '%s\n' 'ky=0' 'kz=9' 'kx=8,10,11' 'gap_kx=9')"
extent_text="$(printf '%s\n' 'bounded_content=2048' 'bounded_param2=512' \
	'case4_content=512' 'case4_param2=0')"

# The stage-1 log-shape regex is read from the gate that owns it rather than
# duplicated here, so the fixture binds the committed bytes (12.5 stage 1).
LOG_SHAPE_REGEX="$("$verify_log" --print-log-shape-regex)"

manifest_digest_at() { # DIR PREFIX
	wp40_t5_probe_manifest_digest "$GAME_COMMIT" "$PAYLOAD_DIGEST" \
		"$ENGINE_REGEX" "$coordinate_text" "$extent_text" \
		"$1/${2}A1-O1.conf" "$1/${2}A1-O2.conf" \
		"$1/${2}B-O1.conf" "$1/${2}B-O2.conf" "$LOG_SHAPE_REGEX"
}

mfd_first="$(manifest_digest_at "$scratch/mfd/one" "")"
mfd_second="$(manifest_digest_at "$scratch/mfd/two" "renamed-")"
if [[ "$mfd_first" != "$mfd_second" ]]; then
	fail "manifest digest is path sensitive: identical config bytes at two different paths produced different digests"
fi
record_row "13.2" "fixture" "digest is path sensitive" \
	"HELD -- identical config bytes at two paths give one digest"

printf '%s\n' 'water_level = 2' >>"$scratch/mfd/two/renamed-B-O1.conf"
mfd_changed="$(manifest_digest_at "$scratch/mfd/two" "renamed-")"
if [[ "$mfd_first" == "$mfd_changed" ]]; then
	fail "manifest digest did not change when one config line was appended"
fi
record_row "13.2" "fixture" "digest did not change" \
	"HELD -- one appended config line changes the digest"

# The two assertions above are only worth their line count if they can fail, so
# the named anti-pattern is run against the same comparison: a digest taken over
# `sha256sum` OUTPUT lines embeds the path and IS path sensitive
# (capture_t0_baseline.sh:63-68). digest_lib.sh does not do this; this control
# proves the check would catch it if it did.
path_sensitive_control() {
	local first second
	first="$(sha256sum -- "$scratch/mfd/one/B-O1.conf" | sha256sum | awk '{print $1}')"
	second="$(sha256sum -- "$scratch/mfd/two/renamed-A1-O1.conf" | sha256sum | awk '{print $1}')"
	if [[ "$first" != "$second" ]]; then
		printf 'manifest digest is path sensitive: identical config bytes at two different paths produced different digests\n' >&2
		return 1
	fi
	return 0
}
expect_failure "13.2" "fixture" "sha256sum-output-line anti-pattern control" \
	"digest is path sensitive" path_sensitive_control

# ===========================================================================
# Report
# ===========================================================================
# rows_covered also carries the two non-stream labels A-02 and 13.2, so only the
# numeric labels are counted against the section-16 total.
section16_rows=0
for _row in $rows_covered; do
	case "$_row" in
		''|*[!0-9]*) ;;
		*) section16_rows=$((section16_rows + 1)) ;;
	esac
done
if (( section16_rows != 45 )); then
	fail "expected 45 section-16 rows to be exercised, counted $section16_rows"
fi

printf '%-5s %-11s %-56s %s\n' "row" "stream" "fragment" "result"
printf '%s\n' "$(printf '%.0s-' {1..118})"
printf '%s\n' "${table[@]}"
printf '%s\n' "$(printf '%.0s-' {1..118})"

printf 'WP40 t5-probe selftest: PASS (47 checks -- 45 section-16 rows proven by %d fixtures, plus the A-02 refusal and the manifest-digest fixture; %d negative fixtures in all, no engine capture)\n' \
	"$section16_fixtures" "$fixtures"
