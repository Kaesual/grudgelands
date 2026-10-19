-- Round 51 follow-up FT: the capitals' city ground cover and lake plants of
-- one seed (wp13/city_green.lua `cover`), counted without writing a chunk.
--
--   luajit tools/r51_ft/city_cover.lua REPO SEED
--
-- Builds the seed fleet's runtime, takes each capital's overlay and plots
-- as tools/r47_tc/city_trees.lua does, walks the city's square in 80 x 80
-- mapchunk boxes exactly as the R7 settlement successor does (the trees
-- first, then the cover on the cells they leave) and prints per capital the
-- cover plants, the bones among them, the lily pads and waterweeds, the open
-- columns they stand on and the CPU seconds of the trees and of the cover.
-- Numbers are comparisons, never targets.
local repo, seed = arg[1], arg[2]
assert(repo and seed, "usage: city_cover.lua REPO SEED")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local native = dofile(wp40 .. "/r7_native.lua")
local authority = R.main.build_authority(native.identities())
local ps = authority.planner_source
local function upvalue(fn, wanted)
	for index = 1, 255 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("upvalue " .. wanted .. " not found")
end
local settlements = upvalue(R.main.settlement_sockets, "settlements")
local function column(x, z)
	local _, _, _, _, _, terrain_y, water_y = ps.column_values_at(x, z)
	local road = ps.road_column_at and ps.road_column_at(x, z) == "surface" or false
	if type(water_y) ~= "number" or water_y <= terrain_y then water_y = nil end
	return terrain_y, water_y, road
end
local BONES = {}
for _, name in ipairs({"grug_nodes:bone_pile", "grug_nodes:skull_human", "grug_nodes:ribcage_human",
		"grug_nodes:skull_horned", "grug_nodes:spine_animal", "grug_nodes:bones_fragments"}) do
	BONES[name] = true
end
local HALF = 260
for _, row in ipairs(settlements) do
	local profile, prepared = row.profile, row.prepared
	if profile.slot == "capital" then
		local anchor = authority.zones_session.anchor(profile.zone_id, profile.slot)
		local rects, city = {}, nil
		for _, b in ipairs(prepared.blueprints) do
			if b.descriptor.kind == "reference" then
				local rect = settlement.plot_rect(b, anchor.x, anchor.z)
				rect.turns = b.descriptor.turns or 0
				rects[#rects + 1] = rect
			elseif b.descriptor.kind == "overlay" then
				city = b.city
			end
		end
		local green = city.green({x = anchor.x, z = anchor.z}, rects, column)
		local t_trees, t_cover = 0, 0
		local plants, bones, lilies, weeds = 0, 0, 0, 0
		local x0 = math.floor((anchor.x - HALF + 32) / 80) * 80 - 32
		local z0 = math.floor((anchor.z - HALF + 32) / 80) * 80 - 32
		for bz = z0, anchor.z + HALF, 80 do
			for bx = x0, anchor.x + HALF, 80 do
				local box = {min_x = bx, max_x = bx + 79, min_z = bz, max_z = bz + 79}
				local t0 = os.clock()
				local cells = green.cells(box)
				local t1 = os.clock()
				local taken = {}
				for _, c in ipairs(cells) do taken[c.x .. ":" .. c.y .. ":" .. c.z] = true end
				local cover = green.cover and green.cover(box, taken) or {}
				t_trees, t_cover = t_trees + (t1 - t0), t_cover + (os.clock() - t1)
				for _, c in ipairs(cover) do
					if c.name == "grug_mapgen:freshwater_waterlily" then lilies = lilies + 1
					elseif c.name == "grug_mapgen:freshwater_waterweed" then weeds = weeds + 1
					else
						plants = plants + 1
						if BONES[c.name] then bones = bones + 1 end
					end
				end
			end
		end
		print(("%-12s cover %5d (bones %4d)  lilies %4d  weeds %4d  trees %.2f s  cover %.2f s CPU"):format(
			profile.key, plants, bones, lilies, weeds, t_trees, t_cover))
	end
end
