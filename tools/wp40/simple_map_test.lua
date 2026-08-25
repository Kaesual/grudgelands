local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local mode = arg[3] or "--kat"
local seed = arg[4] or "0"
assert(mode == "--kat" or mode == "--full", "expected --kat or --full")

local loaded = dofile(repo .. "/tools/wp40/simple_map_offline.lua")(
	repo,scratch,seed)
local source, session = loaded.source, loaded.session

assert(loaded.module.validate_source())
assert(#source.zones == 38 and #source.routes == 57 and
	#source.allowed_contacts == 61 and #source.anchors == 100 and
	#source.relief_profiles == 6 and #source.landmarks == 70 and
	#source.hydrology == 25 and #source.capital_ingresses == 6 and
	#source.hard_protection == 42 and
	#source.claim_exclusions == 482)

local route_classes = {primary=0,secondary=0,trail=0}
for index = 1, #source.routes do
	local row = source.routes[index]
	assert(row.kind == (row.class == "trail" and "trail" or "road"))
	route_classes[row.class] = route_classes[row.class] + 1
end
assert(route_classes.primary == 30 and route_classes.secondary == 24 and
	route_classes.trail == 3)
assert(session.nearest_path_at(0,-2500,"road").kind == "road")
assert(session.nearest_path_at(0,-125,"trail").kind == "trail")
assert(session.nearest_path_at(-2700,-125,"boat").kind == "boat")
for index=1,#source.capital_ingresses do
	local ingress=source.capital_ingresses[index]
	assert(ingress.total_width == 128 and #ingress.route_ids == 2)
end

for index = 1, #source.zones do
	local zone = source.zones[index]
	assert(session.id_at(zone.hub.x,zone.hub.z) == zone.id,
		"zone hub does not own itself: " .. zone.id)
end

-- The bay masks must not expose the fixed-core precedence as a rectangular
-- shoreline. Keep one visible 16-node bay-free ring around every start core;
-- separately declared civic hydrology may still enter that ring.
for index=1,6 do
	local position=source.anchors[index].position
	local half_x=source.start_core.width_x/2+16
	local half_z=source.start_core.width_z/2+16
	local function assert_no_bay(x,z)
		assert(session.classification_at(x,z).bay_id == nil)
	end
	for offset=-source.start_core.width_x/2,
			source.start_core.width_x/2,16 do
		assert_no_bay(position.x+offset,position.z-half_z)
		assert_no_bay(position.x+offset,position.z+half_z)
	end
	for offset=-source.start_core.width_z/2,
			source.start_core.width_z/2,16 do
		assert_no_bay(position.x-half_x,position.z+offset)
		assert_no_bay(position.x+half_x,position.z+offset)
	end
end

local expected_samples = {
	{0,0,"land",true},
	{-3150,0,"land","front_wyrmglass_crown"},
	{3150,0,"land","front_stormscale_summit"},
	{-2700,0,"immutable_dragon_channel",false},
	{2700,0,"immutable_dragon_channel",false},
	{0,-3200,"deep_ocean",false},
	{0,3200,"deep_ocean",false},
	{-980,-2500,"planned_water",true},
	{900,-2500,"planned_water",true},
}
local sample_mismatches={}
for index = 1, #expected_samples do
	local row = expected_samples[index]
	local water_class=session.water_class_at(row[1],row[2])
	local id = session.id_at(row[1],row[2])
	local id_matches
	if type(row[4]) == "string" then id_matches=id == row[4]
	elseif row[4] == false then id_matches=id == nil
	else id_matches=type(id) == "string" end
	if water_class ~= row[3] or not id_matches then
		sample_mismatches[#sample_mismatches+1]=("%d:%s:%s"):format(
			index,water_class,id or "-")
	end
end

-- V1d keeps the exact Holy Grounds macro rectangle, but the warped mainland
-- fronts overlap behind its long north/south edges between the channel-corner
-- transitions. Any water there must be an explicitly authored hydrology mask,
-- never an accidental shelf/ocean seam.
for _, z in ipairs({-251,251}) do
	for x=-2400,2400,32 do
		local classification=session.classification_at(x,z)
		assert(classification.water_class == "land" or
			(classification.water_class == "planned_water" and
				type(classification.hydrology_id) == "string"),
			"unintended Holy Grounds edge seam")
	end
end

local outside_x=source.extent.max_x+source.shelf_width+source.warp.maximum+1
assert(session.water_class_at(outside_x,0) == "deep_ocean" and
	session.id_at(outside_x,0) == nil and session.warp_at(outside_x,0) == nil)
for z=source.extent.min_z,source.extent.max_z,512 do
	for x=source.extent.min_x,source.extent.max_x,512 do
		local warped=session.warp_at(x,z)
		assert(warped and math.abs(warped.x-x) <= source.warp.maximum and
			math.abs(warped.z-z) <= source.warp.maximum)
	end
end

local hydrology_sample=session.nearest_hydrology_at(-400,-1500)
local hydrology_sample_ok=hydrology_sample and
	hydrology_sample.hydrology_id == "hydro_whitebridge_main" and
	hydrology_sample.distance_squared == 0

for index = 1, #source.anchors do
	local row = source.anchors[index]
	local selected = session.selected_anchor_by_id(row.id)
	assert(selected and selected.anchor_id == row.id)
	if row.position then
		assert(selected.candidate_index == 0 and selected.x == row.position.x and
			selected.z == row.position.z)
	else
		assert(selected.candidate_index >= 1 and selected.candidate_index <= 3)
		local candidate = row.candidates[selected.candidate_index]
		assert(selected.x == candidate.x and selected.z == candidate.z)
	end
end

local digest = session.canonical_kat_digest()
assert(digest:match("^[0-9a-f]+$") and #digest == 64)
print("kat\t" .. digest)

if mode == "--full" then
	local function find_root(parent,index)
		local root=index
		while parent[root] ~= root do root=parent[root] end
		while parent[index] ~= index do
			local next_index=parent[index]
			parent[index]=root
			index=next_index
		end
		return root
	end
	local function union(parent,a,b)
		local root_a=find_root(parent,a)
		local root_b=find_root(parent,b)
		if root_a ~= root_b then parent[root_b]=root_a end
	end
	local water_counts = {land=0,planned_water=0,coastal_shelf=0,
		deep_ocean=0,immutable_dragon_channel=0}
	local sampled_zone = {}
	local step = 16
	local previous_row = {}
	local previous_land_indices={}
	local contacts = {}
	local land_parent,zone_parent,node_zone={},{},{}
	local grid_index=0
	for z = source.extent.min_z, source.extent.max_z, step do
		local current_row = {}
		local current_land_indices={}
		local column = 0
		for x = source.extent.min_x, source.extent.max_x, step do
			column = column + 1
			grid_index=grid_index+1
			local classification = session.classification_at(x,z)
			water_counts[classification.water_class] =
				water_counts[classification.water_class] + 1
			local zone_id = classification.water_class == "land" and
				(classification.zone_numeric_id or 0) or 0
			current_row[column] = zone_id
			if zone_id ~= 0 then
				sampled_zone[zone_id]=(sampled_zone[zone_id] or 0)+1
				land_parent[grid_index]=grid_index
				zone_parent[grid_index]=grid_index
				node_zone[grid_index]=zone_id
				current_land_indices[column]=grid_index
				local left_index=current_land_indices[column-1]
				local down_index=previous_land_indices[column]
				if left_index then
					union(land_parent,grid_index,left_index)
					if node_zone[left_index] == zone_id then
						union(zone_parent,grid_index,left_index)
					end
				end
				if down_index then
					union(land_parent,grid_index,down_index)
					if node_zone[down_index] == zone_id then
						union(zone_parent,grid_index,down_index)
					end
				end
			end
			local left = current_row[column-1] or 0
			local down = previous_row[column] or 0
			for _, other in ipairs({left,down}) do
				if zone_id ~= 0 and other ~= 0 and zone_id ~= other then
					local a,b=zone_id,other if a>b then a,b=b,a end
					contacts[a..":"..b]=true
				end
			end
		end
		previous_row = current_row
		previous_land_indices=current_land_indices
	end
	local missing_zones={}
	for index = 1, #source.zones do
		if not sampled_zone[index] then
			missing_zones[#missing_zones+1]=source.zones[index].id
		end
	end
	local allowed = {}
	for index = 1, #source.allowed_contacts do
		local row = source.allowed_contacts[index]
		local a,b=row.zone_a,row.zone_b if a>b then a,b=b,a end
		allowed[a..":"..b]=true
	end
	local forbidden = {}
	for key in pairs(contacts) do
		if not allowed[key] then forbidden[#forbidden+1]=key end
	end
	table.sort(forbidden)
	local land_roots,zone_roots={},{}
	for index in pairs(land_parent) do
		land_roots[find_root(land_parent,index)]=true
		local zone_id=node_zone[index]
		local roots=zone_roots[zone_id]
		if not roots then roots={} zone_roots[zone_id]=roots end
		roots[find_root(zone_parent,index)]=true
	end
	local land_components=0
	for _ in pairs(land_roots) do land_components=land_components+1 end
	local disconnected_zones=0
	for zone_id=1,#source.zones do
		local count=0
		for _ in pairs(zone_roots[zone_id] or {}) do count=count+1 end
		if count ~= 1 then disconnected_zones=disconnected_zones+1 end
	end

	local route_interface_by_id={}
	for index=1,#source.crossing_interfaces do
		local row=source.crossing_interfaces[index]
		route_interface_by_id[row.id]=row
	end
	local declared_crossing={}
	for index=1,#source.hydrology_interfaces do
		local row=source.hydrology_interfaces[index]
		local interface=row.route_interface_id and
			route_interface_by_id[row.route_interface_id] or nil
		if interface and row.hydrology_id then
			declared_crossing[interface.route_id..":"..row.hydrology_id]=true
		end
	end
	local route_samples, route_off_land, route_declared_water = 0, 0, 0
	for index = 1, #source.routes do
		local route = source.routes[index]
		for segment = 1, #route.centreline-1 do
			local a,b=route.centreline[segment],route.centreline[segment+1]
			local dx,dz=b.x-a.x,b.z-a.z
			local length=math.sqrt(dx*dx+dz*dz)
			local count=math.max(1,math.ceil(length/8))
			for sample = 0, count do
				local x=math.floor(a.x+dx*sample/count+0.5)
				local z=math.floor(a.z+dz*sample/count+0.5)
				route_samples=route_samples+1
				local classification=session.classification_at(x,z)
				if classification.water_class ~= "land" then
					local key=classification.hydrology_id and
						route.id..":"..classification.hydrology_id or ""
					if declared_crossing[key] then
						route_declared_water=route_declared_water+1
					else route_off_land=route_off_land+1 end
				end
			end
		end
	end
	local bay_sample_failures=0
	for index=1,#source.bays do
		for sample_index=1,#source.bays[index].centreline do
			local sample=source.bays[index].centreline[sample_index]
			local visible_x=math.max(source.extent.min_x,
				math.min(source.extent.max_x,sample.x))
			local visible_z=math.max(source.extent.min_z,
				math.min(source.extent.max_z,sample.z))
			if session.water_class_at(visible_x,visible_z) ~= "planned_water" then
				bay_sample_failures=bay_sample_failures+1
			end
		end
	end
	local channel_interior_failures=0
	for index=1,#source.channels do
		local polygon=source.channels[index].polygon
		local min_x,max_x=polygon[1].x,polygon[1].x
		local min_z,max_z=polygon[1].z,polygon[1].z
		for point_index=2,#polygon do
			min_x=math.min(min_x,polygon[point_index].x)
			max_x=math.max(max_x,polygon[point_index].x)
			min_z=math.min(min_z,polygon[point_index].z)
			max_z=math.max(max_z,polygon[point_index].z)
		end
		for z=min_z+1,max_z-1,16 do
			for x=min_x+1,max_x-1,16 do
				if session.water_class_at(x,z) ~= "immutable_dragon_channel" then
					channel_interior_failures=channel_interior_failures+1
				end
			end
		end
	end

	local candidate_total, candidate_same_zone = 0, 0
	for index = 1, #source.anchors do
		local row=source.anchors[index]
		if row.candidates then
			for candidate_index=1,#row.candidates do
				local point=row.candidates[candidate_index]
				candidate_total=candidate_total+1
				if session.id_at(point.x,point.z)==source.zones[row.zone_numeric_id].id then
					candidate_same_zone=candidate_same_zone+1
				end
			end
		end
	end

	local benchmark_times = {}
	for repetition = 1, 9 do
		local started = os.clock()
		local checksum = 0
		for row = 0, 79 do
			local z = source.extent.min_z + math.floor(
				(source.extent.max_z-source.extent.min_z)*row/79)
			for column = 0, 79 do
				local x = source.extent.min_x + math.floor(
					(source.extent.max_x-source.extent.min_x)*column/79)
				local classification = session.classification_at(x,z)
				checksum = checksum + (classification.zone_numeric_id or 0)
			end
		end
		assert(checksum > 0)
		benchmark_times[repetition] = (os.clock()-started)*1000
	end
	table.sort(benchmark_times)
	local benchmark_median = benchmark_times[5]

	print(("full\tgrid_step=%d land=%d planned=%d shelf=%d channel=%d deep=%d"):format(
		step,water_counts.land,water_counts.planned_water,
		water_counts.coastal_shelf,water_counts.immutable_dragon_channel,
		water_counts.deep_ocean))
	print(("advisory\tland_components=%d disconnected_zones=%d missing_zones=%d forbidden_contacts=%d route_off_land=%d/%d declared_water=%d anchor_same_zone=%d/%d bay_samples_failed=%d channel_interior_failed=%d sample_mismatches=%d hydrology_sample_failed=%d"):format(
		land_components,disconnected_zones,#missing_zones,#forbidden,
		route_off_land,route_samples,
		route_declared_water,candidate_same_zone,candidate_total,
		bay_sample_failures,channel_interior_failures,#sample_mismatches,
		hydrology_sample_ok and 0 or 1))
	local benchmark_interpreter=rawget(_G,"jit") and "luajit" or "puc51"
	print(("benchmark\tclassifier_80x80_median_ms=%.3f interpreter=%s status=advisory"):format(
		benchmark_median,benchmark_interpreter))
	if #forbidden > 0 then
		print("advisory_forbidden\t" .. table.concat(forbidden,","))
	end
	if #missing_zones > 0 then
		print("advisory_missing_zones\t" .. table.concat(missing_zones,","))
	end
	if #sample_mismatches > 0 then
		print("advisory_samples\t" .. table.concat(sample_mismatches,","))
	end
	if not hydrology_sample_ok then
		print("advisory_hydrology_sample\t" ..
			(hydrology_sample and hydrology_sample.hydrology_id or "missing"))
	end
end
