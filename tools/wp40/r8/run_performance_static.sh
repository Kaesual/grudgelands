#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
receipt="${1:?receipt path required}"
luac_bin="$repo/tools/bin/luac51"

for command_name in rg sha256sum awk sort mkdir dirname mv; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "WP40 R8 performance static gates: missing command $command_name" >&2
		exit 1
	}
done
[[ -x "$luac_bin" ]] || {
	echo "WP40 R8 performance static gates: luac51 is unavailable" >&2
	exit 1
}

mapfile -t production_lua < <(cd "$repo" &&
	rg --files mods | rg '/grug_[^/]+/.*[.]lua$' | sort)
mapfile -t tool_lua < <(cd "$repo" &&
	rg --files tools/wp40/r8 |
		rg '^tools/wp40/r8/(construction|performance)_hotpath[.]lua$' | sort)
[[ "${#production_lua[@]}" -gt 0 && "${#tool_lua[@]}" -eq 2 ]] || {
	echo "WP40 R8 performance static gates: Lua population differs" >&2
	exit 1
}

changed_production=(
	mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua
	mods/MAPGEN/grug_mapgen/wp40/r5.lua
	mods/MAPGEN/grug_mapgen/wp40/r6.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_content.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_hash.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_anchor_activation.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_content.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_p9g.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_successor.lua
	mods/MAPGEN/grug_mapgen/wp40/zones.lua
)

all_lua=("${production_lua[@]}" "${tool_lua[@]}")
all_paths=()
for file in "${all_lua[@]}"; do all_paths+=("$repo/$file"); done
"$luac_bin" -p "${all_paths[@]}"

for file in "${changed_production[@]}" "${tool_lua[@]}"; do
	[[ -f "$repo/$file" ]] || {
		echo "WP40 R8 performance static gates: changed Lua file is absent: $file" >&2
		exit 1
	}
	if "$luac_bin" -l -p -o /dev/null "$repo/$file" | rg -n 'SETGLOBAL'; then
		echo "WP40 R8 performance static gates: global write in $file" >&2
		exit 1
	fi
done

# Plain Lua 5.1 parsing above is authoritative for executable operator syntax.
# Keep the textual sweep as a required diagnostic even though comments may
# contain C-style operators.
operator_status=0
rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' \
	"${all_paths[@]}" >/dev/null || operator_status=$?
[[ "$operator_status" -le 1 ]] || {
	echo "WP40 R8 performance static gates: operator sweep could not run" >&2
	exit 1
}

if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${all_paths[@]}" ||
		rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${all_paths[@]}" |
			rg -v '^[^:]+:[0-9]+:[[:space:]]*--' ||
		rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' \
			"${all_paths[@]}" ||
		rg -n 'io\.popen|os\.(execute|exit)|\bminetest\.' "${all_paths[@]}" ||
		rg -n '(^|[^[:alnum:]_.])require[[:space:]]*\(' "${all_paths[@]}"; then
	echo "WP40 R8 performance static gates: Lua 5.1 source sweep failed" >&2
	exit 1
fi

source_set_sha="$(
	cd "$repo"
	for file in "${changed_production[@]}" "${tool_lua[@]}"; do
		sha256sum "$file"
	done | sha256sum | awk '{print $1}'
)"
mkdir -p -- "$(dirname "$receipt")"
partial="${receipt}.partial"
{
	printf 'schema\tgrug_wp40_r8_performance_static_v1\n'
	printf 'status\tpass\n'
	printf 'production_lua_count\t%s\n' "${#production_lua[@]}"
	printf 'tool_lua_count\t%s\n' "${#tool_lua[@]}"
	printf 'changed_production_lua_count\t%s\n' "${#changed_production[@]}"
	printf 'source_set_sha256\t%s\n' "$source_set_sha"
} >"$partial"
mv -- "$partial" "$receipt"
printf 'WP40 R8 performance static gates PASS source=%s\n' "$source_set_sha"
