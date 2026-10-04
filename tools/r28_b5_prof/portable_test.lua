-- Round 28 Lane B5 portable test (rulings 27, 28). Loads the REAL files under
-- minimal stubs and checks:
--   1. the shipped data/enchants.json (Round 33: the same text as
--      tools/r33_ds/enchants_r33.json) validates against the real stat pools
--      (grug_quality) and yields the 588 operations, each costing own
--      material + the channel's loot + family input;
--   2. operations generated from a complete sample catalogue: exact costs,
--      prefix and suffix take their own loot, so do the trinket's two pools;
--   3. load errors for missing or wrong entries (prefix_loot, suffix_loot,
--      family_input, tiers, unknown keys, non-item values);
--   4. the cross-profession check: a foreign product in an operation is
--      reported, an own product is not;
--   5. cooking (grug_cooking/init.lua + grug_jobs/basics_routes.lua): the six
--      raw-assembly dishes have no grid route, only "Raw X" in the furnace;
--      the other twelve keep their grid route;
--   6. no metal fittings remain in the profession sources.
--
-- Usage (repo root): luajit tools/r28_b5_prof/portable_test.lua

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
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function fails_with(fn, part, label)
	local ok, err = pcall(fn)
	return check(not ok and tostring(err):find(part, 1, true) ~= nil,
		label .. " (got " .. (ok and "no error" or ("%q"):format(tostring(err))) .. ")")
end
local function read(path)
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local text = file:read("*a")
	file:close()
	return text
end

