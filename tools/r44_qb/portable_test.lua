-- Round 44 lane QB portable test (LuaJIT): the quickbar on E
-- (round44-plan.md §4.9, ui-crafting-rework-plan.md ruling 9 and §3.5).
-- Loads the REAL grug_keys, grug_quickbar, grug_mounts (catalog, state,
-- entity, items, trainer, shipwright), grug_traders/potion.lua,
-- grug_alchemy/effects.lua and grug_home/travel.lua under a minimal engine
-- stub:
--   A. the window's content per owned mounts and boats and belt contents:
--      one button per owned tier with its model icon, the ridden tier
--      framed, item buttons only for filled belt slots (the count in the
--      item string), Return home with a home only; its size and place;
--   B. opening: the rising edge of aux1 sends the window once; held, zoom,
--      dead and character creation send nothing;
--   C. a belt click drinks once through the potion's own on_use (the
--      vendor potion, an alchemy potion, an elixir) and respects the shared
--      potion cooldown; the stack shrinks in the belt; an emptied slot has
--      no button; a click acts once and closes; stale and unopened clicks
--      do nothing;
--   D. summon and dismount through grug_mounts.toggle with its gates
--      (combat, a boat out of water, a tier not owned);
--   E. Return home through grug_home.return_home with its gates (combat,
--      the cooldown) and the travel request when ready;
--   F. no mount item handed out on purchase or join, an old item left as it
--      is, the retired item inert, the "Press E" tip in both dialogues;
--   G. the window's bytes (printed, a comparison only).
--
--   luajit tools/r44_qb/portable_test.lua [REPO]
-- Prints "R44 QB PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. part .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. part .. ")")
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
vector = {
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

-- ItemStack double: a name and a count; "name count" strings like the engine.
local Stack = {}
Stack.__index = Stack
function ItemStack(value)
	if type(value) == "table" then return setmetatable({name = value.name, count = value.count}, Stack) end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)")
	count = tonumber(count) or 1
	if name == "" then count = 0 end
	return setmetatable({name = name, count = count}, Stack)
end
function Stack:is_empty() return self.name == "" or self.count <= 0 end
function Stack:get_name() return self:is_empty() and "" or self.name end
function Stack:get_count() return self:is_empty() and 0 or self.count end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	self.count = self.count - n
	if self.count <= 0 then self.name, self.count = "", 0 end
	return ItemStack(self.name .. " " .. n)
end
function Stack:to_string()
	if self:is_empty() then return "" end
	return self.count > 1 and (self.name .. " " .. self.count) or self.name
end

local world = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function node_at(pos)
	local x, y, z = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
	return world[key(x, y, z)] or (y < 0 and "default:dirt" or "air")
end

local serial, chat, shown, afters, emerges = {}, {}, {}, {}, {}
local callbacks = {hp = {}, die = {}, leave = {}, join = {}, shutdown = {}, fields = {},
	globalstep = {}}
local registered_entities, registered_items = {}, {}
local connected = {}

