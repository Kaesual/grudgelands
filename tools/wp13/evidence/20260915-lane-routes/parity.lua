-- The road this lane did NOT change, and the runs it did.
--
--     luajit parity.lua <repo> <a checkout of the base commit> <seed>
--
-- Three roads per run of both capitals, all three on the same WP40 height
-- session of the same seed:
--
--   1. `old`   -- the base commit's `wp13/avenue.lua`;
--   2. `bare`  -- this lane's, with no route geometry handed to it;
--   3. `live`  -- this lane's, with the route geometry the seam now hands it.
--
-- (1) and (2) must be byte-identical on every run, which is the claim that
-- this lane changes nothing where no route spans the road. (3) is reported as
-- the cells that differ from (1), which is the claim about what DID move.
--
-- Plain Lua 5.1 (LuaJIT for the WP40 construction).

local repo = assert(arg[1], "repository root required")
local base = assert(arg[2], "base-commit checkout required")
local seed = assert(arg[3], "world seed required")

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local base_wp13 = base .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local new_avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local old_avenue = dofile(base_wp13 .. "/avenue.lua")(base_wp13)
local highcourt = dofile(wp13 .. "/highcourt.lua")(wp13)
local quadrants = dofile(wp13 .. "/highcourt_quadrants.lua")()
local dur_brannoc = dofile(wp13 .. "/dur_brannoc.lua")(wp13)

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
	schemas = dofile(wp40 .. "/schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256, horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)

local function walkable(x, z)
	local terrain_y = height.terrain_height_at(x, z)
	local water_y = height.water_surface_at(x, z)
	if type(water_y) == "number" and water_y > terrain_y then return water_y end
	return terrain_y
end
local function deck(x, z)
	local kind, functional_y = height.functional_surface_values_at(x, z)
	if kind ~= "bridge_deck" then return nil end
	return functional_y
end

local function lists(...)
	local out = {}
	for _, list in ipairs({...}) do
		for index = 1, #list do out[#out + 1] = list[index] end
	end
	return out
end
local CAPITALS = {
	{key = "highcourt", race = "human", x = 0, z = -1500,
		runs = lists(highcourt.avenues, highcourt.ring, quadrants.lane_runs())},
	{key = "dur_brannoc", race = "dwarf", x = -1800, z = -1500,
		runs = lists(dur_brannoc.avenues, dur_brannoc.ring)},
}

local function key(cell) return cell.x .. ":" .. cell.y .. ":" .. cell.z end
local function body(cell) return cell.name .. ":" .. cell.param2 end

local unchanged, moved, rows = 0, 0, {}
for _, capital in ipairs(CAPITALS) do
	local palette = palettes.new(capital.race)
	for _, run in ipairs(capital.runs) do
		local along = (run.axis == "x") and capital.x or capital.z
		local across = (run.axis == "x") and capital.z or capital.x
		local spec = {id = run.id, axis = run.axis, at = across + run.at,
			from = along + run.from, to = along + run.to,
			lamp_phase = along + run.from}
		local old = old_avenue.run(palette, spec, walkable)
		local bare = new_avenue.run(palette, spec, walkable)
		spec.overhead = deck
		local live = new_avenue.run(palette, spec, walkable)
		if #old.cells ~= #bare.cells then
			error(run.id .. ": the bare road moved -- " .. #old.cells .. " cells " ..
				"against " .. #bare.cells, 0)
		end
		for index = 1, #old.cells do
			if key(old.cells[index]) ~= key(bare.cells[index]) or
					body(old.cells[index]) ~= body(bare.cells[index]) then
				error(run.id .. ": the bare road moved at cell " .. index, 0)
			end
		end
		local index = {}
		for _, cell in ipairs(old.cells) do index[key(cell)] = body(cell) end
		local delta = 0
		for _, cell in ipairs(live.cells) do
			if index[key(cell)] ~= body(cell) then delta = delta + 1 end
			index[key(cell)] = nil
		end
		for _ in pairs(index) do delta = delta + 1 end
		if delta == 0 then
			unchanged = unchanged + 1
		else
			moved = moved + 1
			rows[#rows + 1] = capital.key .. "/" .. run.id .. "\t" .. delta ..
				"\t" .. #old.cells .. "\t" .. #live.cells
		end
	end
end
io.write("seed=", seed, " runs_unchanged=", unchanged, " runs_moved=", moved,
	"\n")
if #rows > 0 then io.write("run\tcells_differing\tbefore\tafter\n") end
for index = 1, #rows do io.write(rows[index], "\n") end
