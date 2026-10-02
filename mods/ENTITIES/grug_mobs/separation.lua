-- Mob separation and melee knockback (Round 28 rulings 5 and 7,
-- combat_stats.md §3).
--
-- Actors pass through each other (`collide_with_objects = false` since
-- 2026-09-17), so what players see is overlap: a mob standing inside its
-- target, or several mobs stacked on one spot. Both rulings move a mob by a
-- small horizontal POSITION displacement, never a velocity (the attack state
-- writes the velocity every step, ruling 8 removed the pause that used to
-- protect one), and only when the mob's collision box fits at the destination
-- and has a floor under it. Otherwise nothing happens: no pushing into walls
-- (suffocation) or over ledges (fall damage). No pathfinding, no extra
-- per-step scan: the separation check runs once per second per engaged mob.

-- Ruling 7: metres of knockback per second of the swing interval. Knockback
-- per second of fighting is therefore the same for every weapon (dagger 0.7 s
-- -> 0.175 m per hit, sword 1.0 s -> 0.25 m, battle axe 1.4 s -> 0.35 m); the
-- attack-speed affix shortens interval and push together. Tune by feel.
grug_mobs.KNOCKBACK_PER_SECOND = 0.25

-- Tiers a melee swing may push. Elite, rare and boss (and the elite-tier
-- kings) are never pushed; a Kraken-style `knock_back = false` mob neither.
local KNOCKBACK_TIERS = {normal = true, critter = true}

local SEPARATION_INTERVAL = 1 -- seconds, ruling 5: at most 1 Hz
local SEPARATION_STEP_MAX = 0.5 -- metres per separation tick
-- The contact run stops this far outside the target's column, so a step's
-- overshoot (run 4.6 m/s x 0.09 s = 0.41 m) never lands it back inside.
local HOLD_MARGIN = 0.5
local NEIGHBOUR_REACH = 1.5 -- query radius beyond the own radius
local EPS = 0.05

local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max

local function round(v)
	return floor(v + 0.5)
end

-- Horizontal radius of a collision box.
-- A mob's or player's collision box without a get_properties() table per
-- call (mobs/grug_obstacle.lua, Round 30 P2).
local function object_cbox(object)
	return mobs.grug_obstacle.object_cbox(object)
end

local function box_radius(cbox)
	return max(-cbox[1], cbox[4], -cbox[3], cbox[6])
end
grug_mobs.box_radius = box_radius

-- Collision top of a node above its centre, cached per node name: +0.5 for a
-- regular (or unknown-shaped) node, the highest y of a "fixed" collision box
-- (or node box, when a nodebox has no collision box) otherwise. Snow dust
-- (-6/16) and bottom slabs (0) are low; anything else counts as full.
local tops = {}

local function fixed_top(box)
	if box.type ~= "fixed" or type(box.fixed) ~= "table" then
		return 0.5 -- regular, leveled, wallmounted, connected: a full block
	end
	local boxes = type(box.fixed[1]) == "number" and {box.fixed} or box.fixed
	local top
	for _, b in ipairs(boxes) do
		local y = max(b[2], b[5])
		top = top and max(top, y) or y
	end
	return top or 0.5
end

local function collision_top(def)
	local top = tops[def.name]
	if top == nil then
		local box = def.collision_box
		if box == nil and def.drawtype == "nodebox" then
			box = def.node_box
		end
		top = type(box) == "table" and fixed_top(box) or 0.5
		tops[def.name] = top
	end
	return top
end

-- A rotated node keeps its fixed top only when it is turned about the y axis
-- (facedir 0-3, any 4dir); an upside-down slab is a full obstacle.
local function top_kept(def, param2)
	local kind = def.paramtype2
	if kind == "facedir" or kind == "colorfacedir" then
		return (param2 or 0) % 32 < 4
	end
	return kind ~= "wallmounted" and kind ~= "colorwallmounted"
end

-- A walkable node whose top is at or below the feet (+EPS) is ground, not an
-- obstacle: snow dust, or the slab a mob stands on. Deliberately not a
-- centre-height threshold, so a mob on a slab is never pushed half into a
-- full block beside it.
local function low(def, param2, y, feet)
	return top_kept(def, param2) and y + collision_top(def) <= feet + EPS
end

