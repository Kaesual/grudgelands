-- Round 56 lane FREEZE-CAPITALS portable test (building-template-format.md):
--   A. every capital's roster loads through the game's loader
--      (`templates.capital`), with every template it lists, and every
--      capital template carries the measurements the plot builders read
--      (`extent`, `top`, format doc §4.1);
--   B. a capital places only what its roster lists: a template or palette
--      combination the roster lacks, a missing roof palette and a roster
--      line whose channels differ from the template's are refused, and a
--      malformed roster stops at load with its file and line;
--   C. the stamped town points: a socket point without a role is the
--      position of a town entry, recorded with its building; another
--      building's point, a point stamped twice and a point no entry takes are
--      refused;
--   D. THE FREEZE: every capital builds the identity, point and build digests
--      it built from the building generators before the freeze (pinned), and
--      places each template and palette combination exactly as often as its
--      roster says.
--
-- Usage (repo root): luajit tools/r56_freeze_capitals/portable_test.lua [REPO]
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local templates = dofile(wp13 .. "/templates.lua")(wp13)
local CAPITALS = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak",
	"kezamba"}

-- A. every roster and its templates ---------------------------------------------
local listed, measured = 0, 0
for _, key in ipairs(CAPITALS) do
	local capital = templates.capital(key)
	check(capital.id == key and capital.palettes.town ~= nil, key .. " loads")
	for _, use in ipairs(capital.roster.uses) do
		local t = capital.templates[use.template]
		listed = listed + 1
		if type(t.meta.extent) == "table" and #t.meta.extent == 4 and
				type(t.meta.top) == "number" then
			measured = measured + 1
		end
	end
end
check(listed > 200 and measured == listed, "every use names a measured template (" ..
	measured .. " of " .. listed .. ")")

-- B. what the roster allows -----------------------------------------------------
local highcourt = templates.capital("highcourt")
local part = highcourt.part("highcourt_chapel", "chapel", "town", "white_slate")
check(part.peak == 10 and part.extent[3] == 11 and part.top == 12, "a part carries its meta")
check(highcourt.used["highcourt_chapel roof=white_slate"] == 1, "the use is counted")
check(not pcall(highcourt.part, "highcourt_chapel", "chapel", "white", "white_slate"),
	"a palette combination the roster lacks is refused")
check(not pcall(highcourt.part, "highcourt_chapel", "chapel", "town"),
	"a template with a roof channel needs its roof palette")
check(not pcall(highcourt.part, "no_such_template", "x", "town"),
	"a template the roster does not list is refused")
local ROSTER = table.concat({templates.ROSTER_MAGIC, "town x", "race human",
	"palette slate race=human roof_slab=stairs:slab_stone",
	"use highcourt_chapel count=1 roof=slate", ""}, "\n")
local roster = templates.parse_layout(ROSTER, "x.roster", true)
check(roster.uses[1].count == 1 and roster.uses[1].key == "highcourt_chapel roof=slate",
	"a roster parses")
local function refused(text, wanted_line, label)
	local ok, err = pcall(templates.parse_layout, text, "x.roster", true)
	check(not ok and tostring(err):find("^x%.roster:" .. wanted_line .. ": ") ~= nil,
		label .. " is refused with its line: " .. tostring(err))
end
refused(ROSTER:gsub("count=1", "count=0"), 5, "a count below one")
refused(ROSTER:gsub("roof=slate", "roof=tile"), 5, "a palette the roster does not define")
refused(ROSTER:gsub("count=1 roof", "count=1 x=3 roof"), 5, "a placement field")
refused(ROSTER .. "use highcourt_chapel count=2 roof=slate\n", 6, "a use given twice")
refused(ROSTER:gsub("town%-roster 1", "town-roster 2"), 1, "another version")
refused(ROSTER:gsub("use highcourt", "place highcourt"), 5, "a layout's place line")

-- C. the stamped town points ----------------------------------------------------
local stamped = templates.collect_sockets({}, {sockets = {
	{id = "own", role = "quest", x = 1, y = 1, z = 1, face = 0},
	{id = "town_entry", x = 2, y = 1, z = 3, face = 1}}}, "chapel")
check(stamped.own == nil and stamped.town_entry.building == "chapel",
	"only a point without a role is a town entry's position")
