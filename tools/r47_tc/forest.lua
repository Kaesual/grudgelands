-- Round 47 lane TC: trees in a few forest chunks of one seed, through the
-- seed fleet's real runtime and writer (tools/seed_fleet/runtime.lua).
--
--   luajit tools/r47_tc/forest.lua REPO SEED [CHUNKS_PER_BIOME]
--
-- Picks, per tree biome, the first CHUNKS_PER_BIOME (default 2) land columns
-- of a coarse grid over the world, writes the chunk holding each, and prints
-- per template row the writer's own counts (r6_settlement.lua
-- `metrics().templates`): owner-rooted candidates, those clipped by the
-- owner intersection (`current_mapchunk_owner_intersection_v1`, a mapchunk
-- border), those accepted, and for generated trees the root runs tried and
-- written; then the shape and trunk nodes the chunks hold, and the CPU
-- seconds of the runtime's construction. Numbers are comparisons (run the
-- same seed and chunks on another tree), never targets.
local repo, seed, per_biome = arg[1], arg[2], tonumber(arg[3] or "2")
assert(repo and seed, "usage: forest.lua REPO SEED [CHUNKS_PER_BIOME]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local BIOMES = {"grug_meadows", "grug_deep_forest", "grug_elf_forest", "grug_deep_jungle",
	"grug_jungle_fringe", "grug_jungle_edge", "grug_pine_hills", "grug_savanna",
	"grug_blight", "grug_bone_forest", "grug_crags"}
local wanted, found, chunks, seen = {}, {}, {}, {}
for _, b in ipairs(BIOMES) do wanted[b], found[b] = true, 0 end
for z = -3300, 3300, 96 do
	for x = -3700, 3700, 96 do
		local biome = zones.biome_at(x, z)
		if biome and wanted[biome] and found[biome] < per_biome and
				zones.water_class_at(x, z) == "land" and R.ground_at(x, z) > 3 then
			local minp = {x = R.origin(x), y = R.origin(R.ground_at(x, z)), z = R.origin(z)}
			local key = minp.x .. "," .. minp.y .. "," .. minp.z
			if not seen[key] then
				seen[key] = true
				found[biome] = found[biome] + 1
				chunks[#chunks + 1] = {biome, minp}
			end
		end
	end
end
local names, write_seconds = {}, 0
for _, entry in ipairs(chunks) do
	local result = R.chunk(entry[2])
	write_seconds = write_seconds + result.write_seconds
end
local m = R.built.session.metrics().settlement.templates or {}
local ids = {}
for id in pairs(m) do ids[#ids + 1] = id end
table.sort(ids)
print(("seed %s: %d chunks (%s)"):format(seed, #chunks, (function()
	local parts = {}
	for _, b in ipairs(BIOMES) do parts[#parts + 1] = b:gsub("^grug_", "") .. "=" .. found[b] end
	return table.concat(parts, " ")
end)()))
print(("%-30s %6s %6s %6s %7s %6s %6s"):format("template row", "cand", "clip", "acc",
	"clip%", "runs", "roots"))
local total = {0, 0, 0}
for _, id in ipairs(ids) do
	local t = m[id]
	total[1], total[2], total[3] = total[1] + t.candidates, total[2] + t.clipped,
		total[3] + t.accepted
	print(("%-30s %6d %6d %6d %6.1f%% %6s %6s"):format(id, t.candidates, t.clipped,
		t.accepted, t.candidates > 0 and 100 * t.clipped / t.candidates or 0,
		t.root_runs and tostring(t.root_runs) or "-",
		t.root_runs_written and tostring(t.root_runs_written) or "-"))
end
print(("%-30s %6d %6d %6d %6.1f%%"):format("all", total[1], total[2], total[3],
	total[1] > 0 and 100 * total[2] / total[1] or 0))
print(("runtime: main %.2f s, build %.2f s, template variants %s s; chunk writes %.2f s")
	:format(R.seconds.main, R.seconds.build,
		R.built.template_seconds and ("%.3f"):format(R.built.template_seconds) or "-",
		write_seconds))
