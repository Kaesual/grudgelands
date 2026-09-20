-- Dual-furnace node definitions. Jobs owns shared/personal inventories and
-- the common elapsed-server-time process evaluator (automatic.lua).
local INACTIVE = "grug_smelting:dual_furnace"
local ACTIVE = "grug_smelting:dual_furnace_active"
grug_smelting.NODE = INACTIVE
grug_smelting.NODE_ACTIVE = ACTIVE

local function register(name, active)
	local groups = {cracky = 2}
	local front = "grug_smelting_dual_furnace_front.png"
	if active then
		groups.not_in_creative_inventory = 1
		front = {
			name = "grug_smelting_dual_furnace_front_active.png",
			backface_culling = false,
			animation = {type = "vertical_frames", aspect_w = 16,
				aspect_h = 16, length = 1.5},
		}
	end
	local def = {
		description = "Dual Furnace",
		tiles = {
			"default_furnace_top.png", "default_furnace_bottom.png",
			"default_furnace_side.png", "default_furnace_side.png",
			"default_furnace_side.png", front,
		},
		paramtype2 = "facedir",
		groups = groups,
		is_ground_content = false,
		sounds = default.node_sound_stone_defaults(),
		drop = INACTIVE,
		_grug_station = "dual_furnace",
		light_source = active and 8 or 0,
	}

	default.set_inventory_action_loggers(def, "dual furnace")
	core.register_node(name, def)
end

register(INACTIVE, false)
register(ACTIVE, true)
