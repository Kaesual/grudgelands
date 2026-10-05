-- Round 36 lane W3 portable test (LuaJIT): ground cover in the bare band
-- round the start towns and the capitals.
--   A. habitat_registry.band_cover on the real decoration rows: every
--      one-node simple row (grass, ferns, dry grass, junglegrass, dry
--      shrubs, bone piles) and nothing else -- no tree, bush, the blueberry
--      bush, the reeds, the cactus or the fallen log, no taller simple row;
--   B. the "cover" exclusion purpose (simple_map.lua) on the real world of
--      seed 42 with its roads and capitals (tools/r28_zone_atlas/world.lua):
--      at all six starts the pad stays excluded, every band column stays
--      excluded for trees ("vegetation"), and the share of band columns open
--      to cover rises from about a third at the pad to nearly all at the
--      band's outer edge; beyond the band "cover" answers as "vegetation".
--      At all six capitals the city and the edge (within EDGE_REACH of the
--      wall line) stay excluded and the band beyond opens the same way;
--      capital_protection's `distance2` agrees with its member test. The
--      admitted columns are the same on a second ask and differ on another
--      seed's hash;
--   C. the real R6 planner over that world (tools/r23_tree_line/harness.lua)
--      in the cells round two starts of different biomes (Dawnmere Fields,
--      meadows; Sunscar Flats, savanna) and across a band stretch of every
--      capital: candidates in the band are band-cover rows on admitted
--      columns only, none on a pad or in a capital's edge, the band's cover
--      appears in both starts' own species, and every band candidate on a
--      road corridor is one the writer's vegetation rule refuses (the road
--      corridor answers for "cover" as for "vegetation");
--   D. the renewal density authority (vegetation_density.lua) over that
--      world: an admitted band column offers ground cover only, a pad column
--      and a closed band column nothing.
--
-- Usage (repo root): luajit tools/r36_w3/portable_test.lua [REPO]
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function out(message) print(message) end
local floor, sqrt = math.floor, math.sqrt

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local habitat = dofile(wp40 .. "/habitat_registry.lua")
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
local capital_protection = dofile(wp40 .. "/capital_protection.lua")

-- A. The rows ---------------------------------------------------------------
local BAND_ROWS = {}
do
	local simple, band = 0, 0
	for _, row in ipairs(manifest.decorations) do
		local yes = habitat.band_cover(row)
		if row.kind == "simple" then
			simple = simple + 1
			check(yes, "A simple row " .. row.id .. " grows in the band")
		else
			check(not yes, "A template row " .. row.id .. " stays out of the band")
		end
		if yes then band = band + 1 BAND_ROWS[row.id] = true end
	end
	check(simple == band and band >= 20, "A every simple row and only those (" .. band .. ")")
	check(not habitat.band_cover({id = "tall", kind = "simple", settlement_class = 3}),
		"A a 2-4 node tall simple row stays out")
	for _, id in ipairs({"swamp_papyrus", "pine_hills_blueberry_bush", "meadows_bush",
			"meadows_apple_tree", "badlands_large_cactus", "deep_forest_apple_log"}) do
		check(not BAND_ROWS[id], "A " .. id .. " stays out of the band")
	end
	out(("A: %d band-cover rows"):format(band))
end

-- The world -----------------------------------------------------------------
local SEED = "42"
local started = os.clock()
local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, SEED)
local ps = W.planner_source
out(("world %s built in %.1f s"):format(SEED, os.clock() - started))
local function static(x, z, purpose)
	return select(2, ps.static_exclusion_values_at(x, z, purpose))
end

