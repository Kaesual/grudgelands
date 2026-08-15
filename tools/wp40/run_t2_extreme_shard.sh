#!/usr/bin/env bash
set -euo pipefail

if (( $# != 3 )); then
	echo "usage: tools/wp40/run_t2_extreme_shard.sh START END OUTPUT" >&2
	exit 2
fi
first="$1"
last="$2"
output="$3"
if [[ ! "$first" =~ ^(0|[1-9][0-9]{0,3})$ ||
	! "$last" =~ ^(0|[1-9][0-9]{0,3})$ ]] ||
	(( first < 0 || last != first + 511 || last > 4095 || first % 512 != 0 )); then
	echo "WP40 T2 extreme retained shards are the eight canonical 512-row ranges" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-extreme.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT
authority_commit="$(git -C "$repo" rev-parse --verify HEAD)"
authority_tree="$(git -C "$repo" rev-parse --verify "${authority_commit}^{tree}")"
launcher_authority=(
	"tools/wp40/run_t2_extreme_shard.sh"
	"tools/wp40/t2_extreme_authority.lua"
	"tools/wp40/t2_extreme_gate_check.lua"
	"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua"
)
for path in "${launcher_authority[@]}"; do
	git -C "$repo" ls-files --error-unmatch "$path" >/dev/null 2>&1 || {
		echo "WP40 T2 extreme launcher authority is untracked: $path" >&2
		exit 2
	}
done
if ! git -C "$repo" diff --quiet "$authority_commit" -- \
	"${launcher_authority[@]}"; then
	echo "WP40 T2 extreme launcher authority differs from commit $authority_commit" >&2
	exit 2
fi
echo "WP40 T2 extreme launcher authority: commit=$authority_commit tree=$authority_tree"
"$repo/tools/bin/lua51" "$script_dir/t2_extreme_gate_check.lua" "$repo" "$scratch"
interpreter_launcher=/usr/bin/luajit
if [[ ! -x "$interpreter_launcher" ]]; then
	echo "WP40 T2 extreme shard interpreter is not executable: $interpreter_launcher" >&2
	exit 2
fi
interpreter_path="$(readlink -f "$interpreter_launcher")"
if [[ "$interpreter_path" != /usr/bin/luajit-2.1.1767980792 ]]; then
	echo "WP40 T2 extreme shard interpreter target changed: $interpreter_path" >&2
	exit 2
fi
interpreter_id=luajit
interpreter_version="$("$interpreter_launcher" -v 2>&1)"
expected="$repo/tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-$(printf '%04d' "$first")-$(printf '%04d' "$last").tsv"
if [[ "$output" != "$expected" || -e "$output" ]]; then
	echo "WP40 T2 extreme shard output must be new: $expected" >&2
	exit 2
fi

export_repo="$scratch/export"
mkdir -p "$export_repo"
git -C "$repo" archive "$authority_commit" | tar -x -C "$export_repo"
export_script="$export_repo/tools/wp40"
export_output="$export_script/fixtures/t2_extreme_e0/shard-luajit-v3-$(printf '%04d' "$first")-$(printf '%04d' "$last").tsv"
"$repo/tools/bin/luac51" -p \
	"$export_repo/mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua" \
	"$export_repo/mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua" \
	"$export_repo/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua" \
	"$export_script/t2_extreme_authority.lua" \
	"$export_script/t2_extreme_gate_check.lua" \
	"$export_script/fixtures/t2_extreme_e0/full_scan_gate.lua" \
	"$export_script/fixtures/t2_extreme_e0/vocabulary.lua" \
	"$export_script/t2_extreme_shard_worker.lua"
echo "WP40 T2 extreme shard interpreter: $interpreter_launcher -> $interpreter_path"
"$interpreter_launcher" "$export_script/t2_extreme_shard_worker.lua" \
	"$export_repo" "$scratch" "$first" "$last" "$export_output" \
	"$interpreter_id" "$interpreter_launcher" "$interpreter_path" \
	"$interpreter_version" "$authority_commit" "$authority_tree"
temporary_output="$output.tmp"
if [[ -e "$temporary_output" ]]; then
	echo "WP40 T2 extreme shard temporary output already exists: $temporary_output" >&2
	exit 2
fi
cp -- "$export_output" "$temporary_output"
if ! cmp -s -- "$export_output" "$temporary_output"; then
	rm -f -- "$temporary_output"
	echo "WP40 T2 extreme shard copy verification failed" >&2
	exit 1
fi
mv -T -- "$temporary_output" "$output"
bash -n "$script_dir/run_t2_extreme_shard.sh"
