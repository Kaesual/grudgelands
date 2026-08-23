#!/usr/bin/env bash
set -euo pipefail

# Bounded Pinned PUC Conformance Core (PCC), contracts section 14.7.
# This runner never launches F1, F2, full-W, C1 reacceptance or a population
# under PUC.  Those final gates remain separately named by the contract.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
fixtures="$script_dir/fixtures/t2_puc_core"
luajit_requested="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"

command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}
luajit_bin="$(command -v "$luajit_requested" 2>/dev/null || true)"
[[ -n "$luajit_bin" && -x "$luajit_bin" && -x "$puc_bin" &&
	-x "$repo/tools/bin/luac51" ]] || {
	echo "WP40 PCC: LuaJIT and vendored PUC tools must be executable" >&2
	exit 2
}
luajit_real="$(readlink -f -- "$luajit_bin")"
puc_real="$(readlink -f -- "$puc_bin")"
if [[ "$luajit_real" == "$puc_real" ]]; then
	echo "WP40 PCC: LuaJIT and PUC resolve to the same executable" >&2
	exit 2
fi
if ! "$luajit_bin" -e \
	'assert(type(rawget(_G, "jit")) == "table" and type(jit.version) == "string")' \
		>/dev/null 2>&1; then
	echo "WP40 PCC: configured LuaJIT side is not genuinely LuaJIT: $luajit_requested" >&2
	exit 2
fi

