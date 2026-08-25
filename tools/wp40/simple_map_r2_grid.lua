-- Complete-grid horizontal invariants for the WP40 simple map.
--
-- This module is engine-free and deliberately owns no geometry. Every node
-- classification and difficulty value comes from the production evaluator.
-- Horizontal component proofs use eight-neighbor adjacency, matching player
-- movement across diagonal x/z node boundaries; geometric zone contacts stay
-- the stricter orthogonal edge contacts.

return function(source, session, options)
	if type(source) ~= "table" or type(source.extent) ~= "table" or
			type(source.zones) ~= "table" or type(source.routes) ~= "table" then
		error("WP40 R2 grid source missing", 0)
	end
	if type(session) ~= "table" or
			type(session.classification_values_at) ~= "function" or
			type(session.difficulty_for_macro_at) ~= "function" then
		error("WP40 R2 grid evaluator seam missing", 0)
	end
	if options ~= nil and type(options) ~= "table" then
		error("WP40 R2 grid options must be a table", 0)
	end
	options = options or {}
	if options.step ~= nil and options.step ~= 1 then
		error("WP40 R2 grid production step is exactly one", 0)
	end

	local function integer(value, label)
		if type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or value % 1 ~= 0 then
			error("WP40 R2 grid " .. label .. " is not an integer", 0)
		end
		return value
	end

	local authoritative = options.test_extent == nil
	local extent = options.test_extent or source.extent
	if type(extent) ~= "table" then
		error("WP40 R2 grid test extent missing", 0)
	end
	local min_x = integer(extent.min_x, "minimum x")
	local max_x = integer(extent.max_x, "maximum x")
	local min_z = integer(extent.min_z, "minimum z")
	local max_z = integer(extent.max_z, "maximum z")
	if min_x > max_x or min_z > max_z then
		error("WP40 R2 grid extent is empty", 0)
	end
	if not authoritative then
		if min_x < source.extent.min_x or max_x > source.extent.max_x or
				min_z < source.extent.min_z or max_z > source.extent.max_z then
			error("WP40 R2 grid test extent leaves the authored extent", 0)
		end
	end

	local maximum_difficulty_delta = authoritative and 2 or
		(options.maximum_difficulty_delta or 2)
	integer(maximum_difficulty_delta, "maximum difficulty delta")
	if maximum_difficulty_delta < 0 then
		error("WP40 R2 grid maximum difficulty delta is negative", 0)
	end

	local zone_count = #source.zones
	local routed_contacts = {}
	for index = 1, #source.routes do
		local row = source.routes[index]
		local a, b = row.zone_a, row.zone_b
		if a > b then a, b = b, a end
		routed_contacts[tostring(a) .. ":" .. tostring(b)] = true
	end

	local occurrence_counts = {}
	local first_witness = {}
	local function observe(code, x, z, fields)
		occurrence_counts[code] = (occurrence_counts[code] or 0) + 1
		if first_witness[code] then return end
		local witness = {code=code,x=x,z=z}
		if fields then
			for key, value in pairs(fields) do witness[key] = value end
		end
		first_witness[code] = witness
	end

	local land_parent = {}
	local territory_parent = {}
	local label_x, label_z = {}, {}
	local label_min_x, label_max_x = {}, {}
	local territory_label_zone,territory_label_x,territory_label_z={},{},{}
	local territory_label_min_x,territory_label_max_x={},{}
	local label_count = 0
	local territory_label_count=0
	local function new_label(x, z)
		label_count = label_count + 1
		land_parent[label_count] = label_count
		label_x[label_count] = x
		label_z[label_count] = z
		label_min_x[label_count] = x
		label_max_x[label_count] = x
		return label_count
	end
	local function new_territory_label(zone_numeric_id,x,z)
		territory_label_count=territory_label_count+1
		territory_parent[territory_label_count]=territory_label_count
		territory_label_zone[territory_label_count]=zone_numeric_id
		territory_label_x[territory_label_count]=x
		territory_label_z[territory_label_count]=z
		territory_label_min_x[territory_label_count]=x
		territory_label_max_x[territory_label_count]=x
		return territory_label_count
	end

	local function find(parent, label)
		local root = label
		while parent[root] ~= root do root = parent[root] end
		while parent[label] ~= label do
			local next_label = parent[label]
			parent[label] = root
			label = next_label
		end
		return root
	end

	local function unite(parent, a, b)
		local root_a = find(parent, a)
		local root_b = find(parent, b)
		if root_a == root_b then return root_a end
		-- Labels are allocated in canonical z/x scan order. Keeping the lower
		-- label as root also keeps component witnesses deterministic.
		if root_a < root_b then
			parent[root_b] = root_a
			return root_a
		end
		parent[root_a] = root_b
		return root_b
	end

	local contact_by_key = {}
	local function observe_contact(a, b, ax, az, bx, bz)
		if a == b then return end
		if a > b then
			a, b = b, a
			ax, bx = bx, ax
			az, bz = bz, az
		end
		local key = tostring(a) .. ":" .. tostring(b)
		if not contact_by_key[key] then
			contact_by_key[key] = {key=key,zone_a=a,zone_b=b,
				a_x=ax,a_z=az,b_x=bx,b_z=bz}
		end
	end

	local known_water = {
		land=true,
		planned_water=true,
		coastal_shelf=true,
		immutable_dragon_channel=true,
		deep_ocean=true,
	}
	local water_counts = {
		land=0,
		planned_water=0,
		coastal_shelf=0,
		immutable_dragon_channel=0,
		deep_ocean=0,
		unknown=0,
	}
	local zone_land_nodes = {}
	for zone_id = 1, zone_count do zone_land_nodes[zone_id] = 0 end

	local scanned_nodes = 0
	local previous_runs = {}
	local previous_territory_runs={}
	local previous_owner = {}
	local previous_difficulty = {}
	local maximum_observed_delta = -1
	local maximum_delta_witness = nil
	local classify = session.classification_values_at
	local difficulty_for_macro = session.difficulty_for_macro_at

	local function consider_delta(a_x, a_z, a_value, b_x, b_z, b_value)
		if type(a_value) ~= "number" or type(b_value) ~= "number" then return end
		local delta = math.abs(a_value - b_value)
		if delta > maximum_observed_delta then
			maximum_observed_delta = delta
			maximum_delta_witness = {code="maximum_difficulty_delta",
				a_x=a_x,a_z=a_z,a_value=a_value,
				b_x=b_x,b_z=b_z,b_value=b_value,delta=delta}
		end
	end

	for z = min_z, max_z do
		local current_runs = {}
		local current_territory_runs={}
		local current_owner = {}
		local current_difficulty = {}
		local active_run = nil
		local active_territory_run=nil
		local left_owner = false
		local left_difficulty = false
		local column = 0

		for x = min_x, max_x do
			column = column + 1
			scanned_nodes = scanned_nodes + 1
			local water_class, macro_region, owner, bay_id = classify(x,z)
			local known = known_water[water_class] == true
			if known then
				water_counts[water_class] = water_counts[water_class] + 1
			else
				water_counts.unknown = water_counts.unknown + 1
				observe("unknown_water_class",x,z,{water_class=water_class})
			end

			local zone = type(owner) == "number" and owner % 1 == 0 and
				owner >= 1 and owner <= zone_count and source.zones[owner] or nil
			if owner ~= nil and (not zone or zone.macro_region ~= macro_region) then
				observe("owner_macro_inconsistent",x,z,{owner=owner,
					macro_region=macro_region,
					expected_macro_region=zone and zone.macro_region or nil})
			end

			local land = water_class == "land"
			local owned_water = water_class == "planned_water" or
				water_class == "coastal_shelf"
			if land and not zone then
				observe("land_owner_missing_or_invalid",x,z,{owner=owner,
					macro_region=macro_region})
			elseif owned_water and not zone then
				observe("owned_water_owner_missing_or_invalid",x,z,
					{water_class=water_class,owner=owner,macro_region=macro_region})
			elseif known and not land and not owned_water and
					(owner ~= nil or macro_region ~= nil) then
				observe("owner_on_ownerless_water",x,z,{water_class=water_class,
					owner=owner,macro_region=macro_region})
			end

			local run_owner = land and (zone and owner or 0) or false
			-- Shelf and bay water inherit a nearby owner for biome/difficulty and
			-- shoreline queries, but are not political territory components. Local
			-- hydrology stays in the connectivity proof so rivers do not split a zone.
			local territory_owner=(land or
				(water_class == "planned_water" and bay_id == nil)) and
				zone and owner or false
			local difficulty = false
			if land then
				if zone then zone_land_nodes[owner] = zone_land_nodes[owner] + 1 end
				difficulty = difficulty_for_macro(x,z,macro_region)
				if type(difficulty) ~= "number" or difficulty % 1 ~= 0 then
					observe("walkable_land_difficulty_missing",x,z,
						{macro_region=macro_region,owner=owner,difficulty=difficulty})
					difficulty = false
				end

				if not active_run or active_run.zone_numeric_id ~= run_owner then
					local label = new_label(x,z)
					local run = {min_x=x,max_x=x,zone_numeric_id=run_owner,label=label}
					local prior_run = current_runs[#current_runs]
					if prior_run and prior_run.max_x == x-1 then
						unite(land_parent,prior_run.label,label)
					end
					current_runs[#current_runs+1] = run
					active_run = run
				else
					active_run.max_x = x
				end
			else
				active_run = nil
			end
			if type(territory_owner) == "number" then
				if not active_territory_run or
						active_territory_run.zone_numeric_id ~= territory_owner then
					local label=new_territory_label(territory_owner,x,z)
					local run={min_x=x,max_x=x,zone_numeric_id=territory_owner,
						label=label}
					current_territory_runs[#current_territory_runs+1]=run
					active_territory_run=run
				else
					active_territory_run.max_x=x
				end
			else
				active_territory_run=nil
			end

			local above_owner = previous_owner[column]
			local above_difficulty = previous_difficulty[column]
			if type(run_owner) == "number" then
				if type(left_owner) == "number" then
					if run_owner > 0 and left_owner > 0 then
						observe_contact(left_owner,run_owner,x-1,z,x,z)
					end
					consider_delta(x-1,z,left_difficulty,x,z,difficulty)
				end
				if type(above_owner) == "number" then
					if run_owner > 0 and above_owner > 0 then
						observe_contact(above_owner,run_owner,x,z-1,x,z)
					end
					consider_delta(x,z-1,above_difficulty,x,z,difficulty)
				end
			end

			current_owner[column] = run_owner
			current_difficulty[column] = difficulty
			left_owner = run_owner
			left_difficulty = difficulty
		end

		local previous_index = 1
		for run_index = 1, #current_runs do
			local run = current_runs[run_index]
			label_max_x[run.label] = run.max_x
		end
		for run_index=1,#current_territory_runs do
			local run=current_territory_runs[run_index]
			territory_label_max_x[run.label]=run.max_x
		end
		for current_index = 1, #current_runs do
			local current = current_runs[current_index]
			while previous_index <= #previous_runs and
					previous_runs[previous_index].max_x < current.min_x-1 do
				previous_index = previous_index + 1
			end
			local candidate_index = previous_index
			while candidate_index <= #previous_runs and
					previous_runs[candidate_index].min_x <= current.max_x+1 do
				local previous = previous_runs[candidate_index]
				unite(land_parent,current.label,previous.label)
				candidate_index = candidate_index + 1
			end
		end
		local previous_territory_index=1
		for current_index=1,#current_territory_runs do
			local current=current_territory_runs[current_index]
			while previous_territory_index <= #previous_territory_runs and
					previous_territory_runs[previous_territory_index].max_x <
					current.min_x-1 do
				previous_territory_index=previous_territory_index+1
			end
			local candidate_index=previous_territory_index
			while candidate_index <= #previous_territory_runs and
					previous_territory_runs[candidate_index].min_x <= current.max_x+1 do
				local previous=previous_territory_runs[candidate_index]
				if current.zone_numeric_id == previous.zone_numeric_id then
					unite(territory_parent,current.label,previous.label)
				end
				candidate_index=candidate_index+1
			end
		end

		previous_runs = current_runs
		previous_territory_runs=current_territory_runs
		previous_owner = current_owner
		previous_difficulty = current_difficulty
	end

	local land_component_by_root = {}
	local zone_root_seen = {}
	local zone_component_by_root = {}
	for zone_id = 1, zone_count do zone_root_seen[zone_id] = {} end
	for zone_id = 1, zone_count do zone_component_by_root[zone_id] = {} end
	for label = 1, label_count do
		local land_root = find(land_parent,label)
		local land_component=land_component_by_root[land_root]
		if not land_component then
			land_component={root=land_root,x=label_x[land_root],z=label_z[land_root],
				nodes=0,min_x=label_min_x[label],max_x=label_max_x[label],
				min_z=label_z[label],max_z=label_z[label]}
			land_component_by_root[land_root]=land_component
		end
		land_component.nodes=land_component.nodes+
			(label_max_x[label]-label_min_x[label]+1)
		land_component.min_x=math.min(land_component.min_x,label_min_x[label])
		land_component.max_x=math.max(land_component.max_x,label_max_x[label])
		land_component.min_z=math.min(land_component.min_z,label_z[label])
		land_component.max_z=math.max(land_component.max_z,label_z[label])
	end
	for label=1,territory_label_count do
		local zone_id=territory_label_zone[label]
		local zone_root=find(territory_parent,label)
		zone_root_seen[zone_id][zone_root]=true
		local zone_component=zone_component_by_root[zone_id][zone_root]
		if not zone_component then
			zone_component={root=zone_root,x=territory_label_x[zone_root],
				z=territory_label_z[zone_root],nodes=0,
				min_x=territory_label_min_x[label],
				max_x=territory_label_max_x[label],min_z=territory_label_z[label],
				max_z=territory_label_z[label]}
			zone_component_by_root[zone_id][zone_root]=zone_component
		end
		zone_component.nodes=zone_component.nodes+
			(territory_label_max_x[label]-territory_label_min_x[label]+1)
		zone_component.min_x=math.min(zone_component.min_x,
			territory_label_min_x[label])
		zone_component.max_x=math.max(zone_component.max_x,
			territory_label_max_x[label])
		zone_component.min_z=math.min(zone_component.min_z,territory_label_z[label])
		zone_component.max_z=math.max(zone_component.max_z,territory_label_z[label])
	end
	local land_components={}
	for _, component in pairs(land_component_by_root) do
		land_components[#land_components+1]=component
	end
	table.sort(land_components,function(a,b) return a.root < b.root end)

	local zone_components = {}
	local zones_with_one_component = 0
	local first_bad_zone = nil
	for zone_id = 1, zone_count do
		local count = 0
		local first_root = nil
		local components={}
		for root in pairs(zone_root_seen[zone_id]) do
			count = count + 1
			if not first_root or root < first_root then first_root = root end
			components[#components+1]=zone_component_by_root[zone_id][root]
		end
		table.sort(components,function(a,b) return a.root < b.root end)
		if count == 1 then zones_with_one_component = zones_with_one_component + 1
		elseif not first_bad_zone then
			first_bad_zone = {zone_numeric_id=zone_id,components=count,
				x=first_root and territory_label_x[first_root] or
					source.zones[zone_id].hub.x,
				z=first_root and territory_label_z[first_root] or
					source.zones[zone_id].hub.z}
		end
		zone_components[#zone_components+1] = {
			zone_numeric_id=zone_id,zone_id=source.zones[zone_id].id,
			components=count,land_nodes=zone_land_nodes[zone_id],
			component_records=components}
	end

	local contacts = {}
	for _, contact in pairs(contact_by_key) do contacts[#contacts+1] = contact end
	table.sort(contacts,function(a,b)
		if a.zone_a ~= b.zone_a then return a.zone_a < b.zone_a end
		return a.zone_b < b.zone_b
	end)
	local unrouted_contact_count = 0
	for index = 1, #contacts do
		local contact = contacts[index]
		contact.routed = routed_contacts[contact.key] == true
		if not contact.routed then
			unrouted_contact_count = unrouted_contact_count + 1
		end
	end

	local aggregate_counts = {}
	local aggregate_witness = {}
	if authoritative and zone_count ~= 38 then
		aggregate_counts.zone_catalog_count = 1
		aggregate_witness.zone_catalog_count = {code="zone_catalog_count",
			expected=38,actual=zone_count}
	end
	local expected_land_components = authoritative and 3 or
		options.expected_land_components
	if expected_land_components and #land_components ~= expected_land_components then
		aggregate_counts.land_component_count = 1
		local component = land_components[math.min(#land_components,
			expected_land_components+1)] or land_components[1]
		aggregate_witness.land_component_count = {code="land_component_count",
			expected=expected_land_components,actual=#land_components,
			x=component and component.x or nil,z=component and component.z or nil}
	end
	local check_all_zones = authoritative or options.check_all_zones == true
	if check_all_zones and zones_with_one_component ~= zone_count then
		aggregate_counts.zone_component_count = zone_count-zones_with_one_component
		aggregate_witness.zone_component_count = {code="zone_component_count",
			zone_numeric_id=first_bad_zone.zone_numeric_id,
			expected=1,actual=first_bad_zone.components,
			x=first_bad_zone.x,z=first_bad_zone.z}
	end
	if maximum_observed_delta > maximum_difficulty_delta then
		aggregate_counts.maximum_difficulty_delta = 1
		aggregate_witness.maximum_difficulty_delta = maximum_delta_witness
		aggregate_witness.maximum_difficulty_delta.limit = maximum_difficulty_delta
	end

	local violation_order = {
		"zone_catalog_count",
		"unknown_water_class",
		"land_owner_missing_or_invalid",
		"owned_water_owner_missing_or_invalid",
		"owner_macro_inconsistent",
		"owner_on_ownerless_water",
		"walkable_land_difficulty_missing",
		"land_component_count",
		"zone_component_count",
		"maximum_difficulty_delta",
	}
	local violations, witnesses = {}, {}
	for index = 1, #violation_order do
		local code = violation_order[index]
		local count = occurrence_counts[code] or aggregate_counts[code]
		if count and count > 0 then
			violations[#violations+1] = {code=code,count=count}
			witnesses[#witnesses+1] = first_witness[code] or
				aggregate_witness[code]
		end
	end

	if maximum_observed_delta < 0 then maximum_observed_delta = 0 end
	local metrics = {
		{name="authoritative",value=authoritative},
		{name="step",value=1},
		{name="min_x",value=min_x},
		{name="max_x",value=max_x},
		{name="min_z",value=min_z},
		{name="max_z",value=max_z},
		{name="scanned_nodes",value=scanned_nodes},
		{name="land_nodes",value=water_counts.land},
		{name="planned_water_nodes",value=water_counts.planned_water},
		{name="coastal_shelf_nodes",value=water_counts.coastal_shelf},
		{name="dragon_channel_nodes",value=water_counts.immutable_dragon_channel},
		{name="deep_ocean_nodes",value=water_counts.deep_ocean},
		{name="unknown_water_nodes",value=water_counts.unknown},
		{name="row_run_labels",value=label_count},
		{name="land_components",value=#land_components},
		{name="zones_with_one_component",value=zones_with_one_component},
		{name="emergent_contacts",value=#contacts},
		{name="unrouted_emergent_contacts",value=unrouted_contact_count},
		{name="maximum_difficulty_delta",value=maximum_observed_delta},
		{name="maximum_difficulty_delta_limit",value=maximum_difficulty_delta},
	}

	return {
		schema="grug_wp40_simple_map_r2_grid_v1",
		authoritative=authoritative,
		ok=#violations == 0,
		violations=violations,
		metrics=metrics,
		witnesses=witnesses,
		contacts=contacts,
		land_components=land_components,
		zone_components=zone_components,
	}
end
