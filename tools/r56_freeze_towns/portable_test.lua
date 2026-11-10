-- Round 56 lane FREEZE-TOWNS portable test (building-template-format.md):
--   A. the building template loader (wp13/templates.lua) reads every layout
--      and template the six start towns place;
--   B. a malformed file stops at load with its file, line and reason;
--   C. a legend entry resolves per race: roles through the placement's
--      channel palettes, fixed nodes, race switches, else= fallbacks and the
--      orientation rule (none -> 0, meshoptions pinned, a wrong kind refused);
--   D. a placement's part: `{id}` filled in, the generator's point groups
--      present, sockets placed from the stamp;
--   E. THE FREEZE: every start town builds the settlement identity and the
--      point digest it built from the generators before the freeze (pinned;
--      a template, layout or palette change that moves them needs a declared
--      map reset, tools/check_upgrade.py).
--
-- Usage (repo root): luajit tools/r56_freeze_towns/portable_test.lua [REPO]
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
local palettes = dofile(wp13 .. "/palette.lua")
local parts = dofile(wp13 .. "/parts.lua")
local TOWNS = {"hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar", "kapok"}

-- A. every town's layout and templates ---------------------------------------
local placements = 0
for _, id in ipairs(TOWNS) do
	local town = templates.town(id)
	check(palettes.races[town.race] ~= nil and town.id == id, id .. " race")
	for _, place in ipairs(town.places) do
		local part = town.part(place)
		check(part.w >= 1 and part.d >= 1 and type(part.peak) == "number",
			id .. ":" .. place.id .. " part")
		placements = placements + 1
	end
end
check(placements == 51, "51 placements, got " .. placements)

-- B. malformed files ------------------------------------------------------------
local GOOD = table.concat({templates.TEMPLATE_MAGIC, "name t", "pivot 1 1",
	"origin 0 0 0", "size 1 3 1", "cell 1", "races dwarf human", "legend",
	"F role floor", "W role wall", "S role shutter o=facedir:2 else=air",
	"B role bed_fancy variant=_bottom o=facedir:1 else=b",
	"b role bed variant=_bottom o=facedir:1", "N node default:dry_shrub",
	"R race dwarf=W *=F", "P role window o=facedir:3", "end",
	"layer 0", "|F|", "layer 1", "|.|", "layer 2", "|.|", "points",
	"inside 0 1 0 id={id} note=\"a {id} b\" tags=[door,{id}]", "end", ""}, "\n")
