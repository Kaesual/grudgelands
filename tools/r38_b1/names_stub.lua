-- Round 38 lane B1: grug_mobs.names for a fixture that stubs grug_mobs
-- (names_core.lua's query table). Plain Lua 5.1.
--
--   local stub = dofile(ROOT .. "/tools/r38_b1/names_stub.lua")
--   grug_mobs.names = stub.shipped(ROOT)         -- data/names.json
--   grug_mobs.names = stub.of(ROOT, map)         -- {slot key = name}
--   grug_mobs.names = stub.from_regions(ROOT, regions, zones, name_of)
--       every kind, camp and leader slot of `zones` in a fixture's
--       spawn_regions seams, named name_of(role)
local S = {}

local function core_of(root)
	return dofile(root .. "/mods/ENTITIES/grug_mobs/names_core.lua")
end

function S.of(root, map)
	local NC = core_of(root)
	local index, errors = NC.build(map)
	assert(#errors == 0, table.concat(errors, "\n"))
	return NC.api(index)
end

function S.shipped(root)
	local json = dofile(root .. "/tools/r28_b4_quests/json.lua")
	local handle = assert(io.open(root .. "/mods/ENTITIES/grug_mobs/data/names.json", "r"))
	local map = json.decode(handle:read("*a")).names
	handle:close()
	return S.of(root, map)
end

function S.slot_map(regions, zones, name_of, roles)
	local map = {}
	for _, zone in ipairs(zones) do
		for _, id in ipairs(regions.zone_area_ids(zone)) do
			for role, range in pairs(regions.get_area(zone, id).levels_by_role) do
				map[("%s/%s/L%d-%d"):format(zone, role, range[1], range[2])] = name_of(role)
			end
		end
	end
	for _, role in ipairs(roles or {}) do
		local leader = regions.leader(role)
		if leader then
			map[("%s/%s/L%d-%d"):format(leader.zone, role, leader.level, leader.level)] = name_of(role)
		end
	end
	return map
end

function S.from_regions(root, regions, zones, name_of, roles)
	return S.of(root, S.slot_map(regions, zones, name_of, roles))
end

return S
