-- One R7 successor tail composed from P9G and the fixed activation suffix.
--
-- `settlement_configs` is the ordered WP13 settlement list, and `roster_keys`
-- is the settlement key of every row of `r7_settlement.M.roster` in roster
-- order. Every settlement is planned and settled in that order, and its ledger
-- and metrics are published under its own key, so `ledger.hearthpine` keeps the
-- shape the accepted R6 settlement contract reads and every later settlement
-- adds its own field beside it.
--
-- The key check used to be `if not keys.hearthpine`, i.e. one settlement named
-- in this file. It is derived from the roster now (contract section 2.2.2):
-- the configs must be exactly the roster's keys, in the roster's order, so
-- losing ANY settlement -- or reordering them, which would reorder the manifest
-- -- is what fails here.

return function(p9g_config, anchor_config, settlement_configs, roster_keys, world_config)
	local function fail(message) error("WP40 R7 successor: " .. message, 0) end
	if type(p9g_config) ~= "table" or type(p9g_config.new) ~= "function" or
			type(anchor_config) ~= "table" or type(anchor_config.new) ~= "function" or
			type(settlement_configs) ~= "table" or #settlement_configs < 1 or
			type(roster_keys) ~= "table" or #roster_keys ~= #settlement_configs then
		fail("configuration seam differs")
	end
	-- The ledger and the metrics below are ONE table per settle: the fixed
	-- fields first, then one field per settlement under its roster key. A
	-- roster key equal to a fixed field would overwrite it and publish a
	-- settlement's ledger as the schema string, the P9G ledger or the anchor
	-- ledger, so the roster may not carry one.
	local RESERVED_LEDGER_FIELDS = {schema = true, p9g = true, anchors = true, world_content = true}
	local keys = {}
	for index = 1, #settlement_configs do
		local settlement = settlement_configs[index]
		if type(settlement) ~= "table" or type(settlement.new) ~= "function" or
				type(settlement.key) ~= "string" or settlement.key == "" or
				keys[settlement.key] then
			fail("settlement configuration seam differs")
		end
		if RESERVED_LEDGER_FIELDS[settlement.key] then
			fail("settlement key is a reserved ledger field: " .. settlement.key)
		end
		if settlement.key ~= roster_keys[index] then
			fail("settlement " .. index .. " is not the roster's " ..
				tostring(roster_keys[index]))
		end
		keys[settlement.key] = true
	end
	local config = {schema = "grug_wp40_r7_successor_config_v1"}
	function config.new(dependencies)
		local p9g = p9g_config.new({full_seed_string = dependencies.full_seed_string,
			hash = dependencies.hash, planner_source = dependencies.planner_source,
			horizontal = dependencies.horizontal, content = dependencies.content,
			source = dependencies.source, zones_session = dependencies.zones_session,
			construction_identity = dependencies.construction_identity,
			runtime_mode = dependencies.runtime_mode})
		local anchors = anchor_config.new(dependencies)
		local world = assert(world_config).new(dependencies)
		local settlements = {}
		for index = 1, #settlement_configs do
			local settlement = settlement_configs[index].new(dependencies)
			if type(settlement) ~= "table" or
					settlement.key ~= settlement_configs[index].key then
				fail("settlement tail differs")
			end
			settlements[index] = settlement
		end
		local tail = {}
		function tail.plan_slice(self, minp, maxp, plan, generation)
			if not rawequal(self, tail) then fail("plan receiver differs") end
			p9g:plan_slice(minp, maxp, plan, generation)
			world.bind(plan, generation)
			anchors:bind_plan(minp, maxp, plan, generation)
			for index = 1, #settlements do
				settlements[index]:bind_plan(minp, maxp, plan, generation)
			end
		end
		function tail.plan_evidence_owner(self, min_x, max_x, min_z, max_z)
			if not rawequal(self, tail) then fail("evidence receiver differs") end
			local plan, generation = p9g:plan_evidence_owner(min_x, max_x, min_z, max_z)
			world.bind(plan, generation)
			anchors:bind_plan({x = min_x, y = -30912, z = min_z},
				{x = max_x, y = 30927, z = max_z}, plan, generation)
			for index = 1, #settlements do
				settlements[index]:bind_plan({x = min_x, y = -30912, z = min_z},
					{x = max_x, y = 30927, z = max_z}, plan, generation)
			end
			return plan, generation
		end
		function tail.settle(self, context)
			if not rawequal(self, tail) then fail("settle receiver differs") end
			local p9g_context = {}
			for _, key in ipairs({"schema", "plan", "generation", "call_mode",
					"min_x", "min_y", "min_z", "max_x", "max_y", "max_z",
					"inside_owner", "original_at", "settled_at", "production_content",
					"analytic_p7_ref", "analytic_p7_tuple", "exclusion_at",
					"housing_excluded_at", "column_values_at", "write_p9g"}) do
				p9g_context[key] = context[key]
			end
			local p9g_ledger = p9g:settle(p9g_context)
			local world_ledger = world.settle(context)
			local anchor_ledger = anchors:settle(context)
			local ledger = {schema = "grug_wp40_r7_successor_ledger_v1",
				p9g = p9g_ledger, world_content = world_ledger, anchors = anchor_ledger}
			for index = 1, #settlements do
				ledger[settlements[index].key] = settlements[index]:settle(context)
			end
			return ledger
		end
		function tail.metrics(self)
			if not rawequal(self, tail) then fail("metrics receiver differs") end
			local metrics = {schema = "grug_wp40_r7_successor_metrics_v1",
				p9g = p9g:metrics(), world_content = world.metrics(), anchors = anchors:metrics()}
			for index = 1, #settlements do
				metrics[settlements[index].key] = settlements[index]:metrics()
			end
			return metrics
		end
		function tail.probe_reason(self, context, catalog_index, x, y, z)
			if not rawequal(self, tail) then fail("probe receiver differs") end
			return p9g:probe_reason(context, catalog_index, x, y, z)
		end
		function tail.anchor_roster(self)
			if not rawequal(self, tail) then fail("roster receiver differs") end
			return anchors:roster()
		end
		return tail
	end
	return config
end
