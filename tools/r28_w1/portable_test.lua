-- Round 28 Lane W1 portable test (LuaJIT): `from` with an anchor and a
-- border together (spawn_regions_core.lua), and the border classification of
-- the world view (tools/r28_world/borders.lua) on a synthetic world.
--
--   luajit tools/r28_w1/portable_test.lua [REPO]
--
-- A. The parser: `from` = {anchor, border} parses with both sources kept;
--    neither, an empty anchor list, the zone itself as a border and an entry
--    border that is also the exit still fail.
-- B. The builder: the anchor's cell and every border cell are sources
--    (d_from 0); an anchor cell on the border counts once; the anchor pulls
--    the levels round it down against a border-only entry.
-- C. Borders: three zones built by the real core (A 11-20 between B to the
--    north and C to the south); every shared side of two zones' land cells
--    is one edge, classed by the gap between the two regions' level ranges
--    (fit <= 1, step 2-5, jump > 5), forced where the zones' bands lie more
--    than 5 apart, none where a side has no recipe.
-- Prints "R28 W1 PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local CORE = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local B = dofile(repo .. "/tools/r28_world/borders.lua")

-- The synthetic world: zone A x in [-640, 640), z in [-640, 0) (40 x 20
-- cells), zone B north of it (z in [0, 320)), zone C south (z in [-960,
-- -640)), all flat land; open sea round them. A's start lies inside, its
-- capital on the southern row (the border with C).
local ZA, ZB, ZC = "zone_a", "zone_b", "zone_c"
local function zone_at(x, z)
	if x < -640 or x >= 640 then return nil end
	if z >= 0 and z < 320 then return ZB end
	if z >= -640 and z < 0 then return ZA end
	if z >= -960 and z < -640 then return ZC end
	return nil
end
local ANCHORS = {
	{id = "anchor_001", slot = "start", x = -400, z = -320},
	{id = "anchor_002", slot = "capital", x = 16, z = -624},
}
local SOURCE = {zones = {{id = ZA, numeric_id = 1}, {id = ZB, numeric_id = 2}, {id = ZC, numeric_id = 3}},
	anchors = {}}
for _, a in ipairs(ANCHORS) do
	SOURCE.anchors[#SOURCE.anchors + 1] = {id = a.id, zone_numeric_id = 1, slot_id = a.slot,
		template_id = a.slot}
end
local HUBS = {[ZA] = {x = 0, z = -320}, [ZB] = {x = 0, z = 160}, [ZC] = {x = 0, z = -800}}
local ZONES = {
	id_at = zone_at,
	water_class_at = function(x, z) return zone_at(x, z) and "land" or "deep_ocean" end,
	terrain_height_at = function() return 20 end,
	biome_at = function() return "grug_meadows" end,
	hard_protection_kind_at = function() return nil end,
	anchor = function(zone, slot)
		if zone ~= ZA then return nil end
		for _, a in ipairs(ANCHORS) do
			if a.slot == slot then return {x = a.x, y = 20, z = a.z, id = a.id} end
		end
		return nil
	end,
	get = function(zone) return HUBS[zone] and {hub = HUBS[zone]} end,
}
local Q = CORE.queries({zones = ZONES, road_polylines = {}, source = SOURCE,
	column_values_at = function() return "land" end})
local function ctx(band)
	return {band = band, role_levels = function() return nil end,
		leader = function() return false end,
		pois = function() return {} end}
end
local function kind(id)
	local roster = {{role = "boar", weight = 1}}
	return {open = {id = id, name = id, day = roster, night = roster, density = "normal"}}
end
local function a_belts()
	return {
		{id = "low", share = 50, levels = {11, 14}, kinds = kind("low_open")},
		{id = "high", share = 50, levels = {15, 20}, kinds = kind("high_open")},
	}
end
local function one_belt(lo, hi)
	return {{id = "all", share = 100, levels = {lo, hi}, kinds = kind("all_open")}}
end
local function parse(zone, recipe, band) return CORE.parse_recipe(zone, recipe, ctx(band or {11, 20})) end
local function parse_fails(recipe, pattern, label)
	local ok, err = pcall(parse, ZA, recipe)
	check(not ok and tostring(err):find(pattern, 1, true) ~= nil,
		label .. " (got " .. tostring(ok and "no error" or err) .. ")")
