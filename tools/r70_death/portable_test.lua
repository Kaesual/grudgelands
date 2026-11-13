-- Round 70 lane DEATH portable test (plan §2.9, durability_repair.md).
--
--   luajit tools/r70_death/portable_test.lua [repo]
--
-- Loads the REAL grug_core combat.lua (the hp-change seam, the equipment
-- notifier), death_messages.lua and hud_layout.lua, the REAL grug_pvp and the
-- REAL grug_repair through its init.lua, with os.time under test control.
-- Checks:
--   W  the rule: a death takes 10 % of the maximum on every equipped item
--      that wears at every tier, down to 0; trinkets, bags and hotbar tools
--      are untouched; ten deaths break a fresh item exactly; a broken item
--      keeps its stack; the tooltip line follows; Creative costs nothing; one
--      equipment change and one break cue per death;
--   P  the PvP window: 30 s, its own value beside the 15 s kill credit; a
--      fall, a drowning or a mob inside it costs nothing; an own-faction
--      hit, a dodged hit and a mob's hit do not count; an enemy who went
--      offline still counts; the death clears the window;
--   L  the logout death: settled at logout, decided then, happens at the
--      join: free after an enemy's hit however long the player stayed away,
--      wear for a contact without one, a 0.69.0 mark costs nothing;
--   H  the HUD hints: at join, on the use that crosses 15 %, on the break, on
--      a repair and a swap; 15 % itself is no hint; a broken item is the
--      broken hint alone; trinkets never; a use reads one slot, sends nothing
--      unless a hint changes; no globalstep;
--   Y  the placement over desktop and web windows at GUI scaling 1 and 2:
--      the two lines never touch each other, the bars, the XP bar or the
--      hotbar and fit the window; the column's rows did not move.
-- Prints "R70 DEATH PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."

local checks, failures = 0, 0
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

local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy
function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

local cues = 0
grug_sounds = {CLICK_STYLE = "", play = function(name)
	if name == "gear_break" then cues = cues + 1 end
	return false
end}

local clock = 1700000000
os.time = function() return clock end -- luacheck: ignore
local function advance(seconds) clock = clock + seconds end

local hp_modifiers, globalsteps = {}, {}
local callbacks = {join = {}, leave = {}, die = {}, shutdown = {}, loaded = {}}
local afters, connected = {}, {}
local creative_names = {}
local current_mod = "grug_pvp"
local registered_items = {}

