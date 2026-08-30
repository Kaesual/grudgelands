-- Construction-only retained-table allocator for the disabled WP40 R5 path.

local MAX_SAFE = 9007199254740991
local MAX_MAP_KEYS = 512
local PLANNER_DOMAIN = "grug_wp40_r5_planner_allocator_v1"
local ADAPTER_DOMAIN = "grug_wp40_r5_adapter_allocator_v1"
local R6_PLANNER_DOMAIN = "grug_wp40_r6_planner_allocator_v1"
local R6_SETTLEMENT_DOMAIN = "grug_wp40_r6_settlement_allocator_v1"
local allocator_states = setmetatable({}, {__mode = "k"})

local function fail(message)
	error("WP40 R5 allocator: " .. message, 0)
end

local function integer(value, label, minimum, maximum)
	minimum = minimum or 0
	maximum = maximum or MAX_SAFE
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or value < minimum or
			value > maximum then
		fail(label .. " is not an integer in range")
	end
	return value
end

local function text(value, label)
	if type(value) ~= "string" or value == "" then
		fail(label .. " is not non-empty text")
	end
	return value
end

local function state_for(allocator)
	local state = allocator_states[allocator]
	if not state then fail("allocator identity differs") end
	return state
end

local function metadata_key(kind, label)
	return kind .. ":" .. label
end

local function require_construction(state)
	if state.hotpath_active ~= false then
		state.hotpath_table_allocations = state.hotpath_table_allocations + 1
		fail("hotpath is active")
	end
	if state.construction_sealed then fail("construction is sealed") end
end

local function register_object(state, object, label, kind, maximum)
	state[label] = object
	state[object] = label
	state[metadata_key("kind", label)] = kind
	state[metadata_key("maximum", label)] = maximum
	state[metadata_key("capacity", label)] = 0
	state[metadata_key("count", label)] = 0
end

local function require_object(state, object, label, kind)
	text(label, kind .. " label")
	if type(object) ~= "table" or state[object] ~= label or
			not rawequal(state[label], object) or
			state[metadata_key("kind", label)] ~= kind then
		fail(kind .. " identity/label differs")
	end
	return object
end

local allocator_methods = {}

function allocator_methods.new_array(allocator, label,
		maximum_logical_capacity)
	local state = state_for(allocator)
	require_construction(state)
	text(label, "array label")
	maximum_logical_capacity = integer(maximum_logical_capacity,
		"array maximum logical capacity")
	if state[label] ~= nil then fail("allocator label is not unique") end
	local array = {}
	register_object(state, array, label, "array", maximum_logical_capacity)
	state.construction_table_allocations =
		state.construction_table_allocations + 1
	state.construction_array_tables = state.construction_array_tables + 1
	return array
end

function allocator_methods.new_map(allocator, label, maximum_key_count)
	local state = state_for(allocator)
	require_construction(state)
	text(label, "map label")
	maximum_key_count = integer(maximum_key_count, "map maximum key count", 0,
		MAX_MAP_KEYS)
	if state[label] ~= nil then fail("allocator label is not unique") end
	local map = {}
	register_object(state, map, label, "map", maximum_key_count)
	state.construction_table_allocations =
		state.construction_table_allocations + 1
	state.construction_map_tables = state.construction_map_tables + 1
	state.retained_map_key_capacity = state.retained_map_key_capacity +
		maximum_key_count
	return map
end

function allocator_methods.grow(allocator, array, label,
		old_logical_capacity, new_logical_capacity)
	local state = state_for(allocator)
	require_construction(state)
	require_object(state, array, label, "array")
	old_logical_capacity = integer(old_logical_capacity,
		"old logical capacity")
	new_logical_capacity = integer(new_logical_capacity,
		"new logical capacity")
	local capacity_key = metadata_key("capacity", label)
	local maximum = state[metadata_key("maximum", label)]
	if old_logical_capacity ~= state[capacity_key] then
		fail("old logical capacity differs")
	end
	if new_logical_capacity <= old_logical_capacity or
			new_logical_capacity > maximum then
		fail("array growth is outside its declared bound")
	end
	for index = old_logical_capacity + 1, new_logical_capacity do
		array[index] = 0
	end
	state[capacity_key] = new_logical_capacity
	state.retained_numeric_capacity = state.retained_numeric_capacity +
		(new_logical_capacity - old_logical_capacity)
	state.allocator_growth_events = state.allocator_growth_events + 1
