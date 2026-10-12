-- Round 46 lane LT portable test (LuaJIT): loot, coin bags and cloth
-- (round46-plan.md §4.6, rulings 11 and 12).
--
--   luajit tools/r46_lt/portable_test.lua [ROOT]
--
-- A. The data: none of the 23 sell-only items in any drop row (drops.json
--    and every grug_mobs entity file), the items still in items.json; every
--    tier-cloth row of the six cloth families (and the outlaw silk) at
--    1/1 x1-2; the spider family's band 5; briar_web_spider at 21-50 and in
--    both 41-50 zones' recipes with a name per slot; the design catalogue
--    copies byte-equal to the shipped files.
-- B. The coin bag (the REAL grug_mobs disposition.lua and aggro.lua, the
--    REAL grug_money init.lua and coins.lua, under a minimal stub): the
--    band means are 4 x the price tier factor, a bag holds half to one and a
--    half times its band's mean, one roll per looted kill, none for an
--    untagged kill, a critter, a faction NPC or a failed roll.
-- C. The automatic deposit on pickup: on by default (no meta), a picked-up
--    bag is credited and gone; off, or refused by the deposit rules (empty
--    bag, the balance clamp, no player), it goes to the ordinary pickup, so a
--    bag is never lost or doubled; the toggle's meta values.
-- Prints "R46 LT PORTABLE PASS checks=<n>" or exits 1 listing failures.

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
local function read(path)
	local file = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = file:read("*a")
	file:close()
	return text
end

