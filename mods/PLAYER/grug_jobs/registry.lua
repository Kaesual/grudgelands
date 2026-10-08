-- The recipe registry (Round 45, round45-plan.md §3, ui-crafting-rework-plan.md
-- §4.1): every craft is an ingredient list in one crafting area. A record is
--   {id, output, count, ingredients = {{item = name | group = name, n}, ...},
--    area, profession, tier, time, station, progress}
-- `area` is "basic", "cooking", a primary profession or "alchemist";
-- `profession` is the area's profession (nil for Basic); `time` is the
-- duration of one craft in seconds (spec §2.30); `station` is nil or the
-- station kind that must stand nearby; `progress` says whether the craft
-- gives profession XP (never in Basic). Nothing here matches a craft grid:
-- a job names its recipe by id. Furnace, dual-furnace and alloy recipes are
-- no records; they stay engine cooking and grug_smelting recipes.
local function fail(message)
	error("grug_jobs recipe registry: " .. message, 0)
end

grug_jobs.PROFESSIONS = {
	weaponsmith = {name = "Weaponsmith", class = "primary"},
	armorsmith = {name = "Armorsmith", class = "primary"},
	alchemist = {name = "Alchemy", class = "secondary"},
	tailor = {name = "Tailor", class = "primary"},
	leatherworker = {name = "Leatherworker", class = "primary"},
	woodcarver = {name = "Woodcarver", class = "primary"},
	goldsmith = {name = "Goldsmith", class = "primary"},
	cooking = {name = "Cooking", class = "secondary"},
}

grug_jobs.PRIMARY_PROFESSIONS = {
	"weaponsmith", "armorsmith", "tailor", "leatherworker", "woodcarver",
	"goldsmith",
}
-- Secondaries take no primary slot; every character may learn both (Round
-- 33: Alchemy joined Cooking).
grug_jobs.SECONDARY_PROFESSIONS = {"cooking", "alchemist"}

-- The crafting areas (spec §2.16): Basic, Cooking, the six primaries (a
-- character shows the two it learned) and Alchemy.
grug_jobs.AREAS = {"basic", "cooking", "weaponsmith", "armorsmith", "tailor",
	"leatherworker", "woodcarver", "goldsmith", "alchemist"}
local AREA_SET = {}
for _, area in ipairs(grug_jobs.AREAS) do AREA_SET[area] = true end

-- Station nodes. Furnaces and dual furnaces keep their dialog (workspaces.lua)
-- and no recipe names them; the others are the kinds a recipe may need
-- nearby (spec §2.27, §4.7).
grug_jobs.STATIONS = {
	furnace = {display_name = "Furnace", node = "default:furnace"},
	dual_furnace = {display_name = "Dual Furnace",
		node = "grug_smelting:dual_furnace"},
	brewing_stand = {display_name = "Brewing Stand", profession = "alchemist",
		node = "grug_brewing:brewing_stand"},
	forge = {display_name = "Forge", professions = {weaponsmith = true,
		armorsmith = true},
		node = "grug_jobs:forge"},
	tanning_rack = {display_name = "Tanning Rack", profession = "leatherworker",
		node = "grug_jobs:tanning_rack"},
	tailor_bench = {display_name = "Tailor Bench", profession = "tailor",
		node = "grug_jobs:tailor_bench"},
	carving_bench = {display_name = "Carving Bench", profession = "woodcarver",
		node = "grug_jobs:carving_bench"},
	jewellers_bench = {display_name = "Jeweller's Bench", profession = "goldsmith",
		node = "grug_jobs:jewellers_bench"},
}

-- The station each profession's recipes need nearby (Cooking needs none).
grug_jobs.PROFESSION_STATIONS = {
	weaponsmith = "forge", armorsmith = "forge", leatherworker = "tanning_rack",
	tailor = "tailor_bench", woodcarver = "carving_bench",
	goldsmith = "jewellers_bench", alchemist = "brewing_stand",
}

-- Seconds per crafted item (spec §2.30; a job lasts quantity x time).
-- `material` covers the profession intermediates (bolt bundles, cut gems,
-- settings) and `station` the station nodes, which the spec leaves open:
-- both as Basic. Enchants (5 s) and upgrades (1 s per level) are station
-- operations, not records.
grug_jobs.DURATIONS = {basic = 1, food = 1, potion = 2, gear = 3, bag = 3,
	material = 1, station = 1}

