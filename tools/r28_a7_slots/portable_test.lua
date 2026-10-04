-- Round 28 Lane A7 portable test: class hand slots (ruling 25) and the Scout
-- quiver slot (ruling 26). Loads the REAL grug_gear permissions and the REAL
-- grug_inventory equipment.lua and bags.lua under a minimal `core` stub, then
-- drives their allow / action / pickup / class-chosen callbacks through a
-- small model of the engine's inventory move (IMoveAction::apply: fit, swap,
-- allow limits, move_somewhere for shift-click).
--
-- The item doubles mirror grug_gear's registrations (families, hands, groups,
-- arrow stack_max); the engine probe (run.sh) checks the real registry.
--
-- Usage (repo root): luajit tools/r28_a7_slots/portable_test.lua [ROOT]

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
local callbacks = {allow = {}, globalstep = {}, action = {}, pickup = {}, class_chosen = {},
	join = {}, mods_loaded = {}}
local chat, logs, dropped = {}, {}, {}
local connected = {}
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
	register_on_mods_loaded = function(f) table.insert(callbacks.mods_loaded, f) end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	chat_send_player = function(name, text) chat[#chat + 1] = text end,
	colorize = function(_, text) return text end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	add_item = function(_, stack) dropped[#dropped + 1] = stack end,
	get_us_time = function() return 0 end,
	get_connected_players = function() return connected end,
	register_globalstep = function(f) table.insert(callbacks.globalstep, f) end,
	after = function() end,
	formspec_escape = function(text) return text end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})

-- ItemStack double: name, count, wear and the definition's stack_max.
local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	local self = setmetatable({}, Stack)
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name, item.count, item.wear
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
function Stack:get_free_space() return self:get_stack_max() - self.count end
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count = "", 0 end
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self.name .. " " .. n)
	if n <= 0 then taken = ItemStack("") end
	self:set_count(self.count - n)
	return taken
end
-- Merge `other` into this stack; returns the leftover (engine addItem).
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		self.name, self.count, self.wear = other.name, other.count, other.wear
		return ItemStack("")
	end
	if self.name ~= other.name then return other end
	local fit = math.max(0, math.min(other.count, self:get_stack_max() - self.count))
	self.count = self.count + fit
	other:set_count(other.count - fit)
	return other
end
function Stack:to_string()
	if self:is_empty() then return "" end
	return self.name .. " " .. self.count
end
function Stack:get_meta()
	return {get_int = function() return 0 end, get_string = function() return "" end}
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
	function inv:room_for_item(list, stack)
		local copy = {}
		for i, s in ipairs(self.lists[list]) do copy[i] = ItemStack(s) end
		local saved = self.lists[list]
		self.lists[list] = copy
		local left = self:add_item(list, stack)
		self.lists[list] = saved
		return left:is_empty()
	end
	return inv
end

local function new_player(name, class_id, level)
	local inv = new_inventory()
	inv:set_size("main", 32)
	local meta_store = {}
	local player = {inv = inv, class_id = class_id, level = level or 60}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	function player:get_meta()
		return {get_int = function(_, k) return meta_store[k] or 0 end,
			set_int = function(_, k, v) meta_store[k] = v end,
			get_string = function(_, k) return meta_store[k] or "" end}
	end
	return player
end

------------------------------------------------------------------------------
-- Mod surface.
------------------------------------------------------------------------------
local equipment_changes = 0
local mono, feed_lines = 0, {}
grug_core = {
	mono_time = function() return mono end,
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), kind = kind,
			text = text, key = key}
		return true
	end,
	notify_equipment_change = function() equipment_changes = equipment_changes + 1 end,
	equipment_is_broken = function(stack) return stack:get_wear() >= 65535 end,
	can_use_item_level = function(player, stack)
		local def = core.registered_items[stack:get_name()]
		local required = def and def._grug_req_level or 1
		return player.level >= required, required, player.level
	end,
	status_modifier_sum = function() return 0 end,
}
local CLASSES = {warrior = {name = "Warrior"}, scout = {name = "Scout"},
	mage = {name = "Mage"}, priest = {name = "Priest"}}
