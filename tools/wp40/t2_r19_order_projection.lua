-- WP40 T2 D1 keys-4/5 firing-set projection (plan 7.1, contracts 11.6, 12.5).
--
-- Contracts 11.6 forbids ruling a rule ahead of a measurement of its own
-- firing set.  The standing ruling is that plan 7.1 keys 4 and 5 -- "the
-- sorted set of resolved terminal world coordinates, lexicographic by
-- (x, z)" -- are authoritative and that production, which sorts and compares
-- the RENDERED TEXT x .. ":" .. z, must be aligned.  The two metrics invert
-- on negative x of equal digit width.  This script measures, over the whole
-- retained census population, whether that difference can move a single
-- selected tuple.
--
-- It is a pure TSV scan: it never compiles a seed and never touches
-- production.  Its only inputs are committed census shards.
--
-- Usage:
--   lua tools/wp40/t2_r19_order_projection.lua ARTIFACTS_DIR SHARD_NAME...
--
-- ARTIFACTS_DIR is the directory holding the census shards; each SHARD_NAME
-- is a shard file basename inside it.  Lua 5.1 cannot list a directory
-- without a C extension or a subprocess, and both are out of bounds here, so
-- the caller supplies the shard names -- see
-- tools/wp40/run_t2_r19_order_projection.sh, which globs them.
--
-- Deep analysis (the D1 descriptors, both metrics, decided_by) runs on the
-- v5 and v6 schemas, whose scan2 edge row records the selection.  A v4 shard
-- predates the D1 amendment: multiple complete tuples were a reject there,
-- so v4 is consumed for the reconciliation head count only.
--
-- Key 6 of the 7.1 order -- the probe byte sequence under canonical
-- orientation -- is NOT reconstructible from the census TSV: no shard row
-- carries the probe raster.  A record whose winner ties every competitor
-- through key 5 is therefore reported loudly as undecidable here, never
-- silently resolved.

local function fail(message)
	error("WP40 T2 R19 order projection: " .. message, 0)
end

-- ------------------------------------------------------------------
-- Row schemas, frozen.  An unexpected field count aborts the scan.
-- ------------------------------------------------------------------
local ENDPOINT_FIELDS = 14
local EDGE_FIELDS_SELECT = 11
local EDGE_FIELDS_V4 = 10
local TUPLE_FIELDS = 16

local E_SEED, E_ID, E_EDGE, E_ENDPOINT, E_CLASS = 2, 3, 4, 5, 6
local E_FIRST, E_FINISH, E_SUCCESSES = 8, 9, 14

local G_SEED, G_EDGE, G_CLASS = 2, 3, 4
local G_TUPLE_COUNT, G_COMPLETE_COUNT, G_DUPLICATE_COUNT = 6, 7, 8
local G_SELECTED_INDEX, G_SELECTED_STATIONS, G_AGREEMENT = 9, 10, 11

local T_SEED, T_EDGE, T_INDEX, T_CLASS = 2, 3, 4, 5
local T_FROM_INDEX, T_FROM_MODE, T_FROM_POINT, T_FROM_PREVIOUS = 6, 7, 8, 9
local T_TO_INDEX, T_TO_MODE, T_TO_POINT, T_TO_PREVIOUS = 10, 11, 12, 13
local T_STATIONS = 14

local COMPLETE_CLASS = "scan2_tuple_complete"

-- Plan 7.1 records the pre-correction (v4) firing set as 757 multi-complete
-- records with this per-edge breakdown.  Declared here so the measurement
-- reconciles against the plan rather than the reader's memory.
local PLAN_TOTAL = 757
local PLAN_PER_EDGE = {land_007 = 321, land_004 = 248, land_013 = 119,
	land_010 = 52, land_016 = 13, land_001 = 4}

-- Contracts 8.5: seven seeds returned to the scanned universe with the D2
-- admission and were first scanned post-correction.  The coordinator's
-- hypothesis is that exactly these two of them carry a multi-complete record
-- and account for the v5/v6 surplus over the plan's 757.  Declared as an
-- expectation to be tested, never as a filter.
local EXPECTED_READMITTED = {"343674299183575008", "7851242355115945264"}

-- ------------------------------------------------------------------
-- Small typed parsers, all fail-closed.
-- ------------------------------------------------------------------
local function integer_field(text, what)
	if type(text) ~= "string" or not text:match("^%-?%d+$") then
		fail(what .. " is not an integer: " .. tostring(text))
	end
	local value = tonumber(text)
	if value == nil or value ~= math.floor(value) then
		fail(what .. " is not an integer: " .. tostring(text))
	end
	return value
end

local function point_field(text, what)
	if type(text) ~= "string" then fail(what .. " is missing") end
	local x, z = text:match("^(%-?%d+):(%-?%d+)$")
	if not x then
		fail(what .. " is not a world coordinate: " .. tostring(text))
	end
	return {x = tonumber(x), z = tonumber(z), text = text}
