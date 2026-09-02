-- Disposable WP40 R8 probe. The host runner copies this mod into an exact
-- game snapshot and grants it insecure access only inside a throw-away world.

grug_wp40_r8_probe = {}

local insecure = core.request_insecure_environment()
if not insecure then
	error("grug_wp40_r8_probe: trusted insecure environment is required")
end

local output_path = core.settings:get("grug_wp40_r8_output")
local corpus_path = core.settings:get("grug_wp40_r8_corpus")
local expected_seed = core.settings:get("grug_wp40_r8_seed")
local order_name = core.settings:get("grug_wp40_r8_order") or "forward"
local min_cases = tonumber(core.settings:get("grug_wp40_r8_min_cases")) or 10
local max_cases = tonumber(core.settings:get("grug_wp40_r8_max_cases")) or 15
local timeout_seconds = tonumber(core.settings:get("grug_wp40_r8_timeout")) or 900

local function fail(message)
	error("grug_wp40_r8_probe: " .. message, 0)
end

if not output_path or output_path == "" or not corpus_path or
		corpus_path == "" then
	fail("output and corpus settings are required")
end
if order_name ~= "forward" and order_name ~= "reverse" then
	fail("order must be forward or reverse")
end

local function write_event(event)
	local file = assert(io.open(output_path, "ab"))
	assert(file:write(core.write_json(event, false), "\n"))
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

local function containing_chunk_origin(value)
	-- chunksize 5 uses the engine's -2-block chunk offset. This is integer
	-- floor arithmetic written without LuaJIT-only integer-division syntax.
	local block = math.floor(value / 16)
	local chunk_block = math.floor((block + 2) / 5) * 5 - 2
	return chunk_block * 16
end

local function read_corpus(path)
	local file = assert(io.open(path, "rb"))
	local rows, seen, seen_ids = {}, {}, {}
	for line in file:lines() do
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local id, x, y_text, z = line:match(
				"^([^\t]+)\t(-?%d+)\t([^\t]+)\t(-?%d+)$")
			if not id then
				file:close()
				fail("invalid corpus row: " .. line)
			end
			if seen_ids[id] then
				file:close()
				fail("corpus contains duplicate id " .. id)
			end
			seen_ids[id] = true
			x, z = assert(tonumber(x)), assert(tonumber(z))
			local y, height_mode
			if y_text == "surface" then
				if type(grug_zones) ~= "table" or
						type(grug_zones.terrain_height_at) ~= "function" then
					file:close()
					fail("published terrain-height authority is unavailable")
				end
				-- Use the first node above H so vegetation and the fixed
				-- anchor root stay in the sampled owner even when H is the
				-- upper face of the mapchunk below it.
				y = grug_zones.terrain_height_at(x, z) + 1
				height_mode = "surface"
			elseif y_text:match("^-?%d+$") then
				y = assert(tonumber(y_text))
				height_mode = "exact"
			else
				file:close()
				fail("corpus y must be surface or an integer: " .. y_text)
			end
			if x < -31007 or x > 31007 or y < -31007 or y > 31007 or
					z < -31007 or z > 31007 then
				file:close()
				fail("corpus coordinate exceeds production map limit")
			end
			local origin = {
				x = containing_chunk_origin(x),
				y = containing_chunk_origin(y),
				z = containing_chunk_origin(z),
			}
			local key = origin.x .. "," .. origin.y .. "," .. origin.z
			if seen[key] then
				file:close()
				fail("corpus contains duplicate mapchunk " .. key)
			end
			seen[key] = true
			rows[#rows + 1] = {id = id, origin = origin, key = key,
				position = {x = x, y = y, z = z}, height_mode = height_mode}
		end
	end
	assert(file:close())
	if #rows < min_cases or #rows > max_cases then
		fail("corpus row count is outside the selected run-mode bounds")
	end
	if order_name == "reverse" then
		local reversed = {}
		for i = #rows, 1, -1 do reversed[#reversed + 1] = rows[i] end
		rows = reversed
	end
	return rows
end

local cases = read_corpus(corpus_path)
local loaded_at = core.get_us_time()
local current = 0
local emerged_case_count = 0
local snapshot_count = 0
local finished = false
local generated_count = 0
local action_names = {
	[core.EMERGE_GENERATED] = "generated",
	[core.EMERGE_FROM_MEMORY] = "memory",
	[core.EMERGE_FROM_DISK] = "disk",
	[core.EMERGE_CANCELLED] = "cancelled",
	[core.EMERGE_ERRORED] = "errored",
}

local function hex_digest(raw)
	if type(raw) ~= "string" or #raw ~= 32 then
		fail("core.sha256 raw digest has unexpected size")
	end
	return (raw:gsub(".", function(char)
		return string.format("%02x", string.byte(char))
	end))
end

