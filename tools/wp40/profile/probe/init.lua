-- Disposable WP40 mapgen profiling probe. Timing is performed by the patched
-- mapgen callback; this main-environment mod only drives ordered emerges and
-- computes a small output digest after every timed request has completed.

grug_wp40_profile_probe = {}

local modpath = core.get_modpath(core.get_current_modname())
local cases = dofile(modpath .. "/cases.lua")
local phase = core.settings:get("grug_wp40_profile_phase")
local expected_seed = core.settings:get("grug_wp40_profile_seed")
local timeout_seconds = tonumber(
	core.settings:get("grug_wp40_profile_probe_timeout")) or 600
local full_digest_enabled =
	core.settings:get("grug_wp40_profile_full_digest") == "true"

local function fail(message)
	error("grug_wp40_profile_probe: " .. message, 0)
end

if phase ~= "cold" and phase ~= "disk" then
	fail("phase must be cold or disk")
end
if type(expected_seed) ~= "string" or
		not expected_seed:match("^%-?%d+$") then
	fail("canonical decimal seed setting is required")
end

local function log(fields)
	local parts = {"GRUG_WP40_PROFILE_PROBE"}
	for index = 1, #fields do parts[#parts + 1] = fields[index] end
	core.log("action", table.concat(parts, " "))
end

local function chunk_origin(value)
	local block = math.floor(value / 16)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end

local resolved = {}
local seen = {}
for index = 1, #cases do
	local case = cases[index]
	local y = case.y
	if y == "surface" then
		if type(grug_zones) ~= "table" or
				type(grug_zones.terrain_height_at) ~= "function" then
			fail("terrain-height authority is unavailable")
		end
		y = grug_zones.terrain_height_at(case.x, case.z) + 1
	end
	if type(y) ~= "number" or y % 1 ~= 0 then
		fail("case y differs for " .. case.id)
	end
	local origin = {x = chunk_origin(case.x), y = chunk_origin(y),
		z = chunk_origin(case.z)}
	local key = origin.x .. "," .. origin.y .. "," .. origin.z
	if seen[key] then fail("duplicate mapchunk " .. key) end
	seen[key] = true
	resolved[index] = {id = case.id, x = case.x, y = y, z = case.z,
		origin = origin, key = key, expected_biome = case.expected_biome}
end

local action_names = {
	[core.EMERGE_GENERATED] = "generated",
	[core.EMERGE_FROM_MEMORY] = "memory",
	[core.EMERGE_FROM_DISK] = "disk",
	[core.EMERGE_CANCELLED] = "cancelled",
	[core.EMERGE_ERRORED] = "errored",
}
local totals = {generated = 0, memory = 0, disk = 0, cancelled = 0,
	errored = 0}
local generated_callbacks = 0
local current = 0
local completed = 0
local finished = false
local loaded_us = core.get_us_time()

core.register_on_generated(function()
	generated_callbacks = generated_callbacks + 1
end)

local function sampled_digest()
	local parts = {"grug_wp40_profile_sample_v1", expected_seed}
	local offsets = {-8, 0, 8}
	local vertical = {-3, 0, 1, 5}
	for case_index = 1, #resolved do
		local case = resolved[case_index]
		parts[#parts + 1] = case.id
		for z_index = 1, #offsets do
			for x_index = 1, #offsets do
				local x = case.x + offsets[x_index]
				local z = case.z + offsets[z_index]
				local base_y = case.y
				if cases[case_index].y == "surface" then
					base_y = grug_zones.terrain_height_at(x, z)
				end
				for y_index = 1, #vertical do
					local y = base_y + vertical[y_index]
					local node = core.get_node({x = x, y = y, z = z})
					parts[#parts + 1] = table.concat({x, y, z, node.name,
						node.param2 or 0}, ":")
				end
			end
		end
	end
	local digest = core.sha256(table.concat(parts, "\n"), false)
	if type(digest) ~= "string" or #digest ~= 64 or
			digest:find("[^0-9a-f]") then
		fail("sample digest differs")
	end
	return digest, #parts - 2
