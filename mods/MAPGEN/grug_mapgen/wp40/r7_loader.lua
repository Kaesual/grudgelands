-- Main-environment half of the atomic R7 cutover. All fallible semantic work
-- finishes before the native registrations, IPC publication, sole mapgen
-- script registration and assignment-only public authority installation.

return function(core_api, mapgen_modpath, materials, gathering, core_owner)
	local IPC_KEY = "grug_mapgen:r7_runtime_v1"
	local function fail(message)
		error("WP40 R7 loader: " .. message, 0)
	end
	if type(core_api) ~= "table" or type(core_api.ipc_set) ~= "function" or
			type(core_api.register_mapgen_script) ~= "function" or
			type(mapgen_modpath) ~= "string" or mapgen_modpath == "" or
			type(materials) ~= "table" or type(gathering) ~= "table" or
			type(core_owner) ~= "table" or
			type(core_owner.prepare_zone_authority) ~= "function" then
		fail("construction seam differs")
	end
	local wp40 = mapgen_modpath .. "/wp40"
	local default_path = core_api.get_modpath("default")
	local gathering_path = core_api.get_modpath("grug_gathering")
	if type(default_path) ~= "string" or type(gathering_path) ~= "string" then
		fail("required mod path differs")
	end
	local handoff = dofile(mapgen_modpath .. "/wp43_handoff.lua")
	local projection = handoff.project(materials)
	handoff.validate_public(materials, projection)
	handoff.validate_registrations(projection, core_api.registered_items,
		core_api.registered_nodes)
	handoff.validate_target_names(materials, projection)
	local catalog = dofile(gathering_path .. "/catalog.lua")
	local native = dofile(wp40 .. "/r7_native.lua")
	local native_token = native.apply_and_validate_main()
	local runtime = dofile(wp40 .. "/r7_runtime.lua")(core_api, wp40,
		default_path .. "/schematics", projection, catalog)
	local built = runtime.build(native.identities())
	local publish_authority = core_owner.prepare_zone_authority(
		built.zones_session, built.consumer_payload)
	if type(publish_authority) ~= "function" then
		fail("prepared authority seam differs")
	end
	local payload = {schema = "grug_wp40_r7_ipc_v1",
		manifest_sha256 = built.manifest.sha256, full_seed = built.full_seed,
		projection = projection}

	-- No fallible semantic validation follows this line.
	native.register_ores(native_token)
	core_api.ipc_set(IPC_KEY, payload)
	core_api.register_mapgen_script(mapgen_modpath .. "/wp40/r7_mapgen.lua")
	publish_authority()

	return {schema = "grug_wp40_r7_loader_status_v1", enabled = true,
		production_enabled = true, writer_count = 1,
		manifest_sha256 = built.manifest.sha256, full_seed = built.full_seed,
		zones = rawget(_G, "grug_zones")}
end
