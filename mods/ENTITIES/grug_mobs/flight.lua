-- Gentle near-ground drift for free-flying AIR mobs.
-- Tuning and ownership contract: docs/research/wp40-flight-nudge.md.

local PROBE_INTERVAL = 0.75
local PROBE_DEPTH = 12
local CLEARANCE_LOW = 2
local CLEARANCE_HIGH = 4
local DESCENT_BIAS = -0.65
local ASCENT_BIAS = 0.55
local BIAS_ACCELERATION = 0.8

local function approach(value, target, amount)
	if value < target then
		return math.min(value + amount, target)
	end
	return math.max(value - amount, target)
end

local function steering_owned(self)
	return self.state == "attack" or self.state == "runaway" or self.following
		or (self.temp and self.temp.grug_evading)
		or (self._grug_root_left or 0) > 0
end

local function probe_clearance(self, pos)
	-- The runtime box field, not a get_properties() table (Round 30 P2).
	local box = mobs.grug_obstacle.mob_cbox(self)
	local bottom = pos.y + ((box and box[2]) or 0)
	local start_y = math.floor(bottom - 0.001)
	for offset = 0, PROBE_DEPTH - 1 do
		local node = core.get_node_or_nil({
			x = math.floor(pos.x + 0.5),
			y = start_y - offset,
			z = math.floor(pos.z + 0.5),
		})
		if not node or node.name == "ignore" then
			return nil
		end
		local def = core.registered_nodes[node.name]
		if not def then
			return nil
		end
		if def.walkable or (def.groups and (def.groups.liquid or 0) > 0) then
			return bottom - (start_y - offset + 0.5)
		end
	end
	-- Every sampled node was known and open. Ground is farther away than the
	-- bounded probe, which is enough information to request gentle descent.
	return PROBE_DEPTH
end

function grug_mobs.flight_nudge_tick(self, dtime)
	if not self.fly or self.fly_in ~= "air" or not self.object then
		return
	end
	self.temp = self.temp or {}
	local temp = self.temp
	local velocity = self.object:get_velocity()
	local pos = self.object:get_pos()
	if not velocity or not pos then
		return
	end
	if steering_owned(self) then
		-- Remove a still-recognizable owned bias. mobs_redo's ordinary
		-- set_velocity preserves Y, including in-reach dogfight movement, so
		-- merely clearing bookkeeping would otherwise leave the bird drifting.
		-- If another branch replaced Y, preserve that new authoritative value.
		local previous = temp.grug_flight_bias or 0
		if previous ~= 0 and temp.grug_flight_applied_y ~= nil
				and math.abs(velocity.y - temp.grug_flight_applied_y) <= 0.000001 then
			self.object:set_velocity({
				x = velocity.x,
				y = velocity.y - previous,
				z = velocity.z,
			})
		end
		temp.grug_flight_bias = nil
		temp.grug_flight_applied_y = nil
		-- Purposeful steering can cross several columns. Never reuse clearance
		-- measured before it began; the next free-flight tick schedules a probe
		-- from the current position.
		temp.grug_flight_clearance = nil
		temp.grug_flight_probe_left = nil
		return
	end

	if temp.grug_flight_probe_left == nil then
		local phase = (math.floor(pos.x) + 3 * math.floor(pos.y)
			+ 7 * math.floor(pos.z)) % 16
		temp.grug_flight_probe_left = phase * PROBE_INTERVAL / 16
	end
	temp.grug_flight_probe_left = temp.grug_flight_probe_left - dtime
	if temp.grug_flight_probe_left <= 0 then
		temp.grug_flight_clearance = probe_clearance(self, pos)
		temp.grug_flight_probe_left = PROBE_INTERVAL
	end

	local target = 0
	local clearance = temp.grug_flight_clearance
	if clearance then
		if clearance > CLEARANCE_HIGH then
			target = DESCENT_BIAS
		elseif clearance < CLEARANCE_LOW then
			target = ASCENT_BIAS
		end
	end
	local previous = temp.grug_flight_bias or 0
	if temp.grug_flight_applied_y == nil
			or math.abs(velocity.y - temp.grug_flight_applied_y) > 0.000001 then
		-- Native flight correction replaced the velocity: use its value as the
		-- new baseline instead of subtracting an obsolete additive term.
		previous = 0
	end
	local next_bias = approach(previous, target, BIAS_ACCELERATION * dtime)
	if next_bias ~= previous then
		local next_velocity = {
			x = velocity.x,
			y = velocity.y - previous + next_bias,
			z = velocity.z,
		}
		self.object:set_velocity(next_velocity)
		temp.grug_flight_applied_y = next_velocity.y
	else
		temp.grug_flight_applied_y = velocity.y
	end
	temp.grug_flight_bias = next_bias
end

function grug_mobs.install_flight_nudge(def)
	local old_do_custom = def.do_custom
	def.do_custom = function(self, dtime, moveresult)
		grug_mobs.flight_nudge_tick(self, dtime)
		if old_do_custom then
			return old_do_custom(self, dtime, moveresult)
		end
	end
end

--
-- THE WINGS BEAT IN THE AIR (Round 45 playtest). mobs_redo picks the fly clip
-- only in its walk state; its stand state (velocity 0, a fly mob hovers where
-- it is), the follow pause, the runaway, the in-reach stops of a fight and
-- stop_attack ask for "stand", "walk" or "run", so a bird hung in the air in
-- its perched pose. On a flier whose definition has a fly clip, every such
-- request plays the fly clip while the mob is in the air: inside its element
-- (flight_check) and not standing on walkable ground out of water, the rule
-- do_states' walk state and grug_mobs.walk_animation (patrol.lua) already
-- use. On the ground the clip asked for plays. Installed on the registered
-- prototype, so every set_animation of the mob (mobs_redo's and ours) passes
-- here; the dragons switch `fly` at runtime and are covered while it is on.
--
-- The swing lock (mobs/api.lua set_animation, Round 37 MB) holds back
-- "stand", "walk" and "run" but not "fly": while it holds, the request goes
-- through unchanged so the lock still applies.
--
local function in_the_air(self)
	if not self.fly or not self:flight_check() then
		return false
	end
	local on = core.registered_nodes[self.standing_on]
	if not (on and on.walkable) then
		return true
	end
	local within = core.registered_nodes[self.standing_in]
	return (within and within.groups and within.groups.water or 0) ~= 0
end

local MOVE_CLIPS = {stand = true, walk = true, run = true}

function grug_mobs.flier_clip(self, anim, force)
	if not MOVE_CLIPS[anim] or not in_the_air(self) then
		return anim
	end
	local temp = self.temp
	if not force and temp and temp.grug_punch_until
			and core.get_us_time() / 1000000 < temp.grug_punch_until then
		return anim
	end
	return "fly"
end

-- An air flier (fly_in "air", alone or in a list) with a fly clip; `fly` or
-- `keep_flying` on the definition. Called right after mobs:register_mob.
function grug_mobs.install_flier_animation(name)
	local proto = core.registered_entities[name]
	local anims = proto and proto.animation
	local fly_in = proto and proto.fly_in
	local in_air = fly_in == "air"
	if type(fly_in) == "table" then
		for _, medium in ipairs(fly_in) do
			if medium == "air" then in_air = true end
		end
	end
	if not (in_air and (proto.fly or proto.keep_flying)
			and anims and anims.fly_start and anims.fly_end) then
		return false
	end
	local native = proto.set_animation
	proto.set_animation = function(self, anim, force)
		return native(self, grug_mobs.flier_clip(self, anim, force), force)
	end
	return true
end
