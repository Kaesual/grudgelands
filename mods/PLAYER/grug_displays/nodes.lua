local M = grug_displays

local FRAME_IDS = {
	"grug_decor:xdecor_itemframe",
	"grug_displays:frame_iron",
	"grug_displays:frame_carved",
	"grug_displays:frame_brass",
}
local STAND_IDS = {
	"grug_displays:armor_stand",
	"grug_displays:armor_stand_iron",
	"grug_displays:armor_stand_carved",
}
M.FRAME_IDS = FRAME_IDS
M.STAND_IDS = STAND_IDS
M.WEAPON_HOLDER = "grug_displays:weapon_holder"

local function actor_name(player)
	return player and player:get_player_name() or ""
end

local function empty(pos, lists)
	local inv = core.get_meta(pos):get_inventory()
	for _, list in ipairs(lists) do
		if not inv:is_empty(list) then return false end
	end
	return true
end

local function can_dig(lists)
	return function(pos, player)
		return not core.is_protected(pos, actor_name(player)) and empty(pos, lists)
	end
end

local function changed(pos)
	M.refresh(pos)
	default.node_formspec.refresh(pos)
end

local function after_destruct(pos)
	M.remove(pos)
	default.node_formspec.refresh(pos)
end

local function interaction_refused(pos, actor)
	local name = actor_name(actor)
	if not grug_core.interaction_protected(pos, name) then return false end
	if name ~= "" then core.record_protection_violation(pos, name) end
	return true
end

local function form_builder(rows)
	return function(pos, player, context)
		local station = grug_inventory.STATION
		local growth = grug_core.ui.text_growth(player)
		local box, bottom = grug_inventory.station_box("Display", 1.65, growth)
		local location = default.node_formspec.location(pos)
		local content = {box}
		for index, row in ipairs(rows) do
			local x = station.x + (index - 1) * station.pitch * 2
			content[#content + 1] = grug_core.ui.heading(x, station.y - 0.25,
				row.label, growth)
			content[#content + 1] = ("list[%s;%s;%.3f,%.3f;1,1;]"):format(
				location, row.list, x, station.y)
		end
		return grug_inventory.station_formspec(player, table.concat(content),
			bottom, context, 3)
	end
end

local function open(rows)
	local build = form_builder(rows)
	return function(pos, node, clicker, itemstack)
		if not clicker or not clicker:is_player() then return itemstack end
		if interaction_refused(pos, clicker) then return itemstack end
		default.node_formspec.show(clicker, pos, build)
		return itemstack
	end
end

local function one_put(accept)
	return function(pos, listname, index, stack, player)
		if interaction_refused(pos, player) then return 0 end
		if index ~= 1 or not accept(listname, stack) then return 0 end
		return 1
	end
end

local function allow_take(pos, listname, index, stack, player)
	if interaction_refused(pos, player) then return 0 end
	return stack:get_count()
end

local function refuse_move(pos, from_list, from_index, to_list, to_index, count, player)
	interaction_refused(pos, player)
	return 0
end

local frame_rows = {{label = "Item", list = "item"}}
local armor_rows = {{label = "Head", list = "head"}, {label = "Chest", list = "chest"},
	{label = "Legs", list = "legs"}, {label = "Feet", list = "feet"}}

local function construct_frame(pos)
	core.get_meta(pos):get_inventory():set_size("item", 1)
end

local function construct_stand(pos)
	local inv = core.get_meta(pos):get_inventory()
	for _, slot in ipairs(grug_visuals.SLOTS) do inv:set_size(slot, 1) end
	M.refresh(pos)
end

local function place_on_wall(itemstack, placer, pointed_thing)
	if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
	local under, above = pointed_thing.under, pointed_thing.above
	if under.y ~= above.y then return itemstack end
	local param2 = core.dir_to_facedir(vector.subtract(under, above))
	return core.item_place(itemstack, placer, pointed_thing, param2)
end

-- attached_node support loss bypasses can_dig. The engine calls this while
-- node metadata still exists, so the displayed stack becomes a separate drop.
local function preserve_wall_item(pos, node, oldmeta, drops)
	local stack = core.get_meta(pos):get_inventory():get_stack("item", 1)
	if not stack:is_empty() then drops[#drops + 1] = stack end
end

local frame_override = {
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, attached_node = 2,
		grug_functional_display = 1},
	_grug_decor_family = "N01",
	_grug_decor_mount = "wall",
	_grug_display_kind = "frame",
	on_construct = construct_frame,
	can_dig = can_dig({"item"}),
	on_place = place_on_wall,
	preserve_metadata = preserve_wall_item,
	on_rightclick = open(frame_rows),
	allow_metadata_inventory_put = one_put(function(_, stack) return stack:get_count() >= 1 end),
	allow_metadata_inventory_take = allow_take,
	allow_metadata_inventory_move = refuse_move,
	on_metadata_inventory_put = changed,
	on_metadata_inventory_take = changed,
	after_place_node = changed,
	after_destruct = after_destruct,
}
core.override_item(FRAME_IDS[1], frame_override)