leg="all"
capture=""
while (( $# > 0 )); do
	case "$1" in
	--micro|--source|--unit|--compiler|--worker|--worker-selftest|--merge|--optional|--all)
		leg="${1#--}"
		shift
		;;
	--capture)
		(( $# >= 2 )) || { echo "--capture requires a path" >&2; exit 2; }
		capture="$2"
		shift 2
		;;
	*)
		echo "usage: tools/wp40/run_t2_puc_core.sh [--micro|--source|--unit|--compiler|--worker|--worker-selftest|--merge|--optional|--all] [--capture SAFE_TMP_DIR]" >&2
		exit 2
		;;
	esac
done
if [[ -n "$capture" ]]; then
	if [[ ! "$capture" =~ ^/tmp/grudgelands-wp40-t2-puc-core\.[A-Za-z0-9]+$ ]] ||
			[[ -e "$capture" ]]; then
		echo "WP40 PCC: capture path must be a new safe /tmp PCC directory" >&2
		exit 2
	fi
	mkdir -p "$capture"
fi

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-puc-core.XXXXXXXX)"
declare -a leg_scratch_dirs=()
merge_progress_pid=0
cleanup() {
	local directory
	if (( merge_progress_pid != 0 )); then
		kill "$merge_progress_pid" 2>/dev/null || true
	fi
	for directory in "${leg_scratch_dirs[@]:-}"; do
		if [[ "$directory" == /tmp/grudgelands-wp40-t2-census.* ]]; then
			rm -rf -- "$directory"
		fi
	done
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-puc-core.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT INT TERM

verify_fixture_manifest() {
	local manifest="$fixtures/manifest-v1.tsv"
	[[ -f "$manifest" ]] || {
		echo "WP40 PCC: fixture manifest is missing" >&2
		exit 1
	}
	[[ $(rg -c '^schema\tgrug_wp40_puc_core_fixture_manifest_v1$' "$manifest") -eq 1 &&
		$(rg -c '^selection\t' "$manifest") -eq 1 &&
		$(rg -c '^final_rounds\t' "$manifest") -eq 1 ]] || {
		echo "WP40 PCC: fixture manifest header is malformed" >&2
		exit 1
	}
	local kind relative expected actual extra fixture_count=0 tree_count=0
	local compiler_count=0 worker_count=0 merge_count=0
	while IFS=$'\t' read -r kind relative expected extra; do
		case "$kind" in
		fixture)
			[[ -z "$extra" && "$relative" =~ ^[A-Za-z0-9._/-]+$ &&
				-f "$fixtures/$relative" && "$expected" =~ ^[0-9a-f]{64}$ ]] || {
				echo "WP40 PCC: malformed fixture manifest row: $relative" >&2
				exit 1
			}
			actual="$(sha256sum "$fixtures/$relative" | awk '{print $1}')"
			[[ "$actual" == "$expected" ]] || {
				echo "WP40 PCC: fixture manifest digest differs: $relative" >&2
				exit 1
			}
			fixture_count=$((fixture_count + 1))
			;;
		fixture_tree_sha256_stream)
			[[ -z "$extra" && "$relative" =~ ^[A-Za-z0-9._/-]+$ &&
				-d "$fixtures/$relative" && "$expected" =~ ^[0-9a-f]{64}$ ]] || {
				echo "WP40 PCC: malformed fixture-tree manifest row: $relative" >&2
				exit 1
			}
			actual="$(cd "$fixtures/$relative" &&
				find . -type f -print0 | sort -z | xargs -0 sha256sum |
				sha256sum | awk '{print $1}')"
			[[ "$actual" == "$expected" ]] || {
				echo "WP40 PCC: fixture-tree manifest digest differs: $relative" >&2
				exit 1
			}
			tree_count=$((tree_count + 1))
			;;
		compiler_digest)
			[[ -z "$extra" && "$relative" =~ ^[0-9]+$ &&
				"$expected" =~ ^[0-9a-f]{64}$ ]] || {
				echo "WP40 PCC: malformed compiler digest row" >&2
				exit 1
			}
			rg -Fqx "repro seed $relative compiled $expected" \
				"$fixtures/compiler-pair-v1.txt" || {
				echo "WP40 PCC: compiler digest pin is not carried by its fixture" >&2
				exit 1
			}
			compiler_count=$((compiler_count + 1))
			;;
		worker_internal_digest)
			[[ -z "$expected" && -z "$extra" &&
				"$relative" =~ ^[0-9a-f]{64}$ ]] || {
				echo "WP40 PCC: malformed worker digest row" >&2
				exit 1
			}
			if [[ "$(tail -n 1 "$fixtures/worker-pair-v1.tsv")" != \
					$'digest\tsha256='"$relative" ]] ||
					! rg -Fqx $'worker_internal_digest\t'"$relative" \
						"$fixtures/worker-pair-gate-v1.tsv"; then
				echo "WP40 PCC: worker digest pin is not carried by its fixtures" >&2
				exit 1
			fi
			worker_count=$((worker_count + 1))
			;;
		merge_artifacts_digest)
			[[ -z "$expected" && -z "$extra" &&
				"$relative" =~ ^[0-9a-f]{64}$ ]] || {
				echo "WP40 PCC: malformed merge digest row" >&2
				exit 1
			}
			[[ $(rg -Fc "artifacts_digest=$relative" \
				"$fixtures/merge-v1.txt") -eq 2 ]] || {
				echo "WP40 PCC: merge digest pin is not carried by stdout" >&2
				exit 1
			}
			for actual in "$fixtures/merge-v1/merge-luajit/census-manifest-v3.tsv" \
					"$fixtures/merge-v1/merge-puc/census-manifest-v3.tsv"; do
				rg -Fqx $'artifacts_digest\t'"$relative" "$actual" || {
					echo "WP40 PCC: merge digest pin is not carried by both manifests" >&2
					exit 1
				}
			done
			merge_count=$((merge_count + 1))
			;;
		esac
	done <"$manifest"
	[[ "$fixture_count" -eq 11 && "$tree_count" -eq 2 &&
		"$compiler_count" -eq 2 && "$worker_count" -eq 1 &&
		"$merge_count" -eq 1 ]] || {
		echo "WP40 PCC: fixture manifest roster differs" >&2
		exit 1
	}
}

verify_fixture_manifest

owned_lua=(
	"$script_dir/t2_puc_core_kat.lua"
	"$script_dir/t2_correction_repro.lua"
	"$script_dir/t2_census_worker.lua"
)
"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 PCC: global write in $file" >&2
		exit 1
	fi
done
bash -n "$script_dir/run_t2_puc_core.sh" "$script_dir/run_t2_census.sh" \
	"$script_dir/run_t2_compiler_optional_load.sh" \
	"$script_dir/run_t2_correction_kat.sh" \
	"$script_dir/t2_puc_worker_pair_gate.sh"
