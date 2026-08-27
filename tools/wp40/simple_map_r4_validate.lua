-- Independent exhaustive and targeted validation for the WP40 R4 zone payload.

return function(common)
	local validator = {}
	local NIL = "-"
	local EXTENT_SHARD_SCHEMA = "grug_wp40_simple_map_r4_extent_shard_v1"
	local POPULATION_SCHEMA = "grug_wp40_simple_map_r4_population_v1"
	local CONSTRUCTION_SCHEMA = "grug_wp40_simple_map_r4_construction_validation_v1"
	local SUPPLEMENTAL_SCHEMA = "grug_wp40_simple_map_r4_supplemental_validation_v1"
	local API_SCHEMA = "grug_wp40_simple_map_r4_api_validation_v1"
	local TARGETED_SCHEMA = "grug_wp40_simple_map_r4_targeted_rows_v1"
	local EXPECTED_WATER_COUNTS = {
		land = 25701492,
		planned_water = 4401570,
		coastal_shelf = 1515520,
		deep_ocean = 17870090,
		immutable_dragon_channel = 491889,
	}
	local OWNER_CLASSES = {land = true, planned_water = true,
		coastal_shelf = true}
	local WATER_CLASSES = {land = true, planned_water = true,
		coastal_shelf = true, deep_ocean = true,
		immutable_dragon_channel = true}

	local function fail(message)
		error("WP40 simple-map R4 validation: " .. message, 0)
	end

	local function method(value, name)
		if type(value) ~= "table" or type(value[name]) ~= "function" then
			fail("session." .. name .. " missing")
		end
	end

	local function require_context(context, full)
		if type(context) ~= "table" or type(context.source) ~= "table" then
			fail("validation context/source missing")
		end
		if context.source.schema ~= common.SOURCE_SCHEMA then
			fail("validation source schema differs")
		end
		if full and (type(context.horizontal) ~= "table" or
				type(context.height) ~= "table") then
			fail("full validation requires accepted horizontal and height sessions")
		end
		return context.source
	end

	local function nonempty_text(value, label)
		if type(value) ~= "string" or value == "" or value:find("[\t\r\n]") then
			fail(label .. " is not safe nonempty text")
		end
		return value
	end

	local function key(value)
		if value == nil then return NIL end
		return nonempty_text(common.scalar(value), "count key")
	end

	local function increment(map, map_key, amount)
		map_key = key(map_key)
		amount = amount or 1
		common.safe_integer(amount, "count increment")
		if amount < 0 then fail("negative count increment") end
		map[map_key] = (map[map_key] or 0) + amount
		common.safe_integer(map[map_key], "count value")
	end

	local function add_nested(map, first, second, amount)
		first, second = key(first), key(second)
		local row = map[first]
		if not row then row = {} map[first] = row end
		increment(row, second, amount)
	end

	local function count_total(map)
		local total = 0
		for map_key, value in pairs(map) do
			nonempty_text(map_key, "count-map key")
			common.safe_integer(value, "count-map value")
			if value < 0 then fail("negative count-map value") end
			total = total + value
		end
		return common.safe_integer(total, "count-map total")
	end

	local function exact_equal(a, b, seen)
		if type(a) ~= type(b) then return false end
		if type(a) ~= "table" then return a == b end
		seen = seen or {}
		if seen[a] then return seen[a] == b end
		seen[a] = b
		for k, v in pairs(a) do
			if not exact_equal(v, b[k], seen) then return false end
		end
		for k in pairs(b) do if a[k] == nil then return false end end
		return true
	end

	local function expect_error(callback, label)
		local ok = pcall(callback)
		if ok then fail("expected programmer error: " .. label) end
	end

	local function evidence_bytes(value)
		local builder = common.new_tsv()
		common.add_evidence_at(builder, "projection", value)
		return builder.body()
	end

	local function digest_rows(raw_sha256, rows)
		return common.digest_hex(raw_sha256, table.concat(rows))
	end

	local function scalar(value)
		return value == nil and NIL or common.scalar(value)
	end

	local function expected_zone(source, index)
		local row = source.zones[index]
		local biomes = {}
		for biome_index = 1, #row.biomes do
			biomes[biome_index] = {id = row.biomes[biome_index].id,
				share = row.biomes[biome_index].share}
		end
		return {
			numeric_id = index, id = row.id, display_name = row.display_name,
			macro_region = row.macro_region, race_region = row.race_region,
			faction = row.faction ~= false and row.faction or nil,
			territory_rule = row.territory_rule, pvp_rule = row.pvp_rule,
			level_min = row.level_min, level_max = row.level_max,
			primary_relief_id = row.primary_relief_id,
			difficulty_target = row.difficulty_target,
			civic_no_hostiles = row.civic_no_hostiles == true,
			hub = {x = row.hub.x, z = row.hub.z}, biomes = biomes,
		}
	end

	local function source_maps(source)
		local zones_by_id, zones_by_numeric, anchors_by_id, routes_by_id = {}, {}, {}, {}
		for index = 1, #source.zones do
			local row = source.zones[index]
			if row.numeric_id ~= index or zones_by_id[row.id] then
				fail("source zone identity/order differs")
			end
			zones_by_id[row.id], zones_by_numeric[index] = row, row
		end
		for index = 1, #source.anchors do
			local row = source.anchors[index]
			if anchors_by_id[row.id] then fail("duplicate source anchor") end
			anchors_by_id[row.id] = row
		end
		for index = 1, #source.routes do
			local row = source.routes[index]
			if routes_by_id[row.id] then fail("duplicate source route") end
			routes_by_id[row.id] = row
		end
		return zones_by_id, zones_by_numeric, anchors_by_id, routes_by_id
	end

	local function validate_palette_partitions(source, raw_sha256)
		local rows, vocabulary = {}, {}
		local entry_count, roll_case_count = 0, 0
		for zone_index = 1, common.dense_count(source.zones, "source zones") do
			local zone = source.zones[zone_index]
			local palette_count = common.dense_count(zone.biomes,
				"source zone biome palette")
			if palette_count == 0 then
				fail("logical palette is empty at " .. scalar(zone.id))
			end
			local authored_total, selected_counts, seen_ids = 0, {}, {}
			for palette_index = 1, palette_count do
				local entry = zone.biomes[palette_index]
				local biome_id = nonempty_text(entry.id,
					"logical palette biome id")
				local share = common.safe_integer(entry.share,
					"logical palette authored weight")
				if share <= 0 then
					fail("logical palette weight is not positive at " .. zone.id ..
						" entry " .. palette_index .. " (" .. biome_id .. ")")
				end
				if seen_ids[biome_id] then
					fail("duplicate logical palette biome at " .. zone.id ..
						": " .. biome_id)
				end
				seen_ids[biome_id], vocabulary[biome_id] = true, true
				authored_total = authored_total + share
				selected_counts[palette_index] = 0
				entry_count = entry_count + 1
			end
			if authored_total ~= 100 then
				fail("logical palette weight total differs at " .. zone.id ..
					": expected 100, observed " .. authored_total)
			end
			for roll = 0, 99 do
				local cumulative, selected_index = 0, nil
				for palette_index = 1, palette_count do
					cumulative = cumulative + zone.biomes[palette_index].share
					if roll < cumulative then
						selected_index = palette_index
						break
					end
				end
				if selected_index == nil then
					fail("logical palette roll is unreachable at " .. zone.id ..
						" roll " .. roll)
				end
				selected_counts[selected_index] = selected_counts[selected_index] + 1
				roll_case_count = roll_case_count + 1
			end
			for palette_index = 1, palette_count do
				local entry = zone.biomes[palette_index]
				local selected = selected_counts[palette_index]
				if selected <= 0 or selected ~= entry.share then
					fail("logical palette roll partition differs at " .. zone.id ..
						" entry " .. palette_index .. " (" .. entry.id ..
						"): authored " .. entry.share .. ", reachable " .. selected)
				end
				rows[#rows + 1] = table.concat({zone_index, zone.id,
					palette_index, entry.id, entry.share, selected}, "\t") .. "\n"
			end
		end
		local vocabulary_count = 0
		for _ in pairs(vocabulary) do vocabulary_count = vocabulary_count + 1 end
		if vocabulary_count ~= 16 then
			fail("authored logical-biome vocabulary differs: expected 16, observed " ..
				vocabulary_count)
		end
		return {
			zone_count = #source.zones,
			entry_count = entry_count,
			roll_case_count = roll_case_count,
			vocabulary_count = vocabulary_count,
			sha256 = digest_rows(raw_sha256, rows),
		}, vocabulary
	end

	local function literal_occurrence_count(bytes, needle)
		local count, offset = 0, 1
		while true do
			local found = bytes:find(needle, offset, true)
			if not found then return count end
			count = count + 1
			offset = found + #needle
		end
	end

	local function validate_legacy_share_audit_metadata(source, context,
			raw_sha256)
		local selector = source.logical_biome_selector
		if type(selector) ~= "table" then
			fail("logical-biome selector metadata is absent")
		end
		local fields = {
			{name = "share_audit_domain",
				value = "ordinary_land_columns_after_fixed_roads_and_structures"},
			{name = "share_audit_tolerance_percentage_points", value = 5},
		}
		if type(context.repo) ~= "string" or context.repo:sub(1, 1) ~= "/" then
			fail("legacy share-audit source inspection requires absolute repository root")
		end
		local production_path =
			"mods/MAPGEN/grug_mapgen/wp40/zones.lua"
		local production_bytes = common.read_file(context.repo .. "/" ..
			production_path)
		local evidence_fields, digest_rows_list = {}, {}
		local production_read_count = 0
		for index = 1, #fields do
			local expected = fields[index]
			if selector[expected.name] ~= expected.value then
				fail("retained legacy share-audit metadata differs at " ..
					expected.name .. ": expected " .. scalar(expected.value) ..
					", observed " .. scalar(selector[expected.name]))
			end
			local reads = literal_occurrence_count(production_bytes, expected.name)
			if reads ~= 0 then
				fail("production zones.lua reads superseded legacy metadata " ..
					expected.name .. " (text occurrences " .. reads .. ")")
			end
			production_read_count = production_read_count + reads
			evidence_fields[index] = {
				name = expected.name,
				value = expected.value,
				retained = true,
				operative = false,
				production_read_count = reads,
			}
			digest_rows_list[#digest_rows_list + 1] = table.concat({index,
				expected.name, scalar(expected.value), "retained",
				"non_operative", reads}, "\t") .. "\n"
		end
		local production_sha256 = common.digest_hex(raw_sha256, production_bytes)
		digest_rows_list[#digest_rows_list + 1] = table.concat({"production",
			production_path, production_sha256, production_read_count}, "\t") .. "\n"
		return {
			retained_field_count = #fields,
			operative_field_count = 0,
			production_read_count = production_read_count,
			production_path = production_path,
			production_sha256 = production_sha256,
			fields = evidence_fields,
			binding_sha256 = digest_rows(raw_sha256, digest_rows_list),
		}
	end

	local function square_member(x, z, center, width)
		local half = width / 2
		return x >= center.x - half and x < center.x + half and
			z >= center.z - half and z < center.z + half
	end

	local function build_hard_oracle(context, count_membership)
		local source = require_context(context, false)
		local horizontal, height = context.horizontal, context.height
		if type(horizontal) ~= "table" or
				type(horizontal.polyline_corridor_member) ~= "function" then
			fail("hard oracle requires accepted horizontal session")
		end
		local _, _, _, routes_by_id = source_maps(source)
		local recipes = {}
		for index = 1, #source.hard_protection_recipes do
			local row = source.hard_protection_recipes[index]
			recipes[row.id] = row
		end
		local height_rows
		if height then
			height_rows = height.hard_protection_volumes()
			if common.dense_count(height_rows, "height hard records") ~= 42 then
				fail("accepted height hard-record population differs")
			end
		end
		local records, by_id, cells = {}, {}, {}
		local function add_cell(cx, cz, id)
			local column = cells[cx]
			if not column then column = {} cells[cx] = column end
			local list = column[cz]
			if not list then list = {} column[cz] = list end
			list[#list + 1] = id
		end
		for index = 1, #source.hard_protection do
			local source_row = source.hard_protection[index]
			local height_row = height_rows and height_rows[index] or nil
			local recipe = recipes[source_row.recipe_id]
			if not recipe then fail("hard recipe identity differs") end
			if height_row and not exact_equal(source_row, (function()
				local copy = common.deep_copy(height_row)
				copy.y_min, copy.upward_unbounded, copy.y_policy_id, copy.surface_y =
					nil, nil, nil, nil
				return copy
			end)()) then
				fail("R3 hard identity/pass-through differs at " .. tostring(index))
			end
			local row = {id = source_row.id, recipe_id = recipe.id,
				shape = recipe.shape, y_min = recipe.y_min,
				record = common.deep_copy(height_row or source_row)}
			local bbox
			if recipe.shape == "centered_half_open_square" then
				row.center, row.total_width = source_row.center, recipe.total_width
				local half = recipe.total_width / 2
				bbox = {min_x = row.center.x - half, max_x = row.center.x + half,
					min_z = row.center.z - half, max_z = row.center.z + half}
			elseif recipe.shape == "polyline_corridor" then
				row.paths, row.total_width = {}, recipe.total_width
				local min_x, max_x, min_z, max_z
				for route_index = 1, #source_row.route_ids do
					local route = routes_by_id[source_row.route_ids[route_index]]
					if not route then fail("hard ingress route missing") end
					row.paths[#row.paths + 1] = route.centreline
					for point_index = 1, #route.centreline do
						local point = route.centreline[point_index]
						min_x = min_x and math.min(min_x, point.x) or point.x
						max_x = max_x and math.max(max_x, point.x) or point.x
						min_z = min_z and math.min(min_z, point.z) or point.z
						max_z = max_z and math.max(max_z, point.z) or point.z
					end
				end
				local expansion = math.floor((recipe.total_width + 1) / 2)
				bbox = {min_x = min_x - expansion, max_x = max_x + expansion + 1,
					min_z = min_z - expansion, max_z = max_z + expansion + 1}
			elseif recipe.shape == "exact_column" then
				row.center = source_row.center
				bbox = {min_x = row.center.x, max_x = row.center.x + 1,
					min_z = row.center.z, max_z = row.center.z + 1}
			else fail("unknown hard recipe shape") end
			row.bbox = bbox
			records[index], by_id[row.id] = row, row
			for cx = common.floor_div(bbox.min_x, 128),
					common.floor_div(bbox.max_x - 1, 128) do
				for cz = common.floor_div(bbox.min_z, 128),
						common.floor_div(bbox.max_z - 1, 128) do
					add_cell(cx, cz, row.id)
				end
			end
		end
		for _, column in pairs(cells) do
			for _, ids in pairs(column) do table.sort(ids) end
		end
		local function member(row, x, z)
			if row.shape == "centered_half_open_square" then
				return square_member(x, z, row.center, row.total_width)
			elseif row.shape == "polyline_corridor" then
				for path_index = 1, #row.paths do
					if horizontal.polyline_corridor_member(x, z, row.paths[path_index],
							row.total_width) then return true end
				end
				return false
			end
			return x == row.center.x and z == row.center.z
		end
		local function at(x, y, z)
			if y < -700 then return nil end
			local column = cells[common.floor_div(x, 128)]
			local ids = column and column[common.floor_div(z, 128)] or nil
			if not ids then return nil end
			for index = 1, #ids do
				local row = by_id[ids[index]]
				if y >= row.y_min and member(row, x, z) then return row end
			end
			return nil
		end
		if count_membership then
			for index = 1, #records do
				local row, count, immutable_overlap = records[index], 0, 0
				for z = row.bbox.min_z, row.bbox.max_z - 1 do
					for x = row.bbox.min_x, row.bbox.max_x - 1 do
						if member(row, x, z) then
							count = count + 1
							local water_class = horizontal.classification_values_at(x, z)
							if water_class == "deep_ocean" or
									water_class == "immutable_dragon_channel" then
								immutable_overlap = immutable_overlap + 1
							end
						end
					end
				end
				row.membership_columns = count
				row.immutable_water_overlap_columns = immutable_overlap
				if immutable_overlap ~= 0 then
					fail("hard footprint overlaps independently classified immutable water")
				end
			end
		end
		return {records = records, by_id = by_id, cells = cells,
			member = member, at = at}
	end

	local function route_catalog(source)
		local _, _, anchors = source_maps(source)
		local trail = {bandit_home = true, bandit_frontier = true,
			mirefolk = true, clash = true}
		local features, segments = {}, {}
		local function add(row, kind, class)
			local profile = source.route_profiles[class]
			local feature = {id = row.id, path_kind = kind, route_class = class,
				surface_width = profile.surface_width,
				corridor_width = profile.corridor_width,
				order = #features + 1, centreline = row.centreline}
			features[#features + 1] = feature
			for segment = 1, #row.centreline - 1 do
				local a, b = row.centreline[segment], row.centreline[segment + 1]
				if a.x == b.x and a.z == b.z then fail("degenerate route segment") end
				segments[#segments + 1] = {feature = feature, segment = segment,
					ax = a.x, az = a.z, bx = b.x, bz = b.z}
			end
		end
		for index = 1, #source.routes do
			add(source.routes[index], "land_route", source.routes[index].class)
		end
		for index = 1, #source.poi_spurs do
			local row = source.poi_spurs[index]
			local anchor = anchors[row.anchor_id]
			add(row, "poi_spur", trail[anchor.template_id] and "trail" or "secondary")
		end
		for index = 1, #source.island_routes do
			add(source.island_routes[index], "island_route", "secondary")
		end
		if #features ~= 139 or #segments ~= 476 then
			fail("route oracle population differs")
		end
		return features, segments
	end

	local function hydrology_catalog(source)
		local features, segments = {}, {}
		for index = 1, #source.hydrology do
			local row = source.hydrology[index]
			local feature = {id = row.id, order = index, centreline = row.centreline}
			features[index] = feature
			for segment = 1, #row.centreline - 1 do
				local a, b = row.centreline[segment], row.centreline[segment + 1]
				if a.x == b.x and a.z == b.z then fail("degenerate hydrology segment") end
				segments[#segments + 1] = {feature = feature, segment = segment,
					ax = a.x, az = a.z, bx = b.x, bz = b.z}
			end
		end
		if #features ~= 25 or #segments ~= 102 then
			fail("hydrology oracle population differs")
		end
		return features, segments
	end

	local function squared(value, label)
		common.safe_integer(value, label)
		local result = value * value
		return common.safe_integer(result, label .. " squared")
	end

	local function segment_distance(x, z, segment)
		local vx, vz = segment.bx - segment.ax, segment.bz - segment.az
		local wx, wz = x - segment.ax, z - segment.az
		local length = squared(vx, "segment vx") + squared(vz, "segment vz")
		common.safe_integer(length, "segment length")
		local dot = wx * vx + wz * vz
		common.safe_integer(dot, "segment dot")
		if dot <= 0 then
			return squared(wx, "start dx") + squared(wz, "start dz"), 1
		elseif dot >= length then
			return squared(x - segment.bx, "end dx") +
				squared(z - segment.bz, "end dz"), 1
		end
		local cross = wx * vz - wz * vx
		common.safe_integer(cross, "segment cross")
		return squared(cross, "segment cross"), length
	end

	local function nearest_oracle(segments, x, z, hydrology)
		if x < common.MIN_X or x > common.MAX_X or
				z < common.MIN_Z or z > common.MAX_Z then return nil end
		local best, best_numerator, best_denominator
		for index = 1, #segments do
			local segment = segments[index]
			local numerator, denominator = segment_distance(x, z, segment)
			local comparison = best and common.rational_compare(numerator,
				denominator, best_numerator, best_denominator) or -1
			local tie = false
			if comparison == 0 then
				if hydrology then
					tie = segment.feature.order < best.feature.order or
						segment.feature.order == best.feature.order and
						segment.segment < best.segment
				else
					tie = segment.feature.id < best.feature.id or
						segment.feature.id == best.feature.id and
						segment.segment < best.segment
				end
			end
			if not best or comparison < 0 or tie then
				best, best_numerator, best_denominator = segment, numerator, denominator
			end
		end
		return best and {segment_record = best, numerator = best_numerator,
			denominator = best_denominator} or nil
	end

	local function assert_metrics_zero(metrics, label)
		if type(metrics) ~= "table" then fail(label .. " metrics missing") end
		for map_key, value in pairs(metrics) do
			nonempty_text(map_key, label .. " metric key")
			common.safe_integer(value, label .. " metric " .. map_key)
		end
		for _, map_key in ipairs({"query_sha256_calls",
			"query_lattice_constructions", "query_feature_list_constructions",
			"query_unindexed_catalog_scans"}) do
			if metrics[map_key] ~= 0 then fail(label .. " nonzero " .. map_key) end
		end
		if metrics.logical_lattice_constructions ~= 1 or
				metrics.logical_site_count ~= 1596 then
			fail(label .. " logical-lattice metrics differ")
		end
	end

	function validator.validate_api(session, raw_sha256)
		if type(raw_sha256) ~= "function" then fail("raw SHA-256 helper missing") end
		local expected_methods = {"get", "at", "neighbors", "travel_links",
			"anchor", "id_at", "biome_at", "race_region_at", "faction_at",
			"territory_rule_at", "pvp_rule_at", "surface_mob_level_at",
			"mob_level_at", "guard_level_at", "terrain_height_at",
			"water_class_at", "nearest_route_at", "nearest_hydrology_at",
			"housing_eligible_at", "canonical_kat", "canonical_kat_digest",
			"artifact_evidence", "metrics"}
		local allowed = {compatibility = true}
		for _, name in ipairs(expected_methods) do method(session, name) allowed[name] = true end
		for map_key in pairs(session) do
			if not allowed[map_key] then fail("unexpected public session field " .. tostring(map_key)) end
		end
		local compatibility = session.compatibility
		if type(compatibility) ~= "table" then fail("compatibility payload missing") end
		local compatibility_names = {"surface_level_at", "mob_level_at",
			"guard_level_at", "open_sea_at", "difficulty_at", "territory_at",
			"zone_at", "world_protected_for_faction"}
		local compatibility_allowed = {}
		for _, name in ipairs(compatibility_names) do
			if type(compatibility[name]) ~= "function" then
				fail("compatibility." .. name .. " missing")
			end
			compatibility_allowed[name] = true
		end
		for map_key in pairs(compatibility) do
			if not compatibility_allowed[map_key] then
				fail("unexpected compatibility field " .. tostring(map_key))
			end
		end

		local kat = session.canonical_kat()
		if type(kat) ~= "string" or common.digest_hex(raw_sha256, kat) ~=
				common.digest(session.canonical_kat_digest(), "R4 canonical KAT") then
			fail("canonical KAT bytes/digest differ")
		end
		local metrics = session.metrics()
		assert_metrics_zero(metrics, "initial")
		metrics.query_sha256_calls = -1
		assert_metrics_zero(session.metrics(), "defensive metrics")

		if session.get("__unknown_zone__") ~= nil or
				#session.neighbors("__unknown_zone__") ~= 0 or
				#session.travel_links("__unknown_zone__") ~= 0 or
				session.anchor("__unknown_zone__", "start") ~= nil or
				session.anchor("elandor_hearthpine_vale", "__absent__") ~= nil then
			fail("unknown/absent registry result differs")
		end
		for _, callback in ipairs({
			function() session.get(1) end,
			function() session.neighbors(false) end,
			function() session.travel_links({}) end,
			function() session.anchor("elandor_hearthpine_vale", 1) end,
			function() session.at({x = 0, z = 0}) end,
			function() session.id_at(0 / 0, 0) end,
			function() session.biome_at(math.huge, 0) end,
			function() session.territory_rule_at("bad") end,
			function() session.water_class_at(common.MAX_SAFE + 2, 0) end,
		}) do expect_error(callback, "malformed public input") end

		for _, point in ipairs({
			{common.MAX_SAFE, common.MAX_SAFE},
			{-common.MAX_SAFE, -common.MAX_SAFE},
		}) do
			local x, z = point[1], point[2]
			if session.id_at(x, z) ~= nil or session.biome_at(x, z) ~= nil or
					session.water_class_at(x, z) ~= "deep_ocean" or
					session.terrain_height_at(x, z) ~= -23 or
					session.territory_rule_at({x = x, y = 0, z = z}) ~= "immutable" or
					session.pvp_rule_at({x = x, y = 0, z = z}) ~= nil or
					session.nearest_route_at(x, z) ~= nil or
					session.nearest_hydrology_at(x, z) ~= nil or
					session.housing_eligible_at(x, z) ~= false then
				fail("safe exterior short-circuit differs")
			end
		end
		if session.id_at(-0.5, -0.5) ~= session.id_at(-1, -1) or
				session.id_at(0.5, 0.5) ~= session.id_at(1, 1) or
				session.id_at(-0.49, 0.49) ~= session.id_at(0, 0) then
			fail("coordinate normalization differs")
		end
		return {schema = API_SCHEMA, method_count = #expected_methods,
			compatibility_method_count = #compatibility_names,
			canonical_kat_sha256 = session.canonical_kat_digest(),
			malformed_cases = 9, safe_exterior_cases = 2,
			normalization_cases = 3, violation_count = 0}
	end

	function validator.validate_construction(session, context, raw_sha256)
		local source = require_context(context, true)
		local palette_proof = validate_palette_partitions(source, raw_sha256)
		local legacy_share_audit = validate_legacy_share_audit_metadata(source,
			context, raw_sha256)
		local evidence = session.artifact_evidence()
		if type(evidence) ~= "table" or evidence.schema ~= common.ZONES_SCHEMA or
				evidence.sparse_schema ~= common.SPARSE_INDEX_SCHEMA or
				evidence.layout_id ~= common.LAYOUT_ID or
				evidence.layout_revision_id ~= common.LAYOUT_REVISION_ID or
				evidence.water_level ~= 1 then
			fail("construction evidence identity differs")
		end
		local original = evidence_bytes(evidence)
		evidence.__mutation = true
		if evidence.zone_records and evidence.zone_records[1] then
			evidence.zone_records[1].__mutation = true
		end
		local fresh = session.artifact_evidence()
		if evidence_bytes(fresh) ~= original then
			fail("artifact_evidence is not a defensive copy")
		end
		if fresh.bounds.min_x ~= common.MIN_X or fresh.bounds.max_x ~= common.MAX_X or
				fresh.bounds.min_z ~= common.MIN_Z or fresh.bounds.max_z ~= common.MAX_Z then
			fail("construction evidence bounds differ")
		end
		local zones_by_id, zones_by_numeric = source_maps(source)
		if common.dense_count(fresh.zone_records, "evidence zones") ~= 38 then
			fail("evidence zone count differs")
		end
		local zone_digest_rows = {}
		for index = 1, #source.zones do
			local expected = expected_zone(source, index)
			local public = session.get(expected.id)
			if not exact_equal(public, expected) or
					not exact_equal(fresh.zone_records[index], expected) then
				fail("public/evidence zone differs at " .. expected.id)
			end
			local at = session.at({x = expected.hub.x, y = 0, z = expected.hub.z})
			if not at or at.id ~= session.id_at(expected.hub.x, expected.hub.z) then
				fail("zone at/id parity differs at " .. expected.id)
			end
			zone_digest_rows[#zone_digest_rows + 1] = evidence_bytes(expected)
		end

		local neighbor_expected, edge_rows = {}, {}
		for index = 1, #source.zones do neighbor_expected[index] = {} end
		for index = 1, #source.routes do
			local row = source.routes[index]
			neighbor_expected[row.zone_a][#neighbor_expected[row.zone_a] + 1] =
				zones_by_numeric[row.zone_b].id
			neighbor_expected[row.zone_b][#neighbor_expected[row.zone_b] + 1] =
				zones_by_numeric[row.zone_a].id
			local first, second = row.zone_a, row.zone_b
			if second < first then first, second = second, first end
			local a, b = zones_by_numeric[first].id, zones_by_numeric[second].id
			edge_rows[#edge_rows + 1] = {a = a, b = b, route_id = row.id}
		end
		for index = 1, #neighbor_expected do
			table.sort(neighbor_expected[index])
			if not exact_equal(session.neighbors(source.zones[index].id),
					neighbor_expected[index]) then
				fail("neighbor graph differs at " .. source.zones[index].id)
			end
		end
		table.sort(edge_rows, function(a, b)
			if a.a ~= b.a then return a.a < b.a end
			if a.b ~= b.b then return a.b < b.b end
			return a.route_id < b.route_id
		end)
		if not exact_equal(edge_rows, fresh.neighbor_edges) then
			fail("neighbor edge evidence differs")
		end

		local boat_rows = {}
		for index = 1, #source.boat_paths do
			local boat = source.boat_paths[index]
			local expected = {id = boat.id, kind = "boat",
				from_zone_id = zones_by_numeric[boat.from_zone].id,
				to_zone_id = zones_by_numeric[boat.to_zone].id,
				landing_id = boat.landing_id, width = boat.width,
				centreline = common.deep_copy(boat.centreline)}
			boat_rows[index] = expected
			for _, endpoint in ipairs({boat.from_zone, boat.to_zone}) do
				local links = session.travel_links(zones_by_numeric[endpoint].id)
				local found
				for link_index = 1, #links do
					if links[link_index].id == boat.id then found = links[link_index] break end
				end
				if not found then fail("boat link missing at endpoint") end
				local wanted = common.deep_copy(expected)
				wanted.destination_zone_id = zones_by_numeric[
					endpoint == boat.from_zone and boat.to_zone or boat.from_zone].id
				if not exact_equal(found, wanted) then fail("caller-relative boat differs") end
			end
		end
		if not exact_equal(boat_rows, fresh.boat_paths) then
			fail("boat evidence differs")
		end

		if common.dense_count(fresh.anchors, "evidence anchors") ~= 100 then
			fail("anchor evidence count differs")
		end
		for index = 1, #source.anchors do
			local source_anchor = source.anchors[index]
			local expected = context.height.selected_anchor_3d_by_id(source_anchor.id)
			if not exact_equal(fresh.anchors[index], expected) or
					not exact_equal(session.anchor(zones_by_numeric[
						source_anchor.zone_numeric_id].id, source_anchor.slot_id), expected) then
				fail("anchor passthrough differs at " .. source_anchor.id)
			end
		end

		local hard = build_hard_oracle(context, true)
		local hard_membership_digest_rows = {}
		if common.dense_count(fresh.hard_protection, "evidence hard") ~= 42 then
			fail("hard evidence count differs")
		end
		for index = 1, #hard.records do
			local actual, expected = fresh.hard_protection[index], hard.records[index]
			local record = common.deep_copy(expected.record)
			record.bbox = common.deep_copy(expected.bbox)
			record.membership_columns = expected.membership_columns
			if not exact_equal(actual, record) then
				fail("hard construction evidence differs at " .. expected.id)
			end
			hard_membership_digest_rows[#hard_membership_digest_rows + 1] =
				table.concat({expected.id, expected.membership_columns,
					expected.immutable_water_overlap_columns,
					expected.bbox.min_x, expected.bbox.max_x,
					expected.bbox.min_z, expected.bbox.max_z}, "\t") .. "\n"
		end
		if fresh.logical_biome.cell_size ~= 192 or
				fresh.logical_biome.min_cell_x ~= -21 or
				fresh.logical_biome.max_cell_x ~= 20 or
				fresh.logical_biome.min_cell_z ~= -19 or
				fresh.logical_biome.max_cell_z ~= 18 or
				fresh.logical_biome.site_count ~= 1596 then
			fail("logical-biome lattice evidence differs")
		end
		common.digest(fresh.logical_biome.digest, "logical-biome lattice")
		if fresh.path_population.features ~= 139 or
				fresh.path_population.segments ~= 476 or
				fresh.hydrology_population.features ~= 25 or
				fresh.hydrology_population.segments ~= 102 then
			fail("sparse population evidence differs")
		end
		for _, family in ipairs({"route_index", "hydrology_index", "hard_index"}) do
			local row = fresh[family]
			if type(row) ~= "table" or row.schema ~= common.SPARSE_INDEX_SCHEMA or
					row.cell_size ~= 128 or row.min_x ~= common.MIN_X or
					row.max_x ~= common.MAX_X or row.min_z ~= common.MIN_Z or
					row.max_z ~= common.MAX_Z then fail(family .. " evidence differs") end
		end
		if fresh.horizontal_canonical_kat_digest ~=
				context.horizontal.canonical_kat_digest() or
				fresh.height_canonical_kat_digest ~= context.height.canonical_kat_digest() or
				fresh.height_relief_lattice_digest ~= context.height.relief_lattice_digest() then
			fail("R2/R3 digest passthrough differs")
		end
		if context.peer_session then
			if session.canonical_kat_digest() ~= context.peer_session.canonical_kat_digest() or
					evidence_bytes(fresh) ~= evidence_bytes(
						context.peer_session.artifact_evidence()) then
				fail("engine-free/engine-shaped session parity differs")
			end
		end
		return {schema = CONSTRUCTION_SCHEMA, zone_count = 38,
			neighbor_edge_count = 57, boat_count = 4, anchor_count = 100,
			hard_count = 42, route_feature_count = 139,
			route_segment_count = 476, hydrology_feature_count = 25,
			hydrology_segment_count = 102, logical_site_count = 1596,
			zone_records_sha256 = digest_rows(raw_sha256, zone_digest_rows),
			hard_membership_sha256 = digest_rows(raw_sha256,
				hard_membership_digest_rows),
			hard_immutable_water_overlap_columns = 0,
			logical_site_sha256 = fresh.logical_biome.digest,
			logical_palette_entry_count = palette_proof.entry_count,
			logical_palette_roll_case_count = palette_proof.roll_case_count,
			logical_palette_vocabulary_count = palette_proof.vocabulary_count,
			logical_palette_partition_sha256 = palette_proof.sha256,
			logical_legacy_share_audit_retained_field_count =
				legacy_share_audit.retained_field_count,
			logical_legacy_share_audit_operative_field_count =
				legacy_share_audit.operative_field_count,
			logical_legacy_share_audit_production_read_count =
				legacy_share_audit.production_read_count,
			logical_legacy_share_audit_binding_sha256 =
				legacy_share_audit.binding_sha256,
			logical_legacy_share_audit = legacy_share_audit,
			peer_session_checked = context.peer_session ~= nil,
			violation_count = 0}
	end

	local EXTENT_COUNT_FIELDS = {
		"water", "id", "race", "faction",
		"surface", "biome", "territory_700",
		"pvp_700", "territory_701", "pvp_701",
	}

	local function new_extent_counts()
		local result = {zone_land_counts = {}, zone_land_biome_counts = {}}
		for index = 1, #EXTENT_COUNT_FIELDS do
			result[EXTENT_COUNT_FIELDS[index]] = {}
		end
		return result
	end

	function validator.run_extent_shard(session, context, raw_sha256,
			min_z, max_z, progress)
		local source = require_context(context, false)
		if type(context.horizontal) ~= "table" or
				type(context.horizontal.classification_values_at) ~= "function" then
			fail("extent validation requires accepted horizontal session")
		end
		min_z = common.safe_integer(min_z, "extent min z")
		max_z = common.safe_integer(max_z, "extent max z")
		if min_z < common.MIN_Z or max_z > common.MAX_Z or min_z > max_z then
			fail("extent shard range differs")
		end
		if progress ~= nil and type(progress) ~= "function" then
			fail("extent progress callback differs")
		end
		local counts = new_extent_counts()
		local hard = build_hard_oracle(context, false)
		local palette_by_zone = {}
		for zone_index = 1, #source.zones do
			local palette = {}
			for biome_index = 1, #source.zones[zone_index].biomes do
				palette[source.zones[zone_index].biomes[biome_index].id] = true
			end
			palette_by_zone[zone_index] = palette
		end
		local row_digests, column_count = {}, 0
		local horizontal = context.horizontal
		for z = min_z, max_z do
			local scalar_row, policy_row, biome_row = {}, {}, {}
			for x = common.MIN_X, common.MAX_X do
				local water_class, macro_region, owner =
					horizontal.classification_values_at(x, z)
				if not WATER_CLASSES[water_class] then
					fail("unknown horizontal water class")
				end
				if (OWNER_CLASSES[water_class] == true) ~= (owner ~= nil) then
					fail("horizontal class/owner combination differs")
				end
				local zone = owner and source.zones[owner] or nil
				if owner and (not zone or zone.numeric_id ~= owner) then
					fail("horizontal owner identity differs")
				end
				local expected_id = zone and zone.id or nil
				local expected_race = zone and zone.race_region or nil
				local expected_faction = zone and
					(zone.faction ~= false and zone.faction or nil) or nil
				local expected_surface
				if water_class == "land" or water_class == "planned_water" then
					expected_surface = horizontal.difficulty_for_macro_at(
						x, z, macro_region)
					if expected_surface == nil then fail("horizontal surface level absent") end
				end
				local id = session.id_at(x, z)
				local race = session.race_region_at(x, z)
				local faction = session.faction_at({x = x, y = 0, z = z})
				local actual_water = session.water_class_at(x, z)
				local surface = session.surface_mob_level_at(x, z)
				local biome = session.biome_at(x, z)
				if actual_water ~= water_class or id ~= expected_id or
						race ~= expected_race or faction ~= expected_faction or
						surface ~= expected_surface or (owner ~= nil) ~= (biome ~= nil) then
					fail("extent scalar parity differs at " .. x .. "," .. z)
				end
				if biome and type(biome) ~= "string" then
					fail("logical biome result is not text")
				end
				if owner and not palette_by_zone[owner][biome] then
					fail("logical biome is outside exact owner palette at " ..
						x .. "," .. z)
				end

				local hard_row = hard.at(x, -700, z)
				local territory_700 = hard_row and "hard_protected" or
					(not owner and "immutable" or zone.territory_rule)
				local pvp_700 = zone and zone.pvp_rule or nil
				local territory_701 = owner and "contested_land" or "immutable"
				local pvp_701 = owner and "contested" or nil
				local actual_territory_700 = session.territory_rule_at(
					{x = x, y = -700, z = z})
				local actual_pvp_700 = session.pvp_rule_at(
					{x = x, y = -700, z = z})
				local actual_territory_701 = session.territory_rule_at(
					{x = x, y = -701, z = z})
				local actual_pvp_701 = session.pvp_rule_at(
					{x = x, y = -701, z = z})
				if actual_territory_700 ~= territory_700 or
						actual_pvp_700 ~= pvp_700 or
						actual_territory_701 ~= territory_701 or
						actual_pvp_701 ~= pvp_701 then
					fail("extent policy parity differs at " .. x .. "," .. z)
				end

				increment(counts.water, water_class)
				increment(counts.id, id)
				increment(counts.race, race)
				increment(counts.faction, faction)
				increment(counts.surface, surface)
				increment(counts.biome, biome)
				increment(counts.territory_700, actual_territory_700)
				increment(counts.pvp_700, actual_pvp_700)
				increment(counts.territory_701, actual_territory_701)
				increment(counts.pvp_701, actual_pvp_701)
				if water_class == "land" then
					increment(counts.zone_land_counts, id)
					add_nested(counts.zone_land_biome_counts, id, biome)
				end
				scalar_row[#scalar_row + 1] = table.concat({water_class,
					scalar(id), scalar(race), scalar(faction), scalar(surface)}, ":")
				policy_row[#policy_row + 1] = table.concat({actual_territory_700,
					scalar(actual_pvp_700), actual_territory_701,
					scalar(actual_pvp_701)}, ":")
				biome_row[#biome_row + 1] = scalar(biome)
				column_count = column_count + 1
			end
			row_digests[#row_digests + 1] = {
				z = z,
				scalar_sha256 = common.digest_hex(raw_sha256,
					table.concat(scalar_row, "\t") .. "\n"),
				policy_sha256 = common.digest_hex(raw_sha256,
					table.concat(policy_row, "\t") .. "\n"),
				biome_sha256 = common.digest_hex(raw_sha256,
					table.concat(biome_row, "\t") .. "\n"),
			}
			if progress and ((z - min_z + 1) % 128 == 0 or z == max_z) then
				progress("extent", z - min_z + 1, max_z - min_z + 1)
			end
		end
		counts.schema = EXTENT_SHARD_SCHEMA
		counts.min_z, counts.max_z = min_z, max_z
		counts.columns, counts.row_digests = column_count, row_digests
		counts.violation_count = 0
		return counts
	end

	local function merge_count_map(target, source_map)
		if type(source_map) ~= "table" then fail("shard count map missing") end
		for map_key, value in pairs(source_map) do increment(target, map_key, value) end
	end

	local function merge_nested_map(target, source_map)
		if type(source_map) ~= "table" then fail("shard nested map missing") end
		for first, row in pairs(source_map) do
			for second, value in pairs(row) do add_nested(target, first, second, value) end
		end
	end

	function validator.merge_extent_shards(shards, raw_sha256, source)
		common.dense_count(shards, "extent shards")
		if #shards == 0 then fail("extent shard population is empty") end
		if type(source) ~= "table" or source.schema ~= common.SOURCE_SCHEMA then
			fail("extent merge source differs")
		end
		local palette_proof, authored_vocabulary =
			validate_palette_partitions(source, raw_sha256)
		local ordered = common.deep_copy(shards)
		table.sort(ordered, function(a, b) return a.min_z < b.min_z end)
		local result = new_extent_counts()
		local expected_z, column_count = common.MIN_Z, 0
		local scalar_rows, policy_rows, biome_rows = {}, {}, {}
		for shard_index = 1, #ordered do
			local shard = ordered[shard_index]
			if shard.schema ~= EXTENT_SHARD_SCHEMA or shard.min_z ~= expected_z or
					type(shard.max_z) ~= "number" or shard.max_z < shard.min_z then
				fail("extent shards do not form exact ordered cover")
			end
			local rows = common.dense_count(shard.row_digests, "shard row digests")
			if rows ~= shard.max_z - shard.min_z + 1 or
					shard.columns ~= rows * (common.MAX_X - common.MIN_X + 1) then
				fail("extent shard dimensions differ")
			end
			for field_index = 1, #EXTENT_COUNT_FIELDS do
				local field = EXTENT_COUNT_FIELDS[field_index]
				merge_count_map(result[field], shard[field])
			end
			merge_count_map(result.zone_land_counts, shard.zone_land_counts)
			merge_nested_map(result.zone_land_biome_counts,
				shard.zone_land_biome_counts)
			for row_index = 1, #shard.row_digests do
				local row = shard.row_digests[row_index]
				if row.z ~= shard.min_z + row_index - 1 then
					fail("extent row order differs")
				end
				common.digest(row.scalar_sha256, "scalar row")
				common.digest(row.policy_sha256, "policy row")
				common.digest(row.biome_sha256, "biome row")
				scalar_rows[#scalar_rows + 1] = row.z .. "\t" .. row.scalar_sha256 .. "\n"
				policy_rows[#policy_rows + 1] = row.z .. "\t" .. row.policy_sha256 .. "\n"
				biome_rows[#biome_rows + 1] = row.z .. "\t" .. row.biome_sha256 .. "\n"
			end
			column_count = column_count + shard.columns
			expected_z = shard.max_z + 1
		end
		if expected_z ~= common.MAX_Z + 1 or column_count ~= common.COLUMN_COUNT then
			fail("extent merge coverage differs")
		end
		for class, expected in pairs(EXPECTED_WATER_COUNTS) do
			if result.water[class] ~= expected then
				fail("water population differs for " .. class)
			end
		end
		if count_total(result.water) ~= column_count then
			fail("water population total differs")
		end
		for index = 1, #EXTENT_COUNT_FIELDS do
			if count_total(result[EXTENT_COUNT_FIELDS[index]]) ~= column_count then
				fail(EXTENT_COUNT_FIELDS[index] .. " population total differs")
			end
		end
		if count_total(result.zone_land_counts) ~= EXPECTED_WATER_COUNTS.land then
			fail("ordinary-land zone population total differs")
		end
		local observed_vocabulary = {}
		local realized_shares = {}
		for zone_index = 1, #source.zones do
			local zone = source.zones[zone_index]
			local observed = result.zone_land_biome_counts[zone.id]
			local zone_total = result.zone_land_counts[zone.id]
			if not observed or not zone_total or zone_total <= 0 or
					count_total(observed) ~= zone_total then
				fail("zone logical-biome population absent at " .. zone.id)
			end
			local authored = {}
			for palette_index = 1, #zone.biomes do
				local palette = zone.biomes[palette_index]
				authored[palette.id] = palette.share
			end
			for biome, observed_count in pairs(observed) do
				if not authored[biome] then
					fail("foreign logical biome " .. biome .. " in " .. zone.id ..
						" (observed count " .. observed_count .. ")")
				end
				if observed_count > 0 then observed_vocabulary[biome] = true end
			end
			realized_shares[zone.id] = {}
			for palette_index = 1, #zone.biomes do
				local biome = zone.biomes[palette_index].id
				local observed_count = observed[biome] or 0
				-- Retain explicit zeroes and exact rational shares as characterization;
				-- realized area is not an authored-weight conformance gate.
				observed[biome] = observed_count
				realized_shares[zone.id][biome] = {
					numerator = observed_count, denominator = zone_total,
				}
			end
		end
		local observed_vocabulary_count = 0
		for biome in pairs(observed_vocabulary) do
			observed_vocabulary_count = observed_vocabulary_count + 1
			if not authored_vocabulary[biome] then
				fail("globally observed foreign logical biome " .. biome)
			end
		end
		if observed_vocabulary_count ~= palette_proof.vocabulary_count then
			local missing = {}
			for biome in pairs(authored_vocabulary) do
				if not observed_vocabulary[biome] then missing[#missing + 1] = biome end
			end
			table.sort(missing)
			fail("global logical-biome observation differs: expected " ..
				palette_proof.vocabulary_count .. ", observed " ..
				observed_vocabulary_count .. ", missing " ..
				(#missing > 0 and table.concat(missing, ",") or NIL))
		end
		if result.territory_701.contested_land ~=
				EXPECTED_WATER_COUNTS.land + EXPECTED_WATER_COUNTS.planned_water +
				EXPECTED_WATER_COUNTS.coastal_shelf or
				result.territory_701.immutable ~=
				EXPECTED_WATER_COUNTS.deep_ocean +
				EXPECTED_WATER_COUNTS.immutable_dragon_channel or
				result.pvp_701.contested ~=
				EXPECTED_WATER_COUNTS.land + EXPECTED_WATER_COUNTS.planned_water +
				EXPECTED_WATER_COUNTS.coastal_shelf or
				result.pvp_701[NIL] ~=
				EXPECTED_WATER_COUNTS.deep_ocean +
				EXPECTED_WATER_COUNTS.immutable_dragon_channel then
			fail("y=-701 exact policy population differs")
		end
		result.schema = POPULATION_SCHEMA
		result.column_count = column_count
		result.scalar_population_sha256 = digest_rows(raw_sha256, scalar_rows)
		result.policy_population_sha256 = digest_rows(raw_sha256, policy_rows)
		result.biome_population_sha256 = digest_rows(raw_sha256, biome_rows)
		result.logical_biome_id_count = observed_vocabulary_count
		result.authored_logical_biome_id_count = palette_proof.vocabulary_count
		result.logical_palette_partition_sha256 = palette_proof.sha256
		result.zone_land_biome_shares = realized_shares
		result.row_count = common.MAX_Z - common.MIN_Z + 1
		result.violation_count = 0
		return result
	end

	local function point_set()
		local points, seen = {}, {}
		local function add(x, z, label)
			common.finite_number(x, "sample x")
			common.finite_number(z, "sample z")
			local identity = common.canonical_number(x) .. "," ..
				common.canonical_number(z)
			if not seen[identity] then
				seen[identity] = true
				points[#points + 1] = {x = x, z = z, label = label or "sample"}
			end
		end
		return points, add
	end

	local function sorted_points(points)
		table.sort(points, function(a, b)
			if a.x ~= b.x then return a.x < b.x end
			if a.z ~= b.z then return a.z < b.z end
			return a.label < b.label
		end)
		return points
	end

	local function housing_corpus(context)
		local source = require_context(context, true)
		if type(context.repo) ~= "string" or context.repo:sub(1, 1) ~= "/" then
			fail("housing corpus requires absolute repository root")
		end
		local points, add = point_set()
		local artifact = common.read_file(context.repo ..
			"/docs/research/wp40-simple-map-r2-artifact.tsv")
		local order_count = 0
		for line in artifact:gmatch("([^\n]+)\n") do
			local _, _, _, _, _, _, first_x, first_z, last_x, last_z =
				line:match("^(housing_order)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t" ..
					"([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
			if first_x then
				order_count = order_count + 1
				add(assert(tonumber(first_x)), assert(tonumber(first_z)), "housing_order")
				add(assert(tonumber(last_x)), assert(tonumber(last_z)), "housing_order")
			end
		end
		if order_count ~= 230 then fail("accepted housing-order population differs") end
		local offsets = {-51, -50, -1, 0, 1, 50, 51}
		for mask_index = 1, #source.housing_masks do
			local mask = source.housing_masks[mask_index]
			local min_x, max_x, min_z, max_z
			for index = 1, #mask.polygon do
				local point = mask.polygon[index]
				add(point.x, point.z, "mask_vertex")
				min_x = min_x and math.min(min_x, point.x) or point.x
				max_x = max_x and math.max(max_x, point.x) or point.x
				min_z = min_z and math.min(min_z, point.z) or point.z
				max_z = max_z and math.max(max_z, point.z) or point.z
			end
			add(math.floor((min_x + max_x) / 2),
				math.floor((min_z + max_z) / 2), "mask_bbox_center")
			local previous = mask.polygon[#mask.polygon]
			for edge_index = 1, #mask.polygon do
				local current = mask.polygon[edge_index]
				local raster = common.raster_polyline({previous, current})
				for raster_index = 32, #raster, 32 do
					local point = raster[raster_index]
					for dx_index = 1, #offsets do
						for dz_index = 1, #offsets do
							add(point.x + offsets[dx_index],
								point.z + offsets[dz_index], "mask_edge_offset")
						end
					end
				end
				previous = current
			end
			for ix = 0, 20 do
				local x = min_x + math.floor(ix * (max_x - min_x) / 20)
				for iz = 0, 20 do
					local z = min_z + math.floor(iz * (max_z - min_z) / 20)
					add(x, z, "mask_lattice")
				end
			end
		end
		for _, point in ipairs({
			{-0.5, -0.5}, {-0.49, 0.49}, {0.49, -0.49}, {0.5, 0.5},
			{common.MIN_X - 0.5, common.MIN_Z - 0.5},
			{common.MAX_X + 0.49, common.MAX_Z + 0.49},
			{common.MAX_SAFE, common.MAX_SAFE},
			{-common.MAX_SAFE, -common.MAX_SAFE},
		}) do add(point[1], point[2], "normalization") end
		return sorted_points(points), order_count
	end

	local function nearest_samples(source, policy_points)
		local points, add = point_set()
		local routes_by_id = {}
		for index = 1, #source.routes do
			routes_by_id[source.routes[index].id] = source.routes[index]
		end
		for cell_x = common.floor_div(common.MIN_X, 128),
				common.floor_div(common.MAX_X, 128) do
			local min_x, max_x = cell_x * 128, cell_x * 128 + 127
			local mid_x = min_x + 63
			for cell_z = common.floor_div(common.MIN_Z, 128),
					common.floor_div(common.MAX_Z, 128) do
				local min_z, max_z = cell_z * 128, cell_z * 128 + 127
				local mid_z = min_z + 63
				for _, point in ipairs({{min_x,min_z},{max_x,min_z},
						{min_x,max_z},{max_x,max_z},{mid_x,mid_z},
						{mid_x,min_z},{mid_x,max_z},{min_x,mid_z},{max_x,mid_z}}) do
					if point[1] >= common.MIN_X and point[1] <= common.MAX_X and
							point[2] >= common.MIN_Z and point[2] <= common.MAX_Z then
						add(point[1], point[2], "grid")
					end
				end
			end
		end
		for _, family in ipairs({source.routes, source.poi_spurs,
				source.island_routes, source.hydrology}) do
			for feature_index = 1, #family do
				for point_index = 1, #family[feature_index].centreline do
					local point = family[feature_index].centreline[point_index]
					add(point.x, point.z, "vertex")
				end
			end
		end
		for index = 0, 4095 do
			local x = common.MIN_X + (index * 1103515245 + 12345) %
				(common.MAX_X - common.MIN_X + 1)
			local z = common.MIN_Z + (index * 1664525 + 1013904223) %
				(common.MAX_Z - common.MIN_Z + 1)
			add(x, z, "interior")
		end
		-- Policy KAT points are a named part of the nearest-oracle corpus, not
		-- an accidental subset of the grid samples.
		for zone_index = 1, #source.zones do
			local hub = source.zones[zone_index].hub
			add(hub.x, hub.z, "policy_zone_hub")
		end
		for hard_index = 1, #source.hard_protection do
			local row = source.hard_protection[hard_index]
			if row.center then add(row.center.x, row.center.z, "policy_hard_center") end
			if row.route_ids then
				for route_index = 1, #row.route_ids do
					local route = routes_by_id[row.route_ids[route_index]]
					if not route then fail("policy hard route missing") end
					add(route.centreline[1].x, route.centreline[1].z,
						"policy_ingress_endpoint")
					add(route.centreline[#route.centreline].x,
						route.centreline[#route.centreline].z,
						"policy_ingress_endpoint")
				end
			end
		end
		for _, point in ipairs({{-2700,0},{2700,0},{0,0},
				{common.MIN_X,common.MIN_Z},{common.MAX_X,common.MAX_Z}}) do
			add(point[1], point[2], "policy_water")
		end
		if policy_points then
			common.dense_count(policy_points, "policy nearest points")
			for index = 1, #policy_points do
				add(policy_points[index].x, policy_points[index].z,
					"targeted_policy:" .. policy_points[index].label)
			end
		end
		add(common.MIN_X - 1, common.MIN_Z, "outside")
		add(common.MAX_X + 1, common.MAX_Z, "outside")
		return sorted_points(points)
	end

	local function choose_mode_rows(rows, mode, stride)
		if mode == "full" then return rows end
		if mode ~= "targeted" then fail("unknown validation mode") end
		local result = {}
		for index = 1, #rows, stride do result[#result + 1] = rows[index] end
		if #rows > 0 and result[#result] ~= rows[#rows] then
			result[#result + 1] = rows[#rows]
		end
		return result
	end

	local function compare_nearest(actual, expected, hydrology, x, z)
		if not expected then
			if actual ~= nil then fail("outside nearest result differs") end
			return
		end
		if type(actual) ~= "table" then fail("nearest result absent") end
		local segment, feature = expected.segment_record,
			expected.segment_record.feature
		if actual.segment ~= segment.segment or
				actual.distance_numerator ~= expected.numerator or
				actual.distance_denominator ~= expected.denominator or
				actual.distance_squared ~= expected.numerator / expected.denominator then
			fail("nearest exact distance differs at " .. x .. "," .. z)
		end
		if hydrology then
			if actual.hydrology_id ~= feature.id then
				fail("nearest hydrology identity differs")
			end
		else
			if actual.route_id ~= feature.id or actual.path_kind ~= feature.path_kind or
					actual.route_class ~= feature.route_class or
					actual.surface_width ~= feature.surface_width or
					actual.corridor_width ~= feature.corridor_width then
				fail("nearest route identity/profile differs")
			end
		end
	end

	local function mutate_and_compare(first, fresh_callback, label)
		if type(first) ~= "table" then fail(label .. " mutation target missing") end
		local before = common.deep_copy(first)
		first.__mutation = true
		for _, child in pairs(first) do
			if type(child) == "table" then child.__mutation = true break end
		end
		if not exact_equal(fresh_callback(), before) then
			fail(label .. " is not a defensive copy")
		end
	end

	local function adjacent_hard_boundary(start_x, start_z, inside_callback,
			outside_callback)
		if not inside_callback(start_x, start_z) then
			fail("hard boundary search did not start inside")
		end
		for _, direction in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
			local previous_x, previous_z = start_x, start_z
			for distance = 1, 2048 do
				local x = start_x + direction[1] * distance
				local z = start_z + direction[2] * distance
				if not inside_callback(x, z) then
					if not outside_callback or outside_callback(x, z) then
						return previous_x, previous_z, x, z
					end
					break
				end
				previous_x, previous_z = x, z
			end
		end
		fail("adjacent hard inside/outside witness absent")
	end

	local function validate_terrain_passthrough(session, context, raw_sha256,
			policy_points)
		local source = require_context(context, true)
		local points, add = point_set()
		for index = 1, #policy_points do
			add(policy_points[index].x, policy_points[index].z,
				"targeted_policy")
		end
		for index = 1, #source.anchors do
			add(source.anchors[index].position.x, source.anchors[index].position.z,
				"r3_anchor")
		end
		for _, point in ipairs({
			{common.MIN_X,common.MIN_Z},{common.MIN_X,common.MAX_Z},
			{common.MAX_X,common.MIN_Z},{common.MAX_X,common.MAX_Z},
			{common.MIN_X-1,common.MIN_Z},{common.MAX_X+1,common.MAX_Z},
			{common.MAX_SAFE,common.MAX_SAFE},
			{-common.MAX_SAFE,-common.MAX_SAFE},
		}) do add(point[1], point[2], "extent_boundary") end
		local exterior = {}
		local artifact = common.read_file(context.repo ..
			"/docs/research/wp40-simple-map-r3-artifact.tsv")
		for line in artifact:gmatch("([^\n]+)\n") do
			local ordinal, axis, value = line:match("^evidence\theight/height/" ..
				"exterior_witnesses/(%d+)/(x)\tnumber\t(%-?%d+)$")
			if not ordinal then
				ordinal, axis, value = line:match("^evidence\theight/height/" ..
					"exterior_witnesses/(%d+)/(z)\tnumber\t(%-?%d+)$")
			end
			if ordinal then
				exterior[ordinal] = exterior[ordinal] or {}
				exterior[ordinal][axis] = assert(tonumber(value))
			end
		end
		local exterior_count = 0
		for ordinal, point in pairs(exterior) do
			if type(ordinal) ~= "string" or point.x == nil or point.z == nil then
				fail("R3 exterior witness parse differs")
			end
			add(point.x, point.z, "r3_exterior_witness")
			exterior_count = exterior_count + 1
		end
		if exterior_count ~= 4 then fail("R3 exterior witness count differs") end
		sorted_points(points)
		local rows = {}
		for index = 1, #points do
			local point = points[index]
			local expected
			if point.x < common.MIN_X or point.x > common.MAX_X or
					point.z < common.MIN_Z or point.z > common.MAX_Z then
				expected = -23
			else
				expected = context.height.terrain_height_at(point.x, point.z)
			end
			common.safe_integer(expected, "accepted R3 terrain height")
			if session.terrain_height_at(point.x, point.z) ~= expected then
				fail("R3 terrain-height passthrough differs")
			end
			rows[#rows + 1] = point.x .. "\t" .. point.z .. "\t" ..
				expected .. "\n"
		end
		return #points, digest_rows(raw_sha256, rows), exterior_count
	end

	function validator.validate_supplemental(session, context, raw_sha256, mode)
		local source = require_context(context, true)
		local hard = build_hard_oracle(context, true)
		local housing_all, housing_order_count = housing_corpus(context)
		local housing_rows = choose_mode_rows(housing_all, mode, 64)
		local housing_digest_rows, housing_true = {}, 0
		for index = 1, #housing_rows do
			local point = housing_rows[index]
			local x, z = common.normalize_xz(point.x, point.z)
			local expected = false
			if x >= common.MIN_X and x <= common.MAX_X and
					z >= common.MIN_Z and z <= common.MAX_Z then
				expected = context.horizontal.housing_eligible_at(x, z)
			end
			local actual = session.housing_eligible_at(point.x, point.z)
			if actual ~= expected then fail("housing wrapper parity differs") end
			if actual then housing_true = housing_true + 1 end
			housing_digest_rows[#housing_digest_rows + 1] = table.concat({
				common.canonical_number(point.x), common.canonical_number(point.z),
				tostring(actual)}, "\t") .. "\n"
		end

		-- Reuse the exact targeted-policy roster as nearest-oracle input.  The
		-- third return is intentionally ignored by the KAT writer but prevents
		-- the full and targeted validators from growing separate point lists.
		local _, _, policy_points = validator.targeted_rows(session, context,
			raw_sha256)
		local terrain_count, terrain_sha256, r3_exterior_count =
			validate_terrain_passthrough(session, context, raw_sha256, policy_points)
		local route_features, route_segments = route_catalog(source)
		local hydrology_features, hydrology_segments = hydrology_catalog(source)
		local nearest_all = nearest_samples(source, policy_points)
		local samples = choose_mode_rows(nearest_all, mode, 32)
		local route_digest_rows, hydrology_digest_rows = {}, {}
		for index = 1, #samples do
			local point = samples[index]
			local route_expected = nearest_oracle(route_segments, point.x, point.z, false)
			local hydrology_expected = nearest_oracle(
				hydrology_segments, point.x, point.z, true)
			local route_actual = session.nearest_route_at(point.x, point.z)
			local hydrology_actual = session.nearest_hydrology_at(point.x, point.z)
			compare_nearest(route_actual, route_expected, false, point.x, point.z)
			compare_nearest(hydrology_actual, hydrology_expected, true, point.x, point.z)
			route_digest_rows[#route_digest_rows + 1] = table.concat({point.x, point.z,
				route_actual and route_actual.route_id or NIL,
				route_actual and route_actual.segment or NIL,
				route_actual and route_actual.distance_numerator or NIL,
				route_actual and route_actual.distance_denominator or NIL}, "\t") .. "\n"
			hydrology_digest_rows[#hydrology_digest_rows + 1] = table.concat({point.x,
				point.z, hydrology_actual and hydrology_actual.hydrology_id or NIL,
				hydrology_actual and hydrology_actual.segment or NIL,
				hydrology_actual and hydrology_actual.distance_numerator or NIL,
				hydrology_actual and hydrology_actual.distance_denominator or NIL},
				"\t") .. "\n"
		end

		local metrics = session.metrics()
		assert_metrics_zero(metrics, "supplemental")
		for _, prefix in ipairs({"nearest_route", "nearest_hydrology"}) do
			if metrics[prefix .. "_query_count"] <= 0 or
					metrics[prefix .. "_maximum_rings_scanned"] <= 0 or
					metrics[prefix .. "_maximum_cells_scanned"] <= 0 or
					metrics[prefix .. "_maximum_candidates_scanned"] <= 0 then
				fail(prefix .. " metric maxima were not exercised")
			end
		end

		-- Exercise exact policy membership for every recipe, including a known
		-- adjacent point outside each individual footprint.
		local recipe_seen, hard_rows = {}, {}
		for index = 1, #hard.records do
			local row = hard.records[index]
			recipe_seen[row.recipe_id] = true
			local x, z
			if row.shape == "polyline_corridor" then
				x, z = row.paths[1][1].x, row.paths[1][1].z
			else x, z = row.center.x, row.center.z end
			local expected = hard.at(x, -700, z)
			if not expected or session.territory_rule_at({x=x,y=-700,z=z}) ~=
					"hard_protected" then fail("hard inside witness differs") end
			local inside_x, inside_z, outside_x, outside_z = adjacent_hard_boundary(
				x, z, function(px, pz) return hard.member(row, px, pz) end,
				function(px, pz) return session.territory_rule_at(
					{x=px,y=-700,z=pz}) ~= "hard_protected" end)
			if math.abs(inside_x - outside_x) + math.abs(inside_z - outside_z) ~= 1 then
				fail("hard adjacent witness distance differs")
			end
			hard_rows[#hard_rows + 1] = table.concat({row.id, row.recipe_id,
				row.membership_columns, inside_x, inside_z, outside_x, outside_z},
				"\t") .. "\n"
		end
		local recipe_count = 0
		for _ in pairs(recipe_seen) do recipe_count = recipe_count + 1 end
		if recipe_count ~= 4 then fail("hard recipe coverage differs") end

		local zone = source.zones[1]
		mutate_and_compare(session.get(zone.id), function() return session.get(zone.id) end,
			"zone record")
		mutate_and_compare(session.at({x=zone.hub.x,y=0,z=zone.hub.z}),
			function() return session.at({x=zone.hub.x,y=0,z=zone.hub.z}) end,
			"zone-at record")
		mutate_and_compare(session.neighbors(zone.id),
			function() return session.neighbors(zone.id) end, "neighbor list")
		local boat_zone = source.zones[source.boat_paths[1].from_zone].id
		mutate_and_compare(session.travel_links(boat_zone),
			function() return session.travel_links(boat_zone) end, "travel list")
		local anchor = source.anchors[1]
		local anchor_zone = source.zones[anchor.zone_numeric_id].id
		mutate_and_compare(session.anchor(anchor_zone, anchor.slot_id),
			function() return session.anchor(anchor_zone, anchor.slot_id) end,
			"anchor record")
		mutate_and_compare(session.nearest_route_at(0, 0),
			function() return session.nearest_route_at(0, 0) end, "route result")
		mutate_and_compare(session.nearest_hydrology_at(0, 0),
			function() return session.nearest_hydrology_at(0, 0) end,
			"hydrology result")

		return {schema = SUPPLEMENTAL_SCHEMA, mode = mode,
			housing_result_sha256 = common.HOUSING_RESULT_SHA256,
			housing_order_count = housing_order_count,
			housing_corpus_count = #housing_rows, housing_true_count = housing_true,
			housing_wrapper_sha256 = digest_rows(raw_sha256, housing_digest_rows),
			route_feature_count = #route_features,
			route_segment_count = #route_segments,
			hydrology_feature_count = #hydrology_features,
			hydrology_segment_count = #hydrology_segments,
			nearest_sample_count = #samples,
			nearest_route_sha256 = digest_rows(raw_sha256, route_digest_rows),
			nearest_hydrology_sha256 = digest_rows(raw_sha256, hydrology_digest_rows),
			hard_record_count = #hard.records, hard_recipe_count = recipe_count,
			hard_membership_sha256 = digest_rows(raw_sha256, hard_rows),
			terrain_passthrough_count = terrain_count,
			terrain_passthrough_sha256 = terrain_sha256,
			r3_exterior_witness_count = r3_exterior_count,
			metrics = metrics, defensive_family_count = 7, violation_count = 0}
	end

	local function logical_oracle(context, raw_sha256, session)
		local source = require_context(context, false)
		if type(context.repo) ~= "string" or context.repo:sub(1, 1) ~= "/" then
			fail("logical oracle requires absolute repository root")
		end
		local canonical = dofile(context.repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
		local deterministic = dofile(context.repo ..
			"/mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
		local seed = session.artifact_evidence().full_seed
		local selector = source.logical_biome_selector
		local hash = deterministic.new_hash(canonical, raw_sha256,
			selector.hash_schema, seed)
		local sites = {}
		local min_x = deterministic.floor_div(common.MIN_X, 192) - 1
		local max_x = deterministic.floor_div(common.MAX_X, 192) + 1
		local min_z = deterministic.floor_div(common.MIN_Z, 192) - 1
		local max_z = deterministic.floor_div(common.MAX_Z, 192) + 1
		for cell_x = min_x, max_x do
			sites[cell_x] = {}
			for cell_z = min_z, max_z do
				sites[cell_x][cell_z] = {
					x = cell_x * 192 + 32 + hash.range(selector.hash_domain, "",
						{cell_x, cell_z}, 0, selector.hash_lanes.site_x, 128),
					z = cell_z * 192 + 32 + hash.range(selector.hash_domain, "",
						{cell_x, cell_z}, 0, selector.hash_lanes.site_z, 128),
					roll = hash.range(selector.hash_domain, "", {cell_x, cell_z},
						0, selector.hash_lanes.palette, 100),
					cell_x = cell_x, cell_z = cell_z,
				}
			end
		end
		local zones_by_id = source_maps(source)
		local function winner(x, z)
			local own_x, own_z = deterministic.floor_div(x, 192),
				deterministic.floor_div(z, 192)
			local best, best_distance, ties
			for cell_x = own_x - 1, own_x + 1 do
				for cell_z = own_z - 1, own_z + 1 do
					local site = sites[cell_x] and sites[cell_x][cell_z]
					if not site then fail("logical oracle halo differs") end
					local dx, dz = x - site.x, z - site.z
					local distance = dx * dx + dz * dz
					if best_distance == nil or distance < best_distance then
						best, best_distance, ties = site, distance, 1
					elseif distance == best_distance then
						ties = ties + 1
						if site.cell_x < best.cell_x or
								(site.cell_x == best.cell_x and site.cell_z < best.cell_z) then
							best = site
						end
					end
				end
			end
			return best, best_distance, ties
		end
		local function biome_at(x, z, zone_id)
			local zone = zones_by_id[zone_id]
			if not zone then return nil end
			local site = winner(x, z)
			local cumulative = 0
			for index = 1, #zone.biomes do
				cumulative = cumulative + zone.biomes[index].share
				if site.roll < cumulative then return zone.biomes[index].id end
			end
			fail("logical oracle palette escaped")
		end
		local function find_tie()
			for cell_x = min_x + 1, max_x - 1 do
				for cell_z = min_z + 1, max_z - 1 do
					local a = sites[cell_x][cell_z]
					for _, delta in ipairs({{1,0},{0,1},{1,1},{1,-1}}) do
						local b = sites[cell_x + delta[1]][cell_z + delta[2]]
						local coefficient_x = 2 * (b.x - a.x)
						local coefficient_z = 2 * (b.z - a.z)
						local constant = b.x*b.x + b.z*b.z - a.x*a.x - a.z*a.z
						for z = math.max(common.MIN_Z, (cell_z - 1) * 192),
								math.min(common.MAX_Z, (cell_z + 2) * 192 - 1) do
							local remainder = constant - coefficient_z * z
							if coefficient_x ~= 0 and remainder % coefficient_x == 0 then
								local x = remainder / coefficient_x
								if x >= common.MIN_X and x <= common.MAX_X then
									local _, _, ties = winner(x, z)
									if ties >= 2 and session.id_at(x, z) ~= nil then
										return x, z
									end
								end
							elseif coefficient_x == 0 and remainder == 0 then
								local x = math.max(common.MIN_X, cell_x * 192)
								local _, _, ties = winner(x, z)
								if ties >= 2 and session.id_at(x, z) ~= nil then
									return x, z
								end
							end
						end
					end
				end
			end
			fail("no integer logical-biome distance tie found")
		end
		local function find_seeded_site()
			for cell_x = min_x, max_x do
				for cell_z = min_z, max_z do
					local site = sites[cell_x][cell_z]
					if site.x >= common.MIN_X and site.x <= common.MAX_X and
							site.z >= common.MIN_Z and site.z <= common.MAX_Z and
							session.id_at(site.x, site.z) ~= nil then
						local selected, distance = winner(site.x, site.z)
						if selected ~= site or distance ~= 0 then
							fail("seeded logical site does not select itself")
						end
						return site
					end
				end
			end
			fail("owner-bearing seeded logical site absent")
		end
		return {biome_at = biome_at, winner = winner, find_tie = find_tie,
			find_seeded_site = find_seeded_site}
	end

	local function add_coverage(coverage, family, value)
		nonempty_text(family, "coverage family")
		nonempty_text(value, "coverage value")
		local values = coverage[family]
		if not values then values = {} coverage[family] = values end
		values[value] = true
	end

	local function distinct_feature_tie(features, segments, hydrology)
		local candidates, seen = {}, {}
		for feature_index = 1, #features do
			for point_index = 1, #features[feature_index].centreline do
				local point = features[feature_index].centreline[point_index]
				local point_key = point.x .. ":" .. point.z
				if not seen[point_key] then
					seen[point_key] = true
					candidates[#candidates + 1] = {x=point.x,z=point.z}
				end
			end
		end
		table.sort(candidates, function(a, b)
			if a.x ~= b.x then return a.x < b.x end
			return a.z < b.z
		end)
		for candidate_index = 1, #candidates do
			local point = candidates[candidate_index]
			local tied, tied_count = {}, 0
			for segment_index = 1, #segments do
				local numerator = segment_distance(point.x, point.z,
					segments[segment_index])
				if numerator == 0 then
					local feature = segments[segment_index].feature
					if not tied[feature.id] then
						tied[feature.id] = feature
						tied_count = tied_count + 1
					end
				end
			end
			if tied_count >= 2 then
				local expected = nearest_oracle(segments, point.x, point.z, hydrology)
				local best
				for _, feature in pairs(tied) do
					if not best or (hydrology and feature.order < best.order) or
							(not hydrology and feature.id < best.id) then best = feature end
				end
				if not expected or expected.numerator ~= 0 or
						expected.segment_record.feature.id ~= best.id then
					fail("independent distinct-feature tie winner differs")
				end
				return point.x, point.z, expected, tied_count
			end
		end
		fail("distinct-feature nearest tie witness absent")
	end

	local function same_feature_segment_tie(segments, x, z, feature_id,
			expected_segment, hydrology)
		local first, second
		for index = 1, #segments do
			local segment = segments[index]
			if segment.feature.id == feature_id then
				if segment.segment == 1 then first = segment
				elseif segment.segment == 2 then second = segment end
			end
		end
		if not first or not second then fail("same-feature tie segments absent") end
		local first_numerator, first_denominator = segment_distance(x, z, first)
		local second_numerator, second_denominator = segment_distance(x, z, second)
		if common.rational_compare(first_numerator, first_denominator,
				second_numerator, second_denominator) ~= 0 then
			fail("reviewed same-feature segment witness is not equidistant")
		end
		local expected = nearest_oracle(segments, x, z, hydrology)
		if not expected or expected.segment_record.feature.id ~= feature_id or
				expected.segment_record.segment ~= expected_segment or
				common.rational_compare(expected.numerator, expected.denominator,
					first_numerator, first_denominator) ~= 0 then
			fail("same-feature raw-segment tie winner differs")
		end
		return expected
	end

	function validator.targeted_rows(session, context, raw_sha256)
		local source = require_context(context, false)
		local peer = context.peer_session
		if type(peer) ~= "table" then fail("targeted KAT peer session missing") end
		local rows, coverage = {}, {}
		local policy_points, add_policy_point = point_set()
		local logical = logical_oracle(context, raw_sha256, session)
		local route_features, route_segments = route_catalog(source)
		local hydrology_features, hydrology_segments = hydrology_catalog(source)
		local function assert_peer(name, ...)
			local a = session[name](...)
			local b = peer[name](...)
			if not exact_equal(a, b) then fail("targeted peer parity differs: " .. name) end
			return a
		end
		local function add_query(label, x, y, z)
			local id = assert_peer("id_at", x, z)
			local biome = assert_peer("biome_at", x, z)
			local race = assert_peer("race_region_at", x, z)
			local faction = assert_peer("faction_at", {x=x,y=y,z=z})
			local territory = assert_peer("territory_rule_at", {x=x,y=y,z=z})
			local pvp = assert_peer("pvp_rule_at", {x=x,y=y,z=z})
			local surface = assert_peer("surface_mob_level_at", x, z)
			local mob = assert_peer("mob_level_at", {x=x,y=y,z=z})
			local guard = assert_peer("guard_level_at", {x=x,y=y,z=z})
			local terrain = assert_peer("terrain_height_at", x, z)
			local water = assert_peer("water_class_at", x, z)
			local route = assert_peer("nearest_route_at", x, z)
			local hydrology = assert_peer("nearest_hydrology_at", x, z)
			local housing = assert_peer("housing_eligible_at", x, z)
			local legacy_zone = session.compatibility.zone_at({x=x,y=y,z=z})
			local legacy_territory = session.compatibility.territory_at({x=x,y=y,z=z})
			local open_sea = session.compatibility.open_sea_at({x=x,y=y,z=z})
			local protection_accord = session.compatibility.world_protected_for_faction(
				{x=x,y=y,z=z}, "accord")
			local protection_throng = session.compatibility.world_protected_for_faction(
				{x=x,y=y,z=z}, "throng")
			local difficulty_numerator = mob and math.max(0, math.min(59, mob - 1)) or 1
			local difficulty_denominator = mob and 59 or 1
			if session.compatibility.surface_level_at(x,z) ~= terrain or
					session.compatibility.mob_level_at({x=x,y=y,z=z}) ~= mob or
					session.compatibility.guard_level_at({x=x,y=y,z=z}) ~= guard or
					session.compatibility.difficulty_at({x=x,y=y,z=z}) ~=
						difficulty_numerator / difficulty_denominator then
				fail("compatibility direct-adapter parity differs")
			end
			local nx, nz = common.normalize_xz(x, z)
			add_policy_point(nx, nz, label)
			if id and logical.biome_at(nx, nz, id) ~= biome then
				fail("targeted logical-biome oracle differs")
			end
			rows[#rows + 1] = {TARGETED_SCHEMA, label,
				common.canonical_number(x), common.canonical_number(y),
				common.canonical_number(z), water, scalar(id), scalar(biome),
				scalar(race), scalar(faction), territory, scalar(pvp),
				scalar(surface), scalar(mob), scalar(guard), terrain,
				legacy_zone, legacy_territory, open_sea,
				difficulty_numerator, difficulty_denominator,
				protection_accord, protection_throng, housing,
				route and route.route_id or NIL, route and route.segment or NIL,
				route and route.distance_numerator or NIL,
				route and route.distance_denominator or NIL,
				hydrology and hydrology.hydrology_id or NIL,
				hydrology and hydrology.segment or NIL,
				hydrology and hydrology.distance_numerator or NIL,
				hydrology and hydrology.distance_denominator or NIL}
			add_coverage(coverage, "water", water)
			add_coverage(coverage, "owner_class", id and
				("owner_bearing:" .. water) or ("ownerless:" .. water))
			add_coverage(coverage, "faction", scalar(faction))
			add_coverage(coverage, "territory", territory)
			add_coverage(coverage, "pvp", scalar(pvp))
			add_coverage(coverage, "legacy_zone", legacy_zone)
			return {x=nx,z=nz,water=water,id=id,territory=territory,pvp=pvp}
		end

		local water_witness = {}
		for _, point in ipairs({{-2700,0},{2700,0},
			{common.MIN_X,common.MIN_Z},{0,0}}) do
			local water = session.water_class_at(point[1], point[2])
			water_witness[water] = water_witness[water] or point
		end
		for z = common.MIN_Z, common.MAX_Z, 32 do
			if next(water_witness) and water_witness.land and
					water_witness.planned_water and water_witness.coastal_shelf and
					water_witness.deep_ocean and
					water_witness.immutable_dragon_channel then break end
			for x = common.MIN_X, common.MAX_X, 32 do
				local water = session.water_class_at(x,z)
				water_witness[water] = water_witness[water] or {x,z}
			end
		end
		for _, water in ipairs({"land","planned_water","coastal_shelf",
				"deep_ocean","immutable_dragon_channel"}) do
			local point = water_witness[water]
			if not point then fail("targeted water witness absent: " .. water) end
			add_query("water:" .. water, point[1], 0, point[2])
		end

		local y_values = {1,0,-1,-40,-300,-301,-500,-501,-700,-701,-1000,-1001}
		local function territory_surface_witness(token)
			for zone_index = 1, #source.zones do
				local zone = source.zones[zone_index]
				if zone.territory_rule == token and
						session.id_at(zone.hub.x, zone.hub.z) == zone.id and
						session.territory_rule_at(
							{x=zone.hub.x,y=0,z=zone.hub.z}) == token then
					return {zone.hub.x, zone.hub.z}
				end
			end
			fail("surface territory witness absent: " .. token)
		end
		for _, token in ipairs({"accord_home","throng_home","contested_land",
				"holy_grounds"}) do
			local point = territory_surface_witness(token)
			for y_index = 1, #y_values do
				local result = add_query("boundary:" .. token, point[1],
					y_values[y_index], point[2])
				if y_values[y_index] >= -700 and result.territory ~= token then
					fail("surface territory witness changed: " .. token)
				end
			end
		end
		for _, water in ipairs({"planned_water","coastal_shelf","deep_ocean",
				"immutable_dragon_channel"}) do
			local point = water_witness[water]
			for y_index = 1, #y_values do
				local result = add_query("boundary:" .. water, point[1],
					y_values[y_index], point[2])
				if result.water ~= water then fail("boundary water witness changed") end
			end
		end

		local recipes, routes_by_id = {}, {}
		for index = 1, #source.hard_protection_recipes do
			recipes[source.hard_protection_recipes[index].id] =
				source.hard_protection_recipes[index]
		end
		for index = 1, #source.routes do routes_by_id[source.routes[index].id] = source.routes[index] end
		local hard_recipe_seen = {}
		for index = 1, #source.hard_protection do
			local row = source.hard_protection[index]
			if not hard_recipe_seen[row.recipe_id] then
				hard_recipe_seen[row.recipe_id] = true
				local recipe, x, z = recipes[row.recipe_id]
				if recipe.shape == "polyline_corridor" then
					x, z = routes_by_id[row.route_ids[1]].centreline[1].x,
						routes_by_id[row.route_ids[1]].centreline[1].z
				else x, z = row.center.x, row.center.z end
				if add_query("hard_inside:" .. row.recipe_id, x, -700, z).territory ~=
						"hard_protected" then fail("targeted hard witness differs") end
				local inside_x, inside_z, outside_x, outside_z = adjacent_hard_boundary(
					x, z,
					function(px, pz) return session.territory_rule_at(
						{x=px,y=-700,z=pz}) == "hard_protected" end)
				if add_query("hard_boundary_inside:" .. row.recipe_id,
						inside_x, -700, inside_z).territory ~= "hard_protected" or
						add_query("hard_outside:" .. row.recipe_id,
						outside_x, -700, outside_z).territory == "hard_protected" then
					fail("targeted adjacent hard boundary differs")
				end
				add_coverage(coverage, "hard_recipe", row.recipe_id)
			end
		end
		add_coverage(coverage, "hard_recipe", "adjacent_outside")
		local capital = source.hard_protection[7].center
		local ingress = source.hard_protection[13]
		local ingress_path = routes_by_id[ingress.route_ids[1]].centreline
		local ingress_point = ingress_path[math.floor((#ingress_path + 1) / 2)]
		for _, row in ipairs({{"capital",capital.x,capital.z},
				{"ingress",ingress_point.x,ingress_point.z}}) do
			for y_index = 1, #y_values do
				add_query("boundary:" .. row[1], row[2], y_values[y_index], row[3])
			end
			add_coverage(coverage, "boundary_family", row[1])
		end
		for _, family in ipairs({"home","contested","battlegrounds",
				"planned_water","coastal_shelf","deep_ocean",
				"immutable_dragon_channel"}) do
			add_coverage(coverage, "boundary_family", family)
		end

		local tie_x, tie_z = logical.find_tie()
		add_query("logical_distance_tie", tie_x, 0, tie_z)
		add_query("logical_cell_edge", 0, 0, 192)
		local seeded_site = logical.find_seeded_site()
		local selected_site, selected_distance = logical.winner(
			seeded_site.x, seeded_site.z)
		if selected_site.cell_x ~= seeded_site.cell_x or
				selected_site.cell_z ~= seeded_site.cell_z or selected_distance ~= 0 then
			fail("targeted seeded-site winner differs")
		end
		add_query("logical_seeded_site", seeded_site.x, 0, seeded_site.z)
		add_coverage(coverage, "logical_biome", "distance_tie")
		add_coverage(coverage, "logical_biome", "cell_edge")
		add_coverage(coverage, "logical_biome", "seeded_site")

		local route_x, route_z, route_expected = distinct_feature_tie(
			route_features, route_segments, false)
		compare_nearest(session.nearest_route_at(route_x,route_z), route_expected,
			false, route_x, route_z)
		add_query("nearest_route_tie", route_x, 0, route_z)
		local hydro_x, hydro_z, hydro_expected = distinct_feature_tie(
			hydrology_features, hydrology_segments, true)
		compare_nearest(session.nearest_hydrology_at(hydro_x,hydro_z), hydro_expected,
			true, hydro_x, hydro_z)
		add_query("nearest_hydrology_tie", hydro_x, 0, hydro_z)
		add_coverage(coverage, "nearest", "route_tie")
		add_coverage(coverage, "nearest", "hydrology_tie")
		local route_segment_expected = same_feature_segment_tie(route_segments,
			-1906, -2447, "route_001", 1, false)
		compare_nearest(session.nearest_route_at(-1906, -2447),
			route_segment_expected, false, -1906, -2447)
		add_query("nearest_route_segment_tie", -1906, 0, -2447)
		local hydro_segment_expected = same_feature_segment_tie(hydrology_segments,
			-2260, -1880, "hydro_copperfell_streams", 1, true)
		compare_nearest(session.nearest_hydrology_at(-2260, -1880),
			hydro_segment_expected, true, -2260, -1880)
		add_query("nearest_hydrology_segment_tie", -2260, 0, -1880)
		add_coverage(coverage, "nearest", "route_segment_tie")
		add_coverage(coverage, "nearest", "hydrology_segment_tie")

		for _, point in ipairs({{-0.5,-0.5},{0.5,0.5},
				{common.MAX_SAFE,common.MAX_SAFE},{-common.MAX_SAFE,-common.MAX_SAFE}}) do
			add_query("normalization", point[1], 0, point[2])
		end
		add_coverage(coverage, "coordinate", "positive_half_tie")
		add_coverage(coverage, "coordinate", "negative_half_tie")
		add_coverage(coverage, "coordinate", "safe_extrema")
		add_coverage(coverage, "coordinate", "malformed")

		local known = source.zones[1].id
		if not session.get(known) or session.get("__unknown__") ~= nil or
				#session.neighbors("__unknown__") ~= 0 then fail("targeted registry differs") end
		add_coverage(coverage, "registry", "known")
		add_coverage(coverage, "registry", "unknown")
		local anchor = source.anchors[1]
		local anchor_zone = source.zones[anchor.zone_numeric_id].id
		if not session.anchor(anchor_zone, anchor.slot_id) or
				session.anchor(anchor_zone, "__absent__") ~= nil then
			fail("targeted anchor differs")
		end
		add_coverage(coverage, "anchor", "known")
		add_coverage(coverage, "anchor", "absent")
		local boat = source.boat_paths[1]
		for _, endpoint in ipairs({boat.from_zone, boat.to_zone}) do
			local zone_id = source.zones[endpoint].id
			local links = session.travel_links(zone_id)
			local found
			for index = 1, #links do if links[index].id == boat.id then found = true end end
			if not found then fail("targeted travel direction differs") end
		end
		add_coverage(coverage, "travel", "forward")
		add_coverage(coverage, "travel", "reverse")
		mutate_and_compare(session.get(known), function() return session.get(known) end,
			"targeted zone record")
		add_coverage(coverage, "ownership", "defensive_copy")
		validator.assert_targeted_coverage(coverage)
		return rows, coverage, sorted_points(policy_points)
	end

	local REQUIRED_TARGETED_COVERAGE = {
		water = {"land","planned_water","coastal_shelf","deep_ocean",
			"immutable_dragon_channel"},
		owner_class = {"owner_bearing:land","owner_bearing:planned_water",
			"owner_bearing:coastal_shelf","ownerless:deep_ocean",
			"ownerless:immutable_dragon_channel"},
		faction = {"accord","throng",NIL},
		territory = {"accord_home","throng_home","contested_land",
			"holy_grounds","hard_protected","immutable"},
		pvp = {"peaceful","contested",NIL},
		hard_recipe = {"hard_capital_build_plus_apron_v1",
			"hard_capital_ingress_corridor_v1","hard_start_core_v1",
			"hard_apex_socket_column_v1","adjacent_outside"},
		logical_biome = {"distance_tie","cell_edge","seeded_site"},
		nearest = {"route_tie","hydrology_tie","route_segment_tie",
			"hydrology_segment_tie"},
		coordinate = {"positive_half_tie","negative_half_tie","safe_extrema",
			"malformed"},
		registry = {"known","unknown"}, anchor = {"known","absent"},
		travel = {"forward","reverse"}, ownership = {"defensive_copy"},
		boundary_family = {"home","contested","battlegrounds","capital",
			"ingress","planned_water","coastal_shelf","deep_ocean",
			"immutable_dragon_channel"},
	}

	function validator.assert_targeted_coverage(coverage)
		if type(coverage) ~= "table" then fail("targeted coverage missing") end
		for family, values in pairs(REQUIRED_TARGETED_COVERAGE) do
			for index = 1, #values do
				if not coverage[family] or coverage[family][values[index]] ~= true then
					fail("targeted coverage missing " .. family .. "/" .. values[index])
				end
			end
		end
		return true
	end

	local function project(value, active)
		local kind = type(value)
		if kind ~= "table" then
			if kind == "number" then common.safe_integer(value, "projection number")
			elseif kind ~= "string" and kind ~= "boolean" then
				fail("unsupported deterministic projection scalar")
			end
			return value
		end
		active = active or {}
		if active[value] then fail("cyclic deterministic projection") end
		active[value] = true
		local result = {}
		for map_key, child in pairs(value) do
			if type(map_key) ~= "string" and (type(map_key) ~= "number" or
					map_key % 1 ~= 0 or map_key < 1) then
				fail("unsupported deterministic projection key")
			end
			result[map_key] = project(child, active)
		end
		active[value] = nil
		return result
	end

	function validator.deterministic_projection(aggregate)
		if type(aggregate) ~= "table" then fail("projection aggregate missing") end
		return project(aggregate)
	end

	return validator
end
