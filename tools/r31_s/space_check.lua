-- Round 31 lane S: is there room for the fortress beside the middle road?
--
--   luajit tools/r31_s/space_check.lua [REPO] [SEED ...]
--
-- Per SEED (default 42 7 2026) the world with its roads is built as main
-- builds it (tools/r25_road_poi/world.lua). For Ashenward March and
-- Bannerbreak Mesa it walks the middle road (Highcourt - Gor Drazhak) inside
-- the zone and tries fortress centres beside it, on both sides, at lateral
-- offsets of 40..120 nodes. A centre fits when the square core plus an
-- 8-node collar stays in the zone and on land, keeps 6 nodes (2 corridor + 4)
-- off every road edge and 16 nodes off every other anchor's core, and the
-- natural ground under the core varies by at most 40 nodes (world_zones.md
-- §8: above that the terrain needs a calm bowl). Prints, per core size, how
-- many centres fit and the flattest ones; then, because an anchor keeps one
-- x/z on every seed, the fixed centres of a 16-node grid that fit the 49
-- core within 72 nodes of the middle road on every seed given. Today's road
-- is routed without a fortress; a reserved fortress bends it instead. A
-- report, not a gate.
local repo = arg[1] or "."
local seeds = {}
for i = 2, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then seeds = {"42", "7", "2026"} end

local SIZES = {49, 65}
local COLLAR, ROAD_GAP, ANCHOR_GAP, RELIEF = 8, 6, 16, 40
local CORE = {start = 128, village = 24, outpost = 16, bandit_home = 24,
	bandit_frontier = 16, mine = 20, mirefolk = 16, clash = 16, dragon = 32,
	apex_mine = 32, rare_route = 12}

local world = dofile(repo .. "/tools/r25_road_poi/world.lua")
-- fixed centres (anchors do not move per seed) that fit on every seed with
-- the 49-node core and stand beside that seed's middle road
local GRID, NEAR = 16, 24 + 48
local fixed = {}
for _, seed in ipairs(seeds) do
	local W = world(repo, seed)
	local S, column = W.session, W.planner_source.column_values_at
	local hc = S.anchor("elandor_highcourt", "capital")
	local gd = S.anchor("kragmar_gor_drazhak", "capital")
	local middle
	for _, r in ipairs(W.built.roads) do
		if (r.a == hc.id and r.b == gd.id) or (r.a == gd.id and r.b == hc.id) then middle = r end
	end
	assert(middle, "middle road, seed " .. seed)
	-- every road's points, for the corridor gap
	local road_points = {}
	for _, r in ipairs(W.built.roads) do
		for i = 1, #r.X, 2 do road_points[#road_points + 1] = {r.X[i], r.Z[i], r.hw or 4} end
	end
	local anchors = {}
	for _, a in ipairs(W.source.anchors) do
		local half = (CORE[a.template_id] or (a.slot_id == "capital" and 266) or 16) / 2
		anchors[#anchors + 1] = {a.position.x, a.position.z, half}
	end
	local function fits_at(zone, cx, cz, half)
		local reach = half + COLLAR
		for z = cz - reach, cz + reach, 4 do
			for x = cx - reach, cx + reach, 4 do
				if S.id_at(x, z) ~= zone or S.water_class_at(x, z) ~= "land" then return nil end
			end
		end
		for _, p in ipairs(road_points) do
			local dx = math.max(0, math.abs(p[1] - cx) - half)
			local dz = math.max(0, math.abs(p[2] - cz) - half)
			if dx * dx + dz * dz < (p[3] + ROAD_GAP) * (p[3] + ROAD_GAP) then return nil end
		end
		for _, a in ipairs(anchors) do
			local gap = half + a[3] + ANCHOR_GAP
			if math.abs(a[1] - cx) < gap and math.abs(a[2] - cz) < gap then return nil end
		end
		local low, high
		for z = cz - half, cz + half, 2 do
			for x = cx - half, cx + half, 2 do
				local y = select(6, column(x, z))
				low = (low and math.min(low, y)) or y
				high = (high and math.max(high, y)) or y
			end
		end
		if high - low > RELIEF then return nil end
		return high - low
	end
	for _, zone in ipairs({"elandor_ashenward_march", "kragmar_bannerbreak_mesa"}) do
		local sign = zone:sub(1, 7) == "elandor" and -1 or 1
		for gz = 360, 1200, GRID do
			for gx = -240, 240, GRID do
				local cz = sign * gz
				local near = false
				for i = 1, #middle.X do
					if math.abs(middle.Z[i] - cz) <= NEAR and math.abs(middle.X[i] - gx) <= NEAR then near = true break end
				end
				local relief = near and fits_at(zone, gx, cz, 24)
				local k = zone .. ":" .. gx .. ":" .. cz
				local row = fixed[k] or {zone = zone, x = gx, z = cz, seeds = 0, worst = 0}
				fixed[k] = row
				if relief then
					row.seeds = row.seeds + 1
					row.worst = math.max(row.worst, relief)
				end
			end
		end
		for _, size in ipairs(SIZES) do
			local half = (size - 1) / 2
			local fits, tried, best = 0, 0, {}
			local road_in_zone = 0
			for i = 1, #middle.X, 8 do
				local rx, rz = middle.X[i], middle.Z[i]
				if S.id_at(rx, rz) == zone then
					road_in_zone = road_in_zone + 1
					for _, side in ipairs({-1, 1}) do
						for offset = 40, 120, 16 do
							tried = tried + 1
							local cx, cz = math.floor(rx + side * offset), math.floor(rz)
							local relief = fits_at(zone, cx, cz, half)
							if relief then
								fits = fits + 1
								best[#best + 1] = {x = cx, z = cz, relief = relief,
									offset = side * offset, road_x = rx}
							end
						end
					end
				end
			end
			table.sort(best, function(a, b)
				return a.relief < b.relief or (a.relief == b.relief and math.abs(a.offset) < math.abs(b.offset))
			end)
			local shown = {}
			for i = 1, math.min(3, #best) do
				local b = best[i]
				shown[#shown + 1] = ("(%d,%d) relief %d, %+d from road x=%d"):format(b.x, b.z,
					b.relief, b.offset, b.road_x)
			end
			print(("seed %s %s core %d: %d of %d centres fit (road samples in zone %d); flattest: %s")
				:format(seed, zone, size, fits, tried, road_in_zone, table.concat(shown, "; ")))
		end
	end
end
for _, zone in ipairs({"elandor_ashenward_march", "kragmar_bannerbreak_mesa"}) do
	local rows = {}
	for _, row in pairs(fixed) do
		if row.zone == zone and row.seeds == #seeds then rows[#rows + 1] = row end
	end
	table.sort(rows, function(a, b)
		return a.worst < b.worst or (a.worst == b.worst and (math.abs(a.x) < math.abs(b.x) or
			(math.abs(a.x) == math.abs(b.x) and a.x < b.x)))
	end)
	local shown = {}
	for i = 1, math.min(6, #rows) do
		shown[#shown + 1] = ("(%d,%d) worst relief %d"):format(rows[i].x, rows[i].z, rows[i].worst)
	end
	print(("%s: %d fixed centres (grid %d) fit the 49 core beside the middle road on all %d seeds; best: %s")
		:format(zone, #rows, GRID, #seeds, table.concat(shown, "; ")))
end
