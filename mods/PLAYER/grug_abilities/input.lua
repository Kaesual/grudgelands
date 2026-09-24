-- Contextual controls over native digging and the existing combat transactions.
-- One state per player, no world scanning, dig simulation or inventory swapping.
return function(api)
	local Q, states = grug_abilities, {}
	local HAND_RANGE, HOLD_US, FOOD_US = 4, 200000, 1500000
	local pickup_delegate
	local function same(a, b)
		return a and b and a.x == b.x and a.y == b.y and a.z == b.z
	end
	local function allowed(player)
		return player:get_hp() > 0 and core.check_player_privs(player, {interact = true}) and
			not grug_core.is_stunned(player) and
			not grug_core.player_has_live_mount(player) and
			not (grug_core.player_in_creation_stasis and
				grug_core.player_in_creation_stasis(player:get_player_name()))
	end
	local function selected(player)
		local def = api.selected(player)
		return def and Q.is_unlocked(player, def.id) and def or nil
	end
	local function ray(player, range)
		local origin = grug_core.combat_eye_pos(player)
		local destination = vector.add(origin, vector.multiply(player:get_look_dir(), range))
		local best, distance
		for hit in core.raycast(origin, destination, true, false) do
			if hit.type ~= "object" or hit.ref ~= player then
				local d = hit.intersection_point and vector.distance(origin, hit.intersection_point)
				if d and (not distance or d < distance or
						(d == distance and hit.type == "node")) then
					best, distance = hit, d
				end
			end
		end
		return best, distance
	end
	local function state(player)
		local name = player:get_player_name()
		local s = states[name]
		if not s then s = {}; states[name] = s end
		return s
	end
	local function cancel(player, s)
		s.pending, s.dig, s.right = nil, nil, nil
		s.cancelled = true
		if Q.cancel_bow_draw then Q.cancel_bow_draw(player) end
	end
	local function hand_node(player, hit, distance)
		if not hit or hit.type ~= "node" or distance > HAND_RANGE then return false end
		local node = core.get_node_or_nil(hit.under)
		local def = node and core.registered_nodes[node.name]
		if not def or def.diggable == false or
				core.is_protected(hit.under, player:get_player_name()) then return false end
		local caps = ItemStack(""):get_tool_capabilities()
		return core.get_dig_params(def.groups or {}, caps).diggable == true
	end
	local function support(def)
		return def and (def.target_kind == "self" or def.target_kind == "friendly")
	end
	local function usable(player, def, s)
		return def and def.id ~= "loose" and
			(def.repeat_policy ~= "once" or not s.used) and api.can_cast(player, def)
	end
	local function cast(player, def, s, hit)
		if not usable(player, def, s) then return false end
		if Q.try_cast(player, def, hit, true) then
			if def.repeat_policy == "once" then s.used = true end
			api.delay_strike(player)
			return true
		end
		return false
	end
	local function interactive(hit, distance)
		if not hit or distance > HAND_RANGE then return false end
		if hit.type == "object" then
			local ent = hit.ref and hit.ref:get_luaentity()
			return ent and type(ent.on_rightclick) == "function"
		end
		local node = core.get_node_or_nil(hit.under)
		local def = node and core.registered_nodes[node.name]
		return def and (type(def.on_rightclick) == "function" or
			core.get_meta(hit.under):get_string("formspec") ~= "")
	end
	local function right_begin(player, s, def, hit, distance)
		s.pending, s.dig = nil, nil
		if interactive(hit, distance) then
			s.right = "interaction"
		elseif def and def.id == "loose" then
			s.right = "bow"
			Q.start_bow_draw(player)
		elseif core.get_item_group(player:get_wielded_item():get_name(), "grug_food") > 0 then
			s.right, s.right_started = "food", core.get_us_time()
		else
			s.right = "other"
		end
	end
	local function activate(player, s, def, hit, distance, fresh)
		local now = core.get_us_time()
		if fresh and hit and hit.type == "object" and distance <= HAND_RANGE then
			local ent = hit.ref and hit.ref:get_luaentity()
			if ent and ent.name == "__builtin:item" then
				-- The initial decision owns exactly one pickup attempt, including
				-- a full inventory; ordinary native repeats may not consume another.
				if pickup_delegate then pickup_delegate(ent, player) end
				return
			end
		end
		if s.pending then
			if hit and hit.type == "node" and same(hit.under, s.pending.pos) and
					core.get_node_or_nil(hit.under) and core.get_node_or_nil(hit.under).name == s.pending.node then
				if now - s.pending.started < HOLD_US then return end
				s.pending = nil -- Native digging has accumulated since the press.
			else
				s.pending, s.dig = nil, nil
			end
		end
		if hit and hit.type == "object" then
			s.dig = nil
			if Q.valid_target(player, hit.ref, "friendly") then
				if support(def) and not def.offensive then cast(player, def, s, hit) end
				return
			end
			if Q.valid_target(player, hit.ref, "hostile") then
				if def.kind == "swing" then
					local chosen = api.swing_ready(player, def) and def or Q.registered.strike
					api.swing(player, chosen)
				elseif not cast(player, def, s, hit) then
					api.swing(player, Q.registered.strike)
				end
				return
			end
			-- Actors block action on anything behind them, including drops after
			-- this press's initial pickup attempt and non-healable service NPCs.
			return
		end
		if hand_node(player, hit, distance) then
			if not s.dig or not same(s.dig.pos, hit.under) then
				s.dig = {pos = vector.copy(hit.under), started = now}
			end
			if fresh and support(def) and usable(player, def, s) then
				s.pending = {pos = vector.copy(hit.under), started = now, id = def.id,
					node = core.get_node_or_nil(hit.under).name}
			end
			return
		end
		s.dig = nil
		if not s.empty_used and support(def) then
			s.empty_used = true
			cast(player, def, s, nil)
		end
	end
	local M = {}
	function M.step(player, press)
		local s, controls = state(player), player:get_player_control()
		local down, right = controls.dig == true or press == true, controls.place == true
		local item, slot = player:get_wielded_item():get_name(), player:get_wield_index()
		local def = selected(player)
		if not allowed(player) or (s.slot and (s.slot ~= slot or s.item ~= item)) then
			cancel(player, s)
		end
		s.slot, s.item = slot, item
		if not down and not right and s.cancelled then
			s.cancelled, s.down, s.rmb = nil, false, false
			return
		end
		if s.cancelled then s.down, s.rmb = down, right; return end
		if not down and not right and not s.pending then
			s.down, s.rmb, s.right, s.dig = false, false, nil, nil
			return
		end
		local food_selected = core.get_item_group(item, "grug_food") > 0
		if not def and not food_selected then
			s.down, s.rmb = down, right
			return
		end
		local hit, distance = ray(player, math.max(HAND_RANGE, def and Q.get_range(player, def) or 0))
		if right and not s.rmb then right_begin(player, s, def, hit, distance) end
		if right and s.right == "food" and core.get_us_time() - s.right_started >= FOOD_US then
			s.right = "food_done"
			local food = rawget(_G, "grug_food")
			if food then food.consume_held(player) end
		end
		if right then
			s.pending, s.dig, s.down, s.rmb = nil, nil, down, true
			return
		end
		if s.rmb then
			-- Bow release is settled by the existing Scout draw loop. Native
			-- inventory/pause/GUI releases are indistinguishable and accepted.
			s.right, s.rmb, s.down = nil, false, down
			return -- Scout settles the release before another weapon action.
		end
		if down and not s.down then
			s.used, s.empty_used = false, false
			if def then activate(player, s, def, hit, distance, true) end
		elseif down and def then
			activate(player, s, def, hit, distance, false)
		elseif not down then
			local pending = s.pending
			s.pending, s.dig = nil, nil
			if pending and def and pending.id == def.id and hit and hit.type == "node" and
					same(hit.under, pending.pos) and core.get_node_or_nil(hit.under) and
					core.get_node_or_nil(hit.under).name == pending.node and
					core.get_us_time() - pending.started < HOLD_US then
				cast(player, def, s, hit)
			end
		end
		s.down = down
	end
	function M.press(player) M.step(player, true) end
	function M.right_action(player)
		M.step(player)
		return state(player).right
	end
	function M.cancel(player) cancel(player, state(player)) end
	function M.interaction(player)
		local s = state(player)
		s.pending, s.dig, s.right, s.rmb = nil, nil, "interaction", true
		if Q.cancel_bow_draw then Q.cancel_bow_draw(player) end
	end
	function M.can_dig(player, pos, node)
		local s = state(player)
		if not api.selected(player) then
			local eating = core.get_item_group(player:get_wielded_item():get_name(), "grug_food") > 0
			return not (eating and player:get_player_control().place and s.right)
		end
		if not selected(player) or not allowed(player) or s.cancelled or
				not player:get_player_control().dig or player:get_player_control().place or
				s.right or not api.within_hand_reach(player, pos) then
			return false
		end
		local hit, distance = ray(player, HAND_RANGE)
		if not hit or hit.type ~= "node" or not same(pos, hit.under) or
				not hand_node(player, hit, distance) then return false end
		if s.pending and core.get_us_time() - s.pending.started < HOLD_US then return false end
		return true -- Native digging already owns time, drops and node callbacks.
	end
	core.register_on_mods_loaded(function()
		local hand = ItemStack(""):get_tool_capabilities()
		hand.groupcaps = hand.groupcaps or {}
		hand.groupcaps.dig_immediate = {times = {[2] = 0.3, [3] = 0.3}, uses = 0, maxlevel = 0}
		core.override_item("", {tool_capabilities = hand})
		for name, definition in pairs(core.registered_nodes) do
			local original_dig, original_punch = definition.on_dig, definition.on_punch
			local changes = {}
			if (definition.groups or {}).dig_immediate == 3 then
				changes.groups = table.copy(definition.groups)
				changes.groups.dig_immediate = 2 -- Also positive for ordinary tools.
			end
			if original_dig then
				changes.on_dig = function(pos, node, player)
					if player and player:is_player() and not M.can_dig(player, pos, node) then return end
					return original_dig(pos, node, player)
				end
			end
			if original_punch then
				changes.on_punch = function(pos, node, player, pointed)
					if player and player:is_player() and api.selected(player) then M.press(player) end
					return original_punch(pos, node, player, pointed)
				end
			end
			if next(changes) then core.override_item(name, changes) end
		end
		local item = core.registered_entities["__builtin:item"]
		pickup_delegate = item.on_punch
		item.on_punch = function(entity, player, ...)
			if player and player:is_player() and api.selected(player) then
				M.press(player)
				return
			end
			return pickup_delegate(entity, player, ...)
		end
	end)
	grug_core.register_on_stun(M.cancel)
	core.register_on_dieplayer(M.cancel)
	core.register_on_leaveplayer(function(player) states[player:get_player_name()] = nil end)
	return M
end
