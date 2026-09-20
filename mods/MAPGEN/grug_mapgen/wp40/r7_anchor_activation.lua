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
	local base = anchor_content.successor_base_ref
 if type(base) ~= "number" or base % 1 ~= 0 or base < 1 or base > 65535 then
  fail("anchor successor reference base differs")
 end
 local config = {schema = "grug_wp40_r7_anchor_config_v1"}
	function config.new(dependencies)
		if type(dependencies) ~= "table" or type(dependencies.source) ~= "table" or
				type(dependencies.zones_session) ~= "table" or
				type(dependencies.planner_source) ~= "table" or
				type(dependencies.raw_sha256) ~= "function" or
				type(dependencies.content) ~= "table" then
			fail("successor dependencies differ")
		end
		local roster = roster_factory(dependencies.source, dependencies.zones_session,
			dependencies.planner_source, dependencies.raw_sha256)
		local production = dependencies.content.content_contract()
		if dependencies.runtime_mode ~= nil and
				type(dependencies.runtime_mode) ~= "boolean" then
			fail("runtime mode differs")
		end
		local emit_ledger = not dependencies.runtime_mode
		local air_cid, air_kind, air_param2 = production.r5.resolve(1, 0, 0)
		if air_kind ~= 0 or air_param2 ~= 0 or air_cid == production.ignore_cid then
			fail("air authority differs")
		end
		local bound_plan, bound_generation, active = false, 0, false
		-- THE MAPCHUNK THIS TRANSACTION OWNS, which is not the same box as
		-- `context.inside_owner`. That one also answers true for the
		-- authenticated one-node halo around the chunk, and the halo belongs to
		-- a NEIGHBOURING chunk: its bytes are ours only if that chunk has
		-- already generated. See the support check in `settle`.
		local bound_min_y, bound_max_y = 0, -1
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
			bound_min_y, bound_max_y = minp.y, maxp.y
			metrics.plan_calls = metrics.plan_calls + 1
		end
		function tail.settle(self, context)
			if not rawequal(self, tail) or type(context) ~= "table" or
					not rawequal(context.plan, bound_plan) or
					context.generation ~= bound_generation then
				fail("settlement plan binding differs")
			end
			local ledger = {schema = "grug_wp40_r7_anchor_ledger_v1",
				roster_sha256 = roster.sha256, written = 0}
			if emit_ledger then ledger.operations = {} end
			local written = 0
			if active then
				for index = 1, #roster.rows do
					local row = roster.rows[index]
					local root_y = row.y + 1
					if context.inside_owner(row.x, root_y, row.z) then
						local water_class, _, zone_id, _, _, terrain_y, _, _, _,
							functional_kind, functional_y, functional_feature_id, _, _, _, _,
							_, _, _, hard_foundation =
							context.column_values_at(row.x, row.z)
						if (water_class ~= "land" and water_class ~= "planned_water") or
								zone_id ~= row.zone_id or terrain_y ~= row.y or
								functional_kind ~= row.functional_kind or
								functional_y ~= row.functional_y or
								functional_feature_id ~= row.functional_feature_id or
								hard_foundation ~= row.hard_foundation then
							fail("anchor column authority differs at " .. row.id)
						end
						-- THE SUPPORT, and why it is only asserted when we own it.
						--
						-- A root on the owner's lower Y edge has its support one node
						-- below, in the mapchunk BENEATH this one. `inside_owner` answers
						-- true there -- the settlement context exposes the authenticated
						-- one-node halo read-only -- but the halo carries OUR column only
						-- if that lower chunk has already generated. Which of the two
						-- generates first is the engine's emerge order, and a player who
						-- teleports in from above gets the upper one first.
						--
						-- That is the crash the user hit on seed 15912857179583385436,
						-- where Highcourt's anchor sits at y 47 with its root at 48, which
						-- is exactly a chunk's lowest layer (chunks span 80 nodes offset
						-- by -32). The check read air out of an ungenerated halo and
						-- failed the whole mapgen transaction. Both gate seeds put that
						-- anchor's root mid-chunk, which is why two seeds never saw it.
						--
						-- The COLUMN AUTHORITY above is the guarantee that survives emerge
						-- order: it has already verified this column's terrain height,
						-- functional kind, functional y, feature and foundation against
						-- the planner, and the chunk that owns the support writes its
						-- surface from that same plan whenever it generates. So the
						-- settled bytes are asserted where this transaction writes them
						-- and trusted from the plan where it does not.
						--
						-- The seven support values and the seven root values are
						-- declared HERE and not inside the two branches, because the
						-- diagnostic ledger below records them. Declared inside, the
						-- ledger's `support_*` and `prior_*` fields read fourteen
						-- globals that are always nil -- which is what
						-- `tools/wp40/r7/anchor_activation_kat.lua` catches at
						-- "operation differs at 1". Outside them, a row whose support
						-- or root this transaction does NOT own still records nil for
						-- those fields, which is the honest answer: it did not read
						-- them.
						local support_cid, support_param2, support_occupancy,
							support_opcode, support_feature, support_interface,
							support_aux
						local prior_cid, prior_param2, prior_occupancy, prior_opcode,
							prior_feature, prior_interface, prior_aux
						local support_owned = row.y >= bound_min_y and row.y <= bound_max_y
						if support_owned then
							support_cid, support_param2, support_occupancy,
								support_opcode, support_feature, support_interface,
								support_aux = context.settled_at(row.x, row.y, row.z)
							local class_id, _, liquid_kind =
								production.r5.classify(support_cid, support_param2)
							local solid = class_id == 2 or class_id == 6 or class_id == 7 or
								class_id == 10 or class_id == 11
							-- WHAT AN ANCHOR MAY STAND ON.
							--
							-- `occupancy`, `feature` and `interface` are the CLAIM fields:
							-- something else owns this cell, and an anchor may not stand on
							-- it. They stay zero.
							--
							-- `opcode` and `aux` are not a claim. They say which operation
							-- produced the node and out of which material. Zero -- nothing
							-- wrote the cell, the ground came straight out of the engine's
							-- own mapgen -- was the only value the six capitals ever showed,
							-- because until playtest round 4 a WP40 ROUTE ran across every
							-- capital anchor and suppressed R6's surface pass there. With
							-- the routes ruled back to the gates the same columns are
							-- ordinary ground again, and R6 writes them as what they are:
							-- opcode 4, a biome TOP, carrying its material in `aux`
							-- (measured at anchor_007 and anchor_009, seed
							-- 531802985935182545: 393/0/0/4/0/0/19456 where the route-era
							-- value was 0/0/0/0/0/0/0).
							--
							-- 3 (shore) and 4 (top) are R6's own two SURFACE opcodes, and
							-- they are already this tree's spelling of "this cell is ground
							-- a thing may stand on": `r6_settlement.lua`'s cultural
							-- placement refuses any root whose support is not one of those
							-- two (`wrong_support`). An anchor is held to the same rule,
							-- plus the untouched case its POI and bandit rows still show.
							-- Every other opcode -- a decoration, a bridge deck, a path
							-- surface, a foundation -- stays refused.
							local natural_support = support_opcode == 0 or
								support_opcode == 3 or support_opcode == 4
							local support_ok = support_cid ~= air_cid and
								support_cid ~= production.ignore_cid and liquid_kind == 0 and
								solid and support_occupancy == 0 and
								natural_support and support_feature == 0 and
								support_interface == 0 and
								(support_opcode ~= 0 or support_aux == 0)
							if not support_ok then
								fail("anchor settled support differs at " .. row.id ..
									" actual=" .. table.concat({support_cid,
										support_param2, support_occupancy, support_opcode,
										support_feature, support_interface, support_aux}, "/"))
							end
						end
						-- The root cell itself, under the same rule: a root that lies in
						-- the halo rather than in this chunk is the neighbouring chunk's
						-- to clear, and reading it here would depend on emerge order the
						-- same way.
						if root_y >= bound_min_y and root_y <= bound_max_y then
							prior_cid, prior_param2, prior_occupancy, prior_opcode,
								prior_feature, prior_interface, prior_aux =
									context.settled_at(row.x, root_y, row.z)
							if prior_cid ~= air_cid or prior_param2 ~= 0 or
									prior_occupancy ~= 0 or prior_opcode ~= 0 or
									prior_feature ~= 0 or prior_interface ~= 0 or
									prior_aux ~= 0 then
								fail("anchor root is not empty at " .. row.id)
							end
						end
						local cid, _, _, param2 = anchor_content.resolve_anchor(row.content_ref, 0)
						context.write_anchor(row.x, root_y, row.z, cid, param2,
							row.content_ref, row.numeric_id)
						if emit_ledger then
							ledger.operations[#ledger.operations + 1] = {id = row.id,
								numeric_id = row.numeric_id, family = row.family,
								content_ref = row.content_ref, x = row.x, y = root_y, z = row.z,
								support_y = row.y, support_cid = support_cid,
								support_param2 = support_param2,
								support_occupancy = support_occupancy,
								support_opcode = support_opcode,
								support_feature = support_feature,
								support_interface = support_interface,
								support_aux = support_aux, prior_cid = prior_cid,
								prior_param2 = prior_param2, prior_occupancy = prior_occupancy,
								prior_opcode = prior_opcode, prior_feature = prior_feature,
								prior_interface = prior_interface, prior_aux = prior_aux,
								final_cid = cid, final_param2 = param2, final_occupancy = -2,
								final_opcode = 36, final_feature = row.numeric_id,
								final_interface = 0,
								final_aux = (base + row.content_ref - 1) * 256 + param2}
						end
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
			ledger.written = written
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
