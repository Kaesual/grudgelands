-- The civic core of dur_brannoc for the town viewer (Round 58 lane HALLS):
--   python3 tools/building_templates/viewer/build_viewer.py tools/r58_halls/view/dur_brannoc_core_blueprint.lua -o out.html
local info = debug.getinfo(1, "S")
local here = info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
local library = dofile(here .. "/../../../mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua")
return library.composition("dur_brannoc").core()
