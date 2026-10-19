-- Round 51 follow-up FW: how meadows end (the user's item 1: seagrass in
-- sharp outlines). Reads the pure seabed rule (wp40/seabed.lua) of a seed
-- over a square of columns at one depth and prints, for seagrass, kelp and
-- coral, the share of grown columns by their grown neighbours (8 around:
-- 0 a single tuft, 1-3 the meadow edge, 4-8 the core), and for seagrass and
-- kelp the fill by distance from the meadow outline of before (the noise
-- threshold T3 cut at: seagrass 480, kelp 600; negative = outside), so a
-- hard edge shows as a full core and nothing outside.
--
--   luajit tools/r51_fw/meadow_edge.lua REPO [SEED] [DEPTH] [SIZE]
--
-- Defaults: seed 12345, depth 6 (every kind may grow), 1024 x 1024 columns
-- from (0, 0). Comparisons, not targets.
local repo = assert(arg[1], "usage: meadow_edge.lua REPO [SEED] [DEPTH] [SIZE]")
local seed, depth, size = arg[2] or "12345", tonumber(arg[3] or "6"), tonumber(arg[4] or "1024")
local rule = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seabed.lua")(seed)
local KINDS = {"seagrass", "kelp", "coral"}
local OUTLINE = {seagrass = {20, 151, 480}, kelp = {24, 131, 600}}

local grid = {}
local function index(x, z) return z * size + x + 1 end
local totals = {seagrass = 0, kelp = 0, coral = 0}
for z = 0, size - 1 do
	for x = 0, size - 1 do
		local kind = rule.at(x, z, depth)
		if kind == "patch" then kind = "coral" end
		grid[index(x, z)] = kind or false
		if kind then totals[kind] = totals[kind] + 1 end
	end
end
print(("seed %s, depth %d, %d x %d columns: seagrass %.1f %%, kelp %.1f %%, coral %.1f %%")
	:format(seed, depth, size, size, 100 * totals.seagrass / (size * size),
	100 * totals.kelp / (size * size), 100 * totals.coral / (size * size)))

for _, kind in ipairs(KINDS) do
	local bins = {0, 0, 0}
	for z = 1, size - 2 do
		for x = 1, size - 2 do
			if grid[index(x, z)] == kind then
				local n = 0
				for dz = -1, 1 do
					for dx = -1, 1 do
						if (dx ~= 0 or dz ~= 0) and grid[index(x + dx, z + dz)] == kind then n = n + 1 end
					end
				end
				local bin = n == 0 and 1 or (n <= 3 and 2 or 3)
				bins[bin] = bins[bin] + 1
			end
		end
	end
	local all = math.max(1, bins[1] + bins[2] + bins[3])
	print(("%-8s %7d columns by grown neighbours: 0 (tuft) %.1f %%, 1-3 (edge) %.1f %%, " ..
		"4-8 (core) %.1f %%"):format(kind, all, 100 * bins[1] / all, 100 * bins[2] / all,
		100 * bins[3] / all))
end

-- Signed distance from the old outline (8-neighbour steps; inside > 0).
for _, kind in ipairs({"seagrass", "kelp"}) do
	local o = OUTLINE[kind]
	local inside = {}
	for z = 0, size - 1 do
		for x = 0, size - 1 do inside[index(x, z)] = rule.reef_noise(x, z, o[1], o[2]) > o[3] end
	end
	local MAX = 10
	local dist = {}
	local queue, head = {}, 1
	for z = 0, size - 1 do
		for x = 0, size - 1 do
			local i = index(x, z)
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local xx, zz = x + d[1], z + d[2]
				if xx >= 0 and zz >= 0 and xx < size and zz < size and
						inside[index(xx, zz)] ~= inside[i] then
					if not dist[i] then dist[i] = 1; queue[#queue + 1] = {x, z} end
				end
			end
		end
	end
	while head <= #queue do
		local x, z = queue[head][1], queue[head][2]
		head = head + 1
		local d0 = dist[index(x, z)]
		if d0 < MAX then
			for dz = -1, 1 do
				for dx = -1, 1 do
					local xx, zz = x + dx, z + dz
					if xx >= 0 and zz >= 0 and xx < size and zz < size then
						local j = index(xx, zz)
						if not dist[j] and inside[j] == inside[index(x, z)] then
							dist[j] = d0 + 1
							queue[#queue + 1] = {xx, zz}
						end
					end
				end
			end
		end
	end
	local grown, columns = {}, {}
	for z = 0, size - 1 do
		for x = 0, size - 1 do
			local i = index(x, z)
			local d = dist[i] or MAX + 1
			if d <= MAX then
				local signed = inside[i] and d or -d
				columns[signed] = (columns[signed] or 0) + 1
				if grid[i] == kind then grown[signed] = (grown[signed] or 0) + 1 end
			end
		end
	end
	local parts = {}
	for d = -MAX, MAX do
		if columns[d] then
			parts[#parts + 1] = ("%+d:%.0f"):format(d, 100 * (grown[d] or 0) / columns[d])
		end
	end
	print(("%-8s fill %% by distance from the old outline (out - / in +): %s"):format(kind,
		table.concat(parts, " ")))
end
