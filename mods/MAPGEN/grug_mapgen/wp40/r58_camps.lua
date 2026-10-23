-- Round 58 camp module (round58-plan.md §3, the camp-and-room module): the
-- camps of the Miner's Guild with their lift columns and levels, and the
-- enemy camps under construction, of one world. Pure and deterministic: it
-- reads the authored source (`source/simple_map.lua`), the camp catalogues
-- (`r58_camp_catalog.lua`, `r31_pvp_catalog.lua`) and the world's placement
-- layout (`placement.lua` text, the `placement_layout` the main and the
-- mapgen environment both hold), so it gives the same answer in both
-- environments and needs no new IPC field. No saved camp state.
--
--   local C = dofile(wp40 .. "/r58_camps.lua")
--   C.camps(layout[, seams])        -- every camp with a lift, sorted by id
--   C.under_construction(layout)    -- the 6 camps under construction, by id
--   C.ROOM_FLOOR_Y                  -- {-50, -250, -450, -650, -950, -1050}
--   local index = C.index(layout[, seams])  -- grug_mapgen.mining_camps
--
-- `layout` is the placement text ("P1 <count>" and one "<anchor id> <x> <z>
-- <step>" line per placed anchor) or a table anchor id -> {x, z}. A camp of
-- `camps()`:
--   {id, kind ("mining_camp" | "war_camp"), faction, race, zone_id, tier,
--    anchor = {x, z}, lift = {x, z}, levels = {1, ..., tier},
--    label, anchor_id}
-- `lift` is the x/z column of the camp's lift node (the rooms stack below
-- it: ROOMS owns a room's shape round (lift.x, ROOM_FLOOR_Y[level],
-- lift.z)); `tier` is the zone's tier. A war camp's race is rolled per
-- world (`r31_pvp_catalog.camp_race`): `seams = {raw_sha256, full_seed}`
-- gives it, without them a war camp's `race` is nil (the lifts, levels and
-- every other field do not depend on it). A camp under construction:
-- {id, faction, race, zone_id, anchor = {x, z}, label, anchor_id}.
-- Plain Lua 5.1, no globals.
local module_info = debug and debug.getinfo and debug.getinfo(1, "S")
local module_dir = type(module_info)=="table" and type(module_info.source)=="string" and
	module_info.source:sub(1,1)=="@" and module_info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not module_dir or module_dir=="" then module_dir=core.get_modpath("grug_mapgen").."/wp40" end
local source = dofile(module_dir .. "/source/simple_map.lua")
local catalog = dofile(module_dir .. "/r58_camp_catalog.lua")
local pvp = dofile(module_dir .. "/r31_pvp_catalog.lua")
local rot = dofile(module_dir .. "/../wp13/plot_approach.lua").rot

local M = {}
M.ROOM_FLOOR_Y = catalog.ROOM_FLOOR_Y
M.LIFT = catalog.LIFT
-- A position belongs to a camp's surface lift when it lies within this many
-- nodes (horizontally) of the lift column and above the shallowest room's
-- reach (`M.near`).
M.NEAR_RADIUS = 8
M.SURFACE_MIN_Y = catalog.ROOM_FLOOR_Y[1] + 16

local function fail(message)
	error("WP40 camps: " .. message, 0)
end

local zone_by_id, anchor_of = {}, {}
for _, zone in ipairs(source.zones) do zone_by_id[zone.id] = zone end
for _, a in ipairs(source.anchors) do
	anchor_of[a.zone_numeric_id .. "/" .. a.slot_id] = a
end
local function bind(row)
	local zone = zone_by_id[row.zone_id]
	if not zone then fail("zone differs: " .. row.key) end
	local a = anchor_of[zone.numeric_id .. "/" .. row.slot]
	if not a or a.template_id ~= row.kind then fail("anchor differs: " .. row.key) end
	return zone, a
end

-- The placement layout as anchor id -> {x, z}.
local function positions_of(layout)
	if type(layout) == "table" then return layout end
	if type(layout) ~= "string" then fail("placement layout differs") end
	local out, count, lines = {}, nil, 0
	for line in layout:gmatch("[^\n]+") do
		if not count then
			count = tonumber(line:match("^P1 (%d+)$"))
			if not count then fail("placement layout header differs") end
		else
			local id, x, z = line:match("^(anchor_%d+) (%-?%d+) (%-?%d+) %d+$")
			if not id then fail("placement layout row differs") end
			out[id] = {x = tonumber(x), z = tonumber(z)}
			lines = lines + 1
		end
	end
	if not count or lines ~= count then fail("placement layout count differs") end
	return out