"$script_dir/run_t2_correction_kat.sh" --pair-self-test >/dev/null
"$script_dir/t2_puc_worker_pair_gate.sh" --self-test >/dev/null

new_lua_scratch() {
	mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX
}

publish_or_verify() {
	local source="$1" relative="$2"
	local expected="$fixtures/$relative"
	if [[ -n "$capture" ]]; then
		local target="$capture/$relative"
		mkdir -p "${target%/*}"
		[[ ! -e "$target" ]] || {
			echo "WP40 PCC: capture target already exists: $target" >&2
			exit 1
		}
		cp -- "$source" "$target"
	elif [[ ! -f "$expected" ]] || ! cmp -s -- "$source" "$expected"; then
		echo "WP40 PCC: fixture differs: $relative" >&2
		if [[ -f "$expected" ]]; then
			diff "$expected" "$source" >&2 || true
		fi
		exit 1
	fi
}

publish_tree_or_verify() {
	local source="$1" relative="$2"
	local expected="$fixtures/$relative"
	if [[ -n "$capture" ]]; then
		local target="$capture/$relative"
		[[ ! -e "$target" ]] || {
			echo "WP40 PCC: capture target already exists: $target" >&2
			exit 1
		}
		mkdir -p "${target%/*}"
		cp -a -- "$source" "$target"
	elif [[ ! -d "$expected" ]] || ! diff -qr -- "$expected" "$source" >/dev/null; then
		echo "WP40 PCC: fixture tree differs: $relative" >&2
		if [[ -d "$expected" ]]; then
			diff -qr -- "$expected" "$source" >&2 || true
		fi
		exit 1
	fi
}

normalize_merge_output() {
	local source="$1" target="$2" interpreter_lines
	interpreter_lines="$(rg -c '^WP40 T2 census interpreter: .+ -> .+$' \
		"$source" || true)"
	if [[ "$interpreter_lines" != 1 ]] ||
			! head -n 1 "$source" |
				rg -q '^WP40 T2 census interpreter: .+ -> .+$'; then
		echo "WP40 PCC merge: expected exactly one leading interpreter identity" >&2
		return 1
	fi
	sed -E 's|^WP40 T2 census interpreter: .+ -> .+$|WP40 T2 census interpreter: <LuaJIT>|' \
		"$source" >"$target"
}

normalize_optional_output() {
	local source="$1" target="$2" success_lines
	local success_pattern='^WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=(de_DE\.UTF-8|de_DE\.utf8|fr_FR\.UTF-8|fr_FR\.utf8)$'
	success_lines="$(rg -c -- "$success_pattern" "$source" || true)"
	if [[ "$success_lines" != 1 ]] ||
			! tail -n 1 "$source" | rg -q -- "$success_pattern"; then
		echo "WP40 PCC optional: expected exactly one trailing C plus real non-C locale success line" >&2
		return 1
	fi
	sed -E '$s#^(WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=)(de_DE\.UTF-8|de_DE\.utf8|fr_FR\.UTF-8|fr_FR\.utf8)$#\1<non-C>#' \
		"$source" >"$target"
}

normalization_raw="$scratch/merge-normalization.raw.txt"
normalization_actual="$scratch/merge-normalization.actual.txt"
normalization_expected="$scratch/merge-normalization.expected.txt"
printf '%s\n%s\n' \
	'WP40 T2 census interpreter: /host/luajit -> /host/luajit-build-id' \
	'semantic-line' >"$normalization_raw"
printf '%s\n%s\n' 'WP40 T2 census interpreter: <LuaJIT>' 'semantic-line' \
	>"$normalization_expected"
normalize_merge_output "$normalization_raw" "$normalization_actual"
cmp -s -- "$normalization_expected" "$normalization_actual" || {
	echo "WP40 PCC merge: interpreter normalization self-test failed" >&2
	exit 1
}
printf '%s\n' \
	'WP40 T2 census interpreter: /extra/luajit -> /extra/luajit-build-id' \
	>>"$normalization_raw"
