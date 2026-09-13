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
	local props = self.object:get_properties()
	local box = props and props.collisionbox
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
