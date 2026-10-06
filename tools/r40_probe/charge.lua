-- Round 40 lane V4: the Charge variants (round40-plan.md §3.3, rulings §2.3,
-- §2.10, §2.11). Every variant takes the game's own destination
-- (grug_abilities.charge_destination, called exactly like kits.lua) and
-- reports when the server saw the arrival or the miss. Nothing is damaged:
-- "arrived within CHARGE_REACH" / "miss" is the result.
--
--   teleport  today's Charge: set_pos to the destination (the baseline)
--   ghost     carrier A, non-physical, one straight line feet to destination
--   physical  carrier A, physical (collides, falls; `step` = stepheight)
--   path      carrier A, non-physical, on the planned path (planner.lua)
--   push      B: add_velocity plus a temporary braking override
--
-- The carrier follows the §3.3 contract: visible with a blank texture (an
-- invisible object gets no scene node, so the rider would not follow it),
-- static_save = false, not pointable, removes itself without its rider,
-- clamps the stop and checks the arrival in its own on_step, forwards
-- punches to the rider, never sets _grug_rider or player_attached.

return function(P)
local MOD, planner = P.MOD, P.planner
local charge = {}
P.charge = charge

local CHARGE_REACH = 3 -- grug_abilities/blink.lua:216, the arrival rule (§2.10)
local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local EPS_LEAD = 0.01 -- model units: the first Body override is never identity
local US = core.get_us_time
local sqrt, max, min = math.sqrt, math.max, math.min

charge.DEFAULTS = {
	speed = 16, lead = 0, leadin = 0.1, fov = 0, step = 0.6, hold = 0.1,
	anim = "walk", snap = 0,
	-- planner knobs (planner.DEFAULTS has the rest)
	hopspeed = 1.0, gmax = 50, maxhop = 6.0, rise = 1.6, drop = 4.0, clear = 0.35,
}

local runs = {} -- rider key (player name or "bench:<n>") -> run
charge.runs = runs

