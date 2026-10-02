-- GRUG PATCH: bounded close-obstacle decisions shared by the real attack path
-- and its pure-Lua regression test (combat_stats.md section 4).

local obstacle = {
	path_delay = 1.0,
	sidestep_time = 0.5,
	path_backoff = 0.25,
	-- Round 30 P2 (perf review 2026-10 #4): A* time per server step, in
	-- microseconds, instead of a fixed number of searches. A no-path search
	-- costs 2-3 ms at searchdistance 24, a found path 14-211 us.
	path_budget_us = 3000,
	-- Negative path cache: after a no-path result the mob waits before it
	-- searches the same pair of nodes again (seconds, per consecutive
	-- failure, the last one repeated, capped).
	no_path_waits = {1, 2, 4, 8},
	no_path_wait_cap = 10,
	-- Give up a target after this many failed searches in a row while the
	-- target's node stays the same (the user's ruling, round30-plan.md §2).
	give_up_after = 3,
	-- searchdistance of the close-obstacle A* pass (a target within reach
	-- behind a trunk or wall); the chase pass keeps the server setting.
	close_searchdistance = 8,
}

-- Microseconds spent on A* in the current server step, and the running
-- estimate of one search (used to grant queued requests at step start).
local path_spent_us = 0
local path_granted_us = 0
local path_cost_estimate_us = 1000
local path_queue = {}
local path_queue_head = 1
local path_entries = setmetatable({}, {__mode = "k"})
local path_generation = 0

local function copy_pos(pos)
	if not pos then return end
	return {x = pos.x, y = pos.y, z = pos.z}
end

function obstacle.copy_pos(pos)
	return copy_pos(pos)
end

--
-- Collision boxes without get_properties() (Round 30 P2, perf review 2026-10
-- #6): every get_properties() call builds the whole property table (about
-- 2.8 KB of garbage). A mobs_redo mob carries its live box in `_grug_cbox`
-- (api.lua writes it wherever it sets the collisionbox); a player's box is
-- read once per server step.
--
local player_boxes = {}
local player_boxes_used = false

function obstacle.mob_cbox(self)
	return self._grug_cbox or self.object:get_properties().collisionbox
end

function obstacle.object_cbox(object)
	local ent = object:get_luaentity()
	local box = ent and ent._grug_cbox
	if box then return box end
	if object:is_player() then
		box = player_boxes[object]
		if not box then
			box = object:get_properties().collisionbox
			player_boxes[object] = box
			player_boxes_used = true
		end
		return box
	end
	return object:get_properties().collisionbox
end

function obstacle.path_request_current(temp, generation)
	local entry = path_entries[temp]
	return entry ~= nil and entry.active == true
		and entry.generation == generation
end

function obstacle.cancel_path_request(temp)
	local entry = path_entries[temp]
	if not entry then return end
	path_entries[temp] = nil
	entry.active = false
	entry.temp = nil
end

local function discard_invalid_queue_head()
	while path_queue_head <= #path_queue do
		local entry = path_queue[path_queue_head]
		local temp = entry and entry.temp
		if temp and entry.status == "queued"
		and obstacle.path_request_current(temp, entry.generation) then
			return
		end
		if entry then entry.temp = nil end
		path_queue[path_queue_head] = false
		path_queue_head = path_queue_head + 1
	end
	path_queue = {}
	path_queue_head = 1
end

local function new_path_request(temp)
	path_generation = path_generation + 1
	local entry = {
		active = true,
		generation = path_generation,
		status = "queued",
		temp = temp,
	}
	path_entries[temp] = entry
	return entry
end

function obstacle.begin_server_step()
	if player_boxes_used then
		for object in pairs(player_boxes) do player_boxes[object] = nil end
		player_boxes_used = false
	end
	-- A grant belongs to one server step. If its mob stopped requesting before
	-- claiming it, invalidate the grant without retaining the mob's temp table.
	for temp, entry in pairs(path_entries) do
		if entry.status == "granted" then
			obstacle.cancel_path_request(temp)
		end
	end

	-- Queued requests are granted against the estimated cost of a search;
	-- what they really spend is added as they run (note_path_cost).
	path_spent_us = 0
	path_granted_us = 0
	discard_invalid_queue_head()
	while path_granted_us < obstacle.path_budget_us
	and path_queue_head <= #path_queue do
		local entry = path_queue[path_queue_head]
		path_queue[path_queue_head] = false
		path_queue_head = path_queue_head + 1
		local temp = entry.temp
		if temp and entry.status == "queued"
		and obstacle.path_request_current(temp, entry.generation) then
			entry.temp = nil
			entry.status = "granted"
			entry.grant_us = path_cost_estimate_us
			path_granted_us = path_granted_us + entry.grant_us
		end
		discard_invalid_queue_head()
	end
