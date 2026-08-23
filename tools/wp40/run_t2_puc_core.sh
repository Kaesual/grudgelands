#!/usr/bin/env bash
set -euo pipefail

# Bounded Pinned PUC Conformance Core (PCC), contracts section 14.7.
# This runner never launches F1, F2, full-W, C1 reacceptance or a population
# under PUC.  Those final gates remain separately named by the contract.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
fixtures="$script_dir/fixtures/t2_puc_core"
luajit_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"

command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}
[[ -x "$luajit_bin" && -x "$puc_bin" && -x "$repo/tools/bin/luac51" ]] || {
	echo "WP40 PCC: LuaJIT and vendored PUC tools must be executable" >&2
	exit 2
}

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
cleanup() {
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
		esac
	done <"$manifest"
	[[ "$fixture_count" -eq 10 && "$tree_count" -eq 2 ]] || {
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

run_dual_kat() {
	local mode="$1" fixture="$2"
	local jit_scratch puc_scratch jit_out puc_out jit_status=0 puc_status=0
	jit_scratch="$(new_lua_scratch)"
	puc_scratch="$(new_lua_scratch)"
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
		echo "WP40 PCC $name: pair exhausted ${limit}s wall budget after LuaJIT" >&2
		exit 124
	fi
	echo "WP40 PCC $name phase=puc remaining_budget_seconds=$remaining" >&2
	timeout --signal=TERM --kill-after=5s "$remaining" "$puc_bin" "$driver" "$repo" \
		"$puc_scratch" "$@" \
		>"$puc_out" 2>&1 || puc_status=$?
	local total_seconds=$((SECONDS - start))
	local puc_seconds=$((total_seconds - jit_seconds))
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
	rm -rf -- "$jit_scratch" "$puc_scratch"
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
		echo "WP40 PCC worker-pair: exhausted 3600s wall budget after LuaJIT" >&2
		exit 124
	fi
	echo "WP40 PCC worker-pair phase=puc seeds=2 remaining_budget_seconds=$remaining" >&2
	timeout --signal=TERM --kill-after=5s "$remaining" "$puc_bin" \
		"$script_dir/t2_census_worker.lua" "$repo" "$puc_scratch" "$puc_tsv" \
		2147483648 16178445837170081103 >"$puc_out" 2>"$puc_err" || puc_status=$?
	local total_seconds=$((SECONDS - start))
	local puc_seconds=$((total_seconds - jit_seconds))
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
	rm -rf -- "$jit_scratch" "$puc_scratch"
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
	local output="$scratch/merge-v1.txt" progress="$scratch/merge-progress.log"
	local status=0
	timeout --signal=TERM --kill-after=5s 420 env WP40_LUA_BIN="$luajit_bin" \
		"$script_dir/run_t2_census.sh" --merge-kat \
		--retain-evidence "$retained" >"$output" \
		2> >(tee "$progress" >&2) || status=$?
	if (( status != 0 )); then
		cat "$output" >&2
		if (( status == 124 )); then
			echo "WP40 PCC merge: reached the authorized 420-second wall limit" >&2
		fi
		exit "$status"
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
	fi
	cat "$output"
	echo "WP40 PCC merge: probe, synthetic and measured invariance retained"
}

run_optional() {
	local output="$scratch/optional-load-v1.txt" status=0
	WP40_LUA_BIN="$luajit_bin" "$script_dir/run_t2_compiler_optional_load.sh" \
		>"$output" 2>&1 || status=$?
	if (( status != 0 )); then cat "$output" >&2; exit "$status"; fi
	if [[ -n "$capture" ]]; then
		publish_or_verify "$output" optional-load-v1.txt
	fi
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
