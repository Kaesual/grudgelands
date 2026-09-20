-- Sole soil registrations, available before synchronous mapgen compilation.
-- FARM installs the actual runtime functions before engine callbacks can run.
return function(core, default)
 local callbacks
local soil_common = {
	drop = "default:dirt",
	is_ground_content = false,
	sounds = default.node_sound_dirt_defaults(),
	on_construct = function(pos)
  return assert(callbacks, "crop soil runtime is not bound").on_construct(pos)
 end,
	on_timer = function(pos, elapsed)
  return assert(callbacks, "crop soil runtime is not bound").on_timer(pos, elapsed)
 end,
}

core.register_node(":grug_farming:soil", {
	description = "Crop Soil",
	tiles = {
		"default_dirt.png^[colorize:#5b3a20:60",
		"default_dirt.png",
		"default_dirt.png^[colorize:#4a311f:30",
	},
	drop = soil_common.drop,
	groups = {crumbly = 3, soil = 2, field = 1, grug_crop_soil = 1},
	is_ground_content = soil_common.is_ground_content,
	sounds = soil_common.sounds,
	on_construct = soil_common.on_construct,
	on_timer = soil_common.on_timer,
})

core.register_node(":grug_farming:soil_wet", {
	description = "Wet Crop Soil",
	tiles = {
		"default_dirt.png^[colorize:#24180f:105",
		"default_dirt.png",
		"default_dirt.png^[colorize:#24180f:65",
	},
	drop = soil_common.drop,
	groups = {crumbly = 3, soil = 3, field = 1, grug_crop_soil = 1,
		grug_crop_soil_wet = 1, not_in_creative_inventory = 1},
	is_ground_content = soil_common.is_ground_content,
	sounds = soil_common.sounds,
	on_construct = soil_common.on_construct,
	on_timer = soil_common.on_timer,
})

 return function(value)
  assert(callbacks == nil, "crop soil runtime already bound")
  assert(type(value) == "table" and type(value.on_construct) == "function" and
   type(value.on_timer) == "function", "invalid crop soil runtime")
  callbacks = value
 end
end
