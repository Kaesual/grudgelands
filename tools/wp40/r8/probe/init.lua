-- Disposable WP40 R8 probe. The host runner copies this mod into an exact
-- game snapshot and grants it insecure access only inside a throw-away world.

grug_wp40_r8_probe = {}

local insecure = core.request_insecure_environment()
if not insecure then
	error("grug_wp40_r8_probe: trusted insecure environment is required")
end

local output_path = core.settings:get("grug_wp40_r8_output")
local corpus_path = core.settings:get("grug_wp40_r8_corpus")
local native_corpus_path = core.settings:get("grug_wp40_r8_native_corpus")
local native_required = core.settings:get("grug_wp40_r8_native_required") == "true"
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
	local file = assert(insecure.io.open(output_path, "ab"))
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

local function read_corpus(path, native_rows)
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
			if native_rows and y_text == "surface" then
				file:close()
				fail("native witness corpus requires exact numeric y")
			elseif y_text == "surface" then
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
			local native_role
			if native_rows then
				if id:match("^native_owner_") then
					native_role = "owner"
				elseif id:match("^native_stratum_") or
						id:match("^native_ore_") then
					native_role = "census"
				else
					file:close()
					fail("native row id must use native_owner_/native_stratum_/native_ore_")
				end
			end
			rows[#rows + 1] = {id = id, origin = origin, key = key,
				position = {x = x, y = y, z = z}, height_mode = height_mode,
				native_role = native_role}
		end
	end
	assert(file:close())
	if not native_rows and (#rows < min_cases or #rows > max_cases) then
		fail("corpus row count is outside the selected run-mode bounds")
	end
	return rows
end

local feature_cases = read_corpus(corpus_path, false)
local native_rows = {}
if native_corpus_path and native_corpus_path ~= "" then
	native_rows = read_corpus(native_corpus_path, true)
end
if native_required and #native_rows == 0 then
	fail("final mode requires a native witness corpus")
end
local request_cases, combined_keys, combined_ids = {}, {}, {}
local native_scope_keys, native_scope_bounds = {}, {}
for i = 1, #feature_cases do
	local case = feature_cases[i]
	request_cases[#request_cases + 1] = case
	combined_keys[case.key] = true
	combined_ids[case.id] = true
end
for i = 1, #native_rows do
	local native = native_rows[i]
	if combined_ids[native.id] then
		fail("combined corpus contains duplicate id " .. native.id)
	end
	if combined_keys[native.key] then
		fail("combined corpus contains duplicate mapchunk " .. native.key)
	end
	combined_ids[native.id] = true
	combined_keys[native.key] = true
	if native.native_role == "owner" then
		native_scope_keys[native.key] = true
		native_scope_bounds[native.key] = {
			minp = native.origin,
			maxp = {x = native.origin.x + 79, y = native.origin.y + 79,
				z = native.origin.z + 79},
		}
	end
	request_cases[#request_cases + 1] = native
end
if order_name == "reverse" then
	local reversed = {}
	for i = #request_cases, 1, -1 do
		reversed[#reversed + 1] = request_cases[i]
	end
	request_cases = reversed
end
local loaded_at = core.get_us_time()
local current = 0
local emerged_case_count = 0
local snapshot_count = 0
local finished = false
local generated_count = 0
local native_by_key = {}
local native_census_totals = {native_ore = 0, strata = {}}
local native_event_names = {"cave_begin", "cave_end", "large_cave_begin",
	"large_cave_end", "dungeon"}
local stratum_names = {"grug_materials:slate", "grug_materials:basalt",
	"grug_materials:granite", "grug_materials:emberrock",
	"grug_materials:abyssal_rock"}
for i = 1, #stratum_names do
	native_census_totals.strata[stratum_names[i]] = 0
end
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

local function count_content_box(values, area, minp, maxp, expected_cid)
	local count = 0
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				if values[area:index(x, y, z)] == expected_cid then
					count = count + 1
				end
			end
		end
	end
	return count
end

local function sort_native_events(events)
	table.sort(events, function(a, b)
		if a.kind ~= b.kind then return a.kind < b.kind end
		if a.position.x ~= b.position.x then
			return a.position.x < b.position.x
		end
		if a.position.y ~= b.position.y then
			return a.position.y < b.position.y
		end
		if a.position.z ~= b.position.z then
			return a.position.z < b.position.z
		end
		return a.source_mapchunk < b.source_mapchunk
	end)
end

local function native_census(node_counts)
	local census = {native_ore = count_node(node_counts, "default:gravel"),
		strata = {}}
	for i = 1, #stratum_names do
		local name = stratum_names[i]
		census.strata[name] = count_node(node_counts, name)
	end
	native_census_totals.native_ore = native_census_totals.native_ore + census.native_ore
	for i = 1, #stratum_names do
		local name = stratum_names[i]
		native_census_totals.strata[name] =
			(native_census_totals.strata[name] or 0) + census.strata[name]
	end
	return census
end

local function collect_native_events(minp)
	local key = minp.x .. "," .. minp.y .. "," .. minp.z
	if not native_scope_keys[key] then return end
	local notify = core.get_mapgen_object("gennotify") or {}
	local events = native_by_key[key] or {}
	for i = 1, #native_event_names do
		local kind = native_event_names[i]
		local positions = notify[kind]
		if type(positions) == "table" then
			for j = 1, #positions do
				local position = positions[j]
				if type(position) == "table" and type(position.x) == "number" and
					type(position.y) == "number" and type(position.z) == "number" then
				events[#events + 1] = {kind = kind,
					position = {x = position.x, y = position.y, z = position.z},
					source_mapchunk = key}
				end
			end
		end
	end
	sort_native_events(events)
	native_by_key[key] = events
end

local function read_voxel_arrays(case, full)
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
	local area = VoxelArea:new({MinEdge = emerged_min, MaxEdge = emerged_max})
	local content = vm:get_data()
	if #content == 0 then
		fail("voxel snapshot contains an empty array")
	end
	if not full then
		return vm, area, minp, maxp, emerged_min, emerged_max, content
	end
	local param2 = vm:get_param2_data()
	local light = vm:get_light_data()
	if #param2 == 0 or #light == 0 then
		fail("voxel snapshot contains an empty auxiliary array")
	end
	return vm, area, minp, maxp, emerged_min, emerged_max, content,
		param2, light
end

local function snapshot_case(case)
	local vm, area, minp, maxp, emerged_min, emerged_max, content,
		param2, light = read_voxel_arrays(case, true)
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
		exact_source_witness = true,
	}
	local semantic_evidence = {}
	if case.id == "human_capital" then
		-- Source-bound anchor_008 root: accepted H=36, activation root y=37.
		local node = core.get_node({x = 0, y = 37, z = -1500}).name
		semantic_checks.exact_source_witness = node == "grug_nodes:guard_banner"
	elseif case.id == "wyrmglass_channel" or case.id == "stormscale_channel" then
		-- A fixed 8x8 water-level envelope stays well inside both immutable
		-- channel polygons and inside this central mapchunk.
		local x = case.id == "wyrmglass_channel" and -2675 or 2675
		local witness_min = {x = x - 7, y = 1, z = -3}
		local witness_max = {x = x, y = 1, z = 4}
		local minimum = 56
		local water_count = count_content_box(content, area, witness_min,
			witness_max, core.get_content_id("default:water_source"))
		semantic_evidence.channel_water = {minp = witness_min,
			maxp = witness_max, water_source_count = water_count,
			minimum = minimum, sampled_voxels = 64}
		semantic_checks.exact_source_witness = water_count >= minimum
	elseif case.id == "deep_cross_border_resource" then
		-- Accepted deep cross-border ruby witness, retained as one exact voxel.
		local node = core.get_node({x = -1691, y = -842, z = 191}).name
		semantic_checks.exact_source_witness = node ==
			"grug_materials:stone_with_ruby"
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
		semantic_evidence = semantic_evidence,
		semantic_ok = semantic_ok,
		central_voxels = 80 * 80 * 80,
		process = process_metrics(),
	}
	vm:close()
	return result
end

local function snapshot_native_census(case)
	local vm, area, minp, maxp, emerged_min, emerged_max, content =
		read_voxel_arrays(case, false)
	local content_sha256, node_counts = digest_array(
		content, area, minp, maxp, 4, "content")
	local counted_voxels = 0
	for i = 1, #node_counts do
		counted_voxels = counted_voxels + node_counts[i].count
	end
	local census = native_census(node_counts)
	local semantic_checks = {
		complete_node_census = counted_voxels == 80 * 80 * 80,
		no_ignore = count_node(node_counts, "ignore") == 0,
	}
	local result = {
		event = "native_census",
		id = case.id,
		mapchunk = case.key,
		requested_position = case.position,
		central_min = minp,
		central_max = maxp,
		emerged_min = emerged_min,
		emerged_max = emerged_max,
		content_sha256 = content_sha256,
		node_counts = node_counts,
		native_census = census,
		semantic_checks = semantic_checks,
		semantic_ok = semantic_checks.complete_node_census and
			semantic_checks.no_ignore,
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
for i = 1, #feature_cases do
	snapshot_cases[#snapshot_cases + 1] = feature_cases[i]
end
local native_census_case_count = 0
for i = 1, #native_rows do
	if native_rows[i].native_role == "census" then
		snapshot_cases[#snapshot_cases + 1] = native_rows[i]
		native_census_case_count = native_census_case_count + 1
	end
end
table.sort(snapshot_cases, function(a, b) return a.id < b.id end)

local function point_in_source(event)
	local bounds = native_scope_bounds[event.source_mapchunk]
	local position = event.position
	return bounds and position.x >= bounds.minp.x and
		position.x <= bounds.maxp.x and position.y >= bounds.minp.y and
		position.y <= bounds.maxp.y and position.z >= bounds.minp.z and
		position.z <= bounds.maxp.z
end

local function node_name_at(position)
	local vm = core.get_voxel_manip(position, position)
	local emerged_min, emerged_max = vm:get_emerged_area()
	local area = VoxelArea:new({MinEdge = emerged_min, MaxEdge = emerged_max})
	local data = vm:get_data()
	local cid = data[area:index(position.x, position.y, position.z)]
	vm:close()
	local name = cid and core.get_name_from_content_id(cid) or nil
	return name or ""
end

local function air_near(position, radius)
	local minp = {x = position.x - radius, y = position.y - radius,
		z = position.z - radius}
	local maxp = {x = position.x + radius, y = position.y + radius,
		z = position.z + radius}
	local vm = core.get_voxel_manip(minp, maxp)
	local emerged_min, emerged_max = vm:get_emerged_area()
	local area = VoxelArea:new({MinEdge = emerged_min, MaxEdge = emerged_max})
	local data = vm:get_data()
	local air_cid = core.get_content_id("air")
	local count = 0
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				if data[area:index(x, y, z)] == air_cid then
					count = count + 1
				end
			end
		end
	end
	vm:close()
	return count
end

local function native_gate_result()
	local counts = {cave_begin = 0, cave_end = 0, large_cave_begin = 0,
		large_cave_end = 0, dungeon = 0}
	local events = {}
	for _, bucket in pairs(native_by_key) do
		for i = 1, #bucket do
			local event = bucket[i]
			counts[event.kind] = counts[event.kind] + 1
			events[#events + 1] = event
		end
	end
	sort_native_events(events)
	local dungeon_preserved, cave_air_witness = 0, 0
	for i = 1, #events do
		local event = events[i]
		event.inside_source = point_in_source(event) and true or false
		if event.kind == "dungeon" then
			event.node = node_name_at(event.position)
			event.below = node_name_at({x = event.position.x,
				y = event.position.y - 1, z = event.position.z})
			event.preserved_room = event.inside_source and event.node == "air" and
				(event.below == "default:cobble" or
					event.below == "default:mossycobble")
			if event.preserved_room then dungeon_preserved = dungeon_preserved + 1 end
		elseif event.kind == "cave_begin" or
				event.kind == "large_cave_begin" then
			event.nearby_air_count = event.inside_source and
				air_near(event.position, 8) or 0
			event.preserved_cave_air = event.nearby_air_count > 0
			if event.preserved_cave_air then cave_air_witness = cave_air_witness + 1 end
		end
	end
	local cave_pairs = counts.cave_begin == counts.cave_end and
		counts.large_cave_begin == counts.large_cave_end and
		counts.cave_begin + counts.large_cave_begin > 0
	local all_strata = true
	for i = 1, #stratum_names do
		if native_census_totals.strata[stratum_names[i]] == 0 then
			all_strata = false
		end
	end
	local result = {
		required = native_required,
		native_ore_count = native_census_totals.native_ore,
		strata = native_census_totals.strata,
		event_counts = counts,
		events = events,
		dungeon_preserved_room_count = dungeon_preserved,
		cave_air_witness_count = cave_air_witness,
	}
	result.dungeon_witness = not native_required or
		(counts.dungeon > 0 and dungeon_preserved > 0)
	result.cave_witness = not native_required or
		(cave_pairs and cave_air_witness > 0)
	result.cave_pairs = not native_required or cave_pairs
	result.stratum_census = not native_required or all_strata
	result.native_ore_census = not native_required or
		native_census_totals.native_ore > 0
	result.ok = result.dungeon_witness and result.cave_witness and
		result.cave_pairs and result.stratum_census and
		result.native_ore_census
	return result
end

snapshot_next = function()
	snapshot_count = snapshot_count + 1
	local case = snapshot_cases[snapshot_count]
	if not case then
		finished = true
		write_event({
			event = "complete",
			request_count = #request_cases,
			feature_case_count = #feature_cases,
			emerged_case_count = emerged_case_count,
			snapshot_count = #snapshot_cases,
			native_census_case_count = native_census_case_count,
			generated_callback_count = generated_count,
			native_gate = native_gate_result(),
			elapsed_us = core.get_us_time() - loaded_at,
			process = process_metrics(),
		})
		core.request_shutdown("WP40 R8 probe complete", false, 0.1)
		return
	end
	local snapshot
	if case.native_role == "census" then
		snapshot = snapshot_native_census(case)
	else
		snapshot = snapshot_case(case)
	end
	snapshot.order = order_name
	write_event(snapshot)
	core.after(0, snapshot_next)
end

run_next = function()
	current = current + 1
	local case = request_cases[current]
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
	core.register_on_generated(function(minp)
		generated_count = generated_count + 1
		collect_native_events(minp)
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
		seed_sha256 = hex_digest(core.sha256(seed, true)),
		mapgen = core.get_mapgen_setting("mg_name"),
		chunksize = core.get_mapgen_setting("chunksize"),
		water_level = core.get_mapgen_setting("water_level"),
		num_emerge_threads = core.settings:get("num_emerge_threads"),
		mapgen_flags = core.get_mapgen_setting("mg_flags"),
		request_count = #request_cases,
		feature_case_count = #feature_cases,
		native_corpus_count = #native_rows,
		request_order = (function()
			local ids = {}
			for i = 1, #request_cases do ids[i] = request_cases[i].id end
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

-- This must be installed before the first emerge request; the main callback
-- reads the resulting per-chunk native events through gennotify.
core.set_gen_notify({
	cave_begin = true,
	cave_end = true,
	large_cave_begin = true,
	large_cave_end = true,
	dungeon = true,
})