if normalize_merge_output "$normalization_raw" "$normalization_actual" \
		>/dev/null 2>&1; then
	echo "WP40 PCC merge: extra-identity normalization self-test passed" >&2
	exit 1
fi

optional_raw="$scratch/optional-normalization.raw.txt"
optional_actual="$scratch/optional-normalization.actual.txt"
optional_expected="$scratch/optional-normalization.expected.txt"
printf '%s\n%s\n' 'semantic-line' \
	'WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=<non-C>' \
	>"$optional_expected"
for locale_name in de_DE.UTF-8 de_DE.utf8 fr_FR.UTF-8 fr_FR.utf8; do
	printf '%s\n%s%s\n' 'semantic-line' \
		'WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=' \
		"$locale_name" >"$optional_raw"
	normalize_optional_output "$optional_raw" "$optional_actual"
	cmp -s -- "$optional_expected" "$optional_actual" || {
		echo "WP40 PCC optional: locale normalization self-test failed for $locale_name" >&2
		exit 1
	}
done
expect_optional_normalization_reject() {
	local label="$1"
	if normalize_optional_output "$optional_raw" "$optional_actual" \
			>/dev/null 2>&1; then
		echo "WP40 PCC optional: $label normalization negative passed" >&2
		exit 1
	fi
}
printf '%s\n' 'semantic-line' >"$optional_raw"
expect_optional_normalization_reject zero-success
printf '%s\n%s\n' 'semantic-line' \
	'WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C' \
	>"$optional_raw"
expect_optional_normalization_reject no-non-c
printf '%s\n%s\n' \
	'WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=de_DE.utf8' \
	'WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=fr_FR.utf8' \
	>"$optional_raw"
expect_optional_normalization_reject multiple-success
printf '%s\n' \
	'WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=de_DE utf8' \
	>"$optional_raw"
expect_optional_normalization_reject malformed-success
printf '%s\n%s\n' \
	'WP40 T2 compiler optional-load: LuaJIT/PUC byte-identical under LC_ALL=C and LC_ALL=de_DE.utf8' \
	'semantic-line' >"$optional_raw"
expect_optional_normalization_reject non-trailing-success

run_dual_kat() {
	local mode="$1" fixture="$2"
	local jit_scratch puc_scratch jit_out puc_out jit_status=0 puc_status=0
	jit_scratch="$(new_lua_scratch)"
	puc_scratch="$(new_lua_scratch)"
	leg_scratch_dirs+=("$jit_scratch" "$puc_scratch")
	jit_out="$scratch/$mode-luajit.txt"
	puc_out="$scratch/$mode-puc.txt"
	"$luajit_bin" "$script_dir/t2_puc_core_kat.lua" "$repo" "$jit_scratch" \
		"$mode" >"$jit_out" 2>&1 || jit_status=$?
	"$puc_bin" "$script_dir/t2_puc_core_kat.lua" "$repo" "$puc_scratch" \
		"$mode" >"$puc_out" 2>&1 || puc_status=$?
	rm -rf -- "$jit_scratch" "$puc_scratch"
	if (( jit_status != puc_status )) || ! cmp -s -- "$jit_out" "$puc_out"; then
		echo "WP40 PCC $mode: LuaJIT/PUC output or exit differs" >&2
		diff "$jit_out" "$puc_out" >&2 || true
		exit 1
	fi
	if (( jit_status != 0 )); then
		cat "$jit_out" >&2
		echo "WP40 PCC $mode: both interpreters failed ($jit_status)" >&2
		exit "$jit_status"
	fi
	publish_or_verify "$jit_out" "$fixture"
	cat "$jit_out"
	echo "WP40 PCC $mode: LuaJIT/PUC stdout and exit byte-identical"
}

run_micro() { run_dual_kat micro micro-v1.txt; }
run_source() { run_dual_kat source source-v1.txt; }

