-- Round 31 Lane A portable test (LuaJIT): character looks
-- (round31-plan.md §2.1).
--
--   luajit tools/r31_a/portable_test.lua [REPO]
--
-- Loads the REAL grug_visuals files (looks, compose, wield_geometry, apply)
-- and player_api against stubs:
--   A. the option counts per race are the plan's table (§2.1.2);
--   B. every texture a look can name exists and has its LICENSE-media row,
--      and every licensed look layer is named by some look;
--   C. normalize / parse / look_string round trip; roll_look and the NPC
--      seed stay in range and reach every option; an NPC rolls ONCE and
--      keeps its look; the seed derivation is pinned;
--   D. layer order (§2.1.3): skin -> eyes -> hairstyle -> attire -> body
--      armour -> helmet with the face window -> headwear -> feature; a helmet
--      drops the hairstyle;
--   E. compose: every armour piece in its own parentheses (the Silversteel
--      `^[hsl` never reaches the skin), lane B's `armor_layers` inside the
--      piece and, for the helmet, under the face window; the cache key moves
--      with every input; royal attire; the explicit-skin path; the
--      worst-case string length;
--   F. equal hitbox (§2.1.4): after player_api's model and grug_visuals'
--      apply, every race has the same collision box, selection box and eye
--      height, and only the visual size differs;
--   G. the stored look: set once, immutable, read back through player_spec.
-- Prints "R31 A PORTABLE PASS checks=<n> worst=<length>" or the failures.

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
	return text:find(needle, 1, true) ~= nil
end
local function position(text, needle)
	return text:find(needle, 1, true) or -1
end