end

-- ---------------------------------------------------------------------------
-- A. The parser
-- ---------------------------------------------------------------------------
local r = parse(ZA, {from = {anchor = "start", border = ZC}, to = {border = ZB}, belts = a_belts()})
check(r.from.anchors[1] == "start" and #r.from.anchors == 1 and r.from.border[1] == ZC and
	#r.from.border == 1, "from with an anchor and a border keeps both")
r = parse(ZA, {from = {anchor = {"start", "capital"}, border = {ZC}}, to = {core = true}, belts = a_belts()})
check(#r.from.anchors == 2 and r.from.border[1] == ZC and r.to.core, "an anchor list and a border list, to core")
r = parse(ZA, {from = {border = ZC}, to = {border = ZB}, belts = a_belts()})
check(r.from.anchors == nil and r.from.border[1] == ZC, "a border alone has no anchors")
r = parse(ZA, {from = {anchor = "start"}, to = {border = ZB}, belts = a_belts()})
check(r.from.border == nil and r.from.anchors[1] == "start", "an anchor alone has no border")
parse_fails({from = {}, to = {border = ZB}, belts = a_belts()}, "from: needs", "from with neither")
parse_fails({from = {anchor = {}, border = ZC}, to = {border = ZB}, belts = a_belts()},
	"anchor is a slot", "an empty anchor list beside a border")
parse_fails({from = {anchor = "start", border = ZA}, to = {border = ZB}, belts = a_belts()},
	"other zones' ids", "the zone itself as the border beside an anchor")
parse_fails({from = {anchor = "start", border = ZB}, to = {border = ZB}, belts = a_belts()},
	"both the entry and the exit border", "the anchor's border is the exit")
parse_fails({from = {anchor = "start", border = ZC, core = true}, to = {border = ZB}, belts = a_belts()},
	"unknown field core", "an unknown field in from")
print("A: parser")

-- ---------------------------------------------------------------------------
-- B. The builder
-- ---------------------------------------------------------------------------
local CELL = CORE.CELL
local function build(zone, recipe, band) return CORE.build(zone, Q, parse(zone, recipe, band)) end
local function at(map, x, z) return map.cells[CORE.key(math.floor(x / CELL), math.floor(z / CELL))] end
local both = build(ZA, {from = {anchor = "start", border = ZC}, to = {border = ZB}, belts = a_belts()})
local border_only = build(ZA, {from = {border = ZC}, to = {border = ZB}, belts = a_belts()})
check(#both.order == 800, "800 land cells (" .. #both.order .. ")")
local south_ok = true
for _, c in ipairs(both.order) do
	if c.j == -20 and c.d_from ~= 0 then south_ok = false end
end
check(south_ok and at(both, -400, -320).d_from == 0, "the anchor's cell and every border cell have d_from 0")
check(#both.from_cells == 41, "41 sources: 40 border cells and the start (" .. #both.from_cells .. ")")
local start_cell = at(both, -400, -320)
check(start_cell.progress == 0 and start_cell.belt == 1, "the start's cell lies at progress 0 in the first belt")
check(at(border_only, -400, -320).progress > 0.4, "without the anchor the start's cell lies half way up")
local near_lower, near_cells = 0, 0
for _, c in ipairs(both.order) do
	local dx, dz = c.x - -400, c.z - -320
	if dx * dx + dz * dz <= 96 * 96 then
		near_cells = near_cells + 1
		local other = border_only.cells[c.key]
		if c.progress < other.progress then near_lower = near_lower + 1 end
	end
end
check(near_cells > 20 and near_lower == near_cells, "the anchor lowers the progress round it (" ..
	near_lower .. "/" .. near_cells .. ")")
local on_border = build(ZA, {from = {anchor = "capital", border = ZC}, to = {border = ZB}, belts = a_belts()})
check(#on_border.from_cells == 40, "an anchor cell on the border counts once (" .. #on_border.from_cells .. ")")
local same = true
for _, c in ipairs(on_border.order) do
	if c.progress ~= border_only.cells[c.key].progress then same = false end
end
check(same, "an anchor on the entry border changes nothing")
print("B: builder")

-- ---------------------------------------------------------------------------
-- C. Borders
-- ---------------------------------------------------------------------------
check(B.gap(11, 14, 15, 20) == 1 and B.gap(15, 20, 11, 14) == 1 and B.gap(11, 20, 15, 18) == 0,
	"gap: touching ranges 1, overlapping 0")
check(B.class(0, 0) == "fit" and B.class(1, 1) == "fit" and B.class(2, 1) == "step" and
	B.class(5, 0) == "step" and B.class(6, 1) == "jump", "classes by the gap")
check(B.class(11, 6) == "forced" and B.class(nil, 11) == "forced" and B.class(nil, 1) == "none",
	"forced by the bands before a missing side")

local function zone_cells(map)
	local out = {}
	for _, c in ipairs(map.order) do
		local lv = map.recipe.belts[c.region.belt].levels
		out[#out + 1] = {c.i, c.j, lv[1], lv[2]}
	end
	return out
end
local a_cells = zone_cells(both)
local function world(b_levels, c_band, c_levels)
	-- (Parsed with the belt as the band: the cover rule wants the last belt
	-- at the band's top; the border check reads the zones' real bands.)
	local b = build(ZB, {belts = one_belt(b_levels[1], b_levels[2])}, b_levels)
	local c = build(ZC, {belts = one_belt(c_levels[1], c_levels[2])}, c_levels)
	return {
		{id = ZA, band = {11, 20}, cells = a_cells},
		{id = ZB, band = {21, 30}, cells = zone_cells(b)},
		{id = ZC, band = c_band, cells = zone_cells(c)},
	}
end
local function tally(zones)
	local edges, dup = B.edges(zones)
	local by = {}
	for _, e in ipairs(edges) do
		local pair = zones[math.min(e.a, e.b)].id .. "|" .. zones[math.max(e.a, e.b)].id
		by[pair] = by[pair] or {}
		by[pair][e.class] = (by[pair][e.class] or 0) + 1
	end
	return by, edges, dup
end
-- B at L28-30 beside A's top belt (L15-20): a jump; C at 31-40 (band gap 11): forced.
local by, edges, dup = tally(world({28, 30}, {31, 40}, {31, 40}))
check(dup == 0 and #edges == 80, "80 border edges, no duplicate cells (" .. #edges .. ", " .. dup .. ")")
check(by[ZA .. "|" .. ZB].jump == 40, "A L15-20 | B L28-30: 40 jump edges")
check(by[ZA .. "|" .. ZC].forced == 40, "A 11-20 | C 31-40: 40 forced edges")
local ab
for _, e in ipairs(edges) do
	if e.a == 1 and e.b == 2 then ab = e end
end
check(ab and ab.side == "n" and ab.j == -1 and ab.a_lo == 15 and ab.a_hi == 20 and ab.b_lo == 28 and
	ab.gap == 8 and ab.band_gap == 1, "an A|B edge: A's northern row, its top belt, gap 8")
check(B.totals(edges, CELL).jump == 40 * CELL and B.totals(edges, CELL).forced == 40 * CELL,
	"totals in nodes")
-- B at L21-25: fit (touching); at L23-30: step; C at 1-10 beside A's first belt (L11-14): fit.
by = tally(world({21, 25}, {1, 10}, {1, 10}))
check(by[ZA .. "|" .. ZB].fit == 40 and by[ZA .. "|" .. ZC].fit == 40, "touching ranges fit on both borders")
by = tally(world({23, 30}, {1, 10}, {5, 8}))
check(by[ZA .. "|" .. ZB].step == 40 and by[ZA .. "|" .. ZC].step == 40, "gaps 3 and 3: step")
-- A side without a recipe (cells without levels): none, unless the bands force it.
local zones = world({21, 25}, {1, 10}, {1, 10})
for _, c in ipairs(zones[2].cells) do c[3], c[4] = nil, nil end
by = tally(zones)
check(by[ZA .. "|" .. ZB].none == 40 and by[ZA .. "|" .. ZC].fit == 40, "no recipe: none")
-- A cell two zones both list: the first keeps it.
zones = world({21, 25}, {1, 10}, {1, 10})
table.insert(zones[2].cells, {a_cells[1][1], a_cells[1][2], 21, 25})
local _, _, dups = tally(zones)
check(dups == 1, "a cell listed twice is counted once and kept by the first zone")
print("C: borders")

print(("R28 W1 PORTABLE PASS checks=%d"):format(checks))