end

function allocator_methods.map_put(allocator, map, label, key, value)
	local state = state_for(allocator)
	require_construction(state)
	require_object(state, map, label, "map")
	if key == nil or value == nil then fail("map key/value is nil") end
	if rawget(map, key) ~= nil then fail("map key is not unique") end
	local count_key = metadata_key("count", label)
	local count = state[count_key]
	local maximum = state[metadata_key("maximum", label)]
	if count >= maximum then fail("map key capacity exceeded") end
	map[key] = value
	state[count_key] = count + 1
	state.retained_map_key_count = state.retained_map_key_count + 1
end

function allocator_methods.seal_construction(allocator)
	local state = state_for(allocator)
	if state.hotpath_active ~= false then fail("hotpath is active") end
	if state.construction_sealed then fail("construction already sealed") end
	state.construction_sealed = true
end

function allocator_methods.enter_hotpath(allocator, name)
	local state = state_for(allocator)
	text(name, "hotpath name")
	if not state.construction_sealed then fail("construction is not sealed") end
	if state.hotpath_active ~= false then fail("hotpath is already active") end
	state.hotpath_active = name
	state.hotpath_entries = state.hotpath_entries + 1
end

function allocator_methods.leave_hotpath(allocator, name)
	local state = state_for(allocator)
	text(name, "hotpath name")
	if state.hotpath_active ~= name then fail("hotpath leave is unbalanced") end
	state.hotpath_active = false
end

function allocator_methods.metrics(allocator)
	local state = state_for(allocator)
	if state.hotpath_active ~= false then fail("metrics requested in hotpath") end
	state.metrics_result_table_allocations =
		state.metrics_result_table_allocations + 1
	return {
		domain_id = state.domain_id,
		construction_table_allocations = state.construction_table_allocations,
		construction_array_tables = state.construction_array_tables,
		construction_map_tables = state.construction_map_tables,
		allocator_bootstrap_tables = state.allocator_bootstrap_tables,
		retained_numeric_capacity = state.retained_numeric_capacity,
		retained_map_key_capacity = state.retained_map_key_capacity,
		retained_map_key_count = state.retained_map_key_count,
		allocator_growth_events = state.allocator_growth_events,
		hotpath_entries = state.hotpath_entries,
		hotpath_table_allocations = state.hotpath_table_allocations,
		metrics_result_table_allocations =
			state.metrics_result_table_allocations,
		construction_sealed = state.construction_sealed,
		hotpath_active = state.hotpath_active,
	}
end

local function valid_domain(domain_id)
	return domain_id == PLANNER_DOMAIN or domain_id == ADAPTER_DOMAIN or
		domain_id == R6_PLANNER_DOMAIN or domain_id == R6_SETTLEMENT_DOMAIN
end

local function new_allocator(...)
	local argument_count = select("#", ...)
	local domain_id, candidate = ...
	if argument_count == 2 then
		local state = type(candidate) == "table" and
			allocator_states[candidate] or nil
		return valid_domain(domain_id) and state ~= nil and
			state.domain_id == domain_id or false
	end
	if argument_count ~= 1 then fail("allocator factory arity differs") end
	text(domain_id, "allocator domain_id")
	if not valid_domain(domain_id) then
		fail("allocator domain_id differs")
	end
	local allocator = {
		new_array = allocator_methods.new_array,
		new_map = allocator_methods.new_map,
		grow = allocator_methods.grow,
		map_put = allocator_methods.map_put,
		seal_construction = allocator_methods.seal_construction,
		enter_hotpath = allocator_methods.enter_hotpath,
		leave_hotpath = allocator_methods.leave_hotpath,
		metrics = allocator_methods.metrics,
	}
	allocator_states[allocator] = {
		domain_id = domain_id,
		construction_table_allocations = 2,
		construction_array_tables = 0,
		construction_map_tables = 0,
		allocator_bootstrap_tables = 2,
		retained_numeric_capacity = 0,
		retained_map_key_capacity = 0,
		retained_map_key_count = 0,
		allocator_growth_events = 0,
		hotpath_entries = 0,
		hotpath_table_allocations = 0,
		metrics_result_table_allocations = 0,
		construction_sealed = false,
		hotpath_active = false,
	}
	return allocator
end

return {new = new_allocator}