------------------------------------------------------------------------------
-- Stubs: just enough engine for the real files.
------------------------------------------------------------------------------
local callbacks = {join = {}, race = {}, class = {}, equipment = {}}
local logs = {}
core = {
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	get_modpath = function(name)
		return ROOT .. (name == "player_api" and "/mods/BASE/" or "/mods/PLAYER/") .. name
	end,
	formspec_escape = function(text) return text end,
	calculate_knockback = function() return 0 end,
	get_connected_players = function() return {} end,
	get_current_modname = function() return "grug_visuals" end,
	register_entity = function() end,
	register_globalstep = function() end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_respawnplayer = function() end,
	register_on_mods_loaded = function() end,
	get_item_group = function() return 0 end,
	registered_items = {},
	global_exists = function(name) return rawget(_G, name) ~= nil end,
}
minetest = core
local race_of = {}
grug_classes = {
	race_ids = {accord = {"human", "dwarf", "elf"}, throng = {"orc", "troll", "undead"}},
	registered_races = {},
	get_race = function(player) return race_of[player] end,
	register_on_race_chosen = function(fn) callbacks.race[#callbacks.race + 1] = fn end,
	register_on_class_chosen = function(fn) callbacks.class[#callbacks.class + 1] = fn end,
	register_look_step = function(step) callbacks.look_step = step end,
}
grug_core = {
	register_on_equipment_change = function(fn) callbacks.equipment[#callbacks.equipment + 1] = fn end,
	equipment_is_broken = function() return false end,
	settlement_socket_settlements = function()
		return {{key = "start_dwarf", race_id = "dwarf"}, {key = "capital_troll", race_id = "troll"}}
	end,
}
grug_inventory = {
	get_cosmetic_weapon = function() return nil end,
	get_cosmetic_hand = function() return nil end,
}
grug_gear = {
	BRACKETS = {{}, {}, {}, {}, {}, {}},
	MATERIALS = {
		{metal = {key = "bronze"}, cloth = {key = "patch"}, leather = {key = "light"}},
		{metal = {key = "iron"}, cloth = {key = "woven"}, leather = {key = "cured"}},
		{metal = {key = "steel"}, cloth = {key = "heavy"}, leather = {key = "heavy"}},
		{metal = {key = "silversteel"}, cloth = {key = "silkweave"}, leather = {key = "scaled"}},
		{metal = {key = "embersteel"}, cloth = {key = "silk"}, leather = {key = "sleek"}},
		{metal = {key = "abyssal_steel"}, cloth = {key = "stormweave"}, leather = {key = "nightscale"}},
	},
	bracket_for_level = function(level)
		if type(level) ~= "number" then return 1 end
		return math.max(1, math.min(6, math.ceil(level / 10)))
	end,
	weapon_item = function(family, bracket)
		return "grug_gear:" .. family .. "_" .. grug_gear.MATERIALS[bracket].metal.key
	end,
}
-- The real crack wrapper, so the broken path is the shipped one.
dofile(ROOT .. "/mods/ITEMS/grug_gear/permissions.lua")
local function new_meta()
	local store = {}
	return {
		get_string = function(_, key) return store[key] or "" end,
		set_string = function(_, key, value) store[key] = value end,
	}
end
ItemStack = function() return {get_name = function() return "" end,
	get_meta = function() return new_meta() end, to_string = function() return "" end} end

-- Builtin's table.copy (grug_visuals copies player_api's model definition).
function table.copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = table.copy(v) end
	return out
end

-- player_api (the vendored base) first, as the dependency order loads it:
-- the model registry the boxes come from, and its join hook runs first.
player_api = nil
dofile(ROOT .. "/mods/BASE/player_api/init.lua")
grug_visuals = nil
dofile(ROOT .. "/mods/PLAYER/grug_visuals/init.lua")

local LOOKS = grug_visuals.LOOKS
local TEXTURES = ROOT .. "/mods/PLAYER/grug_visuals/textures/"

------------------------------------------------------------------------------
-- A. Option counts.
------------------------------------------------------------------------------
local PLAN = {
	human = {tone = 4, hair = 6, style = 4, eyes = 3, feature = 3},
	dwarf = {tone = 3, hair = 5, style = 3, eyes = 3, feature = 4},
	elf = {tone = 3, hair = 5, style = 4, eyes = 3, feature = 3},
	orc = {tone = 3, hair = 4, style = 4, eyes = 3, feature = 4},
	troll = {tone = 3, hair = 5, style = 4, eyes = 3, feature = 3},
	undead = {tone = 3, hair = 4, style = 3, eyes = 3, feature = 3},
}
local races = {}
for race in pairs(LOOKS) do
	races[#races + 1] = race
end
table.sort(races)
eq(#races, 6, "six races")
for race, counts in pairs(PLAN) do
	check(LOOKS[race] ~= nil, race .. " has looks")
	check(grug_visuals.RACES[race] ~= nil, race .. " has a stature")
	check(grug_visuals.ROYAL[race] ~= nil, race .. " has royal colours")
	check(grug_visuals.KING_LOOKS[race] ~= nil, race .. " has a king look")
	for category, count in pairs(counts) do
		eq(#LOOKS[race].options[category], count, race .. " " .. category .. " count")
	end
	for _, list in ipairs({LOOKS[race].tones, LOOKS[race].hair, LOOKS[race].eyes}) do
		for _, colour in ipairs(list) do
			check(colour:match("^#%x%x%x%x%x%x$") ~= nil, race .. " colour " .. colour)
		end
	end
	for category, value in pairs(grug_visuals.KING_LOOKS[race]) do
		check(value >= 1 and value <= counts[category], race .. " king " .. category ..
			" in range")
	end
end

------------------------------------------------------------------------------
-- B. Files.
------------------------------------------------------------------------------
local function exists(name)
	local handle = io.open(TEXTURES .. name, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

local named = {}
local function name(file)
	named[file] = true
	check(exists(file), "texture exists: " .. file)
end
for _, file in ipairs({grug_visuals.SKIN_MASK, grug_visuals.HELMET_WINDOW,
		"grug_visuals_tabard_mask.png", "grug_visuals_tabard_trim_mask.png",
		"grug_visuals_tabard.png", "grug_visuals_crown.png"}) do
	name(file)
end
for _, race in ipairs(races) do
	local def = LOOKS[race]
	name(def.body)
	name(def.eyes_mask)
	for _, style in ipairs(def.styles) do
		name(style.mask)
		name(style.detail)
		check(type(style.name) == "string", race .. " " .. style.id .. " has a name")
	end
	for _, feature in ipairs(def.features) do
		name(feature.detail)
		check(type(feature.name) == "string", race .. " " .. feature.id .. " has a name")
		check((feature.mask ~= nil) == (feature.tint ~= nil),
			race .. " " .. feature.id .. ": a mask exactly when tinted")
		if feature.mask then
			name(feature.mask)
		end
		check(feature.tint == nil or feature.tint == "hair" or feature.tint == "tone",
			race .. " " .. feature.id .. " tint")
	end
	check(not exists("grug_visuals_skin_" .. race .. ".png"),
		"the painted race skin of " .. race .. " is gone")
end
local license = io.open(ROOT .. "/mods/PLAYER/grug_visuals/LICENSE-media.md"):read("*a")
local rows = {}
for file in license:gmatch("\n| `(grug_visuals_[%w_]+%.png)` |") do
	rows[file] = true
	local layer = file:match("^grug_visuals_%l+_body%.png$") or
		file:match("^grug_visuals_%l+_hair_") or file:match("^grug_visuals_%l+_feature_") or
		file:match("_mask%.png$") or file:match("^grug_visuals_tabard") or
		file == grug_visuals.HELMET_WINDOW or file == "grug_visuals_crown.png"
	if layer then
		check(named[file] == true, "licensed layer file named by looks.lua: " .. file)
	end
end
for file in pairs(named) do
	check(rows[file] == true, "LICENSE-media row for " .. file)
end

------------------------------------------------------------------------------
-- C. Looks: normalize, parse, roll, seed.
------------------------------------------------------------------------------
local n = grug_visuals.normalize_look("human", {tone = 4, hair = 7, style = 2.5,
	eyes = 0})
eq(n.tone, 4, "valid tone kept")
eq(n.hair, 1, "out-of-range hair -> 1")
eq(n.style, 1, "fractional style -> 1")
eq(n.eyes, 1, "zero eyes -> 1")
eq(n.feature, 1, "missing feature -> 1")
eq(grug_visuals.normalize_look("gnome", {}), nil, "unknown race: no look")
eq(grug_visuals.normalize_look("orc", "junk").tone, 1, "non-table look")
local text = grug_visuals.look_string({tone = 3, hair = 2, style = 4, eyes = 1, feature = 3})
eq(text, "3,2,4,1,3", "look string")
local back = grug_visuals.parse_look("human", text)
eq(grug_visuals.look_string(back), text, "parse round trip")
eq(grug_visuals.parse_look("human", ""), nil, "empty string: no look")
eq(grug_visuals.parse_look("human", "1,2,3"), nil, "short string: no look")
eq(grug_visuals.look_string(grug_visuals.parse_look("dwarf", "4,9,1,1,1")),
	"1,1,1,1,1", "parse normalizes against the race")

math.randomseed(31)
for _, race in ipairs(races) do
	local seen, seen_seed = {}, {}
	for k = 1, 400 do
		local look = grug_visuals.roll_look(race)
		local from_seed = grug_visuals.look_from_seed(race, k * 7919)
		for _, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
			local count = #LOOKS[race].options[category]
			check(look[category] >= 1 and look[category] <= count, race .. " roll in range")
			check(from_seed[category] >= 1 and from_seed[category] <= count,
				race .. " seed look in range")
			seen[category .. look[category]] = true
			seen_seed[category .. from_seed[category]] = true
		end
	end
	for _, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		for index = 1, #LOOKS[race].options[category] do
			check(seen[category .. index], race .. " roll reaches " .. category .. " " .. index)
			check(seen_seed[category .. index], race .. " seed reaches " .. category ..
				" " .. index)
		end
	end
end
local picks = {}
grug_visuals.roll_look("dwarf", function(count)
	picks[#picks + 1] = count
	return count
end)
eq(table.concat(picks, ","), "3,5,3,3,4", "roll asks each category once, in order")
-- Pinned: the derivation must not drift, or every saved NPC changes face.
eq(grug_visuals.look_string(grug_visuals.look_from_seed("human", 12345)),
	grug_visuals.look_string(grug_visuals.look_from_seed("human", 12345 + 2147483647)),
	"seed is taken modulo 2^31 - 1")
eq(grug_visuals.look_string(grug_visuals.look_from_seed("human", 1)), "4,1,3,2,2",
	"pinned look of seed 1")

local npc = {}
local first = grug_visuals.npc_look(npc, "orc", function(lo, hi) return 777 end)
eq(npc._grug_look_seed, 777, "the NPC keeps its rolled seed")
local again = grug_visuals.npc_look(npc, "orc", function() error("rolled twice") end)
eq(grug_visuals.look_string(again), grug_visuals.look_string(first), "same look on the next draw")
-- The race decides only the reading, so an NPC placed before its settlement
-- was known keeps its seed when it is redrawn as the settlement's race.
eq(grug_visuals.look_string(grug_visuals.npc_look(npc, "troll")),
	grug_visuals.look_string(grug_visuals.look_from_seed("troll", 777)), "reread for another race")

-- NPC races: the settlement's, else one roll of the faction kept.
eq(grug_visuals.npc_race({_grug_start = "start_dwarf"}, "accord"), "dwarf", "settlement race")
eq(grug_visuals.npc_race({_grug_start = "capital_troll"}, "throng"), "troll", "capital race")
local outpost = {}
local race = grug_visuals.npc_race(outpost, "throng", {random = function(count) return count end})
eq(race, "undead", "faction roll")
eq(outpost._grug_visual_race, "undead", "faction roll kept")
eq(grug_visuals.npc_race(outpost, "throng", {random = function() error("rolled twice") end}),
	"undead", "faction roll not repeated")
-- Mixed garrisons (pvp-plan §6): a fortress guard in a settlement registered
-- under the seat race still rolls a race of its faction, by option or field.
local fortress = {_grug_start = "capital_troll"}
eq(grug_visuals.npc_race(fortress, "throng", {mixed = true,
	random = function() return 1 end}), "orc", "mixed: faction roll inside a settlement")
eq(grug_visuals.npc_race(fortress, "throng", {mixed = true,
	random = function() error("rolled twice") end}), "orc", "mixed: roll kept")
local flagged = {_grug_start = "capital_troll", _grug_mixed_race = true}
eq(grug_visuals.npc_race(flagged, "throng", {random = function() return 3 end}), "undead",
	"mixed by entity field")
eq(grug_visuals.npc_race({_grug_start = "capital_troll", _grug_visual_race = "orc"}, "throng"),
	"troll", "without mixed the settlement race wins over an early roll")

------------------------------------------------------------------------------
-- D. Layer order.
------------------------------------------------------------------------------
local HELM = "(grug_visuals_metal_head_steel.png)"
local CHEST = "(grug_visuals_metal_chest_steel.png)"
for _, race in ipairs(races) do
	local def = LOOKS[race]
	local attire, headwear = grug_visuals.royal_attire(race, true)
	for feature_index, feature in ipairs(def.features) do
		local look = grug_visuals.normalize_look(race, {feature = feature_index,
			style = 2, hair = 2, tone = 2, eyes = 2})
		local style = def.styles[2]
		local bare = grug_visuals.look_texture(race, look, {attire = attire, body = {CHEST}})
		local order = {
			position(bare, grug_visuals.SKIN_MASK .. "^[multiply:" .. def.tones[2]),
			position(bare, def.body),
			position(bare, def.eyes_mask .. "^[multiply:" .. def.eyes[2]),
			position(bare, style.mask .. "^[multiply:" .. def.hair[2]),
			position(bare, style.detail),
			position(bare, attire[1]),
			position(bare, CHEST),
			position(bare, feature.detail),
		}
		for index = 1, #order do
			check(order[index] > 0, race .. " " .. feature.id .. " layer " .. index ..
				" present")
			if index > 1 then
				check(order[index] > order[index - 1], race .. " " .. feature.id ..
					" layer " .. index .. " after " .. (index - 1))
			end
		end
		if feature.mask then
			local colour = feature.tint == "tone" and def.tones[2] or def.hair[2]
			local at = position(bare, feature.mask .. "^[multiply:" .. colour)
			check(at > order[7] and at < order[8], race .. " " .. feature.id ..
				" mask in its colour, before its detail")
		end

		local helmed = grug_visuals.look_texture(race, look,
			{body = {CHEST}, helmet = HELM, headwear = headwear})
		eq(position(helmed, style.mask), -1, race .. " helmet hides the hair mask")
		eq(position(helmed, style.detail), -1, race .. " helmet hides the hair")
		local window = position(helmed, "(" .. HELM .. "^[mask:" ..
			grug_visuals.HELMET_WINDOW .. ")")
		check(window > position(helmed, CHEST), race .. " helmet after body armour")
		check(position(helmed, headwear[1]) > window, race .. " headwear after the helmet")
		check(position(helmed, feature.detail) > position(helmed, headwear[1]),
			race .. " " .. feature.id .. " over helmet and headwear")
		check(position(helmed, def.eyes_mask) < window, race .. " eyes under the helmet")
	end
end

------------------------------------------------------------------------------
-- E. compose.
------------------------------------------------------------------------------
-- The armour index, as index_armor builds it from the item registry.
local items = {}
for bracket = 1, 6 do
	for rank, line in ipairs({"cloth", "leather", "metal"}) do
		for _, slot in ipairs(grug_visuals.SLOTS) do
			items["test:" .. line .. "_" .. slot .. "_" .. bracket] = {groups = {
				["grug_equip_" .. slot] = 1, grug_armor_class = rank}, _grug_bracket = bracket}
		end
	end
end
grug_visuals.index_armor(items)

local function top_level(textstring)
	local parts, depth, current = {}, 0, ""
	for ch in textstring:gmatch(".") do
		if ch == "(" then depth = depth + 1 elseif ch == ")" then depth = depth - 1 end
		if ch == "^" and depth == 0 then
			parts[#parts + 1] = current
			current = ""
		else
			current = current .. ch
		end
	end
	parts[#parts + 1] = current
	return parts
end

-- Silversteel (bracket 4): its hsl correction stays inside its piece.
for _, spec in ipairs({
	{race = "human", armor_line = "metal", bracket = 4},
	{skin = "grug_mobs_mirefolk.png", armor_line = "metal", bracket = 4},
	{race = "orc", armor = {head = "test:metal_head_4", chest = "test:metal_chest_4"},
		armor_broken = {chest = true}},
}) do
	local texture = grug_visuals.compose(spec).textures[1]
	check(has(texture, "[hsl:0:-90:5"), "silversteel correction present")
	for _, part in ipairs(top_level(texture)) do
		check(part:sub(1, 1) ~= "[", "no top-level modifier in " .. texture:sub(1, 60))
	end
end

-- The key moves with every input, and the same spec is the same entry.
local base = {race = "dwarf", look = {tone = 2, hair = 2, style = 2, eyes = 2, feature = 2},
	armor = {head = "test:metal_head_3", chest = "test:metal_chest_3"}, weapon = "w:sword"}
local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end
local reference = grug_visuals.compose(base)
check(grug_visuals.compose(copy(base)) == reference, "same spec, same cache entry")
local variants = {
	function(s) s.race = "elf" end,
	function(s) s.look.tone = 3 end,
	function(s) s.look.hair = 3 end,
	-- (a hairstyle under a helmet draws nothing: own key, same picture)
	function(s) s.look.style = 3; return "same" end,
	function(s) s.look.eyes = 3 end,
	function(s) s.look.feature = 3 end,
	function(s) s.royal = "guard" end,
	function(s) s.armor.chest = "test:metal_chest_4" end,
	function(s) s.armor_broken = {head = true} end,
	function(s) s.armor_layers = {chest = "(x_mask.png^[multiply:#123456)"} end,
	function(s) s.armor_layers = {head = "(x_mask.png^[multiply:#123456)"} end,
	-- (the weapon is the wield entity, not the skin)
	function(s) s.weapon = "w:axe"; return "same" end,
}
local keys = {[reference.key] = true}
for index, change in ipairs(variants) do
	local spec = copy(base)
	local same = change(spec) == "same"
	local result = grug_visuals.compose(spec)
	check(not keys[result.key], "variant " .. index .. " has its own key")
	check((result.textures[1] == reference.textures[1]) == same, "variant " .. index ..
		(same and " draws the same" or " draws differently"))
	keys[result.key] = true
end
-- A field the composition ignores shares the entry.
local ignored = copy(base)
ignored.colour_of_the_sky = "blue"
check(grug_visuals.compose(ignored) == reference, "ignored field shares the entry")
-- Missing look = option 1 everywhere, the same as an explicit one.
eq(grug_visuals.compose({race = "orc"}).key,
	grug_visuals.compose({race = "orc", look = {tone = 1, hair = 1, style = 1, eyes = 1,
		feature = 1}}).key, "no look is the first look")

-- Lane B's seam: inside the piece's parentheses, under the face window.
local layered = grug_visuals.compose({race = "human", armor = {head = "test:metal_head_2",
	chest = "test:metal_chest_2"}, armor_layers = {head = "(hA.png^[multiply:#aa0000)",
	chest = "(cA.png^[multiply:#00aa00)"}}).textures[1]
check(has(layered, "(grug_visuals_metal_chest_iron.png^(cA.png^[multiply:#00aa00))"),
	"chest layers inside the chest piece")
check(has(layered, "((grug_visuals_metal_head_iron.png^(hA.png^[multiply:#aa0000))^[mask:" ..
	grug_visuals.HELMET_WINDOW .. ")"), "helmet layers cut by the face window")
local broken = grug_visuals.compose({race = "human", armor = {chest = "test:metal_chest_2"},
	armor_broken = {chest = true}, armor_layers = {chest = "(cA.png)"}}).textures[1]
check(has(broken, "((grug_visuals_metal_chest_iron.png^(cA.png))" .. grug_gear.BROKEN_MODIFIER .. ")"),
	"a broken piece cracks with its layers")

-- Royal attire.
local king = grug_visuals.compose({race = "orc", look = grug_visuals.KING_LOOKS.orc,
	royal = "king"}).textures[1]
local royal_guard = grug_visuals.compose({race = "orc", royal = "guard"}).textures[1]
check(has(king, "grug_visuals_tabard_mask.png^[multiply:" .. grug_visuals.ROYAL.orc.cloth),
	"king's tabard in the royal colour")
check(has(king, "grug_visuals_crown.png"), "king's crown")
check(has(royal_guard, "grug_visuals_tabard_trim_mask.png^[multiply:" ..
	grug_visuals.ROYAL.orc.trim), "royal guard's tabard trim")
check(not has(royal_guard, "crown"), "a royal guard has no crown")

-- The explicit-skin path (mirefolk): its skin, its armour, no look layers.
local fish = grug_visuals.compose({skin = "grug_mobs_mirefolk.png"})
eq(fish.textures[1], "grug_mobs_mirefolk.png", "an explicit skin stays itself")
eq(fish.visual_size, nil, "an explicit skin has no stature")

-- Worst case: the longest overlays that exist in their longest runtime form
-- (Silversteel's hsl, broken), plus two tinted layers per piece for lane B.
local worst, worst_label = 0, ""
local function lane_b(slot)
	local out = {}
	for _, group in ipairs({"a", "b"}) do
		out[#out + 1] = "(grug_visuals_metal_" .. slot .. "_abyssal_steel_enchant_" ..
			group .. ".png^[multiply:#a0b0c0)"
	end
	return table.concat(out, "^")
end
for _, race_id in ipairs(races) do
	local def = LOOKS[race_id]
	for style = 1, #def.styles do
		for feature = 1, #def.features do
			for _, with_helmet in ipairs({false, true}) do
				local spec = {race = race_id, look = {style = style, feature = feature},
					armor = {chest = "test:metal_chest_4", legs = "test:metal_legs_4",
						feet = "test:metal_feet_4"},
					armor_broken = {head = true, chest = true, legs = true, feet = true},
					armor_layers = {head = lane_b("head"), chest = lane_b("chest"),
						legs = lane_b("legs"), feet = lane_b("feet")},
					royal = "guard"}
				if with_helmet then
					spec.armor.head = "test:metal_head_4"
				end
				local length = #grug_visuals.compose(spec).textures[1]
				if length > worst then
					worst, worst_label = length, race_id .. " " .. def.styles[style].id ..
						" " .. def.features[feature].id .. (with_helmet and " helmet" or "")
				end
			end
		end
	end
end
-- The engine serializes a texture with serializeString16 (65535 bytes);
-- "well inside" is read as below 4 KiB.
check(worst < 4096, "worst-case texture string " .. worst .. " below 4096")

------------------------------------------------------------------------------
-- F. Equal hitbox: player_api's model, then grug_visuals' apply, per race.
------------------------------------------------------------------------------
local function fake_player(name_text)
	local props = {}
	local meta = new_meta()
	local player = {}
	function player:get_player_name() return name_text end
	function player:is_player() return true end
	function player:set_properties(p) for k, v in pairs(p) do props[k] = v end end
	function player:get_properties() return props end
	function player:set_animation() end
	function player:set_local_animation() end
	function player:get_meta() return meta end
	function player:get_inventory() return nil end
	function player:get_wielded_item() return {get_name = function() return "" end} end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	return player, props
end
local boxes = {}
for _, race_id in ipairs(races) do
	local player, props = fake_player("p_" .. race_id)
	race_of[player] = race_id
	for _, fn in ipairs(callbacks.join) do
		fn(player)
	end
	grug_visuals.apply(player)
	local box = props.collisionbox
	check(box ~= nil, race_id .. " has a collision box")
	boxes[race_id] = {
		collision = table.concat(box or {}, ","),
		selection = table.concat(props.selectionbox or {"engine default"}, ","),
		eye = tostring(props.eye_height),
		size = props.visual_size and props.visual_size.x,
	}
	eq(props.visual_size and props.visual_size.x, grug_visuals.RACES[race_id].stature,
		race_id .. " visual size is its stature")
end
for _, race_id in ipairs(races) do
	eq(boxes[race_id].collision, boxes.human.collision, race_id .. " collision box")
	eq(boxes[race_id].selection, boxes.human.selection, race_id .. " selection box")
	eq(boxes[race_id].eye, boxes.human.eye, race_id .. " eye height")
end
eq(boxes.human.collision, "-0.3,0,-0.3,0.3,1.7,0.3", "the player_api box")
check(boxes.dwarf.size ~= boxes.troll.size, "statures still differ")

------------------------------------------------------------------------------
-- G. The stored look.
------------------------------------------------------------------------------
local player = fake_player("creator")
race_of[player] = "elf"
for _, fn in ipairs(callbacks.join) do
	fn(player)
end
check(not grug_visuals.has_look(player), "a new character has no look")
eq(grug_visuals.get_look(player), nil, "no look to read")
check(grug_visuals.set_look(player, {tone = 3, hair = 4, style = 2, eyes = 3, feature = 3}),
	"the look is stored")
check(grug_visuals.has_look(player), "the look is there")
eq(grug_visuals.look_string(grug_visuals.player_spec(player).look), "3,4,2,3,3",
	"player_spec carries the stored look")
check(not grug_visuals.set_look(player, {tone = 1}), "a stored look cannot be replaced")
eq(grug_visuals.look_string(grug_visuals.get_look(player)), "3,4,2,3,3", "unchanged")

if failures > 0 then
	error("R31 A PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
end
print("R31 A PORTABLE PASS checks=" .. checks .. " worst=" .. worst ..
	" (" .. worst_label .. ")")
