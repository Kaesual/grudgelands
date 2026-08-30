-- Internal, disabled WP40 R6 construction boundary. R7 owns activation.

return function(dependencies)
	if type(dependencies) ~= "table" then error("WP40 R6 dependencies missing", 0) end
	local ALLOWED = {
		r5_factory = true, zones_factory = true, r5_planner_factory = true,
		r5_adapter_factory = true, manifest_module = true, allocator_factory = true,
		source = true, schemas = true, canonical = true, deterministic = true,
		index128 = true, horizontal_factory = true, height_factory = true,
		raw_sha256 = true, hash_factory = true, content_factory = true,
		templates_factory = true, planner_factory = true, settlement_factory = true,
	}
	for key in pairs(dependencies) do
		if not ALLOWED[key] then
			error("WP40 R6 unexpected dependency " .. tostring(key), 0)
		end
	end
	for key in pairs(ALLOWED) do
		if dependencies[key] == nil then
			error("WP40 R6 dependency missing: " .. key, 0)
		end
	end
	local STATUS = "disabled_r6_surface_resource_content"
	local CULTURAL_KEYS = {
		"gravesalt", "moonresin", "red_ochre", "runeslate", "spirit_resin",
		"sunwax",
	}
	local MAX_SAFE = 9007199254740991

	local function fail(code, message)
		error(code .. ": " .. message, 0)
	end

	local function integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail("fail_cultural_registration",
				label .. " is not an exact bounded integer")
		end
		return value
	end

	local function text(value, label)
		if type(value) ~= "string" or value == "" or
				value:find("\0", 1, true) or value:find("\t", 1, true) or
				value:find("\r", 1, true) or value:find("\n", 1, true) then
			fail("fail_cultural_registration", label .. " is not length-safe text")
		end
		return value
	end

	local function exact_fields(value, allowed, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail("fail_cultural_registration", label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not allowed[key] then
				fail("fail_cultural_registration",
					label .. " has unexpected field " .. tostring(key))
			end
		end
		for key in pairs(allowed) do
			if value[key] == nil then
				fail("fail_cultural_registration", label .. " is missing " .. key)
			end
		end
		return value
	end

	local function dense(values, label)
		if type(values) ~= "table" or getmetatable(values) ~= nil then
			fail("fail_cultural_registration", label .. " is not a plain array")
		end
		local count = #values
		for index = 1, count do
			if values[index] == nil then
				fail("fail_cultural_registration", label .. " has a hole")
			end
		end
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				fail("fail_cultural_registration", label .. " is not dense")
			end
		end
		return count
	end

	local function copy(value, active)
		if type(value) ~= "table" then return value end
		active = active or {}
		if active[value] then
			fail("fail_cultural_registration", "registration graph contains a cycle")
		end
		active[value] = true
		local result = {}
		for key, child in pairs(value) do result[copy(key, active)] = copy(child, active) end
		active[value] = nil
		return result
	end

	if type(dependencies.raw_sha256) ~= "function" or
			type(dependencies.hash_factory) ~= "function" or
			type(dependencies.content_factory) ~= "function" or
			type(dependencies.templates_factory) ~= "function" or
			type(dependencies.planner_factory) ~= "table" or
			type(dependencies.planner_factory.new) ~= "function" or
			type(dependencies.settlement_factory) ~= "table" or
			type(dependencies.settlement_factory.new) ~= "function" or
			type(dependencies.r5_factory) ~= "function" then
		fail("fail_status", "module factory seam differs")
	end

	local hash = dependencies.hash_factory(dependencies.raw_sha256)

	local function canonical_registration(cultural_key, definition)
		local known = false
		for index = 1, #CULTURAL_KEYS do
			if CULTURAL_KEYS[index] == cultural_key then known = true end
		end
		if not known then fail("fail_cultural_registration", "unknown cultural key") end
		exact_fields(definition, {
			id = true, template_or_simple_kind = true, immutable_content = true,
			footprint_min_x = true, footprint_max_x = true,
			footprint_min_y = true, footprint_max_y = true,
			footprint_min_z = true, footprint_max_z = true,
			lower_two_policy = true,
		}, "cultural definition")
		local id = text(definition.id, "cultural definition ID")
		local kind = definition.template_or_simple_kind
		if kind ~= "simple" and kind ~= "template" then
			fail("fail_cultural_registration", "cultural content kind differs")
		end
		local min_x = integer(definition.footprint_min_x, "footprint min x", -2, 2)
		local max_x = integer(definition.footprint_max_x, "footprint max x", -2, 2)
		local min_y = integer(definition.footprint_min_y, "footprint min y", -1, 7)
		local max_y = integer(definition.footprint_max_y, "footprint max y", -1, 7)
		local min_z = integer(definition.footprint_min_z, "footprint min z", -2, 2)
		local max_z = integer(definition.footprint_max_z, "footprint max z", -2, 2)
		if min_x > max_x or min_y > max_y or min_z > max_z then
			fail("fail_cultural_registration", "cultural footprint is inverted")
		end
		if definition.lower_two_policy ~= "preserve_p7" and
				definition.lower_two_policy ~= "replace_exact_p7" then
			fail("fail_cultural_registration", "lower-two policy differs")
		end
		exact_fields(definition.immutable_content, {cells = true},
			"cultural immutable content")
		local cell_count = dense(definition.immutable_content.cells,
			"cultural content cells")
		if cell_count < 1 or cell_count > 225 then
			fail("fail_cultural_registration", "cultural cell population differs")
		end
		local cells, seen = {}, {}
		for index = 1, cell_count do
			local cell = definition.immutable_content.cells[index]
			exact_fields(cell, {x = true, y = true, z = true, node = true,
				param2 = true, force_place = true}, "cultural cell")
			local x = integer(cell.x, "cultural cell x", min_x, max_x)
			local y = integer(cell.y, "cultural cell y", min_y, max_y)
			local z = integer(cell.z, "cultural cell z", min_z, max_z)
			local key = x .. "\0" .. y .. "\0" .. z
			if seen[key] then
				fail("fail_cultural_registration", "duplicate cultural cell")
			end
			seen[key] = true
			if type(cell.force_place) ~= "boolean" then
				fail("fail_cultural_registration", "cultural force_place differs")
			end
			cells[index] = {x = x, y = y, z = z,
				node = text(cell.node, "cultural cell node"),
				param2 = integer(cell.param2, "cultural cell param2", 0, 255),
				force_place = cell.force_place}
		end
		table.sort(cells, function(left, right)
			if left.y ~= right.y then return left.y < right.y end
			if left.z ~= right.z then return left.z < right.z end
			return left.x < right.x
		end)
		local parts = {
			hash.frame("grug_wp40_r6_cultural_registration_v1"),
			hash.frame(cultural_key), hash.frame(id), hash.frame(kind),
			hash.frame(min_x), hash.frame(max_x), hash.frame(min_y), hash.frame(max_y),
			hash.frame(min_z), hash.frame(max_z),
			hash.frame(definition.lower_two_policy),
		}
		for index = 1, #cells do
			local cell = cells[index]
			parts[#parts + 1] = hash.frame(cell.x)
			parts[#parts + 1] = hash.frame(cell.y)
			parts[#parts + 1] = hash.frame(cell.z)
			parts[#parts + 1] = hash.frame(cell.node)
			parts[#parts + 1] = hash.frame(cell.param2)
			parts[#parts + 1] = hash.frame(cell.force_place and "true" or "false")
		end
		local digest = hash.hex(hash.sha256_bytes(table.concat(parts)))
		return {
			schema = "grug_wp40_r6_cultural_registration_v1",
			cultural_key = cultural_key, id = id,
			template_or_simple_kind = kind,
			footprint_min_x = min_x, footprint_max_x = max_x,
			footprint_min_y = min_y, footprint_max_y = max_y,
			footprint_min_z = min_z, footprint_max_z = max_z,
			lower_two_policy = definition.lower_two_policy,
			cells = cells, digest = digest,
		}, digest
	end

	local function cultural_slot_api()
		local validator = {}
		function validator.required_keys()
			local result = {}
			for index = 1, #CULTURAL_KEYS do result[index] = CULTURAL_KEYS[index] end
			return result
		end
		function validator.validate(cultural_key, definition)
			local record, digest = canonical_registration(cultural_key, definition)
			return copy(record), digest
		end
		return validator
	end

	local r5_module = dependencies.r5_factory({
		zones_factory = dependencies.zones_factory,
		planner_factory = dependencies.r5_planner_factory,
		adapter_factory = dependencies.r5_adapter_factory,
		manifest_module = dependencies.manifest_module,
		allocator_factory = dependencies.allocator_factory,
		source = dependencies.source, schemas = dependencies.schemas,
		canonical = dependencies.canonical,
		deterministic = dependencies.deterministic,
		index128 = dependencies.index128,
		horizontal_factory = dependencies.horizontal_factory,
		height_factory = dependencies.height_factory,
		raw_sha256 = dependencies.raw_sha256,
	})

	local module = {}
	function module.status() return STATUS end
	function module.cultural_slot_api() return cultural_slot_api() end
	function module.new(full_seed_string, configured_water_level, manifest_values,
			content_contract, mapgen_context, wp43_projection, template_source,
			cultural_registrations)
		if type(full_seed_string) ~= "string" or full_seed_string == "" then
			fail("fail_hash", "full seed string differs")
		end
		integer(configured_water_level, "configured water level", -31000, 31000)
		if configured_water_level ~= 1 then fail("fail_manifest", "water level differs") end
		local content_module = dependencies.content_factory(manifest_values,
			content_contract, wp43_projection)
		local templates_module = dependencies.templates_factory(hash, content_module,
			template_source)
		local normalized_registrations = {}
		local registration_count = dense(cultural_registrations,
			"cultural registrations")
		if registration_count ~= 0 and registration_count ~= 6 then
			fail("fail_cultural_registration", "registration population differs")
		end
		for index = 1, registration_count do
			local supplied = cultural_registrations[index]
			if type(supplied) ~= "table" or
					supplied.schema ~= "grug_wp40_r6_cultural_registration_v1" or
					supplied.cultural_key ~= CULTURAL_KEYS[index] then
				fail("fail_cultural_registration", "registration order/schema differs")
			end
			local definition = {
				id = supplied.id,
				template_or_simple_kind = supplied.template_or_simple_kind,
				immutable_content = {cells = supplied.cells},
				footprint_min_x = supplied.footprint_min_x,
				footprint_max_x = supplied.footprint_max_x,
				footprint_min_y = supplied.footprint_min_y,
				footprint_max_y = supplied.footprint_max_y,
				footprint_min_z = supplied.footprint_min_z,
				footprint_max_z = supplied.footprint_max_z,
				lower_two_policy = supplied.lower_two_policy,
			}
			local checked, digest = canonical_registration(supplied.cultural_key,
				definition)
			if supplied.digest ~= digest then
				fail("fail_cultural_registration", "registration digest differs")
			end
			for cell_index = 1, #checked.cells do
				local cell = checked.cells[cell_index]
				local content_ref = content_module.content_ref(cell.node)
				if not content_ref or
						math.floor(content_contract.content_kind_masks[content_ref] / 16) % 2 ~= 1 then
					fail("fail_cultural_registration", "cultural node role differs")
				end
				local cid, kind, mode, param2 = content_contract.resolve_r6(content_ref,
					cell.param2)
				if cid == content_contract.ignore_cid or kind ~= 1 or mode ~= 1 or
						param2 ~= cell.param2 then
					fail("fail_cultural_registration", "cultural target differs")
				end
				cell.content_ref = content_ref
			end
			normalized_registrations[index] = checked
		end

		local _, planner_source, r5_planner, r5_adapter = r5_module.new(
			full_seed_string, configured_water_level,
			content_module.r5_manifest_values(), content_contract.r5, mapgen_context)
		local horizontal_module = dependencies.horizontal_factory({
			source = dependencies.source, schemas = dependencies.schemas,
			canonical = dependencies.canonical,
			deterministic = dependencies.deterministic,
			raw_sha256 = dependencies.raw_sha256,
		})
		local horizontal = horizontal_module.new(full_seed_string)
		local identity_holder = {value = false}
		local planner_allocator = dependencies.allocator_factory.new(
			"grug_wp40_r6_planner_allocator_v1")
		local settlement_allocator = dependencies.allocator_factory.new(
			"grug_wp40_r6_settlement_allocator_v1")
		local planner = dependencies.planner_factory.new({
			full_seed_string = full_seed_string, planner_source = planner_source,
			r5_planner = r5_planner, horizontal = horizontal,
			content = content_module, templates = templates_module, hash = hash,
			source = dependencies.source, construction_identity = identity_holder,
			counting_allocator = planner_allocator,
		})
		local settlement = dependencies.settlement_factory.new({
			full_seed_string = full_seed_string, r5_adapter = r5_adapter,
			content = content_module, templates = templates_module, hash = hash,
			horizontal = horizontal, planner_source = planner_source,
			construction_identity = identity_holder,
			cultural_registrations = normalized_registrations,
			source = dependencies.source, counting_allocator = settlement_allocator,
		})
		local session = {}
		function session.plan_slice(minp, maxp)
			return planner:plan_slice(minp, maxp)
		end
		function session.apply_fixture(vm, minp, maxp, plan, generation)
			return settlement:apply(vm, minp, maxp, plan, generation, "fixture")
		end
		function session.metrics()
			return {planner = planner:metrics(), settlement = settlement:metrics(),
				r5_planner = r5_planner:metrics(), r5_adapter = r5_adapter:metrics(),
				content = content_contract.metrics()}
		end
		function session.status() return STATUS end
		return session
	end
	return module
end
