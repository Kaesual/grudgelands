#!/usr/bin/env bash
set -euo pipefail

command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required" >&2
	exit 1
}
command -v python3 >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: python3 is required" >&2
	exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
luajit_bin="${WP40_LUA_BIN:-$(command -v luajit || true)}"
puc_bin="${WP40_PUC_BIN:-$repo/tools/bin/lua51}"
luac_bin="${WP40_LUAC_BIN:-$repo/tools/bin/luac51}"
evidence_dir="${WP40_EVIDENCE_DIR:-}"

[[ -n "$luajit_bin" && -x "$luajit_bin" ]] || {
	echo "WP40 C-a1 fields: executable LuaJIT not found" >&2
	exit 127
}
[[ -x "$puc_bin" ]] || {
	echo "WP40 C-a1 fields: executable PUC 5.1 not found; set WP40_PUC_BIN" >&2
	exit 127
}
[[ -x "$luac_bin" ]] || {
	echo "WP40 C-a1 fields: executable luac51 not found; set WP40_LUAC_BIN" >&2
	exit 127
}

owned_lua=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/analytic_record.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/relief.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/template.lua"
	"$repo/tools/wp40/t2_fields_test.lua"
)

"$luac_bin" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$luac_bin" -p -l - < "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 C-a1 fields: global write in $file" >&2
		exit 1
	fi
done

patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for pattern in "${patterns[@]}"; do
	if rg -n "$pattern" "${owned_lua[@]}"; then
		echo "WP40 C-a1 fields: forbidden Lua construct matched" >&2
		exit 1
	fi
done
bash -n "$script_dir/run_t2_fields.sh"

