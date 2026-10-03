-- Round 31 Lane A portable test (LuaJIT): character look layers, stage 1
-- (round31-plan.md §2.1).
--
--   luajit tools/r31_a/portable_test.lua [REPO]
--
-- Loads the REAL mods/PLAYER/grug_visuals/looks.lua against a stub table:
--   A. the option counts per race are the plan's table (§2.1.2);
--   B. every texture a look can name exists and has its LICENSE-media row,
--      and every licensed look layer is named by some look;
--   C. normalize_look: missing, fractional or out-of-range entries become 1,
--      valid ones stay; roll_look stays in range and reaches every option;
--   D. layer order (§2.1.3): skin -> eyes -> hairstyle -> body armour ->
--      helmet with the face window -> lower-face feature; a helmet drops the
--      hairstyle;
--   E. the worst-case string length, with every helmet and body overlay in
--      its longest form (Silversteel hsl, broken crack) plus two tinted mask
--      layers per armour piece as room for lane B's enchant colours.
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

grug_visuals = {}
dofile(ROOT .. "/mods/PLAYER/grug_visuals/looks.lua")
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
	for category, count in pairs(counts) do
		eq(#LOOKS[race].options[category], count, race .. " " .. category .. " count")
	end
	for _, colour in ipairs(LOOKS[race].tones) do
		check(colour:match("^#%x%x%x%x%x%x$") ~= nil, race .. " tone " .. colour)
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
name(grug_visuals.SKIN_MASK)
name(grug_visuals.HELMET_WINDOW)
for _, race in ipairs(races) do
	local def = LOOKS[race]
	name(def.body)
	name(def.eyes_mask)
	for _, files in ipairs(def.style_files) do
		name(files.mask)
		name(files.detail)
	end
	for _, feature in ipairs(def.features) do
		name(feature.detail)
		check((feature.mask ~= nil) == (feature.tint ~= nil),
			race .. " " .. feature.id .. ": a mask exactly when tinted")
		if feature.mask then
			name(feature.mask)
		end
		check(feature.tint == nil or feature.tint == "hair" or feature.tint == "tone",
			race .. " " .. feature.id .. " tint")
	end
end
-- Every look layer the licence table lists belongs to some look, and every
-- file a look names has its licence row.
local license = io.open(ROOT .. "/mods/PLAYER/grug_visuals/LICENSE-media.md"):read("*a")
local rows = {}
for file in license:gmatch("\n| `(grug_visuals_[%w_]+%.png)` |") do
	rows[file] = true
	local race = file:match("^grug_visuals_(%l+)_body%.png$") or
		file:match("^grug_visuals_(%l+)_hair_") or
		file:match("^grug_visuals_(%l+)_feature_")
	if race or file:match("_mask%.png$") or file == grug_visuals.HELMET_WINDOW then
		check(named[file] == true, "licensed layer file named by looks.lua: " .. file)
	end
end
for file in pairs(named) do
	check(rows[file] == true, "LICENSE-media row for " .. file)
end

------------------------------------------------------------------------------
-- C. normalize and roll.
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

math.randomseed(31)
for _, race in ipairs(races) do
	local seen = {}
	for _ = 1, 400 do
		local look = grug_visuals.roll_look(race)
		local again = grug_visuals.normalize_look(race, look)
		for _, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
			check(again[category] == look[category], race .. " roll in range")
			seen[category .. look[category]] = true
		end
	end
	for _, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		for index = 1, #LOOKS[race].options[category] do
			check(seen[category .. index], race .. " roll reaches " .. category ..
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

------------------------------------------------------------------------------
-- D. Layer order.
------------------------------------------------------------------------------
local function position(text, needle)
	local at = text:find(needle, 1, true)
	return at or -1
end
local HELM = "grug_visuals_metal_head_steel.png"
local CHEST = "grug_visuals_metal_chest_steel.png"
for _, race in ipairs(races) do
	local def = LOOKS[race]
	for feature_index, feature in ipairs(def.features) do
		local look = grug_visuals.normalize_look(race, {feature = feature_index,
			style = 2, hair = 2, tone = 2, eyes = 2})
		local hair = def.style_files[2]
		local bare = grug_visuals.look_texture(race, look, {CHEST})
		local order = {
			position(bare, grug_visuals.SKIN_MASK .. "^[multiply:" .. def.tones[2]),
			position(bare, def.body),
			position(bare, def.eyes_mask .. "^[multiply:" .. def.eyes[2]),
			position(bare, hair.mask .. "^[multiply:" .. def.hair[2]),
			position(bare, hair.detail),
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
			check(at > order[6] and at < order[7], race .. " " .. feature.id ..
				" mask in its colour, before its detail")
		end

		local helmed = grug_visuals.look_texture(race, look, {CHEST}, HELM)
		eq(position(helmed, hair.mask), -1, race .. " helmet hides the hair mask")
		eq(position(helmed, hair.detail), -1, race .. " helmet hides the hair")
		local window = position(helmed, "(" .. HELM .. "^[mask:" ..
			grug_visuals.HELMET_WINDOW .. ")")
		check(window > position(helmed, CHEST), race .. " helmet after body armour")
		check(position(helmed, feature.detail) > window, race .. " " .. feature.id ..
			" over the helmet")
		check(position(helmed, def.eyes_mask) < window, race .. " eyes under the helmet")
	end
end

------------------------------------------------------------------------------
-- E. Worst-case length.
------------------------------------------------------------------------------
-- The longest overlay names that exist, in their longest runtime form:
-- Silversteel's hsl correction inside grug_gear.broken_image's crack wrapper,
-- plus two tinted mask layers per piece for lane B (names made up, as long
-- as their likely real ones).
local function longest(slot)
	local base = "grug_visuals_metal_" .. slot .. "_abyssal_steel.png^[hsl:0:-90:5"
	local enchant = ""
	for _, group in ipairs({"a", "b"}) do
		enchant = enchant .. "^(grug_visuals_metal_" .. slot .. "_abyssal_steel_enchant_" ..
			group .. ".png^[multiply:#a0b0c0)"
	end
	return "((" .. base .. ")^[cracko:1:4" .. enchant .. ")"
end
local worst, worst_label = 0, ""
local body = {longest("chest"), longest("legs"), longest("feet")}
for _, race in ipairs(races) do
	local def = LOOKS[race]
	for style = 1, #def.styles do
		for feature = 1, #def.features do
			local look = grug_visuals.normalize_look(race, {style = style,
				feature = feature})
			for _, helmet in ipairs({false, true}) do
				local text = grug_visuals.look_texture(race, look, body,
					helmet and longest("head") or nil)
				if #text > worst then
					worst, worst_label = #text, race .. " " .. def.styles[style] ..
						" " .. def.features[feature].id .. (helmet and " helmet" or "")
				end
			end
		end
	end
end
-- The engine serializes a texture with serializeString16 (65535 bytes);
-- "well inside" is read as below 4 KiB.
check(worst < 4096, "worst-case texture string " .. worst .. " below 4096")

if failures > 0 then
	error("R31 A PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
end
print("R31 A PORTABLE PASS checks=" .. checks .. " worst=" .. worst ..
	" (" .. worst_label .. ")")
