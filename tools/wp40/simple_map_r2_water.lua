-- Horizontal water invariants for the WP40 simple map.
--
-- This engine-free module does not classify ownership or geometry itself.
-- World membership comes from the production evaluator; source geometry is
-- used only for finite scan bounds and structural relationships. Component
-- scans use the same eight-neighbor horizontal adjacency as the R2 land proof.

return function(source, session, options)
	if type(source) ~= "table" or type(source.extent) ~= "table" or
			type(source.bays) ~= "table" or type(source.channels) ~= "table" or
			type(source.hydrology) ~= "table" or
			type(source.crossing_interfaces) ~= "table" or
			type(source.hydrology_interfaces) ~= "table" then
		error("WP40 R2 water source missing", 0)
	end
	if type(session) ~= "table" or
			type(session.classification_values_at) ~= "function" or
			type(session.warp_at) ~= "function" or
			type(session.warp_proof) ~= "function" or
			type(session.polygon_member) ~= "function" or
			type(session.polyline_corridor_member) ~= "function" or
			type(session.polyline_point_member) ~= "function" or
			type(session.path_corridor_member) ~= "function" then
		error("WP40 R2 water evaluator seam missing", 0)
	end
	if options ~= nil and type(options) ~= "table" then
		error("WP40 R2 water options must be a table", 0)
	end
	options = options or {}
	if options.step ~= nil and options.step ~= 1 then
		error("WP40 R2 water production step is exactly one", 0)
	end

	local function integer(value, label)
		if type(value) ~= "number" or value ~= value or
				value == math.huge or value == -math.huge or value % 1 ~= 0 then
			error("WP40 R2 water " .. label .. " is not an integer", 0)
		end
		return value
	end

	local extent = source.extent
	local min_x = integer(extent.min_x,"minimum x")
	local max_x = integer(extent.max_x,"maximum x")
	local min_z = integer(extent.min_z,"minimum z")
	local max_z = integer(extent.max_z,"maximum z")
	local warp_maximum = integer(source.warp.maximum,"warp maximum")
	local classify = session.classification_values_at
	local warp_at = session.warp_at
	local warp_proof=session.warp_proof()
	local maximum_axis_delta=math.max(
		warp_proof.max_horizontal_x+warp_proof.max_vertical_x,
		warp_proof.max_horizontal_z+warp_proof.max_vertical_z)

	local violations, witnesses = {}, {}
	local violation_keys = {}
	local function violate(code, feature_id, count, witness)
		local key = code .. "\0" .. (feature_id or "")
		if violation_keys[key] then return end
		violation_keys[key] = true
		violations[#violations+1] = {
			code=code,feature_id=feature_id,count=count or 1,
		}
		witness = witness or {}
		witness.code = code
		witness.feature_id = feature_id
		witnesses[#witnesses+1] = witness
	end

	local function bounds_for_tapered(row)
		local bounds = {min_x=math.huge,max_x=-math.huge,
			min_z=math.huge,max_z=-math.huge}
		for index = 1, #row.centreline do
			local point = row.centreline[index]
			bounds.min_x = math.min(bounds.min_x,point.x-point.half_width)
			bounds.max_x = math.max(bounds.max_x,point.x+point.half_width)
			bounds.min_z = math.min(bounds.min_z,point.z-point.half_width)
			bounds.max_z = math.max(bounds.max_z,point.z+point.half_width)
		end
		return bounds
	end

	local function expanded_world_bounds(row)
		local bounds = bounds_for_tapered(row)
		return {
			min_x=math.max(min_x,bounds.min_x-warp_maximum),
			max_x=math.min(max_x,bounds.max_x+warp_maximum),
			min_z=math.max(min_z,bounds.min_z-warp_maximum),
			max_z=math.min(max_z,bounds.max_z+warp_maximum),
		}
	end

	local function aabb_overlap(a, b)
		return a.max_x >= b.min_x and a.min_x <= b.max_x and
			a.max_z >= b.min_z and a.min_z <= b.max_z
	end

	local function new_tracker()
		local tracker = {
			parent={},head={},outer={},planned={},
			label_x={},label_z={},nodes={},min_x={},max_x={},min_z={},max_z={},
			count=0,previous_runs={},
		}

		local function find(label)
			local root = label
			while tracker.parent[root] ~= root do root=tracker.parent[root] end
			while tracker.parent[label] ~= label do
				local next_label=tracker.parent[label]
				tracker.parent[label]=root
				label=next_label
			end
			return root
		end

		local function unite(a,b)
			local root_a,root_b=find(a),find(b)
			if root_a == root_b then return end
			if root_a < root_b then tracker.parent[root_b]=root_a
			else tracker.parent[root_a]=root_b end
		end

		function tracker.begin_row()
			tracker.current_runs={}
			tracker.active=nil
		end

		function tracker.feed(member,x,z,has_head,has_outer,is_planned)
			if not member then tracker.active=nil return end
			local run=tracker.active
			if not run then
				tracker.count=tracker.count+1
				local label=tracker.count
				tracker.parent[label]=label
				tracker.label_x[label]=x tracker.label_z[label]=z
				tracker.nodes[label]=0
				tracker.min_x[label]=x tracker.max_x[label]=x
				tracker.min_z[label]=z tracker.max_z[label]=z
				run={min_x=x,max_x=x,label=label}
				tracker.current_runs[#tracker.current_runs+1]=run
				tracker.active=run
			else run.max_x=x end
			local label=run.label
			tracker.nodes[label]=tracker.nodes[label]+1
			tracker.min_x[label]=math.min(tracker.min_x[label],x)
			tracker.max_x[label]=math.max(tracker.max_x[label],x)
			tracker.min_z[label]=math.min(tracker.min_z[label],z)
			tracker.max_z[label]=math.max(tracker.max_z[label],z)
			if has_head then tracker.head[label]=true end
			if has_outer then tracker.outer[label]=true end
			if is_planned then tracker.planned[label]=true end
		end

		function tracker.end_row()
			local previous_index=1
			for current_index=1,#tracker.current_runs do
				local current=tracker.current_runs[current_index]
				while previous_index <= #tracker.previous_runs and
						tracker.previous_runs[previous_index].max_x < current.min_x-1 do
					previous_index=previous_index+1
				end
				local candidate_index=previous_index
				while candidate_index <= #tracker.previous_runs and
						tracker.previous_runs[candidate_index].min_x <= current.max_x+1 do
					unite(current.label,tracker.previous_runs[candidate_index].label)
					candidate_index=candidate_index+1
				end
			end
			tracker.previous_runs=tracker.current_runs
			tracker.current_runs=nil tracker.active=nil
		end

		function tracker.components()
			local by_root={}
			for label=1,tracker.count do
				local root=find(label)
				local component=by_root[root]
				if not component then
					component={root=root,x=tracker.label_x[root],z=tracker.label_z[root],
						head=false,outer=false,planned=false,nodes=0,
						min_x=math.huge,max_x=-math.huge,
						min_z=math.huge,max_z=-math.huge}
					by_root[root]=component
				end
				component.nodes=component.nodes+tracker.nodes[label]
				component.min_x=math.min(component.min_x,tracker.min_x[label])
				component.max_x=math.max(component.max_x,tracker.max_x[label])
				component.min_z=math.min(component.min_z,tracker.min_z[label])
				component.max_z=math.max(component.max_z,tracker.max_z[label])
				component.head=component.head or tracker.head[label] or false
				component.outer=component.outer or tracker.outer[label] or false
				component.planned=component.planned or tracker.planned[label] or false
			end
			local result={}
			for _,component in pairs(by_root) do result[#result+1]=component end
			table.sort(result,function(a,b) return a.root < b.root end)
			return result
		end

		return tracker
	end

	local function deep_side(bay, warped_z)
		if bay.deep_ocean_side == "min_z" then
			return warped_z <= bay.deep_ocean_cut_z
		end
		return warped_z >= bay.deep_ocean_cut_z
	end

	local capital_bounds={}
	for index=1,#source.anchors do
		local anchor=source.anchors[index]
		if anchor.slot_id == "capital" and anchor.position then
			local width_x=source.capital_core.width_x
			local width_z=source.capital_core.width_z
			local core_min_x=anchor.position.x-math.floor(width_x/2)
			local core_min_z=anchor.position.z-math.floor(width_z/2)
			capital_bounds[#capital_bounds+1]={id=anchor.id,
				min_x=core_min_x,max_x=core_min_x+width_x-1,
				min_z=core_min_z,max_z=core_min_z+width_z-1}
		end
	end

	local landmark_by_id={}
	for index=1,#source.landmarks do
		landmark_by_id[source.landmarks[index].id]=source.landmarks[index]
	end
	local coastal_bounds={}
	for index=1,#source.coastal_housing_cores do
		local core=source.coastal_housing_cores[index]
		local landmark=landmark_by_id[core.landmark_id]
		if landmark and landmark.primitive == "rectangle" then
			coastal_bounds[#coastal_bounds+1]={id=core.id,
				min_x=landmark.center.x-landmark.radius_x,
				max_x=landmark.center.x+landmark.radius_x,
				min_z=landmark.center.z-landmark.radius_z,
				max_z=landmark.center.z+landmark.radius_z}
		end
	end

	local bay_reports={}
	local total_bay_nodes,total_bay_transitions=0,0
	for bay_index=1,#source.bays do
		local bay=source.bays[bay_index]
		local bounds=expanded_world_bounds(bay)
		local possible_bounds=bounds_for_tapered(bay)
		possible_bounds={min_x=possible_bounds.min_x-warp_maximum,
			max_x=possible_bounds.max_x+warp_maximum,
			min_z=possible_bounds.min_z-warp_maximum,
			max_z=possible_bounds.max_z+warp_maximum}
		local minimum_width=math.huge
		local coincident_segments=0
		for point_index=1,#bay.centreline do
			minimum_width=math.min(minimum_width,
				2*bay.centreline[point_index].half_width)
			if point_index < #bay.centreline then
				local a,b=bay.centreline[point_index],bay.centreline[point_index+1]
				if a.x == b.x and a.z == b.z then coincident_segments=coincident_segments+1 end
			end
		end
		if minimum_width < 64 then
			violate("bay_authored_width_below_minimum",bay.id,1,
				{minimum=minimum_width,required=64})
		end
		-- The fixed bilinear warp has this conservative L-infinity Lipschitz
		-- bound. Dividing the warped-space width by it proves a minimum
		-- preimage width without a sampled or second geometry authority.
		local realized_width_lower_bound=math.floor(minimum_width*
			warp_proof.cell/(warp_proof.cell+maximum_axis_delta))
		if realized_width_lower_bound < 64 then
			violate("bay_realized_width_lower_bound_below_minimum",bay.id,1,
				{minimum=realized_width_lower_bound,required=64})
		end
		if coincident_segments > 0 then
			violate("bay_centreline_segment_degenerate",bay.id,coincident_segments,{})
		end
		local outer=bay.centreline[1]
		local head=bay.centreline[#bay.centreline]
		local cut_bracketed=bay.deep_ocean_side == "min_z" and
			outer.z <= bay.deep_ocean_cut_z and head.z > bay.deep_ocean_cut_z or
			bay.deep_ocean_side == "max_z" and
			outer.z >= bay.deep_ocean_cut_z and head.z < bay.deep_ocean_cut_z
		if not cut_bracketed then
			violate("bay_deep_cut_not_bracketed",bay.id,1,
				{outer_z=outer.z,head_z=head.z,cut_z=bay.deep_ocean_cut_z})
		end

		local capital_clear=true
		for index=1,#capital_bounds do
			if aabb_overlap(possible_bounds,capital_bounds[index]) then
				capital_clear=false
				violate("bay_capital_clearance_not_proven",bay.id,1,
					{other_id=capital_bounds[index].id})
				break
			end
		end
		local coastal_clear=true
		for index=1,#coastal_bounds do
			if aabb_overlap(possible_bounds,coastal_bounds[index]) then
				coastal_clear=false
				violate("bay_coastal_core_clearance_not_proven",bay.id,1,
					{other_id=coastal_bounds[index].id})
				break
			end
		end

		local planned_tracker=new_tracker()
		local open_tracker=new_tracker()
		local previous_kind={}
		local planned_nodes,deep_nodes=0,0
		local wrong_side_nodes,transition_count=0,0
		local wrong_side_witness,transition_witness=nil,nil
		local column_count=bounds.max_x-bounds.min_x+1

		for z=bounds.min_z,bounds.max_z do
			planned_tracker.begin_row()
			open_tracker.begin_row()
			local current_kind={}
			local left_kind=0
			for x=bounds.min_x,bounds.max_x do
				local column=x-bounds.min_x+1
				local water_class,_,_,bay_id=classify(x,z)
				local planned=water_class == "planned_water" and bay_id == bay.id
				local deep=water_class == "deep_ocean"
				local kind=planned and 1 or deep and 2 or 0
				local at_head=false
				if planned then
					planned_nodes=planned_nodes+1
					local need_warp=false
					if math.abs(x-head.x) <= head.half_width+warp_maximum and
							math.abs(z-head.z) <= head.half_width+warp_maximum then
						need_warp=true
					end
					if bay.deep_ocean_side == "min_z" and
							z <= bay.deep_ocean_cut_z+warp_maximum or
							bay.deep_ocean_side == "max_z" and
							z >= bay.deep_ocean_cut_z-warp_maximum then
						need_warp=true
					end
					if need_warp then
						local warped=warp_at(x,z)
						if warped then
							local dx,dz=warped.x-head.x,warped.z-head.z
							at_head=dx*dx+dz*dz <= head.half_width*head.half_width
							if deep_side(bay,warped.z) then
								wrong_side_nodes=wrong_side_nodes+1
								if not wrong_side_witness then
									wrong_side_witness={x=x,z=z,warped_z=warped.z,
										cut_z=bay.deep_ocean_cut_z}
								end
							end
						end
					end
				elseif deep then deep_nodes=deep_nodes+1 end

				planned_tracker.feed(planned,x,z,at_head,false,planned)
				local at_outer=deep and ((bay.deep_ocean_side == "min_z" and z == min_z) or
					(bay.deep_ocean_side == "max_z" and z == max_z))
				open_tracker.feed(planned or deep,x,z,at_head,at_outer,planned)

				local function transition(other_kind,other_x,other_z)
					if not ((kind == 1 and other_kind == 2) or
							(kind == 2 and other_kind == 1)) then return end
					local deep_x,deep_z=x,z
					if other_kind == 2 then deep_x,deep_z=other_x,other_z end
					local warped=warp_at(deep_x,deep_z)
					if warped and deep_side(bay,warped.z) then
						transition_count=transition_count+1
						if not transition_witness then
							transition_witness={x=deep_x,z=deep_z,warped_z=warped.z,
								cut_z=bay.deep_ocean_cut_z}
						end
					end
				end
				if x > bounds.min_x then transition(left_kind,x-1,z) end
				if z > bounds.min_z then transition(previous_kind[column],x,z-1) end
				current_kind[column]=kind
				left_kind=kind
			end
			planned_tracker.end_row()
			open_tracker.end_row()
			previous_kind=current_kind
		end
		assert(column_count >= 1)

		local planned_components=planned_tracker.components()
		local open_components=open_tracker.components()
		local head_reached=false
		for index=1,#planned_components do
			if planned_components[index].head then head_reached=true break end
		end
		local open_to_outer=false
		for index=1,#open_components do
			local component=open_components[index]
			if component.head and component.outer and component.planned then
				open_to_outer=true break
			end
		end

		if planned_nodes == 0 then
			violate("bay_has_no_planned_water",bay.id,1,{})
		elseif #planned_components ~= 1 then
			violate("bay_planned_water_disconnected",bay.id,1,
				{expected=1,actual=#planned_components,
				x=planned_components[1] and planned_components[1].x or nil,
				z=planned_components[1] and planned_components[1].z or nil,
				components=planned_components})
		end
		if not head_reached then
			violate("bay_head_not_reached",bay.id,1,{x=head.x,z=head.z})
		end
		if not open_to_outer then
			violate("bay_not_open_to_outer_ocean",bay.id,1,
				{x=head.x,z=head.z,side=bay.deep_ocean_side})
		end
		if transition_count == 0 then
			violate("bay_deep_ocean_transition_missing",bay.id,1,
				{cut_z=bay.deep_ocean_cut_z})
		end
		if wrong_side_nodes > 0 then
			violate("bay_planned_water_survives_deep_cap",bay.id,
				wrong_side_nodes,wrong_side_witness)
		end

		total_bay_nodes=total_bay_nodes+planned_nodes
		total_bay_transitions=total_bay_transitions+transition_count
		bay_reports[#bay_reports+1]={id=bay.id,
			planned_nodes=planned_nodes,deep_nodes=deep_nodes,
			planned_components=#planned_components,head_reached=head_reached,
			planned_component_details=planned_components,
			open_to_outer_ocean=open_to_outer,
			deep_transition_edges=transition_count,
			authored_minimum_width=minimum_width,
			realized_width_lower_bound=realized_width_lower_bound,
			capital_aabb_clear=capital_clear,coastal_core_aabb_clear=coastal_clear,
			transition_witness=transition_witness}
	end

	local channel_reports={}
	local total_channel_nodes,total_channel_mismatches=0,0
	for channel_index=1,#source.channels do
		local channel=source.channels[channel_index]
		local bounds={min_x=math.huge,max_x=-math.huge,
			min_z=math.huge,max_z=-math.huge}
		for point_index=1,#channel.polygon do
			local point=channel.polygon[point_index]
			bounds.min_x=math.min(bounds.min_x,point.x)
			bounds.max_x=math.max(bounds.max_x,point.x)
			bounds.min_z=math.min(bounds.min_z,point.z)
			bounds.max_z=math.max(bounds.max_z,point.z)
		end
		local tracker=new_tracker()
		local polygon_nodes,active_nodes,land_overlap_nodes=0,0,0
		local mismatches,owner_mismatches=0,0
		local first_mismatch,first_owner_mismatch=nil,nil
		local minimum_horizontal_gap=math.huge
		for z=bounds.min_z,bounds.max_z do
			tracker.begin_row()
			local polygon_row=false
			local active_run_length,row_max_active_run=0,0
			for x=bounds.min_x,bounds.max_x do
				local member=session.polygon_member(x,z,channel.polygon)
				if member then
					polygon_nodes=polygon_nodes+1
					polygon_row=true
					local water,macro,owner,_,_,channel_id=classify(x,z)
					local active=water == "immutable_dragon_channel" and
						channel_id == channel.id
					tracker.feed(active,x,z,false,false,false)
					if active then
						active_nodes=active_nodes+1
						active_run_length=active_run_length+1
						if macro ~= nil or owner ~= nil then
							owner_mismatches=owner_mismatches+1
							if not first_owner_mismatch then
								first_owner_mismatch={x=x,z=z,macro_region=macro,owner=owner}
							end
						end
					else
						row_max_active_run=math.max(row_max_active_run,active_run_length)
						active_run_length=0
					end
					if water == "land" then
						land_overlap_nodes=land_overlap_nodes+1
					elseif not active then
						mismatches=mismatches+1
						if not first_mismatch then
							first_mismatch={x=x,z=z,water_class=water,
								actual_channel_id=channel_id}
						end
					end
				else
					tracker.feed(false,x,z,false,false,false)
					row_max_active_run=math.max(row_max_active_run,active_run_length)
					active_run_length=0
				end
			end
			row_max_active_run=math.max(row_max_active_run,active_run_length)
			tracker.end_row()
			if polygon_row then
				minimum_horizontal_gap=math.min(minimum_horizontal_gap,row_max_active_run)
			end
		end
		local components=tracker.components()
		if minimum_horizontal_gap == math.huge then minimum_horizontal_gap=0 end
		local required_cross_section=channel.minimum_hard_width+2*channel.warning_width
		if channel.warning_width < 48 then
			violate("channel_warning_width_below_minimum",channel.id,1,
				{actual=channel.warning_width,required=48})
		end
		if channel.minimum_hard_width < 104 then
			violate("channel_hard_width_below_minimum",channel.id,1,
				{actual=channel.minimum_hard_width,required=104})
		end
		if minimum_horizontal_gap < required_cross_section then
			violate("channel_cross_section_below_declared_strips",channel.id,1,
				{actual=minimum_horizontal_gap,required=required_cross_section})
		end
		if #components ~= 1 then
			violate("channel_active_water_disconnected",channel.id,1,
				{expected=1,actual=#components})
		end
		if mismatches > 0 then
			violate("channel_interior_other_water_class",channel.id,
				mismatches,first_mismatch)
		end
		if owner_mismatches > 0 then
			violate("channel_active_water_has_owner",channel.id,
				owner_mismatches,first_owner_mismatch)
		end
		total_channel_nodes=total_channel_nodes+active_nodes
		total_channel_mismatches=total_channel_mismatches+mismatches
		channel_reports[#channel_reports+1]={id=channel.id,
			polygon_nodes=polygon_nodes,active_channel_nodes=active_nodes,
			land_overlap_nodes=land_overlap_nodes,active_components=#components,
			minimum_horizontal_gap_nodes=minimum_horizontal_gap,
			required_cross_section_nodes=required_cross_section,
			other_water_mismatches=mismatches,owner_mismatches=owner_mismatches}
	end

	local profile_by_id,transition_profile_by_id={},{}
	for index=1,#source.hydrology_profiles do
		profile_by_id[source.hydrology_profiles[index].id]=source.hydrology_profiles[index]
	end
	for index=1,#source.hydrology_transition_profiles do
		transition_profile_by_id[source.hydrology_transition_profiles[index].id]=
			source.hydrology_transition_profiles[index]
	end
	local hydrology_by_id,route_by_id,crossing_by_id={},{},{}
	for index=1,#source.hydrology do hydrology_by_id[source.hydrology[index].id]=source.hydrology[index] end
	for index=1,#source.routes do route_by_id[source.routes[index].id]=source.routes[index] end
	for index=1,#source.crossing_interfaces do
		crossing_by_id[source.crossing_interfaces[index].id]=source.crossing_interfaces[index]
	end

	local hydrology_reports={}
	local wet_reaches,dry_reaches,wet_sample_failures=0,0,0
	for index=1,#source.hydrology do
		local reach=source.hydrology[index]
		local profile=profile_by_id[reach.profile_id]
		local wet=profile and profile.depth > 0
		if wet then wet_reaches=wet_reaches+1 else dry_reaches=dry_reaches+1 end
		local failures,shadowed,active_samples=0,0,0
		local first_failure=nil
		for point_index=1,#reach.centreline do
			local point=reach.centreline[point_index]
			local water,macro,owner,bay_id,hydrology_id,_,fixed=
				classify(point.x,point.z)
			if wet then
				local zone=source.zones[reach.zone_numeric_id]
				if water == "planned_water" and hydrology_id == reach.id then
					if macro ~= zone.macro_region then
						failures=failures+1
						if not first_failure then
							first_failure={x=point.x,z=point.z,water_class=water,
								owner=owner,macro_region=macro,hydrology_id=hydrology_id}
						end
					else active_samples=active_samples+1 end
				elseif (water == "land" and fixed) or
						(water == "planned_water" and
						(hydrology_id ~= nil or bay_id ~= nil)) or
						(water == "land" and not fixed and
						reach.civic_core_zone_numeric_id ~= nil) then
					shadowed=shadowed+1
				else
					failures=failures+1
					if not first_failure then
						first_failure={x=point.x,z=point.z,water_class=water,
							owner=owner,macro_region=macro,hydrology_id=hydrology_id,
							bay_id=bay_id,fixed=fixed}
					end
				end
			elseif hydrology_id == reach.id then
				failures=failures+1
				if not first_failure then
					first_failure={x=point.x,z=point.z,water_class=water,
						hydrology_id=hydrology_id}
				end
			end
		end
		if failures > 0 then
			violate(wet and "wet_hydrology_sample_not_planned_water" or
				"dry_hydrology_sample_became_own_water",reach.id,failures,first_failure)
		end
		wet_sample_failures=wet_sample_failures+failures
		hydrology_reports[#hydrology_reports+1]={id=reach.id,wet=wet,
			samples=#reach.centreline,active_samples=active_samples,
			failures=failures,shadowed_samples=shadowed}
	end

	-- The fixed layout makes this complete wet-reach contact roster
	-- seed-independent. Scan only pairwise conservative support intersections,
	-- but take every membership decision from the production classifier.
	local function contact_key(a,b)
		if a < b then return a .. "\0" .. b end
		return b .. "\0" .. a
	end
	local function point_key(x,z) return x .. ":" .. z end
	local contact_directions={
		{dx=-1,dz=0,mask=1},{dx=1,dz=0,mask=2},
		{dx=0,dz=-1,mask=4},{dx=0,dz=1,mask=8},
	}
	local neighbor_directions={
		{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1},
	}
	local function sort_points(points)
		table.sort(points,function(a,b)
			return a.z < b.z or a.z == b.z and a.x < b.x
		end)
	end
	local function point_bounds(points)
		if #points == 0 then return nil end
		local result={min_x=points[1].x,max_x=points[1].x,
			min_z=points[1].z,max_z=points[1].z}
		for index=2,#points do
			local point=points[index]
			result.min_x=math.min(result.min_x,point.x)
			result.max_x=math.max(result.max_x,point.x)
			result.min_z=math.min(result.min_z,point.z)
			result.max_z=math.max(result.max_z,point.z)
		end
		return result
	end
	local function point_components(points)
		local members,seen={},{}
		for index=1,#points do
			members[point_key(points[index].x,points[index].z)]=true
		end
		local components=0
		for index=1,#points do
			local start=points[index]
			local start_key=point_key(start.x,start.z)
			if not seen[start_key] then
				components=components+1 seen[start_key]=true
				local queue={{x=start.x,z=start.z}}
				local head=1
				while head <= #queue do
					local current=queue[head] head=head+1
					for direction_index=1,#neighbor_directions do
						local direction=neighbor_directions[direction_index]
						local x,z=current.x+direction[1],current.z+direction[2]
						local key=point_key(x,z)
						if members[key] and not seen[key] then
							seen[key]=true queue[#queue+1]={x=x,z=z}
						end
					end
				end
			end
		end
		return components
	end
	local function centered_half_open_member(x,z,center,total_width)
		local min_x=center.x-math.floor(total_width/2)
		local min_z=center.z-math.floor(total_width/2)
		return x >= min_x and x < min_x+total_width and
			z >= min_z and z < min_z+total_width
	end

	local anchor_by_id,anchor_profile_by_id={},{}
	for index=1,#source.anchors do anchor_by_id[source.anchors[index].id]=source.anchors[index] end
	for index=1,#source.anchor_profiles do
		anchor_profile_by_id[source.anchor_profiles[index].id]=source.anchor_profiles[index]
	end
	local hard_recipe_by_id={}
	for index=1,#source.hard_protection_recipes do
		hard_recipe_by_id[source.hard_protection_recipes[index].id]=
			source.hard_protection_recipes[index]
	end
	local ingress_by_id={}
	for index=1,#source.capital_ingresses do
		ingress_by_id[source.capital_ingresses[index].id]=source.capital_ingresses[index]
	end
	local path_rows={}
	for index=1,#source.routes do
		local row=source.routes[index]
		path_rows[#path_rows+1]={id=row.id,centreline=row.centreline,
			surface_width=row.surface_width,corridor_width=row.corridor_width}
	end
	for index=1,#source.island_routes do
		local row=source.island_routes[index]
		path_rows[#path_rows+1]={id=row.id,centreline=row.centreline,
			surface_width=5,corridor_width=12}
	end
	local trail_template={bandit_home=true,bandit_frontier=true,
		mirefolk=true,clash=true}
	for index=1,#source.poi_spurs do
		local row=source.poi_spurs[index]
		local anchor=anchor_by_id[row.anchor_id]
		local corridor_width=trail_template[anchor.template_id] and 8 or 12
		path_rows[#path_rows+1]={id=row.id,centreline=row.centreline,
			surface_width=corridor_width == 8 and 3 or 5,
			corridor_width=corridor_width}
	end
	table.sort(path_rows,function(a,b) return a.id < b.id end)

	local function path_intersections(points)
		local surface_columns,corridor_columns=0,0
		for point_index=1,#points do
			local point=points[point_index]
			local in_surface,in_corridor=false,false
			for path_index=1,#path_rows do
				local path=path_rows[path_index]
				if not in_surface and session.polyline_corridor_member(point.x,point.z,
						path.centreline,path.surface_width) then in_surface=true end
				if not in_corridor and session.polyline_corridor_member(point.x,point.z,
						path.centreline,path.corridor_width) then in_corridor=true end
				if in_surface and in_corridor then break end
			end
			if in_surface then surface_columns=surface_columns+1 end
			if in_corridor then corridor_columns=corridor_columns+1 end
		end
		return surface_columns,corridor_columns
	end
	local function named_operation_intersections(points)
		local columns=0
		for point_index=1,#points do
			local point=points[point_index]
			local member=false
			for crossing_index=1,#source.crossing_interfaces do
				local crossing=source.crossing_interfaces[crossing_index]
				if point.x == crossing.position.x and point.z == crossing.position.z or
						crossing.authorization_polygon and
						session.polygon_member(point.x,point.z,
							crossing.authorization_polygon) then
					member=true break
				end
			end
			if member then columns=columns+1 end
		end
		return columns
	end
	local function fitting_intersections(upper_points,lower_points)
		local result={}
		for anchor_index=1,#source.anchors do
			local anchor=source.anchors[anchor_index]
			local profile=anchor_profile_by_id[anchor.template_id]
			local counts={upper_full=0,lower_full=0,upper_blend=0,lower_blend=0}
			for _,item in ipairs({{upper_points,"upper"},{lower_points,"lower"}}) do
				for point_index=1,#item[1] do
					local point=item[1][point_index]
					if centered_half_open_member(point.x,point.z,anchor.position,
							profile.fitting_width) then
						counts[item[2] .. "_full"]=counts[item[2] .. "_full"]+1
					end
					if centered_half_open_member(point.x,point.z,anchor.position,
							profile.blend_width) then
						counts[item[2] .. "_blend"]=counts[item[2] .. "_blend"]+1
					end
				end
			end
			if counts.upper_full+counts.lower_full+
					counts.upper_blend+counts.lower_blend > 0 then
				counts.anchor_id=anchor.id result[#result+1]=counts
			end
		end
		return result
	end
	local function hard_member(hard,x,z)
		local recipe=hard_recipe_by_id[hard.recipe_id]
		if recipe.shape == "centered_half_open_square" then
			return centered_half_open_member(x,z,hard.center,recipe.total_width)
		elseif recipe.shape == "exact_column" then
			return x == hard.center.x and z == hard.center.z
		elseif recipe.shape == "polyline_corridor" then
			local ingress=ingress_by_id[hard.ingress_id]
			for route_index=1,#ingress.route_ids do
				local route=route_by_id[ingress.route_ids[route_index]]
				if session.polyline_corridor_member(x,z,route.centreline,
						recipe.total_width) then return true end
			end
		end
		return false
	end
	local function hard_intersections(upper_points,lower_points)
		local result={}
		for hard_index=1,#source.hard_protection do
			local hard=source.hard_protection[hard_index]
			local upper,lower=0,0
			for point_index=1,#upper_points do
				local point=upper_points[point_index]
				if hard_member(hard,point.x,point.z) then upper=upper+1 end
			end
			for point_index=1,#lower_points do
				local point=lower_points[point_index]
				if hard_member(hard,point.x,point.z) then lower=lower+1 end
			end
			if upper+lower > 0 then
				result[#result+1]={hard_id=hard.id,upper=upper,lower=lower}
			end
		end
		return result
	end

	local vertical_interface_by_pair={}
	for interface_index=1,#source.hydrology_interfaces do
		local interface=source.hydrology_interfaces[interface_index]
		if interface.upper_id and interface.lower_id then
			local key=contact_key(interface.upper_id,interface.lower_id)
			if vertical_interface_by_pair[key] then
				violate("duplicate_vertical_interface_pair",interface.id,1,
					{other_id=vertical_interface_by_pair[key].id})
			else vertical_interface_by_pair[key]=interface end
		end
	end

	local wet_rows={}
	for index=1,#source.hydrology do
		local row=source.hydrology[index]
		if profile_by_id[row.profile_id].depth > 0 then wet_rows[#wet_rows+1]=row end
	end
	local contact_reports,contact_report_by_interface={},{}
	local contact_pair_count,unequal_contact_pair_count=0,0
	for first_index=1,#wet_rows-1 do
		for second_index=first_index+1,#wet_rows do
			local first,second=wet_rows[first_index],wet_rows[second_index]
			local upper,lower=first,second
			if first.water_surface_offset < second.water_surface_offset or
					first.water_surface_offset == second.water_surface_offset and
					first.id > second.id then upper,lower=second,first end
			local upper_bounds=bounds_for_tapered(upper)
			local lower_bounds=bounds_for_tapered(lower)
			local scan_min_x=math.max(upper_bounds.min_x-1,lower_bounds.min_x-1)
			local scan_max_x=math.min(upper_bounds.max_x+1,lower_bounds.max_x+1)
			local scan_min_z=math.max(upper_bounds.min_z-1,lower_bounds.min_z-1)
			local scan_max_z=math.min(upper_bounds.max_z+1,lower_bounds.max_z+1)
			if scan_min_x <= scan_max_x and scan_min_z <= scan_max_z then
				local edges,upper_by_key,lower_by_key={},{},{}
				for z=scan_min_z,scan_max_z do
					for x=scan_min_x,scan_max_x do
						local water,_,_,_,hydrology_id=classify(x,z)
						if water == "planned_water" and hydrology_id == upper.id then
							for direction_index=1,#contact_directions do
								local direction=contact_directions[direction_index]
								local lower_x,lower_z=x+direction.dx,z+direction.dz
								local lower_water,_,_,_,lower_hydrology_id=
									classify(lower_x,lower_z)
								if lower_water == "planned_water" and
										lower_hydrology_id == lower.id then
									edges[#edges+1]={upper_x=x,upper_z=z,
										lower_x=lower_x,lower_z=lower_z}
									local upper_key=point_key(x,z)
									if not upper_by_key[upper_key] then
										upper_by_key[upper_key]={x=x,z=z}
									end
									local lower_key=point_key(lower_x,lower_z)
									local lower_point=lower_by_key[lower_key]
									if not lower_point then
										lower_point={x=lower_x,z=lower_z,bits={}}
										lower_by_key[lower_key]=lower_point
									end
									local mask=direction.mask == 1 and 2 or
										direction.mask == 2 and 1 or
										direction.mask == 4 and 8 or 4
									lower_point.bits[mask]=true
								end
							end
						end
					end
				end
				if #edges > 0 then
					table.sort(edges,function(a,b)
						if a.upper_z ~= b.upper_z then return a.upper_z < b.upper_z end
						if a.upper_x ~= b.upper_x then return a.upper_x < b.upper_x end
						if a.lower_z ~= b.lower_z then return a.lower_z < b.lower_z end
						return a.lower_x < b.lower_x
					end)
					local upper_points,lower_points={},{}
					for _,point in pairs(upper_by_key) do upper_points[#upper_points+1]=point end
					for _,point in pairs(lower_by_key) do
						point.face_mask=0
						for _,mask in ipairs({1,2,4,8}) do
							if point.bits[mask] then point.face_mask=point.face_mask+mask end
						end
						point.bits=nil lower_points[#lower_points+1]=point
					end
					sort_points(upper_points) sort_points(lower_points)
					local key=contact_key(upper.id,lower.id)
					local interface=vertical_interface_by_pair[key]
					local surface_columns,corridor_columns=
						path_intersections(lower_points)
					local report={upper_id=upper.id,lower_id=lower.id,
						upper_offset=upper.water_surface_offset,
						lower_offset=lower.water_surface_offset,
						unequal=upper.water_surface_offset ~= lower.water_surface_offset,
						interface_id=interface and interface.id or nil,
						edges=edges,upper_points=upper_points,lower_points=lower_points,
						edge_count=#edges,upper_count=#upper_points,lower_count=#lower_points,
						upper_bounds=point_bounds(upper_points),
						lower_bounds=point_bounds(lower_points),
						upper_components=point_components(upper_points),
						lower_components=point_components(lower_points),
						path_surface_columns=surface_columns,
						path_corridor_columns=corridor_columns,
						named_operation_columns=named_operation_intersections(lower_points),
						fitting_intersections=fitting_intersections(upper_points,lower_points),
						hard_intersections=hard_intersections(upper_points,lower_points)}
					contact_reports[#contact_reports+1]=report
					contact_pair_count=contact_pair_count+1
					if report.unequal then
						unequal_contact_pair_count=unequal_contact_pair_count+1
						if not interface then
							violate("unequal_hydrology_contact_unbound",key,#edges,
								edges[1])
						end
					end
					if interface then contact_report_by_interface[interface.id]=report end
				end
			end
		end
	end
	table.sort(contact_reports,function(a,b)
		return a.upper_id < b.upper_id or
			a.upper_id == b.upper_id and a.lower_id < b.lower_id
	end)
	if contact_pair_count ~= 12 then
		violate("hydrology_contact_pair_count_differs","hydrology",contact_pair_count,
			{expected=12,actual=contact_pair_count})
	end
	if unequal_contact_pair_count ~= 7 then
		violate("unequal_hydrology_contact_pair_count_differs","hydrology",
			unequal_contact_pair_count,{expected=7,actual=unequal_contact_pair_count})
	end
	for key,interface in pairs(vertical_interface_by_pair) do
		if not contact_report_by_interface[interface.id] then
			violate("vertical_interface_has_no_contact",interface.id,1,{pair=key})
		end
	end

	local expected_contact_faces={
		highcourt_goldmead_fall={edges=13,upper=13,lower=13,
			upper_bounds={-106,-94,-1756,-1756},lower_bounds={-106,-94,-1757,-1757},
			fitting={anchor_id="anchor_008",upper_full=13,lower_full=0,
				upper_blend=13,lower_blend=13},
			hard={hard_id="hard:anchor_008",upper=13,lower=13}},
		gravesalt_broken_fall={edges=163,upper=114,lower=114,
			upper_bounds={-1713,-1650,21,110},lower_bounds={-1712,-1649,21,110},
			fitting={anchor_id="anchor_077",upper_full=0,lower_full=0,
				upper_blend=1,lower_blend=0}},
		raincall_reedmaze_fall={edges=109,upper=66,lower=65,
			upper_bounds={2026,2070,1864,1929},lower_bounds={2026,2069,1864,1928}},
	}
	local contact_face_count=0
	for interface_index=1,#source.hydrology_interfaces do
		local interface=source.hydrology_interfaces[interface_index]
		if interface.transition_scope_id == "orthogonal_reach_contact_face_v1" then
			contact_face_count=contact_face_count+1
			local expected=expected_contact_faces[interface.id]
			local report=contact_report_by_interface[interface.id]
			local failed=not expected or not report or interface.kind ~= "waterfall" or
					interface.transition_profile_id ~= "waterfall_drop" or
					interface.drop ~= interface.upper_level_offset-interface.lower_level_offset or
					interface.drop_height ~= interface.drop or
					interface.receiver_source_omission_nodes ~= 1 or
					not interface.sealed
			if not failed then
				local ub,lb=report.upper_bounds,report.lower_bounds
				failed=report.edge_count ~= expected.edges or
					report.upper_count ~= expected.upper or report.lower_count ~= expected.lower or
					report.upper_components ~= 1 or report.lower_components ~= 1 or
					ub.min_x ~= expected.upper_bounds[1] or ub.max_x ~= expected.upper_bounds[2] or
					ub.min_z ~= expected.upper_bounds[3] or ub.max_z ~= expected.upper_bounds[4] or
					lb.min_x ~= expected.lower_bounds[1] or lb.max_x ~= expected.lower_bounds[2] or
					lb.min_z ~= expected.lower_bounds[3] or lb.max_z ~= expected.lower_bounds[4] or
					report.path_surface_columns ~= 0 or report.path_corridor_columns ~= 0 or
					report.named_operation_columns ~= 0
			end
			if not failed then
				local expected_fitting=expected.fitting
				if expected_fitting then
					failed=#report.fitting_intersections ~= 1
					local actual=report.fitting_intersections[1]
					for _,field in ipairs({"anchor_id","upper_full","lower_full",
							"upper_blend","lower_blend"}) do
						if not actual or actual[field] ~= expected_fitting[field] then failed=true end
					end
				else failed=#report.fitting_intersections ~= 0 end
				local expected_hard=expected.hard
				if expected_hard then
					failed=failed or #report.hard_intersections ~= 1
					local actual=report.hard_intersections[1]
					for _,field in ipairs({"hard_id","upper","lower"}) do
						if not actual or actual[field] ~= expected_hard[field] then failed=true end
					end
				else failed=failed or #report.hard_intersections ~= 0 end
			end
			if failed then
				violate("contact_face_proof_differs",interface.id,1,
					{report_exists=report ~= nil})
			end
		end
	end
	if contact_face_count ~= 3 then
		violate("contact_face_interface_count_differs","hydrology_interfaces",
			contact_face_count,{expected=3,actual=contact_face_count})
	end

	local hydro_interface_by_crossing={}
	local structural_interface_failures=0
	for index=1,#source.hydrology_interfaces do
		local interface=source.hydrology_interfaces[index]
		local profile=transition_profile_by_id[interface.transition_profile_id]
		local failure=nil
		if not profile or not interface.sealed or profile.kind ~= interface.kind then
			failure={reason="transition_profile_or_seal"}
		elseif interface.route_interface_id then
			local crossing=crossing_by_id[interface.route_interface_id]
			local reach=hydrology_by_id[interface.hydrology_id]
			if not crossing or not reach or crossing.kind ~= interface.kind or
					crossing.position.x ~= interface.position.x or
					crossing.position.z ~= interface.position.z then
				failure={reason="crossing_binding",x=interface.position.x,
					z=interface.position.z}
			elseif hydro_interface_by_crossing[crossing.id] then
				failure={reason="duplicate_crossing_binding",x=interface.position.x,
					z=interface.position.z}
			else
				hydro_interface_by_crossing[crossing.id]=interface
				local water,macro,owner,_,hydrology_id=classify(
					interface.position.x,interface.position.z)
				local zone=source.zones[reach.zone_numeric_id]
				if water ~= "planned_water" or macro ~= zone.macro_region or
						not hydrology_id or
						not session.path_corridor_member(crossing.route_id,
						interface.position.x,interface.position.z) then
					failure={reason="crossing_world_membership",x=interface.position.x,
						z=interface.position.z,water_class=water,owner=owner,
						hydrology_id=hydrology_id}
				end
			end
		elseif interface.kind == "confluence" then
			local outgoing=hydrology_by_id[interface.outgoing_reach_id]
			if not outgoing or not session.polyline_point_member(interface.position.x,
					interface.position.z,outgoing.centreline) then
				failure={reason="confluence_outgoing_membership",x=interface.position.x,
					z=interface.position.z}
			else
				for from_index=1,#interface.from_ids do
					local incoming=hydrology_by_id[interface.from_ids[from_index]]
					if not incoming or not session.polyline_point_member(
							interface.position.x,interface.position.z,incoming.centreline) then
						failure={reason="confluence_incoming_membership",
							x=interface.position.x,z=interface.position.z}
						break
					end
				end
			end
		elseif interface.upper_id or interface.lower_id then
			local upper=hydrology_by_id[interface.upper_id]
			local lower=hydrology_by_id[interface.lower_id]
			if not upper or not lower or
					interface.upper_level_offset ~= upper.water_surface_offset or
					interface.lower_level_offset ~= lower.water_surface_offset or
					interface.upper_level_offset <= interface.lower_level_offset then
				failure={reason="vertical_transition_offsets",
					x=interface.position.x,z=interface.position.z}
			end
		end
		if failure then
			structural_interface_failures=structural_interface_failures+1
			violate("hydrology_interface_structural_failure",interface.id,1,failure)
		end
	end

	local crossing_reports={}
	local crossing_failures=0
	for index=1,#source.crossing_interfaces do
		local crossing=source.crossing_interfaces[index]
		local route=route_by_id[crossing.route_id]
		local on_line=route and session.polyline_point_member(crossing.position.x,
			crossing.position.z,route.centreline) or false
		local in_corridor=route and session.path_corridor_member(crossing.route_id,
			crossing.position.x,crossing.position.z) or false
		local authorized=crossing.authorization_polygon and
			session.polygon_member(crossing.position.x,crossing.position.z,
				crossing.authorization_polygon) or false
		local water_kind=crossing.kind == "bridge" or crossing.kind == "ford" or
			crossing.kind == "causeway"
		local hydro_interface=hydro_interface_by_crossing[crossing.id]
		local failed=not route or not on_line or not in_corridor or
			(water_kind and (not authorized or not hydro_interface)) or
			(crossing.kind == "tunnel" and hydro_interface ~= nil)
		if failed then
			crossing_failures=crossing_failures+1
			violate("crossing_structural_failure",crossing.id,1,
				{x=crossing.position.x,z=crossing.position.z,route_exists=route ~= nil,
				on_centreline=on_line,in_corridor=in_corridor,authorized=authorized,
				hydrology_bound=hydro_interface ~= nil})
		end
		crossing_reports[#crossing_reports+1]={id=crossing.id,kind=crossing.kind,
			on_centreline=on_line,in_corridor=in_corridor,authorized=authorized,
			hydrology_bound=hydro_interface ~= nil}
	end

	local metrics={
		{name="authoritative_horizontal",value=true},
		{name="step",value=1},
		{name="bay_count",value=#source.bays},
		{name="bay_planned_nodes",value=total_bay_nodes},
		{name="bay_deep_transition_edges",value=total_bay_transitions},
		{name="channel_count",value=#source.channels},
		{name="channel_active_nodes",value=total_channel_nodes},
		{name="channel_other_water_mismatches",value=total_channel_mismatches},
		{name="wet_hydrology_reaches",value=wet_reaches},
		{name="dry_hydrology_reaches",value=dry_reaches},
		{name="hydrology_sample_failures",value=wet_sample_failures},
		{name="hydrology_contact_pairs",value=contact_pair_count},
		{name="unequal_hydrology_contact_pairs",value=unequal_contact_pair_count},
		{name="contact_face_interfaces",value=contact_face_count},
		{name="hydrology_interface_failures",value=structural_interface_failures},
		{name="crossing_failures",value=crossing_failures},
		{name="violation_count",value=#violations},
		{name="ok",value=#violations == 0},
	}

	return {
		schema="grug_wp40_simple_map_r2_water_v1",
		ok=#violations == 0,
		violations=violations,
		metrics=metrics,
		witnesses=witnesses,
		bays=bay_reports,
		channels=channel_reports,
		hydrology=hydrology_reports,
		hydrology_contacts=contact_reports,
		crossings=crossing_reports,
	}
end
