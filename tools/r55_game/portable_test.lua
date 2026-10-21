-- Round 55 lane GAME portable test (LuaJIT): the offhand look in the game
-- (docs/planning/round55-plan.md §4 GAME, docs/technical/offhand-format.md
-- §1, §5, §7).
--
--   luajit tools/r55_game/portable_test.lua [REPO]
--
-- Loads the REAL grug_gear, grug_quality, grug_repair (service and
-- presentation) and grug_visuals (looks, compose, enchant, wield_geometry,
-- appearance, apply with player_api's real registry) under a permissive engine
-- stub with ItemStack metadata and wear (tools/r54_game's), and drives
-- grug_visuals on fake players, fake NPC entities and its own wield poll.
-- The setting is `grug_visuals.OFFHAND_VISUALS` (init.lua reads
-- grug_offhand_visuals into it); this test switches it. Checks:
--   N  the offhand layers' names (format doc §7) for every shield and
--      spellbook, the six per-tier shield and spellbook icons and masks
--      (the picked art, tools/r55_offhand/bake.py) registered without a
--      tint and on disk;
--   C  composition with the look on: a Warrior's shield at each size step's
--      tiers, a Mage's and a Priest's spellbook, a Scout's blade (nothing),
--      no offhand, a broken and an enchanted shield (exactly as an armor
--      layer), the setting in the key;
--   O  the look off: every player list is 0.54.1's four plus three blanks,
--      compose ignores the offhand fields (the same cache entry), NPC lists
--      0.54.1's three plus two blanks with the digest over all five;
--   B  the back slot's two cards (format doc §5): `back_card` puts the image
--      into the left half (the cloak's card) or the right (the body's) of a
--      32 x 16 `[combine`, escaped as the engine unescapes it;
--   S  the Scout's back card through the real wield poll: nothing held, a
--      bow skill, a melee skill, a bow skill again, a pickaxe, the bow item,
--      the blade item, each changing
--      the card and rewriting the texture list exactly once; an unchanged
--      poll writes nothing; a cloak put on and taken off moves the card to
--      the other half (one rewrite each); a Warrior and a Scout with the look
--      off never;
--   W  the wings from a stub cloak source: on with a wing texture, blank
--      without one and with the look off;
--   P  the Character tab's preview: seven textures, the offhand layer, the
--      Scout's blade on the back (the bow is on the card), the wings;
--   A  the stored appearance version 3: `offhand` and `wings` ("none" when
--      empty and with the look off), a stored version 2 value rebuilt at
--      the next join, the caps (seven texture strings);
--   M  prints the texture string lengths per slot and in total, 0.54.1's
--      (the four slots) and now (look off and on): bare, metal T3, a fully
--      enchanted Warrior (and the same broken), a Scout; and the poll's
--      extra work per player and second.
-- Prints "R55 GAME PORTABLE PASS checks=<n>" or the failures.

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
local function file_exists(path)
	local handle = io.open(path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

------------------------------------------------------------------------------
-- Engine stub (tools/r54_game's, plus the globalsteps and connected players).
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
local joins, equipment_consumers, polls, connected = {}, {}, {}, {}
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
	register_globalstep = function(fn)
		if current_mod == "grug_visuals" then polls[#polls + 1] = fn end
	end,
	get_connected_players = function() return connected end,
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
	local handle = assert(io.open(ROOT .. "/mods/CORE/grug_core/combat.lua", "rb"))
	local body = handle:read("*a"):match("\n(function grug_core%.equipment_is_broken%(.-\nend)\n")
	handle:close()
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

current_mod = "player_api"
player_api = nil
dofile(ROOT .. "/mods/BASE/player_api/init.lua")
for _, id in ipairs({"human", "dwarf", "elf", "orc", "troll", "undead"}) do
	grug_classes.registered_races[id] = {id = id}
end
grug_classes.get_race = function(player) return player._race end
grug_classes.get_class = function(player) return player._class end
-- The hand lists of grug_inventory (HAND_RULES): a Scout's Melee skills
-- swing the offhand list, everyone else's the Weapon list.
local hand_reads = 0
local function slot_copy(player, list)
	local stack = player:get_inventory():get_stack(list, 1)
	return not stack:is_empty() and ItemStack(stack) or nil
end
local function hand_list(player, slot)
	if slot == "melee" then
		return player._class == "scout" and "grug_offhand" or "grug_weapon"
	end
	return slot == "offhand" and "grug_offhand" or "grug_weapon"
end
grug_inventory.get_cosmetic_weapon = function(player) return slot_copy(player, "grug_weapon") end
grug_inventory.get_cosmetic_offhand = function(player) return slot_copy(player, "grug_offhand") end
grug_inventory.get_cosmetic_hand = function(player, slot)
	hand_reads = hand_reads + 1
	return slot_copy(player, hand_list(player, slot))
end

current_mod = "grug_visuals"
grug_visuals = {}
for _, file in ipairs({"looks", "compose", "enchant", "wield_geometry", "appearance", "apply"}) do
	dofile(ROOT .. "/mods/PLAYER/grug_visuals/" .. file .. ".lua")
end
grug_visuals.index_armor(registered)
local V = grug_visuals
local CLOAK = "grug_achievements_cloak_plain_grey.png"
-- A wing texture: the Supporter Cloak's (the stub source pairs it with the
-- plain grey cloak; any file does for the slot).
local WINGS = "grug_achievements_cloak_supporter_wings.png"
local cloak_of, wings_of = {}, {}
V.register_cloak_source(function(player)
	return cloak_of[player], cloak_of[player] and "plain_grey" or nil, wings_of[player]
end)

-- The setting, switched by the test: a fresh cache each time, as a server
-- start would have.
local function set_look(on)
	V.OFFHAND_VISUALS = on
	for key in pairs(V.cache) do V.cache[key] = nil end
end

------------------------------------------------------------------------------
-- Fake players (tools/r54_game's, counting the texture writes).
------------------------------------------------------------------------------
local function new_player(name, race, class, no_join)
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
	local player = {_race = race, _class = class, _wielded = ItemStack(""), props = props,
		writes = 0}
	function player:is_player() return true end
	function player:get_player_name() return name end
	function player:get_meta() return meta end
	function player:get_inventory() return inv end
	function player:get_wielded_item() return ItemStack(self._wielded) end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	function player:set_properties(p)
		if p.textures then self.writes = self.writes + 1 end
		for key, value in pairs(p) do props[key] = value end
	end
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
local function wear_set(player, line, bracket, prefix, suffix, broken)
	for _, slot in ipairs(V.SLOTS) do
		equip(player, "grug_" .. slot, gear_stack(grug_gear.armor_item(slot, line, bracket),
			prefix, suffix, broken))
	end
end
local function poll()
	for _, fn in ipairs(polls) do fn(1.5) end
end
local function list_of(player)
	return player.props.textures or {}
end

local GRADES = {}
for bracket, materials in ipairs(grug_gear.MATERIALS) do GRADES[bracket] = materials.metal.key end
local SHIELD = function(bracket) return "grug_gear:shield_" .. GRADES[bracket] end
local BOOK = function(bracket) return "grug_gear:spellbook_" .. GRADES[bracket] end

------------------------------------------------------------------------------
-- N. The names.
------------------------------------------------------------------------------
do
	eq(#polls, 1, "N the wield poll registered")
	local GEAR = ROOT .. "/mods/ITEMS/grug_gear/textures/"
	for bracket, grade in ipairs(GRADES) do
		local shield = V.offhand_appearance[SHIELD(bracket)]
		local book = V.offhand_appearance[BOOK(bracket)]
		eq(shield and shield.file, "grug_offhand_shield_" .. grade .. ".png", "N shield T" .. bracket .. " layer")
		eq(book and book.file, "grug_offhand_book_" .. grade .. ".png", "N book T" .. bracket .. " layer")
		eq(shield and shield.kind, "shield", "N shield kind")
		eq(book and book.kind, "book", "N book kind")
		for _, pair in ipairs({{"shield", SHIELD(bracket)}, {"spellbook", BOOK(bracket)}}) do
			local kind, item = pair[1], pair[2]
			local icon = "grug_gear_" .. kind .. "_" .. grade .. ".png"
			eq(registered[item].inventory_image, icon, "N " .. kind .. " T" .. bracket .. " icon file")
			check(file_exists(GEAR .. icon) and file_exists(GEAR .. icon:sub(1, -5) .. "_ench.png"),
				"N " .. icon .. " and its mask ship")
			check(grug_gear.has_enchant_masks(registered[item]), "N " .. kind .. " T" .. bracket ..
				" takes enchant colours")
		end
	end
	local count = 0
	for _ in pairs(V.offhand_appearance) do count = count + 1 end
	eq(count, 12, "N twelve offhand items drawn (six shields, six spellbooks)")
	eq(V.offhand_appearance["grug_gear:sword_bronze"], nil, "N a blade is no offhand look")
	eq(V.OFFHAND_NONE .. V.BACK_NONE .. V.WINGS_NONE, "blank.pngblank.pngblank.png",
		"N the empty slots are the builtin blank")
end

------------------------------------------------------------------------------
-- O. The look off (the off switch; on is the default since 0.55.0): 0.54.1 plus blanks.
------------------------------------------------------------------------------
local OFF_LISTS = {}
do
	set_look(nil)
	local model = player_api.registered_models[V.PLAYER_MODEL]
	eq(#model.textures, 7, "O the player model registers seven textures")
	local wanda = new_player("wanda", "dwarf", "warrior")
	wear_set(wanda, "metal", 3)
	equip(wanda, "grug_offhand", gear_stack(SHIELD(3), "str", "dex"))
	cloak_of[wanda], wings_of[wanda] = CLOAK, WINGS
	V.apply(wanda)
	local list = list_of(wanda)
	local spec = V.player_spec(wanda)
	eq(spec.offhand_item, nil, "O player_spec reads no offhand item with the look off")
	local plain = V.compose({race = "dwarf", armor = spec.armor, armor_broken = spec.armor_broken,
		armor_enchant = spec.armor_enchant})
	eq(#list, 7, "O seven textures")
	eq(list[1], plain.skin, "O the skin as 0.54.1")
	eq(list[2], CLOAK, "O the cloak as 0.54.1")
	eq(list[3], plain.armor, "O the armor as 0.54.1")
	eq(table.concat(list, ",", 4), "blank.png,blank.png,blank.png,blank.png",
		"O weapon card, offhand, back and wings blank (the wings too)")
	OFF_LISTS.wanda = table.copy(list)
	-- compose ignores the offhand fields with the look off: one cache entry.
	local with = V.compose({race = "human", offhand_item = SHIELD(6), offhand_broken = true,
		offhand_enchant = {prefix = "str"}})
	eq(with, V.compose({race = "human"}), "O the offhand fields leave the composition alone")
	eq(with.offhand, V.OFFHAND_NONE, "O no offhand layer")
	-- A Scout with the look off: no back card, and the poll writes nothing.
	local sam = new_player("sam", "elf", "scout")
	equip(sam, "grug_weapon", gear_stack(grug_gear.STARTER_BOW))
	equip(sam, "grug_offhand", gear_stack(grug_gear.STARTER_SWORD))
	connected[1] = sam
	registered["test:bow_skill"] = {groups = {grug_ability = 1}, _grug_ability_slot = "weapon"}
	sam._wielded = ItemStack("test:bow_skill")
	local before = sam.writes
	poll()
	eq(sam.writes, before, "O the look off: the poll never writes")
	eq(list_of(sam)[6], V.BACK_NONE, "O the look off: no back card")
	connected[1] = nil
	-- NPCs: 0.54.1's three plus two blanks, the digest over all five.
	local npc = V.compose({race = "orc", armor_line = "metal", level = 30, weapon_family = "sword"})
	eq(#npc.textures, 5, "O an armored NPC: five textures")
	eq(npc.textures[3] .. "," .. npc.textures[4] .. "," .. npc.textures[5],
		"blank.png,blank.png,blank.png", "O weapon card, offhand and back blank")
	eq(npc.digest:match("^(%d+):"), tostring(#table.concat(npc.textures, "\n")),
		"O the digest covers all five (an NPC saved with three is redrawn once)")
	eq(#V.compose({race = "elf"}).textures, 1, "O an unarmored NPC: the skin alone")
	check(has(V.compose({race = "human"}).key, ";-"), "O the key carries the look's state")
end

------------------------------------------------------------------------------
-- C. Composition with the look on.
------------------------------------------------------------------------------
do
	set_look(true)
	check(V.compose({race = "human"}).key ~= nil and has(V.compose({race = "human"}).key, ";offhand"),
		"C the setting is part of the key")
	-- A Warrior's shield at each size step's tiers (the size is in the baked
	-- layer: the game names the tier's file).
	local wren = new_player("wren", "human", "warrior")
	for _, bracket in ipairs({1, 3, 6}) do
		equip(wren, "grug_offhand", gear_stack(SHIELD(bracket)))
		eq(list_of(wren)[5], "(grug_offhand_shield_" .. GRADES[bracket] .. ".png)",
			"C Warrior shield T" .. bracket)
	end
	-- Broken: cracked as a worn piece.
	equip(wren, "grug_offhand", gear_stack(SHIELD(2), nil, nil, true))
	eq(list_of(wren)[5], "((grug_offhand_shield_iron.png)" .. grug_gear.BROKEN_MODIFIER .. ")",
		"C a broken shield: the armor's broken modifier")
	-- Enchanted: the zones through its own mask, as an armor layer.
	equip(wren, "grug_offhand", gear_stack(SHIELD(4), "str", "armor_rating"))
	local file = "grug_offhand_shield_silversteel.png"
	eq(list_of(wren)[5], "(" .. file .. "^" .. grug_gear.enchant_layers(file, "str", "armor_rating") .. ")",
		"C an enchanted shield: both colours inside its layer")
	check(has(list_of(wren)[5], "grug_offhand_shield_silversteel_ench.png^[verticalframe:2:1"),
		"C ... zone B through the layer's own mask")
	-- An enchanted and broken one: colours inside, cracks over all.
	equip(wren, "grug_offhand", gear_stack(SHIELD(4), "str", nil, true))
	eq(list_of(wren)[5], "((" .. file .. "^" .. grug_gear.enchant_layers(file, "str") .. ")" ..
		grug_gear.BROKEN_MODIFIER .. ")", "C enchanted and broken")
	-- An affix without a colour draws plainly.
	equip(wren, "grug_offhand", gear_stack(SHIELD(5), "no_such_stat"))
	eq(list_of(wren)[5], "(grug_offhand_shield_embersteel.png)", "C an unknown stat: plain")
	equip(wren, "grug_offhand", ItemStack(""))
	eq(list_of(wren)[5], V.OFFHAND_NONE, "C no offhand: blank")
	eq(list_of(wren)[6], V.BACK_NONE, "C a Warrior: no back card")
	-- Mage and Priest with a book.
	for _, row in ipairs({{"mira", "mage", 2}, {"pia", "priest", 5}}) do
		local p = new_player(row[1], "elf", row[2])
		equip(p, "grug_offhand", gear_stack(BOOK(row[3]), "int", "max_mana_percent"))
		local book = "grug_offhand_book_" .. GRADES[row[3]] .. ".png"
		eq(list_of(p)[5], "(" .. book .. "^" .. grug_gear.enchant_layers(book, "int", "max_mana_percent") ..
			")", "C " .. row[2] .. " spellbook T" .. row[3])
		eq(list_of(p)[6], V.BACK_NONE, "C " .. row[2] .. ": no back card")
	end
	-- A Scout's offhand slot holds the Melee blade: nothing in the offhand.
	local skye = new_player("skye", "elf", "scout")
	equip(skye, "grug_weapon", gear_stack(grug_gear.STARTER_BOW))
	equip(skye, "grug_offhand", gear_stack(grug_gear.STARTER_SWORD, "dex"))
	eq(list_of(skye)[5], V.OFFHAND_NONE, "C a Scout's blade is no offhand look")
	-- The armor and the rest stay as before.
	local spec = V.player_spec(wren)
	eq(list_of(wren)[3], V.compose(spec).armor, "C the armor slot unchanged")
	eq(#list_of(wren), 7, "C seven textures")
end

------------------------------------------------------------------------------
-- B. The back slot's two cards.
------------------------------------------------------------------------------
-- The engine's reading of a `[combine` part (src/client/imagesource.cpp:
-- Strfnd next_esc(":", '\\') then unescape_string): split at the first
-- unescaped ":", drop each escaping backslash.
local function combine_parts(texture)
	local w, h, x, y, rest = texture:match("^%[combine:(%d+)x(%d+):(%d+),(%d+)=(.*)$")
	if not w then return nil end
	local out, index = {}, 1
	while index <= #rest do
		local char = rest:sub(index, index)
		if char == "\\" then
			out[#out + 1] = rest:sub(index + 1, index + 1)
			index = index + 2
		elseif char == ":" then
			return nil -- a second part: the image was cut
		else
			out[#out + 1] = char
			index = index + 1
		end
	end
	return {w = tonumber(w), h = tonumber(h), x = tonumber(x), y = tonumber(y),
		image = table.concat(out)}
end
do
	eq(V.back_card(V.BACK_NONE, true), V.BACK_NONE, "B no card: blank")
	eq(V.back_card("grug_gear_bow_birch.png", true), "[combine:32x16:0,0=grug_gear_bow_birch.png\\^[transformR180",
		"B with a cloak: the left half, turned 180 degrees (grip up, 2026-10-21)")
	eq(V.back_card("grug_gear_bow_birch.png", false), "[combine:32x16:16,0=grug_gear_bow_birch.png\\^[transformR180",
		"B without: the right half")
	local tricky = "((grug_gear_bow_birch.png^[hsl:0:-20:16^(grug_gear_bow_birch_ench.png^" ..
		"[verticalframe:2:0^[multiply:#20dea2^[opacity:128))^[hsl:0:-80:-35^[cracko:1:4)"
	local card = V.back_card(tricky, false)
	local parts = combine_parts(card)
	check(parts ~= nil and parts.w == 32 and parts.h == 16 and parts.x == 16 and parts.y == 0,
		"B a 32 x 16 combine, the image at 16,0")
	eq(parts and parts.image, tricky .. "^[transformR180", "B the escaped image reads back exactly, turned")
	check(not card:sub(#"[combine:32x16:16,0=" + 1):find("[^\\][%^:]"), "B every ^ and : escaped")
	eq(combine_parts(V.back_card("a\\b.png", true)).image, "a\\b.png^[transformR180", "B a backslash escaped too")
end

------------------------------------------------------------------------------
-- S. The Scout's back card through the poll.
------------------------------------------------------------------------------
local SCOUT
do
	set_look(true)
	registered["test:strike"] = {groups = {grug_ability = 1}, _grug_ability_slot = "melee"}
	registered["test:pickaxe"] = {groups = {pickaxe = 1}, inventory_image = "test_pickaxe.png"}
	local scout = new_player("scout", "troll", "scout")
	SCOUT = scout
	connected[1] = scout
	local bow = gear_stack(grug_gear.weapon_item("bow", 3), "dex", nil)
	local sword = gear_stack(grug_gear.weapon_item("sword", 3), nil, nil, true)
	equip(scout, "grug_weapon", bow)
	equip(scout, "grug_offhand", sword)
	local bow_raw = bow:get_meta():get_string("inventory_image")
	local sword_raw = sword:get_meta():get_string("inventory_image")
	check(has(bow_raw, "_ench.png") and has(sword_raw, grug_gear.BROKEN_MODIFIER),
		"S the stacks carry their own images (enchanted bow, broken sword)")
	-- No cloak: the body's card, the right half.
	local bow_image, sword_image = V.back_card(bow_raw, false), V.back_card(sword_raw, false)
	eq(list_of(scout)[6], bow_image, "S nothing held: the bow on the back, as its stack shows it")
	local steps = {
		{"test:bow_skill", sword_image, "a bow skill: the sword on the back"},
		{"test:strike", bow_image, "a melee skill: the bow on the back"},
		{"test:bow_skill", sword_image, "a bow skill again: the sword"},
		{"test:pickaxe", bow_image, "a pickaxe: the bow"},
		-- The rule compares what the hand shows with the equipped weapons.
		{bow:get_name(), sword_image, "the bow item itself held: the sword"},
		{sword:get_name(), bow_image, "the blade item itself held: the bow"},
	}
	for _, step in ipairs(steps) do
		scout._wielded = ItemStack(step[1])
		local before = scout.writes
		poll()
		eq(list_of(scout)[6], step[2], "S " .. step[3])
		eq(scout.writes, before + 1, "S " .. step[3] .. ": one rewrite")
		poll()
		eq(scout.writes, before + 1, "S " .. step[3] .. ": the next poll writes nothing")
		eq(list_of(scout)[5], V.OFFHAND_NONE, "S the offhand stays empty")
	end
	-- An empty hand after the pickaxe: still the bow, no write.
	scout._wielded = ItemStack("")
	local before = scout.writes
	poll()
	eq(scout.writes, before, "S empty hands after the blade: the bow stays, no write")
	-- The rest of the list rides along unchanged.
	local applied = table.copy(list_of(scout))
	scout._wielded = ItemStack("test:bow_skill")
	poll()
	for index = 1, 7 do
		if index ~= 6 then
			eq(list_of(scout)[index], applied[index], "S a card swap keeps texture " .. index)
		end
	end
	-- An equipment change goes through apply and keeps the card of the held skill.
	equip(scout, "grug_head", gear_stack(grug_gear.armor_item("head", "leather", 3)))
	eq(list_of(scout)[6], sword_image, "S apply keeps the held skill's card")
	-- An empty Melee slot under a bow skill: nothing on the back.
	equip(scout, "grug_offhand", ItemStack(""))
	eq(list_of(scout)[6], V.BACK_NONE, "S no blade: an empty card")
	equip(scout, "grug_offhand", sword)
	-- A cloak moves the card to the cloak's half, and back without it.
	cloak_of[scout] = CLOAK
	local before_cloak = scout.writes
	V.apply(scout)
	eq(list_of(scout)[6], V.back_card(sword_raw, true), "S a cloak: the card on the cloak (left half)")
	eq(scout.writes, before_cloak + 1, "S a cloak: one rewrite")
	poll()
	eq(scout.writes, before_cloak + 1, "S a cloak: the next poll writes nothing")
	scout._wielded = ItemStack("test:strike")
	poll()
	eq(list_of(scout)[6], V.back_card(bow_raw, true), "S a cloak and a melee skill: the bow, left")
	cloak_of[scout] = nil
	V.apply(scout)
	eq(list_of(scout)[6], V.back_card(bow_raw, false), "S the cloak off: the body's card (right half)")
	eq(scout.writes, before_cloak + 3, "S the cloak off: one rewrite")
	scout._wielded = ItemStack("test:bow_skill")
	poll()
	-- Not a Scout: the poll never writes.
	local wade = new_player("wade", "human", "warrior")
	connected[2] = wade
	wade._wielded = ItemStack("test:bow_skill")
	equip(wade, "grug_weapon", gear_stack("grug_gear:sword_steel"))
	before = wade.writes
	poll()
	poll()
	eq(wade.writes, before, "S a Warrior: the poll never writes")
	connected[2] = nil
	-- The poll's extra work for a Scout: one cosmetic hand read per second.
	scout._wielded = ItemStack("test:pickaxe")
	poll()
	local reads = hand_reads
	poll()
	eq(hand_reads - reads, 1, "S a Scout with a tool: one hand read per poll (the card)")
	scout._wielded = ItemStack("test:strike")
	poll()
	reads = hand_reads
	poll()
	eq(hand_reads - reads, 2, "S a Scout with a skill: the shown item's read and the card's")
	connected[1] = nil
end

------------------------------------------------------------------------------
-- W. The wings.
------------------------------------------------------------------------------
do
	set_look(true)
	local wyn = new_player("wyn", "human", "priest")
	cloak_of[wyn] = CLOAK
	V.apply(wyn)
	eq(list_of(wyn)[7], V.WINGS_NONE, "W a cloak without wings: blank")
	wings_of[wyn] = WINGS
	local before = wyn.writes
	V.apply(wyn)
	eq(list_of(wyn)[7], WINGS, "W a cloak with wings: its texture")
	eq(wyn.writes, before + 1, "W one rewrite")
	check(has(wyn:get_meta():get_string(V.APPEARANCE_META), '"wings":"' .. WINGS .. '"'),
		"W stored in the appearance")
	set_look(nil)
	local wyn_off = new_player("wyn_off", "human", "priest")
	cloak_of[wyn_off], wings_of[wyn_off] = CLOAK, WINGS
	V.apply(wyn_off)
	eq(list_of(wyn_off)[7], V.WINGS_NONE, "W the look off: no wings")
	check(has(wyn_off:get_meta():get_string(V.APPEARANCE_META), '"wings":"none"'),
		"W the look off: none stored")
end

------------------------------------------------------------------------------
-- P. The Character tab.
------------------------------------------------------------------------------
do
	set_look(true)
	local pat = new_player("pat", "orc", "warrior")
	equip(pat, "grug_weapon", gear_stack("grug_gear:sword_steel"))
	equip(pat, "grug_offhand", gear_stack(SHIELD(6)))
	cloak_of[pat], wings_of[pat] = CLOAK, WINGS
	V.apply(pat)
	local preview = V.preview(pat)
	eq(#preview.textures, 7, "P seven textures")
	-- the card mirrors its image across the anti-diagonal (the Character tab, 2026-10-21)
	eq(preview.textures[4], "grug_gear_item_sword_steel.png^[transformFYR90", "P the sword on the weapon card")
	eq(preview.textures[5], "(grug_offhand_shield_abyssal_steel.png)", "P the shield")
	eq(preview.textures[6], V.BACK_NONE, "P a Warrior: no back card")
	eq(preview.textures[7], WINGS, "P the wings")
	for _, index in ipairs({1, 2, 3, 5, 7}) do
		eq(preview.textures[index], list_of(pat)[index], "P texture " .. index .. " as applied")
	end
	-- The Scout: the weapon card shows the bow, so the blade is on the back,
	-- whatever the hotbar holds.
	SCOUT._wielded = ItemStack("test:strike")
	local scout_preview = V.preview(SCOUT)
	local bow_raw = slot_copy(SCOUT, "grug_weapon"):get_meta():get_string("inventory_image")
	local blade_raw = slot_copy(SCOUT, "grug_offhand"):get_meta():get_string("inventory_image")
	eq(scout_preview.textures[4], V.hand_image(slot_copy(SCOUT, "grug_weapon")) .. "^[transformFYR90", "P the bow on the card")
	check(has(scout_preview.textures[4], bow_raw), "P ... the equipped bow")
	eq(scout_preview.textures[6], V.back_card(blade_raw, false), "P the Scout's blade on the back (no cloak)")
	cloak_of[SCOUT] = CLOAK
	eq(V.preview(SCOUT).textures[6], V.back_card(blade_raw, true), "P with a cloak: on the cloak's card")
	cloak_of[SCOUT] = nil
	set_look(nil)
	local off = V.preview(pat)
	eq(table.concat(off.textures, ",", 5), "blank.png,blank.png,blank.png", "P the look off: blank")
	eq(V.preview(SCOUT).textures[6], V.BACK_NONE, "P the look off: no card")
end

------------------------------------------------------------------------------
-- A. The stored appearance version 3.
------------------------------------------------------------------------------
do
	eq(V.APPEARANCE_VERSION, 3, "A version 3")
	eq(V.APPEARANCE_JSON_MAX, 7 * V.APPEARANCE_TEXTURE_MAX + V.APPEARANCE_JSON_OVERHEAD,
		"A the JSON cap holds seven texture strings")
	set_look(nil)
	local ada = new_player("ada", "human", "warrior", true)
	ada:get_meta():set_string("grug_visuals:look", "1,2,1,1,1")
	ada:get_inventory():set_stack("grug_offhand", 1, gear_stack(SHIELD(2)))
	-- A version 2 value from 0.54.1 is rebuilt at the next join.
	local v2 = '{"v":2,"race":"human","look":{"tone":1,"hair":2,"style":1,"eyes":1,"feature":1},' ..
		'"cloak":"none","visual_size":{"x":1,"y":1,"z":1},"textures":{"body":"x.png",' ..
		'"cloak":"none","armor":"none"},"slots":{}}'
	ada:get_meta():set_string(V.APPEARANCE_META, v2)
	for _, row in ipairs(joins) do row.fn(ada) end
	local stored = ada:get_meta():get_string(V.APPEARANCE_META)
	check(has(stored, '{"v":3,'), "A a version 2 value is version 3 after the join")
	check(has(stored, '"armor":"none","offhand":"none","wings":"none"},"slots":'),
		"A the look off: offhand and wings none, in order")
	check(has(stored, '"offhand":{"item":"' .. SHIELD(2) .. '"'), "A the offhand slot still stored")
	set_look(true)
	V.apply(ada)
	stored = ada:get_meta():get_string(V.APPEARANCE_META)
	check(has(stored, '"offhand":"(grug_offhand_shield_iron.png)"'), "A the look on: the offhand layer")
	check(not has(stored, "back"), "A the back card is never stored")
	-- The worst offhand string within the per-string cap.
	local worst = ""
	for name in pairs(V.offhand_appearance) do
		local layer = V.compose({race = "human", offhand_item = name, offhand_broken = true,
			offhand_enchant = {prefix = "max_mana_percent", suffix = "attack_speed_percent"}}).offhand
		if #layer > #worst then worst = layer end
	end
	check(#worst <= V.APPEARANCE_TEXTURE_MAX, "A the worst offhand layer within the cap (" .. #worst .. ")")
	print("worst offhand layer: " .. #worst .. " bytes")
	set_look(nil)
end

------------------------------------------------------------------------------
-- M. What a client receives per character (bytes of the texture strings).
------------------------------------------------------------------------------
do
	local function lengths(list)
		local parts, total = {}, 0
		for index, texture in ipairs(list) do
			parts[index] = #texture
			total = total + #texture
		end
		return total, table.concat(parts, "/")
	end
	local function old_total(list)
		local total = 0
		for index = 1, 4 do total = total + #list[index] end
		return total
	end
	local function row(label, off_list, on_list)
		local off_total, off_parts = lengths(off_list)
		local on_total, on_parts = lengths(on_list)
		print(("%-34s 0.54.1 %5d | off %5d (%s) | on %5d (%s)"):format(label, old_total(off_list),
			off_total, off_parts, on_total, on_parts))
	end
	local function dress(name, class, setup)
		local lists = {}
		for _, on in ipairs({false, true}) do
			set_look(on or nil)
			local p = new_player(name .. (on and "_on" or "_off"), "human", class)
			setup(p)
			V.apply(p)
			lists[#lists + 1] = table.copy(list_of(p))
		end
		set_look(nil)
		return lists[1], lists[2]
	end
	print("texture string lengths (bytes; slots skin/cloak/armor/weapon/offhand/back/wings):")
	row("bare", dress("m_bare", "warrior", function() end))
	row("Warrior metal T3, shield T3", dress("m_t3", "warrior", function(p)
		wear_set(p, "metal", 3)
		equip(p, "grug_offhand", gear_stack(SHIELD(3)))
	end))
	local pair = {"max_mana_percent", "attack_speed_percent"}
	row("Warrior T6 fully enchanted", dress("m_ench", "warrior", function(p)
		wear_set(p, "metal", 6, pair[1], pair[2])
		equip(p, "grug_offhand", gear_stack(SHIELD(6), pair[1], pair[2]))
		cloak_of[p] = "grug_achievements_cloak_wyvernslayer_3.png"
	end))
	row("Warrior T6 enchanted and broken", dress("m_worst", "warrior", function(p)
		wear_set(p, "metal", 6, pair[1], pair[2], true)
		equip(p, "grug_offhand", gear_stack(SHIELD(6), pair[1], pair[2], true))
		cloak_of[p] = "grug_achievements_cloak_wyvernslayer_3.png"
	end))
	row("Scout leather T5, enchanted bow", dress("m_scout", "scout", function(p)
		wear_set(p, "leather", 5)
		equip(p, "grug_weapon", gear_stack(grug_gear.weapon_item("bow", 6), pair[1], pair[2]))
		equip(p, "grug_offhand", gear_stack(grug_gear.weapon_item("sword", 6), pair[1], pair[2], true))
	end))
	row("Scout worst: broken enchanted bow, cloak", dress("m_scout_worst", "scout", function(p)
		wear_set(p, "leather", 6, pair[1], pair[2], true)
		equip(p, "grug_weapon", gear_stack(grug_gear.weapon_item("bow", 6), pair[1], pair[2], true))
		equip(p, "grug_offhand", gear_stack(grug_gear.weapon_item("sword", 6), pair[1], pair[2], true))
		cloak_of[p] = "grug_achievements_cloak_wyvernslayer_3.png"
	end))
	local npc = V.compose({race = "troll", armor_line = "metal", bracket = 6})
	print(("armored NPC T6: %d bytes (0.54.1: %d)"):format(lengths(npc.textures),
		#npc.textures[1] + #npc.textures[2] + #npc.textures[3]))
end

if failures > 0 then
	error("R55 GAME PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
end
print("R55 GAME PORTABLE PASS checks=" .. checks)