end

local function seed_field(text, what)
	if type(text) ~= "string" or not text:match("^%d+$") then
		fail(what .. " is not a decimal seed: " .. tostring(text))
	end
	if #text > 1 and text:sub(1, 1) == "0" then
		fail(what .. " seed has a leading zero: " .. text)
	end
	return text
end

-- Canonical unsigned-64 decimal order: no leading zeros, so a shorter text is
-- the smaller number and equal lengths compare lexicographically.  Seeds never
-- pass through a Lua number.
local function decimal_less(left, right)
	if #left ~= #right then return #left < #right end
	return left < right
end

local function split_fields(line)
	local fields, position, count = {}, 1, 0
	while true do
		local tab = line:find("\t", position, true)
		if not tab then
			count = count + 1
			fields[count] = line:sub(position)
			break
		end
		count = count + 1
		fields[count] = line:sub(position, tab - 1)
		position = tab + 1
	end
	return fields, count
end

-- ------------------------------------------------------------------
-- The two metrics over keys 4 and 5.
-- ------------------------------------------------------------------
local function point_less(a, b)
	return a.x < b.x or (a.x == b.x and a.z < b.z)
end

-- Metric TEXT: the metric production carried BEFORE the contracts section 13
-- alignment -- sort the rendered point texts as strings and join them. It is
-- reproduced here, not imported: this tool loads nothing from mods/ on
-- purpose, so it measures the two orders against the recorded census rows
-- independently of whichever one production happens to implement, and it
-- keeps measuring both after the alignment landed.
local function sorted_text(points)
	local copy = {}
	for index = 1, #points do copy[index] = points[index].text end
	table.sort(copy)
	return table.concat(copy, ",")
end

-- Metric TUPLE: what plan 7.1 declares -- sort the points by (x, z) as signed
-- integers and compare the sorted sequences element-wise.
local function sorted_points(points)
	local copy = {}
	for index = 1, #points do copy[index] = points[index] end
	table.sort(copy, point_less)
	return copy
end

local function sequence_equal(a, b)
	if #a ~= #b then return false end
	for index = 1, #a do
		if a[index].x ~= b[index].x or a[index].z ~= b[index].z then
			return false
		end
	end
	return true
end

local function sequence_less(a, b)
	local shorter = #a
	if #b < shorter then shorter = #b end
	for index = 1, shorter do
		if point_less(a[index], b[index]) then return true end
		if point_less(b[index], a[index]) then return false end
	end
	return #a < #b
end

-- Returns the first key at which two descriptors differ, in the 7.1 order.
-- 6 means "keys 1-5 all tie"; key 6 is canonical probe bytes and no census
-- row carries them, so 6 here is UNDECIDABLE, not decided.
local KEY6_UNKNOWN = 6

local function first_difference(a, b, metric)
	if a.total_retreat ~= b.total_retreat then return 1 end
	if a.max_retreat ~= b.max_retreat then return 2 end
	if a.elbow_count ~= b.elbow_count then return 3 end
	if metric == "text" then
		if a.terminal_text ~= b.terminal_text then return 4 end
		if a.previous_text ~= b.previous_text then return 5 end
	else
		if not sequence_equal(a.terminal_seq, b.terminal_seq) then return 4 end
		if not sequence_equal(a.previous_seq, b.previous_seq) then return 5 end
	end
	return KEY6_UNKNOWN
end

-- nil means "cannot be decided from the census" (keys 1-5 tie).
local function tuple_less(a, b, metric)
	local key = first_difference(a, b, metric)
	if key == 1 then return a.total_retreat < b.total_retreat end
	if key == 2 then return a.max_retreat < b.max_retreat end
	if key == 3 then return a.elbow_count < b.elbow_count end
	if key == 4 then
		if metric == "text" then return a.terminal_text < b.terminal_text end
		return sequence_less(a.terminal_seq, b.terminal_seq)
	end
	if key == 5 then
		if metric == "text" then return a.previous_text < b.previous_text end
		return sequence_less(a.previous_seq, b.previous_seq)
	end
	return nil
end

-- Production's selection loop: keep the first tuple, replace only on a strict
-- decrease, so an undecidable comparison leaves the incumbent standing and is
-- reported.  Returns winner, decided_by, divergent_key, undecidable_count.
local function select_winner(tuples, metric)
	local best, undecidable = tuples[1], 0
	for index = 2, #tuples do
		local less = tuple_less(tuples[index], best, metric)
		if less == nil then
			undecidable = undecidable + 1
		elseif less then
			best = tuples[index]
		end
	end
	local decided_by, divergent = 0, nil
	for index = 1, #tuples do
		if tuples[index] ~= best then
			local key = first_difference(best, tuples[index], metric)
			if key > decided_by then decided_by = key end
			if (key == 4 or key == 5) and not divergent then divergent = key end
		end
	end
	return best, decided_by, divergent, undecidable
