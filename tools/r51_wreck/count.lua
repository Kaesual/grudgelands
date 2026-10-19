-- Round 51 lane WRECK: the wrecks of one seed (numbers for the report).
--
--   luajit tools/r51_wreck/count.lua REPO SEED [WRITE]
--
-- Builds the real runtime of SEED (tools/seed_fleet/runtime.lua), takes the
-- wreck writer's layout through its harness hook and asks every 256-node
-- cell of the world for its wreck. Prints the wrecks per shape and per
-- owning zone (the zone of the footprint's middle), the zones of the coast
-- that hold none, the seconds the layout took, and every wreck (shape,
-- turn, corner, seabed y, depth there), so a probe can visit one. With a
-- third argument WRITE (a number N) it also writes, through the real
-- per-chunk path on the harness's fake VoxelManip, every chunk the first N
-- wrecks touch and prints the wreck cells each chunk wrote, and the
-- chunk's plan and write seconds with the wreck pass and without it (the
-- pass replaced by a no-op on the same harness: before / after), the median
-- of three runs each.
local repo, seed, write_count = arg[1], arg[2], tonumber(arg[3] or "0")
assert(repo and seed, "usage: count.lua REPO SEED")
local layout, writer_state
_G.GRUG_WRECK_LAYOUT_HOOK = function(l, w)
	if not layout then layout, writer_state = l, w end
end
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
_G.GRUG_WRECK_LAYOUT_HOOK = nil
assert(layout, "the wreck writer was not built")
local S = R.built.zones_session
local writer = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/wreck_writer.lua")
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local W = source.world_bounds
local started = os.clock()
local by_shape, by_zone, sites = {}, {}, {}
for cz = math.floor(W.min_z / writer.CELL), math.floor(W.max_z / writer.CELL) do
	for cx = math.floor(W.min_x / writer.CELL), math.floor(W.max_x / writer.CELL) do
		local site = layout.site(cx, cz)
		if site then
			sites[#sites + 1] = site
			by_shape[site.key] = (by_shape[site.key] or 0) + 1
			local class, zone = S.water_query_at(site.x + math.floor(site.w / 2),
				site.z + math.floor(site.d / 2))
			site.zone, site.class = zone or "?", class
			by_zone[site.zone] = (by_zone[site.zone] or 0) + 1
		end
	end
end
local seconds = os.clock() - started
print(("seed %s: %d wrecks, layout %.2f s for the whole world"):format(seed, #sites, seconds))
for _, key in ipairs({"wreck.hull", "wreck.bow", "wreck.stern", "wreck.debris"}) do
	print(("  %-13s %d"):format(key, by_shape[key] or 0))
end
local zones = {}
for zone in pairs(by_zone) do zones[#zones + 1] = zone end
table.sort(zones)
local counts = {}
for _, zone in ipairs(zones) do
	counts[#counts + 1] = by_zone[zone]
	print(("  zone %-34s %d"):format(zone, by_zone[zone]))
end
table.sort(counts)
local coast = {}
for _, zone in ipairs(source.zones or {}) do coast[#coast + 1] = zone.id end
local none = {}
for _, id in ipairs(coast) do if not by_zone[id] then none[#none + 1] = id end end
print(("  zones with wrecks %d, per zone min %d median %d max %d; zones without: %s"):format(
	#zones, counts[1] or 0, counts[math.max(1, math.floor(#counts / 2 + 0.5))] or 0,
	counts[#counts] or 0, table.concat(none, " ")))
for _, site in ipairs(sites) do
	print(("  site %s turn %d at %d %d %d (%dx%d) depth %d %s %s"):format(site.key, site.turn,
		site.x, site.y, site.z, site.w, site.d, 1 - site.y, site.class, site.zone))
end

-- The real write of the chunks of the first WRITE wrecks.
for index = 1, math.min(write_count, #sites) do
	local site = sites[index]
	local done = {}
	for _, x in ipairs({site.x, site.x + site.w - 1}) do
		for _, z in ipairs({site.z, site.z + site.d - 1}) do
			local minp = {x = R.origin(x), y = R.origin(site.y), z = R.origin(z)}
			local key = minp.x .. "," .. minp.y .. "," .. minp.z
			if not done[key] then
				done[key] = true
				local before = writer_state.cells
				local chunk = R.chunk(minp)
				local cells = writer_state.cells - before
				local real = writer_state.dress
				local function median(off)
					writer_state.dress = off and function() return 0 end or real
					local t = {}
					for run = 1, 3 do
						local c = R.chunk(minp)
						t[run] = c.plan_seconds + c.write_seconds
					end
					writer_state.dress = real
					table.sort(t)
					return t[2]
				end
				local with, without = median(false), median(true)
				print(("  write %s chunk %s: %d wreck cells; chunk %.3f s with the wrecks, %.3f s without"):format(
					site.key, key, cells, with, without))
			end
		end
	end
end
