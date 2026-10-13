-- Round 47 lane TC: the capitals' city trees of one seed (wp13/city_green.lua
-- through the capital overlay), counted without writing a chunk.
--
--   luajit tools/r47_tc/city_trees.lua REPO SEED
--
-- Builds the seed fleet's runtime (tools/seed_fleet/runtime.lua), takes each
-- capital's prepared overlay and plots from main's runtime, builds the city
-- trees exactly as the R7 settlement successor does (the plot rects, the
-- planner's final columns) and prints per capital the planted city trees and
-- the CPU seconds of deciding them.
local repo, seed = arg[1], arg[2]
assert(repo and seed, "usage: city_trees.lua REPO SEED")
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
local total = 0
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
		local t0 = os.clock()
		local green = city.green({x = anchor.x, z = anchor.z}, rects, column)
		local planted = green.count(anchor.x - 260, anchor.x + 260, anchor.z - 260, anchor.z + 260)
		total = total + planted
		print(("%-12s city trees %4d  (%.2f s CPU)"):format(profile.key, planted, os.clock() - t0))
	end
end
print(("all capitals: %d city trees"):format(total))
