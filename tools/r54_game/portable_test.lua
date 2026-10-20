-- Round 54 lane GAME portable test (LuaJIT): the armor redesign in the game
-- (docs/planning/round54-plan.md §4 GAME, docs/technical/armor-format.md).
--
--   luajit tools/r54_game/portable_test.lua [REPO]
--
-- Loads the REAL grug_gear, grug_quality, grug_repair (service and
-- presentation) and every grug_visuals file but the creation panel (with the
-- real player_api registration block of apply.lua) under a permissive engine
-- stub with ItemStack metadata and wear, and drives grug_visuals on fake
-- players and NPC entities. Checks:
--   N  the baked file names of armor-format.md §7 per line, grade and slot
--      (72 atlas layers, 54 skin layers, each with its mask) and that every
--      one exists in grug_visuals/textures;
--   P  players: the model's four textures {skin, cloak, armor, weapon}, a
--      metal T6 and a cloth T1 set, an enchanted and a broken piece, the
--      hair under a helmet, the weapon card empty in the world;
--   V  the preview seam grug_visuals.preview(player): the player model, the
--      same four textures with the main hand's image on the weapon card;
--   E  armored NPCs: three textures through grug_mobs' write seam, the write
--      guard on compose's key (no rewrite for the same look, a rewrite for a
--      changed armor alone, the pre-Round-54 skin field dropped), unarmored
--      NPCs one texture; the definitions' meshes (guards, bandits, kings,
--      royal guards, Generals and their kin on the NPC model, the Poacher
--      on character.b3d);
--   R  the royal armour: kings without a helmet, royal guards with it, zone
--      A in the royal colour and zone B gold under any enchant colours;
--   A  the stored appearance version 2: `textures.armor`, "none" when bare;
--   H  leather tier 4 "Hardened": the grade name, the four item
--      descriptions, a stack stored under the old base name renamed on its
--      next rebuild, nothing else renamed;
--   M  prints the texture string lengths a client receives per character
--      (bare, metal T3, the worst case) and an armored NPC's.
-- Prints "R54 GAME PORTABLE PASS checks=<n>" or the failures.

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
local function has(text, needle)
	return type(text) == "string" and text:find(needle, 1, true) ~= nil
