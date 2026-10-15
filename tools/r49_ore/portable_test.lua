-- Round 49 lane ORE portable fixture (LuaJIT; mapgen-native-plan.md §4.1):
--
--   luajit tools/r49_ore/portable_test.lua REPO
--
--   A. The native scatter rows (r7_native.lua), derived from the resource
--      table (r7_r6_manifest.lua RESOURCE_ROWS) and the WP43 tiers: every
--      resource and band has its rows, a lower-half row covers only the
--      band's lower half, T6 splits at the deep bands; the ore is the
--      resource's node and the host the band's tier rock; clust_scarcity =
--      denominator * clust_num_ores (divided by the deep multiplier,
--      rounded); the shapes by vein cap (8: 3-cube / 8, 4: 2-cube / 4,
--      2: 2-cube / 1); all of them registered after the strata and nests.
--      The digest refuses a changed input.
--   B. The fill ores (r6_settlement.lua r49_fill_ores_new): over a
--      synthetic fill volume each T1 resource lands at about 1 / its
--      denominator (rough ranges, mapgen plan ruling 2), T1 Iron only in
--      T1's lower half, cluster sizes like the native shapes (gems mostly
--      single nodes and pairs); the same placements under LuaJIT and
--      tools/bin/lua51 (tools/r49_ore/fill_digest.lua).
--   C. The cave decorations: simple, all_floors, on the catalog row's host
--      rocks, the row's y range one lower (the engine tests the floor
--      node), fill_ratio one in the initial denominator; the Lua cave
--      rows are gone from world_content.lua.
-- Prints "R49 ORE PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

_G.R24_MINING_HARNESS = true
dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local M = grug_materials
local projection = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
	.project(M)
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
_G.core = {sha256 = function(bytes) return common.hex(sha(bytes)) end}
local native = dofile(wp40 .. "/r7_native.lua")
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()

