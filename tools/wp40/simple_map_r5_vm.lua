-- WP40 simple-map R5 engine-shaped VoxelManip and mapgen-context fixture.
--
-- This module is test tooling only.  The VoxelManip proxy intentionally
-- exposes exactly the ten methods that the disabled R5 adapter may call.  Its
-- lighting implementation follows the pinned Mapgen::propagateSunlight and
-- Mapgen::spreadLight algorithms closely enough for deterministic seam KATs.

local math_floor = math.floor
local type = type
local pairs = pairs
local getmetatable = getmetatable
local setmetatable = setmetatable
local pcall = pcall
local error = error

local CONTEXT_SCHEMA = "grug_wp40_r5_mapgen_context_v1"

local SPEC_FIELDS = {
	minp = true,
	maxp = true,
	data = true,
	param2 = true,
	light = true,
	heightmap = true,
	content_contract = true,
	water_level = true,
	ignore_cid = true,
}

local VM_METHODS = {
	"get_emerged_area",
	"get_data",
	"get_param2_data",
	"get_light_data",
	"set_data",
	"set_param2_data",
	"set_lighting",
	"calc_lighting",
	"set_light_data",
	"update_liquids",
}

local function fail(message)
	error("simple_map_r5_vm: " .. message, 0)
end

local function is_finite_integer(value)
	return type(value) == "number" and value == value and
		value ~= math.huge and value ~= -math.huge and
		value == math_floor(value)
end

local function validate_exact_fields(value, allowed, label)
	if type(value) ~= "table" then
		fail(label .. " must be a table")
	end
	for key in pairs(value) do
		if not allowed[key] then
			fail(label .. " has unexpected field")
		end
	end
	for key in pairs(allowed) do
		if value[key] == nil then
			fail(label .. " is missing a field")
		end
	end
end

local function validate_position(pos, label)
	if type(pos) ~= "table" or not is_finite_integer(pos.x) or
			not is_finite_integer(pos.y) or not is_finite_integer(pos.z) then
		fail(label .. " must contain integer x/y/z")
	end
end

local function validate_dense_array(value, count, validator, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " must be a plain table")
	end
	local seen = 0
	for key, item in pairs(value) do
		if not is_finite_integer(key) or key < 1 or key > count then
			fail(label .. " has an out-of-range key")
		end
		if not validator(item) then
			fail(label .. " has an invalid value")
		end
		seen = seen + 1
	end
	if seen ~= count then
		fail(label .. " has a hole")
	end
	for index = 1, count do
		if value[index] == nil then
			fail(label .. " has a hole")
		end
	end
end

local function is_cid(value)
	return is_finite_integer(value) and value >= 0
end

local function is_byte(value)
	return is_finite_integer(value) and value >= 0 and value <= 255
end

local function is_height(value)
	return is_finite_integer(value)
end

local function copy_array(source, count)
	local result = {}
	for index = 1, count do
		result[index] = source[index]
	end
	return result
end

local function copy_position(source)
	return {x = source.x, y = source.y, z = source.z}
end

local function pack_trace_value(value)
	return tostring(value)
end

