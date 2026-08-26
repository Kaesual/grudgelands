-- Exact selected-path surface contact evidence for the WP40 V1e R2 refresh.
-- Geometry membership stays owned by the production simple-map session.

return function(source, session, baseline_pairs)
	local result = {
		schema = "grug_wp40_simple_map_r2_contacts_v1",
		ok = true,
		violations = {},
		metrics = {},
		contacts = {},
	}
	local function violation(code, subject, expected, observed)
		result.ok = false
		result.violations[#result.violations + 1] = {
			code = code, subject = subject, expected = expected, observed = observed,
		}
	end
	local function copy_points(points, subject)
		if type(points) ~= "table" or #points < 2 then
			violation("path_centreline", subject, "at least two points", "invalid")
			return nil
		end
		local copied = {}
		for index = 1, #points do
			local point = points[index]
			if type(point) ~= "table" or type(point.x) ~= "number" or
					point.x % 1 ~= 0 or type(point.z) ~= "number" or
					point.z % 1 ~= 0 then
				violation("path_point", subject, "integer x/z", index)
				return nil
			end
			copied[index] = {x = point.x, z = point.z}
		end
		return copied
	end
	local paths, path_by_id = {}, {}
	local function add_path(id, path_type, surface_width, points)
		if type(id) ~= "string" or id == "" or path_by_id[id] then
			violation("path_identity", tostring(id), "unique nonempty id", "invalid")
			return
		end
		if surface_width ~= 3 and surface_width ~= 5 and surface_width ~= 7 then
			violation("path_surface_width", id, "3, 5, or 7", surface_width)
			return
		end
		local copied = copy_points(points, id)
		if not copied then return end
		local path = {id = id, path_type = path_type,
			surface_width = surface_width, points = copied}
		paths[#paths + 1] = path
		path_by_id[id] = path
	end

	if type(source.routes) ~= "table" or #source.routes ~= 57 then
		violation("land_route_roster", "routes", 57,
			type(source.routes) == "table" and #source.routes or "invalid")
	else
		for index = 1, #source.routes do
			local route = source.routes[index]
			add_path(route.id, "land_route", route.surface_width, route.centreline)
		end
	end
	local anchor_by_id = {}
	if type(source.anchors) == "table" then
		for index = 1, #source.anchors do
			local anchor = source.anchors[index]
			if type(anchor) == "table" and type(anchor.id) == "string" then
				anchor_by_id[anchor.id] = anchor
			end
		end
	end
	local trail_templates = {
		bandit_home = true, bandit_frontier = true, mirefolk = true, clash = true,
	}
	if type(source.poi_spurs) ~= "table" or #source.poi_spurs ~= 74 then
		violation("poi_spur_roster", "poi_spurs", 74,
			type(source.poi_spurs) == "table" and #source.poi_spurs or "invalid")
	else
		for index = 1, #source.poi_spurs do
			local spur = source.poi_spurs[index]
			local anchor = type(spur) == "table" and
				anchor_by_id[spur.anchor_id] or nil
			local width = anchor and trail_templates[anchor.template_id] and 3 or 5
			add_path(spur.id, "poi_spur", width, spur.centreline)
		end
	end
	if type(source.island_routes) ~= "table" or #source.island_routes ~= 8 then
		violation("island_route_roster", "island_routes", 8,
			type(source.island_routes) == "table" and #source.island_routes or
				"invalid")
	else
		for index = 1, #source.island_routes do
			local route = source.island_routes[index]
			add_path(route.id, "island_route", 5, route.centreline)
		end
	end
	if #paths ~= 139 then
		violation("selected_path_roster", "selected_paths", 139, #paths)
	end
	table.sort(paths, function(a, b) return a.id < b.id end)

	local surface_offset, surface_stride = 10000, 32768
	local function surface_key(x, z)
		return (x + surface_offset) * surface_stride + z + surface_offset
	end
	local total_surface_columns = 0
	for index = 1, #paths do
		local path = paths[index]
		local expansion = math.floor(path.surface_width / 2) + 1
		local min_x, max_x, min_z, max_z
		for point_index = 1, #path.points do
			local point = path.points[point_index]
			min_x = math.min(min_x or point.x, point.x)
			max_x = math.max(max_x or point.x, point.x)
			min_z = math.min(min_z or point.z, point.z)
			max_z = math.max(max_z or point.z, point.z)
		end
		min_x, max_x = min_x - expansion, max_x + expansion
		min_z, max_z = min_z - expansion, max_z + expansion
		local set, xs, zs = {}, {}, {}
		local actual_min_x, actual_max_x, actual_min_z, actual_max_z
		for z = min_z, max_z do
			for x = min_x, max_x do
				if session.polyline_corridor_member(x, z, path.points,
						path.surface_width) then
					local key = surface_key(x, z)
					if set[key] then
						violation("surface_duplicate", path.id, "unique column", key)
					else
						set[key] = true
						xs[#xs + 1], zs[#zs + 1] = x, z
						actual_min_x = math.min(actual_min_x or x, x)
						actual_max_x = math.max(actual_max_x or x, x)
						actual_min_z = math.min(actual_min_z or z, z)
						actual_max_z = math.max(actual_max_z or z, z)
					end
				end
			end
		end
		if #xs == 0 then
			violation("surface_empty", path.id, "at least one column", 0)
		end
		path.surface = {set = set, xs = xs, zs = zs, count = #xs,
			min_x = actual_min_x, max_x = actual_max_x,
			min_z = actual_min_z, max_z = actual_max_z}
		total_surface_columns = total_surface_columns + #xs
	end

	local function tuple_less(a, b)
		if not b then return true end
		if a.kind ~= b.kind then return a.kind < b.kind end
		if a.x1 ~= b.x1 then return a.x1 < b.x1 end
		if a.z1 ~= b.z1 then return a.z1 < b.z1 end
		if a.x2 ~= b.x2 then return a.x2 < b.x2 end
		return a.z2 < b.z2
	end
	local directions = {{-1, 0}, {0, -1}, {0, 1}, {1, 0}}
	local final_pair_by_key = {}
	local new_contact_pairs = 0
	for a_index = 1, #paths - 1 do
		local a = paths[a_index]
		for b_index = a_index + 1, #paths do
			local b = paths[b_index]
			local a_surface, b_surface = a.surface, b.surface
			if a_surface.min_x <= b_surface.max_x + 1 and
					a_surface.max_x + 1 >= b_surface.min_x and
					a_surface.min_z <= b_surface.max_z + 1 and
					a_surface.max_z + 1 >= b_surface.min_z then
				local scan, other = a_surface, b_surface
				if b_surface.count < a_surface.count then scan, other = b_surface, a_surface end
				local overlap_count, touch_count = 0, 0
				local bounds, first_witness
				local function include_endpoint(x, z)
					if not bounds then
						bounds = {min_x = x, max_x = x, min_z = z, max_z = z}
					else
						bounds.min_x = math.min(bounds.min_x, x)
						bounds.max_x = math.max(bounds.max_x, x)
						bounds.min_z = math.min(bounds.min_z, z)
						bounds.max_z = math.max(bounds.max_z, z)
					end
				end
				for point_index = 1, scan.count do
					local x, z = scan.xs[point_index], scan.zs[point_index]
					local key = surface_key(x, z)
					if other.set[key] then
						overlap_count = overlap_count + 1
						include_endpoint(x, z)
						local witness = {kind = "overlap", x1 = x, z1 = z,
							x2 = x, z2 = z}
						if tuple_less(witness, first_witness) then first_witness = witness end
					else
						for direction_index = 1, #directions do
							local direction = directions[direction_index]
							local nx, nz = x + direction[1], z + direction[2]
							local neighbor_key = surface_key(nx, nz)
							if other.set[neighbor_key] and not scan.set[neighbor_key] then
								touch_count = touch_count + 1
								include_endpoint(x, z)
								include_endpoint(nx, nz)
								local x1, z1, x2, z2 = x, z, nx, nz
								if x2 < x1 or x2 == x1 and z2 < z1 then
									x1, z1, x2, z2 = x2, z2, x1, z1
								end
								local witness = {kind = "touch", x1 = x1, z1 = z1,
									x2 = x2, z2 = z2}
								if tuple_less(witness, first_witness) then
									first_witness = witness
								end
							end
						end
					end
				end
				if overlap_count > 0 or touch_count > 0 then
					local key = a.id .. "\t" .. b.id
					local row = {path_a = a.id, path_b = b.id,
						overlap_count = overlap_count, touch_count = touch_count,
						min_x = bounds.min_x, max_x = bounds.max_x,
						min_z = bounds.min_z, max_z = bounds.max_z,
						witness_kind = first_witness.kind,
						witness_x1 = first_witness.x1, witness_z1 = first_witness.z1,
						witness_x2 = first_witness.x2, witness_z2 = first_witness.z2}
					result.contacts[#result.contacts + 1] = row
					final_pair_by_key[key] = row
					if not baseline_pairs[key] then
						new_contact_pairs = new_contact_pairs + 1
						violation("new_path_contact", key,
							"pair present in accepted V1d baseline", "new")
					end
				end
			end
		end
	end
	local removed = 0
	for key in pairs(baseline_pairs) do
		if key ~= "count" and not final_pair_by_key[key] then removed = removed + 1 end
	end
	result.metrics.selected_paths = #paths
	result.metrics.surface_columns_with_path_multiplicity = total_surface_columns
	result.metrics.baseline_contact_pairs = baseline_pairs.count or 0
	result.metrics.final_contact_pairs = #result.contacts
	result.metrics.removed_contact_pairs = removed
	result.metrics.new_contact_pairs = new_contact_pairs
	return result
end
