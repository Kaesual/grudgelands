-- Round 31 lane S: build one PvP POI composition and write it for the
-- preview renderer (LuaJIT, no engine).
--
--   luajit tools/r31_s/dump.lua REPO KIND FACTION RACE TURNS OUT_STEM
--
-- KIND is pvp_fortress / pvp_camp_low / pvp_camp_high, RACE "-" for the
-- fortress. Writes OUT_STEM.cells.tsv (x y z name param2, non-air only) and
-- OUT_STEM.sockets.tsv (id role group/kind x y z dir_x dir_z).
local repo, kind, faction, race, turns, out = unpack(arg)
assert(out, "usage: dump.lua REPO KIND FACTION RACE TURNS OUT_STEM")
_G.core = _G.core or {}
local build = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r31_pvp_poi_blueprint.lua")
local bp = build({}, {blueprint_schema = "grug_r31_preview_v1",
	art = {kind = kind, faction = faction, race = race ~= "-" and race or nil,
		turns = tonumber(turns)}})
local f = assert(io.open(out .. ".cells.tsv", "w"))
for _, c in ipairs(bp.cells) do
	if c.name ~= "air" then
		f:write(table.concat({c.x, c.y, c.z, c.name, c.param2}, "\t"), "\n")
	end
end
f:close()
f = assert(io.open(out .. ".sockets.tsv", "w"))
for _, s in ipairs(bp.landmarks.sockets) do
	f:write(table.concat({s.id, s.role, s.group or s.kind or "-", s.x, s.y, s.z,
		s.dir.x, s.dir.z}, "\t"), "\n")
end
f:close()
print(("%s %s %s: %d cells, bounds %d..%d x %d, %d sockets"):format(kind, faction,
	race, #bp.cells, bp.bounds.min.x, bp.bounds.max.x, bp.bounds.max.y,
	#bp.landmarks.sockets))
