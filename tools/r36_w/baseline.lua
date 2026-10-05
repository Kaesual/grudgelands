-- Round 36 lane W: the footprint and socket record of every composition the
-- decor pass touches (LuaJIT, no engine): the Round 14 and Round 20 POIs of
-- the settlement roster (the dragon arenas and the PvP POIs aside), the six
-- starts, every capital core and district plot. One line per composition:
-- its bounds, its cleared airspace and its sockets (id, role, position,
-- facing). The decor pass may change cells, never these.
--
--   luajit tools/r36_w/baseline.lua REPO > tools/r36_w/baseline.tsv
--
-- (written once from main before the decor pass; portable_test.lua compares
-- the current tree's record with that file). As a module:
-- `dofile(path)(repo)` returns the lines.
local function record(repo)
	_G.core = _G.core or {}
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local lines = {}
	local function line(label, bp)
		local b = bp.bounds
		local parts = {label, b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z,
			tostring(bp.clear_to or "-")}
		local sockets = {}
		for _, s in ipairs(bp.landmarks.sockets or {}) do
			local dir = s.dir or {x = 0, z = 0}
			sockets[#sockets + 1] = table.concat({s.id, s.role, s.x, s.y, s.z, dir.x, dir.z}, ",")
		end
		table.sort(sockets)
		parts[#parts + 1] = table.concat(sockets, ";")
		lines[#lines + 1] = table.concat(parts, "\t")
	end
	local settlement = dofile(wp40 .. "/r7_settlement.lua")
	for _, profile in ipairs(settlement.roster) do
		local file = profile.blueprint_file
		local r20 = file == "r20_poi_blueprint.lua" and profile.art.kind ~= "dragon"
		local r14 = file:match("^r7_.*_blueprint%.lua$") and profile.slot ~= "capital" and
			profile.slot ~= "start"
		if r20 or r14 then
			local bp = dofile(wp40 .. "/" .. file)({}, profile)
			if type(bp) == "function" then bp = bp({}) end
			line(profile.key, bp)
		end
	end
	for _, name in ipairs({"dawnmere", "hearthpine", "kapok", "silverleaf", "stillgrave", "sunscar"}) do
		local bp = dofile(wp40 .. "/r7_" .. name .. "_blueprint.lua")
		if type(bp) == "function" then bp = bp() end
		line(name, bp)
	end
	local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
	for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}) do
		local kit = capital.kit(key)
		line(key .. "/core", kit.core.build())
		for _, plot in ipairs(kit.plots) do line(key .. "/" .. plot.id, plot.build()) end
	end
	return lines
end

if arg and arg[0] and arg[0]:match("baseline%.lua$") and arg[1] then
	for _, l in ipairs(record(arg[1])) do print(l) end
end
return record
