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
	local MAX_SAFE = 9007199254740991

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
		local center_x, center_z = (min_x + max_x) / 2, (min_z + max_z) / 2
		local half_x, half_z = (max_x - min_x) / 2, (max_z - min_z) / 2
		local dx = math.max(math.abs(x - center_x) - (half_x - radius), 0)
		local dz = math.max(math.abs(z - center_z) - (half_z - radius), 0)
		return dx * dx + dz * dz <= radius * radius
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

	local function rational_compare(a, b, c, d)
		local direction=1
		while true do
			local left=math.floor(a/b)
			local right=math.floor(c/d)
			if left < right then return -direction end
			if left > right then return direction end
			local left_remainder=a%b
			local right_remainder=c%d
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

	local function segment_distance_squared(x, z, a, b)
		local vx, vz = b.x - a.x, b.z - a.z
		local length_squared = vx * vx + vz * vz
		if length_squared == 0 then
			return squared_distance(x,z,a.x,a.z)
		end
		local t = ((x-a.x)*vx + (z-a.z)*vz) / length_squared
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		local dx = x - (a.x + vx*t)
		local dz = z - (a.z + vz*t)
		return dx*dx + dz*dz
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

	local function closed_pair(a, b)
		if a > b then a, b = b, a end
		return tostring(a) .. ":" .. tostring(b)
	end

	local function validate_source()
		if source.schema ~= schemas.simple_map_source or
				schemas.simple_map ~= "grug_wp40_simple_map_v1" or
				source.layout_id ~= "wp40-simple-map-v1d" then
			fail("source schema/layout identity differs")
		end
		if source.warp.cell ~= 256 or source.warp.maximum ~= 60 or
				type(source.warp.hash_domain) ~= "string" or
				4*source.warp.maximum >= source.warp.cell then
			fail("warp identity/no-fold bound differs")
		end
		local expected_counts = {
			zones=38,land_primitives=14,bays=4,islands=2,channels=2,routes=57,
			allowed_contacts=61,crossing_interfaces=7,boat_paths=4,
			route_stations=38,island_routes=8,housing_masks=10,
			coastal_housing_cores=4,
			capital_ingresses=6,
			anchors=100,poi_spurs=74,apex_sockets=24,region_resources=6,
			relief_profiles=6,anchor_profiles=17,landmarks=70,
			hydrology_profiles=11,hydrology_transition_profiles=6,
			hydrology=25,hydrology_interfaces=10,
			hard_protection_recipes=4,hard_protection=42,
			claim_exclusion_recipes=5,claim_exclusions=482,
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
		local function validate_tapered_centreline(row,label)
			if dense_count(row.centreline,label .. " centreline") < 2 then
				fail(label .. " centreline is too short")
			end
			for sample_index=1,#row.centreline do
				local sample=row.centreline[sample_index]
				integer(sample.x,label .. " x") integer(sample.z,label .. " z")
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
		end
		for index=1,#source.bays do
			local row=source.bays[index]
			if not ordinary_regions[row.region] or #row.shore_zone_ids < 2 then
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
			channel_ids[row.id]=true
		end
		local station_ids={}
		for index=1,#source.route_stations do
			local row=source.route_stations[index]
			if station_ids[row.id] or not source.zones[row.zone_numeric_id] then
				fail("route station identity/reference differs at " .. index)
			end
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
		local contact_pairs = {}
		for index = 1, #source.allowed_contacts do
			local row = source.allowed_contacts[index]
			local key = closed_pair(row.zone_a,row.zone_b)
			if contact_pairs[key] then fail("duplicate allowed contact " .. key) end
			contact_pairs[key] = true
			if not source.zones[row.zone_a] or not source.zones[row.zone_b] or
					(index <= 57 and (not route_pairs[key] or
					row.route_id ~= route_pairs[key])) then
				fail("route contact prefix differs at " .. index)
			end
		end
		local crossing_ids={}
		for index = 1, #source.crossing_interfaces do
			local row=source.crossing_interfaces[index]
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
			if crossing_ids[row.id] or not route or not pinned then
				fail("crossing route reference differs")
			end
			crossing_ids[row.id]=true
		end
		local boat_ids, boat_pair_counts={},{}
		for index=1,#source.boat_paths do
			local row=source.boat_paths[index]
			if boat_ids[row.id] or row.kind ~= "boat" or row.width ~= 96 or
					not source.zones[row.from_zone] or not source.zones[row.to_zone] or
					dense_count(row.centreline,"boat centreline") < 2 then
				fail("boat path identity/reference differs at " .. index)
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
		collect_ids(source.island_routes,"island route")
		for index=1,#source.island_routes do
			if source.island_routes[index].kind ~= "road" then
				fail("island route kind differs at " .. index)
			end
		end
		local fixed_count, candidate_count = 0, 0
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
			if row.placement_mode == "fixed" then
				fixed_count = fixed_count + 1
				if not row.position then fail("fixed anchor has no position") end
			elseif row.placement_mode == "candidate_set" then
				candidate_count = candidate_count + 1
				if dense_count(row.candidates,"anchor candidates") ~= 3 then
					fail("anchor candidate count differs")
				end
			else fail("unknown anchor placement mode") end
			if index <= 12 then
				local expected_slot=index <= 6 and "start" or "capital"
				if row.placement_mode ~= "fixed" or row.slot_id ~= expected_slot or
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
		if fixed_count ~= 16 or candidate_count ~= 84 then
			fail("fixed/candidate anchor counts differ")
		end
		local spur_ids={}
		for index = 1, #source.poi_spurs do
			local row = source.poi_spurs[index]
			if spur_ids[row.id] or not anchor_ids[row.anchor_id] or
					#row.candidate_paths ~= 3 then
				fail("POI spur binding differs")
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
		for index=1,#source.hydrology_interfaces do
			local row=source.hydrology_interfaces[index]
			local upper=row.upper_id and hydrology_ids[row.upper_id] or nil
			local lower=row.lower_id and hydrology_ids[row.lower_id] or nil
			if not transition_profile_ids[row.transition_profile_id] or
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
	local layout_hash=deterministic.new_hash(canonical,raw_sha256,
		schemas.simple_map,"0")

	function module.new(full_seed_string)
		local hash = deterministic.new_hash(canonical,raw_sha256,
			schemas.simple_map,full_seed_string)
		local cell = source.warp.cell
		local maximum = source.warp.maximum
		local lattice = {}
		local query_bounds={
			min_x=source.extent.min_x-source.shelf_width-maximum,
			max_x=source.extent.max_x+source.shelf_width+maximum,
			min_z=source.extent.min_z-source.shelf_width-maximum,
			max_z=source.extent.max_z+source.shelf_width+maximum,
		}
		local min_ix = deterministic.floor_div(query_bounds.min_x,cell)-1
		local max_ix = deterministic.floor_div(query_bounds.max_x,cell)+1
		local min_iz = deterministic.floor_div(query_bounds.min_z,cell)-1
		local max_iz = deterministic.floor_div(query_bounds.max_z,cell)+1
		local function vector_at(ix, iz)
			local row = lattice[iz]
			if not row then row={} lattice[iz]=row end
			local value = row[ix]
			if value then return value end
			local span = 2*maximum+1
			value = {
				x=layout_hash.range(source.warp.hash_domain,source.layout_id,
					{ix,iz},0,0,span)-maximum,
				z=layout_hash.range(source.warp.hash_domain,source.layout_id,
					{ix,iz},0,1,span)-maximum,
			}
			row[ix] = value
			return value
		end
		for iz = min_iz, max_iz do
			for ix = min_ix, max_ix do vector_at(ix,iz) end
		end
		for iz=min_iz,max_iz do
			for ix=min_ix,max_ix do
				local value=vector_at(ix,iz)
				if math.abs(value.x) > maximum or math.abs(value.z) > maximum then
					fail("warp lattice displacement exceeds maximum")
				end
				if ix < max_ix then
					local neighbor=vector_at(ix+1,iz)
					if math.abs(value.x-neighbor.x) > 2*maximum or
							math.abs(value.z-neighbor.z) > 2*maximum then
						fail("warp horizontal adjacent-vector bound differs")
					end
				end
				if iz < max_iz then
					local neighbor=vector_at(ix,iz+1)
					if math.abs(value.x-neighbor.x) > 2*maximum or
							math.abs(value.z-neighbor.z) > 2*maximum then
						fail("warp vertical adjacent-vector bound differs")
					end
				end
			end
		end

		local function warp(x, z)
			integer(x,"query x") integer(z,"query z")
			if not in_rectangle(x,z,query_bounds,0) then return nil end
			local ix = math.floor(x/cell)
			local iz = math.floor(z/cell)
			if ix < min_ix or ix >= max_ix or iz < min_iz or iz >= max_iz then
				return nil
			end
			local tx = math.floor(((x-ix*cell)*Q+
				math.floor(cell/2))/cell)
			local tz = math.floor(((z-iz*cell)*Q+
				math.floor(cell/2))/cell)
			local v00,v10 = vector_at(ix,iz),vector_at(ix+1,iz)
			local v01,v11 = vector_at(ix,iz+1),vector_at(ix+1,iz+1)
			local dx0 = deterministic.qlerp(v00.x,v10.x,tx)
			local dx1 = deterministic.qlerp(v01.x,v11.x,tx)
			local dz0 = deterministic.qlerp(v00.z,v10.z,tx)
			local dz1 = deterministic.qlerp(v01.z,v11.z,tx)
			return x+deterministic.qlerp(dx0,dx1,tz),
				z+deterministic.qlerp(dz0,dz1,tz)
		end

		local warped_hubs = {}
		for index = 1, #source.zones do
			local row = source.zones[index]
			local x,z = warp(row.hub.x,row.hub.z)
			warped_hubs[index] = {x=x,z=z}
		end

		local function fixed_owner_at(x, z, expansion)
			expansion = expansion or 0
			for group_index = 1, #fixed_core_groups do
				local group=fixed_core_groups[group_index]
				if z >= group.z-group.half_z-expansion and
						z <= group.z+group.half_z+expansion then
					for core_index = 1, #group.cores do
						local core=group.cores[core_index]
						if x >= core.x-core.half_x-expansion and
								x <= core.x+core.half_x+expansion then
							return core.zone_numeric_id
						end
					end
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

		local function hydrology_at(x, z, civic_core_zone_numeric_id)
			local grid_row=hydrology_grid[math.floor(z/hydrology_cell)]
			local candidates=grid_row and
				grid_row[math.floor(x/hydrology_cell)] or nil
			if not candidates then return nil end
			for index=1,#candidates do
				local row=candidates[index]
				if (not civic_core_zone_numeric_id or
						row.civic_core_zone_numeric_id == civic_core_zone_numeric_id) and
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
			local candidate_region = warped_z < 0 and "elandor_mainland" or
				"kragmar_mainland"
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
			local candidate_region = warped_z < 0 and "elandor_mainland" or
				"kragmar_mainland"
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

		local function owner_for_region(region, x, z, candidate_ids)
			local best_id, best_score
			local ids = candidate_ids or zone_ids_by_region[region]
			for candidate_index = 1, #ids do
				local index = ids[candidate_index]
				local zone = source.zones[index]
				if zone.macro_region == region then
					local hub = warped_hubs[index]
					local score = squared_distance(x,z,hub.x,hub.z)-zone.bias
					if not best_score or score < best_score or
							(score == best_score and index < best_id) then
						best_id,best_score = index,score
					end
				end
			end
			return best_id
		end

		local function classification_at(x, z)
			local warped_x, warped_z = warp(x,z)
			if not warped_x then return {water_class="deep_ocean"} end
			local fixed_owner = fixed_owner_at(x,z,0)
			if fixed_owner then
				local civic_hydrology=hydrology_at(x,z,fixed_owner)
				if civic_hydrology then
					local zone=source.zones[fixed_owner]
					return {water_class="planned_water",macro_region=zone.macro_region,
						zone_numeric_id=fixed_owner,
						hydrology_id=civic_hydrology.id,fixed=true,civic_water=true}
				end
				return {water_class="land",macro_region=source.zones[fixed_owner].macro_region,
					zone_numeric_id=fixed_owner,fixed=true}
			end
			local exact_holy=in_rectangle(x,z,source.holy_grounds,0)
			if not exact_holy then
				local bay = bay_at(warped_x,warped_z)
				if bay then
					local owner = owner_for_region(bay.region,warped_x,warped_z,
						bay.shore_zone_ids)
					return {water_class="planned_water",macro_region=bay.region,
						zone_numeric_id=owner,bay_id=bay.id}
				end
			end
			local region = exact_holy and "holy_grounds" or
				ordinary_region_at(warped_x,warped_z)
			if region then
				local hydrology=hydrology_at(x,z)
				if hydrology then
					local zone=source.zones[hydrology.zone_numeric_id]
					return {water_class="planned_water",macro_region=zone.macro_region,
						zone_numeric_id=zone.numeric_id,hydrology_id=hydrology.id}
				end
				local owner = owner_for_region(region,warped_x,warped_z)
				return {water_class="land",macro_region=region,
					zone_numeric_id=owner,fixed=exact_holy or nil}
			end
			local channel = channel_at(x,z)
			if channel then
				return {water_class="immutable_dragon_channel",channel_id=channel.id}
			end
			local shelf_region=expanded_positive_at(x,z,warped_x,warped_z,
				source.shelf_width)
			if shelf_region then
				local owner=owner_for_region(shelf_region,warped_x,warped_z)
				return {water_class="coastal_shelf",macro_region=shelf_region,
					zone_numeric_id=owner}
			end
			return {water_class="deep_ocean"}
		end

		local session = {}

		function session.warp_at(x, z)
			local warped_x, warped_z = warp(x,z)
			if not warped_x then return nil end
			return {x=warped_x,z=warped_z}
		end

		function session.classification_at(x, z)
			return classification_at(x,z)
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
						local distance = segment_distance_squared(x,z,points[segment],
							points[segment+1])
						if not result.distance_squared or
								distance < result.distance_squared then
							result.path=row result.segment=segment
							result.distance_squared=distance
						end
					end
				end
			end
		end

		function session.nearest_path_at(x, z, kind)
			integer(x,"path query x") integer(z,"path query z")
			local result = {}
			consider_paths(result,source.routes,kind,x,z)
			consider_paths(result,source.boat_paths,kind,x,z)
			consider_paths(result,source.island_routes,kind,x,z)
			return result.path and {path_id=result.path.id,class=result.path.class,
				kind=result.path.kind,segment=result.segment,
				distance_squared=result.distance_squared} or nil
		end

		function session.nearest_hydrology_at(x, z)
			integer(x,"hydrology query x") integer(z,"hydrology query z")
			local result = {}
			consider_paths(result,source.hydrology or {},nil,x,z)
			return result.path and {hydrology_id=result.path.id,
				segment=result.segment,distance_squared=result.distance_squared} or nil
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
			if row.position then return {x=row.position.x,z=row.position.z,
				anchor_id=row.id,candidate_index=0} end
			local base = row.candidates[1]
			local selected = hash.range("anchor-select",source.layout_id..":"..row.id,
				{base.x,base.z},0,0,#row.candidates)+1
			local position = row.candidates[selected]
			return {x=position.x,z=position.z,anchor_id=row.id,
				candidate_index=selected}
		end

		function session.selected_anchor_by_id(anchor_id)
			local row = anchor_by_id[anchor_id]
			if not row then return nil end
			local zone = source.zones[row.zone_numeric_id]
			return session.selected_anchor_2d(zone.id,row.slot_id)
		end

		local function housing_mask_record_at(x, z)
			for index = 1, #source.housing_masks do
				local row = source.housing_masks[index]
				if in_polygon(x,z,row.polygon) then return row end
			end
			return nil
		end

		function session.housing_mask_id_at(x, z)
			integer(x,"housing query x") integer(z,"housing query z")
			local row=housing_mask_record_at(x,z)
			return row and row.id or nil
		end

		-- R1 exposes only the pre-freeze geometric footprint check. R2 compiles
		-- every static exclusion into the final housing_eligible_at predicate.
		function session.housing_footprint_dry_at(x, z)
			integer(x,"housing query x") integer(z,"housing query z")
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

		local function text(value) return canonical.text(value or "") end
		local function signed(value) return canonical.signed(value or 0) end
		function session.canonical_kat()
			local rows = {}
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
					signed(selected.candidate_index),signed(selected.x),signed(selected.z)})
			end
			for _, coordinates in ipairs({{-3600,-3200},{0,0},{3600,3200}}) do
				local warped_x,warped_z=warp(coordinates[1],coordinates[2])
				rows[#rows+1]=canonical.array({text("warp"),signed(coordinates[1]),
					signed(coordinates[2]),signed(warped_x or 0),signed(warped_z or 0)})
			end
			for index = 1, #source.routes do
				local route = source.routes[index]
				for point_index=1,#route.centreline do
					local route_point=route.centreline[point_index]
					local classification=classification_at(route_point.x,route_point.z)
					rows[#rows+1]=canonical.array({text("route"),signed(index),
						signed(point_index),signed(route_point.x),signed(route_point.z),
						signed(classification.zone_numeric_id or 0),
						text(classification.water_class)})
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