grug_classes = {
	class_ids = {"warrior", "scout", "mage", "priest"},
	registered_classes = CLASSES,
	get_class = function(player) return player.class_id end,
	get_class_def = function(player) return CLASSES[player.class_id] end,
	get_armor_rank = function(player)
		return ({warrior = 3, scout = 2})[player.class_id] or 1
	end,
	register_on_class_chosen = function(f) table.insert(callbacks.class_chosen, f) end,
	get_talent_bonus = function() return 0 end,
	talent_rank = function() return 0 end,
}
grug_gear = {STARTER_SWORD = "grug_gear:sword_bronze",
	STARTER_STAFF = "grug_gear:staff_bronze", STARTER_BOW = "grug_gear:bow_bronze"}
dofile(ROOT .. "/mods/ITEMS/grug_gear/permissions.lua")
function grug_gear.usable_by() return "Usable by: someone" end

-- Item doubles in grug_gear's shape (init.lua WEAPONS, shields, spellbooks,
-- arrow).
local WEAPONS = {
	sword = {hands = 1, group = "sword"}, dagger = {hands = 1, group = "sword"},
	greataxe = {hands = 2, group = "axe"}, staff = {hands = 2, group = "staff"},
	wand = {hands = 1, group = "wand"}, bow = {hands = 1, group = "bow"},
}
for family, w in pairs(WEAPONS) do
	for _, tier in ipairs({{"bronze", 1}, {"steel", 20}}) do
		local groups = {grug_gear = 1, grug_equip_weapon = 1}
		groups[w.group] = 1
		if family == "bow" then groups.grug_bow = 1 end
		core.registered_items["grug_gear:" .. family .. "_" .. tier[1]] = {
			description = family .. " " .. tier[1], groups = groups, stack_max = 1,
			_grug_weapon_family = family, _grug_hands = w.hands,
			_grug_req_level = tier[2],
		}
	end
end
core.registered_items["grug_gear:shield_bronze"] = {description = "Shield",
	stack_max = 1, groups = {grug_gear = 1, grug_equip_offhand = 1, grug_shield = 1}}
core.registered_items["grug_gear:spellbook_bronze"] = {description = "Spellbook",
	stack_max = 1, groups = {grug_gear = 1, grug_equip_offhand = 1, grug_spellbook = 1}}
-- Round 33 (round33-plan.md §2.2): every equipment slot holds the level gate.
core.registered_items["grug_gear:head_metal_steel"] = {description = "Steel Helm",
	stack_max = 1, _grug_req_level = 20,
	groups = {grug_gear = 1, grug_equip_head = 1, grug_armor_class = 3}}
core.registered_items["grug_gear:shield_steel"] = {description = "Steel Shield",
	stack_max = 1, _grug_req_level = 20,
	groups = {grug_gear = 1, grug_equip_offhand = 1, grug_shield = 1}}
core.registered_items["grug_gear:manawell_t3"] = {description = "Steel Manawell Pendant",
	stack_max = 1, _grug_req_level = 20, _grug_trinket_identity = "manawell",
	groups = {grug_gear = 1, grug_equip_trinket = 1}}
core.registered_items["grug_gear:arrow"] = {description = "Arrow", stack_max = 100,
	groups = {grug_arrow = 1}}
core.registered_items["t:apple"] = {description = "Apple", stack_max = 99, groups = {}}

