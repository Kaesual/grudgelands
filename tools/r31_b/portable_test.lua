-- Round 31 Lane B portable test (LuaJIT): enchant colours (round31-plan.md
-- §2.2), stages 1 and 2.
--
-- Loads the REAL grug_gear (init.lua with permissions.lua, enchant_colors.lua
-- and trinkets.lua), grug_visuals' looks.lua, compose.lua and enchant.lua, and
-- grug_quality's init.lua, under a permissive engine stub that records every
-- registered item and models ItemStack metadata (an empty string removes a
-- key, as the engine's metadata does):
--   A. the colour table: exactly the nine affix stats, each a distinct
--      "#rrggbb", at 50 % strength;
--   B. the modifier: no affix (nil, unknown) keeps the image byte for byte;
--      one layer per affix naming the item's own mask; layers alone for the
--      worn seam; strip_enchant takes them off again;
--   C. every enchantable item (weapons, offhands, armour; never a trinket) is
--      flagged for masks and every worn overlay has its mask file;
--   D. per-stack image: grug_quality writes the image whenever affixes are
--      set (a loot roll, an enchant operation) and removes it when they are
--      cleared (a crafted output); a plain stack never gets the key; a broken
--      stack whose uncracked image is unchanged is not rewritten;
--   E. body colours: armor_layers from worn pieces, inside each piece's
--      parentheses of the composed skin, the helmet's under its face window;
--      a plain set composes exactly as before (same key, same texture);
--   F. NPC weapons: weapon_colors gives an item string with the image, plain
--      without; every king's fixed colours come from its weapon's pool;
--   G. the station legend: nine swatches in the table's colours (Round 45:
--      no station dialog draws it until the Crafting tab's enchanting box);
--   H. reports the worst-case modifier lengths.
--
--   luajit tools/r31_b/portable_test.lua [REPO]
--   luajit tools/r31_b/portable_test.lua REPO emit OPACITY PAIR...
--     (for the preview page: one line per item / worn overlay and pair,
--      "item<TAB>name<TAB>pair<TAB>texture" and
--      "worn<TAB>line<TAB>slot<TAB>bracket<TAB>pair<TAB>texture",
--      PAIR as prefix:suffix with "-" for none)
-- Prints "R31 B PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local MODE = arg and arg[2] or "test"
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end

------------------------------------------------------------------------------
-- Engine stub: every unknown function is a no-op; items are recorded.
------------------------------------------------------------------------------
local registered = {}
local function permissive(base)
	return setmetatable(base, {__index = function()
		return function() end
	end})
end
local modpaths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_visuals = ROOT .. "/mods/PLAYER/grug_visuals",
	grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
}
local current_mod = "grug_gear"
local serial = {}
core = permissive({
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	formspec_escape = function(text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
	serialize = function(value) serial[#serial + 1] = value; return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and serial[index] or nil
	end,
	get_us_time = function() return 1 end,
})
grug_core = permissive({level_scale = function() return 1 end})
grug_classes = permissive({get_melee_bonus = function() return 0 end})
grug_mobs = permissive({})
grug_inventory = permissive({})
grug_jobs = permissive({})
grug_xp = permissive({get_level = function() return 10 end})

-- ItemStack with real metadata semantics: set_string("") removes the key.
local function new_meta()
	local fields = {}
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
ItemStack = function(name)
	local meta = new_meta()
	local stack = {}
	function stack:get_name() return name end
	function stack:is_empty() return name == "" end
	function stack:get_count() return 1 end
	function stack:get_meta() return meta end
	function stack:get_definition() return registered[name] or {} end
	function stack:get_wear() return 0 end
	function stack:get_tool_capabilities() return (registered[name] or {}).tool_capabilities end
	function stack:to_string()
		local keys = {}
		for key in pairs(meta.fields) do keys[#keys + 1] = key end
		table.sort(keys)
		local out = name
		for _, key in ipairs(keys) do out = out .. " " .. key .. "=" .. meta.fields[key] end
		return out
	end
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
current_mod = "grug_visuals"
grug_visuals = {}
dofile(ROOT .. "/mods/PLAYER/grug_visuals/looks.lua")
dofile(ROOT .. "/mods/PLAYER/grug_visuals/compose.lua")
dofile(ROOT .. "/mods/PLAYER/grug_visuals/enchant.lua")
grug_visuals.index_armor(registered)

local COLORS = grug_gear.ENCHANT_COLORS
local enchant_image = grug_gear.enchant_image

local function file_exists(path)
	local handle = io.open(path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

local function stem_of(image)
	return image:match("^([%w_%-]+)%.png")
end

-- Every item whose stack can carry affixes and has a texture of its own:
-- the weapons, offhands and armour of grug_gear.
local function gear(def)
	local groups = def.groups or {}
	return (groups.grug_equip_weapon or 0) > 0 or (groups.grug_shield or 0) > 0 or
		(groups.grug_spellbook or 0) > 0 or (groups.grug_armor_class or 0) > 0
end

local items = {}
for name, def in pairs(registered) do
	if gear(def) then items[#items + 1] = name end
end
table.sort(items)

-- What compose appends inside a worn piece's parentheses.
local function worn_layer(overlay, prefix, suffix, broken)
	local piece = enchant_image(overlay, prefix, suffix)
	if broken then piece = grug_gear.broken_image(piece) end
	return "^(" .. piece .. ")"
end

if MODE == "emit" then
	grug_gear.ENCHANT_OPACITY = tonumber(arg[3]) or 255
	local pairs_wanted, bodies = {}, {}
	for index = 4, #arg do
		local race, line, bracket = arg[index]:match("^body=(%a+):(%a+):(%d)$")
		if race then
			bodies[#bodies + 1] = {race = race, line = line, bracket = tonumber(bracket)}
		else
			pairs_wanted[#pairs_wanted + 1] = arg[index]
		end
	end
	local function split_pair(pair)
		local prefix, suffix = pair:match("^([^:]*):([^:]*)$")
		return prefix ~= "-" and prefix or nil, suffix ~= "-" and suffix or nil
	end
	for _, name in ipairs(items) do
		for _, pair in ipairs(pairs_wanted) do
			local prefix, suffix = split_pair(pair)
			print("item\t" .. name .. "\t" .. pair .. "\t" ..
				enchant_image(registered[name].inventory_image, prefix, suffix))
		end
	end
	for _, line in ipairs(grug_visuals.LINES) do
		for _, slot in ipairs(grug_visuals.SLOTS) do
			for bracket, overlay in ipairs(grug_visuals.OVERLAY[line][slot]) do
				for _, pair in ipairs(pairs_wanted) do
					local prefix, suffix = split_pair(pair)
					print("worn\t" .. line .. "\t" .. slot .. "\t" .. bracket .. "\t" ..
						pair .. "\t" .. worn_layer(overlay, prefix, suffix, false):sub(2))
				end
			end
		end
	end
	-- Whole bodies through the real compose: a full set of one line and
	-- bracket, every piece with the pair's colours.
	for _, body in ipairs(bodies) do
		for _, pair in ipairs(pairs_wanted) do
			local prefix, suffix = split_pair(pair)
			local armor, worn = {}, {}
			local affixes = {{channel = "prefix", stat = prefix}, {channel = "suffix", stat = suffix}}
			for _, slot in ipairs(grug_visuals.SLOTS) do
				armor[slot] = grug_gear.armor_item(slot, body.line, body.bracket)
				worn[slot] = {name = armor[slot], affixes = affixes}
			end
			local result = grug_visuals.compose({race = body.race, armor = armor,
				armor_layers = grug_visuals.armor_layers(worn)})
			print("body\t" .. body.race .. "\t" .. body.line .. "\t" .. body.bracket .. "\t" ..
				pair .. "\t" .. result.textures[1])
		end
	end
	return
end

local function read_file(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

------------------------------------------------------------------------------
-- A. The colour table.
------------------------------------------------------------------------------
local affix_stats = {}
do
	local block = read_file(ROOT .. "/mods/ITEMS/grug_quality/init.lua"):match("\nlocal AFFIX = (%b{})")
	check(block ~= nil, "grug_quality AFFIX table found")
	for stat in (block or ""):gmatch("\n\t([%w_]+) = {label") do
		affix_stats[#affix_stats + 1] = stat
	end
end
check(#affix_stats == 9, "nine affix stats in grug_quality (got " .. #affix_stats .. ")")
local seen_color, color_count = {}, 0
for stat, color in pairs(COLORS) do
	color_count = color_count + 1
	check(type(color) == "string" and color:match("^#%x%x%x%x%x%x$") ~= nil,
		"colour of " .. stat .. " is #rrggbb")
	check(not seen_color[color:lower()], "colour of " .. stat .. " is unique")
	seen_color[color:lower()] = true
end
check(color_count == #affix_stats, "one colour per affix stat")
for index, stat in ipairs(affix_stats) do
	check(COLORS[stat] ~= nil, "colour for affix stat " .. stat)
	check(grug_gear.ENCHANT_ORDER[index] == stat, "legend order follows AFFIX: " .. stat)
end
check(#grug_gear.ENCHANT_ORDER == 9, "legend lists nine stats")
check(grug_gear.ENCHANT_OPACITY == 128, "default strength 50 % (ruling 7)")

------------------------------------------------------------------------------
-- B. The modifier, C. masks.
------------------------------------------------------------------------------
-- One expected layer, written out independently of enchant_colors.lua.
local function layer(mask, frame, color)
	return "(" .. mask .. "^[verticalframe:2:" .. frame .. "^[multiply:" .. color ..
		"^[opacity:" .. grug_gear.ENCHANT_OPACITY .. ")"
end
check(#items == 120, "120 enchantable gear items (got " .. #items .. ")")
local longest_item, longest_item_name = 0, nil
for _, name in ipairs(items) do
	local def = registered[name]
	local image = def.inventory_image
	check(type(image) == "string" and stem_of(image) ~= nil, name .. " has a file image")
	check(grug_gear.has_enchant_masks(def), name .. " is flagged for masks")
	check(enchant_image(image) == image, name .. ": no affix keeps the image")
	check(enchant_image(image, nil, nil) == image, name .. ": nil, nil keeps the image")
	check(enchant_image(image, "nonsense", "nothing") == image,
		name .. ": unknown stats keep the image")
	check(grug_gear.enchant_layers(image) == nil, name .. ": no layers without affix")
	local mask = stem_of(image) .. "_ench.png"
	local both = enchant_image(image, "str", "crit_percent")
	check(both == image .. "^" .. layer(mask, 0, COLORS.str) .. "^" ..
		layer(mask, 1, COLORS.crit_percent), name .. ": prefix frame 0, suffix frame 1")
	check(enchant_image(image, "dex", nil) == image .. "^" .. layer(mask, 0, COLORS.dex),
		name .. ": prefix only")
	check(enchant_image(image, nil, "int") == image .. "^" .. layer(mask, 1, COLORS.int),
		name .. ": suffix only")
	check(grug_gear.enchant_layers(image, "str", "crit_percent") ==
		layer(mask, 0, COLORS.str) .. "^" .. layer(mask, 1, COLORS.crit_percent),
		name .. ": layers alone")
	check(grug_gear.strip_enchant(both) == image and grug_gear.strip_enchant(image) == image,
		name .. ": strip_enchant restores the image")
	check(not both:find(",", 1, true), name .. ": no comma in the modifier")
	check(file_exists(ROOT .. "/mods/ITEMS/grug_gear/textures/" .. mask), name .. ": " .. mask)
	local worst = #grug_gear.broken_image(both)
	if worst > longest_item then longest_item, longest_item_name = worst, name end
end
local trinkets = 0
for name, def in pairs(registered) do
	if not gear(def) then
		check(not grug_gear.has_enchant_masks(def), name .. " (no gear) has no masks")
		if ((def.groups or {}).grug_equip_trinket or 0) > 0 then trinkets = trinkets + 1 end
	end
end
check(trinkets > 0, "trinkets registered and left uncoloured")

local overlay_count, longest_slot = 0, {}
for _, line in ipairs(grug_visuals.LINES) do
	for _, slot in ipairs(grug_visuals.SLOTS) do
		for _, overlay in ipairs(grug_visuals.OVERLAY[line][slot]) do
			overlay_count = overlay_count + 1
			local mask = stem_of(overlay) .. "_ench.png"
			check(file_exists(ROOT .. "/mods/PLAYER/grug_visuals/textures/" .. mask),
				line .. " " .. slot .. ": " .. mask)
			local piece = worn_layer(overlay, "attack_speed_percent", "max_mana_percent", true)
			if #piece > (longest_slot[slot] or 0) then longest_slot[slot] = #piece end
		end
	end
end
check(overlay_count == 72, "72 worn overlays (got " .. overlay_count .. ")")

------------------------------------------------------------------------------
-- D. Per-stack image through grug_quality.
------------------------------------------------------------------------------
current_mod = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")

local function stack_with(name, affixes)
	local stack = ItemStack(name)
	if affixes then stack:get_meta():set_string("grug_ench", core.serialize(affixes)) end
	return stack
end

do
	local sword = "grug_gear:sword_steel"
	local image = registered[sword].inventory_image
	-- A plain stack: description written, no image key at all.
	local plain = stack_with(sword)
	grug_items.regenerate_description(plain)
	check(plain:get_meta().fields.inventory_image == nil, "plain stack has no image key")
	-- Affixes set: the image carries both colours.
	local enchanted = stack_with(sword, {{channel = "prefix", stat = "str", tier = 3, value = 3},
		{channel = "suffix", stat = "crit_percent", tier = 3, value = 1}})
	grug_items.regenerate_description(enchanted)
	check(enchanted:get_meta():get_string("inventory_image") ==
		enchant_image(image, "str", "crit_percent"), "enchanted stack carries its colours")
	-- Unchanged on a second pass (no write, no change reported).
	check(grug_items.refresh_enchant_image(enchanted,
		grug_items.get_affixes(enchanted)) == false, "unchanged image is not rewritten")
	-- An enchant replacing the suffix: the image follows.
	enchanted:get_meta():set_string("grug_ench", core.serialize({
		{channel = "prefix", stat = "str", tier = 3, value = 3},
		{channel = "suffix", stat = "max_hp_percent", tier = 3, value = 2}}))
	check(grug_items.regenerate_description(enchanted) == true, "changed affix reports a change")
	check(enchanted:get_meta():get_string("inventory_image") ==
		enchant_image(image, "str", "max_hp_percent"), "image follows the new suffix")
	-- A crafted output clears the channels and the image key.
	grug_items.crafted_output(enchanted)
	check(enchanted:get_meta().fields.inventory_image == nil, "crafted output: key removed")
	-- A loot roll (roll_enchants) writes the image too.
	local rolled = ItemStack("grug_gear:chest_leather_cured")
	rolled:get_meta():set_int("grug_quality", 3)
	local ok = grug_items.roll_enchants(rolled, 20, 2, 4242)
	local prefix, suffix = grug_visuals.affix_pair(grug_items.get_affixes(rolled))
	check(ok and prefix and suffix, "loot roll gives two affixes")
	check(rolled:get_meta():get_string("inventory_image") ==
		enchant_image(registered["grug_gear:chest_leather_cured"].inventory_image, prefix, suffix),
		"loot roll writes the image")
	-- Broken, uncracked image unchanged: not rewritten.
	local broken = stack_with(sword, {{channel = "prefix", stat = "dex", tier = 3, value = 3}})
	local meta = broken:get_meta()
	local base = enchant_image(image, "dex", nil)
	meta:set_string("inventory_image", grug_gear.broken_image(base))
	meta:set_string("_grug_broken_drawn_inventory_image", grug_gear.broken_image(base))
	meta:set_string("_grug_broken_base_inventory_image", base)
	check(grug_items.refresh_enchant_image(broken, grug_items.get_affixes(broken)) == false,
		"broken stack with its image unchanged is left alone")
	local broken_plain = stack_with(sword)
	meta = broken_plain:get_meta()
	meta:set_string("inventory_image", grug_gear.broken_image(image))
	meta:set_string("_grug_broken_drawn_inventory_image", grug_gear.broken_image(image))
	check(grug_items.refresh_enchant_image(broken_plain, {}) == false,
		"broken plain stack is left alone")
	-- A trinket with affixes gets no image (no masks).
	local trinket
	for name, def in pairs(registered) do
		if ((def.groups or {}).grug_equip_trinket or 0) > 0 and
				(not trinket or name < trinket) then
			trinket = name
		end
	end
	local t = stack_with(trinket, {{channel = "prefix", stat = "str", tier = 3, value = 1}})
	grug_items.regenerate_description(t)
	check(t:get_meta().fields.inventory_image == nil, "trinket stays plain: " .. trinket)
end

------------------------------------------------------------------------------
-- E. Body colours through compose's seam.
------------------------------------------------------------------------------
do
	local worn = {
		head = {name = "grug_gear:head_metal_steel",
			affixes = {{channel = "prefix", stat = "str"}, {channel = "suffix", stat = "armor_rating"}}},
		chest = {name = "grug_gear:chest_metal_steel",
			affixes = {{channel = "suffix", stat = "max_hp_percent"}}},
		legs = {name = "grug_gear:legs_metal_steel", affixes = {}},
	}
	local layers = grug_visuals.armor_layers(worn)
	check(layers and layers.head and layers.chest and not layers.legs and not layers.feet,
		"layers only for enchanted pieces")
	local armor = {head = worn.head.name, chest = worn.chest.name, legs = worn.legs.name}
	local plain = grug_visuals.compose({race = "dwarf", armor = armor})
	local none = grug_visuals.compose({race = "dwarf", armor = armor,
		armor_layers = grug_visuals.armor_layers({legs = worn.legs})})
	check(none == plain, "a plain set composes exactly as before")
	local dressed = grug_visuals.compose({race = "dwarf", armor = armor, armor_layers = layers})
	check(dressed.key ~= plain.key, "enchanted set has its own key")
	local texture = dressed.textures[1]
	local head = grug_visuals.OVERLAY.metal.head[3]
	local chest = grug_visuals.OVERLAY.metal.chest[3]
	check(texture:find("((" .. head .. "^" .. layers.head .. ")^[mask:", 1, true) ~= nil,
		"helmet colours sit inside the helmet, under the face window")
	check(texture:find("(" .. chest .. "^" .. layers.chest .. ")", 1, true) ~= nil,
		"chest colours sit inside the chest piece")
	check(layers.chest == grug_gear.enchant_layers(chest, nil, "max_hp_percent"),
		"worn layers use the overlay's mask")
	local broken = grug_visuals.compose({race = "dwarf", armor = armor, armor_layers = layers,
		armor_broken = {chest = true}})
	check(broken.textures[1]:find("((" .. chest .. "^" .. layers.chest .. ")" .. grug_gear.BROKEN_MODIFIER, 1, true)
		~= nil, "a broken piece cracks together with its colours")
	check(grug_visuals.armor_layer("grug_gear:sword_steel", "chest", "str", nil) == nil,
		"a non-armour item has no worn layers")
end

------------------------------------------------------------------------------
-- F. NPC weapons and kings.
------------------------------------------------------------------------------
do
	-- apply.lua needs the engine; npc_weapon is copied out of it by pattern
	-- so the fixture checks the shipped function body.
	local source = read_file(ROOT .. "/mods/PLAYER/grug_visuals/apply.lua")
	local body = source:match("\n(function grug_visuals%.npc_weapon%(.-\nend)\n")
	check(body ~= nil, "npc_weapon found in apply.lua")
	assert(loadstring(body))()
	local axe = "grug_gear:greataxe_abyssal_steel"
	check(grug_visuals.npc_weapon(axe, nil) == axe, "no colours: the plain name")
	check(grug_visuals.npc_weapon(nil, {prefix = "str"}) == nil, "no weapon: nothing")
	check(grug_visuals.npc_weapon(axe, {}) == axe, "empty colours: the plain name")
	local shown = grug_visuals.npc_weapon(axe, {prefix = "str", suffix = "max_hp_percent"})
	check(shown == axe .. " inventory_image=" ..
		enchant_image(registered[axe].inventory_image, "str", "max_hp_percent"),
		"colours: an item string with the coloured image")
	-- Every king: fixed colours from the weapon family's pool.
	local bosses = read_file(ROOT .. "/mods/ENTITIES/grug_mobs/bosses.lua")
	local kings = 0
	for race, weapon, prefix, suffix in bosses:gmatch(
			"\n\t(%a+) = {faction = \"%a+\",%s*kit = \"[%a_]+\", " ..
			"weapon = \"(%a+)\",%s*colors = {prefix = \"([%a_]+)\", suffix = \"([%a_]+)\"}}") do
		kings = kings + 1
		local pool = grug_items.POOLS[(weapon == "staff" or weapon == "wand") and
			"caster_weapon" or weapon]
		local found = {}
		for _, stat in ipairs(pool) do found[stat] = true end
		check(found[prefix] and found[suffix] and prefix ~= suffix,
			"king " .. race .. ": colours from the " .. weapon .. " pool")
		check(grug_visuals.npc_weapon(grug_gear.weapon_item(weapon, 6),
			{prefix = prefix, suffix = suffix}) ~= grug_gear.weapon_item(weapon, 6),
			"king " .. race .. ": the weapon is coloured")
	end
	check(kings == 6, "six kings with colours (got " .. kings .. ")")
	check(bosses:find("weapon_family = row.weapon, weapon_colors = row.colors", 1, true) ~= nil,
		"the king's visual spec carries the colours")
end

------------------------------------------------------------------------------
-- G. The station legend.
------------------------------------------------------------------------------
do
	local legend = grug_items.enchant_legend_formspec(5, 4.65)
	local boxes = 0
	for color in legend:gmatch("box%[[%d.]+,[%d.]+;0%.24,0%.24;(#%x+)%]") do
		boxes = boxes + 1
		check(seen_color[color], "legend swatch is a table colour: " .. color)
	end
	check(boxes == 9, "legend has nine swatches (got " .. boxes .. ")")
	-- Round 45: the bench dialog that drew it is gone; the enchanting box of
	-- the Crafting tab (lane EU) takes it over.
end

------------------------------------------------------------------------------
-- H. Lengths.
------------------------------------------------------------------------------
local plain_slots = 0
for _, slot in ipairs(grug_visuals.SLOTS) do
	local longest = 0
	for _, line in ipairs(grug_visuals.LINES) do
		for _, overlay in ipairs(grug_visuals.OVERLAY[line][slot]) do
			longest = math.max(longest, #overlay + 3)
		end
	end
	plain_slots = plain_slots + longest
end
local enchanted_slots = 0
for _, slot in ipairs(grug_visuals.SLOTS) do enchanted_slots = enchanted_slots + longest_slot[slot] end
print(("lengths: item image worst %d chars (%s, both affixes, broken); armour pieces " ..
	"worst %d chars all four enchanted and broken against %d plain (the look layers " ..
	"come on top)"):format(longest_item, longest_item_name, enchanted_slots, plain_slots))

if failures > 0 then
	error(("R31 B PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R31 B PORTABLE PASS checks=%d"):format(checks))
