-- Engine callbacks own scheduling. No retry queue, cache, map loading or timer.
-- See pinned luanti/doc/lua_api.md on_flood and on_liquid_transformed; air
-- bypasses on_flood in src/servermap.cpp, so both boundaries are required.
local water_names = {
	["default:water_source"] = true,
	["default:water_flowing"] = true,
	["default:river_water_source"] = true,
	["default:river_water_flowing"] = true,
}

-- The world's own planned water may move where the guard otherwise stops all
-- water: the flow at a step between two planned water surfaces (a canal's or
-- a river's rapid inside a protected capital) is part of the generated world,
-- not an alteration. The owner of the water layout (grug_mapgen) registers a
-- predicate pos -> true for exactly those positions; anything else stays
-- guarded.
local planned_flow = {}

function grug_core.register_planned_water_flow(predicate)
	assert(type(predicate) == "function", "planned water flow must be a function")
	planned_flow[#planned_flow + 1] = predicate
end

local function guarded(pos)
	if grug_core.world_alterable(pos) then return false end
	for index = 1, #planned_flow do
		if planned_flow[index](pos) == true then return false end
	end
	return true
end

local function wrap_flood(original)
	return function(pos, oldnode, newnode)
		if water_names[newnode.name] and guarded(pos) then
			return true
		end
		if original then return original(pos, oldnode, newnode) end
	end
end

core.register_on_mods_loaded(function()
	for name, definition in pairs(core.registered_nodes) do
		if definition.floodable and name ~= "air" then
			core.override_item(name, {on_flood = wrap_flood(definition.on_flood)})
		end
	end
end)

core.register_on_liquid_transformed(function(positions, old_nodes)
	for index = 1, #positions do
		local pos, oldnode = positions[index], old_nodes[index]
		local current = core.get_node_or_nil(pos)
		if current and oldnode and
				(water_names[current.name] or water_names[oldnode.name]) and
				guarded(pos) then
			-- swap_node preserves metadata and performs ordinary lighting/liquid
			-- updates without construction/destruction callbacks or item drops.
			core.swap_node(pos, oldnode)
		end
	end
end)
