-- Round 29 Lane M-geo: zone-field check of the wider Battlegrounds (LuaJIT).
--
--   luajit tools/r29_mgeo/zone_check.lua [REPO] [FRONT_BIAS] SEED...
--
-- Builds the checked zone field (zone_field.new_checked, the construction
-- self-check and its fallback) of each SEED from the mapgen source, with
-- `front_bias` replaced by FRONT_BIAS when it is a number ("-" keeps the
-- source value), and prints per seed: the warp scale and narrowest dragon
-- strait, land area per zone (16-node grid) of the four Battlegrounds zones
-- and the six contested 31-40 zones with both factions' totals, the
-- Battlegrounds border |z| (mean of the north and south border on every x
-- column), the gameplay neighbour pairs (simple_map.lua's rule) and their
-- digest, the zone of the four boat-start key points, and every anchor
-- bulge with a reach above 0 (an anchor the warped border would cut).
local repo = arg[1] or "."
local bias_arg = arg[2] or "-"
local seeds = {}
for i = 3, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then seeds = {"1", "7", "42", "1234", "20261002"} end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(dir .. "/source/simple_map.lua")
local zone_field = dofile(dir .. "/zone_field.lua")
local params = source.zone_field
if tonumber(bias_arg) then params.front_bias = tonumber(bias_arg) end
local zones = source.zones
local FRONT = {34, 35, 36, 37}
local DONORS = {5, 10, 16, 21, 26, 32}
local floor, min, max, abs = math.floor, math.min, math.max, math.abs

print(("front_bias %d"):format(params.front_bias))
for _, seed in ipairs(seeds) do
	local t0 = os.clock()
	local field = zone_field.new_checked(seed, source, params)
	local sample = field.sample
	local step = params.neighbor_grid
	local c = params.check
	local W = floor((c.max_x - c.min_x) / step) + 1
	local H = floor((c.max_z - c.min_z) / step) + 1
	local area, pair_edges, previous_row = {}, {}, {}
	-- per x column: the smallest and largest z of Battlegrounds land
	local front_lo, front_hi = {}, {}
	for j = 0, H - 1 do
		local z = c.min_z + j * step
		local row = {}
		for i = 0, W - 1 do
			local n = sample(c.min_x + i * step, z)
			row[i] = n
			if n ~= 0 then
				area[n] = (area[n] or 0) + step * step
				if n >= 34 and n <= 37 then
					front_lo[i] = min(front_lo[i] or z, z)
					front_hi[i] = max(front_hi[i] or z, z)
				end
				local left = i > 0 and row[i - 1] or 0
				if left ~= 0 and left ~= n then
					local key = min(left, n) * 64 + max(left, n)
					pair_edges[key] = (pair_edges[key] or 0) + 1
				end
				local below = previous_row[i]
				if below and below ~= 0 and below ~= n then
					local key = min(below, n) * 64 + max(below, n)
					pair_edges[key] = (pair_edges[key] or 0) + 1
				end
			end
		end
		previous_row = row
	end
	local pairs_list = {}
	for key, edges in pairs(pair_edges) do
		if edges * step >= params.neighbor_min_border then
			pairs_list[#pairs_list + 1] = ("%d-%d"):format(floor(key / 64), key % 64)
		end
	end
	table.sort(pairs_list)
	local hash = 5381
	local joined = table.concat(pairs_list, ",")
	for k = 1, #joined do hash = (hash * 33 + joined:byte(k)) % 4294967296 end
	-- mean Battlegrounds border on the columns between the two straits' coasts
	local sum_lo, sum_hi, cols = 0, 0, 0
	for i = 0, W - 1 do
		local x = c.min_x + i * step
		if front_lo[i] and x >= -2300 and x <= 2300 then
			sum_lo, sum_hi, cols = sum_lo + front_lo[i], sum_hi + front_hi[i], cols + 1
		end
	end
	local check = field.check
	local last = check.tries[#check.tries]
	print(("seed %s: scale %.1f tries %d strait %d pairs %d digest %08x (%.1f s)"):format(seed,
		check.scale, #check.tries, last.stats.min_strait, #pairs_list, hash, os.clock() - t0))
	print(("  border mean z: south %.0f north %.0f"):format(sum_lo / cols, sum_hi / cols))
	local parts, accord, throng, front = {}, 0, 0, 0
	for _, n in ipairs(FRONT) do
		parts[#parts + 1] = ("%d:%d"):format(n, (area[n] or 0) / 1000)
		front = front + (area[n] or 0)
	end
	print("  front area (k nodes) " .. table.concat(parts, " ") .. (" total %d"):format(front / 1000))
	parts = {}
	for _, n in ipairs(DONORS) do parts[#parts + 1] = ("%d:%d"):format(n, (area[n] or 0) / 1000) end
	for n = 1, 16 do accord = accord + (area[n] or 0) end
	for n = 17, 32 do throng = throng + (area[n] or 0) end
	print("  donor area (k nodes) " .. table.concat(parts, " ") ..
		(" accord %d throng %d"):format(accord / 1000, throng / 1000))
	parts = {}
	for _, kp in ipairs(field.keypoints) do
		if kp.kind == "boat_start" then
			parts[#parts + 1] = ("%s=%d"):format(kp.id:match("^boat_(%a+_%a+)"), sample(kp.x, kp.z))
		end
	end
	print("  boat starts " .. table.concat(parts, " "))
	parts = {}
	for _, bu in ipairs(field.diag.bulges) do
		if bu.reach > 0 then parts[#parts + 1] = ("%s(%.0f)"):format(bu.id:match("^[^:]+:[^:]+"), bu.reach) end
	end
	print("  bulges with reach " .. (#parts > 0 and table.concat(parts, " ") or "none"))
	print("  pairs " .. joined)
end
