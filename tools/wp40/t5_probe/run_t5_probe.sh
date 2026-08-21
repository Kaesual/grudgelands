#!/usr/bin/env bash
set -euo pipefail

# WP40 T5-0 engine-seam probe -- runner (contract section 8.1).
#
#   tools/wp40/t5_probe/run_t5_probe.sh
#
# Cheap gates first, expensive half last and opt-in:
#
#   1  preflight            rg and jq up front, interpreters, `bash -n`
#   2  static gates         luac51 -p, SETGLOBAL, the five 5.1 sweeps, 10.12
#   3  coordinate audit     dual interpreter, byte-identical stdout
#   4  selftest             every offline negative fixture of section 16
#   5  injection            git archive + flattened mod + payload-digest refusal
#   6  four captures        strictly serial, fresh world each, ports 32001..4
#   7  per-run gate         verify_log.sh, then artefacts into the result tree
#   8  cross-run gate       compare_runs.sh -> comparison.jsonl
#   9  result assembly      host manifest, capture manifest, checksums
#
# Steps 1-4 always run.  Steps 5-9 run only under WP40_T5_PROBE_HEADLESS=1 and
# are skip-not-fail otherwise (8.2, precedent tools/wp40/run_dungeon_probe.sh:29-32).
#
# A second, separate mode promotes an already-captured and already-reviewed
# result tree to committed evidence (13.3):
#
#   bash tools/wp40/t5_probe/run_t5_probe.sh --promote RESULT_DIR
#
# Promotion runs NO engine invocation.  14.1 caps the package at four, and the
# reviewed bytes are the ones already captured -- a re-capture under a different
# WP40_RESULTS_ROOT would be a fifth..eighth invocation of a DIFFERENT run set,
# so it could not be the evidence anybody reviewed.  See README.md, "Promotion
# to committed evidence", which records this as a deliberate, reported departure
# from 13.3's wording ("by overriding WP40_RESULTS_ROOT") in favour of 13.3's
# and 14.1's substance.  WP40_T5_PROBE_RESULT_PREFIX keeps the literal mechanism
# available for anyone who does want a fresh capture written straight into the
# evidence tree.
#
# Environment:
#   WP40_T5_PROBE_HEADLESS=1        opt in to the four engine captures
#   WP40_T5_PROBE_KEEP_WORLD=1      keep the arm-B order-O1 world (19.1)
#   WP40_T5_PROBE_ENGINE_PATTERN    engine version regex, default ^5[.]16[.][0-9]+$
#   WP40_LUA_BIN                    LuaJIT binary, default /usr/bin/luajit
#   WP40_RESULTS_ROOT               parent of the result dir
#   WP40_T5_PROBE_RESULT_PREFIX     result dir name prefix, default empty
#   WP40_T5_PROBE_EVIDENCE_ROOT     --promote destination root,
#                                   default tools/wp40/evidence
#
# The capture result dir is named "<prefix><manifest-digest>"; the promoted
# evidence dir is always "t5-probe-<manifest-digest>" under the evidence root,
# which is the exact path 13.3 and 17 item 10 require.
#
# Exit codes: 0 pass, 1 failed gate, 2 preflight failure or refusal to overwrite
# an immutable result, 124 outer timeout, 127 missing tool.

self_name="${BASH_SOURCE[0]##*/}"

note() { printf '%s: %s\n' "$self_name" "$*" >&2; }
fail_gate() { printf '%s: %s\n' "$self_name" "$*" >&2; exit 1; }
fail_preflight() { printf '%s: %s\n' "$self_name" "$*" >&2; exit 2; }
fail_missing_tool() { printf '%s: %s\n' "$self_name" "$*" >&2; exit 127; }

# --------------------------------------------------------------------------
# 1. Preflight
# --------------------------------------------------------------------------

# rg first and unconditionally.  A missing rg exits 127, and 127 in an `if`
# condition reads exactly like "no match found": until 2026-08-15 that made nine
# gates report success without ever running (AGENTS.md:133-136).  jq is hard
# required for the same reason -- every structural gate below it is a jq
# program.  Contract 15, abort A-01.
command -v rg >/dev/null 2>&1 ||
	fail_missing_tool "ripgrep (rg) is required and was not found (A-01)"
command -v jq >/dev/null 2>&1 ||
	fail_missing_tool "jq is required and was not found (A-01)"
for required_tool in sha256sum grep cmp awk sed find sort xargs; do
	command -v "$required_tool" >/dev/null 2>&1 ||
		fail_missing_tool "$required_tool is required and was not found"
done

probe_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$probe_dir/../../.." && pwd)"
lua51="$repo/tools/bin/lua51"
luac51="$repo/tools/bin/luac51"
luajit_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"

# `bash -n` on this runner and on every sibling shell file of the probe tree.
# All four siblings are mandatory: a missing gate is a failure, never a
# tolerated absence, because a run that cannot execute a gate has not passed it.
bash -n "${BASH_SOURCE[0]}"
sibling_shell_files=(digest_lib.sh verify_log.sh compare_runs.sh selftest.sh)
for sibling in "${sibling_shell_files[@]}"; do
	[[ -f "$probe_dir/$sibling" ]] ||
		fail_preflight "required probe file is missing: tools/wp40/t5_probe/$sibling"
	bash -n "$probe_dir/$sibling" ||
		fail_gate "bash -n failed on $sibling"
done
# shellcheck source=/dev/null
source "$probe_dir/digest_lib.sh"

# The 10.7 matrix order.  It is the order the manifest digest binds and the
# order every per-run artefact is enumerated in, including by --promote below,
# and it is deliberately NOT the execution order of 14.3.
matrix_run_ids=(A1-O1 A1-O2 B-O1 B-O2)

# The four payload files, in the working-tree layout.  The runner needs them by
# name in three places (static gates, injection, payload digest), so the list is
# stated once.
payload_mod_conf="$probe_dir/driver/mod.conf"
payload_init_lua="$probe_dir/driver/init.lua"
payload_mapgen_lua="$probe_dir/payload/mapgen.lua"
payload_vm_proxy_lua="$probe_dir/payload/vm_proxy.lua"
coordinate_audit_lua="$probe_dir/coordinate_audit.lua"

