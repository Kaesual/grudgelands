-- A submerged player may step from the water surface onto a one-node bank.
-- Land keeps player_api's ordinary 0.6 stepheight.

local LAND_STEPHEIGHT = 0.6
local LIQUID_STEPHEIGHT = 1.1
local CHECK_INTERVAL = 0.1
local elapsed = 0
local desired_by_player = {}

function grug_core.liquid_step_for_node(node_def)
	return node_def ~= nil and node_def.liquidtype ~= nil and
		node_def.liquidtype ~= "none"
end

-- Returns true exactly when an engine property write was needed. Reading the
-- live value also repairs a later player-model refresh without resending an
-- already-correct property every pass.
function grug_core.update_liquid_step(player, in_liquid)
	local name = player:get_player_name()
	local desired = in_liquid and LIQUID_STEPHEIGHT or LAND_STEPHEIGHT
	local current = player:get_properties().stepheight or LAND_STEPHEIGHT
	local previous = desired_by_player[name]
	desired_by_player[name] = desired
	if previous == desired and current == desired then
		return false
	end
	if current == desired then
		return false
	end
	player:set_properties({stepheight = desired})
	return true
end

core.register_on_leaveplayer(function(player)
	desired_by_player[player:get_player_name()] = nil
end)

core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < CHECK_INTERVAL then
		return
	end
	elapsed = elapsed % CHECK_INTERVAL
	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if pos then
			local node = core.get_node(pos)
			local def = node and core.registered_nodes[node.name] or nil
			grug_core.update_liquid_step(player,
				grug_core.liquid_step_for_node(def))
		end
	end
end)