run_unit() {
	local combined="$scratch/unit-v1.txt"
	: >"$combined"
	"$script_dir/run_t2_correction_kat.sh" >>"$combined"
	local s11_dir="${WP40_S11_ARTIFACTS_DIR:-$repo/tools/wp40/results/bay-transition-package-final-artifacts}"
	[[ -d "$s11_dir" ]] || {
		echo "WP40 PCC unit: set WP40_S11_ARTIFACTS_DIR to the retained Section-11 artifacts" >&2
		exit 2
	}
	local s11_output="$scratch/s11-v1.txt"
	"$script_dir/run_t2_s11_acceptance.sh" "$s11_dir" >"$s11_output"
	sed -e 's|^artifacts .*|artifacts <retained>|' \
		-e 's|^fixtures .*|fixtures <canonical>|' "$s11_output" >>"$combined"
	local jit_scratch puc_scratch jit_out puc_out jit_status=0 puc_status=0
	jit_scratch="$(new_lua_scratch)"
	puc_scratch="$(new_lua_scratch)"
	leg_scratch_dirs+=("$jit_scratch" "$puc_scratch")
	jit_out="$scratch/scan4-luajit.txt"
	puc_out="$scratch/scan4-puc.txt"
	"$luajit_bin" "$script_dir/t2_census_scan4_kat.lua" "$repo" "$jit_scratch" \
		>"$jit_out" 2>&1 || jit_status=$?
	"$puc_bin" "$script_dir/t2_census_scan4_kat.lua" "$repo" "$puc_scratch" \
		>"$puc_out" 2>&1 || puc_status=$?
	rm -rf -- "$jit_scratch" "$puc_scratch"
	if (( jit_status != puc_status )) || ! cmp -s -- "$jit_out" "$puc_out"; then
		echo "WP40 PCC unit: Scan-3b/4 LuaJIT/PUC output or exit differs" >&2
		diff "$jit_out" "$puc_out" >&2 || true
		exit 1
	fi
	if (( jit_status != 0 )); then
		cat "$jit_out" >&2
		exit "$jit_status"
	fi
	cat "$jit_out" >>"$combined"
	printf '%s\n' 'WP40 PCC unit: Scan-3b/4 LuaJIT/PUC stdout and exit byte-identical' \
		>>"$combined"
	publish_or_verify "$combined" unit-v1.txt
	cat "$combined"
}

run_bounded_pair() {
	local name="$1" limit="$2" driver="$3"
	shift 3
	local jit_scratch puc_scratch jit_out puc_out start remaining
	local jit_status=0 puc_status=0
	jit_scratch="$(new_lua_scratch)"
	puc_scratch="$(new_lua_scratch)"
	leg_scratch_dirs+=("$jit_scratch" "$puc_scratch")
	jit_out="$scratch/$name-luajit.txt"
	puc_out="$scratch/$name-puc.txt"
	start=$SECONDS
	echo "WP40 PCC $name phase=luajit" >&2
	timeout --signal=TERM --kill-after=5s "$limit" "$luajit_bin" "$driver" "$repo" \
		"$jit_scratch" "$@" \
		>"$jit_out" 2>&1 || jit_status=$?
	local jit_seconds=$((SECONDS - start))
	remaining=$((limit - (SECONDS - start)))
	if (( remaining <= 0 )); then
		rm -rf -- "$jit_scratch" "$puc_scratch"
		echo "WP40 PCC $name: pair exhausted ${limit}s wall budget after LuaJIT" >&2
		exit 124
	fi
	echo "WP40 PCC $name phase=puc remaining_budget_seconds=$remaining" >&2
	timeout --signal=TERM --kill-after=5s "$remaining" "$puc_bin" "$driver" "$repo" \
		"$puc_scratch" "$@" \
		>"$puc_out" 2>&1 || puc_status=$?
	local total_seconds=$((SECONDS - start))
	local puc_seconds=$((total_seconds - jit_seconds))
	rm -rf -- "$jit_scratch" "$puc_scratch"
	if (( jit_status != puc_status )) || ! cmp -s -- "$jit_out" "$puc_out"; then
		echo "WP40 PCC $name: LuaJIT/PUC output or exit differs" >&2
		diff "$jit_out" "$puc_out" >&2 || true
		exit 1
	fi
	if (( jit_status != 0 )); then
		cat "$jit_out" >&2
		echo "WP40 PCC $name: both interpreters failed ($jit_status)" >&2
		exit "$jit_status"
	fi
	publish_or_verify "$jit_out" "$name-v1.txt"
	if [[ -n "$capture" ]]; then
		printf 'leg\tluajit_seconds\tpuc_seconds\ttotal_seconds\n%s\t%d\t%d\t%d\n' \
			"$name" "$jit_seconds" "$puc_seconds" "$total_seconds" \
			>"$capture/$name-runtime-v1.tsv"
	fi
	cat "$jit_out"
	echo "WP40 PCC $name: LuaJIT/PUC stdout and exit byte-identical"
}

