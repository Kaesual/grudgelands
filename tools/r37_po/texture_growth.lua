-- Round 37 lane PO, audit CORE-05: the minimap's client texture growth
-- (LuaJIT, no engine; a measurement, not a fixture).
--
--   luajit tools/r37_po/texture_growth.lua [repo]
--
-- The client never frees a texture it built from modifiers
-- (docs/design/world_map.md "Cells"), and the minimap builds one per grid
-- cell the player enters: its texture string is a function of the cell
-- (minimap_view.lua V.origin, V.texture), so distinct textures = distinct
-- cells entered. Loads the REAL minimap_view.lua with the REAL atlas bounds
-- and base sizes (base.lua QUALITY) and counts, per map quality:
--   - cells per 1,000 nodes travelled straight along an axis and diagonally;
--   - the bytes of one texture as RGBA8 (pixels x pixels x 4) and as the
--     next power of two (what a GPU without non-power-of-two support pads to);
--   - distinct textures after 1 and 3 hours of travel at walking (4 nodes/s),
--     land-mount (6.4, 8) and flying-mount (8, 12) speeds on a deterministic
--     tour inside the world bounds (straight legs of 150-600 nodes with
--     random turns, reflected at the world's edge), so revisited cells count
--     once, as on the client.
-- Prints one table per quality. Numbers are comparisons, not targets.
local repo = arg[1] or "."
local V = dofile(repo .. "/mods/PLAYER/grug_map/minimap_view.lua")
-- the atlas world bounds (atlas.lua WORLD) and base sizes (base.lua QUALITY)
local BOUNDS = {min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}
local QUALITY = {normal = {width = 1080, height = 960}, high = {width = 3600, height = 3200}}
do
	-- read both from the real files, so a change there shows here
	local atlas = io.open(repo .. "/mods/PLAYER/grug_map/atlas.lua"):read("*a")
	local x0, x1, z0, z1 = atlas:match("min_x = (%-?%d+), max_x = (%-?%d+), min_z = (%-?%d+), max_z = (%-?%d+)")
	BOUNDS = {min_x = tonumber(x0), max_x = tonumber(x1), min_z = tonumber(z0), max_z = tonumber(z1)}
	local base = io.open(repo .. "/mods/PLAYER/grug_map/base.lua"):read("*a")
	for quality, row in pairs(QUALITY) do
		local w, h = base:match(quality .. " = {width = (%d+), height = (%d+)")
		row.width, row.height = tonumber(w), tonumber(h)
	end
end

local function pow2(n)
	local p = 1
	while p < n do p = p * 2 end
	return p
end

-- deterministic LCG in [0, 1)
local seed = 12345
local function rand()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function straight(v, dx, dz, nodes)
	local seen, count = {}, 0
	local x, z = 0, 0
	local len = math.sqrt(dx * dx + dz * dz)
	for i = 0, nodes * 4 do
		local t = i / 4
		local cx, cy = V.cell(v, x + dx / len * t, z + dz / len * t)
		local key = cx .. "/" .. cy
		if not seen[key] then seen[key], count = true, count + 1 end
	end
	return count
end

-- Distinct cells after each of `hours` on the tour at `speed` nodes/s.
local function tour(v, speed, hours)
	seed = 12345
	local seen, count, results = {}, 0, {}
	local x, z = 0, 0
	local angle = rand() * 2 * math.pi
	local leg = 150 + rand() * 450
	local step = 1 -- node
	local per_hour = speed * 3600
	local margin = 50
	for hour = 1, hours do
		for _ = 1, per_hour / step do
			x, z = x + math.cos(angle) * step, z + math.sin(angle) * step
			if x < BOUNDS.min_x + margin or x > BOUNDS.max_x - margin then
				angle = math.pi - angle
				x = math.max(BOUNDS.min_x + margin, math.min(BOUNDS.max_x - margin, x))
			end
			if z < BOUNDS.min_z + margin or z > BOUNDS.max_z - margin then
				angle = -angle
				z = math.max(BOUNDS.min_z + margin, math.min(BOUNDS.max_z - margin, z))
			end
			leg = leg - step
			if leg <= 0 then
				angle = angle + (rand() - 0.5) * math.pi
				leg = 150 + rand() * 450
			end
			local cx, cy = V.cell(v, x, z)
			local key = cx * 100000 + cy
			if not seen[key] then seen[key], count = true, count + 1 end
		end
		results[hour] = count
	end
	return results
end

local SPEEDS = {{"walk", 4}, {"land mount", 6.4}, {"fast land / slow flying", 8}, {"fast flying", 12}}
for _, quality in ipairs({"normal", "high"}) do
	local base = QUALITY[quality]
	local v = V.new({quality = quality, width = base.width, height = base.height, tiles = {}}, BOUNDS)
	local bytes = v.pixels * v.pixels * 4
	local padded = pow2(v.pixels) * pow2(v.pixels) * 4
	local cell_nodes = v.grid * v.npp
	print(("== %s: grid %d base px = %.1f nodes per cell, texture %dx%d px, %.1f KB RGBA8 (%.1f KB padded to %dx%d)"):format(
		quality, v.grid, cell_nodes, v.pixels, v.pixels, bytes / 1024, padded / 1024, pow2(v.pixels), pow2(v.pixels)))
	local axis = straight(v, 1, 0, 1000)
	local diagonal = straight(v, 1, 1, 1000)
	print(("   straight 1,000 nodes: %d textures along an axis (%.2f MB), %d diagonally (%.2f MB)"):format(
		axis, axis * bytes / 1048576, diagonal, diagonal * bytes / 1048576))
	for _, speed in ipairs(SPEEDS) do
		local r = tour(v, speed[2], 3)
		print(("   %-24s %5.1f n/s: 1 h %6d textures %7.1f MB (padded %7.1f), 3 h %6d textures %7.1f MB"):format(
			speed[1], speed[2], r[1], r[1] * bytes / 1048576, r[1] * padded / 1048576,
			r[3], r[3] * bytes / 1048576))
	end
end
