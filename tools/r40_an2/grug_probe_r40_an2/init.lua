-- Round 40 AN2 engine probe (staged by tools/r40_an2/engine.sh, never
-- shipped): what the head look's two engine calls cost. A headless server has
-- no players, so 100 entities with the player model stand in: `get_yaw` (one
-- ObjectRef read returning a number, like the pass's `get_look_vertical`) and
-- `set_bone_override` with the pass's own reused table, timed per call. Logs
-- "[r40an2]" lines and shuts the server down.

local N, ROUNDS = 100, 200
local function log(msg) core.log("action", "[r40an2] " .. msg) end

core.register_entity("grug_probe_r40_an2:dummy", {
	initial_properties = {
		visual = "mesh", mesh = grug_visuals.PLAYER_MODEL,
		textures = {"character.png", "blank.png"},
		physical = false, pointable = false, static_save = false,
	},
})

local function measure(pos)
	local objs = {}
	for i = 1, N do
		objs[i] = core.add_entity({x = pos.x + i % 10, y = pos.y, z = pos.z + math.floor(i / 10)},
			"grug_probe_r40_an2:dummy")
	end
	log(("spawned %d of %d"):format(#objs, N))
	if #objs < N then return end
	local vec = {x = 0.001, y = 0, z = 0}
	local rotation = {vec = vec, interpolation = 0.2}
	local override = {rotation = rotation}
	local sum = 0
	local t0 = core.get_us_time()
	for _ = 1, ROUNDS do
		for i = 1, N do sum = sum + objs[i]:get_yaw() end
	end
	local t1 = core.get_us_time()
	for r = 1, ROUNDS do
		vec.x = math.rad((r % 23 - 10) * 5)
		for i = 1, N do objs[i]:set_bone_override("Head", override) end
	end
	local t2 = core.get_us_time()
	local calls = ROUNDS * N
	log(("COST get_yaw %.3f us/call, set_bone_override %.3f us/call (%d calls each, sum %d)"):format(
		(t1 - t0) / calls, (t2 - t1) / calls, calls, sum))
	local o = objs[1]:get_bone_override("Head")
	log(("CHECK Head override read back x=%.4f interpolation=%.2f absolute=%s; head_step=%s"):format(
		o.rotation.vec.x, o.rotation.interpolation, tostring(o.rotation.absolute),
		tostring(grug_visuals.head_step ~= nil)))
	for i = 1, N do objs[i]:remove() end
end

local t, phase, done = 0, "wait", false
local pos = {x = 0, y = 400, z = 0}
core.register_globalstep(function(dtime)
	t = t + dtime
	if phase == "wait" and t > 3 then
		phase = "emerge"
		core.forceload_block(pos, true)
		core.emerge_area(pos, pos, function(_, _, remaining)
			if remaining == 0 then done = true end
		end)
	elseif phase == "emerge" and (done or t > 120) then
		phase = "end"
		log("emerge done=" .. tostring(done))
		measure(pos)
		log("RESULT DONE")
		core.request_shutdown("r40an2 probe done")
	end
end)
