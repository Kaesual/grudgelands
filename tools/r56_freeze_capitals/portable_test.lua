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
-- re-pinned in Round 58 (lane HALLS) for the Miner's Guild house in every
-- civic core, the declared map reset of 0.58.0.
local FROZEN = {
	highcourt = {"8ad7d50b51d595e6b8f65e062364344e3845c8df8f62c501cf79883b22e9ab26",
		"ec4578038df134a62b69b5fd9115f1bd19d1633d2c54f20a092707acf72acb57",
		"61f8170e8ee7c99fda9306f025ba3d8314ce094e2a63837ef2640fb5ccc6eb2a"},
	dur_brannoc = {"4111d0ccc0e8173211454e74755a1614fb4b93e18a4bccef99de38d13dcc3bcc",
		"383737fcbd8e68612516b0548856dd00723f78749110b6dbb31681d1638ad1c3",
		"2da150159db26810c6f6ad2244be88bfeb87e020bb4463ecab347babfcd63dcf"},
	lethariel = {"d9aa7d6fd11beb580d70d5417ffbe76c4cbdf8c6446ad0c807012d2ea1198504",
		"4a82266b9a09df063b06b14dee76d60412be934fa55660dd3806277ab381c726",
		"b530dbd31831b425bbe09241149fab67dcfcc66da017577866f741fe438653fe"},
	nhal_veyr = {"212f1a1f95cf7e8e51e1512547bd413f8faea5fd4250cae983db7f241b809f53",
		"0318e5c46549ad97d40d03781e61d14e460df3e211f45d19434e26d25e81b893",
		"ccb2ae2b3462d85e2dda9fa70c72ba5118f49aa08b166503277268c385d5fa5b"},
	gor_drazhak = {"ab30f47f7893ff767d716552419f8b0afe0a10b7bbaa7caec834d6e50246a836",
		"076a1fd897c790862926a0e9b8ea3a266f0fc2fa52b01dd269a5a8c2beacac5b",
		"9dac237d625f37cb96764e8a1fa7817d621a6adb651d0f93489b05f51bf4a6be"},
	kezamba = {"84d57ba31eaf33d519b9038ab863c45e6dcecf7c36df3ddf100b28cfcd9306db",
		"064bce2cc904f445964cd72961de89a8f5ac1cb1f72fe9bf4541a20cf05bf28a",
		"d0e82e2ee7e014471c054a3f3d0927de2b5f70cad88d7258ee38db71018dc036"},
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
-- stamps two of its own)
local PLACEMENTS = {highcourt = 58, dur_brannoc = 54, lethariel = 48, nhal_veyr = 61,
	gor_drazhak = 48, kezamba = 48}
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
