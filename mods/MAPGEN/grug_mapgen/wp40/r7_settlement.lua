-- The WP13 start settlements. One pure successor per settlement clips its
-- fixed blueprint to the current mapchunk owner and mutates bytes only
-- through R7's private writer.
--
-- The first increment hard-wired Hearthpine Vale into this file. From the
-- fourth increment on the same code serves every start: a settlement is a
-- profile in `M.roster` (zone, anchor identity, blueprint file and the schema
-- strings its identity, ledger and metrics carry) plus a blueprint, and
-- `M.config(profile, blueprint, content, raw_sha256)` returns the successor
-- configuration the R7 successor composes. Hearthpine keeps every schema
-- string and every identity byte it had, so its blueprint identity SHA-256 is
-- unchanged by the generalisation.
--
-- `content` is the ONE shared opcode-37 settlement content channel
-- (`r7_content.lua`): a cell's `content_ref` indexes the sorted union of
-- every start's palette, not this blueprint's own palette.
--
-- Plain Lua 5.1, no globals.

local M = {}

-- Fixed order. The successor settles the roster in this order, and the
-- manifest publishes one identity block per row in the same order.
M.roster = {
	{
		key = "hearthpine", label = "Hearthpine",
		zone_id = "elandor_hearthpine_vale",
		anchor_id = "anchor_001", numeric_id = 1, x = -1800, z = -2550,
		blueprint_file = "r7_hearthpine_blueprint.lua",
		blueprint_schema = "grug_wp13_hearthpine_blueprint_v1",
		identity_schema = "grug_wp13_hearthpine_blueprint_identity_v1",
		config_schema = "grug_wp13_hearthpine_config_v1",
		ledger_schema = "grug_wp13_hearthpine_ledger_v1",
		metrics_schema = "grug_wp13_hearthpine_metrics_v1",
		delta_schema = "grug_wp13_hearthpine_delta_v1",
	},
	{
		key = "dawnmere", label = "Dawnmere",
		zone_id = "elandor_dawnmere_fields",
		anchor_id = "anchor_002", numeric_id = 2, x = 0, z = -2550,
		blueprint_file = "r7_dawnmere_blueprint.lua",
		blueprint_schema = "grug_wp13_dawnmere_blueprint_v1",
		identity_schema = "grug_wp13_dawnmere_blueprint_identity_v1",
		config_schema = "grug_wp13_dawnmere_config_v1",
		ledger_schema = "grug_wp13_dawnmere_ledger_v1",
		metrics_schema = "grug_wp13_dawnmere_metrics_v1",
		delta_schema = "grug_wp13_dawnmere_delta_v1",
	},
	{
		key = "kapok", label = "Kapok",
		zone_id = "kragmar_kapok_cradle",
		anchor_id = "anchor_006", numeric_id = 6, x = 1800, z = 2550,
		blueprint_file = "r7_kapok_blueprint.lua",
		blueprint_schema = "grug_wp13_kapok_blueprint_v1",
		identity_schema = "grug_wp13_kapok_blueprint_identity_v1",
		config_schema = "grug_wp13_kapok_config_v1",
		ledger_schema = "grug_wp13_kapok_ledger_v1",
		metrics_schema = "grug_wp13_kapok_metrics_v1",
		delta_schema = "grug_wp13_kapok_delta_v1",
	},
}

local PROFILE_FIELDS = {"key", "label", "zone_id", "anchor_id", "numeric_id",
	"x", "z", "blueprint_file", "blueprint_schema", "identity_schema",
	"config_schema", "ledger_schema", "metrics_schema", "delta_schema"}

