-- The reward room (Round 71): the door behind the boss and the one chest with an
-- inventory per player. Nothing here is saved; a detached list lives as long as
-- its run (pattern: grug_inventory/trash.lua). A player's contents are rolled at
-- their first opening, so everyone of the owner who entered this run gets one roll
-- at the run's level, also a member who entered after the kill.
local loot = ...
local M = grug_expeditions

local CHEST = "grug_expeditions:reward_chest"
local DOOR = "grug_expeditions:reward_door"
local LIST = "main"
local TITLE = "Reward Chest"
local WARNING = "What you leave here is lost when the Expedition ends."
local VIEW_ROWS, HINT_H = 4, 0.5
-- A door is every door node this close to the template's `door` place.
local DOOR_REACH = 8

local boxes = {} -- run -> {player name -> {inv = detached name, size = slots}}

local function box_name(run, name)
	return "grug_expedition_chest_" .. run.id .. "_" .. name
end

local function stack_of(entry, level, player)
	if entry.item then return ItemStack(entry.item .. " " .. entry.count) end
	if entry.copper then return grug_money.make_bag(entry.copper) end
	local stack = grug_items.roll_gear_item(level, entry.quality)
	-- The receiving player's lines, before the stack sits in the list.
	grug_gear.initialize_weapon_tooltip(stack, player)
	return stack
end

local function roll(run, name, player)
	local mob_band = grug_mobs.level_band(run.level)
	local plan = loot.plan(loot.TABLES[run.expedition] or {}, run.level, math.random,
		grug_mobs.coin_bag_range(mob_band))
	local inv_name = box_name(run, name)
	local inv = core.create_detached_inventory(inv_name, {
		allow_put = function() return 0 end,
		allow_move = function() return 0 end,
		allow_take = function(_, _, _, stack, actor)
			if not actor or actor:get_player_name() ~= name then return 0 end
			return stack:get_count()
		end,
	}, name)
	local size = loot.slots(plan)
	inv:set_size(LIST, size)
	for index, entry in ipairs(plan) do
		inv:set_stack(LIST, index, stack_of(entry, run.level, player))
	end
	return {inv = inv_name, size = size}
end

local function chest_form(box)
	return function(_, player, context)
		local station = grug_inventory.STATION
		local location = "detached:" .. box.inv
		local rows = math.ceil(box.size / 8)
		local list_h = rows * station.pitch - 0.25
		local growth = grug_core.ui.text_growth(player)
		local frame, bottom = grug_inventory.station_box(TITLE, list_h + HINT_H, growth)
		local content = table.concat({
			frame,
			grug_inventory.station_list(location, LIST, box.size, rows, context),
			"listring[" .. location .. ";" .. LIST .. "]listring[current_player;grug_inbox]" ..
				"listring[current_player;main]",
			("label[%.3f,%.3f;%s]"):format(station.x, station.y + list_h + HINT_H / 2,
				core.formspec_escape(core.colorize(grug_core.ui.colors.muted, WARNING))),
		})
		return grug_inventory.station_formspec(player, content, bottom, context, VIEW_ROWS)
	end
end

-- Whether `name` may open the chest at `pos` now: the run, or nil and why.
local function may_open(pos, name)
	local run = M.run_at(pos)
	if not run then return nil, "This Expedition has ended." end
	if not M.belongs(run, name) or not run.entered[name] then
		return nil, "This chest holds nothing for you."
	end
	if not M.rewards_open(run) then return nil, "The chest is sealed." end
	return run
end

local function open_chest(pos, player)
	local name = player:get_player_name()
	local run, why = may_open(pos, name)
	if not run then
		grug_core.feed(player, "notice", why, "expedition_chest")
		return
	end
	local mine = boxes[run]
	if not mine then
		mine = {}
		boxes[run] = mine
	end
	local box = mine[name] or roll(run, name, player)
	mine[name] = box
	default.node_formspec.show(player, pos, chest_form(box))
end

core.register_node(CHEST, {
	description = TITLE,
	-- A closed chest's tiles (default/chests.lua register_chest).
	tiles = {"default_chest_top.png", "default_chest_top.png",
		"default_chest_side.png^[transformFX", "default_chest_side.png",
		"default_chest_side.png", "default_chest_front.png"},
	paramtype2 = "facedir",
	groups = {not_in_creative_inventory = 1},
	diggable = false,
	is_ground_content = false,
	drop = "",
	on_blast = function() end,
	sounds = default.node_sound_wood_defaults(),
	on_rightclick = function(pos, _, clicker, itemstack)
		if clicker and clicker:is_player() then open_chest(pos, clicker) end
		return itemstack
	end,
})

-- Sealed timber, from the shipped junglewood. Nothing but the boss's death moves it.
core.register_node(DOOR, {
	description = "Sealed Door",
	tiles = {"default_junglewood.png^[colorize:#20140a:150"},
	paramtype2 = "facedir",
	groups = {not_in_creative_inventory = 1},
	diggable = false,
	is_ground_content = false,
	drop = "",
	on_blast = function() end,
	sounds = default.node_sound_wood_defaults(),
})

-- The run's door only: its nodes stand in its own box.
function M.open_door(run)
	local door = M.places(run).door
	if not door then return end
	local from = vector.subtract(door, DOOR_REACH)
	local to = vector.add(door, DOOR_REACH)
	core.load_area(from, to)
	for _, pos in ipairs(core.find_nodes_in_area(from, to, DOOR)) do
		core.remove_node(pos)
	end
	for name in pairs(run.inside) do
		local player = core.get_player_by_name(name)
		if player then
			grug_core.feed(player, "notice", "The way to the reward room stands open.",
				"expedition_door")
		end
	end
end

-- VoxelManip wrote the chest: its hover text comes here.
M.register_on_ready(function(run)
	local pos = M.places(run).chest
	if not pos then return end
	core.load_area(pos) -- a long preparation may have let its block go
	core.get_meta(pos):set_string("infotext", TITLE)
end)

M.register_on_end(function(run)
	local chest = M.places(run).chest
	for name, box in pairs(boxes[run] or {}) do
		if chest and vector.equals(default.node_formspec.session_pos(name) or vector.zero(), chest) then
			core.close_formspec(name, default.node_formspec.formname)
		end
		core.remove_detached_inventory(box.inv)
	end
	boxes[run] = nil
end)
