-- Does an anchor stand on ground, whatever order the engine generates in?
--
--     luajit tools/wp13/capital_anchor_fixture.lua <repo>
--
-- WHAT THIS IS FOR.
--
-- Every roster anchor writes its content one node above its own y and needs
-- solid ground AT its y. `r7_anchor_activation.lua` checks both at load, and on
-- 2026-09-15 a user's fresh world on seed 15912857179583385436 crashed there:
--
--     fail_anchor_activation: anchor settled support differs at anchor_008
--     actual=126/0/0/0/0/0/0            (126 is that world's "air")
--
-- The cause is geometric, not seed luck. A Luanti mapchunk is 80 nodes tall and
-- offset by -32, so chunks span [80k - 32, 80k + 47]. Highcourt's anchor on
-- that seed sits at y 47, which puts its ROOT at 48 -- exactly a chunk's lowest
-- layer -- and its SUPPORT at 47, one node down in the chunk BELOW. The
-- activation check read that support out of the authenticated one-node halo,
-- which carries our column only if the lower chunk has already generated.
-- Teleporting in from above generates the upper chunk first, so it read air.
--
-- Two gate seeds never saw it because on both of them no capital anchor's root
-- lands on a chunk edge. THAT is what this fixture exists to keep true of the
-- seed set: it asserts the column authority every anchor relies on, and it
-- asserts that the set still CONTAINS the edge case, so the day someone prunes
-- the seed list the gate says it stopped testing the thing it was written for.
--
-- What it can check offline, and what it cannot. It cannot read written nodes;
-- there is no map without an engine. It checks the authority the writer builds
-- the column from -- the planner's terrain height, water class, functional kind
-- and functional y at the anchor column -- which is exactly what the fixed
-- activation check relies on when the support lies outside the chunk it owns.
-- The written bytes in both emerge orders are the engine gate's job:
-- `tools/wp13/run_highcourt.sh <out> edge <seed>`.
--
-- Plain Lua 5.1, LuaJIT in practice; no engine, no globals.

local repo = assert(arg[1], "repository root required")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()
local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
local height_factory = dofile(wp40 .. "/height.lua")
local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()

-- The two gate seeds, the seed the user's world crashed on, and six more. Nine
-- worlds is what makes "no capital anchor ever lands on a chunk edge" a claim
-- somebody can refute instead of a thing two seeds happened not to do.
local SEEDS = {"531802985935182545", "8675309", "15912857179583385436",
	"0", "1", "2", "42", "12345", "999999999"}

-- A Luanti mapchunk: 80 nodes, offset by -32.
local CHUNK, CHUNK_OFFSET = 80, -32
local function chunk_origin(y)
	return math.floor((y - CHUNK_OFFSET) / CHUNK) * CHUNK + CHUNK_OFFSET
end

local capitals = {}
for index = 1, #source.anchors do
	if source.anchors[index].slot_id == "capital" then
		capitals[#capitals + 1] = source.anchors[index]
	end
end
assert(#capitals == 6, "the roster carries " .. #capitals .. " capitals")

io.write("kind\tseed\tanchor\tx\tz\tanchor_y\tterrain_y\twater\tfunctional",
	"\tfunctional_y\troot_y\troot_chunk\tsupport_chunk\troot_on_chunk_edge\n")
local rows = {}
local edge_cases, failures = 0, 0
for seed_index = 1, #SEEDS do
	local seed = SEEDS[seed_index]
	local horizontal = horizontal_factory({source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic,
		raw_sha256 = raw_sha256}).new(seed)
	local height = height_factory({source = source, canonical = canonical,
		deterministic = deterministic, raw_sha256 = raw_sha256,
		horizontal_session = horizontal, coupled_grade = coupled_grade}).new_runtime(seed)
	for index = 1, #capitals do
		local anchor = capitals[index]
		local record = height.selected_anchor_3d_by_id(anchor.id)
		assert(type(record) == "table", "capital anchor missing: " .. anchor.id)
		local terrain_y = height.terrain_height_at(record.x, record.z)
		local water = horizontal.water_class_at(record.x, record.z)
		local kind, surface_y = height.functional_surface_values_at(record.x,
			record.z)
		local root_y = record.y + 1
		local root_chunk = chunk_origin(root_y)
		local support_chunk = chunk_origin(record.y)
		local edge = root_chunk ~= support_chunk
		if edge then edge_cases = edge_cases + 1 end

		-- 1. THE COLUMN AUTHORITY the activation check verifies, and the thing
		--    the writer builds the column from. If the planner's terrain height
		--    at the anchor column is not the anchor's own y, the anchor stands
		--    in the air or inside the ground on that world however the chunks
		--    are ordered.
		local function refuse(why)
			failures = failures + 1
			io.write("FAIL\t", seed, "\t", anchor.id, "\t", why, "\n")
		end
		if terrain_y ~= record.y then
			refuse("terrain height " .. terrain_y .. " is not the anchor y " ..
				record.y)
		end
		if water ~= "land" and water ~= "planned_water" then
			refuse("anchor column is " .. tostring(water))
		end
		-- 2. THE SURFACE IS GRADED, which is what makes it solid at terrain_y:
		--    a graded column writes its path or platform surface exactly there.
		if kind ~= "land_grade" and kind ~= "anchor_platform" then
			refuse("anchor column functional kind is " .. tostring(kind))
		end
		if surface_y ~= record.y then
			refuse("surface y " .. tostring(surface_y) .. " is not the anchor y " ..
				record.y)
		end
		local row = table.concat({"capital_anchor", seed, anchor.id, record.x,
			record.z, record.y, terrain_y, water, tostring(kind),
			tostring(surface_y), root_y, root_chunk, support_chunk,
			tostring(edge)}, "\t")
		io.write(row, "\n")
		rows[#rows + 1] = row
	end
end
io.write("capital_anchor_digest\t", #rows, "\t",
	canonical.hex(raw_sha256(table.concat(rows, "\n"))), "\n")
io.write("capital_anchor_edge_cases\t", edge_cases, "\n")

assert(failures == 0, failures ..
	" capital anchor column(s) do not carry their own anchor")
-- The seed set must keep covering the shape that crashed. A set in which no
-- anchor root lands on a chunk edge cannot fail the way the user's world did,
-- and a gate that cannot fail is not one.
assert(edge_cases > 0,
	"no capital anchor in this seed set has its root on a mapchunk edge, so " ..
	"this fixture no longer covers the case it was written for; add a seed " ..
	"that does before removing one")
