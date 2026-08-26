-- Exhaustive and targeted gates for the WP40 simple-map R3 height session.

return function(common)
	local validator = {}
	local Q = 65536
	local ALLOWED_FUNCTIONAL = {
		land_grade = true,
		anchor_platform = true,
		causeway = true,
		ford = true,
		bridge_deck = true,
		tunnel_floor = true,
	}
	local ALLOWED_TRANSITIONS = {rapid = true, waterfall = true}
	local BASELINE_DIAGNOSIS_PAIRS = {
		{"island_route_stormscale_junction_apex", "poi_spur_086"},
		{"poi_spur_013", "route_001"},
		{"poi_spur_023", "route_016"},
		{"poi_spur_025", "route_001"},
		{"poi_spur_029", "poi_spur_051"},
		{"poi_spur_036", "route_048"},
		{"poi_spur_045", "route_016"},
		{"poi_spur_050", "route_043"},
		{"poi_spur_060", "route_054"},
		{"poi_spur_069", "route_010"},
		{"poi_spur_077", "route_055"},
		{"poi_spur_081", "route_052"},
		{"route_051", "route_056"},
		{"route_052", "route_056"},
	}
	local DIAGNOSIS_FIELDS = {
		"losing_path_id", "losing_run", "from_x", "from_z", "from_y",
		"to_x", "to_z", "to_y", "absolute_step", "winner_path_id",
		"winner_run", "winner_x", "winner_z", "pair_a", "pair_b",
	}
	local DIAGNOSIS_SORT_FIELDS = {
		"losing_path_id", "losing_run", "from_x", "from_z", "to_x",
		"to_z", "winner_path_id", "winner_run", "winner_x", "winner_z",
	}

	local function fail(message)
		error("WP40 simple-map R3 validation: " .. message, 0)
	end

	local function method(value, name)
		if type(value[name]) ~= "function" then fail("session." .. name .. " missing") end
	end

	local function clearance_at(session, x, z)
		local water = session.water_surface_at(x, z)
		if water ~= nil then
			common.safe_integer(water, "water clearance datum")
			return water, false
		end
		local kind, _, upper, lower =
			session.hydrology_transition_values_at(x, z)
		if kind ~= "waterfall" then
			fail("planned-water column has no scalar water or waterfall datum at " ..
				tostring(x) .. "," .. tostring(z))
		end
		common.safe_integer(upper, "waterfall clearance upper y")
		common.safe_integer(lower, "waterfall clearance lower y")
		return math.max(upper, lower), true
	end

	local function exact_copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[exact_copy(key)] = exact_copy(child) end
		return result
	end

	local function normalized_evidence_bytes(evidence)
		local builder = common.new_tsv()
		common.add_evidence(builder, evidence)
		return builder.body()
	end

	local function row_id(row)
		return row.id or row.profile_id or row.anchor_id or row.interface_id or
			row.feature_id or row.core_id
	end

	local function require_array(evidence, name, count)
		local value = evidence[name]
		local actual = common.dense_count(value, "artifact evidence " .. name)
		if count and actual ~= count then
			fail(name .. " count differs: expected " .. count .. ", got " .. actual)
		end
		return value
	end

	local function require_id_coverage(rows, expected, label)
		local found = {}
		for index = 1, #rows do
			local id = row_id(rows[index])
			if type(id) ~= "string" or id == "" then fail(label .. " row has no id") end
			if found[id] then fail(label .. " has duplicate id " .. id) end
			found[id] = true
		end
		for index = 1, #expected do
			if not found[expected[index].id] then
				fail(label .. " evidence misses " .. expected[index].id)
			end
		end
	end

	local function check_digest_fields(value, path)
		if type(value) ~= "table" then return end
		for key, child in pairs(value) do
			local child_path = path .. "." .. tostring(key)
			if type(key) == "string" and
					(key == "digest" or key:match("_digest$") or key:match("_sha256$")) then
				common.digest(child, child_path)
			elseif type(child) == "table" then
				check_digest_fields(child, child_path)
			end
		end
	end

	local function check_zero_violation_fields(value, path)
		if type(value) ~= "table" then return end
		for key, child in pairs(value) do
			local child_path = path .. "." .. tostring(key)
			if type(child) == "table" then
				check_zero_violation_fields(child, child_path)
			elseif type(key) == "string" and type(child) == "number" and
					(key:match("_violations$") or key:match("_failures$") or
					key:match("_escapes$") or key == "rejected_anchors" or
					key == "reselected_anchors" or key == "unsafe_integers") then
				common.safe_integer(child, child_path)
				if child ~= 0 then fail(child_path .. " is not zero") end
			end
		end
	end

	local function maps_by_id(rows)
		local result = {}
		for index = 1, #rows do result[rows[index].id] = rows[index] end
		return result
	end

	local function expected_paths(source)
		local result = {}
		for index = 1, #source.routes do result[#result + 1] = source.routes[index] end
		for index = 1, #source.poi_spurs do result[#result + 1] = source.poi_spurs[index] end
		for index = 1, #source.island_routes do
			result[#result + 1] = source.island_routes[index]
		end
		return result
	end

	local function integer_fields(row, fields, label)
		for index = 1, #fields do
			common.safe_integer(row[fields[index]], label .. " " .. fields[index])
		end
	end

	local function validate_station_anchor_evidence(session, source, evidence)
		if evidence.source_cut_fill_limits_consumed ~= false then
			fail("source max_cut/max_fill were not explicitly retired")
		end
		local profile_by_id = maps_by_id(source.relief_profiles)
		local station_rows = require_array(evidence, "stations", #source.route_stations)
		require_id_coverage(station_rows, source.route_stations, "stations")
		local station_by_zone = {}
		for index = 1, #station_rows do
			local row = station_rows[index]
			integer_fields(row, {"zone_numeric_id", "primary_min_above_water",
				"primary_max_above_water", "zone_station_y", "hub_x", "hub_z",
				"hub_target_y"}, "station")
			local zone = source.zones[row.zone_numeric_id]
			local station = source.route_stations[row.zone_numeric_id]
			local profile = zone and profile_by_id[zone.primary_relief_id] or nil
			if not zone or not station or not profile or row.id ~= station.id or
					station.zone_numeric_id ~= row.zone_numeric_id or
					row.primary_profile_id ~= profile.id or
					row.primary_min_above_water ~= profile.min_above_water or
					row.primary_max_above_water ~= profile.max_above_water or
					row.zone_station_y ~= common.WATER_LEVEL + profile.min_above_water or
					row.hub_x ~= zone.hub.x or row.hub_z ~= zone.hub.z or
					type(row.hub_water) ~= "boolean" then
				fail("station/reference rule differs at " .. tostring(row.id))
			end
			if station_by_zone[row.zone_numeric_id] then
				fail("duplicate station zone " .. row.zone_numeric_id)
			end
			station_by_zone[row.zone_numeric_id] = row
			if row.hub_water then
				if row.capital_anchor_id ~= nil then
					fail("capital hub is planned water at " .. row.id)
				end
				common.safe_integer(row.hub_clearance_y, "station hub clearance")
				if row.hub_target_y ~= math.max(row.zone_station_y,
						row.hub_clearance_y + 1) then
					fail("planned-water hub target differs at " .. row.id)
				end
			elseif row.hub_clearance_y ~= nil then
				fail("dry station carries a clearance datum at " .. row.id)
			elseif row.capital_anchor_id == nil and
					row.hub_target_y ~= row.zone_station_y then
				fail("dry non-capital hub target differs at " .. row.id)
			end
		end

		local anchors = require_array(evidence, "anchors", #source.anchors)
		require_id_coverage(anchors, source.anchors, "anchors")
		local anchor_profile_by_id = maps_by_id(source.anchor_profiles)
		local source_anchor_by_id = maps_by_id(source.anchors)
		local capital_by_zone = {}
		for index = 1, #source.anchors do
			local anchor = source.anchors[index]
			if anchor.slot_id == "capital" then capital_by_zone[anchor.zone_numeric_id] = anchor end
		end
		for index = 1, #anchors do
			local row = anchors[index]
			local source_anchor = assert(source_anchor_by_id[row_id(row)])
			local profile = assert(anchor_profile_by_id[source_anchor.template_id])
			local station = assert(station_by_zone[source_anchor.zone_numeric_id])
			integer_fields(row, {"reference_y", "profile_midpoint_y", "fitting_width",
				"blend_width", "collar_width", "fitting_columns", "collar_columns",
				"platform_columns", "owner_escape_columns", "observed_max_cut",
				"observed_max_cut_witness_x", "observed_max_cut_witness_z",
				"observed_max_fill", "observed_max_fill_witness_x",
				"observed_max_fill_witness_z", "civic_water_columns"}, "anchor")
			local midpoint = common.WATER_LEVEL + math.floor(
				(station.primary_min_above_water + station.primary_max_above_water) / 2)
			if row.profile_midpoint_y ~= midpoint or row.fitting_width ~= profile.fitting_width or
					row.blend_width ~= profile.blend_width or
					row.fitting_width <= 0 or row.fitting_width % 2 ~= 0 or
					row.blend_width <= row.fitting_width or row.blend_width % 2 ~= 0 or
					row.collar_width ~= (profile.blend_width - profile.fitting_width) / 2 or
					row.fitting_columns ~= profile.fitting_width * profile.fitting_width or
					row.collar_columns ~= (profile.blend_width - 2) *
						(profile.blend_width - 2) - row.fitting_columns or
					row.owner_escape_columns ~= 0 or row.observed_max_cut < 0 or
					row.observed_max_fill < 0 or row.rejected ~= false or
					row.reselected ~= false then
				fail("anchor fitting/reference evidence differs at " .. source_anchor.id)
			end
			local expected_rule, expected_reference
			if source_anchor.slot_id == "start" then
				expected_rule, expected_reference = "start_zone_station", station.zone_station_y
			elseif source_anchor.slot_id == "capital" then
				local selected = session.selected_anchor_3d_by_id(source_anchor.id)
				if not selected or session.water_surface_at(selected.x, selected.z) ~= nil or
						select(1, session.hydrology_transition_values_at(
							selected.x, selected.z)) == "waterfall" then
					fail("capital centre is planned water at " .. source_anchor.id)
				end
				if row.civic_water_columns == 0 then
					expected_rule, expected_reference = "capital_zone_station",
						station.zone_station_y
					if row.civic_max_clearance_y ~= nil or
							row.civic_max_clearance_witness_x ~= nil or
							row.civic_max_clearance_witness_z ~= nil then
						fail("empty capital civic-water set has a maximum")
					end
				else
					integer_fields(row, {"civic_max_clearance_y",
						"civic_max_clearance_witness_x", "civic_max_clearance_witness_z"},
						"capital civic water")
					expected_rule, expected_reference = "capital_civic_max",
						math.max(station.zone_station_y, row.civic_max_clearance_y + 1)
					if clearance_at(session, row.civic_max_clearance_witness_x,
							row.civic_max_clearance_witness_z) ~= row.civic_max_clearance_y then
						fail("capital civic-water maximum witness differs")
					end
				end
				if row.platform_columns ~= 0 then
					fail("capital received an anchor platform at " .. source_anchor.id)
				end
			else
				local selected = session.selected_anchor_3d_by_id(source_anchor.id)
				local datum
				if selected then
					local water = session.water_surface_at(selected.x, selected.z)
					if water ~= nil then datum = water
					else
						local transition, _, upper, lower =
							session.hydrology_transition_values_at(selected.x, selected.z)
						if transition == "waterfall" then datum = math.max(upper, lower) end
					end
				end
				if datum then
					expected_rule, expected_reference = "profile_midpoint_water_raise",
						math.max(midpoint, datum + 1)
				else expected_rule, expected_reference = "profile_midpoint", midpoint end
			end
			if row.reference_rule ~= expected_rule or row.reference_y ~= expected_reference then
				fail("anchor reference rule differs at " .. source_anchor.id)
			end
			if row.platform_columns > 0 then
				integer_fields(row, {"platform_witness_x", "platform_witness_z"},
					"anchor platform")
				local datum = clearance_at(session, row.platform_witness_x,
					row.platform_witness_z)
				local kind, surface, feature = session.functional_surface_values_at(
					row.platform_witness_x, row.platform_witness_z)
				if kind ~= "anchor_platform" or feature ~= source_anchor.id or
						surface ~= math.max(row.reference_y, datum + 1) or
						session.terrain_height_at(row.platform_witness_x,
							row.platform_witness_z) ~= surface then
					fail("non-capital water platform witness differs at " .. source_anchor.id)
				end
			end
		end
		for zone_id, anchor in pairs(capital_by_zone) do
			local station = assert(station_by_zone[zone_id])
			local anchor_row = maps_by_id(anchors)[anchor.id]
			if station.capital_anchor_id ~= anchor.id or
					station.hub_target_y ~= anchor_row.reference_y then
				fail("capital hub/reference link differs at " .. anchor.id)
			end
		end
		return anchors
	end

	local function validate_route_operation_evidence(session, source, evidence)
		local routes = require_array(evidence, "routes")
		local paths = expected_paths(source)
		if #routes ~= #paths then
			fail("routes count differs: expected " .. #paths .. ", got " .. #routes)
		end
		require_id_coverage(routes, paths, "routes")
		local route_by_id = maps_by_id(routes)
		local pin_count_by_path, lower_count_by_path = {}, {}
		local lower_columns_by_path, raise_count_by_path = {}, {}, {}
		for index = 1, #routes do
			local row = routes[index]
			integer_fields(row, {"node_count", "baseline_min_y", "baseline_max_y",
				"final_min_y", "final_max_y", "maximum_step", "exact_pin_count",
				"water_lower_bound_run_count", "water_lower_bound_column_count",
				"raised_run_count", "support_witness_count"}, "route")
			if row.node_count <= 1 or row.baseline_min_y > row.baseline_max_y or
					row.final_min_y > row.final_max_y or row.maximum_step < 0 or
					row.maximum_step > 1 or row.raised_run_count ~= row.support_witness_count then
				fail("route grade aggregate differs at " .. row.id)
			end
			for _, key in ipairs({"baseline_digest", "final_grade_digest",
				"exact_pin_digest", "lower_bound_digest", "classification_digest"}) do
				common.digest(row[key], "route " .. key)
			end
		end

		local pins = require_array(evidence, "route_exact_pins")
		local pin_key = {}
		for index = 1, #pins do
			local row = pins[index]
			integer_fields(row, {"run", "y", "baseline_y", "final_y"}, "route pin")
			if not route_by_id[row.path_id] or type(row.pin_kind) ~= "string" or
					type(row.source_id) ~= "string" or row.run < 1 or
					row.run > route_by_id[row.path_id].node_count or row.y ~= row.baseline_y or
					row.y ~= row.final_y then
				fail("exact route pin changed at " .. tostring(row.path_id))
			end
			local key = row.path_id .. ":" .. row.run
			if pin_key[key] then fail("duplicate exact route pin " .. key) end
			pin_key[key] = row
			pin_count_by_path[row.path_id] = (pin_count_by_path[row.path_id] or 0) + 1
		end
		local station_by_zone = {}
		for index = 1, #evidence.stations do
			station_by_zone[evidence.stations[index].zone_numeric_id] = evidence.stations[index]
		end
		local anchor_by_id = maps_by_id(evidence.anchors)
		local function exact_endpoint(path_id, run, kind, source_id, y)
			local pin = pin_key[path_id .. ":" .. run]
			if not pin or pin.pin_kind ~= kind or pin.source_id ~= source_id or pin.y ~= y then
				fail("route skeleton endpoint differs at " .. path_id .. ":" .. run)
			end
		end
		for index = 1, #source.routes do
			local path = source.routes[index]
			local row = assert(route_by_id[path.id])
			local station_a = assert(station_by_zone[path.zone_a])
			local station_b = assert(station_by_zone[path.zone_b])
			exact_endpoint(path.id, 1, "endpoint_a", source.zones[path.zone_a].id,
				station_a.hub_target_y)
			exact_endpoint(path.id, row.node_count, "endpoint_b",
				source.zones[path.zone_b].id, station_b.hub_target_y)
		end
		for index = 1, #source.poi_spurs do
			local path = source.poi_spurs[index]
			if path.anchor_id then
				local row = assert(route_by_id[path.id])
				local anchor = assert(anchor_by_id[path.anchor_id])
				local source_anchor
				for anchor_index = 1, #source.anchors do
					if source.anchors[anchor_index].id == path.anchor_id then
						source_anchor = source.anchors[anchor_index] break
					end
				end
				local station = assert(station_by_zone[source_anchor.zone_numeric_id])
				exact_endpoint(path.id, 1, "anchor_endpoint", path.anchor_id,
					anchor.reference_y)
				exact_endpoint(path.id, row.node_count, "station_endpoint",
					source.zones[source_anchor.zone_numeric_id].id, station.hub_target_y)
			end
		end
		local landing_at, fixed_anchor_at = {}, {}
		for index = 1, #source.island_landings do
			local landing = source.island_landings[index]
			landing_at[landing.position.x .. ":" .. landing.position.z] = landing
		end
		for index = 1, #source.anchors do
			local anchor = source.anchors[index]
			if anchor.position and (anchor.template_id == "dragon" or
					anchor.template_id == "apex_mine") then
				fixed_anchor_at[anchor.position.x .. ":" .. anchor.position.z] = anchor
			end
		end
		local function island_endpoint(path, point, run, owner)
			local key = point.x .. ":" .. point.z
			local landing = landing_at[key]
			if landing then
				exact_endpoint(path.id, run, "landing_endpoint", landing.id,
					common.WATER_LEVEL + 1)
				return
			end
			local anchor = fixed_anchor_at[key]
			if anchor then
				exact_endpoint(path.id, run, "island_anchor_endpoint", anchor.id,
					assert(anchor_by_id[anchor.id]).reference_y)
				return
			end
			exact_endpoint(path.id, run, "island_junction", source.zones[owner].id,
				assert(station_by_zone[owner]).zone_station_y)
		end
		for index = 1, #source.island_routes do
			local path = source.island_routes[index]
			local row = assert(route_by_id[path.id])
			local first_key = path.centreline[1].x .. ":" .. path.centreline[1].z
			local last_point = path.centreline[#path.centreline]
			local last_key = last_point.x .. ":" .. last_point.z
			local endpoint_source = landing_at[first_key] or fixed_anchor_at[first_key] or
				landing_at[last_key] or fixed_anchor_at[last_key]
			if not endpoint_source then
				fail("island route has no authoritative landing/anchor owner")
			end
			local owner = endpoint_source.zone_numeric_id
			island_endpoint(path, path.centreline[1], 1, owner)
			island_endpoint(path, last_point, row.node_count, owner)
		end

		local lower_bounds = require_array(evidence, "route_water_lower_bounds")
		local lower_key = {}
		for index = 1, #lower_bounds do
			local row = lower_bounds[index]
			integer_fields(row, {"run", "column_count", "lower_y", "witness_x",
				"witness_z"}, "route water lower bound")
			if not route_by_id[row.path_id] or row.run < 1 or
					row.run > route_by_id[row.path_id].node_count or row.column_count <= 0 or
					type(row.bound_kind) ~= "string" then
				fail("route water lower-bound row differs")
			end
			local key = row.path_id .. ":" .. row.run
			if lower_key[key] then fail("duplicate projected lower-bound run " .. key) end
			lower_key[key] = row
			local datum = clearance_at(session, row.witness_x, row.witness_z)
			local expected_lower
			if row.bound_kind == "ordinary_water" or row.bound_kind == "causeway" then
				expected_lower = datum + 1
			elseif row.bound_kind == "bridge_deck" then
				expected_lower = datum + 4
			elseif row.bound_kind == "ford" then
				expected_lower = datum - 1
			elseif row.bound_kind == "ford_approach" then
				expected_lower = row.lower_y
			else fail("unknown projected lower-bound kind " .. row.bound_kind) end
			if row.lower_y ~= expected_lower then
				fail("projected lower-bound witness differs at " .. key)
			end
			lower_count_by_path[row.path_id] =
				(lower_count_by_path[row.path_id] or 0) + 1
			lower_columns_by_path[row.path_id] =
				(lower_columns_by_path[row.path_id] or 0) + row.column_count
		end

		local raises = require_array(evidence, "route_raise_witnesses")
		local raise_key = {}
		for index = 1, #raises do
			local row = raises[index]
			integer_fields(row, {"run", "baseline_y", "final_y", "support_run",
				"support_lower_y", "support_x", "support_z"}, "route raise witness")
			local route = route_by_id[row.path_id]
			if not route or row.run < 1 or row.run > route.node_count or
					row.support_run < 1 or row.support_run > route.node_count or
					row.final_y <= row.baseline_y or
					row.final_y ~= row.support_lower_y - math.abs(row.run - row.support_run) or
					type(row.support_kind) ~= "string" then
				fail("non-minimal route-envelope witness at " .. tostring(row.path_id))
			end
			local support = lower_key[row.path_id .. ":" .. row.support_run]
			if not support or support.lower_y ~= row.support_lower_y or
					support.witness_x ~= row.support_x or support.witness_z ~= row.support_z or
					support.bound_kind ~= row.support_kind or
					support.interface_id ~= row.support_id then
				fail("route raise does not bind a projected support witness")
			end
			local key = row.path_id .. ":" .. row.run
			if raise_key[key] then fail("duplicate raised route run " .. key) end
			raise_key[key] = row
			raise_count_by_path[row.path_id] = (raise_count_by_path[row.path_id] or 0) + 1
		end
		for path_id, row in pairs(route_by_id) do
			if row.exact_pin_count ~= (pin_count_by_path[path_id] or 0) or
					row.water_lower_bound_run_count ~= (lower_count_by_path[path_id] or 0) or
					row.water_lower_bound_column_count ~=
						(lower_columns_by_path[path_id] or 0) or
					row.raised_run_count ~= (raise_count_by_path[path_id] or 0) then
				fail("route evidence totals differ at " .. path_id)
			end
		end
		for path_id, route in pairs(route_by_id) do
			local pin_runs = {}
			for run = 1, route.node_count do
				if pin_key[path_id .. ":" .. run] then pin_runs[#pin_runs + 1] = run end
			end
			if #pin_runs < 2 or pin_runs[1] ~= 1 or
					pin_runs[#pin_runs] ~= route.node_count then
				fail("route exact pins do not cover both endpoints at " .. path_id)
			end
			local baseline = {}
			for pin_index = 1, #pin_runs - 1 do
				local first_run, last_run = pin_runs[pin_index], pin_runs[pin_index + 1]
				local first = pin_key[path_id .. ":" .. first_run]
				local last = pin_key[path_id .. ":" .. last_run]
				if math.abs(last.y - first.y) > last_run - first_run then
					fail("infeasible exact-pin interval at " .. path_id)
				end
				for run = first_run, last_run do
					baseline[run] = first.y + common.round_half_away(
						(last.y - first.y) * (run - first_run), last_run - first_run)
				end
			end
			local final = {}
			for run = 1, route.node_count do
				local lower = lower_key[path_id .. ":" .. run]
				final[run] = math.max(baseline[run], lower and lower.lower_y or baseline[run])
			end
			for run = 2, route.node_count do
				final[run] = math.max(final[run], final[run - 1] - 1)
			end
			for run = route.node_count - 1, 1, -1 do
				final[run] = math.max(final[run], final[run + 1] - 1)
			end
			local baseline_min, baseline_max, final_min, final_max, maximum_step
			local expected_raises = 0
			for run = 1, route.node_count do
				baseline_min = baseline_min and math.min(baseline_min, baseline[run]) or baseline[run]
				baseline_max = baseline_max and math.max(baseline_max, baseline[run]) or baseline[run]
				final_min = final_min and math.min(final_min, final[run]) or final[run]
				final_max = final_max and math.max(final_max, final[run]) or final[run]
				if run > 1 then
					maximum_step = math.max(maximum_step or 0,
						math.abs(final[run] - final[run - 1]))
				end
				local pin = pin_key[path_id .. ":" .. run]
				if pin and (baseline[run] ~= pin.y or final[run] ~= pin.y) then
					fail("two-pass envelope changed an exact pin at " .. path_id)
				end
				local raised = raise_key[path_id .. ":" .. run]
				if final[run] > baseline[run] then
					expected_raises = expected_raises + 1
					if not raised or raised.baseline_y ~= baseline[run] or
							raised.final_y ~= final[run] then
						fail("two-pass envelope raise evidence differs at " .. path_id)
					end
				elseif raised then fail("unchanged route run reported as raised") end
			end
			if route.baseline_min_y ~= baseline_min or route.baseline_max_y ~= baseline_max or
					route.final_min_y ~= final_min or route.final_max_y ~= final_max or
					route.maximum_step ~= (maximum_step or 0) or maximum_step > 1 or
					route.raised_run_count ~= expected_raises then
				fail("exact minimal two-pass envelope aggregate differs at " .. path_id)
			end
		end

		local approaches = require_array(evidence, "ford_approaches")
		local approach_by_interface = {}
		for index = 1, #approaches do
			local row = approaches[index]
			integer_fields(row, {"run", "ford_run", "ford_pin_y", "distance",
				"uncapped_lower_y", "capped_lower_y", "witness_x", "witness_z"},
				"ford approach")
			local datum = clearance_at(session, row.witness_x, row.witness_z)
			if row.distance ~= math.abs(row.run - row.ford_run) or
					row.capped_lower_y ~= row.ford_pin_y + row.distance or
					row.uncapped_lower_y ~= datum + 1 or
					row.capped_lower_y >= row.uncapped_lower_y or
					type(row.interface_id) ~= "string" or
					type(row.hydrology_id) ~= "string" or
					not lower_key[row.path_id .. ":" .. row.run] or
					lower_key[row.path_id .. ":" .. row.run].bound_kind ~= "ford_approach" or
					lower_key[row.path_id .. ":" .. row.run].interface_id ~= row.interface_id then
				fail("ford-approach cap differs at " .. tostring(row.interface_id))
			end
			local kind, surface, feature, interface =
				session.functional_surface_values_at(row.witness_x, row.witness_z)
			if kind ~= "ford" or feature ~= row.path_id or
					interface ~= row.interface_id or surface < row.capped_lower_y or
					session.terrain_height_at(row.witness_x, row.witness_z) ~= surface then
				fail("ford-approach functional witness differs")
			end
			local rows = approach_by_interface[row.interface_id]
			if not rows then rows = {} approach_by_interface[row.interface_id] = rows end
			rows[#rows + 1] = row
		end
		local summaries = require_array(evidence, "ford_approach_summaries")
		local ford_source_count, ford_source_ids = 0, {}
		for index = 1, #source.crossing_interfaces do
			if source.crossing_interfaces[index].kind == "ford" then
				ford_source_count = ford_source_count + 1
				ford_source_ids[source.crossing_interfaces[index].id] = true
			end
		end
		if #summaries ~= ford_source_count then fail("ford summary count differs") end
		local summary_ids = {}
		for index = 1, #summaries do
			local row = summaries[index]
			if not ford_source_ids[row.interface_id] or summary_ids[row.interface_id] then
				fail("ford summary identity differs")
			end
			summary_ids[row.interface_id] = true
			integer_fields(row, {"ford_run", "ford_pin_y", "capped_run_count"},
				"ford approach summary")
			local rows = approach_by_interface[row.interface_id] or {}
			if row.capped_run_count ~= #rows then fail("ford cap count differs") end
			if #rows == 0 then
				if row.first_run ~= nil or row.last_run ~= nil or
						row.resume_before_run ~= nil or row.resume_after_run ~= nil then
					fail("empty ford cap carries run bounds")
				end
			else
				table.sort(rows, function(a, b) return a.run < b.run end)
				if row.first_run ~= rows[1].run or row.last_run ~= rows[#rows].run or
						row.resume_before_run ~= row.first_run - 1 or
						row.resume_after_run ~= row.last_run + 1 then
					fail("ford ordinary-water resumption differs")
				end
				local before = lower_key[row.path_id .. ":" .. row.resume_before_run]
				local after = lower_key[row.path_id .. ":" .. row.resume_after_run]
				if not before or before.bound_kind ~= "ordinary_water" or
						not after or after.bound_kind ~= "ordinary_water" then
					fail("ford cap does not resume at the first ordinary-water run")
				end
			end
		end

		local named_expected = {}
		local tunnel_expected = {}
		for index = 1, #source.crossing_interfaces do
			local crossing = source.crossing_interfaces[index]
			if crossing.kind == "tunnel" then tunnel_expected[#tunnel_expected + 1] = crossing
			else named_expected[#named_expected + 1] = crossing end
		end
		local named = require_array(evidence, "named_water_operations", #named_expected)
		require_id_coverage(named, named_expected, "named water operations")
		local kind_map = {bridge = "bridge_deck", causeway = "causeway", ford = "ford"}
		local expected_named_by_id = maps_by_id(named_expected)
		for index = 1, #named do
			local row = named[index]
			local expected = expected_named_by_id[row_id(row)]
			integer_fields(row, {"footprint_columns", "min_surface_y", "max_surface_y",
				"first_witness_x", "first_witness_z"}, "named water operation")
			if not expected or row.path_id ~= expected.route_id or
					row.kind ~= kind_map[expected.kind] or row.footprint_columns <= 0 or
					row.min_surface_y > row.max_surface_y then
				fail("named water operation differs at " .. tostring(row_id(row)))
			end
			local datum = clearance_at(session, row.first_witness_x,
				row.first_witness_z)
			local kind, surface, feature, interface =
				session.functional_surface_values_at(row.first_witness_x,
					row.first_witness_z)
			if kind ~= row.kind or feature ~= row.path_id or interface ~= row_id(row) or
					surface < row.min_surface_y or surface > row.max_surface_y then
				fail("named operation identity witness differs at " .. row_id(row))
			end
			if row.kind == "bridge_deck" then
				if surface < datum + 4 or session.terrain_height_at(row.first_witness_x,
						row.first_witness_z) == surface then
					fail("named bridge scalar semantics differ at " .. row_id(row))
				end
			elseif row.kind == "causeway" then
				if surface < datum + 1 or session.terrain_height_at(row.first_witness_x,
						row.first_witness_z) ~= surface then
					fail("named causeway scalar semantics differ at " .. row_id(row))
				end
			elseif session.terrain_height_at(row.first_witness_x,
					row.first_witness_z) ~= surface then
				fail("named ford scalar semantics differ at " .. row_id(row))
			end
			common.digest(row.classification_digest, "named operation classification")
		end
		for index = 1, #named_expected do
			local crossing = named_expected[index]
			if crossing.kind == "ford" then
				local found
				for pin_index = 1, #pins do
					local pin = pins[pin_index]
					if pin.source_id == crossing.id and pin.pin_kind == "ford_center" then
						if found then fail("duplicate ford-centre pin at " .. crossing.id) end
						found = pin
					end
				end
				local datum = clearance_at(session, crossing.position.x,
					crossing.position.z)
				if not found or found.path_id ~= crossing.route_id or found.y ~= datum - 1 then
					fail("ford-centre exact pin differs at " .. crossing.id)
				end
			end
		end

		local derived = require_array(evidence, "derived_water_runs")
		local derived_key = {}
		for index = 1, #derived do
			local row = derived[index]
			integer_fields(row, {"run", "causeway_columns", "bridge_columns"},
				"derived water run")
			if not route_by_id[row.path_id] or row.causeway_columns < 0 or
					row.bridge_columns < 0 or row.causeway_columns + row.bridge_columns <= 0 or
					row.interface_id ~= nil or row.id ~= nil then
				fail("derived water run identity/count differs")
			end
			local key = row.path_id .. ":" .. row.run
			if derived_key[key] then fail("duplicate derived water run " .. key) end
			derived_key[key] = true
			if row.causeway_columns > 0 then
				integer_fields(row, {"causeway_witness_x", "causeway_witness_z"},
					"derived causeway witness")
				local datum = clearance_at(session, row.causeway_witness_x,
					row.causeway_witness_z)
				local kind, surface, feature, interface =
					session.functional_surface_values_at(row.causeway_witness_x,
						row.causeway_witness_z)
				if kind ~= "causeway" or surface ~= datum + 1 or
						feature ~= row.path_id or interface ~= nil or
						session.terrain_height_at(row.causeway_witness_x,
							row.causeway_witness_z) ~= surface then
					fail("derived causeway scalar semantics differ")
				end
			end
			if row.bridge_columns > 0 then
				integer_fields(row, {"bridge_witness_x", "bridge_witness_z"},
					"derived bridge witness")
				local datum = clearance_at(session, row.bridge_witness_x,
					row.bridge_witness_z)
				local kind, surface, feature, interface =
					session.functional_surface_values_at(row.bridge_witness_x,
						row.bridge_witness_z)
				if kind ~= "bridge_deck" or surface <= datum + 1 or
						feature ~= row.path_id or interface ~= nil or
						session.terrain_height_at(row.bridge_witness_x,
							row.bridge_witness_z) == surface then
					fail("derived bridge non-scalar semantics differ")
				end
			end
			common.digest(row.classification_digest, "derived classification")
		end

		local landings = require_array(evidence, "landings", #source.island_landings)
		require_id_coverage(landings, source.island_landings, "landings")
		local source_landing_by_id = maps_by_id(source.island_landings)
		local source_boat_by_id = maps_by_id(source.boat_paths or {})
		local island_path_by_id = maps_by_id(source.island_routes)
		for index = 1, #landings do
			local row = landings[index]
			local source_landing = source_landing_by_id[row_id(row)]
			local boat = source_landing and source_boat_by_id[source_landing.boat_path_id]
			integer_fields(row, {"surface_y", "corridor_land_columns", "graded_columns",
				"water_columns_unchanged", "mainland_columns_unchanged", "witness_x",
				"witness_z"}, "landing")
			if not source_landing or not boat or boat.width ~= 96 or
					row.boat_path_id ~= boat.id or not island_path_by_id[row.route_id] or
					row.surface_y ~= common.WATER_LEVEL + 1 or
					row.corridor_land_columns <= 0 or
					row.graded_columns <= 0 or row.water_columns_unchanged <= 0 or
					row.mainland_columns_unchanged <= 0 or
					row.graded_columns > row.corridor_land_columns then
				fail("island landing grade evidence differs at " .. row.id)
			end
			local kind, surface, feature = session.functional_surface_values_at(
				row.witness_x, row.witness_z)
			if kind ~= "land_grade" or surface ~= row.surface_y or feature ~= row.id then
				fail("island landing witness differs at " .. row.id)
			end
			common.digest(row.classification_digest, "landing classification")
		end

		local tunnels = require_array(evidence, "tunnels", #tunnel_expected)
		require_id_coverage(tunnels, tunnel_expected, "tunnels")
		for index = 1, #tunnels do
			local row = tunnels[index]
			local expected_tunnel = maps_by_id(tunnel_expected)[row_id(row)]
			integer_fields(row, {"center_run", "first_run", "last_run", "axis_node_count",
				"footprint_columns", "interior_min", "interior_min_witness_x",
				"interior_min_witness_z", "baseline_y", "feasible_lower_y",
				"feasible_upper_y", "floor_y", "before_pin_run", "before_pin_y",
				"after_pin_run", "after_pin_y", "minimum_overburden",
				"overburden_witness_x", "overburden_witness_z",
				"named_overlap_columns", "tunnel_overlap_columns"}, "tunnel")
			local clamped_floor = math.max(row.feasible_lower_y,
				math.min(row.baseline_y, row.feasible_upper_y))
			if not expected_tunnel or row.path_id ~= expected_tunnel.route_id or
					row.axis_node_count ~= 33 or row.last_run - row.first_run ~= 32 or
					row.center_run - row.first_run ~= 16 or row.last_run - row.center_run ~= 16 or
					row.footprint_columns < 33 or row.feasible_lower_y > row.feasible_upper_y or
					row.floor_y ~= clamped_floor or
					row.feasible_upper_y > row.interior_min - 5 or
					row.minimum_overburden ~= row.interior_min - row.floor_y or
					row.minimum_overburden < 5 or row.before_pin_run >= row.first_run or
					row.after_pin_run <= row.last_run or
					math.abs(row.floor_y - row.before_pin_y) > row.first_run - row.before_pin_run or
					math.abs(row.floor_y - row.after_pin_y) > row.after_pin_run - row.last_run or
					row.named_overlap_columns ~= 0 or row.tunnel_overlap_columns ~= 0 then
				fail("central-33 tunnel construction differs at " .. row.interface_id)
			end
			if session.terrain_height_at(row.interior_min_witness_x,
					row.interior_min_witness_z) ~= row.interior_min or
					session.terrain_height_at(row.overburden_witness_x,
						row.overburden_witness_z) - row.floor_y < 5 then
				fail("tunnel overburden witness differs at " .. row.interface_id)
			end
			local tunnel_pins = {}
			for pin_index = 1, #pins do
				local pin = pins[pin_index]
				if pin.source_id == row.interface_id and
						(pin.pin_kind == "tunnel_first" or pin.pin_kind == "tunnel_last") then
					tunnel_pins[pin.pin_kind] = pin
				end
			end
			if not tunnel_pins.tunnel_first or not tunnel_pins.tunnel_last or
					tunnel_pins.tunnel_first.path_id ~= row.path_id or
					tunnel_pins.tunnel_last.path_id ~= row.path_id or
					tunnel_pins.tunnel_first.run ~= row.first_run or
					tunnel_pins.tunnel_last.run ~= row.last_run or
					tunnel_pins.tunnel_first.y ~= row.floor_y or
					tunnel_pins.tunnel_last.y ~= row.floor_y then
				fail("tunnel-end exact pins differ at " .. row.interface_id)
			end
			common.digest(row.classification_digest, "tunnel classification")
		end

		common.digest(evidence.visible_surface_classification_digest,
			"visible-surface classification digest")
		if type(evidence.operation_counts) ~= "table" then
			fail("deterministic operation counts missing")
		end
		for key, value in pairs(evidence.operation_counts) do
			if type(key) ~= "string" or type(value) ~= "number" or
					key:match("time") or key:match("cpu") or key:match("wall") or
					key:match("second") or key:match("duration") then
				fail("operation_counts must contain deterministic numeric counts only")
			end
			common.safe_integer(value, "operation count " .. key)
			if value < 0 then fail("negative operation count " .. key) end
		end
		common.digest(evidence.operation_digest, "operation digest")
		common.digest(evidence.route_digest, "route digest")
		local named_overlap = evidence.operation_counts.tunnel_named_operation_overlap_columns
		common.safe_integer(named_overlap, "tunnel/named-operation overlap columns")
		if named_overlap ~= 0 then fail("tunnel overlaps a named water operation") end
	end

	function validator.validate_evidence(session, source)
		method(session, "artifact_evidence")
		local first = session.artifact_evidence()
		if type(first) ~= "table" then fail("artifact_evidence did not return a table") end
		local original = normalized_evidence_bytes(first)
		first.__r3_mutation_probe = true
		if type(first.anchors) == "table" and type(first.anchors[1]) == "table" then
			first.anchors[1].__r3_mutation_probe = true
		end
		local evidence = session.artifact_evidence()
		if normalized_evidence_bytes(evidence) ~= original then
			fail("artifact_evidence is not a defensive copy")
		end
		if type(evidence.schema) ~= "string" or evidence.schema == "" then
			fail("artifact evidence schema missing")
		end
		if evidence.height_schema ~= nil and
				evidence.height_schema ~= common.HEIGHT_SCHEMA then
			fail("artifact evidence height schema differs")
		end
		common.digest(evidence.base_lattice_digest, "base lattice digest")
		local roots = require_array(evidence, "relief_roots", #source.relief_profiles)
		require_id_coverage(roots, source.relief_profiles, "relief roots")
		local octave_count = 0
		for index = 1, #source.relief_profiles do
			octave_count = octave_count + #source.relief_profiles[index].octaves
		end
		require_array(evidence, "octave_lattices", octave_count)
		local profiles = require_array(evidence, "primary_profiles",
			#source.relief_profiles)
		require_id_coverage(profiles, source.relief_profiles, "primary profiles")
		local source_profile_by_id = maps_by_id(source.relief_profiles)
		for index = 1, #profiles do
			local row = profiles[index]
			local source_profile = assert(source_profile_by_id[row_id(row)])
			for _, key in ipairs({"sample_count", "observed_min_y",
				"observed_min_count", "observed_min_witness_x",
				"observed_min_witness_z", "observed_max_y",
				"observed_max_count", "observed_max_witness_x",
				"observed_max_witness_z"}) do
				common.safe_integer(row[key], "primary profile " .. key)
			end
			if row.sample_count <= 0 or row.observed_min_count <= 0 or
					row.observed_max_count <= 0 or
					row.observed_min_count > row.sample_count or
					row.observed_max_count > row.sample_count or
					row.observed_min_y > row.observed_max_y or
					row.observed_min_y < common.WATER_LEVEL +
						source_profile.min_above_water or
					row.observed_max_y > common.WATER_LEVEL +
						source_profile.max_above_water then
				fail("primary profile observed extrema/counts differ at " .. row_id(row))
			end
		end
		local landmarks = require_array(evidence, "landmarks", #source.landmarks)
		require_id_coverage(landmarks, source.landmarks, "landmarks")
		for index = 1, #landmarks do
			local row = landmarks[index]
			for _, key in ipairs({"mask_columns", "collar_columns",
				"owner_escape_columns", "observed_min_y",
				"observed_min_witness_x", "observed_min_witness_z",
				"observed_max_y", "observed_max_witness_x",
				"observed_max_witness_z"}) do
				common.safe_integer(row[key], "landmark " .. key)
			end
			if row.mask_columns <= 0 or row.collar_columns <= 0 or
					row.owner_escape_columns ~= 0 or
					row.observed_min_y > row.observed_max_y then
				fail("landmark mask/owner/extrema evidence differs at " .. row_id(row))
			end
		end
		validate_station_anchor_evidence(session, source, evidence)
		local hard = require_array(evidence, "hard_protection",
			#source.hard_protection)
		require_id_coverage(hard, source.hard_protection, "hard protection")
		validate_route_operation_evidence(session, source, evidence)
		local hydrology = require_array(evidence, "hydrology", #source.hydrology)
		require_id_coverage(hydrology, source.hydrology, "hydrology")
		local interfaces = require_array(evidence, "interfaces",
			#source.hydrology_interfaces)
		require_id_coverage(interfaces, source.hydrology_interfaces, "interfaces")
		local exterior = require_array(evidence, "exterior_witnesses")
		local exterior_seen = {}
		for index = 1, #exterior do
			local row = exterior[index]
			integer_fields(row, {"x", "z", "terrain_y", "water_y"},
				"exterior witness")
			if exterior_seen[row.kind] or
					session.terrain_height_at(row.x, row.z) ~= row.terrain_y or
					session.water_surface_at(row.x, row.z) ~= row.water_y then
				fail("exterior witness differs at " .. tostring(row.kind))
			end
			exterior_seen[row.kind] = true
		end
		for _, kind in ipairs({"bay", "coastal_shelf", "deep_ocean",
				"immutable_dragon_channel"}) do
			if not exterior_seen[kind] then fail("exterior evidence misses " .. kind) end
		end
		local cores = require_array(evidence, "coastal_cores",
			#source.coastal_housing_cores)
		require_id_coverage(cores, source.coastal_housing_cores, "coastal cores")
		check_digest_fields(evidence, "artifact_evidence")
		check_zero_violation_fields(evidence, "artifact_evidence")
		return evidence
	end

	function validator.validate_api(session, raw_sha256)
		for _, name in ipairs({
			"terrain_height_at", "water_surface_at",
			"functional_surface_values_at", "hydrology_transition_values_at",
			"selected_anchor_3d_by_id", "hard_protection_volumes",
			"relief_lattice_digest", "canonical_kat", "canonical_kat_digest",
			"artifact_evidence", "metrics",
		}) do method(session, name) end
		common.digest(session.relief_lattice_digest(), "relief lattice digest")
		local kat = session.canonical_kat()
		if type(kat) ~= "string" then fail("canonical_kat did not return bytes") end
		local digest = common.digest(session.canonical_kat_digest(),
			"canonical KAT digest")
		if common.digest_hex(raw_sha256, kat) ~= digest then
			fail("canonical KAT bytes and digest differ")
		end
		local metrics = session.metrics()
		if type(metrics) ~= "table" then fail("metrics did not return a table") end
		common.safe_integer(metrics.query_sha256_calls, "query SHA-256 calls")
		common.safe_integer(metrics.query_lattice_constructions,
			"query lattice constructions")
		if metrics.query_sha256_calls ~= 0 then fail("height query used SHA-256") end
		if metrics.query_lattice_constructions ~= 0 then
			fail("height query constructed a lattice")
		end
		for key, value in pairs(metrics) do
			if type(key) ~= "string" or type(value) ~= "number" then
				fail("metrics must be a flat table of deterministic numeric counts")
			end
			if key:match("time") or key:match("cpu") or key:match("wall") or
					key:match("second") or key:match("duration") then
				fail("host/interpreter timings must not enter canonical metrics")
			end
			common.safe_integer(value, "metric " .. key)
		end
		metrics.query_sha256_calls = -1
		local second = session.metrics()
		if second.query_sha256_calls ~= 0 then fail("metrics is not a defensive copy") end
		return second
	end

	local function query_column(session, horizontal, x, z, reuse)
		common.safe_integer(x, "query x")
		common.safe_integer(z, "query z")
		local ground = session.terrain_height_at(x, z)
		common.safe_integer(ground, "terrain height")
		local water = session.water_surface_at(x, z)
		if water ~= nil then common.safe_integer(water, "water surface") end
		local kind, surface, feature_id, interface_id =
			session.functional_surface_values_at(x, z)
		if kind == nil then
			if surface ~= nil or feature_id ~= nil or interface_id ~= nil then
				fail("partial nil functional tuple")
			end
		else
			if not ALLOWED_FUNCTIONAL[kind] then fail("unknown functional kind " .. tostring(kind)) end
			common.safe_integer(surface, "functional surface")
			if type(feature_id) ~= "string" or feature_id == "" then
				fail("functional feature id missing")
			end
			if interface_id ~= nil and
					(type(interface_id) ~= "string" or interface_id == "") then
				fail("functional interface id differs")
			end
			if ((kind == "land_grade" or kind == "anchor_platform") and
					interface_id ~= nil) or
					((kind == "ford" or kind == "tunnel_floor") and
					interface_id == nil) then
				fail("functional interface identity differs for " .. kind)
			end
		end
		local transition, transition_id, upper, lower, progress =
			session.hydrology_transition_values_at(x, z)
		if transition == nil then
			if transition_id ~= nil or upper ~= nil or lower ~= nil or progress ~= nil then
				fail("partial nil hydrology-transition tuple")
			end
		else
			if not ALLOWED_TRANSITIONS[transition] then
				fail("unknown hydrology transition " .. tostring(transition))
			end
			if type(transition_id) ~= "string" or transition_id == "" then
				fail("hydrology transition id missing")
			end
			common.safe_integer(upper, "transition upper y")
			common.safe_integer(lower, "transition lower y")
			common.safe_integer(progress, "transition progress Q")
			if progress < 0 or progress > Q then fail("transition progress outside Q") end
		end
		local water_class, macro_region, zone_numeric_id, bay_id, hydrology_id,
			channel_id, fixed, civic_water = horizontal.classification_values_at(x, z)
		local row = reuse or {}
		local classification = row.classification or {}
		classification.water_class = water_class
		classification.macro_region = macro_region
		classification.zone_numeric_id = zone_numeric_id
		classification.bay_id = bay_id
		classification.hydrology_id = hydrology_id
		classification.channel_id = channel_id
		classification.fixed = fixed or nil
		classification.civic_water = civic_water or nil
		row.x, row.z, row.ground, row.water = x, z, ground, water
		row.kind, row.surface, row.feature_id = kind, surface, feature_id
		row.interface_id, row.transition = interface_id, transition
		row.transition_id, row.upper, row.lower = transition_id, upper, lower
		row.progress, row.classification = progress, classification
		return row
	end

	local function expected_shelf_depth(horizontal, x, z, shelf_width)
		local low, high = 1, shelf_width
		while low < high do
			local middle = math.floor((low + high) / 2)
			if horizontal.expanded_land_at(x, z, middle) then high = middle
			else low = middle + 1 end
		end
		return 1 + math.floor(7 * (low - 1) / 79)
	end

	local function check_column_rules(row, source, horizontal, hydro_by_id,
			profile_by_id, counts, anchor_reference_by_id, landing_ids)
		local class = row.classification.water_class
		counts[class] = (counts[class] or 0) + 1
		if class == "land" then
			if row.water ~= nil then fail("land column has a water surface") end
			if row.kind == "anchor_platform" then
				fail("anchor platform appeared on ordinary land")
			elseif row.kind == "land_grade" then
				if row.ground ~= row.surface then fail("solid functional surface differs from H") end
				if landing_ids and landing_ids[row.feature_id] and
						row.surface ~= common.WATER_LEVEL + 1 then
					fail("island landing grade is not water level + 1")
				end
			end
		elseif class == "planned_water" then
			if row.water == nil and row.transition ~= "waterfall" then
				fail("planned-water column has no scalar water or waterfall datum")
			end
			local reach = row.classification.hydrology_id and
				hydro_by_id[row.classification.hydrology_id] or nil
			local expected_bed
			if reach then
				local profile = assert(profile_by_id[reach.profile_id])
				local expected_water = common.WATER_LEVEL + reach.water_surface_offset
				if row.transition == nil and row.water ~= expected_water then
					fail("wet reach surface differs at " .. row.x .. "," .. row.z)
				end
				expected_bed = expected_water - profile.depth
			else
				if not row.classification.bay_id then fail("unidentified planned water") end
				if row.water ~= common.WATER_LEVEL then fail("bay surface differs") end
				expected_bed = common.WATER_LEVEL - 8
			end
			if row.kind == "causeway" then
				local clearance_y = row.water or math.max(row.upper, row.lower)
				if row.surface < clearance_y + 1 or
						(row.interface_id == nil and row.surface ~= clearance_y + 1) or
						row.ground ~= row.surface then
					fail("causeway output differs")
				end
			elseif row.kind == "ford" then
				if row.interface_id == nil or row.ground ~= row.surface then
					fail("ford output differs")
				end
			elseif row.kind == "bridge_deck" then
				local clearance_y = row.water or math.max(row.upper, row.lower)
				if (row.interface_id ~= nil and row.surface < clearance_y + 4) or
						(row.interface_id == nil and row.surface <= clearance_y + 1) then
					fail("bridge clearance/classification differs")
				end
				if row.transition == nil and row.ground ~= expected_bed then
					fail("bridge changed the water bed")
				end
			elseif row.kind == "anchor_platform" then
				local clearance_y = row.water or math.max(row.upper, row.lower)
				local reference_y = anchor_reference_by_id and
					anchor_reference_by_id[row.feature_id] or nil
				if not reference_y or
						row.surface ~= math.max(reference_y, clearance_y + 1) or
						row.ground ~= row.surface then
					fail("anchor platform is not dry")
				end
			elseif row.kind == "tunnel_floor" then
				fail("land-only tunnel entered planned water")
			elseif row.transition == nil and row.ground ~= expected_bed then
				fail("planned-water bed differs at " .. row.x .. "," .. row.z)
			end
		elseif class == "coastal_shelf" then
			if row.kind ~= nil then fail("functional grade entered coastal shelf") end
			if row.water ~= common.WATER_LEVEL then fail("shelf surface differs") end
			local depth = expected_shelf_depth(horizontal, row.x, row.z,
				source.shelf_width)
			if row.ground ~= common.WATER_LEVEL - depth then fail("shelf bed differs") end
		elseif class == "deep_ocean" or class == "immutable_dragon_channel" then
			if row.kind ~= nil then fail("functional grade entered forbidden exterior water") end
			if row.water ~= common.WATER_LEVEL or
					row.ground ~= common.WATER_LEVEL - 24 then
				fail(class .. " output differs")
			end
		else
			fail("unknown horizontal water class " .. tostring(class))
		end
	end

	local function selected_paths(source, horizontal)
		local result = {}
		for index = 1, #source.routes do
			local row = source.routes[index]
			result[#result + 1] = {id = row.id, points = row.centreline,
				surface_width = row.surface_width, corridor_width = row.corridor_width,
				kind = "land_route"}
		end
		local anchor_by_id = maps_by_id(source.anchors)
		local trail = {bandit_home = true, bandit_frontier = true,
			mirefolk = true, clash = true}
		for index = 1, #source.poi_spurs do
			local spur = source.poi_spurs[index]
			local anchor = assert(anchor_by_id[spur.anchor_id])
			local width = trail[anchor.template_id] and 8 or 12
			result[#result + 1] = {id = spur.id,
				points = spur.centreline,
				surface_width = width == 8 and 3 or 5, corridor_width = width,
				kind = "poi_spur"}
		end
		for index = 1, #source.island_routes do
			local row = source.island_routes[index]
			result[#result + 1] = {id = row.id, points = row.centreline,
				surface_width = 5, corridor_width = 12, kind = "island_route"}
		end
		return result
	end

	local function diagnosis_less(a, b)
		for index = 1, #DIAGNOSIS_SORT_FIELDS do
			local field = DIAGNOSIS_SORT_FIELDS[index]
			local left, right = tostring(a[field]), tostring(b[field])
			if left ~= right then return left < right end
		end
		return false
	end

	function validator.validate_baseline_axis_diagnosis(witnesses, source)
		if common.dense_count(witnesses, "baseline diagnosis witnesses") ~= 40 then
			fail("baseline diagnosis must contain exactly 40 witnesses")
		end
		local paths = selected_paths(source)
		if #paths ~= 139 then fail("baseline diagnosis path count differs") end
		local path_by_id, raster_by_id = {}, {}
		for index = 1, #paths do
			local path = paths[index]
			if path_by_id[path.id] then
				fail("baseline diagnosis has duplicate path " .. tostring(path.id))
			end
			path_by_id[path.id] = path
			raster_by_id[path.id] = common.raster_polyline(path.points)
		end
		local required = {}
		for index = 1, #DIAGNOSIS_FIELDS do
			required[DIAGNOSIS_FIELDS[index]] = true
		end
		local expected_pairs = {}
		for index = 1, #BASELINE_DIAGNOSIS_PAIRS do
			local pair = BASELINE_DIAGNOSIS_PAIRS[index]
			expected_pairs[pair[1] .. "\t" .. pair[2]] = true
		end
		local pair_counts, duplicate_keys = {}, {}
		local previous
		for index = 1, #witnesses do
			local row = witnesses[index]
			if type(row) ~= "table" then
				fail("baseline diagnosis witness is not a table")
			end
			local field_count = 0
			for key in pairs(row) do
				if not required[key] then
					fail("baseline diagnosis witness has unexpected field " ..
						tostring(key))
				end
				field_count = field_count + 1
			end
			if field_count ~= #DIAGNOSIS_FIELDS then
				fail("baseline diagnosis witness field count differs")
			end
			for field in pairs(required) do
				if row[field] == nil then
					fail("baseline diagnosis witness misses " .. field)
				end
			end
			if type(row.losing_path_id) ~= "string" or
					type(row.winner_path_id) ~= "string" or
					type(row.pair_a) ~= "string" or type(row.pair_b) ~= "string" or
					row.losing_path_id == "" or row.winner_path_id == "" or
					row.pair_a == "" or row.pair_b == "" then
				fail("baseline diagnosis path identity differs")
			end
			integer_fields(row, {"losing_run", "from_x", "from_z", "from_y",
				"to_x", "to_z", "to_y", "absolute_step", "winner_run",
				"winner_x", "winner_z"}, "baseline diagnosis")
			local losing = raster_by_id[row.losing_path_id]
			local winner = raster_by_id[row.winner_path_id]
			if not losing or not winner or row.losing_path_id == row.winner_path_id then
				fail("baseline diagnosis loser/winner identity differs")
			end
			if row.losing_run < 2 or row.losing_run > #losing then
				fail("baseline diagnosis losing run is outside the path")
			end
			local from, to = losing[row.losing_run - 1], losing[row.losing_run]
			if row.from_x ~= from.x or row.from_z ~= from.z or
					row.to_x ~= to.x or row.to_z ~= to.z or
					math.max(math.abs(row.to_x - row.from_x),
						math.abs(row.to_z - row.from_z)) ~= 1 then
				fail("baseline diagnosis losing adjacency differs")
			end
			if row.absolute_step ~= math.abs(row.to_y - row.from_y) or
					row.absolute_step <= 1 then
				fail("baseline diagnosis does not describe a final axis violation")
			end
			if row.winner_run < 1 or row.winner_run > #winner or
					row.winner_x ~= winner[row.winner_run].x or
					row.winner_z ~= winner[row.winner_run].z then
				fail("baseline diagnosis winner projection differs")
			end
			local pair_a, pair_b = row.losing_path_id, row.winner_path_id
			if pair_b < pair_a then pair_a, pair_b = pair_b, pair_a end
			if row.pair_a ~= pair_a or row.pair_b ~= pair_b or
					row.pair_a >= row.pair_b then
				fail("baseline diagnosis unordered pair differs")
			end
			local pair_key = row.pair_a .. "\t" .. row.pair_b
			if not expected_pairs[pair_key] then
				fail("baseline diagnosis pair is outside the closed authority: " ..
					row.pair_a .. " / " .. row.pair_b)
			end
			pair_counts[pair_key] = (pair_counts[pair_key] or 0) + 1
			local duplicate_values = {}
			for field_index = 1, #DIAGNOSIS_FIELDS do
				duplicate_values[field_index] = tostring(row[DIAGNOSIS_FIELDS[field_index]])
			end
			local duplicate_key = table.concat(duplicate_values, "\t")
			if duplicate_keys[duplicate_key] then
				fail("baseline diagnosis has a duplicate witness")
			end
			duplicate_keys[duplicate_key] = true
			if previous and diagnosis_less(row, previous) then
				fail("baseline diagnosis witnesses are not canonically sorted")
			end
			previous = row
		end
		local pair_rows = {}
		for index = 1, #BASELINE_DIAGNOSIS_PAIRS do
			local pair = BASELINE_DIAGNOSIS_PAIRS[index]
			local key = pair[1] .. "\t" .. pair[2]
			local count = pair_counts[key]
			if not count or count <= 0 then
				fail("baseline diagnosis misses required pair " .. pair[1] ..
					" / " .. pair[2])
			end
			pair_rows[index] = {pair_a = pair[1], pair_b = pair[2],
				witness_count = count}
		end
		local unique_pair_count = 0
		for _ in pairs(pair_counts) do unique_pair_count = unique_pair_count + 1 end
		if unique_pair_count ~= 14 then
			fail("baseline diagnosis must contain exactly 14 unique pairs")
		end
		return pair_rows
	end

	local function traversable_y(row)
		return row.kind and row.surface or row.ground
	end

	local function route_envelope_from_evidence(evidence, path_id, node_count)
		local pins, lower = {}, {}
		for index = 1, #evidence.route_exact_pins do
			local row = evidence.route_exact_pins[index]
			if row.path_id == path_id then pins[#pins + 1] = row end
		end
		for index = 1, #evidence.route_water_lower_bounds do
			local row = evidence.route_water_lower_bounds[index]
			if row.path_id == path_id then lower[row.run] = row.lower_y end
		end
		table.sort(pins, function(a, b) return a.run < b.run end)
		if #pins < 2 or pins[1].run ~= 1 or pins[#pins].run ~= node_count then
			fail("route envelope evidence lacks endpoint pins at " .. path_id)
		end
		local baseline = {}
		for index = 1, #pins - 1 do
			local a, b = pins[index], pins[index + 1]
			for run = a.run, b.run do
				baseline[run] = a.y + common.round_half_away(
					(b.y - a.y) * (run - a.run), b.run - a.run)
			end
		end
		local final = {}
		for run = 1, node_count do
			final[run] = math.max(baseline[run], lower[run] or baseline[run])
		end
		for run = 2, node_count do final[run] = math.max(final[run], final[run - 1] - 1) end
		for run = node_count - 1, 1, -1 do
			final[run] = math.max(final[run], final[run + 1] - 1)
		end
		return final
	end

	local function check_paths(session, horizontal, source, evidence,
			full_corridors, metrics)
		local paths = selected_paths(source, horizontal)
		local path_ids = {}
		for index = 1, #paths do path_ids[paths[index].id] = true end
		local function check_visible_land_identity(row, path_id)
			if row.classification.water_class ~= "land" then return end
			if row.kind == "tunnel_floor" then
				if not path_ids[row.feature_id] then fail("tunnel path identity differs") end
				return
			end
			if row.kind ~= "land_grade" then
				fail("visible land path lacks its scalar grade: " .. path_id)
			end
			if not path_ids[row.feature_id] then
				fail("non-path grade masks full-weight visible path: " .. path_id)
			end
		end
		metrics.route_summaries = {}
		for path_index = 1, #paths do
			local path = paths[path_index]
			local raster = common.raster_polyline(path.points)
			local expected_grade = route_envelope_from_evidence(evidence, path.id, #raster)
			local seen, previous_y, maximum_step = {}, nil, 0
			local start_y, end_y
			for index = 1, #raster do
				local point = raster[index]
				local key = point.x .. ":" .. point.z
				if seen[key] then fail("route raster repeats a non-join node: " .. path.id) end
				seen[key] = true
				local row = query_column(session, horizontal, point.x, point.z)
				check_visible_land_identity(row, path.id)
				local class = row.classification.water_class
				if class == "coastal_shelf" or class == "deep_ocean" or
						class == "immutable_dragon_channel" then
					fail("graded route enters forbidden water: " .. path.id)
				end
				if class == "planned_water" and row.kind ~= "causeway" and
						row.kind ~= "ford" and row.kind ~= "bridge_deck" then
					fail("route planned-water run has no local operation: " .. path.id)
				end
				if class == "planned_water" and not path_ids[row.feature_id] then
					fail("planned-water route operation has non-path feature identity")
				end
				local y = traversable_y(row)
				if y ~= expected_grade[index] then
					fail("final composed route differs from exact envelope: " .. path.id)
				end
				if previous_y then
					local step = math.abs(y - previous_y)
					maximum_step = math.max(maximum_step, step)
					if step > 1 then fail("route step exceeds one: " .. path.id) end
				end
				if index == 1 then start_y = y end
				if index == #raster then end_y = y end
				previous_y = y
				metrics.route_axis_nodes = metrics.route_axis_nodes + 1
			end
			if full_corridors then
				for segment = 1, #path.points - 1 do
					local a, b = path.points[segment], path.points[segment + 1]
					local segment_points = {a, b}
					local radius = math.floor(path.corridor_width / 2) + 1
					for z = math.min(a.z, b.z) - radius, math.max(a.z, b.z) + radius do
						for x = math.min(a.x, b.x) - radius, math.max(a.x, b.x) + radius do
							if horizontal.polyline_corridor_member(x, z, segment_points,
									path.corridor_width) then
								local row = query_column(session, horizontal, x, z)
								local visible = horizontal.polyline_corridor_member(x, z,
									segment_points, path.surface_width)
								if visible then check_visible_land_identity(row, path.id) end
								if visible and row.classification.water_class == "planned_water" and
									row.kind ~= "causeway" and row.kind ~= "ford" and
									row.kind ~= "bridge_deck" then
									fail("visible water crossing lacks an operation: " .. path.id)
								end
								if visible and row.classification.water_class == "planned_water" and
										not path_ids[row.feature_id] then
									fail("visible water operation has non-path feature identity")
								end
								metrics.route_corridor_visits = metrics.route_corridor_visits + 1
							end
						end
					end
				end
			end
			metrics.route_summaries[#metrics.route_summaries + 1] = {
				id = path.id, kind = path.kind, nodes = #raster,
				start_y = start_y, end_y = end_y, maximum_step = maximum_step,
			}
		end
		metrics.graded_paths = #paths
	end

	local function check_anchors(session, horizontal, source, metrics)
		local volumes = session.hard_protection_volumes()
		if common.dense_count(volumes, "hard protection volumes") ~=
				#source.hard_protection then fail("hard-protection count differs") end
		local by_id = maps_by_id(volumes)
		for index = 1, #source.hard_protection do
			local expected = source.hard_protection[index]
			local actual = by_id[expected.id]
			if not actual then fail("hard-protection volume missing " .. expected.id) end
			if actual.recipe_id ~= expected.recipe_id or actual.y_min ~= -700 or
					actual.upward_unbounded ~= true then
				fail("hard-protection policy differs for " .. expected.id)
			end
			if expected.center and (type(actual.center) ~= "table" or
					actual.center.x ~= expected.center.x or
					actual.center.z ~= expected.center.z) then
				fail("hard-protection centre differs for " .. expected.id)
			end
			if expected.ingress_id then
				if actual.surface_y ~= nil then fail("ingress collapsed to one surface y") end
			elseif actual.surface_y ~= nil then
				common.safe_integer(actual.surface_y, "hard-protection surface y")
				local centre = query_column(session, horizontal,
					expected.center.x, expected.center.z)
				if actual.surface_y ~= traversable_y(centre) then
					fail("hard-protection centre surface differs for " .. expected.id)
				end
			else
				fail("hard-protection centre surface missing for " .. expected.id)
			end
		end
		volumes[1].id = "mutation-probe"
		if session.hard_protection_volumes()[1].id == "mutation-probe" then
			fail("hard_protection_volumes is not a defensive copy")
		end
		for index = 1, #source.anchors do
			local expected = source.anchors[index]
			local two_d = assert(horizontal.selected_anchor_by_id(expected.id))
			local two_d_fields = {x = true, z = true, anchor_id = true,
				selection_mode = true, approved_candidate_index = true}
			local two_d_field_count = 0
			for key in pairs(two_d) do
				if not two_d_fields[key] then
					fail("2D anchor result has an unexpected field " .. tostring(key))
				end
				two_d_field_count = two_d_field_count + 1
			end
			if two_d_field_count ~= 5 or two_d.anchor_id ~= expected.id then
				fail("2D anchor result shape differs " .. expected.id)
			end
			local actual = session.selected_anchor_3d_by_id(expected.id)
			if type(actual) ~= "table" then fail("3D anchor missing " .. expected.id) end
			if actual.id ~= nil and actual.id ~= expected.id then fail("3D anchor id differs") end
			if actual.anchor_id ~= nil and actual.anchor_id ~= expected.id then
				fail("3D anchor anchor_id differs")
			end
			if actual.x ~= two_d.x or actual.z ~= two_d.z or
					actual.selection_mode ~= two_d.selection_mode or
					actual.approved_candidate_index ~=
						two_d.approved_candidate_index then
				fail("3D anchor moved or reselected " .. expected.id)
			end
			common.safe_integer(actual.y, "anchor y")
			local centre = query_column(session, horizontal, two_d.x, two_d.z)
			if actual.y ~= traversable_y(centre) then
				fail("anchor y differs from its resolved surface " .. expected.id)
			end
			if actual.ground_y ~= nil then
				common.safe_integer(actual.ground_y, "anchor ground y")
				if actual.ground_y ~= session.terrain_height_at(two_d.x, two_d.z) then
					fail("anchor ground y differs from H " .. expected.id)
				end
			end
			local expected_selection_mode =
				expected.placement_mode == "authored_fixed" and
				"authored_fixed" or "frozen_layout"
			if actual.selection_mode ~= expected_selection_mode or
					actual.approved_candidate_index ~=
						expected.approved_candidate_index then
				fail("anchor selection provenance differs " .. expected.id)
			end
			actual.x = actual.x + 1
			if session.selected_anchor_3d_by_id(expected.id).x ~= two_d.x then
				fail("selected_anchor_3d_by_id is not a defensive copy")
			end
		end
		metrics.anchors = #source.anchors
		metrics.hard_protection_volumes = #source.hard_protection
	end

	local function check_interfaces(session, horizontal, source, metrics)
		local crossing_kind = {
			bridge = "bridge_deck", ford = "ford", causeway = "causeway",
			tunnel = "tunnel_floor",
		}
		for index = 1, #source.crossing_interfaces do
			local interface = source.crossing_interfaces[index]
			local row = query_column(session, horizontal,
				interface.position.x, interface.position.z)
			if row.kind ~= crossing_kind[interface.kind] or
					row.interface_id ~= interface.id or row.feature_id ~= interface.route_id then
				fail("crossing kind differs at " .. interface.id)
			end
		end
		for index = 1, #source.hydrology_interfaces do
			local interface = source.hydrology_interfaces[index]
			local row = query_column(session, horizontal,
				interface.position.x, interface.position.z)
			if interface.kind == "rapid" or interface.kind == "waterfall" then
				if row.transition ~= interface.kind or
						row.transition_id ~= interface.id then
					fail("hydrology transition identity differs at " .. interface.id)
				end
				if row.upper ~= common.WATER_LEVEL + interface.upper_level_offset or
						row.lower ~= common.WATER_LEVEL + interface.lower_level_offset or
						row.upper - row.lower ~= interface.drop then
					fail("hydrology transition levels differ at " .. interface.id)
				end
			end
		end
		metrics.crossing_interfaces = #source.crossing_interfaces
		metrics.hydrology_interfaces = #source.hydrology_interfaces
	end

	local function check_dry_channel(session, horizontal, source, metrics)
		local profiles = maps_by_id(source.hydrology_profiles)
		local found = 0
		for index = 1, #source.hydrology do
			local reach = source.hydrology[index]
			if profiles[reach.profile_id].depth == 0 then
				local raster = common.raster_polyline(reach.centreline)
				local exact = common.WATER_LEVEL + reach.water_surface_offset
				local exact_witness = false
				for point_index = 1, #raster do
					local point = raster[point_index]
					local row = query_column(session, horizontal, point.x, point.z)
					if row.water ~= nil then fail("dry channel returned a water surface") end
					if row.classification.water_class ~= "land" then
						fail("dry channel changed horizontal water class")
					end
					if row.kind == nil and row.ground == exact then exact_witness = true end
				end
				if not exact_witness then fail("dry channel has no ungraded datum witness") end
				found = found + 1
			end
		end
		if found == 0 then fail("source has no dry channel") end
		metrics.dry_channels = found
	end

	local function core_bounds(source, core)
		local landmarks = maps_by_id(source.landmarks)
		local landmark = assert(landmarks[core.landmark_id])
		return landmark.center.x - landmark.radius_x,
			landmark.center.x + landmark.radius_x - 1,
			landmark.center.z - landmark.radius_z,
			landmark.center.z + landmark.radius_z - 1
	end

	local function check_coastal_cores(session, horizontal, source, r2, metrics)
		metrics.coastal_cores = {}
		for index = 1, #source.coastal_housing_cores do
			local core = source.coastal_housing_cores[index]
			local min_x, max_x, min_z, max_z = core_bounds(source, core)
			local minimum, maximum, count
			for z = min_z, max_z do
				for x = min_x, max_x do
					if horizontal.coastal_core_member(core.id, x, z) then
						local row = query_column(session, horizontal, x, z)
						if row.classification.water_class ~= "land" or
								row.classification.zone_numeric_id ~= core.zone_numeric_id then
							fail("coastal core escaped dry owner: " .. core.id)
						end
						minimum = minimum and math.min(minimum, row.ground) or row.ground
						maximum = maximum and math.max(maximum, row.ground) or row.ground
						count = (count or 0) + 1
					end
				end
			end
			if not count or maximum - minimum > core.relief_max then
				fail("coastal-core relief exceeds contract: " .. core.id)
			end
			local reservations = r2.coastal_reservation_counts[core.id]
			if type(reservations) ~= "number" or reservations <= 0 then
				fail("accepted R2 reservation count missing for " .. core.id)
			end
			metrics.coastal_cores[#metrics.coastal_cores + 1] = {
				id = core.id, columns = count, minimum = minimum, maximum = maximum,
				range = maximum - minimum, reservations = reservations,
			}
		end
	end

	local function check_outside(session, horizontal, source, counts)
		local warp = horizontal.warp_proof()
		local points = {
			{warp.min_x - 1, warp.min_z}, {warp.max_x + 1, warp.max_z},
			{warp.min_x, warp.min_z - 1}, {warp.max_x, warp.max_z + 1},
		}
		for index = 1, #points do
			local row = query_column(session, horizontal, points[index][1], points[index][2])
			check_column_rules(row, source, horizontal, {}, {}, counts)
			if row.classification.zone_numeric_id ~= nil or
					row.classification.water_class ~= "deep_ocean" then
				fail("outside-bounds query is not fixed deep ocean")
			end
		end
	end

	local function representative_points(source, horizontal, evidence)
		local points, seen = {}, {}
		local function add(x, z, label)
			if type(x) ~= "number" or type(z) ~= "number" then return end
			local key = x .. ":" .. z
			if not seen[key] then
				seen[key] = true
				points[#points + 1] = {x = x, z = z, label = label}
			end
		end
		for _, pair in ipairs({{-64, -64}, {-63, -63}, {-1, -1}, {0, 0},
			{1, 1}, {63, 63}, {64, 64}, {-769, 257}}) do add(pair[1], pair[2], "lattice") end
		local profile_seen = {}
		for index = 1, #source.zones do
			local zone = source.zones[index]
			if not profile_seen[zone.primary_relief_id] then
				profile_seen[zone.primary_relief_id] = true
				add(zone.hub.x, zone.hub.z, "profile:" .. zone.primary_relief_id)
			end
		end
		for profile_index = 1, #source.relief_profiles do
			local profile = source.relief_profiles[profile_index]
			for octave_index = 1, #profile.octaves do
				local period = profile.octaves[octave_index].period
				add(-period, 0, "octave-corner:" .. profile.id .. ":" .. octave_index)
				add(-period + math.floor(period / 2), math.floor(period / 3),
					"octave-interior:" .. profile.id .. ":" .. octave_index)
			end
		end
		local primitive_seen = {}
		for index = 1, #source.landmarks do
			local row = source.landmarks[index]
			if not primitive_seen[row.primitive] then
				primitive_seen[row.primitive] = true
				add(row.center.x, row.center.z, "mask:" .. row.primitive)
				add(row.center.x + row.radius_x - 1, row.center.z,
					"mask-edge:" .. row.primitive)
				add(row.center.x + row.radius_x + 32, row.center.z,
					"mask-collar:" .. row.primitive)
			end
		end
		for index = 1, #source.hydrology do
			local point = source.hydrology[index].centreline[1]
			add(point.x, point.z, "hydrology:" .. source.hydrology[index].id)
		end
		for index = 1, #source.hydrology_interfaces do
			local row = source.hydrology_interfaces[index]
			add(row.position.x, row.position.z, "interface:" .. row.id)
		end
		for index = 1, #source.crossing_interfaces do
			local row = source.crossing_interfaces[index]
			add(row.position.x, row.position.z, "crossing:" .. row.id)
		end
		for index = 1, #source.anchors do
			local selected = horizontal.selected_anchor_by_id(source.anchors[index].id)
			add(selected.x, selected.z, "anchor:" .. source.anchors[index].id)
		end
		for _, family in ipairs({"exterior_witnesses", "stations", "anchors",
				"routes", "route_exact_pins", "route_water_lower_bounds",
				"route_raise_witnesses", "ford_approaches",
				"named_water_operations", "derived_water_runs", "landings",
				"tunnels", "hydrology", "interfaces", "landmarks", "coastal_cores"}) do
			local rows = evidence[family] or {}
			for index = 1, #rows do
				local row = rows[index]
				add(row.x or row.witness_x, row.z or row.witness_z,
					family .. ":" .. tostring(row_id(row) or index))
				local keys = common.sorted_keys(row)
				for key_index = 1, #keys do
					local key = keys[key_index]
					if type(key) == "string" and key:match("_x$") then
						local prefix = key:sub(1, #key - 2)
						add(row[key], row[prefix .. "_z"], family .. ":" ..
							tostring(row_id(row) or index) .. ":" .. prefix)
					end
				end
			end
		end
		return points
	end

	function validator.targeted_rows(session, horizontal, source, evidence)
		local rows, coverage = {}, {functional = {}, transition = {}, class = {}}
		local points = representative_points(source, horizontal, evidence)
		for index = 1, #points do
			local point = points[index]
			local row = query_column(session, horizontal, point.x, point.z)
			coverage.class[row.classification.water_class] = true
			if row.kind then coverage.functional[row.kind] = true end
			if row.transition then coverage.transition[row.transition] = true end
			rows[#rows + 1] = {
				point.label, point.x, point.z, row.classification.water_class,
				row.classification.zone_numeric_id, row.classification.bay_id,
				row.classification.hydrology_id, row.classification.channel_id,
				row.ground, row.water, row.kind, row.surface, row.feature_id,
				row.interface_id, row.transition, row.transition_id,
				row.upper, row.lower, row.progress,
			}
		end
		return rows, coverage
	end

	function validator.assert_targeted_coverage(coverage)
		for kind in pairs(ALLOWED_FUNCTIONAL) do
			if not coverage.functional[kind] then fail("targeted KAT misses " .. kind) end
		end
		for kind in pairs(ALLOWED_TRANSITIONS) do
			if not coverage.transition[kind] then fail("targeted KAT misses " .. kind) end
		end
		for _, class in ipairs({"land", "planned_water", "coastal_shelf",
			"deep_ocean", "immutable_dragon_channel"}) do
			if not coverage.class[class] then fail("targeted KAT misses " .. class) end
		end
	end

	function validator.run(session, horizontal, source, r2, evidence, mode, progress)
		if mode ~= "quick" and mode ~= "full" then fail("unknown validation mode") end
		local metrics = {
			columns = 0, route_axis_nodes = 0, route_corridor_visits = 0,
			graded_paths = 0, class_counts = {},
		}
		local profile_by_id = maps_by_id(source.hydrology_profiles)
		local hydro_by_id = maps_by_id(source.hydrology)
		local anchor_reference_by_id = {}
		for index = 1, #evidence.anchors do
			anchor_reference_by_id[row_id(evidence.anchors[index])] =
				evidence.anchors[index].reference_y
		end
		local landing_ids = {}
		for index = 1, #source.island_landings do
			landing_ids[source.island_landings[index].id] = true
		end
		local function check_contact(id, water, transition, other_id, other_water,
				other_transition, x, z)
			if id and other_id and id ~= other_id and water and other_water and
					water ~= other_water and not transition and not other_transition then
				fail("unequal-level adjacent reaches lack an interface at " .. x ..
					"," .. z)
			end
		end
		if mode == "full" then
			local warp = horizontal.warp_proof()
			local above_hydrology, above_water, above_transition = {}, {}, {}
			local query_reuse = {classification = {}}
			for z = warp.min_z, warp.max_z do
				local left_hydrology, left_water, left_transition
				for x = warp.min_x, warp.max_x do
					local row = query_column(session, horizontal, x, z, query_reuse)
					check_column_rules(row, source, horizontal, hydro_by_id,
						profile_by_id, metrics.class_counts, anchor_reference_by_id,
						landing_ids)
					local offset = x - warp.min_x + 1
					local hydrology_id = row.classification.hydrology_id
					check_contact(hydrology_id, row.water, row.transition,
						left_hydrology, left_water, left_transition, x, z)
					check_contact(hydrology_id, row.water, row.transition,
						above_hydrology[offset], above_water[offset],
						above_transition[offset], x, z)
					left_hydrology, left_water, left_transition = hydrology_id,
						row.water, row.transition
					above_hydrology[offset], above_water[offset],
						above_transition[offset] = hydrology_id, row.water, row.transition
					metrics.columns = metrics.columns + 1
				end
				if progress and (z - warp.min_z) % 128 == 0 then
					progress("extent", z - warp.min_z, warp.max_z - warp.min_z + 1)
				end
			end
		else
			local points = representative_points(source, horizontal, evidence)
			for index = 1, #points do
				local point = points[index]
				local row = query_column(session, horizontal, point.x, point.z)
				check_column_rules(row, source, horizontal, hydro_by_id,
					profile_by_id, metrics.class_counts, anchor_reference_by_id,
					landing_ids)
				metrics.columns = metrics.columns + 1
			end
		end
		check_outside(session, horizontal, source, metrics.class_counts)
		check_anchors(session, horizontal, source, metrics)
		check_interfaces(session, horizontal, source, metrics)
		check_dry_channel(session, horizontal, source, metrics)
		check_paths(session, horizontal, source, evidence, mode == "full", metrics)
		check_coastal_cores(session, horizontal, source, r2, metrics)
		local after = session.metrics()
		if after.query_sha256_calls ~= 0 or after.query_lattice_constructions ~= 0 then
			fail("query-time construction counters changed during validation")
		end
		return metrics
	end

	function validator.deterministic_evidence_projection(evidence)
		local result = {
			schema = evidence.schema,
			height_schema = evidence.height_schema,
			base_lattice_digest = evidence.base_lattice_digest,
			relief_lattice_digest = evidence.relief_lattice_digest,
			octave_lattice_digest = evidence.octave_lattice_digest,
			relief_roots = exact_copy(evidence.relief_roots),
			octave_lattices = exact_copy(evidence.octave_lattices),
			primary_profiles = exact_copy(evidence.primary_profiles),
			landmarks = exact_copy(evidence.landmarks),
			stations = exact_copy(evidence.stations),
			anchors = exact_copy(evidence.anchors),
			hard_protection = exact_copy(evidence.hard_protection),
			routes = exact_copy(evidence.routes),
			route_exact_pins = exact_copy(evidence.route_exact_pins),
			route_water_lower_bounds = exact_copy(evidence.route_water_lower_bounds),
			route_raise_witnesses = exact_copy(evidence.route_raise_witnesses),
			ford_approaches = exact_copy(evidence.ford_approaches),
			ford_approach_summaries = exact_copy(evidence.ford_approach_summaries),
			named_water_operations = exact_copy(evidence.named_water_operations),
			derived_water_runs = exact_copy(evidence.derived_water_runs),
			landings = exact_copy(evidence.landings),
			tunnels = exact_copy(evidence.tunnels),
			visible_surface_classification_digest =
				evidence.visible_surface_classification_digest,
			hydrology = exact_copy(evidence.hydrology),
			interfaces = exact_copy(evidence.interfaces),
			exterior_witnesses = exact_copy(evidence.exterior_witnesses),
			coastal_cores = exact_copy(evidence.coastal_cores),
			source_cut_fill_limits_consumed =
				evidence.source_cut_fill_limits_consumed,
			operation_counts = exact_copy(evidence.operation_counts),
			operation_digest = evidence.operation_digest,
			route_digest = evidence.route_digest,
		}
		return result
	end

	return validator
end