function grug_jobs.station_info(station)
	local definition = grug_jobs.STATIONS[station]
	if type(definition) ~= "table" then return nil end
	return {id = station, display_name = definition.display_name,
		profession = definition.profession, professions = definition.professions,
		node = definition.node}
end

-- Every record in registration order (prices and the load audits walk it).
grug_jobs.recipes = {}

local ingredient_tiers = {}
local by_id, by_output, by_area = {}, {}, {}
local finalized = false

local function item_name(value)
	if type(value) == "string" then
		return value:match("^%s*([^%s]+)") or ""
	end
	if type(value) == "userdata" or type(value) == "table" then
		if type(value.get_name) == "function" then
			return value:get_name()
		end
	end
	return ""
end

-- The names in a list or a nested grid of item strings, empty slots left
-- out (station operations still list their materials this way).
local function flatten_inputs(value, result)
	result = result or {}
	if type(value) == "string" or
			((type(value) == "userdata" or type(value) == "table") and
			type(value.get_name) == "function") then
		local name = item_name(value)
		if name ~= "" then result[#result + 1] = name end
	elseif type(value) == "table" then
		local maximum = 0
		for key in pairs(value) do
			if type(key) == "number" and key % 1 == 0 and key > maximum then
				maximum = key
			end
		end
		for index = 1, maximum do
			flatten_inputs(value[index], result)
		end
	end
	return result
end

function grug_jobs.register_ingredient_tier(item, tier)
	local name = item_name(item)
	if name == "" then fail("an ingredient needs an itemstring") end
	if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > 6 then
		fail("ingredient " .. name .. " needs tier 1..6")
	end
	local old = ingredient_tiers[name]
	if old and old ~= tier then
		fail("ingredient " .. name .. " already has tier " .. old)
	end
	ingredient_tiers[name] = tier
	return tier
end

function grug_jobs.ingredient_tier(item)
	return ingredient_tiers[item_name(item)]
end

-- "group:<name>" for a group entry, else the item name: the token the
-- ingredient-tier table and the price module key on.
local function token_of(entry)
	return entry.group and ("group:" .. entry.group) or entry.item
end
grug_jobs.ingredient_token = token_of

-- Whether an item (a name) is accepted by one ingredient entry.
function grug_jobs.ingredient_accepts(entry, name)
	if entry.item then return entry.item == name end
	return core.get_item_group(name, entry.group) > 0
end

local function positive_integer(value)
	return type(value) == "number" and value % 1 == 0 and value >= 1
end

-- The id a record gets when its definition names none: the output and the
-- sorted ingredient list, so it stays the same however the registering code
-- orders its rows (a job stores it).
local function default_id(output, ingredients)
	local parts = {}
	for index, entry in ipairs(ingredients) do
		parts[index] = token_of(entry) .. "*" .. entry.n
	end
	table.sort(parts)
	return output .. "|" .. table.concat(parts, "+")
end

local function copy_ingredients(list, label)
	if type(list) ~= "table" or #list == 0 then fail(label .. " needs ingredients") end
	local result, seen = {}, {}
	for index, entry in ipairs(list) do
		if type(entry) ~= "table" or not positive_integer(entry.n) then
			fail(label .. " ingredient " .. index .. " needs a count n")
		end
		local item, group = entry.item, entry.group
		if (item == nil) == (group == nil) then
			fail(label .. " ingredient " .. index .. " needs exactly one of item and group")
		end
		if item ~= nil and (type(item) ~= "string" or not item:match("^[%w_]+:[%w_]+$")) then
			fail(label .. " ingredient " .. index .. " item differs")
		end
		if group ~= nil and (type(group) ~= "string" or not group:match("^[%w_]+$")) then
			fail(label .. " ingredient " .. index .. " group differs")
		end
		local copy = item and {item = item, n = entry.n} or {group = group, n = entry.n}
		local token = token_of(copy)
		if seen[token] then fail(label .. " lists " .. token .. " twice") end
		seen[token] = true
		result[index] = copy
	end
	return result
end

-- The ingredient list of a flat list (or a nested grid) of item names and
-- "group:<name>" tokens, empty slots left out: each token counted once per
-- slot, in the order it first appears. The profession catalogs keep their
-- input tables and convert them here.
function grug_jobs.ingredient_list(tokens)
	local result, index_of = {}, {}
	for _, token in ipairs(flatten_inputs(tokens)) do
		local entry = result[index_of[token]]
		if entry then
			entry.n = entry.n + 1
		else
			local group = token:match("^group:(.+)$")
			result[#result + 1] = group and {group = group, n = 1} or {item = token, n = 1}
			index_of[token] = #result
		end
	end
	return result
end

-- Registers one record. `definition` takes the record's fields; `id`,
-- `count` (1), `profession` (the area's) and `progress` (true outside Basic)
-- may be left out, `time` too in Basic. `material = true` (validation only)
-- marks a profession intermediate: its output is an ingredient of the
-- recipe's tier and it gives no XP. A profession recipe never needs an
-- ingredient above its tier and, unless it is a material, needs one of its
-- own tier (professions.md §1.3).
function grug_jobs.register_recipe(definition)
	if type(definition) ~= "table" then fail("recipe definition differs") end
	if finalized then fail("recipes register at load time") end
	local output = definition.output
	if type(output) ~= "string" or not output:match("^[%w_]+:[%w_]+$") then
		fail("a recipe needs an output item name, got " .. tostring(output))
	end
	local area = definition.area
	if not AREA_SET[area] then fail(output .. " has unknown area " .. tostring(area)) end
	local basic = area == "basic"
	local profession = not basic and area or nil
	if definition.profession ~= nil and definition.profession ~= profession then
		fail(output .. " profession differs from its area")
	end
	local count = definition.count == nil and 1 or definition.count
	if not positive_integer(count) then fail(output .. " count differs") end
	local ingredients = copy_ingredients(definition.ingredients, output)
	local tier = definition.tier
	if tier ~= nil and (type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > 6) then
		fail(output .. " needs tier 1..6")
	end
	if not basic and tier == nil then fail(output .. " needs a tier") end
	local time = definition.time
	if time == nil and basic then time = grug_jobs.DURATIONS.basic end
	if type(time) ~= "number" or time <= 0 then fail(output .. " needs a time") end
	local station = definition.station
	if station ~= nil then
		if basic then fail(output .. ": Basic recipes need no station") end
		if station ~= grug_jobs.PROFESSION_STATIONS[profession] then
			fail(output .. " station " .. tostring(station) .. " is not " ..
				grug_jobs.PROFESSIONS[profession].name .. "'s")
		end
	end
	local progress = definition.progress
	if progress == nil then progress = not basic and definition.material ~= true end
	if type(progress) ~= "boolean" then fail(output .. " progress flag differs") end
	if basic and progress then fail(output .. ": Basic recipes give no XP") end
	if definition.material ~= nil and type(definition.material) ~= "boolean" then
		fail(output .. " material flag differs")
	end
	if not basic then
		local has_own_tier = false
		for _, entry in ipairs(ingredients) do
			local input_tier = ingredient_tiers[token_of(entry)]
			if input_tier == tier then has_own_tier = true end
			if input_tier and input_tier > tier then
				fail(profession .. " T" .. tier .. " recipe " .. output ..
					" uses higher-tier ingredient " .. token_of(entry))
			end
		end
		if definition.material then
			if progress then fail(output .. ": a material gives no XP") end
			if ingredient_tiers[output] ~= tier then
				fail(output .. " material output tier differs from recipe tier")
			end
		elseif not has_own_tier then
			fail(profession .. " T" .. tier .. " recipe " .. output ..
				" needs at least one declared T" .. tier .. " ingredient")
		end
	end
	local id = definition.id or default_id(output, ingredients)
	if type(id) ~= "string" or id == "" then fail(output .. " id differs") end
	if by_id[id] then fail("duplicate recipe id " .. id) end
	local recipe = {id = id, output = output, count = count,
		ingredients = ingredients, area = area, profession = profession,
		tier = tier, time = time, station = station, progress = progress}
	by_id[id] = recipe
	grug_jobs.recipes[#grug_jobs.recipes + 1] = recipe
	by_output[output] = by_output[output] or {}
	table.insert(by_output[output], recipe)
	by_area[area] = by_area[area] or {}
	table.insert(by_area[area], recipe)
	return recipe
end

-- The record with this id, or nil.
function grug_jobs.recipe(id)
	return by_id[id]
end

-- Every record that makes `output` (an item name or stack), in registration
-- order. The list is the registry's own: never write into it.
function grug_jobs.recipes_for_output(output)
	return by_output[item_name(output)] or {}
end

-- Every record of one area, ordered by tier, then the output's description,
-- then id (spec §2.17's stable order). The list is the registry's own: never
-- write into it.
function grug_jobs.recipes_in_area(area)
	return by_area[area] or {}
end

-- Registers the Basic catalog (basic_recipes.lua, which init.lua loads) and
-- its loop-made families as the vendored stairs and walls loops registered
-- them.
function grug_jobs.register_basic_catalog(data)
	for _, row in ipairs(data.recipes) do
		grug_jobs.register_recipe({area = "basic", output = row.output,
			count = row.count, ingredients = row.ingredients})
	end
	local function add(output, count, item, n)
		grug_jobs.register_recipe({area = "basic", output = output, count = count,
			ingredients = {{item = item, n = n}}})
	end
	for _, row in ipairs(data.stairs) do
		local sub, block = row[1], row[2]
		local stair, slab = "stairs:stair_" .. sub, "stairs:slab_" .. sub
		add(stair, 8, block, 6)
		add("stairs:stair_inner_" .. sub, 7, block, 6)
		add("stairs:stair_outer_" .. sub, 6, block, 4)
		add(slab, 6, block, 3)
		add(block, 3, stair, 4)
		add(block, 1, slab, 2)
	end
	for _, row in ipairs(data.walls) do add(row[1], 6, row[2], 6) end
end

-- An item's material tier, or nil when nothing declares one: its own tier,
-- a gear bracket, a registered ingredient tier (bars, graded wood), else its
-- level band.
local function declared_tier(name)
	local definition = core.registered_items[name] or {}
	local sources = {definition._grug_tier, definition._grug_bracket,
		ingredient_tiers[name]}
	for index = 1, 3 do
		local tier = tonumber(sources[index])
		if tier and tier >= 1 and tier <= 6 then return math.floor(tier) end
	end
	local level = tonumber(definition._grug_ilvl)
	if level and level > 0 then
		return math.min(6, math.floor((level - 1) / 10) + 1)
	end
	return nil
end

local function first_line(name)
	local definition = core.registered_items[name]
	local text = definition and definition.description or ""
	text = text:match("^[^\n]*") or ""
	return text ~= "" and text or name
end

-- After every mod: each output and item ingredient is registered and each
-- group has a member; a Basic record's tier (for the list order only) is its
-- output's, else its highest ingredient's, else 1; the area lists are sorted.
core.register_on_mods_loaded(function()
	finalized = true
	local groups = {}
	for _, recipe in ipairs(grug_jobs.recipes) do
		if not core.registered_items[recipe.output] then
			fail("unregistered output " .. recipe.output .. " (" .. recipe.id .. ")")
		end
		local inferred
		for _, entry in ipairs(recipe.ingredients) do
			if entry.item then
				if not core.registered_items[entry.item] then
					fail("unregistered ingredient " .. entry.item .. " (" .. recipe.id .. ")")
				end
			else
				groups[entry.group] = groups[entry.group] or recipe.id
			end
			local tier = entry.item and declared_tier(entry.item) or
				ingredient_tiers[token_of(entry)]
			if tier and tier > (inferred or 0) then inferred = tier end
		end
		if recipe.tier == nil then
			recipe.tier = declared_tier(recipe.output) or inferred or 1
		end
	end
	for name in pairs(core.registered_items) do
		for group in pairs(groups) do
			if core.get_item_group(name, group) > 0 then groups[group] = nil end
		end
	end
	for group, id in pairs(groups) do
		fail("group " .. group .. " has no member (" .. id .. ")")
	end
	local labels = {}
	for _, list in pairs(by_area) do
		for _, recipe in ipairs(list) do
			labels[recipe.output] = labels[recipe.output] or first_line(recipe.output)
		end
		table.sort(list, function(a, b)
			if a.tier ~= b.tier then return a.tier < b.tier end
			if labels[a.output] ~= labels[b.output] then
				return labels[a.output] < labels[b.output]
			end
			return a.id < b.id
		end)
	end
end)

grug_jobs._item_name = item_name
grug_jobs._flatten_inputs = flatten_inputs