end

-- ------------------------------------------------------------------
-- Per-version accumulators.
-- ------------------------------------------------------------------
local function new_version_state(version, deep, analysis_class)
	return {version = version, deep = deep, analysis_class = analysis_class,
		shards = {}, seeds_seen = {}, seed_count = 0, lines = 0,
		edge_class_counts = {}, records = 0, per_edge = {}, record_keys = {},
		record_by_key = {}, decided_by_text = {}, decided_by_tuple = {},
		divergent_records = {}, undecidable_records = {},
		metric_disagreement = {}, census_disagreement = {},
		winner_retreat = {}, complete_hist = {}, tuple_hist = {}}
end

local function bump(counter, key)
	counter[key] = (counter[key] or 0) + 1
end

local function sorted_keys(map, less)
	local keys = {}
	for key in pairs(map) do keys[#keys + 1] = key end
	table.sort(keys, less)
	return keys
end

-- ------------------------------------------------------------------
-- Record analysis (v5/v6 only).
-- ------------------------------------------------------------------
local function analyse_record(state, seed, edge_id, edge_row, endpoints, tuples)
	local declares_from = endpoints.from ~= nil
	local declares_to = endpoints.to ~= nil
	if not declares_from and not declares_to then
		fail(seed .. " " .. edge_id .. " has no scan2_endpoint row")
	end
	local first, finish
	if declares_from then
		first, finish = endpoints.from.first, endpoints.from.finish
	end
	if declares_to then
		if first ~= nil and (first ~= endpoints.to.first or
				finish ~= endpoints.to.finish) then
			fail(seed .. " " .. edge_id ..
				" declared endpoints disagree on the selected interval")
		end
		first, finish = endpoints.to.first, endpoints.to.finish
	end
	if first == nil or finish == nil or finish < first then
		fail(seed .. " " .. edge_id .. " has no usable selected interval")
	end

	local tuple_count = integer_field(edge_row[G_TUPLE_COUNT],
		seed .. " " .. edge_id .. " tuple_count")
	local complete_count = integer_field(edge_row[G_COMPLETE_COUNT],
		seed .. " " .. edge_id .. " complete_count")
	local duplicate_count = integer_field(edge_row[G_DUPLICATE_COUNT],
		seed .. " " .. edge_id .. " duplicate_count")
	if duplicate_count ~= 0 then
		fail(seed .. " " .. edge_id ..
			" is a multi-complete selection with duplicate authority")
	end
	if complete_count < 2 then
		fail(seed .. " " .. edge_id ..
			" is classified multi-complete but records complete_count " ..
			string.format("%d", complete_count))
	end
	if #tuples ~= tuple_count then
		fail(seed .. " " .. edge_id .. " has " ..
			string.format("%d", #tuples) .. " scan2_tuple rows against " ..
			"tuple_count " .. string.format("%d", tuple_count))
	end
	local seen_index = {}
	for index = 1, #tuples do
		local at = tuples[index].tuple_index
		if at < 1 or at > tuple_count or seen_index[at] then
			fail(seed .. " " .. edge_id .. " tuple index " ..
				string.format("%d", at) .. " is out of range or duplicated")
		end
		seen_index[at] = true
	end

	local complete = {}
	for index = 1, #tuples do
		local row = tuples[index]
		if row.class == COMPLETE_CLASS then
			local descriptor = {tuple_index = row.tuple_index,
				stations = row.stations, elbow_count = 0,
				terminals = {}, previouses = {}}
			local total_retreat, max_retreat = 0, 0
			if row.from_point ~= nil then
				if not declares_from then
					fail(seed .. " " .. edge_id .. " tuple " ..
						string.format("%d", row.tuple_index) ..
						" resolves a from terminal the edge does not declare")
				end
				local retreat = row.from_index - first
				if retreat < 0 then
					fail(seed .. " " .. edge_id .. " tuple " ..
						string.format("%d", row.tuple_index) ..
						" has a negative from retreat")
				end
				if not endpoints.from.successes[row.from_index .. ":" ..
						row.from_mode] then
					fail(seed .. " " .. edge_id .. " tuple " ..
						string.format("%d", row.tuple_index) ..
						" from incidence " .. string.format("%d", row.from_index) ..
						":" .. row.from_mode ..
						" is not in the endpoint row's success list")
				end
				total_retreat = total_retreat + retreat
				if retreat > max_retreat then max_retreat = retreat end
				if row.from_mode ~= "direct" then
					descriptor.elbow_count = descriptor.elbow_count + 1
				end
				descriptor.terminals[#descriptor.terminals + 1] = row.from_point
				descriptor.previouses[#descriptor.previouses + 1] = row.from_previous
			elseif declares_from then
				fail(seed .. " " .. edge_id .. " tuple " ..
					string.format("%d", row.tuple_index) ..
					" is missing the declared from terminal")
			end
			if row.to_point ~= nil then
				if not declares_to then
					fail(seed .. " " .. edge_id .. " tuple " ..
						string.format("%d", row.tuple_index) ..
						" resolves a to terminal the edge does not declare")
				end
				local retreat = finish - row.to_index
				if retreat < 0 then
					fail(seed .. " " .. edge_id .. " tuple " ..
						string.format("%d", row.tuple_index) ..
						" has a negative to retreat")
				end
				if not endpoints.to.successes[row.to_index .. ":" ..
						row.to_mode] then
					fail(seed .. " " .. edge_id .. " tuple " ..
						string.format("%d", row.tuple_index) ..
						" to incidence " .. string.format("%d", row.to_index) ..
						":" .. row.to_mode ..
						" is not in the endpoint row's success list")
				end
				total_retreat = total_retreat + retreat
				if retreat > max_retreat then max_retreat = retreat end
				if row.to_mode ~= "direct" then
					descriptor.elbow_count = descriptor.elbow_count + 1
				end
				descriptor.terminals[#descriptor.terminals + 1] = row.to_point
				descriptor.previouses[#descriptor.previouses + 1] = row.to_previous
			elseif declares_to then
				fail(seed .. " " .. edge_id .. " tuple " ..
					string.format("%d", row.tuple_index) ..
					" is missing the declared to terminal")
			end
			if row.stations == nil then
				fail(seed .. " " .. edge_id .. " tuple " ..
					string.format("%d", row.tuple_index) ..
					" is complete without a probe station count")
			end
			descriptor.total_retreat = total_retreat
			descriptor.max_retreat = max_retreat
			descriptor.terminal_text = sorted_text(descriptor.terminals)
			descriptor.previous_text = sorted_text(descriptor.previouses)
			descriptor.terminal_seq = sorted_points(descriptor.terminals)
			descriptor.previous_seq = sorted_points(descriptor.previouses)
			complete[#complete + 1] = descriptor
		end
	end
	if #complete ~= complete_count then
		fail(seed .. " " .. edge_id .. " has " ..
			string.format("%d", #complete) .. " complete tuple rows against " ..
			"complete_count " .. string.format("%d", complete_count))
	end

	local text_winner, text_key, text_divergent, text_undecidable =
		select_winner(complete, "text")
	local tuple_winner, tuple_key, tuple_divergent, tuple_undecidable =
		select_winner(complete, "tuple")

	local record = {seed = seed, edge_id = edge_id,
		complete = complete_count, tuples = tuple_count,
		text_index = text_winner.tuple_index,
		tuple_index = tuple_winner.tuple_index,
		text_key = text_key, tuple_key = tuple_key,
		text_divergent = text_divergent, tuple_divergent = tuple_divergent,
		undecidable = text_undecidable + tuple_undecidable,
		winner_retreat = text_winner.total_retreat,
		winner_stations = text_winner.stations}

	local key = seed .. "\t" .. edge_id
	if state.record_by_key[key] then
		fail("duplicate multi-complete record for " .. seed .. " " .. edge_id)
	end
	state.record_by_key[key] = record
	state.record_keys[#state.record_keys + 1] = key
	state.records = state.records + 1
	bump(state.per_edge, edge_id)
	bump(state.decided_by_text, text_key)
	bump(state.decided_by_tuple, tuple_key)
	bump(state.winner_retreat, text_winner.total_retreat)
	bump(state.complete_hist, complete_count)
	bump(state.tuple_hist, tuple_count)
	if text_divergent or tuple_divergent then
		state.divergent_records[#state.divergent_records + 1] = record
	end
	if text_undecidable > 0 or tuple_undecidable > 0 or
			text_key == KEY6_UNKNOWN or tuple_key == KEY6_UNKNOWN then
		state.undecidable_records[#state.undecidable_records + 1] = record
	end
	if record.text_index ~= record.tuple_index then
		state.metric_disagreement[#state.metric_disagreement + 1] = record
	end

	local recorded_index = integer_field(edge_row[G_SELECTED_INDEX],
		seed .. " " .. edge_id .. " selected_tuple_index")
	local recorded_stations = integer_field(edge_row[G_SELECTED_STATIONS],
		seed .. " " .. edge_id .. " selected_station_count")
	record.census_index = recorded_index
	if recorded_index ~= record.text_index or
			recorded_index ~= record.tuple_index or
			recorded_stations ~= record.winner_stations then
		state.census_disagreement[#state.census_disagreement + 1] = record
	end
	if edge_row[G_AGREEMENT] ~= "agrees" then
		fail(seed .. " " .. edge_id .. " records compile_agreement " ..
			tostring(edge_row[G_AGREEMENT]) ..
			", so the shard's own compile cross-check did not agree")
	end
end

-- ------------------------------------------------------------------
-- The shard scan.
-- ------------------------------------------------------------------
local function flush_record(state, seed, endpoints, edges, tuples, wanted)
	if seed == nil then return end
	for index = 1, #wanted do
		local edge_id = wanted[index]
		analyse_record(state, seed, edge_id, edges[edge_id],
			endpoints[edge_id] or {}, tuples[edge_id] or {})
	end
end

local function scan_shard(state, path, name)
	local file = io.open(path, "r")
	if not file then fail("cannot open census shard " .. path) end
	local seed, endpoints, edges, tuples, wanted = nil, {}, {}, {}, {}
	local lines = 0
	for line in file:lines() do
		lines = lines + 1
		if line:sub(1, 6) == "scan2_" then
			local fields, count = split_fields(line)
			local kind = fields[1]
			local row_seed = seed_field(fields[2], path .. " row seed")
			if row_seed ~= seed then
				flush_record(state, seed, endpoints, edges, tuples, wanted)
				if state.seeds_seen[row_seed] then
					fail("seed " .. row_seed ..
						" appears in a second, non-contiguous scan2 block")
				end
				state.seeds_seen[row_seed] = true
				state.seed_count = state.seed_count + 1
				seed, endpoints, edges, tuples, wanted = row_seed, {}, {}, {}, {}
			end
			if kind == "scan2_endpoint" then
				if count ~= ENDPOINT_FIELDS then
					fail(path .. " scan2_endpoint row has " ..
						string.format("%d", count) .. " fields, not " ..
						string.format("%d", ENDPOINT_FIELDS))
				end
				local edge_id = fields[E_EDGE]
				local endpoint = fields[E_ENDPOINT]
				if endpoint ~= "from" and endpoint ~= "to" then
					fail(path .. " scan2_endpoint row has endpoint " .. endpoint)
				end
				if fields[E_ID] ~= "bay_edge_transition:" .. edge_id .. ":" ..
						endpoint then
					fail(path .. " scan2_endpoint row id " .. fields[E_ID] ..
						" does not name its own edge and endpoint")
				end
				local slot = endpoints[edge_id]
				if not slot then slot = {}; endpoints[edge_id] = slot end
				if slot[endpoint] then
					fail(row_seed .. " " .. edge_id .. ":" .. endpoint ..
						" has a duplicate scan2_endpoint row")
				end
				local successes = {}
				if fields[E_SUCCESSES] ~= "-" then
					for token in fields[E_SUCCESSES]:gmatch("[^,]+") do
						if successes[token] then
							fail(row_seed .. " " .. edge_id .. ":" .. endpoint ..
								" repeats success " .. token)
						end
						successes[token] = true
					end
				end
				local record = {class = fields[E_CLASS], successes = successes}
				if fields[E_FIRST] ~= "-" and fields[E_FINISH] ~= "-" then
					record.first = integer_field(fields[E_FIRST],
						row_seed .. " " .. edge_id .. ":" .. endpoint .. " first")
					record.finish = integer_field(fields[E_FINISH],
						row_seed .. " " .. edge_id .. ":" .. endpoint .. " finish")
				end
				slot[endpoint] = record
			elseif kind == "scan2_edge" then
				local expected = state.deep and EDGE_FIELDS_SELECT or EDGE_FIELDS_V4
				if count ~= expected then
					fail(path .. " scan2_edge row has " ..
						string.format("%d", count) .. " fields, not " ..
						string.format("%d", expected))
				end
				local edge_id = fields[G_EDGE]
				if edges[edge_id] then
					fail(row_seed .. " " .. edge_id ..
						" has a duplicate scan2_edge row")
				end
				edges[edge_id] = fields
				bump(state.edge_class_counts, fields[G_CLASS])
				if fields[G_CLASS] == state.analysis_class then
					if state.deep then
						wanted[#wanted + 1] = edge_id
					else
						state.records = state.records + 1
						bump(state.per_edge, edge_id)
						local key = row_seed .. "\t" .. edge_id
						if state.record_by_key[key] then
							fail("duplicate multi-complete record for " .. key)
						end
						state.record_by_key[key] = true
						state.record_keys[#state.record_keys + 1] = key
					end
				end
			elseif kind == "scan2_tuple" then
				if count ~= TUPLE_FIELDS then
					fail(path .. " scan2_tuple row has " ..
						string.format("%d", count) .. " fields, not " ..
						string.format("%d", TUPLE_FIELDS))
				end
				local edge_id = fields[T_EDGE]
				if not edges[edge_id] then
					fail(row_seed .. " " .. edge_id ..
						" has a scan2_tuple row before its scan2_edge row")
				end
				if state.deep and
						edges[edge_id][G_CLASS] == state.analysis_class then
					local row = {tuple_index = integer_field(fields[T_INDEX],
						row_seed .. " " .. edge_id .. " tuple_index"),
						class = fields[T_CLASS]}
					local label = row_seed .. " " .. edge_id .. " tuple " ..
						fields[T_INDEX]
					if fields[T_FROM_INDEX] ~= "-" then
						row.from_index = integer_field(fields[T_FROM_INDEX],
							label .. " from_index")
						row.from_mode = fields[T_FROM_MODE]
						row.from_point = point_field(fields[T_FROM_POINT],
							label .. " from_point")
						row.from_previous = point_field(fields[T_FROM_PREVIOUS],
							label .. " from_previous")
					end
					if fields[T_TO_INDEX] ~= "-" then
						row.to_index = integer_field(fields[T_TO_INDEX],
							label .. " to_index")
						row.to_mode = fields[T_TO_MODE]
						row.to_point = point_field(fields[T_TO_POINT],
							label .. " to_point")
						row.to_previous = point_field(fields[T_TO_PREVIOUS],
							label .. " to_previous")
					end
					if fields[T_STATIONS] ~= "-" then
						row.stations = integer_field(fields[T_STATIONS],
							label .. " probe_station_count")
					end
					local slot = tuples[edge_id]
					if not slot then slot = {}; tuples[edge_id] = slot end
					slot[#slot + 1] = row
				end
			else
				fail(path .. " carries an unknown scan2 row kind " .. kind)
			end
		end
	end
	flush_record(state, seed, endpoints, edges, tuples, wanted)
	file:close()
	state.lines = state.lines + lines
	state.shards[#state.shards + 1] = name
end

-- ------------------------------------------------------------------
-- Arguments.
-- ------------------------------------------------------------------
local args = {...}
local artifacts_dir = args[1]
if type(artifacts_dir) ~= "string" or artifacts_dir == "" then
	fail("usage: t2_r19_order_projection.lua ARTIFACTS_DIR SHARD_NAME...")
end
if #args < 2 then
	fail("no census shard names were given; pass the shard basenames after " ..
		"the artifacts directory (run_t2_r19_order_projection.sh globs them)")
end

local shards = {}
for index = 2, #args do
	local name = args[index]
	local version, first, last =
		name:match("^census%-scan%-v(%d+)%-(%d+)%-(%d+)%.tsv$")
	if not version then
		fail("shard name is not a canonical census shard: " .. tostring(name))
	end
	shards[#shards + 1] = {name = name, version = tonumber(version),
		first = tonumber(first), last = tonumber(last)}
end
table.sort(shards, function(a, b)
	if a.version ~= b.version then return a.version < b.version end
	if a.first ~= b.first then return a.first < b.first end
	return a.last < b.last
end)

local states, state_order = {}, {}
for index = 1, #shards do
	local shard = shards[index]
	local state = states[shard.version]
	if not state then
		local deep = shard.version >= 5
		state = new_version_state(shard.version, deep,
			deep and "scan2_multi_complete_select" or
			"scan2_multi_complete_reject")
		states[shard.version] = state
		state_order[#state_order + 1] = shard.version
	end
	if #state.shards == 0 then
		state.range_first = shard.first
	elseif shard.first ~= state.next_first then
		fail("census shard ranges of v" .. string.format("%d", shard.version) ..
			" are not contiguous at " .. shard.name)
	end
	state.next_first = shard.last + 1
	state.range_last = shard.last
	scan_shard(state, artifacts_dir .. "/" .. shard.name, shard.name)
end
table.sort(state_order)

-- ------------------------------------------------------------------
-- Report.
-- ------------------------------------------------------------------
local out = {}
local function say(text) out[#out + 1] = text end
local function number(value) return string.format("%d", value) end

say("WP40 T2 R19 order projection (plan 7.1 keys 4/5, contracts 11.6/12.5)")
say("artifacts " .. artifacts_dir)
say("key6 canonical probe bytes are NOT reconstructible from the census TSV; " ..
	"a keys-1-5 tie is reported as UNDECIDABLE, never resolved")

for order_index = 1, #state_order do
	local state = states[state_order[order_index]]
	local tag = "v" .. number(state.version)
	say("")
	say("--- census " .. tag .. " (" .. (state.deep and "deep analysis" or
		"reconciliation head count only") .. ") ---")
	say(tag .. " shards " .. number(#state.shards) .. " covering W index " ..
		number(state.range_first) .. ".." .. number(state.range_last) ..
		" lines " .. number(state.lines) .. " seeds " ..
		number(state.seed_count))
	say(tag .. " shard files " .. table.concat(state.shards, " "))
	local class_keys = sorted_keys(state.edge_class_counts)
	for index = 1, #class_keys do
		say(tag .. " scan2_edge class " .. class_keys[index] .. " " ..
			number(state.edge_class_counts[class_keys[index]]))
	end
	say(tag .. " " .. state.analysis_class .. " records " ..
		number(state.records))
	local edge_keys = sorted_keys(state.per_edge)
	for index = 1, #edge_keys do
		say(tag .. " per-edge " .. edge_keys[index] .. " " ..
			number(state.per_edge[edge_keys[index]]))
	end
	if state.deep then
		local decided_keys = sorted_keys(state.decided_by_text)
		for index = 1, #decided_keys do
			local key = decided_keys[index]
			say(tag .. " decided_by[TEXT] key " .. number(key) ..
				(key == KEY6_UNKNOWN and " (keys 1-5 tie, UNDECIDABLE)" or "") ..
				" " .. number(state.decided_by_text[key]))
		end
		local decided_tuple_keys = sorted_keys(state.decided_by_tuple)
		for index = 1, #decided_tuple_keys do
			local key = decided_tuple_keys[index]
			say(tag .. " decided_by[TUPLE] key " .. number(key) ..
				(key == KEY6_UNKNOWN and " (keys 1-5 tie, UNDECIDABLE)" or "") ..
				" " .. number(state.decided_by_tuple[key]))
		end
		local complete_keys = sorted_keys(state.complete_hist)
		for index = 1, #complete_keys do
			say(tag .. " complete_count " .. number(complete_keys[index]) ..
				" records " .. number(state.complete_hist[complete_keys[index]]))
		end
		local tuple_keys = sorted_keys(state.tuple_hist)
		for index = 1, #tuple_keys do
			say(tag .. " tuple_count " .. number(tuple_keys[index]) ..
				" records " .. number(state.tuple_hist[tuple_keys[index]]))
		end
		local retreat_keys = sorted_keys(state.winner_retreat)
		for index = 1, #retreat_keys do
			say(tag .. " winner total_retreat " .. number(retreat_keys[index]) ..
				" records " .. number(state.winner_retreat[retreat_keys[index]]))
		end
		local divergent = #state.divergent_records
		local undecidable = #state.undecidable_records
		local metric_split = #state.metric_disagreement
		local census_split = #state.census_disagreement
		say((divergent == 0 and "PASS " or "FAIL ") .. tag ..
			" keys-4/5-load-bearing records " .. number(divergent))
		for index = 1, divergent do
			local record = state.divergent_records[index]
			say(tag .. " DIVERGENT " .. record.seed .. " " .. record.edge_id ..
				" text_key=" .. tostring(record.text_divergent) ..
				" tuple_key=" .. tostring(record.tuple_divergent))
		end
		say((undecidable == 0 and "PASS " or "FAIL ") .. tag ..
			" keys-1-5-tie records " .. number(undecidable))
		for index = 1, undecidable do
			local record = state.undecidable_records[index]
			say(tag .. " UNDECIDABLE " .. record.seed .. " " .. record.edge_id ..
				" complete=" .. number(record.complete))
		end
		say((metric_split == 0 and "PASS " or "FAIL ") .. tag ..
			" TEXT-vs-TUPLE winner disagreements " .. number(metric_split))
		for index = 1, metric_split do
			local record = state.metric_disagreement[index]
			say(tag .. " METRIC-SPLIT " .. record.seed .. " " .. record.edge_id ..
				" text=" .. number(record.text_index) ..
				" tuple=" .. number(record.tuple_index))
		end
		say((census_split == 0 and "PASS " or "FAIL ") .. tag ..
			" reconstructed-vs-recorded selection disagreements " ..
			number(census_split))
		for index = 1, census_split do
			local record = state.census_disagreement[index]
			say(tag .. " CENSUS-SPLIT " .. record.seed .. " " .. record.edge_id ..
				" text=" .. number(record.text_index) ..
				" tuple=" .. number(record.tuple_index) ..
				" census=" .. number(record.census_index))
		end
	end
end

-- Cross-version reconciliation.
say("")
say("--- reconciliation ---")
local function record_set(state)
	local set = {}
	for index = 1, #state.record_keys do set[state.record_keys[index]] = true end
	return set
end
local function difference(left, right)
	local extra = {}
	for index = 1, #left.record_keys do
		local key = left.record_keys[index]
		if not right[key] then extra[#extra + 1] = key end
	end
	table.sort(extra, function(a, b)
		local seed_a, edge_a = a:match("^([^\t]+)\t(.+)$")
		local seed_b, edge_b = b:match("^([^\t]+)\t(.+)$")
		if seed_a ~= seed_b then return decimal_less(seed_a, seed_b) end
		return edge_a < edge_b
	end)
	return extra
end

for index = 1, #state_order do
	local state = states[state_order[index]]
	say("reconciliation v" .. number(state.version) .. " records " ..
		number(state.records) .. " against plan 7.1 total " ..
		number(PLAN_TOTAL) .. " delta " ..
		number(state.records - PLAN_TOTAL))
end

local plan_edges = sorted_keys(PLAN_PER_EDGE)
for order_index = 1, #state_order do
	local state = states[state_order[order_index]]
	local tag = "v" .. number(state.version)
	local matched = true
	for index = 1, #plan_edges do
		local edge_id = plan_edges[index]
		local measured = state.per_edge[edge_id] or 0
		local delta = measured - PLAN_PER_EDGE[edge_id]
		if delta ~= 0 then matched = false end
		say("reconciliation " .. tag .. " per-edge " .. edge_id ..
			" measured " .. number(measured) .. " plan " ..
			number(PLAN_PER_EDGE[edge_id]) .. " delta " .. number(delta))
	end
	local extra_edges = {}
	local measured_edges = sorted_keys(state.per_edge)
	for index = 1, #measured_edges do
		if PLAN_PER_EDGE[measured_edges[index]] == nil then
			extra_edges[#extra_edges + 1] = measured_edges[index]
			matched = false
		end
	end
	if #extra_edges > 0 then
		say("reconciliation " .. tag .. " edges absent from plan 7.1 " ..
			table.concat(extra_edges, ","))
	end
	say("reconciliation " .. tag .. " per-edge breakdown vs plan 7.1 " ..
		(matched and "MATCH" or "DIFFERS"))
end

for left_index = 1, #state_order do
	for right_index = 1, #state_order do
		if left_index ~= right_index then
			local left = states[state_order[left_index]]
			local right = states[state_order[right_index]]
			local extra = difference(left, record_set(right))
			say("reconciliation v" .. number(left.version) .. " minus v" ..
				number(right.version) .. " records " .. number(#extra))
			for index = 1, #extra do
				local seed, edge_id = extra[index]:match("^([^\t]+)\t(.+)$")
				say("reconciliation v" .. number(left.version) .. " minus v" ..
					number(right.version) .. " EXTRA " .. seed .. " " .. edge_id)
			end
		end
	end
end

local readmitted_lookup = {}
for index = 1, #EXPECTED_READMITTED do
	readmitted_lookup[EXPECTED_READMITTED[index]] = true
end
for order_index = 1, #state_order do
	local state = states[state_order[order_index]]
	if state.deep then
		local hits = {}
		for index = 1, #state.record_keys do
			local seed, edge_id = state.record_keys[index]:match("^([^\t]+)\t(.+)$")
			if readmitted_lookup[seed] then
				hits[#hits + 1] = seed .. " " .. edge_id
			end
		end
		table.sort(hits)
		say("reconciliation v" .. number(state.version) ..
			" D2 re-admitted seed records " .. number(#hits))
		for index = 1, #hits do
			say("reconciliation v" .. number(state.version) ..
				" D2 re-admitted " .. hits[index])
		end
		say("reconciliation v" .. number(state.version) ..
			" surplus over plan 7.1 " ..
			number(state.records - PLAN_TOTAL) ..
			" vs D2 re-admitted records " .. number(#hits) .. " " ..
			((#hits == state.records - PLAN_TOTAL) and "MATCH" or "DIFFERS"))
	end
end

-- Overall verdict.
local divergent_total, undecidable_total = 0, 0
local metric_total, census_total = 0, 0
for index = 1, #state_order do
	local state = states[state_order[index]]
	if state.deep then
		divergent_total = divergent_total + #state.divergent_records
		undecidable_total = undecidable_total + #state.undecidable_records
		metric_total = metric_total + #state.metric_disagreement
		census_total = census_total + #state.census_disagreement
	end
end
say("")
say("--- verdict ---")
say((divergent_total == 0 and "PASS" or "FAIL") ..
	" keys 4/5 are load-bearing at " .. number(divergent_total) ..
	" records over every deep-analysed census version")
say((undecidable_total == 0 and "PASS" or "FAIL") ..
	" keys 1-5 tie at " .. number(undecidable_total) .. " records")
say((metric_total == 0 and "PASS" or "FAIL") ..
	" TEXT and TUPLE metrics pick a different winner at " ..
	number(metric_total) .. " records")
say((census_total == 0 and "PASS" or "FAIL") ..
	" reconstructed winner disagrees with the recorded " ..
	"selected_tuple_index at " .. number(census_total) .. " records")
say((divergent_total == 0 and metric_total == 0 and census_total == 0 and
	undecidable_total == 0) and
	"WP40 T2 R19 order projection: the keys-4/5 firing set is EMPTY over " ..
	"the retained population; aligning production to the coordinate-tuple " ..
	"metric preserves every measured selection byte for byte" or
	"WP40 T2 R19 order projection: the keys-4/5 firing set is NOT empty -- " ..
	"STOP and report")

print(table.concat(out, "\n"))
