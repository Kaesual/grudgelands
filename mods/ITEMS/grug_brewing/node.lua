local INACTIVE = "grug_brewing:brewing_stand"
local ACTIVE = "grug_brewing:brewing_stand_active"
local recipes = {}
local station_factory = dofile(core.get_modpath("grug_jobs") .. "/station_nodes.lua")
station_factory.register_nodes()

grug_brewing.NODE = INACTIVE
grug_brewing.NODE_ACTIVE = ACTIVE

function grug_brewing.register_public_position(pos)
	station_factory.register_public_position("brewing_stand", pos)
end

function grug_brewing.register_recipe(recipe)
	if type(recipe) ~= "table" or recipe.station ~= "brewing_stand" or
			#recipe.flat_inputs ~= 1 then
		error("grug_brewing: finishing needs one prepared mixture", 0)
	end
	local mixture = recipe.flat_inputs[1]
	if recipes[mixture] then error("grug_brewing: duplicate mixture", 0) end
	recipes[mixture] = {output = recipe.output, output_name = recipe.output_name,
		time = tonumber(recipe.time) or 5}
end

function grug_brewing.match(mixture)
	return recipes[mixture]
end

local function register(name, active)
	local groups = {cracky = 2}
	if active then groups.not_in_creative_inventory = 1 end
	local def = {
		description = "Brewing Stand",
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = {
			{-0.5, -0.5, -0.4375, 0.5, -0.375, -0.3125},
			{-0.1875, -0.5, -0.3125, 0.1875, -0.375, 0.5},
			{-0.0625, -0.375, -0.0625, 0.0625, 0.5, 0.0625},
		}},
		tiles = {
			"grug_brewing_top.png",
			"grug_brewing_base.png",
			"grug_brewing_side.png",
			"grug_brewing_side.png",
			"grug_brewing_side.png",
			"grug_brewing_side.png^[transformFX",
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
register(ACTIVE, true)
