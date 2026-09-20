-- Focused engine-free check for the clipped WP13 settlement successors.
--
-- Runs every settlement in the `r7_settlement.lua` roster through the real
-- prepare/config factory over the real owner grid: every cell of every
-- blueprint must be written exactly once, by the owner that contains it,
-- through R7's opcode-37 writer, and an owner that contains no settlement must
-- write nothing at all.
--
-- Since the seam generalisation a settlement may own several blueprints of
-- three kinds, so the fixture drives all three: the anchor-relative core, the
-- terrain-relative plots against a stub height function, and the per-mapchunk
-- avenue overlay, whose cells it collects owner by owner and compares with the
-- union it computes from the whole runs.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local module = dofile(wp40 .. "/r7_settlement.lua")
	assert(#module.roster >= 2, "the settlement roster lost a start")

	-- A stub final-height field. It is deliberately NOT flat: a terrace every
	-- 32 nodes with a three-node step is what makes a plot's reference column
	-- and the avenue's envelope observable at all.
	local function stub_height(x, z)
		local terrace = math.floor((x + 4096) / 32) + math.floor((z + 4096) / 32)
		return 40 + terrace % 3
	end
	local planner_source = {}
	local height_calls = 0
	function planner_source.column_values_at(x, z)
		height_calls = height_calls + 1
		return "land", 1, "zone", "biome", "region", stub_height(x, z)
	end

	-- The shared opcode-37 content channel: the sorted ASCII union of every
	-- settlement's palette, exactly as `r7_runtime.lua` builds it.
	local prepared, union, seen = {}, {}, {}
	local sha = common.new_sha256()
	for index = 1, #module.roster do
		local profile = module.roster[index]
		local source = dofile(wp40 .. "/" .. profile.blueprint_file)()
		if type(source) == "function" then source = source() end
		local entry = module.prepare(profile, source, sha)
		prepared[index] = entry
		for _, name in ipairs(entry.palette) do
			if not seen[name] then
				seen[name] = true
				union[#union + 1] = name
			end
		end
	end
	table.sort(union, module.less_bytes)
	local ref_by_name, cid_by_ref = {}, {}
	for index = 1, #union do
		ref_by_name[union[index]] = index
		cid_by_ref[index] = 1000 + index
	end
	local content = {schema = "grug_wp13_settlement_content_v1",
		content_names = union}
	function content.content_ref(name) return ref_by_name[name] end
	function content.resolve(ref, param2) return cid_by_ref[ref], param2 end

	local function owner_minimum(value)
		return -30912 + math.floor((value + 30912) / 80) * 80
	end

	local report = {}
	for index = 1, #module.roster do
		local profile = module.roster[index]
		local entry = prepared[index]
		local config = module.config(entry, content, sha)
		assert(config.schema == profile.config_schema)
		assert(config.identity.schema == profile.identity_schema)
		assert(#config.identities == #entry.blueprints)
		local anchor = {id = profile.anchor_id, numeric_id = profile.numeric_id,
			x = profile.x, y = 40, z = profile.z}
		local dependencies = {planner_source = planner_source,
			zones_session = {anchor = function(zone_id, slot_id)
				if zone_id == profile.zone_id and slot_id == profile.slot then
					return anchor
				end
			end}}
		local tail = config.new(dependencies)
		assert(tail.key == profile.key)
		-- A neighbouring settlement's zone must not answer this one's anchor.
		local other = module.roster[(index % #module.roster) + 1]
		assert(not pcall(config.new, {planner_source = planner_source,
			zones_session = {anchor = function()
				return {id = other.anchor_id, numeric_id = other.numeric_id,
					x = other.x, y = 40, z = other.z}
			end}}), "the successor accepted a foreign anchor")

		-- Every expected cell, in world space, from every blueprint kind. The
		-- overlay's expectation is computed from the WHOLE run, which is what
		-- makes the per-mapchunk pieces' union the property under test.
		local expected, expected_count = {}, 0
		local min_x, max_x, min_y, max_y, min_z, max_z
		local function note(x, y, z)
			local key = x .. "/" .. y .. "/" .. z
			assert(not expected[key], profile.key ..
				": two blueprints claim " .. key)
			expected[key] = true
			expected_count = expected_count + 1
			if min_x == nil or x < min_x then min_x = x end
			if max_x == nil or x > max_x then max_x = x end
			if min_y == nil or y < min_y then min_y = y end
			if max_y == nil or y > max_y then max_y = y end
			if min_z == nil or z < min_z then min_z = z end
			if max_z == nil or z > max_z then max_z = z end
		end
		local reserved = profile.reserve_anchor_root and
			(anchor.x .. "/" .. (anchor.y + 1) .. "/" .. anchor.z) or nil
		local overlay_cells = 0
		for blueprint_index = 1, #entry.blueprints do
			local blueprint = entry.blueprints[blueprint_index]
			local descriptor = blueprint.descriptor
			if descriptor.kind == "overlay" then
				-- The oracle for the overlay: every WHOLE run, in authored order,
				-- with the seam's own two arbitration rules recomputed here -- the
				-- first run wins a shared cell, and no lamp standard may stand in
				-- another run's carriageway. What the owner loop then proves is
				-- that the mapchunk pieces' union is exactly this.
				local carriageways = {}
				for run_index = 1, #blueprint.runs do
					local run = blueprint.runs[run_index]
					local half = blueprint.half
					if run.axis == "x" then
						carriageways[run_index] = {min_x = run.from, max_x = run.to,
							min_z = run.at - half, max_z = run.at + half}
					else
						carriageways[run_index] = {min_z = run.from, max_z = run.to,
							min_x = run.at - half, max_x = run.at + half}
					end
				end
				local taken = {}
				for run_index = 1, #blueprint.runs do
					local run = blueprint.runs[run_index]
					-- The junction squares travel with the run exactly as the
					-- seam hands them over (`wp40/r7_settlement.lua`): a plateau
					-- where two streets cross is part of the road's own geometry,
					-- so a fixture that left them out would be comparing the
					-- settlement against a road nobody builds.
					local piece = blueprint.run({id = run.id, axis = run.axis,
						at = run.at, from = run.from, to = run.to,
						width = blueprint.width, lamp_spacing = blueprint.lamp_spacing,
						lamp_phase = run.from, reach = blueprint.reach,
						junctions = run.junctions,
						plain_verge = run.plain_verge,
						clear_verge = run.clear_verge},
						function(x, z)
							return stub_height(anchor.x + x, anchor.z + z)
						end)
					local dropped = {}
					for lamp_index = 1, #piece.lamps do
						local lamp = piece.lamps[lamp_index]
						for other_index = 1, #carriageways do
							local other = carriageways[other_index]
							if other_index ~= run_index and lamp.x >= other.min_x and
									lamp.x <= other.max_x and lamp.z >= other.min_z and
									lamp.z <= other.max_z then
								for y = lamp.y - 2, lamp.y do
									dropped[lamp.x .. "/" .. y .. "/" .. lamp.z] = true
								end
								break
							end
						end
					end
					for cell_index = 1, #piece.cells do
						local cell = piece.cells[cell_index]
						local local_key = cell.x .. "/" .. cell.y .. "/" .. cell.z
						if not dropped[local_key] and not taken[local_key] then
							taken[local_key] = true
							note(anchor.x + cell.x, cell.y, anchor.z + cell.z)
							overlay_cells = overlay_cells + 1
						end
					end
				end
			else
				-- The cells the identity was hashed from. A lazy settlement
				-- released them, so the builder is asked again -- which is also
				-- the fixture's proof that a rebuild produces the same blueprint.
				local cells = blueprint.cells
				local base_y = anchor.y
				if not cells then
					local rebuilt = descriptor.build()
					cells = rebuilt.cells
					assert(#cells == blueprint.identity.cell_count,
						profile.key .. ": the rebuild of " .. descriptor.id ..
						" has a different cell count")
				end
				local base_x, base_z = anchor.x, anchor.z
				if descriptor.kind == "reference" then
					base_x, base_z = anchor.x + descriptor.offset.x,
						anchor.z + descriptor.offset.z
					base_y = stub_height(base_x + blueprint.reference.x,
						base_z + blueprint.reference.z)
				end
				for cell_index = 1, #cells do
					local cell = cells[cell_index]
					local x, y, z = base_x + cell.x, base_y + cell.y, base_z + cell.z
					local key = x .. "/" .. y .. "/" .. z
					if key ~= reserved then note(x, y, z) end
				end
			end
		end
		assert(overlay_cells == 0 or profile.slot == "capital")

		local seen_cells, written = {}, 0
		for owner_z = owner_minimum(min_z), owner_minimum(max_z), 80 do
			for owner_y = owner_minimum(min_y), owner_minimum(max_y), 80 do
				for owner_x = owner_minimum(min_x), owner_minimum(max_x), 80 do
					local plan = {}
					local minp = {x = owner_x, y = owner_y, z = owner_z}
					local maxp = {x = owner_x + 79, y = owner_y + 79,
						z = owner_z + 79}
					tail:bind_plan(minp, maxp, plan, 1)
					local context = {plan = plan, generation = 1,
						call_mode = "fixture",
						min_x = minp.x, min_y = minp.y, min_z = minp.z,
						max_x = maxp.x, max_y = maxp.y, max_z = maxp.z}
					function context.inside_owner(x, y, z)
						return x >= minp.x and x <= maxp.x and y >= minp.y and
							y <= maxp.y and z >= minp.z and z <= maxp.z
					end
					function context.write_hearthpine(x, y, z, cid, param2, ref,
							feature)
						local key = x .. "/" .. y .. "/" .. z
						assert(not seen_cells[key] and cid == cid_by_ref[ref] and
							param2 >= 0 and param2 <= 255 and feature == 1)
						assert(ref >= 1 and ref <= #union,
							"content ref escaped the shared channel")
						assert(expected[key],
							profile.key .. " wrote the unexpected cell " .. key)
						assert(context.inside_owner(x, y, z),
							profile.key .. " wrote outside its owner")
						seen_cells[key], written = true, written + 1
					end
					local ledger = tail:settle(context)
					assert(ledger.schema == profile.ledger_schema)
				end
			end
		end
		assert(written == expected_count, profile.key .. " wrote " .. written ..
			" of " .. expected_count .. " cells")
		for key in pairs(expected) do
			assert(seen_cells[key], profile.key .. " never wrote " .. key)
		end
		-- The reserved anchor root: the writer must leave the guard banner the
		-- anchor writer put there, and the composition must have had nothing but
		-- air in that cell for the reservation to be free.
		if reserved then
			assert(not seen_cells[reserved],
				profile.key .. " overwrote the anchor root " .. reserved)
		end
		-- An owner that holds no settlement writes nothing.
		local far_plan = {}
		tail:bind_plan({x = 8000, y = 0, z = 8000}, {x = 8079, y = 79, z = 8079},
			far_plan, 2)
		local far_context = {plan = far_plan, generation = 2,
			call_mode = "replay_fixture", min_x = 8000, min_y = 0, min_z = 8000,
			max_x = 8079, max_y = 79, max_z = 8079,
			inside_owner = function() return true end,
			write_hearthpine = function() error("inactive owner wrote", 0) end}
		assert(tail:settle(far_context).written == 0)
		local metrics = tail:metrics()
		assert(metrics.schema == profile.metrics_schema)
		assert(metrics.written == expected_count and metrics.replay_calls == 1)
		-- Lazy construction: a settlement marked lazy built at least once on
		-- demand, and an eager one never did.
		if profile.lazy then
			assert(metrics.build_calls >= 1, profile.key .. " never built lazily")
		else
			assert(metrics.build_calls == 0, profile.key .. " built lazily")
		end
		local identity_row = {profile.key, config.identity.sha256, written,
			metrics.settle_calls, metrics.replay_calls, metrics.build_calls,
			metrics.release_calls}
		report[#report + 1] = table.concat(identity_row, "/")
		for blueprint_index = 1, #config.identities do
			local row = config.identities[blueprint_index]
			report[#report + 1] = table.concat({row.prefix, row.kind,
				row.identity.sha256, row.identity.cell_count}, "/")
		end
	end

	-- One composed successor tail: every settlement planned and settled
	-- together, with an owner that belongs to none writing nothing.
	local successor_factory = dofile(wp40 .. "/r7_successor.lua")
	local configs, keys = {}, {}
	for index = 1, #module.roster do
		configs[index] = module.config(prepared[index], content, sha)
		keys[index] = module.roster[index].key
	end
	local stub_calls = {plan = 0, settle = 0}
	local function stub(schema)
		local config = {}
		function config.new()
			local tail = {}
			function tail.plan_slice() stub_calls.plan = stub_calls.plan + 1 end
			function tail.bind_plan() stub_calls.plan = stub_calls.plan + 1 end
			tail.bind = tail.bind_plan
			function tail.settle()
				stub_calls.settle = stub_calls.settle + 1
				return {schema = schema}
			end
			function tail.metrics() return {schema = schema} end
			function tail.roster() return {} end
			return tail
		end
		return config
	end
	local composed = successor_factory(stub("p9g"), stub("anchors"), configs, keys, stub("world"))
	-- The roster order is the manifest's order, so a successor built from a
	-- reordered or short roster must be refused outright.
	local reordered = {configs[2], configs[1]}
	for index = 3, #configs do reordered[index] = configs[index] end
	assert(not pcall(successor_factory, stub("p9g"), stub("anchors"), reordered,
		keys), "the successor accepted a reordered roster")
	local short = {}
	for index = 2, #configs do short[index - 1] = configs[index] end
	assert(not pcall(successor_factory, stub("p9g"), stub("anchors"), short, keys),
		"the successor accepted a short roster")
	local anchors_by_zone = {}
	for index = 1, #module.roster do
		anchors_by_zone[module.roster[index].zone_id] = {
			id = module.roster[index].anchor_id,
			numeric_id = module.roster[index].numeric_id,
			slot = module.roster[index].slot,
			x = module.roster[index].x, y = 40, z = module.roster[index].z}
	end
	local tail = composed.new({planner_source = planner_source,
		zones_session = {anchor = function(zone_id, slot)
			local row = anchors_by_zone[zone_id]
			if row and row.slot == slot then return row end
		end}})
	local plan = {}
	tail:plan_slice({x = 1200, y = 0, z = 1200}, {x = 1279, y = 79, z = 1279},
		plan, 3)
	local wrote = 0
	tail:settle({plan = plan, generation = 3, call_mode = "fixture",
		min_x = 1200, min_y = 0, min_z = 1200,
		max_x = 1279, max_y = 79, max_z = 1279,
		inside_owner = function() return true end,
		write_p9g = function() end, write_anchor = function() end,
		write_hearthpine = function() wrote = wrote + 1 end})
	assert(wrote == 0, "an unrelated owner received settlement bytes")
	local ledger_keys = 0
	local metrics = tail:metrics()
	for index = 1, #module.roster do
		assert(type(metrics[module.roster[index].key]) == "table",
			"composed metrics lost " .. module.roster[index].key)
		ledger_keys = ledger_keys + 1
	end
	report[#report + 1] = "composed/" .. ledger_keys .. "/" .. #union

	return table.concat(report, " ")
end
