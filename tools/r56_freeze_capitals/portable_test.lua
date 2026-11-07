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
-- capital's new digests again; each capital lane pins its own.
local FROZEN = {
	highcourt = {"abc75504ededff37c18f83c9f09e195e1d4b3e42164d315ebc22d1149f2c5c1b",
		"61eddb6f823916828b970d9b4dd740fdf7409e499881d4be560847c5cfe93ede",
		"92b576f2f09cc0252a3ae862784c163741b6305ac6421705ccf44d8cb43eb8f7"},
	-- the next capital
	dur_brannoc = {"846961cd7a6edc906185fb59f4d42da986abd75fe4c3e4a650299a2f8c48ba9f",
		"8d7ea2686c9ffac290086a5cc2b844ff108960af9f45b7012c809963f5baed6d",
		"bd63e88dcc8a3b344280e38e85d629f12f9a8a852a7fa7f1d23df5f33ea4dc6c"},
	-- the next capital
	lethariel = {"82d73eb49f11a0be54aadf6b02f98f56e658f5e7b8e439f54e3f5abb3528df92",
		"f6a1923cb52937f56adb31155398541c6b15b9c4749e14c4fff88520ce02d804",
		"a3e6e753511323c48c37dd2e759dde7c0e627c44c9dad82d35876d3cec557e12"},
	-- the next capital
	nhal_veyr = {"919d95a0ca0e21241e1139c71f44d782194850d4493bafc82a87f1f461c44869",
		"a1e918e7a39b3b24a48df3cb2cb8b9433f1bf5f9fd37efec34546addaf98b7ac",
		"5570ef4f3363ce0f940982b4dec1be3788425a35b89bc7e9460af0b563b2fb47"},
	-- the next capital
	gor_drazhak = {"bc6f2a5f4d8a2673d06b11118723d007f9a6de523744587fc5feafe4c7647012",
		"8ac478378008b993136310b70913d2d20f540e6a37918ca8b659e01ca4b59a92",
		"6738a820ba3af1c2cc215305fc6a8133deac881e16bfc428e5c01479a11251f4"},
	-- the next capital
	kezamba = {"711b3aaaca00cc47dbb1f484ebfa5ed76913be94214d71617a989d13e22cacf9",
		"9eff6c643c2f7091b047d114c04a35b018b7828c937af5279babf78be8b06b0e",
		"d58bb720021dd365fadd24490770e3d46e3250b1917e9e45a141c8a2193ba504"},
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
