-- One R7 successor tail composed from P9G and the fixed activation suffix.

return function(p9g_config, anchor_config)
	local function fail(message) error("WP40 R7 successor: " .. message, 0) end
	if type(p9g_config) ~= "table" or type(p9g_config.new) ~= "function" or
			type(anchor_config) ~= "table" or type(anchor_config.new) ~= "function" then
		fail("configuration seam differs")
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
		local tail = {}
		function tail.plan_slice(self, minp, maxp, plan, generation)
			if not rawequal(self, tail) then fail("plan receiver differs") end
			p9g:plan_slice(minp, maxp, plan, generation)
			anchors:bind_plan(minp, maxp, plan, generation)
		end
		function tail.plan_evidence_owner(self, min_x, max_x, min_z, max_z)
			if not rawequal(self, tail) then fail("evidence receiver differs") end
			local plan, generation = p9g:plan_evidence_owner(min_x, max_x, min_z, max_z)
			anchors:bind_plan({x = min_x, y = -30912, z = min_z},
				{x = max_x, y = 30927, z = max_z}, plan, generation)
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
			return {schema = "grug_wp40_r7_successor_ledger_v1",
				p9g = p9g:settle(p9g_context), anchors = anchors:settle(context)}
		end
		function tail.metrics(self)
			if not rawequal(self, tail) then fail("metrics receiver differs") end
			return {schema = "grug_wp40_r7_successor_metrics_v1",
				p9g = p9g:metrics(), anchors = anchors:metrics()}
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
