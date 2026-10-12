-- Round 46 lane PL: the whole map of one seed's world for the placement
-- review page (LuaJIT; render.py draws it).
--
--   luajit tools/r46_pl/overview.lua REPO SEED OUT_PREFIX
--
-- Builds the world as main builds it, placement, water and roads included
-- (tools/r25_road_poi/world.lua; the capitals' protected cities are stood
-- in by squares, their streets are not drawn), and writes
--   OUT_PREFIX.zones.tsv    a 16-node raster of the map: x, z, zone number
--                           (0 sea), 1 on inland water
--   OUT_PREFIX.rivers.tsv   river id, then x z pairs of each wet run
--   OUT_PREFIX.roads.tsv    road id, kind, then x z pairs
--   OUT_PREFIX.anchors.tsv  id, template, slot, x, z, zone, placement step
--                           ("fixed" for a fixed anchor), 0, the mob level at
--                           the centre, half the fitting square (a start's
--                           town square, a capital's reserved square), label
local repo, seed, prefix = arg[1], arg[2], arg[3]
assert(repo and seed and prefix, "usage: overview.lua REPO SEED OUT_PREFIX")
local floor = math.floor
local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
local S, H, source = W.raw_session, W.height, W.source
local number = {}
for _, z in ipairs(source.zones) do number[z.id] = z.numeric_id end
local extent = source.extent

local out = assert(io.open(prefix .. ".zones.tsv", "w"))
for z = extent.min_z, extent.max_z, 16 do
	for x = extent.min_x, extent.max_x, 16 do
		local id = S.id_at(x, z)
		local class = S.water_class_at(x, z)
		local n = (class == "land" or class == "planned_water") and id and number[id] or 0
		local wet = class == "planned_water" or (class == "land" and H.inland_water_at(x, z) ~= nil)
		out:write(("%d\t%d\t%d\t%d\n"):format(x, z, n, wet and 1 or 0))
	end
end
out:close()

out = assert(io.open(prefix .. ".rivers.tsv", "w"))
for _, run in ipairs(H.river_polylines()) do
	local parts = {tostring(run.id)}
	for _, p in ipairs(run.points) do
		parts[#parts + 1] = ("%d %d"):format(floor(p.x + 0.5), floor(p.z + 0.5))
	end
	out:write(table.concat(parts, "\t") .. "\n")
end
out:close()

out = assert(io.open(prefix .. ".roads.tsv", "w"))
for _, r in ipairs(W.built.roads) do
	local parts = {tostring(r.id), r.kind or "road"}
	for i = 1, #r.X, 2 do
		parts[#parts + 1] = ("%d %d"):format(floor(r.X[i] + 0.5), floor(r.Z[i] + 0.5))
	end
	parts[#parts + 1] = ("%d %d"):format(floor(r.X[#r.X] + 0.5), floor(r.Z[#r.Z] + 0.5))
	out:write(table.concat(parts, "\t") .. "\n")
end
out:close()

local profile, label_of = {}, {}
for _, p in ipairs(source.anchor_profiles) do profile[p.id] = p end
for _, p in ipairs(W.settlement.roster) do label_of[p.anchor_id] = p.label end
out = assert(io.open(prefix .. ".anchors.tsv", "w"))
for _, a in ipairs(source.anchors) do
	local zone = source.zones[a.zone_numeric_id]
	local at = S.anchor(zone.id, a.slot_id)
	local half = profile[a.template_id].fitting_width / 2
	if a.slot_id == "capital" then half = 266 elseif a.slot_id == "start" then half = 76 end
	out:write(("%s\t%s\t%s\t%d\t%d\t%d\t%s\t0\t%d\t%d\t%s\n"):format(a.id, a.template_id,
		a.slot_id, at.x, at.z, a.zone_numeric_id,
		a.placement_mode == "placed" and tostring(a.placement_step) or "fixed",
		S.surface_mob_level_at(at.x, at.z) or 0, half, label_of[a.id] or zone.display_name))
end
out:close()
print("overview " .. seed .. " written")
