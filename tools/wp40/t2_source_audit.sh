#!/usr/bin/env bash
set -euo pipefail

repo=${1:-.}
cd "$repo"

scratch=$(mktemp -d /tmp/grudgelands-wp40-t2.XXXXXX)
trap 'rm -rf "$scratch"' EXIT

mapfile -t lua_files < <(find mods/MAPGEN/grug_mapgen/wp40/source \
	mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua \
	tools/wp40/t2_source_test.lua -type f -name '*.lua' -print | sort)

tools/bin/luac51 -p "${lua_files[@]}"

stage1=mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua
catalog=mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua
test_file=tools/wp40/t2_source_test.lua
grep -q '^function validator.validate(source,vocabulary)$' "$stage1"
grep -q 'engine_core.get_modpath("grug_mapgen")' "$stage1"
grep -q 'production_canonical=dofile(production_modpath.."/wp40/canonical.lua")' "$stage1"
grep -q 'return engine_sha256(data,true)' "$stage1"
grep -q '^local function canonicalize_source(source,canonical)$' "$stage1"
grep -q 'pcall(canonicalize_source,source,canonical)' "$stage1"
grep -q '^if engine_core==nil then$' "$stage1"
[[ $(grep -c '^source\.critical_source_manifest = {' "$catalog") -eq 1 ]]
grep -q '"critical_source_manifest", "constants"' "$catalog"
grep -q '^local function validate_critical_manifest(manifest)$' "$stage1"
grep -q 'validate_critical_manifest(source\.critical_source_manifest)' "$stage1"
grep -q 'changed_manifest_checksum~=checksum_a' "$test_file"
grep -q $'^\tmg_name = "v7",$' "$catalog"
grep -q $'^\twater_level = 1,$' "$catalog"
grep -q $'^\tchunksize = 5,$' "$catalog"
grep -q $'^\tnum_emerge_threads = 1,$' "$catalog"
grep -q $'^\tmgv7_dungeon_ymin = -31000,$' "$catalog"
grep -q $'^\tmgv7_dungeon_ymax = -193,$' "$catalog"
grep -q $'^\tbroad_content_y_min = -37,$' "$catalog"
if grep -q 'nofloatlands' "$catalog"; then
	echo 'T2 source audit: incidental special-flag serialization in source' >&2
	exit 1
fi
if grep -q 'force_native_dungeon = true' "$catalog"; then
	echo 'T2 source audit: positive native-dungeon force authority in source' >&2
	exit 1
fi
if grep -nE '^function validator\.validate\([^)]*(canonical|sha|digest|project)' "$stage1"; then
	echo 'T2 source audit: production validate exposes a forgeable trust input' >&2
	exit 1
fi
if grep -RFn 'new_offline_test_adapter' mods/MAPGEN/grug_mapgen/wp40/source; then
	echo 'T2 source audit: offline adapter referenced by production source' >&2
	exit 1
fi

mapfile -t production_files < <(find mods/MAPGEN/grug_mapgen/wp40/source \
	mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua \
	-type f -name '*.lua' -print | sort)

if tools/bin/luac51 -l -p "${production_files[@]}" | grep -q 'SETGLOBAL'; then
	echo 'T2 source audit: forbidden SETGLOBAL found' >&2
	exit 1
fi

production_paths=(mods/MAPGEN/grug_mapgen/wp40/source \
	mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua)

# The five exact plain-Lua-5.1 sweeps from docs/research/luanti-lua.md.
patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for pattern in "${patterns[@]}"; do
	hits=$(grep -rnE "$pattern" "${production_paths[@]}" --include='*.lua' || true)
	if [[ -n "$hits" ]]; then
		printf '%s\n' "$hits"
		echo 'T2 source audit: forbidden production Lua construct found' >&2
		exit 1
	fi
done

# Offline harness exception: os.execute is used only to invoke sha256sum for
# an independent digest, as in T1. All other sweeps remain exact on the test.
for pattern_index in 0 1 2 3; do
	hits=$(grep -nE "${patterns[$pattern_index]}" tools/wp40/t2_source_test.lua || true)
	if [[ -n "$hits" ]]; then
		printf '%s\n' "$hits"
		echo 'T2 source audit: forbidden offline Lua construct found' >&2
		exit 1
	fi
done

tools/bin/lua51 tools/wp40/t2_source_test.lua "$repo" "$scratch"

bash -n tools/wp40/t2_source_audit.sh

echo 'WP40 T2 source audit passed'
