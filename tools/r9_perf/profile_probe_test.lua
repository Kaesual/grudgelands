-- Engine-free control-flow check: collect every owner and reload exactly that set.
-- Hash bytes are mocked; the real engine run authenticates content and SHA-256.
return function(repo)
	local saved, serialized, logs = "", nil, {}
	local cases = {}
	for index = 1, 10 do cases[index] = {id = "case" .. index, x = index * 160,
		y = 0, z = 0} end
	for _, phase in ipairs({"cold", "disk"}) do
		local queue, on_generated, on_loaded = {}, nil, nil
		local requests, reads, stopped, now = 0, 0, false, 0
		local settings = {grug_wp40_profile_phase = phase,
			grug_wp40_profile_seed = "0", grug_wp40_profile_full_digest = "true"}
		local core = {EMERGE_GENERATED = 1, EMERGE_FROM_MEMORY = 2,
			EMERGE_FROM_DISK = 3, EMERGE_CANCELLED = 4, EMERGE_ERRORED = 5,
			settings = {get = function(_, key) return settings[key] end},
			registered_nodes = {air = {}}}
		function core.get_modpath() return "/probe" end
		function core.get_current_modname() return "probe" end
		function core.get_mod_storage() return {
			get_string = function() return saved end,
			set_string = function(_, _, value) saved = value end} end
		function core.serialize(value) serialized = value return "owner_manifest" end
		function core.deserialize(value) assert(value == "owner_manifest") return serialized end
		function core.register_on_generated(callback) on_generated = callback end
		function core.register_on_mods_loaded(callback) on_loaded = callback end
		function core.after(delay, callback)
			if delay < 1 then queue[#queue + 1] = callback end
		end
		function core.get_us_time() now = now + 1 return now end
		function core.log(_, message) logs[#logs + 1] = message end
		function core.get_version() return {string = "5.17.0"} end
		function core.get_mapgen_setting() return "0" end
		function core.request_shutdown() stopped = true end
		function core.get_node() return {name = "air", param2 = 0} end
		function core.get_content_id() return 0 end
		function core.sha256(_, raw) return string.rep("a", raw and 32 or 64) end
		function core.emerge_area(minp, maxp, callback, state)
			requests = requests + 1
			if phase == "cold" then
				if requests == 1 then
					on_generated({x = 8000, y = -32, z = -32}, {x = 8079, y = 47, z = 47})
				end
				on_generated(minp, maxp)
			end
			callback(nil, phase == "cold" and 1 or 3, 0, state)
		end
		function core.get_voxel_manip(minp, maxp)
			reads = reads + 1
			local zeroes = setmetatable({}, {__index = function() return 0 end})
			return {get_emerged_area = function() return minp, maxp end,
				get_data = function() return zeroes end,
				get_param2_data = function() return zeroes end,
				get_light_data = function() return zeroes end, close = function() end}
		end
		local environment = setmetatable({core = core,
			dofile = function(path) assert(path == "/probe/cases.lua") return cases end,
			grug_core = {starts_ready = function() return 6, 6 end,
				starts_preload_failed = function() return false end},
			grug_mapgen = {wp40 = {enabled = true, production_enabled = true,
				writer_count = 1, manifest_sha256 = "test"}},
			VoxelArea = {new = function() return {index = function() return 1 end} end}},
			{__index = _G})
		setfenv(assert(loadfile(repo .. "/tools/wp40/profile/probe/init.lua")), environment)()
		on_loaded()
		local cursor = 1
		while queue[cursor] do
			queue[cursor]()
			cursor = cursor + 1
			assert(cursor < 100, "probe did not quiesce")
		end
		assert(stopped and reads == 11, "probe did not hash all generated owners")
		assert(requests == (phase == "cold" and 10 or 21), "disk owner reload set differs")
		assert(#serialized == 11)
		for index = 2, #serialized do
			assert(serialized[index - 1].key < serialized[index].key, "owner order is not canonical")
		end
		local complete = logs[#logs]
		assert(complete:find("event=complete", 1, true) and
			complete:find("full_owners=11", 1, true) and
			complete:find("full_voxels=5632000", 1, true), "completion coverage differs")
	end
	return "profile_probe_test PASS cold=11_owners disk=11_owners canonical=pass\n"
end
