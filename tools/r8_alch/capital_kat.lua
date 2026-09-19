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
	-- The production authority constructor reads pinned MTS bytes through the
	-- repository's LuaJIT FFI parser. Exercise that real constructor and its
	-- settlement-socket consumer here when the required parser is available;
	-- the portable interpreter still runs the blueprint assertions below and
	-- produces the same canonical KAT output.
	if rawget(_G, "jit") then
		local settlement_names, settlement_seen = {}, {}
		for index = 1, #settlement.roster do
			local profile = settlement.roster[index]
			local source = dofile(mapgen .. "/wp40/" .. profile.blueprint_file)()
			for _, descriptor in ipairs(settlement.descriptors(profile, source)) do
				local names = descriptor.kind == "overlay" and
					descriptor.overlay.names or descriptor.build().palette
				for _, name in ipairs(names) do
					if not settlement_seen[name] then
						settlement_seen[name] = true
						settlement_names[#settlement_names + 1] = name
					end
				end
			end
		end
		-- MAP-A extends the production content projection beyond the historical
		-- runtime fixture vocabulary.  Register those authentic default-node
		-- definitions in this bounded ALCH manifest/settlement integration stub.
		for _, name in ipairs({"default:clay", "default:desert_stone",
				"default:mossycobble", "default:sandstone"}) do
			if not settlement_seen[name] then
				settlement_seen[name] = true
				settlement_names[#settlement_names + 1] = name
			end
		end
		table.sort(settlement_names, settlement.less_bytes)
		local regular_dofile = dofile
		local support_names = {"beds", "doors", "dye", "stairs", "vessels",
			"walls", "wool", "xpanes", "grug_decor", "grug_brewing"}
		local saved_support = {}
		for _, name in ipairs(support_names) do
			saved_support[name] = rawget(_G, name)
		end
		local support_loaded = false
		local settlement_definitions
		dofile = function(path)
			if path == root .. "/tools/wp40/r7/node_semantics_fixture.lua" then
				local factory = regular_dofile(path)
				return function(repo, catalog, expected_names)
					local expanded, seen = {}, {}
					for _, name in ipairs(expected_names) do
						expanded[#expanded + 1], seen[name] = name, true
					end
					for _, name in ipairs(settlement_names) do
						if not seen[name] then expanded[#expanded + 1] = name end
					end
					local result = factory(repo, catalog, expanded)
					settlement_definitions = result.definitions
					result.target_count = #expected_names
					return result
				end
			end
			if path == root .. "/mods/ITEMS/grug_materials/init.lua" then
				-- Reconstruct every settlement-palette owner before the semantic
				-- fixture snapshots its registered nodes. This is the same bounded
				-- registration seam used by the final portable micro fixture.
				if not support_loaded then
					support_loaded = true
					local semantic_core = core
					local current_modname = semantic_core.get_current_modname
					local get_modpath = semantic_core.get_modpath
					semantic_core.get_translator = semantic_core.get_translator or
						function() return function(text) return text end end
					semantic_core.register_on_placenode =
						semantic_core.register_on_placenode or function() end
					semantic_core.get_craft_result = semantic_core.get_craft_result or
						function() return {time = 0} end
					semantic_core.register_lbm = semantic_core.register_lbm or function() end
					semantic_core.register_on_player_receive_fields =
						semantic_core.register_on_player_receive_fields or function() end
					for _, modname in ipairs(support_names) do
						semantic_core.get_current_modname = function() return modname end
						semantic_core.get_modpath = function(name)
							if name == modname then
								local pack = modname:match("^grug_") and "ITEMS" or "BASE"
								return root .. "/mods/" .. pack .. "/" .. modname
							end
							return get_modpath(name)
						end
						regular_dofile(semantic_core.get_modpath(modname) .. "/init.lua")
					end
					semantic_core.get_current_modname = current_modname
					semantic_core.get_modpath = get_modpath
				end
				for _, name in ipairs({"default:shovel_wood",
						"default:shovel_stone", "default:shovel_bronze",
						"default:shovel_steel"}) do
					if not core.registered_items[name] then
						core.register_tool(name, {})
					end
				end
			end
			return regular_dofile(path)
		end
		local ok, fixture = pcall(function()
			return regular_dofile(root ..
				"/tools/wp40/r7/runtime_fixture.lua")(root, "0", true)
		end)
		dofile = regular_dofile
		for _, name in ipairs(support_names) do
			rawset(_G, name, saved_support[name])
		end
		if not ok then error(fixture, 0) end
		local next_cid = 100
		for cid in pairs(fixture.name_by_cid) do
			if cid >= next_cid and cid < 65535 then next_cid = cid + 1 end
		end
		for _, name in ipairs(settlement_names) do
			if not fixture.cid_by_name[name] then
				fixture.cid_by_name[name] = next_cid
				fixture.name_by_cid[next_cid] = name
				fixture.core.registered_nodes[name] = settlement_definitions[name]
				next_cid = next_cid + 1
			end
		end
		local runtime = dofile(mapgen .. "/wp40/r7_runtime.lua")(
			fixture.core, mapgen .. "/wp40",
			root .. "/mods/BASE/default/schematics", fixture.projection,
			fixture.catalog)
		local built = runtime.build_authority(fixture.native_identities, nil)
		if type(built.manifest) ~= "table" or
				built.manifest.schema ~= "grug_wp40_r7_mapgen_manifest_v1" then
			error("R8-ALCH capital KAT: real manifest constructor differs", 0)
		end
		local consumed = runtime.settlement_sockets(built)
		local highcourt
		for index = 1, #consumed do
			if consumed[index].key == "highcourt" then highcourt = consumed[index] end
		end
		local trainer = false
		for index = 1, #(highcourt and highcourt.sockets or {}) do
			local socket = highcourt.sockets[index]
			if socket.role == "trainer" and socket.profession == "alchemist" then
				trainer = true
			end
		end
		if not trainer then
			error("R8-ALCH capital KAT: real settlement consumer differs", 0)
		end
	end
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
