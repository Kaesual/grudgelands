-- One window of a capital's streets ON ITS REAL TERRAIN, as a TSV the renderer
-- can draw.
--
--     luajit tools/wp13/evidence/20260916-streets-r4/street_dump.lua \
--         <repo> <key> <seed> <x1> <z1> <x2> <z2> [out.tsv]
--
-- WHY NOT THE PROBE'S OWN DUMPS. `tools/wp13/capital_probe` reads three fixed
-- regions back out of the finished map, and the two places playtest 5 named --
-- Lethariel's ring corner at 1894,-1405 and a Highcourt river crossing -- are in
-- none of them. This builds the same picture offline instead: WP40's height
-- session for the ground and water, the real overlay seam for the streets, and
-- the same run specs the engine is handed. It runs on `main` and on this branch
-- (see `street_geometry.lua` for the `street_plan` fallback), so a before and an
-- after picture are the same window of the same world.
--
-- The coordinates are ANCHOR-RELATIVE, the way every WP13 dump is, and the
-- output is anchor-relative too.
--
-- Plain Lua 5.1 (LuaJIT for the WP40 construction).

local repo = assert(arg[1], "repository root required")
local key = assert(arg[2], "settlement key required")
local seed = assert(arg[3], "world seed required")
local x1 = assert(tonumber(arg[4]), "x1 required")
local z1 = assert(tonumber(arg[5]), "z1 required")
local x2 = assert(tonumber(arg[6]), "x2 required")
local z2 = assert(tonumber(arg[7]), "z2 required")
local out_path = arg[8]
if x1 > x2 then x1, x2 = x2, x1 end
if z1 > z2 then z1, z2 = z2, z1 end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"

local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
	schemas = schemas, canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256, horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)

local palettes = dofile(wp13 .. "/palette.lua")
local elf_parts = dofile(wp13 .. "/elf_parts.lua")(wp13)
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local profile
for index = 1, #settlement.roster do
	if settlement.roster[index].key == key then
		profile = settlement.roster[index]
	end
end
assert(profile, "the roster carries no settlement called " .. key)
local blueprint = dofile(wp40 .. "/r7_" .. key .. "_blueprint.lua")()
local palette = (key == "lethariel") and elf_parts.handles().elf or
	palettes.new(profile.race)
local ax, az = profile.x, profile.z

local function walkable(x, z)
	local terrain_y = height.terrain_height_at(ax + x, az + z)
	local water_y = height.water_surface_at(ax + x, az + z)
	if type(water_y) == "number" and water_y > terrain_y then return water_y end
	return terrain_y
end
local function wet(x, z)
	local terrain_y = height.terrain_height_at(ax + x, az + z)
	local water_y = height.water_surface_at(ax + x, az + z)
	return type(water_y) == "number" and water_y > terrain_y
end
local function overhead(x, z)
	local kind, functional_y =
		height.functional_surface_values_at(ax + x, az + z)
	if kind ~= "bridge_deck" then return nil end
	return functional_y
end

-- 1. The ground of the window: the terrain's top four courses, and the water
-- standing on it, so the picture is a hillside and not a road in the dark.
local cells, seen = {}, {}
local function emit(x, y, z, name, param2)
	local position = x .. ":" .. y .. ":" .. z
	if seen[position] then return end
	seen[position] = true
	cells[#cells + 1] = {x = x, y = y, z = z, name = name,
		param2 = param2 or 0}
end
local GROUND = palette.node("ground")
local SUBSOIL = palette.node("subsoil")
local WATER = palette.maybe("water") or "default:water_source"
local low, high
for z = z1, z2 do
	for x = x1, x2 do
		local terrain_y = height.terrain_height_at(ax + x, az + z)
		local water_y = height.water_surface_at(ax + x, az + z)
		emit(x, terrain_y, z, GROUND)
		for y = terrain_y - 3, terrain_y - 1 do emit(x, y, z, SUBSOIL) end
		if type(water_y) == "number" and water_y > terrain_y then
			for y = terrain_y + 1, water_y do emit(x, y, z, WATER) end
			terrain_y = water_y
		end
		if low == nil or terrain_y < low then low = terrain_y end
		if high == nil or terrain_y > high then high = terrain_y end
	end
end

-- 2. Every overlay run that reaches into the window, in the composition's own
-- order, with the seam's own first-run-wins arbitration -- `emit` keeps the
-- FIRST writer of a cell, which is the rule the successor applies.
local written = 0
for _, run in ipairs(blueprint.overlay.runs) do
	local min_x, max_x, min_z, max_z
	local half = (blueprint.overlay.width - 1) / 2 + 1
	if run.axis == "x" then
		min_x, max_x = run.from, run.to
		min_z, max_z = run.at - half, run.at + half
	else
		min_z, max_z = run.from, run.to
		min_x, max_x = run.at - half, run.at + half
	end
	if min_x <= x2 and max_x >= x1 and min_z <= z2 and max_z >= z1 then
		local piece = blueprint.overlay.run({id = run.id, axis = run.axis,
			at = run.at, from = run.from, to = run.to,
			width = blueprint.overlay.width,
			lamp_spacing = blueprint.overlay.lamp_spacing,
			lamp_phase = run.from, reach = blueprint.overlay.reach,
			overhead = overhead, wet = wet, junctions = run.junctions,
			plain_verge = run.plain_verge, clear_verge = run.clear_verge},
			walkable)
		for _, cell in ipairs(piece.cells) do
			if cell.x >= x1 and cell.x <= x2 and cell.z >= z1 and
					cell.z <= z2 and cell.name ~= "air" then
				local position = cell.x .. ":" .. cell.y .. ":" .. cell.z
				if not seen[position] then written = written + 1 end
				-- A road cell REPLACES the ground it stands on, so the write is
				-- unconditional here and `emit`'s first-wins only arbitrates
				-- between two runs.
				seen[position] = true
				cells[#cells + 1] = {x = cell.x, y = cell.y, z = cell.z,
					name = cell.name, param2 = cell.param2 or 0}
			end
		end
	end
end

table.sort(cells, function(a, b)
	if a.z ~= b.z then return a.z < b.z end
	if a.y ~= b.y then return a.y < b.y end
	if a.x ~= b.x then return a.x < b.x end
	return a.name < b.name
end)

local rows = {("# %s %s, seed %s, window x %d..%d z %d..%d, ground %d..%d\n")
	:format(profile.label, key, seed, x1, x2, z1, z2, low, high)}
rows[#rows + 1] = ("# anchor %d,%d\n"):format(ax, az)
for _, cell in ipairs(cells) do
	rows[#rows + 1] = table.concat({cell.x, cell.y, cell.z, cell.name,
		cell.param2}, "\t") .. "\n"
end
local text = table.concat(rows)
if out_path then
	local file = assert(io.open(out_path, "wb"))
	file:write(text)
	file:close()
else
	io.write(text)
end
io.stderr:write(("%s %s: %d cells, %d of them street\n"):format(key, seed,
	#cells, written))
