-- Deterministic R2 housing-centre packing portfolio for the fixed WP40 map.
-- World membership, exact bias distances and hash priorities stay in the
-- production evaluator. This module only aggregates eligible windows and
-- applies the reviewed two-dimensional AABB conflict rule.

local NAMED_ORDERS = {
	"minimum_conflict_degree", "maximum_conflict_degree", "edge_biased",
	"route_biased", "poi_biased", "row_major", "reverse_row_major",
}

local function integer(value)
	return type(value) == "number" and value == value and
		value ~= math.huge and value ~= -math.huge and value % 1 == 0
end

local function value_text(value)
	if value == nil then return "nil" end
	if type(value) == "boolean" then return value and "true" or "false" end
	return tostring(value)
end

local function divmod_nonnegative(numerator, denominator)
	local quotient = math.floor(numerator / denominator)
	local product = quotient * denominator
	while product > numerator do
		quotient = quotient - 1
		product = product - denominator
	end
	while numerator - product >= denominator do
		quotient = quotient + 1
		product = product + denominator
	end
	return quotient, numerator - product
end

-- Continued-fraction comparison avoids an unsafe cross product.
local function rational_compare(a, b, c, d)
	local direction = 1
	while true do
		local left, left_remainder = divmod_nonnegative(a,b)
		local right, right_remainder = divmod_nonnegative(c,d)
		if left < right then return -direction end
		if left > right then return direction end
		if left_remainder == 0 or right_remainder == 0 then
			if left_remainder == right_remainder then return 0 end
			return (left_remainder == 0 and -1 or 1) * direction
		end
		a,b = b,left_remainder
		c,d = d,right_remainder
		direction = -direction
	end
end

local function polygon_bounds(points)
	if type(points) ~= "table" or type(points[1]) ~= "table" then return nil end
	local result = {min_x=points[1].x,max_x=points[1].x,
		min_z=points[1].z,max_z=points[1].z}
	if not integer(result.min_x) or not integer(result.min_z) then return nil end
	for index = 2, #points do
		local point = points[index]
		if type(point) ~= "table" or not integer(point.x) or
				not integer(point.z) then return nil end
		result.min_x = math.min(result.min_x,point.x)
		result.max_x = math.max(result.max_x,point.x)
		result.min_z = math.min(result.min_z,point.z)
		result.max_z = math.max(result.max_z,point.z)
	end
	return result
end