end

-- The measured duration of one A* search (microseconds) against this step's
-- budget, and into the running estimate the queue grants with.
function obstacle.note_path_cost(us)
	us = us > 0 and us or 0
	path_spent_us = path_spent_us + us
	path_cost_estimate_us = path_cost_estimate_us * 0.75 + us * 0.25
	if path_cost_estimate_us < 50 then path_cost_estimate_us = 50 end
end

function obstacle.tick_backoff(temp, dtime)
	local remaining = (temp.grug_obstacle_backoff or 0) - dtime
	if remaining > 0 then
		temp.grug_obstacle_backoff = remaining
	else
		temp.grug_obstacle_backoff = nil
	end
end

function obstacle.close_path_due(temp, dtime, blocked, can_path, following)
	if not blocked or not can_path then
		obstacle.cancel_path_request(temp)
		temp.grug_obstacle_blocked = nil
		if not blocked then temp.grug_obstacle_sidestep = nil end
		return false
	end

	temp.grug_obstacle_blocked = (temp.grug_obstacle_blocked or 0) + dtime
	if following then obstacle.cancel_path_request(temp) end
	return not temp.grug_obstacle_sidestep
		and not following
		and not temp.grug_obstacle_backoff
		and temp.grug_obstacle_blocked >= obstacle.path_delay
end

