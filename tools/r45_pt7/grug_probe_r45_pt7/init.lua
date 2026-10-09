-- Disposable Round 45 PT7 probe, never shipped. Run from the worktree root:
--   KEEP=1 PROBE=tools/r45_pt7/grug_probe_r45_pt7 tools/luanti_headless.sh 240
-- (through the round's lua_run.sh queue), then grep "\[r45pt7\]" in server.log.
--
-- On a stone floor built high in the air (y 300, forceloaded, no player):
--   STEP   a real Shore Crab and two plain physical boxes of the crab's size
--          with stepheight 1 and 1.1 are pushed at 1.5 n/s against a
--          one-node step for 4 s (the crab's AI is held off, gravity stays);
--          each one's rise is logged: the crab and 1.1 climb, 1 does not;
--   FLY    a Parrot and a Carrion Crow are put 6 nodes above the floor with
--          their own AI; for 8 s every step logs which clip plays (the frame
--          range the object really shows) while the bird stands on air.
-- Every line carries "[r45pt7]"; the probe ends the server when done.
local P = "[r45pt7] "
local function log(s) core.log("action", P .. s) end
local Y = 300
local ORIGIN = {x = 8, y = Y, z = 8}

for _, step in ipairs({1, 1.1}) do
	core.register_entity("grug_probe_r45_pt7:box_" .. (step == 1 and "10" or "11"), {
		initial_properties = {
			physical = true, collide_with_objects = false, stepheight = step,
			visual = "sprite", textures = {"blank.png"}, static_save = false,
			collisionbox = {-0.4, -0.01, -0.4, 0.4, 0.4, 0.4},
		},
	})
end

local phase, t, emerged = "wait", 0, false
local pushed, birds, counts = {}, {}, {}

local function build()
	for x = ORIGIN.x - 8, ORIGIN.x + 8 do
		for z = ORIGIN.z - 8, ORIGIN.z + 8 do
			core.set_node({x = x, y = Y, z = z}, {name = "default:stone"})
			-- The step: one node up from x = ORIGIN.x + 2 on.
			if x >= ORIGIN.x + 2 then
				core.set_node({x = x, y = Y + 1, z = z}, {name = "default:stone"})
			end
		end
	end
end

local function start()
	build()
	local feet = Y + 0.5 + 0.01
	local crab = core.add_entity({x = ORIGIN.x - 3, y = feet, z = ORIGIN.z - 4}, "grug_mobs:shore_crab")
	local ent = crab and crab:get_luaentity()
	if ent then ent.do_custom = function() return false end end
	pushed = {
		{name = "shore_crab", obj = crab},
		{name = "box stepheight 1", obj = core.add_entity({x = ORIGIN.x - 3, y = feet, z = ORIGIN.z}, "grug_probe_r45_pt7:box_10")},
		{name = "box stepheight 1.1", obj = core.add_entity({x = ORIGIN.x - 3, y = feet, z = ORIGIN.z + 4}, "grug_probe_r45_pt7:box_11")},
	}
	for _, p in ipairs(pushed) do
		if p.obj then
			p.obj:set_acceleration({x = 0, y = -9.81, z = 0})
			p.y0 = p.obj:get_pos().y
		end
		log(("STEP %s spawned=%s"):format(p.name, tostring(p.obj ~= nil)))
	end
	for i, name in ipairs({"parrot", "carrion_crow"}) do
		local obj = core.add_entity({x = ORIGIN.x - 6 + i * 3, y = Y + 7, z = ORIGIN.z - 7}, "grug_mobs:" .. name)
		birds[#birds + 1] = {name = name, obj = obj}
		counts[name] = {fly = 0, stand = 0, other = 0, ground = 0, states = {}}
		log(("FLY %s spawned=%s"):format(name, tostring(obj ~= nil)))
	end
end

local requested = false
local function request_area()
	requested = true
	for bx = -1, 2 do for bz = -1, 2 do for by = 18, 19 do
		core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
	end end end
	core.emerge_area({x = -16, y = Y - 16, z = -16}, {x = 40, y = Y + 24, z = 40},
		function(_, _, remaining) if remaining == 0 then emerged = true end end)
end

local result_ok = true
core.register_globalstep(function(dtime)
	t = t + dtime
	if phase == "wait" then
		if not requested then request_area() end
		if emerged and t > 3 then
			start()
			phase, t = "run", 0
		elseif t > 60 then
			log("RESULT FAIL no emerge")
			core.request_shutdown("r45pt7 done", false, 0)
			phase = "done"
		end
		return
	end
	if phase ~= "run" then return end
	if t <= 4 then
		for _, p in ipairs(pushed) do
			local v = p.obj and p.obj:get_velocity()
			if v then p.obj:set_velocity({x = 1.5, y = v.y, z = 0}) end
		end
	end
	for _, b in ipairs(birds) do
		local ent = b.obj and b.obj:get_luaentity()
		if ent then
			local c = counts[b.name]
			local def = core.registered_nodes[ent.standing_on]
			if def and def.walkable then
				c.ground = c.ground + 1
			else
				local range = b.obj:get_animation()
				local a = ent.animation
				if range.x == a.fly_start and range.y == a.fly_end then c.fly = c.fly + 1
				elseif range.x == a.stand_start and range.y == a.stand_end then c.stand = c.stand + 1
				else c.other = c.other + 1 end
				c.states[ent.state or "?"] = true
			end
		end
	end
	if t > 8 then
		for _, p in ipairs(pushed) do
			local pos = p.obj and p.obj:get_pos()
			local rise = pos and (pos.y - p.y0) or -99
			local want = p.name ~= "box stepheight 1"
			local ok = (rise > 0.9) == want
			result_ok = result_ok and ok
			log(("STEP %s rise=%.2f x=%.2f expect_climb=%s %s"):format(p.name, rise,
				pos and pos.x or -99, tostring(want), ok and "ok" or "BAD"))
		end
		for _, b in ipairs(birds) do
			local c = counts[b.name]
			local states = {}
			for s in pairs(c.states) do states[#states + 1] = s end
			table.sort(states)
			local ok = c.fly > 0 and c.stand == 0
			result_ok = result_ok and ok
			log(("FLY %s in-air steps: fly=%d stand=%d other=%d; on ground=%d; states=%s %s"):format(
				b.name, c.fly, c.stand, c.other, c.ground, table.concat(states, ","), ok and "ok" or "BAD"))
		end
		log("RESULT " .. (result_ok and "PASS" or "FAIL"))
		phase = "done"
		core.request_shutdown("r45pt7 done", false, 0)
	end
end)
