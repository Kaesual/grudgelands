-- Round 48 lane QUEST portable test (LuaJIT; mail plan §6 "QUEST", §3.18-
-- §3.20, round plan §4.11). Loads the REAL grug_quests registry, state,
-- labels and hud files, grug_map's quest_box.lua, the REAL grug_mail (with
-- texts.lua, letters.lua and quest.lua), grug_money and the inventory's give
-- helpers under an engine stub (the one of tools/r48_mail) and checks:
--   R  the system quest kind: registered without NPC and objectives, refused
--      with either, validate_registry passes, no NPC lists or marks it;
--   G  the starter quest's grant: at arrival and at join, once; nothing for
--      a player still creating a character; a full log skips it for good;
--   T  the tracker HUD and the quest log show the system text instead of
--      "Return to <NPC>";
--   O  opening a mailbox turns it in through grug_quests.turn_in: XP and
--      25c, the turn-in listeners, the completion line in the feed; out of
--      reach nothing happens, a full purse refuses and keeps the quest;
--   W  the welcome letter: an admin letter, once per character, with the
--      player's name;
--   L  the level letters: once each, at 15 without a riding tier and at 20
--      while the claim state is "never", both on a jump 14 -> 21, late at a
--      join, {player} and {capital} filled, never when no longer useful.
--
--   luajit tools/r48_quest/portable_test.lua [REPO]
-- Prints "R48 QUEST PORTABLE PASS checks=<n>" or the failures (exit 1).

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
		label .. " (missing " .. ("%q"):format(part) .. ")")
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil,
		label .. " (unexpected " .. ("%q"):format(part) .. ")")
end

local NOW = 1800000000
function table.copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for key, item in pairs(value) do copy[table.copy(key, seen)] = table.copy(item, seen) end
	return setmetatable(copy, getmetatable(value))
end

