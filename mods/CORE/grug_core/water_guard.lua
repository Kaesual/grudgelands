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

-- Water stays out of fixed guarded ground: the territory rule's towns,
-- capitals, landmarks and open sea, and (Round 81 ruling 3, audit C1-01) the
-- road, bridge, village, camp, fortress, war camp, mining camp and POI cores
-- of the world-protection layer (grug_core.world_feature_at), which
-- grug_core.world_alterable alone does not know. A registered guard (an
-- arrival cube) refuses first, and planned flow passes everywhere else. Each
-- guard is asked once. Returns nil where water may move, "layer" where only
-- the world-protection layer guards (on ground the territory rule leaves
-- alterable), true elsewhere.
local function guard(pos)
	if grug_core.world_alteration_guarded(pos) then return true end
	local layer = false
	if grug_core.natural_ground_alterable(pos) then
		if grug_core.world_feature_at(pos) == nil then return nil end
		layer = true
	end
	for index = 1, #planned_flow do
		if planned_flow[index](pos) == true then return nil end
	end
	return layer and "layer" or true
end

local function guarded(pos)
	return guard(pos) ~= nil
end

-- What a guarded air node that a liquid flowed into becomes again (Round 37,
-- CORE-02). Air itself would loop: air takes no on_flood, so the engine
-- floods it first and the guard reverts afterwards, and the revert re-queues
-- the source beside it, which floods the air again on the next liquid tick
-- (about once a second, each time with a block resend; measured at a
-- capital edge, tools/r37_ix/engine.sh). The barrier looks and acts like
-- air, but it is floodable, so its on_flood (wrapped below like every
-- floodable node's) refuses the flow before anything changes. It is used only
-- where the fixed territory rule guards (towns, capitals, landmarks, the open
-- sea) and on the world-protection layer's roads and cores (Round 81), which
-- never change: a guard that can vanish (a Claim Stone's
-- arrival cube) keeps the plain air revert, so no barrier outlives it in
-- ordinary ground, where code that expects "air" would trip over it.
-- The world writer (grug_mapgen, wp40/r7_content.lua) reads the group
-- grug_air as air: a barrier the guard left in the top or bottom layer of a
-- chunk not generated yet is filled or kept like the flooded air it stands
-- for, never refused as foreign content (Round 41 lane CR, the production
-- mapgen crash).
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
	groups = {not_in_creative_inventory = 1, grug_air = 1},
})

-- The node a guarded transform at `pos` is set back to: what was there,
-- except that air on fixed guarded ground (the territory rule or the
-- world-protection layer) becomes the barrier.
function grug_core.water_guard_revert_node(pos, oldnode)
	if oldnode.name == "air" and (not grug_core.natural_ground_alterable(pos) or
			grug_core.world_feature_at(pos) ~= nil) then
		return {name = BARRIER}
	end
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
		local rule = current and oldnode and
			(water_names[current.name] or water_names[oldnode.name]) and guard(pos)
		-- On the world-protection layer only a flood is set back (the cell was
		-- no water before); a drain or a level change stands. Water that lay
		-- on a road or in a core before Round 81 (a compatible upgrade keeps
		-- it) can drain away there instead of being restored every liquid
		-- tick, and a later flood meets the barrier.
		if rule == true or (rule == "layer" and not water_names[oldnode.name]) then
			-- swap_node preserves metadata and performs ordinary lighting/liquid
			-- updates without construction/destruction callbacks or item drops.
			core.swap_node(pos, grug_core.water_guard_revert_node(pos, oldnode))
		elseif current and oldnode and
				(other_liquids[current.name] or other_liquids[oldnode.name]) and
				grug_core.world_alteration_guarded(pos) then
			core.swap_node(pos, oldnode)
		end
	end
end)
