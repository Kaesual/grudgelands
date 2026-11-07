-- Round 70 lane SPAWN portable fixture (LuaJIT; round70-plan.md §2.1, §2.2).
--
--   luajit tools/r70_spawn/portable_test.lua REPO
--
--   A. The water predicates (habitat_registry.lua): "near_water" reaches 10
--      nodes (square) on ground at most 4 above the water, reads each block
--      of columns once and answers like the plain scan; "no_water" looks at
--      the four faces only.
--   B. The six rows' effective densities and habitats, as ruled.
--   C. Writer and renewal agree, height test included: the real r7_p9g.lua settlement decision and
--      the real vegetation_density.lua, on one small synthetic shore, accept
--      the same columns for Rock Salt and Stormkelp.
--   D. Renewal: Stormkelp counts a band of SHORE_REACH, a Rock Salt category
--      no band at all, and a resource row with a shore rule rolls four times
--      the resource chance (ground cover keeps its own).
-- Prints "R70 SPAWN PORTABLE PASS checks=<n>" or raises.
local repo = assert(arg and arg[1], "usage: portable_test.lua REPO")
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if not value then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", want " ..
		tostring(expected) .. ")")
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local habitat = dofile(wp40 .. "/habitat_registry.lua")
local world = dofile(wp40 .. "/world_content_catalog.lua")
local gathering = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")

-- A. The predicates, one water column at (wx, wz) with its surface at y 1.
do
	local function matches(predicate, wx, wz, ground)
		local rule = habitat.p9g_water_rule(predicate, function(x, z)
			return x == wx and z == wz and 1 or nil
		end)
		return rule(0, 0, ground or 3)
	end
	eq(habitat.VEGETATION.SHORE_REACH, 10, "A the ruled reach")
	local rise = habitat.VEGETATION.SHORE_HEIGHT
	eq(rise, 4, "A the height limit")
	for _, water in ipairs({{1, 0}, {0, -1}, {2, 1}, {-3, 0}, {0, 10}, {10, 10}, {-10, -10}, {-10, 7}}) do
		check(matches("near_water", water[1], water[2]),
			("A near_water sees water at %d,%d"):format(water[1], water[2]))
	end
	for _, water in ipairs({{11, 0}, {0, -11}, {11, 11}, {-11, 2}, {3, 11}}) do
		check(not matches("near_water", water[1], water[2]),
			("A near_water ends before %d,%d"):format(water[1], water[2]))
	end
	check(matches("near_water", 5, 0, 1 + rise), "A ground at the limit above the water")
	check(not matches("near_water", 5, 0, 2 + rise), "A ground one above the limit")
	check(not matches("near_water", 1, 0, 40), "A no cliff top beside the sea")
	check(matches("near_water", 5, 0, -3), "A ground below the surface is near it too")
	for _, water in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		check(not matches("no_water", water[1], water[2]),
			("A no_water refuses a face at %d,%d"):format(water[1], water[2]))
	end
	check(matches("no_water", 1, 1), "A no_water takes a diagonal: it touches no face")
	check(matches("no_water", 2, 0), "A no_water takes water two away")
	check(matches("none", 1, 0), "A none asks nothing")
	check(not habitat.is_p9g_predicate("dry_cardinal"), "A the old predicate is gone")
	check(habitat.p9g_shore_row("near_water") and not habitat.p9g_shore_row("no_water") and
		not habitat.p9g_shore_row("none"), "A only near_water is a shore row")

	-- What the test costs: a block is read once, and a dry test reads no more.
	local reads = 0
	local rule = habitat.p9g_water_rule("near_water", function(x, z)
		reads = reads + 1
		return x > 1000 and 1 or nil
	end)
	check(not rule(100, 100, 5), "A a dry column")
	check(reads <= 16 * 64, "A a first test reads at most 16 blocks (" .. reads .. ")")
	local first = reads
	check(not rule(101, 100, 5), "A its neighbour")
	check(reads <= first + 4 * 64, "A a neighbour reads only the blocks it adds")
	reads = 0
	for _ = 1, 3 do rule(101, 100, 5) end
	eq(reads, 0, "A a repeated test reads nothing")
	-- Blocks over the limit are read again, with the same answer.
	for offset = 0, 3000 do rule(offset * 32, 5000, 5) end
	check(not rule(101, 100, 5), "A an evicted block gives the same answer")
	check(rule(1005, 100, 3), "A and a wet block its water")
	-- The result is the plain scan's, wherever the column lies against the blocks.
	local function pond(x, z)
		if (x * 7 + z * 13) % 53 == 0 then return (x + z) % 9 end
		return nil
	end
	local blocks = habitat.p9g_water_rule("near_water", pond)
	local same = true
	for z = -40, 40 do
		for x = -40, 40 do
			local ground = (x * 3 + z) % 13
			local plain = false
			for dz = -10, 10 do
				for dx = -10, 10 do
					local level = pond(x + dx, z + dz)
					if level and ground - level <= rise then plain = true end
				end
			end
			same = same and blocks(x, z, ground) == plain
		end
	end
	check(same, "A the blocks answer like the plain 441-column scan")
