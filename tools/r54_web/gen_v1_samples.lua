-- Round 54 lane WEB: version 1 appearance samples for tools/r54_web's fixture
-- and the kaesual handoff (tools/web_data/README.md, "Version 1 appearances").
--
-- A character who has not joined since 0.54.0 keeps a version 1 appearance
-- in player meta: one body texture with the old armour overlays in it. The
-- game that wrote those strings is gone from the tree, so this generator runs
-- the OLD game (an extracted tree of 0.53.1, main d18840a6) through the old
-- export loader and writes what its composition produced: bodies for every
-- race (bare, two looks), every line and grade as a full enchanted set with a
-- helmet (every old overlay file and every old mask named at least once),
-- sets without a helmet, broken pieces, mixed lines, and two whole values.
--
--   OLD=$(mktemp -d)
--   git archive d18840a6 mods | tar -x -C "$OLD"
--   git archive d18840a6 tools/web_data | tar -x -C "$OLD"
--   luajit tools/r54_web/gen_v1_samples.lua "$OLD"            # rewrite
--   luajit tools/r54_web/gen_v1_samples.lua "$OLD" --check    # exit 1 if stale
--
-- Output: tools/r54_web/v1_samples.lua (a Lua data file: `return {...}`).

local OLD, mode = nil, "write"
for _, value in ipairs(arg or {}) do
	if value == "--check" then mode = "check" else OLD = value end
end
assert(OLD, "usage: luajit tools/r54_web/gen_v1_samples.lua OLD_TREE [--check]")
local HERE = (arg[0]:match("^(.*)/[^/]*$") or ".")
local TARGET = HERE .. "/v1_samples.lua"

local web_data = dofile(OLD .. "/tools/web_data/build.lua")
web_data.build(OLD) -- loads the old game into the globals
local gv = grug_visuals
assert(gv.APPEARANCE_VERSION == 1, "gen_v1_samples: OLD is not a version 1 tree")
assert(gv.OVERLAY, "gen_v1_samples: OLD has no armour overlays")
gv.index_armor(core.registered_items)

local LINES = {"cloth", "leather", "metal"}
local SLOTS = gv.SLOTS
local RACES = {"human", "dwarf", "elf", "orc", "troll", "undead"}
local STATS = grug_gear.ENCHANT_ORDER

-- Look number `n` of a race: option ((n + category) mod count) + 1, so the
-- samples walk through every option of every category.
local function look_of(race, n)
	local look = {}
	for index, category in ipairs(gv.LOOK_CATEGORIES) do
		local count = #gv.LOOKS[race].options[category]
		look[category] = (n + index) % count + 1
	end
	return look
end

local function max_look(race)
	local look = {}
	for _, category in ipairs(gv.LOOK_CATEGORIES) do
		look[category] = #gv.LOOKS[race].options[category]
	end
	return look
end

local function item(slot, line, bracket)
	return "grug_gear:" .. slot .. "_" .. line .. "_" .. grug_gear.MATERIALS[bracket][line].key
end

local samples = {}

