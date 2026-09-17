-- GRUG PATCH: bounded close-obstacle decisions shared by the real attack path
-- and its pure-Lua regression test (combat_stats.md section 4).

local obstacle = {
	path_delay = 1.0,
	sidestep_time = 0.5,
	path_budget_per_step = 2,
	path_backoff = 0.25,
}

local path_budget = obstacle.path_budget_per_step
local path_queue = {}
local path_queue_head = 1
local path_waiting = setmetatable({}, {__mode = "k"})
local path_granted = setmetatable({}, {__mode = "k"})

local function copy_pos(pos)
	if not pos then return end
	return {x = pos.x, y = pos.y, z = pos.z}
end

function obstacle.copy_pos(pos)
	return copy_pos(pos)
end

function obstacle.begin_server_step()
	path_budget = obstacle.path_budget_per_step
	path_granted = setmetatable({}, {__mode = "k"})

	while path_budget > 0 and path_queue_head <= #path_queue do
		local temp = path_queue[path_queue_head]
		path_queue[path_queue_head] = false
		path_queue_head = path_queue_head + 1
		if path_waiting[temp] then
			path_waiting[temp] = nil
			path_granted[temp] = true
			path_budget = path_budget - 1
		end
	end

	if path_queue_head > #path_queue then
		path_queue = {}
		path_queue_head = 1
	end
end

function obstacle.cancel_path_request(temp)
	path_waiting[temp] = nil
	path_granted[temp] = nil
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
	if path_granted[temp] then
		path_granted[temp] = nil
		return true
	end
	if path_waiting[temp] then return false end

	while path_queue_head <= #path_queue
	and not path_waiting[path_queue[path_queue_head]] do
		path_queue[path_queue_head] = false
		path_queue_head = path_queue_head + 1
	end
	if path_queue_head > #path_queue and path_budget > 0 then
		path_queue = {}
		path_queue_head = 1
		path_budget = path_budget - 1
		return true
	end

	path_waiting[temp] = true
	path_queue[#path_queue + 1] = temp
	return false
end

function obstacle.path_attempted(temp)
	temp.grug_obstacle_blocked = nil
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

	local cbox = self.object:get_properties().collisionbox
	mob_eye.y = mob_eye.y + cbox[2] + ((cbox[5] - cbox[2]) * 0.9)
	cbox = self.attack:get_properties().collisionbox
	target_eye.y = target_eye.y + cbox[2] + ((cbox[5] - cbox[2]) * 0.9)
	return self:line_of_sight(target_eye, mob_eye) == true
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