local function new(spec)
	validate_exact_fields(spec, SPEC_FIELDS, "spec")
	validate_position(spec.minp, "minp")
	validate_position(spec.maxp, "maxp")

	local minp = copy_position(spec.minp)
	local maxp = copy_position(spec.maxp)
	local water_level = spec.water_level
	local ignore_cid = spec.ignore_cid
	local x_count = maxp.x - minp.x + 1
	local y_count = maxp.y - minp.y + 1
	local z_count = maxp.z - minp.z + 1
	if x_count ~= 80 or z_count ~= 80 or y_count < 1 or y_count > 80 then
		fail("central bounds must be 80 x 1..80 x 80")
	end

	local emin = {x = minp.x - 16, y = minp.y - 16, z = minp.z - 16}
	local emax = {x = maxp.x + 16, y = maxp.y + 16, z = maxp.z + 16}
	local ex = emax.x - emin.x + 1
	local ey = emax.y - emin.y + 1
	local ez = emax.z - emin.z + 1
	local volume = ex * ey * ez
	local y_stride = ex
	local z_stride = ex * ey

	validate_dense_array(spec.data, volume, is_cid, "data")
	validate_dense_array(spec.param2, volume, is_byte, "param2")
	validate_dense_array(spec.light, volume, is_byte, "light")
	validate_dense_array(spec.heightmap, 6400, is_height, "heightmap")
	if not is_finite_integer(spec.water_level) then
		fail("water_level must be an integer")
	end
	if not is_cid(spec.ignore_cid) then
		fail("ignore_cid must be a content id")
	end
	local content_contract = spec.content_contract
	if type(content_contract) ~= "table" or
			type(content_contract.classify) ~= "function" or
			content_contract.ignore_cid ~= spec.ignore_cid then
		fail("content_contract is incompatible")
	end

	local data = copy_array(spec.data, volume)
	local param2 = copy_array(spec.param2, volume)
	local light = copy_array(spec.light, volume)
	local heightmap_source = copy_array(spec.heightmap, 6400)
	local trace = {}
	local trace_count = 0
	local calls = {}
	for method_index = 1, #VM_METHODS do
		calls[VM_METHODS[method_index]] = 0
	end
	calls.get_heightmap = 0
	local context_heightmap_fetch_calls = 0
	local context_heightmap_external_table_allocations = 0
	local context_metrics_result_table_allocations = 0

	local function index_of(x, y, z)
		return (z - emin.z) * z_stride + (y - emin.y) * y_stride +
			(x - emin.x) + 1
	end

	local function contains(x, y, z)
		return x >= emin.x and x <= emax.x and y >= emin.y and
			y <= emax.y and z >= emin.z and z <= emax.z
	end

	local function record(name, detail)
		calls[name] = calls[name] + 1
		trace_count = trace_count + 1
		if detail then
			trace[trace_count] = name .. ":" .. detail
		else
			trace[trace_count] = name
		end
	end

	local function read_light_flags(cid, p2)
		local ok, class_id, liquid_family_id, liquid_kind, liquid_level,
			floodable, paramtype_light, light_propagates,
			sunlight_propagates, light_source =
			pcall(content_contract.classify, cid, p2)
		if not ok or not is_finite_integer(class_id) or
				not is_finite_integer(liquid_family_id) or
				not is_finite_integer(liquid_kind) or
				not is_finite_integer(liquid_level) or
				type(floodable) ~= "boolean" or
				type(paramtype_light) ~= "boolean" or
				type(light_propagates) ~= "boolean" or
				type(sunlight_propagates) ~= "boolean" or
				not is_finite_integer(light_source) or
				light_source < 0 or light_source > 14 then
			fail("content_contract.classify returned an invalid tuple")
		end
		return light_propagates, sunlight_propagates, light_source
	end

	local vm = {}

	function vm.get_emerged_area(_)
		record("get_emerged_area")
		return copy_position(emin), copy_position(emax)
	end

	local function get_buffer(name, source, buffer)
		record(name)
		if type(buffer) ~= "table" then
			fail(name .. " requires a retained buffer")
		end
		for index = 1, volume do
			buffer[index] = source[index]
		end
		return buffer
	end

	function vm.get_data(_, buffer)
		return get_buffer("get_data", data, buffer)
	end

	function vm.get_param2_data(_, buffer)
		return get_buffer("get_param2_data", param2, buffer)
	end

	function vm.get_light_data(_, buffer)
		return get_buffer("get_light_data", light, buffer)
	end

	local function set_buffer(name, target, source, validator)
		record(name)
		if type(source) ~= "table" then
			fail(name .. " requires a buffer")
		end
		for index = 1, volume do
			local value = source[index]
			if not validator(value) then
				fail(name .. " received an invalid buffer value")
			end
			target[index] = value
		end
	end

	function vm.set_data(_, buffer)
		set_buffer("set_data", data, buffer, is_cid)
	end

	function vm.set_param2_data(_, buffer)
		set_buffer("set_param2_data", param2, buffer, is_byte)
	end

	function vm.set_light_data(_, buffer)
		set_buffer("set_light_data", light, buffer, is_byte)
	end

	local function validate_box(p1, p2, label)
		validate_position(p1, label .. " min")
		validate_position(p2, label .. " max")
		if p1.x > p2.x or p1.y > p2.y or p1.z > p2.z or
				not contains(p1.x, p1.y, p1.z) or
				not contains(p2.x, p2.y, p2.z) then
			fail(label .. " is outside the emerged area")
		end
	end

	function vm.set_lighting(_, value, p1, p2)
		if type(value) ~= "table" or not is_finite_integer(value.day) or
				not is_finite_integer(value.night) or value.day < 0 or
				value.day > 15 or value.night < 0 or value.night > 15 then
			fail("set_lighting received an invalid light value")
		end
		validate_box(p1, p2, "set_lighting box")
		record("set_lighting", pack_trace_value(value.day) .. "," ..
			pack_trace_value(value.night) .. "," ..
			pack_trace_value(p1.x) .. "," .. pack_trace_value(p1.y) .. "," ..
			pack_trace_value(p1.z) .. "," .. pack_trace_value(p2.x) .. "," ..
			pack_trace_value(p2.y) .. "," .. pack_trace_value(p2.z))
		local packed = value.day + value.night * 16
		for z = p1.z, p2.z do
			for y = p1.y, p2.y do
				local index = index_of(p1.x, y, z)
				for x = p1.x, p2.x do
					light[index] = packed
					index = index + 1
				end
			end
		end
	end

	local function light_spread(queue_index, queue_light, queue_tail,
			x, y, z, incoming)
		if not contains(x, y, z) then
			return queue_tail
		end
		local index = index_of(x, y, z)
		local cid = data[index]
		if cid == ignore_cid then
			return queue_tail
		end
		local light_propagates = read_light_flags(cid, param2[index])
		if not light_propagates then
			return queue_tail
		end
		local day = incoming % 16
		if day > 0 then
			day = day - 1
		end
		local night = math_floor(incoming / 16)
		if night > 0 then
			night = night - 1
		end
		local current = light[index]
		local current_day = current % 16
		local current_night = math_floor(current / 16)
		if day <= current_day and night <= current_night then
			return queue_tail
		end
		if day < current_day then
			day = current_day
		end
		if night < current_night then
			night = current_night
		end
		local packed = day + night * 16
		light[index] = packed
		queue_tail = queue_tail + 1
		queue_index[queue_tail] = index
		queue_light[queue_tail] = packed
		return queue_tail
	end

	local function spread_neighbors(queue_index, queue_light, queue_tail,
			index, incoming)
		local offset = index - 1
		local z_offset = math_floor(offset / z_stride)
		offset = offset - z_offset * z_stride
		local y_offset = math_floor(offset / y_stride)
		local x_offset = offset - y_offset * y_stride
		local x = emin.x + x_offset
		local y = emin.y + y_offset
		local z = emin.z + z_offset
		queue_tail = light_spread(queue_index, queue_light, queue_tail,
			x - 1, y, z, incoming)
		queue_tail = light_spread(queue_index, queue_light, queue_tail,
			x + 1, y, z, incoming)
		queue_tail = light_spread(queue_index, queue_light, queue_tail,
			x, y - 1, z, incoming)
		queue_tail = light_spread(queue_index, queue_light, queue_tail,
			x, y + 1, z, incoming)
		queue_tail = light_spread(queue_index, queue_light, queue_tail,
			x, y, z - 1, incoming)
		queue_tail = light_spread(queue_index, queue_light, queue_tail,
			x, y, z + 1, incoming)
		return queue_tail
	end

	function vm.calc_lighting(_, p1, p2, propagate_shadow)
		validate_box(p1, p2, "calc_lighting box")
		if type(propagate_shadow) ~= "boolean" then
			fail("calc_lighting requires a boolean propagate_shadow")
		end
		if p2.y + 1 > emax.y then
			fail("calc_lighting requires an overtop row")
		end
		record("calc_lighting", pack_trace_value(p1.x) .. "," ..
			pack_trace_value(p1.y) .. "," .. pack_trace_value(p1.z) .. "," ..
			pack_trace_value(p2.x) .. "," .. pack_trace_value(p2.y) .. "," ..
			pack_trace_value(p2.z) .. "," .. tostring(propagate_shadow))

		local block_is_underground = water_level >= p2.y
		for z = p1.z, p2.z do
			for x = p1.x, p2.x do
				local overtop = index_of(x, p2.y + 1, z)
				local overtop_cid = data[overtop]
				local seeded = true
				if overtop_cid == ignore_cid then
					if block_is_underground then
						seeded = false
					end
				elseif light[overtop] % 16 ~= 15 and propagate_shadow then
					seeded = false
				end
				if seeded then
					for y = p2.y, p1.y, -1 do
						local index = index_of(x, y, z)
						local _, sunlight_propagates =
							read_light_flags(data[index], param2[index])
						if not sunlight_propagates then
							break
						end
						light[index] = 15
					end
				end
			end
		end

		local queue_index = {}
		local queue_light = {}
		local queue_head = 1
		local queue_tail = 0
		for z = emin.z, emax.z do
			for y = emin.y, emax.y do
				local index = index_of(emin.x, y, z)
				for x = emin.x, emax.x do
					local cid = data[index]
					if cid ~= ignore_cid then
						local light_propagates, _, light_source =
							read_light_flags(cid, param2[index])
						if light_propagates then
							if light_source > 0 then
								light[index] = light_source + light_source * 16
							end
							local packed = light[index]
							if packed > 0 then
								queue_tail = spread_neighbors(queue_index,
									queue_light, queue_tail, index, packed)
							end
						end
					end
					index = index + 1
				end
			end
		end
		while queue_head <= queue_tail do
			local index = queue_index[queue_head]
			local packed = queue_light[queue_head]
			queue_head = queue_head + 1
			queue_tail = spread_neighbors(queue_index, queue_light,
				queue_tail, index, packed)
		end
	end

	function vm.update_liquids(_)
		record("update_liquids")
	end

	setmetatable(vm, {
		__index = function(_, key)
			fail("forbidden VoxelManip method " .. tostring(key))
		end,
		__newindex = function()
			fail("VoxelManip proxy is immutable")
		end,
		__metatable = "grug_wp40_r5_vm_proxy_v1",
	})

	local context = {}
	function context.get_heightmap()
		record("get_heightmap")
		context_heightmap_fetch_calls = context_heightmap_fetch_calls + 1
		context_heightmap_external_table_allocations =
			context_heightmap_external_table_allocations + 1
		return copy_array(heightmap_source, 6400)
	end
	function context.metrics()
		context_metrics_result_table_allocations =
			context_metrics_result_table_allocations + 1
		return {
			heightmap_fetch_calls = context_heightmap_fetch_calls,
			heightmap_external_table_allocations =
				context_heightmap_external_table_allocations,
			metrics_result_table_allocations =
				context_metrics_result_table_allocations,
		}
	end
	context.schema = CONTEXT_SCHEMA

	local observer = {}
	function observer.snapshot()
		local trace_copy = {}
		for index = 1, trace_count do
			trace_copy[index] = trace[index]
		end
		local call_copy = {}
		for method_index = 1, #VM_METHODS do
			local name = VM_METHODS[method_index]
			call_copy[name] = calls[name]
		end
		return {
			emin = copy_position(emin),
			emax = copy_position(emax),
			data = copy_array(data, volume),
			param2 = copy_array(param2, volume),
			light = copy_array(light, volume),
			trace = trace_copy,
			calls = call_copy,
		}
	end
	function observer.metrics()
		return {
			trace_entries = trace_count,
			vm_get_emerged_area_calls = calls.get_emerged_area,
			vm_get_data_calls = calls.get_data,
			vm_get_param2_calls = calls.get_param2_data,
			vm_get_light_calls = calls.get_light_data,
			vm_set_data_calls = calls.set_data,
			vm_set_param2_calls = calls.set_param2_data,
			vm_set_lighting_calls = calls.set_lighting,
			vm_calc_lighting_calls = calls.calc_lighting,
			vm_set_light_data_calls = calls.set_light_data,
			vm_update_liquids_calls = calls.update_liquids,
		}
	end

	return vm, context, observer
end

return {new = new}
