-- Round 31 lane M: fixed PvP POI centres that fit every seed (a report).
--
--   luajit tools/r31_m/pick.lua REPO CANDIDATE_FILE...
--
-- Reads the per-seed candidate lists of candidates.lua and keeps, per
-- catalogue row, the centres that passed on EVERY seed given, scored by
-- their worst relief (a fortress also by its worst gap to the middle road,
-- which may not exceed NEAR). Then it picks one centre per row, fortresses
-- first, every row's best centre that keeps SPACING nodes (centre to
-- centre) from the PvP POIs already picked, and prints the anchor rows.
local repo = arg[1]
local files = {}
for i = 2, #arg do files[#files + 1] = arg[i] end
assert(repo and #files > 0, "usage: pick.lua REPO CANDIDATE_FILE...")
local catalog = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua")
local SPACING, NEAR = tonumber(os.getenv("SPACING") or "160"), tonumber(os.getenv("NEAR") or "40")
local ZONE_OUT = tonumber(os.getenv("ZONE_OUT") or "60")
local WET = tonumber(os.getenv("WET") or "20")
-- boat-path mainland ends: a camp keeps off the harbours
local BOAT_GAP = 128
local boat_ends = {}
for _, b in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").boat_paths) do
	boat_ends[#boat_ends + 1] = b.centreline[1]
end
local band = {}
local zone_row = {}
for _, z in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").zones) do
	zone_row[z.id] = z
end
for _, cat in ipairs(catalog.rows) do
	if cat.band then
		local z = zone_row[cat.zone_id]
		band[cat.key] = {catalog.camp_levels(z.level_min, z.level_max, cat.band)}
	end
end

local seen = {}
for _, file in ipairs(files) do
	for line in io.lines(file) do
		local key, x, z, relief, gap, out, lv_min, lv_max, lv_centre, wet = line:match(
			"^(%S+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+)$")
		local k = key .. " " .. x .. " " .. z
		local row = seen[k] or {key = key, x = tonumber(x), z = tonumber(z), n = 0, relief = 0,
			gap = 0, out = 0, level_ok = 0, level_near = 0, relief_sum = 0, wet = 0}
		seen[k] = row
		row.n = row.n + 1
		row.relief = math.max(row.relief, tonumber(relief))
		row.relief_sum = row.relief_sum + tonumber(relief)
		row.gap = math.max(row.gap, tonumber(gap))
		row.out = math.max(row.out, tonumber(out))
		row.wet = math.max(row.wet, tonumber(wet))
		local b = band[key]
		if not b or (tonumber(lv_min) >= b[1] and tonumber(lv_max) <= b[2]) then
			row.level_ok = row.level_ok + 1
		end
		if not b or (tonumber(lv_centre) >= b[1] - 1 and tonumber(lv_centre) <= b[2] + 1) then
			row.level_near = row.level_near + 1
		end
	end
end
local by_key = {}
for _, row in pairs(seen) do
	local harbour = false
	for _, p in ipairs(boat_ends) do
		local dx, dz = p.x - row.x, p.z - row.z
		if dx * dx + dz * dz < BOAT_GAP * BOAT_GAP then harbour = true end
	end
	if row.n == #files and (row.gap < 0 or row.gap <= NEAR) and row.level_near == #files and
			row.out <= ZONE_OUT and row.wet <= WET and not harbour then
		local list = by_key[row.key] or {}
		by_key[row.key] = list
		list[#list + 1] = row
	end
end
local function score(row)
	return row.relief / 2 + row.relief_sum / row.n + (row.gap > 0 and row.gap / 4 or 0) +
		row.out / 2 + (#files - row.level_ok) * 4 + row.wet
end
for _, list in pairs(by_key) do
	table.sort(list, function(a, b)
		local sa, sb = score(a), score(b)
		if sa ~= sb then return sa < sb end
		if math.abs(a.z) ~= math.abs(b.z) then return math.abs(a.z) < math.abs(b.z) end
		return a.x < b.x
	end)
end
-- Greedy, the rows with the fewest centres first, then improvement passes:
-- each row takes its best centre that keeps SPACING from the others.
local choice = {}
local function fits(key, row)
	for other, c in pairs(choice) do
		if other ~= key then
			local dx, dz = c.x - row.x, c.z - row.z
			if dx * dx + dz * dz < SPACING * SPACING then return false end
		end
	end
	return true
end
local order = {}
for _, cat in ipairs(catalog.rows) do order[#order + 1] = cat.key end
table.sort(order, function(a, b)
	local na, nb = #(by_key[a] or {}), #(by_key[b] or {})
	if na ~= nb then return na < nb end
	return a < b
end)
for _, key in ipairs(order) do
	for _, row in ipairs(by_key[key] or {}) do
		if fits(key, row) then choice[key] = row break end
	end
end
for _ = 1, 4 do
	for _, key in ipairs(order) do
		for _, row in ipairs(by_key[key] or {}) do
			if row == choice[key] then break end
			if fits(key, row) then choice[key] = row break end
		end
	end
end
local picked = {}
for _, cat in ipairs(catalog.rows) do
	local list = by_key[cat.key] or {}
	local best, c = list[1], choice[cat.key]
	local function show(r)
		return r and ("(%d,%d) r%d/%.0f g%d o%d lv%d w%d"):format(r.x, r.z, r.relief,
			r.relief_sum / r.n, r.gap, r.out, r.level_ok, r.wet) or "NONE"
	end
	print(("%-44s %4d best %s  picked %s"):format(cat.key, #list, show(best), show(c)))
	if c then picked[#picked + 1] = c end
end
local nearest = math.huge
for i = 1, #picked do
	for j = i + 1, #picked do
		local dx, dz = picked[i].x - picked[j].x, picked[i].z - picked[j].z
		nearest = math.min(nearest, math.sqrt(dx * dx + dz * dz))
	end
end
print(("picked %d of %d, nearest pair %.0f"):format(#picked, #catalog.rows, nearest))
