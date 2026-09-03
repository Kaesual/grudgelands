#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$script_dir/../../.." && pwd -P)"
source_audit="$repo/tools/wp40/r7/source_audit.sh"
final_micro="$repo/tools/wp40/r7/final_micro.sh"
r7_run="$repo/tools/wp40/r7/run.sh"
integration="$repo/docs/research/wp40-r8-projection-integration-receipt.tsv"
pilot="$repo/tools/wp40/evidence/wp40-r8-cold-start-444d8f2f1e32d14d1304e650ffe25205d61e5083596dc32a3d4f9487ad18f560"
durable_parent="$repo/docs/research/wp40-r8-cold-start-final-micro-evidence"
durable="$durable_parent/result"

[[ "$#" -eq 0 ]] || {
	echo "usage: bash tools/wp40/r8/finalize_cold_start.sh" >&2
	exit 2
}
for command_name in awk bash cmp cp dirname git ln mkdir mktemp mv ps rm sha256sum sort wc; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "WP40 R8 cold-start finalization: missing command $command_name" >&2
		exit 1
	}
done
[[ -x "$source_audit" && -x "$final_micro" && -x "$r7_run" && -f "$integration" &&
	-f "$pilot/checksums.sha256" && -d "$durable_parent" &&
	! -e "$durable" ]] || {
	echo "WP40 R8 cold-start finalization: input or durable boundary differs" >&2
	exit 1
}
[[ -z "$(git -C "$repo" status --porcelain --untracked-files=no)" ]] || {
	echo "WP40 R8 cold-start finalization: tracked worktree is not clean" >&2
	exit 1
}

candidate_commit="$(git -C "$repo" rev-parse HEAD)"
production_commit=269038e3c437f0014fc4fcace748e474541c6112
git -C "$repo" diff --quiet "$production_commit" "$candidate_commit" -- mods || {
	echo "WP40 R8 cold-start finalization: reviewed production bytes changed" >&2
	exit 1
}
self_sha="$(sha256sum "$script_dir/finalize_cold_start.sh" | awk '{print $1}')"
integration_sha="$(sha256sum "$integration" | awk '{print $1}')"
integration_manifest="$(awk -F '\t' '$1 == "r7_manifest_sha256" {
	count++; value=$2} END {if (count == 1) print value}' "$integration")"
[[ "$integration_sha" == 1fc22c764be500726f6f777b0eabd7a03a2434e23895aad6132c7c7e1ca78010 &&
	"$integration_manifest" == 9ff0e78818e842c578ecacbf9d5be4426ca72f6c3230f6184b0e8b23f69f369d ]] || {
	echo "WP40 R8 cold-start finalization: integration receipt differs" >&2
	exit 1
}
(
	cd "$pilot"
	sha256sum -c checksums.sha256 >/dev/null
) || {
	echo "WP40 R8 cold-start finalization: pilot evidence differs" >&2
	exit 1
}
pilot_checksums_sha="$(sha256sum "$pilot/checksums.sha256" | awk '{print $1}')"
[[ "$pilot_checksums_sha" == 1f0f645ea325b31c97acf5dda7ece2ab65e533b9e6e81cc776a512bf1fd9000b ]] || {
	echo "WP40 R8 cold-start finalization: pilot checksum identity differs" >&2
	exit 1
}

stage="$(mktemp -d "$durable_parent/.cold-start-final.partial.XXXXXXXX")"
scratch="$(mktemp -d /tmp/grudgelands-wp40-r8-final.XXXXXXXX)"
cleanup() {
	local status=$?
	case "$stage" in
		"$durable_parent"/.cold-start-final.partial.*) rm -rf -- "$stage" ;;
	esac
	case "$scratch" in
		/tmp/grudgelands-wp40-r8-final.*) rm -rf -- "$scratch" ;;
	esac
	return "$status"
}
trap cleanup EXIT

prefreeze="$scratch/source-audit-prefreeze.tsv"
postfreeze="$scratch/source-audit-postfreeze.tsv"
static_log="$scratch/static-gates.log"
bash "$r7_run" static >"$static_log"
bash "$source_audit" "$repo" "$prefreeze" prefreeze >/dev/null
bash "$final_micro" "$repo" "$stage/receipt.tsv" >/dev/null
bash "$source_audit" "$repo" "$postfreeze" prefreeze >/dev/null
cmp -s "$prefreeze" "$postfreeze" || {
	echo "WP40 R8 cold-start finalization: source inputs changed during final pair" >&2
	exit 1
}
[[ "$candidate_commit" == "$(git -C "$repo" rev-parse HEAD)" &&
	"$self_sha" == "$(sha256sum "$script_dir/finalize_cold_start.sh" | awk '{print $1}')" &&
	-z "$(git -C "$repo" status --porcelain --untracked-files=no)" ]] || {
	echo "WP40 R8 cold-start finalization: commit or tracked bytes changed" >&2
	exit 1
}

