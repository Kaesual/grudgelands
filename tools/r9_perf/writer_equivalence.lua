-- Bounded real R5+R6 transactions; identical tooling can target frozen production.
-- Compare complete emerged buffers, external calls, intent and dirty metrics.
return function(repo, production_repo)
	local loader = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo, production_repo)
	local heightmap = loader.heightmap(-31007)
	local loaded = loader.new_capture("0", heightmap, false)
	local rows = {}
	local function digest(values)
		local blocks, parts = {}, {}
		for index = 1, #values do
			parts[#parts + 1] = tostring(values[index]) .. ","
			if #parts == 1024 then
				blocks[#blocks + 1] = loader.raw_sha256(table.concat(parts))
				parts = {}
			end
		end
		blocks[#blocks + 1] = loader.raw_sha256(table.concat(parts))
		return loader.common.hex(loader.raw_sha256(table.concat(blocks)))
	end
	for case = 1, 3 do
		local minp = {x = -432, y = case == 1 and 48 or -4, z = -1552}
		local maxp = {x = minp.x + 79, y = minp.y + 15, z = minp.z + 79}
		local plan, generation = loaded.session.plan_slice(minp, maxp)
		local ex, ey, ez = 112, 48, 112
		local data, param2, light = {}, {}, {}
		for z = minp.z - 16, maxp.z + 16 do
			for y = minp.y - 16, maxp.y + 16 do
				for x = minp.x - 16, maxp.x + 16 do
					local index = #data + 1
					data[index] = case == 1 and 1 or
						(y < 0 and 1 or (y == 0 and 10 or 0))
					param2[index], light[index] = 0, y > 0 and 15 or 0
					if case == 3 and x == minp.x - 16 then data[index] = 65535 end
				end
			end
		end
		assert(#data == ex * ey * ez)
		local vm, _, observer = loader.vm_module.new({minp = minp, maxp = maxp,
			data = data, param2 = param2, light = light, heightmap = heightmap,
			content_contract = loaded.content_contract, water_level = 1,
			ignore_cid = loaded.content_contract.ignore_cid, verify_inactive_tail = false})
		loaded.settlement_fixture.arm_private_capture()
		local result = loaded.session.apply_fixture(vm, minp, maxp, plan, generation)
		local capture = loaded.settlement_fixture.take_private_capture()
		local snapshot, metrics = observer.snapshot(), loaded.session.metrics()
		rows[#rows + 1] = "case\t" .. case .. "\t" .. result .. "\n"
		for _, key in ipairs({"data", "param2", "light", "trace"}) do
			rows[#rows + 1] = key .. "\t" .. digest(snapshot[key]) .. "\n"
		end
		-- Capture exposes canonical private tuples, including each intent field.
		local keys = {}
		for key, value in pairs(capture) do
			if type(value) == "string" and key:find("sha256", 1, true) then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys)
		assert(#keys > 0, "private capture digest missing")
		for _, key in ipairs(keys) do rows[#rows + 1] = key .. "\t" .. capture[key] .. "\n" end
		for _, key in ipairs({"modified_voxels", "content_dirty_columns",
			"param2_dirty_columns", "light_dirty_columns", "liquid_dirty_columns"}) do
			rows[#rows + 1] = key .. "\t" .. tostring(metrics.settlement[key]) .. "\n"
		end
	end
	return table.concat(rows)
end
