-- Pure fixed-layout WP40 horizontal evaluator. It registers no engine hooks
-- and performs no map writes.

return function(dependencies)
	if type(dependencies) ~= "table" then
		error("WP40 simple map dependencies missing", 0)
	end
	local source = assert(dependencies.source, "WP40 simple map source missing")
	local schemas = assert(dependencies.schemas, "WP40 simple map schemas missing")
	local canonical = assert(dependencies.canonical,
		"WP40 simple map canonical dependency missing")
	local deterministic = assert(dependencies.deterministic,
		"WP40 simple map deterministic dependency missing")
	local raw_sha256 = assert(dependencies.raw_sha256,
		"WP40 simple map SHA-256 dependency missing")
	local Q = 65536
	local OWNER_SCALE = 256
	local MAX_SAFE = 9007199254740991
	local GEOMETRY_LIMIT = 8192

	local function fail(message)
		error("WP40 simple map: " .. message, 0)
	end

	local function integer(value, label)
		if type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or value % 1 ~= 0 or
				math.abs(value) > MAX_SAFE then
			fail((label or "value") .. " is not a safe integer")
		end
		return value
	end

	local function coordinate(value,label)
		integer(value,label)
		if math.abs(value) > GEOMETRY_LIMIT then
			fail((label or "coordinate") .. " exceeds the fixed-layout bound")
		end
		return value
	end

	local function dense_count(values, label)
		if type(values) ~= "table" then fail(label .. " is not an array") end
		local count = #values
		for index = 1, count do
			if values[index] == nil then fail(label .. " has a hole") end
		end
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or
					key > count then
				fail(label .. " is not a dense array")
			end
		end
		return count
	end

	local function squared_distance(a_x, a_z, b_x, b_z)
		local dx, dz = a_x - b_x, a_z - b_z
		return dx * dx + dz * dz
	end

	local function in_rectangle(x, z, row, expansion)
		expansion = expansion or 0
		return x >= row.min_x - expansion and x <= row.max_x + expansion and
			z >= row.min_z - expansion and z <= row.max_z + expansion
	end

	local function in_centered_half_open_square(x,z,center,total_width,
			expansion)
		expansion=expansion or 0
		local width=total_width+2*expansion
		local x2,z2=2*x,2*z
		return x2 >= 2*center.x-width and x2 < 2*center.x+width and
			z2 >= 2*center.z-width and z2 < 2*center.z+width
	end

	local function in_ellipse(x, z, row, expansion)
		expansion = expansion or 0
		local radius_x = row.radius_x + expansion
		local radius_z = row.radius_z + expansion
		local dx, dz = x - row.center.x, z - row.center.z
		return dx * dx * radius_z * radius_z +
			dz * dz * radius_x * radius_x <=
			radius_x * radius_x * radius_z * radius_z
	end

	local function in_rounded_rectangle(x, z, row, expansion)
		expansion = expansion or 0
		local min_x, max_x = row.min_x - expansion, row.max_x + expansion
		local min_z, max_z = row.min_z - expansion, row.max_z + expansion
		local radius = row.radius + expansion
		local dx2 = math.max(math.abs(2*x-(min_x+max_x))-
			((max_x-min_x)-2*radius),0)
		local dz2 = math.max(math.abs(2*z-(min_z+max_z))-
			((max_z-min_z)-2*radius),0)
		return dx2*dx2+dz2*dz2 <= 4*radius*radius
	end

	local function in_capsule(x, z, row, expansion)
		expansion = expansion or 0
		local radius = row.radius + expansion
		local vx, vz = row.b.x - row.a.x, row.b.z - row.a.z
		local wx, wz = x - row.a.x, z - row.a.z
		local length_squared = vx * vx + vz * vz
		local dot = wx * vx + wz * vz
		if dot <= 0 then
			return wx * wx + wz * wz <= radius * radius
		elseif dot >= length_squared then
			return squared_distance(x,z,row.b.x,row.b.z) <= radius * radius
		end
		local cross = wx * vz - wz * vx
		return cross * cross <= radius * radius * length_squared
	end

	local function point_on_segment(x, z, a, b)
		local cross = (x - a.x) * (b.z - a.z) -
			(z - a.z) * (b.x - a.x)
		if cross ~= 0 then return false end
		return x >= math.min(a.x,b.x) and x <= math.max(a.x,b.x) and
			z >= math.min(a.z,b.z) and z <= math.max(a.z,b.z)
	end

	local function in_polygon(x, z, points)
		local inside = false
		local previous = points[#points]
		for index = 1, #points do
			local current = points[index]
			if point_on_segment(x,z,previous,current) then return true end
			if (current.z > z) ~= (previous.z > z) then
				local orientation=(previous.x-current.x)*(z-current.z)-
					(previous.z-current.z)*(x-current.x)
				if (previous.z > current.z and orientation > 0) or
						(previous.z < current.z and orientation < 0) then
					inside = not inside
				end
			end
			previous = current
		end
		return inside
	end

	local function divmod_nonnegative(numerator, denominator)
		local quotient=math.floor(numerator/denominator)
		local product=quotient*denominator
		while product > numerator do
			quotient=quotient-1
			product=product-denominator
		end
		while numerator-product >= denominator do
			quotient=quotient+1
			product=product+denominator
		end
		return quotient,numerator-product
	end

	local function rational_compare(a, b, c, d)
		local direction=1
		while true do
			local left,left_remainder=divmod_nonnegative(a,b)
			local right,right_remainder=divmod_nonnegative(c,d)
			if left < right then return -direction end
			if left > right then return direction end
			if left_remainder == 0 or right_remainder == 0 then
				if left_remainder == right_remainder then return 0 end
				return (left_remainder == 0 and -1 or 1)*direction
			end
			a,b=b,left_remainder
			c,d=d,right_remainder
			direction=-direction
		end
	end

	local function segment_within_radius(x, z, a, b, radius)
		local vx,vz=b.x-a.x,b.z-a.z
		local wx,wz=x-a.x,z-a.z
		local length_squared=vx*vx+vz*vz
		if length_squared == 0 then
			return wx*wx+wz*wz <= radius*radius
		end
		local dot=wx*vx+wz*vz
		if dot <= 0 then return wx*wx+wz*wz <= radius*radius end
		if dot >= length_squared then
			return squared_distance(x,z,b.x,b.z) <= radius*radius
		end
		local cross=wx*vz-wz*vx
		return cross*cross <= radius*radius*length_squared
	end

	local function segment_distance_ratio(x, z, a, b)
		local vx, vz = b.x - a.x, b.z - a.z
		local length_squared = vx * vx + vz * vz
		if length_squared == 0 then
			return squared_distance(x,z,a.x,a.z),1
		end
		local wx,wz=x-a.x,z-a.z
		local dot=wx*vx+wz*vz
		if dot <= 0 then return wx*wx+wz*wz,1 end
		if dot >= length_squared then
			return squared_distance(x,z,b.x,b.z),1
		end
		local cross=wx*vz-wz*vx
		return cross*cross,length_squared
	end

	local function segment_corridor_member(x,z,a,b,total_width)
		local half_floor=math.floor(total_width/2)
		if x < math.min(a.x,b.x)-half_floor-1 or
				x > math.max(a.x,b.x)+half_floor+1 or
				z < math.min(a.z,b.z)-half_floor-1 or
				z > math.max(a.z,b.z)+half_floor+1 then
			return false
		end
		local numerator,denominator=segment_distance_ratio(x,z,a,b)
		return 4*numerator <= total_width*total_width*denominator
	end

	local function polyline_corridor_member(x,z,points,total_width)
		for index=1,#points-1 do
			if segment_corridor_member(x,z,points[index],points[index+1],
					total_width) then return true,index end
		end
		return false,nil
	end

	local function expanded_polygon_member(x, z, points, radius)
		if in_polygon(x,z,points) then return true end
		local previous = points[#points]
		for index = 1, #points do
			local current = points[index]
			if segment_within_radius(x,z,previous,current,radius) then
				return true
			end
			previous = current
		end
		return false
	end

	local function primitive_member(row, x, z, expansion)
		if row.kind == "capsule" then return in_capsule(x,z,row,expansion)
		elseif row.kind == "ellipse" then return in_ellipse(x,z,row,expansion)
		elseif row.kind == "rounded_rect" then
			return in_rounded_rectangle(x,z,row,expansion)
		end
		fail("unknown primitive kind " .. tostring(row.kind))
	end

	local function bay_member(bay, x, z)
		local samples = bay.centreline
		for index = 1, #samples do
			local sample = samples[index]
			if squared_distance(x,z,sample.x,sample.z) <=
					sample.half_width*sample.half_width then
				return true
			end
		end
		for index = 1, #samples - 1 do
			local a, b = samples[index], samples[index+1]
			local vx, vz = b.x-a.x, b.z-a.z
			local length_squared = vx*vx + vz*vz
			local wx,wz=x-a.x,z-a.z
			local dot=wx*vx+wz*vz
			if dot >= 0 and dot <= length_squared then
				local cross=wx*vz-wz*vx
				local width_numerator=a.half_width*length_squared+
					(b.half_width-a.half_width)*dot
				if rational_compare(cross*cross,length_squared,
						width_numerator*width_numerator,
						length_squared*length_squared) <= 0 then
					return true
				end
			end
		end
		return false
	end

	local function bay_mouth_is_deep_ocean(bay, warped_z)
		if bay.deep_ocean_side == "min_z" then
			return warped_z <= bay.deep_ocean_cut_z
		end
		return warped_z >= bay.deep_ocean_cut_z
	end

	local function closed_pair(a, b)
		if a > b then a, b = b, a end
		return tostring(a) .. ":" .. tostring(b)
	end

	local function validate_source()
		if source.schema ~= schemas.simple_map_source or
				schemas.simple_map ~= "grug_wp40_simple_map_v1" or
				source.layout_id ~= "wp40-simple-map-v1d" or
				source.layout_revision_id ~= "wp40-simple-map-v1e" then
			fail("source schema/layout identity differs")
		end
		if source.warp.cell ~= 256 or source.warp.maximum ~= 60 or
				type(source.warp.hash_domain) ~= "string" or
				4*source.warp.maximum >= source.warp.cell then
			fail("warp identity/no-fold bound differs")
		end
		local partition=source.mainland_partition
		if type(partition) ~= "table" or partition.axis ~= "warped_z" or
				partition.split ~= 0 or
				partition.negative_region ~= "elandor_mainland" or
				partition.nonnegative_region ~= "kragmar_mainland" then
			fail("mainland partition differs")
		end
		for _, pair in ipairs({{source.extent.min_x,"extent min x"},
				{source.extent.max_x,"extent max x"},
				{source.extent.min_z,"extent min z"},
				{source.extent.max_z,"extent max z"}}) do
			coordinate(pair[1],pair[2])
		end
		if source.extent.min_x >= source.extent.max_x or
				source.extent.min_z >= source.extent.max_z or
				integer(source.shelf_width,"shelf width") ~= 80 then
			fail("fixed extent/shelf differs")
		end
		for _, core in ipairs({source.start_core,source.capital_core}) do
			if integer(core.width_x,"core width x") <= 0 or
					integer(core.width_z,"core width z") <= 0 or
					core.width_x%2 ~= 0 or core.width_z%2 ~= 0 then
				fail("fixed core dimensions are not positive even integers")
			end
		end
		local housing=source.housing_policy
		if type(housing) ~= "table" or housing.reservation_width ~= 101 or
				housing.reservation_radius ~= 50 or housing.minimum_gap ~= 10 or
				housing.lattice_spacing ~= 111 or
				housing.lattice_origin_period ~= 111 or
				housing.hash_order_count ~= 16 or
				housing.hash_domain_prefix ~= "housing-pack-" or
				housing.hash_order_numbering ~= "zero_based_two_digit" or
				housing.conflict_rule ~= "candidate_expanded_aabb_v1" or
				housing.tie_break ~= "z_then_x" or
				housing.bias_direction ~= "nearest_first" or
				housing.edge_bias_scope ~= "mask_polygon_boundary" or
				housing.route_bias_scope ~= "all_land_route_centrelines" or
				housing.poi_bias_scope ~=
					"all_actual_anchor_positions_v1" or
				dense_count(housing.greedy_orders,"housing greedy orders") ~= 7 then
			fail("housing packing policy differs")
		end
		local expected_counts = {
			zones=38,land_primitives=14,bays=4,islands=2,channels=2,routes=57,
			crossing_interfaces=9,boat_paths=4,
			island_landings=4,
			route_stations=38,island_routes=8,housing_masks=10,
			coastal_housing_cores=4,
			capital_ingresses=6,
			anchors=100,poi_spurs=74,apex_sockets=24,region_resources=6,
			relief_profiles=6,anchor_profiles=17,landmarks=70,
			hydrology_profiles=11,hydrology_transition_profiles=6,
			hydrology=25,hydrology_interfaces=15,
			hard_protection_recipes=4,hard_protection=42,
			claim_exclusion_recipes=5,claim_exclusions=314,
		}
		for key, expected in pairs(expected_counts) do
			if dense_count(source[key], key) ~= expected then
				fail(key .. " count differs from " .. expected)
			end
		end
		local function collect_ids(values, label)
			local result={}
			for index = 1, #values do
				local id=values[index].id
				if type(id) ~= "string" or id == "" or result[id] then
					fail(label .. " identity differs at " .. index)
				end
				result[id]=values[index]
			end
			return result
		end
		local relief_ids=collect_ids(source.relief_profiles,"relief profile")
		local anchor_profile_ids=collect_ids(source.anchor_profiles,
			"anchor profile")
		local hydrology_profile_ids=collect_ids(source.hydrology_profiles,
			"hydrology profile")
		local transition_profile_ids=collect_ids(
			source.hydrology_transition_profiles,"hydrology transition profile")
		local zone_ids, route_ids, anchor_ids = {}, {}, {}
		local macro_counts = {}
		for index = 1, #source.zones do
			local row = source.zones[index]
			if row.numeric_id ~= index or zone_ids[row.id] then
				fail("zone numeric/id order differs at " .. index)
			end
			integer(row.hub.x,"zone hub x") integer(row.hub.z,"zone hub z")
			integer(row.bias,"zone bias")
			if math.abs(row.bias) > 16777216 then fail("zone bias exceeds 2^24") end
			if not relief_ids[row.primary_relief_id] then
				fail("zone relief reference differs at " .. index)
			end
			local share_total, biome_ids=0,{}
			for biome_index=1,dense_count(row.biomes,"zone biome palette") do
				local biome=row.biomes[biome_index]
				if type(biome.id) ~= "string" or biome_ids[biome.id] or
						integer(biome.share,"biome share") <= 0 then
					fail("zone biome palette differs at " .. index)
				end
				biome_ids[biome.id]=true share_total=share_total+biome.share
			end
			if share_total ~= 100 then fail("zone biome shares do not total 100") end
			zone_ids[row.id] = true
			macro_counts[row.macro_region] = (macro_counts[row.macro_region] or 0)+1
		end
		if macro_counts.elandor_mainland ~= 16 or
				macro_counts.kragmar_mainland ~= 16 or
				macro_counts.holy_grounds ~= 4 or
				macro_counts.wyrmglass_island ~= 1 or
				macro_counts.stormscale_island ~= 1 then
			fail("macro-region zone counts differ")
		end
		local ordinary_regions={elandor_mainland=true,kragmar_mainland=true}
		local function validate_point(value,label)
			if type(value) ~= "table" then fail(label .. " point missing") end
			coordinate(value.x,label .. " x")
			coordinate(value.z,label .. " z")
		end
		local function validate_polygon(points,label)
			if dense_count(points,label .. " polygon") < 3 then
				fail(label .. " polygon is too short")
			end
			for point_index=1,#points do
				validate_point(points[point_index],label .. " polygon")
			end
		end
		local function validate_tapered_centreline(row,label)
			if dense_count(row.centreline,label .. " centreline") < 2 then
				fail(label .. " centreline is too short")
			end
			for sample_index=1,#row.centreline do
				local sample=row.centreline[sample_index]
				coordinate(sample.x,label .. " x")
				coordinate(sample.z,label .. " z")
				if integer(sample.half_width,label .. " half width") <= 0 then
					fail(label .. " width differs")
				end
			end
			for segment=1,#row.centreline-1 do
				local a,b=row.centreline[segment],row.centreline[segment+1]
				local dx,dz=b.x-a.x,b.z-a.z
				local length_squared=dx*dx+dz*dz
				if length_squared <= 0 or length_squared*length_squared > MAX_SAFE or
						math.max(a.half_width,b.half_width)^2*
						length_squared^2 > MAX_SAFE then
					fail(label .. " rational intermediate exceeds safe integer range")
				end
			end
		end
		for index=1,#source.land_primitives do
			local row=source.land_primitives[index]
			if row.operation ~= "add" or not ordinary_regions[row.region] or
					(row.kind ~= "capsule" and row.kind ~= "ellipse" and
					row.kind ~= "rounded_rect") then
				fail("land primitive operation/kind/region differs at " .. index)
			end
			if row.kind == "capsule" then
				validate_point(row.a,"land capsule a")
				validate_point(row.b,"land capsule b")
				if integer(row.radius,"land capsule radius") <= 0 or
						row.radius > 2048 then fail("land capsule radius differs") end
			elseif row.kind == "ellipse" then
				validate_point(row.center,"land ellipse center")
				if integer(row.radius_x,"land ellipse radius x") <= 0 or
						integer(row.radius_z,"land ellipse radius z") <= 0 or
						row.radius_x > 2048 or row.radius_z > 2048 then
					fail("land ellipse radii differ")
				end
			else
				coordinate(row.min_x,"land rounded min x")
				coordinate(row.max_x,"land rounded max x")
				coordinate(row.min_z,"land rounded min z")
				coordinate(row.max_z,"land rounded max z")
				if row.min_x >= row.max_x or row.min_z >= row.max_z or
						integer(row.radius,"land rounded radius") <= 0 or
						2*row.radius > math.min(row.max_x-row.min_x,
							row.max_z-row.min_z) then
					fail("land rounded rectangle differs")
				end
			end
		end
		for index=1,#source.bays do
			local row=source.bays[index]
			local expected_deep_side=row.region == "elandor_mainland" and
				"min_z" or "max_z"
			integer(row.deep_ocean_cut_z,"bay deep-ocean cut z")
			if not ordinary_regions[row.region] or #row.shore_zone_ids < 2 or
					row.deep_ocean_side ~= expected_deep_side or
					row.deep_ocean_cut_z < source.extent.min_z or
					row.deep_ocean_cut_z > source.extent.max_z then
				fail("bay region/shape differs at " .. index)
			end
			validate_tapered_centreline(row,"bay")
			local shore_ids={}
			for shore_index=1,#row.shore_zone_ids do
				local zone_id=row.shore_zone_ids[shore_index]
				if shore_ids[zone_id] or not source.zones[zone_id] or
						source.zones[zone_id].macro_region ~= row.region then
					fail("bay shore ownership differs at " .. index)
				end
				shore_ids[zone_id]=true
			end
		end
		local island_ids={}
		for index=1,#source.islands do
			local row=source.islands[index]
			local zone=source.zones[row.zone_numeric_id]
			if island_ids[row.id] or not zone or zone.macro_region ~= row.region or
					dense_count(row.polygon,"island polygon") < 3 then
				fail("island identity/reference differs at " .. index)
			end
			validate_polygon(row.polygon,"island")
			island_ids[row.id]=true
		end
		local channel_ids={}
		for index=1,#source.channels do
			local row=source.channels[index]
			if channel_ids[row.id] or dense_count(row.polygon,"channel polygon") < 3 or
					integer(row.warning_width,"channel warning width") < 1 or
					integer(row.minimum_hard_width,"channel hard width") < 1 then
				fail("channel identity/shape differs at " .. index)
			end
			validate_polygon(row.polygon,"channel")
			channel_ids[row.id]=true
		end
		local station_ids={}
		for index=1,#source.route_stations do
			local row=source.route_stations[index]
			if station_ids[row.id] or not source.zones[row.zone_numeric_id] then
				fail("route station identity/reference differs at " .. index)
			end
			validate_point(row.position,"route station")
			station_ids[row.id]=row
		end
		if source.route_curve.id ~= "bounded_pinned_curve_v1" or
				source.route_curve.points_per_leg ~= 3 or
				source.route_curve.minimum_points_per_route ~= 7 or
				source.route_curve.amplitude_by_class.primary ~= 48 or
				source.route_curve.amplitude_by_class.secondary ~= 64 or
				source.route_curve.amplitude_by_class.trail ~= 80 then
			fail("route curve policy differs")
		end
		local class_counts = {primary=0,secondary=0,trail=0}
		local route_pairs,route_by_id = {},{}
		for index = 1, #source.routes do
			local row = source.routes[index]
			local pair_key=closed_pair(row.zone_a,row.zone_b)
			local station_a=station_ids[row.station_a_id]
			local station_b=station_ids[row.station_b_id]
			local expected_kind=row.class == "trail" and "trail" or "road"
			if row.numeric_id ~= index or row.kind ~= expected_kind or
					route_ids[row.id] or route_pairs[pair_key] or
					not source.zones[row.zone_a] or not source.zones[row.zone_b] or
					not station_a or not station_b or
					row.curve_policy_id ~= source.route_curve.id or
					row.pinned_point_index ~= 4 or
					dense_count(row.centreline,"route centreline") <
						source.route_curve.minimum_points_per_route then
				fail("route identity/reference differs at " .. index)
			end
			local profile=source.route_profiles[row.class]
			if type(profile) ~= "table" or row.surface_width ~= profile.surface_width or
					row.corridor_width ~= profile.corridor_width or
					(row.class == "primary" and
						(row.surface_width ~= 7 or row.corridor_width ~= 16)) or
					(row.class == "secondary" and
						(row.surface_width ~= 5 or row.corridor_width ~= 12)) or
					(row.class == "trail" and
						(row.surface_width ~= 3 or row.corridor_width ~= 8)) then
				fail("route profile differs at " .. index)
			end
			for point_index=1,#row.centreline do
				validate_point(row.centreline[point_index],"route centreline")
			end
			local first,last=row.centreline[1],row.centreline[#row.centreline]
			if first.x ~= station_a.position.x or first.z ~= station_a.position.z or
					last.x ~= station_b.position.x or last.z ~= station_b.position.z then
				fail("route endpoint pin differs at " .. index)
			end
			route_ids[row.id] = true
			route_by_id[row.id]=row
			class_counts[row.class] = (class_counts[row.class] or 0)+1
			route_pairs[pair_key] = row.id
		end
		if class_counts.primary ~= 30 or class_counts.secondary ~= 24 or
				class_counts.trail ~= 3 then fail("route class counts differ") end
		local crossing_ids={}
		local crossing_kinds={bridge=true,ford=true,tunnel=true,causeway=true}
		for index = 1, #source.crossing_interfaces do
			local row=source.crossing_interfaces[index]
			validate_point(row.position,"crossing")
			local route=route_by_id[row.route_id]
			local pinned=false
			if route then
				for point_index=1,#route.centreline do
					local point=row.position
					local candidate=route.centreline[point_index]
					if candidate.x == point.x and candidate.z == point.z then
						pinned=true break
					end
				end
			end
			if crossing_ids[row.id] or not route or not pinned or
					not crossing_kinds[row.kind] then
				fail("crossing route reference differs")
			end
			if row.authorization_polygon then
				validate_polygon(row.authorization_polygon,"crossing authorization")
				if not in_polygon(row.position.x,row.position.z,
						row.authorization_polygon) then
					fail("crossing authorization does not contain its position")
				end
			end
			crossing_ids[row.id]=true
		end
		local landing_by_id=collect_ids(source.island_landings,"island landing")
		local boat_ids, boat_pair_counts={},{}
		for index=1,#source.boat_paths do
			local row=source.boat_paths[index]
			local landing=landing_by_id[row.landing_id]
			if boat_ids[row.id] or row.kind ~= "boat" or row.width ~= 96 or
					not source.zones[row.from_zone] or not source.zones[row.to_zone] or
					dense_count(row.centreline,"boat centreline") < 2 or not landing or
					landing.boat_path_id ~= row.id or
					landing.zone_numeric_id ~= row.to_zone or landing.width ~= row.width then
				fail("boat path identity/reference differs at " .. index)
			end
			for point_index=1,#row.centreline do
				validate_point(row.centreline[point_index],"boat centreline")
			end
			validate_point(landing.position,"island landing")
			local terminal=row.centreline[#row.centreline]
			if terminal.x ~= landing.position.x or terminal.z ~= landing.position.z then
				fail("boat landing endpoint differs")
			end
			boat_ids[row.id]=true
			local key=closed_pair(row.from_zone,row.to_zone)
			boat_pair_counts[key]=(boat_pair_counts[key] or 0)+1
		end
		for _, count in pairs(boat_pair_counts) do
			if count ~= 2 then fail("boat approach pair count differs") end
		end
		if boat_pair_counts[closed_pair(34,33)] ~= 2 or
				boat_pair_counts[closed_pair(37,38)] ~= 2 then
			fail("boat travel graph differs")
		end
		local parity=source.boat_parity_policy
		if type(parity) ~= "table" or
				parity.id ~= "paired_axis_aligned_node_run_v1" or
				parity.metric ~= "axis_aligned_polyline_node_run" or
				parity.maximum_difference_numerator ~= 1 or
				parity.maximum_difference_denominator ~= 10 or
				dense_count(parity.pairs,"boat parity pairs") ~= 2 then
			fail("boat parity policy differs")
		end
		collect_ids(source.island_routes,"island route")
		for index=1,#source.island_routes do
			if source.island_routes[index].kind ~= "road" then
				fail("island route kind differs at " .. index)
			end
			for point_index=1,#source.island_routes[index].centreline do
				validate_point(source.island_routes[index].centreline[point_index],
					"island route centreline")
			end
		end
		local authored_fixed_count, layout_fixed_count = 0, 0
		local fixed_core_by_zone={}
		local anchor_slot_keys={}
		for index = 1, #source.anchors do
			local row = source.anchors[index]
			local slot_key=tostring(row.zone_numeric_id)..":"..row.slot_id
			if row.numeric_id ~= index or anchor_ids[row.id] or
					anchor_slot_keys[slot_key] or
				not source.zones[row.zone_numeric_id] then
				fail("anchor identity/reference differs at " .. index)
			end
			anchor_ids[row.id] = true
			anchor_slot_keys[slot_key]=true
			if not anchor_profile_ids[row.template_id] then
				fail("anchor profile reference differs at " .. index)
			end
			if row.placement_mode == "authored_fixed" then
				authored_fixed_count = authored_fixed_count + 1
				if row.approved_candidate_index ~= 0 then
					fail("authored anchor provenance differs")
				end
			elseif row.placement_mode == "layout_fixed" then
				layout_fixed_count = layout_fixed_count + 1
				if not integer(row.approved_candidate_index,
						"approved candidate index") or
						row.approved_candidate_index < 1 or
						row.approved_candidate_index > 3 then
					fail("layout-fixed anchor provenance differs")
				end
			else fail("unknown anchor placement mode") end
			if not row.position then fail("fixed anchor has no position") end
			validate_point(row.position,"fixed anchor")
			if row.candidates ~= nil then fail("anchor candidate array survives") end
			if index <= 12 then
				local expected_slot=index <= 6 and "start" or "capital"
				if row.placement_mode ~= "authored_fixed" or
						row.slot_id ~= expected_slot or
						fixed_core_by_zone[row.zone_numeric_id] then
					fail("fixed core anchor order differs at " .. index)
				end
				local dimensions=expected_slot == "start" and source.start_core or
					source.capital_core
				fixed_core_by_zone[row.zone_numeric_id]={
					x=row.position.x,z=row.position.z,
					half_x=dimensions.width_x/2,half_z=dimensions.width_z/2,
				}
			end
		end
		if authored_fixed_count ~= 16 or layout_fixed_count ~= 84 then
			fail("authored/layout-fixed anchor counts differ")
		end
		local spur_ids={}
		for index = 1, #source.poi_spurs do
			local row = source.poi_spurs[index]
			local anchor=source.anchors[index+12]
			local zone=anchor and source.zones[anchor.zone_numeric_id]
			if spur_ids[row.id] or not anchor_ids[row.anchor_id] or
					row.id ~= ("poi_spur_%03d"):format(index+12) or
					row.anchor_id ~= ("anchor_%03d"):format(index+12) or
					dense_count(row.centreline,"POI spur centreline") < 2 or
					row.candidate_paths ~= nil or not zone or
					row.centreline[1].x ~= anchor.position.x or
					row.centreline[1].z ~= anchor.position.z or
					row.centreline[#row.centreline].x ~= zone.hub.x or
					row.centreline[#row.centreline].z ~= zone.hub.z then
				fail("POI spur binding differs")
			end
			for point_index=1,#row.centreline do
				validate_point(row.centreline[point_index],"POI spur centreline")
			end
			spur_ids[row.id]=true
		end
		local socket_ids={}
		for index=1,#source.apex_sockets do
			local row=source.apex_sockets[index]
			if socket_ids[row.id] or not anchor_ids[row.anchor_id] then
				fail("apex socket identity/reference differs at " .. index)
			end
			socket_ids[row.id]=true
		end
		local landmark_ids={}
		for index=1,#source.landmarks do
			local row=source.landmarks[index]
			if row.numeric_id ~= index or landmark_ids[row.id] or
					not source.zones[row.zone_numeric_id] or
					not relief_ids[row.secondary_relief_id] then
				fail("landmark identity/reference differs at " .. index)
			end
			landmark_ids[row.id]=row
		end
		local hydrology_ids={}
		for index=1,#source.hydrology do
			local row=source.hydrology[index]
			if hydrology_ids[row.id] or not landmark_ids[row.landmark_id] or
					not source.zones[row.zone_numeric_id] or
					not hydrology_profile_ids[row.profile_id] then
				fail("hydrology identity/reference differs at " .. index)
			end
			validate_tapered_centreline(row,"hydrology")
			if row.civic_core_zone_numeric_id then
				local civic_zone=integer(row.civic_core_zone_numeric_id,
					"civic core zone")
				if civic_zone ~= row.zone_numeric_id or
						not fixed_core_by_zone[civic_zone] or
						hydrology_profile_ids[row.profile_id].depth <= 0 then
					fail("civic hydrology ownership differs at " .. index)
				end
				local min_x,max_x,min_z,max_z
				for sample_index=1,#row.centreline do
					local sample=row.centreline[sample_index]
					min_x=math.min(min_x or sample.x-sample.half_width,
						sample.x-sample.half_width)
					max_x=math.max(max_x or sample.x+sample.half_width,
						sample.x+sample.half_width)
					min_z=math.min(min_z or sample.z-sample.half_width,
						sample.z-sample.half_width)
					max_z=math.max(max_z or sample.z+sample.half_width,
						sample.z+sample.half_width)
				end
				local overlap_count,overlap_zone=0,nil
				for zone_id,core in pairs(fixed_core_by_zone) do
					if max_x >= core.x-core.half_x and min_x <= core.x+core.half_x and
							max_z >= core.z-core.half_z and
							min_z <= core.z+core.half_z then
						overlap_count=overlap_count+1 overlap_zone=zone_id
					end
				end
				if overlap_count ~= 1 or overlap_zone ~= civic_zone then
					fail("civic hydrology core intersection differs at " .. index)
				end
			end
			hydrology_ids[row.id]=row
		end
		local contact_face_interfaces = {
			{id="highcourt_goldmead_fall",
				upper_id="hydro_highcourt_fork_west",
				lower_id="hydro_goldmead_millriver",
				upper_level_offset=34,lower_level_offset=16,x=-100,z=-1780,
				lip_id="highcourt_goldmead_lip",
				drop_id="highcourt_goldmead_drop",
				plunge_id="highcourt_goldmead_plunge",drop=18,
				plunge_profile_id="river"},
			{id="gravesalt_broken_fall",upper_id="hydro_gravesalt_pans",
				lower_id="hydro_broken_marsh",upper_level_offset=100,
				lower_level_offset=8,x=-1700,z=80,
				lip_id="gravesalt_broken_lip",drop_id="gravesalt_broken_drop",
				plunge_id="gravesalt_broken_plunge",drop=92,
				plunge_profile_id="ordinary_lake"},
			{id="raincall_reedmaze_fall",upper_id="hydro_raincall_plunge",
				lower_id="hydro_whispering_reedmaze",upper_level_offset=44,
				lower_level_offset=8,x=2100,z=1900,
				lip_id="raincall_reedmaze_lip",drop_id="raincall_reedmaze_drop",
				plunge_id="raincall_reedmaze_plunge",drop=36,
				plunge_profile_id="shallow_marsh"},
		}
		local contact_face_fields = {
			id=true,kind=true,upper_id=true,lower_id=true,
			upper_level_offset=true,lower_level_offset=true,position=true,
			lip_id=true,drop_id=true,plunge_id=true,transition_profile_id=true,
			transition_scope_id=true,drop=true,drop_height=true,
			plunge_profile_id=true,bed_seal_layers=true,bank_seal_nodes=true,
			receiver_source_omission_nodes=true,sealed=true,
		}
		local hydrology_interface_ids={}
		for index=1,#source.hydrology_interfaces do
			local row=source.hydrology_interfaces[index]
			local upper=row.upper_id and hydrology_ids[row.upper_id] or nil
			local lower=row.lower_id and hydrology_ids[row.lower_id] or nil
			if type(row.id) ~= "string" or hydrology_interface_ids[row.id] or
					not transition_profile_ids[row.transition_profile_id] or
					(row.hydrology_id and not hydrology_ids[row.hydrology_id]) or
					(row.upper_id and not hydrology_ids[row.upper_id]) or
					(row.lower_id and not hydrology_ids[row.lower_id]) or
					(row.outgoing_reach_id and
						not hydrology_ids[row.outgoing_reach_id]) or
					(row.route_interface_id and
						not crossing_ids[row.route_interface_id]) or
					(row.plunge_profile_id and
						not hydrology_profile_ids[row.plunge_profile_id]) then
				fail("hydrology interface reference differs at " .. index)
			end
			hydrology_interface_ids[row.id]=true
			if upper and (not lower or
					row.upper_level_offset ~= upper.water_surface_offset or
					row.lower_level_offset ~= lower.water_surface_offset) then
				fail("hydrology interface water level differs at " .. index)
			end
			if row.from_ids then
				for from_index=1,#row.from_ids do
					if not hydrology_ids[row.from_ids[from_index]] then
						fail("hydrology confluence reference differs")
					end
				end
			end
			if index <= 12 and row.transition_scope_id ~= nil then
				fail("existing hydrology interface scope differs at " .. index)
			elseif index > 12 then
				local expected=contact_face_interfaces[index-12]
				for key in pairs(row) do
					if not contact_face_fields[key] then
						fail("contact-face waterfall field differs at " .. index)
					end
				end
				if not expected or row.id ~= expected.id or
						row.kind ~= "waterfall" or
						row.upper_id ~= expected.upper_id or
						row.lower_id ~= expected.lower_id or
						row.upper_level_offset ~= expected.upper_level_offset or
						row.lower_level_offset ~= expected.lower_level_offset or
						row.position.x ~= expected.x or row.position.z ~= expected.z or
						row.lip_id ~= expected.lip_id or
						row.drop_id ~= expected.drop_id or
						row.plunge_id ~= expected.plunge_id or
						row.transition_profile_id ~= "waterfall_drop" or
						row.transition_scope_id ~=
							"orthogonal_reach_contact_face_v1" or
						row.drop ~= expected.drop or
						row.drop_height ~= expected.drop or
						row.plunge_profile_id ~= expected.plunge_profile_id or
						row.bed_seal_layers ~= 3 or row.bank_seal_nodes ~= 2 or
						row.receiver_source_omission_nodes ~= 1 or
						row.sealed ~= true then
					fail("contact-face waterfall record differs at " .. index)
				end
			end
		end
		local housing_ids=collect_ids(source.housing_masks,"housing mask")
		for index=1,#source.housing_masks do
			local row=source.housing_masks[index]
			if not source.zones[row.zone_numeric_id] or
					dense_count(row.polygon,"housing polygon") < 3 then
				fail("housing mask reference differs at " .. index)
			end
		end
		for index=1,#source.coastal_housing_cores do
			local row=source.coastal_housing_cores[index]
			local landmark_row=landmark_ids[row.landmark_id]
			if not housing_ids[row.housing_mask_id] or not landmark_row or
					row.shape ~= "vertical_capsule_v1" or
					landmark_row.zone_numeric_id ~= row.zone_numeric_id or
					landmark_row.primitive ~= "rectangle" or
					landmark_row.radius_x*2 < row.inland_depth_min or
					landmark_row.radius_z*2 < row.frontage_min then
				fail("coastal housing core reference differs at " .. index)
			end
		end
		local ingress_ids={}
		for index=1,#source.capital_ingresses do
			local row=source.capital_ingresses[index]
			local anchor=source.anchors[index+6]
			local route_a=route_by_id[row.route_ids and row.route_ids[1]]
			local route_b=route_by_id[row.route_ids and row.route_ids[2]]
			if ingress_ids[row.id] or row.capital_anchor_id ~= anchor.id or
					row.total_width ~= 128 or not route_a or not route_b or
					route_a.class ~= "primary" or route_b.class ~= "secondary" or
					route_a.zone_a ~= anchor.zone_numeric_id or
					route_a.zone_b ~= route_b.zone_a or
					source.zones[route_b.zone_b].macro_region ~= "holy_grounds" then
				fail("capital ingress identity/continuity differs at " .. index)
			end
			local end_a=route_a.centreline[#route_a.centreline]
			local start_b=route_b.centreline[1]
			if end_a.x ~= start_b.x or end_a.z ~= start_b.z then
				fail("capital ingress route join differs at " .. index)
			end
			ingress_ids[row.id]=row
		end
		local hard_recipe_ids=collect_ids(source.hard_protection_recipes,
			"hard protection recipe")
		local hard_ids={}
		for index=1,#source.hard_protection do
			local row=source.hard_protection[index]
			if hard_ids[row.id] or not hard_recipe_ids[row.recipe_id] or
					not anchor_ids[row.source_anchor_id] or
					(row.ingress_id and (not ingress_ids[row.ingress_id] or
						row.route_ids ~= ingress_ids[row.ingress_id].route_ids)) then
				fail("hard protection identity/reference differs at " .. index)
			end
			hard_ids[row.id]=true
		end
		local exclusion_recipe_ids=collect_ids(source.claim_exclusion_recipes,
			"claim exclusion recipe")
		local exclusion_ids={}
		for index=1,#source.claim_exclusions do
			local row=source.claim_exclusions[index]
			if exclusion_ids[row.id] or not exclusion_recipe_ids[row.recipe_id] then
				fail("claim exclusion identity/reference differs at " .. index)
			end
			exclusion_ids[row.id]=true
		end
		local forbidden_keys = {
			boundary_id=true,boundary_interface_id=true,perimeter_id=true,
			face_id=true,winner_seed=true,repair_rule=true,
			candidate_index=true,
		}
		local function reject_retired_fields(value, seen)
			if type(value) ~= "table" or seen[value] then return end
			seen[value] = true
			for key, child in pairs(value) do
				if forbidden_keys[key] then fail("retired field survives: "..key) end
				reject_retired_fields(child,seen)
			end
		end
		reject_retired_fields(source,{})
		return true
	end

	validate_source()

	local module = {validate_source=validate_source}
	local zone_ids_by_region = {}
	for index = 1, #source.zones do
		local region = source.zones[index].macro_region
		local ids = zone_ids_by_region[region]
		if not ids then ids={} zone_ids_by_region[region]=ids end
		ids[#ids+1] = index
	end
	local land_primitives_by_region = {}
	for index = 1, #source.land_primitives do
		local row = source.land_primitives[index]
		local records = land_primitives_by_region[row.region]
		if not records then records={} land_primitives_by_region[row.region]=records end
		records[#records+1] = row
	end
	local hydrology_profile_by_id={}
	for index=1,#source.hydrology_profiles do
		local row=source.hydrology_profiles[index]
		hydrology_profile_by_id[row.id]=row
	end
	local feature_bounds = {}
	for index = 1, #source.bays do
		local row = source.bays[index]
		local bounds = {min_x=math.huge,max_x=-math.huge,
			min_z=math.huge,max_z=-math.huge}
		for sample_index = 1, #row.centreline do
			local sample = row.centreline[sample_index]
			bounds.min_x=math.min(bounds.min_x,sample.x-sample.half_width)
			bounds.max_x=math.max(bounds.max_x,sample.x+sample.half_width)
			bounds.min_z=math.min(bounds.min_z,sample.z-sample.half_width)
			bounds.max_z=math.max(bounds.max_z,sample.z+sample.half_width)
		end
		feature_bounds[row]=bounds
	end
	for index = 1, #source.hydrology do
		local row=source.hydrology[index]
		local bounds={min_x=math.huge,max_x=-math.huge,
			min_z=math.huge,max_z=-math.huge}
		for sample_index=1,#row.centreline do
			local sample=row.centreline[sample_index]
			bounds.min_x=math.min(bounds.min_x,sample.x-sample.half_width)
			bounds.max_x=math.max(bounds.max_x,sample.x+sample.half_width)
			bounds.min_z=math.min(bounds.min_z,sample.z-sample.half_width)
			bounds.max_z=math.max(bounds.max_z,sample.z+sample.half_width)
		end
		feature_bounds[row]=bounds
	end
	for index = 1, #source.islands do
		local row = source.islands[index]
		local bounds = {min_x=math.huge,max_x=-math.huge,
			min_z=math.huge,max_z=-math.huge}
		for point_index = 1, #row.polygon do
			local value=row.polygon[point_index]
			bounds.min_x=math.min(bounds.min_x,value.x)
			bounds.max_x=math.max(bounds.max_x,value.x)
			bounds.min_z=math.min(bounds.min_z,value.z)
			bounds.max_z=math.max(bounds.max_z,value.z)
		end
		feature_bounds[row]=bounds
	end
	for index=1,#source.channels do
		local row=source.channels[index]
		local bounds={min_x=math.huge,max_x=-math.huge,
			min_z=math.huge,max_z=-math.huge}
		for point_index=1,#row.polygon do
			local value=row.polygon[point_index]
			bounds.min_x=math.min(bounds.min_x,value.x)
			bounds.max_x=math.max(bounds.max_x,value.x)
			bounds.min_z=math.min(bounds.min_z,value.z)
			bounds.max_z=math.max(bounds.max_z,value.z)
		end
		feature_bounds[row]=bounds
	end
	local exclusion_source_by_id={}
	for _, collection in ipairs({source.anchors,source.poi_spurs,source.routes,
			source.island_routes,source.hydrology,source.bays,source.islands,
			source.channels,source.hard_protection}) do
		for index=1,#collection do
			exclusion_source_by_id[collection[index].id]=collection[index]
		end
	end
	local hard_recipe_by_id={}
	for index=1,#source.hard_protection_recipes do
		local row=source.hard_protection_recipes[index]
		hard_recipe_by_id[row.id]=row
	end
	local exclusion_shapes={}
	local function polyline_bounds(paths,total_width)
		local expansion=math.floor((total_width+1)/2)
		local bounds={min_x=math.huge,max_x=-math.huge,
			min_z=math.huge,max_z=-math.huge}
		for path_index=1,#paths do
			local points=paths[path_index]
			for point_index=1,#points do
				local point=points[point_index]
				bounds.min_x=math.min(bounds.min_x,point.x-expansion)
				bounds.max_x=math.max(bounds.max_x,point.x+expansion)
				bounds.min_z=math.min(bounds.min_z,point.z-expansion)
				bounds.max_z=math.max(bounds.max_z,point.z+expansion)
			end
		end
		return bounds
	end
	for index=1,#source.claim_exclusions do
		local exclusion=source.claim_exclusions[index]
		local record=exclusion_source_by_id[exclusion.source_id]
		local shape={numeric_id=index,id=exclusion.id,record=record}
		if exclusion.recipe_id == "exclude_anchor_blend_v1" then
			shape.kind="square" shape.center=exclusion.center
			shape.total_width=exclusion.total_width
			local half=math.floor((shape.total_width+1)/2)
			shape.bounds={min_x=shape.center.x-half,max_x=shape.center.x+half,
				min_z=shape.center.z-half,max_z=shape.center.z+half}
		elseif exclusion.recipe_id == "exclude_route_corridor_v1" then
			shape.kind="polyline" shape.total_width=exclusion.corridor_width
			shape.paths={record.centreline}
			shape.bounds=polyline_bounds(shape.paths,shape.total_width)
		elseif exclusion.recipe_id == "exclude_planned_water_v1" then
			shape.kind="tapered" shape.paths={record.centreline}
			shape.warped=record.region ~= nil
			shape.bounds={min_x=feature_bounds[record].min_x,
				max_x=feature_bounds[record].max_x,
				min_z=feature_bounds[record].min_z,
				max_z=feature_bounds[record].max_z}
			if shape.warped then
				shape.bounds.min_x=shape.bounds.min_x-source.warp.maximum
				shape.bounds.max_x=shape.bounds.max_x+source.warp.maximum
				shape.bounds.min_z=shape.bounds.min_z-source.warp.maximum
				shape.bounds.max_z=shape.bounds.max_z+source.warp.maximum
			end
		elseif exclusion.recipe_id == "exclude_coast_v1" then
			shape.kind="polygon" shape.polygon=record.polygon
			shape.expansion=exclusion.projection_width
			shape.warped=record.region ~= nil
			local extra=shape.expansion+(shape.warped and source.warp.maximum or 0)
			shape.bounds={min_x=feature_bounds[record].min_x-extra,
				max_x=feature_bounds[record].max_x+extra,
				min_z=feature_bounds[record].min_z-extra,
				max_z=feature_bounds[record].max_z+extra}
		elseif exclusion.recipe_id == "exclude_active_core_v1" then
			local recipe=hard_recipe_by_id[record.recipe_id]
			if recipe.shape == "polyline_corridor" then
				shape.kind="polyline" shape.total_width=recipe.total_width
				shape.paths={}
				for route_index=1,#record.route_ids do
					shape.paths[#shape.paths+1]=
						exclusion_source_by_id[record.route_ids[route_index]].centreline
				end
				shape.bounds=polyline_bounds(shape.paths,shape.total_width)
			else
				shape.kind="square" shape.center=record.center
				shape.total_width=recipe.total_width or 1
				local half=math.floor((shape.total_width+1)/2)
				shape.bounds={min_x=shape.center.x-half,max_x=shape.center.x+half,
					min_z=shape.center.z-half,max_z=shape.center.z+half}
			end
		else fail("unknown compiled claim exclusion recipe") end
		exclusion_shapes[index]=shape
	end
	local exclusion_grid={}
	local exclusion_cell=128
	for index=1,#exclusion_shapes do
		local shape=exclusion_shapes[index]
		local min_cell_x=deterministic.floor_div(shape.bounds.min_x,exclusion_cell)
		local max_cell_x=deterministic.floor_div(shape.bounds.max_x,exclusion_cell)
		local min_cell_z=deterministic.floor_div(shape.bounds.min_z,exclusion_cell)
		local max_cell_z=deterministic.floor_div(shape.bounds.max_z,exclusion_cell)
		for cell_z=min_cell_z,max_cell_z do
			local row=exclusion_grid[cell_z]
			if not row then row={} exclusion_grid[cell_z]=row end
			for cell_x=min_cell_x,max_cell_x do
				local values=row[cell_x]
				if not values then values={} row[cell_x]=values end
				values[#values+1]=shape
			end
		end
	end
	local hydrology_grid={}
	local hydrology_cell=128
	for index=1,#source.hydrology do
		local row=source.hydrology[index]
		local bounds=feature_bounds[row]
		local min_ix=deterministic.floor_div(bounds.min_x,hydrology_cell)
		local max_ix=deterministic.floor_div(bounds.max_x,hydrology_cell)
		local min_iz=deterministic.floor_div(bounds.min_z,hydrology_cell)
		local max_iz=deterministic.floor_div(bounds.max_z,hydrology_cell)
		for iz=min_iz,max_iz do
			local grid_row=hydrology_grid[iz]
			if not grid_row then grid_row={} hydrology_grid[iz]=grid_row end
			for ix=min_ix,max_ix do
				local candidates=grid_row[ix]
				if not candidates then candidates={} grid_row[ix]=candidates end
				candidates[#candidates+1]=row
			end
		end
	end
	local fixed_core_groups, fixed_group_by_key = {}, {}
	for index = 1, 12 do
		local anchor=source.anchors[index]
		local half_x, half_z
		if index <= 6 then
			half_x=source.start_core.width_x/2
			half_z=source.start_core.width_z/2
		else
			half_x=source.capital_core.width_x/2
			half_z=source.capital_core.width_z/2
		end
		local key=tostring(anchor.position.z)..":"..tostring(half_z)
		local group=fixed_group_by_key[key]
		if not group then
			group={z=anchor.position.z,half_z=half_z,cores={}}
			fixed_group_by_key[key]=group
			fixed_core_groups[#fixed_core_groups+1]=group
		end
		group.cores[#group.cores+1]={x=anchor.position.x,half_x=half_x,
			zone_numeric_id=anchor.zone_numeric_id}
	end
	local landmark_by_id={}
	for index=1,#source.landmarks do
		local row=source.landmarks[index]
		landmark_by_id[row.id]=row
	end
	local coastal_core_capsules={}
	local coastal_core_capsule_by_id={}
	for index=1,#source.coastal_housing_cores do
		local row=source.coastal_housing_cores[index]
		local landmark=landmark_by_id[row.landmark_id]
		local radius=landmark.radius_x
		local half_axis=landmark.radius_z-radius
		local capsule={
			id=row.id,
			a={x=landmark.center.x,z=landmark.center.z-half_axis},
			b={x=landmark.center.x,z=landmark.center.z+half_axis},
			radius=radius,
			min_x=landmark.center.x-landmark.radius_x,
			max_x=landmark.center.x+landmark.radius_x,
			min_z=landmark.center.z-landmark.radius_z,
			max_z=landmark.center.z+landmark.radius_z,
			zone_numeric_id=row.zone_numeric_id,
		}
		coastal_core_capsules[index]=capsule
		coastal_core_capsule_by_id[capsule.id]=capsule
	end
	local layout_hash=deterministic.new_hash(canonical,raw_sha256,
		schemas.simple_map,"0")
	local function housing_priority_word(domain,mask_id,x,z)
		local input="GRUGWP40HASH" .. string.char(0) ..
			canonical.encode(canonical.text(schemas.simple_map)) ..
			canonical.encode(canonical.text(domain)) ..
			canonical.encode(canonical.text(source.layout_id)) ..
			canonical.encode(canonical.text(mask_id)) ..
			canonical.encode(canonical.array({canonical.signed(x),
				canonical.signed(z)})) ..
			canonical.encode(canonical.unsigned(0)) ..
			canonical.encode(canonical.unsigned(0)) ..
			canonical.encode(canonical.unsigned(0))
		local digest=raw_sha256(input)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("housing hash digest differs")
		end
		local a,b,c,d=digest:byte(1,4)
		return ((a*256+b)*256+c)*256+d
	end
	local path_by_id={}
	for _, collection in ipairs({source.routes,source.boat_paths,
			source.island_routes}) do
		for index=1,#collection do path_by_id[collection[index].id]=collection[index] end
	end
	local cell=source.warp.cell
	local maximum=source.warp.maximum
	local query_bounds={
		min_x=source.extent.min_x-source.shelf_width-maximum,
		max_x=source.extent.max_x+source.shelf_width+maximum,
		min_z=source.extent.min_z-source.shelf_width-maximum,
		max_z=source.extent.max_z+source.shelf_width+maximum,
	}
	local min_ix=deterministic.floor_div(query_bounds.min_x,cell)-1
	local max_ix=deterministic.floor_div(query_bounds.max_x,cell)+1
	local min_iz=deterministic.floor_div(query_bounds.min_z,cell)-1
	local max_iz=deterministic.floor_div(query_bounds.max_z,cell)+1
	local lattice={}
	local function vector_at(ix,iz)
		local row=lattice[iz]
		if not row then row={} lattice[iz]=row end
		local value=row[ix]
		if value then return value end
		local span=2*maximum+1
		value={
			x=layout_hash.range(source.warp.hash_domain,source.layout_id,
				{ix,iz},0,0,span)-maximum,
			z=layout_hash.range(source.warp.hash_domain,source.layout_id,
				{ix,iz},0,1,span)-maximum,
		}
		row[ix]=value
		return value
	end
	for iz=min_iz,max_iz do
		for ix=min_ix,max_ix do vector_at(ix,iz) end
	end
	local warp_proof={max_horizontal_x=0,max_horizontal_z=0,
		max_vertical_x=0,max_vertical_z=0}
	for iz=min_iz,max_iz do
		for ix=min_ix,max_ix do
			local value=vector_at(ix,iz)
			if math.abs(value.x) > maximum or math.abs(value.z) > maximum then
				fail("warp lattice displacement exceeds maximum")
			end
			if ix < max_ix then
				local neighbor=vector_at(ix+1,iz)
				warp_proof.max_horizontal_x=math.max(warp_proof.max_horizontal_x,
					math.abs(value.x-neighbor.x))
				warp_proof.max_horizontal_z=math.max(warp_proof.max_horizontal_z,
					math.abs(value.z-neighbor.z))
			end
			if iz < max_iz then
				local neighbor=vector_at(ix,iz+1)
				warp_proof.max_vertical_x=math.max(warp_proof.max_vertical_x,
					math.abs(value.x-neighbor.x))
				warp_proof.max_vertical_z=math.max(warp_proof.max_vertical_z,
					math.abs(value.z-neighbor.z))
			end
		end
	end
	if warp_proof.max_horizontal_x+warp_proof.max_vertical_x >= cell or
			warp_proof.max_horizontal_z+warp_proof.max_vertical_z >= cell then
		fail("warp bilinear no-fold proof differs")
	end
	warp_proof.cell=cell
	warp_proof.maximum=maximum
	warp_proof.query_bounds=query_bounds
	warp_proof.halo={min_ix=min_ix,max_ix=max_ix,min_iz=min_iz,max_iz=max_iz}

	local function warp(x,z)
		integer(x,"query x") integer(z,"query z")
		if not in_rectangle(x,z,query_bounds,0) then return nil end
		local ix=deterministic.floor_div(x,cell)
		local iz=deterministic.floor_div(z,cell)
		if ix < min_ix or ix >= max_ix or iz < min_iz or iz >= max_iz then
			return nil
		end
		local tx=math.floor(((x-ix*cell)*Q+math.floor(cell/2))/cell)
		local tz=math.floor(((z-iz*cell)*Q+math.floor(cell/2))/cell)
		local v00,v10=vector_at(ix,iz),vector_at(ix+1,iz)
		local v01,v11=vector_at(ix,iz+1),vector_at(ix+1,iz+1)
		local dx0=deterministic.qlerp(v00.x,v10.x,tx)
		local dx1=deterministic.qlerp(v01.x,v11.x,tx)
		local dz0=deterministic.qlerp(v00.z,v10.z,tx)
		local dz1=deterministic.qlerp(v01.z,v11.z,tx)
		local owner_dx0=deterministic.qlerp(v00.x*OWNER_SCALE,
			v10.x*OWNER_SCALE,tx)
		local owner_dx1=deterministic.qlerp(v01.x*OWNER_SCALE,
			v11.x*OWNER_SCALE,tx)
		local owner_dz0=deterministic.qlerp(v00.z*OWNER_SCALE,
			v10.z*OWNER_SCALE,tx)
		local owner_dz1=deterministic.qlerp(v01.z*OWNER_SCALE,
			v11.z*OWNER_SCALE,tx)
		return x+deterministic.qlerp(dx0,dx1,tz),
			z+deterministic.qlerp(dz0,dz1,tz),
			x*OWNER_SCALE+deterministic.qlerp(owner_dx0,owner_dx1,tz),
			z*OWNER_SCALE+deterministic.qlerp(owner_dz0,owner_dz1,tz)
	end

	local warped_hubs={}
	for index=1,#source.zones do
		local row=source.zones[index]
		local x,z,owner_x,owner_z=warp(row.hub.x,row.hub.z)
		warped_hubs[index]={x=x,z=z,owner_x=owner_x,owner_z=owner_z}
	end
	local difficulty_cache=nil

	function module.new(full_seed_string)
		local hash = deterministic.new_hash(canonical,raw_sha256,
			schemas.simple_map,full_seed_string)

		local function fixed_owner_at(x, z, expansion)
			expansion = expansion or 0
			for group_index = 1, #fixed_core_groups do
				local group=fixed_core_groups[group_index]
				if z >= group.z-group.half_z-expansion and
						z < group.z+group.half_z+expansion then
					for core_index = 1, #group.cores do
						local core=group.cores[core_index]
						if x >= core.x-core.half_x-expansion and
								x < core.x+core.half_x+expansion then
							return core.zone_numeric_id
						end
					end
				end
			end
			return nil
		end

		local function coastal_core_owner_at(x,z)
			for index=1,#coastal_core_capsules do
				local core=coastal_core_capsules[index]
				if x >= core.min_x and x < core.max_x and
						z >= core.min_z and z < core.max_z and
						in_capsule(x,z,core,0) then
					return core.zone_numeric_id
				end
			end
			return nil
		end

		local function bay_at(warped_x, warped_z)
			for index = 1, #source.bays do
				local row=source.bays[index]
				local bounds=feature_bounds[row]
				if in_rectangle(warped_x,warped_z,bounds,0) and
						bay_member(row,warped_x,warped_z) then
					return row
				end
			end
			return nil
		end

		local function hydrology_at(x, z, civic_core_zone_numeric_id,
				macro_region)
			local grid_row=hydrology_grid[math.floor(z/hydrology_cell)]
			local candidates=grid_row and
				grid_row[math.floor(x/hydrology_cell)] or nil
			if not candidates then return nil end
			for index=1,#candidates do
				local row=candidates[index]
				local zone=source.zones[row.zone_numeric_id]
				if ((civic_core_zone_numeric_id and
						row.civic_core_zone_numeric_id == civic_core_zone_numeric_id) or
						(not civic_core_zone_numeric_id and not row.civic_core_zone_numeric_id and
						zone.macro_region == macro_region)) and
						hydrology_profile_by_id[row.profile_id].depth > 0 and
						in_rectangle(x,z,feature_bounds[row],0) and
						bay_member(row,x,z) then
					return row
				end
			end
			return nil
		end

		local function ordinary_region_at(warped_x, warped_z)
			for index = 1, #source.islands do
				local row = source.islands[index]
				if in_rectangle(warped_x,warped_z,feature_bounds[row],0) and
						in_polygon(warped_x,warped_z,row.polygon) then return row.region end
			end
			local partition=source.mainland_partition
			local candidate_region = warped_z < partition.split and
				partition.negative_region or partition.nonnegative_region
			local candidates = land_primitives_by_region[candidate_region]
			for index = 1, #candidates do
				local row = candidates[index]
				if primitive_member(row,warped_x,warped_z,0) then return row.region end
			end
			return nil
		end

		local function expanded_positive_at(x, z, warped_x, warped_z, radius)
			local fixed_owner=fixed_owner_at(x,z,radius)
			if fixed_owner then return source.zones[fixed_owner].macro_region end
			if in_rectangle(x,z,source.holy_grounds,radius) then
				return "holy_grounds"
			end
			for index = 1, #source.islands do
				local row=source.islands[index]
				if in_rectangle(warped_x,warped_z,feature_bounds[row],radius) and
						expanded_polygon_member(warped_x,warped_z,
						row.polygon,radius) then return row.region end
			end
			local partition=source.mainland_partition
			local candidate_region = warped_z < partition.split and
				partition.negative_region or partition.nonnegative_region
			local candidates = land_primitives_by_region[candidate_region]
			for index = 1, #candidates do
				local row=candidates[index]
				if primitive_member(row,warped_x,warped_z,radius) then
					return candidate_region
				end
			end
			return nil
		end

		local function channel_at(x, z)
			for index = 1, #source.channels do
				local row=source.channels[index]
				if in_rectangle(x,z,feature_bounds[row],0) and
						in_polygon(x,z,row.polygon) then
					return row
				end
			end
			return nil
		end

		local function owner_for_region(region, x, z, candidate_ids, owner_x,
				owner_z)
			local best_id, best_score
			owner_x=owner_x or x*OWNER_SCALE
			owner_z=owner_z or z*OWNER_SCALE
			local ids = candidate_ids or zone_ids_by_region[region]
			for candidate_index = 1, #ids do
				local index = ids[candidate_index]
				local zone = source.zones[index]
				if zone.macro_region == region then
					local hub = warped_hubs[index]
					local score = squared_distance(owner_x,owner_z,
						hub.owner_x,hub.owner_z)-zone.bias*OWNER_SCALE*OWNER_SCALE
					if not best_score or score < best_score or
							(score == best_score and index < best_id) then
						best_id,best_score = index,score
					end
				end
			end
			return best_id
		end

		local function classification_values_at(x, z)
			local warped_x,warped_z,owner_x,owner_z=warp(x,z)
			if not warped_x then return "deep_ocean" end
			local fixed_owner = fixed_owner_at(x,z,0)
			if fixed_owner then
				local civic_hydrology=hydrology_at(x,z,fixed_owner)
				local macro_region=source.zones[fixed_owner].macro_region
				if civic_hydrology then
					return "planned_water",macro_region,fixed_owner,nil,
						civic_hydrology.id,nil,true,true
				end
				return "land",macro_region,fixed_owner,nil,nil,nil,true,false
			end
			-- These four mutable dry strips are deliberate political/shoreline
			-- overrides.  Keeping the guarantee here makes the complete authored
			-- 600 by 300 footprint survive the warped macro coast, owner scoring,
			-- hydrology and later housing erosion without a repair pass.
			local coastal_owner=coastal_core_owner_at(x,z)
			if coastal_owner then
				return "land",source.zones[coastal_owner].macro_region,coastal_owner
			end
			local exact_holy=in_rectangle(x,z,source.holy_grounds,0)
			if not exact_holy then
				local bay = bay_at(warped_x,warped_z)
				if bay then
					if bay_mouth_is_deep_ocean(bay,warped_z) then
						return "deep_ocean"
					end
					local owner = owner_for_region(bay.region,warped_x,warped_z,
						bay.shore_zone_ids,owner_x,owner_z)
					return "planned_water",bay.region,owner,bay.id
				end
			end
			local region = exact_holy and "holy_grounds" or
				ordinary_region_at(warped_x,warped_z)
			if region then
				local hydrology=hydrology_at(x,z,nil,region)
				if hydrology then
					local owner=owner_for_region(region,warped_x,warped_z,nil,
						owner_x,owner_z)
					return "planned_water",region,owner,nil,
						hydrology.id
				end
				local owner = owner_for_region(region,warped_x,warped_z,nil,
					owner_x,owner_z)
				return "land",region,owner,nil,nil,nil,exact_holy or false,false
			end
			local channel = channel_at(x,z)
			if channel then
				return "immutable_dragon_channel",nil,nil,nil,nil,channel.id
			end
			local shelf_region=expanded_positive_at(x,z,warped_x,warped_z,
				source.shelf_width)
			if shelf_region then
				local owner=owner_for_region(shelf_region,warped_x,warped_z,nil,
					owner_x,owner_z)
				return "coastal_shelf",shelf_region,owner
			end
			return "deep_ocean"
		end

		local function classification_at(x,z)
			local water_class,macro_region,zone_numeric_id,bay_id,hydrology_id,
				channel_id,fixed,civic_water=classification_values_at(x,z)
			return {water_class=water_class,macro_region=macro_region,
				zone_numeric_id=zone_numeric_id,bay_id=bay_id,
				hydrology_id=hydrology_id,channel_id=channel_id,
				fixed=fixed or nil,civic_water=civic_water or nil}
		end

		local function static_exclusion_values_at(x,z)
			local grid_row=exclusion_grid[deterministic.floor_div(z,exclusion_cell)]
			local candidates=grid_row and
				grid_row[deterministic.floor_div(x,exclusion_cell)] or nil
			if not candidates then return nil end
			for index=1,#candidates do
				local shape=candidates[index]
				if in_rectangle(x,z,shape.bounds,0) then
					local member=false
					if shape.kind == "square" then
						member=in_centered_half_open_square(x,z,shape.center,
							shape.total_width,0)
					elseif shape.kind == "polyline" then
						for path_index=1,#shape.paths do
							if polyline_corridor_member(x,z,shape.paths[path_index],
									shape.total_width) then member=true break end
						end
					elseif shape.kind == "tapered" then
						local query_x,query_z=x,z
						if shape.warped then query_x,query_z=warp(x,z) end
						member=query_x and bay_member(shape.record,query_x,query_z) or false
					elseif shape.kind == "polygon" then
						local query_x,query_z=x,z
						if shape.warped then query_x,query_z=warp(x,z) end
						member=query_x and expanded_polygon_member(query_x,query_z,
							shape.polygon,shape.expansion) or false
					end
					if member then return shape.numeric_id,shape.id end
				end
			end
			return nil
		end

		local function build_difficulty_lattice()
			if difficulty_cache then return difficulty_cache end
			local spacing=32
			local radius=192
			local sample_radius=math.floor((radius-1)/spacing)
			local min_grid_x=deterministic.floor_div(query_bounds.min_x,spacing)-1
			local max_grid_x=deterministic.floor_div(query_bounds.max_x,spacing)+1
			local min_grid_z=deterministic.floor_div(query_bounds.min_z,spacing)-1
			local max_grid_z=deterministic.floor_div(query_bounds.max_z,spacing)+1
			local components={"mainland","wyrmglass_island","stormscale_island"}
			local values={}
			local digest_rows={}
			local weight_sum=0
			for offset=-sample_radius,sample_radius do
				weight_sum=weight_sum+(radius-math.abs(offset*spacing))
			end
			local denominator=weight_sum*weight_sum
			local function hard_target(component,x,z)
				if component == "wyrmglass_island" then
					return source.zones[33].difficulty_target
				elseif component == "stormscale_island" then
					return source.zones[38].difficulty_target
				end
				x=math.max(query_bounds.min_x,math.min(query_bounds.max_x,x))
				z=math.max(query_bounds.min_z,math.min(query_bounds.max_z,z))
				local warped_x,warped_z,owner_x,owner_z=warp(x,z)
				local region
				if in_rectangle(x,z,source.holy_grounds,0) then
					region="holy_grounds"
				else
					local partition=source.mainland_partition
					region=warped_z < partition.split and
						partition.negative_region or partition.nonnegative_region
				end
				local owner=owner_for_region(region,warped_x,warped_z,nil,
					owner_x,owner_z)
				return source.zones[owner].difficulty_target
			end
			for component_index=1,#components do
				local component=components[component_index]
				local raw={}
				for grid_z=min_grid_z-sample_radius,
						max_grid_z+sample_radius do
					local row={}
					raw[grid_z]=row
					for grid_x=min_grid_x-sample_radius,
							max_grid_x+sample_radius do
						row[grid_x]=hard_target(component,grid_x*spacing,
							grid_z*spacing)
					end
				end
				local horizontal={}
				for grid_z=min_grid_z-sample_radius,
						max_grid_z+sample_radius do
					local row={}
					horizontal[grid_z]=row
					for grid_x=min_grid_x,max_grid_x do
						local weighted=0
						for offset=-sample_radius,sample_radius do
							weighted=weighted+raw[grid_z][grid_x+offset]*
								(radius-math.abs(offset*spacing))
						end
						row[grid_x]=weighted
					end
				end
				local component_values={}
				values[component]=component_values
				for grid_z=min_grid_z,max_grid_z do
					local row={}
					component_values[grid_z]=row
					for grid_x=min_grid_x,max_grid_x do
						local weighted=0
						for offset_z=-sample_radius,sample_radius do
							local weight_z=radius-math.abs(offset_z*spacing)
							weighted=weighted+
								horizontal[grid_z+offset_z][grid_x]*weight_z
						end
						local q=deterministic.qfrom_ratio(weighted,denominator)
						row[grid_x]=q
						digest_rows[#digest_rows+1]=canonical.array({
							canonical.signed(component_index),canonical.signed(grid_x),
							canonical.signed(grid_z),canonical.signed(q)})
					end
				end
			end
			difficulty_cache={spacing=spacing,radius=radius,
				min_grid_x=min_grid_x,max_grid_x=max_grid_x,
				min_grid_z=min_grid_z,max_grid_z=max_grid_z,values=values,
				digest=canonical.hex(raw_sha256(canonical.encode(
					canonical.array(digest_rows))))}
			return difficulty_cache
		end

		local difficulty=build_difficulty_lattice()
		local function difficulty_q_for_macro(x,z,macro_region)
			local component
			if macro_region == "wyrmglass_island" then component="wyrmglass_island"
			elseif macro_region == "stormscale_island" then
				component="stormscale_island"
			elseif macro_region == "elandor_mainland" or
					macro_region == "kragmar_mainland" or
					macro_region == "holy_grounds" then component="mainland" end
			if not component then return nil end
			local spacing=difficulty.spacing
			local ix=deterministic.floor_div(x,spacing)
			local iz=deterministic.floor_div(z,spacing)
			local tx=deterministic.qfrom_ratio(x-ix*spacing,spacing)
			local tz=deterministic.qfrom_ratio(z-iz*spacing,spacing)
			local rows=difficulty.values[component]
			local row0,row1=rows[iz],rows[iz+1]
			if not row0 or not row1 or not row0[ix] or not row0[ix+1] or
					not row1[ix] or not row1[ix+1] then return nil end
			local q0=deterministic.qlerp(row0[ix],row0[ix+1],tx)
			local q1=deterministic.qlerp(row1[ix],row1[ix+1],tx)
			return deterministic.qlerp(q0,q1,tz)
		end

		local function difficulty_q_at(x,z)
			local _,macro_region=classification_values_at(x,z)
			return difficulty_q_for_macro(x,z,macro_region)
		end

		local session = {}

		function session.warp_at(x, z)
			local warped_x, warped_z = warp(x,z)
			if not warped_x then return nil end
			return {x=warped_x,z=warped_z}
		end

		function session.warp_proof()
			return {cell=warp_proof.cell,maximum=warp_proof.maximum,
				max_horizontal_x=warp_proof.max_horizontal_x,
				max_horizontal_z=warp_proof.max_horizontal_z,
				max_vertical_x=warp_proof.max_vertical_x,
				max_vertical_z=warp_proof.max_vertical_z,
				min_x=query_bounds.min_x,max_x=query_bounds.max_x,
				min_z=query_bounds.min_z,max_z=query_bounds.max_z,
				min_ix=min_ix,max_ix=max_ix,min_iz=min_iz,max_iz=max_iz}
		end

		function session.classification_at(x, z)
			return classification_at(x,z)
		end

		function session.classification_values_at(x,z)
			return classification_values_at(x,z)
		end

		function session.coastal_core_member(core_id,x,z)
			integer(x,"coastal core x") integer(z,"coastal core z")
			local core=coastal_core_capsule_by_id[core_id]
			return core ~= nil and in_capsule(x,z,core,0) or false
		end

		function session.static_exclusion_values_at(x,z)
			integer(x,"static exclusion query x")
			integer(z,"static exclusion query z")
			if not in_rectangle(x,z,query_bounds,0) then return nil end
			return static_exclusion_values_at(x,z)
		end

		function session.power_owner_at(x,z,macro_region)
			integer(x,"power query x") integer(z,"power query z")
			if not zone_ids_by_region[macro_region] then return nil end
			local warped_x,warped_z,owner_x,owner_z=warp(x,z)
			if not warped_x then return nil end
			return owner_for_region(macro_region,warped_x,warped_z,nil,
				owner_x,owner_z)
		end

		function session.macro_region_at(x, z)
			return classification_at(x,z).macro_region
		end

		function session.land_at(x, z)
			return classification_at(x,z).water_class == "land"
		end

		function session.expanded_land_at(x, z, radius)
			integer(radius,"expanded land radius")
			if radius < 0 or radius > 512 then fail("expanded land radius differs") end
			local warped_x, warped_z = warp(x,z)
			if not warped_x then return false end
			return expanded_positive_at(x,z,warped_x,warped_z,radius) ~= nil
		end

		function session.water_class_at(x, z)
			return classification_at(x,z).water_class
		end

		function session.id_at(x, z)
			local numeric_id = classification_at(x,z).zone_numeric_id
			return numeric_id and source.zones[numeric_id].id or nil
		end

		function session.difficulty_target_at(x, z)
			local numeric_id=classification_at(x,z).zone_numeric_id
			local row=numeric_id and source.zones[numeric_id] or nil
			return row and row.difficulty_target or nil
		end

		function session.difficulty_q_at(x,z)
			integer(x,"difficulty query x") integer(z,"difficulty query z")
			return difficulty_q_at(x,z)
		end

		function session.difficulty_at(x,z)
			local value=session.difficulty_q_at(x,z)
			return value and deterministic.qround(value) or nil
		end

		function session.difficulty_for_macro_at(x,z,macro_region)
			integer(x,"difficulty query x") integer(z,"difficulty query z")
			local value=difficulty_q_for_macro(x,z,macro_region)
			return value and deterministic.qround(value) or nil
		end

		function session.difficulty_lattice_digest()
			return difficulty.digest
		end

		function session.neighbors(zone_id)
			local numeric_id
			if type(zone_id) == "number" then numeric_id=zone_id else
				for index = 1, #source.zones do
					if source.zones[index].id == zone_id then numeric_id=index break end
				end
			end
			if not numeric_id then return {} end
			local result = {}
			for index = 1, #source.routes do
				local row = source.routes[index]
				if row.zone_a == numeric_id then result[#result+1]=source.zones[row.zone_b].id
				elseif row.zone_b == numeric_id then result[#result+1]=source.zones[row.zone_a].id end
			end
			table.sort(result)
			return result
		end

		local function consider_paths(result, paths, kind, x, z)
			for index = 1, #paths do
				local row = paths[index]
				if not kind or kind == row.class or kind == row.kind or
						(kind == "land" and paths == source.routes) or
						(kind == "boat" and paths == source.boat_paths) then
					local points = row.centreline
					for segment = 1, #points-1 do
						local numerator,denominator = segment_distance_ratio(x,z,points[segment],
							points[segment+1])
						if not result.distance_numerator or
								rational_compare(numerator,denominator,
									result.distance_numerator,
									result.distance_denominator) < 0 then
							result.path=row result.segment=segment
							result.distance_numerator=numerator
							result.distance_denominator=denominator
						end
					end
				end
			end
		end

		function session.nearest_path_at(x, z, kind)
			integer(x,"path query x") integer(z,"path query z")
			if not in_rectangle(x,z,query_bounds,0) then return nil end
			local result = {}
			consider_paths(result,source.routes,kind,x,z)
			consider_paths(result,source.boat_paths,kind,x,z)
			consider_paths(result,source.island_routes,kind,x,z)
			return result.path and {path_id=result.path.id,class=result.path.class,
				kind=result.path.kind,segment=result.segment,
				distance_squared=result.distance_numerator/result.distance_denominator,
				distance_numerator=result.distance_numerator,
				distance_denominator=result.distance_denominator} or nil
		end

		function session.nearest_hydrology_at(x, z)
			integer(x,"hydrology query x") integer(z,"hydrology query z")
			if not in_rectangle(x,z,query_bounds,0) then return nil end
			local result = {}
			consider_paths(result,source.hydrology or {},nil,x,z)
			return result.path and {hydrology_id=result.path.id,
				segment=result.segment,
				distance_squared=result.distance_numerator/result.distance_denominator,
				distance_numerator=result.distance_numerator,
				distance_denominator=result.distance_denominator} or nil
		end

		function session.polyline_corridor_member(x,z,points,total_width)
			integer(x,"corridor query x") integer(z,"corridor query z")
			if type(points) ~= "table" or #points < 2 then
				fail("corridor point list differs")
			end
			integer(total_width,"corridor width")
			if total_width <= 0 or total_width > 256 then
				fail("corridor width differs")
			end
			return polyline_corridor_member(x,z,points,total_width)
		end

		function session.polyline_point_member(x,z,points)
			integer(x,"polyline point x") integer(z,"polyline point z")
			if type(points) ~= "table" or #points < 2 then return false end
			for index=1,#points-1 do
				if point_on_segment(x,z,points[index],points[index+1]) then return true end
			end
			return false
		end

		function session.polygon_member(x,z,points)
			integer(x,"polygon query x") integer(z,"polygon query z")
			if type(points) ~= "table" or #points < 3 then return false end
			return in_polygon(x,z,points)
		end

		function session.path_corridor_member(path_id,x,z)
			integer(x,"path corridor query x") integer(z,"path corridor query z")
			local path=path_by_id[path_id]
			if not path then return false end
			local width=path.corridor_width or path.width
			return polyline_corridor_member(x,z,path.centreline,width)
		end

		local anchor_by_id = {}
		for index = 1, #source.anchors do anchor_by_id[source.anchors[index].id]=source.anchors[index] end

		function session.selected_anchor_2d(zone_id, slot_id)
			local matches = {}
			for index = 1, #source.anchors do
				local row = source.anchors[index]
				local zone = source.zones[row.zone_numeric_id]
				if (zone_id == zone.id or zone_id == row.zone_numeric_id) and
						row.slot_id == slot_id then matches[#matches+1]=row end
			end
			if #matches == 0 then return nil end
			if #matches > 1 then fail("anchor slot query is ambiguous") end
			local row = matches[1]
			return {x=row.position.x,z=row.position.z,anchor_id=row.id,
				selection_mode=row.placement_mode == "authored_fixed" and
					"authored_fixed" or "frozen_layout",
				approved_candidate_index=row.approved_candidate_index}
		end

		function session.selected_anchor_by_id(anchor_id)
			local row = anchor_by_id[anchor_id]
			if not row then return nil end
			local zone = source.zones[row.zone_numeric_id]
			return session.selected_anchor_2d(zone.id,row.slot_id)
		end

		local housing_mask_by_id={}
		for index=1,#source.housing_masks do
			housing_mask_by_id[source.housing_masks[index].id]=source.housing_masks[index]
		end
		local function housing_mask_record_at(x, z)
			for index = 1, #source.housing_masks do
				local row = source.housing_masks[index]
				if in_polygon(x,z,row.polygon) then return row end
			end
			return nil
		end

		local function housing_point_valid_for_mask(mask,x,z)
			if not in_polygon(x,z,mask.polygon) then return false end
			local water_class,_,zone_numeric_id=classification_values_at(x,z)
			return water_class == "land" and
				zone_numeric_id == mask.zone_numeric_id and
				static_exclusion_values_at(x,z) == nil
		end

		function session.housing_mask_id_at(x, z)
			integer(x,"housing query x") integer(z,"housing query z")
			if not in_rectangle(x,z,query_bounds,0) then return nil end
			local row=housing_mask_record_at(x,z)
			return row and row.id or nil
		end

		function session.housing_point_valid_for_mask(mask_id,x,z)
			integer(x,"housing point x") integer(z,"housing point z")
			local mask=housing_mask_by_id[mask_id]
			if not mask or not in_rectangle(x,z,query_bounds,0) then return false end
			return housing_point_valid_for_mask(mask,x,z)
		end

		-- R2 packing uses the production hash grammar rather than reproducing it
		-- in an offline validator. The public ordinal is 1..16; the reviewed
		-- canonical domains remain housing-pack-00 through housing-pack-15.
		function session.housing_hash_priority(order_ordinal,mask_id,x,z)
			integer(order_ordinal,"housing hash order")
			integer(x,"housing hash x") integer(z,"housing hash z")
			if order_ordinal < 1 or
					order_ordinal > source.housing_policy.hash_order_count then
				fail("housing hash order differs")
			end
			if not housing_mask_by_id[mask_id] then
				fail("housing hash mask differs")
			end
			local domain=source.housing_policy.hash_domain_prefix ..
				("%02d"):format(order_ordinal-1)
			return housing_priority_word(domain,mask_id,x,z)
		end

		-- Exact squared-distance ratios for the three reviewed bias orders.
		-- All 100 actual anchor positions are included. Housing capacity is fixed
		-- by the approved layout and cannot depend on the world seed.
		function session.housing_bias_values_at(mask_id,x,z)
			integer(x,"housing bias x") integer(z,"housing bias z")
			local mask=housing_mask_by_id[mask_id]
			if not mask then fail("housing bias mask differs") end
			local edge_numerator,edge_denominator
			local previous=mask.polygon[#mask.polygon]
			for index=1,#mask.polygon do
				local current=mask.polygon[index]
				local numerator,denominator=segment_distance_ratio(
					x,z,previous,current)
				if not edge_numerator or rational_compare(numerator,denominator,
						edge_numerator,edge_denominator) < 0 then
					edge_numerator,edge_denominator=numerator,denominator
				end
				previous=current
			end
			local route={}
			consider_paths(route,source.routes,nil,x,z)
			local poi_numerator
			for index=1,#source.anchors do
				local anchor=source.anchors[index]
				local distance=squared_distance(x,z,
					anchor.position.x,anchor.position.z)
				if not poi_numerator or distance < poi_numerator then
					poi_numerator=distance
				end
			end
			return {
				edge_numerator=edge_numerator,edge_denominator=edge_denominator,
				route_numerator=route.distance_numerator,
				route_denominator=route.distance_denominator,
				poi_numerator=poi_numerator,poi_denominator=1,
			}
		end

		-- The dry-only predicate remains useful for diagnostics. R2's complete
		-- predicate below also rejects every compiled static exclusion.
		function session.housing_footprint_dry_at(x, z)
			integer(x,"housing query x") integer(z,"housing query z")
			if not in_rectangle(x,z,query_bounds,0) then return false end
			local mask = housing_mask_record_at(x,z)
			if not mask then return false end
			for dz = -50, 50 do
				for dx = -50, 50 do
					local px,pz=x+dx,z+dz
					local classification=classification_at(px,pz)
					if not in_polygon(px,pz,mask.polygon) or
							classification.water_class ~= "land" or
							classification.zone_numeric_id ~= mask.zone_numeric_id then
						return false
					end
				end
			end
			return true
		end

		function session.housing_eligible_at(x,z)
			integer(x,"housing query x") integer(z,"housing query z")
			if not in_rectangle(x,z,query_bounds,0) then return false end
			local mask=housing_mask_record_at(x,z)
			if not mask then return false end
			local radius=source.housing_policy.reservation_radius
			for dz=-radius,radius do
				for dx=-radius,radius do
					local px,pz=x+dx,z+dz
					if not housing_point_valid_for_mask(mask,px,pz) then
						return false
					end
				end
			end
			return true
		end

		local function text(value) return canonical.text(value or "") end
		local function signed(value) return canonical.signed(value or 0) end
		function session.canonical_kat()
			local rows = {}
			local proof=session.warp_proof()
			rows[#rows+1]=canonical.array({text("layout"),text(source.layout_id),
				text(source.layout_revision_id),
				text(difficulty.digest),signed(proof.cell),signed(proof.maximum),
				signed(proof.max_horizontal_x),signed(proof.max_horizontal_z),
				signed(proof.max_vertical_x),signed(proof.max_vertical_z),
				signed(proof.min_x),signed(proof.max_x),signed(proof.min_z),
				signed(proof.max_z)})
			rows[#rows+1]=canonical.array({text("housing_policy"),
				signed(source.housing_policy.reservation_width),
				signed(source.housing_policy.reservation_radius),
				signed(source.housing_policy.minimum_gap),
				signed(source.housing_policy.lattice_spacing),
				signed(source.housing_policy.hash_order_count),
				text(source.housing_policy.hash_domain_prefix),
				text(source.housing_policy.hash_order_numbering),
				text(source.housing_policy.conflict_rule),
				text(source.housing_policy.tie_break),
				text(source.housing_policy.bias_direction),
				text(source.housing_policy.edge_bias_scope),
				text(source.housing_policy.route_bias_scope),
				text(source.housing_policy.poi_bias_scope)})
			for index = 1, #source.zones do
				local zone = source.zones[index]
				local classification = classification_at(zone.hub.x,zone.hub.z)
				rows[#rows+1] = canonical.array({text("hub"),signed(index),
					signed(classification.zone_numeric_id or 0),
					text(classification.water_class)})
			end
			for index=1,#source.anchors do
				local selected=session.selected_anchor_by_id(source.anchors[index].id)
				rows[#rows+1]=canonical.array({text("anchor"),signed(index),
					text(selected.selection_mode),
					signed(selected.approved_candidate_index),signed(selected.x),
					signed(selected.z)})
			end
			for _, coordinates in ipairs({{-3600,-3200},{0,0},{3600,3200}}) do
				local warped_x,warped_z=warp(coordinates[1],coordinates[2])
				rows[#rows+1]=canonical.array({text("warp"),signed(coordinates[1]),
					signed(coordinates[2]),signed(warped_x or 0),signed(warped_z or 0)})
			end
			for index=1,#source.bays do
				local bay=source.bays[index]
				rows[#rows+1]=canonical.array({text("bay"),signed(index),
					text(bay.id),text(bay.deep_ocean_side),
					signed(bay.deep_ocean_cut_z)})
			end
			for index = 1, #source.routes do
				local route = source.routes[index]
				rows[#rows+1]=canonical.array({text("route_record"),signed(index),
					text(route.id),text(route.class),text(route.kind),
					signed(route.zone_a),signed(route.zone_b),
					text(route.station_a_id),text(route.station_b_id),
					signed(route.surface_width),signed(route.corridor_width)})
				for point_index=1,#route.centreline do
					local route_point=route.centreline[point_index]
					local classification=classification_at(route_point.x,route_point.z)
					rows[#rows+1]=canonical.array({text("route"),signed(index),
						signed(point_index),signed(route_point.x),signed(route_point.z),
						signed(classification.zone_numeric_id or 0),
						text(classification.water_class)})
				end
			end
			for index=1,#source.crossing_interfaces do
				local crossing=source.crossing_interfaces[index]
				rows[#rows+1]=canonical.array({text("crossing"),signed(index),
					text(crossing.id),text(crossing.route_id),text(crossing.kind),
					signed(crossing.position.x),signed(crossing.position.z)})
			end
			for _, collection in ipairs({source.boat_paths,source.island_routes}) do
				for index=1,#collection do
					local path=collection[index]
					rows[#rows+1]=canonical.array({text("water_graph_path"),
						text(path.id),text(path.kind),signed(path.width or 0),
						signed(path.from_zone or 0),signed(path.to_zone or 0)})
					for point_index=1,#path.centreline do
						local point=path.centreline[point_index]
						rows[#rows+1]=canonical.array({text("water_graph_point"),
							text(path.id),signed(point_index),signed(point.x),signed(point.z)})
					end
				end
			end
			for index=1,#source.capital_ingresses do
				local ingress=source.capital_ingresses[index]
				rows[#rows+1]=canonical.array({text("capital_ingress"),
					signed(index),text(ingress.id),text(ingress.capital_anchor_id),
					signed(ingress.total_width),text(ingress.route_ids[1]),
					text(ingress.route_ids[2])})
			end
			for index=1,#source.hydrology do
				local reach=source.hydrology[index]
				for point_index=1,#reach.centreline do
					local water_point=reach.centreline[point_index]
					local classification=classification_at(water_point.x,water_point.z)
					rows[#rows+1]=canonical.array({text("hydrology"),signed(index),
						signed(point_index),signed(water_point.x),signed(water_point.z),
						signed(water_point.half_width),
						signed(classification.zone_numeric_id or 0),
						text(classification.water_class)})
				end
			end
			for z = source.extent.min_z, source.extent.max_z, 512 do
				for x = source.extent.min_x, source.extent.max_x, 512 do
					local classification = classification_at(x,z)
					rows[#rows+1] = canonical.array({text("grid"),signed(x),signed(z),
						signed(classification.zone_numeric_id or 0),
						text(classification.water_class)})
				end
			end
			return canonical.encode(canonical.array(rows))
		end

		function session.canonical_kat_digest()
			return canonical.hex(raw_sha256(session.canonical_kat()))
		end

		return session
	end

	return module
end
