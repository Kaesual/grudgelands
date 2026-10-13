-- Round 47 lane TC: town trees per composition (LuaJIT, no engine).
--
--   luajit tools/r47_tc/town_trees.lua REPO [all]
--
-- Builds every composition tools/r36_w/baseline.lua records (the POIs, the
-- six starts, every capital core and plot) and counts the trees the wp13
-- dressing tree routines plant in it (`tree`, `broadleaf`, `columnar`,
-- `acacia`, `gravewood`, `jungle_tree`, `emergent`): a routine that returns
-- false planted nothing; one that returns nothing (the routines before
-- Round 47) planted its tree. Prints one line per composition with trees
-- (`all`: every composition) and the totals per town, so two trees can be
-- compared (run it on each).
local repo = assert(arg[1], "usage: town_trees.lua REPO [all]")
local show_all = arg[2] == "all"
_G.core = _G.core or {}
local ROUTINES = {"tree", "broadleaf", "columnar", "acacia", "gravewood", "jungle_tree",
	"emergent"}
local counts = {calls = 0, planted = 0}
local real_dofile = dofile
rawset(_G, "dofile", function(path, ...)
	local result = real_dofile(path, ...)
	if type(path) == "string" and path:match("wp13/dressing%.lua$") and
			type(result) == "function" then
		local loader = result
		return function(...)
			local M = loader(...)
			for _, name in ipairs(ROUTINES) do
				local routine = M[name]
				M[name] = function(...)
					counts.calls = counts.calls + 1
					local planted = routine(...)
					if planted ~= false then counts.planted = counts.planted + 1 end
					return planted
				end
			end
			return M
		end
	end
	return result
end)

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local rows, towns = {}, {}
local function measure(label, build)
	counts.calls, counts.planted = 0, 0
	build()
	rows[#rows + 1] = {label, counts.calls, counts.planted}
	local town = label:match("^([^/]+)/") or label
	towns[town] = towns[town] or {0, 0}
	towns[town][1] = towns[town][1] + counts.calls
	towns[town][2] = towns[town][2] + counts.planted
end
local settlement = real_dofile(wp40 .. "/r7_settlement.lua")
for _, profile in ipairs(settlement.roster) do
	local file = profile.blueprint_file
	local r20 = file == "r20_poi_blueprint.lua" and profile.art.kind ~= "dragon"
	local r14 = file:match("^r7_.*_blueprint%.lua$") and profile.slot ~= "capital" and
		profile.slot ~= "start"
	if r20 or r14 then
		measure(profile.key, function()
			local bp = dofile(wp40 .. "/" .. file)({}, profile)
			if type(bp) == "function" then bp({}) end
		end)
	end
end
for _, name in ipairs({"dawnmere", "hearthpine", "kapok", "silverleaf", "stillgrave", "sunscar"}) do
	measure(name, function()
		local bp = dofile(wp40 .. "/r7_" .. name .. "_blueprint.lua")
		if type(bp) == "function" then bp() end
	end)
end
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}) do
	local kit = capital.kit(key)
	measure(key .. "/core", function() kit.core.build() end)
	for _, plot in ipairs(kit.plots) do
		measure(key .. "/" .. plot.id, function() plot.build() end)
	end
end
local total = {0, 0}
for _, row in ipairs(rows) do
	if show_all or row[2] > 0 then
		print(("%-40s spots %3d planted %3d"):format(row[1], row[2], row[3]))
	end
end
local names = {}
for name in pairs(towns) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
	local t = towns[name]
	total[1], total[2] = total[1] + t[1], total[2] + t[2]
	if t[1] > 0 then print(("town %-28s spots %3d planted %3d"):format(name, t[1], t[2])) end
end
print(("all spots %d planted %d"):format(total[1], total[2]))