end

local function append_u32(parts, value)
	parts[#parts + 1] = string.char(value % 256,
		math.floor(value / 256) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 16777216) % 256)
end

local function full_owner_digest()
	local names = {}
	for name in pairs(core.registered_nodes) do names[#names + 1] = name end
	table.sort(names)
	local ordinal_by_cid, vocabulary = {}, {}
	for ordinal = 1, #names do
		local name = names[ordinal]
		local cid = core.get_content_id(name)
		if ordinal_by_cid[cid] then fail("duplicate canonical content id") end
		ordinal_by_cid[cid] = ordinal
		vocabulary[#vocabulary + 1] = ordinal .. ":" .. name
	end
	local vocabulary_digest = core.sha256(table.concat(vocabulary, "\n"), false)
	if type(vocabulary_digest) ~= "string" or #vocabulary_digest ~= 64 or
			vocabulary_digest:find("[^0-9a-f]") then
		fail("full digest vocabulary hash differs")
	end
	local function digest_channel(values, area, minp, maxp, width, translate)
		local raw_blocks, bytes, count = {}, {}, 0
		for z = minp.z, maxp.z do
			for y = minp.y, maxp.y do
				for x = minp.x, maxp.x do
					local value = values[area:index(x, y, z)]
					if translate then
						value = ordinal_by_cid[value]
						if not value then fail("unbound content id in full digest") end
					end
					if width == 4 then append_u32(bytes, value)
					else bytes[#bytes + 1] = string.char(value) end
					count = count + 1
					if count == 1024 then
						raw_blocks[#raw_blocks + 1] =
							core.sha256(table.concat(bytes), true)
						bytes, count = {}, 0
					end
				end
			end
		end
		if count > 0 then
			raw_blocks[#raw_blocks + 1] = core.sha256(table.concat(bytes), true)
		end
		return core.sha256(table.concat(raw_blocks), false)
	end
	local owner_digests = {"grug_wp40_profile_full_owner_v1",
		expected_seed, vocabulary_digest}
	local voxel_count = 0
	for case_index = 1, #resolved do
		local case = resolved[case_index]
		local minp = case.origin
		local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
		local vm = core.get_voxel_manip(minp, maxp)
		local emerged_min, emerged_max = vm:get_emerged_area()
		if emerged_min.x > minp.x or emerged_min.y > minp.y or
				emerged_min.z > minp.z or emerged_max.x < maxp.x or
				emerged_max.y < maxp.y or emerged_max.z < maxp.z then
			fail("full digest owner is outside emerged area")
		end
		local area = VoxelArea:new({MinEdge = emerged_min, MaxEdge = emerged_max})
		local content = vm:get_data()
		local content_digest = digest_channel(content, area, minp, maxp, 4, true)
		content = nil
		collectgarbage("collect")
		local param2 = vm:get_param2_data()
		local param2_digest = digest_channel(param2, area, minp, maxp, 1, false)
		param2 = nil
		collectgarbage("collect")
		local light = vm:get_light_data()
		local light_digest = digest_channel(light, area, minp, maxp, 1, false)
		light = nil
		collectgarbage("collect")
		vm:close()
		owner_digests[#owner_digests + 1] = table.concat({case.id, case.key,
			content_digest, param2_digest, light_digest}, ":")
		voxel_count = voxel_count + 80 * 80 * 80
	end
	local digest = core.sha256(table.concat(owner_digests, "\n"), false)
	if type(digest) ~= "string" or #digest ~= 64 or
			digest:find("[^0-9a-f]") then
		fail("full owner digest differs")
	end
	return digest, vocabulary_digest, voxel_count
end

local run_next
local function emerge_done(_, action, calls_remaining, state)
	local name = action_names[action]
	if not name then fail("unknown emerge action " .. tostring(action)) end
	state.actions[name] = state.actions[name] + 1
	totals[name] = totals[name] + 1
	if calls_remaining ~= 0 then return end
	completed = completed + 1
	log({"phase=" .. phase, "event=emerge", "case=" .. state.case.id,
		"mapchunk=" .. state.case.key,
		"elapsed_us=" .. (core.get_us_time() - state.started_us),
		"generated=" .. state.actions.generated,
		"disk=" .. state.actions.disk, "memory=" .. state.actions.memory,
		"cancelled=" .. state.actions.cancelled,
		"errored=" .. state.actions.errored})
	core.after(0, run_next)
end

run_next = function()
	current = current + 1
	local case = resolved[current]
	if not case then
		local measured_finished_us = core.get_us_time()
		local diagnostic_started_us = measured_finished_us
		local callbacks_before_diagnostic = generated_callbacks
		local digest, sample_count = sampled_digest()
		local full_digest, vocabulary_digest, full_voxels = "disabled", "-", 0
		if full_digest_enabled then
			full_digest, vocabulary_digest, full_voxels = full_owner_digest()
		end
		if generated_callbacks ~= callbacks_before_diagnostic then
			fail("post-timing diagnostics triggered map generation")
		end
		finished = true
		log({"phase=" .. phase, "event=complete",
			"requested=" .. #resolved, "completed=" .. completed,
			"callbacks=" .. generated_callbacks,
			"generated=" .. totals.generated, "disk=" .. totals.disk,
			"memory=" .. totals.memory, "cancelled=" .. totals.cancelled,
			"errored=" .. totals.errored, "samples=" .. sample_count,
			"digest=" .. digest,
			"full_digest=" .. full_digest,
			"full_vocabulary_digest=" .. vocabulary_digest,
			"full_voxels=" .. full_voxels,
			"measured_elapsed_us=" .. (measured_finished_us - loaded_us),
			"diagnostic_us=" .. (core.get_us_time() - diagnostic_started_us)})
		core.request_shutdown("WP40 profile " .. phase .. " complete", false, 0.1)
		return
	end
	if case.expected_biome then
		local biome = grug_zones.biome_at(case.x, case.z)
		if biome ~= case.expected_biome then
			fail("expected biome differs for " .. case.id .. ": " ..
				tostring(biome))
		end
	end
	local minp = case.origin
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local state = {case = case, started_us = core.get_us_time(), actions = {
		generated = 0, memory = 0, disk = 0, cancelled = 0, errored = 0}}
	core.emerge_area(minp, maxp, emerge_done, state)
end

core.register_on_mods_loaded(function()
	local version = core.get_version()
	if type(version) ~= "table" or type(version.string) ~= "string" or
			not version.string:match("^5%.17%.") then
		fail("Luanti 5.17.x is required")
	end
	local jit_api = rawget(_G, "jit")
	if type(jit_api) ~= "table" or type(jit_api.version) ~= "string" or
			not jit_api.version:match("^LuaJIT ") then
		fail("LuaJIT is required")
	end
	if core.get_mapgen_setting("seed") ~= expected_seed then
		fail("engine seed differs")
	end
	local status = type(grug_mapgen) == "table" and grug_mapgen.wp40 or nil
	if type(status) ~= "table" or status.enabled ~= true or
			status.production_enabled ~= true or status.writer_count ~= 1 then
		fail("R7 production authority differs")
	end
	log({"phase=" .. phase, "event=start", "engine=" .. version.string,
		"lua=" .. jit_api.version:gsub(" ", "_"), "seed=" .. expected_seed,
		"cases=" .. #resolved, "manifest=" .. status.manifest_sha256,
		"full_digest=" .. tostring(full_digest_enabled)})
	core.after(0, run_next)
	core.after(timeout_seconds, function()
		if not finished then
			log({"phase=" .. phase, "event=timeout", "current=" .. current,
				"completed=" .. completed})
			core.request_shutdown("WP40 profile timeout", false, 0)
		end
	end)
end)
