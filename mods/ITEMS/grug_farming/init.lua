-- Public MAP-B contract (registered here; mapgen only references these names):
--   grug_farming:soil       dry crop soil
--   grug_farming:soil_wet   hydrated crop soil
-- Crop nodes are runtime content and are not a mapgen placement contract.

grug_farming = {}

dofile(core.get_modpath(core.get_current_modname()) .. "/bucket.lua")

local SOIL_DRY = "grug_farming:soil"
local SOIL_WET = "grug_farming:soil_wet"
local SOIL_INTERVAL = 15
local WATER_RADIUS = 3
local STAGES = 4
local STAGE_SECONDS = 200
local CROP_PROGRESS_META = "wet_progress"
local CROP_PLANTER_META = "grug_crop_planter"

local crop_by_node = {}
local helper_by_node = {}
local profiles = dofile(core.get_modpath(core.get_current_modname()) ..
	"/crop_profiles.lua")

grug_farming.SOIL_DRY = SOIL_DRY
grug_farming.SOIL_WET = SOIL_WET
grug_farming.SOIL_INTERVAL = SOIL_INTERVAL
grug_farming.WATER_RADIUS = WATER_RADIUS
grug_farming.STAGES = STAGES
grug_farming.STAGE_SECONDS = STAGE_SECONDS

local function start_soil_timer(pos)
	core.get_node_timer(pos):start(SOIL_INTERVAL)
end

local function growing_crop_at(pos)
	local state = crop_by_node[core.get_node(pos).name]
	if state and state.stage < STAGES then return state end
	return nil
end

local function pause_crop_timer(pos)
	if not growing_crop_at(pos) then return end
	local timer = core.get_node_timer(pos)
	if not timer:is_started() then return end
	core.get_meta(pos):set_float(CROP_PROGRESS_META, timer:get_elapsed())
	timer:stop()
end

local function resume_crop_timer(pos)
	if not growing_crop_at(pos) then return end
	local timer = core.get_node_timer(pos)
	if timer:is_started() then return end
	local elapsed = core.get_meta(pos):get_float(CROP_PROGRESS_META)
	timer:set(STAGE_SECONDS, elapsed)
end

local function start_crop_timer(pos)
	core.get_meta(pos):set_float(CROP_PROGRESS_META, 0)
	local below = {x = pos.x, y = pos.y - 1, z = pos.z}
	if core.get_node(below).name == SOIL_WET then
		core.get_node_timer(pos):set(STAGE_SECONDS, 0)
	else
		core.get_node_timer(pos):stop()
	end
end

local function soil_timer(pos)
	local node = core.get_node(pos)
	local wet = core.find_node_near(pos, WATER_RADIUS, {"group:water"}) ~= nil
	local wanted = wet and SOIL_WET or SOIL_DRY
	if node.name ~= wanted then
		core.swap_node(pos, {name = wanted})
		local above = {x = pos.x, y = pos.y + 1, z = pos.z}
		if wanted == SOIL_WET then
			resume_crop_timer(above)
		else
			pause_crop_timer(above)
		end
	end
	return true
end

