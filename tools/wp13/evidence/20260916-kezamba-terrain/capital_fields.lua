-- ONE DIGEST PER CAPITAL OVER ITS WHOLE TERRAIN FIELD.
--
--     luajit tools/wp13/evidence/20260916-kezamba-terrain/capital_fields.lua \
--         <repo> <seed> [<reach>]
--
-- WHAT IT IS FOR. A capital terrain change is allowed to move exactly the
-- capital it is about, and "the other five are byte-identical" has to be a
-- comparison and not a hope. This prints, per capital anchor, a SHA-256 over
-- the final terrain height AND the land/water class of every one of the
-- 251 001 columns within +-250 of it -- the same field
-- `tools/wp13/run_capital.sh <out> <key> field <seed>` dumps out of a running
-- server, read here from the planner instead, which is the same answer: on
-- seed 531802985935182545 the engine's own `kezamba-field.tsv` body and this
-- tool's input are byte-identical (`36ed1258...`, section 8.9 of
-- `docs/research/wp13-kezamba.md`).
--
-- `tools/wp13/capital_terrain_fixture.lua` is the WALKABILITY gate and answers
-- a different question: it counts climbs in a +-128 window and its digest moves
-- whenever any capital's per-mille figure does. This one is the IDENTITY check,
-- per capital and per seed, so a row that must not move can be compared on its
-- own.
--
-- Plain Lua 5.1, LuaJIT in practice; no engine, no globals. Roughly ten seconds
-- per capital per seed, so one seed is about a minute.

local repo = assert(arg[1], "repository root required")
local seed = assert(arg[2], "seed required")
local reach = tonumber(arg[3] or "250")
assert(reach and reach % 1 == 0 and reach >= 16 and reach <= 250,
	"reach must be a whole number of nodes in 16..250")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()
local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
	schemas = schemas, canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256, horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)

local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
end

local capitals = 0
for index = 1, #source.anchors do
	local anchor_row = source.anchors[index]
	if anchor_row.slot_id == "capital" then
		capitals = capitals + 1
		local anchor = assert(height.selected_anchor_3d_by_id(anchor_row.id),
			"capital anchor missing: " .. anchor_row.id)
		-- One string per row, hashed once: a per-column update would be the
		-- same bytes and a hundred times the calls.
		local rows = {}
		for z = -reach, reach do
			local row = {}
			for x = -reach, reach do
				local wx, wz = anchor.x + x, anchor.z + z
				row[#row + 1] = height.terrain_height_at(wx, wz)
				row[#row + 1] = horizontal.water_class_at(wx, wz) == "land"
					and 1 or 0
			end
			rows[#rows + 1] = table.concat(row, ",")
		end
		io.write("field\t", anchor_row.template_id, "\t", anchor_row.id, "\t",
			seed, "\treach=", reach, "\tanchor=", anchor.x, ",", anchor.y, ",",
			anchor.z, "\tsha256=", hex(raw_sha256(table.concat(rows, "\n"))),
			"\n")
	end
end
assert(capitals == 6, "the roster carries " .. capitals .. " capitals")
