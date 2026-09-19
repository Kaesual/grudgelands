-- Public MAP-B contract (registered here; mapgen only references these names):
--   grug_farming:soil       dry crop soil
--   grug_farming:soil_wet   hydrated crop soil
-- Crop nodes are runtime content and are not a mapgen placement contract.

grug_farming = {}

local SOIL_DRY = "grug_farming:soil"
local SOIL_WET = "grug_farming:soil_wet"
local SOIL_INTERVAL = 15
local WATER_RADIUS = 3
local STAGES = 4
local STAGE_SECONDS = 200
local HOE_USES = 64

grug_farming.SOIL_DRY = SOIL_DRY
grug_farming.SOIL_WET = SOIL_WET
grug_farming.SOIL_INTERVAL = SOIL_INTERVAL
grug_farming.WATER_RADIUS = WATER_RADIUS
grug_farming.STAGES = STAGES
grug_farming.STAGE_SECONDS = STAGE_SECONDS

local function start_soil_timer(pos)
	core.get_node_timer(pos):start(SOIL_INTERVAL)
end

local function soil_timer(pos)
	local node = core.get_node(pos)
	local wet = core.find_node_near(pos, WATER_RADIUS, {"group:water"}) ~= nil
	local wanted = wet and SOIL_WET or SOIL_DRY
	if node.name ~= wanted then
		core.swap_node(pos, {name = wanted})
		-- A dry interval must never become credited growth merely because water
		-- arrived just before the crop callback. Hydration changes start a fresh
		-- stage interval; genuinely late intervals that stayed wet still catch up.
		local above = {x = pos.x, y = pos.y + 1, z = pos.z}
		local crop_definition = core.registered_nodes[core.get_node(above).name]
		local groups = crop_definition and crop_definition.groups or {}
		if groups.grug_farming_crop == 1 and groups.growing == 1 then
			core.get_node_timer(above):start(STAGE_SECONDS)
		end
	end
	return true
end

local soil_common = {
	drop = "default:dirt",
	is_ground_content = false,
	sounds = default.node_sound_dirt_defaults(),
	on_construct = start_soil_timer,
	on_timer = soil_timer,
}

