-- Water swimmers (`_grug_swimmer = true`: Reed Angelfish, Kraken) never move
-- into or rest in a non-water node.
--
-- mobs_redo's swimming (`fly = true`, `fly_in = <water>`) does not hold that on
-- its own (headless evidence: tools/pt_fixes/lane_c/run.sh; unguarded, fish
-- and Krakens spent most of a four-minute run on the bank):
--   * the default stepheight 1.1 lets a swimmer step up a bank level with the
--     water surface, and nothing turns a wandering swimmer back from there:
--     `do_states` keeps re-applying the walk velocity along its yaw;
--   * `flight_check` counts ANY node that is not airlike or liquid as "in my
--     medium" (api.lua flight_check), so shore plants, reeds and waterlilies
--     are swimmable;
--   * a fly mob has no gravity and `set_velocity` keeps the vertical part, so
--     the up/down wander of `attempt_flight_correction` drifts it through the
--     surface into the air or a waterlily.
--
-- The guard runs AFTER the native on_step, so its velocity is the last word
-- before the engine moves the object, whatever branch (wander, attack, path,
-- knockback pause, stun) wrote it. It reads the same point mobs_redo's
-- get_nodes calls standing_in (collision-box bottom + 0.25):
--   in water  -> the point one look-ahead further along the velocity must be
--                water too; otherwise the offending horizontal and/or vertical
--                part of the velocity is removed and the swimmer turns round.
--   displaced -> reachable water within one node (knockback, water removed):
--                swim to the nearest such node; none: a stranded fish, it
--                flops in place (no horizontal movement, falls to the ground).
-- Cost in water: one or two get_node_raw reads per step while moving, none
-- while still. Out of water: one read per step, plus a 27-node scan at most
-- every DISPLACED_SCAN seconds; the chosen velocity is re-applied in between.

local LOOKAHEAD = 0.35 -- seconds of travel checked ahead
local MIN_AHEAD = 0.2 -- nodes; keeps slow drift from creeping over an edge
local STRANDED_FALL = -5 -- mobs_redo's own flop velocity (follow_flop)
local DISPLACED_SCAN = 0.25 -- seconds between out-of-water water searches

local get_node_raw = core.get_node_raw
local get_content_id = core.get_content_id
if not get_node_raw then
	get_node_raw = function(x, y, z)
		return get_content_id(core.get_node({x = x, y = y, z = z}).name)
	end
end
local sqrt, floor, pi = math.sqrt, math.floor, math.pi

-- Filled at mods_loaded (content ids exist only after registration).
local medium_id = {}

local function turn_round(self)
	local yaw = self.object:get_yaw()
	if yaw then
		self.delay = 0 -- cancel a pending smooth turn towards the shore
		self:set_yaw(yaw + pi, 0)
	end
end

-- Walkability by content id, filled lazily (unknown ids count as walkable).
local walkable_id = {}
local function walkable(id)
	local w = walkable_id[id]
	if w == nil then
		local def = core.registered_nodes[core.get_name_from_content_id(id)]
		w = not def or def.walkable ~= false
		walkable_id[id] = w
	end
	return w
end

-- The nearest REACHABLE medium node within one node of (x, y, z), or nil. A
-- face neighbour is always reachable; a diagonal one only when one of the
-- face steps towards it is not walkable -- diagonal water behind a solid
-- block would otherwise hold the swimmer pressed against that block.
local function nearest_medium(x, y, z, cid)
	local bx, by, bz = floor(x + 0.5), floor(y + 0.5), floor(z + 0.5)
	local best, best_d
	for dy = -1, 1 do
		for dz = -1, 1 do
			for dx = -1, 1 do
				local nx, ny, nz = bx + dx, by + dy, bz + dz
				if get_node_raw(nx, ny, nz) == cid then
					local axes = (dx ~= 0 and 1 or 0) + (dy ~= 0 and 1 or 0)
						+ (dz ~= 0 and 1 or 0)
					local reachable = axes <= 1
						or (dx ~= 0 and not walkable(get_node_raw(nx, by, bz)))
						or (dy ~= 0 and not walkable(get_node_raw(bx, ny, bz)))
						or (dz ~= 0 and not walkable(get_node_raw(bx, by, nz)))
					if reachable then
						local ex, ey, ez = nx - x, ny - y, nz - z
						local d = ex * ex + ey * ey + ez * ez
						if not best_d or d < best_d then
							best_d, best = d, {x = ex, y = ey, z = ez}
						end
					end
				end
			end
		end
	end
	return best, best_d
end

