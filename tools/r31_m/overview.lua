-- Round 31 lane M: the front of one seed's world for the preview overview.
--
--   luajit tools/r31_m/overview.lua REPO SEED OUT_PREFIX
--
-- Writes OUT_PREFIX.zones.tsv (an 8-node raster of x -2720..2720,
-- z -1360..1360: x, z, zone number (0 sea), 1 when inland water),
-- OUT_PREFIX.roads.tsv (road id, kind, then x z pairs) and
-- OUT_PREFIX.anchors.tsv (id, template, slot, x, z, zone number) of the world
-- main builds (tools/r25_road_poi/world.lua). render.py draws them.
local repo, seed, prefix = arg[1], arg[2], arg[3]
assert(repo and seed and prefix, "usage: overview.lua REPO SEED OUT_PREFIX")
local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
local S = W.raw_session
local number = {}
for _, z in ipairs(W.source.zones) do number[z.id] = z.numeric_id end
local out = assert(io.open(prefix .. ".zones.tsv", "w"))
for z = -1360, 1360, 8 do
	for x = -2720, 2720, 8 do
		local id = S.id_at(x, z)
		local class = S.water_class_at(x, z)
		local n = (class == "land" or class == "planned_water") and id and number[id] or 0
		out:write(("%d\t%d\t%d\t%d\n"):format(x, z, n, class == "planned_water" and 1 or 0))
	end
end
out:close()
out = assert(io.open(prefix .. ".roads.tsv", "w"))
for _, r in ipairs(W.built.roads) do
	local parts = {tostring(r.id), r.kind or "road"}
	for i = 1, #r.X, 2 do
		parts[#parts + 1] = ("%d %d"):format(math.floor(r.X[i] + 0.5), math.floor(r.Z[i] + 0.5))
	end
	out:write(table.concat(parts, "\t") .. "\n")
end
out:close()
out = assert(io.open(prefix .. ".anchors.tsv", "w"))
for _, a in ipairs(W.source.anchors) do
	out:write(("%s\t%s\t%s\t%d\t%d\t%d\n"):format(a.id, a.template_id, a.slot_id, a.position.x,
		a.position.z, a.zone_numeric_id))
end
out:close()
print("overview " .. seed .. " written")
