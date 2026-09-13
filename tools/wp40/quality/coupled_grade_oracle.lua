-- Independent all-pairs oracle for the coupled path-grade envelope solver.

return function(repo, production_repo)
	production_repo = production_repo or repo
	local solve = dofile(production_repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/coupled_grade.lua")().solve
	local function check(value, message)
		if not value then error("coupled grade oracle: " .. message, 0) end
	end
	local function copy(values)
		local result = {}
		for index = 1, #values do result[index] = values[index] end
		return result
	end
	local function oracle(lower, upper, preferred, edges)
		local count, infinity = #lower, 1000000000
		local distance = {}
		for a = 1, count do
			distance[a] = {}
			for b = 1, count do distance[a][b] = a == b and 0 or infinity end
		end
		for index = 1, #edges do
			local a, b = edges[index][1], edges[index][2]
			distance[a][b], distance[b][a] = 1, 1
		end
		for through = 1, count do
			for a = 1, count do
				for b = 1, count do
					local candidate = distance[a][through] + distance[through][b]
					if candidate < distance[a][b] then distance[a][b] = candidate end
				end
			end
		end
		local lo, up, bounded = {}, {}, {}
		for a = 1, count do
			lo[a], up[a] = lower[a], upper[a]
			for b = 1, count do
				if distance[a][b] < infinity then
					lo[a] = math.max(lo[a], lower[b] - distance[a][b])
					up[a] = math.min(up[a], upper[b] + distance[a][b])
				end
			end
			if lo[a] > up[a] then return nil, lo, up end
			bounded[a] = math.max(lo[a], math.min(up[a], preferred[a]))
		end
		local result = {}
		for a = 1, count do
			local maximum, minimum = bounded[a], bounded[a]
			for b = 1, count do
				if distance[a][b] < infinity then
					maximum = math.max(maximum, bounded[b] - distance[a][b])
					minimum = math.min(minimum, bounded[b] + distance[a][b])
				end
			end
			result[a] = math.floor((maximum + minimum) / 2)
		end
		return result, lo, up
	end
	local function equal(actual, expected, label)
		check(#actual == #expected, label .. " length")
		for index = 1, #expected do
			check(actual[index] == expected[index], label .. " node " .. index ..
				" expected " .. expected[index] .. " got " .. actual[index])
		end
	end
	local case_count, node_count, edge_count, digest = 0, 0, 0, 0
	local function verify(label, lower, upper, preferred, edges)
		local expected, expected_lo, expected_up = oracle(lower, upper,
			preferred, edges)
		local actual, second, third, fourth = solve(copy(lower), copy(upper),
			copy(preferred), edges)
		check((actual == nil) == (expected == nil), label .. " feasibility")
		if actual then
			equal(actual, expected, label .. " result")
			equal(second, expected_lo, label .. " lower envelope")
			equal(third, expected_up, label .. " upper envelope")
			for index = 1, #edges do
				check(math.abs(actual[edges[index][1]] -
					actual[edges[index][2]]) <= 1, label .. " edge grade")
			end
			for index = 1, #actual do
				digest = (digest * 65599 + actual[index] * 17 +
					expected_lo[index] * 7 + expected_up[index]) % 2147483647
			end
		else
			check(second and third and fourth and third > fourth,
				label .. " infeasible witness")
		end
		case_count, node_count = case_count + 1, node_count + #lower
		edge_count = edge_count + #edges
		return actual
	end

	verify("cycle/shared/pins", {0, -20, -20, 2, -20},
		{0, 20, 20, 2, 20}, {0, 12, -9, 2, 8},
		{{1, 2}, {2, 3}, {3, 1}, {3, 4}, {4, 5}})
	verify("disconnected/negative", {-9, -20, 4, -30, -30, -7},
		{-9, 20, 4, 30, 30, -7}, {-9, 18, 4, -29, 28, -7},
		{{1, 2}, {4, 5}})
	verify("infeasible pins", {0, 4, -10}, {0, 4, 10}, {0, 4, 0},
		{{1, 2}, {2, 3}})

	-- Dense deterministic coverage varies graph topology, signs, pins and bounds.
	for count = 1, 6 do
		for variant = 0, 47 do
			local lower, upper, preferred, edges = {}, {}, {}, {}
			for node = 1, count do
				local center = ((variant * 7 + node * 11) % 19) - 12
				local radius = (variant + node * 3) % 5
				if (variant + node) % 7 == 0 then radius = 0 end
				lower[node], upper[node] = center - radius, center + radius
				preferred[node] = ((variant * 13 + node * 5) % 41) - 23
			end
			for a = 1, count do
				for b = a + 1, count do
					if (variant + a * 3 + b * 5) % 4 <= 1 then
						edges[#edges + 1] = {a, b}
					end
				end
			end
			verify("generated " .. count .. "/" .. variant,
				lower, upper, preferred, edges)
		end
	end

	-- Edge order and node numbering cannot expose heap insertion order.
	local lower, upper, preferred = {-8, -5, -10, -3, -12, -6},
		{8, 9, 4, 11, 7, 6}, {8, -5, 3, 10, -11, 1}
	local edges = {{1, 2}, {2, 3}, {3, 4}, {4, 1}, {2, 5}, {5, 6}}
	local base = verify("permutation base", lower, upper, preferred, edges)
	local reversed = {}
	for index = #edges, 1, -1 do
		reversed[#reversed + 1] = {edges[index][2], edges[index][1]}
	end
	equal(verify("edge permutation", lower, upper, preferred, reversed), base,
		"edge permutation mapped")
	local permutation = {4, 1, 6, 2, 5, 3}
	local inverse, pl, pu, pp, pe = {}, {}, {}, {}, {}
	for old = 1, #permutation do inverse[permutation[old]] = old end
	for new = 1, #permutation do
		local old = inverse[new]
		pl[new], pu[new], pp[new] = lower[old], upper[old], preferred[old]
	end
	for index = 1, #edges do
		pe[index] = {permutation[edges[index][1]], permutation[edges[index][2]]}
	end
	local permuted = verify("node permutation", pl, pu, pp, pe)
	local mapped = {}
	for old = 1, #permutation do mapped[old] = permuted[permutation[old]] end
	equal(mapped, base, "node permutation mapped")

	-- Bounded scale guards against accidentally quadratic heap relaxation.
	for _, shape in ipairs({"line", "fan"}) do
		local count, lower_large, upper_large, preferred_large, large_edges =
			768, {}, {}, {}, {}
		for node = 1, count do
			lower_large[node], upper_large[node] = -4096, 4096
			preferred_large[node] = ((node * 7919) % 997) - 600
			if node > 1 then
				large_edges[#large_edges + 1] = shape == "line" and
					{node - 1, node} or {1, node}
			end
		end
		local result = assert(solve(lower_large, upper_large, preferred_large,
			large_edges))
		check(#result == count, shape .. " scale result")
		for index = 1, #large_edges do
			local edge = large_edges[index]
			check(math.abs(result[edge[1]] - result[edge[2]]) <= 1,
				shape .. " scale edge")
		end
		digest = (digest * 65599 + result[1] * 17 + result[count]) % 2147483647
	end

	return table.concat({"schema\tgrug_wp40_coupled_grade_oracle_v1",
		"cases\t" .. case_count, "nodes\t" .. node_count,
		"edges\t" .. edge_count, "digest\t" .. digest,
		"scale\t768\tline,fan", "coupled_grade_oracle\tok"}, "\n") .. "\n"
end
