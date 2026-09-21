#!/usr/bin/env bash
set -euo pipefail
repo=${1:-.}
out=${2:-$repo/tools/r14_poi/gallery}
mkdir -p "$out"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
# Read the actual display registrations, preserving their shipped textures.
luajit - "$repo" > "$scratch/displays.tsv" <<'LUA'
dofile(arg[1].."/mods/MAPGEN/grug_mapgen/poi_displays.lua")({
 register_node=function(name,def) io.write(name,"\t",def.tiles[1],"\n") end})
LUA
python3 - "$repo" "$scratch" <<'PYTHON'
import json, pathlib, sys
repo, scratch = map(pathlib.Path, sys.argv[1:])
data = json.loads((repo / "tools/wp13/node_tiles.json").read_text())
for line in (scratch / "displays.tsv").read_text().splitlines():
    name, texture = line.split("\t")
    data["nodes"][name] = {"tiles": [texture], "drawtype": "normal"}
(scratch / "tiles.json").write_text(json.dumps(data))
PYTHON
for name in copperfell_village goldmead_outpost starbough_bandit_camp \
	mournfen_village redtusk_outpost raincall_bandit_camp; do
	python3 "$repo/tools/wp13/render_blueprint.py" \
		"$repo/mods/MAPGEN/grug_mapgen/wp40/r7_${name}_blueprint.lua" \
		--tiles "$scratch/tiles.json" --view ne --max-pixels 1800 --quiet -o "$out/${name}.png"
done