-- One body as the old apply composed it: `pieces[slot] = {line, bracket,
-- prefix, suffix, broken}`.
local function add(label, race, look, pieces)
	local armor, worn, broken = {}, {}, {}
	local helmet = false
	for _, slot in ipairs(SLOTS) do
		local piece = pieces[slot]
		if piece then
			local name = item(slot, piece.line, piece.bracket)
			assert(gv.armor_appearance[name], "gen_v1_samples: unknown item " .. name)
			armor[slot] = name
			local affixes = {}
			if piece.prefix then affixes[#affixes + 1] = {channel = "prefix", stat = piece.prefix} end
			if piece.suffix then affixes[#affixes + 1] = {channel = "suffix", stat = piece.suffix} end
			worn[slot] = {name = name, affixes = affixes}
			broken[slot] = piece.broken == true
			helmet = helmet or slot == "head"
		end
	end
	local result = gv.compose({race = race, look = look, armor = armor,
		armor_broken = broken, armor_layers = gv.armor_layers(worn)})
	samples[#samples + 1] = {label = label, race = race, look = gv.normalize_look(race, look),
		helmet = helmet, body = result.textures[1]}
end

local function set(line, bracket, extra)
	local pieces = {}
	for index, slot in ipairs(SLOTS) do
		local piece = {line = line, bracket = bracket}
		for key, value in pairs(extra and extra(index, slot) or {}) do piece[key] = value end
		pieces[slot] = piece
	end
	return pieces
end

-- Every race bare (two looks) and under a broken, enchanted top-tier helmet set.
for index, race in ipairs(RACES) do
	add(race .. " bare, look 1", race, nil, {})
	add(race .. " bare, last options", race, max_look(race), {})
	add(race .. " metal T6, enchanted, chest broken", race, max_look(race),
		set("metal", 6, function(_, slot)
			return {prefix = STATS[index], suffix = STATS[10 - index], broken = slot == "chest"}
		end))
end

-- Every line and grade: a full set with a helmet, every piece enchanted
-- (prefix, suffix or both), so every overlay and every mask is named.
local n = 0
for _, line in ipairs(LINES) do
	for bracket = 1, #grug_gear.MATERIALS do
		n = n + 1
		local race = RACES[n % #RACES + 1]
		add(line .. " T" .. bracket .. ", full set, enchanted", race, look_of(race, n),
			set(line, bracket, function(index)
				return {prefix = index ~= 4 and STATS[(n + index) % #STATS + 1] or nil,
					suffix = index ~= 3 and STATS[(n + 2 * index) % #STATS + 1] or nil,
					broken = (n + index) % 5 == 0}
			end))
	end
end

-- Without a helmet (the hair stays), plain, and mixed lines.
for index, line in ipairs(LINES) do
	local pieces = set(line, 2 * index)
	pieces.head = nil
	add(line .. " T" .. 2 * index .. " without a helmet, plain", RACES[index + 3],
		look_of(RACES[index + 3], index), pieces)
end
add("mixed: cloth helmet, leather chest broken, metal legs, no feet", "dwarf", look_of("dwarf", 7), {
	head = {line = "cloth", bracket = 5, suffix = "int"},
	chest = {line = "leather", bracket = 4, prefix = "dex", broken = true},
	legs = {line = "metal", bracket = 1},
})
add("mixed: only boots", "elf", look_of("elf", 3), {feet = {line = "leather", bracket = 6}})

-- Two whole stored values, as the old apply wrote them.
local function value(sample, slots, cloak_id, cloak)
	local size = gv.RACES[sample.race].size
	return gv.appearance_json({v = 1, race = sample.race, look = sample.look,
		cloak = cloak_id, visual_size = {x = size.x, y = size.y, z = size.z},
		textures = {body = sample.body, cloak = cloak}, slots = slots})
end
local function sample_of(label)
	for _, s in ipairs(samples) do
		if s.label == label then return s end
	end
	error("gen_v1_samples: no sample " .. label)
end
local values = {
	{label = "dwarf bare, look 1", json = value(sample_of("dwarf bare, look 1"), {}, "none", "none")},
}
do
	local sample = sample_of("human metal T6, enchanted, chest broken")
	local slots = {}
	for _, slot in ipairs(SLOTS) do
		slots[slot] = {item = item(slot, "metal", 6), broken = slot == "chest",
			enchant = {STATS[1], STATS[9]}}
	end
	slots.mainhand = {item = "grug_gear:sword_abyssal_steel", broken = false, enchant = {},
		pose = "edge_down", image = "grug_gear_item_sword_abyssal_steel.png"}
	values[2] = {label = sample.label .. ", a sword", json = value(sample, slots,
		"hunter_2", "grug_achievements_cloak_hunter_2.png")}
end

-- The Lua data file.
local function quote(text)
	return ("%q"):format(text):gsub("\\\n", "\\n")
end
local out = {"-- Generated by tools/r54_web/gen_v1_samples.lua from main d18840a6 (0.53.1,",
	"-- appearance version 1); do not edit. " .. #samples .. " bodies, " .. #values .. " values.",
	"return {", "\tsamples = {"}
for _, s in ipairs(samples) do
	local look = {}
	for _, category in ipairs(gv.LOOK_CATEGORIES) do
		look[#look + 1] = category .. " = " .. s.look[category]
	end
	out[#out + 1] = ("\t\t{label = %s, race = %s, look = {%s}, helmet = %s,\n\t\t\tbody = %s},"):format(
		quote(s.label), quote(s.race), table.concat(look, ", "), tostring(s.helmet), quote(s.body))
end
out[#out + 1] = "\t},"
out[#out + 1] = "\tvalues = {"
for _, v in ipairs(values) do
	out[#out + 1] = ("\t\t{label = %s,\n\t\t\tjson = %s},"):format(quote(v.label), quote(v.json))
end
out[#out + 1] = "\t},"
out[#out + 1] = "}"
local text = table.concat(out, "\n") .. "\n"

if mode == "check" then
	local handle = io.open(TARGET, "rb")
	local committed = handle and handle:read("*a")
	if handle then handle:close() end
	if committed ~= text then
		print("gen_v1_samples: " .. TARGET .. " is stale, re-run without --check")
		os.exit(1)
	end
	print("gen_v1_samples: up to date (" .. #samples .. " bodies)")
	return
end
local handle = assert(io.open(TARGET, "wb"))
handle:write(text)
handle:close()
print("gen_v1_samples: wrote " .. TARGET .. " (" .. #samples .. " bodies, " .. #text .. " bytes)")
