#!/usr/bin/env bash
# WP40 T5-0 engine-seam probe -- cross-run comparison over the four runs'
# summaries. Emits and gates `comparison.jsonl` (contract 12.7).
#
# What it does, in order:
#   1. the six cross-run assertions X-01 ... X-06 (contract 10.8) -- no
#      comparison is reported unless all six hold;
#   2. all NINE verdicts V-01 ... V-09 (contract 10.9), with the 10.13 cascade
#      applied verbatim, `inconclusive` as a first-class value and no outcome
#      rewritten as a probe failure;
#   3. `first_diff` localization records, one per differing compared digest
#      pair and zero for an equal pair;
#   4. its OWN fail-closed gate over the emitted file, applying the 12.7
#      common-field set -- never the 12.2 run-stream one.
#
# Scope discipline this file must keep (contract 3.2, 10.13, 18 item 19):
# micro-case 4 is a bounded persistence and seam OBSERVATION. It is not a test
# of the engine unfinished-slice bug, it claims no settled liquid, and it tests
# no halo-light idempotence -- the probe writes no halo light at all.
#
# KNOWN EVIDENCE LIMIT, recorded rather than papered over: `first_diff` is
# specified with `flat_index`, `pos`, `value_a` and `value_b`, but a SHA-256
# says only WHETHER two byte strings differ, never HOW, and this script sees
# only digests. Localization is therefore as fine as `digest_incl` allows --
# the named write box implicated, else the compared box origin -- and
# `value_a` / `value_b` carry the sentinel -1, "not resolvable from digest
# evidence". No node value is invented.
set -euo pipefail

usage() {
	cat >&2 <<'USAGE'
usage: compare_runs.sh RESULTS_DIR [OUT_JSONL]
       compare_runs.sh OUT_JSONL SUM_A1_O1 SUM_A1_O2 SUM_B_O1 SUM_B_O2
       compare_runs.sh --gate-only COMPARISON_JSONL \
                       SUM_A1_O1 SUM_A1_O2 SUM_B_O1 SUM_B_O2

RESULTS_DIR is the pinned layout: <dir>/run-A1-O1/summary.json ... and the
comparison stream defaults to <dir>/comparison.jsonl.

--gate-only runs the comparison-stream gate over an EXISTING comparison.jsonl
without regenerating it. It is what makes the section-16 rows that corrupt the
comparison stream provable, and it re-gates committed evidence.
USAGE
}

case "${1:-}" in
	-h|--help) usage; exit 0 ;;
esac

gate_only=0
if [[ "${1:-}" == "--gate-only" ]]; then
	if [[ "$#" -ne 6 ]]; then
		usage
		exit 2
	fi
	gate_only=1
	out_jsonl="$2"
	sum_a1o1="$3"
	sum_a1o2="$4"
	sum_bo1="$5"
	sum_bo2="$6"
	[[ -f "$out_jsonl" ]] || {
		echo "error: comparison stream not found: $out_jsonl" >&2
		exit 2
	}
elif [[ "$#" -eq 1 || "$#" -eq 2 ]] && [[ -d "${1:-}" ]]; then
	results_dir="$1"
	out_jsonl="${2:-$results_dir/comparison.jsonl}"
	sum_a1o1="$results_dir/run-A1-O1/summary.json"
	sum_a1o2="$results_dir/run-A1-O2/summary.json"
	sum_bo1="$results_dir/run-B-O1/summary.json"
	sum_bo2="$results_dir/run-B-O2/summary.json"
elif [[ "$#" -eq 5 ]]; then
	out_jsonl="$1"
	sum_a1o1="$2"
	sum_a1o2="$3"
	sum_bo1="$4"
	sum_bo2="$5"
else
	usage
	exit 2
fi

# `rg` is preflighted because the package shell rule requires it up front.
for tool in jq rg; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "error: $tool is required by the WP40 t5-probe comparison gate" >&2
		exit 127
	}
done

for f in "$sum_a1o1" "$sum_a1o2" "$sum_bo1" "$sum_bo2"; do
	[[ -f "$f" ]] || {
		echo "error: run summary not found: $f" >&2
		exit 2
	}
done

