-- Engine-free LuaJIT fixture for the production R7 assembly. It supplies only
-- engine registration/readback primitives; all map decisions and settlement
-- remain in the production modules loaded by r7_runtime.lua.

return function(repo, seed_identity, content_only)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local offline = dofile(repo .. "/tools/wp40/r6/offline.lua")(repo)
	local accepted = offline.new_static()
	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local projection = offline.fixtures.projection()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local catalog_manifest = catalog.manifest()
	local p9g_rows = catalog.p9g_sources()
	local cultural_rows = catalog.cultural_sources()
	local cid_by_name, name_by_cid, registered_nodes = {}, {}, {}
	local next_cid = 100

	local function fail(message)
		error("WP40 R7 runtime fixture: " .. message, 0)
	end

	local function register(name, definition, requested_cid)
		if cid_by_name[name] then fail("duplicate node " .. name) end
		local cid = requested_cid or next_cid
		if not requested_cid then next_cid = next_cid + 1 end
		if name_by_cid[cid] then fail("duplicate CID") end
		cid_by_name[name], name_by_cid[cid] = cid, name
		registered_nodes[name] = definition
	end

	local semantic_names = {"air", "ignore", "default:water_source",
		"default:water_flowing", "default:river_water_source",
		"default:river_water_flowing"}
	for index = 1, #accepted.content_contract.content_names do
		semantic_names[#semantic_names + 1] =
			accepted.content_contract.content_names[index]
	end
	for index = 1, #cultural_rows do
		semantic_names[#semantic_names + 1] = cultural_rows[index].source_node
	end
	for index = 1, #p9g_rows do
		semantic_names[#semantic_names + 1] = p9g_rows[index].source_node
	end
	local semantic_fixture = dofile(repo ..
		"/tools/wp40/r7/node_semantics_fixture.lua")(
			repo, catalog, semantic_names)
	if semantic_fixture.schema ~= "grug_wp40_r7_node_semantics_fixture_v1" or
			semantic_fixture.target_count ~= 101 then
		fail("node-semantics fixture differs")
	end

	register("air", semantic_fixture.definitions.air, 0)
	register("default:water_source",
		semantic_fixture.definitions["default:water_source"], 1)
	register("default:water_flowing",
		semantic_fixture.definitions["default:water_flowing"], 2)
	register("default:river_water_source",
		semantic_fixture.definitions["default:river_water_source"], 3)
	register("default:river_water_flowing",
		semantic_fixture.definitions["default:river_water_flowing"], 4)
	register("ignore", semantic_fixture.definitions.ignore, 65535)

	for index = 1, #accepted.content_contract.content_names do
		local name = accepted.content_contract.content_names[index]
		register(name, semantic_fixture.definitions[name])
	end
	for index = 1, #cultural_rows do
		local name = cultural_rows[index].source_node
		register(name, semantic_fixture.definitions[name])
	end
	for index = 1, #p9g_rows do
		local name = p9g_rows[index].source_node
		register(name, semantic_fixture.definitions[name])
	end

	local heightmap = {}
	for index = 1, 6400 do heightmap[index] = -31007 end
	local settings_values = {num_emerge_threads = "1"}
	local mapgen_values = {
		mg_name = "v7", water_level = "1", mapgen_limit = "31007",
		chunksize = "5", mgv7_dungeon_ymin = "-31000",
		mgv7_dungeon_ymax = "-193",
		mg_flags = "biomes,caves,decorations,dungeons,light,ores",
		mgv7_spflags = "caverns,mountains,nofloatlands,ridges",
		seed = seed_identity or "0",
	}
	local core_api = {registered_nodes = registered_nodes, CONTENT_AIR = 0,
		CONTENT_IGNORE = 65535}
	function core_api.get_content_id(name)
		local cid = cid_by_name[name]
		if cid == nil then fail("unknown node " .. tostring(name)) end
		return cid
	end
	function core_api.get_name_from_content_id(cid) return name_by_cid[cid] end
	function core_api.sha256(bytes, raw)
		local digest = raw_sha256(bytes)
		return raw and digest or common.hex(digest)
	end
	function core_api.get_mapgen_setting(name) return mapgen_values[name] end
	core_api.settings = {}
	function core_api.settings.get(_, name) return settings_values[name] end
	function core_api.get_mapgen_object(name)
		if name ~= "heightmap" then fail("unexpected mapgen object") end
		local copy = {}
		for index = 1, 6400 do copy[index] = heightmap[index] end
		return copy
	end
	function core_api.read_schematic(path)
		return common.read_mts(path)
	end

	local native_identities = {
		noise_schema = "grug_wp40_r7_noiseparams_v1",
		noise_digest =
			"5a1183a0db4dcbf7c2fce382e907660bfd26e53325d370f62a2d9e78c04d8738",
		native_schema = "grug_wp40_r7_native_allowlist_v1",
		native_digest =
			"d1fe4ac1c7cbe5525af65bde48cc4309870c01e4d474785f2cf0cda3d2639480",
	}
	if content_only == true then
		return {schema = "grug_wp40_r7_content_fixture_v1", common = common,
			raw_sha256 = raw_sha256, core = core_api, catalog = catalog,
			projection = projection, native_identities = native_identities,
			cid_by_name = cid_by_name, name_by_cid = name_by_cid}
	elseif content_only ~= nil and content_only ~= false then
		fail("content-only mode differs")
	end
	local runtime = dofile(wp40 .. "/r7_runtime.lua")(core_api, wp40,
		repo .. "/mods/BASE/default/schematics", projection, catalog)
	local built = runtime.build(native_identities, nil, true)

	local module = {schema = "grug_wp40_r7_runtime_fixture_v1",
		common = common, raw_sha256 = raw_sha256, core = core_api,
		catalog = catalog, catalog_manifest = catalog_manifest,
		projection = projection, built = built, vm_module = offline.vm_module,
		cid_by_name = cid_by_name, name_by_cid = name_by_cid}

	function module.set_heightmap(values)
		if type(values) ~= "table" or #values ~= 6400 then
			fail("heightmap shape differs")
		end
		for index = 1, 6400 do heightmap[index] = values[index] end
	end

	function module.new_vm(minp, maxp)
		local axis_x = maxp.x - minp.x + 33
		local axis_y = maxp.y - minp.y + 33
		local axis_z = maxp.z - minp.z + 33
		local volume = axis_x * axis_y * axis_z
		local data, param2, light = {}, {}, {}
		for index = 1, volume do data[index], param2[index], light[index] = 0, 0, 0 end
		return offline.vm_module.new({minp = minp, maxp = maxp,
			data = data, param2 = param2, light = light, heightmap = heightmap,
			content_contract = built.content.production, water_level = 1,
			ignore_cid = built.content.production.ignore_cid,
			verify_inactive_tail = false})
	end

	return module
end