for required_file in \
		"$payload_mod_conf" "$payload_init_lua" \
		"$payload_mapgen_lua" "$payload_vm_proxy_lua" \
		"$coordinate_audit_lua"; do
	[[ -f "$required_file" ]] ||
		fail_preflight "required probe file is missing: ${required_file#"$repo"/}"
done

# --------------------------------------------------------------------------
# 1b. --promote: reviewed result tree -> committed evidence (13.3, 17 item 10)
# --------------------------------------------------------------------------
#
# Copy only.  No engine runs, no digest is recomputed from the world, and the
# kept world of 19.1 is deliberately left behind: 20 keeps worlds under
# tools/wp40/results/ and retains only the evidence tree, and 19.1 permits the
# GUI to modify a kept world, so its bytes are not evidence of anything.
promote_evidence() {
	local source_dir="$1"
	local digest target staging run_id artefact
	local top_level_artefacts=(capture.json comparison.jsonl host.txt engine-version.txt)
	local run_artefacts=(raw.log summary.json minetest.conf world.mt map_meta.txt exit-status)

	[[ -d "$source_dir" ]] ||
		fail_preflight "promotion source is not a directory: $source_dir"
	source_dir="$(cd "$source_dir" && pwd)"
	[[ -f "$source_dir/capture.json" ]] ||
		fail_preflight "promotion source has no capture.json: $source_dir"

	# The digest is read from the capture manifest rather than from the
	# directory name, then the two are required to agree.  A renamed or
	# hand-assembled directory therefore cannot be promoted under a name its
	# own manifest does not carry.
	digest="$(jq -r '.digests.manifest // empty' "$source_dir/capture.json")"
	[[ "$digest" =~ ^[0-9a-f]{64}$ ]] ||
		fail_preflight "capture.json carries no manifest digest: $source_dir/capture.json"
	if [[ "${source_dir##*/}" != "$evidence_prefix$digest" && "${source_dir##*/}" != "$digest" ]]; then
		fail_preflight "result directory name ${source_dir##*/} does not match its own manifest digest $digest"
	fi
	if [[ "$(jq -r '.status // empty' "$source_dir/capture.json")" != "raw_capture_complete" ]]; then
		fail_gate "promotion source is not a complete capture: $source_dir/capture.json"
	fi

	# Integrity of the bytes about to be committed, checked against the
	# self-excluding manifests the capture wrote.  Only the kept world is
	# excluded, and only because 19.1 allows the GUI to change it.
	(
		cd "$source_dir" &&
		grep -v '^[0-9a-f]\{64\}  \./world-' MANIFEST.sha256 | sha256sum -c --quiet -
	) || fail_gate "checksum mismatch in the promotion source: $source_dir/MANIFEST.sha256"

	# Every artefact 17 item 10 names is required by an explicit name, so a
	# missing one fails the promotion instead of producing a short evidence
	# tree nobody notices -- and the whole list is checked BEFORE anything is
	# created, so a short source never leaves a partial tree behind to block
	# the corrected run with the overwrite refusal below.
	for artefact in "${top_level_artefacts[@]}"; do
		[[ -f "$source_dir/$artefact" ]] ||
			fail_gate "promotion source is missing $artefact"
	done
	for run_id in "${matrix_run_ids[@]}"; do
		for artefact in "${run_artefacts[@]}"; do
			[[ -f "$source_dir/run-$run_id/$artefact" ]] ||
				fail_gate "promotion source is missing run-$run_id/$artefact"
		done
	done

	target="$evidence_root/$evidence_prefix$digest"
	if [[ -e "$target" ]]; then
		fail_preflight "refusing to overwrite an existing evidence tree: $target"
	fi

	# Assembled under a hidden sibling and renamed into place at the end, so
	# the committed path only ever exists complete.  An I/O failure part way
	# through removes the staging tree instead of publishing half an evidence
	# tree under a name that then refuses to be rewritten.
	staging="$evidence_root/.$evidence_prefix$digest.partial"
	rm -rf -- "$staging"
	promote_staging="$staging"
	trap 'if [[ -n "${promote_staging:-}" ]]; then rm -rf -- "$promote_staging"; fi' EXIT INT TERM
	mkdir -p "$staging"

	for artefact in "${top_level_artefacts[@]}"; do
		cp "$source_dir/$artefact" "$staging/$artefact"
	done
	for run_id in "${matrix_run_ids[@]}"; do
		mkdir -p "$staging/run-$run_id"
		for artefact in "${run_artefacts[@]}"; do
			cp "$source_dir/run-$run_id/$artefact" "$staging/run-$run_id/$artefact"
		done
	done

	# Self-excluding checksum manifests, regenerated over the promoted bytes in
	# the shape of tools/wp40/capture_t0_baseline.sh:263-267: one per run
	# directory (13.2), then one over the whole tree.  They are regenerated
	# rather than copied because the promoted tree is a different file set --
	# the kept world is not in it -- so a copied manifest would not describe it.
	for run_id in "${matrix_run_ids[@]}"; do
		(
			cd "$staging/run-$run_id" &&
			find . -type f ! -name MANIFEST.sha256 -print0 | sort -z |
				xargs -0 sha256sum >MANIFEST.sha256
		)
	done
	(
		cd "$staging" &&
		find . -type f ! -path './MANIFEST.sha256' -print0 | sort -z |
			xargs -0 sha256sum >MANIFEST.sha256
	)

	mv "$staging" "$target"
	promote_staging=""
	trap - EXIT INT TERM

	printf 'WP40 t5-probe promote: PASS; 4 runs, 12 mapchunks, evidence at %s\n' \
		"${target#"$repo"/}"
}

evidence_root="${WP40_T5_PROBE_EVIDENCE_ROOT:-$repo/tools/wp40/evidence}"
if [[ "$evidence_root" != /* ]]; then
	evidence_root="$repo/$evidence_root"
fi
# 13.3 and 8.1 both spell the committed directory `t5-probe-<manifest-digest>`.
# It is a constant here, never an argument: a promotion that could be given a
# different prefix could write outside the package boundary of 8.1.
evidence_prefix="t5-probe-"

case "${1:-}" in
	--promote)
		[[ "$#" -eq 2 ]] ||
			fail_preflight "usage: ${BASH_SOURCE[0]##*/} --promote RESULT_DIR"
		promote_evidence "$2"
		exit 0
		;;
	"")
		;;
	*)
		fail_preflight "unknown argument: $1 (usage: ${BASH_SOURCE[0]##*/} [--promote RESULT_DIR])"
		;;
