local INACTIVE = "grug_brewing:brewing_stand"
local ACTIVE = "grug_brewing:brewing_stand_active"
local station_factory = dofile(core.get_modpath("grug_jobs") .. "/station_nodes.lua")
station_factory.register_nodes()

grug_brewing.NODE = INACTIVE
grug_brewing.NODE_ACTIVE = ACTIVE

function grug_brewing.register_public_position(pos)
	station_factory.register_public_position("brewing_stand", pos)
end

local BOXES = {
	{-0.4375, -0.3125, -0.375, 0.4375, -0.1875, 0.375},
	{-0.375, -0.5, -0.3125, -0.25, -0.3125, -0.1875},
	{-0.375, -0.5, 0.1875, -0.25, -0.3125, 0.3125},
	{0.25, -0.5, -0.3125, 0.375, -0.3125, -0.1875},
	{0.25, -0.5, 0.1875, 0.375, -0.3125, 0.3125},
	{-0.3125, -0.375, 0, 0.3125, -0.3125, 0.125},
	{-0.4375, -0.1875, 0.25, -0.3125, 0.5, 0.375},
	{0.3125, -0.1875, 0.25, 0.4375, 0.5, 0.375},
	{-0.3125, 0.125, 0.125, 0.3125, 0.1875, 0.375},
	{-0.1875, 0.1875, 0.125, -0.125, 0.25, 0.3125},
	{-0.25, 0.25, 0.125, -0.0625, 0.375, 0.3125},
	{-0.1875, 0.375, 0.1875, -0.125, 0.4375, 0.25},
	{-0.1875, 0.4375, 0.1875, -0.125, 0.5, 0.25},
	{0.125, 0.1875, 0.125, 0.1875, 0.25, 0.3125},
	{0.0625, 0.25, 0.125, 0.25, 0.375, 0.3125},
	{0.125, 0.375, 0.1875, 0.1875, 0.4375, 0.25},
	{0.125, 0.4375, 0.1875, 0.1875, 0.5, 0.25},
	{-0.125, -0.1875, -0.3125, 0.125, -0.125, -0.0625},
	{-0.0625, -0.125, -0.25, 0.0625, -0.0625, -0.125},
	{-0.0625, -0.0625, -0.25, 0.0625, 0, -0.125},
	{-0.1875, -0.1875, -0.25, -0.125, 0.125, -0.125},
	{0.125, -0.1875, -0.25, 0.1875, 0.125, -0.125},
	{-0.0625, 0.0625, -0.3125, 0.0625, 0.125, -0.0625},
	{-0.125, 0.125, -0.3125, 0.125, 0.3125, -0.0625},
	{-0.0625, 0.3125, -0.25, 0.0625, 0.375, -0.125},
	{-0.0625, 0.375, -0.25, 0.0625, 0.4375, -0.125},
	{0.25, -0.1875, -0.25, 0.375, -0.125, 0},
}

local function register(name, active)
	local groups = {cracky = 2}
	if active then groups.not_in_creative_inventory = 1 end
	local def = {
		description = "Brewing Stand",
		drawtype = "nodebox",
		-- The user's Round 45 pick (tools/r45_a2, brewing_stand B, apothecary
		-- bench): the design's boxes verbatim, its six tiles in node order
		-- (+Y, -Y, +X, -X, +Z, -Z; the front faces -Z). The lit stand looks
		-- the same and glows (light_source).
		node_box = {type = "fixed", fixed = BOXES},
		tiles = {
			"grug_brewing_stand_top.png",
			"grug_brewing_stand_bottom.png",
			"grug_brewing_stand_right.png",
			"grug_brewing_stand_left.png",
			"grug_brewing_stand_back.png",
			"grug_brewing_stand_front.png",
		},
		paramtype = "light", paramtype2 = "facedir", is_ground_content = false,
		groups = groups, sounds = default.node_sound_metal_defaults(), drop = INACTIVE,
		light_source = active and 6 or 0,
		_grug_station = "brewing_stand",
	}
	default.set_inventory_action_loggers(def, "brewing stand")
	core.register_node(name, def)
end

register(INACTIVE, false)
-- The stand the automatic brewing lit before Round 45 (a stable id: worlds
-- hold it). Nothing lights it now; it goes out at its next node timer
-- (grug_jobs/workspaces.lua).
register(ACTIVE, true)
