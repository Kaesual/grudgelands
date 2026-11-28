-- Round 88 lane ICONS-W portable test (docs/planning/round88-plan.md ruling 2,
-- §4 ICONS). Loads the REAL grug_alchemy effects.lua and recipes.lua and
-- grug_traders potion.lua under small stubs and checks:
--   F  every registered potion, elixir and draught (group grug_potion) has a
--      plain inventory image (no texture modifier, so no tinted bottle) that
--      exists as a file in its mod's textures folder;
--   M  the bottle manifest (tools/r88_icons/game_textures.json) and the
--      registrations agree: the same 41 items, each with the manifest's
--      texture, its family's file name and the item level of its tier;
--   T  no registered item uses the old corked flask any more, and
--      register_consumable refuses a definition without an image.
--
-- Usage (repo root): luajit tools/r88_icons_w/portable_test.lua [REPO]

local repo = arg[1] or "."
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
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local function exists(path)
	local handle = io.open(repo .. "/" .. path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

-- ---------------------------------------------------------------------------
-- Stubs: only what the three files call at load time.
-- ---------------------------------------------------------------------------
local registered = {}
_G.core = {
	registered_items = registered,
	register_craftitem = function(name, def) registered[name] = def end,
	register_alias = function() end,
	register_on_dieplayer = function() end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
	log = function() end,
}
local permissive = {__index = function() return function() end end}
_G.grug_core = setmetatable({}, permissive)
_G.grug_sounds = setmetatable({}, permissive)
_G.grug_jobs = setmetatable({DURATIONS = {potion = 2, station = 1},
	ingredient_list = function(tokens) return tokens end}, permissive)
_G.grug_brewing = {NODE = "grug_brewing:brewing_stand"}
_G.grug_gathering = setmetatable({}, permissive)
_G.grug_gear = {format_armor = function(value) return tostring(value * 10) end}
local catalogue = {}
for object in read("mods/ENTITIES/grug_mobs/data/items.json"):gmatch("%b{}") do
	local id = object:match('"id"%s*:%s*"([^"]+)"')
	local tier = tonumber(object:match('"tier"%s*:%s*(%d+)'))
	if id and tier then catalogue[#catalogue + 1] = {id = id, tier = tier} end
end
_G.grug_mobs = {read_data_json = function() return catalogue end}
_G.grug_traders = setmetatable({}, permissive)
dofile(repo .. "/mods/ENTITIES/grug_traders/potion.lua")
_G.grug_alchemy = {}
dofile(repo .. "/mods/ITEMS/grug_alchemy/effects.lua")
dofile(repo .. "/mods/ITEMS/grug_alchemy/recipes.lua")

local OWNER = {grug_alchemy = "mods/ITEMS/grug_alchemy/textures/",
	grug_traders = "mods/ENTITIES/grug_traders/textures/"}

-- ---------------------------------------------------------------------------
-- F. Every potion item: a plain image that exists.
-- ---------------------------------------------------------------------------
local potions, count = {}, 0
for name, def in pairs(registered) do
	if def.groups and def.groups.grug_potion then
		potions[name] = def
		count = count + 1
		local image = def.inventory_image
		local folder = OWNER[name:match("^([^:]+):")]
		check(type(image) == "string" and image:match("^[%w_]+%.png$") ~= nil,
			"F " .. name .. ": a plain file name, no modifier (" .. tostring(image) .. ")")
		check(folder and type(image) == "string" and exists(folder .. image),
			"F " .. name .. ": the image exists in its mod (" .. tostring(image) .. ")")
	end
end
eq(count, 41, "F 40 alchemy products and the merchant's potion")
eq(#grug_alchemy.CATALOG, 40, "F ...the catalogue's 40 rows")

-- ---------------------------------------------------------------------------
-- M. The manifest against the registrations.
-- ---------------------------------------------------------------------------
local rows = 0
for object in read("tools/r88_icons/game_textures.json"):gmatch("%b{}") do
	rows = rows + 1
	local family = object:match('"family"%s*:%s*"([^"]+)"')
	local tier = tonumber(object:match('"tier"%s*:%s*(%d+)'))
	local item = object:match('"item_id"%s*:%s*"([^"]+)"')
	local texture = object:match('"texture"%s*:%s*"([^"]+)"')
	local def = potions[item]
	if check(def ~= nil, "M " .. tostring(item) .. ": registered as a potion") then
		eq(def.inventory_image, texture, "M " .. item .. ": the manifest's texture")
		potions[item] = nil
		if item:match("^grug_alchemy:") then
			check(texture == "grug_alchemy_" .. family .. ".png" or
				texture == "grug_alchemy_" .. family .. "_t" .. tier .. ".png",
				"M " .. item .. ": its family's file (" .. texture .. ")")
			eq(def._grug_ilvl, grug_alchemy.TIER_LEVELS[tier], "M " .. item .. ": its tier's level")
		end
	end
end
eq(rows, 41, "M the manifest's rows")
check(next(potions) == nil, "M no registered potion outside the manifest: " ..
	tostring(next(potions)))

-- ---------------------------------------------------------------------------
-- T. The old flask and the fallback are gone.
-- ---------------------------------------------------------------------------
for name, def in pairs(registered) do
	check(not tostring(def.inventory_image):find("potion_healing_weak.png", 1, true) and
		not tostring(def.inventory_image):find("colorize", 1, true),
		"T " .. name .. ": no old flask, no tint")
end
check(not read("mods/ITEMS/grug_alchemy/effects.lua"):find("colorize", 1, true),
	"T effects.lua has no tinted fallback")
local ok = pcall(grug_alchemy.register_consumable, "test_without_image",
	{family = "potion", tier = 1, description = "Test"})
check(not ok and registered["grug_alchemy:test_without_image"] == nil,
	"T register_consumable refuses a definition without an image")

print(("R88 ICONS-W PORTABLE %s checks=%d failures=%d"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures))
assert(failures == 0, "R88 ICONS-W portable test failed")