esac

# The two interpreters are required by the static gates only, so they are
# checked here rather than at the top: --promote copies reviewed bytes and must
# not demand a built tools/bin/ that .gitignore:8 keeps out of every checkout.
if [[ ! -x "$lua51" || ! -x "$luac51" ]]; then
	fail_preflight "tools/bin/lua51 and tools/bin/luac51 are required; run tools/build_lua51.sh"
fi
if [[ ! -x "$luajit_bin" ]]; then
	fail_preflight "WP40_LUA_BIN is not executable: $luajit_bin"
fi

scratch="$(mktemp -d /tmp/grudgelands-wp40-t5-probe.XXXXXX)"
cleanup() {
	case "$scratch" in
		/tmp/grudgelands-wp40-t5-probe.*) rm -rf -- "$scratch" ;;
		*) echo "refusing unsafe cleanup path: $scratch" >&2 ;;
	esac
}
trap cleanup EXIT INT TERM

# --------------------------------------------------------------------------
# 2. Static gates over the whole probe tree
# --------------------------------------------------------------------------

# Syntax, under the engine's own bundled PUC 5.1 parser.  LuaJIT is a superset
# and proves nothing here (docs/research/luanti-lua.md:271-274).  Discovered
# rather than listed, so a stray Lua file cannot slip past the gate.
probe_lua_files=()
while IFS= read -r -d '' lua_file; do
	probe_lua_files+=("$lua_file")
done < <(find "$probe_dir" -type f -name '*.lua' -print0 | sort -z)
if [[ "${#probe_lua_files[@]}" -eq 0 ]]; then
	fail_gate "no Lua files found under ${probe_dir#"$repo"/}"
fi
"$luac51" -p "${probe_lua_files[@]}" ||
	fail_gate "luac51 -p failed on the probe tree"

# Global writes.  A tools-only file gets zero SETGLOBAL lines; driver/init.lua is
# a mod init.lua and may carry exactly one, its mod table
# (docs/research/luanti-lua.md:260-261 permits one, it does not require one).
for lua_file in "${probe_lua_files[@]}"; do
	setglobal_count="$("$luac51" -l -p "$lua_file" | grep -c 'SETGLOBAL' || true)"
	if [[ "$lua_file" == "$payload_init_lua" ]]; then
		if [[ "$setglobal_count" -gt 1 ]]; then
			fail_gate "driver/init.lua writes $setglobal_count globals; at most one (the mod table) is permitted"
		fi
	elif [[ "$setglobal_count" -ne 0 ]]; then
		fail_gate "global write in ${lua_file#"$repo"/} ($setglobal_count SETGLOBAL lines)"
	fi
done

# The five plain-Lua-5.1 sweeps of docs/research/luanti-lua.md:310-321, run
# EXPLICITLY against tools/wp40/t5_probe: AGENTS.md:130-133 scopes them to
# mods/*/grug_*, so nothing under tools/ is covered unless it is named here.
sweep_patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
sweep_labels=(
	'goto / labels'
	'LuaJIT-only string escapes'
	'5.2+/5.3 stdlib'
	'integer division / bitwise operator syntax'
	'sandbox-blocked calls and the wrong namespace'
)
for sweep_index in 0 1 2 3 4; do
	sweep_hits="$(grep -rnE "${sweep_patterns[$sweep_index]}" "$probe_dir" \
		--include='*.lua' || true)"
	if [[ -n "$sweep_hits" ]]; then
		printf '%s\n' "$sweep_hits" >&2
		fail_gate "plain-5.1 sweep $((sweep_index + 1)) (${sweep_labels[$sweep_index]}) found a forbidden construct"
	fi
done

# Contract 10.12: raw VoxelManip access appears in exactly one file.  The
# scoping is as load-bearing as the pattern.  Three exclusions are stated by the
# contract rather than discovered:
#
#   * THIS RUNNER IS OUT OF SCOPE -- it contains all of the pattern literals
#     because it implements the sweep.  The --glob confines the sweep to
#     payload/*.lua, so the runner is never searched.
#   * payload/vm_proxy.lua is the one permitted holder, excluded by path.
#   * driver/init.lua's main-state readback is the stated exemption of 10.12:
#     core.get_voxel_manip() + read_from_map is legal outside the emerge
#     environment, is not the payload, and runs after every chunk is generated.
#
# Both `vm:` anchors are supplied.  The contract's literal `(^|[^%w_])` is used
# verbatim; the fourth pattern `(^|\W)` is the same anchor expressed in the
# regex dialect rg actually speaks, and is added because the union of the two is
# strictly stricter than either -- it can only ever produce a loud false
# positive, never a silent miss.  See the note in the package report.
# The explicit `.` search root is not decoration: rg with no path argument
# searches STDIN whenever stdin is not a terminal, so the contract's snippet run
# verbatim from a non-interactive shell blocks forever and, once fed an empty
# stdin, reports "no match" without having read a single file.  The globs stay
# repo-relative, which is why the search root is the repo and not payload/.
vm_sweep_status=0
(
	cd "$repo" &&
	rg -n \
		--glob 'tools/wp40/t5_probe/payload/**.lua' \
		--glob '!tools/wp40/t5_probe/payload/vm_proxy.lua' \
		-e 'core\.vmanip' \
		-e 'get_mapgen_object' \
		-e '(^|[^%w_])vm:[a-z_]+' \
		-e '(^|\W)vm:[a-z_]+' \
		-- .
) >"$scratch/vm-sweep.txt" 2>"$scratch/vm-sweep.err" </dev/null || vm_sweep_status=$?
if [[ "$vm_sweep_status" -ne 1 ]]; then
	cat "$scratch/vm-sweep.txt" >&2 || true
	cat "$scratch/vm-sweep.err" >&2 || true
	if [[ "$vm_sweep_status" -eq 0 ]]; then
		fail_gate "raw VoxelManip access outside payload/vm_proxy.lua (10.12)"
	fi
	fail_gate "the 10.12 VoxelManip sweep did not run cleanly (rg exit $vm_sweep_status)"
