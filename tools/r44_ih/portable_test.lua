-- Round 44 lane IH portable test (LuaJIT): the inventory logic of the
-- one-inventory view (round44-plan.md §4.1, ui-crafting-rework-plan.md
-- §2.2-2.5, §3.2). Loads the REAL grug_inventory bags.lua (which loads
-- storage.lua) under a minimal engine stub with ItemStack metadata and a
-- model of the engine's inventory move (IMoveAction::apply: fit, swap, the
-- allow callbacks in both directions) and drop (IDropAction: allow-take,
-- then the take and the action callback):
--   A. the give helper's order: the quiver, main[9..], the bags in slot
--      order, the hotbar last, partial stacks first, the leftover; soulbound
--      items only in `main`; the weapon-tooltip setup; pickup and dug drops;
--   B. the fit check: in the helper's order, partial stacks and the quiver
--      counted, several stacks together, nothing changed;
--   C. bag swaps: to a larger bag (contents stay), to a smaller one with room
--      (the overflow fills the kept cells, then the inventory) and without
--      (refused, nothing moves);
--   D. bag removal by drag and by drop: with room (contents redistributed,
--      never into the landing slot) and without (refused), the swap whose
--      old bag would land in its own list refused, bag slot to bag slot;
--   E. a bag inside a bag, never into its own list;
--   F. the sort: categories, tier, name, quality, merging of identical
--      stacks only, free slots at the end, the hotbar untouched, soulbound
--      kept in `main`;
--   G. the potion belt's allow rule and its creation at join;
--   H. ammo from a bag (count, shot, refund).
-- Every operation checks that no item is lost or duplicated.
--
--   luajit tools/r44_ih/portable_test.lua [REPO]
-- Prints "R44 IH PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local callbacks = {allow = {}, action = {}, pickup = {}, join = {}}
local dropped, feed_lines, tooltip_calls = {}, {}, 0
local builtin_drops = 0
core = {
	registered_items = {},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_player_inventory_action = function(f) table.insert(callbacks.action, f) end,
	register_on_item_pickup = function(f) table.insert(callbacks.pickup, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_inventory" end,
	get_current_modname = function() return "grug_inventory" end,
	strip_colors = function(text) return text end,
	is_creative_enabled = function() return false end,
	log = function() end,
	add_item = function(_, stack) dropped[#dropped + 1] = ItemStack(stack) end,
	handle_node_drops = function() builtin_drops = builtin_drops + 1 end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {offset = function(pos, x, y, z) return {x = pos.x + x, y = pos.y + y, z = pos.z + z} end}

-- ItemStack double: name, count, wear and a metadata table; stacks merge
-- only when name, wear and metadata are identical (engine ItemStack::addItem).
local Meta = {}
Meta.__index = Meta
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_int(key, value) self.fields[key] = tostring(value) end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
local function meta_string(fields)
	local keys = {}
	for key in pairs(fields) do keys[#keys + 1] = key end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. fields[key] end
	return table.concat(parts, ";")
end

local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	local self = setmetatable({fields = {}}, Stack)
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name, item.count, item.wear
		for key, value in pairs(item.fields or {}) do self.fields[key] = value end
		return self
	end
	local name, count = tostring(item or ""):match("^(%S*)%s*(%d*)")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	self.wear = 0
	return self
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:get_definition() return core.registered_items[self.name] end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:get_meta() return setmetatable({fields = self.fields}, Meta) end
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count, self.fields = "", 0, {} end
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self)
	taken:set_count(n)
	self:set_count(self.count - n)
	return taken
end
local function compatible(a, b)
	return a.name == b.name and a.wear == b.wear and
		meta_string(a.fields) == meta_string(b.fields)
end
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		local fit = math.min(other.count, ItemStack(other):get_stack_max())
		self.name, self.count, self.wear = other.name, fit, other.wear
		self.fields = {}
		for key, value in pairs(other.fields) do self.fields[key] = value end
		other:set_count(other.count - fit)
		return other
	end
	if not compatible(self, other) then return other end
	local fit = math.max(0, math.min(other.count, self:get_stack_max() - self.count))
	self.count = self.count + fit
	other:set_count(other.count - fit)
	return other
end
function Stack:to_string()
	if self:is_empty() then return "" end
	local meta = meta_string(self.fields)
	return self.name .. " " .. self.count .. " " .. self.wear .. (meta ~= "" and " " .. meta or "")
end

-- InvRef double.
local function new_inventory()
	local inv = {lists = {}}
	function inv:set_size(list, size)
		local old = self.lists[list] or {}
		local new = {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i)
		local l = self.lists[list]
		return ItemStack(l and l[i] or "")
	end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	function inv:get_list(list)
		local l = self.lists[list]
		if not l then return nil end
		local out = {}
		for i = 1, #l do out[i] = ItemStack(l[i]) end
		return out
	end
	function inv:is_empty(list)
		for _, s in ipairs(self.lists[list] or {}) do
			if not s:is_empty() then return false end
		end
		return true
	end
	function inv:add_item(list, stack)
		stack = ItemStack(stack)
		local l = self.lists[list]
		for pass = 1, 2 do
			for i = 1, #l do
				if not stack:is_empty() and ((pass == 1 and not l[i]:is_empty()) or
						(pass == 2 and l[i]:is_empty())) then
					stack = l[i]:add_item(stack)
				end
			end
		end
		return stack
	end
	return inv
end

------------------------------------------------------------------------------
-- Mod surface.
------------------------------------------------------------------------------
grug_core = {
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {kind = kind, text = text, key = key}
		return true
	end,
}
grug_classes = {get_class = function(player) return player.class_id end}
grug_gear = {initialize_weapon_tooltip = function() tooltip_calls = tooltip_calls + 1; return false end}
grug_inventory = {refresh = function() end}

local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.description = def.description or name
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
item("grug_gear:arrow", {description = "Arrow", stack_max = 100, groups = {grug_arrow = 1}})
item("t:apple", {description = "Apple", groups = {grug_food = 1, grug_food_tier = 1}})
item("t:stew", {description = "Stew", groups = {grug_food = 1, grug_food_tier = 3}})
item("t:dirt", {description = "Dirt"})
item("t:stone", {description = "Stone"})
item("t:potion", {description = "Healing Potion", stack_max = 20, groups = {grug_potion = 1}})
item("t:mixture", {description = "Mixture", stack_max = 20, groups = {grug_potion_mixture = 1}})
item("t:claim", {description = "Claim Stone", stack_max = 1, groups = {grug_soulbound = 1}})
item("t:sword_t1", {description = "Bronze Sword", stack_max = 1, _grug_bracket = 1,
	groups = {grug_equip_weapon = 1}})
item("t:sword_t3", {description = "Steel Sword", stack_max = 1, _grug_bracket = 3,
	groups = {grug_equip_weapon = 1}})
item("t:shield_t3", {description = "Steel Shield", stack_max = 1, _grug_bracket = 3,
	groups = {grug_equip_offhand = 1}})
item("t:ring_t2", {description = "Ring", stack_max = 1, _grug_bracket = 2,
	groups = {grug_equip_trinket = 1}})
item("t:helm_t2", {description = "Helm", stack_max = 1, _grug_bracket = 2,
	groups = {grug_equip_head = 1}})
item("t:pick", {description = "Pick", stack_max = 1, groups = {pickaxe = 1}})

dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
local I = grug_inventory
local Q, BELT = I.QUIVER_LIST, I.POTION_BELT
local BAG = {small = "grug_inventory:bag_small", medium = "grug_inventory:bag_medium",
	large = "grug_inventory:bag_large", great = "grug_inventory:bag_great"}

local function new_player(name, class_id)
	local inv = new_inventory()
	inv:set_size("main", 32)
	local player = {inv = inv, class_id = class_id}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	for _, f in ipairs(callbacks.join) do f(player) end
	return player
end
-- Equip a bag server-side the way a move would leave it.
local function equip_bag(player, i, bag)
	player.inv:set_stack(I.bag_list(i), 1, ItemStack(bag))
	player.inv:set_size(I.content_list(i), I.bag_slots_of(ItemStack(bag)))
end
local function fill_list(player, list, from, to, itemstring)
	for index = from, to do player.inv:set_stack(list, index, ItemStack(itemstring)) end
end
local function put(player, list, index, itemstring)
	player.inv:set_stack(list, index, ItemStack(itemstring))
end
local function name_at(player, list, index) return player.inv:get_stack(list, index):get_name() end
local function count_at(player, list, index) return player.inv:get_stack(list, index):get_count() end

-- Every item the player holds, per name (all lists), for the no-loss checks.
local function census(player)
	local counts = {}
	for _, list in pairs(player.inv.lists) do
		for _, stack in ipairs(list) do
			if not stack:is_empty() then
				counts[stack.name] = (counts[stack.name] or 0) + stack.count
			end
		end
	end
	for _, stack in ipairs(dropped) do
		counts[stack.name] = (counts[stack.name] or 0) + stack.count
	end
	return counts
end
local function same_census(a, b, label)
	local ok = true
	for name, count in pairs(a) do if b[name] ~= count then ok = false end end
	for name, count in pairs(b) do if a[name] ~= count then ok = false end end
	return check(ok, label .. ": no item lost or duplicated")
end

------------------------------------------------------------------------------
-- Engine model: IMoveAction::apply inside one player inventory, the drop.
------------------------------------------------------------------------------
local function allow(player, action, info)
	for _, f in ipairs(callbacks.allow) do
		local r = f(player, action, player.inv, info)
		if r ~= nil then return r end
	end
	return nil
end
local function after_action(player, action, info)
	for _, f in ipairs(callbacks.action) do f(player, action, player.inv, info) end
end
local function move(player, from_list, from_i, to_list, to_i, count)
	local inv = player.inv
	local src = inv:get_stack(from_list, from_i)
	if src:is_empty() then return 0 end
	if count and count > 0 and count < src:get_count() then src:set_count(count) end
	local probe = inv:get_stack(to_list, to_i)
	local rest = probe:add_item(ItemStack(src))
	local allow_swap = rest:get_count() == src:get_count()
	local move_count = src:get_count() - rest:get_count()
	if allow_swap then move_count = inv:get_stack(from_list, from_i):get_count() end
	local take = allow(player, "move", {from_list = from_list, from_index = from_i,
		to_list = to_list, to_index = to_i, count = move_count})
	take = take == nil and move_count or take
	local swap_expected = allow_swap
	allow_swap = allow_swap and take >= move_count
	if allow_swap then
		local back = inv:get_stack(to_list, to_i):get_count()
		local r = allow(player, "move", {from_list = to_list, from_index = to_i,
			to_list = from_list, to_index = from_i, count = back})
		allow_swap = r == nil or r >= back
	end
	if swap_expected ~= allow_swap then take = 0 end
	move_count = math.min(take, move_count, inv:get_stack(from_list, from_i):get_count())
	if move_count <= 0 then return 0 end
	if allow_swap then
		local a, b = inv:get_stack(from_list, from_i), inv:get_stack(to_list, to_i)
		inv:set_stack(from_list, from_i, b)
		inv:set_stack(to_list, to_i, a)
	else
		local source = inv:get_stack(from_list, from_i)
		local moving = source:take_item(move_count)
		local dest = inv:get_stack(to_list, to_i)
		local left = dest:add_item(moving)
		source:add_item(left)
		move_count = move_count - left:get_count()
		inv:set_stack(from_list, from_i, source)
		inv:set_stack(to_list, to_i, dest)
	end
	local info = {from_list = from_list, from_index = from_i, to_list = to_list,
		to_index = to_i, count = move_count}
	after_action(player, "move", info)
	if allow_swap then
		after_action(player, "move", {from_list = to_list, from_index = to_i,
			to_list = from_list, to_index = from_i, count = 1})
	end
	return move_count
end
-- Drop out of the window: allow-take, the drop, then the take's callback.
local function drop(player, list, index)
	local stack = player.inv:get_stack(list, index)
	local info = {listname = list, index = index, stack = stack}
	local take = allow(player, "take", info)
	if take == 0 then return false end
	player.inv:set_stack(list, index, ItemStack(""))
	dropped[#dropped + 1] = stack
	after_action(player, "take", info)
	return true
end

------------------------------------------------------------------------------
-- A. The give helper's order.
------------------------------------------------------------------------------
do
	local p = new_player("a1", "warrior")
	equip_bag(p, 1, BAG.small)
	equip_bag(p, 2, BAG.medium)
	local calls = tooltip_calls
	eq(I.give(p, "t:dirt 5"):get_count(), 0, "give: no leftover")
	eq(count_at(p, "main", 9), 5, "give: first into main[9]")
	check(tooltip_calls > calls, "give: the weapon-tooltip setup runs")
	fill_list(p, "main", 10, 32, "t:stone 99")
	I.give(p, "t:apple 3")
	eq(count_at(p, I.content_list(1), 1), 3, "give: main[9..] full -> first bag")
	fill_list(p, I.content_list(1), 2, 8, "t:stone 99")
	I.give(p, "t:apple 99")
	eq(count_at(p, I.content_list(1), 1), 99, "give: partial stack in a bag filled first")
	eq(count_at(p, I.content_list(2), 1), 3, "give: overflow into the second bag")
	fill_list(p, I.content_list(2), 2, 16, "t:stone 99")
	put(p, "main", 9, "t:stone 99")
	put(p, I.content_list(2), 1, "t:stone 99")
	I.give(p, "t:pick")
	eq(name_at(p, "main", 1), "t:pick", "give: the hotbar last")
	put(p, "main", 5, "t:dirt 90")
	I.give(p, "t:dirt 9")
	eq(count_at(p, "main", 5), 99, "give: a partial hotbar stack merges (takes no free slot)")
	check(name_at(p, "main", 2) == "", "give: no free hotbar slot used for a merge")
	fill_list(p, "main", 2, 8, "t:stone 99")
	put(p, "main", 5, "t:dirt 99")
	eq(I.give(p, "t:apple 4"):get_count(), 4, "give: a full inventory returns the leftover")

	-- Soulbound: main only, a free bag cell does not count.
	local s = new_player("a2", "warrior")
	equip_bag(s, 1, BAG.small)
	fill_list(s, "main", 9, 32, "t:stone 99")
	I.give(s, "t:claim")
	check(s.inv:is_empty(I.content_list(1)), "give: soulbound skips the bags")
	eq(name_at(s, "main", 1), "t:claim", "give: soulbound into the hotbar")
	check(not I.fits(s, {"t:claim", "t:claim", "t:claim", "t:claim", "t:claim",
		"t:claim", "t:claim", "t:claim"}), "fits: soulbound counts main only")

	-- Arrows: a Scout's quiver first, everyone else main[9..].
	local scout = new_player("a3", "scout")
	I.give(scout, "grug_gear:arrow 520")
	eq(I.quiver_count(scout), 500, "give: arrows into the quiver first")
	eq(count_at(scout, "main", 9), 20, "give: the quiver's overflow into main[9]")
	local warrior = new_player("a4", "warrior")
	I.give(warrior, "grug_gear:arrow 30")
	eq(count_at(warrior, "main", 9), 30, "give: a non-Scout's arrows into main[9]")

	-- Pickup and dug drops use the helper.
	local picker = new_player("a5", "warrior")
	local result
	for _, f in ipairs(callbacks.pickup) do
		result = f(ItemStack("t:apple 7"), picker)
		if result then break end
	end
	check(result and result:is_empty(), "pickup: handled, no leftover")
	eq(count_at(picker, "main", 9), 7, "pickup: into main[9]")
	fill_list(picker, "main", 1, 32, "t:stone 99")
	dropped = {}
	core.handle_node_drops({x = 0, y = 0, z = 0}, {"t:dirt 2"}, picker)
	eq(#dropped, 1, "dug drops: a full inventory drops the leftover beside the node")
	eq(builtin_drops, 0, "dug drops: builtin's handler not used for a player")
	core.handle_node_drops({x = 0, y = 0, z = 0}, {"t:dirt"}, nil)
	eq(builtin_drops, 1, "dug drops: no digger keeps the previous handler")
	dropped = {}
end

------------------------------------------------------------------------------
-- B. The fit check.
------------------------------------------------------------------------------
do
	local p = new_player("b1", "warrior")
	equip_bag(p, 1, BAG.small)
	fill_list(p, "main", 1, 32, "t:stone 99")
	fill_list(p, I.content_list(1), 1, 7, "t:stone 99")
	put(p, I.content_list(1), 8, "t:apple 90")
	local before = census(p)
	check(I.fits(p, {"t:apple 9"}), "fits: a partial stack counts")
	check(not I.fits(p, {"t:apple 10"}), "fits: one too many")
	check(not I.fits(p, {"t:apple 5", "t:apple 5"}), "fits: several stacks share the room")
	check(I.fits(p, {}), "fits: nothing always fits")
	check(I.fits(p, ItemStack("t:apple 9")), "fits: one stack without a list")
	same_census(before, census(p), "fits")
	eq(count_at(p, I.content_list(1), 8), 90, "fits: changes nothing")
	local scout = new_player("b2", "scout")
	fill_list(scout, "main", 1, 32, "t:stone 99")
	check(I.fits(scout, {"grug_gear:arrow 500"}), "fits: the quiver counts for arrows")
	check(not I.fits(scout, {"grug_gear:arrow 501"}), "fits: beyond the quiver")
	eq(I.quiver_count(scout), 0, "fits: the quiver unchanged")
end

------------------------------------------------------------------------------
-- C. Bag swaps.
------------------------------------------------------------------------------
do
	-- To a larger bag: the contents stay.
	local p = new_player("c1", "warrior")
	equip_bag(p, 1, BAG.large)
	fill_list(p, I.content_list(1), 1, 24, "t:dirt 10")
	put(p, "main", 12, BAG.great)
	local before = census(p)
	eq(move(p, "main", 12, I.bag_list(1), 1), 1, "swap to a larger bag: allowed")
	eq(name_at(p, I.bag_list(1), 1), BAG.great, "swap: the larger bag equipped")
	eq(name_at(p, "main", 12), BAG.large, "swap: the old bag where the new one was")
	eq(p.inv:get_size(I.content_list(1)), 32, "swap: the list grows")
	eq(count_at(p, I.content_list(1), 24), 10, "swap: the contents stay")
	same_census(before, census(p), "swap to a larger bag")

	-- To a smaller bag with room: the kept cells first, then main[9..].
	local s = new_player("c2", "warrior")
	equip_bag(s, 1, BAG.large)
	for index = 5, 24 do put(s, I.content_list(1), index, "t:dirt 99") end
	put(s, "main", 10, BAG.small)
	before = census(s)
	eq(move(s, "main", 10, I.bag_list(1), 1), 1, "swap to a smaller bag: allowed with room")
	eq(p.inv:get_size(I.content_list(1)), 32, "other player untouched")
	eq(s.inv:get_size(I.content_list(1)), 8, "swap: the list shrinks to the small bag")
	local in_bag = 0
	for index = 1, 8 do in_bag = in_bag + count_at(s, I.content_list(1), index) end
	eq(in_bag, 8 * 99, "swap: the overflow fills the kept cells first")
	eq(count_at(s, "main", 9), 99, "swap: the rest of the overflow into main[9..]")
	eq(count_at(s, "main", 21), 99, "swap: twelve stacks in main[9..]")
	eq(name_at(s, "main", 22), "", "swap: nothing beyond the overflow")
	eq(name_at(s, "main", 10), BAG.large, "swap: the old bag on the dragged bag's slot")
	same_census(before, census(s), "swap to a smaller bag")

	-- The same swap dragged the other way (the equipped bag onto the small
	-- one lying in main): the same rule.
	local r = new_player("c2r", "warrior")
	equip_bag(r, 1, BAG.medium)
	fill_list(r, I.content_list(1), 1, 16, "t:dirt 99")
	put(r, "main", 30, BAG.small)
	before = census(r)
	eq(move(r, I.bag_list(1), 1, "main", 30), 1, "swap by dragging the equipped bag: allowed")
	eq(name_at(r, I.bag_list(1), 1), BAG.small, "swap by drag: the small bag equipped")
	eq(r.inv:get_size(I.content_list(1)), 8, "swap by drag: the list shrinks")
	eq(count_at(r, "main", 16), 99, "swap by drag: eight stacks moved to main[9..16]")
	same_census(before, census(r), "swap by dragging the equipped bag")

	-- To a smaller bag without room: refused, nothing moves.
	local f = new_player("c3", "warrior")
	equip_bag(f, 1, BAG.medium)
	fill_list(f, I.content_list(1), 1, 16, "t:dirt 99")
	fill_list(f, "main", 1, 32, "t:stone 99")
	put(f, "main", 20, BAG.small)
	before = census(f)
	feed_lines = {}
	eq(move(f, "main", 20, I.bag_list(1), 1), 0, "swap to a smaller bag: refused without room")
	eq(name_at(f, I.bag_list(1), 1), BAG.medium, "refused swap: the bag stays")
	eq(f.inv:get_size(I.content_list(1)), 16, "refused swap: the list keeps its size")
	check(#feed_lines > 0 and feed_lines[#feed_lines].key == "bag_contents",
		"refused swap: one keyed feed line")
	same_census(before, census(f), "refused swap")
end

------------------------------------------------------------------------------
-- D. Bag removal.
------------------------------------------------------------------------------
do
	-- Drag out with room: contents to main[9..], never into the landing slot.
	local p = new_player("d1", "warrior")
	equip_bag(p, 1, BAG.small)
	equip_bag(p, 2, BAG.small)
	fill_list(p, I.content_list(1), 1, 8, "t:dirt 99")
	fill_list(p, "main", 9, 24, "t:stone 99")
	local before = census(p)
	eq(move(p, I.bag_list(1), 1, "main", 25), 1, "removal: allowed with room")
	eq(name_at(p, "main", 25), BAG.small, "removal: the bag in its landing slot")
	eq(p.inv:get_size(I.content_list(1)), 0, "removal: the list is gone")
	eq(count_at(p, "main", 26), 99, "removal: contents after the landing slot")
	eq(count_at(p, "main", 32), 99, "removal: main[9..] filled to the end")
	eq(count_at(p, I.content_list(2), 1), 99, "removal: then the other bag")
	same_census(before, census(p), "removal by drag")

	-- Exactly as many free slots as contents, one of them the landing slot.
	local t = new_player("d2", "warrior")
	equip_bag(t, 1, BAG.small)
	fill_list(t, I.content_list(1), 1, 8, "t:dirt 99")
	fill_list(t, "main", 1, 32, "t:stone 99")
	for index = 25, 32 do put(t, "main", index, "") end
	before = census(t)
	eq(move(t, I.bag_list(1), 1, "main", 25), 0, "removal: the landing slot does not count")
	eq(name_at(t, I.bag_list(1), 1), BAG.small, "refused removal: the bag stays")
	same_census(before, census(t), "refused removal")
	-- The hotbar is the last room: one free hotbar slot makes it fit.
	put(t, "main", 3, "")
	before = census(t)
	eq(move(t, I.bag_list(1), 1, "main", 25), 1, "removal: the hotbar counts last")
	eq(count_at(t, "main", 3), 99, "removal: the last stack on the hotbar")
	same_census(before, census(t), "removal into the hotbar")

	-- Drop out of the window: with and without room.
	dropped = {}
	local d = new_player("d3", "warrior")
	equip_bag(d, 1, BAG.small)
	fill_list(d, I.content_list(1), 1, 3, "t:apple 5")
	before = census(d)
	check(drop(d, I.bag_list(1), 1), "drop: allowed with room")
	eq(count_at(d, "main", 9), 15, "drop: the contents merged into main[9]")
	eq(d.inv:get_size(I.content_list(1)), 0, "drop: the list is gone")
	same_census(before, census(d), "drop with room")
	dropped = {}
	local full = new_player("d4", "warrior")
	equip_bag(full, 1, BAG.small)
	fill_list(full, I.content_list(1), 1, 8, "t:dirt 99")
	fill_list(full, "main", 1, 32, "t:stone 99")
	check(not drop(full, I.bag_list(1), 1), "drop: refused without room")
	eq(name_at(full, I.bag_list(1), 1), BAG.small, "refused drop: the bag stays")
	eq(#dropped, 0, "refused drop: nothing on the ground")

	-- Between two bag slots: only empty bags.
	local b = new_player("d5", "warrior")
	equip_bag(b, 1, BAG.small)
	equip_bag(b, 2, BAG.medium)
	put(b, I.content_list(1), 1, "t:dirt")
	eq(move(b, I.bag_list(1), 1, I.bag_list(3), 1), 0, "bag slot to bag slot: refused with contents")
	put(b, I.content_list(1), 1, "")
	eq(move(b, I.bag_list(1), 1, I.bag_list(3), 1), 1, "bag slot to bag slot: empty bags move")
	eq(b.inv:get_size(I.content_list(3)), 8, "bag slot to bag slot: the new slot's list")
	eq(b.inv:get_size(I.content_list(1)), 0, "bag slot to bag slot: the old list gone")
	eq(move(b, "main", 9, I.bag_list(4), 1), 0, "an empty source moves nothing")
	put(b, "main", 9, "t:dirt")
	eq(move(b, "main", 9, I.bag_list(4), 1), 0, "only bags fit into bag slots")
end

------------------------------------------------------------------------------
-- E. Bags inside bags.
------------------------------------------------------------------------------
do
	local p = new_player("e1", "warrior")
	equip_bag(p, 1, BAG.small)
	equip_bag(p, 2, BAG.medium)
	put(p, "main", 9, BAG.large)
	eq(move(p, "main", 9, I.content_list(2), 4), 1, "an unequipped bag into a bag")
	eq(name_at(p, I.content_list(2), 4), BAG.large, "the bag sits in the bag")
	eq(move(p, I.bag_list(1), 1, I.content_list(1), 2), 0, "never into its own list")
	eq(move(p, I.bag_list(1), 1, I.content_list(2), 5), 1, "an equipped bag into another bag")
	eq(p.inv:get_size(I.content_list(1)), 0, "the bag left its slot")
	-- A bag in bag 2's list swapped onto slot 2: the old bag would land in
	-- its own list.
	local before = census(p)
	eq(move(p, I.content_list(2), 4, I.bag_list(2), 1), 0, "swap into the own list refused")
	eq(name_at(p, I.bag_list(2), 1), BAG.medium, "refused: bag 2 stays")
	same_census(before, census(p), "bag in a bag")
	-- give fills bags inside nothing: an unequipped bag is an item.
	eq(I.give(p, BAG.small):get_count(), 0, "a bag is given like any item")
end

------------------------------------------------------------------------------
-- F. The sort.
------------------------------------------------------------------------------
do
	local p = new_player("f1", "warrior")
	equip_bag(p, 1, BAG.small)
	put(p, "main", 1, "t:pick")
	put(p, "main", 2, "t:dirt 3")
	local rare = ItemStack("t:sword_t3")
	rare:get_meta():set_int("grug_quality", 3)
	local common = ItemStack("t:sword_t3")
	common:get_meta():set_int("grug_quality", 1)
	local layout = {
		{"main", 9, "t:dirt 40"}, {"main", 11, "t:potion 3"}, {"main", 12, "t:apple 50"},
		{"main", 14, "t:ring_t2"}, {"main", 15, "t:helm_t2"}, {"main", 17, "t:sword_t1"},
		{"main", 20, "grug_gear:arrow 30"}, {"main", 22, "t:stew 2"},
		{"main", 25, "t:claim"}, {"main", 30, "t:shield_t3"},
		{I.content_list(1), 2, "t:apple 60"}, {I.content_list(1), 5, "t:dirt 70"},
		{I.content_list(1), 7, "t:mixture 2"}, {I.content_list(1), 8, "t:pick"},
	}
	for _, row in ipairs(layout) do put(p, row[1], row[2], row[3]) end
	p.inv:set_stack("main", 28, rare)
	p.inv:set_stack(I.content_list(1), 1, common)
	local named = ItemStack("t:dirt 5")
	named:get_meta():set_string("description", "Special Dirt")
	p.inv:set_stack(I.content_list(1), 3, named)
	local before = census(p)
	check(I.sort(p), "sort: changed")
	local expected = {
		"t:shield_t3", "t:sword_t3", "t:sword_t3", "t:sword_t1", -- weapons: tier, name, quality
		"t:ring_t2", "t:helm_t2",                                 -- trinkets, armour
		"grug_gear:arrow", "t:stew", "t:apple", "t:apple", "t:potion", -- consumables
	}
	for index, name in ipairs(expected) do
		eq(name_at(p, "main", 8 + index), name, "sort: main[" .. (8 + index) .. "]")
	end
	eq(p.inv:get_stack("main", 10):get_meta():get_int("grug_quality"), 3,
		"sort: the better quality first")
	eq(count_at(p, "main", 17), 99, "sort: identical apples merged to a full stack")
	eq(count_at(p, "main", 18), 11, "sort: the merge's rest")
	-- The rest (by name): Claim Stone, Dirt (110 plain merged to 99 + 11,
	-- the special one apart), Mixture, Pick.
	local rest = {}
	for index = 20, 32 do rest[#rest + 1] = name_at(p, "main", index) end
	eq(table.concat(rest, ","), "t:claim,t:dirt,t:dirt,t:dirt,t:mixture,t:pick,,,,,,,",
		"sort: the rest, then free slots")
	eq(count_at(p, "main", 21) .. "/" .. count_at(p, "main", 22) .. "/" ..
		count_at(p, "main", 23), "99/11/5", "sort: plain dirt merged, the special stack apart")
	eq(p.inv:get_stack("main", 23):get_meta():get_string("description"), "Special Dirt",
		"sort: metadata kept")
	check(p.inv:is_empty(I.content_list(1)), "sort: free slots contiguous at the end")
	eq(name_at(p, "main", 1), "t:pick", "sort: hotbar slot 1 untouched")
	eq(count_at(p, "main", 2), 3, "sort: hotbar slot 2 untouched")
	same_census(before, census(p), "sort")
	check(not I.sort(p), "sort: a sorted inventory does not change")

	-- Soulbound beyond main: pinned into the last main slot.
	local s = new_player("f2", "warrior")
	equip_bag(s, 1, BAG.small)
	fill_list(s, "main", 9, 32, "t:sword_t1")
	put(s, I.content_list(1), 1, "t:claim")
	before = census(s)
	I.sort(s)
	eq(name_at(s, "main", 32), "t:claim", "sort: soulbound stays in main")
	eq(name_at(s, I.content_list(1), 1), "t:sword_t1", "sort: a weapon moved into the bag")
	same_census(before, census(s), "sort with a soulbound item")
end

------------------------------------------------------------------------------
-- G. The potion belt.
------------------------------------------------------------------------------
do
	local p = new_player("g1", "warrior")
	eq(p.inv:get_size(BELT), 4, "belt: four slots at join")
	put(p, BELT, 2, "t:potion 3")
	for _, f in ipairs(callbacks.join) do f(p) end
	eq(count_at(p, BELT, 2), 3, "belt: a rejoin keeps its contents")
	put(p, "main", 9, "t:potion 5")
	put(p, "main", 10, "t:apple 5")
	put(p, "main", 11, "t:mixture 2")
	eq(move(p, "main", 9, BELT, 1), 5, "belt: a potion goes in")
	eq(move(p, "main", 10, BELT, 3), 0, "belt: an apple is refused")
	eq(move(p, "main", 11, BELT, 3), 0, "belt: a mixture is refused")
	eq(move(p, "main", 10, BELT, 1), 0, "belt: no swap that puts an apple in")
	eq(move(p, BELT, 1, "main", 12), 5, "belt: a potion comes out")
	eq(allow(p, "put", {listname = BELT, index = 1, stack = ItemStack("t:dirt")}), 0,
		"belt: a put from another inventory is refused for non-potions")
	check(I.belt_accepts(ItemStack("t:potion")), "belt_accepts: potion")
	local before = census(p)
	I.give(p, "t:potion 1")
	eq(count_at(p, BELT, 2), 3, "belt: the give helper never fills the belt")
	before["t:potion"] = before["t:potion"] + 1
	same_census(before, census(p), "belt")
end

------------------------------------------------------------------------------
-- H. Ammo from a bag.
------------------------------------------------------------------------------
do
	local s = new_player("h1", "scout")
	equip_bag(s, 1, BAG.small)
	put(s, I.content_list(1), 4, "grug_gear:arrow 30")
	eq(I.ammo_count(s), 30, "ammo: arrows in a bag count")
	check(I.consume_ammo(s, 5), "ammo: a shot from a bag")
	eq(count_at(s, I.content_list(1), 4), 25, "ammo: taken from the bag")
	I.refund_ammo(s, 2)
	eq(I.quiver_count(s), 2, "ammo: a refund goes to the quiver first")
	eq(I.ammo_count(s), 27, "ammo: quiver and bag together")
	local w = new_player("h2", "warrior")
	equip_bag(w, 2, BAG.small)
	put(w, I.content_list(2), 1, "grug_gear:arrow 3")
	eq(I.ammo_count(w), 3, "ammo: a bag counts without a quiver too")
end

print(("R44 IH PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then os.exit(1) end
