-- Contextual controls over native digging and the existing combat transactions.
-- One state per player, no world scanning, dig simulation or inventory swapping.
return function(api)
	local Q, states = grug_abilities, {}
	local HAND_RANGE, HOLD_US, FOOD_US = 4, 200000, 1500000
	-- Held food time accrues per observed step, at most this much per step, so
	-- a server stall cannot turn a click into a hold.
	local MAX_HELD_STEP_US = 100000
	-- A skill failure message shows on a fresh press only and the same
	-- message at most once per NOTICE_US (Round 28 ruling 13).
	local NOTICE_US = 1000000
	-- A held retry of a cast that failed inside try_cast (Charge without room)
	-- waits this long: every try resets the swing boundary, which would keep
	-- the held Strike fallback from accumulating.
	local RETRY_US = 250000
	-- An LMB mode outlives a release seen this soon after it was decided: a
	-- native punch reports the press before the next control report (up to
	-- one dedicated_server_step later) does.
	local MODE_GRACE_US = 150000
	local pickup_delegate
	local entity_rightclick = {} -- entity name -> unwrapped on_rightclick
	local function food_api() return rawget(_G, "grug_food") end
	local function is_food(item_name)
		local food = food_api()
		return food ~= nil and food.is_food ~= nil and food.is_food(item_name)
	end
	-- Eating progress ring (crosshair.lua, owner "food"): shown from the
	-- confirmed hold, filled by held time / FOOD_US, hidden with the visual.
	local function food_ring(player, fraction)
		if Q.crosshair then Q.crosshair.set_ring(player, fraction, "food") end
	end
	-- Every eating end path (release, portion eaten, cancel, stun, death, item
	-- or slot change) runs through here.
	local function end_food_hold(player)
		food_ring(player, nil)
		local food = food_api()
		if food and food.end_hold then food.end_hold(player) end
	end
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
	local function ray(player, range, origin)
		origin = origin or grug_core.combat_eye_pos(player)
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
	-- Zero pointing range on the held skill stack (tool.cpp getToolRange
	-- reads meta "range"): the client then points at nothing, so it neither
	-- digs, cracks nor punches. Owners ("combat": an LMB combat hold, "bow":
	-- a Loose draw) share the one meta key; the stack points again once the
	-- last owner lets go. Written with set_wielded_item(stack, true): sent at
	-- once and without the wield-change animation a meta change would play.
	local ranges = {} -- player name -> {owners = {}, list, index, item}
	local function write_range(player, r, value)
		local inv = player:get_inventory()
		local stack = inv and inv:get_stack(r.list, r.index)
		if not stack or stack:get_name() ~= r.item then return end
		local meta = stack:get_meta()
		if meta:get_string("range") == value then return end
		meta:set_string("range", value)
		if player:get_wield_list() == r.list and player:get_wield_index() == r.index then
			player:set_wielded_item(stack, true)
		else
			inv:set_stack(r.list, r.index, stack)
		end
	end
	local function hold_range(player, owner, on)
		local name = player:get_player_name()
		local r = ranges[name]
		if on then
			local list, index = player:get_wield_list(), player:get_wield_index()
			local item = player:get_wielded_item():get_name()
			if r and (r.list ~= list or r.index ~= index or r.item ~= item) then
				write_range(player, r, "") -- another stack: let the old one go
				r = nil
			end
			r = r or {owners = {}, list = list, index = index, item = item}
			ranges[name] = r
			r.owners[owner] = true
			write_range(player, r, "0")
		elseif r and r.owners[owner] then
			r.owners[owner] = nil
			if next(r.owners) == nil then
				ranges[name] = nil
				write_range(player, r, "")
			end
		end
	end
	local function end_mode(player, s)
		if s.mode == "combat" then hold_range(player, "combat", false) end
		s.mode, s.mode_at, s.foe = nil, nil, nil
	end
	-- Drop every pending action of the previous item or press.
	local function reset(player, s)
		end_food_hold(player)
		end_mode(player, s)
		s.pending, s.dig, s.right, s.food = nil, nil, nil, nil
		if Q.cancel_bow_draw then Q.cancel_bow_draw(player) end
	end
	-- ... and latch the cancellation until both buttons are released.
	local function cancel(player, s)
		reset(player, s)
		s.cancelled = true
	end
	local function report(player, s, message)
		if not message then return end
		local now = core.get_us_time()
		s.notices = s.notices or {}
		local last = s.notices[message]
		if last and now - last < NOTICE_US then return end
		s.notices[message] = now
		Q.flash(player, message)
	end
	local function new_food_press(now)
		return {started = now, observed = now, held = 0, stage = "press"}
	end
	-- A node within hand reach that bare hands can dig, protection aside.
	local function hand_diggable(hit, distance)
		if not hit or hit.type ~= "node" or distance > HAND_RANGE then return false end
		local node = core.get_node_or_nil(hit.under)
		local def = node and core.registered_nodes[node.name]
		if not def or def.diggable == false then return false end
		local caps = ItemStack(""):get_tool_capabilities()
		return core.get_dig_params(def.groups or {}, caps).diggable == true
	end
	local function hand_node(player, hit, distance)
		return hand_diggable(hit, distance) and
			not core.is_protected(hit.under, player:get_player_name())
	end
	local function support(def)
		return def and (def.target_kind == "self" or def.target_kind == "friendly")
	end
	-- Can this press still try a cast of def (Loose casts by RMB only)?
	local function castable(def, s)
		return def and def.id ~= "loose" and def.kind == "cast" and
			(def.repeat_policy ~= "once" or not s.used)
	end
	local function silent() end
	-- `fresh`: this attempt is the press's own decision (key-down, its
	-- single empty-space or tap cast), so a refusal is reported; held
	-- repeats stay silent.
	local function cast(player, def, s, hit, fresh)
		if not castable(def, s) then return false end
		local refusal = api.cast_refusal(player, def)
		if refusal then
			if fresh then report(player, s, refusal) end
			return false
		end
		local now = core.get_us_time()
		s.failed = s.failed or {}
		local failed = s.failed[def.id]
		if not fresh and failed and now - failed < RETRY_US then return false end
		local notify = fresh and function(message) report(player, s, message) end or silent
		if Q.try_cast(player, def, hit, notify) then
			s.failed[def.id] = nil
			if def.repeat_policy == "once" then s.used = true end
			s.cast_press = true -- this physical press cast (see M.cast_this_press)
			api.delay_strike(player)
			return true
		end
		s.failed[def.id] = now
		return false
	end
	-- The LMB hold (Round 28 ruling 14, Round 32 §2.4) is one state machine:
	-- "gather" or "combat" locked on a foe (`s.foe`, the last valid hostile
	-- the hold aimed at). Every hold starts as gather; at key-down a valid
	-- hostile the combat ray finds (plants and dropped loot never hide a mob)
	-- within max(hand reach, skill range) makes it combat at once. Later in
	-- the hold only a threat does -- a PvP-harmable player, an aggressive mob
	-- or one fighting this player, never a passing neutral mob -- and only
	-- while the selected skill attacks hostiles (a self or support skill
	-- never fires because a mob walked into the crosshair). Combat returns to
	-- gather once its foe is gone: dead, despawned or unloaded, no longer a
	-- valid target (a PvP flag dropped, evading home), or farther than
	-- FLEE_REACH times the reach (a foe briefly stepping out of reach keeps
	-- the lock). Combat never digs (zero pointing range, can_dig
	-- refuses); gather never attacks.
	local FLEE_REACH = 2
	local function combat_reach(player, def)
		-- Loose's LMB is Strike or hand digging; its bow range is RMB's.
		if def.id == "loose" then return HAND_RANGE end
		return math.max(HAND_RANGE, Q.get_range(player, def))
	end
	-- A hostile this hold may fight: what combat accepts (Q.valid_target:
	-- alive, loaded, hostile, PvP-harmable), range aside, and not a mob that
	-- is evading home after a leash reset (it takes no damage).
	local function fightable(player, ref)
		if not Q.valid_target(player, ref, "hostile") then return false end
		local ent = ref:get_luaentity()
		return not (ent and ent.temp and ent.temp.grug_evading)
	end
	local function threatens(player, ref)
		if ref:is_player() then return true end -- valid_target asked grug_pvp.can_harm
		local ent = ref:get_luaentity()
		return ent ~= nil and (ent.attack == player or grug_mobs.disposition(ent) == "aggressive")
	end
	-- The valid hostile the crosshair finds within `reach` (only a threat
	-- unless `any`), or nil. `hit` is the step's hand ray, which reaches at
	-- least as far: a walkable node first (or nothing) hides every actor, so
	-- the combat ray runs only behind plants, loot and actors.
	local function hostile_ahead(player, reach, hit, any)
		if not hit then return nil end
		if hit.type == "node" then
			local node = core.get_node_or_nil(hit.under)
			local ndef = node and core.registered_nodes[node.name]
			if ndef and ndef.walkable then return nil end
		end
		local r = grug_core.combat_ray(player, reach)
		local target = r.status == "target" and fightable(player, r.target) and r.target
		return target and (any or threatens(player, target)) and target or nil
	end
	-- Dead, despawned or unloaded, no longer fightable (a PvP flag dropped,
	-- evading), or fled beyond FLEE_REACH times the reach.
	local function foe_gone(player, foe, reach)
		if not fightable(player, foe) then return true end
		local pos, own = foe:get_pos(), player:get_pos()
		local dx, dy, dz = pos.x - own.x, pos.y - own.y, pos.z - own.z
		local far = FLEE_REACH * reach
		return dx * dx + dy * dy + dz * dz > far * far
	end
	-- What a combat hold acts on: the combat ray's first actor, else nothing.
	-- A valid hostile there becomes the hold's foe.
	local function combat_hit(player, reach, s)
		local r = grug_core.combat_ray(player, reach)
		if not r.target or r.reason == "out_of_range" then return nil end
		if r.status == "target" and fightable(player, r.target) then
			s.foe = r.target
		end
		return {type = "object", ref = r.target,
			intersection_point = r.pointed and r.pointed.intersection_point}, r.distance or 0
	end
	local function interactive(hit, distance)
		if not hit or distance > HAND_RANGE then return false end
		if hit.type == "object" then
			local ent = hit.ref and hit.ref:get_luaentity()
			return ent and type(ent.on_rightclick) == "function"
		end
		-- No node keeps its UI in metadata (default/node_formspec.lua): every
		-- interactive node answers on_rightclick.
		local node = core.get_node_or_nil(hit.under)
		local def = node and core.registered_nodes[node.name]
		return def ~= nil and type(def.on_rightclick) == "function"
	end
	local function right_begin(player, s, def, hit, distance)
		s.pending, s.dig = nil, nil
		if not def and is_food(player:get_wielded_item():get_name()) then
			-- Food owns the whole press, interactive target or not (user ruling
			-- 2026-09-28): a release before HOLD_US is a click, performed on
			-- release at the target the press's first native call reported; a
			-- longer hold eats and the pointed interaction never fires.
			s.right, s.food = "food", new_food_press(core.get_us_time())
		elseif interactive(hit, distance) then
			s.right = "interaction"
		elseif def and def.id == "loose" then
			s.right = "bow"
			local ok, err = Q.start_bow_draw(player)
			if not ok then report(player, s, err) end
		else
			s.right = "other"
		end
	end
	-- Held food: "press" becomes "eating" (or "refused" in combat) at HOLD_US;
	-- one portion is due FOOD_US after the press (held time, see above).
	local function food_hold(player, s)
		local f, food = s.food, food_api()
		if not f or not food then return end
		local now = core.get_us_time()
		f.held = f.held + math.min(now - f.observed, MAX_HELD_STEP_US)
		f.observed = now
		local elapsed = f.held
		if f.stage == "press" and elapsed >= HOLD_US then
			f.stage = food.begin_hold(player) and "eating" or "refused"
		end
		if f.stage ~= "eating" then return end
		if elapsed >= FOOD_US then
			f.stage = "done"
			food.consume_held(player)
			end_food_hold(player)
		else
			food.step_hold(player)
			food_ring(player, elapsed / FOOD_US)
		end
	end
	-- The unwrapped entity callback, for a click replayed on release. An
	-- instance-level callback was never deferred, so it is never replayed.
	local function native_rightclick(entity, clicker)
		local original = entity_rightclick[entity.name]
		if original and rawget(entity, "on_rightclick") == nil then
			return original(entity, clicker)
		end
	end
	-- RMB release: ends every RMB-owned feedback; a food press released
	-- before the hold threshold performs its click now.
	local function release_right(player, s)
		local f = s.right == "food" and s.food or nil
		end_food_hold(player)
		s.right, s.food = nil, nil
		local food = food_api()
		if f and f.stage == "press" and f.target and food and food.click then
			food.click(player, f.target, native_rightclick)
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
				if support(def) and not def.offensive then cast(player, def, s, hit, fresh) end
				return
			end
			if Q.valid_target(player, hit.ref, "hostile") then
				-- Gather never attacks (a passing neutral mob is not pulled); a
				-- hostile that should be fought has made the hold combat.
				if s.mode == "gather" then return end
				if def.kind == "swing" then
					local refusal = api.swing_refusal(player, def)
					if refusal and fresh then report(player, s, refusal) end
					api.swing(player, refusal and Q.registered.strike or def)
				elseif not cast(player, def, s, hit, fresh) then
					api.swing(player, Q.registered.strike)
				end
				return
			end
			-- An ally the PvP flag forbids: the cast refuses (and reports) at
			-- no cost, never healing the caster instead (Round 31 ruling 9).
			if Q.support_refused(player, hit.ref) then
				if def.target_kind == "friendly" then cast(player, def, s, hit, fresh) end
				return
			end
			-- Actors block action on anything behind them, including drops after
			-- this press's initial pickup attempt and non-healable service NPCs.
			return
		end
		if s.mode ~= "combat" and hand_node(player, hit, distance) then
			if not s.dig or not same(s.dig.pos, hit.under) then
				s.dig = {pos = vector.copy(hit.under), started = now}
			end
			-- Readiness is checked at the tap, which reports a refusal.
			if fresh and support(def) and castable(def, s) then
				s.pending = {pos = vector.copy(hit.under), started = now, id = def.id,
					node = core.get_node_or_nil(hit.under).name}
			end
			return
		end
		s.dig = nil
		if s.mode == "gather" and hit and hit.type == "node" and distance <= HAND_RANGE and
				core.is_protected(hit.under, player:get_player_name()) then
			-- A gather press on a node the hand may not dig (protected town
			-- ground): a short tap still casts a self/support skill (Blink in a
			-- town); holding only earns the protection hint.
			if fresh and support(def) and castable(def, s) then
				s.pending = {pos = vector.copy(hit.under), started = now, id = def.id,
					node = core.get_node_or_nil(hit.under).name}
			end
			return
		end
		-- Nothing to act on (air, out of reach, a node bare hands cannot dig):
		-- one self/support activation per press, at key-down or in combat.
		if (fresh or s.mode == "combat") and not s.empty_used and support(def) then
			s.empty_used = true
			cast(player, def, s, nil, true)
		end
	end
	local M = {}
	local stepping = {} -- player name -> true while that player's step runs
	local function step(player, press)
		local s, controls = state(player), player:get_player_control()
		local down, right = controls.dig == true or press == true, controls.place == true
		-- LMB released: the hold's mode ends (after the grace, see MODE_GRACE_US).
		if not down and s.mode and core.get_us_time() - s.mode_at >= MODE_GRACE_US then
			end_mode(player, s)
		end
		local item, slot = player:get_wielded_item():get_name(), player:get_wield_index()
		local def = selected(player)
		-- One native RMB action per physical press (see M.food_native).
		if not right then s.native_seen = nil end
		local changed = s.slot and (s.slot ~= slot or s.item ~= item)
		-- A press the previous step already saw, carried over into a new item.
		local carried = (right and s.rmb) or (down and s.down)
		if not allowed(player) or (changed and carried) then
			cancel(player, s)
			-- A carried-over press is not a new press: the engine's repeated
			-- place must not act for the new item either.
			if changed and right and s.rmb then s.native_seen = true end
		elseif changed then
			-- Switch and a fresh press in the same step (or no press): settle
			-- the old item without latching, so the new press begins normally.
			reset(player, s)
		end
		s.slot, s.item = slot, item
		if not down and not right and s.cancelled then
			s.cancelled, s.down, s.rmb = nil, false, false
			return
		end
		if s.cancelled then s.down, s.rmb = down, right; return end
		if not down and not right and not s.pending then
			release_right(player, s)
			s.down, s.rmb, s.dig = false, false, nil
			return
		end
		if not def and not is_food(item) then
			s.down, s.rmb = down, right
			return
		end
		-- Food decides from the native pointed thing, never from this ray. A
		-- held combat press acts on the combat ray alone (below).
		local hit, distance
		if def and not (s.mode == "combat" and down and not right) then
			hit, distance = ray(player, math.max(HAND_RANGE, Q.get_range(player, def)))
		end
		if right and not s.rmb then right_begin(player, s, def, hit, distance) end
		if right and s.right == "food" then food_hold(player, s) end
		if right then
			s.pending, s.dig, s.down, s.rmb = nil, nil, down, true
			return
		end
		if s.rmb then
			-- Bow release is settled by the existing Scout draw loop. Native
			-- inventory/pause/GUI releases are indistinguishable and accepted.
			release_right(player, s)
			s.rmb, s.down = false, down
			return -- Scout settles the release before another weapon action.
		end
		if down and def then
			local reach = combat_reach(player, def)
			-- Key-down (or a press first seen after an RMB action) starts as gather.
			local starting = not s.mode
			if starting then s.mode, s.mode_at = "gather", core.get_us_time() end
			if s.mode == "gather" and (starting or def.target_kind == "hostile") then
				local foe = hostile_ahead(player, reach, hit, starting)
				if foe then
					s.mode, s.foe, s.pending, s.dig = "combat", foe, nil, nil
					-- A switch mid-hold never brings an empty-space self cast along.
					if not starting then s.empty_used = true end
					hold_range(player, "combat", true)
				end
			end
			if s.mode == "combat" then
				hit, distance = combat_hit(player, reach, s)
				if foe_gone(player, s.foe, reach) then
					-- No hostile in sight (combat_hit keeps the foe current) and the
					-- last one is gone: gather again.
					hold_range(player, "combat", false)
					s.mode, s.foe = "gather", nil
					hit, distance = ray(player, math.max(HAND_RANGE, Q.get_range(player, def)))
				end
			end
		end
		if down and not s.down then
			s.used, s.empty_used, s.cast_press = false, false, false
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
				cast(player, def, s, hit, true)
			end
		end
		s.down = down
	end
	-- One decision per player at a time. A skill's own synchronous effects
	-- (its damage punch reaching a native-input seam, a callback it triggers)
	-- belong to the decision already running; evaluating them as a new press
	-- would cast again before the outer cast has paid its cost or armed its
	-- cooldown. The guard is cleared even when a nested callback raises; the
	-- rethrown message keeps the inner traceback.
	function M.step(player, press)
		local name = player:get_player_name()
		if stepping[name] then return end
		stepping[name] = true
		local ok, err = xpcall(function() return step(player, press) end,
			debug.traceback)
		stepping[name] = nil
		if not ok then error(err, 0) end
	end
	function M.press(player) M.step(player, true) end
	-- Did the current (or last) LMB press cast a skill? The mining hint skips
	-- its protection line on a punch whose press already cast (Round 24).
	function M.cast_this_press(player)
		local s = player and player.get_player_name and
			states[player:get_player_name()]
		return s ~= nil and s.cast_press == true
	end
	function M.right_action(player)
		M.step(player)
		return state(player).right
	end
	function M.cancel(player) cancel(player, state(player)) end
	-- The bow draw (scout.lua) is the other owner of the zero pointing range.
	function M.hold_range(player, owner, on) hold_range(player, owner, on) end
	-- Crosshair feedback (crosshair.lua): is the first thing within hand reach
	-- something a press would interact with? The same ray and classification
	-- an RMB press uses, plus a dropped item (the LMB pickup of `activate`).
	-- `origin` is the caller's combat eye position (optional). The second
	-- result is true when that first thing is a walkable node: then no object
	-- lies in front of it, so every combat ray (grug_core.combat_ray) along the
	-- same line ends at that node or earlier with no target. Reads only; no
	-- press state is touched.
	function M.aims_at_interactive(player, origin)
		local hit, distance = ray(player, HAND_RANGE, origin)
		if not hit or distance > HAND_RANGE then return false, false end
		if hit.type == "object" then
			local ent = hit.ref and hit.ref:get_luaentity()
			if ent and ent.name == "__builtin:item" then return true, false end
			return interactive(hit, distance) and true or false, false
		end
		local node = core.get_node_or_nil(hit.under)
		local def = node and core.registered_nodes[node.name]
		return interactive(hit, distance) and true or false,
			def ~= nil and def.walkable and true or false
	end
	function M.interaction(player)
		local s = state(player)
		end_food_hold(player)
		s.pending, s.dig, s.right, s.food, s.rmb = nil, nil, "interaction", nil, true
		if Q.cancel_bow_draw then Q.cancel_bow_draw(player) end
	end
	-- A food item's native on_place/on_secondary_use (press and the engine's
	-- repeat_place_time repeats). True: contextual input owns the press and
	-- the native action must not run now -- the first call of a food press
	-- records its pointed thing for a click on release. False: the press is not
	-- food-owned (mounted, stunned ...), so its first native call acts as an
	-- ordinary right-click immediately; later repeats of that press never do.
	function M.food_native(player, pointed)
		M.step(player)
		local s = state(player)
		if s.right == "food" and s.food then
			-- The client sends object and empty-air calls on the press edge only
			-- (game.cpp:3249, :2923), so a second one during an owned press is a
			-- new press whose release fell between two control snapshots: settle
			-- the old press (its click, if still undecided) and start the new
			-- one. Node calls also repeat every repeat_place_time (0.16 s at the
			-- client minimum) and packet timing cannot tell a repeat from a new
			-- press, so node calls never start one. Known limitation: a
			-- missed-release double click at a node loses at most one click or
			-- aborts one eat; it never acts twice.
			if s.food.target_set and (not pointed or pointed.type ~= "node") then
				release_right(player, s)
				s.right, s.food = "food", new_food_press(core.get_us_time())
			end
			if not s.food.target_set then
				s.food.target_set = true
				s.food.target = pointed and {type = pointed.type,
					under = pointed.under and vector.copy(pointed.under),
					above = pointed.above and vector.copy(pointed.above),
					ref = pointed.ref}
			end
			s.native_seen = true
			return true
		end
		if s.native_seen then return true end
		s.native_seen = true
		return false
	end
	-- Entity right-clicks reach the entity directly on press (engine
	-- INTERACT_PLACE). A food-owned press defers them to the click on release,
	-- so holding food at an NPC or trader eats instead of interacting.
	function M.defer_rightclick(clicker)
		local s = states[clicker:get_player_name()]
		return s ~= nil and s.right == "food"
	end
	function M.can_dig(player, pos, node)
		local s = state(player)
		if not api.selected(player) then
			local eating = is_food(player:get_wielded_item():get_name())
			return not (eating and player:get_player_control().place and s.right)
		end
		if not selected(player) or not allowed(player) or s.cancelled or s.mode == "combat" or
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
					if player and player:is_player() and not M.can_dig(player, pos, node) then
						-- A refused dig on protected ground is still a protection
						-- violation (its handlers show the reason, Round 24).
						local name = player:get_player_name()
						if core.is_protected(pos, name) then
							core.record_protection_violation(pos, name)
						end
						return
					end
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
		for name, definition in pairs(core.registered_entities) do
			local original = definition.on_rightclick
			if type(original) == "function" then
				entity_rightclick[name] = original
				definition.on_rightclick = function(self, clicker, ...)
					if clicker and clicker.is_player and clicker:is_player() and
							M.defer_rightclick(clicker) then
						return
					end
					return original(self, clicker, ...)
				end
			end
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
	core.register_on_leaveplayer(function(player)
		local name = player:get_player_name()
		local r = ranges[name]
		if r then write_range(player, r, "") end -- never saved without pointing
		ranges[name], states[name] = nil, nil
	end)
	-- A crash mid-hold saves a skill stack without pointing range; every join
	-- starts with all of them pointing.
	core.register_on_joinplayer(function(player)
		local inv = player:get_inventory()
		for index, stack in ipairs(inv and inv:get_list("main") or {}) do
			local meta = stack:get_meta()
			if meta:get_string("range") ~= "" and
					core.get_item_group(stack:get_name(), "grug_ability") > 0 then
				meta:set_string("range", "")
				inv:set_stack("main", index, stack)
			end
		end
	end)
	return M
end