fi

# --------------------------------------------------------------------------
# 3. coordinate_audit.lua under both interpreters
# --------------------------------------------------------------------------

# Shape of tools/wp40/run_t2_s11_acceptance.sh:22-44: the audit's own stdout is
# the artefact, so an interpreter split is itself a failure.  stdout and exit
# status are both gated; stderr is kept separate so a real failure message
# survives instead of being reported as "outputs differ".
luajit_status=0
puc_status=0
"$luajit_bin" "$coordinate_audit_lua" "$repo" \
	>"$scratch/coordinate-audit.luajit.out" \
	2>"$scratch/coordinate-audit.luajit.err" || luajit_status=$?
"$lua51" "$coordinate_audit_lua" "$repo" \
	>"$scratch/coordinate-audit.puc.out" \
	2>"$scratch/coordinate-audit.puc.err" || puc_status=$?

if ! cmp -s "$scratch/coordinate-audit.luajit.out" "$scratch/coordinate-audit.puc.out"; then
	diff "$scratch/coordinate-audit.luajit.out" "$scratch/coordinate-audit.puc.out" >&2 || true
	fail_gate "coordinate_audit.lua stdout differs between LuaJIT and PUC 5.1"
fi
if [[ "$luajit_status" -ne "$puc_status" ]]; then
	fail_gate "coordinate_audit.lua exit status differs (luajit $luajit_status, puc $puc_status)"
fi
if [[ "$luajit_status" -ne 0 ]]; then
	cat "$scratch/coordinate-audit.luajit.err" >&2 || true
	cat "$scratch/coordinate-audit.luajit.out" >&2 || true
	fail_gate "coordinate_audit.lua failed with status $luajit_status under both interpreters"
fi

# --------------------------------------------------------------------------
# 4. selftest.sh
# --------------------------------------------------------------------------

# All 43 negative rows of section 16 plus the two non-stream fixtures, and the
# manifest-digest fixture of 13.2.  Its presence is already required by the
# preflight above; a failure here fails the run.
bash "$probe_dir/selftest.sh" || fail_gate "selftest.sh failed"

# --------------------------------------------------------------------------
# 5. The expensive half -- opt in, skip-not-fail
# --------------------------------------------------------------------------

if [[ "${WP40_T5_PROBE_HEADLESS:-0}" != "1" ]]; then
	printf 'WP40 t5-probe static gates: PASS; headless captures skipped, set WP40_T5_PROBE_HEADLESS=1 to run the four engine invocations\n'
	exit 0
fi

for required_tool in git tar flatpak timeout; do
	command -v "$required_tool" >/dev/null 2>&1 ||
		fail_missing_tool "$required_tool is required for the headless captures"
done
# ---- the contract literals bound into the manifest digest (13.2) ----------
#
# Coordinates are reproduced from the coordinator's interface pin, which
# pre-computed them against contract 10.3 / 10.10 / 14.3.  They are literals
# here, never recomputed, so the digest binds what the contract says rather than
# what this script could derive.
coordinate_set_literal="$(cat <<'COORDINATE_SET'
schema=wp40-t5-probe-coordinate-set-v1
chunk_k_y=0
chunk_k_z=9
chunk_k_x=8,10,11
gap_k_x=9
central_8=608,-32,688..687,47,767
emerged_8=592,-48,672..703,63,783
emerge_pos_8=648,8,728
central_10=768,-32,688..847,47,767
emerged_10=752,-48,672..863,63,783
emerge_pos_10=808,8,728
central_11=848,-32,688..927,47,767
emerged_11=832,-48,672..943,63,783
emerge_pos_11=888,8,728
calc_lighting_8=592,-32,672..703,47,783
calc_lighting_10=752,-32,672..863,47,783
calc_lighting_11=832,-32,672..943,47,783
core_8=624,-16,704..671,31,751
core_10=784,-16,704..831,31,751
core_11=864,-16,704..911,31,751
core_voxels=110592
seam=824,-16,696..871,23,735
seam_kx=-1
seam_voxels=76800
order_O1=8,10,11
order_O2=11,10,8
COORDINATE_SET
)"

case_write_extent_literal="$(cat <<'CASE_WRITE_EXTENTS'
schema=wp40-t5-probe-write-extent-v1
box_name=cut
box=628,0,712..635,7,719
content=air
param2=none
box_name=fill
box=628,-8,712..635,-1,719
content=default:stone
param2=none
box_name=water
box=644,0,712..651,7,719
content=default:water_source
param2=none
box_name=facedir
box=660,0,712..667,7,719
content=stairs:stair_cobble
param2=1
box_name=4lo
box=840,0,712..847,7,719
content=default:goldblock
param2=none
box_name=4hi
box=848,0,712..855,7,719
content=default:goldblock
param2=none
case=bounded
case_kx=8
write_extent_content=2048
write_extent_param2=512
param2_extent=660,0,712..667,7,719
content_extent_bounding_box=628,-8,712..667,7,719
light_write_box=613,-23,697..682,22,734
light_write_voxels=122360
case=4lo
case_kx=10
write_extent_content=512
write_extent_param2=0
param2_extent=null
content_extent_bounding_box=840,0,712..847,7,719
light_write_box=825,-15,697..847,22,734
light_write_voxels=33212
case=4hi
case_kx=11
write_extent_content=512
write_extent_param2=0
param2_extent=null
content_extent_bounding_box=848,0,712..855,7,719
light_write_box=848,-15,697..870,22,734
light_write_voxels=33212
CASE_WRITE_EXTENTS
)"

expected_version_pattern="${WP40_T5_PROBE_ENGINE_PATTERN:-^5[.]16[.][0-9]+$}"
# 12.5 stage 1's non-marker garbage gate is "an explicit committed regex whose
# bytes are bound into the manifest digest".  The bytes are read back out of
# verify_log.sh rather than restated here, so the digest binds exactly what the
# gate will use; verify_log.sh is then handed the same bytes explicitly instead
# of falling back to its own default, which is what makes "bound" mean
# "identical to the bytes that ran" rather than "identical to a copy".
log_shape_regex="$(bash "$probe_dir/verify_log.sh" --print-log-shape-regex)" ||
	fail_preflight "verify_log.sh --print-log-shape-regex failed"
