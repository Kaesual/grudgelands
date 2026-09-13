#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo"
command -v rg >/dev/null
mapfile -t files < <(rg --files tools/wp40/tree_slices tools/wp40/resource_rank \
	tools/wp40/profile | rg '[.]lua$' | sort)
files+=(mods/MAPGEN/grug_mapgen/wp40/r6_hash.lua \
	mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua)
tools/bin/luac51 -p "${files[@]}"
for file in "${files[@]}"; do
	hits="$(tools/bin/luac51 -l -p -o /dev/null "$file" | rg SETGLOBAL || true)"
	if [[ "$file" == tools/wp40/profile/probe/init.lua ]]; then
		[[ "$(printf '%s\n' "$hits" | wc -l)" -eq 1 && \
			"$hits" == *'grug_wp40_profile_probe'* ]]
	else
		[[ -z "$hits" ]] || { printf '%s\n' "$file: $hits" >&2; exit 1; }
	fi
done
patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for index in "${!patterns[@]}"; do
	status=0
	hits="$(rg -n "${patterns[$index]}" "${files[@]}")" || status=$?
	[[ "$status" -le 1 ]]
	if [[ -n "$hits" ]]; then
		# Literal trace separators are data, and parser above checks syntax.
		if [[ "$index" -eq 3 ]]; then
			unexpected="$(printf '%s\n' "$hits" | rg -v \
				'^tools/wp40/resource_rank/fixture[.]lua:[0-9]+:.*"\|"' || true)"
			[[ -z "$unexpected" ]] || { printf '%s\n' "$unexpected"; exit 1; }
		else printf '%s\n' "$hits"; exit 1
		fi
	fi
done
bash -n tools/wp40/{profile,resource_rank,tree_slices}/*.sh
git diff --check
printf 'Changed Lua parser, SETGLOBAL and five sweeps PASS (%s files)\n' "${#files[@]}"