-- A node blocks a body when it is unknown or unloaded, hurts (lava, fire:
-- damage_per_second > 0), or is walkable and reaches above the feet.
local function blocks(def, param2, y, feet)
	if def == nil or def.name == "ignore"
			or (def.damage_per_second or 0) > 0 then
		return true
	end
	return def.walkable ~= false and not low(def, param2, y, feet)
end

local function supports(def)
	return def ~= nil and def.name ~= "ignore" and def.walkable ~= false
end

-- Pure: may a body with collision box `cbox` stand at `dest`? Every node the
-- box overlaps must be free (low ground such as snow dust or a slab under the
-- feet is fine), and there must be walkable ground under the feet at the
-- destination's centre: the node just under the feet, or the one
-- below it (a drop of at most half a node, e.g. off a slab or a snow layer).
-- `def_at(x, y, z)` returns the node definition and param2 at integer node
-- coordinates (nil = unknown/unloaded). Higher partial nodes (a slab beside
-- a mob on stone, an upside-down slab, a stair) block: no displacement there.
function grug_mobs.box_fits_at(dest, cbox, def_at)
	local feet = dest.y + cbox[2]
	local x0, x1 = round(dest.x + cbox[1] + EPS), round(dest.x + cbox[4] - EPS)
	local y0, y1 = round(feet + EPS), round(dest.y + cbox[5] - EPS)
	local z0, z1 = round(dest.z + cbox[3] + EPS), round(dest.z + cbox[6] - EPS)
	for x = x0, x1 do
		for y = y0, y1 do
			for z = z0, z1 do
				local def, param2 = def_at(x, y, z)
				if blocks(def, param2, y, feet) then
					return false
				end
			end
		end
	end
	local cx, cz = round(dest.x), round(dest.z)
	return supports(def_at(cx, round(feet - EPS), cz))
		or supports(def_at(cx, round(feet - 0.5 - EPS), cz))
end

local function engine_def_at(x, y, z)
	local node = core.get_node_or_nil({x = x, y = y, z = z})
	if not node then
		return nil
	end
	return core.registered_nodes[node.name], node.param2
end

-- Move the mob by (dx, dz) when its box fits there; true when it moved.
function grug_mobs.displace_mob(self, dx, dz)
	local object = self.object
	local pos = object and object:get_pos()
	if not pos then
		return false
	end
	local dest = {x = pos.x + dx, y = pos.y, z = pos.z + dz}
	if not grug_mobs.box_fits_at(dest, object_cbox(object), engine_def_at) then
		return false
	end
	object:move_to(dest, true)
	return true
end

-- Pure: the knockback vector for a hit from `from` on a mob at `pos` with a
-- swing interval of `interval` seconds; nil when the two stand on one spot.
function grug_mobs.knockback_offset(from, pos, interval)
	local dx, dz = pos.x - from.x, pos.z - from.z
	local length = sqrt(dx * dx + dz * dz)
	if length < 1e-3 or not interval or interval <= 0 then
		return nil
	end
	local distance = grug_mobs.KNOCKBACK_PER_SECOND * interval
	return dx / length * distance, dz / length * distance
end

function grug_mobs.can_be_knocked_back(self)
	return self.knock_back ~= false
		and KNOCKBACK_TIERS[self._grug_tier or "normal"] == true
end