-- B. The rule ---------------------------------------------------------------
local PAD_HALF, BAND = 64, 12
local starts, capitals = {}, {}
for _, row in ipairs(W.source.hard_protection) do
	if row.recipe_id == "hard_start_town_v1" then
		starts[#starts + 1] = {anchor = row.source_anchor_id, x = row.center.x, z = row.center.z}
	else
		capitals[#capitals + 1] = {anchor = row.source_anchor_id, x = row.center.x,
			z = row.center.z}
	end
end
check(#starts == 6 and #capitals == 6, "B six starts and six capitals")
local function pad_distance(s, x, z)
	local ex = math.max(s.x - PAD_HALF - x, x - (s.x + PAD_HALF - 1), 0)
	local ez = math.max(s.z - PAD_HALF - z, z - (s.z + PAD_HALF - 1), 0)
	return sqrt(ex * ex + ez * ez)
end
-- the admitted band columns, for C and D
local admitted, closed = {}, {}
local function key(x, z) return x .. "," .. z end
local admitted_list = {}
local bins = {{0, 4}, {4, 8}, {8, 12}}
for _, s in ipairs(starts) do
	local own = static(s.x, s.z, "vegetation")
	check(own ~= nil and static(s.x, s.z, "cover") == own, s.anchor .. " pad centre excluded")
	local open, total = {0, 0, 0}, {0, 0, 0}
	local pad_open, ring_differs, ring = 0, 0, 0
	local reach = PAD_HALF + BAND + 8
	for z = s.z - reach, s.z + reach - 1 do
		for x = s.x - reach, s.x + reach - 1 do
			local d = pad_distance(s, x, z)
			if d == 0 then
				if static(x, z, "cover") == nil then pad_open = pad_open + 1 end
			elseif d <= BAND then
				local veg = static(x, z, "vegetation")
				check(veg ~= nil, s.anchor .. " band column excluded for trees")
				if veg == own then
					local b = d <= 4 and 1 or (d <= 8 and 2 or 3)
					total[b] = total[b] + 1
					if static(x, z, "cover") == nil then
						open[b] = open[b] + 1
						admitted[key(x, z)] = true
						admitted_list[#admitted_list + 1] = {x, z}
					else
						closed[key(x, z)] = true
					end
				end
			else
				ring = ring + 1
				if static(x, z, "cover") ~= static(x, z, "vegetation") then
					ring_differs = ring_differs + 1
				end
			end
		end
	end
	check(pad_open == 0, s.anchor .. " every pad column stays excluded")
	check(ring_differs == 0 and ring > 1000, s.anchor .. " beyond the band cover = vegetation")
	local shares = {}
	for b = 1, 3 do shares[b] = total[b] > 0 and open[b] / total[b] or 0 end
	out(("B %s band shares d0-4 %.2f (%d) d4-8 %.2f (%d) d8-12 %.2f (%d)"):format(
		s.anchor, shares[1], total[1], shares[2], total[2], shares[3], total[3]))
	check(shares[1] > 0.3 and shares[1] < 0.55, s.anchor .. " a third to a half near the pad")
	check(shares[2] > shares[1] and shares[3] > shares[2], s.anchor .. " the share rises outward")
	check(shares[3] > 0.8, s.anchor .. " nearly all at the band's outer edge")
end
-- capitals: rays from the anchor across the edge and the band
for _, c in ipairs(capitals) do
	local shape = W.capital_shapes[c.anchor]
	check(shape and type(shape.distance2) == "function", c.anchor .. " distance2 published")
	check(shape.edge_reach == capital_protection.EDGE_REACH and
		shape.band == capital_protection.BAND, c.anchor .. " band geometry published")
	local E, B = shape.edge_reach, shape.band
	local own = static(c.x, c.z, "vegetation")
	local open, total = {0, 0, 0}, {0, 0, 0}
	local edge_open, member_mismatch, ring_differs, samples = 0, 0, 0, 0
	for ray = 0, 127 do
		local angle = ray * math.pi / 64
		local dx, dz = math.cos(angle), math.sin(angle)
		for step = 100, 300 do
			local x, z = floor(c.x + dx * step + 0.5), floor(c.z + dz * step + 0.5)
			local d2 = shape.distance2(x, z)
			samples = samples + 1
			if (d2 ~= nil) ~= shape.member(x, z) then member_mismatch = member_mismatch + 1 end
			if d2 ~= nil and d2 > 0 then
				local veg = static(x, z, "vegetation")
				if veg == own then
					local d = sqrt(d2)
					if d <= E then
						if static(x, z, "cover") == nil then edge_open = edge_open + 1 end
					else
						local b = d <= E + 4 and 1 or (d <= E + 8 and 2 or 3)
						total[b] = total[b] + 1
						if static(x, z, "cover") == nil then open[b] = open[b] + 1 end
					end
				end
			elseif d2 == nil and static(x, z, "cover") ~= static(x, z, "vegetation") then
				ring_differs = ring_differs + 1
			end
		end
	end
	local shares = {}
	for b = 1, 3 do shares[b] = total[b] > 0 and open[b] / total[b] or 0 end
	out(("B %s band shares d9-13 %.2f (%d) d13-17 %.2f (%d) d17-21 %.2f (%d)"):format(
		c.anchor, shares[1], total[1], shares[2], total[2], shares[3], total[3]))
	check(member_mismatch == 0 and samples > 20000, c.anchor .. " distance2 agrees with member")
	check(edge_open == 0, c.anchor .. " the edge strip stays excluded")
	check(ring_differs == 0, c.anchor .. " beyond the band cover = vegetation")
	check(total[1] > 50 and total[3] > 50, c.anchor .. " band sampled")
	check(shares[1] > 0.3 and shares[1] < 0.6 and shares[3] > 0.8 and
		shares[3] > shares[1], c.anchor .. " the band opens a third to nearly all")
end
-- the same answer twice; another seed's hash admits other columns
do
	local same = true
	for index = 1, #admitted_list, 7 do
		local x, z = admitted_list[index][1], admitted_list[index][2]
		if static(x, z, "cover") ~= nil then same = false end
	end
	check(same, "B the admitted columns are stable")
	local other = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, "7")
	local differ, compared = 0, 0
	for index = 1, #admitted_list, 3 do
		local x, z = admitted_list[index][1], admitted_list[index][2]
		local o = select(2, other.planner_source.static_exclusion_values_at(x, z, "cover"))
		local v = select(2, other.planner_source.static_exclusion_values_at(x, z, "vegetation"))
		if v ~= nil then
			compared = compared + 1
			if o ~= nil then differ = differ + 1 end
		end
	end
	out(("B seed 7 closes %d of %d columns seed 42 opens"):format(differ, compared))
	check(compared > 1000 and differ > compared / 10, "B the hash follows the seed")
end

-- C. The planner --------------------------------------------------------------
local H = dofile(repo .. "/tools/r23_tree_line/harness.lua").new(repo)
local content = H.content(ps.start_ground_names())
local _, planner = H.planner(SEED, ps, content, W.source)
local rows = content.decorations()
local function cell_candidates(cx, cz)
	local list = planner.build_cell(cx, cz)
	local result = {}
	for _, row in ipairs(list) do
		if floor(row.x / 16) == cx and floor(row.z / 16) == cz then result[#result + 1] = row end
	end
	return result
end
-- The writer's claim rule for a decoration footprint cell (r6_settlement.lua
-- exclusion_reason with the row's `plant_purpose`): the static exclusion of
-- the row's purpose, then the road corridor.
local function writer_accepts(row, x, z)
	local purpose = habitat.band_cover(row) and "cover" or "vegetation"
	return static(x, z, purpose) == nil and ps.overlay_exclusion_at(x, z) ~= "road_corridor"
end
local START_NAMES = {anchor_002 = "dawnmere", anchor_005 = "sunscar"}
for _, s in ipairs(starts) do
	if START_NAMES[s.anchor] then
		local name = START_NAMES[s.anchor]
		local species, band, pad, woody, closed_hit, road, road_refused = {}, 0, 0, 0, 0, 0, 0
		local reach = PAD_HALF + BAND + 16
		for cz = floor((s.z - reach) / 16), floor((s.z + reach) / 16) do
			for cx = floor((s.x - reach) / 16), floor((s.x + reach) / 16) do
				for _, c in ipairs(cell_candidates(cx, cz)) do
					local row = rows[c.catalog]
					local d = pad_distance(s, c.x, c.z)
					if d == 0 then
						pad = pad + 1
					elseif d <= BAND then
						band = band + 1
						if not BAND_ROWS[row.id] then woody = woody + 1 end
						if not admitted[key(c.x, c.z)] then closed_hit = closed_hit + 1 end
						species[row.asset_or_node] = (species[row.asset_or_node] or 0) + 1
						if ps.overlay_exclusion_at(c.x, c.z) == "road_corridor" then
							road = road + 1
							if not writer_accepts(row, c.x, c.z) then
								road_refused = road_refused + 1
							end
						end
					end
				end
			end
		end
		-- the planner's two hosts on the band's columns (r6_planner.lua
		-- column_tuple): no tree host anywhere, a cover host only where admitted
		local tree_host, cover_host, stray = 0, 0, 0
		for z = s.z - PAD_HALF - BAND, s.z + PAD_HALF + BAND - 1 do
			for x = s.x - PAD_HALF - BAND, s.x + PAD_HALF + BAND - 1 do
				local d = pad_distance(s, x, z)
				if d > 0 and d <= BAND then
					local values = {planner.column_values_at(x, z)}
					if values[11] then tree_host = tree_host + 1 end
					if values[13] then
						cover_host = cover_host + 1
						if not admitted[key(x, z)] then stray = stray + 1 end
					end
				end
			end
		end
		check(tree_host == 0, name .. " no tree host in the band")
		check(stray == 0 and cover_host > 1000, name .. " cover hosts on admitted columns only (" ..
			cover_host .. ")")
		local names = {}
		for n, count in pairs(species) do names[#names + 1] = n .. " " .. count end
		table.sort(names)
		out(("C %s: %d band candidates (%s), %d on a road corridor, %d on the pad"):format(
			name, band, table.concat(names, ", "), road, pad))
		check(pad == 0, name .. " no candidate on the pad")
		check(woody == 0, name .. " only band-cover rows in the band")
		check(closed_hit == 0, name .. " only on admitted band columns")
		check(band > 200, name .. " the band grows cover")
		check(road == road_refused, name .. " road corridor candidates refused by the writer")
		if name == "dawnmere" then
			check((species["default:grass_1"] or 0) > 0, name .. " meadow grass in the band")
		else
			check((species["default:dry_grass_1"] or 0) > 0, name .. " dry grass in the band")
		end
	end
end
for _, c in ipairs(capitals) do
	local shape = W.capital_shapes[c.anchor]
	local own = static(c.x, c.z, "vegetation")
	-- the north-east stretch of the band: walk out to the wall line
	local step = 0
	while shape.inside(c.x + step, c.z + step) do step = step + 1 end
	local bx, bz = c.x + step + 10, c.z + step + 10
	local band, edge, woody, refused = 0, 0, 0, 0
	for cz = floor(bz / 16) - 2, floor(bz / 16) + 2 do
		for cx = floor(bx / 16) - 2, floor(bx / 16) + 2 do
			for _, cand in ipairs(cell_candidates(cx, cz)) do
				local row = rows[cand.catalog]
				local d2 = shape.distance2(cand.x, cand.z)
				if d2 ~= nil and d2 > 0 and static(cand.x, cand.z, "vegetation") == own then
					-- a city's outer ring may lie beyond its graded collar, where
					-- the planner hosts every row and the writer refuses them
					if not writer_accepts(row, cand.x, cand.z) then
						refused = refused + 1
					elseif d2 <= shape.edge_reach * shape.edge_reach then
						edge = edge + 1
					else
						band = band + 1
						if not BAND_ROWS[row.id] then woody = woody + 1 end
					end
				end
			end
		end
	end
	out(("C %s: the writer keeps %d band candidates, %d in the edge (%d refused)"):format(
		c.anchor, band, edge, refused))
	check(edge == 0, c.anchor .. " nothing in the edge strip")
	check(woody == 0, c.anchor .. " band: ground cover only")
	check(band > 0, c.anchor .. " the band grows cover")
end

-- D. Renewal density ----------------------------------------------------------
do
	local support_names = content.content_contract().content_names
	local records = {}
	for _, row in ipairs(manifest.decorations) do
		if row.kind == "template" then
			records[#records + 1] = {definition_id = row.id, rotations = {{
				size_x = 1, size_y = 1, size_z = 1,
				cells = {{name = "default:tree", probability = 254}}}}}
		end
	end
	local markers = {"default:acacia_bush_stem", "default:acacia_tree",
		"default:aspen_tree", "default:blueberry_bush_leaves",
		"default:blueberry_bush_leaves_with_berries", "default:bush_stem",
		"default:jungletree", "default:pine_bush_stem", "default:pine_tree",
		"default:tree", "grug_trees:gravewood_tree", "grug_trees:silverwood_tree"}
	for _, record in ipairs(records) do
		local cells = {}
		for i, name in ipairs(markers) do cells[i] = {name = name, probability = 254} end
		record.rotations[1].size_y, record.rotations[1].cells = #cells, cells
	end
	local density = dofile(wp40 .. "/vegetation_density.lua")({
		habitat = habitat, vegetation_rule = content.vegetation_rule(SEED, ps),
		world_plants = {}, p9g_rows = {}, decorations = manifest.decorations,
		decoration_cover = function(id, biome, support_name)
			local ref = content.content_ref(support_name)
			return ref and content.decoration_cover(id, biome, ref) or 0
		end,
		support_names = support_names, template_records = records,
		column_values_at = ps.column_values_at,
		overlay_exclusion_at = ps.overlay_exclusion_at,
		surface_mob_level_at = function() return 5 end,
		primary_relief_at = ps.primary_relief_at,
		static_exclusion_values_at = ps.static_exclusion_values_at,
		surface_cave_run_at = ps.surface_cave_run_at,
	})
	local s
	for _, row in ipairs(starts) do if row.anchor == "anchor_002" then s = row end end
	local covered, others, refused, tested = 0, 0, 0, 0
	for z = s.z - PAD_HALF - BAND, s.z + PAD_HALF + BAND - 1 do
		local x = s.x - PAD_HALF - 6
		local _, _, _, biome, _, ty, _, _, _, support = planner.column_values_at(x, z)
		local cats, why = density.categories(x, ty + 1, z, support, 15)
		if admitted[key(x, z)] and ps.overlay_exclusion_at(x, z) ~= "road_corridor" and
				#density.palette("cover", biome, support) > 0 then
			tested = tested + 1
			for _, cat in ipairs(cats or {}) do
				if cat.class == "cover" then covered = covered + 1 else others = others + 1 end
			end
		elseif closed[key(x, z)] then
			check(cats == nil and why == "writer_bare", "D a closed band column offers nothing")
			refused = refused + 1
		end
	end
	local _, why = density.categories(s.x, select(6, ps.column_values_at(s.x, s.z)) + 1, s.z,
		"default:dirt_with_grass", 15)
	check(why == "writer_bare", "D the pad offers nothing")
	out(("D dawnmere band at d 6: %d admitted columns offer cover %d times, other classes %d; " ..
		"%d closed columns refuse"):format(tested, covered, others, refused))
	check(tested > 20 and covered == tested and others == 0, "D admitted columns: cover only")
	check(refused > 10, "D closed columns sampled")
end

out(("R36 W3 PORTABLE PASS checks=%d (%.1f s)"):format(checks, os.clock() - started))
