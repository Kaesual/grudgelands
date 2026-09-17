-- Environmental suffocation: one head-node read per eligible player per
-- second. Character-creation stasis is engine-immortal and explicitly exempt.

local CHECK_INTERVAL = 1
local elapsed = 0

function grug_core.should_suffocate(node_def, in_stasis)
	if in_stasis or not node_def then
		return false
	end
	return node_def.walkable == true and
		(node_def.liquidtype == nil or node_def.liquidtype == "none")
end

local function in_creation_stasis(player)
	return grug_core.player_in_creation_stasis and
		grug_core.player_in_creation_stasis(player:get_player_name()) == true
end

local function head_node_def(player)
	local pos = player:get_pos()
	if not pos then
		return nil
	end
	local properties = player:get_properties()
	local head = {
		x = pos.x,
		y = pos.y + (properties.eye_height or 1.47),
		z = pos.z,
	}
	local node = core.get_node(head)
	return node and core.registered_nodes[node.name] or nil
end

core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < CHECK_INTERVAL then
		return
	end
	local damage = math.floor(elapsed / CHECK_INTERVAL)
	elapsed = elapsed - damage * CHECK_INTERVAL
	for _, player in ipairs(core.get_connected_players()) do
		local stasis = in_creation_stasis(player)
		if player:get_hp() > 0 and not stasis and
				grug_core.should_suffocate(head_node_def(player), stasis) then
			player:set_hp(math.max(0, player:get_hp() - damage), {
				type = "set_hp",
				from = "mod",
				custom_type = "grug_core:suffocation",
			})
		end
	end
end)
