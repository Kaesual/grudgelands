-- Shared one-step grade envelopes for intersecting digital path axes.

return function()
	local function heap_push(heap, item, better)
		local index = #heap + 1
		heap[index] = item
		while index > 1 do
			local parent = math.floor(index / 2)
			if not better(item, heap[parent]) then break end
			heap[index] = heap[parent]
			index = parent
		end
		heap[index] = item
	end

	local function heap_pop(heap, better)
		local first, last = heap[1], heap[#heap]
		heap[#heap] = nil
		if #heap > 0 then
			local index = 1
			while index * 2 <= #heap do
				local child = index * 2
				if child < #heap and better(heap[child + 1], heap[child]) then
					child = child + 1
				end
				if not better(heap[child], last) then break end
				heap[index] = heap[child]
				index = child
			end
			heap[index] = last
		end
		return first
	end

	local function envelope(values, adjacency, maximize)
		local result, heap = {}, {}
		local function better(a, b)
			if a.value ~= b.value then
				if maximize then return a.value > b.value end
				return a.value < b.value
			end
			return a.node < b.node
		end
		for node = 1, #values do
			result[node] = values[node]
			heap_push(heap, {node = node, value = values[node]}, better)
		end
		while #heap > 0 do
			local item = heap_pop(heap, better)
			if item.value == result[item.node] then
				local next_value = item.value + (maximize and -1 or 1)
				local neighbours = adjacency[item.node]
				for index = 1, #neighbours do
					local other = neighbours[index]
					if maximize and next_value > result[other] or
							not maximize and next_value < result[other] then
						result[other] = next_value
						heap_push(heap, {node = other, value = next_value}, better)
					end
				end
			end
		end
		return result
	end

	local function solve(lower, upper, preferred, edges)
		local adjacency = {}
		for node = 1, #lower do adjacency[node] = {} end
		for index = 1, #edges do
			local edge = edges[index]
			adjacency[edge[1]][#adjacency[edge[1]] + 1] = edge[2]
			adjacency[edge[2]][#adjacency[edge[2]] + 1] = edge[1]
		end
		local lo = envelope(lower, adjacency, true)
		local up = envelope(upper, adjacency, false)
		local bounded = {}
		for node = 1, #lower do
			if lo[node] > up[node] then return nil, node, lo[node], up[node] end
			bounded[node] = math.max(lo[node], math.min(up[node], preferred[node]))
		end
		local maximum = envelope(bounded, adjacency, true)
		local minimum = envelope(bounded, adjacency, false)
		local result = {}
		for node = 1, #lower do
			result[node] = math.floor((maximum[node] + minimum[node]) / 2)
		end
		return result, lo, up
	end

	local function solve_paths(paths, grade_min, grade_max, visible_owner)
		local node_path, node_run, node_by_path = {}, {}, {}
		local lower, upper, preferred, edges, edge_keys = {}, {}, {}, {}, {}
		local fixed_nodes = {}
		local function add_edge(a, b)
			if not a or not b or a == b then return end
			if b < a then a, b = b, a end
			local key = tostring(a) .. ":" .. tostring(b)
			if not edge_keys[key] then
				edge_keys[key] = true
				edges[#edges + 1] = {a, b}
			end
		end
		for path_index = 1, #paths do
			local path = paths[path_index]
			node_by_path[path.id] = {}
			for run = 1, #path.axis do
				local node = #node_path + 1
				node_path[node], node_run[node] = path, run
				node_by_path[path.id][run] = node
				local pin = path.pins[run]
				lower[node] = pin and pin.y or path.lower[run] or grade_min
				upper[node] = pin and pin.y or grade_max
				preferred[node] = path.y[run]
				if run > 1 then add_edge(node - 1, node) end
			end
		end
		for path_index = 1, #paths do
			local previous
			for run = 1, #paths[path_index].axis do
				local point = paths[path_index].axis[run]
				local owner, owner_run, fixed_id, fixed_y =
					visible_owner(point.x, point.z)
				local node = owner and owner_run and
					node_by_path[owner.id][owner_run] or nil
				if fixed_id then
					node = fixed_nodes[fixed_id]
					if node and lower[node] ~= fixed_y then
						error("WP40 coupled grade fixed authority differs at " ..
							tostring(fixed_id), 0)
					end
					if not node then
						node = #node_path + 1
						fixed_nodes[fixed_id], node_path[node], node_run[node] =
							node, {id = fixed_id}, 0
						lower[node], upper[node], preferred[node] = fixed_y, fixed_y, fixed_y
					end
				end
				if not node then
					error("WP40 coupled grade visible owner missing at " ..
						paths[path_index].id .. " run " .. tostring(run) .. " x/z " ..
						tostring(point.x) .. "/" .. tostring(point.z), 0)
				end
				add_edge(previous, node)
				previous = node
			end
		end
		local result, failed_node, failed_lower, failed_upper =
			solve(lower, upper, preferred, edges)
		if not result then return nil, node_path[failed_node],
			node_run[failed_node], failed_lower, failed_upper end
		for node = 1, #result do
			if node_run[node] ~= 0 then node_path[node].y[node_run[node]] = result[node] end
		end
		return true
	end

	return {solve = solve, solve_paths = solve_paths}
end
