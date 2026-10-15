-- Round 49 lane PROT: the deepest place a player can stand inside a town
-- below its placement height (LuaJIT, no engine), the measurement the
-- protection depth is sized from (mapgen-native-plan.md §4.4, ruling 6).
--
--   luajit tools/r49_prot/measure_depth.lua REPO [seed ...]
--
-- Builds each seed's world as the runtime does (tools/r28_zone_atlas/world.lua:
-- roads, capital planning, the zones session with its R7 overlay) and, for
-- each of the twelve hard footprints (six start towns, six capital cities),
-- walks every column of its reserved square that the footprint holds
-- (`hard_protection_kind_at` above the town is "town") and takes:
--   * the final column surface (`column_values_at`: the ground or the bed
--     under water, a functional platform, a step's lower level): a player's
--     feet stand one node above it;
--   * every placed capital plot: its base height plus the lowest open cell
--     (air or water) of its blueprint (a sunken pond);
--   * the start or civic-core composition at its anchor: its lowest open
--     cell.
-- The compositions write only solid ground below their y = 0 except the
-- Highcourt market pond (water down to -3), which the plot term covers.
-- Also the second floor on the depth: a capital's city edge reaches 24
-- below its lowest wall walk or gate floor (r7_capital_blueprint.lua), and
-- r7_settlement.lua refuses an edge below the protected volume.
-- Prints one line per town and the deepest standing place per seed and over
-- all seeds, as nodes below the placement height (feet y), and the deepest
-- city-edge reach.
local repo = assert(arg[1], "usage: measure_depth.lua REPO [seed ...]")
local seeds = {}
for index = 2, #arg do seeds[#seeds + 1] = arg[index] end
if #seeds == 0 then seeds = {"4242424242", "10536739806879207652", "12345"} end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}

-- The lowest open (air or liquid) cell of a blueprint, relative to its
-- origin; 0 when nothing below y = 0 is open.
local function open_floor(bp)
	local lowest = 0
	for _, cell in ipairs(bp.cells) do
		if cell.y < lowest and (cell.name == "air" or cell.name:find("water", 1, true)) then
			lowest = cell.y
		end
	end
	return lowest
end

local capital_blueprint = dofile(wp40 .. "/r7_capital_blueprint.lua")
local settlement = dofile(wp40 .. "/r7_settlement.lua")
-- composition key and open floor of every start and capital, by anchor id
local profile_by_anchor = {}
for _, profile in ipairs(settlement.roster) do
	if profile.slot == "start" or profile.slot == "capital" then
		profile_by_anchor[profile.anchor_id] = profile
	end
end
local plot_open, core_open, start_open = {}, {}, {}
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr",
		"gor_drazhak", "kezamba"}) do
	local kit = capital_blueprint.kit(key)
	core_open[key] = open_floor(kit.core.build())
	plot_open[key] = {}
	for _, plot in ipairs(kit.plots) do plot_open[key][plot.id] = open_floor(plot.build()) end
end
for _, name in ipairs({"dawnmere", "hearthpine", "kapok", "silverleaf",
		"stillgrave", "sunscar"}) do
	local bp = dofile(wp40 .. "/r7_" .. name .. "_blueprint.lua")
	if type(bp) == "function" then bp = bp() end
	start_open[name] = open_floor(bp)
end

local overall = {depth = -math.huge}
local edge_worst = {need = -math.huge}
for _, seed in ipairs(seeds) do
	local t0 = os.clock()
	local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
	local S, P, source = W.session, W.planner_source, W.source
	local seed_worst = {depth = -math.huge}
	for index = 1, 12 do
		local a = source.anchors[index]
		local zone = source.zones[a.zone_numeric_id]
		local placement = S.anchor(zone.id, a.slot_id).y
		local profile = assert(profile_by_anchor[a.id], "profile of " .. a.id)
		local capital = a.slot_id == "capital"
		local half = capital and 266 or 76
		local worst = {depth = -math.huge}
		local function consider(feet, what, x, z)
			local depth = placement - feet
			if depth > worst.depth then
				worst = {depth = depth, what = what, x = x, z = z}
			end
		end
		local columns = 0
		for x = a.position.x - half, a.position.x + half do
			for z = a.position.z - half, a.position.z + half do
				if S.hard_protection_kind_at({x = x, y = 30000, z = z}) == "town" then
					columns = columns + 1
					local _, _, _, _, _, ground, water, _, _, _, functional, _, _, _, _, _,
						lower = P.column_values_at(x, z)
					local top = ground
					if functional and functional < top then top = functional end
					if lower and lower < top then top = lower end
					consider(top + 1, water and water > ground and "bed" or "ground", x, z)
				end
			end
		end
		local key = profile.key
		local edge_note = ""
		if capital then
			consider(placement + core_open[key], "core", a.position.x, a.position.z)
			local entry = assert(W.layouts[a.id], "layout of " .. a.id)
			-- The city edge's lowest reach (r7_capital_blueprint.lua: 24 below
			-- the lowest wall walk or gate floor), which r7_settlement.lua
			-- requires inside the protected volume.
			local layout = entry.layout
			local y_low = math.huge
			for _, w in ipairs(layout.wall.walk) do y_low = math.min(y_low, w / 2) end
			for c = 1, 4 do y_low = math.min(y_low, layout.gates[c].y) end
			local need = placement - (math.floor(y_low) - 24)
			edge_note = (" edge needs %d"):format(need)
			if need > edge_worst.need then
				edge_worst = {need = need, seed = seed, town = key}
			end
			for _, plot in ipairs(entry.layout.plots) do
				local open = assert(plot_open[key][plot.id], "plot " .. plot.id)
				consider(plot.y + open, "plot " .. plot.id, a.position.x + plot.x,
					a.position.z + plot.z)
			end
		else
			consider(placement + start_open[key], "composition", a.position.x, a.position.z)
		end
		print(("seed %s %-8s %-12s placement %4d columns %6d deepest feet %3d below" ..
			" (%s at %d,%d)%s"):format(seed, a.slot_id, key, placement, columns,
			worst.depth, worst.what, worst.x, worst.z, edge_note))
		if worst.depth > seed_worst.depth then
			seed_worst = worst
			seed_worst.town = key
		end
	end
	print(("seed %s deepest %d below placement (%s, %s); %.1f s"):format(seed,
		seed_worst.depth, seed_worst.town, seed_worst.what, os.clock() - t0))
	if seed_worst.depth > overall.depth then
		overall = seed_worst
		overall.seed = seed
	end
end
print(("DEEPEST %d below placement (seed %s, %s, %s at %d,%d)"):format(overall.depth,
	overall.seed, overall.town, overall.what, overall.x, overall.z))
print(("EDGE the city edge reaches %d below placement (seed %s, %s)"):format(
	edge_worst.need, edge_worst.seed, edge_worst.town))