return function(source, session)
	local result = {
		schema = "grug_wp40_simple_map_r2_housing_result_v1",
		ok = false,
		violations = {},
		metrics = {
			mask_count = 0,
			order_count_per_mask = 23,
			lattice_origins_per_mask = 12321,
			total_eligible_centers = 0,
			total_order_runs = 0,
			total_lattice_origins = 0,
		},
		masks = {},
		witnesses = {},
	}

	local function add_violation(code, subject, expected, actual)
		result.violations[#result.violations+1] = {
			code=code, subject=subject or "-", expected=value_text(expected),
			actual=value_text(actual),
		}
	end

	local function add_witness(code, mask_id, fields)
		local row = {code=code,mask_id=mask_id}
		for index = 1, #fields do row[fields[index][1]] = fields[index][2] end
		result.witnesses[#result.witnesses+1] = row
	end

	if type(source) ~= "table" or type(session) ~= "table" then
		add_violation("input_missing", "source/session", "tables",
			type(source) .. "/" .. type(session))
		result.metrics.violation_count = #result.violations
		return result
	end
	local required_apis = {
		"housing_point_valid_for_mask",
		"housing_hash_priority", "housing_bias_values_at",
	}
	for index = 1, #required_apis do
		local name = required_apis[index]
		if type(session[name]) ~= "function" then
			add_violation("evaluator_api_missing", name, "function",
				type(session[name]))
		end
	end
	if #result.violations > 0 then
		result.metrics.violation_count = #result.violations
		return result
	end

	local policy = type(source.housing_policy) == "table" and
		source.housing_policy or {}
	local policy_checks = {
		{"reservation_width",101}, {"reservation_radius",50},
		{"minimum_gap",10}, {"lattice_spacing",111},
		{"lattice_origin_period",111}, {"hash_order_count",16},
		{"hash_domain_prefix","housing-pack-"},
		{"hash_order_numbering","zero_based_two_digit"},
		{"conflict_rule","candidate_expanded_aabb_v1"},
		{"tie_break","z_then_x"}, {"bias_direction","nearest_first"},
		{"edge_bias_scope","mask_polygon_boundary"},
		{"route_bias_scope","all_land_route_centrelines"},
		{"poi_bias_scope","all_actual_anchor_positions_v1"},
	}
	for index = 1, #policy_checks do
		local check = policy_checks[index]
		if policy[check[1]] ~= check[2] then
			add_violation("policy_mismatch", check[1], check[2], policy[check[1]])
		end
	end
	local greedy_orders = type(policy.greedy_orders) == "table" and
		policy.greedy_orders or {}
	for index = 1, #NAMED_ORDERS do
		if greedy_orders[index] ~= NAMED_ORDERS[index] then
			add_violation("order_roster_mismatch", ("named_order_%02d"):format(index),
				NAMED_ORDERS[index], greedy_orders[index])
		end
	end
	if #greedy_orders ~= #NAMED_ORDERS then
		add_violation("order_count_mismatch", "named_orders", #NAMED_ORDERS,
			#greedy_orders)
	end
	if #result.violations > 0 then
		result.metrics.violation_count = #result.violations
		return result
	end

	local masks = type(source.housing_masks) == "table" and
		source.housing_masks or {}
	result.metrics.mask_count = #masks
	if #masks ~= 10 then add_violation("mask_count_mismatch", "housing_masks", 10,
		#masks) end
	local radius = policy.reservation_radius
	local window = policy.reservation_width
	local gap = policy.minimum_gap
	local spacing = policy.lattice_spacing
	local period = policy.lattice_origin_period
	local conflict_radius = 2*radius+gap
	result.metrics.conflict_rule = policy.conflict_rule
	result.metrics.conflict_radius = conflict_radius
	result.metrics.tie_break = policy.tie_break
	result.metrics.hash_order_count = policy.hash_order_count

	local function decode(candidate, width, first_x, first_z)
		local row = math.floor((candidate-1)/width)+1
		local column = candidate-(row-1)*width
		return first_x+column-1,first_z+row-1,row,column
	end

	local function copy_candidates(candidates)
		local ordered = {}
		for index = 1, #candidates do ordered[index] = candidates[index] end
		return ordered
	end

	local function packing(ordered, reverse, width, first_x, first_z)
		local buckets = {}
		local placements = {}
		local function consider(candidate)
			local x,z = decode(candidate,width,first_x,first_z)
			local bx,bz = math.floor(x/spacing),math.floor(z/spacing)
			for offset_z = -1, 1 do
				local bucket_row = buckets[bz+offset_z]
				if bucket_row then
					for offset_x = -1, 1 do
						local bucket = bucket_row[bx+offset_x]
						if bucket then
							for index = 1, #bucket do
								local point = bucket[index]
								if math.abs(x-point.x) <= conflict_radius and
										math.abs(z-point.z) <= conflict_radius then
									return
								end
							end
						end
					end
				end
			end
			local bucket_row = buckets[bz]
			if not bucket_row then bucket_row={} buckets[bz]=bucket_row end
			local bucket = bucket_row[bx]
			if not bucket then bucket={} bucket_row[bx]=bucket end
			local point = {x=x,z=z}
			bucket[#bucket+1] = point
			placements[#placements+1] = point
		end
		if reverse then
			for index = #ordered, 1, -1 do consider(ordered[index]) end
		else
			for index = 1, #ordered do consider(ordered[index]) end
		end
		return placements
	end

	local function validate_packing(mask_id, order_id, placements)
		for index = 1, #placements do
			local point = placements[index]
			for previous = 1, index-1 do
				local other = placements[previous]
				if math.abs(point.x-other.x) <= conflict_radius and
						math.abs(point.z-other.z) <= conflict_radius then
					add_violation("packing_conflict", mask_id .. ":" .. order_id,
						"nonconflicting", index .. "/" .. previous)
					return
				end
			end
		end
	end

	for mask_index = 1, #masks do
		local mask = masks[mask_index]
		local mask_id = type(mask) == "table" and mask.id or
			("housing_mask_%02d"):format(mask_index)
		local box = type(mask) == "table" and polygon_bounds(mask.polygon) or nil
		if type(mask_id) ~= "string" or not box then
			add_violation("mask_record_invalid", mask_id, "id and integer polygon",
				"invalid")
		else
			local first_x,last_x = box.min_x+radius,box.max_x-radius
			local first_z,last_z = box.min_z+radius,box.max_z-radius
			local center_width = last_x-first_x+1
			local center_height = last_z-first_z+1
			local vertical,ring = {},{}
			local runs,runs_by_row,candidates = {},{},{}
			local eligible_count = 0
			local lattice = {}
			for origin_z = 0, period-1 do
				local row = {}
				for origin_x = 0, period-1 do row[origin_x+1]=0 end
				lattice[origin_z+1] = row
			end
			if center_width > 0 and center_height > 0 then
				for column = 1, center_width do vertical[column]=0 end
				for z = box.min_z, box.max_z do
					local raw = {}
					for x = box.min_x, box.max_x do
						raw[x-box.min_x+1] =
							session.housing_point_valid_for_mask(mask_id,x,z) and 0 or 1
					end
					local horizontal = {}
					local invalid = 0
					for raw_index = 1, window do invalid=invalid+raw[raw_index] end
					for column = 1, center_width do
						horizontal[column] = invalid == 0 and 1 or 0
						local add_index = column+window
						if add_index <= #raw then
							invalid=invalid-raw[column]+raw[add_index]
						end
					end
					local slot = (z-box.min_z)%window+1
					local old = ring[slot]
					if old then
						for column = 1, center_width do
							vertical[column]=vertical[column]-old[column]
						end
					end
					ring[slot]=horizontal
					for column = 1, center_width do
						vertical[column]=vertical[column]+horizontal[column]
					end
					if z >= box.min_z+window-1 then
						local center_z = z-radius
						local row_index = center_z-first_z+1
						local row_runs = {}
						runs_by_row[row_index] = row_runs
						local run_start
						for column = 1, center_width do
							local eligible = vertical[column] == window
							local center_x = first_x+column-1
							if eligible then
								eligible_count=eligible_count+1
								local candidate=(row_index-1)*center_width+column
								candidates[#candidates+1]=candidate
								lattice[center_z%period+1][center_x%period+1]=
									lattice[center_z%period+1][center_x%period+1]+1
								if not run_start then run_start=center_x end
							elseif run_start then
								local run={z=center_z,min_x=run_start,max_x=center_x-1}
								runs[#runs+1]=run row_runs[#row_runs+1]=run
								run_start=nil
							end
						end
						if run_start then
							local run={z=center_z,min_x=run_start,max_x=last_x}
							runs[#runs+1]=run row_runs[#row_runs+1]=run
						end
					end
				end
			end

			local lattice_min,lattice_max,lattice_sum
			local lattice_min_x,lattice_min_z,lattice_max_x,lattice_max_z=0,0,0,0
			lattice_sum=0
			for origin_z = 0, period-1 do
				for origin_x = 0, period-1 do
					local count=lattice[origin_z+1][origin_x+1]
					lattice_sum=lattice_sum+count
					if lattice_min == nil or count < lattice_min then
						lattice_min,lattice_min_x,lattice_min_z=count,origin_x,origin_z
					end
					if lattice_max == nil or count > lattice_max then
						lattice_max,lattice_max_x,lattice_max_z=count,origin_x,origin_z
					end
				end
			end
			if lattice_sum ~= eligible_count then
				add_violation("lattice_partition_mismatch", mask_id, eligible_count,
					lattice_sum)
			end

			-- A fixed half-open 111 by 111 cell cover is an auditable clique-cover
			-- upper bound: at most one accepted centre may occupy each cell.
			local upper_cells, upper_rows, upper_bound = {},{},0
			for index = 1, #candidates do
				local x,z = decode(candidates[index],center_width,first_x,first_z)
				local bx,bz = math.floor(x/spacing),math.floor(z/spacing)
				local row=upper_rows[bz]
				if not row then row={} upper_rows[bz]=row end
				if not row[bx] then
					row[bx]=true upper_bound=upper_bound+1
					upper_cells[#upper_cells+1]={cell_x=bx,cell_z=bz}
				end
			end

			-- Integral image for the initial exact conflict-graph degree.
			local prefix={}
			for row_index = 1, center_height do
				local row_sum,run_index=0,1
				local row_runs=runs_by_row[row_index] or {}
				for column = 1, center_width do
					local x=first_x+column-1
					while row_runs[run_index] and x > row_runs[run_index].max_x do
						run_index=run_index+1
					end
					local run=row_runs[run_index]
					if run and x >= run.min_x then row_sum=row_sum+1 end
					local candidate=(row_index-1)*center_width+column
					prefix[candidate]=(row_index > 1 and
						prefix[candidate-center_width] or 0)+row_sum
				end
			end
			local function prefix_at(row,column)
				if row < 1 or column < 1 then return 0 end
				return prefix[(row-1)*center_width+column]
			end
			local degrees={}
			for index = 1, #candidates do
				local candidate=candidates[index]
				local _,_,row,column=decode(candidate,center_width,first_x,first_z)
				local left=math.max(1,column-conflict_radius)
				local right=math.min(center_width,column+conflict_radius)
				local top=math.max(1,row-conflict_radius)
				local bottom=math.min(center_height,row+conflict_radius)
				degrees[candidate]=prefix_at(bottom,right)-prefix_at(top-1,right)-
					prefix_at(bottom,left-1)+prefix_at(top-1,left-1)-1
			end
			prefix=nil

			local orders={}
			local function record_order(order_id,kind,ordered,reverse)
				local placements=packing(ordered,reverse,center_width,first_x,first_z)
				validate_packing(mask_id,order_id,placements)
				local row={id=order_id,kind=kind,count=#placements,
					placements=placements}
				orders[#orders+1]=row
				result.metrics.total_order_runs=result.metrics.total_order_runs+1
				return row
			end

			local ordered=copy_candidates(candidates)
			table.sort(ordered,function(a,b)
				if degrees[a] ~= degrees[b] then return degrees[a] < degrees[b] end
				return a < b
			end)
			record_order("minimum_conflict_degree","graph_degree",ordered,false)
			ordered=copy_candidates(candidates)
			table.sort(ordered,function(a,b)
				if degrees[a] ~= degrees[b] then return degrees[a] > degrees[b] end
				return a < b
			end)
			record_order("maximum_conflict_degree","graph_degree",ordered,false)
			degrees=nil

			local edge_n,edge_d,route_n,route_d,poi_n,poi_d={},{},{},{},{},{}
			for index = 1, #candidates do
				local candidate=candidates[index]
				local x,z=decode(candidate,center_width,first_x,first_z)
				local bias=session.housing_bias_values_at(mask_id,x,z)
				local valid=type(bias)=="table" and integer(bias.edge_numerator) and
					integer(bias.edge_denominator) and bias.edge_denominator > 0 and
					integer(bias.route_numerator) and integer(bias.route_denominator) and
					bias.route_denominator > 0 and integer(bias.poi_numerator) and
					integer(bias.poi_denominator) and bias.poi_denominator > 0
				if not valid then
					add_violation("bias_value_invalid", mask_id, "six rational fields",
						"invalid")
					edge_n[candidate],edge_d[candidate]=0,1
					route_n[candidate],route_d[candidate]=0,1
					poi_n[candidate],poi_d[candidate]=0,1
				else
					edge_n[candidate],edge_d[candidate]=
						bias.edge_numerator,bias.edge_denominator
					route_n[candidate],route_d[candidate]=
						bias.route_numerator,bias.route_denominator
					poi_n[candidate],poi_d[candidate]=
						bias.poi_numerator,bias.poi_denominator
				end
			end
			local bias_specs={
				{"edge_biased",edge_n,edge_d}, {"route_biased",route_n,route_d},
				{"poi_biased",poi_n,poi_d},
			}
			for spec_index = 1, #bias_specs do
				local spec=bias_specs[spec_index]
				ordered=copy_candidates(candidates)
				table.sort(ordered,function(a,b)
					local comparison=rational_compare(spec[2][a],spec[3][a],
						spec[2][b],spec[3][b])
					if comparison ~= 0 then return comparison < 0 end
					return a < b
				end)
				record_order(spec[1],"nearest_bias",ordered,false)
			end
			edge_n,edge_d,route_n,route_d,poi_n,poi_d=nil,nil,nil,nil,nil,nil

			record_order("row_major","coordinate",candidates,false)
			record_order("reverse_row_major","coordinate",candidates,true)

			for ordinal = 1, policy.hash_order_count do
				local priorities={}
				for index = 1, #candidates do
					local candidate=candidates[index]
					local x,z=decode(candidate,center_width,first_x,first_z)
					local priority=session.housing_hash_priority(ordinal,mask_id,x,z)
					if not integer(priority) or priority < 0 or priority > 4294967295 then
						add_violation("hash_priority_invalid", mask_id,
							"unsigned 32-bit", priority)
						priority=0
					end
					priorities[candidate]=priority
				end
				ordered=copy_candidates(candidates)
				table.sort(ordered,function(a,b)
					if priorities[a] ~= priorities[b] then
						return priorities[a] < priorities[b]
					end
					return a < b
				end)
				local domain=policy.hash_domain_prefix .. ("%02d"):format(ordinal-1)
				record_order(domain,"canonical_hash_word_0",ordered,false)
				priorities=nil
			end

			local sequence_min,sequence_max,minimum_order,maximum_order
			for index = 1, #orders do
				local order=orders[index]
				if sequence_min == nil or order.count < sequence_min then
					sequence_min,minimum_order=order.count,order.id
				end
				if sequence_max == nil or order.count > sequence_max then
					sequence_max,maximum_order=order.count,order.id
				end
				if order.count > upper_bound then
					add_violation("packing_exceeds_upper_bound", mask_id .. ":" .. order.id,
						upper_bound, order.count)
				end
			end
			if (lattice_max or 0) > upper_bound then
				add_violation("lattice_exceeds_upper_bound", mask_id, upper_bound,
					lattice_max)
			end
			if eligible_count == 0 or (sequence_min or 0) == 0 then
				add_violation("housing_mask_empty", mask_id,
					"eligible center and positive greedy packing", eligible_count)
			end

			local constructive_min=math.min(lattice_min or 0,sequence_min or 0)
			local constructive_max=math.max(lattice_max or 0,sequence_max or 0)
			result.masks[mask_index]={
				id=mask_id,zone_numeric_id=mask.zone_numeric_id,
				eligible_count=eligible_count,runs=runs,
				lattice={origin_count=period*period,counts=lattice,
					minimum=lattice_min or 0,maximum=lattice_max or 0,
					sum=lattice_sum,minimum_origin={x=lattice_min_x,z=lattice_min_z},
					maximum_origin={x=lattice_max_x,z=lattice_max_z}},
				portfolio={order_count=#orders,orders=orders,
					minimum=sequence_min or 0,minimum_order=minimum_order,
					maximum=sequence_max or 0,maximum_order=maximum_order},
				constructive_minimum=constructive_min,
				constructive_maximum=constructive_max,
				auditable_upper_bound=upper_bound,
				upper_bound_partition={origin_x=0,origin_z=0,cell_size=spacing,
					occupied_cells=upper_cells},
			}
			result.metrics.total_eligible_centers=
				result.metrics.total_eligible_centers+eligible_count
			result.metrics.total_lattice_origins=
				result.metrics.total_lattice_origins+period*period
			add_witness("lattice_minimum",mask_id,{{"count",lattice_min or 0},
				{"origin_x",lattice_min_x},{"origin_z",lattice_min_z}})
			add_witness("lattice_maximum",mask_id,{{"count",lattice_max or 0},
				{"origin_x",lattice_max_x},{"origin_z",lattice_max_z}})
			add_witness("portfolio_minimum",mask_id,{{"count",sequence_min or 0},
				{"order_id",minimum_order or "-"}})
			add_witness("portfolio_maximum",mask_id,{{"count",sequence_max or 0},
				{"order_id",maximum_order or "-"}})
			add_witness("auditable_upper_bound",mask_id,{{"count",upper_bound},
				{"origin_x",0},{"origin_z",0},{"cell_size",spacing}})
		end
	end

	result.metrics.violation_count=#result.violations
	result.ok=#result.violations == 0
	return result
end
