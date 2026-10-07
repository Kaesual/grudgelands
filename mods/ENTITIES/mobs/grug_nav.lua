-- GRUG PATCH (Round 42 NV1): the shared navigation module (round42-plan.md
-- §2 rulings 1-9 and 17-20; combat_stats.md §4 "Navigation"). Our own file,
-- loaded by api.lua next to grug_obstacle.lua and published as
-- `mobs.grug_nav`; loaded directly by tools/r42_nv1/portable_test.lua.
--
-- Three stages (ruling 1): a mob walks straight at its goal (stage 1, the
-- caller's own movement); a mob that wants to move but does not is stuck,
-- and a stuck mob asks the engine's pathfinder for a short local detour
-- (stage 2) and follows it. Nothing here runs a search of its own: every
-- `core.find_path` goes through `nav.search`, inside grug_obstacle.lua's
-- per-step A* budget and negative path cache, behind a per-mob lockout and
-- a server-wide count cap.
--
--   * The stuck detector (ruling 2): the caller reports every step what the
--     mob wants (`nav.command`: the speed it really has, after slows and the
--     water slowdown, or 0 for every intentional stop). A window of steps in
--     which the mob wanted to move the whole time ends stuck when the mob
--     moved itself less than STUCK_RATIO of the expected distance. A skipped
--     step (knockback pause, stun) breaks the window.
--   * Combat (`nav.combat_step`, ruling 4): a stuck mob searches straight to
--     a target within CLOSE nodes, otherwise to a standable point on a ring
--     in the target's direction (RINGS, ANGLES, height band BAND). It leaves
--     the path when the target is struck, at its end, when the target moved
--     TARGET_DRIFT from where the path was planned, when the straight line to
--     the target is walkable again (tested every LINE_EVERY.combat s) or when
--     it is stuck on it. Failed searches in a row count (also a rejected or
--     refused one, and a path it got stuck on); GIVE_UP_AFTER of them give
--     the target up (ruling 9), also when it is visible. Progress (a struck
--     target, a path's end, a clear line) resets the count.
--   * Fixed walks (`nav.fixed_step`, ruling 5; for Round 42 NV2/NV3): the
--     path is followed to its end; a mob more than OFF_ROUTE nodes off it
--     searches again. Failures are counted and returned, never given up:
--     the caller's later stages (skip, next spot, snap) decide.
--   * Path checks (ruling 6): head room of ceil(height) cells and room for
--     the body's width at every waypoint; a body wider than one node is
--     steered through the 2x2 block it fits in (2 nodes) or needs every
--     cell round the waypoint (wider). Unknown and unloaded nodes are
--     blocked. A rejected path is a failed search (ruling 19).
--   * Smoothing and the walkable line (ruling 7): at each waypoint the mob
--     steers at the furthest of the next LOOKAHEAD waypoints it can walk to
--     straight. A straight walk samples every half node: feet to head free
--     at both sides of the body, ground below, steps up to the mob's step
--     height, drops down to its fear height; a diagonal step needs both
--     corner cells free with ground under them. Harmless water is ground
--     for a mob that wades (Round 34).
--
-- No wall-clock budget: the lockouts and the negative cache are timers per
-- mob, the cap is a count of searches per second of server steps.

local nav = {
	STUCK_RATIO = 0.3, -- of the expected self-movement (ruling 18)
	WINDOW = {combat = 0.5, fixed = 1}, -- s (ruling 2)
	LINE_EVERY = {combat = 0.5, fixed = 1}, -- s, the walkable-line test
	LOCKOUT = {combat = 1, fixed = 5}, -- s between one mob's searches
	CLOSE = 16, -- nodes: a closer target is searched for directly
	RINGS = {10, 16}, -- nodes: the candidate rings, tried in turn
	ANGLES = {0, 20, -20, 40, -40}, -- degrees off the target's direction
	BAND = 3, -- nodes up and down for a standable candidate
	PADDING = 6, -- the search box's padding (searchdistance)
	-- Never below 2: core.find_path aborts the server on a smaller box
	-- (docs/technical/upstream-workarounds.md §5). The box is exclusive on
	-- its positive edge, so padding p reaches p - 1 nodes on that side.
	MIN_PADDING = 2,
	MAX_LEG = 32, -- nodes: no longer leg goes to the engine in one piece
	CAP = 20, -- searches per second, server-wide (provisional)
	GIVE_UP_AFTER = 3, -- failed searches in a row (ruling 9)
	TARGET_DRIFT = 4, -- nodes the target may move from the planned end
	OFF_ROUTE = 2, -- nodes off a fixed walk's path (ruling 5)
	REACH_WP = 0.6, -- Manhattan distance that reaches a waypoint
	LOOKAHEAD = {8, 4, 2}, -- waypoints ahead tried by the smoothing
}

local floor, ceil, sqrt, abs = math.floor, math.ceil, math.sqrt, math.abs
local cos, sin, pi = math.cos, math.sin, math.pi

-- Set by api.lua (nav.init): the A* budget and negative cache, the
-- per-mob danger test and the engine search settings.
local obstacle, dangerous
local algorithm, max_jump, max_drop = "A*_noprefetch", 4, 6

function nav.init(opts)
	obstacle = opts.obstacle
	dangerous = opts.dangerous
	algorithm = opts.algorithm or algorithm
	max_jump = opts.max_jump or max_jump
	max_drop = opts.max_drop or max_drop
end

function nav.set_dangerous(fn)
	dangerous = fn
end

-- Optional observer (the navigation probe): nav.on_event(self, kind).
nav.on_event = nil
local function emit(self, kind)
	if nav.on_event then nav.on_event(self, kind) end
end

-- Server-wide counts, read by the probe.
nav.counters = {searches = 0, found = 0, cap_waits = 0, largest_us = 0}

local function now()
	return core.get_us_time() / 1000000
end

-- The server-step clock (a detector window breaks when the mob skipped a
-- call) and the count cap: the clock times of the last CAP searches; one
-- more may start when the oldest of them is a second old (any one second
-- holds at most CAP searches).
local clock = 0
local cap_times, cap_next = {}, 1

function nav.begin_server_step(dtime)
	clock = clock + (dtime or 0)
end

local function cap_free()
	local oldest = cap_times[cap_next]
	return not oldest or clock - oldest >= 1
end

local function cap_take()
	cap_times[cap_next] = clock
	cap_next = cap_next % nav.CAP + 1
end

--
-- Cells. `open`: a body may occupy the cell; `ground`: it can stand on it.
-- Unknown and unloaded nodes are neither (ruling 6).
--
local P = {x = 0, y = 0, z = 0}

local function def_at(x, y, z)
	P.x, P.y, P.z = x, y, z
	local node = core.get_node_or_nil(P)
	if not node or node.name == "ignore" then return nil end
	return core.registered_nodes[node.name]
end

local function cell(body, x, y, z)
	local def = def_at(x, y, z)
	if not def then return false, false end
	if dangerous and body.mob and dangerous(body.mob, def.name) then
		return false, false
	end
	if def.walkable then return false, true end
	local groups = def.groups
	if (def.liquidtype and def.liquidtype ~= "none")
	or (groups and (groups.liquid or 0) > 0) then
		local ok = body.wades and not (groups and groups.lava)
			and (def.damage_per_second or 0) <= 0
		return ok, ok
	end
	if (def.damage_per_second or 0) > 0 then return false, false end
	return true, false
end

-- Feet to head free.
local function open_column(body, x, y, z)
	for k = 0, body.head - 1 do
		if not cell(body, x, y + k, z) then return false end
	end
	return true
end

local function stands(body, x, y, z)
	if not open_column(body, x, y, z) then return false end
	local _, ground = cell(body, x, y - 1, z)
	return ground
end

-- The engine's own test for a search's ends: walkable, unknown counting as
-- walkable.
local function engine_walkable(pos)
	local def = def_at(pos.x, pos.y, pos.z)
	return not def or def.walkable == true
end

-- The feet cell of a feet height (a small sink below the surface still
-- counts as standing on it).
local function feet_y(y)
	return floor(y + 0.55)
end

--
-- The body: what the cell tests need of a mob, from its live collision box
-- (`_grug_cbox`, never get_properties()). Rebuilt when the box changes.
--
function nav.body(self, nst)
	local box = obstacle.mob_cbox(self)
	if nst and nst.body and nst.body_box == box then return nst.body end
	local width = box[4] - box[1]
	if box[6] - box[3] > width then width = box[6] - box[3] end
	local props = self.initial_properties
	local stepheight = props and props.stepheight or 1.1
	local jump = 0
	local jump_height = self.jump_height or 0
	if jump_height >= max_jump then
		jump = ceil(jump_height / max_jump)
		if jump > max_jump then jump = max_jump end
	elseif stepheight > 0.5 then
		jump = 1
	end
	local fear = self.fear_height or 0
	local body = {
		mob = self,
		width = width,
		hw = width / 2,
		head = ceil((box[5] - box[2]) - 0.01),
		feet = box[2],
		step = floor(stepheight + 0.05),
		jump = jump,
		drop = fear ~= 0 and fear or max_drop,
		wades = (self.floats and not self.fly and not self.keep_flying) == true,
	}
	if body.head < 1 then body.head = 1 end
	if nst then nst.body, nst.body_box = body, box end
	return body
end

--
-- The walkable line (ruling 7). `a` and `b` are feet positions.
--
local function settle(body, x, y, z)
	if open_column(body, x, y, z) then
		for d = 0, body.drop do
			local open, ground = cell(body, x, y - 1 - d, z)
			if ground then return y - d end
			if not open then return nil end
		end
		return nil
	end
	for up = 1, body.step do
		if open_column(body, x, y + up, z) then
			local _, ground = cell(body, x, y + up - 1, z)
			return ground and y + up or nil
		end
	end
	return nil
end

function nav.line_walkable(body, a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local len = sqrt(dx * dx + dz * dz)
	local y = feet_y(a.y)
	local cx, cz = floor(a.x + 0.5), floor(a.z + 0.5)
	if len < 0.01 then return true end
	local ux, uz = dx / len, dz / len
	-- The square body's half extent across the walking direction.
	local side = body.hw * (abs(ux) + abs(uz))
	local sx, sz = -uz * side, ux * side
	local seen1, seen2
	for i = 1, ceil(len / 0.5) do
		local t = i * 0.5
		if t > len then t = len end
		local x, z = a.x + ux * t, a.z + uz * t
		local nx, nz = floor(x + 0.5), floor(z + 0.5)
		if nx ~= cx or nz ~= cz then
			if nx ~= cx and nz ~= cz
			and not (stands(body, nx, y, cz) and stands(body, cx, y, nz)) then
				return false
			end
			y = settle(body, nx, y, nz)
			if not y then return false end
			cx, cz = nx, nz
		end
		-- Both sides of the body, each side cell once per level.
		for side = -1, 1, 2 do
			local px = floor(x + sx * side + 0.5)
			local pz = floor(z + sz * side + 0.5)
			if px ~= nx or pz ~= nz then
				local key = (px * 65536 + pz) * 1024 + y
				if key ~= (side < 0 and seen1 or seen2) then
					if not open_column(body, px, y, pz) then return false end
					if side < 0 then seen1 = key else seen2 = key end
				end
			end
		end
	end
	return true
end

--
-- Path checks (ruling 6). The offset from the node centre at which `body`
-- fits on waypoint (x, y, z), or nil. Two nodes wide: the 2x2 block round
-- the waypoint it fits in (the previous one first); wider: every cell round
-- the waypoint.
--
local BLOCKS = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

local function fit(body, x, y, z, prev_sx, prev_sz)
	if not open_column(body, x, y, z) then return nil end
	if body.width <= 1 then return 0, 0 end
	if body.width <= 2 then
		for k = 0, #BLOCKS do
			local bx, bz
			if k == 0 then
				bx, bz = prev_sx, prev_sz
			else
				bx, bz = BLOCKS[k][1], BLOCKS[k][2]
			end
			if bx and open_column(body, x + bx, y, z)
			and open_column(body, x, y, z + bz)
			and open_column(body, x + bx, y, z + bz) then
				return bx * 0.5, bz * 0.5
			end
		end
		return nil
	end
	local r = ceil(body.hw - 0.5)
	for dx = -r, r do
		for dz = -r, r do
			if (dx ~= 0 or dz ~= 0)
			and not open_column(body, x + dx, y, z + dz) then
				return nil
			end
		end
	end
	return 0, 0
end

-- The engine's path as steer points for `body`, or nil when any waypoint
-- lacks the head room or the width. The first point is where the mob
-- stands already.
function nav.check_path(body, path)
	local out = {path[1]}
	local psx, psz
	for i = 2, #path do
		local p = path[i]
		local ox, oz = fit(body, p.x, p.y, p.z, psx, psz)
		if not ox then return nil end
		if ox ~= 0 then psx, psz = ox * 2, oz * 2 end
		out[i] = {x = p.x + ox, y = p.y, z = p.z + oz}
	end
	return out
end

--
-- Search ends and candidates.
--

-- The mob's start cell. A mob pressed into a fence or standing on a slab
-- rounds into a walkable node, which the engine refuses: the cell above or
-- the nearest open neighbour instead (NV0 finding F7). nil: no start.
local NEIGHBOURS = {{0, 1, 0}, {1, 0, 0}, {0, 0, 1}, {-1, 0, 0}, {0, 0, -1}}

local function start_cell(body, pos)
	local x, z = floor(pos.x + 0.5), floor(pos.z + 0.5)
	local y = feet_y(pos.y + body.feet)
	local c = {x = x, y = y, z = z}
	if not engine_walkable(c) then return c end
	local fx = (pos.x - x) >= 0 and 1 or -1
	local fz = (pos.z - z) >= 0 and 1 or -1
	-- The neighbours the mob leans into first.
	for k = 1, #NEIGHBOURS do
		local n = NEIGHBOURS[k]
		local ox, oz = n[1], n[3]
		if abs(pos.x - x) < abs(pos.z - z) then ox, oz = oz, ox end
		c.x, c.y, c.z = x + ox * fx, y + n[2], z + oz * fz
		if not engine_walkable(c) then return c end
	end
	return nil
end

local function target_cell(target, target_pos)
	local box = obstacle.object_cbox(target)
	return {x = floor(target_pos.x + 0.5),
		y = feet_y(target_pos.y + (box and box[2] or 0)),
		z = floor(target_pos.z + 0.5)}
end

-- The highest standable feet cell of column (x, z) within BAND of `y0`.
function nav.stand_y(body, x, z, y0)
	for y = y0 + nav.BAND, y0 - nav.BAND, -1 do
		if stands(body, x, y, z) then return y end
	end
	return nil
end

-- The next candidate of this stuck episode: the rings in turn, on each ring
-- the angles in order, the first standable one (ruling 4).
local function next_candidate(nst, body, from, toward)
	local dx, dz = toward.x - from.x, toward.z - from.z
	local len = sqrt(dx * dx + dz * dz)
	if len < 1 then return nil end
	local rings, angles = nav.RINGS, nav.ANGLES
	nst.ring = (nst.ring or 0) % #rings + 1
	nst.angle = nst.angle or {}
	for pass = 0, #rings - 1 do
		local r = (nst.ring - 1 + pass) % #rings + 1
		local radius = rings[r]
		if radius > len then radius = len end
		while (nst.angle[r] or 0) < #angles do
			local k = (nst.angle[r] or 0) + 1
			nst.angle[r] = k
			local a = angles[k] * pi / 180
			local c, s = cos(a), sin(a)
			local x = floor(from.x + (dx * c - dz * s) / len * radius + 0.5)
			local z = floor(from.z + (dx * s + dz * c) / len * radius + 0.5)
			local y = nav.stand_y(body, x, z, from.y)
			if y then return {x = x, y = y, z = z} end
		end
	end
	return nil
end

--
-- The one engine search: the padding floor, the leg limit, the cost.
--
function nav.search(from, goal, padding, jump, drop)
	local dx, dz = goal.x - from.x, goal.z - from.z
	if dx * dx + dz * dz > nav.MAX_LEG * nav.MAX_LEG then return nil end
	padding = floor(padding or nav.PADDING)
	if padding < nav.MIN_PADDING then padding = nav.MIN_PADDING end
	local t0 = core.get_us_time()
	local path = core.find_path(from, goal, padding, jump, drop, algorithm)
	local us = core.get_us_time() - t0
	obstacle.note_path_cost(us)
	local counters = nav.counters
	counters.searches = counters.searches + 1
	if path then counters.found = counters.found + 1 end
	if us > counters.largest_us then counters.largest_us = us end
	return path
end

--
-- Per-mob state: `self.temp.grug_nav` (runtime only, never saved).
--
local function state(self)
	self.temp = self.temp or {}
	local nst = self.temp.grug_nav
	if not nst then
		nst = {fails = 0}
		self.temp.grug_nav = nst
	end
	return nst
end

-- Forget everything (a new target, de-aggro, death, unload).
function nav.forget(temp)
	if not temp then return end
	temp.grug_nav = nil
	if obstacle then obstacle.cancel_path_request(temp) end
end

-- End a stuck episode: the count, the wish to search, the candidates.
local function progress(self, nst)
	nst.fails, nst.want, nst.ring, nst.angle, nst.point = 0, nil, nil, nil, nil
	nst.line_left = nil
	obstacle.cancel_path_request(self.temp)
end

--
-- The stuck detector (ruling 2). After each step (or tick) the caller
-- reports the speed the mob commands (`speed`, already slowed by a liquid; 0
-- for an intentional stop) at `pos`; the next call's observe() measures the
-- window with that call's `dtime`. A per-step caller and a once-a-second
-- tick both work; a call that comes later than its own `dtime` says (a
-- skipped step: knockback pause, stun) breaks the window.
--
function nav.command(self, pos, speed)
	local nst = state(self)
	if not speed or speed <= 0 then
		nst.wt, nst.cmd_v = nil, nil
		return
	end
	nst.cmd_v, nst.cmd_clock = speed, clock
	if not nst.wt then
		nst.wt, nst.we, nst.wx, nst.wz = 0, 0, pos.x, pos.z
	end
end

-- "stuck", "free" (a window ended with enough movement) or nil.
local function observe(nst, pos, dtime, window)
	if not nst.wt then return nil end
	if not nst.cmd_v or clock - nst.cmd_clock > dtime * 1.5 + 0.01 then
		nst.wt = nil
		return nil
	end
	nst.wt = nst.wt + dtime
	nst.we = nst.we + nst.cmd_v * dtime
	if nst.wt < window then return nil end
	local dx, dz = pos.x - nst.wx, pos.z - nst.wz
	local stuck = sqrt(dx * dx + dz * dz) < nav.STUCK_RATIO * nst.we
	nst.wt = nil
	return stuck and "stuck" or "free"
end
nav.observe = observe

--
-- Following (rulings 4, 5, 7).
--
local F = {x = 0, y = 0, z = 0}

local function feet_of(body, pos)
	F.x, F.y, F.z = pos.x, pos.y + body.feet, pos.z
	return F
end

-- Steer at the furthest of the next LOOKAHEAD waypoints that a straight
-- walk reaches.
local function smooth(nst, body, pos)
	local path, i = nst.path, nst.i
	local last = i
	for k = 1, #nav.LOOKAHEAD do
		local j = i + nav.LOOKAHEAD[k]
		if j > #path then j = #path end
		if j > i and j ~= last then
			last = j
			if nav.line_walkable(body, feet_of(body, pos), path[j]) then
				nst.i = j
				break
			end
		end
	end
	nst.sx, nst.sz = pos.x, pos.z
end

-- The point to steer at, nil at the path's end.
local function follow(nst, body, pos)
	local path = nst.path
	local p = path[nst.i]
	local moved = false
	while p and abs(p.x - pos.x) + abs(p.z - pos.z) < nav.REACH_WP do
		nst.i = nst.i + 1
		p = path[nst.i]
		moved = true
	end
	if not p then return nil end
	if moved then
		smooth(nst, body, pos)
		p = path[nst.i]
	end
	return p
end

-- Horizontal distance from `pos` to the leg the mob is on.
local function off_route(nst, pos)
	local p = nst.path[nst.i]
	local ax, az = nst.sx or p.x, nst.sz or p.z
	local vx, vz = p.x - ax, p.z - az
	local wx, wz = pos.x - ax, pos.z - az
	local l2 = vx * vx + vz * vz
	local t = l2 > 0 and (wx * vx + wz * vz) / l2 or 0
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local ex, ez = wx - vx * t, wz - vz * t
	return sqrt(ex * ex + ez * ez)
end

local function take_path(nst, body, pos, steer)
	nst.path, nst.i, nst.lt = steer, #steer >= 2 and 2 or 1, 0
	smooth(nst, body, pos)
end

--
-- One search attempt of a stuck mob. "found", "failed" (counts) or "wait"
-- (lockout, negative cache, cap or budget; nothing counts).
--
local function attempt(self, nst, pos, goal_pos, key, mode, close, target)
	local t = now()
	if t < (nst.lock or 0) then return "wait" end
	local body = nav.body(self, nst)
	local from = start_cell(body, pos)
	local goal
	if from then
		local dx, dz = goal_pos.x - pos.x, goal_pos.z - pos.z
		if dx * dx + dz * dz <= close * close then
			goal = target and target_cell(target, goal_pos)
				or {x = floor(goal_pos.x + 0.5), y = feet_y(goal_pos.y),
					z = floor(goal_pos.z + 0.5)}
		else
			-- A candidate is picked once per search, not per waiting step.
			goal = nst.point or next_candidate(nst, body, from, goal_pos)
			nst.point = goal
			key = "nav_point"
		end
	end
	-- A target in a slab is aimed at from the node above
	-- (grug_obstacle.fit_path_ends). No start, no candidate or an end still
	-- walkable: a search that cannot succeed, counted so it never loops.
	if not goal or not obstacle.fit_path_ends(from, goal, engine_walkable) then
		nst.lock, nst.point = t + nav.LOCKOUT[mode], nil
		emit(self, "refused")
		return "failed"
	end
	if obstacle.no_path_gate(self.temp, t, key, from, goal, true) == "wait" then
		obstacle.cancel_path_request(self.temp)
		return "wait"
	end
	if not cap_free() then
		if not nst.capped then
			nst.capped = true
			nav.counters.cap_waits = nav.counters.cap_waits + 1
			emit(self, "cap_wait")
		end
		obstacle.cancel_path_request(self.temp)
		return "wait"
	end
	if not obstacle.claim_path_budget(self.temp) then return "wait" end
	cap_take()
	nst.capped, nst.point = nil, nil
	nst.lock = t + nav.LOCKOUT[mode]
	local path = nav.search(from, goal, nav.PADDING, body.jump, body.drop)
	local steer = path and nav.check_path(body, path)
	obstacle.note_search_result(self.temp, t, key, from, goal, steer ~= nil)
	if not steer then
		emit(self, path and "rejected" or "no_path")
		return "failed"
	end
	emit(self, "found")
	take_path(nst, body, pos, steer)
	return "found"
end

-- A failed search (or a path the mob got stuck on) in this episode.
local function fail(self, nst, give_up)
	nst.fails = nst.fails + 1
	nst.want = true
	if give_up and nst.fails >= nav.GIVE_UP_AFTER then
		emit(self, "give_up")
		nav.forget(self.temp)
		return "give_up"
	end
end

--
-- Combat (rulings 4, 9). Called every step of the dogfight branch of a
-- ground melee mob that may search. `striking`: the target is in reach and
-- visible. Returns the point to steer at (nil: straight at the target) and
-- "give_up" when the mob gives the target up. `never_give_up`: the dragons
-- and their whelps only wait.
--
function nav.combat_step(self, pos, dtime, target, target_pos, dist, striking,
		never_give_up)
	local nst = state(self)
	if nst.target ~= target then
		nav.forget(self.temp)
		nst = state(self)
		nst.target = target
	end
	local seen = observe(nst, pos, dtime, nav.WINDOW.combat)
	if striking then
		if nst.path or nst.want or nst.fails > 0 then
			nst.path = nil
			progress(self, nst)
		end
		return nil
	end
	local body
	if nst.path then
		local reason
		if seen == "stuck" then
			reason = "stuck"
		else
			local ax, az = target_pos.x - nst.aim_x, target_pos.z - nst.aim_z
			if ax * ax + az * az > nav.TARGET_DRIFT * nav.TARGET_DRIFT then
				reason = "drift"
			else
				nst.lt = nst.lt + dtime
				if nst.lt >= nav.LINE_EVERY.combat then
					nst.lt = 0
					body = nav.body(self, nst)
					if dist <= nav.MAX_LEG and nav.line_walkable(body,
							feet_of(body, pos), target_cell(target, target_pos)) then
						reason = "line"
					end
				end
			end
		end
		if not reason then
			local steer = follow(nst, body or nav.body(self, nst), pos)
			if steer then return steer end
			reason = "end"
		end
		nst.path = nil
		emit(self, "leave_" .. reason)
		if reason == "stuck" then
			return nil, fail(self, nst, not never_give_up)
		elseif reason == "end" then
			progress(self, nst)
		elseif reason == "line" then
			-- Walk straight; progress once the straight walk proves free
			-- (below); stuck before that, the line test was wrong: a failure.
			nst.line_left, nst.want = true, nil
			obstacle.cancel_path_request(self.temp)
		end
		return nil
	end
	if seen == "stuck" then
		if not nst.want then emit(self, "stuck") end
		nst.want = true
		if nst.line_left then
			nst.line_left = nil
			local outcome = fail(self, nst, not never_give_up)
			if outcome then return nil, outcome end
		end
	elseif seen == "free" then
		nst.line_left = nil
		-- Moving freely with a clear way to the target: the episode is over.
		if (nst.want or nst.fails > 0) and dist <= nav.MAX_LEG then
			body = nav.body(self, nst)
			if nav.line_walkable(body, feet_of(body, pos),
					target_cell(target, target_pos)) then
				progress(self, nst)
			end
		end
	end
	if not nst.want then return nil end
	local result = attempt(self, nst, pos, target_pos, target, "combat",
		nav.CLOSE, target)
	if result == "found" then
		nst.aim_x, nst.aim_z = target_pos.x, target_pos.z
		return nst.path[nst.i]
	elseif result == "failed" then
		return nil, fail(self, nst, not never_give_up)
	end
	return nil
end

--
-- Fixed walks (ruling 5): patrol waypoints, posts, villager spots, a home, an
-- idle leader. Called every step of the walk with the goal's feet position
-- and a key naming it (a changed key is a new walk). Returns the point to
-- steer at (nil: straight at the goal) and "failed" when a search failed or
-- the mob got stuck on its path (the caller's later stages decide; the
-- episode's count is `self.temp.grug_nav.fails`). A goal beyond MAX_LEG is
-- approached through ring candidates in its direction.
--
function nav.fixed_step(self, pos, dtime, goal, key)
	local nst = state(self)
	if nst.target ~= key then
		nav.forget(self.temp)
		nst = state(self)
		nst.target = key
	end
	local seen = observe(nst, pos, dtime, nav.WINDOW.fixed)
	if nst.path then
		local reason
		if seen == "stuck" then
			reason = "stuck"
		elseif off_route(nst, pos) > nav.OFF_ROUTE then
			reason = "off_route"
		else
			local steer = follow(nst, nav.body(self, nst), pos)
			if steer then return steer end
			reason = "end"
		end
		nst.path = nil
		emit(self, "leave_" .. reason)
		if reason == "stuck" then
			fail(self, nst, false)
			return nil, "failed"
		elseif reason == "off_route" then
			nst.want = true
		else
			progress(self, nst)
		end
		return nil
	end
	if seen == "stuck" then
		if not nst.want then emit(self, "stuck") end
		nst.want = true
	elseif seen == "free" and nst.want then
		nst.lt = (nst.lt or 0) + nav.WINDOW.fixed
		if nst.lt >= nav.LINE_EVERY.fixed then
			nst.lt = 0
			local body = nav.body(self, nst)
			local dx, dz = goal.x - pos.x, goal.z - pos.z
			if dx * dx + dz * dz <= nav.MAX_LEG * nav.MAX_LEG
			and nav.line_walkable(body, feet_of(body, pos), goal) then
				progress(self, nst)
			end
		end
	end
	if not nst.want then return nil end
	local result = attempt(self, nst, pos, goal, key, "fixed", nav.MAX_LEG)
	if result == "found" then
		return nst.path[nst.i]
	elseif result == "failed" then
		fail(self, nst, false)
		return nil, "failed"
	end
	return nil
end

-- Is the mob following a path right now?
function nav.following(temp)
	local nst = temp and temp.grug_nav
	return nst ~= nil and nst.path ~= nil
end

return nav
