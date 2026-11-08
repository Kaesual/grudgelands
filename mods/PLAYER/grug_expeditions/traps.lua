-- Traps (Round 72): the two trap types of every Expedition and the marked-spot
-- helper a boss uses, one module for all templates. Rules and numbers:
-- docs/design/expeditions.md section "Traps"; the template's `trap` lines:
-- docs/technical/expedition-template-format.md.
--
-- CANDIDATES come from the template (template.lua's `trap` lines). Each group arms
-- `pick` of its lines, drawn at random without replacement when the run is ready,
-- so once per creation. The choice and the marks of fired floor traps belong to the
-- run's state here: a wipe touches neither, the run's end drops both, a restart
-- (which ends every run) forgets them, and the next preparation clears the box.
--
-- FLOOR TRAP: invisible until it first fires. A living player of the run whose feet
--   come within TRIGGER_RADIUS of its cell, on the floor, starts it: the warning ring
--   (radius RADIUS) for WARNING seconds, then the hit: DAMAGE_SHARE of the run level's
--   neutral pool (grug_core.base_pool) to every player within RADIUS of it and in
--   sight of it, through dodge, armor and absorb like a hit. It rearms REARM seconds
--   after the hit. From its first hit a mark node shows its cell for the rest of the run.
-- WALL TRAP: a fireball every `period` seconds from `offset` after readiness, along
--   its axis at SPEED, whoever stands where: no targeting. The first walkable node
--   ahead stops it; a player in its way bursts it: the same damage to every player
--   within RADIUS. A shot with nobody of the run within LAUNCH_RANGE of the muzzle is
--   skipped, the timing kept.
-- STRIKE (strike/cancel): the floor trap's ring and hit on one position, once.
--
-- PLAYERS ONLY: no mob is ever looked at. The trigger and the fireball test the run's
-- players inside, the hit goes to players. No knockback (set_hp, no puncher), no
-- terrain damage, silent. Particles: 16 per warning, 8 per hit or burst, at most 8
-- live tail particles per fireball; a mark is a node, nothing sent again.
--
-- COST: one TICK pass, only while a run with traps has a player inside: its players
-- against its armed floor traps, and its wall schedule. A fireball is an entity, never
-- saved, whose step tests the run's players inside.
local M = grug_expeditions
local T = {}
M.traps = T

T.TRIGGER_RADIUS = 0.6
T.RADIUS = 2
T.WARNING = 1.5
T.REARM = 10
T.DAMAGE_SHARE = 0.45
T.SPEED = 8
T.LAUNCH_RANGE = 32
-- The longest flight in nodes, when no walkable node comes first.
T.MAX_RANGE = 64

local TICK = 0.2
-- A due shot later than this (the pass slept: nobody was inside) is skipped.
local STALE = 0.5
-- Feet this far above or below a floor trap's floor tread on it: a jump clears it.
local FOOT_ABOVE, FOOT_BELOW = 0.6, 0.3
-- A move longer than this between two passes is a teleport or a respawn, no walk.
local WALK_LIMIT = 4
local BODY = 1.77
local BALL = 0.4
local REACH = BALL + 0.3
local TAIL_EVERY = 0.125
local MARK = "grug_expeditions:trap_mark"
local FIREBALL = "grug_expeditions:trap_fireball"
local COLOR = "#b4473c"
local FIRE = "mobs_fire_particle.png"
local AXES = dofile(core.get_modpath(core.get_current_modname()) .. "/template.lua").AXES

-- ---- Look ----------------------------------------------------------------------

local register = grug_core.particles.register
-- The warning: a muted red ring on the radius at the floor, living the whole delay
-- (the area warning's pattern in another colour, under its own id).
register("expedition_trap_warning", function(frame)
	local life = frame.time or T.WARNING
	return {{kind = "single", n = 16, at = "target", color = COLOR, mote = true, fade = false,
		shape = {"disc", {0, 0.15, 0}, frame.reach or T.RADIUS, true}, exp = {life, life},
		size = {3, 3}, glow = 12}}
end, {reach = T.RADIUS, time = T.WARNING})
-- The hit: a ring out to the radius.
register("expedition_trap_hit", function()
	return {{kind = "single", n = 8, at = "target", color = "#d0503a", mote = true,
		blend = "add", shape = {"disc", {0, 0.2, 0}, 0.4, true}, radial = "reach",
		exp = {0.35, 0.35}, size = {3, 3.5}, glow = 14}}
end, {reach = T.RADIUS})
-- A fireball's tail, one particle at a time.
register("expedition_fireball_tail", {{kind = "single", n = 1, at = "target", tex = FIRE,
	blend = "add", shape = {"sphere", {0, 0, 0}, 0.15, false},
	vel = {{-0.3, -0.2, -0.3}, {0.3, 0.4, 0.3}}, exp = {0.5, 0.8}, size = {2.5, 3.5}, glow = 14}})
-- Its burst on a player (out to the radius) or at the stone (frame.reach smaller).
register("expedition_fireball_burst", function()
	return {{kind = "single", n = 8, at = "target", tex = FIRE, blend = "add",
		shape = {"sphere", {0, 0, 0}, 0.2, true}, radial = "reach", exp = {0.4, 0.4},
		size = {2.5, 3.5}, glow = 14}}
end, {reach = T.RADIUS})

local function play(id, pos, reach, time)
	grug_core.particles.play(id, {target = pos, reach = reach, time = time})
end

-- The mark of a fired floor trap: a flat red glow on the floor, in the trap's colour.
core.register_node(MARK, {
	description = "Trap",
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.45, -0.5, -0.45, 0.45, -0.47, 0.45}},
	tiles = {"grug_core_mote.png^[multiply:" .. COLOR},
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 3,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = false,
	floodable = false,
	is_ground_content = false,
	drop = "",
	groups = {not_in_creative_inventory = 1},
	on_blast = function() end,
})

