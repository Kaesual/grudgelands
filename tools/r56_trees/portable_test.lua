-- Round 56 lane TREES portable test (building-template-format.md §4.2: the
-- trees of planted templates stay algorithmic):
--   A. the planted templates are exactly the parts that planted trees or
--      scattered undergrowth (the groves, orchards and copses, the Lethariel
--      boughs), and no template holds a tree piece, trunk or leaf as a fixed
--      node, nor a planted template a scattered undergrowth cell;
--   B. the loader plants: every planted placement of every capital is built
--      by calling the tree generator's planter at each stem in planting
--      order, in the part's frame, with the placement's main palette and
--      the template's tree spacing, then the undergrowth over its rectangle,
--      so a change of the generator reaches every tree; the part holds the
--      trees, no `trees` point and no planting meta, and builds the same
--      twice;
--   C. order: a `late` cell is written over the grown trees (a late block on
--      a trunk cuts that tree out whole), the same cell before planting
--      keeps the tree off it;
--   D. a malformed planted template stops at load with its file and line
--      (an unknown planter, a stem without its height, a turned stem, a
--      malformed undergrowth or tree spacing, `late` twice, a race switch or
--      an `else=` naming a `late` entry: a cell is late by its own entry).
-- Byte identity of every capital's build is pinned by r56_freeze_capitals D.
--
-- Usage (repo root): luajit tools/r56_trees/portable_test.lua [REPO]
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"

-- Every dressing module the loader loads records its planter calls.
local calls
local saved_dofile = dofile
local PLANTERS = {"tree", "broadleaf", "columnar", "acacia", "gravewood", "jungle_tree",
	"emergent"}
_G.dofile = function(path)
	local loaded = saved_dofile(path)
	if not path:match("/dressing%.lua$") then return loaded end
	return function(directory)
		local module = loaded(directory)
		for _, name in ipairs(PLANTERS) do
			local planter = module[name]
			module[name] = function(buf, palette, x, z, height, ...)
				if calls then
					calls[#calls + 1] = {kind = name, x = x, z = z, height = height,
						palette = palette, spacing = buf.tree_spacing}
				end
				return planter(buf, palette, x, z, height, ...)
			end
		end
		local undergrowth = module.undergrowth
		module.undergrowth = function(buf, palette, x1, z1, x2, z2, density, patch)
			if calls then
				calls[#calls + 1] = {kind = "undergrowth", box = {x1, z1, x2, z2, density},
					palette = palette, patch = patch}
			end
			return undergrowth(buf, palette, x1, z1, x2, z2, density, patch)
		end
		return module
	end
end
local templates = dofile(wp13 .. "/templates.lua")(wp13)
local palettes = saved_dofile(wp13 .. "/palette.lua")
local trees = saved_dofile(wp40 .. "/tree_templates.lua")(saved_dofile(wp40 .. "/treegen.lua"))

local TREE_NODE = {}
for _, row in ipairs(trees.SPECIES) do
	for _, field in ipairs({"trunk", "leaves", "fruit", "quarter", "base", "branch", "twig"}) do
		if row[field] then TREE_NODE[row[field]] = true end
	end
end

local function read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

-- A. the planted templates ------------------------------------------------------
local PLANTED = {
	dur_brannoc_forge_copse = 16, highcourt_homes_orchard = 6,
	highcourt_lore_quiet_grove = 16, highcourt_market_grove = 16,
	highcourt_market_orchard = 6, highcourt_orchard_east = 6, highcourt_orchard_west = 6,
	lethariel_bough_east = 0, lethariel_bough_west = 0, lethariel_market_grove = 16,
	lethariel_market_orchard = 6, lethariel_sacred_grove = 16, nhal_veyr_market_copse = 16,
}
-- every template a start town or a capital places
local names, named = {}, {}
local function collect(list)
	local sorted = {}
	for name in pairs(list) do sorted[#sorted + 1] = name end
	table.sort(sorted)
	for _, name in ipairs(sorted) do
		if not named[name] then named[name], names[#names + 1] = true, name end
	end
end
for _, town in ipairs({"hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar",
		"kapok"}) do
	collect(templates.town(town).templates)
end
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak",
		"kezamba"}) do
	collect(templates.capital(key).templates)