core.register_node(SOIL_DRY, {
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

core.register_node(SOIL_WET, {
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

-- VoxelManip placement does not call on_construct. This idempotent current-
-- version activation starts missing timers on MAP-B fields; it is not an
-- old-world migration. run_at_every_load is required because one-shot LBMs do
-- not run on mapblocks generated after the LBM introduction timestamp.
core.register_lbm({
	label = "Start crop-soil hydration timer",
	name = "grug_farming:start_soil_timer",
	nodenames = {SOIL_DRY, SOIL_WET},
	run_at_every_load = true,
	action = function(pos)
		local timer = core.get_node_timer(pos)
		if not timer:is_started() then timer:start(SOIL_INTERVAL) end
	end,
})

local crops = {}
local crop_by_node = {}
local crop_keys = {}

local function add_crop(key, description, item, image)
	if crop_keys[key] then
		error("grug_farming: duplicate crop key " .. key, 0)
	end
	local item_definition = core.registered_items[item]
	if not item_definition then
		error("grug_farming: missing harvest item " .. item, 0)
	end
	image = image or item_definition.inventory_image
	if type(image) ~= "string" or image == "" then
		error("grug_farming: harvest item has no inventory image " .. item, 0)
	end
	local row = {
		key = key,
		description = description,
		harvest_item = item,
		seed = "grug_farming:seed_" .. key,
		stages = {},
		stage_count = STAGES,
		stage_seconds = STAGE_SECONDS,
		seed_source = item,
	}
	for stage = 1, STAGES do
		row.stages[stage] = "grug_farming:" .. key .. "_" .. stage
		crop_by_node[row.stages[stage]] = {crop = row, stage = stage}
	end
	crops[#crops + 1] = row
	crop_keys[key] = true
	row.image = image
	return row
end

for index = 1, #grug_cooking.PLANTS do
	local plant = grug_cooking.PLANTS[index]
	add_crop(plant.name, plant.description, plant.item, plant.image)
end

for _, key in ipairs({"potato", "corn"}) do
	local item = "grug_gathering:" .. key
	local definition = assert(core.registered_items[item],
		"grug_farming: missing staple " .. item)
	local description = definition.description:match("^[^\n]+")
	add_crop(key, description, item, definition.inventory_image)
end

local function start_crop_timer(pos)
	core.get_node_timer(pos):start(STAGE_SECONDS)
end

local function crop_timer(pos, elapsed)
	local node = core.get_node(pos)
	local state = crop_by_node[node.name]
	if not state or state.stage >= STAGES then return false end
	local below = {x = pos.x, y = pos.y - 1, z = pos.z}
	if core.get_node(below).name ~= SOIL_WET then return true end
	local advance = math.floor(elapsed / STAGE_SECONDS)
	if advance < 1 then return true end
	local next_stage = math.min(STAGES, state.stage + advance)
	core.swap_node(pos, {name = state.crop.stages[next_stage]})
	return next_stage < STAGES
end

local function place_seed(row)
	return function(itemstack, placer, pointed_thing)
		if not pointed_thing or pointed_thing.type ~= "node" then
			return itemstack
		end
		local under = pointed_thing.under
		local above = pointed_thing.above
		if above.x ~= under.x or above.y ~= under.y + 1 or above.z ~= under.z then
			return itemstack
		end
		local soil_name = core.get_node(under).name
		if soil_name ~= SOIL_DRY and soil_name ~= SOIL_WET then return itemstack end
		local above_name = core.get_node(above).name
		local above_definition = core.registered_nodes[above_name]
		local above_groups = above_definition and above_definition.groups or {}
		if not above_definition or not above_definition.buildable_to or
				above_groups.plant then
			return itemstack
		end
		local player_name = placer and placer:get_player_name() or ""
		if core.is_protected(above, player_name) then
			core.record_protection_violation(above, player_name)
			return itemstack
		end
		soil_timer(under)
		start_soil_timer(under)
		core.set_node(above, {name = row.stages[1]})
		start_crop_timer(above)
		core.sound_play("default_place_node", {pos = above, gain = 0.35}, true)
		if not core.is_creative_enabled(player_name) then itemstack:take_item(1) end
		return itemstack
	end
end

local stage_tints = {140, 95, 45, 0}
for index = 1, #crops do
	local row = crops[index]
	core.register_craftitem(row.seed, {
		description = row.description .. " Seeds",
		inventory_image = row.image .. "^[colorize:#6f542c:90",
		groups = {seed = 1, grug_farming_seed = 1},
		_grug_crop = row.key,
		on_place = place_seed(row),
	})
	core.register_craft({
		type = "shapeless",
		output = row.seed .. " 2",
		recipe = {row.harvest_item},
	})
	for stage = 1, STAGES do
		local mature = stage == STAGES
		local tint = stage_tints[stage]
		local tile = row.image
		if tint > 0 then tile = tile .. "^[colorize:#47713c:" .. tint end
		local drop
		local groups = {snappy = 3, flammable = 2, attached_node = 1, plant = 1,
			grug_farming_crop = 1, not_in_creative_inventory = 1}
		local on_construct, on_timer
		if mature then
			drop = {items = {{items = {row.harvest_item}}, {items = {row.seed}}}}
		else
			drop = row.seed
			groups.growing = 1
			on_construct = start_crop_timer
			on_timer = crop_timer
		end
		core.register_node(row.stages[stage], {
			description = row.description .. " Crop" .. (mature and "" or
				" (Stage " .. stage .. ")"),
			drawtype = "plantlike",
			tiles = {tile},
			inventory_image = tile,
			wield_image = tile,
			visual_scale = 0.55 + stage * 0.15,
			paramtype = "light",
			sunlight_propagates = true,
			walkable = false,
			buildable_to = true,
			is_ground_content = false,
			floodable = true,
			selection_box = {type = "fixed", fixed = {-0.35, -0.5, -0.35,
				0.35, -0.3 + stage * 0.16, 0.35}},
			groups = groups,
			drop = drop,
			sounds = default.node_sound_leaves_defaults(),
			on_construct = on_construct,
			on_timer = on_timer,
			_grug_crop = row.key,
			_grug_crop_stage = stage,
			_grug_crop_harvest = row.harvest_item,
		})
	end
end

grug_farming.CROPS = crops

local tillable = { ["default:dirt"] = true, ["default:dry_dirt"] = true }

local function hoe_on_use(itemstack, user, pointed_thing)
	if not user or not pointed_thing or pointed_thing.type ~= "node" then
		return itemstack
	end
	local under = pointed_thing.under
	local above = pointed_thing.above
	if above.x ~= under.x or above.y ~= under.y + 1 or above.z ~= under.z or
			not tillable[core.get_node(under).name] or
			core.get_node(above).name ~= "air" then
		return itemstack
	end
	local player_name = user:get_player_name()
	if core.is_protected(under, player_name) then
		core.record_protection_violation(under, player_name)
		return itemstack
	end
	core.set_node(under, {name = SOIL_DRY})
	start_soil_timer(under)
	soil_timer(under)
	core.sound_play("default_dig_crumbly", {pos = under, gain = 0.5}, true)
	if not core.is_creative_enabled(player_name) then
		itemstack:add_wear(math.floor(65535 / HOE_USES + 0.5))
	end
	return itemstack
end

core.register_tool("grug_farming:hoe", {
	description = "Farmer's Hoe\nTier 1",
	inventory_image = "default_tool_steelaxe.png^[colorize:#79552f:120",
	groups = {hoe = 1, grug_farming_hoe = 1},
	_grug_tier = 1,
	damage_groups = {fleshy = 1},
	on_use = hoe_on_use,
})

core.register_craft({
	output = "grug_farming:hoe",
	recipe = {
		{"group:wood", "group:wood", ""},
		{"", "default:stick", ""},
		{"", "default:stick", ""},
	},
})

core.register_on_mods_loaded(function()
	if #crops ~= #grug_cooking.PLANTS + 2 then
		error("grug_farming: crop population differs", 0)
	end
	for index = 1, #crops do
		local row = crops[index]
		if not core.registered_items[row.harvest_item] or
				not core.registered_items[row.seed] or #row.stages ~= STAGES then
			error("grug_farming: incomplete crop " .. row.key, 0)
		end
	end
end)
