-- A submerged player may step from the water surface onto a one-node bank.
-- The live land stepheight is restored after leaving liquid.

local LIQUID_STEPHEIGHT = 1.1
local CHECK_INTERVAL = 0.1
local elapsed = 0
local overrides = {}

function grug_core.liquid_step_for_node(node_def)
	return node_def ~= nil and node_def.liquidtype ~= nil and
		node_def.liquidtype ~= "none"
end

-- Returns true exactly when an engine property write was needed. Entry saves
-- the live value once. While active, the live read repairs a model refresh;
-- exit restores the saved value. Land without our override does no work.
function grug_core.update_liquid_step(player, in_liquid)
	local name = player:get_player_name()
	local override = overrides[name]
	if not in_liquid and not override then
		return false
	end
	local current = player:get_properties().stepheight
	if in_liquid then
		if not override then
			override = {saved = current}
			overrides[name] = override
		end
		if current == LIQUID_STEPHEIGHT then
			return false
		end
		player:set_properties({stepheight = LIQUID_STEPHEIGHT})
		return true
	end
	overrides[name] = nil
	if current == override.saved then
		return false
	end
	player:set_properties({stepheight = override.saved})
	return true
end

core.register_on_leaveplayer(function(player)
	overrides[player:get_player_name()] = nil
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