local function append_u32(parts, value)
	value = math.floor(value)
	if value < 0 then value = value + 4294967296 end
	parts[#parts + 1] = string.char(
		value % 256,
		math.floor(value / 256) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 16777216) % 256)
end

local function digest_array(values, area, minp, maxp, width, summary_kind)
	local blocks, parts = {}, {}
	local count = 0
	local content_counts = summary_kind == "content" and {} or nil
	local light_stats = summary_kind == "light" and {
		day_min = 15, day_max = 0, night_min = 15, night_max = 0,
		day_zero = 0, night_zero = 0,
	} or nil
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local value = values[area:index(x, y, z)]
				if type(value) ~= "number" then
					fail("voxel array has a missing value")
				end
				if width == 4 then
					append_u32(parts, value)
				else
					parts[#parts + 1] = string.char(value % 256)
				end
				if content_counts then
					content_counts[value] = (content_counts[value] or 0) + 1
				elseif light_stats then
					local day = value % 16
					local night = math.floor(value / 16) % 16
					light_stats.day_min = math.min(light_stats.day_min, day)
					light_stats.day_max = math.max(light_stats.day_max, day)
					light_stats.night_min = math.min(light_stats.night_min, night)
					light_stats.night_max = math.max(light_stats.night_max, night)
					if day == 0 then light_stats.day_zero = light_stats.day_zero + 1 end
					if night == 0 then light_stats.night_zero = light_stats.night_zero + 1 end
				end
				count = count + 1
				if count == 128 then
					blocks[#blocks + 1] = table.concat(parts)
					parts, count = {}, 0
				end
			end
		end
	end
	if #parts > 0 then blocks[#blocks + 1] = table.concat(parts) end
	local summary
	if content_counts then
		summary = {}
		for cid, node_count in pairs(content_counts) do
			local name = core.get_name_from_content_id(cid)
			if type(name) ~= "string" or name == "" then
				fail("content id has no registered name")
			end
			summary[#summary + 1] = {name = name, count = node_count}
		end
		table.sort(summary, function(a, b) return a.name < b.name end)
	elseif light_stats then
		summary = light_stats
	end
	return hex_digest(core.sha256(table.concat(blocks), true)), summary
end

local function count_node(rows, expected_name)
	for i = 1, #rows do
		if rows[i].name == expected_name then return rows[i].count end
	end
	return 0
end

local function snapshot_case(case)
	local minp = case.origin
	local maxp = {
		x = minp.x + 79,
		y = minp.y + 79,
		z = minp.z + 79,
	}
	local vm = core.get_voxel_manip(minp, maxp)
	local emerged_min, emerged_max = vm:get_emerged_area()
	if not emerged_min or not emerged_max then
		fail("voxel manipulator did not expose an emerged area")
	end
	if minp.x < emerged_min.x or minp.y < emerged_min.y or
			minp.z < emerged_min.z or maxp.x > emerged_max.x or
			maxp.y > emerged_max.y or maxp.z > emerged_max.z then
		fail("requested central mapchunk is outside emerged area")
	end
	local area = VoxelArea:new(emerged_min, emerged_max)
	local content = vm:get_data()
	local param2 = vm:get_param2_data()
	local light = vm:get_light_data()
	if #content == 0 or #param2 == 0 or #light == 0 then
		fail("voxel snapshot contains an empty array")
	end
	local content_sha256, node_counts = digest_array(
		content, area, minp, maxp, 4, "content")
	local param2_sha256 = digest_array(param2, area, minp, maxp, 1)
	local light_sha256, light_stats = digest_array(
		light, area, minp, maxp, 1, "light")
	local counted_voxels = 0
	for i = 1, #node_counts do
		counted_voxels = counted_voxels + node_counts[i].count
	end
	local semantic_checks = {
		complete_node_census = counted_voxels == 80 * 80 * 80,
		no_ignore = count_node(node_counts, "ignore") == 0,
		surface_has_daylight = case.height_mode ~= "surface" or
			light_stats.day_max > 0,
		expected_runtime_feature = true,
	}
	if case.id == "human_capital" then
		semantic_checks.expected_runtime_feature =
			count_node(node_counts, "grug_nodes:guard_banner") > 0
	elseif case.id == "wyrmglass_channel" or
			case.id == "stormscale_channel" then
		semantic_checks.expected_runtime_feature =
			count_node(node_counts, "default:water_source") > 0
	elseif case.id == "deep_cross_border_resource" then
		semantic_checks.expected_runtime_feature =
			count_node(node_counts, "grug_materials:stone_with_ruby") > 0
	end
	local semantic_ok = true
	for _, passed in pairs(semantic_checks) do
		if not passed then semantic_ok = false end
	end
	local result = {
		event = "case",
		id = case.id,
		mapchunk = case.key,
		requested_position = case.position,
		height_mode = case.height_mode,
		central_min = minp,
		central_max = maxp,
		emerged_min = emerged_min,
		emerged_max = emerged_max,
		content_sha256 = content_sha256,
		param2_sha256 = param2_sha256,
		light_sha256 = light_sha256,
		node_counts = node_counts,
		light_stats = light_stats,
		semantic_checks = semantic_checks,
		semantic_ok = semantic_ok,
		central_voxels = 80 * 80 * 80,
		process = process_metrics(),
	}
	vm:close()
	return result
end

local run_next
local snapshot_next
local function emerge_done(_, action, calls_remaining, state)
	local name = action_names[action] or ("unknown_" .. tostring(action))
	state.actions[name] = (state.actions[name] or 0) + 1
	if calls_remaining ~= 0 then return end
	emerged_case_count = emerged_case_count + 1
	write_event({event = "emerge", id = state.case.id,
		mapchunk = state.case.key, requested_position = state.case.position,
		height_mode = state.case.height_mode,
		emerge_us = core.get_us_time() - state.started_us,
		actions = state.actions, order = order_name,
		process = process_metrics()})
	core.after(0, run_next)
end

local snapshot_cases = {}
for i = 1, #cases do snapshot_cases[i] = cases[i] end
table.sort(snapshot_cases, function(a, b) return a.id < b.id end)

snapshot_next = function()
	snapshot_count = snapshot_count + 1
	local case = snapshot_cases[snapshot_count]
	if not case then
		finished = true
		write_event({
			event = "complete",
			case_count = #cases,
			emerged_case_count = emerged_case_count,
			snapshot_count = #snapshot_cases,
			generated_callback_count = generated_count,
			elapsed_us = core.get_us_time() - loaded_at,
			process = process_metrics(),
		})
		core.request_shutdown("WP40 R8 probe complete", false, 0.1)
		return
	end
	local snapshot = snapshot_case(case)
	snapshot.order = order_name
	write_event(snapshot)
	core.after(0, snapshot_next)
end

run_next = function()
	current = current + 1
	local case = cases[current]
	if not case then
		core.after(0, snapshot_next)
		return
	end
	local state = {
		case = case,
		started_us = core.get_us_time(),
		actions = {},
	}
	local minp = case.origin
	local maxp = {
		x = minp.x + 79,
		y = minp.y + 79,
		z = minp.z + 79,
	}
	core.emerge_area(minp, maxp, emerge_done, state)
end

if type(core.register_on_generated) == "function" then
	core.register_on_generated(function()
		generated_count = generated_count + 1
	end)
end

if type(core.register_on_shutdown) == "function" then
	core.register_on_shutdown(function()
		write_event({
			event = "shutdown",
			clean = finished,
			emerged_cases = emerged_case_count,
			snapshotted_cases = math.min(snapshot_count, #snapshot_cases),
			process = process_metrics(),
		})
	end)
end

core.register_on_mods_loaded(function()
	local seed = core.get_mapgen_setting("seed")
	if expected_seed and expected_seed ~= "" and seed ~= expected_seed then
		fail("engine seed disagrees with requested seed")
	end
	local status = type(grug_mapgen) == "table" and grug_mapgen.wp40 or nil
	if type(status) ~= "table" or status.full_seed ~= expected_seed or
			type(status.manifest_sha256) ~= "string" or
			#status.manifest_sha256 ~= 64 or
			status.manifest_sha256:find("[^0-9a-f]") then
		fail("production status identity differs")
	end
	write_event({
		event = "start",
		engine = (function()
			local version = core.get_version()
			return {string = version.string, project = version.project,
				hash = version.hash}
		end)(),
		seed = seed,
		mapgen = core.get_mapgen_setting("mg_name"),
		chunksize = core.get_mapgen_setting("chunksize"),
		water_level = core.get_mapgen_setting("water_level"),
		num_emerge_threads = core.settings:get("num_emerge_threads"),
		mapgen_flags = core.get_mapgen_setting("mg_flags"),
		case_count = #cases,
		request_order = (function()
			local ids = {}
			for i = 1, #cases do ids[i] = cases[i].id end
			return ids
		end)(),
		order = order_name,
		loaded_at_us = loaded_at,
		lua_runtime = rawget(_G, "jit") and rawget(_G, "jit").version or
			"bundled Lua 5.1",
		production = status and {
			enabled = status.enabled,
			production_enabled = status.production_enabled,
			writer_count = status.writer_count,
			schema = status.schema,
			full_seed = status.full_seed,
			manifest_sha256 = status.manifest_sha256,
		} or nil,
		process = process_metrics(),
	})
	core.after(0, run_next)
	core.after(timeout_seconds, function()
		if not finished then
			write_event({event = "timeout", current_case = current})
			core.request_shutdown("WP40 R8 probe timeout", false, 0.1)
		end
	end)
end)