end
check(#names >= 260, "every template is read (" .. #names .. ")")
local parsed, planted_count = {}, 0
for _, name in ipairs(names) do
	local path = templates.ROOT .. "/templates/" .. name .. ".tpl"
	local t = templates.parse_template(read(path), path, name)
	parsed[name] = t
	local planted = #t.stems > 0 or t.meta.undergrowth ~= nil
	check(planted == (PLANTED[name] ~= nil), name .. " is " ..
		(planted and "" or "not ") .. "a planted template")
	if planted then
		planted_count = planted_count + 1
		check(#t.stems == PLANTED[name], name .. " has its " .. PLANTED[name] .. " stems")
		check(t.meta.undergrowth ~= nil, name .. " scatters its undergrowth")
	end
	for _, key in ipairs(t.legend_order) do
		local entry = t.legend[key]
		check(not (entry.kind == "node" and TREE_NODE[entry.name]),
			name .. " holds no tree cell (" .. tostring(entry.name) .. ")")
		check(not (planted and entry.kind == "role" and
			(entry.role == "undergrowth" or entry.role == "grass_tuft")),
			name .. " holds no scattered undergrowth cell")
	end
end
local expected = 0
for _ in pairs(PLANTED) do expected = expected + 1 end
check(planted_count == expected, "every planted template is there")

-- B. the loader plants ----------------------------------------------------------
local CAPITALS = {highcourt = "human", dur_brannoc = "dwarf", lethariel = "elf",
	nhal_veyr = "undead"}
local built = 0
for key in pairs(CAPITALS) do
	local capital = templates.capital(key)
	for _, use in ipairs(capital.roster.uses) do
		local t = capital.templates[use.template]
		if PLANTED[t.name] then
			local function build()
				calls = {}
				local part = capital.part(t.name, "probe", use.main, use.channels.roof)
				local made = calls
				calls = nil
				return part, made
			end
			local part, made = build()
			local main = capital.palettes[use.main or "town"]
			check(#made == #t.stems + 1, t.name .. ": one planter call per stem and the " ..
				"undergrowth (" .. #made .. ")")
			for index, stem in ipairs(t.stems) do
				local call = made[index]
				check(call.kind == stem.kind and call.x == stem.x and call.z == stem.z and
					call.height == stem.height, t.name .. ": stem " .. index .. " planted in order")
				check(call.palette == main, t.name .. ": planted with the main palette")
				check(call.spacing == t.meta.plant_spacing, t.name .. ": the tree spacing")
			end
			local cover = made[#made]
			check(cover.kind == "undergrowth" and cover.patch == nil and cover.palette == main,
				t.name .. ": the undergrowth last, with the main palette")
			for index = 1, 5 do
				check(cover.box[index] == t.meta.undergrowth[index], t.name .. ": its rectangle")
			end
			check(part.points.trees == nil and part.plant_spacing == nil and
				part.undergrowth == nil, t.name .. ": no stems or planting meta in the part")
			local cells, count = part.buffer:cells()
			local wood, text = 0, {}
			for index = 1, count do
				local cell = cells[index]
				if TREE_NODE[cell.name] then wood = wood + 1 end
				text[#text + 1] = cell.x .. ":" .. cell.y .. ":" .. cell.z .. "=" ..
					cell.name .. "/" .. cell.param2
			end
			check(#t.stems == 0 or wood > 0, t.name .. ": the part holds its trees")
			local again = build()
			local cells2, count2 = again.buffer:cells()
			local same = count2 == count
			for index = 1, same and count2 or 0 do
				local cell = cells2[index]
				if text[index] ~= cell.x .. ":" .. cell.y .. ":" .. cell.z .. "=" ..
						cell.name .. "/" .. cell.param2 then same = false end
			end
			check(same, t.name .. ": the planting is deterministic")
			built = built + 1
		end
	end
end
check(built >= 13, "the planted placements are built (" .. built .. ")")

-- C. late cells are written over the trees --------------------------------------
local human = palettes.new("human")
local function palette_of() return human end
local function tiny(extra_legend, cell_at_1)
	local rows = {}
	for _ = 1, 9 do rows[#rows + 1] = "|GGGGGGGGG|" end
	local above = {}
	for z = 0, 8 do
		above[#above + 1] = "|" .. (z == 4 and ("    " .. cell_at_1 .. "    ") or
			"         ") .. "|"
	end
	return table.concat({templates.TEMPLATE_MAGIC, "name tiny", "pivot 9 9", "origin 0 0 0",
		"size 9 2 9", "cell 1", "races human", "", "legend", "G role ground",
		extra_legend, "end", "", "layer 0", table.concat(rows, "\n"), "layer 1",
		table.concat(above, "\n"), "", "points", "trees 4 0 4 height=5 kind=broadleaf",
		"end", ""}, "\n")
end
local function part_of(text)
	local t = templates.parse_template(text, "tiny.tpl", "tiny")
	local cells, count = templates.part(t, "tiny", "human", palette_of).buffer:cells()
	local at, wood = nil, 0
	for index = 1, count do
		local cell = cells[index]
		if cell.x == 4 and cell.y == 1 and cell.z == 4 then at = cell.name end
		if TREE_NODE[cell.name] then wood = wood + 1 end
	end
	return at, wood
end
local free_at, free_wood = part_of(tiny("S node default:stone", " "))
check(free_wood > 0 and free_at ~= nil and TREE_NODE[free_at],
	"a stem on free ground grows its tree (" .. tostring(free_at) .. ")")
local late_at, late_wood = part_of(tiny("S node default:stone late", "S"))
check(late_at == "default:stone" and late_wood == 0,
	"a late block on the trunk is written after planting and cuts the tree out whole")
local early_at, early_wood = part_of(tiny("S node default:stone", "S"))
check(early_at == "default:stone" and early_wood > 0,
	"the same block before planting keeps the tree off it, the tree grows beside it")

-- D. malformed planted templates stop at load -----------------------------------
local good = tiny("S node default:stone late", "S")
for _, case in ipairs({
	{"kind=broadleaf", "kind=oak", "an unknown planter"},
	{" height=5", "", "a stem without its height"},
	{"trees 4 0 4", "trees 4 0 4 face=1", "a turned stem"},
	{"cell 1", "cell 1\nmeta undergrowth=[0,0,8,8]", "a malformed undergrowth"},
	{"cell 1", "cell 1\nmeta plant_spacing=0", "a tree spacing below one"},
	{"default:stone late", "default:stone late late", "late given twice"},
	{"default:stone late", "default:stone late\nR race human=S", "a race switch naming a late entry"},
	{"default:stone late", "default:stone late\nF role fence_gate else=S",
		"an else= naming a late entry"},
}) do
	local text = good:gsub(case[1]:gsub("%p", "%%%0"), (case[2]:gsub("%%", "%%%%")), 1)
	check(text ~= good, "the case applies: " .. case[3])
	local ok, err = pcall(templates.parse_template, text, "tiny.tpl", "tiny")
	check(not ok and tostring(err):match("^tiny%.tpl:%d+: "), case[3] .. " is refused at load (" ..
		tostring(err) .. ")")
end

print("r56_trees portable test: PASS (" .. checks .. " checks)")
