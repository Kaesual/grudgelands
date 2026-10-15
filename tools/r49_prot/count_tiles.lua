-- Round 49 lane PROT: how many full-preparation tiles the fill-floor bottom
-- (`preparation_plan.lua` M.FILL_FLOOR, mapgen-native-plan.md §4.4) changes,
-- and how many chunks a full-world preparation then generates in addition
-- (LuaJIT, no engine, no generation).
--
--   luajit tools/r49_prot/count_tiles.lua REPO [seed ...]
--
-- Per seed it builds main's real preparation authority (the seed fleet's
-- runtime, `tools/seed_fleet/runtime.lua` in emerge mode: R.authority is what
-- the engine's main environment publishes as `preparation_source`) and the
-- production full plan (chunksize 5, generate distance 10, flight ceiling
-- 600). A tile changes only when its window's lowest surface envelope lies at
-- or above y 144 (bottom - 176 >= -32 before alignment). So:
--   1. a coarse pass reads every fourth column of every tile plus its fitted
--      boxes; a coarse low is never below the exact one, so a window whose
--      coarse low is under 144 is unchanged;
--   2. for every remaining (candidate) tile, the production `scan` gives each
--      window tile's exact statistic and the production `select` resolves
--      the tile twice: with today's bottom (FILL_FLOOR disabled) and with the
--      fill floor. The difference is the extra chunks.
-- Prints per seed: tiles, candidates, changed tiles, extra chunks and the
-- highest coarse window low (how close the highest tile came to changing).
local repo = assert(arg[1], "usage: count_tiles.lua REPO [seed ...]")
local seeds = {}
for index = 2, #arg do seeds[#seeds + 1] = arg[index] end
if #seeds == 0 then seeds = {"4242424242"} end

local plan_api = dofile(repo .. "/mods/CORE/grug_core/preparation_plan.lua")
local FILL_FLOOR = plan_api.FILL_FLOOR
local GEOMETRY = {x = 5, y = 5, z = 5}
local OPTIONS = {generate_distance = 10, flight_ceiling = 600}
local settlement = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
local floor = math.floor

local function select_with(plan, scanner, index, fill_floor)
	plan_api.FILL_FLOOR = fill_floor
	plan.cursor, plan.selection = index - 1, nil
	assert(plan_api.select(plan, scanner), "selection not resolved")
	local selection = plan.selection
	plan.selection = nil
	plan_api.FILL_FLOOR = FILL_FLOOR
	return selection
end

for _, seed in ipairs(seeds) do
	local t0 = os.clock()
	local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed, "emerge")
	local source = R.authority.preparation_source
	local zones = R.authority.zones_session
	local identities = {}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "start" then
			local a = zones.anchor(profile.zone_id, "start")
			identities[#identities + 1] = {race_id = profile.key,
				anchor = {x = a.x, y = a.y, z = a.z}}
		end
	end
	local plan = plan_api.new("full", GEOMETRY, identities, OPTIONS)
	local nx, nz = plan.counts.x, plan.counts.z
	local wx, wz = plan.window.x, plan.window.z
	local size = GEOMETRY.x * 16
	local function origin(index)
		local tx = (index - 1) % nx
		local tz = (index - 1 - tx) / nx
		return tx, tz, plan.bounds.min.x + tx * size, plan.bounds.min.z + tz * size
	end
	local t1 = os.clock()

	-- 1. Coarse lows (never below the exact ones).
	local coarse = {}
	for index = 1, plan.total do
		local _, _, x, z = origin(index)
		local _, low = source.tile_bounds({x = x, z = z},
			{x = x + size - 1, z = z + size - 1})
		for dz = 0, size - 1, 4 do
			for dx = 0, size - 1, 4 do
				local column_low = source.column_bounds(x + dx, z + dz)
				if column_low < low then low = column_low end
			end
		end
		coarse[index] = low
	end
	local t2 = os.clock()

	-- 2. Candidates and their exact selections.
	local exact = {}
	local function exact_stat(index)
		if exact[index] then return exact[index] end
		local _, _, x, z = origin(index)
		local radius = source.tile_bounds({x = x, z = z},
			{x = x + size - 1, z = z + size - 1})
		local scanner = {next = index, stats = {}, kept_row = 0}
		plan_api.scan(plan, scanner, source, (size + 2 * radius) * (size + 2 * radius))
		exact[index] = assert(scanner.stats[index], "exact statistic incomplete")
		return exact[index]
	end
	local candidates, changed, extra, low_min = 0, 0, 0, math.huge
	local highest_window = -math.huge
	for index = 1, plan.total do
		local tx, tz = origin(index)
		local window_low = math.huge
		for row = math.max(0, tz - wz), math.min(nz - 1, tz + wz) do
			for column = math.max(0, tx - wx), math.min(nx - 1, tx + wx) do
				window_low = math.min(window_low, coarse[row * nx + column + 1])
			end
		end
		if window_low > highest_window then highest_window = window_low end
		if plan_api.align(window_low - plan.reach, GEOMETRY.y) >
				plan_api.align(FILL_FLOOR, GEOMETRY.y) then
			candidates = candidates + 1
			local stats = {}
			for row = math.max(0, tz - wz), math.min(nz - 1, tz + wz) do
				for column = math.max(0, tx - wx), math.min(nx - 1, tx + wx) do
					stats[row * nx + column + 1] = exact_stat(row * nx + column + 1)
				end
			end
			local scanner = {next = plan.total + 1, stats = stats,
				kept_row = math.max(0, tz - wz)}
			local before = select_with(plan, scanner, index, math.huge)
			local after = select_with(plan, scanner, index, FILL_FLOOR)
			assert(after.y_max == before.y_max and after.y_min <= before.y_min,
				"the fill floor only lowers a bottom")
			if after.y_min < before.y_min then
				changed = changed + 1
				extra = extra + (before.y_min - after.y_min) / (GEOMETRY.y * 16)
				if before.y_min < low_min then low_min = before.y_min end
			end
		end
	end
	local t3 = os.clock()
	print(("seed %s tiles %d candidates %d changed %d extra chunks %d" ..
		" (lowest old bottom of a changed tile %s; highest coarse window low %d);" ..
		" exact tiles %d; build %.0f s, coarse %.0f s, exact %.0f s"):format(seed,
		plan.total, candidates, changed, extra, tostring(low_min), highest_window,
		(function() local n = 0 for _ in pairs(exact) do n = n + 1 end return n end)(),
		t1 - t0, t2 - t1, t3 - t2))
end
