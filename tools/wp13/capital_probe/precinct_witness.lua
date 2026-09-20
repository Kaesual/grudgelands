-- Bounded readback of the authored civic ring and its axis gate thresholds.
return function(params)
	local core, fail = core, params.fail
	local key, anchor, composition = params.key, params.anchor, params.composition
	local expected = {}
	for _, cell in ipairs(composition.cells) do
		expected[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
			{name = cell.name, param2 = cell.param2 or 0}
	end
	local rows = {"capital\tkind\tx\ty\tz\texpected\tactual\tparam2\n"}
	local digest_rows, ring_columns, ring_cells = {}, {}, 0
	local function actual_at(x, y, z)
		local node = core.get_node({x = anchor.x + x, y = anchor.y + y,
			z = anchor.z + z})
		if node.name == "ignore" then fail("precinct readback is unloaded") end
		return node
	end
	local seen = {}
	for offset = -48, 48 do
		for _, point in ipairs({{offset, -48}, {48, offset},
				{offset, 48}, {-48, offset}}) do
			local x, z = point[1], point[2]
			local column_key = x .. ":" .. z
			if not seen[column_key] then
				seen[column_key] = true
				local authored = false
				for y = 0, 4 do
					local want = expected[x .. ":" .. y .. ":" .. z]
					if want then
						authored = true
						local got = actual_at(x, y, z)
						if got.name ~= want.name or (got.param2 or 0) ~= want.param2 then
							fail("precinct authored cell differs at " .. x .. "/" .. y .. "/" .. z)
						end
						local record = table.concat({x, y, z, got.name, got.param2 or 0}, ":")
						digest_rows[#digest_rows + 1] = record
						rows[#rows + 1] = table.concat({key, "ring", x, y, z,
							want.name, got.name, got.param2 or 0}, "\t") .. "\n"
						ring_cells = ring_cells + 1
					end
				end
				if authored then ring_columns[#ring_columns + 1] = column_key end
			end
		end
	end
	if #ring_columns < 250 or ring_cells < #ring_columns then
		fail("precinct authored ring coverage differs")
	end

	local gates = {{49, 0}, {-49, 0}, {0, 49}, {0, -49}}
	local authored_gates = 0
	for _, gate in ipairs(gates) do
		local x, z = gate[1], gate[2]
		local floor = expected[x .. ":0:" .. z]
		if floor then
			authored_gates = authored_gates + 1
			local got_floor = actual_at(x, 0, z)
			if got_floor.name ~= floor.name or (got_floor.param2 or 0) ~= floor.param2 then
				fail("gate threshold differs at " .. x .. "/" .. z)
			end
			local floor_def = core.registered_nodes[got_floor.name]
			if not floor_def or not floor_def.walkable then fail("gate floor is not walkable") end
			for y = 1, 2 do
				local got = actual_at(x, y, z)
				local definition = core.registered_nodes[got.name]
				if not definition or definition.walkable then
					fail("gate doorway is blocked at " .. x .. "/" .. y .. "/" .. z)
				end
				local want = expected[x .. ":" .. y .. ":" .. z]
				if want and (got.name ~= want.name or (got.param2 or 0) ~= want.param2) then
					fail("authored gate doorway cell differs")
				end
				rows[#rows + 1] = table.concat({key, "gate", x, y, z,
					want and want.name or "passable", got.name, got.param2 or 0}, "\t") .. "\n"
			end
			rows[#rows + 1] = table.concat({key, "gate_floor", x, 0, z,
				floor.name, got_floor.name, got_floor.param2 or 0}, "\t") .. "\n"
		end
	end
	if authored_gates < 3 or authored_gates > 4 then fail("authored gate count differs") end
	table.sort(digest_rows)
	local digest = core.sha256(table.concat(digest_rows, "\n"), false)
	local file = assert(io.open(params.worldpath .. "/" .. key .. "-precinct.tsv", "wb"))
	file:write(table.concat(rows)); assert(file:close())
	params.log({"event=precinct", "capital=" .. key,
		"authored_ring_columns=" .. #ring_columns, "authored_ring_cells=" .. ring_cells,
		"authored_gates=" .. authored_gates, "digest=" .. digest, "status=PASS"})
end
