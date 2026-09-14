-- Focused engine-free check for the clipped WP13 settlement successors.
--
-- Runs every settlement in the `r7_settlement.lua` roster through the real
-- config factory over the real owner grid: every cell must be written exactly
-- once, by the owner that contains it, through R7's opcode-37 writer, and an
-- owner that contains no settlement must write nothing at all.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local module = dofile(wp40 .. "/r7_settlement.lua")
	assert(#module.roster >= 2, "the settlement roster lost a start")

	-- The shared opcode-37 content channel: the sorted ASCII union of every
	-- start's palette, exactly as `r7_runtime.lua` builds it.
	local blueprints, union, seen = {}, {}, {}
	for index = 1, #module.roster do
		local profile = module.roster[index]
		local blueprint = dofile(wp40 .. "/" .. profile.blueprint_file)()
		assert(blueprint.schema == profile.blueprint_schema)
		blueprints[index] = blueprint
		for _, name in ipairs(blueprint.palette) do
			if not seen[name] then
				seen[name] = true
				union[#union + 1] = name
			end
		end
	end
	table.sort(union)
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
		local blueprint = blueprints[index]
		local config = module.config(profile, blueprint, content,
			common.new_sha256())
		assert(config.schema == profile.config_schema)
		assert(config.identity.schema == profile.identity_schema)
		local anchor = {id = profile.anchor_id, numeric_id = profile.numeric_id,
			x = profile.x, y = 40, z = profile.z}
		local tail = config.new({zones_session = {anchor = function(zone_id, slot_id)
			if zone_id == profile.zone_id and slot_id == "start" then
				return anchor
			end
		end}})
		assert(tail.key == profile.key)
		-- A neighbouring settlement's zone must not answer this one's anchor.
		local other = module.roster[(index % #module.roster) + 1]
		assert(not pcall(config.new, {zones_session = {anchor = function()
			return {id = other.anchor_id, numeric_id = other.numeric_id,
				x = other.x, y = 40, z = other.z}
		end}}), "the successor accepted a foreign anchor")

		local min_x = anchor.x + blueprint.bounds.min.x
		local max_x = anchor.x + blueprint.bounds.max.x
		local min_y = anchor.y + blueprint.bounds.min.y
		local max_y = anchor.y + blueprint.bounds.max.y
		local min_z = anchor.z + blueprint.bounds.min.z
		local max_z = anchor.z + blueprint.bounds.max.z
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
						call_mode = "fixture"}
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
						seen_cells[key], written = true, written + 1
					end
					local ledger = tail:settle(context)
					assert(ledger.schema == profile.ledger_schema)
				end
			end
		end
		assert(written == #blueprint.cells)
		for cell_index = 1, #blueprint.cells do
			local cell = blueprint.cells[cell_index]
			assert(seen_cells[(anchor.x + cell.x) .. "/" .. (anchor.y + cell.y) ..
				"/" .. (anchor.z + cell.z)])
		end
		-- An owner that holds no settlement writes nothing.
		local far_plan = {}
		tail:bind_plan({x = 0, y = 0, z = 0}, {x = 79, y = 79, z = 79},
			far_plan, 2)
		local far_context = {plan = far_plan, generation = 2,
			call_mode = "replay_fixture", inside_owner = function() return true end,
			write_hearthpine = function() error("inactive owner wrote", 0) end}
		assert(tail:settle(far_context).written == 0)
		local metrics = tail:metrics()
		assert(metrics.schema == profile.metrics_schema)
		assert(metrics.written == #blueprint.cells and metrics.replay_calls == 1)
		report[#report + 1] = table.concat({profile.key, config.identity.sha256,
			written, metrics.settle_calls, metrics.replay_calls}, "/")
	end

	-- One composed successor tail: both settlements planned and settled
	-- together, with an owner that belongs to neither writing nothing.
	local successor_factory = dofile(wp40 .. "/r7_successor.lua")
	local configs = {}
	for index = 1, #module.roster do
		configs[index] = module.config(module.roster[index], blueprints[index],
			content, common.new_sha256())
	end
	local stub_calls = {plan = 0, settle = 0}
	local function stub(schema)
		local config = {}
		function config.new()
			local tail = {}
			function tail.plan_slice() stub_calls.plan = stub_calls.plan + 1 end
			function tail.bind_plan() stub_calls.plan = stub_calls.plan + 1 end
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
	local composed = successor_factory(stub("p9g"), stub("anchors"), configs)
	local anchors_by_zone = {}
	for index = 1, #module.roster do
		anchors_by_zone[module.roster[index].zone_id] = {
			id = module.roster[index].anchor_id,
			numeric_id = module.roster[index].numeric_id,
			x = module.roster[index].x, y = 40, z = module.roster[index].z}
	end
	local tail = composed.new({zones_session = {anchor = function(zone_id, slot)
		if slot == "start" then return anchors_by_zone[zone_id] end
	end}})
	local plan = {}
	tail:plan_slice({x = 1200, y = 0, z = 1200}, {x = 1279, y = 79, z = 1279},
		plan, 3)
	local wrote = 0
	tail:settle({plan = plan, generation = 3, call_mode = "fixture",
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