function obstacle.claim_path_budget(temp)
	if temp.grug_obstacle_backoff then return false end
	local entry = path_entries[temp]
	if entry then
		if entry.status ~= "granted"
		or not obstacle.path_request_current(temp, entry.generation) then
			return false, entry.generation
		end
		local generation = entry.generation
		-- The grant's reservation turns into the search's real cost.
		path_granted_us = path_granted_us - (entry.grant_us or 0)
		obstacle.cancel_path_request(temp)
		return true, generation
	end

	discard_invalid_queue_head()
	entry = new_path_request(temp)
	if path_queue_head > #path_queue
	and path_spent_us + path_granted_us < obstacle.path_budget_us then
		local generation = entry.generation
		obstacle.cancel_path_request(temp)
		return true, generation
	end

	path_queue[#path_queue + 1] = entry
	return false, entry.generation
end

-- A caller that searches at most once a second (the patrol nudge) cannot
-- claim a queued grant in the step it is given, so it neither queues nor
-- waits: it searches only while the step has budget left and nobody queues.
function obstacle.spare_path_budget()
	discard_invalid_queue_head()
	return path_queue_head > #path_queue
		and path_spent_us + path_granted_us < obstacle.path_budget_us
end

function obstacle.path_attempted(temp)
	temp.grug_obstacle_blocked = nil
end

--
-- Negative path cache and give-up (Round 30 P2, perf review 2026-10 #4).
--
-- A no-path search explores the whole search box, so repeating it for an
-- unreachable target (a closed house, a pillar, a boat) cost 2-3 ms every
-- couple of seconds, forever. `temp.grug_no_path` remembers the last failed
-- search: the target object, the mob's and the target's node and how many
-- searches in a row failed while the target's node stayed the same.
--   * The next search for the same two nodes waits 1, 2, 4, 8 s after the
--     1st, 2nd, 3rd, 4th failure (capped); a changed node of either side lifts
--     the wait, since that is a different search.
--   * A target that changes node starts the count again.
--   * Once `give_up_after` searches failed, the next search that would run
--     gives the target up instead (the caller drops it and goes home). A
--     caller without a target to give up (the patrol nudge) passes
--     `no_give_up`; its waits keep growing to the cap instead.
-- Nodes are rounded positions; `now` is in seconds.
--

local function node_of(pos)
	return math.floor(pos.x + 0.5), math.floor(pos.y + 0.5),
		math.floor(pos.z + 0.5)
end

-- "search", "wait" (back-off running) or "give_up".
function obstacle.no_path_gate(temp, now, target, mob_pos, target_pos,
		no_give_up)
	local state = temp.grug_no_path
	if not state then return "search" end
	local tx, ty, tz = node_of(target_pos)
	if state.target ~= target or state.tx ~= tx or state.ty ~= ty
	or state.tz ~= tz then
		temp.grug_no_path = nil
		return "search"
	end
	if not no_give_up and state.fails >= obstacle.give_up_after then
		local mx, my, mz = node_of(mob_pos)
		if now < state.until_time and state.mx == mx and state.my == my
		and state.mz == mz then
			return "wait"
		end
		temp.grug_no_path = nil
		return "give_up"
	end
	local mx, my, mz = node_of(mob_pos)
	if now < state.until_time and state.mx == mx and state.my == my
	and state.mz == mz then
		return "wait"
	end
	return "search"
end

-- Record a search result. `mob_pos`/`target_pos` are the search's ends.
function obstacle.note_search_result(temp, now, target, mob_pos, target_pos,
		has_path)
	if has_path then
		temp.grug_no_path = nil
		return
	end
	local tx, ty, tz = node_of(target_pos)
	local mx, my, mz = node_of(mob_pos)
	local state = temp.grug_no_path
	local fails = 1
	if state and state.target == target and state.tx == tx
	and state.ty == ty and state.tz == tz then
		fails = state.fails + 1
	end
	local waits = obstacle.no_path_waits
	local wait = waits[math.min(fails, #waits)]
	if wait > obstacle.no_path_wait_cap then wait = obstacle.no_path_wait_cap end
	temp.grug_no_path = {target = target, fails = fails,
		until_time = now + wait, mx = mx, my = my, mz = mz,
		tx = tx, ty = ty, tz = tz}
end

function obstacle.forget_no_path(temp)
	temp.grug_no_path = nil
end

function obstacle.note_path_result(temp, has_path)
	if has_path then
		temp.grug_obstacle_sidestep = nil
		return
	end

	local previous = temp.grug_obstacle_side or -1
	temp.grug_obstacle_side = -previous
	temp.grug_obstacle_sidestep = obstacle.sidestep_time
end

function obstacle.note_exhausted_blocked_path(temp)
	obstacle.note_path_result(temp, false)
	temp.grug_obstacle_blocked = obstacle.path_delay
	temp.grug_obstacle_backoff = obstacle.path_backoff
end

function obstacle.keep_path(distance, reach, target_visible)
	return not (distance < reach and target_visible)
end

function obstacle.should_close_contact(distance, reach, target_visible)
	return not target_visible or distance > reach * 0.6
end

function obstacle.target_visible(self, mob_pos, target_pos, ground_melee)
	local mob_eye = copy_pos(mob_pos)
	local target_eye = copy_pos(target_pos)
	if not mob_eye or not target_eye then return false end

	if not ground_melee then
		mob_eye.y = mob_eye.y + 0.5
		target_eye.y = target_eye.y + 0.5
		return self:line_of_sight(mob_eye, target_eye) == true
	end

	local cbox = obstacle.mob_cbox(self)
	mob_eye.y = mob_eye.y + cbox[2] + ((cbox[5] - cbox[2]) * 0.9)
	cbox = obstacle.object_cbox(self.attack)
	target_eye.y = target_eye.y + cbox[2] + ((cbox[5] - cbox[2]) * 0.9)
	return self:line_of_sight(target_eye, mob_eye) == true
end

function obstacle.strike_target_visible(self, mob_pos, target_pos,
		common_visible, ground_melee)
	if not common_visible or ground_melee then return common_visible == true end
	return obstacle.target_visible(self, mob_pos, target_pos, true)
end

local function side_velocity(mob_pos, target_pos, side, speed)
	local dx = target_pos.x - mob_pos.x
	local dz = target_pos.z - mob_pos.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length == 0 then return end
	return {
		x = -dz / length * speed * side,
		z = dx / length * speed * side,
	}
end

function obstacle.choose_sidestep(mob_pos, target_pos, preferred_side, speed, is_safe)
	local first = preferred_side or 1
	local velocity = side_velocity(mob_pos, target_pos, first, speed)
	if velocity and is_safe(velocity) then return velocity, first end

	local second = -first
	velocity = side_velocity(mob_pos, target_pos, second, speed)
	if velocity and is_safe(velocity) then return velocity, second end
	return nil, first
end

function obstacle.advance_sidestep(temp, dtime)
	local remaining = (temp.grug_obstacle_sidestep or 0) - dtime
	if remaining > 0 then
		temp.grug_obstacle_sidestep = remaining
	else
		temp.grug_obstacle_sidestep = nil
	end
end

function obstacle.try_melee_attack(args)
	if not args.ready or not args.in_reach then return false, false end
	if not args.target_visible then return false, false end
	if args.custom_attack and not args.custom_attack() then return false, true end
	args.punch()
	return true, true
end

return obstacle
