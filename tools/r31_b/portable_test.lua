-- Round 31 Lane B portable test (LuaJIT): enchant colours, stage 1.
--
-- Loads the REAL grug_gear (init.lua with permissions.lua, enchant_colors.lua
-- and trinkets.lua) under a permissive engine stub that records every
-- registered item, and grug_visuals/compose.lua for the worn overlays:
--   A. the colour table: exactly the nine affix stats of grug_quality's AFFIX
--      table, each a distinct "#rrggbb";
--   B. no affix (nil, nil / unknown stats) returns the item's image string
--      unchanged, byte for byte; one or two affixes append one layer each,
--      naming the item's own mask file and the stat colour;
--   C. every enchantable item (weapons, offhands, armour) and every worn
--      overlay has its mask file `<source>_ench.png` beside the source;
--   D. reports the worst-case modifier length of an item image and of a body
--      composition with all four slots enchanted (and broken), built the way
--      stage 2 will: each overlay in parentheses, its layers inside.
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
}
local current_mod = "grug_gear"
core = permissive({
	registered_items = registered,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	colorize = function(_, text) return text end,
	register_tool = function(name, def) registered[name] = def end,
	register_craftitem = function(name, def) registered[name] = def end,
})
grug_core = permissive({})
grug_classes = permissive({})
ItemStack = function(name)
	return {get_name = function() return name end,
		get_definition = function() return registered[name] or {} end}
end

dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_visuals"
grug_visuals = {}
dofile(ROOT .. "/mods/PLAYER/grug_visuals/compose.lua")

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

-- Every item whose stack can carry affixes: the enchantable families.
local function enchantable(def)
	local groups = def.groups or {}
	return (groups.grug_equip_weapon or 0) > 0 or (groups.grug_shield or 0) > 0 or
		(groups.grug_spellbook or 0) > 0 or (groups.grug_armor_class or 0) > 0
end

local items = {}
for name, def in pairs(registered) do
	if enchantable(def) then items[#items + 1] = name end
end
table.sort(items)

-- What stage 2's body composition appends per slot: the overlay with its
-- layers, in parentheses so an overlay's own modifier ([hsl) cannot reach
-- the layers below it; a broken piece wrapped as compose.lua does today.
local function worn_layer(overlay, prefix, suffix, broken)
	local piece = enchant_image(overlay, prefix, suffix)
	if broken then piece = "(" .. grug_gear.broken_image(piece) .. ")" end
	return "^(" .. piece .. ")"
end

if MODE == "emit" then
	grug_gear.ENCHANT_OPACITY = tonumber(arg[3]) or 255
	local pairs_wanted = {}
	for index = 4, #arg do pairs_wanted[#pairs_wanted + 1] = arg[index] end
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
	return
end

------------------------------------------------------------------------------
-- A. The colour table.
------------------------------------------------------------------------------
local affix_stats = {}
do
	local handle = assert(io.open(ROOT .. "/mods/ITEMS/grug_quality/init.lua", "rb"))
	local text = handle:read("*a")
	handle:close()
	local block = text:match("\nlocal AFFIX = (%b{})")
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
for _, stat in ipairs(affix_stats) do
	check(COLORS[stat] ~= nil, "colour for affix stat " .. stat)
end

------------------------------------------------------------------------------
-- B. The modifier: unchanged without an affix, one layer per affix.
------------------------------------------------------------------------------
check(#items == 120, "120 enchantable gear items (got " .. #items .. ")")
local longest_item, longest_item_name = 0, nil
for _, name in ipairs(items) do
	local image = registered[name].inventory_image
	check(type(image) == "string" and stem_of(image) ~= nil, name .. " has a file image")
	check(enchant_image(image) == image, name .. ": no affix keeps the image")
	check(enchant_image(image, nil, nil) == image, name .. ": nil, nil keeps the image")
	check(enchant_image(image, "nonsense", "nothing") == image,
		name .. ": unknown stats keep the image")
	local mask = stem_of(image) .. "_ench.png"
	local both = enchant_image(image, "str", "crit_percent")
	check(both:sub(1, #image) == image, name .. ": layers come after the image")
	check(both == image .. "^(" .. mask .. "^[verticalframe:2:0^[multiply:" .. COLORS.str ..
		")^(" .. mask .. "^[verticalframe:2:1^[multiply:" .. COLORS.crit_percent .. ")",
		name .. ": prefix frame 0, suffix frame 1")
	check(enchant_image(image, "dex", nil) == image .. "^(" .. mask ..
		"^[verticalframe:2:0^[multiply:" .. COLORS.dex .. ")", name .. ": prefix only")
	check(enchant_image(image, nil, "int") == image .. "^(" .. mask ..
		"^[verticalframe:2:1^[multiply:" .. COLORS.int .. ")", name .. ": suffix only")
	check(not both:find(",", 1, true), name .. ": no comma in the modifier")
	-- C. The mask ships beside the item texture.
	check(file_exists(ROOT .. "/mods/ITEMS/grug_gear/textures/" .. mask), name .. ": " .. mask)
	local worst = #grug_gear.broken_image(both)
	if worst > longest_item then longest_item, longest_item_name = worst, name end
end

------------------------------------------------------------------------------
-- C. Worn overlays, D. lengths.
------------------------------------------------------------------------------
local overlay_count = 0
local longest_slot = {}
for _, line in ipairs(grug_visuals.LINES) do
	for _, slot in ipairs(grug_visuals.SLOTS) do
		for _, overlay in ipairs(grug_visuals.OVERLAY[line][slot]) do
			overlay_count = overlay_count + 1
			local mask = stem_of(overlay) .. "_ench.png"
			check(file_exists(ROOT .. "/mods/PLAYER/grug_visuals/textures/" .. mask),
				line .. " " .. slot .. ": " .. mask)
			check(enchant_image(overlay) == overlay, overlay .. ": no affix keeps it")
			local piece = worn_layer(overlay, "attack_speed_percent", "max_mana_percent", true)
			if #piece > (longest_slot[slot] or 0) then longest_slot[slot] = #piece end
		end
	end
end
check(overlay_count == 72, "72 worn overlays (got " .. overlay_count .. ")")

local longest_skin = 0
for _, race in pairs(grug_visuals.RACES) do
	longest_skin = math.max(longest_skin, #race.skin)
end
local body = longest_skin
for _, slot in ipairs(grug_visuals.SLOTS) do body = body + longest_slot[slot] end
local plain = longest_skin
for _, slot in ipairs(grug_visuals.SLOTS) do
	local longest = 0
	for _, line in ipairs(grug_visuals.LINES) do
		for _, overlay in ipairs(grug_visuals.OVERLAY[line][slot]) do
			longest = math.max(longest, #overlay + 1)
		end
	end
	plain = plain + longest
end

print(("lengths: item image worst %d chars (%s, both affixes, broken); " ..
	"body worst %d chars (4 slots, both affixes, broken; unenchanted worst %d)")
	:format(longest_item, longest_item_name, body, plain))

if failures > 0 then
	error(("R31 B PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R31 B PORTABLE PASS checks=%d"):format(checks))