end
local function position(positions, a)
	local p = positions[a.id]
	if type(p) ~= "table" or type(p.x) ~= "number" or type(p.z) ~= "number" then
		fail("placed anchor missing: " .. a.id)
	end
	return {x = p.x, z = p.z}
end

local function levels(tier)
	local out = {}
	for level = 1, tier do out[level] = level end
	return out
end

local function by_id(l, r) return l.id < r.id end

function M.camps(layout, seams)
	local positions = positions_of(layout)
	if seams ~= nil and (type(seams) ~= "table" or type(seams.raw_sha256) ~= "function" or
			type(seams.full_seed) ~= "string") then
		fail("seams differ")
	end
	local out = {}
	local function add(row, kind, race, zone, a)
		local anchor = position(positions, a)
		local offset = catalog.LIFT[row.kind]
		if not offset then fail("no lift for kind " .. tostring(row.kind)) end
		local dx, dz = rot(offset.x, offset.z, pvp.gate_turns(row))
		local tier = catalog.tier_of(zone.level_min)
		out[#out + 1] = {id = row.key, kind = kind, faction = row.faction, race = race,
			zone_id = row.zone_id, tier = tier, anchor = anchor,
			lift = {x = anchor.x + dx, z = anchor.z + dz}, levels = levels(tier),
			label = row.label, anchor_id = a.id}
	end
	for _, row in ipairs(catalog.mining) do
		local zone, a = bind(row)
		add(row, "mining_camp", row.race, zone, a)
	end
	for _, row in ipairs(pvp.rows) do
		if row.kind ~= "pvp_fortress" then
			local zone, a = bind(row)
			local race = seams and pvp.camp_race(seams.raw_sha256, seams.full_seed,
				a.numeric_id, row.faction) or nil
			add(row, "war_camp", race, zone, a)
		end
	end
	table.sort(out, by_id)
	return out
end

function M.under_construction(layout)
	local positions = positions_of(layout)
	local out = {}
	for _, row in ipairs(catalog.construction) do
		local _, a = bind(row)
		out[#out + 1] = {id = row.key, faction = row.faction, race = row.race,
			zone_id = row.zone_id, anchor = position(positions, a), label = row.label,
			anchor_id = a.id}
	end
	table.sort(out, by_id)
	return out
end

-- The main environment's public table (`grug_mapgen.mining_camps`): the
-- lists of one world and the two lookups. Treat every returned table as
-- read-only.
--   index.camps, index.under_construction   the lists above
--   index.get(id)                           a camp or a camp under construction
--   index.near(pos[, radius])               the camp whose surface lift column
--                                           is within `radius` (M.NEAR_RADIUS)
--                                           of pos (x/z), pos.y above
--                                           M.SURFACE_MIN_Y; the nearest wins
function M.index(layout, seams)
	local positions = positions_of(layout)
	local index = {ROOM_FLOOR_Y = M.ROOM_FLOOR_Y, camps = M.camps(positions, seams),
		under_construction = M.under_construction(positions)}
	local by = {}
	for _, list in ipairs({index.camps, index.under_construction}) do
		for _, camp in ipairs(list) do
			if by[camp.id] then fail("camp id repeats: " .. camp.id) end
			by[camp.id] = camp
		end
	end
	function index.get(id) return by[id] end
	function index.near(pos, radius)
		if type(pos) ~= "table" or type(pos.x) ~= "number" or type(pos.z) ~= "number" then
			return nil
		end
		if type(pos.y) == "number" and pos.y <= M.SURFACE_MIN_Y then return nil end
		radius = radius or M.NEAR_RADIUS
		local best, best_d2
		for _, camp in ipairs(index.camps) do
			local dx, dz = pos.x - camp.lift.x, pos.z - camp.lift.z
			local d2 = dx * dx + dz * dz
			if d2 <= radius * radius and (not best_d2 or d2 < best_d2) then
				best, best_d2 = camp, d2
			end
		end
		return best
	end
	return index
end

return M