local good = templates.parse_template(GOOD, "t.tpl", "t")
check(good.name == "t" and #good.grid == 3, "a template parses")
local function refused(text, wanted_line, label)
	local ok, err = pcall(templates.parse_template, text, "bad.tpl", "t")
	check(not ok, label .. " is refused")
	check(tostring(err):find("^bad%.tpl:" .. wanted_line .. ": ") ~= nil,
		label .. " names file and line: " .. tostring(err))
end
refused(GOOD:gsub("template 1", "template 2", 1), 1, "another version")
refused(GOOD:gsub("|F|", "|F |", 1), 19, "a row too wide")
refused(GOOD:gsub("|F|", "|X|", 1), 19, "an undefined key")
refused(GOOD:gsub("F role floor", "F role flor", 1), 9, "an undeclared role")
refused(GOOD:gsub("F role floor", "F role floor else=air", 1), 9, "else= on a required role")
refused(GOOD:gsub("variant=_bottom o=facedir:1 else", "variant=_top_x o=facedir:1 else", 1),
	12, "a variant outside the family")
refused(GOOD:gsub("inside 0 1 0", "inside 0 9 0", 1), 25, "a point outside the box")
refused(GOOD:gsub("layer 2", "layer 3", 1), 22, "a layer out of order")
refused(GOOD:gsub("R race dwarf=W", "R race dwarf=Q", 1), 15, "a switch to an undefined key")
refused(GOOD:gsub("name t\n", "name t\r\n", 1), 2, "a carriage return")
local ok_layout, err_layout = pcall(templates.parse_layout,
	templates.LAYOUT_MAGIC .. "\ntown x\nrace dwarf\nplace a template=t x=0 y=0 z=0 " ..
	"turns=0 roof=slate\n", "x.layout")
check(not ok_layout and tostring(err_layout):find("^x%.layout:4: ") ~= nil,
	"a channel naming no palette is refused: " .. tostring(err_layout))

-- C. resolution per race ------------------------------------------------------------
local dwarf, human, troll = palettes.new("dwarf"), palettes.new("human"), palettes.new("troll")
local function by(palette) return function() return palette end end
local function at(t, key, race, palette)
	return templates.resolve(t, key, by(palette), race)
end
check(at(good, "F", "dwarf", dwarf) == "default:pine_wood", "a role through the palette")
check(at(good, "R", "dwarf", dwarf) == "default:pine_wood", "a switch picks the dwarf key")
check(at(good, "R", "human", human) == "default:wood", "a switch falls to *")
local name, p2 = at(good, "S", "human", human)
check(name == "grug_decor:cottages_window_shutter_closed" and p2 == 2, "a bound optional role")
name, p2 = at(good, "S", "dwarf", dwarf)
check(name == "air" and p2 == 0, "else=air for a race without shutters")
name, p2 = at(good, "B", "undead", palettes.new("undead"))
check(name == "beds:bed_bottom" and p2 == 1, "else=<key>: a plain bed for no fancy bed")
name, p2 = at(good, "N", "dwarf", dwarf)
check(name == "default:dry_shrub" and p2 == 4, "a meshoptions node keeps its pinned value")
name, p2 = at(good, "P", "dwarf", dwarf)
check(name == "xpanes:pane_flat" and p2 == 3, "a pane keeps its orientation")
name, p2 = at(good, "P", "troll", troll)
check(name == "grug_decor:darkage_wood_bars" and p2 == 0, "bars have no orientation: 0")
local wrong = templates.parse_template(GOOD:gsub("P role window o=facedir:3",
	"P role window o=wallmounted:3", 1), "w.tpl", "t")
check(not pcall(at, wrong, "P", "dwarf", dwarf), "a stored kind that differs is refused")

-- D. a part and its points ------------------------------------------------------
local part = templates.part(good, "smithy", "dwarf", by(dwarf))
local inside = part.points.inside[1]
check(inside.id == "smithy" and inside.note == "a smithy b" and inside.tags[2] == "smithy",
	"{id} is filled in")
check(#part.points.doors == 0 and #part.points.lights == 0 and
	#part.points.room_corner == 0, "the generator's point groups are there")
local stamped = parts.stamp(parts.buffer(), part, 10, 0, 20, 1)
check(stamped.inside[1].x == 10 and stamped.inside[1].z == 20, "the point stamps")
-- (Round 56 FREEZE-CAPITALS: the stamped points carry the building that
-- stamped them, `templates.collect_sockets`, and a point of another building
-- is refused.)
local function collected()
	return templates.collect_sockets({}, {sockets = {{x = 5, y = 1, z = 6, face = 3,
		id = "b"}}}, "h")
end
local sockets = templates.sockets({{id = "a", role = "idle", x = 1, y = 1, z = 1,
	dir = {x = 0, z = 1}}, {id = "b", role = "quest", tags = {"door"}, building = "h"}},
	collected(), "test")
check(sockets[2].x == 5 and sockets[2].dir.x == -1 and sockets[2].dir.z == 0 and
	sockets[2].building == nil and sockets[2].role == "quest", "a socket from its building")
check(not pcall(templates.sockets, {{id = "b", building = "h"}}, {}, "test"),
	"a socket its building lacks is refused")
check(not pcall(templates.sockets, {{id = "b", building = "other"}}, collected(), "test"),
	"a socket another building stamped is refused")

-- E. the freeze -------------------------------------------------------------------
-- Identity SHA-256 and point digest of each start town as the building
-- generators built it at 1ac0688b (tools/building_templates/town_identity.lua);
-- since Round 58 (TOWNFIX, a declared map reset: every start's waystone and
-- mailbox at its centre, Silverleaf's terrace stair with its last tread) and
-- Round 70 (TOWNS, a declared map reset: the six towns' reworked layouts) the
-- towns' new values; since 0.73.1 (a declared map reset: thin tables replace the
-- table_leg/table_top pairs, Dawnmere's inn beds; points unchanged, the
-- node list moves the point digest) the towns' new values again.
-- Round 75: declared map reset; restrained city dressing changes cell identities.
-- Source blueprints and their point/build digests stay unchanged.
-- 0.75.1: declared map reset (unreleased 0.75.0 already resets): the slab over
-- every workshop workbench and the human closed shutters are gone; the human
-- palette's shutter node leaves the node list, so Dawnmere's and Highcourt's
-- point digests move too.
local FROZEN = {
	hearthpine = {"6ca976fa5741bdd914e9e540fe676b71269aa8225656d05546be3c11250a15c1",
		"72ca455e10241c9bea4328b1a367d932bf3afecd67d3968c1d3d1359bde61bf5"},
	dawnmere = {"e2d0481360abf226eb40746c1c278037cd9187c413816bc0a157b4b1ecd78cf9",
		"cd0aa85eac0752becbd614999556856086856be4386fd2786bd000ca067d3746"},
	silverleaf = {"86cc1097e793a2cbaa958fe9e33341445a4bd464829bfe4760139aa012f320b5",
		"539aeb053cde71f8362459160f69c07bf6a8727bf81bd36706a1144334f9bfea"},
	stillgrave = {"1e0402d51127f0213b8b2bd57b380eb59ddabd582374f6429cbfc83a2a448b29",
		"9c818115f1656ccb5b6f5b3aa2f77c08362e707d4a8075119eab083e023943c5"},
	sunscar = {"b3f8d7bd725af8ce21be8c22a413135f20f77fa1237dd38746dee2234e8b1485",
		"2647c4c29010a9ad7d827139c0b30eec414326f886baa4e8380dcfef353ae04d"},
	kapok = {"77d762710e1c450fd148fa9d68a48dde5dc83a5aac6ebd2e3be8d3a6e6c8b1f4",
		"eeddeccb546dab30e3955aee0bc75117900810dca32363f56ee36c436f5e9583"},
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
local seen = 0
for _, profile in ipairs(settlement.roster) do
	if profile.slot == "start" then
		local blueprint = dofile(wp40 .. "/" .. profile.blueprint_file)()
		local prepared = settlement.prepare(profile, blueprint, sha)
		local rest = {}
		for key, value in pairs(blueprint) do
			if key ~= "cells" then rest[key] = value end
		end
		local frozen = FROZEN[profile.key]
		check(prepared.blueprints[1].identity.sha256 == frozen[1],
			profile.key .. ": the settlement identity is the frozen one")
		check(common.hex(sha(table.concat(canonical(rest, {})))) == frozen[2],
			profile.key .. ": the point digest is the frozen one")
		seen = seen + 1
	end
end
check(seen == 6, "six start towns")

print("r56_freeze_towns portable test: PASS (" .. checks .. " checks)")