------------------------------------------------------------------------------
-- Engine stub (tools/r48_mail/portable_test.lua's)
------------------------------------------------------------------------------
-- B-D. Engine stub
------------------------------------------------------------------------------
local callbacks = {allow = {}, action = {}, join = {}, fields = {}, leave = {},
	die = {}, mods_loaded = {}, faction = {}, arrival = {}, level = {}, kill = {}}
local feed_lines, logs, dropped, formspecs, closed = {}, {}, {}, {}, {}
local nodes = {}
local players = {}
local clock = NOW

local function serialize(value)
	local kind = type(value)
	if kind == "string" then return string.format("%q", value) end
	if kind == "number" or kind == "boolean" or kind == "nil" then return tostring(value) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		if type(a) == type(b) then return a < b end
		return type(a) == "number"
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = "[" .. serialize(key) .. "]=" .. serialize(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local mod_storage = {}
local Storage = {}
Storage.__index = Storage
function Storage:get_string(key) return mod_storage[key] or "" end
function Storage:set_string(key, value) mod_storage[key] = value ~= "" and value or nil end
function Storage:get_int(key) return tonumber(mod_storage[key]) or 0 end
function Storage:set_int(key, value) mod_storage[key] = tostring(value) end

core = {
	registered_items = {}, registered_nodes = {}, detached_inventories = {},
	registered_entities = {},
	get_player_window_information = function() return nil end,
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_player_inventory_action = function(f) table.insert(callbacks.action, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_dieplayer = function(f) table.insert(callbacks.die, f) end,
	register_on_player_receive_fields = function(f) table.insert(callbacks.fields, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.mods_loaded, f) end,
	register_craftitem = function(name, def)
		def.groups = def.groups or {}
		core.registered_items[name] = def
	end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do core.registered_items[name][key] = value end
	end,
	create_detached_inventory = function() end,
	register_chatcommand = function() end,
	get_modpath = function(name)
		local dirs = {grug_mail = "PLAYER/grug_mail", grug_inventory = "PLAYER/grug_inventory",
			grug_money = "PLAYER/grug_money", grug_quests = "PLAYER/grug_quests"}
		return ROOT .. "/mods/" .. (dirs[name] or name)
	end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function() return setmetatable({}, Storage) end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		local chunk = loadstring(text)
		if not chunk then return nil end
		setfenv(chunk, {})
		local ok, value = pcall(chunk)
		return ok and value or nil
	end,
	formspec_escape = function(text)
		return (tostring(text):gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	colorize = function(_, text) return text end,
	strip_colors = function(text) return text end,
	is_creative_enabled = function() return false end,
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	add_item = function(_, stack) dropped[#dropped + 1] = ItemStack(stack) end,
	get_player_by_name = function(name)
		local player = players[name]
		return player and player.online and player or nil
	end,
	get_connected_players = function()
		local list = {}
		for _, player in pairs(players) do if player.online then list[#list + 1] = player end end
		return list
	end,
	player_exists = function(name) return players[name] ~= nil end,
	get_node = function(pos)
		return {name = nodes[pos.x .. "," .. pos.y .. "," .. pos.z] or "air"}
	end,
	show_formspec = function(name, formname, text)
		formspecs[name] = {formname = formname, text = text}
	end,
	close_formspec = function(name, formname) closed[#closed + 1] = name .. " " .. formname end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
os.time = function() return clock end
vector = {
	new = function(pos) return {x = pos.x, y = pos.y, z = pos.z} end,
	offset = function(pos, x, y, z) return {x = pos.x + x, y = pos.y + y, z = pos.z + z} end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

-- ItemStack double with name, count, wear and metadata that survives
-- to_string (the engine's item string carries all three).
local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:set_int(key, value) self.fields[key] = tostring(value) end
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
	local name, count, wear, meta = tostring(item or ""):match("^(%S*)%s*(%d*)%s*(%d*)%s*(.*)$")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	self.wear = tonumber(wear) or 0
	for key, value in (meta or ""):gmatch("([^=;]+)=([^;]*)") do self.fields[key] = value end
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
function Stack:get_description()
	local def = core.registered_items[self.name]
	return self.fields.description or (def and def.description) or self.name
end
Stack.get_short_description = Stack.get_description
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count, self.fields, self.wear = "", 0, {}, 0 end
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
function Stack:equals(other)
	other = ItemStack(other)
	if self:is_empty() and other:is_empty() then return true end
	return self.count == other.count and compatible(self, other)
end
function Stack:to_string()
	if self:is_empty() then return "" end
	local meta = meta_string(self.fields)
	return self.name .. " " .. self.count .. " " .. self.wear .. (meta ~= "" and " " .. meta or "")
end

local function new_inventory(owner)
	local inv = {lists = {}}
	function inv:set_size(list, size)
		local old = self.lists[list] or {}
		local new = {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
		return true
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i)
		local l = self.lists[list]
		return ItemStack(l and l[i] or "")
	end
	function inv:set_stack(list, i, stack)
		if not self.lists[list] or i > #self.lists[list] then return false end
		self.lists[list][i] = ItemStack(stack)
		return true
	end
	function inv:get_list(list)
		local l = self.lists[list]
		if not l then return nil end
		local out = {}
		for i = 1, #l do out[i] = ItemStack(l[i]) end
		return out
	end
	function inv:get_lists()
		local out = {}
		for name in pairs(self.lists) do out[name] = self:get_list(name) end
		return out
	end
	function inv:is_empty(list)
		for _, s in ipairs(self.lists[list] or {}) do
			if not s:is_empty() then return false end
		end
		return true
	end
	function inv:contains_item() return false end
	function inv:get_location() return {type = "player", name = owner} end
	return inv
end

core.create_detached_inventory = function(_, _, owner) return new_inventory(owner) end


local hud_texts = {}
local function new_player(name, opts)
	opts = opts or {}
	local inv = new_inventory(name)
	inv:set_size("main", 32)
	local meta = setmetatable({fields = {}}, Meta)
	local player = {inv = inv, meta = meta, online = true, hp = 20,
		pos = opts.pos or {x = 0, y = 10, z = 0}, faction = opts.faction or "accord",
		class_id = opts.class, race = opts.race or "dwarf", level = opts.level or 1,
		tiers = opts.tiers or {}, claim = opts.claim or "never", huds = {}}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return meta end
	function player:is_player() return self.online end
	function player:get_pos() return self.pos end
	function player:get_hp() return self.hp end
	function player:hud_add(def)
		self.huds[#self.huds + 1] = def.text
		return #self.huds
	end
	function player:hud_change(id, key, value)
		if key == "text" then self.huds[id] = value; hud_texts[name] = value end
	end
	players[name] = player
	return player
end
local function join(player)
	player.online = true
	for _, f in ipairs(callbacks.join) do f(player) end
end
local function arrive(player)
	for _, f in ipairs(callbacks.arrival) do f(player) end
end
local function level_change(player, old, new)
	player.level = new
	for _, f in ipairs(callbacks.level) do f(player, old, new) end
end

------------------------------------------------------------------------------
-- Mod surface: stand-ins for what the real files call.
------------------------------------------------------------------------------
local QUEST_POS = {x = 120, y = 10, z = 100}
grug_core = {
	feed = function(player, kind, text, key)
		feed_lines[#feed_lines + 1] = {name = player:get_player_name(), kind = kind,
			text = text, key = key}
		return true
	end,
	feed_item = function() return true end,
	plain_text = function(text) return tostring(text or "") end,
	item_name = function(item)
		local name = type(item) == "string" and item or item:get_name()
		local def = core.registered_items[name]
		return def and def.description or name
	end,
	hud_layout = {QUEST_WRAP = 38, side_text_width = function() return 38 end,
		anchors = {quest_list = {position = {x = 1, y = 0.5}, offset = {x = 0, y = 0},
			alignment = {x = -1, y = 1}}}},
	settlement_socket_settlements = function()
		return {
			{key = "dur_brannoc", display_name = "Dur Brannoc", slot = "capital", race_id = "dwarf"},
			{key = "highcourt", display_name = "Highcourt", slot = "capital", race_id = "human"},
			{key = "goldmead", display_name = "Goldmead", slot = "start", race_id = "human"},
		}
	end,
	settlement_sockets_at = function(key)
		if key ~= "dur_brannoc" then return {} end
		return {{id = "travel_waypoint", role = "waypoint", pos = {x = 100, y = 10, z = 100}},
			{id = "quest_1", role = "quest", pos = QUEST_POS}}
	end,
}
grug_classes = {
	get_class = function(player) return player.class_id end,
	get_race = function(player) return player.race end,
	register_on_arrival = function(f) table.insert(callbacks.arrival, f) end,
}
local xp_added = {}
grug_xp = {
	get_level = function(player) return player.level end,
	register_on_level_change = function(f) table.insert(callbacks.level, f) end,
	quest_reward = function(level, weight) return math.floor(weight * (25 + 5 * level) + 0.5) end,
	add_xp = function(player, amount, source)
		xp_added[#xp_added + 1] = {name = player:get_player_name(), amount = amount, source = source}
	end,
}
grug_factions = {
	get_faction = function(player) return player.class_id and player.faction or nil end,
	register_on_faction_chosen = function(f) table.insert(callbacks.faction, f) end,
}
grug_mobs = {
	register_on_eligible_kill = function(f) table.insert(callbacks.kill, f) end,
	register_participant_drop_hook = function() end,
}
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
grug_gear = {initialize_weapon_tooltip = function() return false end}
grug_abilities = {is_unlocked = function() return true end}
grug_mounts = {RIDING_TIERS = {1, 2, 3, 4}, BOAT_TIERS = {5, 6},
	owns_tier = function() return true end,
	owned_tier_ids = function(player) return player.tiers end}
grug_housing = {player_claim = function(name)
	local player = players[name]
	return nil, player and player.claim or "never"
end}
grug_skills = {}
grug_map = {minimap = {set_mail_count = function() end}}
grug_zones = {get = function() return nil end}

local function item(name, def)
	def.stack_max = def.stack_max or 99
	def.description = def.description or name
	def.groups = def.groups or {}
	core.registered_items[name] = def
end
item("t:dirt", {description = "Dirt"})
item("grug_money:bag_of_coins", {description = "Bag of Coins", stack_max = 1})

-- grug_xp runs its level callbacks at every join with old_level = nil, before
-- grug_mail's join (grug_xp/init.lua): the same order here.
table.insert(callbacks.join, function(player)
	for _, f in ipairs(callbacks.level) do f(player, nil, player.level) end
end)

current_mod = "grug_inventory"
grug_inventory = {refresh = function() end}
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/inbox.lua")
grug_inventory.GAME_VERSION = "0.48.0"
grug_inventory.UI = {frame_w = 13.5, frame_h = 13.673}
grug_inventory.SCROLL_FIELDS = {short = "grug_inv_scroll_short"}
grug_inventory.inventory_view = function() return "<inventory view>" end
grug_inventory.wrap_text = function(text) return text end
current_mod = "grug_money"
dofile(ROOT .. "/mods/PLAYER/grug_money/init.lua")
current_mod = "grug_quests"
grug_quests = {}
dofile(ROOT .. "/mods/PLAYER/grug_quests/registry.lua")
dofile(ROOT .. "/mods/PLAYER/grug_quests/state.lua")
dofile(ROOT .. "/mods/PLAYER/grug_quests/labels.lua")
dofile(ROOT .. "/mods/PLAYER/grug_quests/hud.lua")
-- npc.lua's list helpers (the dialogue is not loaded here).
grug_quests.list_entry = function(title) return title end
grug_quests.status_tooltip = function() return "" end
local Q = grug_quests
-- An ordinary NPC quest and twenty fillers beside the system quest.
Q.register_npc("elder", {settlement = "dur_brannoc", socket = "quest_1", title = "Elder Maren"})
Q.register_quest("elder_errand", {npc = "elder", title = "An errand", description = "Bring dirt.",
	objectives = {{type = "item", item = "t:dirt", count = 1}}, rewards = {weight = 1}})
for index = 1, 20 do
	Q.register_quest("filler_" .. index, {npc = "elder", title = "Filler " .. index,
		description = "Bring dirt.", objectives = {{type = "item", item = "t:dirt", count = 1}},
		rewards = {weight = 1}})
end
local turn_ins = {}
Q.register_on_turn_in(function(player, id) turn_ins[#turn_ins + 1] = player:get_player_name() .. ":" .. id end)
local quest_box = dofile(ROOT .. "/mods/PLAYER/grug_map/quest_box.lua")
current_mod = "grug_mail"
-- The Admin Mail tab (admin.lua) registers an sfinv page; tools/r48_admin
-- tests it.
sfinv = {register_page = function() end}
dofile(ROOT .. "/mods/PLAYER/grug_mail/init.lua")
for _, f in ipairs(callbacks.mods_loaded) do f() end

local ID = grug_mail.STARTER_QUEST
local TURNIN = "Open a mailbox beside the waystone of a capital or a starting village"
local TEXTS = grug_mail.texts
local MAILBOX = {x = 102, y = 10, z = 100}
nodes["102,10,100"] = "grug_mapgen:mailbox"
local function letters_of(name) return grug_mail.store.box(name).letters end
local function letters_from(name, from)
	local found = {}
	for _, letter in ipairs(letters_of(name)) do
		if letter.from == from then found[#found + 1] = letter end
	end
	return found
end
local function feeds_of(name, kind)
	local found = {}
	for _, line in ipairs(feed_lines) do
		if line.name == name and (not kind or line.kind == kind) then found[#found + 1] = line.text end
	end
	return found
end

------------------------------------------------------------------------------
-- R. The system quest kind
------------------------------------------------------------------------------
do
	local def = Q.registered_quests[ID]
	check(def and def.system, "R the starter quest is a system quest")
	check(def.npc == nil and def.turnin_npc == nil and #def.objectives == 0,
		"R it has no NPC and no objectives")
	eq(def.title, "Use a mailbox in one of the cities", "R the user's title")
	eq(def.min_level, 1, "R min_level 1")
	eq(def.rewards.copper, 25, "R it pays 25c")
	eq(Q.reward_xp(def), 30, "R and a little XP (one kill equivalent at level 1)")
	lacks(def.description, "{", "R the quest text carries no placeholder")
	check(def.description:find(TEXTS.quest.description, 1, true) == 1,
		"R the description is the picked text (with the requirements line)")
	check(pcall(Q.validate_registry), "R validate_registry accepts the system quest")
	local function refused(id, fields)
		local quest = {system = true, turnin_text = "x", title = "t", description = "d",
			rewards = {weight = 0}}
		for key, value in pairs(fields) do quest[key] = value end
		return not pcall(Q.register_quest, id, quest)
	end
	check(refused("bad_1", {npc = "elder"}), "R a system quest with an NPC is refused")
	check(refused("bad_2", {objectives = {{type = "item", item = "t:dirt", count = 1}}}),
		"R a system quest with objectives is refused")
	check(refused("bad_3", {turnin_text = ""}), "R a system quest without turn-in text is refused")
	check(refused("bad_4", {system = false, npc = "elder", objectives = {}}),
		"R an ordinary quest without objectives is still refused")
	check(not (Q.quests_by_npc.elder or {})[ID], "R no NPC lists the system quest")
end

------------------------------------------------------------------------------
-- G, W. Grant and welcome letter: arrival, join, once
------------------------------------------------------------------------------
local nova = new_player("Nova")
join(nova) -- still creating a character
eq(Q.quest_held(nova, ID), nil, "G nothing is granted while the character is created")
eq(#letters_of("Nova"), 0, "W no letter before the character exists")
nova.class_id = "warrior"
arrive(nova)
eq(Q.quest_held(nova, ID), "active", "G granted at arrival")
eq(Q.status(nova, ID), "ready", "G a system quest is ready at once (no objectives)")
eq(#letters_from("Nova", "Server Admin"), 1, "W the welcome letter at arrival")
local welcome = letters_from("Nova", "Server Admin")[1]
eq(welcome.kind, "admin", "W the welcome letter is an admin letter")
eq(welcome.subject, TEXTS.welcome.subject, "W its subject")
eq(welcome.body, TEXTS.welcome.body:gsub("{player}", "Nova"), "W its text names the player")
has(welcome.body, "Welcome to Grudgelands, Nova.", "W it opens with the user's line")
has(table.concat(feeds_of("Nova", "notice"), "|"), "New letter from Server Admin.",
	"W the letter raises the feed notice")
join(nova)
join(nova)
eq(#letters_from("Nova", "Server Admin"), 1, "W no second welcome letter at later joins")
Q.abandon(nova, ID)
join(nova)
eq(Q.quest_held(nova, ID), nil, "G an abandoned starter quest is not granted again")
-- Back in the log for the turn-in checks below (the flag is the fixture's).
nova.meta:set_string("grug_mail:quest_granted", "")
join(nova)
eq(Q.quest_held(nova, ID), "active", "G granted at join to a character without the flag")

local veteran = new_player("Veteran", {class = "mage", level = 8})
join(veteran)
eq(Q.quest_held(veteran, ID), "active", "G an existing character gets it at its first join")
eq(#letters_from("Veteran", "Server Admin"), 1, "W and the welcome letter")
arrive(veteran)
join(veteran)
eq(#letters_from("Veteran", "Server Admin"), 1, "W once, also after an arrival and a rejoin")

local busy = new_player("Busy")
join(busy)
for index = 1, 20 do check(Q.accept(busy, "filler_" .. index), "G filler " .. index) end
busy.class_id = "warrior"
join(busy)
eq(Q.quest_held(busy, ID), nil, "G a full quest log skips the starter quest")
eq(busy.meta:get_string("grug_mail:quest_granted"), "1", "G and flags it (skipped for good)")
Q.abandon(busy, "filler_1")
join(busy)
eq(Q.quest_held(busy, ID), nil, "G a freed slot does not bring it back")
eq(#letters_from("Busy", "Server Admin"), 1, "W a full log still gets the welcome letter")

------------------------------------------------------------------------------
-- T. Tracker and quest log
------------------------------------------------------------------------------
do
	local journal = Q.journal(nova)
	local row
	for _, quest in ipairs(journal.quests) do if quest.id == ID then row = quest end end
	check(row ~= nil, "T the quest is in the log")
	eq(row.turnin_text, TURNIN, "T the journal row carries the turn-in text")
	eq(Q.hud_line(row, 100), TURNIN, "T the tracker line is the system text")
	eq(Q.hud_line(row, 38), "Open a mailbox beside the waystone...",
		"T cut to the tracker width like every line")
	eq(hud_texts.Nova, "Open a mailbox beside the waystone...", "T the HUD element shows it")
	lacks(hud_texts.Nova, "Return to", "T never \"Return to\"")
	local session = {quest_selected = ID}
	local fs = quest_box.content(session, journal, {x = 0, y = 0, w = 7, h = 12})
	has(fs, core.formspec_escape(TURNIN .. "."), "T the quest log names the system text")
	lacks(fs, "Ready to return to", "T and no \"Ready to return to\" line")
	lacks(fs, "nil", "T nothing reads nil")
	has(fs, core.formspec_escape("Rewards: 30 XP, 25c"), "T the rewards")
	has(fs, "Level 1", "T the level line")
	local errand = Q.accept(nova, "elder_errand")
	check(errand, "T an ordinary quest beside it")
	journal = Q.journal(nova)
	session = {quest_selected = "elder_errand"}
	nova.inv:set_stack("main", 9, ItemStack("t:dirt"))
	journal = Q.journal(nova)
	fs = quest_box.content(session, journal, {x = 0, y = 0, w = 7, h = 12})
	has(fs, "Ready to return to Elder Maren.", "T an NPC quest still reads \"Ready to return to\"")
	for _, quest in ipairs(journal.quests) do
		if quest.id == "elder_errand" then eq(Q.hud_line(quest, 38), "Return to Elder Maren",
			"T and its tracker line \"Return to\"") end
	end
	Q.abandon(nova, "elder_errand")
	nova.inv:set_stack("main", 9, ItemStack(""))
end

------------------------------------------------------------------------------
-- O. Turn-in by opening a mailbox
------------------------------------------------------------------------------
do
	nova.pos = {x = 120, y = 10, z = 130}
	check(not grug_mail.open_mailbox(nova, MAILBOX), "O out of reach the mailbox does not open")
	eq(Q.quest_held(nova, ID), "active", "O and the quest stays active")
	nova.pos = {x = 100, y = 10, z = 100}
	local before, xp_before = grug_money.get(nova), #xp_added
	check(grug_mail.open_mailbox(nova, MAILBOX), "O the mailbox opens")
	eq(Q.quest_held(nova, ID), "completed", "O opening it turns the quest in")
	eq(grug_money.get(nova) - before, 25, "O 25c paid")
	eq(#xp_added - xp_before, 1, "O one XP grant")
	check(xp_added[#xp_added].amount == 30 and xp_added[#xp_added].source == "quest",
		"O 30 XP from the quest path")
	eq(turn_ins[#turn_ins], "Nova:" .. ID, "O the turn-in listeners see it")
	local quest_lines = feeds_of("Nova", "quest")
	eq(quest_lines[#quest_lines], TEXTS.quest.completion, "O the completion line in the feed")
	eq(formspecs.Nova and formspecs.Nova.formname:match("^grug_mail") ~= nil, true,
		"O the mailbox window follows")
	local count = #turn_ins
	grug_mail.open_mailbox(nova, MAILBOX)
	eq(#turn_ins, count, "O a second opening turns nothing in")
	eq(grug_money.get(nova) - before, 25, "O and pays nothing more")
	lacks(hud_texts.Nova or "", "Open a mailbox", "O the tracker line is gone")

	veteran.pos = {x = 101, y = 10, z = 100}
	grug_money.set(veteran, grug_money.MAX - 10)
	grug_mail.open_mailbox(veteran, MAILBOX)
	eq(Q.quest_held(veteran, ID), "active", "O a full purse refuses the turn-in")
	local notices = feeds_of("Veteran", "notice")
	has(notices[#notices], "purse", "O and says why")
	grug_money.set(veteran, 0)
	grug_mail.open_mailbox(veteran, MAILBOX)
	eq(Q.quest_held(veteran, ID), "completed", "O then it completes")
	eq(grug_money.get(veteran), 25, "O with its 25c")
end

------------------------------------------------------------------------------
-- L. Level letters
------------------------------------------------------------------------------
do
	local rider = new_player("Rider", {class = "warrior", level = 14})
	join(rider)
	eq(#letters_from("Rider", "Riding Trainer") + #letters_from("Rider", "Housing Steward"), 0,
		"L nothing below level 15")
	level_change(rider, 14, 21)
	local riding = letters_from("Rider", "Riding Trainer")
	local housing = letters_from("Rider", "Housing Steward")
	eq(#riding, 1, "L a jump 14 -> 21 sends the Riding Trainer's letter")
	eq(#housing, 1, "L and the Housing Steward's")
	eq(riding[1].kind, "npc", "L an NPC letter")
	eq(riding[1].subject, TEXTS.riding.subject, "L the riding letter's subject")
	eq(riding[1].body, (TEXTS.riding.body:gsub("{player}", "Rider"):gsub("{capital}", "Dur Brannoc")),
		"L {player} and {capital} filled")
	has(housing[1].body, "Visit me in Dur Brannoc;", "L the steward names the race capital")
	lacks(riding[1].body .. housing[1].body, "{", "L no placeholder left")
	join(rider)
	level_change(rider, 21, 22)
	eq(#letters_from("Rider", "Riding Trainer") + #letters_from("Rider", "Housing Steward"), 2,
		"L once each")

	local owner = new_player("Owner", {class = "mage", level = 22, tiers = {1}, claim = "placed"})
	join(owner)
	eq(#letters_of("Owner"), 1, "L an owned riding tier and a claim: no level letters")
	check(owner.meta:get_string("grug_mail:letter_riding") ~= "" and
		owner.meta:get_string("grug_mail:letter_housing") ~= "",
		"L and they are settled for good")
	owner.tiers, owner.claim = {}, "never"
	join(owner)
	eq(#letters_of("Owner"), 1, "L never sent later")

	local boater = new_player("Boater", {class = "mage", level = 16, tiers = {5}, race = "human"})
	join(boater)
	eq(#letters_from("Boater", "Riding Trainer"), 1, "L late at join; a boat is no riding tier")
	has(letters_from("Boater", "Riding Trainer")[1].body, "Come to Highcourt",
		"L the human capital")
	eq(#letters_from("Boater", "Housing Steward"), 0, "L no steward letter below 20")
	level_change(boater, 16, 20)
	eq(#letters_from("Boater", "Housing Steward"), 1, "L the steward's letter at 20")

	local lost = new_player("Lost", {class = "mage", level = 25, tiers = {2}, claim = "needs_stone"})
	join(lost)
	eq(#letters_from("Lost", "Housing Steward"), 0, "L a character that had a stone gets no steward letter")

	local drifter = new_player("Drifter", {class = "mage", level = 15, race = "unknown"})
	join(drifter)
	has(letters_from("Drifter", "Riding Trainer")[1].body, "Come to your capital",
		"L without a capital the letter says \"your capital\"")

	local fresh = new_player("Fresh", {level = 30})
	join(fresh)
	eq(#letters_of("Fresh"), 0, "L nothing for a character not created yet")
end

if failures > 0 then
	error(("R48 QUEST PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R48 QUEST PORTABLE PASS checks=%d"):format(checks))
