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
	highcourt = {"e49f60ac20d3576323f19cbc9ef6171688d7be9f2c3dc898de4981d82f0ec679",
		"ec4578038df134a62b69b5fd9115f1bd19d1633d2c54f20a092707acf72acb57",
		"422658ce294873d1d8cb594fee8ac684ed572970c6b1f1fd6e6aa2cd69b1d30f"},
	dur_brannoc = {"689143903c3cc326495b0ac5a5896efe734b031551fdc1e5dda4349cb29012e7",
		"383737fcbd8e68612516b0548856dd00723f78749110b6dbb31681d1638ad1c3",
		"4a871b984fce8d7a1b094305eaa7858e1c6faf2c0f3aecf2c083b5ad5be921e8"},
	lethariel = {"5cbdfd86d1440ee7c511d252218b102c6ebf34d3313b07600f6ef012f16056ae",
		"b3d08db2a916c8089fc1828bf88f5f90a9da0610bbdfb8c59857fb9c63ca663c",
		"9fee967ec360c30ad77fc1f656197dd1883997989c322a00a1b92aa7bbd8295a"},
	nhal_veyr = {"f9faa20739aeb0d7158d3ceac817192d354eb6e472d95d8e3c34320a7168151a",
		"0318e5c46549ad97d40d03781e61d14e460df3e211f45d19434e26d25e81b893",
		"9d9c9ab740be314ce08be275fe1f0cb88e2d8b6400c0e1e3289f5e486e8efe02"},
	gor_drazhak = {"fb0f58d902c4bdb029cf30c47690c1a334141718f237fbb4a159ecb56df025ba",
		"076a1fd897c790862926a0e9b8ea3a266f0fc2fa52b01dd269a5a8c2beacac5b",
		"80d1401942fc24107aeeaa46901d2f4828f6ebbb731ec28222eefc2192e97004"},
	kezamba = {"929d852e1c2467a11e89a261fdacbc46b9b922e5f8b920249cabcc561adcef1e",
		"064bce2cc904f445964cd72961de89a8f5ac1cb1f72fe9bf4541a20cf05bf28a",
		"4627997867a7de84386fea20ee1f3671a73d13b6b4f3dab6bdfb02e05138f7ce"},
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
