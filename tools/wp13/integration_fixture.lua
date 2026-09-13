-- Focused engine-free check for the clipped Hearthpine successor.

return function(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local blueprint = dofile(wp40 .. "/r7_hearthpine_blueprint.lua")()
	local ref_by_name, cid_by_ref = {}, {}
	for index = 1, #blueprint.palette do
		ref_by_name[blueprint.palette[index]] = index
		cid_by_ref[index] = 1000 + index
	end
	local content = {schema = "grug_wp13_hearthpine_content_v1",
		content_names = blueprint.palette}
	function content.content_ref(name) return ref_by_name[name] end
	function content.resolve(ref, param2) return cid_by_ref[ref], param2 end
	local config = dofile(wp40 .. "/r7_hearthpine.lua")(
		blueprint, content, common.new_sha256())
	local anchor = {id = "anchor_001", numeric_id = 1, x = -1800, y = 40,
		z = -2550}
	local tail = config.new({zones_session = {anchor = function(zone_id, slot_id)
		if zone_id == "elandor_hearthpine_vale" and slot_id == "start" then
			return anchor
		end
	end}})
	local function owner_minimum(value)
		return -30912 + math.floor((value + 30912) / 80) * 80
	end
	local min_x = anchor.x + blueprint.bounds.min.x
	local max_x = anchor.x + blueprint.bounds.max.x
	local min_y = anchor.y + blueprint.bounds.min.y
	local max_y = anchor.y + blueprint.bounds.max.y
	local min_z = anchor.z + blueprint.bounds.min.z
	local max_z = anchor.z + blueprint.bounds.max.z
	local seen, written = {}, 0
	for owner_z = owner_minimum(min_z), owner_minimum(max_z), 80 do
		for owner_y = owner_minimum(min_y), owner_minimum(max_y), 80 do
			for owner_x = owner_minimum(min_x), owner_minimum(max_x), 80 do
				local plan = {}
				local minp = {x = owner_x, y = owner_y, z = owner_z}
				local maxp = {x = owner_x + 79, y = owner_y + 79, z = owner_z + 79}
				tail:bind_plan(minp, maxp, plan, 1)
				local context = {plan = plan, generation = 1, call_mode = "fixture"}
				function context.inside_owner(x, y, z)
					return x >= minp.x and x <= maxp.x and y >= minp.y and
						y <= maxp.y and z >= minp.z and z <= maxp.z
				end
				function context.write_hearthpine(x, y, z, cid, param2, ref, feature)
					local key = x .. "/" .. y .. "/" .. z
					assert(not seen[key] and cid == cid_by_ref[ref] and
						param2 >= 0 and param2 <= 255 and feature == 1)
					seen[key], written = true, written + 1
				end
				local ledger = tail:settle(context)
				assert(ledger.schema == "grug_wp13_hearthpine_ledger_v1")
			end
		end
	end
	assert(written == #blueprint.cells)
	for index = 1, #blueprint.cells do
		local cell = blueprint.cells[index]
		assert(seen[(anchor.x + cell.x) .. "/" .. (anchor.y + cell.y) .. "/" ..
			(anchor.z + cell.z)])
	end
	local far_plan = {}
	tail:bind_plan({x = 0, y = 0, z = 0}, {x = 79, y = 79, z = 79}, far_plan, 2)
	local far_context = {plan = far_plan, generation = 2,
		call_mode = "replay_fixture", inside_owner = function() return true end,
		write_hearthpine = function() error("inactive owner wrote", 0) end}
	assert(tail:settle(far_context).written == 0)
	local metrics = tail:metrics()
	assert(metrics.written == #blueprint.cells and metrics.replay_calls == 1)
	return table.concat({config.identity.sha256, written,
		metrics.settle_calls, metrics.replay_calls}, "/")
end
