-- Charge's dash (Round 40, round40-plan.md §2.3, §2.10, §2.11, §2.16, §3.3;
-- docs/design/classes.md §3 "Charge"). The cast picks the destination as
-- before (blink.lua) and hands it here: the warrior rides an invisible
-- carrier along the planned path (charge_path.lua) at a constant 24 m/s.
-- Damage, the stun, the 15 rage and the dust ring land on ARRIVAL, when the
-- dash ends within reach of the target (re-fetched, its relation and PvP
-- flags asked again); a dash that ends anywhere else is a miss: the cooldown
-- is spent and nothing else happens. A stun or root on the warrior, death,
-- logout and travel cancel the dash (a miss).
--
-- The carrier (the reviewed probe's contract, tools/r40_probe/charge.lua):
-- * visible with a blank texture, never is_visible = false: an invisible
--   object gets no scene node on the client, so its rider would not follow
--   it; not pointable, static_save = false, and it removes itself without
--   its rider, so a logout or crash leaves nothing behind;
-- * non-physical: each path segment is one velocity and one acceleration
--   the client extrapolates; its own on_step switches segments with
--   move_to(p, true) (set_pos sends a non-interpolated update the client
--   snaps to, luaentity_sao.cpp:387-392) and clamps the stop -- entity
--   physics runs before on_step (luaentity_sao.cpp:165-216), so the last
--   step is predicted to land exactly on the end;
-- * a punch on it is forwarded to the rider (§2.11: mobs_redo's melee and
--   the Kraken's drag act on the parent, mobs/api.lua:3119): no immunity;
-- * it never sets _grug_rider (the mounted checks key on it) nor
--   player_api's player_attached (that would skip the pose hook).
-- The on_step is the only per-step work, and it exists only while a dash
-- runs: no globalstep visits players.
--
-- The stop (the uphill finding of §2.16): the client draws the carrier
-- through its SmoothTranslator, which closes 0.8 of the gap per update
-- interval (the server step, content_cao.cpp:62-93, 1121-1125), so the drawn
-- carrier -- and the attached local player, which copies it
-- (localplayer.cpp:229-233) -- trails the server by about speed x step / 0.8
-- (2.7 m at 24 m/s), and on detach the client keeps that drawn position. The
-- probe let go 0.1 s after the stop: about 1 m short, on a stair the edge
-- below. So the carrier holds until the drawn position has closed in (three
-- time constants) and the detach puts the player on the stop with set_pos
-- (the engine sends the detach before the move, server.cpp:2097-2106).

return function(path, REACH)
local max, min = math.max, math.min

local CARRIER = "grug_abilities:charge_carrier"
local RAGE, STUN = 15, 1.5 -- classes.md §3, the Charge row
-- The Body lead (model ahead, camera following; third person and other
-- players only, the engine draws no own model in first person): 0.5 m on
-- dashes of at least 3 m, the probe's recommendation. It moves between the
-- epsilon and the lead, never from or to identity: the first override of a
-- bone snaps (content_cao.cpp:1765-1781) and the client erases an override
-- that has returned to identity (content_cao.cpp:716-724, activeobject.h:
-- 140-146), so every player carries the epsilon from joining on
-- (upstream-workarounds.md §3).
local LEAD, LEAD_FROM, LEAD_IN, LEAD_OUT = 0.5, 3, 0.1, 0.15
local EPS_LEAD = 0.01 -- model units, invisible
-- The first-person accent: a mild FOV kick, blended by the client.
local FOV, FOV_IN, FOV_OUT = 1.1, 0.08, 0.25
-- The client's drawn lag behind the server, one time constant (above).
local STEP = tonumber(core.settings:get("dedicated_server_step")) or 0.09
local LAG = STEP / 0.8
local SETTLE = 3 * LAG
-- charge_dust spawners are at most 1 s long (the particle helper's cap).
local DUST_PIECE = 1

local runs = {} -- player name -> the running dash
local gen = 0

local function lead_units(player)
	local size = player:get_properties().visual_size
	local y = size and size.y or 1
	-- 10 model units per node (tools/r33_c3/gen_cloak_model.py), +z is the
	-- model's forward.
	return LEAD * 10 / (y > 0 and y or 1)
end

local function set_lead(player, z, interpolation)
	player:set_bone_override("Body", {position = {vec = {x = 0, y = 0, z = z},
		interpolation = interpolation}})
end

core.register_on_joinplayer(function(player)
	set_lead(player, EPS_LEAD, 0)
end)

-- Lead, FOV kick and the charge pose (grug_visuals/poses.lua, held until
-- the stop).
local function effects_start(run, player)
	if run.plan.dist >= LEAD_FROM then
		set_lead(player, lead_units(player), LEAD_IN)
		run.lead = true
	end
	player:set_fov(FOV, true, FOV_IN)
	run.fov = true
	grug_visuals.start_pose(player, "charge")
end

local function effects_end(run, player)
	if run.lead then
		run.lead = nil
		set_lead(player, EPS_LEAD, LEAD_OUT)
	end
	if run.fov then
		run.fov = nil
		player:set_fov(1, true, FOV_OUT)
		local name = run.name
		core.after(FOV_OUT + 0.05, function()
			local p = core.get_player_by_name(name)
			local now = runs[name]
			if p and not (now and now.fov) then p:set_fov(0, false, 0) end
		end)
	end
	grug_visuals.stop_pose(player, "charge")
	-- Lane AN2's head look writes no Head override while the lead blends
	-- out (every write re-sends all bone overrides and cuts a blend short).
	if grug_visuals.hold_head then grug_visuals.hold_head(player, 0.2) end
end

-- Dust along a run segment, delayed by the client's drawn lag so it rises
-- under the warrior, not ahead of him.
local function dust(run, index)
	local seg = run.plan.segments[index]
	if not seg or seg.kind ~= "run" or seg.t <= 0 then return end
	local t0 = 0
	while t0 < seg.t do
		local dt = min(DUST_PIECE, seg.t - t0)
		local from = vector.add(seg.p0, vector.multiply(seg.v, t0))
		local to = vector.add(seg.p0, vector.multiply(seg.v, t0 + dt))
		core.after(LAG + t0, grug_abilities.charge_dust, from, to, dt)
		t0 = t0 + dt
	end
end

-- The target now: a player is re-fetched by name (a relog is a new object).
local function target_of(run)
	if run.target_name then return core.get_player_by_name(run.target_name) end
	return run.target and run.target:get_pos() and run.target or nil
end

-- Within CHARGE_REACH of the target's collision box from the feet `pos`
-- (the destination is chosen within it, blink.lua).
local function in_reach(pos, target)
	local tpos = target:get_pos()
	local box = target:get_properties().collisionbox or {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
	local function gap(p, lo, hi) return max(lo - p, 0, p - hi) end
	local gx = gap(pos.x, tpos.x + box[1], tpos.x + box[4])
	local gy = gap(pos.y, tpos.y + box[2], tpos.y + box[5])
	local gz = gap(pos.z, tpos.z + box[3], tpos.z + box[6])
	return gx * gx + gy * gy + gz * gz <= REACH * REACH
end

-- The dash ended at `pos`: the hit lands, or it is a miss.
local function arrive(run, player, pos)
	local target = target_of(run)
	if not (target and in_reach(pos, target) and
			grug_abilities.valid_target(player, target, "hostile")) then
		return false
	end
	run.hit = true
	grug_core.particles.play("charge_ring", {target = target:get_pos()})
	grug_abilities.add_rage(player, RAGE)
	grug_core.deal_ability_damage(player, target, run.def.values(player).damage,
		{threat_mult = 3, on_accepted = function()
			if target:is_player() then
				grug_core.set_stun(target, STUN)
			else
				local ent = target:get_luaentity()
				if ent and ent._cmi_is_mob then grug_mobs.stun(ent, STUN) end
			end
		end})
	return true
end

-- The end of a dash: the rider is let go at `run.place` (nil: where it is).
local function release(run)
	if run.done then return end
	run.done = true
	if runs[run.name] == run then runs[run.name] = nil end
	local player = core.get_player_by_name(run.name)
	local carrier = run.carrier
	if player then
		effects_end(run, player)
		if carrier and player:get_attach() == carrier then
			player:set_detach()
			if run.place then player:set_pos(run.place) end
		end
	end
	if carrier and carrier:get_pos() then carrier:remove() end
end

-- The carrier stops at `pos`; the rider stays on it until the client's
-- drawn position has closed in.
local function stop(run, player, pos)
	run.stopped, run.stop_t, run.place = true, run.t, pos
	local obj = run.carrier
	obj:move_to(pos, true)
	obj:set_velocity({x = 0, y = 0, z = 0})
	obj:set_acceleration({x = 0, y = 0, z = 0})
	effects_end(run, player)
end

-- Where a dash cut off now lets its rider go: the plan's own position at
-- the dash time (a spot the planner checked), never the carrier's, which
-- entity physics may already have moved on along the last segment (down
-- the old arc past a landing, or pushed by a pull). `ground` takes the last
-- ground instead: the takeoff of a hop in flight (a logout is saved where
-- it is let go).
local function plan_place(run, ground)
	local pos, _, _, index = path.state_at(run.plan, min(run.t, run.plan.total))
	local seg = run.plan.segments[index]
	if ground and seg and seg.kind == "hop" then return vector.new(seg.p0) end
	return pos
end

-- Ends `name`'s dash now: before its arrival a miss (the rider is let go on
-- the plan where the dash is), after it just the end of the hold. `ground`:
-- on the last ground (a logout).
local function cancel(name, ground)
	local run = runs[name]
	if not run then return end
	if not run.stopped then
		run.place = plan_place(run, ground)
	end
	release(run)
end

local function carrier_step(self, dtime)
	local run = self._grug_run
	if not run or run.done or runs[run.name] ~= run then
		self.object:remove()
		return
	end
	local player = core.get_player_by_name(run.name)
	if not player or player:get_attach() ~= self.object then
		-- The rider left the carrier some other way: nothing more lands.
		run.place = nil
		release(run)
		return
	end
	run.t = run.t + dtime
	if player:get_hp() <= 0 or grug_core.is_stunned(player) or grug_core.is_rooted(player) then
		cancel(run.name)
		return
	end
	if run.stopped then
		if run.t - run.stop_t >= SETTLE then release(run) end
		return
	end
	local plan, obj = run.plan, self.object
	if run.t >= plan.total then
		stop(run, player, plan.finish)
		arrive(run, player, plan.finish)
		return
	end
	local p, v, a, index = path.state_at(plan, run.t)
	local pos
	if index ~= run.seg then
		-- A late switch: put the carrier where the plan says it is now; the
		-- step's own position packet carries pos, v and a.
		run.seg = index
		obj:move_to(p, true)
		obj:set_velocity(v)
		obj:set_acceleration(a)
		pos = p
		dust(run, index)
	end
	-- The last step before the end: arrive in one more step.
	if index == #plan.segments and plan.total - run.t < dtime then
		pos = pos or obj:get_pos()
		local f, k = plan.finish, 1 / max(dtime, 0.02)
		obj:set_velocity({x = (f.x - pos.x) * k, y = (f.y - pos.y) * k,
			z = (f.z - pos.z) * k})
		obj:set_acceleration({x = 0, y = 0, z = 0})
	end
end

core.register_entity(CARRIER, {
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
	-- §2.11: a punch on the carrier reaches the rider; the dash grants no
	-- immunity.
	on_punch = function(self, puncher, tflp, caps, dir)
		local run = self._grug_run
		local player = run and not run.done and core.get_player_by_name(run.name)
		-- Not its own punches (mobs_redo's entity_physics hits every object
		-- near a blast, the carrier included, with itself as the puncher).
		if puncher and puncher ~= self.object and player and
				player:get_attach() == self.object then
			player:punch(puncher, tflp, caps, dir)
		end
		return true
	end,
})

-- The planned path from the feet `from` to the feet `dest` on the live map.
function grug_abilities.charge_plan(from, dest)
	return path.plan(path.live, from, dest)
end

-- Starts `user`'s dash at `target` to the destination `dest` (charge_destination).
-- True when the cast happened (the cooldown is armed, hit or miss); false
-- and a reason when it did not.
function grug_abilities.charge_dash(user, target, dest, def)
	local name = user:get_player_name()
	local old = runs[name]
	-- A carrier removed from outside (/clearobjects) never stepped again:
	-- end its run so it neither blocks this one nor keeps lead, FOV or pose.
	if old and not (old.carrier and old.carrier:get_pos()) then
		old.place = nil
		release(old)
		old = nil
	end
	if old then return false, "Charge is already running." end
	if user:get_attach() then return false, "Dismount before attacking." end
	local from = user:get_pos()
	gen = gen + 1
	local run = {name = name, gen = gen, def = def, t = 0,
		plan = grug_abilities.charge_plan(from, dest)}
	if target:is_player() then
		run.target_name = target:get_player_name()
	else
		run.target = target
	end
	-- Nowhere to go (a hole at the feet) or held in place: the dash ends
	-- where it starts.
	if run.plan.total <= 0 or grug_core.is_rooted(user) then
		arrive(run, user, from)
		return true
	end
	local obj = core.add_entity(from, CARRIER)
	local ent = obj and obj:get_luaentity()
	if not ent then
		if obj then obj:remove() end
		return false, "Not enough room at target."
	end
	ent._grug_run = run
	run.carrier = obj
	local first = run.plan.segments[1]
	obj:set_velocity(first.v)
	obj:set_acceleration(first.a)
	run.seg = 1
	-- The rider faces the dash: the attachment carries the yaw, negated like
	-- the mounts do (grug_mounts/entity.lua:336-337).
	local dx, dz = dest.x - from.x, dest.z - from.z
	local yaw = (dx * dx + dz * dz > 0) and core.dir_to_yaw({x = dx, y = 0, z = dz})
		or user:get_look_horizontal()
	user:set_attach(obj, "", {x = 0, y = 0, z = 0}, {x = 0, y = -math.deg(yaw), z = 0})
	runs[name] = run
	effects_start(run, user)
	dust(run, 1)
	return true
end

-- Whether `player` is dashing (the hold after the arrival included).
function grug_abilities.charge_dashing(player)
	return runs[player:get_player_name()] ~= nil
end

function grug_abilities.cancel_charge(player)
	cancel(player:get_player_name())
end

-- Travel (grug_home/travel.lua) cancels before its set_pos, which an
-- attached player would ignore.
grug_core.cancel_dash = grug_abilities.cancel_charge

core.register_on_dieplayer(function(player)
	cancel(player:get_player_name())
end)

core.register_on_leaveplayer(function(player)
	cancel(player:get_player_name(), true)
end)
end