end
local function read_file(path)
	local handle = assert(io.open(path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function file_exists(path)
	local handle = io.open(path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

------------------------------------------------------------------------------
-- Engine stub (tools/r39_wm's): unknown functions are no-ops.
------------------------------------------------------------------------------
local registered = {}
local function permissive(base)
	return setmetatable(base, {__index = function()
		return function() end
	end})
end
local modpaths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
	grug_repair = ROOT .. "/mods/ITEMS/grug_repair",
	grug_visuals = ROOT .. "/mods/PLAYER/grug_visuals",
	player_api = ROOT .. "/mods/BASE/player_api",
}
local current_mod = "grug_gear"
local serial = {}
local joins, equipment_consumers = {}, {}
core = permissive({
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_node = function(name, def) registered[name] = def end,
	serialize = function(value) serial[#serial + 1] = value; return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and serial[index] or nil
	end,
	get_us_time = function() return 1 end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = {mod = current_mod, fn = fn} end,
	get_connected_players = function() return {} end,
	add_entity = function()
		local obj = {}
		function obj:set_properties() end
		function obj:set_attach() end
		function obj:get_attach() return true end
		function obj:get_pos() return {x = 0, y = 0, z = 0} end
		function obj:remove() end
		return obj
	end,
})
table.copy = table.copy or function(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = table.copy(item) end
	return out
end
minetest = core
vector = permissive({})
grug_core = permissive({
	level_scale = function() return 1 end,
	register_on_equipment_change = function(fn) equipment_consumers[#equipment_consumers + 1] = fn end,
})
do
	local body = read_file(ROOT .. "/mods/CORE/grug_core/combat.lua")
		:match("\n(function grug_core%.equipment_is_broken%(.-\nend)\n")
	assert(loadstring(assert(body, "equipment_is_broken in combat.lua")))()
end
grug_classes = permissive({get_melee_bonus = function() return 0 end,
	registered_races = {}, race_ids = {}})
grug_mobs = permissive({})
grug_inventory = permissive({})
grug_jobs = permissive({})
grug_xp = permissive({get_level = function() return 10 end})

local function new_meta(fields)
	fields = fields or {}
	local meta = {fields = fields}
	function meta:get_string(key) return fields[key] or "" end
	function meta:set_string(key, value)
		if value == "" then fields[key] = nil else fields[key] = value end
	end
	function meta:get_int(key) return tonumber(fields[key]) or 0 end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:set_tool_capabilities() end
	return meta
end
ItemStack = function(source)
	local name, wear, fields = source or "", 0, {}
	if type(source) == "table" then
		name, wear = source:get_name(), source:get_wear()
		for key, value in pairs(source:get_meta().fields) do fields[key] = value end
	end
	local meta = new_meta(fields)
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" end
	function stack:get_count() return name == "" and 0 or 1 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return wear end
	function stack:set_wear(value) wear = value end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	function stack:to_string() return name end
	return stack
end
PcgRandom = function(seed)
	local state = seed
	return {next = function(_, low, high)
		state = (state * 1103515245 + 12345) % 2147483648
		return low + state % (high - low + 1)
	end}
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
current_mod = "grug_repair"
grug_repair = {}
dofile(ROOT .. "/mods/ITEMS/grug_repair/service.lua")
dofile(ROOT .. "/mods/ITEMS/grug_repair/presentation.lua")

-- player_api: the real registry (init.lua registers character.b3d), with
-- set_model/set_textures writing the fake player's properties.
player_api = nil
dofile(ROOT .. "/mods/BASE/player_api/init.lua")
for _, id in ipairs({"human", "dwarf", "elf", "orc", "troll", "undead"}) do
	grug_classes.registered_races[id] = {id = id}
end
grug_classes.get_race = function(player) return player._race end
local HAND_LIST = {weapon = "grug_weapon", offhand = "grug_offhand"}
local function slot_copy(player, list)
	local stack = player:get_inventory():get_stack(list, 1)
	return not stack:is_empty() and ItemStack(stack) or nil
end
grug_inventory.get_cosmetic_weapon = function(player) return slot_copy(player, "grug_weapon") end
grug_inventory.get_cosmetic_offhand = function(player) return slot_copy(player, "grug_offhand") end
grug_inventory.get_cosmetic_hand = function(player, slot)
	return slot_copy(player, HAND_LIST[slot] or "grug_weapon")
end

current_mod = "grug_visuals"
grug_visuals = {}
for _, file in ipairs({"looks", "compose", "enchant", "wield_geometry", "appearance", "apply"}) do
	dofile(ROOT .. "/mods/PLAYER/grug_visuals/" .. file .. ".lua")
end
grug_visuals.index_armor(registered)
local CLOAK = "grug_achievements_cloak_plain_grey.png"
local cloak_of = {}
grug_visuals.register_cloak_source(function(player)
	return cloak_of[player], cloak_of[player] and "plain_grey" or nil
end)
local V = grug_visuals

------------------------------------------------------------------------------
-- Fake players.
------------------------------------------------------------------------------
local function new_player(name, race, no_join)
	local fields, lists, props = {}, {}, {}
	local meta = new_meta(fields)
	local inv = {}
	function inv:get_stack(list, index)
		local stack = lists[list] and lists[list][index]
		return stack and ItemStack(stack) or ItemStack("")
	end
	function inv:set_stack(list, index, stack)
		lists[list] = lists[list] or {}
		lists[list][index] = ItemStack(stack)
	end
	local player = {_race = race, _wielded = ItemStack(""), props = props}
	function player:is_player() return true end
	function player:get_player_name() return name end
	function player:get_meta() return meta end
	function player:get_inventory() return inv end
	function player:get_wielded_item() return ItemStack(self._wielded) end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	function player:set_properties(p) for key, value in pairs(p) do props[key] = value end end
	function player:get_properties() return props end
	function player:set_animation() end
	function player:set_local_animation() end
	function player:hud_add() return 1 end
	if not no_join then
		for _, row in ipairs(joins) do row.fn(player) end
	end
	return player
end
local function equip(player, list, stack)
	player:get_inventory():set_stack(list, 1, stack or ItemStack(""))
	for _, fn in ipairs(equipment_consumers) do fn(player, list) end
end
local function gear_stack(name, prefix, suffix, broken)
	local stack = ItemStack(name)
	local affixes = {}
	if prefix then affixes[#affixes + 1] = {channel = "prefix", stat = prefix, tier = 3, value = 5} end
	if suffix then affixes[#affixes + 1] = {channel = "suffix", stat = suffix, tier = 3, value = 5} end
	if #affixes > 0 then
		stack:get_meta():set_string("grug_ench", core.serialize(affixes))
	end
	grug_items.refresh_enchant_image(stack, affixes)
	if broken then stack:set_wear(65535) end
	grug_repair.refresh_appearance(stack)
	return stack
end
local function wear_set(player, line, bracket)
	for _, slot in ipairs(V.SLOTS) do
		equip(player, "grug_" .. slot, ItemStack(grug_gear.armor_item(slot, line, bracket)))
	end
end

------------------------------------------------------------------------------
-- N. The baked file names.
------------------------------------------------------------------------------
local TEXTURES = ROOT .. "/mods/PLAYER/grug_visuals/textures/"
do
	local GRADES = {
		metal = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"},
		cloth = {"patch", "woven", "heavy", "silkweave", "silk", "stormweave"},
		leather = {"light", "cured", "heavy", "scaled", "sleek", "nightscale"},
	}
	local atlas, skin, missing = 0, 0, {}
	for line, grades in pairs(GRADES) do
		for bracket, grade in ipairs(grades) do
			for _, slot in ipairs(V.SLOTS) do
				local art = V.ARMOR_ART[line][slot][bracket]
				local stem = "grug_armor_" .. line .. "_" .. grade .. "_" .. slot
				eq(art.atlas, stem .. ".png", "N atlas layer name")
				eq(art.skin, slot ~= "head" and stem .. "_skin.png" or nil, "N skin layer name")
				for _, file in ipairs({art.atlas, art.skin}) do
					for _, name in ipairs({file, file:sub(1, -5) .. "_ench.png"}) do
						if not file_exists(TEXTURES .. name) then missing[#missing + 1] = name end
					end
				end
				atlas = atlas + 1
				skin = skin + (art.skin and 1 or 0)
			end
		end
	end
	eq(atlas, 72, "N 72 atlas layers")
	eq(skin, 54, "N 54 skin layers")
	check(#missing == 0, "N every baked file and mask exists in grug_visuals/textures (" ..
		#missing .. " missing, e.g. " .. tostring(missing[1]) .. ")")
	eq(grug_gear.MATERIALS[4].leather.key, "scaled", "N leather T4 keeps its key")
end

------------------------------------------------------------------------------
-- P. Players.
------------------------------------------------------------------------------
local model = player_api.registered_models[V.PLAYER_MODEL]
eq(#model.textures, 4, "P the player model registers four textures")
eq(model.textures[2], V.CLOAK_NONE, "P registered cloak empty")
eq(model.textures[3], V.ARMOR_NONE, "P registered armor empty")
eq(model.textures[4], V.WEAPON_NONE, "P registered weapon card empty")
eq(V.ARMOR_NONE, "blank.png", "P an empty slot is the builtin blank")
eq(V.WEAPON_NONE, "blank.png", "P an empty weapon card is the builtin blank")

local ada = new_player("ada", "human")
ada:get_meta():set_string("grug_visuals:look", "1,2,1,1,1")
for _, row in ipairs(joins) do row.fn(ada) end
local list = ada.props.textures
eq(ada.props.mesh, V.PLAYER_MODEL, "P the player model")
eq(#list, 4, "P bare: four textures")
eq(list[3], V.ARMOR_NONE, "P bare: no armor")
eq(list[4], V.WEAPON_NONE, "P bare: an empty weapon card")
local hair = V.LOOKS.human.styles[1].mask
check(has(list[1], hair), "P bare: the hair is drawn")
local bare_list = table.copy(list)

wear_set(ada, "metal", 6)
equip(ada, "grug_weapon", gear_stack("grug_gear:sword_abyssal_steel"))
list = ada.props.textures
eq(list[3], "(grug_armor_metal_abyssal_steel_head.png)^(grug_armor_metal_abyssal_steel_chest.png)^" ..
	"(grug_armor_metal_abyssal_steel_legs.png)^(grug_armor_metal_abyssal_steel_feet.png)",
	"P metal T6: the four atlas layers")
check(has(list[1], "^(grug_armor_metal_abyssal_steel_chest_skin.png)^" ..
	"(grug_armor_metal_abyssal_steel_legs_skin.png)^(grug_armor_metal_abyssal_steel_feet_skin.png)"),
	"P metal T6: the inner paint on the skin")
check(not has(list[1], hair), "P a helmet drops the hair")
check(not has(list[1], "[mask:"), "P no face window")
eq(list[4], V.WEAPON_NONE, "P the weapon card stays empty in the world")
eq(list[2], V.CLOAK_NONE, "P no cloak")
local t6_list = table.copy(list)

wear_set(ada, "cloth", 1)
equip(ada, "grug_head", ItemStack(""))
list = ada.props.textures
eq(list[3], "(grug_armor_cloth_patch_chest.png)^(grug_armor_cloth_patch_legs.png)^" ..
	"(grug_armor_cloth_patch_feet.png)", "P cloth T1 without a hood")
check(has(list[1], hair), "P no helmet: the hair is back")

-- An enchanted piece (prefix and suffix) and a broken one.
equip(ada, "grug_chest", gear_stack(grug_gear.armor_item("chest", "cloth", 1), "str", "dex"))
equip(ada, "grug_legs", gear_stack(grug_gear.armor_item("legs", "cloth", 1), nil, nil, true))
list = ada.props.textures
local chest = V.ARMOR_ART.cloth.chest[1]
check(has(list[3], "(" .. chest.atlas .. "^" .. grug_gear.enchant_layers(chest.atlas, "str", "dex") .. ")"),
	"P enchanted chest: both colours on its atlas layer")
check(has(list[1], "(" .. chest.skin .. "^" .. grug_gear.enchant_layers(chest.skin, "str", "dex") .. ")"),
	"P enchanted chest: both colours on its skin layer")
check(has(list[3], "((grug_armor_cloth_patch_legs.png)" .. grug_gear.BROKEN_MODIFIER .. ")"),
	"P broken legs: cracked on the atlas")
check(has(list[1], "((grug_armor_cloth_patch_legs_skin.png)" .. grug_gear.BROKEN_MODIFIER .. ")"),
	"P broken legs: cracked on the skin")
check(not has(list[3], "(grug_armor_cloth_patch_feet.png)" .. grug_gear.BROKEN_MODIFIER),
	"P the intact feet are not cracked")

cloak_of[ada] = CLOAK
V.apply(ada)
eq(ada.props.textures[2], CLOAK, "P the cloak is the second texture")

------------------------------------------------------------------------------
-- V. The preview seam.
------------------------------------------------------------------------------
do
	local preview = V.preview(ada)
	eq(preview.mesh, V.PLAYER_MODEL, "V the player model")
	eq(#preview.textures, 4, "V four textures")
	for index = 1, 3 do
		eq(preview.textures[index], ada.props.textures[index], "V texture " .. index .. " as applied")
	end
	eq(preview.textures[4], "grug_gear_item_sword_abyssal_steel.png", "V the sword on the weapon card")
	check(V.preview(ada) ~= preview and V.preview(ada).textures ~= preview.textures, "V a fresh table")
	equip(ada, "grug_weapon", gear_stack("grug_gear:sword_abyssal_steel", "str", nil, true))
	local image = V.preview(ada).textures[4]
	check(has(image, "grug_gear_item_sword_abyssal_steel_ench.png") and
		has(image, grug_gear.BROKEN_MODIFIER), "V an enchanted, broken sword as its stack shows")
	eq(image, V.hand_image(slot_copy(ada, "grug_weapon")), "V the hand image")
	equip(ada, "grug_weapon", ItemStack(""))
	eq(V.preview(ada).textures[4], V.WEAPON_NONE, "V no weapon: an empty card")
	-- A player the join apply has not reached yet (sfinv may build the page
	-- first): composed from the player's state, never nil.
	local early = new_player("early", "elf", true)
	local first = V.preview(early)
	check(first ~= nil and first.mesh == V.PLAYER_MODEL and #first.textures == 4,
		"V before any apply: the full answer")
	eq(early.props.textures, nil, "V before any apply: nothing applied yet")
	check(has(first.textures[1], V.LOOKS.elf.styles[1].mask), "V before any apply: the race look")
	equip(early, "grug_chest", ItemStack(grug_gear.armor_item("chest", "leather", 2)))
	early.props.textures = nil
	check(has(V.preview(early).textures[3], "grug_armor_leather_cured_chest.png"),
		"V the worn chest from the inventory, not from the object")
	local bob = new_player("bob", "dwarf")
	local bare = V.preview(bob)
	eq(bare.textures[2], V.CLOAK_NONE, "V no cloak")
	eq(bare.textures[3], V.ARMOR_NONE, "V no armor")
end

------------------------------------------------------------------------------
-- E. Armored NPCs.
------------------------------------------------------------------------------
do
	local function new_entity()
		local props = {}
		local object = {}
		function object:set_properties(p) for key, value in pairs(p) do props[key] = value end end
		function object:get_pos() return {x = 0, y = 0, z = 0} end
		return {object = object, props = props}
	end
	local writes = 0
	local function write_textures(entity, textures)
		writes = writes + 1
		entity.base_texture = textures
	end
	local guard = new_entity()
	guard._grug_visual_skin = "an old skin"
	local level = 30
	local spec = function(self)
		return {race = "orc", look = V.npc_look(self, "orc"), armor_line = "metal",
			level = level, weapon_family = "sword"}
	end
	local result = V.apply_entity(guard, spec, write_textures)
	eq(writes, 1, "E the first draw writes")
	eq(#guard.base_texture, 3, "E an armored NPC: skin, armor, weapon")
	eq(guard.base_texture[1], result.skin, "E the skin first")
	eq(guard.base_texture[2], result.armor, "E the armor second")
	check(has(result.armor, "grug_armor_metal_steel_chest.png"), "E level 30: the steel set")
	eq(guard.base_texture[3], V.WEAPON_NONE, "E an empty weapon card")
	eq(guard._grug_visual_skin, nil, "E the pre-Round-54 field is dropped")
	eq(guard._grug_visual_key, result.key, "E the key is kept")
	V.apply_entity(guard, spec, write_textures)
	eq(writes, 1, "E the same look: no rewrite")
	-- A change in the armor alone (the skin under a full set changes with the
	-- tier too, so a War Commander's chest layer: the skin moves; and a
	-- level change: the atlas moves).
	level = 31
	V.apply_entity(guard, spec, write_textures)
	eq(writes, 2, "E a new tier rewrites")
	local commander = function(self)
		local s = spec(self)
		s.armor_layers = {chest = "grug_mobs_commander_accord_overlay.png"}
		return s
	end
	local before_armor = guard.base_texture[2]
	V.apply_entity(guard, commander, write_textures)
	eq(writes, 3, "E the commander's chest layer rewrites")
	eq(guard.base_texture[2], before_armor, "E the commander's layer stays off the atlas")
	check(has(guard.base_texture[1], "grug_mobs_commander_accord_overlay.png"),
		"E the commander's layer on the skin")
	-- The plain write without the grug_mobs seam (a vendor): one texture.
	local vendor = new_entity()
	V.apply_entity(vendor, {race = "elf"})
	eq(#vendor.props.textures, 1, "E an unarmored NPC: the skin alone")

	-- The definitions: the armored chassis on the NPC model, every texture
	-- list with three entries; the unarmored ones back on character.b3d.
	local NPC = V.NPC_MODEL
	eq(NPC, "grug_visuals_npc.b3d", "E the NPC model's name")
	local guard_src = read_file(ROOT .. "/mods/ENTITIES/grug_mobs/guard.lua")
	check(has(guard_src, 'mesh = "' .. NPC .. '",\n\t\ttextures = {{texture, "blank.png", "blank.png"}},'),
		"E guard_def: the NPC model, three textures")
	check(not has(guard_src, '"character.b3d"'), "E guard.lua names no character.b3d")
	local bandit_src = read_file(ROOT .. "/mods/ENTITIES/grug_mobs/bandit.lua")
	check(has(bandit_src, 'mesh = "' .. NPC .. '",') and
		has(bandit_src, '{"grug_mobs_bandit_1.png", "blank.png", "blank.png"},') and
		has(bandit_src, '{"grug_mobs_bandit_2.png", "blank.png", "blank.png"},'),
		"E bandit_def: the NPC model, three textures per set")
	check(not has(bandit_src, 'mesh = "character.b3d"'), "E bandit.lua names no character.b3d mesh")
	local bosses = read_file(ROOT .. "/mods/ENTITIES/grug_mobs/bosses.lua")
	check(has(bosses, 'visual = "mesh", mesh = "' .. NPC .. '",') and
		has(bosses, 'textures = {{"character.png", "blank.png", "blank.png"}},'),
		"E kings and Generals (king_def) on the NPC model")
	check(not has(bosses, '"character.b3d"'), "E bosses.lua names no character.b3d")
	local poacher = read_file(ROOT .. "/mods/ENTITIES/grug_mobs/zero_asset_variants.lua")
	check(has(poacher, 'poacher._grug_visual = nil') and has(poacher, 'poacher.mesh = "character.b3d"'),
		"E the Poacher (no composed look) on character.b3d")
	-- Every `_grug_visual` with an armor_line sits on an NPC-model chassis:
	-- guard_def, bandit_def, and in bosses.lua the king, the royal guard and
	-- the General.
	local counts = {}
	for _, file in ipairs({"guard.lua", "bandit.lua", "bosses.lua", "start_villagers.lua",
			"mirefolk.lua", "zero_asset_variants.lua", "bandit_archer.lua"}) do
		local text = read_file(ROOT .. "/mods/ENTITIES/grug_mobs/" .. file)
		local n = 0
		for _ in text:gmatch('armor_line = "metal"') do n = n + 1 end
		for _ in text:gmatch('armor_line = "cloth"') do n = n + 1 end
		counts[file] = n
	end
	eq(counts["guard.lua"], 1, "E armor_line in guard_def")
	eq(counts["bandit.lua"], 1, "E armor_line in bandit_def")
	eq(counts["bosses.lua"], 3, "E armor_line for kings, royal guards and Generals")
	eq(counts["start_villagers.lua"] + counts["mirefolk.lua"] + counts["zero_asset_variants.lua"] +
		counts["bandit_archer.lua"], 0, "E no armor_line elsewhere")
end

------------------------------------------------------------------------------
-- R. The royal armour (the user, 2026-10-20: kings and royal guards on the
-- new model, an adapted variant of the guards' armour).
------------------------------------------------------------------------------
do
	local king = V.compose({race = "orc", look = V.KING_LOOKS.orc, royal = "king",
		armor_line = "metal", level = 65, weapon_family = "greataxe"})
	local guard = V.compose({race = "orc", royal = "guard", armor_line = "metal", level = 60,
		weapon_family = "sword"})
	local plain = V.compose({race = "orc", armor_line = "metal", level = 60})
	local cloth = V.ROYAL.orc.cloth
	eq(#king.textures, 3, "R a king on the NPC model")
	check(not has(king.armor, "_head"), "R a king wears no helmet")
	check(has(king.skin, V.LOOKS.orc.styles[V.KING_LOOKS.orc.style].mask), "R a king shows his hair")
	check(has(king.skin, "grug_visuals_crown.png"), "R and his crown")
	check(has(guard.armor, "grug_armor_metal_abyssal_steel_head.png"), "R a royal guard wears the T6 helmet")
	local chest = V.ARMOR_ART.metal.chest[6]
	local mask = chest.atlas:sub(1, -5) .. "_ench.png"
	check(has(guard.armor, "(" .. chest.atlas .. "^(" .. mask .. "^[verticalframe:2:0^[multiply:" ..
		cloth .. ")^(" .. mask .. "^[verticalframe:2:1^[multiply:" .. V.ROYAL_GOLD .. "))"),
		"R zone A in the royal cloth colour, zone B gold, full strength, inside the piece")
	local skin_mask = chest.skin:sub(1, -5) .. "_ench.png"
	check(has(guard.skin, skin_mask .. "^[verticalframe:2:0^[multiply:" .. cloth),
		"R the inner paint too")
	check(has(guard.skin, "grug_visuals_tabard_mask.png"), "R the tabard stays under the armour")
	check(not has(plain.armor, "[multiply:"), "R an ordinary guard: plain armour")
	local enchanted = V.compose({race = "orc", royal = "guard", armor_line = "metal", level = 60,
		armor_enchant = {chest = {prefix = "str"}}})
	local at_royal = enchanted.armor:find("[multiply:" .. V.ROYAL_GOLD, 1, true)
	local at_enchant = enchanted.armor:find("[multiply:" .. grug_gear.ENCHANT_COLORS.str, 1, true)
	check(at_royal and at_enchant and at_royal < at_enchant, "R enchant colours over the royal ones")
	check(#guard.skin <= V.APPEARANCE_TEXTURE_MAX and #guard.armor <= V.APPEARANCE_TEXTURE_MAX,
		"R within the stored cap")
	print(("royal: king %d bytes, royal guard %d bytes (all textures)"):format(
		#king.skin + #king.armor + #V.WEAPON_NONE, #guard.skin + #guard.armor + #V.WEAPON_NONE))
end

------------------------------------------------------------------------------
-- A. The stored appearance, version 2.
------------------------------------------------------------------------------
do
	eq(V.APPEARANCE_VERSION, 2, "A version 2")
	local stored = ada:get_meta():get_string(V.APPEARANCE_META)
	check(has(stored, '{"v":2,'), "A the stored value is version 2")
	local result = V.compose(V.player_spec(ada))
	check(has(stored, ',"textures":{"body":"' .. result.skin .. '","cloak":"' .. CLOAK ..
		'","armor":"' .. result.armor .. '"},'), "A body, cloak and armor in order")
	local bob = new_player("bob2", "dwarf")
	check(has(bob:get_meta():get_string(V.APPEARANCE_META), '"cloak":"none","armor":"none"}'),
		"A no armor: none")
	eq(V.APPEARANCE_JSON_MAX, 5 * V.APPEARANCE_TEXTURE_MAX + V.APPEARANCE_JSON_OVERHEAD,
		"A five texture strings")
end

------------------------------------------------------------------------------
-- H. Leather tier 4 "Hardened".
------------------------------------------------------------------------------
do
	eq(grug_gear.MATERIALS[4].leather.name, "Hardened", "H the grade's name")
	local nouns = {head = "Hood", chest = "Jerkin", legs = "Pants", feet = "Boots"}
	for _, slot in ipairs(V.SLOTS) do
		local name = "grug_gear:" .. slot .. "_leather_scaled"
		eq(grug_gear.armor_item(slot, "leather", 4), name, "H the item id stays")
		local def = registered[name]
		eq(def and def.description:match("^[^\n]+"), "Hardened " .. nouns[slot],
			"H " .. slot .. " description")
		-- A stack from before: its stored base name is the old one.
		local stack = ItemStack(name)
		stack:get_meta():set_string("grug_base_name", "Scaled " .. nouns[slot])
		stack:get_meta():set_string("grug_ench", core.serialize({
			{channel = "suffix", stat = "dex", tier = 3, value = 2}}))
		grug_items.regenerate_description(stack)
		eq(stack:get_meta():get_string("grug_base_name"), "Hardened " .. nouns[slot],
			"H " .. slot .. ": the stored base name renamed")
		check(has(stack:get_meta():get_string("description"), "Hardened " .. nouns[slot]),
			"H " .. slot .. ": the description reads Hardened")
	end
	-- Nothing else is renamed: another item's stored name stays.
	local other = ItemStack("grug_gear:chest_metal_steel")
	other:get_meta():set_string("grug_base_name", "Scaled Thing")
	grug_items.regenerate_description(other)
	eq(other:get_meta():get_string("grug_base_name"), "Scaled Thing", "H another item keeps its name")
	local cured = ItemStack("grug_gear:chest_leather_cured")
	grug_items.regenerate_description(cured)
	eq(cured:get_meta():get_string("grug_base_name"), "Cured Jerkin", "H tier 2 unchanged")
	-- The MATERIALS table stays readable by its balanced braces (tools/r45_rg).
	local text = read_file(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
	local block = text:match("grug_gear%.MATERIALS = (%b{})")
	local ok, parsed = pcall(function() return assert(loadstring("return " .. block))() end)
	check(ok and parsed[4].leather.name == "Hardened", "H MATERIALS parses by its braces")
end

------------------------------------------------------------------------------
-- M. What a client receives per character.
------------------------------------------------------------------------------
do
	local function total(textures)
		local n = 0
		for _, texture in ipairs(textures) do n = n + #texture end
		return n
	end
	local carl = new_player("carl", "human")
	local bare = total(carl.props.textures)
	wear_set(carl, "metal", 3)
	local t3 = total(carl.props.textures)
	-- The worst case: every slot enchanted in both channels and broken, the
	-- longest look and cloak (the race and look that give the longest skin).
	local worst, worst_skin, worst_armor = 0, 0, 0
	local pair = {prefix = "max_mana_percent", suffix = "attack_speed_percent"}
	for race, def in pairs(V.LOOKS) do
		for style = 1, #def.styles do for feature = 1, #def.features do
			for _, line in ipairs(V.LINES) do for bracket = 1, 6 do
				local armor, broken, enchant = {}, {}, {}
				for _, slot in ipairs(V.SLOTS) do
					armor[slot] = grug_gear.armor_item(slot, line, bracket)
					broken[slot] = true
					enchant[slot] = pair
				end
				local result = V.compose({race = race, look = {style = style, feature = feature},
					armor = armor, armor_broken = broken, armor_enchant = enchant})
				local length = #result.skin + #result.armor + 44 + #V.WEAPON_NONE
				if length > worst then
					worst, worst_skin, worst_armor = length, #result.skin, #result.armor
				end
			end end
		end end
	end
	local npc = V.compose({race = "troll", armor_line = "metal", bracket = 6})
	print(("lengths (bytes per character, all textures): player bare %d, metal T3 %d, " ..
		"worst %d (skin %d, armor %d, cloak 44, weapon %d); armored NPC T6 %d"):format(
		bare, t3, worst, worst_skin, worst_armor, #V.WEAPON_NONE, total(npc.textures)))
	check(worst_skin <= V.APPEARANCE_TEXTURE_MAX and worst_armor <= V.APPEARANCE_TEXTURE_MAX,
		"M the worst strings within the stored cap")
	check(#bare_list[1] < #t6_list[1], "M the inner paint adds to the skin")
end

if failures > 0 then
	error("R54 GAME PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
end
print("R54 GAME PORTABLE PASS checks=" .. checks)
