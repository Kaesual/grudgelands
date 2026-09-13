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
				return maximize and a.value > b.value or a.value < b.value
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

	return {solve = solve}
end