-- Ruling 7, called by the GRUG PATCH in mobs/api.lua on_punch for an
-- authoritative player melee swing that landed. `interval` is that swing's
-- full punch interval (the weapon's, after the attack-speed affix).
function grug_mobs.melee_knockback(self, hitter, interval)
	if not grug_mobs.can_be_knocked_back(self) then
		return false
	end
	local from = hitter and hitter:get_pos()
	local pos = self.object and self.object:get_pos()
	if not from or not pos then
		return false
	end
	local dx, dz = grug_mobs.knockback_offset(from, pos, interval)
	if not dx then
		return false
	end
	return grug_mobs.displace_mob(self, dx, dz)
end

-- Pure: the push out of the target's column, or nil when the mob is outside
-- it. `hold` = own radius + target radius. A mob exactly on the target's
-- centre backs off along `back_x, back_z` (unit vector).
function grug_mobs.column_push(pos, target_pos, hold, back_x, back_z)
	local dx, dz = pos.x - target_pos.x, pos.z - target_pos.z
	local length = sqrt(dx * dx + dz * dz)
	if length >= hold then
		return nil
	end
	local step = min(hold - length, SEPARATION_STEP_MAX)
	if length < 1e-3 then
		return back_x * step, back_z * step
	end
	return dx / length * step, dz / length * step
end

-- Pure: the sideways drift away from an overlapping neighbour. "Sideways" is
-- perpendicular to the line to the own target, toward the side away from the
-- neighbour; `tie` (+1/-1) picks a side when both stand on that line.
function grug_mobs.sideways_push(pos, target_pos, other_pos, overlap, tie)
	local tx, tz = target_pos.x - pos.x, target_pos.z - pos.z
	local length = sqrt(tx * tx + tz * tz)
	if length < 1e-3 or overlap <= 0 then
		return nil
	end
	local px, pz = -tz / length, tx / length
	local side = (pos.x - other_pos.x) * px + (pos.z - other_pos.z) * pz
	if side < 0 or (side == 0 and tie < 0) then
		px, pz = -px, -pz
	end
	local step = min(overlap * 0.5 + EPS, SEPARATION_STEP_MAX)
	return px * step, pz * step
end

-- Ruling 5, the contact run's stop: true while a visible target's column is
-- closer than the hold distance (radii + HOLD_MARGIN). The hold is cached by
-- separation_step; before its first tick the run is unchanged.
function grug_mobs.holds_column(self, pos, target_pos)
	local hold = self.temp and self.temp.grug_separation_hold
	if not hold then
		return false
	end
	local dx, dz = pos.x - target_pos.x, pos.z - target_pos.z
	hold = hold + HOLD_MARGIN
	return dx * dx + dz * dz <= hold * hold
end

local function bodies_overlap_vertically(pos, cbox, other_pos, other_cbox)
	return pos.y + cbox[2] < other_pos.y + other_cbox[5]
		and other_pos.y + other_cbox[2] < pos.y + cbox[5]
end

-- Ruling 5, called once per server step from the GRUG PATCH in the dogfight
-- branch of mobs/api.lua do_states for ground melee mobs; acts at most once
-- per SEPARATION_INTERVAL. First: out of the target's own column. Otherwise:
-- away from one overlapping engaged neighbour, sideways.
function grug_mobs.separation_step(self, dtime, pos, target_pos)
	local state = self.temp
	local target = self.attack
	if not state or not target then
		return
	end
	state.grug_separation_timer = (state.grug_separation_timer
		or SEPARATION_INTERVAL) + dtime
	if state.grug_separation_timer < SEPARATION_INTERVAL then
		return
	end
	state.grug_separation_timer = 0

	-- Boxes from the mobs' runtime field and the per-step player cache, not
	-- a get_properties() table per call (Round 30 P2, perf review 2026-10 #6).
	local cbox = object_cbox(self.object)
	local radius = box_radius(cbox)
	local target_box = object_cbox(target)
	local target_radius = target_box and box_radius(target_box) or 0.3
	local hold = radius + target_radius
	state.grug_separation_hold = hold

	local yaw = self.object:get_yaw() or 0
	-- Backwards along the facing (mobs_redo: forward = (-sin yaw, cos yaw)).
	local dx, dz = grug_mobs.column_push(pos, target_pos, hold,
		math.sin(yaw), -math.cos(yaw))
	if dx then
		grug_mobs.displace_mob(self, dx, dz)
		return
	end

	for _, object in ipairs(core.get_objects_inside_radius(pos,
			radius + NEIGHBOUR_REACH)) do
		local ent = object ~= self.object and object:get_luaentity()
		if ent and ent._cmi_is_mob and ent.state == "attack" then
			local other_pos = object:get_pos()
			local other_cbox = other_pos and object_cbox(object)
			if other_cbox and bodies_overlap_vertically(pos, cbox, other_pos,
					other_cbox) then
				local ox, oz = pos.x - other_pos.x, pos.z - other_pos.z
				local overlap = radius + box_radius(other_cbox)
					- sqrt(ox * ox + oz * oz)
				if overlap > 0 then
					dx, dz = grug_mobs.sideways_push(pos, target_pos, other_pos,
						overlap, math.random(2) == 1 and 1 or -1)
					if dx then
						grug_mobs.displace_mob(self, dx, dz)
					end
					return
				end
			end
		end
	end
end
