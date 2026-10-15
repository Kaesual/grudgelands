-- Round 47 lane SW, build step 2: the swamp in the real writer, without the
-- engine. Builds one seed's mapgen runtime with the seed fleet's harness
-- (tools/seed_fleet/runtime.lua: the real R7 runtime and writer over a fake
-- VoxelManip), finds swamp land on a coarse grid, writes the chunks holding
-- the first few swamp columns found and counts what the swamp got:
--   * the top node of every swamp land column (the ground mix);
--   * water sources the swamp pass wrote, and the pool check: no water
--     source of the pass has an air (or any non-solid, non-water) neighbour
--     on its four sides or below inside the written volume, so no water can
--     flow (`flowing` = such sources; must be 0); also no flowing liquid
--     node anywhere in the written chunks;
--   * plants (reeds, cattails, rooted reeds, waterlilies, carpets, ferns,
--     tall grass) and swamp tree trunks.
--
--   luajit tools/r47_sw/world_probe.lua REPO SEED [CHUNKS] [GRID]
-- CHUNKS (default 4): how many swamp chunks to write; GRID (default 64):
-- the search grid's step. Prints one line per chunk and a total line
-- "SWAMP <seed> chunks=<n> columns=<n> ... flowing=<n>"; exits 1 when the
-- pool check fails.
local repo, seed = arg[1], arg[2]
local want = tonumber(arg[3] or "4")
local step = tonumber(arg[4] or "64")
assert(repo and seed and seed:match("^%d+$"), "usage: world_probe.lua REPO SEED [CHUNKS] [GRID]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = R.built.zones_session
local fake = R.fake

local function cid(name) return fake.get_content_id(name) end
local AIR = fake.CONTENT_AIR
local WATER = cid("default:water_source")
local FLOWING = cid("default:water_flowing")
local RIVER = cid("default:river_water_source")
local RIVER_FLOWING = cid("default:river_water_flowing")
local GROUNDS = {"grug_nodes:mud", "grug_nodes:mud_dry", "grug_nodes:mud_mottled",
	"grug_nodes:mud_with_wet_grass", "grug_nodes:dirt_with_moss"}
local PLANTS = {"grug_nodes:reeds", "grug_nodes:cattails", "grug_nodes:mud_with_reeds",
	"grug_mapgen:freshwater_waterlily", "grug_nodes:moss_carpet", "default:fern_1",
	"default:fern_2", "default:fern_3", "default:grass_3", "default:grass_4",
	"default:grass_5", "default:junglegrass", "default:dry_shrub", "default:papyrus",
	"grug_trees:gravewood_tree", "grug_trees:swamp_leaves", "grug_trees:swamp_hanging_moss"}
local GROUND_SET = {}
for _, name in ipairs(GROUNDS) do GROUND_SET[name] = true end
local name_by_cid = {}
for _, name in ipairs(GROUNDS) do name_by_cid[cid(name)] = name end
for _, name in ipairs(PLANTS) do name_by_cid[cid(name)] = name end

-- Swamp land columns on the grid, then the chunks holding them (distinct).
local chunks, seen = {}, {}
for z = -3328, 3328, step do
	for x = -3728, 3728, step do
		if #chunks >= want then break end
		local flat = true
		if zones.water_class_at(x, z) == "land" and zones.biome_at(x, z) == "grug_swamp" then
			-- prefer gentle swamp, where pools may lie (relief <= 1 round it)
			local low, high = math.huge, -math.huge
			for dz = -4, 4, 2 do
				for dx = -4, 4, 2 do
					local y = zones.terrain_height_at(x + dx, z + dz)
					low, high = math.min(low, y), math.max(high, y)
				end
			end
			flat = high - low <= 1 and zones.water_class_at(x + 8, z) == "land" and
				zones.water_class_at(x - 8, z) == "land"
		else
			flat = false
		end
		if flat then
			local y = math.max(zones.terrain_height_at(x, z), 1)
			local minp = {x = R.origin(x), y = R.origin(y), z = R.origin(z)}
			local key = minp.x .. "," .. minp.y .. "," .. minp.z
			if not seen[key] then
				seen[key] = true
				chunks[#chunks + 1] = minp
			end
		end
	end
end
if #chunks == 0 then print("SWAMP " .. seed .. " no swamp found") return end

local total = {columns = 0, water = 0, flowing = 0, liquid_flowing = 0, chunks = 0}
local tops, plants = {}, {}
local function solid(c)
	if c == AIR then return false end
	local def = fake.registered_nodes[fake.get_name_from_content_id(c)]
	return def ~= nil and def.walkable ~= false and (def.liquidtype or "none") == "none"
end
for _, minp in ipairs(chunks) do
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local vm = R.new_vm(minp)
	local started = os.clock()
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local result = {write_seconds = os.clock() - started}
	-- the swamp rows' planned roots in this chunk (catalog index = sorted row)
	local roots = {}
	for cell = 1, plan.candidate_cell_count do
		local base = (cell - 1) * 4
		for candidate = plan.candidate_cell_values[base + 3],
				plan.candidate_cell_values[base + 4] - 1 do
			local catalog = plan.candidate_values[(candidate - 1) * 7 + 2]
			roots[catalog] = (roots[catalog] or 0) + 1
		end
	end
	local parts = {}
	for catalog = 51, 61 do parts[#parts + 1] = catalog .. ":" .. (roots[catalog] or 0) end
	print("  planned roots (rows 51-61): " .. table.concat(parts, " "))
	local data = vm.written.data
	local ex, ey, ez = minp.x - 16, minp.y - 16, minp.z - 16
	local function at(x, y, z)
		if x < ex or x > ex + 111 or y < ey or y > ey + 111 or z < ez or z > ez + 111 then
			return nil
		end
		return data[(z - ez) * 12544 + (y - ey) * 112 + (x - ex) + 1]
	end
	local columns, water, flowing = 0, 0, 0
	for z = minp.z, minp.z + 79 do
		for x = minp.x, minp.x + 79 do
			local terrain_y = zones.terrain_height_at(x, z)
			if zones.biome_at(x, z) == "grug_swamp" and zones.water_class_at(x, z) == "land" and
					terrain_y >= minp.y and terrain_y + 1 <= minp.y + 79 then
				-- the top: the highest non-air, non-plant node in the chunk
				for y = math.min(terrain_y + 1, minp.y + 79), minp.y, -1 do
					local c = at(x, y, z)
					if c ~= AIR then
						if c == WATER then
							-- a pool (or other water): count, check
							water = water + 1
							for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}, {0, -1, 0}}) do
								local n = at(x + d[1], y + d[2], z + d[3])
								if n ~= nil and n ~= WATER and not solid(n) and
										not (d[2] == 0 and n == cid("grug_mapgen:freshwater_waterlily")) then
									flowing = flowing + 1
								end
							end
						end
						local def = fake.registered_nodes[fake.get_name_from_content_id(c)]
						if def and def.walkable ~= false and c ~= WATER then
							columns = columns + 1
							local top = name_by_cid[c] or fake.get_name_from_content_id(c)
							tops[top] = (tops[top] or 0) + 1
							break
						end
					end
				end
			end
			local swamp = zones.biome_at(x, z) == "grug_swamp"
			for y = minp.y, minp.y + 79 do
				local c = at(x, y, z)
				if c == FLOWING or c == RIVER_FLOWING then total.liquid_flowing = total.liquid_flowing + 1 end
				local name = swamp and name_by_cid[c]
				if name and not GROUND_SET[name] then plants[name] = (plants[name] or 0) + 1 end
			end
		end
	end
	-- stilt ends: a gravewood twig under a gravewood branch or base (the
	-- bottom of a swamp tree's stilt); hanging when no walkable node is under it
	local TWIG, BRANCH, BASE = cid("grug_trees:gravewood_twig"),
		cid("grug_trees:gravewood_branch"), cid("grug_trees:gravewood_base")
	for z = minp.z, minp.z + 79 do
		for x = minp.x, minp.x + 79 do
			for y = minp.y + 1, minp.y + 78 do
				if at(x, y, z) == TWIG then
					local up = at(x, y + 1, z)
					if (up == BRANCH or up == BASE) and at(x, y - 1, z) ~= TWIG then
						total.stilts = (total.stilts or 0) + 1
						if not solid(at(x, y - 1, z)) then total.hanging = (total.hanging or 0) + 1 end
					end
				end
			end
		end
	end
	print(("chunk %d,%d,%d swamp_columns=%d water=%d flowing=%d write=%.1fs"):format(
		minp.x, minp.y, minp.z, columns, water, flowing, result.write_seconds))
	total.columns = total.columns + columns
	total.water = total.water + water
	total.flowing = total.flowing + flowing
	total.chunks = total.chunks + 1
end
local function list(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. t[k] end
	return table.concat(parts, " ")
end
if rawget(_G, "SW_DEBUG") then print("debug: " .. list(SW_DEBUG)) end
print("tops: " .. list(tops))
print("plants: " .. list(plants))
print(("SWAMP %s chunks=%d columns=%d water=%d flowing=%d liquid_flowing=%d stilt_ends=%d hanging=%d")
	:format(seed, total.chunks, total.columns, total.water, total.flowing, total.liquid_flowing,
		total.stilts or 0, total.hanging or 0))
if total.flowing > 0 or total.liquid_flowing > 0 then error("pool check failed", 0) end
