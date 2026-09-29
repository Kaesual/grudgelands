-- Claim protection (rulings 6, 11, 13, 14, 17, 19). grug_housing wraps
-- core.is_protected after grug_core: world protection (towns, landmarks,
-- roads, the other faction's home territory) is asked first and always wins,
-- so an enemy-faction player stays blocked whatever permission a claim gives.
-- Inside an active claim only the owner and "everything" players dig and
-- place; an empty claim protects nothing (ruling 11). The arrival cube above
-- a standing stone takes no placement from anybody, fuelled or not.

local model = grug_housing.model
local previous_is_protected = core.is_protected

-- A placement target: the engine places into air and buildable_to nodes.
local function open_at(pos)
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "air" then return true end
	local def = core.registered_nodes[node.name]
	return def ~= nil and def.buildable_to == true
end

function core.is_protected(pos, name)
	if previous_is_protected(pos, name) then return true end
	if not model.protects(pos, name, open_at) then return false end
	-- The protection_bypass privilege passes claims as it passes the world.
	return name == "" or
		not core.check_player_privs(name, {protection_bypass = true})
end

-- Ruling 6: liquids never flow into an arrival cube (water_guard.lua asks
-- the world alteration guards for every liquid).
grug_core.register_world_alteration_guard(function(pos)
	return model.arrival_cube_claim(pos) == nil
end)

-- Ruling 14: nothing regrows inside an active claim, nor into an arrival
-- cube; an expired claim renews like any other ground (ruling 19).
grug_core.register_natural_renewal_guard(function(pos)
	local claim = model.claim_at(pos)
	if not claim then return true end
	return not model.is_active(claim) and not model.in_arrival_cube(claim, pos)
end)