scratch="$(mktemp -d -p /tmp grudgelands-wp40-fields.XXXXXXXX)"
server_pid=""
cleanup() {
	if [[ -n "$server_pid" ]]; then
		kill "$server_pid" 2>/dev/null || true
	fi
	if [[ "$scratch" == /tmp/grudgelands-wp40-fields.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

run_one() {
	local label="$1"
	local mode="$2"
	local interpreter="$3"
	local run_dir="$scratch/$label"
	local request="$scratch/$label.request"
	local response="$scratch/$label.response"
	mkdir -p "$run_dir"
	mkfifo "$request" "$response"
	python3 "$script_dir/t2_census_sha_server.py" "$request" "$response" \
		>"$run_dir/sha-server.log" 2>&1 &
	server_pid=$!
	/usr/bin/time -f $'wall_seconds\t%e\nuser_seconds\t%U\nsystem_seconds\t%S' \
		-o "$run_dir/wall-time.tsv" \
		"$interpreter" "$script_dir/t2_fields_test.lua" "$repo" "$mode" \
		"$run_dir" "$request" "$response" >"$run_dir/run.log" 2>&1
	wait "$server_pid"
	server_pid=""
}

run_one luajit full "$luajit_bin"
run_one puc51 targeted "$puc_bin"

cmp "$scratch/luajit/shared-kats.bin" "$scratch/puc51/shared-kats.bin"

full_samples="$(awk -F '\t' '$1=="sample_count" {print $2}' \
	"$scratch/luajit/metrics.tsv")"
puc_samples="$(awk -F '\t' '$1=="sample_count" {print $2}' \
	"$scratch/puc51/metrics.tsv")"
[[ "$full_samples" == 292 && "$puc_samples" == 17 ]] || {
	echo "WP40 C-a1 fields: case accounting drift" >&2
	exit 1
}

shared_digest="$(sha256sum "$scratch/luajit/shared-kats.bin" | awk '{print $1}')"
full_digest="$(sha256sum "$scratch/luajit/full-results.bin" | awk '{print $1}')"
targeted_digest="$(sha256sum "$scratch/puc51/targeted-results.bin" | awk '{print $1}')"

if [[ -n "$evidence_dir" ]]; then
	case "$evidence_dir" in
		"$repo"/tools/wp40/evidence/t2-fields-v1) ;;
		*) echo "WP40 C-a1 fields: unsafe evidence path $evidence_dir" >&2; exit 1 ;;
	esac
	if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
		echo "WP40 C-a1 fields: evidence capture requires a clean tested HEAD" >&2
		exit 1
	fi
	if [[ -e "$evidence_dir" ]] && [[ -n "$(find "$evidence_dir" -mindepth 1 -print -quit)" ]]; then
		if [[ "${WP40_EVIDENCE_REFRESH:-}" != 1 ]]; then
			echo "WP40 C-a1 fields: evidence directory is not empty" >&2
			exit 1
		fi
		(
			cd "$evidence_dir"
			sha256sum -c checksums.sha256
		)
	fi
	mkdir -p "$evidence_dir/luajit" "$evidence_dir/puc51"
	cp "$scratch/luajit/full-results.bin" "$evidence_dir/luajit/"
	cp "$scratch/luajit/full-results.tsv" "$evidence_dir/luajit/"
	cp "$scratch/luajit/shared-kats.bin" "$evidence_dir/luajit/"
	cp "$scratch/luajit/metrics.tsv" "$evidence_dir/luajit/"
	cp "$scratch/luajit/run.log" "$evidence_dir/luajit/"
	cp "$scratch/luajit/wall-time.tsv" "$evidence_dir/luajit/"
	awk -F '\t' 'NR > 1 {print $1}' "$scratch/luajit/full-results.tsv" \
		> "$evidence_dir/luajit/case-ids.txt"
	cp "$scratch/puc51/targeted-results.bin" "$evidence_dir/puc51/"
	cp "$scratch/puc51/targeted-results.tsv" "$evidence_dir/puc51/"
	cp "$scratch/puc51/shared-kats.bin" "$evidence_dir/puc51/"
	cp "$scratch/puc51/metrics.tsv" "$evidence_dir/puc51/"
	cp "$scratch/puc51/run.log" "$evidence_dir/puc51/"
	cp "$scratch/puc51/wall-time.tsv" "$evidence_dir/puc51/"
	awk -F '\t' 'NR > 1 {print $1}' "$scratch/puc51/targeted-results.tsv" \
		> "$evidence_dir/puc51/case-ids.txt"

	tested_head="$(git -C "$repo" rev-parse HEAD)"
	tested_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
	luajit_abs="$(readlink -f "$luajit_bin")"
	puc_abs="$(readlink -f "$puc_bin")"
	luac_abs="$(readlink -f "$luac_bin")"
	ordinary_sha="$(awk -F '\t' '$1=="ordinary_cold_sha_calls" {print $2}' \
		"$scratch/luajit/metrics.tsv")"
	warm_sha="$(awk -F '\t' '$1=="ordinary_warm_added_sha_calls" {print $2}' \
		"$scratch/luajit/metrics.tsv")"
	triple_sha="$(awk -F '\t' '$1=="triple_sha_calls" {print $2}' \
		"$scratch/luajit/metrics.tsv")"
	luajit_wall="$(awk -F '\t' '$1=="wall_seconds" {print $2}' \
		"$scratch/luajit/wall-time.tsv")"
	puc_wall="$(awk -F '\t' '$1=="wall_seconds" {print $2}' \
		"$scratch/puc51/wall-time.tsv")"
	full_case_ids_digest="$(sha256sum "$evidence_dir/luajit/case-ids.txt" | awk '{print $1}')"
	targeted_case_ids_digest="$(sha256sum "$evidence_dir/puc51/case-ids.txt" | awk '{print $1}')"
	cat > "$evidence_dir/manifest.tsv" <<EOF
key	value
schema	grug_wp40_t2_fields_evidence_v1
package	WP40 T2 C-a1 payload-free fields
tested_head	$tested_head
tested_tree	$tested_tree
containment_claim	none; CA1-DAG-1 assigns containment to C-a2
luajit_path	$luajit_abs
luajit_version	$("$luajit_bin" -v 2>&1 | head -1)
puc51_path	$puc_abs
puc51_version	$("$puc_bin" -v 2>&1 | head -1)
luac51_path	$luac_abs
luac51_version	$("$luac_bin" -v 2>&1 | head -1)
luajit_full_samples	$full_samples
puc51_targeted_samples	$puc_samples
ellipse_retained_rows	264
full_canonical_sha256	$full_digest
targeted_canonical_sha256	$targeted_digest
dual_runtime_shared_sha256	$shared_digest
dual_runtime_comparison	byte-identical
luajit_case_ids_artifact	luajit/case-ids.txt
luajit_case_ids_sha256	$full_case_ids_digest
puc51_case_ids_artifact	puc51/case-ids.txt
puc51_case_ids_sha256	$targeted_case_ids_digest
luajit_wall_seconds_measured	$luajit_wall
puc51_wall_seconds_measured	$puc_wall
ordinary_cold_sha_calls_measured	$ordinary_sha
ordinary_warm_added_sha_calls_measured	$warm_sha
triple_overlap_sha_calls_measured	$triple_sha
ordinary_sha_threshold_assessment	measured below 30
performance_clock	per-case cold/amortized values are measured process CPU seconds via os.clock; whole-run values are measured wall seconds
fixture_authoring_scan	separate 4.15-second exact Source-bounding-box scan; not repeated by acceptance
reproduction	WP40_LUA_BIN=$luajit_abs WP40_PUC_BIN=$puc_abs WP40_LUAC_BIN=$luac_abs WP40_EVIDENCE_DIR=$evidence_dir WP40_EVIDENCE_REFRESH=1 tools/wp40/run_t2_fields.sh
EOF
	for input in \
		mods/MAPGEN/grug_mapgen/wp40/canonical.lua \
		mods/MAPGEN/grug_mapgen/wp40/deterministic.lua \
		mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua \
		mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua \
		mods/MAPGEN/grug_mapgen/wp40/analytic_record.lua \
		mods/MAPGEN/grug_mapgen/wp40/geometry/relief.lua \
		mods/MAPGEN/grug_mapgen/wp40/geometry/template.lua \
		tools/wp40/t2_fields_test.lua \
		tools/wp40/run_t2_fields.sh \
		tools/wp40/t2_census_sha_server.py \
		tools/wp40/fixtures/t2_fields/ellipse-disagreements-v1.tsv \
		tools/wp40/fixtures/t2_fields/fixture-manifest-v1.tsv; do
		printf 'input_sha256:%s\t%s\n' "$input" \
			"$(sha256sum "$repo/$input" | awk '{print $1}')" >> "$evidence_dir/manifest.tsv"
	done
	printf 'mirrored_predicate_authority_sha256:%s\t%s\n' \
		'mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua' \
		"$(sha256sum "$repo/mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua" | awk '{print $1}')" \
		>> "$evidence_dir/manifest.tsv"
	printf 'mirrored_predicate_authority_execution\tnot loaded; exact mask predicates mirror this pinned Source validator authority\n' \
		>> "$evidence_dir/manifest.tsv"
	(
		cd "$evidence_dir"
		find . -type f ! -name checksums.sha256 -print0 | sort -z | \
			xargs -0 sha256sum > checksums.sha256
	)
	echo "WP40 C-a1 fields evidence written to $evidence_dir"
fi

echo "WP40 C-a1 fields passed: LuaJIT samples=$full_samples PUC samples=$puc_samples"
echo "WP40 C-a1 fields shared digest: $shared_digest"
echo "WP40 C-a1 fields full digest: $full_digest"
cat "$scratch/luajit/wall-time.tsv"
cat "$scratch/puc51/wall-time.tsv"