-- A small JSON decoder (objects, arrays, strings, numbers, booleans, null)
-- for the shipped and sample data files.
local function decode_json(text)
	local pos = 1
	local value
	local function skip() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
	local function string_value()
		local out = {}
		pos = pos + 1
		while true do
			local c = text:sub(pos, pos)
			if c == "" then error("unterminated string") end
			if c == '"' then pos = pos + 1; return table.concat(out) end
			if c == "\\" then
				local e = text:sub(pos + 1, pos + 1)
				out[#out + 1] = ({n = "\n", t = "\t", r = "\r", b = "\b", f = "\f"})[e] or e
				pos = pos + 2
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
	end
	function value()
		skip()
		local c = text:sub(pos, pos)
		if c == "{" then
			local result = {}
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "}" then pos = pos + 1; return result end
			while true do
				skip()
				local key = string_value()
				skip()
				assert(text:sub(pos, pos) == ":", "expected : at " .. pos)
				pos = pos + 1
				result[key] = value()
				skip()
				local d = text:sub(pos, pos)
				pos = pos + 1
				if d == "}" then return result end
				assert(d == ",", "expected , at " .. pos)
			end
		elseif c == "[" then
			local result = {}
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "]" then pos = pos + 1; return result end
			while true do
				result[#result + 1] = value()
				skip()
				local d = text:sub(pos, pos)
				pos = pos + 1
				if d == "]" then return result end
				assert(d == ",", "expected , at " .. pos)
			end
		elseif c == '"' then
			return string_value()
		elseif text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
		elseif text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
		elseif text:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
		end
		local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		assert(number and number ~= "", "bad JSON at " .. pos)
		pos = pos + #number
		return tonumber(number)
	end
	local result = value()
	skip()
	assert(pos > #text, "trailing JSON at " .. pos)
	return result
end

-- ---------------------------------------------------------------------------
-- Real stat pools from grug_quality (top level needs only no-op stubs).
-- ---------------------------------------------------------------------------
local noop_table = setmetatable({}, {__index = function() return function() end end})
_G.core = noop_table
setmetatable(_G, {__index = function(_, name)
	if type(name) == "string" and name:match("^grug_") then return noop_table end
end})
dofile("mods/ITEMS/grug_quality/init.lua")
setmetatable(_G, nil)
local POOLS = assert(grug_items.POOLS, "grug_quality POOLS")
local enchant_pool = grug_items.enchant_pool

local data = dofile("mods/ITEMS/grug_professions/enchant_data.lua")

-- What register_enchants builds for one family, without the engine.
local function operations(by_tier, family, own)
	local result = {}
	for tier = 1, 6 do
		for _, channel in ipairs({"prefix", "suffix"}) do
			for _, stat in ipairs(enchant_pool(family, channel)) do
				result[#result + 1] = {tier = tier, channel = channel, stat = stat, family = family,
					inputs = data.operation_inputs(by_tier, family, stat, channel, tier,
						own[tier])}
			end
		end
	end
	return result
end
local function own_of(family)
	local own = {}
	for tier = 1, 6 do own[tier] = "own:" .. family .. "_t" .. tier end
	return own
end

-- ---------------------------------------------------------------------------
-- 1. The shipped catalogue data.
-- ---------------------------------------------------------------------------
local shipped_text = read("mods/ITEMS/grug_professions/data/enchants.json")
eq(shipped_text, read("tools/r33_ds/enchants_r33.json"),
	"shipped enchants.json is the Round 33 data design's")
local shipped = decode_json(shipped_text)
local by_tier = data.validate_enchants(shipped, POOLS)
local families, stats = data.families_and_stats(POOLS)
eq(#families, 11, "eleven enchant families")
local stat_count = 0
for _ in pairs(stats) do stat_count = stat_count + 1 end
eq(stat_count, 9, "nine stats")
local total = 0
for _, family in ipairs(families) do
	local ops = operations(by_tier, family, own_of(family))
	total = total + #ops
	for _, op in ipairs(ops) do
		eq(#op.inputs, 3, family .. " op has three inputs")
		eq(op.inputs[1], "own:" .. family .. "_t" .. op.tier, family .. " own material first")
		local row = shipped[op.tier]
		eq(op.inputs[2], row[op.channel .. "_loot"][op.stat],
			family .. " T" .. op.tier .. " " .. op.channel .. " loot")
		eq(op.inputs[3], row.family_input[family], family .. " T" .. op.tier .. " family input")
	end
end
eq(total, 588, "588 operations from the shipped data")
eq(#data.referenced_items(by_tier), 6 * (9 + 9 + 11), "referenced items listed per tier")

-- ---------------------------------------------------------------------------
-- 2. A complete sample catalogue: distinct items per stat, family and tier.
-- ---------------------------------------------------------------------------
local stat_list = {}
for stat in pairs(stats) do stat_list[#stat_list + 1] = stat end
table.sort(stat_list)
local function sample()
	local rows = {}
	for tier = 1, 6 do
		local row = {tier = tier, prefix_loot = {}, suffix_loot = {}, family_input = {}}
		for _, stat in ipairs(stat_list) do
			row.prefix_loot[stat] = "loot:" .. stat .. "_t" .. tier
			row.suffix_loot[stat] = "sloot:" .. stat .. "_t" .. tier
		end
		for _, family in ipairs(families) do
			row.family_input[family] = "mine:" .. family .. "_t" .. tier
		end
		rows[tier] = row
	end
	return rows
end
local sample_tiers = data.validate_enchants(sample(), POOLS)
local inputs = data.operation_inputs(sample_tiers, "sword", "dex", "prefix", 2,
	"grug_materials:iron_bar")
eq(table.concat(inputs, ","), "grug_materials:iron_bar,loot:dex_t2,mine:sword_t2",
	"sword T2 dex prefix cost")
inputs = data.operation_inputs(sample_tiers, "leather_armor", "dodge_percent", "suffix", 5,
	"grug_professions:sleek_leather")
eq(table.concat(inputs, ","),
	"grug_professions:sleek_leather,sloot:dodge_percent_t5,mine:leather_armor_t5",
	"leather T5 dodge suffix cost")
local trinket_ops = operations(sample_tiers, "trinket", own_of("trinket"))
eq(#trinket_ops, 36, "36 trinket operations")
local by_key = {}
for _, op in ipairs(trinket_ops) do
	by_key[op.channel .. ":" .. op.stat .. ":" .. op.tier] = table.concat(op.inputs, ",")
	eq(op.inputs[2], (op.channel == "prefix" and "loot:" or "sloot:") .. op.stat .. "_t" .. op.tier,
		"trinket " .. op.channel .. " uses its channel's loot")
	eq(op.inputs[3], "mine:trinket_t" .. op.tier, "trinket uses its family input")
end
check(by_key["prefix:str:4"] and by_key["suffix:crit_percent:4"], "trinket pools differ by channel")
check(by_key["suffix:str:4"] == nil, "trinket suffix has no Strength")
local sword_ops = operations(sample_tiers, "sword", own_of("sword"))
local by_channel = {}
for _, op in ipairs(sword_ops) do
	local key = op.stat .. ":" .. op.tier
	by_channel[key] = by_channel[key] or {}
	by_channel[key][op.channel] = op.inputs[2]
end
for key, loot in pairs(by_channel) do
	check(loot.prefix and loot.suffix and loot.prefix ~= loot.suffix,
		"sword prefix and suffix take their own loot " .. key)
end

-- ---------------------------------------------------------------------------
-- 3. Load errors.
-- ---------------------------------------------------------------------------
local function broken(edit)
	local rows = sample()
	edit(rows)
	return function() return data.validate_enchants(rows, POOLS) end
end
fails_with(broken(function(rows) rows[3].prefix_loot.dodge_percent = nil end),
	"tier 3 has no prefix_loot entry for stat dodge_percent", "missing prefix loot")
fails_with(broken(function(rows) rows[2].suffix_loot.armor_rating = nil end),
	"tier 2 has no suffix_loot entry for stat armor_rating", "missing suffix loot")
fails_with(broken(function(rows) rows[2].suffix_loot = nil end),
	"tier 2 needs suffix_loot", "suffix loot block missing")
fails_with(broken(function(rows) rows[5].family_input.bow = nil end),
	"tier 5 has no family_input entry for family bow", "missing family input")
fails_with(broken(function(rows) rows[2].prefix_loot.strength = "loot:x" end),
	"unknown stat strength", "unknown stat")
fails_with(broken(function(rows) rows[1].family_input.axe = "mine:x" end),
	"unknown family axe", "unknown family")
fails_with(broken(function(rows) rows[6] = nil end), "no entry for tier 6", "missing tier")
fails_with(broken(function(rows) rows[6].tier = 5 end), "lists tier 5 twice", "duplicate tier")
fails_with(broken(function(rows) rows[4].suffix_loot.int = "crab eye" end),
	"suffix_loot.int is not an item name", "non-item suffix loot")
fails_with(broken(function(rows) rows[1].family_input = nil end),
	"needs family_input", "family_input block missing")
fails_with(function() return data.validate_enchants({}, POOLS) end, "non-empty list",
	"empty catalogue")
-- The frame's one-tier example is not a complete catalogue.
fails_with(function()
	return data.validate_enchants(decode_json(read(
		"tools/r28_design/samples/valid/catalog/enchants.json")), POOLS)
end, "tier 1 needs prefix_loot", "the Round 28 one-loot sample is no catalogue now")
fails_with(function()
	return data.operation_inputs(sample_tiers, "sword", "dex", "prefix", 1, nil)
end,
	"sword T1 has no own material", "missing own material")

-- Enchant inputs above the operation tier.
local tiers = {["grug_materials:iron_bar"] = 2, ["loot:dex_t2"] = 2, ["mine:sword_t2"] = 3}
local over = data.over_tier_inputs({
	{tier = 2, label = "enchant:sword:prefix:dex:t2",
		inputs = {"grug_materials:iron_bar", "loot:dex_t2", "mine:sword_t2"}},
	{tier = 3, label = "enchant:sword:prefix:dex:t3",
		inputs = {"grug_materials:iron_bar", "mine:sword_t2", "undeclared:item"}},
}, function(item) return tiers[item] end)
eq(#over, 1, "one input above its tier")
check(over[1] and over[1]:find("enchant:sword:prefix:dex:t2 (T2) needs mine:sword_t2, a T3 ingredient",
	1, true), "over-tier text")

-- ---------------------------------------------------------------------------
-- 4. Cross-profession inputs.
-- ---------------------------------------------------------------------------
local products = {["grug_artisans:setting_tin"] = "goldsmith",
	["grug_professions:woven_bolt_bundle"] = "tailor"}
local offences = data.foreign_inputs(products, {
	{profession = "goldsmith", label = "own", inputs = {"grug_artisans:setting_tin", "loot:a"}},
	{profession = "woodcarver", label = "enchant:bow", inputs = {"grug_artisans:setting_tin"}},
})
eq(#offences, 1, "one cross-profession offence")
check(offences[1] and offences[1]:find("woodcarver enchant:bow needs grug_artisans:setting_tin, " ..
	"a goldsmith product", 1, true), "operation offence text")

-- ---------------------------------------------------------------------------
-- 5. Cooking routes (the real grug_cooking/init.lua and Basics catalogue).
-- ---------------------------------------------------------------------------
local registered = setmetatable({}, {__index = function(_, name)
	return {description = name, groups = {}}
end})
local routes = {}
_G.core = {
	registered_items = registered,
	register_craftitem = function(name, def) rawset(registered, name, def) end,
	override_item = function() end,
	register_craft = function() end,
}
_G.grug_food = {register_item = function() return true end}
_G.grug_jobs = {
	register_ingredient_tier = function() end,
	register_recipe = function(def) routes[#routes + 1] = def end,
}
dofile("mods/ITEMS/grug_cooking/init.lua")
local FURNACE_ONLY = {hearty_stew = true, pumpkin_stew = true, foragers_pot = true,
	marsh_roast = true, kelp_wrapped_roast = true, grand_feast = true}
local function routes_for(item)
	local grid, furnace = 0, 0
	for _, def in ipairs(routes) do
		if def.output == item then
			if def.station == "grid" then grid = grid + 1 end
			if def.station == "furnace" then furnace = furnace + 1 end
		end
	end
	return grid, furnace
end
local grid_dishes = 0
for _, dish in ipairs(grug_cooking.DISHES) do
	local grid, furnace = routes_for(dish.item)
	if FURNACE_ONLY[dish.id] then
		eq(grid, 0, dish.id .. " has no grid route")
		eq(furnace, 1, dish.id .. " comes from its raw assembly in the furnace")
	else
		grid_dishes = grid_dishes + 1
		eq(grid, 1, dish.id .. " keeps its grid route")
	end
end
eq(grid_dishes, 12, "twelve dishes keep a grid route")
for _, raw in ipairs(grug_cooking.RAW_ASSEMBLIES) do
	check(FURNACE_ONLY[raw.output:match(":(.+)$")], raw.id .. " finishes a furnace-only dish")
	eq((routes_for(raw.item)), 1, raw.id .. " is assembled on the grid")
end
local catalogue = dofile("mods/PLAYER/grug_jobs/basics_routes.lua")
for _, route in ipairs(catalogue) do
	local id = route.output:match("^grug_cooking:(.+)$")
	if id and FURNACE_ONLY[id] then
		eq(route.station, "furnace", "Basics catalogue " .. id .. " route is the furnace")
	end
end

-- ---------------------------------------------------------------------------
-- 6. No metal fittings in the profession sources.
-- ---------------------------------------------------------------------------
for _, path in ipairs({"mods/ITEMS/grug_professions/init.lua",
		"mods/ITEMS/grug_professions/smiths.lua", "mods/ITEMS/grug_professions/enchants.lua",
		"mods/ITEMS/grug_artisans/enchants.lua", "mods/ITEMS/grug_artisans/woodcarver.lua"}) do
	check(not read(path):find("fitting", 1, true), path .. " mentions no fittings")
end

print(("R28 B5 PORTABLE %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
	checks, failures))
if failures > 0 then os.exit(1) end