core = {
	registered_items = registered_items, registered_entities = {}, registered_nodes = {},
	get_us_time = function() return clock * 1000000 end,
	get_item_group = function(name, group)
		local def = registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_on_player_hpchange = function(fn, modifier)
		if modifier then hp_modifiers[#hp_modifiers + 1] = fn end
	end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_joinplayer = function(fn) table.insert(callbacks.join, fn) end,
	register_on_leaveplayer = function(fn) table.insert(callbacks.leave, fn) end,
	register_on_dieplayer = function(fn) table.insert(callbacks.die, fn) end,
	register_on_shutdown = function(fn) table.insert(callbacks.shutdown, fn) end,
	register_on_mods_loaded = function(fn) table.insert(callbacks.loaded, fn) end,
	register_chatcommand = function() end,
	get_connected_players = function() return connected end,
	get_player_by_name = function(name)
		for _, p in ipairs(connected) do
			if p.name == name then return p end
		end
	end,
	is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and obj:is_player() end,
	is_creative_enabled = function(name) return creative_names[name] == true end,
	chat_send_player = function() end,
	chat_send_all = function() end,
	colorize = function(_, text) return text end,
	add_particlespawner = function() end,
	after = function(_, fn) afters[#afters + 1] = fn end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_modpath = function()
		return repo .. (current_mod == "grug_pvp" and "/mods/PLAYER/grug_pvp" or
			"/mods/ITEMS/grug_repair")
	end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function()
		return {get_string = function() return "" end, set_string = function() end}
	end,
	serialize = function() return "return {}" end,
	deserialize = function() return {} end,
	formspec_escape = function(text) return text end,
	log = function() end,
	get_objects_in_area = function() return {} end,
	override_item = function(name, def)
		for key, value in pairs(def) do registered_items[name][key] = value end
	end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}

-- An ItemStack with what the wear code reads.
local function new_meta(store)
	store = store or {}
	local m = {store = store}
	function m:get_string(k) return store[k] or "" end
	function m:set_string(k, v) store[k] = (v ~= "" and v) or nil end
	function m:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function m:set_int(k, v) store[k] = v ~= 0 and tostring(v) or nil end
	function m:set_tool_capabilities(caps) store._caps = caps and "set" or nil end
	return m
end
function ItemStack(item)
	local s
	if type(item) == "table" then
		s = {name = item.name, wear = item.wear, meta = new_meta(deep_copy(item.meta.store))}
	else
		s = {name = item or "", wear = 0, meta = new_meta()}
	end
	function s:get_name() return self.name end
	function s:is_empty() return self.name == "" end
	function s:get_wear() return self.wear end
	function s:set_wear(w) self.wear = w end
	function s:get_meta() return self.meta end
	function s:get_definition() return registered_items[self.name] or {} end
	function s:get_tool_capabilities() return {} end
	function s:to_string() return self.name .. "|" .. self.wear end
	return s
end

for tier = 1, 6 do
	registered_items["t:sword" .. tier] = {description = "Sword", _grug_bracket = tier,
		groups = {grug_equip_weapon = 1}}
	registered_items["t:chest" .. tier] = {description = "Chest", _grug_bracket = tier,
		groups = {grug_equip_chest = 1}}
end
registered_items["t:head"] = {description = "Head", _grug_bracket = 1, groups = {grug_equip_head = 1}}
registered_items["t:legs"] = {description = "Legs", _grug_bracket = 2, groups = {grug_equip_legs = 1}}
registered_items["t:feet"] = {description = "Feet", _grug_bracket = 3, groups = {grug_equip_feet = 1}}
registered_items["t:shield"] = {description = "Shield", _grug_bracket = 4,
	groups = {grug_shield = 1, grug_equip_offhand = 1}}
registered_items["t:book"] = {description = "Book", _grug_bracket = 5,
	groups = {grug_spellbook = 1, grug_equip_offhand = 1}}
registered_items["t:ring"] = {description = "Ring", groups = {grug_equip_trinket = 1}}
registered_items["t:pick"] = {description = "Pick", _grug_tool_uses = 300, groups = {pickaxe = 1}}

grug_core = {particles = {play = function() end}}
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/combat_ray.lua")
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
dofile(repo .. "/mods/CORE/grug_core/death_messages.lua")
dofile(repo .. "/mods/CORE/grug_core/environment_damage.lua")
local modifier = hp_modifiers[1]
function grug_core.player_in_creation_stasis() return false end
function grug_core.apply_player_armor(_, damage) return damage end
function grug_core.feed() return true end
function grug_core.register_status_source() return true end
function grug_core.opposing_faction(id) return id == "accord" and "throng" or "accord" end
function grug_core.get_player_faction(name)
	local p = core.get_player_by_name(name)
	return p and p.faction
end

grug_factions = {}
function grug_factions.get_faction(p) return p.faction end
function grug_factions.hostile(a, b)
	return a:is_player() and b:is_player() and a.faction ~= b.faction
end
function grug_factions.same_faction(a, b) return a.faction == b.faction end
grug_zones = {pvp_rule_at = function() return "contested" end, faction_at = function() end}
sfinv = {pages = {}, pages_unordered = {}, contexts = {}, register_page = function() end}
grug_parties = {PAGE = "grug_parties:group"}

dofile(repo .. "/mods/PLAYER/grug_pvp/init.lua")

-- The seam grug_repair writes through: the real notifier behind it.
local changes = {}
grug_inventory = {
	BAG_COUNT = 0,
	equipment_slots = {
		{list = "grug_head"}, {list = "grug_chest"}, {list = "grug_legs"}, {list = "grug_feet"},
		{list = "grug_weapon"}, {list = "grug_offhand"}, {list = "grug_trinket1"},
		{list = "grug_trinket2"},
	},
	melee_list = function() return "grug_weapon" end,
	is_equipment_list = function(list) return list ~= "main" end,
	equipment_changed = function(player, list, reason)
		changes[#changes + 1] = {list = list, reason = reason}
		grug_core.notify_equipment_change(player, list, reason)
	end,
	content_list = function() return "none" end,
}
grug_gear = {
	broken_image = function(image) return image end,
	usable_by = function() return "Usable by: all" end,
	initialize_weapon_tooltip = function() end,
	reference_purchase_price = function() return 100 end,
}
grug_items = {regenerate_description = function() end}

local steps_before = #globalsteps
current_mod = "grug_repair"
dofile(repo .. "/mods/ITEMS/grug_repair/init.lua")
for _, fn in ipairs(callbacks.loaded) do fn() end
eq(#globalsteps, steps_before, "H the mod adds no globalstep")
check(read("mods/ITEMS/grug_repair/mod.conf"):find("grug_pvp", 1, true) ~= nil,
	"W grug_repair loads after grug_pvp")

local function new_player(name, faction)
	local p = {name = name, faction = faction, hp = 100, hp_max = 100,
		pos = {x = 50, y = 10, z = 0}, meta = new_meta(), hud = {}, hud_serial = 0,
		hud_writes = 0, stack_reads = 0, lists = {}}
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_properties() return {hp_max = self.hp_max} end
	function p:get_pos() return self.pos end
	function p:get_meta() return self.meta end
	function p:is_player() return true end
	function p:get_luaentity() return nil end
	function p:hud_add(def)
		self.hud_serial, self.hud_writes = self.hud_serial + 1, self.hud_writes + 1
		self.hud[self.hud_serial] = def
		return self.hud_serial
	end
	function p:hud_remove(id)
		self.hud_writes = self.hud_writes + 1
		self.hud[id] = nil
	end
	function p:set_hp(hp, reason)
		reason = reason or {type = "set_hp"}
		local change = hp - self.hp
		if change < 0 then change = modifier(self, change, reason) end
		self.hp = math.max(0, math.min(self.hp_max, self.hp + change))
		if self.hp == 0 then
			for _, fn in ipairs(callbacks.die) do fn(self, reason) end
		end
	end
	function p:get_inventory()
		local owner = self
		return {
			get_stack = function(_, list, index)
				owner.stack_reads = owner.stack_reads + 1
				return ItemStack(owner.lists[list] and owner.lists[list][index] or "")
			end,
			set_stack = function(_, list, index, stack)
				owner.lists[list] = owner.lists[list] or {}
				owner.lists[list][index] = ItemStack(stack)
			end,
			get_list = function(_, list) return owner.lists[list] end,
		}
	end
	return p
end

local function run_afters()
	local pending = afters
	afters = {}
	for _, fn in ipairs(pending) do fn() end
end
local function join(p)
	connected[#connected + 1] = p
	for _, fn in ipairs(callbacks.join) do fn(p) end
	-- grug_inventory's join notification.
	grug_inventory.equipment_changed(p)
end
local function leave(p)
	for _, fn in ipairs(callbacks.leave) do fn(p, false) end
	for i, q in ipairs(connected) do
		if q == p then table.remove(connected, i) break end
	end
end
local function equip(p, list, name, wear)
	local stack = ItemStack(name)
	stack:set_wear(wear or 0)
	p:get_inventory():set_stack(list, 1, stack)
	return stack
end
local function wear_of(p, list) return p.lists[list][1]:get_wear() end
-- The enemy's landed hit through the real hp-change seam.
local function hit(attacker, target, damage)
	target:set_hp(target.hp - (damage or 1), {type = "punch", object = attacker})
end
local function die(p, reason)
	p:set_hp(0, reason or {type = "fall"})
	p.hp = 100
end
local function hint_texts(p)
	local out = {}
	for _, def in pairs(p.hud) do out[#out + 1] = def.text end
	table.sort(out)
	return table.concat(out, " + ")
end

local BROKEN, LOW = "Broken gear equipped", "Gear almost broken"

------------------------------------------------------------------------------
-- W  the rule
------------------------------------------------------------------------------
do
	local lifetimes = {1000, 1500, 2000, 2500, 3000, 4000}
	for tier = 1, 6 do
		local p = new_player("w" .. tier, "accord")
		equip(p, "grug_weapon", "t:sword" .. tier)
		join(p)
		die(p)
		local stack = p.lists.grug_weapon[1]
		local remaining, maximum = grug_repair.durability(stack)
		eq(maximum, lifetimes[tier], "W tier " .. tier .. " lifetime")
		eq(remaining, maximum * 0.9, "W tier " .. tier .. " loses 10 % of the maximum")
		-- Round 78 ruling 3: the repair factor 0.5 (was 1.0).
		eq(grug_repair.cost(stack), 5, "W the quote prices the wear (half of 10 % of 100)")
		leave(p)
	end

	local p = new_player("wset", "accord")
	equip(p, "grug_head", "t:head")
	equip(p, "grug_chest", "t:chest1")
	equip(p, "grug_legs", "t:legs")
	equip(p, "grug_feet", "t:feet")
	equip(p, "grug_weapon", "t:sword1")
	equip(p, "grug_offhand", "t:shield")
	equip(p, "grug_trinket1", "t:ring")
	equip(p, "grug_trinket2", "t:ring")
	equip(p, "main", "t:pick")
	join(p)
	changes = {}
	die(p)
	for _, list in ipairs({"grug_head", "grug_chest", "grug_legs", "grug_feet", "grug_weapon",
			"grug_offhand"}) do
		check(math.abs(wear_of(p, list) - 6553.5) <= 0.5, "W " .. list .. " wears 10 %")
	end
	eq(wear_of(p, "grug_trinket1"), 0, "W a trinket does not wear")
	eq(wear_of(p, "main"), 0, "W a tool in the hotbar is not equipped")
	eq(#changes, 1, "W one equipment change for the whole set")
	eq(changes[1].list, nil, "W ...naming no list")
	eq(changes[1].reason, "durability_metadata", "W ...pure wear while nothing broke")
	eq(cues, 0, "W no break, no cue")
	local line = p.lists.grug_chest[1]:get_meta():get_string("description")
	check(line:find("Durability: 900 / 1000", 1, true) ~= nil, "W the tooltip line follows: " .. line)
	leave(p)

	local q = new_player("wlife", "accord")
	equip(q, "grug_weapon", "t:sword4")
	equip(q, "grug_chest", "t:chest4")
	join(q)
	for death = 1, 9 do
		die(q)
		check(not grug_core.equipment_is_broken(q.lists.grug_weapon[1]), "W alive after death " .. death)
		eq(grug_repair.durability(q.lists.grug_weapon[1]), 2500 - 250 * death, "W death " .. death)
	end
	cues = 0
	changes = {}
	die(q)
	check(grug_core.equipment_is_broken(q.lists.grug_weapon[1]), "W the tenth death breaks a fresh item")
	eq(#changes, 1, "W one notification")
	eq(changes[1].reason, nil, "W a break is a full change")
	eq(wear_of(q, "grug_weapon"), 65535, "W ...at exactly the sentinel")
	eq(q.lists.grug_weapon[1].name, "t:sword4", "W the stack stays")
	eq(cues, 1, "W two items broke: one cue")
	check(q.lists.grug_weapon[1]:get_meta():get_string("description"):find("Broken", 1, true) ~= nil,
		"W the tooltip says Broken")
	check(q.lists.grug_weapon[1]:get_meta().store._caps ~= nil, "W a broken weapon loses its operation")
	changes = {}
	die(q)
	eq(wear_of(q, "grug_weapon"), 65535, "W a broken item stays at 0")
	eq(#changes, 0, "W nothing left to wear: no change")
	leave(q)

	local r = new_player("wfloor", "accord")
	equip(r, "grug_weapon", "t:sword1", 65000)
	join(r)
	cues = 0
	die(r)
	eq(wear_of(r, "grug_weapon"), 65535, "W an item below 10 % stops at 0")
	eq(cues, 1, "W a death can break an item")
	leave(r)

	local c = new_player("wcreative", "accord")
	creative_names.wcreative = true
	equip(c, "grug_weapon", "t:sword1")
	join(c)
	changes = {}
	die(c)
	eq(wear_of(c, "grug_weapon"), 0, "W Creative costs nothing")
	eq(#changes, 0, "W Creative changes nothing")
	leave(c)
end

------------------------------------------------------------------------------
-- P  the PvP window
------------------------------------------------------------------------------
do
	local R = grug_pvp.rules
	eq(R.PVP_DEATH_SECONDS, 30, "P the window is 30 s")
	eq(R.CREDIT_SECONDS, 15, "P the kill credit stays 15 s")
	local v = new_player("victim", "accord")
	local e = new_player("enemy", "throng")
	local friend = new_player("friend", "accord")
	equip(v, "grug_weapon", "t:sword1")
	join(v); join(e); join(friend)
	local function wear() return wear_of(v, "grug_weapon") end
	local function reset() equip(v, "grug_weapon", "t:sword1") end

	hit(e, v)
	advance(5)
	v:set_hp(0, {type = "punch", object = e})
	v.hp = 100
	eq(wear(), 0, "P an enemy's kill costs nothing")
	eq(grug_pvp.stats(e).kills, 1, "P ...and still credits the kill")

	for _, case in ipairs({{"fall", {type = "fall"}}, {"drown", {type = "drown"}},
			{"node damage", {type = "node_damage"}}, {"a mob", {type = "punch"}}}) do
		hit(e, v)
		advance(29)
		die(v, case[2])
		eq(wear(), 0, "P " .. case[1] .. " 29 s after an enemy's hit costs nothing")
	end
	local kills = grug_pvp.stats(e).kills
	hit(e, v)
	advance(16)
	die(v)
	eq(wear(), 0, "P 16 s after the hit: past the kill credit, inside the window")
	eq(grug_pvp.stats(e).kills, kills, "P ...and no kill")

	hit(e, v)
	advance(30)
	die(v)
	eq(wear(), 0, "P 30 s is inside")
	hit(e, v)
	advance(31)
	die(v)
	check(wear() > 0, "P 31 s is outside: the death wears")
	reset()

	-- The record dies with the victim.
	hit(e, v)
	die(v)
	eq(wear(), 0, "P the PvP death is free")
	die(v)
	check(wear() > 0, "P the next death inside 30 s starts a clean record")
	reset()

	-- Hits that do not count.
	hit(friend, v)
	die(v)
	check(wear() > 0, "P an own-faction hit is no PvP death")
	reset()
	local mob = {is_player = function() return false end,
		get_luaentity = function() return {} end}
	hit(mob, v)
	v.hp = 100
	die(v)
	check(wear() > 0, "P a mob's hit is no PvP death")
	reset()

	-- An offline attacker's hit still counts, for the victim's own record.
	hit(e, v)
	leave(e)
	advance(10)
	die(v)
	eq(wear(), 0, "P the enemy left: the hit still counts")
	join(e)

	-- A party changes nothing: the rule reads the victim's record alone.
	hit(e, friend)
	die(v)
	check(wear() > 0, "P a hit on a party member does not cover the victim")
	reset()
	eq(grug_pvp.register_on_death ~= nil, true, "P the seam exists")
	leave(v); leave(e); leave(friend)
end

------------------------------------------------------------------------------
-- L  the logout death
------------------------------------------------------------------------------
do
	local v = new_player("deserter", "accord")
	local e = new_player("foe", "throng")
	equip(v, "grug_weapon", "t:sword1")
	join(v); join(e)
	local META = "grug_pvp:logout_death"

	hit(e, v)
	leave(v)
	eq(v.meta:get_string(META), "1", "L an enemy's hit: a PvP mark")
	advance(3600)
	join(v)
	eq(v.meta:get_string(META), "", "L the mark is consumed at join")
	eq(wear_of(v, "grug_weapon"), 0, "L nothing before the death")
	run_afters()
	eq(v.hp, 0, "L the character starts dead")
	eq(wear_of(v, "grug_weapon"), 0, "L free, an hour after the window")
	v.hp = 100

	-- The deserter struck but was never hit: PvP combat without an enemy's hit.
	grug_pvp.contact(v, e)
	leave(v)
	eq(v.meta:get_string(META), "wear", "L no enemy's hit: a wear mark")
	join(v)
	run_afters()
	eq(v.hp, 0, "L the logout death happens")
	check(wear_of(v, "grug_weapon") > 0, "L it wears")
	v.hp = 100
	equip(v, "grug_weapon", "t:sword1")
	leave(v)
	join(v)
	run_afters()
	eq(wear_of(v, "grug_weapon"), 0, "L the next join is clean")
	eq(v.hp, 100, "L ...and no second death")
	leave(v)

	-- A mark a 0.69.0 world left behind.
	v.meta:set_string(META, "1")
	join(v)
	run_afters()
	eq(v.hp, 0, "L a 0.69.0 mark still kills")
	eq(wear_of(v, "grug_weapon"), 0, "L ...and costs nothing")
	leave(v)
	v.hp = 100

	-- Leaving while dead, or outside PvP combat, is no death at all.
	join(v)
	hit(e, v)
	advance(11)
	leave(v)
	eq(v.meta:get_string(META), "", "L no mark outside PvP combat")
	join(v)
	run_afters()
	eq(wear_of(v, "grug_weapon"), 0, "L no death, no wear")
	leave(v); leave(e)
end

------------------------------------------------------------------------------
-- H  the HUD hints
------------------------------------------------------------------------------
do
	local WEAR_AT = function(share) return math.floor((1 - share) * 65535 + 0.5) end
	local p = new_player("hints", "accord")
	equip(p, "grug_weapon", "t:sword1", WEAR_AT(0.15))
	eq(grug_repair.durability(p.lists.grug_weapon[1]), 150, "H the weapon sits at exactly 15 %")
	equip(p, "grug_chest", "t:chest1", 65535)
	equip(p, "grug_trinket1", "t:ring", 65535)
	join(p)
	eq(hint_texts(p), BROKEN, "H at join: a broken item; 15 % is no hint; a trinket never")
	local def
	for _, row in pairs(p.hud) do def = row end
	eq(def.alignment.y, 1, "H the broken line lies below the shared edge")
	eq(def.alignment.x, -1, "H its right end sits on the anchor")
	equip(p, "grug_chest", "t:chest1")
	grug_inventory.equipment_changed(p, "grug_chest")
	eq(hint_texts(p), "", "H a swap clears it")

	-- Uses: one slot read each, nothing sent until a hint changes.
	local uses = 0
	local writes = p.hud_writes
	while grug_repair.durability(p.lists.grug_weapon[1]) >= 150 do
		local reads = p.stack_reads
		grug_core.run_settled_outgoing_action(p, {}, "damage")
		uses = uses + 1
		if grug_repair.durability(p.lists.grug_weapon[1]) >= 150 then
			eq(p.hud_writes, writes, "H a use sends nothing")
		end
		eq(p.stack_reads - reads, 2, "H a use reads one slot: the wear's read and the hint's")
		if uses > 5 then break end
	end
	eq(grug_repair.durability(p.lists.grug_weapon[1]), 149, "H the weapon sits below 15 %")
	eq(hint_texts(p), LOW, "H the use that crosses 15 % shows the hint")
	for _, row in pairs(p.hud) do def = row end
	eq(def.alignment.y, -1, "H the low line lies above the shared edge")

	-- Wear on to the break: the hint swaps on the breaking use.
	equip(p, "grug_weapon", "t:sword1", 65535 - 66)
	p.lists.grug_weapon[1]:get_meta():set_string("description", "Sword\nDurability: 2 / 1000")
	grug_inventory.equipment_changed(p, "grug_weapon")
	eq(hint_texts(p), LOW, "H 2 / 1000 is low")
	grug_core.run_settled_outgoing_action(p, {}, "damage")
	grug_core.run_settled_outgoing_action(p, {}, "damage")
	check(grug_core.equipment_is_broken(p.lists.grug_weapon[1]), "H worn out")
	eq(hint_texts(p), BROKEN, "H a broken item is the broken hint alone")

	-- Both, and a death crossing the threshold.
	equip(p, "grug_chest", "t:chest1", WEAR_AT(0.20))
	grug_inventory.equipment_changed(p, "grug_chest")
	eq(hint_texts(p), BROKEN, "H 20 % is no hint")
	die(p)
	eq(hint_texts(p), BROKEN .. " + " .. LOW, "H the death shows both")

	-- A repair: the service's own write and notification.
	local hint_count = 0
	for _ in pairs(p.hud) do hint_count = hint_count + 1 end
	eq(hint_count, 2, "H two elements")
	equip(p, "grug_weapon", "t:sword1")
	equip(p, "grug_chest", "t:chest1")
	grug_inventory.equipment_changed(p)
	eq(hint_texts(p), "", "H a repair clears both")
	eq(next(p.hud), nil, "H no element is left behind")

	-- A rejoin draws from scratch.
	equip(p, "grug_weapon", "t:sword1", 65535)
	leave(p)
	p.hud = {}
	join(p)
	eq(hint_texts(p), BROKEN, "H a rejoin draws the hint again")
	leave(p)
	check(not read("mods/ITEMS/grug_repair/hints.lua"):find("register_globalstep", 1, true),
		"H no tick in the hints")
end

------------------------------------------------------------------------------
-- Y  the placement
------------------------------------------------------------------------------
do
	local layout = grug_core.hud_layout
	local rows = {xp = -76, secondary = -100, life = -120, breath = -140, skill = -162}
	for id, top in pairs(rows) do eq(layout.rows[id].top, top, "Y the " .. id .. " row did not move") end
	eq(#layout.order, 5, "Y the column has its five rows")
	local WINDOWS = {
		{1280, 720, 1, 1}, {1920, 1080, 1, 1}, {1280, 720, 1, 2}, {1920, 1080, 1, 2},
		{1280, 720, 2, 2}, {1920, 1080, 2, 2}, {1600, 900, 1, 1.5},
		-- browser windows of the web build
		{1366, 768, 1, 1}, {1024, 600, 1, 1}, {800, 600, 1, 1},
	}
	local CHAR, LINE = 9, 20 -- the layout's own estimates of the default font
	for _, w in ipairs(WINDOWS) do
		local W, H, hud, gui = w[1], w[2], w[3], w[4]
		local label = ("%dx%d hud %g gui %g"):format(W, H, hud, gui)
		local upper = layout.gear_hint(true, {text = LOW})
		local lower = layout.gear_hint(false, {text = BROKEN})
		local edge = upper.offset.y * hud
		local width = #BROKEN * CHAR * gui
		local right = upper.offset.x * hud
		check(upper.offset.y == lower.offset.y and upper.offset.x == lower.offset.x,
			"Y one shared anchor")
		-- Screen px from the bottom edge, y negative up.
		local top, bottom = edge - LINE * gui, edge + LINE * gui
		check(right <= -(layout.BAR_WIDTH / 2) * hud, label .. ": right of the text is left of the bars")
		check(W / 2 + right - width >= 0, label .. ": the line fits the window")
		local xp_top = layout.rows.xp.top * hud
		check(bottom <= xp_top, label .. ": clear of the XP bar")
		check(top >= (layout.rows.skill.top - 4) * hud, label .. ": below the status captions")
	end
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R70 DEATH PORTABLE FAIL") end
print("R70 DEATH PORTABLE PASS checks=" .. checks)
