-- Actual catalog/selector regression; no full world or native noise required.
return function(repo, expanded)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	-- This fixture needs only template dimensions and declared node names to
	-- construct the content catalog. Decode that uncompressed MTS header in
	-- plain 5.1; template voxels/deflate are outside the surface-selector test.
	-- The override is local to this freshly loaded fixture-common table.
	function common.read_mts(path)
		local bytes = common.read_file(path)
		local function u16(offset)
			local a, b = bytes:byte(offset, offset + 1)
			assert(b, "truncated MTS header")
			return a * 256 + b
		end
		assert(bytes:sub(1, 4) == "MTSM" and u16(5) == 4)
		local sx, sy, sz = u16(7), u16(9), u16(11)
		assert(sx > 0 and sy > 0 and sz > 0)
		local offset, names = 13 + sy, {}
		local count = u16(offset)
		offset = offset + 2
		for index = 1, count do
			local length = u16(offset)
			offset = offset + 2
			local name = bytes:sub(offset, offset + length - 1)
			assert(#name == length)
			names[index] = {name = name == "ignore" and "air" or name}
			offset = offset + length
		end
		return {size = {x = sx, y = sy, z = sz}, data = names}
	end
	local fixtures = dofile(repo .. "/tools/wp40/r6/fixtures.lua")(
		repo, common, common.new_sha256())
	local content = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r6_content.lua")(
		fixtures.r6_manifest(), fixtures.new_content_contract(), fixtures.projection())
	local flat = {column_values_at = function()
		return "land", 1, "fixture", "grug_pine_hills", "dwarf", 30
	end}
	local steep = {column_values_at = function(x)
		return "land", 1, "fixture", "grug_pine_hills", "dwarf", x * 2
	end}
	local seed = "13191094842853985814"
	local select = content.new_surface_selector(seed, flat)
	local reverse = content.new_surface_selector(seed, flat)
	local other = content.new_surface_selector("13191094842853985815", flat)
	local rocky = content.new_surface_selector(seed, steep)
	local samples, counts, rows = {}, {}, {}
	local extent, step = expanded and 128 or 32, expanded and 2 or 8
	local differences, slope_changes = 0, 0
	for _, base in ipairs(content.surfaces()) do
		local names = {}
		for z = -extent, extent, step do
			for x = -extent, extent, step do
				local row = select(base.id, x, z, nil, 30)
				assert(row.id == base.id and row.filler_depth >= 1 and row.filler_depth <= 4)
				assert(content.content_ref(row.top) == row.top_ref)
				assert(content.content_ref(row.filler) == row.filler_ref)
				names[row.top] = true
				local key = base.id .. "/" .. x .. "/" .. z
				local value = row.top .. "/" .. row.filler .. "/" .. row.filler_depth
				samples[#samples + 1] = {id = base.id, x = x, z = z, value = value}
				rows[#rows + 1] = key .. "\t" .. value .. "\n"
				local alternate = other(base.id, x, z, nil, 30)
				if alternate.top ~= row.top then differences = differences + 1 end
				local slope = rocky(base.id, x, z, nil, 30)
				if slope.top ~= row.top then
					assert(slope.top == "default:stone")
					slope_changes = slope_changes + 1
				end
				local wet = select(base.id, x, z, 31, 30)
				assert(wet.top == base.top and wet.filler_depth == base.filler_depth)
			end
		end
		local count = 0
		for _ in pairs(names) do count = count + 1 end
		counts[#counts + 1] = base.id .. "\t" .. count .. "\n"
		if expanded and base.id ~= "grug_beach" and base.id ~= "grug_swamp" then
			assert(count >= (base.id == "grug_crags" and 2 or 3),
				"missing material variation in " .. base.id)
		end
	end
	for index = #samples, 1, -1 do
		local sample = samples[index]
		local row = reverse(sample.id, sample.x, sample.z, nil, 30)
		assert(row.top .. "/" .. row.filler .. "/" .. row.filler_depth == sample.value,
			"surface depends on query order")
	end
	assert(differences > 0 and slope_changes > 0)
	assert(select(nil, 0, 0, nil, 30) == nil)
	for _, x in ipairs({-3740, 3740}) do
		assert(select("grug_pine_hills", x, 3340, nil, 30))
	end
	table.sort(rows)
	return "schema\tgrug_wp40_quality_surface_v2\n" .. table.concat(counts) ..
		"samples\t" .. #samples .. "\nseed_differences\t" .. differences ..
		"\nslope_changes\t" .. slope_changes .. "\noutput_sha256\t" ..
		common.hex(common.new_sha256()(table.concat(rows))) .. "\n", content
end
