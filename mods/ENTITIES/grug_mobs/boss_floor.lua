--
-- Kings, Generals and bosses: the reset rules (Round 72 BOSSRESET, round72-plan.md
-- §2.3, the user's rulings of 2026-11-07, which replace the Round 30 king give-up;
-- combat_stats.md §4 "Kings and bosses"). The outcome of every rule here is one
-- function, grug_mobs.reset_home (aggro.lua): heal, threat and ledger cleared,
-- retinue restored, the evade to the seat from any distance.
--
-- WHO. `reset_kind` below:
--   floor  the kings and Generals (`_grug_royal_king`) and an Expedition's boss
--          (an elite with a ledger id, `_grug_expedition` and `_grug_boss_id`);
--   clock  the rift boss: the 15 s rule only. Its ground can change (the crack), so
--          it stays on the chase leash and the navigation's give-up (aggro.lua).
-- Dragons keep their arena edge, royal guards follow their leader, elites and every
-- other mob keep their rules: kiting is part of the game there.
--
-- THE BOSS FLOOR (the user's idea). One flood fill from the seat (`_grug_home`) over
-- the cells the boss's own body stands in, with the navigation's cell test
-- (mobs/grug_nav.lua `nav.cell`: head room of the body's height, ground below,
-- unknown and damaging nodes blocked), its step up and its drop down, diagonals past
-- an open corner and the body's width as the path check fits it; doors count as
-- passable (a king stuck at a shut one falls to the 15 s rule). Bounded by the range:
-- a king's or General's leash radius round the seat (horizontal, the same height band
-- up and down), an Expedition boss's room (grug_mobs.expedition_boss_room, the
-- template's envelope, grug_expeditions/encounters.lua). Computed once per boss and
-- session, FILL_CELLS cells a server step, from the boss's first step on; the area is
-- loaded first (core.load_area, never generated). A fill that met a node not there
-- (a neighbouring chunk not generated yet on a fresh map) is not used and runs again
-- RETRY seconds later. Floors above each other and steps are why it is a fill and not
-- a plan.
--
-- Once a second: is the current target's ground in the set, or within the boss's
-- reach of a cell of it? No means "no way" or "out of range", one case. The floor only
-- decides: walking stays with grug_nav, whose give-up no longer drops anything for
-- these bosses (aggro.lua give_up_target). Without a floor (none computed yet, a seat
-- the body does not stand on, an Expedition without an envelope) the navigation's
-- give-up is the "no way".
--
-- THE ONE-WAY WINDOW. The current target who has no way or left the range (also by a
-- teleport), or who logged out, has left; a death is no leaving, and a player the
-- boss turned from while they stood on the floor (a Taunt, a threat switch) cannot
-- leave any more (watched every step). Their threat goes to zero at
-- once, they are no target (aggro.lua's give-up veto keeps sight from taking them
-- again: 8 nodes or 15 s), their engagement goes, and an Expedition boss's list loses
-- them. With no other player engaged the reset comes at once. Otherwise only a Taunt
-- (grug_core.taunt) within TAUNT_FORCE_TIME keeps the fight: by anyone but the one who
-- left, after the window opened. Walking back saves nothing. Zero threat alone is not
-- enough, or two players could take turns running out to recover. The window is not
-- an evade: the boss stays attackable and tauntable in it.
--
-- THE 15 S RULE. A boss in a fight (a player target or an engagement) who made no
-- attack for QUIET seconds resets. An attack is a melee swing at a target in reach, a
-- shot with sight or a signature that had a player in its area, a dodged one too: a
-- hit of the boss or of its projectile on a player (grug_core.mark_player_hit, before
-- the dodge roll) or a projectile it locks on a target in sight
-- (grug_core.actor_projectile_lock, its shot range and sight test). A cast alone is
-- none: a king casts Shatter whenever he has a target. Traps are nobody's attack.
-- grug_mobs.boss_attacked(self) is the hook for an attack of another kind.
--
-- Cost: a per-step field test for every mob with a boss id; for these bosses one
-- timer and one target name compare per step, once a second a field test or two,
-- and the floor test only while a player is their target (one table lookup on the
-- floor, a few hundred off it). The
-- fill runs once per boss and session. Everything is runtime state: nothing is saved.
--
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local nav = mobs.grug_nav

local QUIET = 15 -- s without an attack (§2.3)
local CHECK = 1 -- s between floor tests and clock checks
local FILL_CELLS = 400 -- floor cells a server step expands
local RETRY = 10 -- s before an incomplete fill runs again
local SEAT_BAND = {0, 1, -1, 2, -2} -- the seat's own cell first

local F = {}
grug_mobs.boss_floor = F

-- The floor's own rules (pure: nav.cell and the node reader are the world).
local function key(x, y, z)
	return (x + 32768) * 4294967296 + (y + 32768) * 65536 + (z + 32768)
end
F.key = key

-- A door's cells (doors/init.lua: the leaf and the hidden top are walkable).
local function door(name)
	local doors = rawget(_G, "doors")
	return name == "doors:hidden"
		or (doors ~= nil and doors.registered_doors ~= nil and doors.registered_doors[name] == true)
end

-- 1: a body may occupy the cell, 2: it can stand on it (both: wading water). Each node
-- is read once per fill. A node not loaded (or not generated) blocks, as it does the
-- navigation, and marks the fill `unknown`: such a floor is not used (below).
local function class(st, x, y, z)
	local k = key(x, y, z)
	local c = st.memo[k]
	if c then return c end
	local open, ground = nav.cell(st.body, x, y, z)
	if not open then
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		local name = node and node.name
		if not name or name == "ignore" then
			st.unknown = true
		elseif door(name) then
			open, ground = true, false
		end
	end
	c = (open and 1 or 0) + (ground and 2 or 0)
	st.memo[k] = c
	return c
end

local function open_column(st, x, y, z)
	for k = 0, st.body.head - 1 do
		if class(st, x, y + k, z) % 2 == 0 then return false end
	end
	return true
end

-- grug_nav's fit: a body wider than a node needs a 2x2 block, a wider one every cell
-- round it.
local BLOCKS = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local function fits(st, x, y, z)
	local width = st.body.width
	if width <= 1 then return true end
	if width <= 2 then
		for i = 1, #BLOCKS do
			local bx, bz = BLOCKS[i][1], BLOCKS[i][2]
			if open_column(st, x + bx, y, z) and open_column(st, x, y, z + bz)
					and open_column(st, x + bx, y, z + bz) then
				return true
			end
		end
		return false
	end
	local r = ceil(st.body.hw - 0.5)
	for dx = -r, r do
		for dz = -r, r do
			if (dx ~= 0 or dz ~= 0) and not open_column(st, x + dx, y, z + dz) then
				return false
			end
		end
	end
	return true
end

local function stands(st, x, y, z)
	return open_column(st, x, y, z) and class(st, x, y - 1, z) >= 2 and fits(st, x, y, z)
end

-- Where a step from height y into column (x, z) lands, as grug_nav's walkable line
-- settles it: level or down to the drop on an open column, else up to the step (the
-- path check's: the higher of step and jump), or nil.
local function landing(st, x, y, z)
	if open_column(st, x, y, z) then
		for d = 0, st.body.drop do
			local c = class(st, x, y - 1 - d, z)
			if c >= 2 then return y - d end
			if c % 2 == 0 then return nil end
		end
		return nil
	end
	for up = 1, st.up do
		if open_column(st, x, y + up, z) then
			return class(st, x, y + up - 1, z) >= 2 and y + up or nil
		end
	end
	return nil
end

local function inside(b, x, y, z)
	if y < b.y0 or y > b.y1 then return false end
	if b.r then
		local dx, dz = x - b.cx, z - b.cz
		return dx * dx + dz * dz <= b.r * b.r
	end
	return x >= b.x0 and x <= b.x1 and z >= b.z0 and z <= b.z1
end

local function add(st, x, y, z)
	st.cells[key(x, y, z)] = true
	st.count = st.count + 1
	local q, n = st.queue, st.tail
	q[n + 1], q[n + 2], q[n + 3] = x, y, z
	st.tail = n + 3
end

-- A fill from `seat` (a feet position) for `body` (nav.body) inside `bounds`
-- ({cx, cz, r} or {x0, x1, z0, z1}, both with y0, y1). `failed` when the body
-- stands nowhere near the seat.
function F.new(seat, body, bounds)
	local st = {body = body, bounds = bounds, up = max(body.step, body.jump),
		cells = {}, count = 0, queue = {}, head = 1, tail = 0, memo = {}, steps = 0}
	local sx, sy, sz = floor(seat.x + 0.5), floor(seat.y + 0.55), floor(seat.z + 0.5)
	for _, dy in ipairs(SEAT_BAND) do
		if inside(bounds, sx, sy + dy, sz) and stands(st, sx, sy + dy, sz) then
			add(st, sx, sy + dy, sz)
			break
		end
	end
	if st.count == 0 then
		st.done, st.failed, st.memo, st.body = true, true, nil, nil
	end
	return st
end

local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

-- Expands up to `budget` cells; true once the fill is done.
function F.step(st, budget)
	if st.done then return true end
	st.steps = st.steps + 1
	local q, cells, b = st.queue, st.cells, st.bounds
	while budget > 0 do
		local h = st.head
		if h > st.tail then
			st.done, st.memo, st.body, st.queue = true, nil, nil, nil
			return true
		end
		local x, y, z = q[h], q[h + 1], q[h + 2]
		q[h], q[h + 1], q[h + 2] = nil, nil, nil
		st.head = h + 3
		budget = budget - 1
		for i = 1, #DIRS do
			local dx, dz = DIRS[i][1], DIRS[i][2]
			local nx, nz = x + dx, z + dz
			local ny = landing(st, nx, y, nz)
			if ny and inside(b, nx, ny, nz) and not cells[key(nx, ny, nz)]
					and (dx == 0 or dz == 0 or open_column(st, x, max(y, ny), nz)
						or open_column(st, nx, max(y, ny), z))
					and fits(st, nx, ny, nz) then
				add(st, nx, ny, nz)
			end
		end
	end
	return false
end

-- Whether a body at feet position `pos` stands on the floor or within `reach` of a
-- cell of it (from that cell's feet point).
function F.holds(cells, pos, reach)
	local x, y, z = floor(pos.x + 0.5), floor(pos.y + 0.55), floor(pos.z + 0.5)
	if cells[key(x, y, z)] then return true end
	local r, r2 = ceil(reach), reach * reach
	for dy = -r, r do
		for dx = -r, r do
			for dz = -r, r do
				if cells[key(x + dx, y + dy, z + dz)] then
					local ex, ey, ez = x + dx - pos.x, y + dy - 0.5 - pos.y, z + dz - pos.z
					if ex * ex + ey * ey + ez * ez <= r2 then return true end
				end
			end
		end
	end
	return false
end

--
-- The floors of this session, by boss id (a king's and a General's seat, an
-- Expedition run's boss). Read by the probe: count, steps, us (the fill's own time).
--
local floors = {}
grug_mobs.boss_floors = floors

function grug_mobs.boss_floor_forget(id)
	if id then floors[id] = nil end
end

-- The fill's bounds round `home`, or nil (no range known).
local function bounds_of(self, home)
	if self._grug_royal_king then
		local r = self._grug_leash_range or grug_mobs.LEASH_RANGE
		return {cx = floor(home.x + 0.5), cz = floor(home.z + 0.5), r = r,
			y0 = floor(home.y + 0.5) - r, y1 = floor(home.y + 0.5) + r}
	end
	return grug_mobs.expedition_boss_room and grug_mobs.expedition_boss_room(self) or nil
end

local function load_bounds(b)
	if b.r then
		core.load_area({x = b.cx - b.r, y = b.y0, z = b.cz - b.r},
			{x = b.cx + b.r, y = b.y1, z = b.cz + b.r})
	else
		core.load_area({x = b.x0, y = b.y0, z = b.z0}, {x = b.x1, y = b.y1, z = b.z1})
	end
end

-- This boss's floor entry, its fill started or stepped; `cells` once it is ready.
local function floor_entry(self)
	local id, home = self._grug_boss_id, self._grug_home
	if not id or not home then return nil end
	local entry = floors[id]
	if entry and entry.x == home.x and entry.y == home.y and entry.z == home.z then
		if entry.fill then
			local t0 = core.get_us_time()
			local done = F.step(entry.fill, FILL_CELLS)
			entry.us = entry.us + core.get_us_time() - t0
			if done then
				local fill = entry.fill
				entry.fill, entry.count, entry.steps = nil, fill.count, fill.steps
				if fill.unknown then
					entry.retry = grug_core.mono_time() + RETRY
				elseif not fill.failed then
					entry.cells = fill.cells
				end
				core.log("action", ("[grug_mobs] boss floor %s: %d cells in %d steps, %d us%s")
					:format(id, entry.count, entry.steps, entry.us,
						fill.unknown and ", unloaded nodes met: not used, again later" or ""))
			end
		end
		if not (entry.retry and grug_core.mono_time() >= entry.retry) then return entry end
	end
	entry = {x = home.x, y = home.y, z = home.z, us = 0, count = 0}
	floors[id] = entry
	local bounds = bounds_of(self, home)
	if not bounds then return entry end
	local t0 = core.get_us_time()
	load_bounds(bounds)
	entry.fill = F.new(home, nav.body(self), bounds)
	entry.us = core.get_us_time() - t0
	return entry
end

-- The ready floor of this boss, or nil.
function grug_mobs.boss_floor_of(self)
	local entry = self._grug_boss_id and floors[self._grug_boss_id]
	return entry and entry.cells or nil
end

--
-- The rules.
--
local function reset_kind(self)
	if grug_mobs.floor_boss(self) then return "floor" end
	local id = self._grug_boss_id
	if type(id) == "string" and id:sub(1, 5) == "rift:" then return "clock" end
	return nil
end
grug_mobs.reset_boss_kind = reset_kind

-- An attack of this boss (the 15 s rule's clock).
function grug_mobs.boss_attacked(self)
	if self and reset_kind(self) then
		self.temp = self.temp or {}
		self.temp.grug_boss_attack_at = grug_core.mono_time()
	end
end

local function attacker_of(source)
	local ent = source and not source:is_player() and source:get_luaentity()
	local shooter = ent and ent._grug_source
	if shooter then ent = shooter:get_luaentity() end
	return ent
end

-- A landed or dodged hit of a mob or its projectile on a player.
local mark_player_hit = grug_core.mark_player_hit
function grug_core.mark_player_hit(player, source)
	mark_player_hit(player, source)
	local ent = attacker_of(source)
	if ent and (ent._grug_boss_id or ent._grug_royal_king) then grug_mobs.boss_attacked(ent) end
end

-- A projectile locked on a target in sight and shot range.
local actor_projectile_lock = grug_core.actor_projectile_lock
function grug_core.actor_projectile_lock(owner, ...)
	local lock = actor_projectile_lock(owner, ...)
	local ent = lock and owner and owner:get_luaentity()
	if ent and (ent._grug_boss_id or ent._grug_royal_king) then grug_mobs.boss_attacked(ent) end
	return lock
end

local function alive_player(name)
	local player = core.get_player_by_name(name)
	return player ~= nil and player:get_hp() > 0 and player or nil
end

-- Another player still engaged with this boss.
local function others_engaged(t)
	for name in pairs(t.grug_engaged or {}) do
		if alive_player(name) then return true end
	end
	return false
end

-- `name` left this boss's fight (see the header). True when the boss reset.
local function leave(self, t, name)
	if t.grug_threat then t.grug_threat[name] = nil end
	if t.grug_boss_target == name then t.grug_boss_target = nil end
	local player = core.get_player_by_name(name)
	local target = self.attack
	if target and core.is_player(target) and target:get_player_name() == name then
		self:stop_attack()
	elseif player then
		grug_core.disengage_target(self, player)
	end
	if player then grug_mobs.mark_gave_up(self, player) end
	if self._grug_pack and grug_mobs.pack_release then grug_mobs.pack_release(self, name) end
	if not others_engaged(t) then
		grug_mobs.reset_home(self)
		return true
	end
	local window = t.grug_boss_window
	if not window then
		t.grug_boss_window = {started = grug_core.mono_time(), left = {[name] = true}}
	else
		window.left[name] = true
	end
	return false
end

-- The window, every step: a Taunt by someone who did not leave keeps the fight,
-- TAUNT_FORCE_TIME without one resets. True when the boss reset.
local function window_step(self, t, window)
	local forced = t.grug_forced_until
	local target = self.attack
	if forced and forced - grug_core.TAUNT_FORCE_TIME >= window.started
			and target and core.is_player(target)
			and not window.left[target:get_player_name()] then
		t.grug_boss_window = nil
		return false
	end
	if grug_core.mono_time() - window.started >= grug_core.TAUNT_FORCE_TIME then
		grug_mobs.reset_home(self)
		return true
	end
	return false
end

local function target_name(target)
	local name = target and core.is_player(target) and target:get_player_name() or nil
	return name ~= "" and name or nil
end

-- Every step: the target the boss had a step ago, if it is not the target any more,
-- is tested at once, as it stood when the boss lost it. Gone (a logout) or off the
-- floor (a teleport, a step out the boss saw last) it has left; dead it has not, and
-- one the boss turned from on the floor (a Taunt, a threat switch) has not either,
-- whatever it does later: only the current target can leave. True when it reset.
local function target_watch(self, t, cells)
	local name = target_name(self.attack)
	local last = t.grug_boss_target
	if last == name then return false end
	t.grug_boss_target = name
	if not last then return false end
	local player = core.get_player_by_name(last)
	if not player then return leave(self, t, last) end
	if cells and player:get_hp() > 0
			and not F.holds(cells, player:get_pos(), self.reach or 3) then
		return leave(self, t, last)
	end
	return false
end

-- The floor test of the current target, once a second (a dead one has not left).
local function floor_test(self, t, cells)
	local name = t.grug_boss_target
	local pos = name and self.attack:get_hp() > 0 and self.attack:get_pos()
	if pos and not F.holds(cells, pos, self.reach or 3) then leave(self, t, name) end
end

-- Every step of a mob with a boss id or a crown (aggro.lua leash_tick).
function grug_mobs.boss_tick(self, dtime)
	local kind = reset_kind(self)
	if not kind then return end
	local t = self.temp
	local cells
	if kind == "floor" then
		local entry = floor_entry(self)
		cells = entry and entry.cells
	end
	if t.grug_evading or self.state == "die" or (self.health or 0) <= 0 then
		t.grug_boss_window, t.grug_boss_attack_at, t.grug_boss_target = nil, nil, nil
		return
	end
	if target_watch(self, t, cells) then return end
	local window = t.grug_boss_window
	if window and window_step(self, t, window) then return end
	t.grug_boss_acc = (t.grug_boss_acc or 0) + dtime
	if t.grug_boss_acc < CHECK then return end
	t.grug_boss_acc = 0
	local target = self.attack
	if not ((target and core.is_player(target)) or (t.grug_engaged and next(t.grug_engaged))) then
		t.grug_boss_attack_at = nil
	else
		local now = grug_core.mono_time()
		local last = t.grug_boss_attack_at
		if not last then
			t.grug_boss_attack_at = now
		elseif now - last > QUIET then
			grug_mobs.reset_home(self)
			return
		end
	end
	if cells then floor_test(self, t, cells) end
end

-- The navigation gave its target up (aggro.lua give_up_target). With a floor that
-- decides nothing: the floor test does, walking goes on. Without one it is the "no
-- way": the target leaves through the window.
function grug_mobs.boss_no_way(self)
	if grug_mobs.boss_floor_of(self) then return end
	local target = self.attack
	if not (target and core.is_player(target)) then return end
	self.temp = self.temp or {}
	leave(self, self.temp, target:get_player_name())
end

grug_mobs.BOSS_QUIET = QUIET