------------------------------------------------------------------------------
-- A small JSON decoder (core.parse_json is engine C++).
------------------------------------------------------------------------------
local function json_decode(text)
	local pos = 1
	local value
	local function ws() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = text:sub(pos, pos)
			assert(c ~= "", "unterminated string")
			if c == '"' then pos = pos + 1 break end
			if c == "\\" then
				local e = text:sub(pos + 1, pos + 1)
				if e == "u" then
					out[#out + 1] = "?"
					pos = pos + 6
				else
					out[#out + 1] = ({n = "\n", t = "\t", r = "\r", ['"'] = '"',
						["\\"] = "\\", ["/"] = "/"})[e]
					pos = pos + 2
				end
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = text:sub(pos, pos)
		if c == "{" or c == "[" then
			local obj, is_obj = {}, c == "{"
			pos = pos + 1
			ws()
			if text:sub(pos, pos) == (is_obj and "}" or "]") then pos = pos + 1 return obj end
			while true do
				if is_obj then
					ws()
					local k = str()
					ws()
					pos = pos + 1 -- ':'
					obj[k] = value()
				else
					obj[#obj + 1] = value()
				end
				ws()
				local d = text:sub(pos, pos)
				pos = pos + 1
				if d == "}" or d == "]" then return obj end
			end
		elseif c == '"' then
			return str()
		elseif text:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif text:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif text:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
		end
		local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		pos = pos + #num
		return tonumber(num)
	end
	return value()
end

------------------------------------------------------------------------------
-- A. The data
------------------------------------------------------------------------------
local SELL_ONLY = {
	"abyssal_crab_shell", "arrow", "blunt_croc_tooth", "ridged_croc_tooth", "croc_tooth",
	"bone_chitin", "layered_bone_chitin", "campaign_purse", "chipped_core", "siege_core",
	"stone_core", "veined_core", "concentrated_venom", "mild_venom", "feather",
	"mourning_resin", "raptor_claw", "reed_pearl", "restless_wisp_mote", "salt_bear_claw",
	"scarred_bear_claw", "saltpack_fang", "thin_slime_gel",
}
eq(#SELL_ONLY, 23, "A the 23 sell-only items")
local sell = {}
for _, short in ipairs(SELL_ONLY) do sell["grug_mobs:" .. short] = true end

local MOBS = "mods/ENTITIES/grug_mobs"
local drops_text = read(MOBS .. "/data/drops.json")
local drops = json_decode(drops_text)
local family = {}
for _, row in ipairs(drops) do family[row.family] = row end

local found = {}
for _, fam in ipairs(drops) do
	for _, rows in pairs(fam.bands) do
		for _, row in ipairs(rows) do
			if sell[row.item] then found[#found + 1] = fam.family .. ":" .. row.item end
		end
	end
	for _, row in ipairs(fam.leader_bonus or {}) do
		if sell[row.item] then found[#found + 1] = fam.family .. " leader:" .. row.item end
	end
end
eq(table.concat(found, ", "), "", "A no drops.json row names a sell-only item")

-- Every grug_mobs file init.lua loads: no quoted full id of a sell-only
-- item (the arrow entity "grug_mobs:arrow_entity" is another name).
local files = {"init.lua"}
for name in read(MOBS .. "/init.lua"):gmatch('dofile%(modpath %.%. "/([%w_]+%.lua)"%)') do
	files[#files + 1] = name
end
check(#files > 50, "A the grug_mobs entity files listed (" .. #files .. ")")
local static = {}
for _, name in ipairs(files) do
	for id in read(MOBS .. "/" .. name):gmatch('"(grug_mobs:[%w_]+)"') do
		if sell[id] then static[#static + 1] = name .. ":" .. id end
	end
end
eq(table.concat(static, ", "), "", "A no static drop names a sell-only item")

local items_text = read(MOBS .. "/data/items.json")
for _, short in ipairs(SELL_ONLY) do
	check(items_text:find('"grug_mobs:' .. short .. '"', 1, true) or
		read(MOBS .. "/items.lua"):find('"' .. short .. '"', 1, true),
		"A " .. short .. " stays registered (items.json or items.lua)")
end

-- Cloth (ruling 11): the band's tier cloth 1/1 x1-2.
local CLOTH = {zombie = {1, 2, 3, 4, 5, 6}, outlaw = {1, 2, 3, 4, 5, 6},
	goblin = {2, 3, 4}, mirefolk = {2, 3}, skeleton = {3, 4, 5, 6}, witch = {4, 6}}
local function tier_cloth(band)
	return band == 1 and "grug_mobs:linen_scrap" or band == 2 and "grug_mobs:linen_cloth"
		or "grug_mobs:heavy_cloth"
end
for name, bands in pairs(CLOTH) do
	for _, band in ipairs(bands) do
		local rows = family[name] and family[name].bands[tostring(band)] or {}
		local hit
		for _, row in ipairs(rows) do
			if row.item == tier_cloth(band) then hit = row end
		end
		check(hit and hit.chance == 1 and hit.min == 1 and hit.max == 2,
			"A " .. name .. " band " .. band .. ": " .. tier_cloth(band) .. " 1/1 x1-2")
	end
end
for _, band in ipairs({"5", "6"}) do
	local silk
	for _, row in ipairs(family.outlaw.bands[band]) do
		if row.item == "grug_mobs:spider_silk" then silk = row end
	end
	check(silk and silk.chance == 1 and silk.min == 1 and silk.max == 2,
		"A outlaw band " .. band .. ": silk 1/1 x1-2")
end
-- The rows that lost their only item are empty lists (drop nothing).
for _, at in ipairs({{"venomous", "1"}, {"venomous", "3"}, {"wisp", "4"}}) do
	local rows = family[at[1]].bands[at[2]]
	check(rows and #rows == 0, "A " .. at[1] .. " band " .. at[2] .. " is an empty list")
end

-- Spiders at 41-50.
local spider5 = family.spider.bands["5"]
local silk5
for _, row in ipairs(spider5 or {}) do
	if row.item == "grug_mobs:spider_silk" then silk5 = row end
end
check(silk5 and silk5.chance == 1 and silk5.max == 2, "A spider band 5: silk 1/1 x1-2")
local briar
for _, row in ipairs(json_decode(read(MOBS .. "/data/subtypes.json"))) do
	if row.role == "briar_web_spider" then briar = row end
end
check(briar and briar.levels[1] == 21 and briar.levels[2] == 50, "A briar_web_spider at 21-50")
local names = json_decode(read(MOBS .. "/data/names.json")).names
for _, zone in ipairs({"front_broken_causeway", "front_shattered_line"}) do
	local recipe = json_decode(read(MOBS .. "/data/zones/" .. zone .. ".spawns.json")).recipe
	local belts = 0
	for _, belt in ipairs(recipe.belts) do
		local here = false
		for _, kind in pairs(belt.kinds) do
			for _, clock in ipairs({"day", "night"}) do
				if type(kind[clock]) == "table" then
					for _, entry in ipairs(kind[clock]) do
						if entry.role == "briar_web_spider" then here = true end
					end
				end
			end
		end
		if here then
			belts = belts + 1
			local key = ("%s/briar_web_spider/L%d-%d"):format(zone, belt.levels[1], belt.levels[2])
			check(type(names[key]) == "string" and names[key] ~= "", "A " .. key .. " has a name")
		end
	end
	eq(belts, 3, "A " .. zone .. ": a spider in every belt")
end

-- The design catalogue copies (tools/r28_e1/run.sh compares them too).
for _, file in ipairs({"drops", "subtypes", "items", "tints"}) do
	eq(read("docs/planning/round28/design/catalog/" .. file .. ".json") ==
		read(MOBS .. "/data/" .. file .. ".json"), true, "A the design copy of " .. file .. ".json")
end

------------------------------------------------------------------------------
-- Stubs for B and C
------------------------------------------------------------------------------
local function new_stack(name, count)
	local stack = {name = name or "", count = count or 0, fields = {}}
	function stack:get_name() return self.name end
	function stack:get_count() return self.count end
	function stack:is_empty() return self.name == "" or self.count < 1 end
	function stack:take_item(n)
		n = math.min(n or 1, self.count)
		self.count = self.count - n
		if self.count < 1 then self.name = "" end
		return new_stack(self.name, n)
	end
	function stack:get_meta()
		local fields = self.fields
		return {
			set_int = function(_, k, v) fields[k] = tostring(v) end,
			get_int = function(_, k) return tonumber(fields[k]) or 0 end,
			set_string = function(_, k, v) fields[k] = v end,
			get_string = function(_, k) return fields[k] or "" end,
		}
	end
	return stack
end
function ItemStack(x)
	if type(x) == "table" then return x end
	if x == nil or x == "" then return new_stack("", 0) end
	return new_stack(x:match("^(%S+)"), tonumber(x:match("%s(%d+)")) or 1)
end
table.copy = table.copy or function(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end
string.trim = string.trim or function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local registered, added, pickups, feeds, sounds = {}, {}, {}, {}, 0
local noop = function() end
core = {
	register_craftitem = function(name, def) registered[name] = def end,
	register_chatcommand = noop,
	register_on_joinplayer = noop,
	register_on_leaveplayer = noop,
	register_on_player_receive_fields = noop,
	register_on_mods_loaded = noop,
	register_on_dieplayer = noop,
	get_modpath = function(mod) return ROOT .. "/mods/PLAYER/" .. mod end,
	formspec_escape = function(s) return s end,
	colorize = function(_, s) return s end,
	get_gametime = function() return 1000 end,
	log = noop,
	settings = {get = function() return nil end,
		get_bool = function(_, _, default) return default end},
	add_item = function(pos, stack)
		added[#added + 1] = {pos = pos, stack = stack}
		return {set_velocity = noop}
	end,
	-- The ordinary pickup: into the inventory (what fits), the rest stays.
	item_pickup = function(stack, picker)
		pickups[#pickups + 1] = stack
		return picker and picker.full and stack or ItemStack("")
	end,
}
grug_core = {feed = function(_, kind, text) feeds[#feeds + 1] = text end}
grug_sounds = {play = function() sounds = sounds + 1 end}

local function make_player(name)
	local meta = {}
	return {
		meta = meta,
		is_player = function() return true end,
		get_player_name = function() return name end,
		get_meta = function()
			return {
				get_int = function(_, k) return tonumber(meta[k]) or 0 end,
				set_int = function(_, k, v) meta[k] = tostring(v) end,
				get_string = function(_, k) return meta[k] or "" end,
				set_string = function(_, k, v) meta[k] = v end,
			}
		end,
	}
end

dofile(ROOT .. "/mods/PLAYER/grug_money/init.lua")
local BAG = grug_money.BAG
local bag_def = registered[BAG]
check(bag_def and type(bag_def.on_pickup) == "function", "C the bag has its own on_pickup")

grug_mobs = {}
dofile(ROOT .. "/" .. MOBS .. "/disposition.lua")
dofile(ROOT .. "/" .. MOBS .. "/aggro.lua")
-- subtypes.lua's band rule and drop rows (loaded there; the rows are r28_b2's).
function grug_mobs.level_band(level)
	return math.max(1, math.min(6, math.floor(((level or 1) - 1) / 10) + 1))
end
function grug_mobs.band_drop_rows() return nil end

------------------------------------------------------------------------------
-- B. The coin bag
------------------------------------------------------------------------------
local rules = dofile(ROOT .. "/mods/ENTITIES/grug_traders/price_rules.lua")
local bag = grug_mobs.COIN_BAG
eq(bag.chance, 8, "B one roll in 8")
for band = 1, 6 do
	local mean = bag.copper[band]
	eq(mean, math.floor(4 * rules.TIER_FACTOR[band] + 0.5), "B band " .. band .. ": 4 x the tier factor")
	local range = grug_mobs.coin_bag_range(band)
	eq(range[1], math.max(1, math.floor(mean / 2 + 0.5)), "B band " .. band .. ": the low end")
	eq(range[2], math.floor(mean * 1.5 + 0.5), "B band " .. band .. ": the high end")
	check(math.abs((range[1] + range[2]) / 2 - mean) <= 0.5, "B band " .. band .. ": centred on the mean")
end

local real_random = math.random
local queue = {}
math.random = function(a, b)
	if a == nil then return real_random() end -- the bag's toss
	local v = table.remove(queue, 1)
	if v == nil then return real_random(a, b) end
	if v == "hi" then return b end
	if v == "lo" then return b and a or 1 end
	return v
end
local function mob(name, level, extra)
	local self = {name = name, _grug_level = level, _grug_drop_rule = true,
		object = {get_pos = function() return {x = 1, y = 2, z = 3} end},
		_grug_player_tag = {name = "hunter", until_t = 2000},
		drops = {{name = "mobs:meat_raw", chance = 1, min = 1, max = 1}}}
	for k, v in pairs(extra or {}) do self[k] = v end
	return self
end

for band = 1, 6 do
	local level = band * 10 - 5
	local range = grug_mobs.coin_bag_range(band)
	for _, pick in ipairs({"lo", "hi"}) do
		local before = #added
		queue = {1, pick}
		local wolf = mob("grug_mobs:wolf", level)
		local out = grug_mobs._item_drop_filter(wolf, wolf.drops)
		check(type(out) == "table" and out[1] and out[1].name == "mobs:meat_raw",
			"B band " .. band .. ": the loot list as before")
		eq(#added, before + 1, "B band " .. band .. " " .. pick .. ": one bag dropped")
		local got = added[#added] and grug_money.bag_amount(added[#added].stack)
		eq(got, pick == "lo" and range[1] or range[2], "B band " .. band .. " " .. pick .. ": its amount")
		eq(added[#added] and added[#added].stack:get_name(), BAG, "B the bag is the Bag of Coins")
	end
end
local before = #added
queue = {2}
grug_mobs._item_drop_filter(mob("grug_mobs:wolf", 15))
eq(#added, before, "B a failed roll drops no bag")
queue = {1, "lo"}
eq(grug_mobs._item_drop_filter(mob("grug_mobs:wolf", 15, {_grug_player_tag = false})), nil,
	"B an untagged kill drops nothing")
eq(#added, before, "B an untagged kill drops no bag")
queue = {1, "lo"}
grug_mobs._item_drop_filter(mob("grug_mobs:rabbit", 3))
eq(#added, before, "B a critter drops no bag")
queue = {1, "lo"}
eq(grug_mobs.drop_coin_bag(mob("grug_mobs:guard_accord", 30, {_grug_faction = "accord"})), nil,
	"B a faction NPC drops no bag")
eq(#added, before, "B nothing added for the faction NPC")
queue = {}

-- The expected copper per kill is half a tier factor.
for band = 1, 6 do
	local range = grug_mobs.coin_bag_range(band)
	local per_kill = (range[1] + range[2]) / 2 / bag.chance
	check(math.abs(per_kill - rules.TIER_FACTOR[band] / 2) <= 0.1,
		("B band %d: %.2fc per kill ~ half the tier factor"):format(band, per_kill))
end
math.random = real_random

------------------------------------------------------------------------------
-- C. The automatic deposit on pickup
------------------------------------------------------------------------------
local p = make_player("picker")
check(grug_money.auto_deposit(p), "C on by default (no meta)")
local bag37 = grug_money.make_bag(37)
local left = bag_def.on_pickup(bag37, p, {type = "object"})
check(left:is_empty(), "C on: the bag leaves the ground")
eq(grug_money.get(p), 37, "C on: credited")
eq(#pickups, 0, "C on: not put into the inventory")
eq(feeds[#feeds], "Deposited 37c.", "C on: the feed says so")
eq(sounds, 1, "C on: the money sound")

grug_money.set_auto_deposit(p, false)
eq(p.meta[grug_money.AUTO_DEPOSIT_KEY], "off", "C off: stored as \"off\"")
check(not grug_money.auto_deposit(p), "C off: read back")
left = bag_def.on_pickup(grug_money.make_bag(20), p, {type = "object"})
eq(#pickups, 1, "C off: the ordinary pickup")
check(left:is_empty(), "C off: picked up into the inventory")
eq(grug_money.get(p), 37, "C off: not credited")
p.full = true
local full_bag = grug_money.make_bag(20)
left = bag_def.on_pickup(full_bag, p, {type = "object"})
check(not left:is_empty() and grug_money.bag_amount(left) == 20,
	"C off, inventory full: the bag stays on the ground, amount kept")
eq(grug_money.get(p), 37, "C off, inventory full: not credited")
p.full = nil

grug_money.set_auto_deposit(p, true)
eq(p.meta[grug_money.AUTO_DEPOSIT_KEY], "", "C on again: the key cleared")
check(grug_money.auto_deposit(p), "C on again: read back")

-- Refusals go to the ordinary pickup with the bag unchanged.
local pickups_before = #pickups
grug_money.set(p, grug_money.MAX - 10)
left = bag_def.on_pickup(grug_money.make_bag(37), p, {type = "object"})
eq(#pickups, pickups_before + 1, "C over the clamp: the ordinary pickup")
eq(grug_money.get(p), grug_money.MAX - 10, "C over the clamp: not credited")
grug_money.set(p, 0)
left = bag_def.on_pickup(ItemStack(BAG), p, {type = "object"})
eq(#pickups, pickups_before + 2, "C an empty bag: the ordinary pickup")
eq(grug_money.get(p), 0, "C an empty bag: nothing credited")
p.full = true
left = bag_def.on_pickup(grug_money.make_bag(5), p, {type = "object"})
check(left:is_empty() and grug_money.get(p) == 5, "C on, inventory full: still credited")
p.full = nil
local mob_picker = {is_player = function() return false end}
left = bag_def.on_pickup(grug_money.make_bag(9), mob_picker, {type = "object"})
eq(#pickups, pickups_before + 3, "C not a player: the ordinary pickup")
check(not grug_money.auto_deposit_pickup(nil, grug_money.make_bag(9)), "C no picker: refused")

if failures > 0 then
	error(("R46 LT PORTABLE FAIL checks=%d failures=%d"):format(checks, failures))
end
print(("R46 LT PORTABLE PASS checks=%d"):format(checks))
