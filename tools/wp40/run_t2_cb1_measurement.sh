#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
luajit_bin="${WP40_LUA_BIN:-$(command -v luajit || true)}"
puc_bin="${WP40_PUC_BIN:-$repo/tools/bin/lua51}"
luac_bin="${WP40_LUAC_BIN:-$repo/tools/bin/luac51}"
evidence="$repo/tools/wp40/evidence/t2-cb1-v1"
tested_commit="$(git -C "$repo" rev-parse HEAD)"
tested_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
[[ "$tested_commit" == "64592fe24e092997bf676cc2e245ff9181b5ae93" ]] || {
	echo "WP40 CB-1: expected owner-clip tip, got $tested_commit" >&2
	exit 1
}

[[ -n "$luajit_bin" && -x "$luajit_bin" ]] || {
	echo "WP40 CB-1: executable LuaJIT is required" >&2
	exit 127
}
[[ -x "$puc_bin" ]] || {
	echo "WP40 CB-1: executable PUC 5.1 is required; set WP40_PUC_BIN" >&2
	exit 127
}
[[ -x "$luac_bin" ]] || {
	echo "WP40 CB-1: executable luac51 is required; set WP40_LUAC_BIN" >&2
	exit 127
}
command -v rg >/dev/null 2>&1 || {
	echo "WP40 CB-1: ripgrep is required" >&2
	exit 127
}

owned_lua=(
	"$script_dir/cb1_common.lua"
	"$script_dir/cb1_roster.lua"
	"$script_dir/cb1_profile_feasibility.lua"
	"$script_dir/cb1_island_deficits.lua"
	"$script_dir/cb1_route_reach.lua"
	"$script_dir/cb1_hydrology_audit.lua"
	"$script_dir/cb1_measure.lua"
)

"$luac_bin" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$luac_bin" -p -l - < "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 CB-1: global write in $file" >&2
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
		echo "WP40 CB-1: forbidden Lua construct matched" >&2
		exit 1
	fi
done
bash -n "$0"

scratch="$(mktemp -d -p /tmp grudgelands-wp40-cb1.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-cb1.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

deterministic_artifacts=(
	findings.tsv
	hydrology-audit.tsv
	island-deficits.tsv
	manifest.tsv
	profile-feasibility.tsv
	route-reach-intersections.tsv
	route-roster.tsv
)

run_one() {
	local label="$1"
	local interpreter="$2"
	local output_dir="$scratch/$label-output"
	local hash_scratch="$scratch/$label-hasher"
	mkdir -p "$output_dir" "$hash_scratch"
	/usr/bin/time -f $'wall_seconds\t%e\nuser_seconds\t%U\nsystem_seconds\t%S' \
		-o "$scratch/$label-wall-time.tsv" \
		"$interpreter" "$script_dir/cb1_measure.lua" "$repo" "$hash_scratch" \
		"$output_dir" "$tested_commit" "$tested_tree" \
		>"$scratch/$label-run.log" 2>&1
}

run_one luajit "$luajit_bin"
run_one puc51 "$puc_bin"
for artifact in "${deterministic_artifacts[@]}"; do
	cmp "$scratch/luajit-output/$artifact" "$scratch/puc51-output/$artifact"
done

mkdir -p "$evidence"
find "$evidence" -mindepth 1 -maxdepth 1 -type f -delete
for artifact in "${deterministic_artifacts[@]}"; do
	cp "$scratch/luajit-output/$artifact" "$evidence/$artifact"
done
cp "$scratch/luajit-output/runtime.tsv" "$evidence/luajit-runtime.tsv"
cp "$scratch/puc51-output/runtime.tsv" "$evidence/puc51-runtime.tsv"
cp "$scratch/luajit-run.log" "$evidence/luajit-run.log"
cp "$scratch/puc51-run.log" "$evidence/puc51-run.log"
cp "$scratch/luajit-wall-time.tsv" "$evidence/luajit-wall-time.tsv"
cp "$scratch/puc51-wall-time.tsv" "$evidence/puc51-wall-time.tsv"
{
	printf 'comparison\tartifact_count\tresult\n'
	printf 'LuaJIT_vs_PUC51\t%s\tbyte_identical\n' \
		"${#deterministic_artifacts[@]}"
} > "$evidence/dual-runtime.tsv"

(
	cd "$evidence"
	sha256sum dual-runtime.tsv "${deterministic_artifacts[@]}" \
		> REPRODUCIBLE.sha256
	sha256sum luajit-run.log luajit-runtime.tsv luajit-wall-time.tsv \
		puc51-run.log puc51-runtime.tsv puc51-wall-time.tsv \
		> RUN-EVIDENCE.sha256
	sha256sum -c REPRODUCIBLE.sha256
	sha256sum -c RUN-EVIDENCE.sha256
)

awk -F '\t' 'NR > 1 && $2 > 300 {exit 1}' "$evidence/luajit-runtime.tsv"
awk -F '\t' 'NR > 1 && $2 > 300 {exit 1}' "$evidence/puc51-runtime.tsv"
echo "WP40 CB-1 dual-runtime evidence captured at $evidence"
