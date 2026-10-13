-- Round 47 lane TD: forest density, today against new, from the real
-- mapgen (the seed fleet's runtime and writer, tools/seed_fleet/runtime.lua).
--
--   luajit tools/r47_td/density.lua REPO SEED [CHUNKS_PER_BIOME]
--
-- REPO is a checkout of the game (this tree for "new"; an export of the
-- commit before lane TC's merge, e65bf60a, for "today": the runtime and its
-- harness are the same file at both). Picks, per tree biome, the first
-- CHUNKS_PER_BIOME (default 3) land columns of a coarse grid (lane TC's
-- tools/r47_tc/forest.lua rule), writes the 80^3 chunk holding each, and
-- counts the standing trees in what the writer wrote: a tree is a cluster of
-- trunk feet (a trunk or quarter node of a wood standing on ground: the node
-- below is no wood, leaves or air; with wood two nodes up, so lying logs do
-- not count),
-- joined over x/z neighbours. A jungle-wood tree whose trunk reaches 20 or
-- more nodes above its foot is a kapok. Every tree counts for the biome of
-- its foot column; the area is the biome's land columns in the chunks.
-- Prints trees per 1000 land columns, per biome and species. Numbers are
-- comparisons between the two checkouts, never targets.
local repo, seed, per_biome = arg[1], arg[2], tonumber(arg[3] or "3")
assert(repo and seed, "usage: density.lua REPO SEED [CHUNKS_PER_BIOME]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()

-- The runtime's content ids are a function of the name (runtime.lua).
local function cid(name)
	local a, b, c, d = sha256(name):byte(1, 4)
	return 1000 + ((a % 64) * 16777216 + b * 65536 + c * 256 + d)
end
local WOOD = {
	apple = {"default:tree", "grug_trees:apple_quarter"},
	jungle = {"default:jungletree", "grug_trees:jungle_quarter"},
	acacia = {"default:acacia_tree", "grug_trees:acacia_quarter"},
	pine = {"default:pine_tree", "grug_trees:pine_quarter"},
	aspen = {"default:aspen_tree", "grug_trees:aspen_quarter"},
	silverwood = {"grug_trees:silverwood_tree", "grug_trees:silverwood_quarter"},
	gravewood = {"grug_trees:gravewood_tree", "grug_trees:gravewood_quarter"},
}
local wood_of = {}
for wood, names in pairs(WOOD) do
	for _, name in ipairs(names) do wood_of[cid(name)] = wood end
end
-- What a foot may not stand on: air and the crowns (a branch of an old
-- schematic resting on leaves or air is no foot).
local not_ground = {[126] = true}
for _, name in ipairs({"default:leaves", "default:jungleleaves", "default:acacia_leaves",
		"default:pine_needles", "default:aspen_leaves", "grug_trees:silverwood_leaves",
		"grug_trees:gravewood_leaves"}) do
	not_ground[cid(name)] = true
end

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
				chunks[#chunks + 1] = minp
			end
		end
	end
end

local trees, area = {}, {}   -- biome -> species -> count; biome -> columns
local function add(t, a, b, n)
	t[a] = t[a] or {}
	t[a][b] = (t[a][b] or 0) + n
end
for _, minp in ipairs(chunks) do
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local vm = R.new_vm(minp)
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local data = vm.written.data or vm.native.data
	local ex, ey, ez = minp.x - 16, minp.y - 16, minp.z - 16
	local function at(x, y, z) return data[(z - ez) * 12544 + (y - ey) * 112 + (x - ex) + 1] end
	-- area: the chunk's land columns per biome
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local biome = zones.biome_at(x, z)
			if biome and zones.water_class_at(x, z) == "land" then
				area[biome] = (area[biome] or 0) + 1
			end
		end
	end
	-- trunk feet, clustered over x/z neighbours (and one node of y)
	local feet, index = {}, {}
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y - 2 do
			for x = minp.x, maxp.x do
				local wood = wood_of[at(x, y, z)]
				local below = at(x, y - 1, z)
				if wood and not wood_of[below] and not not_ground[below] and
						wood_of[at(x, y + 2, z)] == wood then
					local foot = {x = x, y = y, z = z, wood = wood}
					feet[#feet + 1] = foot
					index[x .. "," .. y .. "," .. z] = #feet
				end
			end
		end
	end
	local parent = {}
	for i = 1, #feet do parent[i] = i end
	local function root(i)
		while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
		return i
	end
	for i, f in ipairs(feet) do
		for dx = -1, 1 do
			for dz = -1, 1 do
				for dy = -1, 1 do
					local j = index[(f.x + dx) .. "," .. (f.y + dy) .. "," .. (f.z + dz)]
					if j and feet[j].wood == f.wood then parent[root(i)] = root(j) end
				end
			end
		end
	end
	local cluster = {}
	for i, f in ipairs(feet) do
		local r = root(i)
		local c = cluster[r]
		if not c then
			c = {wood = f.wood, x = f.x, y = f.y, z = f.z, top = 0}
			cluster[r] = c
		end
		if f.y < c.y then c.x, c.y, c.z = f.x, f.y, f.z end
		local y = f.y
		while y < maxp.y + 16 and wood_of[at(f.x, y + 1, f.z)] == f.wood do y = y + 1 end
		if y - f.y > c.top then c.top = y - f.y end
	end
	for _, c in pairs(cluster) do
		local species = c.wood
		if species == "jungle" and c.top >= 20 then species = "kapok" end
		add(trees, zones.biome_at(c.x, c.z) or "?", species, 1)
	end
end

print(("seed %s: %d chunks"):format(seed, #chunks))
local SPECIES = {"apple", "jungle", "kapok", "acacia", "pine", "aspen", "silverwood", "gravewood"}
print(("%-20s %7s  %s"):format("biome", "land", table.concat(SPECIES, " ")))
for _, biome in ipairs(BIOMES) do
	local parts = {}
	for _, s in ipairs(SPECIES) do
		local n = trees[biome] and trees[biome][s] or 0
		parts[#parts + 1] = ("%s=%d(%.2f)"):format(s, n, area[biome] and area[biome] > 0 and
			1000 * n / area[biome] or 0)
	end
	print(("%-20s %7d  %s"):format(biome, area[biome] or 0, table.concat(parts, " ")))
end
-- The writer's own count of accepted tree rows, where the checkout has it
-- (lane TC's metrics; the tree before TC has none): a check on the cluster
-- count above.
local ok, metrics = pcall(function() return R.built.session.metrics().settlement.templates end)
if ok and metrics then
	local ids = {}
	for id, t in pairs(metrics) do if t.accepted > 0 then ids[#ids + 1] = id end end
	table.sort(ids)
	for _, id in ipairs(ids) do print(("writer accepted %-30s %d"):format(id, metrics[id].accepted)) end
end
