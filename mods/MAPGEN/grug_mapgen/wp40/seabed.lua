-- Round 51 T3: the seabed growth rule (sea plan ruling 7; world_zones.md
-- "Seabed growth"), one pure function of the world seed and a column, shared
-- by the writer (world_content.lua) and the renewal (vegetation_density.lua
-- `seabed`), so a meadow regrows where the generator grew it.
--
--   local seabed = dofile(wp40 .. "/seabed.lua")(full_seed_string)
--   seabed.at(x, z, depth) -> "patch", n (n 0..5 a coral, 6 kelp inside the
--       patch) | "kelp" | "seagrass", variant (1..3) | nil
--   seabed.kelp_height(x, z, depth) -> nodes of kelp above the bed
--
-- `depth` is the water over the bed (surface y - bed y). Coral patches (one
-- 16-node cell in four, small or large, the Round 22 Phase 6 rule) grow 2-10
-- deep; kelp meadows (a smooth noise above 600, one column in six) 3-20
-- deep, taller in deeper water and always under the surface; seagrass
-- meadows (their own noise, two columns in three) 2-14 deep, three
-- variants. Deeper water stays bare. Which water classes grow is the
-- caller's (world_content.lua: the belt, bays and channels, never the open
-- sea).
return function(full_seed_string)
	assert(type(full_seed_string) == "string" and full_seed_string ~= "",
		"seabed: full seed missing")
	local floor = math.floor
	local phase = 0
	for i = 1, #full_seed_string do
		phase = (phase * 131 + string.byte(full_seed_string, i)) % 65521
	end
	-- Exact-double integer mixing, no global random state or per-voxel SHA
	-- (world_content.lua's own hash, unchanged).
	local function hash(x, y, z, salt)
		local value = (x * 374761 + y * 193939 + z * 668265 + phase * 69069 + salt * 83491) %
			16777213
		return (value * 48271) % 16777213
	end
	-- A separate mixed stream prevents the visible axis-aligned runs produced
	-- by the general linear plant hash.
	local function reef_hash(x, z, salt)
		local a = hash(x * 37 + z * 11, salt, x * 7 - z * 29, 151)
		return hash(a % 4093, x * 53 - z * 17, floor(a / 4093), salt + 157)
	end
	-- Smooth value noise in [0,1024) on the reef hash lattice (meadows follow
	-- it, so their edges are soft instead of cell squares).
	local function reef_noise(x, z, period, salt)
		local ix, iz = floor(x / period), floor(z / period)
		local tx, tz = (x - ix * period) / period, (z - iz * period) / period
		tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
		local a = reef_hash(ix, iz, salt) % 1024
		local b = reef_hash(ix + 1, iz, salt) % 1024
		local c = reef_hash(ix, iz + 1, salt) % 1024
		local d = reef_hash(ix + 1, iz + 1, salt) % 1024
		return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz
	end

	local M = {CORAL_MIN = 2, CORAL_MAX = 10, KELP_MIN = 3, KELP_MAX = 20,
		SEAGRASS_MIN = 2, SEAGRASS_MAX = 14, KELP_TALLEST = 15}
	M.hash, M.reef_hash, M.reef_noise = hash, reef_hash, reef_noise

	function M.at(x, z, depth)
		if depth < M.CORAL_MIN or depth > M.KELP_MAX then return nil end
		if depth <= M.CORAL_MAX then
			local cell_x, cell_z = floor(x / 16), floor(z / 16)
			if reef_hash(cell_x, cell_z, 101) % 4 == 0 then
				local dx = x - cell_x * 16 - (3 + reef_hash(cell_x, cell_z, 103) % 10)
				local dz = z - cell_z * 16 - (3 + reef_hash(cell_x, cell_z, 107) % 10)
				local swapped = reef_hash(cell_x, cell_z, 109) % 2 == 1
				local long = swapped and dz or dx
				local short = swapped and dx or dz
				local size = reef_hash(cell_x, cell_z, 111) % 2 == 0 and 15 or 26
				if long * long + 2 * short * short <= size and reef_hash(x, z, 113) % 5 ~= 0 then
					return "patch", reef_hash(x, z, 127) % 7
				end
			end
		end
		if depth >= M.KELP_MIN and reef_noise(x, z, 24, 131) > 600 and
				reef_hash(x, z, 137) % 6 == 0 then
			return "kelp"
		end
		if depth <= M.SEAGRASS_MAX and reef_noise(x, z, 20, 151) > 480 and
				reef_hash(x, z, 157) % 3 ~= 0 then
			return "seagrass", 1 + reef_hash(x, z, 163) % 3
		end
		return nil
	end

	-- Kelp height: 2-6 nodes, one more per two nodes of water beyond 6, never
	-- above depth - 1 (the stem stays under water) nor KELP_TALLEST.
	function M.kelp_height(x, z, depth)
		local extra = depth > 6 and floor((depth - 6) / 2) or 0
		local height = 2 + reef_hash(x, z, 139) % 5 + extra
		if height > depth - 1 then height = depth - 1 end
		if height > M.KELP_TALLEST then height = M.KELP_TALLEST end
		return height
	end
	-- A kelp inside a coral patch keeps the patch's height rule (up to 6).
	function M.patch_kelp_height(depth)
		return math.min(6, depth - 1)
	end
	return M
end
