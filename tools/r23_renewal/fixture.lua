-- Round 23 Lane B portable fixture: habitat-driven vegetation renewal.
--
-- Loads the shipped pure sources (habitat_registry, world_content_catalog,
-- the gathering catalog, the R6 decoration manifest, vegetation_density and
-- grug_farming/renewal.lua) against a small synthetic world: a flat meadow
-- in a start zone with a settlement strip, a road, a protected strip and an
-- unloaded rim. Engine-free and deterministic (own LCG, sorted output), so
-- LuaJIT and PUC Lua 5.1 must print byte-identical text.
--
-- Usage (repo root): luajit tools/r23_renewal/fixture.lua
--                    tools/bin/lua51 tools/r23_renewal/fixture.lua
local ROOT = (arg and arg[1]) or "."
local lines, failures = {}, 0
local function out(text) lines[#lines + 1] = text; print(text) end
local function check(ok, label)
	out((ok and "ok   " or "FAIL ") .. label)
	if not ok then failures = failures + 1 end
end
local function fmt(value) return string.format("%.6f", value) end

local wp40 = ROOT .. "/mods/MAPGEN/grug_mapgen/wp40"
local habitat = dofile(wp40 .. "/habitat_registry.lua")
local world = dofile(wp40 .. "/world_content_catalog.lua")
local gathering = dofile(ROOT .. "/mods/ITEMS/grug_gathering/catalog.lua")
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()

-- Stub of r6_content's decoration cover for three biomes: the row host and
-- the biome's fertile palette at 1, gravel at 4 for low vegetation.
local FERTILE = {
	grug_meadows = {"default:dirt_with_grass", "default:dirt",
		"grug_nodes:dirt_with_forest_litter"},
	grug_pine_hills = {"default:dirt_with_coniferous_litter",
		"grug_nodes:dirt_with_forest_litter", "default:dirt_with_grass"},
	grug_deep_forest = {"grug_nodes:dirt_with_forest_litter",
		"default:dirt_with_coniferous_litter", "default:dirt_with_grass"},
}
local by_id = {}
for _, row in ipairs(manifest.decorations) do by_id[row.id] = row end
local function decoration_cover(id, biome, support)
	local row = by_id[id]
	local listed = false
	for _, value in ipairs(row.biomes) do if value == biome then listed = true end end
	if not listed then return 0 end
	if support == row.host then return 1 end
	for _, name in ipairs(FERTILE[biome] or {}) do if name == support then return 1 end end
	if row.settlement_class == 4 and support == "default:gravel" then return 4 end
	return 0
end
local SUPPORTS = {"default:dirt", "default:dirt_with_coniferous_litter",
	"default:dirt_with_grass", "default:dry_dirt_with_dry_grass", "default:gravel",
	"default:sand", "default:stone", "grug_nodes:dirt_with_forest_litter",
	"grug_nodes:mud"}
-- One-column template stubs holding every marker a woody row may use.
local MARKERS = {"default:acacia_bush_stem", "default:acacia_tree",
	"default:aspen_tree", "default:blueberry_bush_leaves_with_berries",
	"default:bush_stem", "default:jungletree", "default:pine_bush_stem",
	"default:pine_tree", "default:tree", "grug_trees:gravewood_tree",
	"grug_trees:silverwood_tree"}
local records = {}
for _, row in ipairs(manifest.decorations) do
	if row.kind == "template" then
		local cells = {}
		for index, name in ipairs(MARKERS) do
			cells[index] = {name = name, probability = 254}
		end
		records[#records + 1] = {definition_id = row.id, rotations = {{
			size_x = 1, size_y = #MARKERS, size_z = 1, cells = cells}}}
	end
end

-- Synthetic world: flat meadow ground at y = 10 in a start zone.
local GROUND = 10
local LOADED = 100
local function column_values_at(x, z)
	if x >= 60 and x <= 61 then
		return "land", 1, "elandor_dawnmere_fields", "grug_meadows", "human", GROUND
	end
	return "land", 1, "elandor_dawnmere_fields", "grug_meadows", "human", GROUND
end
local planner = {
	column_values_at = column_values_at,
	static_exclusion_values_at = function(x, z, purpose)
		assert(purpose == "vegetation")
		if x < -60 then return 7, "exclude:anchor:test" end
		return nil
	end,
	housing_mask_id_at = function() return nil end,
	functional_surface_values_at = function() return nil end,
	hard_row_at = function() return nil end,
}
local density = dofile(wp40 .. "/vegetation_density.lua")({
	habitat = habitat, world_plants = world.plants,
	p9g_rows = gathering.p9g_sources(), decorations = manifest.decorations,
	decoration_cover = decoration_cover, support_names = SUPPORTS,
	template_records = records, column_values_at = column_values_at,
	overlay_exclusion_at = function(x)
		if x >= 60 and x <= 61 then return "road_corridor" end
		return nil
	end,
	surface_mob_level_at = function() return 5 end,
	primary_relief_at = function() return "plains" end,
})

local sparse = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function loaded(x, y, z)
	return x >= -LOADED and x <= LOADED and z >= -LOADED and z <= LOADED and
		y >= 0 and y <= 40
end
local function name_at(x, y, z)
	local value = sparse[key(x, y, z)]
	if value then return value end
	if y < GROUND then return "default:dirt" end
	if y == GROUND then return "default:dirt_with_grass" end
	return "air"
end
local function set_of(names)
	local result = {}
	for _, name in ipairs(names) do result[name] = true end
	return result
end
local visits = 0
local api = {
	density = density, planner = planner,
	get_node_or_nil = function(pos)
		if not loaded(pos.x, pos.y, pos.z) then return nil end
		return {name = name_at(pos.x, pos.y, pos.z), param2 = 0}
	end,
	set_node = function(pos, node) sparse[key(pos.x, pos.y, pos.z)] = node.name end,
	get_natural_light = function(pos) return pos.y > GROUND and 15 or 0 end,
	get_item_group = function(name, group)
		local groups = {
			["default:dirt_with_grass"] = {soil = 1},
			["default:dirt"] = {soil = 1},
			["grug_farming:soil"] = {soil = 2, grug_crop_soil = 1},
		}
		return (groups[name] or {})[group] or 0
	end,
	find_nodes_in_area = function(minp, maxp, names, grouped)
		local wanted, list, groups = set_of(names), {}, {}
		for x = minp.x, maxp.x do
			for z = minp.z, maxp.z do
				for y = minp.y, maxp.y do
					visits = visits + 1
					if loaded(x, y, z) then
						local name = name_at(x, y, z)
						if wanted[name] then
							local pos = {x = x, y = y, z = z}
							list[#list + 1] = pos
							groups[name] = groups[name] or {}
							groups[name][#groups[name] + 1] = pos
						end
					end
				end
			end
		end
		if grouped then return groups end
		return list
	end,
	find_nodes_in_area_under_air = function(minp, maxp, names)
		local wanted, list = set_of(names), {}
		for x = minp.x, maxp.x do
			for z = minp.z, maxp.z do
				for y = minp.y, maxp.y do
					visits = visits + 1
					if loaded(x, y, z) and loaded(x, y + 1, z) and
							wanted[name_at(x, y, z)] and name_at(x, y + 1, z) == "air" then
						list[#list + 1] = {x = x, y = y, z = z}
					end
				end
			end
		end
		return list
	end,
	world_alterable = function(pos) return pos.z <= 80 end,
	trees = true,
	non_natural = {"default:cobble", "grug_farming:soil", "ignore"},
}
local seed = 12345
api.random = function()
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local renewal = dofile(ROOT .. "/mods/ITEMS/grug_farming/renewal.lua")(api)
local R = renewal.constants

-- 1. Density authority at a meadow site.
out("-- density")
local categories = density.categories(20, GROUND + 1, 20, "default:dirt_with_grass", 15)
for _, category in ipairs(categories) do
	local names = {}
	for _, species in ipairs(category.species) do names[#names + 1] = species.node end
	out(category.class .. " " .. category.key .. " p=" .. fmt(category.p) ..
		" hosts=" .. #category.hosts .. " species=" .. table.concat(names, ","))
end
local classes = {}
for _, category in ipairs(categories) do
	classes[category.class] = (classes[category.class] or 0) + 1
end
check(classes.resource == 4 and classes.cover == 1 and classes.woody == 1,
	"meadow start zone: 4 resource species, one cover and one woody class")
local gravel = density.categories(20, GROUND + 1, 20, "default:gravel", 15)
local gravel_cover
for _, category in ipairs(gravel) do
	if category.class == "cover" then gravel_cover = category end
end
check(gravel_cover and math.abs(gravel_cover.p - 0.075) < 1e-9,
	"gravel hosts ground cover at a quarter of the meadow rate")
local dark = {density.categories(20, GROUND + 1, 20, "default:dirt_with_grass", 5)}
check(dark[1] == nil and dark[2] == "dark", "a dark surface spot grows nothing")
local road = {density.categories(60, GROUND + 1, 20, "default:dirt_with_grass", 15)}
check(road[1] == nil and road[2] == "overlay", "a road corridor grows nothing")
local saplings = density.woody_species()
local woody_ids = {}
for id in pairs(saplings) do woody_ids[#woody_ids + 1] = id end
table.sort(woody_ids)
for _, id in ipairs(woody_ids) do out("sapling " .. id .. " " .. saplings[id]) end
local skipped = density.not_renewed()
local skipped_ids = {}
for id in pairs(skipped) do skipped_ids[#skipped_ids + 1] = id end
table.sort(skipped_ids)
for _, id in ipairs(skipped_ids) do out("not_renewed " .. id .. ": " .. skipped[id]) end

-- 2. Placement rules at single spots (forced roll 0 = the chance always wins).
out("-- placement")
local far = {{x = 0, y = GROUND + 1, z = 0}}
local function run(x, z, class, roll, positions)
	local budget = {left = R.VOLUME_BUDGET}
	return renewal.evaluate({x = x, y = GROUND, z = z}, positions or far, budget,
		roll or 0, class)
end
local result, node = run(30, 30, "cover")
check(result == "placed" and node:match("^default:grass_%d$") ~= nil,
	"empty meadow: ground cover placed (" .. tostring(result) .. " " ..
		tostring(node) .. ")")
result = run(5, 5, "cover")
check(result == "near_player", "within 20 nodes of a player: nothing")
result = run(-70, 30, "cover")
check(result == "excluded", "settlement exclusion: nothing")
result = run(60, 30, "cover")
check(result == "overlay", "road corridor: nothing")
result = run(30, 90, "cover")
check(result == "protected", "protected territory: nothing")
sparse[key(33, GROUND, 33)] = "grug_farming:soil"
result = run(33, 33, "cover")
check(result == "farm_soil", "farm soil support: nothing")
sparse[key(33, GROUND, 33)] = nil
result = run(101, 30, "cover")
check(result == "unloaded", "unloaded spot: skipped")
result = run(34, 34, "resource")
check(result == "placed", "empty meadow: resource plant placed")

-- 3. Density cap: a box filled at natural cover density takes nothing more.
out("-- density cap")
for x = -40, -20 do
	for z = -40, -20 do
		if (x + z) % 3 == 0 then sparse[key(x, GROUND + 1, z)] = "default:grass_1" end
	end
end
-- Spots on open ground only (every third column already carries grass).
local capped_spots = {}
for x = -34, -26 do
	for z = -34, -26 do
		if (x + z) % 3 ~= 0 and #capped_spots < 20 then
			capped_spots[#capped_spots + 1] = {x, z}
		end
	end
end
local capped = {}
for _, spot in ipairs(capped_spots) do
	local r = run(spot[1], spot[2], "cover")
	capped[r] = (capped[r] or 0) + 1
end
local capped_keys = {}
for reason in pairs(capped) do capped_keys[#capped_keys + 1] = reason end
table.sort(capped_keys)
for _, reason in ipairs(capped_keys) do out("capped " .. reason .. " " .. capped[reason]) end
check((capped.at_target or 0) == 20, "cover at natural density: 20 of 20 at target")
local sparse_cover = {}
for x = -40, -20 do
	for z = -40, -20 do
		if (x + z) % 3 == 0 and (x * z) % 2 == 0 then
			sparse[key(x, GROUND + 1, z)] = nil
		end
	end
end
for _, spot in ipairs(capped_spots) do
	local r = run(spot[1], spot[2], "cover", 0.2)
	sparse_cover[r] = (sparse_cover[r] or 0) + 1
end
check((sparse_cover.placed or 0) > 0, "cover below natural density: placement resumes (" ..
	(sparse_cover.placed or 0) .. " of 20)")

-- 4. Sapling guard.
out("-- sapling guard")
sparse[key(45, GROUND + 1, -45)] = "default:cobble"
result = run(40, -40, "woody")
check(result == "guard", "cobble within 10 nodes: no sapling")
sparse[key(45, GROUND + 1, -45)] = nil
sparse[key(45, GROUND, -45)] = "grug_farming:soil"
result = run(40, -40, "woody")
check(result == "guard", "farm soil within 10 nodes: no sapling")
sparse[key(45, GROUND, -45)] = nil
result, node = run(40, -40, "woody")
check(result == "placed" and (node == "default:sapling" or node == "default:bush_sapling"),
	"clear ground: meadow sapling placed (" .. tostring(node) .. ")")
-- Keep planting next to it: the box reaches its natural tree count (about
-- two plants in 19 x 19 meadow columns) and then takes no more.
local woody_placed, woody_last = 1, nil
for step = 1, 8 do
	woody_last = run(40 + step, -40, "woody")
	if woody_last == "placed" then woody_placed = woody_placed + 1 end
end
check(woody_placed <= 2 and woody_last == "at_target",
	"saplings stop at the natural tree count (" .. woody_placed .. " placed)")
api.trees = false
local woody_seen = false
for step = 1, 40 do
	local r, n = run(-10 + step, -60, nil, 0)
	if r == "placed" and (n == "default:sapling" or n == "default:bush_sapling") then
		woody_seen = true
	end
end
check(not woody_seen, "grug_tree_regrowth off: no sapling")
api.trees = true

-- 5. Bounded cost per player and step.
out("-- budget")
local peak = 0
for step = 1, 30 do
	local before = visits
	local _, used = renewal.service({x = 0, y = GROUND + 1, z = 0}, far)
	peak = math.max(peak, used)
	check(visits - before <= R.VOLUME_BUDGET + 2 * R.SPOT_HALF_HEIGHT + 2,
		"service " .. step .. " visits " .. (visits - before) .. " within budget")
end
out("peak accounted visits " .. peak .. " of " .. R.VOLUME_BUDGET)
local stats = renewal.stats()
local reasons = {}
for reason in pairs(stats) do reasons[#reasons + 1] = reason end
table.sort(reasons)
for _, reason in ipairs(reasons) do out("stat " .. reason .. " " .. stats[reason]) end

-- Canonical digest of the output (portable, no bit operations).
local digest = 0
local text = table.concat(lines, "\n")
for index = 1, #text do digest = (digest * 131 + text:byte(index)) % 2147483629 end
print("DIGEST " .. digest)
print(failures == 0 and "RESULT PASS" or ("RESULT FAIL " .. failures))
