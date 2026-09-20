-- Engine callbacks own scheduling. No retry queue, cache, map loading or timer.
-- See pinned luanti/doc/lua_api.md on_flood and on_liquid_transformed; air
-- bypasses on_flood in src/servermap.cpp, so both boundaries are required.
local water_names = {
	["default:water_source"] = true,
	["default:water_flowing"] = true,
	["default:river_water_source"] = true,
	["default:river_water_flowing"] = true,
}

local function wrap_flood(original)
	return function(pos, oldnode, newnode)
		if water_names[newnode.name] and not grug_core.world_alterable(pos) then
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
				not grug_core.world_alterable(pos) then
			-- swap_node preserves metadata and performs ordinary lighting/liquid
			-- updates without construction/destruction callbacks or item drops.
			core.swap_node(pos, oldnode)
		end
	end
end)