end

-- B. The rows.
local p9g_rows, world_rows = {}, {}
for _, row in ipairs(gathering.p9g_sources()) do p9g_rows[row.key] = row end
for _, row in ipairs(world.plants) do world_rows[row.key] = row end
do
	local function effective(key, denominator)
		return habitat.initial_denominator(key, denominator)
	end
	eq(effective("rock_salt", p9g_rows.rock_salt.fill_denominator), 1024, "B Rock Salt")
	eq(effective("stormkelp", p9g_rows.stormkelp.fill_denominator), 256, "B Stormkelp")
	eq(effective("wild_cocoa", p9g_rows.wild_cocoa.fill_denominator), 1024, "B Wild Cocoa")
	eq(effective("frost_melon", world_rows.frost_melon.density), 32, "B Frost Melon")
	eq(effective("bamboo_shoot", world_rows.bamboo_shoot.density), 64, "B Bamboo Shoot")
	eq(effective("sugar_cane", world_rows.sugar_cane.density), 128, "B Sugar Cane")
	eq(p9g_rows.rock_salt.shore_predicate, "no_water", "B Rock Salt's rule")
	eq(p9g_rows.stormkelp.shore_predicate, "near_water", "B Stormkelp's rule")
	eq(#p9g_rows.rock_salt.zones, 3, "B Rock Salt's three zones")
	eq(#p9g_rows.stormkelp.zones, 5, "B Stormkelp's five zones")
	local salt = {}
	for _, host in ipairs(p9g_rows.rock_salt.hosts) do
		eq(host.biome, "grug_beach", "B Rock Salt stays on the beach")
		eq(host.zone, nil, "B Rock Salt on the whole beach of its zones")
		salt[host.support] = true
	end
	check(salt["default:sand"] and salt["default:gravel"] and salt["default:stone"],
		"B Rock Salt on sand, gravel and stone")
	local kelp, biomes = {}, 0
	for _, host in ipairs(p9g_rows.stormkelp.hosts) do
		eq(host.zone, nil, "B Stormkelp's hosts hold in every zone of the row")
		kelp[host.support] = true
		biomes = biomes + (host.support == "default:sand" and 1 or 0)
	end
	check(kelp["default:sand"] and kelp["default:gravel"] and kelp["default:stone"],
		"B Stormkelp on sand, gravel and stone")
	check(not kelp["grug_nodes:mud"] and not kelp["default:dirt_with_grass"],
		"B Stormkelp on bare ground only")
	eq(biomes, 16, "B Stormkelp in every land biome")
	local melon = world_rows.frost_melon.hosts
	check(melon.grug_pine_hills and melon.grug_blight and melon.grug_bone_forest and
		melon.grug_crags and melon.grug_swamp, "B Frost Melon's hosts reach the zones' rivers")
end

-- A small shore: a Gravesalt beach with a river strip at x 20..22 and a pond
-- at (5, 5), the ground 4 above the water and a dune 5 above it at z 8..9.
local ZONE, BIOME = "front_gravesalt_escarpment", "grug_beach"
local function water_column(x, z)
	return (x >= 20 and x <= 22) or (x == 5 and z == 5)
end
local function GROUND(_, z)
	return (z == 8 or z == 9) and 6 or 5
end
local function column_values_at(x, z)
	if water_column(x, z) then
		return "planned_water", 1, ZONE, BIOME, "human", -2, 1, nil
	end
	return "land", 1, ZONE, BIOME, "human", GROUND(x, z)
end
local density = dofile(wp40 .. "/vegetation_density.lua")({
	habitat = habitat, vegetation_rule = habitat.vegetation_rule("70", function() return ZONE end),
	world_plants = world.plants, p9g_rows = gathering.p9g_sources(),
	decorations = {}, decoration_cover = function() return 0 end,
	support_names = {"default:sand"}, template_records = {},
	column_values_at = column_values_at,
	overlay_exclusion_at = function() return nil end,
	surface_mob_level_at = function() return 55 end,
	static_exclusion_values_at = function() return nil end,
	surface_cave_run_at = function() return nil end,
	primary_relief_at = function() return "plains" end,
})

-- C. The real writer's decision against the real authority.
do
	local sha = common.new_sha256()
	local names, cids, refs = {}, {}, {}
	for index, row in ipairs(gathering.p9g_sources()) do names[index] = row.source_node end
	for index = #names + 1, 39 do names[index] = "fixture:content_" .. index end
	for index = 1, 39 do
		cids[index] = 5000 + index
		refs[names[index]] = index
	end
	local p9g_content = {schema = "grug_wp40_r7_p9g_content_v3", content_names = names,
		content_cids = cids,
		content_ref = function(name) return refs[name] end,
		resolve_p9g = function(index) return cids[index], 1, 1, 0, 8 end}
	local production_names = {}
	for index = 1, 174 do production_names[index] = "fixture:production_" .. index end
	local AIR, IGNORE = 1, 2
	local config = dofile(wp40 .. "/r7_p9g.lua")(gathering, p9g_content, sha, habitat)
	local tail = config.new({full_seed_string = "70",
		hash = {budget = function() return 0 end,
			placement = function()
				return function() return 0 end, function() return 0 end
			end},
		planner_source = {}, horizontal = {},
		content = {content_contract = function()
			return {schema = "grug_wp40_r7_production_r6_content_v1",
				content_names = production_names, ignore_cid = IGNORE,
				r5 = {resolve = function() return AIR, 0, 0 end}}
		end},
		source = {world_bounds = {min_x = -100, max_x = 100, min_z = -100, max_z = 100}},
		zones_session = {surface_mob_level_at = function() return 55 end},
		construction_identity = "fixture", runtime_mode = true})
	local SUPPORT = {["default:sand"] = 11, ["default:gravel"] = 12, ["default:stone"] = 13,
		["default:dirt_with_grass"] = 14}
	local index_of = {}
	for index, row in ipairs(gathering.p9g_sources()) do index_of[row.key] = index end
	for support, ref in pairs(SUPPORT) do
		local context = {
			inside_owner = function() return true end,
			original_at = function() return AIR, 0 end,
			settled_at = function(x, y, z)
				if y == GROUND(x, z) + 1 then return AIR, 0, 0, 0, 0, 0, 0 end
				return ref + 100, 0, 0, 3, 0, 0, 0
			end,
			production_content = function(name)
				local value = SUPPORT[name]
				return value, value and value + 100
			end,
			analytic_p7_ref = function() return ref end,
			analytic_p7_tuple = function() return ref + 100, 0, 0, 3, 0, 0, 0 end,
			exclusion_at = function() return nil end,
			column_values_at = column_values_at,
		}
		local accepted = {rock_salt = 0, stormkelp = 0}
		for z = -5, 25 do
			for x = 0, 30 do
				if not water_column(x, z) then
					local root = GROUND(x, z) + 1
					local list = density.categories(x, root, z, support, 15)
					local allowed = {}
					for _, category in ipairs(list or {}) do allowed[category.key] = true end
					for key in pairs(accepted) do
						local reason = tail:probe_reason(context, index_of[key], x, root, z)
						eq(reason == "accepted", allowed[key] == true,
							("C writer and renewal on %s at %d,%d for %s"):format(support, x, z, key))
						if reason == "accepted" then accepted[key] = accepted[key] + 1 end
					end
				end
			end
		end
		if support == "default:dirt_with_grass" then
			eq(accepted.rock_salt + accepted.stormkelp, 0, "C grass hosts neither")
		else
			check(accepted.rock_salt > 300, "C Rock Salt takes the beach on " .. support)
			check(accepted.stormkelp > 100, "C Stormkelp takes the shore on " .. support)
		end
	end
	-- A dry bank column (two from water): not touching, so Rock Salt may grow.
	local at = function(x, z)
		local list = density.categories(x, GROUND(x, z) + 1, z, "default:sand", 15) or {}
		local keys = {}
		for _, category in ipairs(list) do keys[category.key] = category end
		return keys
	end
	check(at(19, 0).rock_salt == nil, "C no Rock Salt on a face of the river")
	check(at(18, 0).rock_salt ~= nil, "C Rock Salt two nodes from it")
	check(at(10, 20).stormkelp ~= nil, "C Stormkelp ten nodes from the river")
	check(at(9, 20).stormkelp == nil, "C no Stormkelp eleven nodes from the river")
	check(at(15, 8).stormkelp == nil, "C no Stormkelp on the dune above the limit")
	check(at(15, 7).stormkelp ~= nil, "C Stormkelp at the limit beside it")
	check(at(10, 20).stormkelp.shore and at(10, 20).stormkelp.shore_band == 10,
		"C Stormkelp's band is its reach")
	check(at(18, 0).rock_salt.shore == false, "C Rock Salt counts no band")
end

-- D. Renewal's band and chance.
do
	local category = {class = "resource", key = "fixture", p = 1 / 4, hosts = {"default:sand"},
		names = {"fixture:plant"}, species = {{node = "fixture:plant", param2 = 0, weight = 1}}}
	local plants, open = 0, 400
	local placed
	local function list(count)
		local result = {}
		for index = 1, count do result[index] = {x = 0, y = 0, z = 0} end
		return result
	end
	local api = {
		density = {categories = function() return {category}, {} end},
		planner = {hard_row_at = function() return nil end},
		get_node_or_nil = function(pos)
			return {name = pos.y == 0 and "default:sand" or "air"}
		end,
		set_node = function(_, node) placed = node.name end,
		get_natural_light = function() return 15 end,
		get_item_group = function() return 0 end,
		find_nodes_in_area = function() return list(plants) end,
		find_nodes_in_area_under_air = function() return list(open) end,
		natural_ground_alterable = function() return true end,
		random = function() return 0 end,
		trees = false, non_natural = {},
	}
	local renewal = dofile(repo .. "/mods/ITEMS/grug_farming/renewal.lua")(api)
	local R = renewal.constants
	local far = {{x = 500, y = 500, z = 500}}
	local function evaluate(roll)
		placed = nil
		return (renewal.evaluate({x = 0, y = 0, z = 0}, far, {left = R.VOLUME_BUDGET}, roll,
			category.class))
	end
	eq(R.SHORE_RESOURCE_FACTOR, 4, "D the shore factor starts at four")
	-- p 1/4: a box 9 wide, 4.5 plants in the default band, 6.75 in a band of 3
	-- (the cap only; 22.5 in Stormkelp's band of 10).
	category.shore = true
	plants = 5
	eq(evaluate(0), "at_target", "D five plants fill the default band")
	category.shore_band = 3
	eq(evaluate(0), "placed", "D the same five leave room in a wider band")
	plants = 0
	category.shore, category.shore_band = false, nil
	eq(evaluate(0.04), "placed", "D a plain resource rolls under its chance")
	eq(evaluate(0.1), "roll", "D a plain resource rolls 0.05")
	eq(evaluate(0), "placed", "D Rock Salt's box is not capped")
	category.shore = true
	eq(evaluate(0.15), "placed", "D a shore row rolls four times the chance")
	eq(placed, "fixture:plant", "D and places its plant")
	eq(evaluate(0.25), "roll", "D but no more")
	category.class = "cover"
	eq(evaluate(0.45), "placed", "D ground cover keeps its chance")
	eq(evaluate(0.55), "roll", "D without the factor")
end

print(checks .. " checks, " .. failures .. " failures")
if failures > 0 then error("R70 SPAWN PORTABLE FAIL", 0) end
print("R70 SPAWN PORTABLE PASS checks=" .. checks)
