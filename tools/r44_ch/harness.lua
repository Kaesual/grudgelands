-- Round 44 lane CH harness: loads the REAL vendored sfinv, grug_inventory's
-- equipment.lua, bags.lua (with storage.lua), ui.lua and pages.lua, the REAL
-- grug_gear permissions, grug_achievements and grug_jobs' Character-page
-- body under a minimal `core` stub, plus a small model of the engine's
-- inventory move (IMoveAction::apply: fit, swap, the allow limits, and
-- move_somewhere for shift-click, which follows the formspec's listring like
-- guiFormSpecMenu.cpp getNextInventoryRing). Used by portable_test.lua and
-- bytes.lua; works against an older tree too (bytes.lua's "before").
--
-- Usage: local H = dofile("tools/r44_ch/harness.lua")(repo)

return function(repo)
local H = {feed = {}, sounds = {}, equipment_changes = 0, logs = {}}

--
-- Engine surface
--

local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
end
H.fs_escape = fs_escape

local callbacks = {allow = {}, action = {}, join = {}, mods_loaded = {},
	receive = {}, class_chosen = {}}
local window_info = {}
H.window_info = window_info
core = {
	registered_items = {},
	formspec_escape = fs_escape,
	colorize = function(_, text) return text end,
	strip_colors = function(text) return text end,
	get_current_modname = function() return "grug_inventory" end,
	get_modpath = function(name)
		return repo .. "/mods/PLAYER/" .. (name or "grug_inventory")
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_player_inventory_action = function(f) table.insert(callbacks.action, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.mods_loaded, f) end,
	register_on_player_receive_fields = function(f) table.insert(callbacks.receive, f) end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	log = function(level, text) H.logs[#H.logs + 1] = level .. ": " .. text end,
	get_us_time = function() return 0 end,
	get_connected_players = function() return {} end,
	get_player_window_information = function(name) return window_info[name] end,
	is_creative_enabled = function() return false end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	add_item = function() end,
	after = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
function core.get_item_group(name, group)
	local def = core.registered_items[name]
	return def and def.groups and def.groups[group] or 0
end
minetest = core
dump = function(value) return tostring(value) end

-- ItemStack double: name, count, wear, the definition's stack_max.
local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	local self = setmetatable({}, Stack)
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name, item.count, item.wear or 0
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
function Stack:get_description() return self.name end
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
	local taken = n > 0 and ItemStack(self.name .. " " .. n) or ItemStack("")
	self:set_count(self.count - n)
	return taken
end
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
	return self.count == 1 and self.name or self.name .. " " .. self.count
end
function Stack:get_meta()
	return {get_int = function() return 0 end, get_string = function() return "" end,
		set_string = function() end}
end

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
				if not stack:is_empty() and (l[i]:is_empty() == (pass == 2)) then
					stack = l[i]:add_item(stack)
				end
			end
		end
		return stack
	end
	return inv
end

--
-- Mod surface
--

local mono = 0
H.status_effects = {}
grug_core = {
	mono_time = function() return mono end,
	feed = function(player, kind, text, key)
		H.feed[#H.feed + 1] = {name = player:get_player_name(), text = text, key = key}
		return true
	end,
	notify_equipment_change = function()
		H.equipment_changes = H.equipment_changes + 1
	end,
	equipment_is_broken = function() return false end,
	can_use_item_level = function(player, stack)
		local def = core.registered_items[stack:get_name()]
		local required = def and def._grug_req_level or 1
		return player.level >= required, required, player.level
	end,
	status_modifier_sum = function() return 0 end,
	register_on_equipment_change = function() end,
	register_on_status_modifiers_changed = function() end,
	status_effects = function() return H.status_effects end,
	status_icons = {remaining_text = function(us) return ("%dm"):format(
		math.floor((us or 0) / 60000000)) end},
	armor_reduction = function() return 0.123 end,
	get_player_level = function(player) return player.level end,
	get_player_faction = function() return "accord" end,
	PROTECTION_ARMOR_MULTIPLIER = 1,
}
local CLASSES = {warrior = {name = "Warrior", resource = "rage"},
	scout = {name = "Scout", resource = "mana"}, mage = {name = "Mage", resource = "mana"},
	priest = {name = "Priest", resource = "mana"}}
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
	get_pool_breakdown = function() return {final = 120} end,
	get_crit_chance = function() return 0.05 end,
	get_dodge_chance = function() return 0.05 end,
}
grug_gear = {STARTER_SWORD = "grug_gear:sword_bronze",
	STARTER_STAFF = "grug_gear:staff_bronze", STARTER_BOW = "grug_gear:bow_bronze",
	initialize_weapon_tooltip = function() return false end,
	usable_by = function() return "Usable by: someone" end,
	can_equip_weapon = function() return true end}
dofile(repo .. "/mods/ITEMS/grug_gear/permissions.lua")
grug_xp = {register_on_level_change = function() end,
	get_level = function() return 30 end}
H.withdrawn = 0
grug_money = {
	register_on_change = function() end,
	deposit_location = function(player)
		return "detached:grug_money_deposit_" .. player:get_player_name(), "deposit"
	end,
	format = function(value) return ("%dg %ds %dc"):format(math.floor(value / 10000),
		math.floor(value / 100) % 100, value % 100) end,
	get = function() return 123456 end,
	show_withdraw = function() H.withdrawn = H.withdrawn + 1 end,
}
grug_sounds = {play = function(event) H.sounds[#H.sounds + 1] = event end,
	CLICK_STYLE = ""}
player_api = {registered_models = {["character.b3d"] = {textures = {"character.png"}}}}
-- Return home: a home for every player (grug_home is read at build time).
H.home = {label = "Ironhold Inn", remaining = 0, pending = false}
grug_home = {
	get = function() return H.home.label and {label = H.home.label} or nil end,
	remaining = function() return H.home.remaining end,
	is_pending = function() return H.home.pending end,
	return_home = function() H.home.pending = true end,
}

-- Items in grug_gear's shape (init.lua WEAPONS, armor, shields, spellbooks,
-- trinkets, the arrow).
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
local function item(name, groups, extra)
	local def = {description = name, stack_max = 1, groups = groups}
	for k, v in pairs(extra or {}) do def[k] = v end
	core.registered_items[name] = def
end
item("grug_gear:shield_bronze", {grug_gear = 1, grug_equip_offhand = 1, grug_shield = 1})
item("grug_gear:spellbook_bronze", {grug_gear = 1, grug_equip_offhand = 1, grug_spellbook = 1})
item("grug_gear:head_cloth", {grug_gear = 1, grug_equip_head = 1, grug_armor_class = 1})
item("grug_gear:head_leather", {grug_gear = 1, grug_equip_head = 1, grug_armor_class = 2})
item("grug_gear:head_metal", {grug_gear = 1, grug_equip_head = 1, grug_armor_class = 3})
item("grug_gear:chest_leather", {grug_gear = 1, grug_equip_chest = 1, grug_armor_class = 2})
item("grug_gear:feet_cloth", {grug_gear = 1, grug_equip_feet = 1, grug_armor_class = 1},
	{_grug_req_level = 40})
item("grug_gear:ring_a", {grug_gear = 1, grug_equip_trinket = 1}, {_grug_trinket_identity = "a"})
item("grug_gear:ring_b", {grug_gear = 1, grug_equip_trinket = 1}, {_grug_trinket_identity = "b"})
item("grug_gear:ring_c", {grug_gear = 1, grug_equip_trinket = 1}, {_grug_trinket_identity = "c"})
item("grug_gear:arrow", {grug_arrow = 1}, {stack_max = 100})
item("t:apple", {}, {stack_max = 99})

--
-- The real files
--

grug_inventory = {}
dofile(repo .. "/mods/BASE/sfinv/api.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/equipment.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/bags.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/ui.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/pages.lua")
H.refreshes = 0
local real_set = sfinv.set_player_inventory_formspec
sfinv.set_player_inventory_formspec = function(player, context)
	H.refreshes = H.refreshes + 1
	return real_set(player, context)
end

-- grug_achievements (its seams as tools/r33_c3 stubs them).
grug_jobs = {register_on_award_progress = function() end}
grug_visuals = {register_cloak_source = function() end, apply = function() end}
grug_mobs = {register_on_eligible_kill = function() end,
	register_on_boss_kill = function() end, subtype = function() return nil end,
	registered_cadence = {}}
grug_pvp = {register_on_stat = function() end,
	stats = function() return {guards = 0, kills = 0} end}
core.get_current_modname = function() return "grug_achievements" end
dofile(repo .. "/mods/PLAYER/grug_achievements/init.lua")
core.get_current_modname = function() return "grug_inventory" end

-- grug_jobs' body builder with a fixed overview (four professions; the
-- first capped by the level).
dofile(repo .. "/mods/PLAYER/grug_jobs/character_tab.lua")
grug_jobs.profession_overview = function()
	return {
		{name = "Weaponsmith", tier = 2, crafts = 15, needed = 15, capped = true,
			next_level = 21},
		{name = "Armorsmith", tier = 2, crafts = 3, needed = 15, capped = false,
			next_level = 21},
		{name = "Cooking", tier = 1, crafts = 4, needed = 10, capped = false,
			next_level = 11},
		{name = "Alchemy", tier = 6, crafts = 0, capped = false, next_level = 61},
	}
end

for _, fn in ipairs(callbacks.mods_loaded) do fn() end

--
-- Players
--

-- `bags`: content size per bag slot (0 = no bag).
function H.player(name, class_id, bags, level)
	local inv = new_inventory()
	inv:set_size("main", 32)
	local meta = {}
	local player = {inv = inv, class_id = class_id, level = level or 30, sent = 0}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:is_player() return true end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	function player:get_properties()
		return {visual = "mesh", mesh = "character.b3d", textures = {"character.png"}}
	end
	function player:get_meta()
		return {get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = tostring(v) end,
			get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v ~= "" and v or nil end}
	end
	function player:set_inventory_formspec(fs)
		self.sent = self.sent + 1
		self.formspec = fs
	end
	for _, f in ipairs(callbacks.join) do f(player) end
	for i, size in ipairs(bags or {}) do
		if size > 0 then
			inv:set_stack("grug_bag" .. i, 1, ItemStack(({[8] = "grug_inventory:bag_small",
				[16] = "grug_inventory:bag_medium", [24] = "grug_inventory:bag_large",
				[32] = "grug_inventory:bag_great"})[size]))
			inv:set_size("grug_bag" .. i .. "_content", size)
		end
	end
	return player
end

-- The Character page in `mode` (nil: the page's default), as the client
-- would receive it.
function H.page(player, mode)
	local context = sfinv.get_or_create_context(player)
	context.page = "grug_inventory:character"
	context.grug_character_tab = mode
	H.context = context
	return sfinv.get_formspec(player, context)
end

-- A button or dropdown event on the open page.
function H.click(player, fields)
	for _, f in ipairs(callbacks.receive) do
		if f(player, "", fields) then return true end
	end
	return false
end

--
-- The engine's inventory move within one player inventory
--

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
function H.move(player, from_list, from_i, to_list, to_i, count, somewhere)
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

-- The listring sequence of a formspec, in order: {location, list}.
function H.rings(fs)
	local rings = {}
	for location, list in fs:gmatch("listring%[([^;%]]+);([^%]]+)%]") do
		rings[#rings + 1] = {location = location, list = list}
	end
	return rings
end

-- Shift-click on cell `index` of `list` while `fs` is the open formspec:
-- the engine's getNextInventoryRing (the ring after the FIRST entry naming
-- the list, wrapping), then move_somewhere over the target list (non-empty
-- cells first, then empty ones) with the whole stack. Returns the target
-- list, or nil when the ring has none.
function H.shift(player, fs, list, index)
	local rings = H.rings(fs)
	if #rings < 2 then return nil end
	local target
	for i, ring in ipairs(rings) do
		if ring.location == "current_player" and ring.list == list then
			target = rings[i % #rings + 1]
			break
		end
	end
	if not target then return nil end
	local inv = player.inv
	local amount = inv:get_stack(list, index):get_count()
	for pass = 1, 2 do
		for i = 1, inv:get_size(target.list) do
			local empty = inv:get_stack(target.list, i):is_empty()
			if (pass == 1) ~= empty and amount > 0 and
					not inv:get_stack(list, index):is_empty() then
				amount = amount - H.move(player, list, index, target.list, i,
					amount, true)
			end
		end
	end
	return target.list
end

function H.put(player, list, index, item)
	player.inv:set_stack(list, index, ItemStack(item))
end
function H.get(player, list, index)
	return player.inv:get_stack(list, index):to_string()
end
function H.tick() mono = mono + 10 end

return H
end