-- ---- Geometry ------------------------------------------------------------------

-- The node a position lies in: floor(v + 0.5), also below y 0 (the boxes lie there).
local function cell_of(pos)
	return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5), z = math.floor(pos.z + 0.5)}
end

-- Unloaded counts as solid: nothing flies or hits through what is not there.
local function solid(pos)
	local node = core.get_node_or_nil(cell_of(pos))
	if not node then return true end
	local def = core.registered_nodes[node.name]
	return not def or def.walkable ~= false
end

-- No walkable node between a and b: a torch or a mark stops no hit.
local function clear_between(a, b)
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	local steps = math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / 0.25)
	for i = 1, steps - 1 do
		local f = i / steps
		if solid({x = a.x + dx * f, y = a.y + dy * f, z = a.z + dz * f}) then return false end
	end
	return true
end

-- The distance from `point` to a player's body (a vertical line from the feet) and
-- the body's nearest point.
local function body_distance(point, feet)
	local y = math.max(feet.y, math.min(feet.y + BODY, point.y))
	local near = {x = feet.x, y = y, z = feet.z}
	return vector.distance(point, near), near
end

-- How far a fireball from `muzzle` flies along `axis` before its front meets a
-- walkable node.
local function flight_range(muzzle, axis)
	local dir = AXES[axis]
	local a = dir.x ~= 0 and "x" or "z"
	local sign = dir[a]
	local cell = cell_of(muzzle)
	for k = 1, T.MAX_RANGE do
		local at = {x = cell.x, y = cell.y, z = cell.z}
		at[a] = cell[a] + sign * k
		if solid(at) then
			return math.max(0, sign * (at[a] - sign * 0.5 - muzzle[a]) - BALL)
		end
	end
	return T.MAX_RANGE
end

local function along(row, s)
	return vector.add(row.muzzle, vector.multiply(row.dir, s))
end

-- Where along a fireball's flight from s0 to s1 it meets a player standing at `feet`,
-- or nil.
local function crossing(row, s0, s1, feet)
	local y = row.muzzle.y
	if y < feet.y - BALL or y > feet.y + BODY + BALL then return nil end
	local a = row.dir.x ~= 0 and "x" or "z"
	local b = a == "x" and "z" or "x"
	local side = math.abs(feet[b] - row.muzzle[b])
	if side > REACH then return nil end
	local at = row.dir[a] * (feet[a] - row.muzzle[a])
	local half = math.sqrt(REACH * REACH - side * side)
	if at + half < s0 or at - half > s1 then return nil end
	return math.max(s0, at - half)
end

-- ---- Damage --------------------------------------------------------------------

-- The hit of either trap and of a strike at a run level, before mitigation.
function T.damage(level)
	return math.floor(T.DAMAGE_SHARE * grug_core.base_pool(level) + 0.5)
end

-- Armor here, then the central modifier: dodge, absorb, death, as a mob's hit.
local function hurt(player, amount, level)
	local hp = player:get_hp()
	if hp <= 0 then return end
	local applied = grug_core.apply_player_armor(player, amount, level)
	if applied < 1 then return end
	player:set_hp(hp - applied, {type = "punch",
		custom_type = grug_core.ARMOR_APPLIED_CUSTOM_TYPE})
