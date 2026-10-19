-- Round 51 T3: the seabed growth rule (sea plan ruling 7; world_zones.md
-- "Seabed growth"), one pure function of the world seed and a column, shared
-- by the writer (world_content.lua) and the renewal (vegetation_density.lua
-- `seabed`), so a meadow regrows where the generator grew it.
--
--   local seabed = dofile(wp40 .. "/seabed.lua")(full_seed_string)
--   seabed.at(x, z, depth) -> "patch", n (n 0..5 a coral, 6 kelp inside the
--       patch) | "kelp" | "seagrass", variant (1..3) | nil
--   seabed.kelp_height(x, z, depth) -> nodes of kelp above the bed
--   seabed.lake_at(x, z, depth) -> "lily", rotation (0..3) | "weed", height
--       (1..4 nodes above the bed) | nil, for wild lake water (Round 51
--       follow-up FW; the caller decides which water that is)
--
-- `depth` is the water over the bed (surface y - bed y). Coral patches (one
-- 16-node cell in four, small or large, the Round 22 Phase 6 rule) grow 2-10
-- deep; kelp meadows (a smooth noise, one column in six in the core) 3-20
-- deep, taller in deeper water and always under the surface; seagrass
-- meadows (their own noise, two columns in three in the core) 2-14 deep,
-- three variants. Deeper water stays bare. Which water classes grow is the
-- caller's (world_content.lua: the belt, bays and channels, never the open
-- sea).
--
-- Soft edges (Round 51 follow-up FW, the user's item 1): no meadow or patch
-- has a sharp outline. A meadow's fill falls from its core's over a band of
-- its noise (EDGE, about 3-6 nodes wide at the noise's usual slope) and a
-- few single tufts stand beyond it (TUFT, about as wide again); a coral
-- patch keeps its ellipse and gains a sparse rim and a few loose pieces
-- round it. Toward the deepest depth a meadow grows the fill thins as well.
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
	-- A roll in [0, 4096) per column: the reef hash squared twice (exact
	-- doubles: below 2^48), since its low bits alone still run in diagonal
	-- stripes when a fill compares against them.
	local function roll(x, z, salt)
		local h = reef_hash(x, z, salt)
		h = (h * h + 7919) % 16777213
		h = (h * h + 104729) % 16777213
		return h % 4096
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
	M.hash, M.reef_hash, M.reef_noise, M.roll = hash, reef_hash, reef_noise, roll
	-- The meadows' fill by their noise value (0..1024), in 1/4096: the core
	-- from `core` up, falling linearly over `core`..`edge` to `edge_fill`,
	-- single tufts at `tuft_fill` over `edge`..`tuft`, nothing below.
	M.SEAGRASS_FADE = {core = 560, fill = 2731, edge = 400, edge_fill = 160, tuft = 290,
		tuft_fill = 80}
	M.KELP_FADE = {core = 660, fill = 683, edge = 560, edge_fill = 80, tuft = 480,
		tuft_fill = 40}
	-- A coral patch: its ellipse (q <= size) four in five, the rim (q <=
	-- RIM * size) at RIM_FILL, loose pieces (q <= LOOSE * size) at
	-- LOOSE_FILL, in 1/4096.
	M.CORAL_FILL, M.CORAL_RIM, M.CORAL_RIM_FILL = 3277, 2, 1024
	M.CORAL_LOOSE, M.CORAL_LOOSE_FILL = 3, 205
	local function fill(fade, n)
		if n >= fade.core then return fade.fill end
		if n >= fade.edge then
			return fade.edge_fill + (fade.fill - fade.edge_fill) * (n - fade.edge) /
				(fade.core - fade.edge)
		end
		if n >= fade.tuft then return fade.tuft_fill end
		return 0
	end
	M.fill = fill
	-- The deep end fades too: the fill thins over the last DEEP_FADE nodes
	-- of depth (coral 8-10, seagrass 12-14, kelp 18-20), so a meadow does not
	-- end on a depth line either.
	M.DEEP_FADE = 3
	local function deep_fade(depth, deepest)
		local left = deepest + 1 - depth
		if left > M.DEEP_FADE then return 1 end
		return left / (M.DEEP_FADE + 1)
	end
	M.deep_fade = deep_fade

	-- The coral patch whose ellipse, rim or loose pieces hold this column:
	-- its own 16-node cell first, then the eight round it (a patch near its
	-- cell's side reaches across), the first that grows here wins.
	local CELLS = {{0, 0}, {-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}}
	local function coral_at(x, z, depth)
		local home_x, home_z = floor(x / 16), floor(z / 16)
		local chance_roll = roll(x, z, 113)
		for c = 1, #CELLS do
			local cell_x, cell_z = home_x + CELLS[c][1], home_z + CELLS[c][2]
			if reef_hash(cell_x, cell_z, 101) % 4 == 0 then
				local dx = x - cell_x * 16 - (3 + reef_hash(cell_x, cell_z, 103) % 10)
				local dz = z - cell_z * 16 - (3 + reef_hash(cell_x, cell_z, 107) % 10)
				if dx >= -10 and dx <= 10 and dz >= -10 and dz <= 10 then
					local swapped = reef_hash(cell_x, cell_z, 109) % 2 == 1
					local long = swapped and dz or dx
					local short = swapped and dx or dz
					local size = reef_hash(cell_x, cell_z, 111) % 2 == 0 and 15 or 26
					local q = long * long + 2 * short * short
					local chance = q <= size and M.CORAL_FILL or
						q <= M.CORAL_RIM * size and M.CORAL_RIM_FILL or
						q <= M.CORAL_LOOSE * size and M.CORAL_LOOSE_FILL or 0
					if chance_roll < chance * deep_fade(depth, M.CORAL_MAX) then
						return true
					end
				end
			end
		end
		return false
	end

	function M.at(x, z, depth)
		if depth < M.CORAL_MIN or depth > M.KELP_MAX then return nil end
		if depth <= M.CORAL_MAX and coral_at(x, z, depth) then
			return "patch", reef_hash(x, z, 127) % 7
		end
		if depth >= M.KELP_MIN and roll(x, z, 137) <
				fill(M.KELP_FADE, reef_noise(x, z, 24, 131)) * deep_fade(depth, M.KELP_MAX) then
			return "kelp"
		end
		if depth <= M.SEAGRASS_MAX and roll(x, z, 157) <
				fill(M.SEAGRASS_FADE, reef_noise(x, z, 20, 151)) * deep_fade(depth, M.SEAGRASS_MAX) then
			return "seagrass", 1 + reef_hash(x, z, 163) % 3
		end
		return nil
	end

	-- Wild lakes (Round 51 follow-up FW, the user's item 8): waterlily pads
	-- in clusters on the surface of water 1-3 deep (near the shore, since a
	-- lake deepens away from it) and waterweed clumps on the bed 3-10 deep,
	-- 1-4 nodes tall and always under the surface; both fade out like the
	-- sea's meadows. One plant per column, the lily first.
	M.LILY_MIN, M.LILY_MAX, M.WEED_MIN, M.WEED_MAX = 1, 3, 3, 10
	M.LILY_FADE = {core = 640, fill = 1638, edge = 520, edge_fill = 120, tuft = 430,
		tuft_fill = 60}
	M.WEED_FADE = {core = 620, fill = 1229, edge = 500, edge_fill = 100, tuft = 400,
		tuft_fill = 40}
	function M.lake_at(x, z, depth)
		if depth >= M.LILY_MIN and depth <= M.LILY_MAX and
				roll(x, z, 243) < fill(M.LILY_FADE, reef_noise(x, z, 10, 241)) then
			return "lily", reef_hash(x, z, 247) % 4
		end
		if depth >= M.WEED_MIN and depth <= M.WEED_MAX and
				roll(x, z, 253) < fill(M.WEED_FADE, reef_noise(x, z, 14, 251)) then
			local height = 1 + reef_hash(x, z, 257) % 4
			if height > depth - 1 then height = depth - 1 end
			return "weed", height
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