micro="$stage/receipt.tsv"
micro_value() {
	local key="$1"
	awk -F '\t' -v wanted="$key" '$1 == wanted {count++; value=$2}
		END {if (count == 1) print value}' "$micro"
}
output="$stage/wp40-r7-micro-kat-output.tsv"
luajit_log="$stage/wp40-r7-micro-kat-luajit.log"
puc51_log="$stage/wp40-r7-micro-kat-puc51.log"
changed_roster_sha="$(sha256sum "$repo/tools/wp40/r7/changed_production_lua.txt" |
	awk '{print $1}')"
[[ "$(micro_value schema)" == grug_wp40_r7_micro_kat_receipt_v1 &&
	"$(micro_value input_population)" == 108 &&
	"$(micro_value executed_module_population)" == 74 &&
	"$(micro_value executed_module_roster_sha256)" == "$changed_roster_sha" &&
	"$(micro_value byte_identical)" == true &&
	"$(awk -F '\t' '$1 == "input" {count++} END {print count + 0}' "$micro")" == 108 &&
	"$(micro_value canonical_output_filename)" == wp40-r7-micro-kat-output.tsv &&
	"$(micro_value luajit_log_filename)" == wp40-r7-micro-kat-luajit.log &&
	"$(micro_value puc51_log_filename)" == wp40-r7-micro-kat-puc51.log &&
	"$(micro_value canonical_output_sha256)" == "$(sha256sum "$output" | awk '{print $1}')" &&
	"$(micro_value luajit_log_sha256)" == "$(sha256sum "$luajit_log" | awk '{print $1}')" &&
	"$(micro_value puc51_log_sha256)" == "$(sha256sum "$puc51_log" | awk '{print $1}')" ]] || {
	echo "WP40 R8 cold-start finalization: final micro evidence differs" >&2
	exit 1
}

cp -- "$prefreeze" "$stage/source-audit-prefreeze.tsv"
cp -- "$static_log" "$stage/static-gates.log"
source_audit_sha="$(sha256sum "$prefreeze" | awk '{print $1}')"
static_sha="$(sha256sum "$static_log" | awk '{print $1}')"
code_input_sha="$(awk -F '\t' '$1 == "code_input_set_sha256" {count++; value=$2}
	END {if (count == 1) print value}' "$prefreeze")"
micro_sha="$(sha256sum "$micro" | awk '{print $1}')"
output_sha="$(sha256sum "$output" | awk '{print $1}')"
input_set_sha="$(micro_value input_set_sha256)"
{
	printf 'schema\tgrug_wp40_r8_cold_start_finalization_v1\n'
	printf 'candidate_commit\t%s\n' "$candidate_commit"
	printf 'production_commit\t%s\n' "$production_commit"
	printf 'finalizer_sha256\t%s\n' "$self_sha"
	printf 'static_gates_sha256\t%s\n' "$static_sha"
	printf 'source_audit_prefreeze_sha256\t%s\n' "$source_audit_sha"
	printf 'code_input_set_sha256\t%s\n' "$code_input_sha"
	printf 'integration_receipt_sha256\t%s\n' "$integration_sha"
	printf 'r7_manifest_sha256\t%s\n' \
		9ff0e78818e842c578ecacbf9d5be4426ca72f6c3230f6184b0e8b23f69f369d
	printf 'pilot_capture_id\t%s\n' \
		444d8f2f1e32d14d1304e650ffe25205d61e5083596dc32a3d4f9487ad18f560
	printf 'pilot_checksums_sha256\t%s\n' "$pilot_checksums_sha"
	printf 'micro_receipt_sha256\t%s\n' "$micro_sha"
	printf 'micro_input_set_sha256\t%s\n' "$input_set_sha"
	printf 'micro_input_population\t108\n'
	printf 'executed_module_population\t74\n'
	printf 'canonical_output_sha256\t%s\n' "$output_sha"
	printf 'byte_identical\ttrue\n'
	printf 'gate\ttracked_worktree_stable\ttrue\n'
	printf 'gate\tprefreeze_postfreeze_equal\ttrue\n'
	printf 'gate\tintegration_receipt_bound\ttrue\n'
	printf 'gate\tpilot_checksums_verified\ttrue\n'
	printf 'gate\tfinal_micro_validated\ttrue\n'
} >"$stage/final-audit.tsv"

mv -T --no-clobber "$stage" "$durable"
stage=""
printf 'WP40 R8 cold-start finalization PASS audit_sha256=%s micro_sha256=%s\n' \
	"$(sha256sum "$durable/final-audit.tsv" | awk '{print $1}')" "$micro_sha"
