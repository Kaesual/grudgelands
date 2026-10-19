-- Round 51 lane LK: the mapgen cost and the kit's real counts in a few fixed
-- chunks of one seed, through the seed fleet's real runtime and writer
-- (tools/seed_fleet/runtime.lua).
--
--   luajit tools/r51_lk/region.lua REPO SEED [CHUNKS_PER_BIOME]
--
-- Picks, per biome of the five kit zones (undead, dwarf, jungle, elves,
-- orc badlands), the first CHUNKS_PER_BIOME (default 2) land columns of a
-- coarse grid over the world, plans and writes the chunk holding each, and
-- prints per zone the CPU seconds of planning and writing, and how many
-- nodes of each kit name (the land kit's props, cairn shapes and the bone
-- pile) the written chunks hold; then the writer's template counts of the
-- kit rows (candidates, owner clips, accepted). The chunks depend on the
-- terrain only, so the same seed picks the same chunks on another tree:
-- numbers are comparisons (before and after a change), never targets.
local repo, seed, per_biome = arg[1], arg[2], tonumber(arg[3] or "2")
assert(repo and seed, "usage: region.lua REPO SEED [CHUNKS_PER_BIOME]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local ZONES = {
	{"undead", {"grug_blight", "grug_bone_forest"}},
	{"dwarf", {"grug_crags", "grug_crags_snowy", "grug_pine_hills"}},
	{"jungle", {"grug_deep_jungle", "grug_jungle_fringe", "grug_jungle_edge"}},
	{"elves", {"grug_elf_forest", "grug_deep_forest"}},
	{"orc", {"grug_badlands", "grug_badlands_east"}},
}
local zone_of, found, chunks, seen = {}, {}, {}, {}
for _, z in ipairs(ZONES) do
	for _, b in ipairs(z[2]) do zone_of[b], found[b] = z[1], 0 end
end
for z = -3300, 3300, 96 do
	for x = -3700, 3700, 96 do
		local biome = zones.biome_at(x, z)
		if biome and zone_of[biome] and found[biome] < per_biome and
				zones.water_class_at(x, z) == "land" and R.ground_at(x, z) > 3 then
			local minp = {x = R.origin(x), y = R.origin(R.ground_at(x, z)), z = R.origin(z)}
			local key = minp.x .. "," .. minp.y .. "," .. minp.z
			if not seen[key] then
				seen[key] = true
				found[biome] = found[biome] + 1
				chunks[#chunks + 1] = {zone_of[biome], biome, minp}
			end
		end
	end
end

-- The kit's node names: every grug_nodes prop and cairn shape the harness
-- registered, and the bone pile.
local KIT = {}
for name in pairs(R.fake.registered_nodes) do
	if name:match("^grug_nodes:") and (name:find("gravestone", 1, true) or
			name:find("cairn", 1, true) or name:find("skull", 1, true) or
			name:find("ribcage", 1, true) or name:find("spine", 1, true) or
			name:find("bone", 1, true) or name:find("statue", 1, true) or
			name:find("obelisk", 1, true)) then
		KIT[R.fake.get_content_id(name)] = name
	end
end

local per_zone = {}
for _, entry in ipairs(chunks) do
	local zone, minp = entry[1], entry[3]
	local t = per_zone[zone] or {chunks = 0, plan = 0, write = 0, nodes = {}}
	per_zone[zone] = t
	local vm = R.new_vm(minp)
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local t1 = os.clock()
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	local t2 = os.clock()
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local t3 = os.clock()
	t.chunks, t.plan, t.write = t.chunks + 1, t.plan + t2 - t1, t.write + t3 - t2
	local data = vm.written.data or vm.native.data
	-- the owner volume only (the fake area carries a 16-node shell)
	for z = 16, 95 do
		for y = 16, 95 do
			local base = z * 12544 + y * 112
			for x = 16, 95 do
				local name = KIT[data[base + x + 1]]
				if name then t.nodes[name] = (t.nodes[name] or 0) + 1 end
			end
		end
	end
end

print(("seed %s, %d chunks"):format(seed, #chunks))
for _, z in ipairs(ZONES) do
	local t = per_zone[z[1]]
	if t then
		print(("%-7s %2d chunks  plan %6.2f s  write %6.2f s"):format(z[1], t.chunks,
			t.plan, t.write))
		local names = {}
		for name in pairs(t.nodes) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do print(("        %-34s %5d"):format(name, t.nodes[name])) end
	end
end
local m = R.built.session.metrics().settlement.templates or {}
local ids = {}
for id in pairs(m) do if id:find("kit_", 1, true) then ids[#ids + 1] = id end end
table.sort(ids)
if #ids > 0 then
	print(("%-28s %6s %6s %6s"):format("kit row", "cand", "clip", "acc"))
	for _, id in ipairs(ids) do
		local t = m[id]
		print(("%-28s %6d %6d %6d"):format(id, t.candidates, t.clipped, t.accepted))
	end
end
print(("runtime: main %.2f s, build %.2f s"):format(R.seconds.main, R.seconds.build))
