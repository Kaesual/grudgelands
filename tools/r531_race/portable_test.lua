-- 0.53.1 lane RACE portable test (LuaJIT): the racials, the skeleton bows
-- and right-click picking (round53-fix-plan.md rulings 5, 6, 7, 9, 10).
-- Loads the real code under minimal stubs:
--
--   A. the undead truce (grug_mobs/init.lua `truce_active`, cut out and run):
--      an unprovoked Undead player is spared by day and by night (no clock),
--      a provoked one is not, another race never is;
--   B. the truce flag: the Zombie (zombie.lua) and the Sun-Dried Husk
--      (zero_asset_variants.lua) carry it, the skeletons do not, every
--      shipped zombie-family sub-type copies one of the two bases, and the
--      Undead race holds the perk the flag names;
--   C. the races: Elf +3 m, Dwarf "Thick Skin" +5 % armor rating and no fall
--      perk left anywhere in mods/, the racial texts;
--   D. Thick Skin in grug_quality's raw_armor (cut out and run): +5 % of a
--      positive total for a Dwarf, nothing for others or a total <= 0;
--   E. the bows: the Skeleton Archer, Skeleton Raider and Frost Stray hold
--      the shipped bow texture in slot 3, and a zone tint leaves it alone;
--   F. right-click picking (grug_gathering/pick.lua): exactly the apple and
--      the ripe blueberry bush get on_rightclick, a pick is one core.node_dig
--      call with the clicker (the dig path, not the input-gated on_dig), the
--      wielded stack AFTER the dig is handed back, a non-player does nothing.
--
-- Usage (repo root): luajit tools/r531_race/portable_test.lua [repo]

local repo = arg and arg[1] or "."
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
local function noop() end
local function read(path)
	local f = assert(io.open(repo .. "/" .. path, "rb"), "cannot read " .. path)
	local text = f:read("*a")
	f:close()
	return text
end
local function exists(path)
	local f = io.open(repo .. "/" .. path, "rb")
	if f then f:close() end
	return f ~= nil
end
local function cut(text, from, to, label)
	local a = text:find(from, 1, true)
	check(a ~= nil, label .. ": start anchor")
	local b, e = text:find(to, a or 1, true)
	check(b ~= nil, label .. ": end anchor")
	return text:sub(a or 1, e or 0)