function M.config(profile, blueprint, content, raw_sha256)
	if type(profile) ~= "table" then
		error("WP13 settlement: profile differs", 0)
	end
	for _, field in ipairs(PROFILE_FIELDS) do
		local value = profile[field]
		local wanted = (field == "numeric_id" or field == "x" or field == "z")
			and "number" or "string"
		if type(value) ~= wanted or (wanted == "string" and value == "") then
			error("WP13 settlement: profile field " .. field .. " differs", 0)
		end
	end
	local function fail(message)
		error("WP13 " .. profile.label .. ": " .. message, 0)
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
			blueprint.schema ~= profile.blueprint_schema or
			type(blueprint.cells) ~= "table" or #blueprint.cells < 1 or
			type(blueprint.bounds) ~= "table" or
			type(blueprint.bounds.min) ~= "table" or
			type(blueprint.bounds.max) ~= "table" or
			type(blueprint.palette) ~= "table" or #blueprint.palette < 1 or
			type(blueprint.landmarks) ~= "table" or
			type(content) ~= "table" or
			content.schema ~= "grug_wp13_settlement_content_v1" or
			type(content.content_names) ~= "table" or
			#content.content_names < #blueprint.palette or
			type(content.resolve) ~= "function" or
			type(content.content_ref) ~= "function" or
			type(raw_sha256) ~= "function" then
		fail("construction seam differs")
	end
	-- Every blueprint name resolves to one ref in the shared channel; the
	-- blueprint's own palette stays sorted and duplicate free, which is what
	-- the identity bytes below are written from.
	local palette = {}
	for index = 1, #blueprint.palette do
		local name = blueprint.palette[index]
		if type(name) ~= "string" or name == "" or palette[name] or
				(index > 1 and not (blueprint.palette[index - 1] < name)) then
			fail("palette differs")
		end
		local ref = content.content_ref(name)
		if type(ref) ~= "number" or ref % 1 ~= 0 or ref < 1 or
				content.content_names[ref] ~= name then
			fail("palette differs")
		end
		palette[name] = ref
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
	local bytes = {"schema\t" .. profile.identity_schema .. "\n",
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
	local identity = {schema = profile.identity_schema,
		sha256 = hex(digest), cell_count = #cells,
		min_x = minimum.x, min_y = minimum.y, min_z = minimum.z,
		max_x = maximum.x, max_y = maximum.y, max_z = maximum.z}

	local config = {schema = profile.config_schema, identity = identity,
		key = profile.key, label = profile.label, anchor_id = profile.anchor_id,
		delta_schema = profile.delta_schema}
	function config.new(dependencies)
		if type(dependencies) ~= "table" or type(dependencies.zones_session) ~= "table" or
				type(dependencies.zones_session.anchor) ~= "function" then
			fail("successor dependencies differ")
		end
		local anchor = dependencies.zones_session.anchor(profile.zone_id, "start")
		if type(anchor) ~= "table" or anchor.id ~= profile.anchor_id or
				anchor.numeric_id ~= profile.numeric_id or
				anchor.x ~= profile.x or anchor.z ~= profile.z or
				type(anchor.y) ~= "number" or anchor.y % 1 ~= 0 then
			fail("stable start anchor differs")
		end
		local bound_plan, bound_generation, active = false, 0, false
		local metrics = {plan_calls = 0, settle_calls = 0, replay_calls = 0,
			written = 0}
		local tail = {key = profile.key}
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
						-- `write_hearthpine` is R7's opcode-37 settlement writer.
						-- The name is the historical one from the first increment
						-- and belongs to the accepted R6 settlement contract; the
						-- channel carries every start, not only Hearthpine.
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
			return {schema = profile.ledger_schema,
				blueprint_sha256 = identity.sha256, written = written}
		end
		function tail.metrics(self)
			if not rawequal(self, tail) then fail("metrics receiver differs") end
			return {schema = profile.metrics_schema,
				plan_calls = metrics.plan_calls, settle_calls = metrics.settle_calls,
				replay_calls = metrics.replay_calls, written = metrics.written,
				blueprint_sha256 = identity.sha256}
		end
		return tail
	end
	return config
end

return M
