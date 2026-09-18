return function(root)
	if type(root) ~= "string" or root:sub(1, 1) ~= "/" then
		error("absolute repository root required", 0)
	end
	local mutation = os.getenv("R8_ALCH_MUTATION") or ""
	local mapgen = root .. "/mods/MAPGEN/grug_mapgen"
	core = {get_modpath = function(name)
		if name == "grug_mapgen" then return mapgen end
		return root .. "/mods/" .. name
	end}
	local settlement = dofile(mapgen .. "/wp40/r7_settlement.lua")
	local found = {}
	for index = 1, #settlement.roster do
		local profile = settlement.roster[index]
		if profile.slot == "capital" then
			local source = dofile(mapgen .. "/wp40/" .. profile.blueprint_file)()
			local descriptors = settlement.descriptors(profile, source)
			local core_descriptor
			for descriptor_index = 1, #descriptors do
				if descriptors[descriptor_index].id == "core" then
					core_descriptor = descriptors[descriptor_index]
				end
			end
			local blueprint = core_descriptor.build()
			local count = 0
			for cell_index = 1, #blueprint.cells do
				local cell = blueprint.cells[cell_index]
				if cell.x == 2 and cell.y == 1 and cell.z == -12 and
						cell.name == "grug_brewing:brewing_stand" then count = count + 1 end
			end
			if mutation == "capital" and #found == 0 then count = 0 end
			if count ~= 1 then
				error("R8-ALCH capital KAT: " .. profile.key ..
					" brewing stand differs", 0)
			end
			found[#found + 1] = profile.key .. "=(2,1,-12)"
		end
	end
	if #found ~= 6 then error("R8-ALCH capital KAT: capital count differs", 0) end
	return "R8-ALCH capital KAT PASS " .. table.concat(found, " ") ..
		" trainer=(1,1,-12)\n"
end