check(not pcall(templates.collect_sockets, stamped, {sockets = {{id = "town_entry",
	x = 0, y = 0, z = 0, face = 0}}}, "hall"), "a point stamped twice is refused")
check(not pcall(templates.stamped_point, stamped, "town_entry", "hall", "x"),
	"another building's point is refused")
check(not pcall(templates.all_used, stamped, "x"), "a point no entry takes is refused")
local spot = templates.stamped_point(stamped, "town_entry", "chapel", "x")
check(spot.x == 2 and spot.face == 1 and pcall(templates.all_used, stamped, "x"),
	"a point its entry takes")

-- D. the freeze -------------------------------------------------------------------
-- The identity, point and build digests of each capital as the building
-- generators built it at 36698232 (tools/building_templates/town_identity.lua);
-- since Round 58 (TOWNFIX, a declared map reset: the five core gatehouses,
-- Lethariel's bough platforms, the throne guards' posts, the gate watch) with
-- the Miner's Guild house of lane HALLS, moved out of the core onto a
-- district plot of its own by lane HALLS2 (the core's replaced building
-- back), the capitals' new values; since Round 59 (STORYQUESTS, chapter 1's
-- six town places: one quest_place socket in a service plot of each capital,
-- the identities unchanged) the new point and build digests; since Round 60
-- (CAPITALS, chapter 2's public register: one quest_place socket in Nhal
-- Veyr's Miner's Guild plot, its cells and identity unchanged) Nhal Veyr's
-- new point and build digests; since Round 62 (TEMPLATEFIX, a declared map
-- reset: the moot house's door gets its upper cell, the mere shrines' inside
-- point stands on the floor) Kezamba's new identity and build digests and
-- Lethariel's new point and build digests (its district shrine's destination);
-- since Round 70 (GUILD, a declared map reset: the Stonewright's work bay in
-- the six guild houses) every capital's new digests; since Round 70 CAP0 (a
-- declared map reset: the core's radius 56, Dur Brannoc's castle) every
-- capital's new digests again; each capital lane pins its own; since 0.73.1 (a
-- declared map reset: royal halls, gate arches, thin tables, the Registrar's own
-- core socket) every capital's new digests again.
-- Round 75: declared map reset; restrained city dressing changes cell identities.
-- Source blueprints and their point/build digests stay unchanged.
-- 0.75.1: declared map reset (unreleased 0.75.0 already resets): the slab over
-- every workshop workbench and the human closed shutters are gone; the human
-- palette's shutter node leaves the node list, so Dawnmere's and Highcourt's
-- point digests move too.
-- 0.75.2: declared map reset; richer authored city decor changes only identities.
-- 0.75.3: declared map reset; the Expedition Registrar's socket moves to the
-- great hall door, so every capital's point and build digests move.
local FROZEN = {
	highcourt = {"932da00d04f22b23b8067f10bc201c21dcfd92000b99d90b715f85336b47ca5d",
		"c23077576987fa6f6aa5a2a00d1bffeb9278d40667b461023e9e114d107b6540",
		"f73492aefae6914427a725dd2c25a6438ff9c688bcf16e5c254636d22c9f7097"},
	-- the next capital
	dur_brannoc = {"4a5b13758b4270e4451647caaf57bc357fc5da10d8be85aca221d360f2d2bfa2",
		"e9bfaf8fb9181bff72fff6351b54d798513038b07042a225ff2f132e69e44a47",
		"36056b75e661cc9fa698dae8fb974611fd85f8d3df4119a49a3499f6bcae14ae"},
	-- the next capital
	lethariel = {"f440bc14f22bd26487ba0cfd8abcb1e5c09ebd9724242584401ccfa051e584de",
		"3c541fb7ebc542e65a1ac8a05af2c28fd26d9f2baef442826a8b116246cb3a9b",
		"ab83735460b6dfedeaac9a11f45dde4289bd4a5769e5b1f33f09c6df8e12e820"},
	-- the next capital
	nhal_veyr = {"cbc495832932c5a4aca4930e8ef6bc57a46ea3c261d9ff60a57e1bd54271e39b",
		"0bdc88e0aa2038d0dfc6502eecad91e3450fb9493d3fab6e21e8540ff951e200",
		"aebf68cb8411f3c69b155104bdfcb71ce464f59e4ba0b353ab8b72ddb110ef7a"},
	-- the next capital
	gor_drazhak = {"1a7681b36f815794d70204a650c943caacf352bd2b3c534433aca6315f9106b7",
		"0cee1c24bbe58065671cfc391598a3ebab867c051c8884716efeb3ca1e3868f8",
		"75431541e1379a100c0582532f8eab54ccbb628b3650246d60cd04a1a0dcd361"},
	-- the next capital
	kezamba = {"41786321777b1f16151a32bd92b8fd06bcbc28d4e9e953c57202230f2b099aab",
		"65fa89d788163afa67babeaee93af54a8f5b41aa9c331663a8f498d7f01d2263",
		"c39b5fec19c51ad999a8b105e81afc5ace07a9881dae02ef2075e5ae6713f6a8"},
}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local function canonical(value, out)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			canonical(key, out)
			out[#out + 1] = "="
			canonical(value[key], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	elseif kind == "number" then
		out[#out + 1] = string.format("n%.17g", value)
	elseif kind == "string" then
		out[#out + 1] = string.format("%q", value)
	else
		out[#out + 1] = value and "T" or "F"
	end
	return out
end
local function digest(text) return common.hex(sha(text)) end

-- Every capital the game's loader makes is remembered, to count its uses.
local made = {}
local saved_dofile = dofile
_G.dofile = function(path)
	local chunk = saved_dofile(path)
	if path:match("/templates%.lua$") then
		return function(directory)
			local loader = chunk(directory)
			local capital = loader.capital
			loader.capital = function(id)
				local one = capital(id)
				made[id] = made[id] or {}
				table.insert(made[id], one)
				return one
			end
			return loader
		end
	end
	return chunk
end
-- the buildings of each core and its district plots (Nhal Veyr's ruin close
-- stamps two of its own; Round 58 HALLS2: one more each, the guild house's
-- district plot)
local PLACEMENTS = {highcourt = 59, dur_brannoc = 55, lethariel = 49, nhal_veyr = 62,
	gor_drazhak = 49, kezamba = 49}
local profiles = {}
for _, profile in ipairs(settlement.roster) do profiles[profile.key] = profile end
local capital_source = dofile(wp40 .. "/r7_capital_blueprint.lua")
for _, key in ipairs(CAPITALS) do
	local kit = capital_source.kit(key)
	local identities, points, builds = {}, {}, {}
	local function add(id, schema, blueprint, first)
		local prepared
		if first then
			prepared = settlement.prepare(profiles[key], blueprint, sha).blueprints[1]
		else
			prepared = settlement.prepare_plot(profiles[key], {id = id, schema = schema,
				build = function() return blueprint end}, sha)
		end
		local rest = {}
		for field, value in pairs(blueprint) do
			if field ~= "cells" then rest[field] = value end
		end
		identities[#identities + 1] = id .. ":" .. prepared.identity.sha256
		points[#points + 1] = id .. ":" .. digest(table.concat(canonical(rest, {})))
		builds[#builds + 1] = id .. ":" .. digest(table.concat(canonical(blueprint, {})))
	end
	add("core", kit.core.schema, kit.core.build(), true)
	for _, plot in ipairs(kit.plots) do add(plot.id, plot.schema, plot.build()) end
	local frozen = FROZEN[key]
	check(digest(table.concat(identities, "\n")) == frozen[1],
		key .. ": the settlement identities are the frozen ones")
	check(digest(table.concat(points, "\n")) == frozen[2],
		key .. ": the point digest is the frozen one")
	check(digest(table.concat(builds, "\n")) == frozen[3],
		key .. ": the build digest is the frozen one")
	-- the roster's counts against the build
	local counts = {}
	for _, one in ipairs(made[key] or {}) do
		for use, count in pairs(one.used) do counts[use] = (counts[use] or 0) + count end
	end
	local roster_uses = templates.capital(key).roster.uses
	local total = 0
	for _, use in ipairs(roster_uses) do
		check(counts[use.key] == use.count, key .. ": " .. use.key .. " placed " ..
			tostring(counts[use.key]) .. " times, the roster says " .. use.count)
		counts[use.key] = nil
		total = total + use.count
	end
	check(next(counts) == nil, key .. ": the capital places nothing its roster lacks")
	check(total == PLACEMENTS[key], key .. ": " .. total .. " placements, not " ..
		PLACEMENTS[key])
end

print("r56_freeze_capitals portable test: PASS (" .. checks .. " checks)")
