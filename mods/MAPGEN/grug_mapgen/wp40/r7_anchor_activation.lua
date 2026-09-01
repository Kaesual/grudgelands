-- Fixed R7 activation cells. This module owns no engine API and may mutate
-- world bytes only through the private successor context supplied by R6.

return function(roster_factory, anchor_content)
	local function fail(message)
		error("fail_anchor_activation: " .. message, 0)
	end
	if type(roster_factory) ~= "function" or type(anchor_content) ~= "table" or
			anchor_content.schema ~= "grug_wp40_r7_anchor_content_v1" or
			type(anchor_content.resolve_anchor) ~= "function" then
		fail("construction seam differs")
	end
	local config = {schema = "grug_wp40_r7_anchor_config_v1"}
	function config.new(dependencies)
		if type(dependencies) ~= "table" or type(dependencies.source) ~= "table" or
				type(dependencies.zones_session) ~= "table" or
				type(dependencies.raw_sha256) ~= "function" or
				type(dependencies.content) ~= "table" then
			fail("successor dependencies differ")
		end
		local roster = roster_factory(dependencies.source, dependencies.zones_session,
			dependencies.raw_sha256)
		local production = dependencies.content.content_contract()
		local air_cid, air_kind, air_param2 = production.r5.resolve(1, 0, 0)
		if air_kind ~= 0 or air_param2 ~= 0 or air_cid == production.ignore_cid then
			fail("air authority differs")
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
			active = false
			for index = 1, #roster.rows do
				local row, root_y = roster.rows[index], roster.rows[index].y + 1
				if row.x >= minp.x and row.x <= maxp.x and row.z >= minp.z and
						row.z <= maxp.z and root_y >= minp.y and root_y <= maxp.y then
					active = true
					break
				end
			end
			bound_plan, bound_generation = plan, generation
			metrics.plan_calls = metrics.plan_calls + 1
		end
		function tail.settle(self, context)
			if not rawequal(self, tail) or type(context) ~= "table" or
					not rawequal(context.plan, bound_plan) or
					context.generation ~= bound_generation then
				fail("settlement plan binding differs")
			end
			local ledger = {schema = "grug_wp40_r7_anchor_ledger_v1",
				roster_sha256 = roster.sha256, operations = {}, written = 0}
			if active then
				for index = 1, #roster.rows do
					local row = roster.rows[index]
					local root_y = row.y + 1
					if context.inside_owner(row.x, root_y, row.z) then
						local water_class, _, zone_id, _, _, terrain_y =
							context.column_values_at(row.x, row.z)
						if (water_class ~= "land" and water_class ~= "planned_water") or
								zone_id ~= row.zone_id or terrain_y ~= row.y then
							fail("anchor column authority differs at " .. row.id)
						end
						-- A root on the owner's lower Y edge may have its support in the
						-- authenticated one-node halo. The settlement context deliberately
						-- exposes that halo read-only, so validate the real settled tuple
						-- instead of inventing an out-of-owner placeholder.
						local support_cid, support_param2, support_occupancy, support_opcode,
							support_feature, support_interface, support_aux =
								context.settled_at(row.x, row.y, row.z)
						local original_cid, original_param2 =
							context.original_support_at(row.x, row.y, row.z)
						local class_id, _, liquid_kind =
							production.r5.classify(original_cid, original_param2)
						local solid = class_id == 2 or class_id == 6 or class_id == 7 or
							class_id == 10 or class_id == 11
						local support_ok = original_cid ~= air_cid and
							original_cid ~= production.ignore_cid and
							liquid_kind == 0 and solid and support_cid == original_cid and
							support_param2 == original_param2 and support_occupancy == 0 and
							support_opcode == 0 and support_feature == 0 and
							support_interface == 0 and support_aux == 0
						if not support_ok then
							fail("anchor support differs at " .. row.id .. " original=" ..
								table.concat({original_cid, original_param2}, "/") ..
								" actual=" .. table.concat({support_cid,
									support_param2, support_occupancy, support_opcode,
									support_feature, support_interface, support_aux}, "/"))
						end
						local prior_cid, prior_param2, prior_occupancy, prior_opcode,
							prior_feature, prior_interface, prior_aux =
								context.settled_at(row.x, root_y, row.z)
						if prior_cid ~= air_cid or prior_param2 ~= 0 or
								prior_occupancy ~= 0 or prior_opcode ~= 0 or
								prior_feature ~= 0 or prior_interface ~= 0 or prior_aux ~= 0 then
							fail("anchor root is not empty at " .. row.id)
						end
						local cid, _, _, param2 = anchor_content.resolve_anchor(row.content_ref, 0)
						context.write_anchor(row.x, root_y, row.z, cid, param2,
							row.content_ref, row.numeric_id)
						ledger.operations[#ledger.operations + 1] = {id = row.id,
							numeric_id = row.numeric_id, family = row.family,
							content_ref = row.content_ref, x = row.x, y = root_y, z = row.z,
							support_y = row.y, prior_cid = prior_cid,
							prior_param2 = prior_param2, prior_occupancy = prior_occupancy,
							prior_opcode = prior_opcode, prior_feature = prior_feature,
							prior_interface = prior_interface, prior_aux = prior_aux,
							final_cid = cid, final_param2 = param2, final_occupancy = -2,
							final_opcode = 36, final_feature = row.numeric_id,
							final_interface = 0,
							final_aux = (95 + row.content_ref - 1) * 256 + param2}
						ledger.written = ledger.written + 1
					end
				end
			end
			if context.call_mode == "replay_fixture" then
				metrics.replay_calls = metrics.replay_calls + 1
			else
				metrics.settle_calls = metrics.settle_calls + 1
				metrics.written = metrics.written + ledger.written
			end
			return ledger
		end
		function tail.metrics(self)
			if not rawequal(self, tail) then fail("metrics receiver differs") end
			return {schema = "grug_wp40_r7_anchor_metrics_v1",
				plan_calls = metrics.plan_calls, settle_calls = metrics.settle_calls,
				replay_calls = metrics.replay_calls, written = metrics.written,
				roster_sha256 = roster.sha256}
		end
		function tail.roster(self)
			if not rawequal(self, tail) then fail("roster receiver differs") end
			return roster
		end
		return tail
	end
	return config
end
