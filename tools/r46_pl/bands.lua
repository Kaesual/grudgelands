-- Round 46 lane PL, build step 1 (run once, before the coordinates of the
-- placed anchors were deleted): the level third each moving POI stood in
-- at its authored position (design note Q4).
--
--   luajit tools/r46_pl/bands.lua REPO [SEED ...]
--
-- Per seed (default: the six quest seeds) today's zone field is built
-- through `world_assembly.lua`, with every anchor of the authored source as
-- a keypoint as the pre-Round-46 code did, and the mapgen level field
-- (`zone_level_at`, simple_map.lua band_ranges) is read at each
-- `layout_fixed` anchor but the four rift sites. Prints per anchor the
-- third on every seed and the majority (ties to the middle third), the
-- `band` the source row carries since. Kept as the record of how the bands
-- were chosen; it needs the authored coordinates and so no longer runs.
local repo = arg[1] or "."
local seeds = {}
for i = 2, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then seeds = {"42", "7", "2026", "1234", "99999", "314159"} end
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local sha = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local A = dofile(dir .. "/world_assembly.lua")(dir, sha)
local source = A.source
local floor = math.floor
local RIFT = {anchor_076 = true, anchor_077 = true, anchor_084 = true, anchor_085 = true}
local NAME = {"low", "mid", "high"}

local thirds = {}
for _, seed in ipairs(seeds) do
	local W = A.world(seed, nil, {roads = false, protection = A.square_cities(120)})
	local horizontal = W.horizontal_factory({source = source, schemas = A.schemas,
		canonical = A.canonical, deterministic = A.deterministic, raw_sha256 = sha}).new(seed)
	for _, a in ipairs(source.anchors) do
		if a.placement_mode == "layout_fixed" and not RIFT[a.id] then
			local zr = source.zones[a.zone_numeric_id]
			local level = horizontal.zone_level_at(a.position.x, a.position.z, a.zone_numeric_id)
			local count = zr.level_max - zr.level_min + 1
			local c1, c2 = floor(count / 3), floor(count * 2 / 3)
			local third = 2
			if zr.level_min ~= zr.level_max then
				third = level < zr.level_min + c1 and 1 or (level < zr.level_min + c2 and 2 or 3)
			end
			local list = thirds[a.id] or {}
			thirds[a.id] = list
			list[#list + 1] = third
		end
	end
end
for _, a in ipairs(source.anchors) do
	local list = thirds[a.id]
	if list then
		local n = {0, 0, 0}
		for _, t in ipairs(list) do n[t] = n[t] + 1 end
		local best = 2
		for t = 1, 3 do
			if n[t] > n[best] then best = t end
		end
		print(("%s\t%s\t%s\t%s"):format(a.id, a.slot_id, table.concat(list, ","), NAME[best]))
	end
end