scratch="$(mktemp -d /tmp/grudgelands-wp40-t5-probe.XXXXXX)"
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-t5-probe.*) rm -rf -- "$scratch" ;;
		*) echo "refusing unsafe cleanup path: $scratch" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

staged="$scratch/comparison.jsonl"
if (( gate_only )); then
	cp -- "$out_jsonl" "$staged"
fi

# ---------------------------------------------------------------------------
# Generator: X-01 ... X-06, then the nine verdicts and the first_diff records.
# Every gate failure is a literal error("...") so section 16 fragments exist.
# ---------------------------------------------------------------------------
if (( gate_only == 0 )); then
jq -nc \
	--slurpfile s_a1o1 "$sum_a1o1" \
	--slurpfile s_a1o2 "$sum_a1o2" \
	--slurpfile s_bo1 "$sum_bo1" \
	--slurpfile s_bo2 "$sum_bo2" \
'
	def run_ids: ["A1-O1", "A1-O2", "B-O1", "B-O2"];
	def lanes: ["content", "param2", "light_day", "light_night"];
	def light_lanes: ["light_day", "light_night"];
	def node_lanes: ["content", "param2"];
	def named_boxes: ["cut", "fill", "water", "facedir", "4lo", "4hi"];
	def seam_halves: ["4lo", "4hi"];
	def core_boxes8: ["cut", "fill", "water", "facedir"];
	def measured_kx: [8, 10, 11];
	def core_box($kx):
		{min: {x: (80 * $kx - 16), y: -16, z: 704},
		 max: {x: (80 * $kx + 31), y: 31, z: 751}};
	def seam_box:
		{min: {x: 824, y: -16, z: 696}, max: {x: 871, y: 23, z: 735}};
	def region_box($region; $kx):
		if $region == "core" then core_box($kx) else seam_box end;
	def named_box($n):
		if $n == "cut" then {min: {x: 628, y: 0, z: 712}, max: {x: 635, y: 7, z: 719}}
		elif $n == "fill" then {min: {x: 628, y: -8, z: 712}, max: {x: 635, y: -1, z: 719}}
		elif $n == "water" then {min: {x: 644, y: 0, z: 712}, max: {x: 651, y: 7, z: 719}}
		elif $n == "facedir" then {min: {x: 660, y: 0, z: 712}, max: {x: 667, y: 7, z: 719}}
		elif $n == "4lo" then {min: {x: 840, y: 0, z: 712}, max: {x: 847, y: 7, z: 719}}
		else {min: {x: 848, y: 0, z: 712}, max: {x: 855, y: 7, z: 719}} end;
	def boxes_in($region; $kx):
		if $region == "seam" then seam_halves
		elif $kx == 8 then core_boxes8
		else [] end;
	def flat_index($box; $p):
		($box.max.x - $box.min.x + 1) as $ex
		| ($box.max.y - $box.min.y + 1) as $ey
		| (($p.z - $box.min.z) * $ey * $ex + ($p.y - $box.min.y) * $ex
			+ ($p.x - $box.min.x) + 1);

	{ "A1-O1": $s_a1o1[0], "A1-O2": $s_a1o2[0],
	  "B-O1": $s_bo1[0], "B-O2": $s_bo2[0] } as $R
	| def dig($id; $region; $kx; $lane; $pass):
		[$R[$id].digests[] | select(.region == $region and .kx == $kx
			and .lane == $lane and .pass == $pass)]
		| if length == 1 then .[0].sha256
			else error("run summary is missing a compared digest") end;
	def dexcl($id; $kx; $lane; $kind; $pass):
		[$R[$id].digests_excl[] | select(.kx == $kx and .lane == $lane
			and .excluded_kind == $kind and .pass == $pass)]
		| if length == 1 then .[0].sha256
			else error("run summary is missing a residual digest") end;
	def dincl($id; $lane; $box; $pass):
		[$R[$id].digests_incl[] | select(.lane == $lane and .box_name == $box
			and .pass == $pass)]
		| if length == 1 then .[0].sha256
			else error("run summary is missing an included-extent digest") end;
	# The "// {}" is not cosmetic: core.write_json renders an empty Lua table as
	# JSON null (reference_projects/luanti/doc/lua_api.md:8112-8113), so
	# dirty_param2_by_box arrives as null on every case-4 chunk. Normalising
	# here keeps has() off a null receiver rather than relying on a particular
	# jq build tolerating it.
	def by_box_dirty($id; $lane; $box):
		[$R[$id].chunks[]
			| (if $lane == "content" then (.dirty_content_by_box // {})
				else (.dirty_param2_by_box // {}) end)
			| select(has($box)) | .[$box]]
		| if length == 0 then 0 else .[0] end;

	# ---- shape of the four inputs, before anything is read from them -------
	(if (run_ids | map($R[.] != null) | all)
		then . else error("comparison needs all four run summaries") end)
	| (if (run_ids | map($R[.].schema == "wp40-t5-probe-summary-v1") | all)
		then . else error("summary is not a t5-probe run summary") end)
	| (if (run_ids | map($R[.].run_id) | sort) == run_ids
		then . else error("the four summaries are not the four runs of 10.7") end)
	| (if (run_ids | map($R[.].status == "PASS" and $R[.].abort_code == null) | all)
		then . else error("a run summary did not pass its own log gate") end)

	# ---- V-09 first: without quiescence no verdict of any kind is reported -
	| (if (run_ids | map($R[.].quiescent == true and $R[.].two_pass_identical == true) | all)
		then . else error("quiescence proof failed") end)

	# ---- X-01 ... X-06 ----------------------------------------------------
	| (if (run_ids | map($R[.].content_id_table_sha256) | unique | length) == 1
		then . else error("content id table is not identical across arms") end)
	| (if (run_ids | map($R[.].mapgen_settings) | unique | length) == 1
			and (run_ids | map($R[.].mapgen_noiseparams_sha256) | unique | length) == 1
		then . else error("realized mapgen settings differ between runs") end)
	| (if (["O1", "O2"] | map(
			($R["A1-" + .].emerge_order) == ($R["B-" + .].emerge_order) and
			($R["A1-" + .].emerge_order) == (if . == "O1" then [8, 10, 11] else [11, 10, 8] end)) | all)
		then . else error("realized emerge order differs between arms") end)
	| (if (run_ids | map($R[.].payload_digest) | unique | length) == 1
		then . else error("injected payload digest differs across runs") end)
	| (if (run_ids | map([$R[.].engine_string, $R[.].engine_hash, $R[.].lua_runtime])
			| unique | length) == 1
		then . else error("engine identity differs across runs") end)
	| (if (run_ids | map(. as $id | $R[$id].chunks
			| map(if $R[$id].arm == "B" then .emin_emax_ok == true
				else .emin_emax_ok == null end) | all) | all)
		then . else error("emin and emax are not minp-16 and maxp+16") end)

	# ---- V-01 containment on BOTH node lanes ------------------------------
	| (if (["O1", "O2"] | map(. as $o | node_lanes | map(. as $l
			| measured_kx | map(. as $k | [1, 2] | map(. as $p
				| dexcl("B-" + $o; $k; $l; "write_extent"; $p)
					== dexcl("A1-" + $o; $k; $l; "write_extent"; $p)) | all) | all) | all) | all)
		then . else error("payload wrote outside its declared extent") end)
	# ---- V-02 containment on the light lanes ------------------------------
	| (if (["O1", "O2"] | map(. as $o | light_lanes | map(. as $l
			| measured_kx | map(. as $k | [1, 2] | map(. as $p
				| dexcl("B-" + $o; $k; $l; "light_write_box"; $p)
					== dexcl("A1-" + $o; $k; $l; "light_write_box"; $p)) | all) | all) | all) | all)
		then . else error("payload wrote outside its declared extent") end)
	# ---- CORE decomposition consistency -----------------------------------
	# CORE is the residual (digest_excl) united with the named boxes inside it.
	# When both halves of that decomposition agree across the compared runs,
	# the full CORE digest must agree too.
	| (if (["O1", "O2"] | map(. as $o | node_lanes | map(. as $l
			| measured_kx | map(. as $k | [1, 2] | map(. as $p
				| (dexcl("B-" + $o; $k; $l; "write_extent"; $p)
						== dexcl("A1-" + $o; $k; $l; "write_extent"; $p))
					and (boxes_in("core"; $k) | map(. as $bx
						| dincl("B-" + $o; $l; $bx; $p) == dincl("A1-" + $o; $l; $bx; $p)) | all)
				| if . then dig("B-" + $o; "core"; $k; $l; $p)
						== dig("A1-" + $o; "core"; $k; $l; $p)
					else true end) | all) | all) | all) | all)
		then . else error("core digest mismatch") end)
	# ---- V-03 gate half: param2 never leaves its declared mask ------------
	| (if (["O1", "O2"] | map(. as $o
			| ["cut", "fill", "water", "4lo", "4hi"] | map(. as $bx
				| dincl("B-" + $o; "param2"; $bx; 1) == dincl("A1-" + $o; "param2"; $bx; 1)) | all) | all)
		then . else error("param2 lane changed outside the declared param2 write mask") end)

	# =======================================================================
	# Verdicts
	# =======================================================================
	| [
		# ---- V-01 -------------------------------------------------------
		(["O1", "O2"][] as $o | node_lanes[] as $l
			| {id: "V-01", lane: $l, a: ("A1-" + $o), b: ("B-" + $o),
			   result: "pass", predicates: {}, outcome: "",
			   detail: ("CORE minus the union of the declared " + $l
				+ " write boxes is equal between arms in " + $o
				+ " on all three chunks and both passes")}),
		# ---- V-02 -------------------------------------------------------
		(["O1", "O2"][] as $o | light_lanes[] as $l
			| {id: "V-02", lane: $l, a: ("A1-" + $o), b: ("B-" + $o),
			   result: "pass", predicates: {}, outcome: "",
			   detail: ("CORE minus the light write box is equal between arms in "
				+ $o + " on all three chunks and both passes")}),
		# ---- V-03: the delta is present where declared -------------------
		(["O1", "O2"][] as $o | node_lanes[] as $l
			| [named_boxes[] as $bx
				| {box: $bx,
				   differs: (dincl("B-" + $o; $l; $bx; 1) != dincl("A1-" + $o; $l; $bx; 1)),
				   dirty: by_box_dirty("B-" + $o; $l; $bx)}] as $rows
			| ($rows | map(select(.differs != (.dirty > 0)))) as $odd
			| {id: "V-03", lane: $l, a: ("A1-" + $o), b: ("B-" + $o),
			   result: (if ($odd | length) == 0 then "pass" else "result" end),
			   predicates: {}, outcome: "",
			   detail: (if ($odd | length) == 0
				then ("every named box differs iff its by-box dirty count is non-zero, in " + $o)
				else ("measured, not a gate failure -- boxes whose "
					+ $l + " difference does not track the by-box dirty count in "
					+ $o + ": "
					+ ($odd | map(.box + "(dirty=" + (.dirty | tostring)
						+ ",differs=" + (.differs | tostring) + ")") | join(", "))) end)}),
		# ---- V-04: order dependence inside CORE, treatment arm -----------
		(lanes[] as $l
			| [measured_kx[] as $k
				| {kx: $k, equal: (dig("B-O1"; "core"; $k; $l; 1) == dig("B-O2"; "core"; $k; $l; 1))}] as $rows
			| {id: "V-04", lane: $l, a: "B-O1", b: "B-O2",
			   result: (if ($rows | map(.equal) | all) then "pass" else "result" end),
			   predicates: {}, outcome: "",
			   detail: ("CORE(B,O1) against CORE(B,O2), read against the V-06 CORE half: "
				+ ($rows | map("kx" + (.kx | tostring) + "="
					+ (if .equal then "equal" else "differs" end)) | join(", ")))}),
		# ---- V-05: the 10.13 cascade, verbatim ---------------------------
		([node_lanes[] as $l
			| (dig("B-O1"; "seam"; -1; $l; 1) == dig("B-O2"; "seam"; -1; $l; 1)) as $P1
			| (dig("A1-O1"; "seam"; -1; $l; 1) == dig("A1-O2"; "seam"; -1; $l; 1)) as $P2
			| (dig("B-O1"; "seam"; -1; $l; 1) == dig("A1-O1"; "seam"; -1; $l; 1)) as $P3
			| (dig("B-O2"; "seam"; -1; $l; 1) == dig("A1-O2"; "seam"; -1; $l; 1)) as $P4
			| {P1: $P1, P2: $P2, P3: $P3, P4: $P4} as $preds
			| ([$P1, $P2, $P3, $P4] | map(select(.)) | length) as $ntrue
			# Row 0: the four edges of a 4-cycle over an equivalence relation,
			# so exactly three true is impossible -- abort A-14.
			| (if $ntrue == 3 then error("impossible predicate combination") else . end)
			| (seam_halves | map(. as $h
				| (dincl("B-O1"; $l; $h; 1) == dincl("B-O2"; $l; $h; 1))
				and (dincl("B-O1"; $l; $h; 1) != dincl("A1-O1"; $l; $h; 1))
				and (dincl("B-O2"; $l; $h; 1) != dincl("A1-O2"; $l; $h; 1))) | all) as $corr
			| (if $l == "param2" then "no_signal_by_construction"
				elif ($P3 and $P4) then "no_delta"
				elif ($P3 != $P4) then "inconclusive"
				elif ($P2 | not) then "no_stable_baseline"
				elif $P1 then (if $corr then "persisted" else "inconclusive" end)
				else "order_effect" end) as $outcome
			| {id: "V-05", lane: $l, a: "B-O1", b: "B-O2",
			   result: (if $outcome == "no_signal_by_construction" then "no_signal"
				elif $outcome == "persisted" then "pass"
				elif $outcome == "order_effect" then "result"
				else "inconclusive" end),
			   predicates: $preds, outcome: $outcome,
			   detail: (if $outcome == "no_signal_by_construction"
					then "micro-case 4 declares no param2 write, so this lane carries no signal by construction and is excluded from the aggregate"
				elif $outcome == "no_delta"
					then "no detectable SEAM change in either order; read V-03, digest_incl over both halves and dirty_content_by_box before concluding anything"
				elif ($outcome == "inconclusive" and ($P3 != $P4))
					then "the delta is empty in exactly one order; localize, conclude nothing"
				elif $outcome == "no_stable_baseline"
					then "the paired control is itself order-dependent over SEAM, so no SEAM difference is attributable to the payload; re-run at a different fixed_map_seed, or with SEAM narrowed to a sub-box over which A1 O1 equals A1 O2"
				elif $outcome == "persisted"
					then "both arms order-stable and the delta non-empty in both orders, corroborated over the digest_incl of both halves -- for this seed, this chunk pair and this synthetic bar, not generalized; no cause is attributed"
				elif $outcome == "order_effect"
					then "the treatment SEAM bytes differ across orders while the paired control does not -- reported as an observed order effect with its cause NOT attributed"
				else "row 4 matched but the digest_incl corroboration over both halves failed; downgraded to inconclusive and the discrepancy reported"
				end)}] as $v05rows
			| ($v05rows | map(select(.outcome != "no_signal_by_construction"))) as $contrib
			| ($v05rows[],
			   {id: "V-05", lane: "all", a: "B-O1", b: "B-O2",
			    result: (if ($contrib | length) == 0 then "no_signal"
				elif ($contrib | map(.outcome == "persisted") | all) then "pass"
				elif ($contrib | map(.outcome == "order_effect") | any) then "result"
				else "inconclusive" end),
			    predicates: {},
			    outcome: (if ($contrib | length) == 0 then "no_signal_by_construction"
				elif ($contrib | map(.outcome == "persisted") | all) then "persisted"
				elif ($contrib | map(.outcome == "order_effect") | any) then "order_effect"
				else "inconclusive" end),
			    detail: ("aggregate over the contributing lanes ("
				+ ($contrib | map(.lane) | join(", "))
				+ "); a lane recorded no_signal_by_construction is excluded")})),
		# ---- V-06: the paired control, in BOTH compared regions ----------
		(lanes[] as $l
			| [measured_kx[] as $k
				| {name: ("CORE" + ($k | tostring)),
				   equal: (dig("A1-O1"; "core"; $k; $l; 1) == dig("A1-O2"; "core"; $k; $l; 1))}] as $core
			| {name: "SEAM",
			   equal: (dig("A1-O1"; "seam"; -1; $l; 1) == dig("A1-O2"; "seam"; -1; $l; 1))} as $seam
			| {id: "V-06", lane: $l, a: "A1-O1", b: "A1-O2",
			   result: (if (($core | map(.equal) | all) and $seam.equal) then "pass" else "result" end),
			   predicates: {}, outcome: "",
			   detail: ("native engine order dependence of the paired control, reported separately; the SEAM half reads into V-05 and the CORE half into V-04: "
				+ (($core + [$seam]) | map(.name + "="
					+ (if .equal then "equal" else "differs" end)) | join(", ")))}),
		# ---- V-07: operation counts against the 10.11 matrix -------------
		(run_ids[] as $id
			| (if $R[$id].ops_matrix_ok then . else error("operation counts do not match the 10.11 matrix") end)
			| {id: "V-07", lane: "all", a: $id, b: $id, result: "pass",
			   predicates: {}, outcome: "",
			   detail: ("stage-2 assertion 9 accepted the 10.11 operation-count matrix for "
				+ $id + ", conditioned on the arm and on the c/p/q/l predicates carried by the same record")}),
		# ---- V-08: light lanes over SEAM, an observation only ------------
		(light_lanes[] as $l
			| ({a: "B-O1", b: "B-O2"}, {a: "A1-O1", b: "B-O1"}, {a: "A1-O2", b: "B-O2"}) as $pair
			| {id: "V-08", lane: $l, a: $pair.a, b: $pair.b,
			   result: (if dig($pair.a; "seam"; -1; $l; 1) == dig($pair.b; "seam"; -1; $l; 1)
				then "pass" else "result" end),
			   predicates: {}, outcome: "",
			   detail: "measured, unknown a priori. Arm A1 performs zero lighting calls, so a light-lane B minus A1 is a different computation per arm over overlapping inputs, not a payload delta. This probe writes no halo light and therefore tests no halo-light idempotence exception"}),
		# ---- V-09: quiescence, per run ------------------------------------
		(run_ids[] as $id
			| {id: "V-09", lane: "all", a: $id, b: $id, result: "pass",
			   predicates: {}, outcome: "",
			   detail: ("the two readback digest passes of " + $id
				+ " are at least two seconds apart and identical; the inter-pass separation and the quiescence criterion are probe-local")})
	] as $verdicts

	# =======================================================================
	# first_diff -- one per differing compared digest pair, zero for an equal
	# pair. The pairs are exactly the full-box `digest` pairs the cascade and
	# V-04 / V-06 / V-08 tell the reader to localize with.
	# =======================================================================
	| ([
		{label: "CORE8:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "core", kx: 8},
		{label: "CORE10:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "core", kx: 10},
		{label: "CORE11:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "core", kx: 11},
		{label: "CORE8:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "core", kx: 8},
		{label: "CORE10:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "core", kx: 10},
		{label: "CORE11:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "core", kx: 11},
		{label: "SEAM:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "seam", kx: -1},
		{label: "SEAM:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "seam", kx: -1},
		{label: "SEAM:O1:A1-vs-B", a: "A1-O1", b: "B-O1", region: "seam", kx: -1},
		{label: "SEAM:O2:A1-vs-B", a: "A1-O2", b: "B-O2", region: "seam", kx: -1}
	] | map(. as $p | lanes | map($p + {lane: .})) | add) as $pairs
	| [$pairs[] | select(dig(.a; .region; .kx; .lane; 1) != dig(.b; .region; .kx; .lane; 1))
		| . as $p
		| region_box($p.region; $p.kx) as $box
		| (if ($p.lane | IN("content", "param2"))
			then ([boxes_in($p.region; $p.kx)[]
				| select(dincl($p.a; $p.lane; .; 1) != dincl($p.b; $p.lane; .; 1))] | first)
			else null end) as $hit
		| (if $hit == null then $box.min else named_box($hit).min end) as $pos
		| {tag: "first_diff", a: $p.a, b: $p.b, comparison: $p.label,
		   lane: $p.lane, region: $p.region,
		   flat_index: flat_index($box; $pos), pos: $pos,
		   value_a: -1, value_b: -1}] as $diffs

	| ([$verdicts[] | . + {tag: "verdict"}] + $diffs)
	| to_entries
	| map(.value as $v | .key as $i
		| {schema: "grug_wp40_t5_probe_synthetic_v0", stream: "comparison",
		   tag: $v.tag, seq: ($i + 1), run_id_a: $v.a, run_id_b: $v.b}
		+ ($v | del(.tag, .a, .b)))
	| .[]
' > "$staged"
fi

# ---------------------------------------------------------------------------
# The comparison stream OWN fail-closed gate (contract 12.7). It applies the
# 12.7 five-field common set, never the 12.2 seven-field run-stream set, and it
# recomputes the compared digest pairs from the same four summaries so the
# first_diff cardinality is checked independently of the generator.
# ---------------------------------------------------------------------------
jq -se \
	--slurpfile s_a1o1 "$sum_a1o1" \
	--slurpfile s_a1o2 "$sum_a1o2" \
	--slurpfile s_bo1 "$sum_bo1" \
	--slurpfile s_bo2 "$sum_bo2" \
'
	def is_integer: type == "number" and . == floor;
	def exact_keys($wanted): (keys) == ($wanted | sort);
	def vector:
		type == "object" and exact_keys(["x", "y", "z"]) and
		(.x | is_integer) and (.y | is_integer) and (.z | is_integer);
	def in_set($set): . as $v | ($set | index($v)) != null;
	def run_ids: ["A1-O1", "A1-O2", "B-O1", "B-O2"];
	def lanes: ["content", "param2", "light_day", "light_night"];
	def verdict_ids:
		["V-01", "V-02", "V-03", "V-04", "V-05", "V-06", "V-07", "V-08", "V-09"];
	def results: ["pass", "fail", "result", "inconclusive", "no_signal"];
	def outcomes:
		["", "no_delta", "persisted", "order_effect", "no_stable_baseline",
		 "inconclusive", "no_signal_by_construction"];
	def common_keys: ["schema", "stream", "tag", "seq", "run_id_a", "run_id_b"];
	def tag_keys($t): common_keys + (
		if $t == "verdict" then ["id", "lane", "result", "predicates", "outcome", "detail"]
		elif $t == "first_diff" then
			["comparison", "lane", "region", "flat_index", "pos", "value_a", "value_b"]
		else [] end);

	{ "A1-O1": $s_a1o1[0], "A1-O2": $s_a1o2[0],
	  "B-O1": $s_bo1[0], "B-O2": $s_bo2[0] } as $R
	# Guarded exactly like the generator copy above, and for a reason. Without
	# the length check a summary that is MISSING a digest yields null on both
	# sides; null != null is false, so the pair would read "equal", no
	# first_diff would be required, and this gate would pass on evidence it
	# never actually compared. An independent re-check that is weaker than the
	# generator it re-checks is not a re-check. In --gate-only mode the four
	# summaries are otherwise only checked for schema and status, so this is
	# the only place that catches it.
	| def dig($id; $region; $kx; $lane):
		[$R[$id].digests[] | select(.region == $region and .kx == $kx
			and .lane == $lane and .pass == 1)]
		| if length == 1 then .[0].sha256
			else error("comparison gate: run summary is missing a compared digest") end;

	(if length > 0 then . else error("no comparison records found") end)
	| (if all(.[]; type == "object") then . else error("comparison record is not an object") end)
	| (if all(.[]; .schema == "grug_wp40_t5_probe_synthetic_v0")
		then . else error("unexpected comparison record schema") end)
	| (if all(.[]; .stream == "comparison")
		then . else error("comparison record is not on the comparison stream") end)
	| (if all(.[]; .tag == "verdict" or .tag == "first_diff")
		then . else error("comparison record tag is not verdict or first_diff") end)
	| (if all(.[]; exact_keys(tag_keys(.tag)))
		then . else error("comparison record has unexpected keys") end)
	| (if [.[] | .seq] == [range(1; 1 + length)]
		then . else error("comparison seq is not contiguous") end)
	| (if all(.[]; (.run_id_a | in_set(run_ids)) and (.run_id_b | in_set(run_ids)))
		then . else error("comparison record names a run outside the four of 10.7") end)
	| (if all(.[] | select(.tag == "verdict");
			(.id | in_set(verdict_ids)) and (.result | in_set(results)) and
			(.outcome | in_set(outcomes)) and (.detail | type == "string") and
			(.predicates | type == "object") and all(.predicates[]; type == "boolean") and
			((.lane | in_set(lanes)) or .lane == "all"))
		then . else error("verdict field is outside its closed set") end)
	| (if all(.[] | select(.tag == "verdict" and .id != "V-05"); .outcome == "")
		then . else error("a non-V-05 verdict carries a cascade outcome") end)
	| (if all(.[] | select(.tag == "verdict" and .id == "V-05" and .result == "pass");
			.outcome == "persisted")
		then . else error("inconclusive row reported as a pass") end)
	# The four predicates are the edges of a 4-cycle over an equivalence
	# relation, so exactly three true is impossible. Re-checked here from the
	# emitted record, independently of the generator that computed it.
	| (if all(.[] | select(.tag == "verdict" and .id == "V-05");
			([.predicates[]] | map(select(.)) | length) != 3)
		then . else error("impossible predicate combination") end)
	| (if ((verdict_ids - [.[] | select(.tag == "verdict") | .id]) | length) == 0
		then . else error("not every verdict V-01 to V-09 was reported") end)
	| (if all(.[] | select(.tag == "first_diff");
			(.comparison | type == "string") and (.lane | in_set(lanes)) and
			(.region | in_set(["core", "seam"])) and (.flat_index | is_integer and . >= 1) and
			(.pos | vector) and (.value_a | is_integer) and (.value_b | is_integer))
		then . else error("first_diff record shape is invalid") end)
	# ---- first_diff cardinality, recomputed from the same summaries -------
	| . as $c
	| ([
		{label: "CORE8:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "core", kx: 8},
		{label: "CORE10:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "core", kx: 10},
		{label: "CORE11:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "core", kx: 11},
		{label: "CORE8:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "core", kx: 8},
		{label: "CORE10:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "core", kx: 10},
		{label: "CORE11:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "core", kx: 11},
		{label: "SEAM:A1:O1-vs-O2", a: "A1-O1", b: "A1-O2", region: "seam", kx: -1},
		{label: "SEAM:B:O1-vs-O2", a: "B-O1", b: "B-O2", region: "seam", kx: -1},
		{label: "SEAM:O1:A1-vs-B", a: "A1-O1", b: "B-O1", region: "seam", kx: -1},
		{label: "SEAM:O2:A1-vs-B", a: "A1-O2", b: "B-O2", region: "seam", kx: -1}
	] | map(. as $p | lanes | map($p + {lane: .})) | add) as $pairs
	| ([$c[] | select(.tag == "first_diff") | [.comparison, .lane]]) as $emitted
	| (if ($pairs | map(select(dig(.a; .region; .kx; .lane) != dig(.b; .region; .kx; .lane))
			| ([.label, .lane]) as $key
			| ($emitted | map(select(. == $key)) | length) == 1) | all)
		then $c else error("differing digest pair has no first_diff record") end)
	| (if ($pairs | map(select(dig(.a; .region; .kx; .lane) == dig(.b; .region; .kx; .lane))
			| ([.label, .lane]) as $key
			| ($emitted | map(select(. == $key)) | length) == 0) | all)
		then $c else error("equal digest pair has a first_diff record") end)
	| (if ($emitted | length) == ($emitted | unique | length)
		then $c else error("duplicate first_diff record for one digest pair") end)
	| true
' "$staged" >/dev/null

if (( gate_only == 0 )); then
	mkdir -p -- "$(dirname -- "$out_jsonl")"
	cp -- "$staged" "$out_jsonl"
fi

verdicts="$(jq -s '[.[] | select(.tag == "verdict")] | length' "$out_jsonl")"
diffs="$(jq -s '[.[] | select(.tag == "first_diff")] | length' "$out_jsonl")"
echo "WP40 t5-probe comparison: PASS ($verdicts verdicts, $diffs first_diff records) -> $out_jsonl"
jq -s -c '[.[] | select(.tag == "verdict") | {id, lane, result, outcome}]
	| group_by(.id) | map({id: .[0].id, rows: map({lane, result, outcome})})' "$out_jsonl"
