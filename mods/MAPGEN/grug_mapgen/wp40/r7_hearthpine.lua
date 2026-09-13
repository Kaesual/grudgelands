-- The first WP13 settlement. This pure successor clips one fixed blueprint to
-- the current mapchunk owner and mutates bytes only through R7's private writer.

return function(blueprint, content, raw_sha256)
	local function fail(message)
		error("WP13 Hearthpine: " .. message, 0)
	end
	local function integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or
				value < minimum or value > maximum then
			fail(label .. " differs")
		end
		return value
	end
	local function hex(bytes)
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end
	if type(blueprint) ~= "table" or
			blueprint.schema ~= "grug_wp13_hearthpine_blueprint_v1" or
			type(blueprint.cells) ~= "table" or #blueprint.cells < 1 or
			type(blueprint.bounds) ~= "table" or
			type(blueprint.bounds.min) ~= "table" or
			type(blueprint.bounds.max) ~= "table" or
			type(blueprint.palette) ~= "table" or #blueprint.palette < 1 or
			type(blueprint.landmarks) ~= "table" or
			type(content) ~= "table" or
			content.schema ~= "grug_wp13_hearthpine_content_v1" or
			type(content.content_names) ~= "table" or
			#content.content_names ~= #blueprint.palette or
			type(content.resolve) ~= "function" or
			type(content.content_ref) ~= "function" or
			type(raw_sha256) ~= "function" then
		fail("construction seam differs")
	end
	local palette = {}
	for index = 1, #blueprint.palette do
		local name = blueprint.palette[index]
		if type(name) ~= "string" or name == "" or palette[name] or
				content.content_names[index] ~= name or
				(index > 1 and not (blueprint.palette[index - 1] < name)) then
			fail("palette differs")
		end
		palette[name] = index
	end
	local minimum, maximum = blueprint.bounds.min, blueprint.bounds.max
	for _, axis in ipairs({"x", "y", "z"}) do
		integer(minimum[axis], "minimum " .. axis, -9007199254740991,
			9007199254740991)
		integer(maximum[axis], "maximum " .. axis, minimum[axis],
			9007199254740991)
	end
	if minimum.x < -63 or maximum.x > 63 or minimum.z < -63 or maximum.z > 63 or
			minimum.y < -2 or maximum.y > 24 then
		fail("blueprint bounds escape the authorized volume")
	end
	local cells, prior, seen, actual_min, actual_max = {}, nil, {}, {}, {}
	local bytes = {"schema\tgrug_wp13_hearthpine_blueprint_identity_v1\n",
		table.concat({"bounds", minimum.x, minimum.y, minimum.z,
			maximum.x, maximum.y, maximum.z}, "\t") .. "\n"}
	for index = 1, #blueprint.palette do
		bytes[#bytes + 1] = table.concat({"palette", index,
			blueprint.palette[index]}, "\t") .. "\n"
	end
	for index = 1, #blueprint.cells do
		local cell = blueprint.cells[index]
		if type(cell) ~= "table" then fail("cell differs at " .. index) end
		local x = integer(cell.x, "cell x", -63, 63)
		local y = integer(cell.y, "cell y", -2, 24)
		local z = integer(cell.z, "cell z", -63, 63)
		local ref = palette[cell.name]
		local param2 = integer(cell.param2, "cell param2", 0, 255)
		if not ref then fail("cell name is outside palette") end
		if prior and (z < prior.z or (z == prior.z and
				(y < prior.y or (y == prior.y and x <= prior.x)))) then
			fail("cells are not canonical z/y/x unique")
		end
		local key = x .. "/" .. y .. "/" .. z
		if seen[key] then fail("duplicate cell") end
		seen[key], prior = true, {x = x, y = y, z = z}
		cells[index] = {x = x, y = y, z = z, content_ref = ref,
			param2 = param2, name = cell.name}
		for _, axis in ipairs({"x", "y", "z"}) do
			local value = cell[axis]
			if actual_min[axis] == nil or value < actual_min[axis] then actual_min[axis] = value end
			if actual_max[axis] == nil or value > actual_max[axis] then actual_max[axis] = value end
		end
		bytes[#bytes + 1] = table.concat({"cell", x, y, z, cell.name, param2}, "\t") .. "\n"
	end
	for _, axis in ipairs({"x", "y", "z"}) do
		if minimum[axis] ~= actual_min[axis] or maximum[axis] ~= actual_max[axis] then
			fail("declared bounds differ on " .. axis)
		end
	end
	local function cell_at(x, y, z)
		for index = 1, #cells do
			local cell = cells[index]
			if cell.x == x and cell.y == y and cell.z == z then return cell end
		end
		return nil
	end
	local support = cell_at(0, 0, 0)
	if not support or support.name == "air" then fail("spawn support differs") end
	for y = 1, 3 do
		local cell = cell_at(0, y, 0)
		if not cell or cell.name ~= "air" then fail("spawn clearance differs") end
	end
	local digest = raw_sha256(table.concat(bytes))
	if type(digest) ~= "string" or #digest ~= 32 then fail("SHA-256 seam differs") end
	local identity = {schema = "grug_wp13_hearthpine_blueprint_identity_v1",
		sha256 = hex(digest), cell_count = #cells,
		min_x = minimum.x, min_y = minimum.y, min_z = minimum.z,
		max_x = maximum.x, max_y = maximum.y, max_z = maximum.z}

	local config = {schema = "grug_wp13_hearthpine_config_v1", identity = identity}
	function config.new(dependencies)
		if type(dependencies) ~= "table" or type(dependencies.zones_session) ~= "table" or
				type(dependencies.zones_session.anchor) ~= "function" then
			fail("successor dependencies differ")
		end
		local anchor = dependencies.zones_session.anchor(
			"elandor_hearthpine_vale", "start")
		if type(anchor) ~= "table" or anchor.id ~= "anchor_001" or
				anchor.numeric_id ~= 1 or anchor.x ~= -1800 or anchor.z ~= -2550 or
				type(anchor.y) ~= "number" or anchor.y % 1 ~= 0 then
			fail("stable start anchor differs")
		end
		local bound_plan, bound_generation, active = false, 0, false
		local metrics = {plan_calls = 0, settle_calls = 0, replay_calls = 0,
			written = 0}
		local tail = {}
		function tail.bind_plan(self, minp, maxp, plan, generation)
			if not rawequal(self, tail) or type(minp) ~= "table" or
					type(maxp) ~= "table" or type(plan) ~= "table" then
				fail("plan binding differs")
			end
			active = anchor.x + maximum.x >= minp.x and anchor.x + minimum.x <= maxp.x and
				anchor.y + maximum.y >= minp.y and anchor.y + minimum.y <= maxp.y and
				anchor.z + maximum.z >= minp.z and anchor.z + minimum.z <= maxp.z
			bound_plan, bound_generation = plan, generation
			metrics.plan_calls = metrics.plan_calls + 1
		end
		function tail.settle(self, context)
			if not rawequal(self, tail) or type(context) ~= "table" or
					not rawequal(context.plan, bound_plan) or
					context.generation ~= bound_generation or
					type(context.inside_owner) ~= "function" or
					type(context.write_hearthpine) ~= "function" then
				fail("settlement plan binding differs")
			end
			local written = 0
			if active then
				for index = 1, #cells do
					local cell = cells[index]
					local x, y, z = anchor.x + cell.x, anchor.y + cell.y,
						anchor.z + cell.z
					if context.inside_owner(x, y, z) then
						local cid, param2 = content.resolve(cell.content_ref, cell.param2)
						context.write_hearthpine(x, y, z, cid, param2,
							cell.content_ref, 1)
						written = written + 1
					end
				end
			end
			if context.call_mode == "replay_fixture" then
				metrics.replay_calls = metrics.replay_calls + 1
			else
				metrics.settle_calls = metrics.settle_calls + 1
				metrics.written = metrics.written + written
			end
			return {schema = "grug_wp13_hearthpine_ledger_v1",
				blueprint_sha256 = identity.sha256, written = written}
		end
		function tail.metrics(self)
			if not rawequal(self, tail) then fail("metrics receiver differs") end
			return {schema = "grug_wp13_hearthpine_metrics_v1",
				plan_calls = metrics.plan_calls, settle_calls = metrics.settle_calls,
				replay_calls = metrics.replay_calls, written = metrics.written,
				blueprint_sha256 = identity.sha256}
		end
		return tail
	end
	return config
end
