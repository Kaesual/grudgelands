-- Disposable T0/T9 headless baseline driver. This file is copied into an
-- archived game checkout by the host harness; it is never loaded in production.

grug_wp40_probe = {}

local insecure = core.request_insecure_environment()
if not insecure then
	error("grug_wp40_probe: trusted insecure environment is required for " ..
		"process/RSS evidence")
end

local output_path = core.settings:get("grug_wp40_probe_output")
local corpus_path = core.settings:get("grug_wp40_probe_corpus")
local expected_seed = core.settings:get("grug_wp40_probe_seed")
local query_iterations = tonumber(core.settings:get(
	"grug_wp40_probe_query_iterations")) or 100
local timeout_seconds = tonumber(core.settings:get(
	"grug_wp40_probe_timeout")) or 180

local function fail(message)
	error("grug_wp40_probe: " .. message)
end

if not output_path or output_path == "" or not corpus_path or
		corpus_path == "" then
	fail("output and corpus settings are required")
end

local function write_event(event)
	local file = assert(io.open(output_path, "ab"))
	assert(file:write(core.write_json(event, true), "\n"))
	assert(file:close())
end

local function process_metrics()
	local file = assert(insecure.io.open("/proc/self/status", "rb"))
	local status = assert(file:read("*a"))
	assert(file:close())
	local function kibibytes(field)
		local value = status:match("\n" .. field .. ":[ \t]+(%d+)[ \t]+kB")
		return value and assert(tonumber(value)) * 1024 or nil
	end
	return {
		cpu_seconds = insecure.os.clock(),
		lua_bytes = math.floor(collectgarbage("count") * 1024),
		rss_bytes = kibibytes("VmRSS"),
		rss_peak_bytes = kibibytes("VmHWM"),
		virtual_bytes = kibibytes("VmSize"),
	}
end

local function read_corpus(path)
	local file = assert(io.open(path, "rb"))
	local cases = {}
	for line in file:lines() do
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local id, x, y, z = line:match(
				"^([^\t]+)\t(-?%d+)\t(-?%d+)\t(-?%d+)$")
			if not id then
				file:close()
				fail("invalid corpus row: " .. line)
			end
			cases[#cases + 1] = {
				id = id,
				x = assert(tonumber(x)),
				y = assert(tonumber(y)),
				z = assert(tonumber(z)),
			}
		end
	end
	assert(file:close())
	if #cases == 0 then
		fail("corpus is empty")
	end
	return cases
end

local cases = read_corpus(corpus_path)
local loaded_at = core.get_us_time()
local current = 0
local finished = false

local action_names = {
	[core.EMERGE_GENERATED] = "generated",
	[core.EMERGE_FROM_MEMORY] = "memory",
	[core.EMERGE_FROM_DISK] = "disk",
	[core.EMERGE_CANCELLED] = "cancelled",
	[core.EMERGE_ERRORED] = "errored",
}

local function query_compatibility(case)
	local at = {x = case.x, y = case.y, z = case.z}
	local started = core.get_us_time()
	local checksum = 0
	for _ = 1, query_iterations do
		local zone = grug_core.zone_at(at)
		local surface = grug_core.surface_level_at(case.x, case.z)
		local level = grug_core.mob_level_at(at)
		local sea = grug_core.open_sea_at(at)
		checksum = checksum + #(zone or "") + (surface or 0) +
			(level or 0) + (sea and 1 or 0)
	end
	return core.get_us_time() - started, checksum
end

local run_next

local function emerge_done(_, action, calls_remaining, state)
	local name = action_names[action] or ("unknown_" .. tostring(action))
	state.actions[name] = (state.actions[name] or 0) + 1
	if calls_remaining ~= 0 then
		return
	end
	local query_us, query_checksum = query_compatibility(state.case)
	write_event({
		event = "case",
		id = state.case.id,
		position = {x = state.case.x, y = state.case.y, z = state.case.z},
		emerge_us = core.get_us_time() - state.started_us,
		query_iterations = query_iterations,
		compatibility_queries = query_iterations * 4,
		query_us = query_us,
		query_checksum = query_checksum,
		actions = state.actions,
		process = process_metrics(),
	})
	core.after(0, run_next)
end

run_next = function()
	current = current + 1
	local case = cases[current]
	if not case then
		finished = true
		write_event({
			event = "complete",
			case_count = #cases,
			elapsed_us = core.get_us_time() - loaded_at,
			process = process_metrics(),
		})
		core.request_shutdown("WP40 baseline probe complete", false, 0.1)
		return
	end
	local state = {
		case = case,
		started_us = core.get_us_time(),
		actions = {},
	}
	local position = {x = case.x, y = case.y, z = case.z}
	core.emerge_area(position, position, emerge_done, state)
end

core.register_on_mods_loaded(function()
	local version = core.get_version()
	local seed = core.get_mapgen_setting("seed")
	if expected_seed and expected_seed ~= "" and seed ~= expected_seed then
		fail("engine seed " .. tostring(seed) .. " disagrees with requested " ..
			expected_seed)
	end
	write_event({
		event = "start",
		engine = version.string,
		project = version.project,
		hash = version.hash,
		seed = seed,
		mapgen = core.get_mapgen_setting("mg_name"),
		chunksize = core.get_mapgen_setting("chunksize"),
		water_level = core.get_mapgen_setting("water_level"),
		case_count = #cases,
		loaded_at_us = loaded_at,
		lua_runtime = rawget(_G, "jit") and rawget(_G, "jit").version or
			"bundled Lua 5.1",
		process = process_metrics(),
	})
	core.after(0, run_next)
	core.after(timeout_seconds, function()
		if not finished then
			write_event({event = "timeout", current_case = current})
			core.request_shutdown("WP40 baseline probe timeout", false, 0.1)
		end
	end)
end)