core = {
	registered_nodes = {
		air = {walkable = false, liquidtype = "none"},
		["default:dirt"] = {walkable = true, liquidtype = "none"},
		["default:water_source"] = {walkable = false, liquidtype = "source", groups = {water = 3}},
	},
	registered_items = registered_items,
	registered_entities = registered_entities,
	get_item_group = function(name, group)
		local def = core.registered_nodes[name] or registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_node_or_nil = function(pos) return {name = node_at(pos)} end,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	register_entity = function(name, def) registered_entities[name] = def end,
	register_craftitem = function(name, def) registered_items[name] = def end,
	register_on_player_hpchange = function(fn) callbacks.hp[#callbacks.hp + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_shutdown = function(fn) callbacks.shutdown[#callbacks.shutdown + 1] = fn end,
	register_on_player_receive_fields = function(fn) callbacks.fields[#callbacks.fields + 1] = fn end,
	register_globalstep = function(fn) callbacks.globalstep[#callbacks.globalstep + 1] = fn end,
	chat_send_player = function(name, text) chat[#chat + 1] = {name = name, text = text} end,
	show_formspec = function(name, formname, fs) shown[#shown + 1] = {name = name, formname = formname, fs = fs} end,
	close_formspec = function(name, formname) core.show_formspec(name, formname, "") end,
	formspec_escape = function(text) return (tostring(text):gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text .. "(c@#ffffff)" end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_player_window_information = function() return nil end,
	after = function(delay, fn, ...) afters[#afters + 1] = {delay = delay, fn = fn, args = {...}} end,
	emerge_area = function(a, b, fn) emerges[#emerges + 1] = {a = a, b = b, fn = fn} end,
	get_connected_players = function() return connected end,
	get_modpath = function(mod)
		local packs = {grug_quickbar = "PLAYER", grug_mounts = "PLAYER", grug_keys = "PLAYER"}
		return ROOT .. "/mods/" .. (packs[mod] or "PLAYER") .. "/" .. mod
	end,
	get_current_modname = function() return "grug_mounts" end,
	log = function() end,
}
local players = {}
core.get_player_by_name = function(name) return players[name] end

-- Entity ObjectRefs (the mount controller and its visual).
local function new_object(pos, name, staticdata)
	local def = registered_entities[name]
	local object = {pos = copy(pos), velocity = {x = 0, y = 0, z = 0}, valid = true, props = {}}
	local entity = setmetatable({object = object, name = name}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:set_pos(p) self.pos = copy(p) end
	function object:get_velocity() return copy(self.velocity) end
	function object:set_velocity(v) self.velocity = copy(v) end
	function object:set_acceleration() end
	function object:set_yaw(y) self.yaw = y end
	function object:get_yaw() return self.yaw or 0 end
	function object:is_valid() return self.valid end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:set_armor_groups() end
	function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function object:get_properties() return self.props end
	function object:set_attach(parent) self.parent = parent end
	function object:get_attach() return self.parent end
	function object:set_animation() end
	if entity.on_activate then entity.on_activate(entity, staticdata, 0) end
	if not object.valid then return nil end
	return object
end
core.add_entity = function(pos, name, staticdata) return new_object(pos, name, staticdata) end

-- A player with a real-looking inventory: named lists of stacks.
local function make_player(name, faction, race)
	local player = {name = name, pos = {x = 0, y = 0.5, z = 0}, hp = 20, hp_max = 100,
		meta = {}, bits = 0, faction = faction, race = race, lists = {}, writes = 0}
	local lists = player.lists
	for _, list in ipairs({"main", "grug_potion_belt", "grug_bag1_content"}) do
		lists[list] = {}
		local size = list == "main" and 32 or (list == "grug_potion_belt" and 4 or 8)
		for i = 1, size do lists[list][i] = ItemStack("") end
	end
	local inv = {}
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack)
		player.writes = player.writes + 1
		lists[list][i] = ItemStack(stack)
	end
	function inv:get_lists() return lists end
	function player:get_inventory() return inv end
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_pos()
		if self.parent and self.parent:is_valid() then return self.parent:get_pos() end
		return copy(self.pos)
	end
	function player:set_pos(p) self.pos = copy(p) end
	function player:get_hp() return self.hp end
	function player:set_attach(parent) self.parent = parent end
	function player:set_detach() self.parent = nil end
	function player:get_attach() return self.parent end
	function player:set_eye_offset() end
	function player:set_properties(p) self.props = p end
	function player:get_properties() return {visual_size = {x = 1, y = 1}, hp_max = self.hp_max} end
	function player:get_look_horizontal() return 0 end
	function player:get_player_control() return {} end
	function player:get_player_control_bits() return self.bits end
	function player:hud_remove() end
	function player:get_meta()
		local meta = self.meta
		return {
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = v end,
			get_string = function(_, k) return meta[k] ~= nil and tostring(meta[k]) or "" end,
			set_string = function(_, k, v) meta[k] = v end,
		}
	end
	players[name] = player
	connected[#connected + 1] = player
	return player
end

------------------------------------------------------------------------------
-- Game stubs.
------------------------------------------------------------------------------
grug_sounds = {play = function() return false end}
player_api = {player_attached = {}, set_animation = function() end}
local combat, feed_lines, statuses = {}, {}, {}
grug_core = {
	FLIGHT_CEILING = 600,
	is_max_hp_clamp = function() return false end,
	FLASH_COLOR = {error = 1, notice = 2},
	in_combat = function(player) return combat[player:get_player_name()] == true end,
	set_status = function(player, id, def) statuses[player:get_player_name() .. ":" .. id] = def end,
	clear_status = function(player, id) statuses[player:get_player_name() .. ":" .. id] = nil end,
	flash = function() end,
	hud_layout = {anchors = {flight_warning = {}}, flight_warning_offset = function() return {} end},
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), text = text, key = key}
		return true
	end,
	heal_player = function(_, target, amount)
		target.hp = math.min(target.hp_max, target.hp + amount)
	end,
	can_use_item_level = function() return true end,
	release_movement = function() end,
	hold_movement = function() end,
	get_player_race = function(name) return players[name] and players[name].race end,
	settlement_sockets_at = function() return {} end,
}
grug_zones = {
	water_class_at = function() return "land" end,
	terrain_height_at = function() return 0 end,
}
grug_factions = {
	get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function() end,
}
grug_classes = {
	get_race = function(player) return player.race end,
	register_on_race_chosen = function() end,
	get_max_hp = function(player) return player.hp_max end,
	get_max_mana = function() return 0 end,
}
local level = 60
grug_xp = {get_level = function() return level end}
local money = 0
grug_money = {
	take = function(_, amount) if money < amount then return false end money = money - amount return true end,
	format = function(c) return c .. " copper" end,
}
grug_mobs = {register_start_socket_role = function() end, clear_poison = function() return false end}
grug_abilities = {restore_mana = function() end}
local suspended = {}
sfinv = {inventory_suspended = function(player) return suspended[player:get_player_name()] == true end}
local homes = {}
grug_inventory = {
	BAG_COUNT = 1, equipment_slots = {},
	content_list = function(i) return "grug_bag" .. i .. "_content" end,
	POTION_BELT = "grug_potion_belt", POTION_BELT_SIZE = 4,
	-- The Character tab's line (pages.lua home_state): label and state.
	home_state = function(player)
		local home = grug_home.get(player)
		if not home then return nil end
		local remaining = grug_home.remaining(player)
		return home.label, grug_home.is_pending(player) and "Preparing arrival" or
			(remaining > 0 and ("%d min"):format(math.ceil(remaining / 60)) or "Ready")
	end,
}
grug_home = {
	get = function(player)
		local home = homes[player:get_player_name()]
		return home and copy(home) or nil
	end,
	innkeeper = function() return nil end,
}

local function load(path) dofile(ROOT .. "/" .. path) end
grug_traders = {}
load("mods/ENTITIES/grug_traders/potion.lua")
grug_alchemy = {}
load("mods/ITEMS/grug_alchemy/effects.lua")
grug_alchemy.register_consumable("potion_healing_t1", {family = "potion", tier = 1,
	description = "Healing Potion I", on_use = grug_alchemy.potion_use("health", 50)})
grug_alchemy.register_consumable("elixir_vigor_t1", {family = "elixir", tier = 1,
	description = "Elixir of Vigor I", on_use = grug_alchemy.elixir_use({label = "Vigor",
		modifier = "hp_pool_percent", value = 2, duration = 600})})
registered_items["default:torch"] = {groups = {}, on_use = function() return nil end}
grug_mounts = {}
load("mods/PLAYER/grug_mounts/catalog.lua")
load("mods/PLAYER/grug_mounts/state.lua")
load("mods/PLAYER/grug_mounts/entity.lua")
load("mods/PLAYER/grug_mounts/items.lua")
load("mods/PLAYER/grug_mounts/trainer.lua")
load("mods/PLAYER/grug_mounts/shipwright.lua")
load("mods/PLAYER/grug_home/travel.lua")
load("mods/PLAYER/grug_keys/init.lua")
load("mods/PLAYER/grug_quickbar/init.lua")

local FORMNAME = grug_quickbar.FORMNAME
local function step()
	for _, fn in ipairs(callbacks.globalstep) do fn(0.05) end
end
local function press(player, bits)
	player.bits = bits
	step()
end
local function last_shown() return shown[#shown] end
local function click(player, fields, formname)
	for _, fn in ipairs(callbacks.fields) do
		if fn(player, formname or FORMNAME, fields) then return true end
	end
	return false
end
local function last_chat() return chat[#chat] and chat[#chat].text end
local function last_feed() return feed_lines[#feed_lines] and feed_lines[#feed_lines].text end
local function count_buttons(fs, kind)
	local n = 0
	for _ in fs:gmatch(kind .. "%[") do n = n + 1 end
	return n
end
local function size_of(fs)
	local w, h = fs:match("size%[([%d%.]+),([%d%.]+)%]")
	return tonumber(w), tonumber(h)
end
local function closed_after(player, from)
	for index = from + 1, #shown do
		local form = shown[index]
		if form.name == player.name and form.formname == FORMNAME and form.fs == "" then return true end
	end
	return false
end

------------------------------------------------------------------------------
-- A. The window's content.
------------------------------------------------------------------------------
local ada = make_player("ada", "accord", "human")
local fs = grug_quickbar.formspec(ada)
has(fs, "formspec_version[6]", "real coordinates")
has(fs, "position[0.02,0.5]anchor[0,0.5]", "the window sits on the left")
has(fs, "label[0.375,0.45;Quickbar]", "title")
has(fs, "No mounts or boats yet.", "no mount: the empty line")
eq(count_buttons(fs, "image_button"), 0, "no mount: no mount button")
eq(count_buttons(fs, "item_image_button"), 0, "empty belt: no item button")
eq(count_buttons(fs, "box"), 4, "empty belt: four empty slots drawn")
lacks(fs, "grug_quickbar_home", "no home: no Return home button")
has(fs, "Click to use\\; the window closes.", "the hint")
local w, h = size_of(fs)
eq(w, 5.5, "four inventory slots wide")
check(h and h > 4 and h < 7, "roughly square without a home: " .. tostring(h))

ada.meta["grug_mounts:land_tier"] = 2
ada.meta["grug_mounts:water_tier"] = 6
ada.lists.grug_potion_belt[1] = ItemStack("grug_traders:potion_healing_weak 3")
ada.lists.grug_potion_belt[3] = ItemStack("grug_alchemy:elixir_vigor_t1")
ada.lists.grug_potion_belt[4] = ItemStack("default:torch") -- never in a belt; not offered
homes.ada = {label = "Highcourt Inn"}
fs = grug_quickbar.formspec(ada)
lacks(fs, "No mounts or boats yet.", "mounts owned: no empty line")
eq(count_buttons(fs, "item_image_button"), 2, "two filled belt slots: two item buttons")
eq(count_buttons(fs, "image_button") - 2, 4, "four owned tiers: four mount buttons")
for _, tier in ipairs({1, 2, 5, 6}) do has(fs, ";grug_quickbar_mount_" .. tier .. ";]", "tier " .. tier .. " button") end
for _, tier in ipairs({3, 4}) do lacks(fs, "grug_quickbar_mount_" .. tier, "tier " .. tier .. " not owned: no button") end
has(fs, "image_button[0.375,1.300;1,1;grug_mounts_icon_t1_accord.png;grug_quickbar_mount_1;]",
	"tier 1: the faction's Courser icon in the first slot")
has(fs, "image_button[1.625,1.300;1,1;grug_mounts_icon_human.png;grug_quickbar_mount_2;]",
	"tier 2: the race mount's icon, one slot pitch (1.25) further")
has(fs, "grug_mounts_icon_boat.png;grug_quickbar_mount_5", "the Boat's icon")
has(fs, "grug_mounts_icon_improved_boat.png;grug_quickbar_mount_6", "the Improved Boat's icon")
has(fs, "tooltip[grug_quickbar_mount_2;Highcourt Charger\nJourneyman Riding — 8 nodes/s]",
	"tooltip: model, tier and speed")
has(fs, "item_image_button[0.375,", "belt slot 1 at the left edge")
has(fs, ";grug_traders:potion_healing_weak 3;grug_quickbar_belt_1;]", "belt 1: the count in the item string")
has(fs, ";grug_alchemy:elixir_vigor_t1;grug_quickbar_belt_3;]", "belt 3: the elixir")
lacks(fs, "grug_quickbar_belt_2", "empty belt slot 2: nothing clickable")
lacks(fs, "grug_quickbar_belt_4", "a non-potion in the belt: nothing clickable")
has(fs, "label[0.375,", "labels at the padding")
has(fs, "Home: Highcourt Inn", "the home's name")
has(fs, "grug_quickbar_home;Return home (Ready)]", "Return home with its state")
lacks(fs, "Click to dismount.", "on foot: no dismount line")
lacks(fs, "#7ae08a", "on foot: no ridden frame")
local w2, h2 = size_of(fs)
eq(w2, 5.5, "width unchanged")
check(h2 and h2 > 6 and h2 < 8, "one mount row and a home: about square (" .. tostring(h2) .. ")")

-- Five owned tiers: a second row.
ada.meta["grug_mounts:flight_tier"] = 3
fs = grug_quickbar.formspec(ada)
eq(count_buttons(fs, "image_button") - 2, 5, "five owned tiers: five mount buttons")
has(fs, "image_button[0.375,2.550;1,1;grug_mounts_icon_improved_boat.png;grug_quickbar_mount_6;]",
	"the fifth button opens a second row")
local _, h3 = size_of(fs)
check(h3 and math.abs(h3 - h2 - 1.25) < 1e-6, "the second row adds one slot pitch")
ada.meta["grug_mounts:flight_tier"] = nil

-- The Throng's Courser for a Throng character.
local orc = make_player("orc", "throng", "orc")
orc.meta["grug_mounts:land_tier"] = 1
has(grug_quickbar.formspec(orc), "grug_mounts_icon_t1_throng.png;grug_quickbar_mount_1",
	"the Throng's Courser icon")

------------------------------------------------------------------------------
-- B. Opening on the rising edge of aux1.
------------------------------------------------------------------------------
local before = #shown
step() -- every player's first step only records
press(ada, 32)
eq(#shown, before + 1, "E: one send")
eq(last_shown().formname, FORMNAME, "E: the quickbar")
eq(last_shown().fs, grug_quickbar.formspec(ada), "E: the window as built")
press(ada, 32)
press(ada, 32)
eq(#shown, before + 1, "E held: no second send")
press(ada, 0)
press(ada, 512)
eq(#shown, before + 1, "Z does not open the quickbar")
press(ada, 0)
press(ada, 32)
eq(#shown, before + 2, "E pressed again: one more send")
press(ada, 0)
ada.hp = 0
press(ada, 32)
eq(#shown, before + 2, "dead: nothing opens")
press(ada, 0)
ada.hp = 20
suspended.ada = true
press(ada, 32)
eq(#shown, before + 2, "character creation: nothing opens")
press(ada, 0)
suspended.ada = nil

------------------------------------------------------------------------------
-- C. The potion belt.
------------------------------------------------------------------------------
local function open_bar(player)
	check(grug_quickbar.open(player), "opened for " .. player.name)
	return #shown
end
ada.hp = 10
local mark = open_bar(ada)
local writes = ada.writes
check(click(ada, {grug_quickbar_belt_1 = ""}), "the click is the quickbar's")
eq(ada.hp, 10 + grug_traders.POTION_HEAL_AMOUNT, "the vendor potion healed once")
eq(ada.lists.grug_potion_belt[1]:to_string(), "grug_traders:potion_healing_weak 2", "the belt stack shrank")
eq(ada.writes, writes + 1, "one inventory write")
check(grug_traders.potion_cooldown_left(ada) > 0, "the shared cooldown runs")
check(closed_after(ada, mark), "the click closed the window")
-- The close's quit and a second click of the closed window change nothing.
click(ada, {quit = "true"})
click(ada, {grug_quickbar_belt_1 = ""})
eq(ada.lists.grug_potion_belt[1]:get_count(), 2, "a click after the close drinks nothing")
-- On cooldown: refused by the potion, the stack stays, the window closes.
ada.hp = 5
mark = open_bar(ada)
click(ada, {grug_quickbar_belt_1 = ""})
eq(ada.hp, 5, "on cooldown: no heal")
eq(ada.lists.grug_potion_belt[1]:get_count(), 2, "on cooldown: the stack stays")
has(last_chat(), "You cannot drink another potion for", "the vendor potion's own refusal")
check(closed_after(ada, mark), "a refused click closes too")
-- An alchemy potion shares the clock and refuses through the feed.
ada.lists.grug_potion_belt[2] = ItemStack("grug_alchemy:potion_healing_t1 2")
open_bar(ada)
click(ada, {grug_quickbar_belt_2 = ""})
eq(ada.lists.grug_potion_belt[2]:get_count(), 2, "alchemy potion on the shared cooldown: kept")
has(last_feed(), "You cannot drink another potion for", "the alchemy potion's feed refusal")
-- Cooldown over: the alchemy potion heals.
ada.meta["grug_traders:potion_cd"] = tostring(os.time() - 1)
open_bar(ada)
click(ada, {grug_quickbar_belt_2 = ""})
eq(ada.hp, 5 + 50, "the alchemy potion healed")
eq(ada.lists.grug_potion_belt[2]:get_count(), 1, "the alchemy stack shrank")
-- The elixir: no potion cooldown, consumed, the slot empties.
open_bar(ada)
click(ada, {grug_quickbar_belt_3 = ""})
check(ada.lists.grug_potion_belt[3]:is_empty(), "the last elixir is used: the slot is empty")
check(statuses["ada:elixir"] ~= nil, "the elixir's effect runs")
lacks(grug_quickbar.formspec(ada), "grug_quickbar_belt_3", "the emptied slot has no button")
-- A stale click on an empty slot and a click without an opened window.
open_bar(ada)
writes = ada.writes
click(ada, {grug_quickbar_belt_3 = ""})
eq(ada.writes, writes, "a click on an empty slot writes nothing")
ada.meta["grug_traders:potion_cd"] = tostring(os.time() - 1)
ada.hp = 5
click(ada, {grug_quickbar_belt_1 = ""})
eq(ada.hp, 5, "no window open: the click drinks nothing")
-- Esc ends the window.
open_bar(ada)
click(ada, {quit = "true"})
click(ada, {grug_quickbar_belt_1 = ""})
eq(ada.hp, 5, "after Esc: the click drinks nothing")
-- One click acts once: two fields in one event drink one potion.
open_bar(ada)
click(ada, {grug_quickbar_belt_1 = "", grug_quickbar_belt_2 = ""})
eq(ada.lists.grug_potion_belt[1]:get_count() + ada.lists.grug_potion_belt[2]:get_count(), 2,
	"one potion for one click")
check(not click(ada, {grug_quickbar_belt_1 = ""}, "grug_other:form"), "another form's fields are not the quickbar's")

------------------------------------------------------------------------------
-- D. Mounts and boats.
------------------------------------------------------------------------------
local bo = make_player("bo", "accord", "elf")
bo.meta["grug_mounts:land_tier"] = 2
bo.meta["grug_mounts:water_tier"] = 5
mark = open_bar(bo)
click(bo, {grug_quickbar_mount_2 = ""})
check(grug_mounts.is_mounted(bo), "the button summons the mount")
eq(grug_mounts.active.bo.tier, 2, "the clicked tier")
check(closed_after(bo, mark), "the mount click closed the window")
fs = grug_quickbar.formspec(bo)
has(fs, "#7ae08a", "the ridden tier is framed")
has(fs, "Silverleaf Stag\nJourneyman Riding — 8 nodes/s\nClick to dismount.", "the ridden tier's tooltip")
open_bar(bo)
click(bo, {grug_quickbar_mount_2 = ""})
check(not grug_mounts.is_mounted(bo), "the ridden tier's button dismounts")
-- Combat gate.
combat.bo = true
open_bar(bo)
click(bo, {grug_quickbar_mount_1 = ""})
check(not grug_mounts.is_mounted(bo), "in combat: no mount")
eq(last_feed(), "You cannot mount while in combat.", "the combat refusal")
combat.bo = nil
-- The boat's water gate.
open_bar(bo)
click(bo, {grug_quickbar_mount_5 = ""})
check(not grug_mounts.is_mounted(bo), "a boat on land: refused")
has(last_feed(), "water", "the boat's water refusal")
-- In water the boat comes.
world[key(0, 0, 0)] = "default:water_source"
bo.pos = {x = 0, y = 0, z = 0}
open_bar(bo)
click(bo, {grug_quickbar_mount_5 = ""})
check(grug_mounts.is_mounted(bo) and grug_mounts.active.bo.mode == "water", "in water: the boat")
grug_mounts.dismount(bo, nil, true)
world[key(0, 0, 0)] = nil
bo.pos = {x = 0, y = 0.5, z = 0}
-- A tier not owned: nothing.
open_bar(bo)
click(bo, {grug_quickbar_mount_4 = ""})
check(not grug_mounts.is_mounted(bo), "a tier not owned: nothing")

------------------------------------------------------------------------------
-- E. Return home.
------------------------------------------------------------------------------
homes.bo = {id = "lethariel_inn", label = "Lethariel Inn", pos = {x = 100, y = 5, z = 100},
	arrival = {x = 101, y = 4.51, z = 100}}
combat.bo = true
mark = open_bar(bo)
click(bo, {grug_quickbar_home = ""})
eq(last_chat(), "Cannot return home in combat.", "Return home: the combat gate")
eq(#emerges, 0, "in combat: no travel")
check(closed_after(bo, mark), "the Return home click closed the window")
combat.bo = nil
bo.meta["grug_home:ready_at"] = tostring(os.time() + 600)
has(grug_quickbar.formspec(bo), "Return home (10 min)", "the cooldown on the button")
open_bar(bo)
click(bo, {grug_quickbar_home = ""})
eq(last_chat(), "Return home is cooling down.", "Return home: the cooldown gate")
eq(#emerges, 0, "on cooldown: no travel")
bo.meta["grug_home:ready_at"] = nil
open_bar(bo)
click(bo, {grug_quickbar_home = ""})
eq(#emerges, 1, "ready: the travel prepares the home's area")
check(grug_home.is_pending(bo), "ready: a return is under way")
has(grug_quickbar.formspec(bo), "Return home (Preparing arrival)", "the running return on the button")

------------------------------------------------------------------------------
-- F. No mount items.
------------------------------------------------------------------------------
check(grug_mounts.stack_for == nil and grug_mounts.reconcile_items == nil,
	"no mount-item builder or refresh left")
local function mount_items(player)
	local n = 0
	for _, list in pairs(player.lists) do
		for _, stack in ipairs(list) do
			local def = registered_items[stack:get_name()]
			if def and def._grug_mount_tier then n = n + 1 end
		end
	end
	return n
end
local cy = make_player("cy", "accord", "dwarf")
level, money = 60, 1000000
local cy_writes = cy.writes
local ok, message = grug_mounts.purchase(cy, 1)
check(ok, "Apprentice Riding bought")
eq(message, "Apprentice Riding learned.", "the purchase line (the tip is the dialogue's)")
ok, message = grug_mounts.purchase(cy, 5)
eq(message, "Boat bought.", "the boat's purchase line")
local answered = grug_mounts.trainer_formspec({{id = 5, name = "Boat", level = 15, state = "owned"}},
	{ok = true, text = message}, grug_mounts.SERVICES.shipwright)
local said = 0
for _ in answered:gmatch("Press E to open your mounts") do said = said + 1 end
eq(said, 1, "after a purchase the dialogue says the tip once")
for _, fn in ipairs(callbacks.join) do fn(cy) end
for _, record in ipairs(afters) do
	if record.delay == 0 then record.fn(unpack(record.args)) end
end
eq(mount_items(cy), 0, "no mount item after purchase and join")
eq(cy.writes, cy_writes, "purchase and join write no inventory")
has(grug_quickbar.formspec(cy), "grug_quickbar_mount_5", "the bought boat is in the quickbar")
-- An old stack from an earlier version stays as it is until the migration.
cy.lists.main[12] = ItemStack("grug_mounts:apprentice_mount")
cy_writes = cy.writes
for _, fn in ipairs(callbacks.join) do fn(cy) end
for _, record in ipairs(afters) do
	if record.delay == 0 then record.fn(unpack(record.args)) end
end
eq(cy.lists.main[12]:get_name(), "grug_mounts:apprentice_mount", "an old mount item stays")
eq(cy.writes, cy_writes, "join leaves the old stack unwritten")
for tier_id, tier in ipairs(grug_mounts.TIERS) do
	local def = registered_items[tier.item]
	check(def and def.on_use == nil and def.on_secondary_use == nil and def.on_place == nil,
		tier.name .. ": the retired item stays registered and does nothing")
	check(def and def.groups.grug_bound_skill == 1 and def.on_drop().name == "",
		tier.name .. ": still bound, a drop deletes it")
	eq(def and def.inventory_image, tier.icon, tier.name .. ": its icon")
	eq(def and def._grug_mount_tier, tier_id, tier.name .. ": its tier")
end
-- The tip in both dialogues.
local rows = {{id = 1, name = "Apprentice Riding", level = 15, state = "owned"}}
has(grug_mounts.trainer_formspec(rows, nil), "label[0.4,5.45;Press E to open your mounts.]",
	"the Riding Trainer's tip")
has(grug_mounts.trainer_formspec(rows, nil, grug_mounts.SERVICES.shipwright),
	"label[0.4,5.45;Press E to open your mounts.]", "the Shipwright's tip")
local tip_count = 0
for _, path in ipairs({"catalog.lua", "state.lua", "items.lua", "trainer.lua", "shipwright.lua"}) do
	local file = assert(io.open(ROOT .. "/mods/PLAYER/grug_mounts/" .. path))
	local text = file:read("*a")
	file:close()
	for _ in text:gmatch("Press E") do tip_count = tip_count + 1 end
end
eq(tip_count, 1, "one wording of the tip in grug_mounts")

------------------------------------------------------------------------------
-- G. Bytes (a comparison only).
------------------------------------------------------------------------------
local full = make_player("full", "accord", "human")
full.meta["grug_mounts:land_tier"] = 2
full.meta["grug_mounts:flight_tier"] = 4
full.meta["grug_mounts:water_tier"] = 6
for i = 1, 4 do full.lists.grug_potion_belt[i] = ItemStack("grug_alchemy:potion_healing_t1 20") end
homes.full = {label = "Highcourt Inn"}
local small = make_player("small", "accord", "human")
small.meta["grug_mounts:land_tier"] = 1
small.lists.grug_potion_belt[1] = ItemStack("grug_traders:potion_healing_weak 5")
homes.small = {label = "Highcourt Inn"}
print(("bytes: quickbar, six tiers, four potions, a home: %d"):format(#grug_quickbar.formspec(full)))
print(("bytes: quickbar, one tier, one potion, a home: %d"):format(#grug_quickbar.formspec(small)))

if failures > 0 then
	print(("%d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("R44 QB PORTABLE PASS checks=%d"):format(checks))
