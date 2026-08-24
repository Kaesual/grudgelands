-- Shared, tools-only orchestration for the pre-C-a2 WP40 CB-1 campaign.
-- Geometry and deterministic arithmetic stay owned by the accepted modules.

local function fail(message)
	error("WP40 CB-1: " .. message, 0)
end

return function(repo, scratch)
	if type(repo) ~= "string" or type(scratch) ~= "string" then
		fail("repository root and scratch directory are required")
	end
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local canonical = dofile(wp40 .. "/canonical.lua")
	local deterministic = dofile(wp40 .. "/deterministic.lua")
	local exact = dofile(wp40 .. "/geometry/exact.lua")({
		deterministic = deterministic,
	})
	local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
		repo = repo,
		scratch = scratch,
	})
	local dependencies = {canonical = canonical, deterministic = deterministic,
		exact = exact, raw_sha256 = hasher.raw_sha256}
	local raster = dofile(wp40 .. "/geometry/raster.lua")(dependencies)
	local relief = dofile(wp40 .. "/geometry/relief.lua")(dependencies)
	local source = dofile(wp40 .. "/source/catalog.lua")
	local common = {repo = repo, source = source, canonical = canonical,
		deterministic = deterministic, exact = exact, raster = raster,
		relief = relief, hasher = hasher, water_level = 1}

	local winner_gate = dofile(repo ..
		"/tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua")
	local expected_indices = {2192, 1713, 1047, 3438}
	local expected_seeds = {"5270046902118333881", "16178445837170081103",
		"15219119262482319357", "17842018860885445630"}
	common.seeds, common.winner_indices = {"0"}, {0}
	for index = 1, 4 do
		local winner = assert(winner_gate.winners[index], "winner gate is incomplete")
		if winner.candidate_index ~= expected_indices[index] or
				winner.decimal ~= expected_seeds[index] then
			fail("accepted winner pin moved at winner row " .. index)
		end
		common.seeds[#common.seeds + 1] = winner.decimal
		common.winner_indices[#common.winner_indices + 1] = winner.candidate_index
	end

	local function index_by_id(rows, label)
		local result = {}
		for index = 1, #rows do
			local row = rows[index]
			if result[row.id] then fail("duplicate " .. label .. " " .. row.id) end
			result[row.id] = row
		end
		return result
	end

	common.zone_by_id = index_by_id(source.zones, "zone")
	common.profile_by_id = index_by_id(source.relief_profiles, "relief profile")
	common.class_by_id = index_by_id(source.route_classes, "route class")
	common.edge_by_id = index_by_id(source.land_edges, "land edge")
	common.hydrology_by_id = index_by_id(source.hydrology, "hydrology reach")
	common.hydro_profile_by_id = index_by_id(source.hydrology_profiles,
		"hydrology profile")
	common.landmark_by_id = index_by_id(source.landmarks, "landmark")
	common.island_zone_by_id = {}
	for index = 1, #source.island_landings do
		local landing = source.island_landings[index]
		local previous = common.island_zone_by_id[landing.island_id]
		if previous and previous ~= landing.zone_id then
			fail("island landings disagree on zone for " .. landing.island_id)
		end
		common.island_zone_by_id[landing.island_id] = landing.zone_id
	end
	-- Design authority world_zones.md section 8.4: the Copperfell drainage
	-- descends from inland spurs toward the west coast. The measured result is
	-- derived from Source endpoint order and roles, never from a reach id.
	common.flow_expectation_by_zone = {
		elandor_copperfell_foothills = {axis = "x", sign = -1,
			from_role = "spring", to_role = "sink",
			authority = "world_zones_8_4_inland_spurs_to_west_coast"},
	}

	common.landmarks_by_zone = {}
	for index = 1, #source.landmarks do
		local row = source.landmarks[index]
		local list = common.landmarks_by_zone[row.zone_id]
		if not list then list = {} common.landmarks_by_zone[row.zone_id] = list end
		list[#list + 1] = row.id
	end

	function common.route_stations(route)
		return raster.authored_stations(route.centreline, false)
	end

	function common.station_index(stations, point)
		local found
		for index = 1, #stations do
			if stations[index].x == point.x and stations[index].z == point.z then
				if found then fail("station occurs twice") end
				found = index
			end
		end
		if not found then fail("authored point is absent from route raster") end
		return found
	end

	function common.mainland_flat_deltas(route, stations)
		local blocked = {}
		local indices = {1, common.station_index(stations,
			route.centreline[route.crossing_station]), #stations}
		for interface_index = 1, #indices do
			local center = indices[interface_index]
			for delta_index = math.max(2, center - 11),
					math.min(#stations, center + 11) do
				blocked[delta_index] = true
			end
		end
		return blocked, indices
	end

	function common.island_flat_deltas(stations, variant)
		local blocked = {}
		for delta_index = 2, math.min(#stations, 8) do
			blocked[delta_index] = true
		end
		local first = variant == "literal_contract" and #stations - 7 or
			#stations - 6
		for delta_index = math.max(2, first), #stations do
			blocked[delta_index] = true
		end
		return blocked, {1, #stations}
	end

	function common.transition_capacity(first_delta, last_delta, blocked,
			minimum_run)
		local count, previous = 0
		for delta_index = first_delta, last_delta do
			if not blocked[delta_index] and
					(previous == nil or delta_index - previous >= minimum_run) then
				count = count + 1
				previous = delta_index
			end
		end
		return count
	end

	local sessions = {}
	function common.relief_session(seed)
		local session = sessions[seed]
		if not session then
			session = relief.new(source, seed, common.water_level,
				{sha_cache_capacity = 4096})
			sessions[seed] = session
		end
		return session
	end

	function common.heights(seed, zone_id, x, z)
		local zone = assert(common.zone_by_id[zone_id], "unknown zone")
		local session = common.relief_session(seed)
		local raw = session.raw_height(zone.primary_relief_id, x, z)
		local all_landmarks = session.compose_landmarks(raw, x, z)
		local selected = common.landmarks_by_zone[zone_id] or {}
		local authored_zone = session.compose_landmarks(raw, x, z, selected)
		return raw, all_landmarks, authored_zone
	end

	local function cell(value)
		if value == nil then return "" end
		if value == true then return "true" end
		if value == false then return "false" end
		local text = tostring(value)
		if text:find("[\t\r\n]") then fail("TSV cell contains control byte") end
		return text
	end

	function common.write_tsv(path, header, rows)
		local lines = {table.concat(header, "\t")}
		for row_index = 1, #rows do
			local values = {}
			for column_index = 1, #header do
				values[column_index] = cell(rows[row_index][header[column_index]])
			end
			lines[#lines + 1] = table.concat(values, "\t")
		end
		local file = assert(io.open(path, "wb"))
		assert(file:write(table.concat(lines, "\n"), "\n"))
		assert(file:close())
	end

	function common.point_key(point)
		return point.x .. ":" .. point.z
	end

	function common.point_on_polyline(point, controls)
		for index = 1, #controls - 1 do
			if exact.point_on_segment(point.x, point.z, controls[index],
					controls[index + 1]) then return true end
		end
		return false
	end

	local function orientation(a, b, c)
		local abx, abz = exact.vector(a, b, "CB-1 orientation segment")
		local acx, acz = exact.vector(a, c, "CB-1 orientation query")
		local value = exact.cross(abx, abz, acx, acz,
			"CB-1 orientation determinant")
		if value < 0 then return -1 end
		if value > 0 then return 1 end
		return 0
	end

	function common.segments_intersect(a, b, c, d)
		local ab_c, ab_d = orientation(a, b, c), orientation(a, b, d)
		local cd_a, cd_b = orientation(c, d, a), orientation(c, d, b)
		if ab_c == 0 and exact.point_on_segment(c.x, c.z, a, b) then return true end
		if ab_d == 0 and exact.point_on_segment(d.x, d.z, a, b) then return true end
		if cd_a == 0 and exact.point_on_segment(a.x, a.z, c, d) then return true end
		if cd_b == 0 and exact.point_on_segment(b.x, b.z, c, d) then return true end
		return ab_c ~= ab_d and cd_a ~= cd_b
	end

	function common.polyline_intersection_count(first, second)
		local count = 0
		for first_index = 1, #first - 1 do
			for second_index = 1, #second - 1 do
				if common.segments_intersect(first[first_index], first[first_index + 1],
						second[second_index], second[second_index + 1]) then
					count = count + 1
				end
			end
		end
		return count
	end

	function common.reach_segment_at(point, centreline)
		for index = 1, #centreline - 1 do
			local a, b = centreline[index], centreline[index + 1]
			if exact.point_on_segment(point.x, point.z, a, b) then
				local dx, dz = exact.vector(a, b, "CB-1 reach segment")
				local px = exact.safe_difference(point.x, a.x,
					"CB-1 reach projection")
				local pz = exact.safe_difference(point.z, a.z,
					"CB-1 reach projection")
				local length = exact.safe_sum(exact.safe_square(dx,
					"CB-1 reach length"), exact.safe_square(dz,
					"CB-1 reach length"), "CB-1 reach length")
				local projection = exact.dot(px, pz, dx, dz,
					"CB-1 reach projection")
				local fraction_q = deterministic.qdiv(projection, length)
				local width = deterministic.qlerp(a.half_width, b.half_width,
					fraction_q)
				return index, width
			end
		end
		return nil
	end

	function common.file_sha256(path)
		return canonical.hex(hasher.raw_sha256_file(path))
	end

	function common.close()
		hasher.close()
	end

	return common
end
