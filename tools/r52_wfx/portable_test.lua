-- Round 52 lane WFX portable test (LuaJIT; round52-class-plan.md C7, C11, D7):
-- the element overlay on the first-person weapon. Loads the REAL
-- grug_abilities/init.lua with its whole dofile chain (kits, scout.lua, input)
-- in a sandbox over a small fake engine, twice: as it ships, and with a test
-- animation table and test strips patched in (the art step's shape). Checks:
--   M  every registered skill has a family of its class or none (Strike
--      none), one-directional in round K (Round 53 K14: a row may wait for
--      its skill); the table lives in init.lua and no kit file names it;
--   O  off while no strip ships (the state before the art step): no family
--      animation, no definition overlay, every skin writes the transparent
--      override (never an empty string) for a weapon, a bow and an empty
--      slot; always: SKIN_VERSION is 5, the token carries the overlay, the
--      empty slot shows the hand;
--   S  on (patched): the definition carries the family's animation under the
--      transparent name; the skin pass writes grug_abilities_fx_<family>_
--      <weapon>.png for the held weapon type, the transparent override for an
--      unpicked strip, an empty slot, a non-weapon and Strike; the token
--      changes with the overlay, so a newly picked strip rewrites the stack
--      once and an unchanged pass writes nothing;
--   D  the Scout's draw (the real start/step/cancel): each draw stage shows
--      its own strip, the idle bow's comes back after the draw, and an
--      unpicked draw strip falls back to transparent;
--   T  third person: the held-item holder (grug_visuals/apply.lua, its two
--      functions copied out of the source) shows the cosmetic weapon for a
--      selected skill and copies only that stack's keys, so the skill's
--      overlay never reaches it;
--   F  every strip that ships (30 since the art step) is named
--      <family>_<weapon>[_draw<n>] for a weapon its family's class wields,
--      has its family's animation, is 16 px wide and `frames` frames high,
--      and has a LICENSE-media.md row; an animated family ships every strip
--      of its class's weapons and the bow's draw stages, and the shipped skin
--      names them.
--
-- Usage (repo root): luajit tools/r52_wfx/portable_test.lua [repo]
-- Prints "R52 WFX PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local MOD = ROOT .. "/mods/PLAYER/grug_abilities/"
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
local function read(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
local function ls(dir)
	local out = {}
	local pipe = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
	for line in pipe:lines() do out[#out + 1] = line end
	pipe:close()
	return out
end

local NONE = "[combine:16x16"
local FAMILY_CLASS = {ember = "mage", rime = "mage", mercy = "priest",
	reckoning = "priest", ruin = "warrior", bulwark = "warrior",
	quarry = "scout", veil = "scout"}
local CLASS_WEAPONS = {warrior = {sword = true, dagger = true, greataxe = true},
	scout = {bow = true, sword = true, dagger = true},
	mage = {staff = true, wand = true, dagger = true},
	priest = {staff = true, wand = true, dagger = true}}

------------------------------------------------------------------------------
-- The fake engine.
------------------------------------------------------------------------------
local now_us = 1e9
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end

-- The weapons the hands can hold: grug_gear's families and a non-weapon.
local registered_items = {
	["grug_gear:sword_iron"] = {inventory_image = "grug_gear_item_sword_iron.png",
		groups = {grug_equip_weapon = 1, sword = 1}, _grug_weapon_family = "sword"},
	["grug_gear:dagger_iron"] = {inventory_image = "grug_gear_item_dagger_iron.png",
		groups = {grug_equip_weapon = 1, sword = 1}, _grug_weapon_family = "dagger"},
	["grug_gear:staff_iron"] = {inventory_image = "grug_gear_item_staff_iron.png",
		groups = {grug_equip_weapon = 1, staff = 1}, _grug_weapon_family = "staff"},
	["grug_gear:bow_wood"] = {inventory_image = "grug_gear_bow_wood.png",
		groups = {grug_equip_weapon = 1, bow = 1}, _grug_weapon_family = "bow",
		_grug_bow_draw_time = 2.5},
	["grug_gear:shield_iron"] = {inventory_image = "grug_gear_shield_iron.png",
		groups = {grug_equip_offhand = 1}},
}

local Stack = {}
Stack.__index = Stack
local function ItemStack(spec)
	if type(spec) == "table" and getmetatable(spec) == Stack then
		local copy = setmetatable({name = spec.name, wear = spec.wear, fields = {}}, Stack)
		for k, v in pairs(spec.fields) do copy.fields[k] = v end
		return copy
	end
	local name = type(spec) == "string" and spec:match("^(%S*)") or ""
	return setmetatable({name = name, wear = 0, fields = {}}, Stack)
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:get_count() return self.name == "" and 0 or 1 end
function Stack:get_wear() return self.wear end
function Stack:set_wear(w) self.wear = w end
function Stack:get_definition() return registered_items[self.name] end
function Stack:equals(other) return self:to_string() == other:to_string() end
function Stack:to_string()
	local keys = {}
	for k in pairs(self.fields) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {self.name, tostring(self.wear)}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(self.fields[k]) end
	return table.concat(parts, "|")
end
function Stack:get_meta()
	local fields = self.fields
	return {
		get_string = function(_, k) return fields[k] or "" end,
		set_string = function(_, k, v) fields[k] = v ~= "" and v or nil end,
		get_int = function(_, k) return tonumber(fields[k]) or 0 end,
		set_int = function(_, k, v) fields[k] = tostring(v) end,
		set_tool_capabilities = function(_, caps)
			fields.caps = caps and tostring(caps.full_punch_interval) or nil
		end,
	}
end
function Stack:get_tool_capabilities() return {full_punch_interval = 1} end

local LISTS = {"main", "grug_hotbar_store", "grug_weapon"}
local function new_player(name, class)
	local inv = {lists = {}, writes = 0}
	for _, l in ipairs(LISTS) do
		inv.lists[l] = {}
		for i = 1, 32 do inv.lists[l][i] = ItemStack("") end
	end
	function inv:get_size(l) return self.lists[l] and #self.lists[l] or 0 end
	function inv:get_stack(l, i) return ItemStack(self.lists[l][i]) end
	function inv:set_stack(l, i, s)
		self.writes = self.writes + 1
		self.lists[l][i] = ItemStack(s)
	end
	function inv:get_list(l)
		local out = {}
		for i, s in ipairs(self.lists[l] or {}) do out[i] = ItemStack(s) end
		return out
	end
	function inv:get_lists()
		local out = {}
		for _, l in ipairs(LISTS) do out[l] = self:get_list(l) end
		return out
	end
	local p = {name = name, class = class, inv = inv, wield = 1, hp = 20,
		hands = {}, controls = {}}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:set_wielded_item(s)
		self.inv:set_stack("main", self.wield, s)
		return true
	end
	function p:get_wield_index() return self.wield end
	function p:get_wield_list() return "main" end
	function p:get_player_control() return self.controls end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = 20} end
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add() return 1 end
	return p
end

-- One sandbox: the real init.lua (its source optionally patched) with the
-- texture directory `strips` lists. Returns the sandbox's grug_abilities,
-- the registered tool definitions and the engine hooks it captured.
local function load_abilities(patch, strips)
	local tools, hooks, players = {}, {}, {}
	local function capture(kind)
		return function(fn)
			hooks[kind] = hooks[kind] or {}
			table.insert(hooks[kind], fn)
		end
	end
	local fake_core = with_any({
		register_globalstep = capture("globalstep"),
		register_on_mods_loaded = capture("mods_loaded"),
		get_modpath = function() return ROOT .. "/mods/PLAYER/grug_abilities" end,
		get_current_modname = function() return "grug_abilities" end,
		get_dir_list = function(path)
			if strips then return strips end
			return ls(path)
		end,
		get_us_time = function() return now_us end,
		global_exists = function(n) return n == "grug_inventory" end,
		register_tool = function(name, def) tools[name] = def end,
		registered_items = registered_items,
		get_item_group = function(name, group)
			return (group == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
		end,
		get_player_by_name = function(name) return players[name] end,
		get_connected_players = function() return {} end,
		log = function() end,
	})
	local fake_grug_core = with_any({
		register_on_equipment_change = capture("equipment"),
		get_melee_weapon = function(p) return p.hands.melee or ItemStack("") end,
		get_equipped_weapon = function(p) return p.hands.weapon end,
		equipment_is_broken = function() return false end,
		is_stunned = function() return false end,
		scale_player_damage = false,
	})
	local registered_classes = {warrior = {name = "Warrior"}, mage = {name = "Mage"},
		priest = {name = "Priest"}, scout = {name = "Scout"}}
	local fake_classes = with_any({
		registered_classes = registered_classes,
		registered_talents = {mend = {name = "Mend"}},
		get_class = function(p) return p.class end,
		get_class_def = function(p) return registered_classes[p.class] end,
		talent_rank = function() return 1 end,
		get_talent_bonus = function() return 0 end,
		get_melee_bonus = function() return 0 end,
		get_race_perk = function() return nil end,
		get_max_mana = function() return 1000 end,
	})
	local fake_inventory = with_any({
		HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 0,
		get_cosmetic_hand = function(p, slot) return p.hands[slot] end,
		hand_list = function() return "grug_weapon" end,
		melee_list = function() return "grug_weapon" end,
		is_bow = function(s) return s ~= nil and s:get_name() == "grug_gear:bow_wood" end,
		ammo_count = function() return 20 end,
		equipment_changed = function() end,
	})
	-- grug_gear: the real weapon_family (permissions.lua), the bow draw's
	-- strip_enchant as identity (no enchant in these stacks).
	local gear = {strip_enchant = function(image) return image end}
	setfenv(assert(loadfile(ROOT .. "/mods/ITEMS/grug_gear/permissions.lua")),
		setmetatable({grug_gear = gear}, {__index = _G}))()
	local env
	env = setmetatable({
		core = fake_core, ItemStack = ItemStack,
		grug_core = fake_grug_core, grug_classes = fake_classes,
		grug_inventory = fake_inventory, grug_gear = gear,
		vector = with_any({}),
	}, {__index = function(_, k)
		local g = rawget(_G, k)
		if g ~= nil and k ~= "core" and k ~= "minetest" then return g end
		return any()
	end})
	env.dofile = function(path) return setfenv(assert(loadfile(path)), env)() end
	env._G = env
	local source = assert(read(MOD .. "init.lua"))
	if patch then source = patch(source) end
	setfenv(assert(loadstring(source, "@" .. MOD .. "init.lua")), env)()
	for _, fn in ipairs(hooks.mods_loaded or {}) do pcall(fn) end
	return env.grug_abilities, tools, hooks, players, new_player
end

local init_src = assert(read(MOD .. "init.lua"))
local G, tools, hooks, players = load_abilities()
check(G and G.registered.strike and G.registered.loose and G.WEAPON_FX,
	"the real init.lua loads with its kits")

------------------------------------------------------------------------------
-- M: the family of every skill. One-directional while round K's lanes
-- register the new skills (round53-plan.md K14): every registered skill has
-- a family of its class; a row may wait for its skill (HOOKS adds the rows
-- first, INTEG restores the reverse check when the retired rows go).
------------------------------------------------------------------------------
local ids = {}
for id in pairs(G.registered) do ids[#ids + 1] = id end
table.sort(ids)
check(#ids >= 1, "M the kits register skills")
eq(G.WEAPON_FX.strike, "none", "M Strike shows no family")
for _, id in ipairs(ids) do
	local family = G.WEAPON_FX[id]
	check(family ~= nil, "M a family for the registered " .. id)
	-- A skill's family belongs to its class's trees.
	local def = G.registered[id]
	if family and family ~= "none" then
		eq(FAMILY_CLASS[family], def.class, "M " .. id .. "'s family is of its class")
	end
end
for id, family in pairs(G.WEAPON_FX) do
	check(family == "none" or FAMILY_CLASS[family] ~= nil, "M a known family: " .. id)
end
check(init_src:find("\ngrug_abilities%.WEAPON_FX = {") ~= nil,
	"M the id-keyed table lives in init.lua")
do
	local pipe = assert(io.popen("ls " .. MOD .. "*.lua"))
	for path in pipe:lines() do
		local file = path:match("([^/]+)$")
		if file ~= "init.lua" then
			check(not (read(MOD .. file) or ""):find("WEAPON_FX", 1, true),
				"M no kit file names the table: " .. file)
		end
	end
	pipe:close()
end

------------------------------------------------------------------------------
-- O: off as shipped.
------------------------------------------------------------------------------
local shipped = {}
for _, file in ipairs(ls(MOD .. "textures")) do
	if file:find("^grug_abilities_fx_") then shipped[#shipped + 1] = file end
end
local animated = 0
for _ in pairs(G.WEAPON_FX_ANIMATION) do animated = animated + 1 end
eq(G.NO_OVERLAY, NONE, "O the transparent override is a 16 x 16 [combine")
eq(tonumber(init_src:match("\nlocal SKIN_VERSION = (%d+)")), 5,
	"O SKIN_VERSION bumped for the overlay")
local function hands(p, weapon, melee)
	p.hands.weapon = weapon and ItemStack(weapon) or nil
	p.hands.melee = melee and ItemStack(melee) or p.hands.weapon
	p.hands.offhand = nil
end
-- Every skill's skin over each hand; returns {id -> wield_overlay}.
local function skins(p)
	local out = {}
	for _, id in ipairs(ids) do
		local def = G.registered[id]
		if not def.class or def.class == p.class then
			local stack = G.stack_for(p, id)
			if stack then out[id] = stack:get_meta():get_string("wield_overlay") end
		end
	end
	return out
end
if #shipped == 0 then
	eq(animated, 0, "O no family is animated while no strip ships")
end
local no_def_overlay = true
for name, def in pairs(tools) do
	if def.wield_overlay ~= nil and animated == 0 then
		no_def_overlay = false
		print("  definition overlay on " .. name)
	end
end
check(no_def_overlay, "O no definition carries an overlay while none is animated")
if animated == 0 then
	for _, case in ipairs({
		{"warrior", "grug_gear:sword_iron"}, {"mage", "grug_gear:staff_iron"},
		{"priest", nil}, {"scout", "grug_gear:bow_wood", "grug_gear:dagger_iron"},
	}) do
		local p = new_player("o_" .. case[1], case[1])
		players[p.name] = p
		hands(p, case[2], case[3])
		for id, overlay in pairs(skins(p)) do
			eq(overlay, NONE, "O " .. case[1] .. " " .. id .. " writes the transparent override")
		end
	end
end
do
	local p = new_player("o_token", "mage")
	hands(p, "grug_gear:staff_iron")
	eq(G.stack_for(p, "fireball"):get_meta():get_string("grug_skin"),
		"5|grug_gear_item_staff_iron.png|" .. G.skin_overlay(G.registered.fireball, "staff"),
		"O the token carries the overlay")
	hands(p, nil)
	local stack = G.stack_for(p, "fireball")
	eq(stack:get_meta():get_string("grug_skin"), "5||" .. NONE, "O the empty slot's token")
	eq(stack:get_meta():get_string("wield_image"), "wieldhand.png", "O the empty slot shows the hand")
end

------------------------------------------------------------------------------
-- S: on, with the art step's shape patched in.
------------------------------------------------------------------------------
local ANIM = "{ember = {frames = 8, frame_length = 0.12}, quarry = {frames = 6, frame_length = 0.2}," ..
	" ruin = {frames = 4, frame_length = 0.1}}"
local STRIPS = {"grug_abilities_fx_ember_staff.png", "grug_abilities_fx_ember_wand.png",
	"grug_abilities_fx_quarry_bow.png", "grug_abilities_fx_quarry_bow_draw0.png",
	"grug_abilities_fx_quarry_bow_draw2.png", "grug_abilities_fx_quarry_dagger.png",
	"grug_abilities_fx_ruin_sword.png", "grug_abilities_fx_rime_staff.png",
	"grug_abilities_bow_draw_0.png"}
local patched = 0
local function patch(source)
	local out, n = source:gsub("\ngrug_abilities%.WEAPON_FX_ANIMATION = %b{}",
		"\ngrug_abilities.WEAPON_FX_ANIMATION = " .. ANIM)
	patched = n
	return out
end
local G2, tools2, hooks2, players2 = load_abilities(patch, STRIPS)
G = G2
eq(patched, 1, "S the animation table is patched in")
local function anim_of(id)
	local o = tools2["grug_abilities:" .. id].wield_overlay
	return o and (o.name .. " " .. o.animation.type .. " " .. o.animation.aspect_w .. "x" ..
		o.animation.aspect_h .. " " .. string.format("%.2f", o.animation.length)) or "none"
end
eq(anim_of("fireball"), NONE .. " vertical_frames 16x16 0.96", "S fireball: ember's animation")
-- Round 53: Cinderfall is retired; Meteor is another ember skill.
eq(anim_of("meteor"), NONE .. " vertical_frames 16x16 0.96", "S meteor shares it")
eq(anim_of("loose"), NONE .. " vertical_frames 16x16 1.20", "S loose: quarry's own tempo")
eq(anim_of("charge"), NONE .. " vertical_frames 16x16 0.40", "S charge: ruin's")
eq(anim_of("ice_nova"), "none", "S rime without an animation has no definition overlay")
eq(anim_of("strike"), "none", "S Strike has none")

local so = G.skin_overlay
local R = G.registered
eq(so(R.fireball, "staff"), "grug_abilities_fx_ember_staff.png", "S ember on a staff")
eq(so(R.meteor, "wand"), "grug_abilities_fx_ember_wand.png", "S ember on a wand")
eq(so(R.fireball, "dagger"), NONE, "S an unpicked strip is transparent")
eq(so(R.fireball, nil), NONE, "S no weapon, no overlay")
eq(so(R.loose, "bow"), "grug_abilities_fx_quarry_bow.png", "S the idle bow")
eq(so(R.sprint, "bow"), "grug_abilities_fx_quarry_bow.png", "S every quarry skill on the bow")
eq(so(R.loose, "bow", 0), "grug_abilities_fx_quarry_bow_draw0.png", "S draw stage 0")
eq(so(R.loose, "bow", 1), NONE, "S an unpicked draw stage is transparent")
eq(so(R.loose, "bow", 2), "grug_abilities_fx_quarry_bow_draw2.png", "S draw stage 2")
eq(so(R.opening, "dagger"), NONE, "S veil without an animation")
eq(so(R.charge, "sword"), "grug_abilities_fx_ruin_sword.png", "S ruin on a sword")
eq(so(R.strike, "sword"), NONE, "S Strike none")
eq(so(R.ice_nova, "staff"), NONE, "S a shipped strip without its animation stays off")

do
	local p = new_player("s_mage", "mage")
	players2[p.name] = p
	hands(p, "grug_gear:staff_iron")
	local got = skins(p)
	eq(got.fireball, "grug_abilities_fx_ember_staff.png", "S the skin writes the staff strip")
	-- Round 53: the Mage's basic attack replaces Strike (so(R.strike) above
	-- keeps Strike's transparent overlay checked).
	eq(got.strike, nil, "S the Mage holds no Strike")
	eq(got.blink, NONE, "S rime is off")
	hands(p, "grug_gear:dagger_iron")
	eq(skins(p).fireball, NONE, "S the dagger strip is not picked")
	hands(p, "grug_gear:shield_iron")
	eq(skins(p).fireball, NONE, "S a non-weapon shows no overlay")
	hands(p, nil)
	got = skins(p)
	eq(got.fireball, NONE, "S the empty slot is transparent")
end

-- The skin pass over the hotbar: equip writes once, a repeat writes nothing,
-- and a stack skinned before a strip shipped is rewritten.
do
	local p = new_player("s_pass", "scout")
	players2[p.name] = p
	hands(p, "grug_gear:bow_wood", "grug_gear:dagger_iron")
	local inv = p.inv
	inv.lists.main[1] = ItemStack("grug_abilities:loose")
	inv.lists.main[2] = ItemStack("grug_abilities:opening")
	inv.lists.main[3] = ItemStack("grug_abilities:strike")
	-- Loose as the off build skinned it: the token without a strip.
	local old = inv.lists.main[1]:get_meta()
	old:set_string("grug_skin", "5|grug_gear_bow_wood.png|" .. NONE)
	old:set_string("wield_image", "grug_gear_bow_wood.png")
	old:set_string("wield_overlay", NONE)
	check(hooks2.equipment and #hooks2.equipment > 0, "S the skin pass hooks equipment changes")
	local function equip()
		for _, fn in ipairs(hooks2.equipment or {}) do fn(p, nil) end
	end
	equip()
	eq(inv.lists.main[1]:get_meta():get_string("wield_overlay"),
		"grug_abilities_fx_quarry_bow.png", "S a newly picked strip reaches a skinned stack")
	-- Opening reads the Melee slot's dagger; its family (veil) is off, the
	-- quarry dagger strip beside it is not Opening's.
	eq(inv.lists.main[2]:get_meta():get_string("wield_overlay"), NONE,
		"S Opening over the Melee slot: veil is off")
	eq(inv.lists.main[3]:get_meta():get_string("wield_overlay"), NONE, "S Strike transparent")
	local before = inv.writes
	equip()
	eq(inv.writes - before, 0, "S an unchanged pass writes nothing")
end

------------------------------------------------------------------------------
-- D: the Scout's draw stages (the real start, step and cancel).
------------------------------------------------------------------------------
do
	local p = new_player("d_scout", "scout")
	players2[p.name] = p
	hands(p, "grug_gear:bow_wood", "grug_gear:dagger_iron")
	p.inv.lists.main[1] = G.stack_for(p, "loose")
	local function shown()
		local meta = p.inv.lists.main[1]:get_meta()
		return meta:get_string("wield_image") .. " " .. meta:get_string("wield_overlay")
	end
	eq(shown(), "grug_gear_bow_wood.png grug_abilities_fx_quarry_bow.png", "D the idle bow")
	local ok = G.start_bow_draw(p)
	check(ok, "D the draw starts")
	eq(shown(), "grug_abilities_bow_draw_0.png grug_abilities_fx_quarry_bow_draw0.png",
		"D stage 0 shows its strip")
	p.controls = {place = true}
	local function advance(seconds)
		for _ = 1, math.floor(seconds / 0.05 + 0.5) do
			now_us = now_us + 50000
			for _, fn in ipairs(hooks2.globalstep or {}) do fn(0.05) end
		end
	end
	advance(1.0)
	eq(shown(), "grug_abilities_bow_draw_1.png " .. NONE, "D stage 1: its strip is not picked")
	advance(1.6)
	eq(shown(), "grug_abilities_bow_draw_2.png grug_abilities_fx_quarry_bow_draw2.png",
		"D stage 2 shows its strip")
	G.cancel_bow_draw(p)
	eq(shown(), "grug_gear_bow_wood.png grug_abilities_fx_quarry_bow.png",
		"D the idle strip comes back after the draw")
	eq(p.inv.lists.main[1]:get_wear(), 0, "D the draw's wear is reset too")
end

------------------------------------------------------------------------------
-- T: third person shows only the cosmetic weapon.
------------------------------------------------------------------------------
do
	local src = assert(read(ROOT .. "/mods/PLAYER/grug_visuals/apply.lua"))
	local appearance = src:match("\n(function grug_visuals%.wield_appearance%(stack%).-\nend)\n")
	local shown = src:match("\n(local function shown_item%(player%).-\nend)\n")
	local group = src:match('\n(local ABILITY_GROUP = "[%w_]+")')
	check(appearance and shown and group, "T found in grug_visuals/apply.lua")
	local env = setmetatable({grug_visuals = {}, ItemStack = ItemStack,
		core = {registered_items = registered_items,
			get_item_group = function(name, g)
				return (g == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
			end},
		grug_inventory = {get_cosmetic_hand = function(p, slot) return p.hands[slot] end}},
		{__index = _G})
	local chunk = assert(loadstring((group or "") .. "\n" .. (shown or "") .. "\n" ..
		(appearance or "") .. "\nreturn shown_item"))
	setfenv(chunk, env)
	env.core.registered_items = setmetatable({["grug_abilities:fireball"] =
		{_grug_ability_slot = "weapon"}}, {__index = registered_items})
	local shown_item = chunk()
	local p = new_player("t_mage", "mage")
	hands(p, "grug_gear:staff_iron")
	local skill = ItemStack("grug_abilities:fireball")
	skill:get_meta():set_string("wield_overlay", "grug_abilities_fx_ember_staff.png")
	skill:get_meta():set_string("wield_image", "grug_gear_item_staff_iron.png")
	p.inv.lists.main[1] = skill
	local held = shown_item(p)
	eq(held and held:get_name(), "grug_gear:staff_iron", "T a selected skill shows the cosmetic weapon")
	local visual = env.grug_visuals.wield_appearance(held)
	check(not visual:find("grug_abilities_fx_", 1, true),
		"T the holder's appearance carries no skill overlay")
end

------------------------------------------------------------------------------
-- F: the strips that ship.
------------------------------------------------------------------------------
do
	local license = read(MOD .. "LICENSE-media.md") or ""
	local real = load_abilities() -- the shipped tables again
	local anim = real.WEAPON_FX_ANIMATION
	for family, a in pairs(anim) do
		check(FAMILY_CLASS[family] ~= nil, "F an animation for a known family: " .. family)
		check(type(a.frames) == "number" and a.frames >= 1 and a.frames % 1 == 0 and
			type(a.frame_length) == "number" and a.frame_length > 0,
			"F " .. family .. ": whole frames and a positive frame length")
	end
	for _, file in ipairs(shipped) do
		local family, weapon, stage = file:match("^grug_abilities_fx_([a-z]+)_([a-z]+)_draw(%d)%.png$")
		if not family then
			family, weapon = file:match("^grug_abilities_fx_([a-z]+)_([a-z]+)%.png$")
		end
		local class = family and FAMILY_CLASS[family]
		check(class and CLASS_WEAPONS[class][weapon], "F a family and a weapon its class wields: " .. file)
		check(not stage or (weapon == "bow" and tonumber(stage) <= 2), "F draw stages only on the bow: " .. file)
		local a = family and anim[family]
		check(a ~= nil, "F its family is animated: " .. file)
		local png = read(MOD .. "textures/" .. file) or ""
		local function be32(s, at)
			local b1, b2, b3, b4 = s:byte(at, at + 3)
			return ((b1 or 0) * 16777216) + ((b2 or 0) * 65536) + ((b3 or 0) * 256) + (b4 or 0)
		end
		local width, height = be32(png, 17), be32(png, 21)
		eq(width, 16, "F 16 px wide: " .. file)
		if a then eq(height, a.frames * 16, "F " .. a.frames .. " frames high: " .. file) end
		check(license:find(file, 1, true) ~= nil, "F a LICENSE-media.md row: " .. file)
	end
	-- A family that ships has every strip of its class's weapons (and the
	-- bow's draw stages), and the shipped skin names them.
	for family in pairs(anim) do
		for weapon in pairs(CLASS_WEAPONS[FAMILY_CLASS[family]] or {}) do
			local names = {"grug_abilities_fx_" .. family .. "_" .. weapon .. ".png"}
			if weapon == "bow" then
				for n = 0, 2 do
					names[#names + 1] = "grug_abilities_fx_" .. family .. "_bow_draw" .. n .. ".png"
				end
			end
			for _, name in ipairs(names) do
				local found = false
				for _, file in ipairs(shipped) do found = found or file == name end
				check(found, "F a picked family ships all its strips: " .. name)
			end
		end
	end
	if anim.ember then
		eq(real.skin_overlay(real.registered.fireball, "staff"), "grug_abilities_fx_ember_staff.png",
			"F as shipped, Fireball over a staff shows ember's staff strip")
		eq(real.skin_overlay(real.registered.loose, "bow", 1), anim.quarry and
			"grug_abilities_fx_quarry_bow_draw1.png" or NONE, "F as shipped, Loose's draw stage 1")
		eq(real.skin_overlay(real.registered.strike, "sword"), NONE, "F as shipped, Strike none")
	end
	print(("F %d strips ship, %d families animated"):format(#shipped, (function()
		local n = 0
		for _ in pairs(anim) do n = n + 1 end
		return n
	end)()))
end

if failures > 0 then
	print(("R52 WFX PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R52 WFX PORTABLE PASS checks=%d"):format(checks))