local frame_box = {type = "fixed", fixed = {-0.5, -0.5, 0.4375, 0.5, 0.5, 0.5}}
local frame_defs = {
	{FRAME_IDS[2], "Iron Item Frame", "default_steel_block.png"},
	{FRAME_IDS[3], "Carved Item Frame", "default_wood.png^[colorize:#e1c28a:75"},
	{FRAME_IDS[4], "Brass Item Frame", "default_steel_block.png^[colorize:#b7832f:150"},
}
for _, row in ipairs(frame_defs) do
	local def = table.copy(frame_override)
	def.description, def.tiles = row[2], {row[3]}
	def._grug_decor_family = "N03"
	def.drawtype, def.node_box = "nodebox", frame_box
	def.paramtype, def.paramtype2, def.sunlight_propagates = "light", "facedir", true
	def.inventory_image = "grug_decor_xdecor_xdecor_itemframe.png"
	def.sounds = default.node_sound_wood_defaults()
	core.register_node(row[1], def)
end

local stand_box = {type = "fixed", fixed = {
	{-0.34, -0.5, -0.28, 0.34, -0.38, 0.28},
	{-0.09, -0.38, -0.09, 0.09, 0.48, 0.09},
	{-0.38, 0.25, -0.08, 0.38, 0.39, 0.08},
	{-0.22, 0.48, -0.16, 0.22, 0.88, 0.16},
}}
local function stand_def(description, texture)
	return {
		description = description, drawtype = "nodebox", node_box = stand_box,
		selection_box = stand_box, tiles = {texture}, paramtype = "light",
		paramtype2 = "facedir", sunlight_propagates = true,
		groups = {choppy = 2, oddly_breakable_by_hand = 1, flammable = 2,
			grug_functional_display = 1},
		_grug_decor_family = "N02", _grug_display_kind = "stand",
		_grug_decor_mount = "floor",
		sounds = default.node_sound_wood_defaults(),
		on_construct = construct_stand, can_dig = can_dig(grug_visuals.SLOTS),
		on_rightclick = open(armor_rows),
		allow_metadata_inventory_put = one_put(M.slot_accepts),
		allow_metadata_inventory_take = allow_take,
		allow_metadata_inventory_move = refuse_move,
		on_metadata_inventory_put = changed, on_metadata_inventory_take = changed,
		after_place_node = changed, after_destruct = after_destruct,
	}
end
core.register_node(STAND_IDS[1], stand_def("Wooden Armor Stand", "default_wood.png"))
local iron_stand = stand_def("Iron Armor Stand", "default_steel_block.png")
iron_stand._grug_decor_family = "N04"
core.register_node(STAND_IDS[2], iron_stand)
local carved_stand = stand_def("Carved Armor Stand", "default_wood.png^[colorize:#e1c28a:75")
carved_stand._grug_decor_family = "N04"
core.register_node(STAND_IDS[3], carved_stand)

local holder = stand_def("Weapon Holder", "default_wood.png")
holder.node_box = {type = "fixed", fixed = {
	{-0.35, -0.32, 0.42, 0.35, -0.22, 0.5},
	{-0.35, 0.22, 0.42, 0.35, 0.32, 0.5},
	{-0.08, -0.28, 0.43, 0.08, 0.28, 0.49}}}
holder.selection_box = holder.node_box
holder._grug_decor_family = "N05"
holder._grug_display_kind = "weapon"
holder._grug_decor_mount = "wall"
holder.groups = {choppy = 2, oddly_breakable_by_hand = 1, flammable = 2,
	attached_node = 2, grug_functional_display = 1}
holder.on_place = place_on_wall
holder.preserve_metadata = preserve_wall_item
holder.on_construct = construct_frame
holder.can_dig = can_dig({"item"})
holder.on_rightclick = open(frame_rows)
holder.allow_metadata_inventory_put = one_put(function(_, stack) return M.weapon_accepts(stack) end)
core.register_node(M.WEAPON_HOLDER, holder)