function grug_mobs.swimmer_guard_step(self, dtime)
	local object = self.object
	local pos = object:get_pos()
	if not pos or self.state == "die" then
		return
	end
	local cid = medium_id[self.name]
	local rx, ry, rz = pos.x, pos.y + self._grug_swim_dy, pos.z
	local here = get_node_raw(rx, ry, rz)
	if here == cid then
		local v = object:get_velocity()
		if not v then return end
		local vx, vy, vz = v.x, v.y, v.z
		local hs = sqrt(vx * vx + vz * vz)
		local cut_h, cut_v = false, false
		if hs > 0.01 then
			local reach = hs * LOOKAHEAD
			if reach < MIN_AHEAD then reach = MIN_AHEAD end
			local k = reach / hs
			if get_node_raw(rx + vx * k, ry, rz + vz * k) ~= cid then
				cut_h = true
			end
		end
		if vy > 0.01 or vy < -0.01 then
			local reach = vy * LOOKAHEAD
			if reach > -MIN_AHEAD and reach < MIN_AHEAD then
				reach = vy > 0 and MIN_AHEAD or -MIN_AHEAD
			end
			if get_node_raw(rx, ry + reach, rz) ~= cid then
				cut_v = true
			end
		end
		if cut_h or cut_v then
			object:set_velocity({
				x = cut_h and 0 or vx,
				y = cut_v and 0 or vy,
				z = cut_h and 0 or vz,
			})
			-- Steered movement keeps its own heading; only a free wander
			-- turns round.
			if cut_h and self.state ~= "attack" and self.state ~= "runaway"
					and not self.following then
				turn_round(self)
			end
		end
		if self.temp then self.temp.grug_swim_scan = nil end
		return
	end
	-- Displaced. An unloaded point (ignore) is left alone: nothing moves there.
	if here == core.CONTENT_IGNORE then
		return
	end
	-- self.temp is runtime-only (never in staticdata).
	self.temp = self.temp or {}
	local temp = self.temp
	local left = (temp.grug_swim_scan or 0) - dtime
	if left > 0 and temp.grug_swim_vel then
		-- Between scans: re-apply the last choice over whatever the native
		-- step wrote.
		temp.grug_swim_scan = left
		local v = temp.grug_swim_vel
		if v.stranded then
			local cur = object:get_velocity()
			object:set_velocity({x = 0,
				y = (cur and cur.y < STRANDED_FALL) and cur.y or STRANDED_FALL, z = 0})
		else
			object:set_velocity(v)
		end
		return
	end
	temp.grug_swim_scan = DISPLACED_SCAN
	local dir, d2 = nearest_medium(rx, ry, rz, cid)
	if dir then
		local d = sqrt(d2)
		local speed = self.walk_velocity or 1
		if speed < 1 then speed = 1 end
		speed = d > 0.001 and speed / d or 0
		local v = {x = dir.x * speed, y = dir.y * speed, z = dir.z * speed}
		temp.grug_swim_vel = v
		object:set_velocity(v)
		return
	end
	temp.grug_swim_vel = {stranded = true}
	local v = object:get_velocity()
	object:set_velocity({x = 0, y = (v and v.y < STRANDED_FALL) and v.y or STRANDED_FALL, z = 0})
	if self.state ~= "flop" and self.state ~= "attack" then
		self.state = "flop"
		self:set_animation("stand")
	end
end

-- Called by grug_mobs.register_mob for a def with `_grug_swimmer = true`,
-- before mobs:register_mob copies the def.
function grug_mobs.prepare_swimmer_def(name, def)
	assert(def.fly and type(def.fly_in) == "string" and def.fly_in ~= "air",
		name .. ": _grug_swimmer needs fly = true and a single fly_in node")
	-- A swimmer never climbs: stepping up a bank level with the water surface
	-- is the first way out of the water (mobs_redo defaults to 1.1).
	assert(def.stepheight == 0, name .. ": a _grug_swimmer must set stepheight = 0")
end

-- Called by grug_mobs.register_mob right after mobs:register_mob.
function grug_mobs.install_swimmer_guard(name)
	local proto = core.registered_entities[name]
	local fly_in = proto.fly_in
	local box = proto.initial_properties.collisionbox
	-- The point mobs_redo's get_nodes reads as standing_in.
	local dy = box[2] + 0.25
	proto._grug_swim_dy = dy
	-- Only the swimmer's own medium counts as swimmable: plants, reeds and
	-- waterlilies are not water (api.lua flight_check would say they are).
	proto.flight_check = function(self)
		return self.standing_in == fly_in
	end
	local native_step = proto.on_step
	proto.on_step = function(self, dtime, moveresult)
		native_step(self, dtime, moveresult)
		grug_mobs.swimmer_guard_step(self, dtime)
	end
	core.register_on_mods_loaded(function()
		medium_id[name] = get_content_id(fly_in)
	end)
end