end
local function load_in(source, env, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

local function player(name, perks)
	return {get_player_name = function() return name end, perks = perks or {},
		is_player = function() return true end}
end
local function race_perk(p, key) return p.perks[key] end

-- ---------------------------------------------------------------------------
-- A. The truce predicate.
-- ---------------------------------------------------------------------------
local init = read("mods/ENTITIES/grug_mobs/init.lua")
local clock = 0.5
local truce_active = load_in(cut(init, "local function truce_active(self, player)",
	"\n\tend\n", "truce") .. "return truce_active\n", {
	truce_perk = "zombie_truce",
	grug_core = {get_race_perk = race_perk},
	core = {get_timeofday = function() return clock end},
	grug_mobs = {},
}, "truce")
local undead = player("u", {zombie_truce = true})
local orc = player("o", {rage_per_hit_taken_bonus = 1})
for _, t in ipairs({0.0, 0.25, 0.5, 0.75, 0.9}) do
	clock = t
	check(truce_active({}, undead) == true, "A1 an unprovoked Undead is spared at time " .. t)
	check(truce_active({temp = {grug_provoked = {u = true}}}, undead) == false,
		"A2 a provoked zombie fights the Undead back at time " .. t)
	check(truce_active({}, orc) == false, "A3 an Orc is never spared at time " .. t)
end
check(truce_active({temp = {grug_provoked = {other = true}}}, undead) == true,
	"A4 another player's provocation does not end the truce")
check(not init:find("is_night", 1, true), "A5 no clock left in grug_mobs/init.lua")
check(init:find("or (truce_perk and truce_active(s, player))", 1, true) ~= nil,
	"A6 the target veto asks the truce")
check(init:find("if truce_perk then", 1, true) ~= nil and
	init:find("and truce_active(self, self.attack) then\n\t\t\t\tself:stop_attack()", 1, true) ~= nil,
	"A7 the per-step check drops an unprovoked truce target that slipped through")
check(init:find("self.temp.grug_provoked[hitter:get_player_name()] = true", 1, true) ~= nil,
	"A8 an accepted player hit records the provocation")

-- ---------------------------------------------------------------------------
-- B/E. The mob defs (zombie, husk, the three bow skeletons).
-- ---------------------------------------------------------------------------
local defs = {}
grug_mobs = setmetatable({
	register_mob = function(name, def) defs[name] = deep_copy(def) end,
	bandit_def = function() return {animation = {}} end,
}, {__index = function() return noop end})
mobs = setmetatable({}, {__index = function() return noop end})
grug_zones = setmetatable({}, {__index = function() return noop end})
core = setmetatable({}, {__index = function() return noop end})
dofile(repo .. "/mods/ENTITIES/grug_mobs/zombie.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/skeleton_archer.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/skeleton_raider.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/zero_asset_variants.lua")
local ZOMBIES = {["grug_mobs:zombie"] = true, ["grug_mobs:sun_dried_husk"] = true}
for _, name in ipairs({"grug_mobs:zombie", "grug_mobs:sun_dried_husk"}) do
	check(defs[name] ~= nil, "B1 " .. name .. " registered")
	eq(defs[name] and defs[name]._grug_truce_perk, "zombie_truce", "B2 " .. name .. " carries the truce flag")
end
local BOWS = {"grug_mobs:skeleton_archer", "grug_mobs:skeleton_raider", "grug_mobs:frost_stray"}
for _, name in ipairs(BOWS) do
	check(defs[name] ~= nil, "B3 " .. name .. " registered")
	eq(defs[name] and defs[name]._grug_truce_perk, nil, "B4 " .. name .. " carries no truce flag")
end
-- Every shipped sub-type of the zombie family copies a flagged base
-- (subtypes.lua copies the base definition, grug_mobs.copy_base_def).
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local subtypes = json.parse(read("mods/ENTITIES/grug_mobs/data/subtypes.json"))
subtypes = subtypes.subtypes or subtypes
local family_count = 0
for _, row in ipairs(subtypes) do
	if row.family == "zombie" then
		family_count = family_count + 1
		check(ZOMBIES[row.base] == true, "B5 zombie sub-type " .. row.role .. " copies a flagged base")
	elseif ZOMBIES[row.base] then
		check(false, "B6 sub-type " .. row.role .. " of a zombie base outside the family")
	end
end
check(family_count >= 20, "B7 the zombie family's sub-types were read (" .. family_count .. ")")
check(read("mods/ENTITIES/grug_mobs/subtypes.lua"):find("grug_mobs.copy_base_def(base)", 1, true) ~= nil and
	init:find("base_defs[name] = table.copy(def)", 1, true) ~= nil,
	"B8 a sub-type starts from a copy of its registered base definition")
-- E. The bows.
for _, name in ipairs(BOWS) do
	local textures = defs[name] and defs[name].textures and defs[name].textures[1] or {}
	eq(#textures, 3, "E1 " .. name .. " fills all three slots")
	eq(textures[3], "grug_gear_bow_wood.png", "E2 " .. name .. " holds the bow in slot 3")
end
check(exists("mods/ITEMS/grug_gear/textures/grug_gear_bow_wood.png"), "E3 the bow texture ships")
local tint_textures = load_in(cut(read("mods/ENTITIES/grug_mobs/subtypes.lua"),
	"function grug_mobs.tint_textures(textures, tint)", "\nend\n", "tint") ..
	"return grug_mobs.tint_textures\n", {BLANK = "grug_mobs_blank.png", grug_mobs = {}}, "tint")
local tinted = tint_textures(defs["grug_mobs:skeleton_archer"].textures[1], {modifier = "^[multiply:#123456"})
eq(tinted[2], "grug_mobs_skeleton.png^[multiply:#123456", "E4 a zone tint colours the bones")
eq(tinted[3], "grug_gear_bow_wood.png", "E5 a zone tint leaves the bow alone")
eq(tinted[1], "grug_mobs_blank.png", "E6 the armour slot stays blank")

-- ---------------------------------------------------------------------------
-- C. The race definitions.
-- ---------------------------------------------------------------------------
local races = {}
local classes_init = read("mods/PLAYER/grug_classes/init.lua")
load_in(cut(classes_init, "grug_classes.register_race({\n\tid = \"human\"",
	"\tperks = {zombie_truce = true},\n})\n", "races"), {
	grug_classes = {register_race = function(def) races[def.id] = def end},
}, "races")
eq(races.elf and races.elf.perks.ability_range_bonus, 3, "C1 Elf +3 m ability range")
check(races.elf and races.elf.description:find("Passive: +3 m ability range.", 1, true) ~= nil,
	"C2 the Elf text says +3 m")
eq(races.dwarf and races.dwarf.perks.armor_rating_mult, 1.05, "C3 Dwarf Thick Skin +5 % armor rating")
eq(races.dwarf and races.dwarf.perks.fall_damage_mult, nil, "C4 the Dwarf fall perk is gone")
check(races.dwarf and races.dwarf.description:find("Thick Skin, +5% armor rating", 1, true) ~= nil,
	"C5 the Dwarf text names Thick Skin")
eq(races.undead and races.undead.perks.zombie_truce, true, "C6 the Undead hold the truce perk the flag names")
check(races.undead and races.undead.description:find("day and night", 1, true) ~= nil and
	not races.undead.description:find("at night (", 1, true),
	"C7 the Undead text says day and night")
local combat = read("mods/CORE/grug_core/combat.lua")
check(not combat:find("fall_damage_mult", 1, true), "C8 combat.lua reads no fall perk")
check(combat:find('if reason.type == "fall" then', 1, true) ~= nil and
	combat:find("hp_change = -math.ceil(max_hp * -hp_change / 20)", 1, true) ~= nil,
	"C9 the fall pool conversion itself stays")

-- ---------------------------------------------------------------------------
-- D. Thick Skin in raw_armor.
-- ---------------------------------------------------------------------------
local gear_total = 100
local raw_armor = load_in(cut(read("mods/ITEMS/grug_quality/init.lua"),
	"local function raw_armor(player)", "\nend\n", "raw_armor") .. "return raw_armor\n", {
	grug_inventory = {get_equipped_armor = function() return gear_total end},
	grug_items = {get_equipment_affix_totals = function() return {armor_rating = 10} end,
		get_equipment_armor_rating_bonus = function() return 5 end},
	grug_classes = {get_talent_bonus = function() return 3 end},
	grug_core = {status_modifier_sum = function() return 2 end, get_race_perk = race_perk},
}, "raw_armor")
local dwarf = player("d", {armor_rating_mult = 1.05})
local human = player("h", {quest_xp_mult = 1.1})
local total, breakdown = raw_armor(dwarf)
check(math.abs(total - 120 * 1.05) < 1e-9, "D1 a Dwarf's 120 becomes 126 (got " .. tostring(total) .. ")")
check(breakdown.result == total, "D2 the Character page's number is combat's")
eq(raw_armor(human), 120, "D3 a Human keeps 120")
gear_total = -40
eq(raw_armor(dwarf), -20, "D4 a total at or below 0 is not scaled")

-- ---------------------------------------------------------------------------
-- F. Right-click picking.
-- ---------------------------------------------------------------------------
local overrides, digs = {}, {}
local wield_after = "default:apple 3"
core = {
	override_item = function(name, def)
		check(overrides[name] == nil, "F0 " .. name .. " overridden once")
		overrides[name] = def
	end,
	node_dig = function(pos, node, digger)
		digs[#digs + 1] = {pos = pos, node = node, digger = digger}
		digger.wielded = wield_after
		return true
	end,
}
dofile(repo .. "/mods/ITEMS/grug_gathering/pick.lua")
local names = {}
for name, def in pairs(overrides) do
	names[#names + 1] = name
	local keys = {}
	for k in pairs(def) do keys[#keys + 1] = k end
	eq(table.concat(keys, ","), "on_rightclick", "F1 " .. name .. " gains only on_rightclick")
end
table.sort(names)
eq(table.concat(names, ","), "default:apple,default:blueberry_bush_leaves_with_berries",
	"F2 exactly the apple and the ripe blueberry bush are picked with right-click")
local picker = player("p")
picker.wielded = ""
picker.get_wielded_item = function(self) return self.wielded end
local pos, node = {x = 1, y = 2, z = 3}, {name = "default:apple", param2 = 0}
local returned = overrides["default:apple"].on_rightclick(pos, node, picker, "", {type = "node"})
eq(#digs, 1, "F3 a pick is one dig")
check(digs[1] and digs[1].pos == pos and digs[1].node == node and digs[1].digger == picker,
	"F4 the dig gets the clicked node and the clicker")
eq(returned, wield_after, "F5 the wielded stack after the dig is handed back")
-- A refused dig (protected ground) changes nothing and hands back the stack.
core.node_dig = function(...) digs[#digs + 1] = {...}; return false end
picker.wielded = "grug_gear:sword"
returned = overrides["default:blueberry_bush_leaves_with_berries"].on_rightclick(pos,
	{name = "default:blueberry_bush_leaves_with_berries"}, picker, "grug_gear:sword", {type = "node"})
eq(#digs, 2, "F6 the bush pick goes through the same dig path")
eq(returned, "grug_gear:sword", "F7 a refused pick keeps the wielded stack")
local mob = {is_player = function() return false end}
returned = overrides["default:apple"].on_rightclick(pos, node, mob, "x", {type = "node"})
eq(#digs, 2, "F8 a non-player right-click digs nothing")
eq(returned, "x", "F9 and returns its stack unchanged")
local pick_src = read("mods/ITEMS/grug_gathering/pick.lua")
check(not pick_src:find("%.on_dig%(") and
	pick_src:find("core.node_dig(pos, node, clicker)", 1, true) ~= nil,
	"F10 the pick calls core.node_dig, never the input-gated on_dig")
check(read("mods/ITEMS/grug_gathering/init.lua"):find('dofile(modpath .. "/pick.lua")', 1, true) ~= nil,
	"F11 grug_gathering loads the pick")
local default_nodes = read("mods/BASE/default/nodes.lua")
for _, block in ipairs({
	{'minetest.register_node("default:apple", {', '\n})\n'},
	{'minetest.register_node("default:blueberry_bush_leaves_with_berries", {', '\n})\n'},
}) do
	local def = cut(default_nodes, block[1], block[2], block[1])
	check(not def:find("on_rightclick", 1, true) and def:find("after_dig_node", 1, true) ~= nil,
		"F12 the vendored def keeps its after_dig_node and has no on_rightclick: " .. block[1])
end

if failures > 0 then
	error(("R531 RACE PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
print(("R531 RACE PORTABLE PASS checks=%d"):format(checks))