run_compiler() {
	# The driver receives REPO, then the interpreter-specific scratch injected
	# by run_bounded_pair, then the two memo-owned witnesses.
	run_bounded_pair compiler-pair 3600 \
		"$script_dir/t2_correction_repro.lua" \
		1959553668008863006 2147483648
}

run_worker_selftest() {
	"$script_dir/t2_puc_worker_pair_gate.sh" --self-test
}

run_worker() {
	local jit_scratch puc_scratch jit_out puc_out jit_err puc_err jit_tsv puc_tsv
	local jit_status=0 puc_status=0 start remaining limit=3600
	local gate_dir="$scratch/worker-pair-gate"
	run_worker_selftest
	jit_scratch="$(new_lua_scratch)"
	puc_scratch="$(new_lua_scratch)"
	leg_scratch_dirs+=("$jit_scratch" "$puc_scratch")
	jit_out="$scratch/worker-luajit.txt"
	puc_out="$scratch/worker-puc.txt"
	jit_err="$scratch/worker-luajit.stderr"
	puc_err="$scratch/worker-puc.stderr"
	jit_tsv="$scratch/worker-luajit.tsv"
	puc_tsv="$scratch/worker-puc.tsv"
	start=$SECONDS
	echo "WP40 PCC worker-pair phase=luajit seeds=2" >&2
	timeout --signal=TERM --kill-after=5s "$limit" "$luajit_bin" \
		"$script_dir/t2_census_worker.lua" "$repo" "$jit_scratch" "$jit_tsv" \
		2147483648 16178445837170081103 >"$jit_out" 2>"$jit_err" || jit_status=$?
	local jit_seconds=$((SECONDS - start))
	remaining=$((limit - (SECONDS - start)))
	if (( remaining <= 0 )); then
		rm -rf -- "$jit_scratch" "$puc_scratch"
		echo "WP40 PCC worker-pair: exhausted 3600s wall budget after LuaJIT" >&2
		exit 124
	fi
	echo "WP40 PCC worker-pair phase=puc seeds=2 remaining_budget_seconds=$remaining" >&2
	timeout --signal=TERM --kill-after=5s "$remaining" "$puc_bin" \
		"$script_dir/t2_census_worker.lua" "$repo" "$puc_scratch" "$puc_tsv" \
		2147483648 16178445837170081103 >"$puc_out" 2>"$puc_err" || puc_status=$?
	local total_seconds=$((SECONDS - start))
	local puc_seconds=$((total_seconds - jit_seconds))
	rm -rf -- "$jit_scratch" "$puc_scratch"
	if ! "$script_dir/t2_puc_worker_pair_gate.sh" \
			"$jit_out" "$jit_err" "$jit_status" "$jit_tsv" \
			"$puc_out" "$puc_err" "$puc_status" "$puc_tsv" "$gate_dir"; then
		echo "WP40 PCC worker-pair: channel-aware gate failed" >&2
		echo "--- LuaJIT stderr ---" >&2
		cat "$jit_err" >&2 || true
		echo "--- PUC stderr ---" >&2
		cat "$puc_err" >&2 || true
		exit 1
	fi
	publish_or_verify "$jit_out" worker-pair-v1.txt
	publish_or_verify "$jit_tsv" worker-pair-v1.tsv
	publish_or_verify "$gate_dir/worker-pair-telemetry-v1.txt" \
		worker-pair-telemetry-v1.txt
	publish_or_verify "$gate_dir/worker-pair-gate-v1.tsv" \
		worker-pair-gate-v1.tsv
	if [[ -n "$capture" ]]; then
		cp -- "$jit_err" "$capture/worker-pair-luajit-stderr-v1.log"
		cp -- "$puc_err" "$capture/worker-pair-puc-stderr-v1.log"
		printf 'leg\tluajit_seconds\tpuc_seconds\ttotal_seconds\nworker-pair\t%d\t%d\t%d\n' \
			"$jit_seconds" "$puc_seconds" "$total_seconds" \
			>"$capture/worker-pair-runtime-v1.tsv"
	fi
	cat "$jit_out"
	echo "WP40 PCC worker-pair: exits zero/equal; stdout and records byte-identical; telemetry normalized/retained"
}