-- A. The native scatter rows ----------------------------------------------------
local definitions, decorations = native.population(wp40, projection)
check(#definitions == 9 + 84, "nine fixed rows and 84 scatter rows")
check(definitions[1].ore == "default:gravel", "gravel first")
for index = 2, 6 do
	check(definitions[index].ore_type == "stratum" and
		definitions[index].ore == M.TIERS[index].node, "stratum " .. index)
end
for index = 7, 9 do check(definitions[index].ore_type == "blob", "nest " .. index) end
local SHAPE = {[8] = {3, 8}, [4] = {2, 4}, [2] = {2, 1}}
local DEEP = {}
for index, band in ipairs(M.DENSITY.deep_bands) do
	DEEP[index] = {y_min = band.y_min, y_max = band.y_max, multiplier = band.multiplier}
end
local claimed, scatter = {}, 0
for index = 10, #definitions do
	local row = definitions[index]
	check(row.ore_type == "scatter", "row " .. index .. " is a scatter row")
	scatter = scatter + 1
end
-- The expected segments of one resource and tier: {y_min, y_max, multiplier}.
local function segments(resource, tier_index)
	local tier = M.TIERS[tier_index]
	local top = resource.lower_half_of == tier_index and tier.lower_half_y_max or tier.y_max
	local result = {}
	local ordinary_bottom = math.max(tier.y_min, DEEP[1].y_max + 1)
	if ordinary_bottom <= top then result[#result + 1] = {ordinary_bottom, top, 1} end
	for _, band in ipairs(DEEP) do
		local low, high = math.max(tier.y_min, band.y_min), math.min(top, band.y_max)
		if low <= high then result[#result + 1] = {low, high, band.multiplier} end
	end
	return result
end
local band_rate = {}
local expected_rows = 0
for _, resource in ipairs(manifest.resources) do
	local node = M.RESOURCE_BY_KEY[resource.key].natural_node
	local shape = SHAPE[resource.max_nodes_per_vein]
	check(shape ~= nil, resource.key .. " has a known vein cap")
	for tier_index = 1, 6 do
		local denominator = resource.denominators[tier_index]
		if denominator then
			for _, segment in ipairs(segments(resource, tier_index)) do
				expected_rows = expected_rows + 1
				local found
				for index = 10, #definitions do
					local row = definitions[index]
					if row.ore == node and row.wherein == M.TIERS[tier_index].node and
							row.y_min == segment[1] and row.y_max == segment[2] then
						check(not found, resource.key .. " T" .. tier_index .. " row is unique")
						found = index
					end
				end
				check(found, ("%s T%d %d..%d has its row"):format(resource.key, tier_index,
					segment[1], segment[2]))
				claimed[found] = true
				local row = definitions[found]
				check(row.clust_size == shape[1] and row.clust_num_ores == shape[2],
					resource.key .. " cluster shape by cap " .. resource.max_nodes_per_vein)
				local exact = denominator * shape[2] / segment[3]
				check(math.abs(row.clust_scarcity - exact) <= 0.5,
					("%s T%d scarcity %d for %.1f"):format(resource.key, tier_index,
						row.clust_scarcity, exact))
				if segment[3] == 1 then
					check(row.clust_scarcity == denominator * shape[2],
						resource.key .. " T" .. tier_index .. " scarcity = denominator * ores")
				end
				if segment[3] == 1 then
					-- the share of the band's ordinary part (T1 from y 0) it covers
					local tier = M.TIERS[tier_index]
					local top = math.min(tier.y_max, 0)
					local bottom = math.max(tier.y_min, DEEP[1].y_max + 1)
					band_rate[tier_index] = (band_rate[tier_index] or 0) +
						row.clust_num_ores / row.clust_scarcity *
						(math.min(segment[2], top) - segment[1] + 1) / (top - bottom + 1)
				end
			end
		end
	end
end
check(expected_rows == 84 and scatter == 84, "84 expected rows")
for index = 10, #definitions do check(claimed[index], "row " .. index .. " is expected") end
-- Ores of each band per host node (T1 counted from y 0, T6 above the deep
-- bands; lower-half rows weighted by their share of the band): the density
-- table's rough totals (world_zones.md §11).
local parts = {}
for tier_index = 1, 6 do
	parts[#parts + 1] = ("T%d %.2f%%"):format(tier_index, 100 * band_rate[tier_index])
end
print("native ore share of host rock by band: " .. table.concat(parts, ", "))
check(band_rate[1] > 0.045 and band_rate[1] < 0.055, "T1 about 5 % ores")
-- A changed input changes the digest: the derived rows are pinned.
do
	local copper = M.RESOURCE_BY_KEY.copper
	local before = copper.natural_node
	for _, row in ipairs(projection.resources) do
		if row.key == "copper" then row.natural_node = "default:stone_with_tin" end
	end
	local ok, err = pcall(native.population, wp40, projection)
	for _, row in ipairs(projection.resources) do
		if row.key == "copper" then row.natural_node = before end
	end
	check(not ok and tostring(err):find("digest differs", 1, true),
		"a changed resource node is refused")
	check(pcall(native.population, wp40, projection), "the restored rows validate")
end
print(("native rows: %d scatter rows after the strata and nests, digest %s"):format(
	scatter, native.identities().native_digest:sub(1, 16)))

-- B. The fill ores --------------------------------------------------------------
local S = dofile(wp40 .. "/r6_settlement.lua")
check(M.TIERS[1].y_min == -100 and M.TIERS[1].lower_half_y_max == -50,
	"fill_digest.lua's T1 matches the registry")
local fill_ore_at = S.r49_fill_ores_new(manifest.resources, M.TIERS[1],
	dofile(wp40 .. "/r6_hash.lua")().placement("10536739806879207652"))
local counts, hosts = {}, 0
local cubes = {}
for z = 0, 191 do
	for y = -37, 62 do
		for x = 0, 191 do
			hosts = hosts + 1
			local index = fill_ore_at(x, y, z)
			if index then
				counts[index] = (counts[index] or 0) + 1
				local resource = manifest.resources[index]
				local size = SHAPE[resource.max_nodes_per_vein][1]
				local key = index .. ":" .. math.floor(x / size) .. ":" ..
					math.floor(y / size) .. ":" .. math.floor(z / size)
				cubes[key] = (cubes[key] or 0) + 1
			end
		end
	end
end
local lines = {}
for index, resource in ipairs(manifest.resources) do
	local denominator = resource.denominators[1]
	local got = counts[index] or 0
	if denominator and resource.lower_half_of ~= 1 then
		local rate = got / hosts * denominator
		lines[#lines + 1] = ("%s 1/%.0f"):format(resource.key, hosts / math.max(got, 1))
		check(rate > 0.85 and rate < 1.15, ("%s fill rate %.3f of 1/%d"):format(
			resource.key, rate, denominator))
	else
		check(got == 0, resource.key .. " has no fill ore above y -50")
	end
end
print(("fill ores over %d hosts (y -37..62): %s"):format(hosts, table.concat(lines, ", ")))
-- Cluster sizes per occupied lattice cube: cap 8 about 8, gems mostly 1-2.
local cube_stats = {}
for key, n in pairs(cubes) do
	local index = tonumber(key:match("^(%d+):"))
	local stat = cube_stats[index] or {cubes = 0, nodes = 0, single = 0, pair = 0}
	cube_stats[index] = stat
	stat.cubes, stat.nodes = stat.cubes + 1, stat.nodes + n
	if n == 1 then stat.single = stat.single + 1 elseif n == 2 then stat.pair = stat.pair + 1 end
end
for index, stat in pairs(cube_stats) do
	local resource = manifest.resources[index]
	local mean = stat.nodes / stat.cubes
	if resource.max_nodes_per_vein == 8 then
		check(mean > 7 and mean < 9, resource.key .. " clusters of about 8: " .. mean)
	elseif resource.max_nodes_per_vein == 2 then
		local single, pair = stat.single / stat.cubes, stat.pair / stat.cubes
		print(("%s clusters: %.0f %% single, %.0f %% pairs"):format(resource.key,
			100 * single, 100 * pair))
		check(single > 0.5 and single < 0.7 and pair > 0.2 and pair < 0.4,
			resource.key .. " mostly single nodes and pairs")
	end
end
-- T1 Iron: only at or below T1's half.
local iron_index
for index, resource in ipairs(manifest.resources) do
	if resource.key == "iron" then iron_index = index end
end
local iron = 0
for z = 0, 63 do
	for y = -100, -50 do
		for x = 0, 63 do
			if fill_ore_at(x, y, z) == iron_index then iron = iron + 1 end
		end
	end
end
check(iron > 0, "fill iron in T1's lower half")
check(fill_ore_at(0, -101, 0) == nil and fill_ore_at(5, -400, 5) == nil,
	"no fill ore below T1")
-- LuaJIT and plain Lua 5.1 give the same placements.
local function run(interpreter)
	local pipe = io.popen(interpreter .. " " .. repo .. "/tools/r49_ore/fill_digest.lua " ..
		repo .. " 2>&1")
	local text = pipe:read("*a")
	pipe:close()
	return text
end
local jit_line = run("luajit")
check(jit_line:match("^fill digest: %d+ ores, checksum %d+"), "fill digest under LuaJIT: " ..
	jit_line)
local lua51 = repo .. "/tools/bin/lua51"
local probe = io.open(lua51, "rb")
if probe then
	probe:close()
	local plain_line = run(lua51)
	check(plain_line == jit_line, "fill digest LuaJIT " .. jit_line .. " vs Lua 5.1 " ..
		plain_line)
	io.write("LuaJIT = Lua 5.1: " .. jit_line)
else
	print("note: tools/bin/lua51 absent (tools/build_lua51.sh), Lua 5.1 comparison skipped")
end

-- C. The cave decorations ---------------------------------------------------------
local catalog = dofile(wp40 .. "/world_content_catalog.lua")
local habitat = dofile(wp40 .. "/habitat_registry.lua")
check(#decorations == 2, "two cave decorations")
local index = 0
for _, plant in ipairs(catalog.plants) do
	if plant.mode == "cave" then
		index = index + 1
		local row = decorations[index]
		check(row.deco_type == "simple" and row.flags == "all_floors" and row.biomes == nil,
			plant.key .. " simple all_floors without biomes")
		check(row.decoration == plant.node, plant.key .. " node")
		check(#row.place_on == #plant.hosts.stone, plant.key .. " host count")
		for host = 1, #row.place_on do
			check(row.place_on[host] == plant.hosts.stone[host], plant.key .. " host " .. host)
		end
		check(row.y_min == plant.min - 1 and row.y_max == plant.max - 1,
			plant.key .. " floor range is the plant range one lower")
		check(row.fill_ratio == 1 / habitat.initial_denominator(plant.key, plant.density),
			plant.key .. " one plant in the initial denominator per floor")
		print(("%s: floors y %d..%d on %s, fill_ratio 1/%d"):format(plant.key, row.y_min,
			row.y_max, table.concat(row.place_on, ","),
			habitat.initial_denominator(plant.key, plant.density)))
	end
end
check(index == 2, "the catalog has the two cave rows")
do
	local file = assert(io.open(wp40 .. "/world_content.lua", "r"))
	local source = file:read("*a")
	file:close()
	check(not source:find("cave_content_allowed_at", 1, true) and
		not source:find("cave_rows", 1, true), "world_content.lua places no cave rows")
end

print("R49 ORE PORTABLE PASS checks=" .. checks)