-- The live map for planner.lua: walkable nodes with their collision boxes,
-- everything unknown or unloaded solid (grug_abilities/blink.lua's rule).
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
function charge.live_boxes(x, y, z)
	local pos = {x = x, y = y, z = z}
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "ignore" then return FULL end
	local def = core.registered_nodes[node.name]
	if not def then return FULL end
	if not def.walkable then return nil end
	return core.get_node_boxes("collision_box", pos, node)
end

local function hdist(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return sqrt(dx * dx + dz * dz)
end

-- The run's rider: a connected player (re-fetched every step) or, in the
-- bench, an entity.
local function rider_of(run)
	if run.name then return core.get_player_by_name(run.name) end
	return run.rider and run.rider:get_pos() and run.rider or nil
end

local function target_feet(run)
	local pos = run.target and run.target:get_pos()
	if not pos then return nil end
	return vector.offset(pos, 0, run.tbox and run.tbox[2] or 0, 0)
end

local function say(run, msg)
	if run.name then
		P.say(run.name, msg)
	else
		run.lines[#run.lines + 1] = msg
	end
end

--
-- Body lead, FOV kick, the running pose
--

local function lead_start(run, player)
	if run.opts.lead <= 0 or not player.set_bone_override then return end
	local vs = player:get_properties().visual_size or {y = 1}
	-- Model units: 10 per node (gen_cloak_model.py), divided by the visual
	-- size; +z is the model's forward (gen_cloak_model.py:51).
	run.lead_units = run.opts.lead * 10 / (vs.y > 0 and vs.y or 1)
	-- An override the client does not know yet snaps (no interpolation,
	-- content_cao.cpp:1774-1781), and overrides go out once per server step
	-- (unit_sao.cpp:138-144): the epsilon first, the lead two steps later
	-- (the order of the player's and the carrier's step is not fixed, so one
	-- step could overwrite the epsilon before it was sent).
	player:set_bone_override("Body", {position = {vec = {x = 0, y = 0, z = EPS_LEAD},
		interpolation = 0}})
	run.lead_stage = 1
end

local function lead_step(run, player)
	if run.lead_stage == 1 and run.steps >= 2 then
		player:set_bone_override("Body", {position = {vec = {x = 0, y = 0, z = run.lead_units},
			interpolation = run.opts.leadin}})
		run.lead_stage = 2
	end
end

local function lead_end(run, player)
	if not run.lead_stage then return end
	run.lead_stage = nil
	player:set_bone_override("Body", {position = {vec = {x = 0, y = 0, z = EPS_LEAD},
		interpolation = run.opts.leadin * 1.5}})
	local name, gen = run.name, run.gen
	core.after(run.opts.leadin * 1.5 + 0.1, function()
		local p = name and core.get_player_by_name(name)
		if p and not (runs[name] and runs[name].gen ~= gen and runs[name].lead_stage) then
			p:set_bone_override("Body", nil)
		end
	end)
end

local function fov_start(run, player)
	if run.opts.fov <= 0 or not run.name then return end
	player:set_fov(run.opts.fov, true, 0.08)
	run.fov_on = true
end

local function fov_end(run, player)
	if not run.fov_on then return end
	run.fov_on = nil
	local name, gen = run.name, run.gen
	local function back()
		local p = core.get_player_by_name(name)
		local now = runs[name]
		if not p or (now and now.gen ~= gen and now.fov_on) then return end
		p:set_fov(1, true, 0.25)
		core.after(0.3, function()
			local q = core.get_player_by_name(name)
			local later = runs[name]
			if q and not (later and later.gen ~= gen and later.fov_on) then
				q:set_fov(0, false, 0)
			end
		end)
	end
	-- A teleport has no travel time: let the kick show for a moment.
	if run.variant == "teleport" then core.after(0.15, back) else back() end
end

-- player_api's pose hook (vendored GRUG PATCH, player_api/api.lua:181-196):
-- the legs run during a dash instead of standing still.
if core.global_exists("player_api") and player_api.register_control_animation_override then
	player_api.register_control_animation_override(function(player)
		local run = runs[player:get_player_name()]
		if run and not run.stopped and run.opts.anim ~= "none" and
				run.variant ~= "teleport" then
			return run.opts.anim
		end
	end)
end

--
-- Reach, strikes, the report
--

local function watch(run, pos)
	local tf = target_feet(run)
	if not tf then return end
	local d = vector.distance(pos, tf)
	if not run.reach and d <= CHARGE_REACH then
		run.reach = {t = run.t, steps = run.steps, us = US() - run.t_us}
	end
	-- §2.11: a mob melee punch mid-dash resolves its target exactly like
	-- mobs_redo (mods/ENTITIES/mobs/api.lua:3119: attack:get_attach() or
	-- attack) and must reach the rider through the carrier.
	if run.name and not run.struck then
		local striker = P.course.striker(run.name)
		local spos = striker and striker:get_pos()
		if spos and vector.distance(spos, pos) <= 2.2 then
			run.struck = true
			local player = core.get_player_by_name(run.name)
			local hp = player:get_hp()
			local victim = player:get_attach() or player
			run.forwarded = false
			victim:punch(striker, 1.0, {full_punch_interval = 1.0,
				damage_groups = {fleshy = 2}}, vector.direction(spos, pos))
			run.strike = {t = run.t, via = victim == player and "the player itself" or
				"the carrier", hp0 = hp, hp1 = player:get_hp(), forwarded = run.forwarded}
		end
	end
end

local function fmt_ms(s) return ("%.0f ms"):format(s * 1000) end

local function report(run)
	local o = run.opts
	local extras = {}
	if run.variant ~= "teleport" then extras[#extras + 1] = ("%g m/s"):format(o.speed) end
	if o.lead > 0 then extras[#extras + 1] = ("lead %g m"):format(o.lead) end
	if o.fov > 0 then extras[#extras + 1] = ("fov x%g"):format(o.fov) end
	if run.variant == "physical" then extras[#extras + 1] = ("step %g"):format(o.step) end
	say(run, ("%s%s: planned %.2f m (cast to destination, %.2f m flat), target %.1f m away; destination in %d us")
		:format(run.variant, #extras > 0 and " (" .. table.concat(extras, ", ") .. ")" or "",
			run.planned, hdist(run.from, run.dest), run.target_dist, run.dest_us))
	if run.plan and run.variant == "path" then
		say(run, ("path: %s; planning %d us (%d samples, %d node reads, %d nodes)%s")
			:format(planner.describe(run.plan), run.plan_us, run.plan.samples,
				run.plan.reads, run.plan.unique,
				run.plan.cut and (", CUT SHORT at %.2f m: %s"):format(run.plan.cut_at,
					run.plan.cut_why) or ""))
	end
	local stop = run.stop
	local d = stop.dist
	say(run, ("%s (%s from target) | stop: %s after %s server time, %d steps (%s wall)%s")
		:format(d and d <= CHARGE_REACH and "ARRIVED within CHARGE_REACH" or "MISS",
			d and ("%.2f m"):format(d) or "?", stop.why, fmt_ms(stop.t), stop.steps,
			fmt_ms(stop.us / 1e6),
			run.variant == "teleport" and "" or run.reach and
				(" | reach entered at %s, step %d"):format(fmt_ms(run.reach.t), run.reach.steps)
				or " | reach never entered"))
	if run.steps > 0 and run.variant ~= "teleport" then
		say(run, ("%s cost: %d steps, avg %.1f us, max %d us per step%s")
			:format(run.variant == "push" and "watcher" or "carrier", run.steps,
				run.cost / run.steps, run.cost_max,
				run.plan and (", %d segment switches"):format(run.switches) or ""))
	end
	if run.strike then
		local s = run.strike
		say(run, ("strike at %s: the mob's punch resolved to %s%s, hp %d -> %d")
			:format(fmt_ms(s.t), s.via, s.via == "the carrier" and
				(s.forwarded and " and was forwarded to the rider" or " and was NOT forwarded") or "",
				s.hp0, s.hp1))
	elseif P.course.striker(run.name or "") then
		say(run, "strike: the striker was never within 2.2 m")
	end
end

-- The dash stops: decide arrival or miss now (the server's view).
local function stop(run, why, pos)
	if run.stopped then return end
	run.stopped = true
	local tf = target_feet(run)
	run.stop = {why = why, t = run.t, steps = run.steps, us = US() - run.t_us,
		dist = tf and pos and vector.distance(pos, tf) or nil}
end

local function finish(run)
	if run.done then return end
	run.done = true
	local rider = rider_of(run)
	if rider and run.name then
		lead_end(run, rider)
		fov_end(run, rider)
	end
	if run.restore and rider then
		rider:set_physics_override(run.restore)
	end
	if run.carrier and run.carrier:get_pos() then
		if rider and rider:get_attach() == run.carrier then
			rider:set_detach()
			if run.opts.snap > 0 and run.stop_pos then rider:set_pos(run.stop_pos) end
		end
		run.carrier:remove()
	end
	if not run.stop then stop(run, "aborted", rider and rider:get_pos()) end
	if runs[run.key] == run then runs[run.key] = nil end
	report(run)
	if run.on_done then run.on_done(run) end
end
charge.finish = finish

local function account(run, c0)
	local c = US() - c0
	run.cost = run.cost + c
	if c > run.cost_max then run.cost_max = c end
end

--
-- Carrier A
--

local function carrier_step(self, dtime, moveresult)
	local run = self._run
	if not run or run.done then
		self.object:remove()
		return
	end
	local c0 = US()
	local rider = rider_of(run)
	if not rider or rider:get_attach() ~= self.object then
		stop(run, "rider gone", self.object:get_pos())
		finish(run)
		self.object:remove()
		return
	end
	run.t = run.t + dtime
	run.steps = run.steps + 1
	local obj = self.object
	local pos = obj:get_pos()
	if run.stopped then
		-- Hold at the stop so the client's smoothed carrier settles before
		-- the rider is let go (the client keeps its own position on detach).
		if run.t - run.stop.t >= run.opts.hold then
			account(run, c0)
			finish(run)
		else
			account(run, c0)
		end
		return
	end
	if run.lead_stage then lead_step(run, rider) end
	if run.variant == "physical" then
		local along = (pos.x - run.from.x) * run.ux + (pos.z - run.from.z) * run.uz
		local remaining = run.flat - along
		local v = obj:get_velocity()
		local hv = sqrt(v.x * v.x + v.z * v.z)
		if run.steps > 2 and hv < 0.3 * run.opts.speed then
			run.slow = (run.slow or 0) + 1
		else
			run.slow = 0
		end
		if remaining <= 0.05 then
			obj:set_velocity({x = 0, y = v.y, z = 0})
			if not moveresult or moveresult.touching_ground or run.t > run.expect + 1 then
				run.stop_pos = pos
				stop(run, "clamped at the destination", pos)
			end
		elseif run.slow >= 2 then
			obj:set_velocity({x = 0, y = v.y, z = 0})
			run.stop_pos = pos
			stop(run, "blocked (collision)", pos)
		elseif run.t > run.expect * 2 + 0.5 then
			run.stop_pos = pos
			stop(run, "timeout", pos)
		else
			-- Clamp ahead: never more than what is left in one step.
			local s = min(run.opts.speed, remaining / max(dtime, 0.02))
			obj:set_velocity({x = run.ux * s, y = v.y, z = run.uz * s})
		end
	else
		local plan = run.plan
		if run.t >= plan.total then
			-- move_to, not set_pos: set_pos sends a non-interpolated update
			-- (luaentity_sao.cpp:387-392) that the client snaps to
			-- (content_cao.cpp:1651-1657).
			obj:move_to(plan.finish, true)
			obj:set_velocity({x = 0, y = 0, z = 0})
			obj:set_acceleration({x = 0, y = 0, z = 0})
			run.stop_pos = plan.finish
			pos = plan.finish
			stop(run, plan.cut and "end of the cut path" or "clamped at the destination", pos)
		else
			local p, v, a, index = planner.state_at(plan, run.t)
			if index ~= run.seg then
				-- A late switch: put the carrier where the plan says it is now.
				-- The step's own position packet carries pos, v and a.
				run.seg = index
				run.switches = run.switches + 1
				obj:move_to(p, true)
				obj:set_velocity(v)
				obj:set_acceleration(a)
				pos = p
			end
			-- The last step before the end: arrive in one more step.
			local left = plan.total - run.t
			if index == #plan.segments and left < dtime then
				local f = plan.finish
				local k = 1 / max(dtime, 0.02)
				obj:set_velocity({x = (f.x - pos.x) * k, y = (f.y - pos.y) * k,
					z = (f.z - pos.z) * k})
				obj:set_acceleration({x = 0, y = 0, z = 0})
			end
		end
	end
	watch(run, pos)
	account(run, c0)
end

core.register_entity(MOD .. ":carrier", {
	initial_properties = {
		physical = false, collide_with_objects = false, pointable = false,
		static_save = false,
		visual = "sprite", visual_size = {x = 0.1, y = 0.1},
		textures = {"grug_mobs_blank.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
		selectionbox = {0, 0, 0, 0, 0, 0},
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_step = carrier_step,
	-- §2.11: a punch on the carrier (mobs_redo melee, the Kraken's drag act
	-- on the parent) is forwarded to the rider; the dash grants no immunity.
	on_punch = function(self, puncher, tflp, caps, dir)
		local run = self._run
		local rider = run and rider_of(run)
		if rider and rider:get_attach() == self.object then
			run.forwarded = true
			rider:punch(puncher, tflp, caps, dir)
		end
		return true
	end,
})

--
-- Start
--

local gen = 0

local function new_run(variant, key, opts)
	gen = gen + 1
	return {variant = variant, key = key, opts = opts, gen = gen,
		t = 0, steps = 0, cost = 0, cost_max = 0, switches = 0, lines = {}}
end

-- Start a dash of `rider` (a player, or an entity in the bench) at `target`.
-- Returns true or false and a reason.
function charge.start(rider, target, variant, opts, key, on_done)
	key = key or rider:get_player_name()
	local old = runs[key]
	-- A carrier removed without its on_step (/clearobjects) leaves its run
	-- behind: forget it.
	if old and old.carrier and not old.carrier:get_pos() then
		runs[key] = nil
		old = nil
	end
	if old then return false, "a dash is already running" end
	if rider:get_attach() then return false, "already attached (mounted?)" end
	local is_player = rider:is_player()
	local run = new_run(variant, key, opts)
	run.name = is_player and rider:get_player_name() or nil
	run.rider = rider
	run.target = target
	run.on_done = on_done
	local props = rider:get_properties()
	run.tbox = target:get_properties().collisionbox
	local tf = target_feet(run)
	run.from = rider:get_pos()
	run.target_dist = vector.distance(run.from, tf)
	local c0 = US()
	local dest = grug_abilities.charge_destination(run.from,
		props.eye_height or 1.47, props.collisionbox or BOX, tf)
	run.dest_us = US() - c0
	if not dest then
		return false, ("%s: refused at the cast (the game's \"Not enough room at target.\"; no line of sight or no room); destination search %d us")
			:format(variant, run.dest_us)
	end
	run.dest = dest
	run.planned = vector.distance(run.from, dest)
	run.flat = hdist(run.from, dest)
	run.ux = run.flat > 0 and (dest.x - run.from.x) / run.flat or 0
	run.uz = run.flat > 0 and (dest.z - run.from.z) / run.flat or 0
	run.t_us = US()

	if variant == "teleport" then
		runs[key] = run
		rider:set_pos(dest)
		fov_start(run, rider)
		stop(run, "teleported", dest)
		finish(run)
		return true
	end

	if variant == "path" then
		local p0 = US()
		local plan, why = planner.plan(charge.live_boxes, run.from, dest, {
			speed = opts.speed, hop_speed = opts.hopspeed, g_max = opts.gmax,
			max_hop = opts.maxhop, max_rise = opts.rise, max_drop = opts.drop,
			clear = opts.clear})
		run.plan_us = US() - p0
		if not plan then
			return false, ("path %s; planning %d us"):format(why, run.plan_us)
		end
		run.plan = plan
	elseif variant == "ghost" then
		run.plan = planner.straight(run.from, dest, opts.speed)
	elseif variant == "physical" then
		run.expect = run.flat / opts.speed
	elseif variant == "push" then
		return charge.start_push(run, rider)
	else
		return false, "unknown variant " .. tostring(variant)
	end

	local obj = core.add_entity(run.from, MOD .. ":carrier")
	local ent = obj and obj:get_luaentity()
	if not ent then return false, "the carrier could not be spawned" end
	ent._run = run
	run.carrier = obj
	if variant == "physical" then
		obj:set_properties({physical = true, stepheight = opts.step})
		local g = tonumber(core.settings:get("movement_gravity")) or 9.81
		obj:set_acceleration({x = 0, y = -g, z = 0})
		obj:set_velocity({x = run.ux * opts.speed, y = 0, z = run.uz * opts.speed})
	else
		local s = run.plan.segments[1]
		if s then
			obj:set_velocity(s.v)
			obj:set_acceleration(s.a)
		end
		run.seg = 1
	end
	-- The rider faces the dash: the attachment carries the yaw, negated
	-- like the mounts do (grug_mounts/entity.lua:334-337).
	local yaw = run.flat > 0 and core.dir_to_yaw({x = run.ux, y = 0, z = run.uz})
		or (is_player and rider:get_look_horizontal() or 0)
	rider:set_attach(obj, "", {x = 0, y = 0, z = 0}, {x = 0, y = -math.deg(yaw), z = 0})
	runs[key] = run
	if is_player then
		lead_start(run, rider)
		fov_start(run, rider)
	end
	return true
end

--
-- Push B
--

-- The client brakes linearly toward the input velocity with
-- movement_acceleration_default (ground) / _air times the override's
-- acceleration_default / _air (localplayer.cpp:700-731), so a start speed
-- v0 stops after v0^2 / 2b: the override is chosen so that b = v0^2 / 2d.
-- This override is the probe's own, tools-only exception to "movement.lua
-- is the only physics writer" (plan §5); it is restored at the end.
function charge.start_push(run, player)
	if not run.name then return false, "push needs a player" end
	local v0, d = run.opts.speed, run.flat
	if d < 0.1 then return false, "push: destination too close" end
	local b = v0 * v0 / (2 * d)
	local ground = tonumber(core.settings:get("movement_acceleration_default")) or 3
	local air = tonumber(core.settings:get("movement_acceleration_air")) or 2
	local live = player:get_physics_override()
	run.restore = {acceleration_default = live.acceleration_default or 1,
		acceleration_air = live.acceleration_air or 1}
	run.brake = b
	player:set_physics_override({acceleration_default = b / ground,
		acceleration_air = b / air})
	player:add_velocity({x = run.ux * v0, y = 0, z = run.uz * v0})
	run.expect = 2 * d / v0
	runs[run.key] = run
	lead_start(run, player)
	fov_start(run, player)
	return true
end

-- The push watcher: every server step while a push runs (the arrival time
-- is what the probe measures), nothing otherwise.
core.register_globalstep(function(dtime)
	for _, run in pairs(runs) do
		if run.variant == "push" and not run.done then
			local c0 = US()
			local player = rider_of(run)
			if not player then
				stop(run, "left")
				finish(run)
			else
				run.t = run.t + dtime
				run.steps = run.steps + 1
				local pos = player:get_pos()
				if run.lead_stage then lead_step(run, player) end
				local remaining = (run.dest.x - pos.x) * run.ux + (run.dest.z - pos.z) * run.uz
				local v = player:get_velocity()
				local hv = sqrt(v.x * v.x + v.z * v.z)
				watch(run, pos)
				if remaining <= 0.3 then
					stop(run, ("reached the destination (%.2f m left)"):format(remaining), pos)
				elseif run.t > 0.25 and hv < 0.5 then
					stop(run, ("stopped short (%.2f m left)"):format(remaining), pos)
				elseif run.t > run.expect * 1.5 + 0.5 then
					stop(run, ("timeout (%.2f m left)"):format(remaining), pos)
				end
				account(run, c0)
				if run.stopped then finish(run) end
			end
		end
	end
end)

local function abort(name, why)
	local run = runs[name]
	if run and not run.done then
		local p = core.get_player_by_name(name)
		stop(run, why, p and p:get_pos())
		finish(run)
	end
end
core.register_on_leaveplayer(function(player) abort(player:get_player_name(), "left") end)
core.register_on_dieplayer(function(player) abort(player:get_player_name(), "died") end)
end