[[ -n "$log_shape_regex" ]] ||
	fail_preflight "verify_log.sh --print-log-shape-regex produced no bytes"
# 14.1: a ceiling, never an expectation.  4 x 180 s must not be quoted as the
# expected cost; the expected in-server work is three mapchunk generations plus
# at most 17 full-volume buffer marshals in arm B.
outer_timeout_s=180
# 13.3's pinned reference, read back from verify_log.sh for the same reason as
# the log-shape regex: one committed literal, not two that can drift apart.
pinned_engine_version="$(bash "$probe_dir/verify_log.sh" --print-pinned-engine-version)" ||
	fail_preflight "verify_log.sh --print-pinned-engine-version failed"
[[ -n "$pinned_engine_version" ]] ||
	fail_preflight "verify_log.sh --print-pinned-engine-version produced no bytes"
pinned_engine_reference="Luanti 5.17.0-dev df04879066de6eb94ca43996822a6dfacc74feca"

# ---- archive base, injection, payload-digest refusal (13.1) --------------

game_root="$scratch/user/games/grudgelands"
mkdir -p "$game_root"

archive_commit="$(git -C "$repo" rev-parse HEAD)"
working_tree_payload_digest="$(wp40_t5_probe_payload_digest \
	"$payload_mod_conf" "$payload_init_lua" \
	"$payload_mapgen_lua" "$payload_vm_proxy_lua")"

git -C "$repo" archive HEAD | tar -x -C "$game_root"
injected_mod_dir="$game_root/mods/grug_wp40_t5_probe"
mkdir -p "$injected_mod_dir"
# Flattened, exactly as the interface pin fixes the injected layout.
cp "$payload_mod_conf" "$injected_mod_dir/mod.conf"
cp "$payload_init_lua" "$injected_mod_dir/init.lua"
cp "$payload_mapgen_lua" "$injected_mod_dir/mapgen.lua"
cp "$payload_vm_proxy_lua" "$injected_mod_dir/vm_proxy.lua"
# .gitignore:8 excludes tools/bin/ from any git archive export, so the built
# interpreters are copied in explicitly -- the shape of
# tools/wp40/run_t2_census_gates.sh:76 immediately after its archive at :75.
mkdir -p "$game_root/tools"
cp -r "$repo/tools/bin" "$game_root/tools/bin"

injected_payload_digest="$(wp40_t5_probe_payload_digest_dir "$injected_mod_dir")"
if [[ "$injected_payload_digest" != "$working_tree_payload_digest" ]]; then
	note "working tree: $working_tree_payload_digest"
	note "injected:     $injected_payload_digest"
	fail_gate "injected probe payload digest differs from the working-tree digest (A-02)"
fi

# ---- the four configurations, generated before anything is measured ------
#
# Every `probe`-class row of section 5 lands here.  Rows of class `engine` are
# deliberately absent: they are the substrate the repository actually produces
# today, and pinning them would create a substrate nothing else runs.  Rows of
# class `repo` are absent for the same reason -- `mg_name` is pinned by
# game.conf's `allowed_mapgens = v7` / `default_mapgen = v7`, and writing it
# here would silently convert a repo pin into a probe pin.  Both classes are
# recorded from the realized `map_meta.txt` copied into each run directory.
#
# The generated bytes contain no scratch path, which is what keeps the manifest
# digest reproducible across runs of this script.
config_dir="$scratch/config"
mkdir -p "$config_dir"

write_run_config() {
	local target="$1" arm="$2" order="$3" port="$4"
	printf '%s\n' \
		"fixed_map_seed = 40200517" \
		"num_emerge_threads = 1" \
		"liquid_update = 86400" \
		"server_announce = false" \
		"enable_ipv6 = false" \
		"bind_address = 127.0.0.1" \
		"port = $port" \
		"secure.trusted_mods = grug_wp40_t5_probe" \
		"grug_wp40_t5_probe.arm = $arm" \
		"grug_wp40_t5_probe.order = $order" \
		>"$target"
}

run_arm_of() { printf '%s' "${1%%-*}"; }
run_order_of() { printf '%s' "${1##*-}"; }
run_port_of() {
	# 10.7 pins the port to the matrix row, not to the execution position:
	# `port = 32000 + run` over runs 1..4 of that table.
	case "$1" in
		A1-O1) printf '32001' ;;
		A1-O2) printf '32002' ;;
		B-O1) printf '32003' ;;
		B-O2) printf '32004' ;;
		*) return 1 ;;
	esac
}
run_config_of() { printf '%s' "$config_dir/minetest-$1.conf"; }

# 14.3 execution order -- arm B order O1 first, because the cost projection is
# folded into that capture instead of being bought with a fifth invocation.
execution_run_ids=(B-O1 A1-O1 A1-O2 B-O2)

for run_id in "${matrix_run_ids[@]}"; do
	write_run_config "$(run_config_of "$run_id")" \
		"$(run_arm_of "$run_id")" "$(run_order_of "$run_id")" \
		"$(run_port_of "$run_id")"
done

manifest_digest="$(wp40_t5_probe_manifest_digest \
	"$archive_commit" \
	"$working_tree_payload_digest" \
	"$expected_version_pattern" \
	"$coordinate_set_literal" \
	"$case_write_extent_literal" \
	"$(run_config_of A1-O1)" \
	"$(run_config_of A1-O2)" \
	"$(run_config_of B-O1)" \
	"$(run_config_of B-O2)" \
	"$log_shape_regex")"

# ---- result tree: named by the manifest digest, immutable ----------------

