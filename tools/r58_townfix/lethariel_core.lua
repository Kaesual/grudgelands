-- Lethariel's civic core as a blueprint chunk for the town viewer
-- (tools/building_templates/viewer/build_viewer.py, Round 58 TOWNFIX's page):
--   python3 tools/building_templates/viewer/build_viewer.py \
--     tools/r58_townfix/lethariel_core.lua -o OUT.html
-- Plain Lua 5.1, no engine: the WP13 library's composition, as the mapgen
-- builds it.
local info = debug.getinfo(1, "S")
local here = info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
local library = dofile(here .. "/../../mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua")
return library.composition("lethariel").core()