end

-- Every living player of the run inside within RADIUS of `point` and in sight of it.
local function blast(run, point)
	local amount = T.damage(run.level)
	for name in pairs(run.inside) do
		local player = core.get_player_by_name(name)
		if player and player:get_hp() > 0 then
			local distance, near = body_distance(point, player:get_pos())
			if distance <= T.RADIUS and clear_between(point, near) then
				hurt(player, amount, run.level)
			end
		end
	end
end

-- The floor's hit: the ring's centre half a node above the floor.
local function land(run, feet)
	play("expedition_trap_hit", feet, T.RADIUS)
	blast(run, {x = feet.x, y = feet.y + 0.5, z = feet.z})
end

-- ---- Runs ----------------------------------------------------------------------

local states = {} -- run -> {run, floors, walls, last}
local ticking = false

-- The armed candidates: per group, `pick` of its lines at random, in file order of
-- the groups.
local function choose(rows)
	local order, groups = {}, {}
	for _, row in ipairs(rows) do
		if not groups[row.group] then
			groups[row.group] = {}
			order[#order + 1] = row.group
		end
		table.insert(groups[row.group], row)
	end
	local chosen = {}
	for _, name in ipairs(order) do
		local lines = groups[name]
		for i = 1, lines[1].pick do
			local j = math.random(i, #lines)
			lines[i], lines[j] = lines[j], lines[i]
			chosen[#chosen + 1] = lines[i]
		end
	end
	return chosen
end

local function absolute(minp, pos)
	return {x = minp.x + pos.x, y = minp.y + pos.y, z = minp.z + pos.z}
end

local function fire_floor(state, trap)
	trap.firing = true
	play("expedition_trap_warning", trap.feet, T.RADIUS, T.WARNING)
	core.after(T.WARNING, function()
		if states[state.run] ~= state then return end
		trap.firing = false
		trap.armed_at = grug_core.mono_time() + T.REARM
		land(state.run, trap.feet)
		if not trap.revealed then
			trap.revealed = true
			if core.get_node(trap.cell).name == "air" then core.set_node(trap.cell, {name = MARK}) end
		end
	end)
end

-- Did the feet walk from p0 to p1 over the trap? A way from the air (a jump over
-- it) counts only where it ends.
local function on_floor(trap, pos)
	local height = pos.y - trap.feet.y
	return height >= -FOOT_BELOW and height <= FOOT_ABOVE
end

local function treads(trap, p0, p1)
	if not on_floor(trap, p1) then return false end
	if not on_floor(trap, p0) then p0 = p1 end
	local fx, fz = trap.feet.x, trap.feet.z
	local ax, az = p0.x, p0.z
	local bx, bz = p1.x - ax, p1.z - az
	local length2 = bx * bx + bz * bz
	local t = 0
	if length2 > 0 then t = math.max(0, math.min(1, ((fx - ax) * bx + (fz - az) * bz) / length2)) end
	local dx, dz = ax + bx * t - fx, az + bz * t - fz
	return dx * dx + dz * dz <= T.TRIGGER_RADIUS * T.TRIGGER_RADIUS
end

local function launch(state, wall)
	local range = flight_range(wall.muzzle, wall.axis)
	if range <= 0 then return end
	local object = core.add_entity(wall.muzzle, FIREBALL)
	local ent = object and object:get_luaentity()
	if not ent then return end
	ent._state, ent._wall, ent._range = state, wall, range
	ent._age, ent._done, ent._tail = 0, 0, 0
	object:set_velocity(vector.multiply(wall.dir, T.SPEED))
end

local function someone_near(players, pos)
	for _, row in ipairs(players) do
		if vector.distance(row.pos, pos) <= T.LAUNCH_RANGE then return true end
	end
	return false
end

local function tick_run(state, now)
	local players = {}
	for name in pairs(state.run.inside) do
		local player = core.get_player_by_name(name)
		if player and player:get_hp() > 0 then
			players[#players + 1] = {name = name, pos = player:get_pos()}
		end
	end
	for _, trap in ipairs(state.floors) do
		if not trap.firing and now >= trap.armed_at then
			for _, row in ipairs(players) do
				local before = state.last[row.name]
				if not before or vector.distance(before, row.pos) > WALK_LIMIT then before = row.pos end
				if treads(trap, before, row.pos) then
					fire_floor(state, trap)
					break
				end
			end
		end
	end
	state.last = {}
	for _, row in ipairs(players) do state.last[row.name] = row.pos end
	for _, wall in ipairs(state.walls) do
		if now >= wall.next_at then
			if now - wall.next_at < STALE and someone_near(players, wall.muzzle) then
				launch(state, wall)
			end
			wall.next_at = wall.next_at + wall.period * (math.floor((now - wall.next_at) / wall.period) + 1)
		end
	end
end

local tick
local function start_tick()
	if ticking then return end
	ticking = true
	core.after(TICK, tick)
end

tick = function()
	local now = grug_core.mono_time()
	local busy = false
	for run, state in pairs(states) do
		if next(run.inside) then
			busy = true
			tick_run(state, now)
		end
	end
	if busy then
		core.after(TICK, tick)
	else
		ticking = false
	end
end

M.register_on_ready(function(run)
	local tpl = M.templates[M.definition(run.expedition).template]
	if not tpl.traps or #tpl.traps == 0 then return end
	local now = grug_core.mono_time()
	local state = {run = run, floors = {}, walls = {}, last = {}}
	for _, row in ipairs(choose(tpl.traps)) do
		local pos = absolute(run.minp, row.pos)
		if row.kind == "floor" then
			state.floors[#state.floors + 1] = {group = row.group, cell = pos,
				feet = {x = pos.x, y = pos.y - 0.5, z = pos.z}, armed_at = 0}
		else
			state.walls[#state.walls + 1] = {group = row.group, muzzle = pos, axis = row.axis,
				dir = AXES[row.axis], period = row.period, next_at = now + row.offset}
		end
	end
	states[run] = state
end)
M.register_on_enter(start_tick)
M.register_on_end(function(run) states[run] = nil end)

-- ---- The fireball --------------------------------------------------------------

local function step(self, dtime)
	local state, wall = self._state, self._wall
	if not state or states[state.run] ~= state then
		self.object:remove()
		return
	end
	local s0 = self._done
	self._age = self._age + dtime
	local s1 = math.min(self._range, self._age * T.SPEED)
	local hit
	for name in pairs(state.run.inside) do
		local player = core.get_player_by_name(name)
		if player and player:get_hp() > 0 then
			local s = crossing(wall, s0, s1, player:get_pos())
			if s and (not hit or s < hit) then hit = s end
		end
	end
	if hit then
		local at = along(wall, hit)
		play("expedition_fireball_burst", at, T.RADIUS)
		blast(state.run, at)
		self.object:remove()
		return
	end
	if s1 >= self._range then
		play("expedition_fireball_burst", along(wall, s1), 0.8)
		self.object:remove()
		return
	end
	self._done = s1
	self._tail = self._tail - dtime
	if self._tail <= 0 then
		self._tail = math.max(0, self._tail + TAIL_EVERY)
		play("expedition_fireball_tail", along(wall, s1))
	end
end

core.register_entity(FIREBALL, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		visual = "sprite",
		textures = {FIRE},
		visual_size = {x = 0.9, y = 0.9},
		glow = 14,
		collisionbox = {0, 0, 0, 0, 0, 0},
		selectionbox = {0, 0, 0, 0, 0, 0},
	},
	on_step = step,
})

-- ---- Reading and the helper ------------------------------------------------------

-- The armed traps of a run, in map coordinates, or nil without traps:
-- {floor = {{group, cell, revealed}, ...}, wall = {{group, muzzle, axis}, ...}}.
function T.chosen(run)
	local state = states[run]
	if not state then return nil end
	local out = {floor = {}, wall = {}}
	for _, trap in ipairs(state.floors) do
		out.floor[#out.floor + 1] = {group = trap.group, cell = vector.copy(trap.cell),
			revealed = trap.revealed == true}
	end
	for _, wall in ipairs(state.walls) do
		out.wall[#out.wall + 1] = {group = wall.group, muzzle = vector.copy(wall.muzzle),
			axis = wall.axis}
	end
	return out
end

-- The marked-spot helper: the floor trap's ring at `pos` (a player's feet) now and
-- its hit there WARNING seconds later, once, for the run's players. Returns a handle
-- for cancel(handle): a reset or a death of the caller takes the hit back (the ring's
-- particles run out by themselves). The run's end cancels it too.
function T.strike(run, pos)
	local handle = {}
	local feet = {x = pos.x, y = pos.y, z = pos.z}
	play("expedition_trap_warning", feet, T.RADIUS, T.WARNING)
	core.after(T.WARNING, function()
		if handle.cancelled or run.state == "ended" then return end
		handle.done = true
		land(run, feet)
	end)
	return handle
end

function T.cancel(handle)
	if handle then handle.cancelled = true end
end
