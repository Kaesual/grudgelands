-- Engine callbacks own scheduling. No retry queue, cache, map loading or timer.
-- See pinned luanti/doc/lua_api.md on_flood and on_liquid_transformed; air
-- bypasses on_flood in src/servermap.cpp, so both boundaries are required,
-- and reverted air becomes the barrier below so the second fires only once.
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
	-- A registered guard (an arrival cube) wins over planned flow.
	if grug_core.world_alteration_guarded(pos) then return true end
	for index = 1, #planned_flow do
		if planned_flow[index](pos) == true then return false end
	end
	return true
end

-- What a guarded air node that a liquid flowed into becomes again (Round 37,
-- CORE-02). Air itself would loop: air takes no on_flood, so the engine
-- floods it first and the guard reverts afterwards, and the revert re-queues
-- the source beside it, which floods the air again on the next liquid tick
-- (about once a second, each time with a block resend; measured at a
-- capital edge, tools/r37_ix/engine.sh). The barrier looks and acts like
-- air, but it is floodable, so its on_flood (wrapped below like every
-- floodable node's) refuses the flow before anything changes; once the guard
-- no longer applies there, a liquid floods it like air.
local BARRIER = "grug_core:water_barrier"
grug_core.WATER_BARRIER = BARRIER
core.register_node(BARRIER, {
	description = "Water Barrier",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	drop = "",
	groups = {not_in_creative_inventory = 1},
})

-- The node a guarded transform at a position is set back to: what was there,
-- except that air becomes the barrier.
function grug_core.water_guard_revert_node(oldnode)
	if oldnode.name == "air" then return {name = BARRIER} end
	return oldnode
end

-- Every other liquid (lava) flows freely except where a world alteration
-- guard refuses the position (a Claim Stone's arrival cube, Round 25 ruling
-- 6); the territory rule stays a water-only rule. Filled at mods loaded.
local other_liquids = {}

local function wrap_flood(original)
	return function(pos, oldnode, newnode)
		if water_names[newnode.name] and guarded(pos) then
			return true
		end
		if other_liquids[newnode.name] and grug_core.world_alteration_guarded(pos) then
			return true
		end
		if original then return original(pos, oldnode, newnode) end
	end
end

core.register_on_mods_loaded(function()
	for name, definition in pairs(core.registered_nodes) do
		if not water_names[name] and definition.liquidtype and
				definition.liquidtype ~= "none" then
			other_liquids[name] = true
		end
	end
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
			core.swap_node(pos, grug_core.water_guard_revert_node(oldnode))
		elseif current and oldnode and
				(other_liquids[current.name] or other_liquids[oldnode.name]) and
				grug_core.world_alteration_guarded(pos) then
			core.swap_node(pos, grug_core.water_guard_revert_node(oldnode))
		end
	end
end)