results_root="${WP40_RESULTS_ROOT:-$repo/tools/wp40/results/t5_probe}"
if [[ "$results_root" != /* ]]; then
	results_root="$repo/$results_root"
fi
# 13.3 names the result tree by the manifest digest alone and the committed
# evidence tree `t5-probe-<manifest-digest>`.  The prefix is empty by default,
# so the ordinary scratch path is unchanged; setting it to `t5-probe-` together
# with WP40_RESULTS_ROOT=tools/wp40/evidence is the literal
# "promoted by overriding WP40_RESULTS_ROOT" mechanism of 13.3, kept available
# for a fresh capture written straight into the evidence tree.  Promoting an
# already-reviewed capture uses --promote instead and costs no engine run.
result_dir="$results_root/${WP40_T5_PROBE_RESULT_PREFIX:-}$manifest_digest"
if [[ -e "$result_dir" ]]; then
	fail_preflight "refusing to overwrite an existing result: $result_dir"
fi
mkdir -p "$result_dir"

note "archive commit:  $archive_commit"
note "payload digest:  $working_tree_payload_digest"
note "manifest digest: $manifest_digest"
note "result tree:     $result_dir"

"$repo/tools/wp40/collect_host.sh" "$repo" >"$result_dir/host.txt"

# Engine identity, host side.  The installed Flatpak is 5.16.1 while the pinned
# reference is 5.17.0-dev df04879; 13.3 records the mismatch instead of hiding
# it, in the shape of tools/wp40/capture_t0_baseline.sh:231-234.  The in-band
# regex gate against WP40_T5_PROBE_ENGINE_PATTERN belongs to verify_log.sh
# stage 3 (A-03) and is not duplicated here.
flatpak run --command=luanti org.luanti.luanti --version \
	>"$result_dir/engine-version.txt" 2>&1 ||
	fail_preflight "could not read the installed engine version"
engine_version_line="$(head -n 1 "$result_dir/engine-version.txt")"
engine_runtime_kind="bundled_lua51"
if rg -q 'Using LuaJIT' "$result_dir/engine-version.txt"; then
	engine_runtime_kind="luajit"
fi
engine_version_digest="$(wp40_t5_sha256_file_content "$result_dir/engine-version.txt")"
version_match="false"
if [[ "$engine_version_line" == *"$pinned_engine_version"* ]]; then
	version_match="true"
fi

# --------------------------------------------------------------------------
# 6-7. Four strictly serial captures, each with a fresh disposable world
# --------------------------------------------------------------------------

kept_world_dir=""
kept_world_source_log=""

capture_run() {
	local run_id="$1"
	local arm order port config run_root world_root run_result_dir
	local raw_log summary_json run_status verify_status
	arm="$(run_arm_of "$run_id")"
	order="$(run_order_of "$run_id")"
	port="$(run_port_of "$run_id")"
	config="$(run_config_of "$run_id")"

	run_root="$scratch/run-$run_id"
	world_root="$run_root/world"
	mkdir -p "$world_root" \
		"$run_root/xdg/config" "$run_root/xdg/cache" "$run_root/xdg/data"

	printf '%s\n' \
		"gameid = grudgelands" \
		"backend = sqlite3" \
		"player_backend = sqlite3" \
		"auth_backend = sqlite3" \
		"mod_storage_backend = sqlite3" \
		"creative_mode = true" \
		"enable_damage = false" \
		"server_announce = false" \
		>"$world_root/world.mt"

	# The result directory exists before the engine starts, so an outer timeout
	# -- the one abort with no in-band record (A-10) -- always has somewhere to
	# put its partial log before `trap cleanup` removes the scratch root.
	run_result_dir="$result_dir/run-$run_id"
	mkdir -p "$run_result_dir"
	raw_log="$run_root/raw.log"
	summary_json="$run_root/summary.json"

	note "capture $run_id (arm $arm, order $order, port $port)"
	run_status=0
	set +e
	# LC_ALL/LANG are pinned to C for two independent reasons, and the capture
	# does not work on this host without it.
	#
	# (1) BYTE-COMPARABLE LOGS. 13.1 keeps --log-timestamp none --color never
	#     "because that is what makes a server log byte-comparable". A log whose
	#     libc strings follow the caller locale is not byte-comparable either,
	#     so the locale belongs in the same pin.
	# (2) It is what makes the archived game loadable here at all.
	#     mods/MAPGEN/grug_mapgen/wp40/compiler.lua:85 tolerates an absent
	#     wp40/geometry/compiler_impl.lua -- which IS absent at this commit --
	#     by string-matching the ENGLISH strerror text "No such file or
	#     directory". Under the inherited de_DE.UTF-8 locale the Flatpak runtime
	#     returns "Datei oder Verzeichnis nicht gefunden", the guard misses, and
	#     compiler.lua:86 aborts the entire game load before any probe code
	#     runs. Measured inside the runtime:
	#       LC_ALL=C           -> "No such file or directory"        (tolerated)
	#       LC_ALL=de_DE.UTF-8 -> "Datei oder Verzeichnis nicht ..."  (aborts)
	#     Pinning the locale is a capture-environment control in this runner and
	#     changes no production file. The locale-dependent match in compiler.lua
	#     is a PRODUCTION defect and is reported, not fixed here: this package
	#     may not touch mods/ (contract 1.3, 8.1).
	timeout "$outer_timeout_s" flatpak run \
		--command=luanti \
		--filesystem="$scratch" \
		--env="LUANTI_USER_PATH=$scratch/user" \
		--env="XDG_CONFIG_HOME=$run_root/xdg/config" \
		--env="XDG_CACHE_HOME=$run_root/xdg/cache" \
		--env="XDG_DATA_HOME=$run_root/xdg/data" \
		--env="LC_ALL=C" \
		--env="LANG=C" \
		org.luanti.luanti \
		--server \
		--gameid grudgelands \
		--world "$world_root" \
		--config "$config" \
		--log-timestamp none --color never \
		>"$raw_log" 2>&1
	run_status=$?
	set -e
	printf '%s\n' "$run_status" >"$run_result_dir/exit-status"

	# Raw evidence is preserved for every outcome, pass or fail.
	cp "$raw_log" "$run_result_dir/raw.log"
	cp "$config" "$run_result_dir/minetest.conf"
	cp "$world_root/world.mt" "$run_result_dir/world.mt"
	if [[ -f "$world_root/map_meta.txt" ]]; then
		cp "$world_root/map_meta.txt" "$run_result_dir/map_meta.txt"
	fi

	if [[ "$run_status" -eq 124 ]]; then
		note "partial raw log preserved at $run_result_dir/raw.log"
		tail -n 80 "$raw_log" >&2 || true
		printf '%s: capture %s hit the %s s outer timeout (A-10)\n' \
			"$self_name" "$run_id" "$outer_timeout_s" >&2
		exit 124
	fi
	if [[ "$run_status" -ne 0 ]]; then
		tail -n 80 "$raw_log" >&2 || true
		fail_gate "capture $run_id exited with status $run_status"
	fi
	if [[ ! -f "$run_result_dir/map_meta.txt" ]]; then
		fail_gate "capture $run_id produced no map_meta.txt; nothing generated a world"
	fi

	verify_status=0
	set +e
	bash "$probe_dir/verify_log.sh" \
		"$raw_log" \
		"$summary_json" \
		"$expected_version_pattern" \
		"$archive_commit" \
		"$working_tree_payload_digest" \
		"$manifest_digest" \
		"$pinned_engine_version" \
		"$log_shape_regex"
	verify_status=$?
	set -e
	if [[ -f "$summary_json" ]]; then
		cp "$summary_json" "$run_result_dir/summary.json"
	fi
	if [[ "$verify_status" -ne 0 ]]; then
		tail -n 80 "$raw_log" >&2 || true
		fail_gate "verify_log.sh rejected capture $run_id (status $verify_status)"
	fi
	if [[ ! -f "$run_result_dir/summary.json" ]]; then
		fail_gate "verify_log.sh passed capture $run_id but wrote no summary.json"
	fi

	# 19.1: the world of the arm-B order-O1 capture is kept only after that
	# capture has passed its gates, and is copied out while the scratch root
	# still exists.
	if [[ "$run_id" == "B-O1" && "${WP40_T5_PROBE_KEEP_WORLD:-0}" == "1" ]]; then
		cp -a "$world_root" "$result_dir/world-B-O1"
		kept_world_dir="$result_dir/world-B-O1"
		kept_world_source_log="$run_result_dir/raw.log"
		note "kept the arm-B order-O1 world at $kept_world_dir"
	fi
}

for run_id in "${execution_run_ids[@]}"; do
	capture_run "$run_id"
done

# --------------------------------------------------------------------------
# 8. Cross-run comparison
# --------------------------------------------------------------------------

compare_status=0
set +e
bash "$probe_dir/compare_runs.sh" "$result_dir"
compare_status=$?
set -e
if [[ "$compare_status" -ne 0 ]]; then
	fail_gate "compare_runs.sh failed (status $compare_status)"
fi
if [[ ! -s "$result_dir/comparison.jsonl" ]]; then
	fail_gate "compare_runs.sh produced no comparison.jsonl"
fi

# --------------------------------------------------------------------------
# 9. Evidence assembly
# --------------------------------------------------------------------------

# The capture manifest carries what belongs to the harness rather than to a
# single run: the digests the result tree is named by, the engine identity with
# its recorded mismatch, and the honest cache disclaimer copied verbatim from
# tools/wp40/capture_t0_baseline.sh:239-241.  Per-run labelling
# (`version_match`, the cache block, the golden labels) is verify_log.sh's, in
# its own summary.json; this file is the capture-level copy and does not touch
# it.  The cache disclaimer and the 3.2 non-claim-11 sentence are deliberately
# in BOTH: 13.1 wants the disclaimer where a reader of one run's summary will
# see it, and a reader of the capture manifest alone must not have to infer it.
# `first_diff_localization` is the capture-level statement of the evidence
# limit compare_runs.sh marks per record with `flat_index: -1`.
# Contract 3.2 non-claim 11 ends "and the summary says it in those words", so
# the words are a literal, defined once and passed to jq as data. It carries
# apostrophes and must never be pasted inside a single-quoted jq program.
# verify_log.sh:1 carries the identical literal for the per-run summaries.
containment_statement="A containment pass means 'no difference in the compared regions', not 'no difference in the chunk'."

run_manifest_json="$(
	for run_id in "${matrix_run_ids[@]}"; do
		jq -nc \
			--arg run_id "$run_id" \
			--arg arm "$(run_arm_of "$run_id")" \
			--arg order "$(run_order_of "$run_id")" \
			--arg config_sha256 "$(wp40_t5_sha256_file_content "$(run_config_of "$run_id")")" \
			--argjson port "$(run_port_of "$run_id")" \
			'{run_id: $run_id, arm: $arm, order: $order, port: $port,
			  config_content_sha256: $config_sha256,
			  directory: ("run-" + $run_id)}'
	done | jq -sc '.'
)"

jq -n \
	--arg schema "wp40_t5_probe_capture_manifest_v1" \
	--arg manifest_digest "$manifest_digest" \
	--arg payload_digest "$working_tree_payload_digest" \
	--arg archive_commit "$archive_commit" \
	--arg engine_version_regex "$expected_version_pattern" \
	--arg containment_statement "$containment_statement" \
	--arg log_shape_regex "$log_shape_regex" \
	--arg log_shape_regex_sha256 "$(wp40_t5_sha256_text "$log_shape_regex")" \
	--arg coordinate_set_sha256 "$(wp40_t5_sha256_text "$coordinate_set_literal")" \
	--arg case_write_extent_sha256 "$(wp40_t5_sha256_text "$case_write_extent_literal")" \
	--arg engine_version_line "$engine_version_line" \
	--arg engine_version_digest "$engine_version_digest" \
	--arg engine_runtime_kind "$engine_runtime_kind" \
	--arg pinned_engine_reference "$pinned_engine_reference" \
	--argjson version_match "$version_match" \
	--argjson runs "$run_manifest_json" \
	--arg execution_order "${execution_run_ids[*]}" \
	--arg matrix_order "${matrix_run_ids[*]}" \
	--argjson outer_timeout_s "$outer_timeout_s" \
	'{schema: $schema,
	  status: "raw_capture_complete",
	  digests: {manifest: $manifest_digest,
	    probe_payload: $payload_digest,
	    game_archive_commit_sha1: $archive_commit,
	    engine_version_regex: $engine_version_regex,
	    log_shape_regex: $log_shape_regex,
	    log_shape_regex_sha256: $log_shape_regex_sha256,
	    coordinate_set: $coordinate_set_sha256,
	    case_write_extent: $case_write_extent_sha256},
	  matrix: {engine_invocations: 4,
	    mapchunks_per_run: 3,
	    mapchunks_total: 12,
	    runs: $runs,
	    manifest_digest_order: $matrix_order,
	    execution_order: $execution_order,
	    execution_order_reason: "arm B order O1 runs first; section 14.3 folds the cost projection into that capture instead of a fifth invocation"},
	  runtime: {kind: $engine_runtime_kind,
	    version_raw: "engine-version.txt",
	    version_raw_line: $engine_version_line,
	    version_digest: $engine_version_digest,
	    installed_flatpak: "5.16.1",
	    pinned_source_reference: $pinned_engine_reference,
	    version_match: $version_match},
	  cache: {process: "new_process_new_disposable_world",
	    filesystem_page_cache: "unknown_uncontrolled",
	    cold_cache_claim: false},
	  containment_scope_statement: $containment_statement,
	  first_diff_localization: {resolvable_from: "sha256 digests only",
	    voxel_level: false,
	    localized: "flat_index >= 1 -- pos is the minimum corner of the named write box whose digest_incl differs; a box, never a voxel",
	    not_localized: "flat_index == -1 -- digest_incl implicates no named box, so pos is only the compared box minimum corner and was NEVER measured; always the case on the light lanes, which have no per-box digest_incl",
	    value_a_value_b: "always -1 -- a node value is not resolvable from digest evidence",
	    consequence: "contract 10.13 asks a follow-on run to narrow the SEAM sub-box using the first_diff of the failing run; a record marked flat_index -1 supplies no such coordinate"},
	  timings_are_golden: false,
	  timing_replicates: 1,
	  settling_is_probe_local: true,
	  harness: {command: "tools/wp40/t5_probe/run_t5_probe.sh",
	    outer_timeout_s: $outer_timeout_s,
	    outer_timeout_is_a_ceiling_not_an_expectation: true,
	    exit_2: "preflight failure or refusal to overwrite an immutable result"}}' \
	>"$result_dir/capture.json"

# Self-excluding checksum manifests, in the shape of
# tools/wp40/capture_t0_baseline.sh:263-267: one per run directory (13.2), then
# one over the whole result tree.
for run_id in "${matrix_run_ids[@]}"; do
	(
		cd "$result_dir/run-$run_id" &&
		find . -type f ! -name MANIFEST.sha256 -print0 | sort -z |
			xargs -0 sha256sum >MANIFEST.sha256
	)
done
(
	# Excluded by path, not by name, so the top-level manifest still covers the
	# per-run manifests written just above.
	cd "$result_dir" &&
	find . -type f ! -path './MANIFEST.sha256' -print0 | sort -z |
		xargs -0 sha256sum >MANIFEST.sha256
)

# --------------------------------------------------------------------------
# 19.1 / 19.2: the kept world and the five-minute runtime test plan
# --------------------------------------------------------------------------

if [[ -n "$kept_world_dir" ]]; then
	cat <<KEPT_WORLD
Kept world (arm B, order O1): $kept_world_dir

Copy that directory into ~/.var/app/org.luanti.luanti/.minetest/worlds/ and open
it with the installed Grudgelands game.  Visual inspection only: the world came
from a git archive of $archive_commit while the installed game is whatever was
last synced, and the healing LBM, mob ABMs and node timers run as soon as a
player is present.  No digest is ever recomputed from a world opened in the GUI.

Expected, and not defects:
  * unsettled liquid -- the capture pinned liquid_update = 86400, so the world
    was saved before the periodic drain ever ran;
  * an ungenerated column at x in [688, 767] -- k_x = 9 is the gap chunk and was
    never requested.

Setup:
  /grantme fly, fast, noclip, teleport, settime
  /time 12000

The five minutes:
  1  /teleport 848 4 715, noclip along x from 835 to 860 -- the micro-case-4
     gold bar across x = 847/848: one continuous 16-node run, 8 each side,
     8 x 8 in cross-section.  Red flag: 8 nodes instead of 16, a missing half,
     or offset halves.
  2  /teleport 848 <native_surface_y + 3> 715 -- lighting continuity across
     x = 848 at the surface.  Red flag: a vertical light seam whose edge sits
     exactly at x = 848.  Skip if native_surface_y is null for both case-4
     columns.
  3  /teleport 648 4 715 (noclip), then east to 663 -- 8x8x8 of water at
     x in [644, 651], y in [0, 7], z in [712, 719], and 8 nodes east an 8x8x8 of
     cobblestone stairs at x in [660, 667], all facing the same way.  Red flag:
     random stair rotations.
  4  /teleport 631 4 715 (noclip) -- the cut/fill cell: an 8x8x8 air pocket at
     y in [0, 7] directly on an 8x8x8 stone block at y in [-8, -1], at
     x in [628, 635], z in [712, 719].  Red flag: a filled pocket or a missing
     slab.
  5  anywhere else in x in [608, 687] or x in [768, 927] at z in [688, 767] --
     ordinary untouched v7 terrain.  Red flag: any artificial block, flat plane
     or hole outside the six declared write boxes.
  6  anywhere in the three chunks, dig down a few nodes -- red flag: an unknown
     node placeholder, meaning a content-ID mismatch between the archive game
     and the installed game.  Record it and stop; the world is not comparable.

This pass confirms no digest, no timing, no operation count and no order
comparison.  Those come only from the headless captures and their gates.

Recorded case_baseline values for that run (anchor column, native_surface_y,
native content counts over the write extent, realized c/p/q/l):
KEPT_WORLD
	if [[ -n "$kept_world_source_log" && -f "$kept_world_source_log" ]]; then
		rg -N -o 'WP40_T5_PROBE_JSON .*' "$kept_world_source_log" |
			sed 's/^WP40_T5_PROBE_JSON //' |
			jq -c 'select(.tag == "case_baseline")' ||
			echo "  (no case_baseline records found in the arm-B order-O1 log)"
	fi
fi

printf 'WP40 t5-probe capture: PASS; 4 invocations, 12 mapchunks, results at %s; promote with --promote %s\n' \
	"$result_dir" "$result_dir"