run_merge() {
	local retained="$scratch/merge"
	local raw_output="$scratch/merge-v1.raw.txt" output="$scratch/merge-v1.txt"
	local progress="$scratch/merge-progress.log" progress_fifo="$scratch/merge-progress.fifo"
	local status=0 tee_status=0 tee_pid start total_seconds
	mkfifo "$progress_fifo"
	tee "$progress" <"$progress_fifo" >&2 &
	tee_pid=$!
	merge_progress_pid=$tee_pid
	start=$SECONDS
	timeout --signal=TERM --kill-after=5s 420 env WP40_LUA_BIN="$luajit_bin" \
		"$script_dir/run_t2_census.sh" --merge-kat \
		--retain-evidence "$retained" >"$raw_output" \
		2>"$progress_fifo" || status=$?
	wait "$tee_pid" || tee_status=$?
	merge_progress_pid=0
	rm -f -- "$progress_fifo"
	total_seconds=$((SECONDS - start))
	if (( tee_status != 0 )); then
		echo "WP40 PCC merge: progress capture failed ($tee_status)" >&2
		exit 1
	fi
	if (( status != 0 )); then
		cat "$raw_output" >&2
		if (( status == 124 )); then
			echo "WP40 PCC merge: reached the authorized 420-second wall limit" >&2
		fi
		exit "$status"
	fi
	if ! normalize_merge_output "$raw_output" "$output"; then
		exit 1
	fi
	for manifest in "$retained/merge-luajit/census-manifest-v3.tsv" \
			"$retained/merge-puc/census-manifest-v3.tsv"; do
		rg -q '^divergence_test\tpairs_order_probe_unsorted=true synthetic_invariance=passed .* measured_invariance=passed$' \
			"$manifest" || {
			echo "WP40 PCC merge: retained divergence evidence is incomplete" >&2
			exit 1
		}
	done
	publish_or_verify "$output" merge-v1.txt
	publish_tree_or_verify "$retained" merge-v1
	if [[ -n "$capture" ]]; then
		publish_or_verify "$progress" merge-progress-v1.log
		printf 'leg\ttotal_seconds\nmerge-seven-seed\t%d\n' "$total_seconds" \
			>"$capture/merge-runtime-v1.tsv"
	fi
	cat "$output"
	echo "WP40 PCC merge: probe, synthetic and measured invariance retained"
}

run_optional() {
	local raw_output="$scratch/optional-load-v1.raw.txt"
	local output="$scratch/optional-load-v1.txt" status=0
	WP40_LUA_BIN="$luajit_bin" "$script_dir/run_t2_compiler_optional_load.sh" \
		>"$raw_output" 2>&1 || status=$?
	if (( status != 0 )); then cat "$raw_output" >&2; exit "$status"; fi
	if ! normalize_optional_output "$raw_output" "$output"; then
		cat "$raw_output" >&2
		exit 1
	fi
	publish_or_verify "$output" optional-load-v1.txt
	cat "$output"
}

case "$leg" in
micro) run_micro ;;
source) run_source ;;
unit) run_unit ;;
compiler) run_compiler ;;
worker) run_worker ;;
worker-selftest) run_worker_selftest ;;
merge) run_merge ;;
optional) run_optional ;;
all)
	run_micro
	run_source
	run_unit
	run_optional
	run_compiler
	run_worker
	run_merge
	;;
esac

echo "WP40 PCC $leg passed"
