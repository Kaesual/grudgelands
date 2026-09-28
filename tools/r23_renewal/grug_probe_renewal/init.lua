-- Disposable engine probe (Round 23 Lane B, habitat-driven vegetation
-- renewal). Never shipped: tools/r23_renewal/run.sh stages it through
-- tools/luanti_headless.sh.
--
-- Real engine, real world authority: the shipped grug_farming.renewal and
-- grug_mapgen.wp40.vegetation on a freshly generated world. A headless server
-- has no players, so the service never runs by itself; the probe calls the
-- renewal functions with explicit "player" positions.

local P = "[renewal_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
end

local renewal = grug_farming.renewal
local R = renewal.constants
local density = grug_mapgen.wp40.vegetation
local planner = grug_mapgen.wp40.planner_source
local WOODY_BIOMES = {grug_meadows = true, grug_pine_hills = true,
	grug_deep_forest = true, grug_elf_forest = true, grug_savanna = true}

local function key_of(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

-- The highest open support in a column near `y`, or in the nearest column
-- within 6 that has one (plants and trunks cover much natural ground).
local function column_surface(x, z, y)
	local found = core.find_nodes_in_area_under_air({x = x, y = y - 40, z = z},
		{x = x, y = y + 40, z = z}, density.support_names())
	local best
	for _, pos in ipairs(found) do
		if not best or pos.y > best.y then best = pos end
	end
	return best
end
local function surface_at(x, z, y)
	for ring = 0, 6 do
		for dz = -ring, ring do
			for dx = -ring, ring do
				if math.max(math.abs(dx), math.abs(dz)) == ring then
					local pos = column_surface(x + dx, z + dz, y)
					if pos then return pos end
				end
			end
		end
	end
end

local function evaluate(support, positions, class, roll)
	local budget = {left = R.VOLUME_BUDGET}
	local started = core.get_us_time()
	local result, node, pos = renewal.evaluate(support, positions, budget, roll or 0, class)
	return result, node, pos, core.get_us_time() - started
end

local function names_set(list)
	local result = {}
	for _, name in ipairs(list) do result[name] = true end
	return result
end

-- A natural site near a start: land, no exclusion, a biome with ground
-- cover and trees.
local function find_site()
	for _, start in ipairs(grug_core.start_identities()) do
		local anchor = start.anchor
		for radius = 40, 120, 4 do
			for step = 0, 15 do
				local angle = step * math.pi / 8
				local x = math.floor(anchor.x + math.cos(angle) * radius + 0.5)
				local z = math.floor(anchor.z + math.sin(angle) * radius + 0.5)
				local water, _, zone, biome, _, terrain_y = planner.column_values_at(x, z)
				if water == "land" and WOODY_BIOMES[biome] and terrain_y >= 2 and
						planner.static_exclusion_values_at(x, z, "vegetation") == nil and
						planner.housing_mask_id_at(x, z) == nil and
						planner.functional_surface_values_at(x, z) == nil and
						planner.overlay_exclusion_at(x, z) == nil and
						grug_core.world_alterable({x = x, y = terrain_y + 1, z = z}) then
					return {x = x, y = terrain_y, z = z}, start, zone, biome
				end
			end
		end
	end
end

-- Every distinct sapling grows through its registered timer on soil in open
-- sky at noon.
local function sapling_growth(site)
	local saplings, seen = {}, {}
	local species = density.woody_species()
	local ids = {}
	for id in pairs(species) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		if not seen[species[id]] then
			seen[species[id]] = true
			saplings[#saplings + 1] = species[id]
		end
	end
	core.set_timeofday(0.5)
	for index, sapling in ipairs(saplings) do
		local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
		local pos = {x = site.x - 21 + col * 14, y = site.y + 40, z = site.z - 14 + row * 14}
		local below = {x = pos.x, y = pos.y - 1, z = pos.z}
		local clear = core.get_node(pos).name == "air" and core.get_node(below).name == "air"
		if not clear then
			check(false, "sapling plot for " .. sapling .. " is not open sky")
		else
			core.set_node(below, {name = "default:dirt_with_grass"})
			core.set_node(pos, {name = sapling})
			local timer = core.get_node_timer(pos)
			local started = timer:is_started()
			local definition = core.registered_nodes[sapling]
			definition.on_timer(pos, 0)
			local grown = core.get_node(pos).name
			local woody = core.find_nodes_in_area(vector.offset(pos, -4, -6, -4),
				vector.offset(pos, 4, 30, 4), {"group:tree", "group:leaves"})
			check(started and grown ~= sapling and #woody > 0,
				"sapling " .. sapling .. " timer started and grows (now " .. grown ..
					", " .. #woody .. " tree/leaf nodes)")
		end
	end
end

local function run(site, start, zone, biome)
	log(string.format("site %s zone %s biome %s (start %s at %s)",
		core.pos_to_string(site), tostring(zone), tostring(biome), start.race_id,
		core.pos_to_string(start.anchor)))
	log("non-natural node names: " .. renewal.non_natural_count())
	local ground = surface_at(site.x, site.z, site.y)
	if not ground then
		-- Diagnostics for a site without open ground (engine run 5): load
		-- state and what the column holds.
		local names = {}
		for dy = -8, 8, 4 do
			local node = core.get_node_or_nil(vector.offset(site, 0, dy, 0))
			names[#names + 1] = (site.y + dy) .. "=" .. (node and node.name or "unloaded")
		end
		log("site column: " .. table.concat(names, " "))
	end
	check(ground ~= nil, "site has open ground")
	if not ground then return end
	local far = {{x = site.x + 200, y = ground.y, z = site.z}}

	-- 1. The real authority at the site.
	local support = core.get_node(ground).name
	local light = core.get_natural_light(vector.offset(ground, 0, 1, 0), 0.5)
	local categories, values = density.categories(ground.x, ground.y + 1, ground.z,
		support, light or 0)
	log("site support " .. support .. " light " .. tostring(light) .. " level " ..
		tostring(type(values) == "table" and values.level or values))
	local classes = {}
	for _, category in ipairs(categories or {}) do
		local names = {}
		for _, row in ipairs(category.species) do names[#names + 1] = row.node end
		log(string.format("category %s %s p=%.5f hosts=%d species=%s",
			category.class, category.key, category.p, #category.hosts,
			table.concat(names, ",")))
		classes[category.class] = true
	end
	check(classes.cover == true, "the site's biome palette hosts ground cover")

	-- 2. Ground cover appears on cleared ground.
	local cover = names_set(density.cover_names())
	local function clear_cover(center, radius)
		for _, pos in ipairs(core.find_nodes_in_area(vector.offset(center, -radius, -6, -radius),
				vector.offset(center, radius, 6, radius), density.cover_names())) do
			core.remove_node(pos)
		end
	end
	clear_cover(ground, 6)
	local result, node, placed_at, us = evaluate(ground, far, "cover", 0)
	check(result == "placed" and cover[node] == true,
		"cleared ground grows cover: " .. tostring(result) .. " " .. tostring(node) ..
			" (" .. us .. " us)")

	-- 3. Density cap: every open host support around B carries cover.
	-- B: ground where renewal may act (not the start's functional grade).
	local b
	for _, offset in ipairs({{12, 0}, {0, 12}, {0, -12}, {-12, 0}, {12, 12},
			{-12, 12}, {12, -12}, {-12, -12}, {24, 0}, {0, 24}, {0, -24}}) do
		local pos = not b and surface_at(site.x + offset[1], site.z + offset[2], site.y)
		if pos and planner.static_exclusion_values_at(pos.x, pos.z, "vegetation") == nil and
				planner.housing_mask_id_at(pos.x, pos.z) == nil and
				planner.functional_surface_values_at(pos.x, pos.z) == nil and
				planner.overlay_exclusion_at(pos.x, pos.z) == nil and
				grug_core.world_alterable(vector.offset(pos, 0, 1, 0)) then
			b = pos
		end
	end
	local b_categories = b and density.categories(b.x, b.y + 1, b.z,
		core.get_node(b).name, core.get_natural_light(vector.offset(b, 0, 1, 0), 0.5) or 0)
	local b_cover
	for _, category in ipairs(b_categories or {}) do
		if category.class == "cover" then b_cover = category end
	end
	if b_cover then
		local filled = 0
		for _, pos in ipairs(core.find_nodes_in_area_under_air(vector.offset(b, -6, -5, -6),
				vector.offset(b, 6, 5, 6), b_cover.hosts)) do
			if not (pos.x == b.x and pos.z == b.z) then
				core.set_node(vector.offset(pos, 0, 1, 0), {name = b_cover.species[1].node})
				filled = filled + 1
			end
		end
		result = evaluate(b, far, "cover", 0)
		check(result == "at_target", "cover-filled box (" .. filled ..
			" plants) takes nothing: " .. tostring(result))
	else
		check(false, "density cap spot has a cover category")
	end

	-- 4. Distance to players.
	result = evaluate(ground, {vector.offset(ground, 6, 1, 6)}, "cover", 0)
	check(result == "near_player", "a player 8 nodes away blocks placement: " .. tostring(result))
	result = evaluate(ground, {far[1], vector.offset(ground, 0, 20, 0)}, "cover", 0)
	check(result == "near_player", "a second player 19 nodes above blocks placement: " ..
		tostring(result))

	-- 5. Farm soil support.
	local c = surface_at(site.x - 12, site.z, site.y)
	if c then
		local saved = core.get_node(c)
		core.set_node(c, {name = "grug_farming:soil"})
		result = evaluate(c, far, nil, 0)
		check(result == "farm_soil", "farm soil support: " .. tostring(result))
		core.set_node(c, saved)
	end

	-- 6. Exclusions: the start's own pad and a road corridor.
	local anchor = start.anchor
	-- Whatever the pad is paved with: the permission test precedes habitat.
	local pad
	for y = anchor.y + 20, anchor.y - 20, -1 do
		local node = core.get_node_or_nil({x = anchor.x, y = y, z = anchor.z})
		local above = core.get_node_or_nil({x = anchor.x, y = y + 1, z = anchor.z})
		if not pad and node and above and node.name ~= "air" and above.name == "air" then
			pad = {x = anchor.x, y = y, z = anchor.z}
		end
	end
	if pad then
		result = evaluate(pad, far, nil, 0)
		check(result == "excluded" or result == "protected" or result == "functional" or
			result == "hard_row", "start pad: " .. tostring(result))
	else
		check(false, "start pad ground loaded")
	end
	local road
	for dz = -46, 46, 2 do
		for dx = -46, 46, 2 do
			if not road and planner.overlay_exclusion_at(anchor.x + dx, anchor.z + dz) ==
					"road_corridor" then
				local pos = surface_at(anchor.x + dx, anchor.z + dz, anchor.y)
				if pos then road = pos end
			end
		end
	end
	if road then
		result = evaluate(road, far, nil, 0)
		check(result == "overlay" or result == "excluded" or result == "protected",
			"road corridor " .. core.pos_to_string(road) .. ": " .. tostring(result))
	else
		log("no loaded road corridor within 46 of the start (covered by the fixture)")
	end

	-- 6b. The natural skin on a start's dry anchor grade renews like the writer
	-- grows it; grades the writer keeps bare do not.
	local grade, bare_grade
	for _, center in ipairs({site, anchor}) do
		for dz = -46, 46, 2 do
			for dx = -46, 46, 2 do
				local x, z = center.x + dx, center.z + dz
				local kind, _, feature = planner.functional_surface_values_at(x, z)
				if kind ~= nil and (not grade or not bare_grade) then
					local skin = kind == "land_grade" and type(feature) == "string" and
						feature:match("^anchor_%d%d%d$") ~= nil and
						planner.static_exclusion_values_at(x, z, "vegetation") == nil
					local pos = column_surface(x, z, center.y)
					if pos and not grade and skin and planner.column_values_at(x, z) == "land" and
							planner.hard_row_at(x, pos.y, z) == nil and
							planner.housing_mask_id_at(x, z) == nil and
							planner.overlay_exclusion_at(x, z) == nil and
							planner.hard_row_at(x, pos.y + 1, z) == nil and
							grug_core.world_alterable(vector.offset(pos, 0, 1, 0)) and
							grug_core.world_alterable(pos) and
							(core.get_natural_light(vector.offset(pos, 0, 1, 0), 0.5) or 0) >= 10 then
						grade = pos
					elseif pos and not bare_grade and not skin and
							planner.column_values_at(x, z) == "land" and
							planner.hard_row_at(x, pos.y + 1, z) == nil and
							planner.hard_row_at(x, pos.y, z) == nil and
							planner.static_exclusion_values_at(x, z, "vegetation") == nil and
							planner.housing_mask_id_at(x, z) == nil and
							grug_core.world_alterable(vector.offset(pos, 0, 1, 0)) then
						bare_grade = pos
					end
				end
			end
		end
	end
	if grade then
		clear_cover(grade, 5)
		result = evaluate(grade, far, "cover", 0)
		check(result == "placed", "dry anchor grade " .. core.pos_to_string(grade) ..
			" grows cover: " .. tostring(result))
	else
		log("no open, alterable dry anchor grade in the loaded boxes (covered by the fixture)")
	end
	if bare_grade then
		result = evaluate(bare_grade, far, nil, 0)
		check(result == "writer_bare", "writer-bare functional surface " ..
			core.pos_to_string(bare_grade) .. ": " .. tostring(result))
	else
		log("no alterable writer-bare functional surface in the loaded boxes")
	end

	-- 7. Sapling guard and placement.
	local markers = density.markers("tree")
	local guard_spot
	for dz = -30, 30, 3 do
		for dx = -30, 30, 3 do
			if not guard_spot then
				local pos = surface_at(site.x + dx, site.z + dz, site.y)
				local above = pos and vector.offset(pos, 0, 1, 0)
				local functional = pos and planner.functional_surface_values_at(pos.x, pos.z)
				if pos and core.get_item_group(core.get_node(pos).name, "soil") > 0 and
						(core.get_natural_light(above, 0.5) or 0) >= 13 and
						planner.static_exclusion_values_at(pos.x, pos.z, "vegetation") == nil and
						planner.housing_mask_id_at(pos.x, pos.z) == nil and
						functional == nil and planner.overlay_exclusion_at(pos.x, pos.z) == nil and
						grug_core.world_alterable(above) and grug_core.world_alterable(pos) then
					local woody_here
					for _, category in ipairs(density.categories(above.x, above.y, above.z,
							core.get_node(pos).name, 15) or {}) do
						if category.class == "tree" then woody_here = true end
					end
					if woody_here then guard_spot = pos end
				end
			end
		end
	end
	if guard_spot then
		-- Deficit: no trunks or saplings in the counting box.
		for _, pos in ipairs(core.find_nodes_in_area(vector.offset(guard_spot, -24, -6, -24),
				vector.offset(guard_spot, 24, 14, 24), markers)) do
			core.remove_node(pos)
		end
		local cobble = vector.offset(guard_spot, 4, 1, 3)
		core.set_node(cobble, {name = "default:cobble"})
		result, node, placed_at, us = evaluate(guard_spot, far, "tree", 0)
		check(result == "guard", "cobble 4 nodes away blocks the sapling: " ..
			tostring(result) .. " (" .. us .. " us)")
		core.remove_node(cobble)
		local soil = vector.offset(guard_spot, -5, 0, 2)
		local saved = core.get_node(soil)
		core.set_node(soil, {name = "grug_farming:soil"})
		result = evaluate(guard_spot, far, "tree", 0)
		check(result == "guard", "farm soil 5 nodes away blocks the sapling: " .. tostring(result))
		core.set_node(soil, saved)
		result, node, placed_at, us = evaluate(guard_spot, far, "tree", 0)
		local timer = placed_at and core.get_node_timer(placed_at)
		check(result == "placed" and core.get_item_group(node or "", "sapling") > 0 and
			timer and timer:is_started(),
			"clear natural ground takes a sapling with a running timer: " ..
				tostring(result) .. " " .. tostring(node) .. " (" .. us .. " us)")
	else
		check(false, "a sapling guard spot exists at the site")
	end

	-- 8. Every sapling species grows.
	sapling_growth(site)

	-- 9. Apples and blueberries regrow through default's own timers.
	local box_min, box_max = vector.offset(site, -48, -20, -48), vector.offset(site, 48, 60, 48)
	-- The generator's apples come from the apple tree template.
	local schematic = core.read_schematic(core.get_modpath("default") ..
		"/schematics/apple_tree.mts", {})
	local template_apples, template_zero = 0, 0
	for _, cell in ipairs(schematic.data) do
		if cell.name == "default:apple" then
			template_apples = template_apples + 1
			if (cell.param2 or 0) == 0 then template_zero = template_zero + 1 end
		end
	end
	check(template_apples > 0 and template_zero == template_apples,
		"apple tree template: " .. template_apples .. " apples, all param2 0")
	local apples = core.find_nodes_in_area(box_min, box_max, {"default:apple"})
	local param2_zero = 0
	for _, pos in ipairs(apples) do
		if core.get_node(pos).param2 == 0 then param2_zero = param2_zero + 1 end
	end
	log("natural apples in the site box: " .. #apples .. ", param2 0: " .. param2_zero)
	check(param2_zero == #apples, "every generated apple carries param2 0 (regrowing)")
	local apple = apples[1] or vector.offset(site, 0, 45, 30)
	if not apples[1] then core.set_node(apple, {name = "default:apple"}) end
	local old = core.get_node(apple)
	core.remove_node(apple)
	core.registered_nodes["default:apple"].after_dig_node(apple, old, {}, nil)
	check(core.get_node(apple).name == "default:apple_mark" and
		core.get_node_timer(apple):is_started(), "a picked natural apple leaves a timed mark")
	local berries = core.find_nodes_in_area(box_min, box_max,
		{"default:blueberry_bush_leaves_with_berries"})
	log("natural blueberry bushes' berry leaves in the site box: " .. #berries)
	local berry = berries[1] or vector.offset(site, 3, 45, 30)
	if not berries[1] then
		core.set_node(berry, {name = "default:blueberry_bush_leaves_with_berries"})
	end
	old = core.get_node(berry)
	core.registered_nodes[old.name].after_dig_node(berry, old, {}, nil)
	check(core.get_node(berry).name == "default:blueberry_bush_leaves" and
		core.get_node_timer(berry):is_started(), "picked blueberries leave timed leaves")
	check(core.get_modpath("grug_farming") and
		core.registered_lbms and (function()
			for _, lbm in ipairs(core.registered_lbms) do
				if lbm.name == "grug_farming:observe_natural_sources" then return false end
			end
			return true
		end)(), "no ecology LBM is registered")

	-- 10. Bounded cost per serviced player, and the distance rule in practice.
	renewal.reset_stats()
	local origin = vector.offset(ground, 0, 1, 0)
	local positions = {origin}
	local worst_us, total_us, worst_visits, near = 0, 0, 0, 0
	local placed = {}
	local SERVICES = 60
	for _ = 1, SERVICES do
		local started = core.get_us_time()
		local _, visits = renewal.service(origin, positions)
		local spent = core.get_us_time() - started
		worst_us, total_us = math.max(worst_us, spent), total_us + spent
		worst_visits = math.max(worst_visits, visits)
	end
	for _ = 1, 200 do
		local budget = {left = R.VOLUME_BUDGET}
		local spot = renewal.sample_spot(origin, budget)
		if spot then
			local outcome, name, pos = renewal.evaluate(spot, positions, budget)
			if outcome == "placed" then
				placed[#placed + 1] = name
				if vector.distance(pos, origin) < R.MIN_PLAYER_DISTANCE then near = near + 1 end
			end
		end
	end
	log(string.format("service cost: %d services, mean %.0f us, worst %d us, " ..
		"worst accounted visits %d of %d", SERVICES, total_us / SERVICES, worst_us,
		worst_visits, R.VOLUME_BUDGET))
	check(worst_visits <= R.VOLUME_BUDGET, "per-player node visits stay within the budget")
	check(near == 0, "no placement within 20 nodes of the player (" .. #placed .. " placed)")
	local stats = renewal.stats()
	local keys = {}
	for k in pairs(stats) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do log("stat " .. k .. " " .. stats[k]) end
end

core.register_on_mods_loaded(function()
	-- Static wiring: every woody species has a growth definition.
	local species = density.woody_species()
	local ids = {}
	for id in pairs(species) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		log("species " .. id .. " -> " .. species[id] .. " growth " ..
			tostring(default.sapling_growth_defs[species[id]] ~= nil))
	end
	local skipped = density.not_renewed()
	for _, id in ipairs((function()
		local list = {}
		for k in pairs(skipped) do list[#list + 1] = k end
		table.sort(list)
		return list
	end)()) do
		log("not renewed " .. id .. ": " .. skipped[id])
	end
end)

local function finish()
	log(string.format("RESULT %s (%d checks, %d failures)",
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("renewal probe done", false, 0)
end

local waited = 0
local function wait_starts()
	local ready = grug_core.starts_ready()
	if ready < 6 and waited < 150 then
		waited = waited + 2
		core.after(2, wait_starts)
		return
	end
	log("starts ready " .. ready .. " after " .. waited .. " s")
	local site, start, zone, biome = find_site()
	if not site then
		check(false, "a natural woody site near a start")
		finish()
		return
	end
	-- The site box, then the start pad and its roads (loaded from disk or
	-- generated); the tests run in the same server step as the last emerge.
	local boxes = {
		{vector.offset(site, -52, -24, -52), vector.offset(site, 52, 84, 52)},
		{vector.offset(start.anchor, -48, -24, -48), vector.offset(start.anchor, 48, 24, 48)},
	}
	local started = core.get_us_time()
	local function emerge(index)
		if index > #boxes then
			log(string.format("site emerged in %.1f s", (core.get_us_time() - started) / 1e6))
			local ok, err = pcall(run, site, start, zone, biome)
			if not ok then check(false, "probe error: " .. tostring(err)) end
			finish()
			return
		end
		core.emerge_area(boxes[index][1], boxes[index][2], function(_, _, remaining)
			if remaining > 0 then return end
			core.after(0, emerge, index + 1)
		end)
	end
	emerge(1)
end
core.after(2, wait_starts)