grug_nodes.bind_crop_soil_callbacks({
 on_construct = start_soil_timer, on_timer = soil_timer,
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
local crop_keys = {}
-- ART owns this pure map and its licensed textures; integration merges that
-- commit before this registration hook is exercised.
local seed_visuals = dofile(core.get_modpath(core.get_current_modname()) ..
	"/seed_visuals.lua")

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
		profile = assert(profiles[key], "grug_farming: missing profile " .. key),
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

local function copy_pos(pos, dy)
	return {x = pos.x, y = pos.y + (dy or 0), z = pos.z}
end

local function height_for(row, stage)
	return row.profile.heights and row.profile.heights[stage] or 1
end

local function helper_name(row, stage, level)
	return "grug_farming:" .. row.key .. "_" .. stage .. "_upper_" .. level
end

local function owned_helper(node_name, root_pos, pos, row)
	local helper = helper_by_node[node_name]
	return helper and helper.crop == row and
		pos.x == root_pos.x and pos.z == root_pos.z and
		pos.y - helper.level == root_pos.y
end

local function protection_ok(pos, player_name)
	if not core.is_protected(pos, player_name) then return true end
	if player_name ~= "" then core.record_protection_violation(pos, player_name) end
	return false
end

local function transition_crop(pos, state, next_stage, player_name)
	local row = state.crop
	local old_height = height_for(row, state.stage)
	local new_height = height_for(row, next_stage)
	local maximum = math.max(old_height, new_height)
	if not protection_ok(pos, player_name) then return false end
	for level = 1, maximum - 1 do
		local upper = copy_pos(pos, level)
		local node = core.get_node_or_nil(upper)
		if not node or not protection_ok(upper, player_name) then return false end
		local owned = owned_helper(node.name, pos, upper, row)
		if level < new_height and not owned then
			local definition = core.registered_nodes[node.name]
			if not definition or not definition.buildable_to then return false end
		end
	end
	for level = 1, maximum - 1 do
		local upper = copy_pos(pos, level)
		local node = core.get_node(upper)
		if owned_helper(node.name, pos, upper, row) then core.remove_node(upper) end
	end
	core.swap_node(pos, {name = row.stages[next_stage]})
	for level = 1, new_height - 1 do
		core.set_node(copy_pos(pos, level), {name = helper_name(row, next_stage, level)})
	end
	return true
end

local function crop_timer(pos, elapsed)
	local node = core.get_node(pos)
	local state = crop_by_node[node.name]
	if not state or state.stage >= STAGES then return false end
	local below = {x = pos.x, y = pos.y - 1, z = pos.z}
	-- Expired timers are removed before Luanti invokes any callbacks. If the
	-- soil callback dried this crop first, this stale callback must credit no
	-- part of its elapsed value and must not restart while dry.
	if core.get_node(below).name ~= SOIL_WET then return false end
	local advance = math.floor(elapsed / STAGE_SECONDS)
	local remainder = elapsed % STAGE_SECONDS
	if advance < 1 then
		core.get_meta(pos):set_float(CROP_PROGRESS_META, elapsed)
		core.get_node_timer(pos):set(STAGE_SECONDS, elapsed)
		return false
	end
	local next_stage = math.min(STAGES, state.stage + advance)
	local player_name = core.get_meta(pos):get_string(CROP_PLANTER_META)
	if not transition_crop(pos, state, next_stage, player_name) then
		core.get_meta(pos):set_float(CROP_PROGRESS_META,
			math.max(0, STAGE_SECONDS - SOIL_INTERVAL))
		core.get_node_timer(pos):set(STAGE_SECONDS,
			math.max(0, STAGE_SECONDS - SOIL_INTERVAL))
		return false
	end
	if next_stage >= STAGES then
		core.get_meta(pos):set_float(CROP_PROGRESS_META, 0)
		return false
	end
	core.get_meta(pos):set_float(CROP_PROGRESS_META, remainder)
	core.get_node_timer(pos):set(STAGE_SECONDS, remainder)
	return false
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
		-- Planting can hydrate/swap the supporting soil before it writes the crop.
		-- Both positions are therefore part of the player action and must pass
		-- protection independently.
		if core.is_protected(under, player_name) then
			core.record_protection_violation(under, player_name)
			return itemstack
		end
		if core.is_protected(above, player_name) then
			core.record_protection_violation(above, player_name)
			return itemstack
		end
		soil_timer(under)
		start_soil_timer(under)
		core.set_node(above, {name = row.stages[1]})
		core.get_meta(above):set_string(CROP_PLANTER_META, player_name)
		start_crop_timer(above)
		core.sound_play("default_place_node", {pos = above, gain = 0.35}, true)
		if not core.is_creative_enabled(player_name) then itemstack:take_item(1) end
		return itemstack
	end
end

local function root_for(pos, node_name)
	local state = crop_by_node[node_name]
	if state then return pos, state end
	local helper = helper_by_node[node_name]
	if not helper then return nil end
	local root = copy_pos(pos, -helper.level)
	local root_state = crop_by_node[core.get_node(root).name]
	if not root_state or root_state.crop ~= helper.crop or
		root_state.stage ~= helper.stage then return nil end
	return root, root_state
end

local function whole_crop_positions(root, state)
	local result = {root}
	for level = 1, height_for(state.crop, state.stage) - 1 do
		local pos = copy_pos(root, level)
		local node = core.get_node_or_nil(pos)
		if not node then return nil end
		local name = node.name
		if owned_helper(name, root, pos, state.crop) then result[#result + 1] = pos end
	end
	return result
end

local function give_harvest(player, pos, item)
	if core.is_creative_enabled(player:get_player_name()) then return end
	local leftover = player:get_inventory():add_item("main", item)
	if not leftover:is_empty() then core.add_item(pos, leftover) end
end

local function dig_crop(pos, node, digger)
	if not digger or not digger:is_player() then return end
	local root, state = root_for(pos, node.name)
	if not root then return end
	local name = digger:get_player_name()
	local positions = whole_crop_positions(root, state)
	if not positions then return end
	for index = 1, #positions do
		if not protection_ok(positions[index], name) then return end
	end
	for index = #positions, 2, -1 do core.remove_node(positions[index]) end
	core.remove_node(root)
	if not core.is_creative_enabled(name) then
		local drops = {state.crop.seed}
		if state.stage == STAGES then drops[#drops + 1] = state.crop.harvest_item end
		core.handle_node_drops(root, drops, digger)
	end
end

local function harvest_crop(pos, node, clicker, itemstack)
	if not clicker or not clicker:is_player() or
		clicker:get_player_control().sneak then return itemstack end
	local root, state = root_for(pos, node.name)
	if not root or state.stage ~= STAGES or not state.crop.profile.regrow_stage then
		return itemstack
	end
	local name = clicker:get_player_name()
	local positions = whole_crop_positions(root, state)
	if not positions then return itemstack end
	for index = 1, #positions do
		if not protection_ok(positions[index], name) then return itemstack end
	end
	local next_stage = state.crop.profile.regrow_stage
	if not transition_crop(root, state, next_stage, name) then return itemstack end
	core.get_meta(root):set_string(CROP_PLANTER_META, name)
	start_crop_timer(root)
	give_harvest(clicker, root, state.crop.harvest_item)
	return itemstack
end

for index = 1, #crops do
	local row = crops[index]
	for stage = 1, STAGES do
		for level = 1, height_for(row, stage) - 1 do
			local name = helper_name(row, stage, level)
			helper_by_node[name] = {crop = row, stage = stage, level = level}
			local visual = grug_nodes.crop_visual(row.key, stage,
				default.node_sound_leaves_defaults(),
				{mode = "cultivated", segment = level})
			visual.description = row.description .. " Crop (upper)"
			visual.groups = {snappy = 3, flammable = 2, plant = 1,
				grug_farming_crop_helper = 1, not_in_creative_inventory = 1}
			visual.drop = ""
			visual.buildable_to = false
			visual.on_dig = dig_crop
			visual.on_rightclick = harvest_crop
			visual._grug_crop = row.key
			visual._grug_crop_stage = stage
			visual._grug_crop_root_offset = -level
			core.register_node(name, visual)
		end
	end
	core.register_craftitem(row.seed, {
		description = row.description .. " Seeds",
		inventory_image = assert(seed_visuals[row.key],
			"grug_farming: missing seed visual " .. row.key),
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

		local definition = grug_nodes.crop_visual(row.key, stage,
			default.node_sound_leaves_defaults(),
			{mode = "cultivated", segment = 0})
		local gameplay = {
			description = row.description .. " Crop" .. (mature and "" or
				" (Stage " .. stage .. ")"),
			groups = groups,
			drop = drop,
			on_construct = on_construct,
			on_timer = on_timer,
			on_dig = dig_crop,
			on_rightclick = harvest_crop,
			_grug_crop = row.key,
			_grug_crop_stage = stage,
			_grug_crop_harvest = row.harvest_item,
		}
		for key, value in pairs(gameplay) do definition[key] = value end
		core.register_node(row.stages[stage], definition)
	end
end

grug_farming.CROPS = crops

local crop_root_names = {}
for index = 1, #crops do
	for stage = 1, STAGES do
		crop_root_names[#crop_root_names + 1] = crops[index].stages[stage]
	end
end

-- Voxel persistence normally restores the complete plant. This activation
-- repairs only current-version helper geometry belonging to a loaded root; it
-- neither scans for orphans nor recognizes any historical format.
core.register_lbm({
	label = "Activate current cultivated crop geometry",
	name = "grug_farming:activate_crop_geometry",
	nodenames = crop_root_names,
	run_at_every_load = true,
	action = function(pos, node)
		local state = crop_by_node[node.name]
		if not state or not state.crop.profile.heights then return end
		transition_crop(pos, state, state.stage,
			core.get_meta(pos):get_string(CROP_PLANTER_META))
	end,
})

dofile(core.get_modpath(core.get_current_modname()) .. "/hoes.lua")({
 start_soil_timer = start_soil_timer,
 soil_timer = soil_timer,
})

dofile(core.get_modpath(core.get_current_modname()) .. "/ecology.lua")()

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