grug_inventory = {}
dofile(ROOT .. "/mods/PLAYER/grug_inventory/equipment.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
local refreshes = 0
grug_inventory.refresh = function() end
grug_inventory.refresh_character_tab = function(_, tab)
	if tab == "stats" then refreshes = refreshes + 1 end
end
local I = grug_inventory
local Q = I.QUIVER_LIST

local function join(player)
	for _, f in ipairs(callbacks.join) do f(player) end
end

------------------------------------------------------------------------------
-- Engine model: IMoveAction::apply within one player inventory.
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

-- One move; returns the moved count. `somewhere` = a shift-click sub-move.
local function move(player, from_list, from_i, to_list, to_i, count, somewhere)
	local inv = player.inv
	local src = inv:get_stack(from_list, from_i)
	if src:is_empty() then return 0 end
	if count and count > 0 and count < src:get_count() then src:set_count(count) end
	local probe = inv:get_stack(to_list, to_i)
	local rest = probe:add_item(ItemStack(src))
	local allow_swap = rest:get_count() == src:get_count() and not somewhere
	local move_count = src:get_count() - rest:get_count()
	if somewhere and move_count == 0 then return 0 end
	if allow_swap then move_count = inv:get_stack(from_list, from_i):get_count() end
	local info = {from_list = from_list, from_index = from_i, to_list = to_list,
		to_index = to_i, count = move_count}
	local take = allow(player, "move", info)
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
	after_action(player, "move", {from_list = from_list, from_index = from_i,
		to_list = to_list, to_index = to_i, count = move_count})
	return move_count
end

-- Shift-click: move_somewhere over every cell of the target list, non-empty
-- cells first.
local function shift_move(player, from_list, from_i, to_list)
	local inv = player.inv
	for pass = 1, 2 do
		for i = 1, inv:get_size(to_list) do
			local empty = inv:get_stack(to_list, i):is_empty()
			if (pass == 1) ~= empty and not inv:get_stack(from_list, from_i):is_empty() then
				move(player, from_list, from_i, to_list, i,
					inv:get_stack(from_list, from_i):get_count(), true)
			end
		end
	end
end

local function put_main(player, index, item)
	player.inv:set_stack("main", index, ItemStack(item))
end
local function quiver_counts(player)
	local out = {}
	for i = 1, player.inv:get_size(Q) do out[i] = player.inv:get_stack(Q, i):get_count() end
	return table.concat(out, ",")
end
local function choose_class(player, class_id)
	player.class_id = class_id
	for _, f in ipairs(callbacks.class_chosen) do f(player, class_id) end
end

------------------------------------------------------------------------------
-- 1. Hand acceptance per class (ruling 25).
------------------------------------------------------------------------------
local function accepts(class_id, list, item)
	return I.hand_accepts(class_id, list, ItemStack(item))
end
local W, O = "grug_weapon", "grug_offhand"
local cases = {
	{"warrior", W, "grug_gear:sword_bronze", true},
	{"warrior", W, "grug_gear:greataxe_bronze", true},
	{"warrior", W, "grug_gear:bow_bronze", false},
	{"warrior", O, "grug_gear:shield_bronze", true},
	{"warrior", O, "grug_gear:spellbook_bronze", false},
	{"warrior", O, "grug_gear:sword_bronze", false},
	{"mage", W, "grug_gear:staff_bronze", true},
	{"mage", O, "grug_gear:spellbook_bronze", true},
	{"mage", O, "grug_gear:shield_bronze", false},
	{"priest", O, "grug_gear:spellbook_bronze", true},
	{"priest", O, "grug_gear:dagger_bronze", false},
	{"scout", W, "grug_gear:bow_bronze", true},
	{"scout", W, "grug_gear:sword_bronze", false},
	{"scout", W, "grug_gear:dagger_bronze", false},
	{"scout", O, "grug_gear:sword_bronze", true},
	{"scout", O, "grug_gear:dagger_bronze", true},
	{"scout", O, "grug_gear:bow_bronze", false},
	{"scout", O, "grug_gear:shield_bronze", false},
	{"scout", O, "grug_gear:spellbook_bronze", false},
	{"scout", O, "grug_gear:greataxe_bronze", false},
	{nil, W, "grug_gear:sword_bronze", false},
	{nil, O, "grug_gear:shield_bronze", false},
}
for _, c in ipairs(cases) do
	eq(accepts(c[1], c[2], c[3]), c[4], ("accepts %s %s %s"):format(
		tostring(c[1]), c[2], c[3]))
end
eq(I.slot_label("scout", W), "Ranged", "scout weapon label")
eq(I.slot_label("scout", O), "Melee", "scout offhand label")
eq(I.slot_label("warrior", O), "Shield", "warrior offhand label")
eq(I.slot_label("mage", O), "Caster offhand", "mage offhand label")
eq(I.slot_label("priest", O), "Caster offhand", "priest offhand label")
eq(I.slot_label("warrior", "grug_head"), nil, "armor slot has no class label")
check(I.slot_ghost("scout", W):find("bow", 1, true) ~= nil, "scout ranged ghost is a bow")
check(I.slot_ghost("warrior", O):find("shield", 1, true) ~= nil, "warrior ghost is a shield")
check(I.slot_ghost("mage", O):find("spellbook", 1, true) ~= nil, "mage ghost is a book")

------------------------------------------------------------------------------
-- 2. The real allow callback: equips through the engine model.
------------------------------------------------------------------------------
local function equip(player, item, list)
	put_main(player, 1, item)
	local moved = move(player, "main", 1, list, 1, 1)
	return moved == 1
end
do
	local scout = new_player("s1", "scout", 30)
	join(scout)
	check(equip(scout, "grug_gear:bow_steel", W), "scout equips bow in Ranged")
	check(equip(scout, "grug_gear:sword_steel", O), "scout equips sword beside the bow")
	eq(I.get_melee_weapon(scout) and I.get_melee_weapon(scout):get_name(),
		"grug_gear:sword_steel", "scout melee weapon is the Melee slot")
	eq(I.get_equipped_weapon(scout):get_name(), "grug_gear:bow_steel",
		"scout Weapon slot keeps the bow")
	eq(I.melee_list(scout), O, "scout melee list")
	eq(I.hand_list(scout, "melee"), O, "scout melee ability slot")
	eq(I.hand_list(scout, "weapon"), W, "scout bow ability slot")
	-- Wrong slot: refused with a hint that names the right slot.
	local sc = new_player("s2", "scout", 30)
	join(sc)
	-- Refusals are message-feed lines keyed by their reason, never chat
	-- (Round 32 F3).
	local before, chat_before = #feed_lines, #chat
	check(not equip(sc, "grug_gear:sword_bronze", W), "scout cannot put sword in Ranged")
	local line = feed_lines[#feed_lines]
	check(#feed_lines == before + 1 and line.text:find("Melee slot", 1, true) ~= nil and
		line.kind == "notice" and line.key:find("^equip:") ~= nil,
		"refusal names the Melee slot in a keyed feed line")
	-- Level gate applies to the Melee slot too.
	local low = new_player("s3", "scout", 5)
	join(low)
	check(not equip(low, "grug_gear:dagger_steel", O), "level gate on Melee slot")
	check(feed_lines[#feed_lines].text:find("Melee slot", 1, true) ~= nil,
		"level refusal names the slot")
	eq(#chat, chat_before, "equip refusals: nothing in chat")
	-- Armour, offhand and trinket slots: the same gate (Round 33).
	for _, row in ipairs({{"grug_gear:head_metal_steel", "grug_head", "Head slot"},
			{"grug_gear:shield_steel", O, "Shield slot"},
			{"grug_gear:manawell_t3", "grug_trinket1", "Trinket slot"}}) do
		local young = new_player("lv_" .. row[2], "warrior", 19)
		join(young)
		check(not equip(young, row[1], row[2]), "level gate: " .. row[1] .. " at level 19")
		check(feed_lines[#feed_lines].text:find("requires level 20 for the " .. row[3], 1, true)
			~= nil, "level refusal names the " .. row[3])
		local ready = new_player("lv20_" .. row[2], "warrior", 20)
		join(ready)
		check(equip(ready, row[1], row[2]), "level gate: " .. row[1] .. " at level 20")
	end
	-- Broken melee weapon: bare hand.
	local broken = new_player("s4", "scout", 30)
	join(broken)
	equip(broken, "grug_gear:sword_bronze", O)
	local stack = broken.inv:get_stack(O, 1)
	stack.wear = 65535
	broken.inv:set_stack(O, 1, stack)
	I.equipment_changed(broken, O)
	eq(I.get_melee_weapon(broken), nil, "broken Melee blade swings as bare hand")

	local warrior = new_player("w1", "warrior", 30)
	join(warrior)
	check(equip(warrior, "grug_gear:sword_bronze", W), "warrior sword")
	check(equip(warrior, "grug_gear:shield_bronze", O), "warrior shield beside sword")
	eq(I.melee_list(warrior), W, "warrior melee list")
	eq(I.get_melee_weapon(warrior):get_name(), "grug_gear:sword_bronze",
		"warrior melee weapon is the Weapon slot")
	check(not equip(warrior, "grug_gear:greataxe_bronze", W),
		"greataxe refused while a shield is held")
	check(feed_lines[#feed_lines].text:find("is two-handed: take", 1, true) ~= nil,
		"two-handed refusal (incoming) is one short feed line: " .. feed_lines[#feed_lines].text)
	local mage = new_player("m1", "mage", 30)
	join(mage)
	check(equip(mage, "grug_gear:staff_bronze", W), "mage staff")
	check(not equip(mage, "grug_gear:spellbook_bronze", O), "staff is two-handed")
	check(feed_lines[#feed_lines].text:find("is two-handed: equip a one-handed weapon", 1, true) ~= nil,
		"two-handed refusal (held) is one short feed line: " .. feed_lines[#feed_lines].text)
	check(equip(mage, "grug_gear:wand_bronze", W), "mage swaps to a wand")
	eq(mage.inv:get_stack("main", 1):get_name(), "grug_gear:staff_bronze",
		"the staff swapped back to main")
	check(equip(mage, "grug_gear:spellbook_bronze", O), "wand and spellbook fit")
	check(not equip(mage, "grug_gear:shield_bronze", O), "mage cannot equip a shield")
end

------------------------------------------------------------------------------
-- 3. Quiver layout and moves (ruling 26).
------------------------------------------------------------------------------
eq(table.concat(I.quiver_layout(437, 100, 5), ","), "100,100,100,100,37", "layout 437")
eq(table.concat(I.quiver_layout(0, 100, 5), ","), "0,0,0,0,0", "layout 0")
eq(table.concat(I.quiver_layout(500, 100, 5), ","), "100,100,100,100,100", "layout 500")
eq(table.concat(I.quiver_layout(60, 100, 5), ","), "60,0,0,0,0", "layout 60")
eq(I.quiver_capacity(), 500, "capacity 500")

do
	-- Starter grant: bow in Ranged, sword in Melee, 200 arrows in the quiver.
	local s = new_player("q1", nil, 1)
	join(s)
	eq(s.inv:get_size(Q), 5, "quiver list has five hidden stacks")
	local fed, chat_before = #feed_lines, #chat
	choose_class(s, "scout")
	-- One feed line per starter item, keyed per slot, never chat (Round 32 F3).
	local starter_lines = 0
	for index = fed + 1, #feed_lines do
		local line = feed_lines[index]
		if line.key and line.key:find("^starter:") and
				line.text:find(" is equipped in the ", 1, true) then
			starter_lines = starter_lines + 1
		end
	end
	eq(starter_lines, 2, "starter bow and sword each report their slot in the feed")
	eq(#chat, chat_before, "starter grant: nothing in chat")
	eq(s.inv:get_stack(W, 1):get_name(), "grug_gear:bow_bronze", "starter bow in Ranged")
	eq(s.inv:get_stack(O, 1):get_name(), "grug_gear:sword_bronze", "starter sword in Melee")
	eq(quiver_counts(s), "100,100,0,0,0", "starter arrows in the quiver")
	eq(I.ammo_count(s), 200, "ammo count")
	check(s.inv:is_empty("main"), "nothing of the starter kit in main")

	-- Drag 50 arrows onto the full visible cell: absorbed, not swapped.
	put_main(s, 3, "grug_gear:arrow 50")
	local moved = move(s, "main", 3, Q, 1, 50)
	eq(moved, 0, "engine move refused (absorbed instead)")
	eq(I.quiver_count(s), 250, "drag onto full cell adds 50")
	check(s.inv:get_stack("main", 3):is_empty(), "dragged arrows left main")
	eq(quiver_counts(s), "100,100,50,0,0", "layout after drag")

	-- Partial drag (10 of 80) onto the FULL visible cell: the engine treats it
	-- as a whole-stack swap and hands the allow callback the whole count, so
	-- the whole stack goes in (an engine property, accepted).
	put_main(s, 4, "grug_gear:arrow 80")
	move(s, "main", 4, Q, 1, 10)
	eq(I.quiver_count(s), 330, "partial drag onto a full cell takes the stack")
	check(s.inv:get_stack("main", 4):is_empty(), "dragged stack left main")
	-- Onto a visible cell with room the dragged count is honoured.
	local few = new_player("q0", nil, 1)
	join(few)
	choose_class(few, "scout")
	I.consume_ammo(few, 150)
	eq(I.quiver_count(few), 50, "quiver at 50")
	put_main(few, 4, "grug_gear:arrow 80")
	move(few, "main", 4, Q, 1, 10)
	eq(I.quiver_count(few), 60, "partial drag adds only the dragged count")
	eq(few.inv:get_stack("main", 4):get_count(), 70, "rest stays in main")
	-- Shift-click the 70 in.
	shift_move(few, "main", 4, Q)
	eq(I.quiver_count(few), 130, "shift-click adds the stack")
	check(few.inv:get_stack("main", 4):is_empty(), "shift-clicked stack left main")
	eq(quiver_counts(few), "100,30,0,0,0", "layout after shift-click")

	-- Fill to the cap: only the room is taken.
	put_main(s, 5, "grug_gear:arrow 100")
	put_main(s, 6, "grug_gear:arrow 100")
	move(s, "main", 5, Q, 1, 100)
	move(s, "main", 6, Q, 1, 100)
	eq(I.quiver_count(s), 500, "quiver caps at 500")
	eq(s.inv:get_stack("main", 6):get_count(), 30, "overflow stays in main")
	shift_move(s, "main", 6, Q)
	eq(s.inv:get_stack("main", 6):get_count(), 30, "full quiver takes nothing")

	-- Non-arrows never enter.
	put_main(s, 7, "t:apple 5")
	move(s, "main", 7, Q, 1, 5)
	eq(s.inv:get_stack("main", 7):get_count(), 5, "apple refused")

	-- Click-take: up to 100 as one stack, the visible cell refills.
	local taken = move(s, Q, 1, "main", 10, 100)
	eq(taken, 100, "take 100 from the quiver")
	eq(s.inv:get_stack("main", 10):get_count(), 100, "one stack of 100 in main")
	eq(quiver_counts(s), "100,100,100,100,0", "visible cell refilled")
	-- Taking onto a full arrow stack would be a swap: refused.
	eq(move(s, Q, 1, "main", 10, 100), 0, "no swap onto a full arrow stack")
	eq(move(s, Q, 1, "main", 7, 100), 0, "no swap onto another item")
	-- Merging into a partial stack is fine.
	put_main(s, 11, "grug_gear:arrow 40")
	eq(move(s, Q, 1, "main", 11, 100), 60, "merge into a partial stack")
	eq(I.quiver_count(s), 340, "quiver after the merge")
	eq(quiver_counts(s), "100,100,100,40,0", "normalized after the merge")
	check(refreshes > 0, "Character page refreshed for the total")

	-- Shots: quiver first, then main.
	eq(I.ammo_count(s), 340 + 100 + 100 + 30, "ammo counts quiver and main")
	check(I.consume_ammo(s, 2), "consume two arrows")
	eq(I.quiver_count(s), 338, "shots draw from the quiver first")
	eq(quiver_counts(s), "100,100,100,38,0", "normalized after a shot")
	local empty = new_player("q2", nil, 1)
	join(empty)
	choose_class(empty, "scout")
	I.consume_ammo(empty, 200)
	eq(I.quiver_count(empty), 0, "quiver emptied")
	put_main(empty, 1, "grug_gear:arrow 5")
	check(I.consume_ammo(empty, 1), "then main")
	eq(empty.inv:get_stack("main", 1):get_count(), 4, "main arrow used")
	check(not I.consume_ammo(empty, 10), "not enough arrows")
	I.refund_ammo(empty, 1)
	eq(I.quiver_count(empty), 1, "refund goes to the quiver first")

	-- Pickup: quiver first while it has room.
	local picker = new_player("q3", nil, 1)
	join(picker)
	choose_class(picker, "scout")
	I.add_to_quiver(picker, ItemStack("grug_gear:arrow 280"))
	eq(I.quiver_count(picker), 480, "quiver at 480")
	local result
	for _, f in ipairs(callbacks.pickup) do
		result = f(ItemStack("grug_gear:arrow 50"), picker)
		if result then break end
	end
	eq(I.quiver_count(picker), 500, "pickup fills the quiver")
	check(result and result:is_empty(), "pickup leftover went to main")
	eq(picker.inv:get_stack("main", 1):get_count(), 30, "30 arrows in main")
	local apple_result
	for _, f in ipairs(callbacks.pickup) do apple_result = f(ItemStack("t:apple"), picker) end
	eq(apple_result, nil, "other pickups untouched")
end

do
	-- Non-Scouts have no quiver: nothing enters it, pickup goes to main.
	local w = new_player("n1", nil, 1)
	join(w)
	choose_class(w, "warrior")
	eq(w.inv:get_stack(W, 1):get_name(), "grug_gear:sword_bronze", "warrior starter sword")
	check(w.inv:get_stack(O, 1):is_empty(), "warrior starts without an offhand")
	eq(I.quiver_count(w), 0, "warrior has no starter arrows")
	put_main(w, 2, "grug_gear:arrow 20")
	move(w, "main", 2, Q, 1, 20)
	eq(I.quiver_count(w), 0, "warrior cannot fill a quiver")
	eq(I.add_to_quiver(w, ItemStack("grug_gear:arrow 5")):get_count(), 5,
		"add_to_quiver refuses a non-Scout")
	local result
	for _, f in ipairs(callbacks.pickup) do result = f(ItemStack("grug_gear:arrow 5"), w) end
	eq(result, nil, "warrior pickup is builtin's")
	local m = new_player("n2", nil, 1)
	join(m)
	choose_class(m, "mage")
	eq(m.inv:get_stack(W, 1):get_name(), "grug_gear:staff_bronze", "mage starter staff")
end

-- The raw-weapon hint (a weapon swung from the hotbar): one message-feed
-- line on a fresh press, none in chat, at most once per 3 s (Round 32 F3).
do
	local p = new_player("raw", "warrior", 30)
	join(p)
	local dig = false
	function p:get_player_control() return {dig = dig} end
	function p:get_wielded_item() return ItemStack("grug_gear:sword_steel") end
	connected = {p}
	local chat_before = #chat
	local function step(pressed)
		dig = pressed
		for _, f in ipairs(callbacks.globalstep) do f(0.1) end
	end
	feed_lines = {}
	mono = 100
	step(true)
	eq(#feed_lines, 1, "raw weapon press: one feed line")
	check(feed_lines[1] and feed_lines[1].text:find("hand slots", 1, true) and
		feed_lines[1].kind == "notice" and feed_lines[1].key == "weapon_hint" and
		#feed_lines[1].text <= 66, "raw weapon hint: one short keyed notice line")
	step(true)
	step(false)
	mono = 101
	step(true)
	eq(#feed_lines, 1, "raw weapon hint: no repeat within 3 s")
	step(false)
	mono = 104
	step(true)
	eq(#feed_lines, 2, "raw weapon hint: a fresh press after 3 s repeats it")
	eq(#chat, chat_before, "raw weapon hint: nothing in chat")
	connected = {}
end

-- Startup audit: every class has rules and an accepted starter kit.
logs = {}
for _, f in ipairs(callbacks.mods_loaded) do f() end
local audit_error = false
for _, line in ipairs(logs) do
	if line:find("^error") then audit_error = true; print(line) end
end
check(not audit_error, "starter audit clean")

print(("r28 A7 slots portable test: %d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
print("RESULT PASS")
