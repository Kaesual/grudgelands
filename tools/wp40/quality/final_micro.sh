#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
output="${1:?absent absolute output directory required}"
[[ "$output" == /* && ! -e "$output" ]] || exit 2
for command_name in rg sort sha256sum cmp chrt ionice luajit tr; do
	command -v "$command_name" >/dev/null 2>&1 || {
		echo "Final quality micro-KAT: missing $command_name" >&2
		exit 2
	}
done
[[ -x "$repo/tools/bin/lua51" ]] || exit 2
mkdir -p "$output"
# Bind all shipped files and current tools; reference checkouts remain read-only.
(cd "$repo" && {
	rg --files mods tools/wp40 tools/wp43 tools/wp13
	printf '%s\n' game.conf minetest.conf tools/check_fresh_server.py
	printf '%s\n' tools/gen_mob_item_textures.py
	printf '%s\n' reference_projects/luanti/src/client/content_mapblock.cpp
	printf '%s\n' reference_projects/luanti/builtin/game/item.lua
	rg --files docs/design
	# The catalog fixture binds additional design/research and engine references.
	rg -o '"(AGENTS.md|docs/[^"]+|reference_projects/[^"]+)"' \
		tools/wp40/r6/fixtures.lua | tr -d '"'
} | sort -u | rg -v '/__pycache__/|[.]pyc$') >"$output/input-paths.txt"
mapfile -t inputs <"$output/input-paths.txt"
[[ "${#inputs[@]}" -gt 0 ]] || exit 2
for sentinel in game.conf mods/MAPGEN/grug_mapgen/wp40/height.lua \
	mods/ITEMS/grug_materials/content_curation.lua tools/wp40/quality/final_micro.lua; do
	rg -F -x -q "$sentinel" "$output/input-paths.txt"
done
(cd "$repo" && sha256sum "${inputs[@]}") >"$output/inputs.sha256"
sha256sum "$repo/tools/bin/lua51" "$(command -v luajit)" >"$output/interpreters.sha256"
# The portable receipt validator does not construct/authenticate the live
# source projection. Exercise that boundary with real decoded MTS under LuaJIT
# before the compact parity pair; never send the geometry constructor to PUC.
chrt --idle 0 ionice -c3 luajit \
	"$repo/tools/wp40/r7/manifest_constructor_kat.lua" "$repo" \
	>"$output/constructor.tsv" 2>"$output/constructor.log"
# Independent immutable inputs; two of the seven permitted interpreter slots.
chrt --idle 0 ionice -c3 "$repo/tools/bin/lua51" \
	"$repo/tools/wp40/quality/final_micro.lua" "$repo" >"$output/puc.tsv" 2>"$output/puc.log" &
puc_pid=$!
chrt --idle 0 ionice -c3 luajit \
	"$repo/tools/wp40/quality/final_micro.lua" "$repo" >"$output/luajit.tsv" 2>"$output/luajit.log" &
lj_pid=$!
puc_status=0; wait "$puc_pid" || puc_status=$?
lj_status=0; wait "$lj_pid" || lj_status=$?
[[ "$puc_status" -eq 0 && "$lj_status" -eq 0 ]]
cmp "$output/puc.tsv" "$output/luajit.tsv"
(cd "$repo" && sha256sum -c "$output/inputs.sha256") >"$output/inputs-check.txt"
sha256sum "$output/puc.tsv" "$output/luajit.tsv" >"$output/output.sha256"
printf 'Final quality micro-KAT PASS: %s\n' "$output"
