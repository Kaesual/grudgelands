-- Round 40 lane AN2 portable test (LuaJIT): the head look (round40-plan.md
-- §2.14 H1, §3.2, §4.2 AN2; character_visuals.md §5d).
--
--   luajit tools/r40_an2/portable_test.lua [repo]   (VERBOSE=1 lists every check)
--
-- Loads the REAL grug_visuals/head_look.lua on a stand-in engine and reads the
-- REAL player model (grug_visuals_character.b3d). Checks:
--   S  the sign on the model file: the face is the side away from the cloak,
--      up is +y; the override the module writes for a look up, composed the
--      engine's way (activeobject.h getRotationEulerDeg, BoneSceneNode,
--      quaternion::getMatrix_transposed), turns the face up, and for a look
--      down turns it down, in every frame of every played clip but lay (a
--      dead player's head stays level);
--   Q  quantization: 5° steps, rounded to the nearest, clamped at 50° down
--      and 60° up; the written override is the Head bone, a relative rotation
--      about x only, the step's angle in radians, blended over 0.15 s;
--   E  the epsilon: the join writes the level head unblended, a level head is
--      the epsilon, never identity (no write is ever all zero);
--   R  the rate cap: a player looking around without pause is written at most
--      four times a second (two server step lengths); a steady look writes
--      nothing after the join;
--   P  the spread: with 100 players no step visits all of them, each is
--      visited about every 0.25 s, and one long step visits each once;
--   L  lifecycle: the pass levels a dead player's head and stops reading its
--      look, respawn resumes it, a player joining dead stays level, leaving
--      drops the player;
--   H  holds: no Head write while the charge pose runs or while hold_head
--      holds (lane CH's Body lead blends back), a longer hold stays, the look
--      catches up on the first visit after.
-- Prints "R40 AN2 PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local VERBOSE = os.getenv("VERBOSE")
local function check(ok, label)
	checks = checks + 1
	if VERBOSE and ok then print("ok   " .. label) end
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

-- --- the stand-in engine --------------------------------------------------------
local steps, joins, leaves, deaths, respawns = {}, {}, {}, {}, {}
local now_us = 0
core = {
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function(fn) deaths[#deaths + 1] = fn end,
	register_on_respawnplayer = function(fn) respawns[#respawns + 1] = fn end,
	get_us_time = function() return now_us end,
}
-- poses.lua's query (the charge pose blocks writes): a field of the stand-in.
grug_visuals = {current_pose = function(player) return player.pose end}
dofile(ROOT .. "/mods/PLAYER/grug_visuals/head_look.lua")
eq(#steps, 1, "one globalstep")

local writes = {}
local function new_player(name, hp)
	local p = {name = name, hp = hp or 20, look = 0, looks = 0, writes = {}}
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_look_vertical()
		self.looks = self.looks + 1
		return self.look
	end
	function p:set_bone_override(bone, override)
		-- The engine copies the table during the call; so does this.
		local r = override.rotation
		local w = {bone = bone, x = r.vec.x, y = r.vec.y, z = r.vec.z,
			interpolation = r.interpolation, absolute = r.absolute,
			position = override.position, scale = override.scale}
		self.writes[#self.writes + 1] = w
		writes[#writes + 1] = w
	end
	return p
end
local function join(p) for _, fn in ipairs(joins) do fn(p) end end
local function leave(p) for _, fn in ipairs(leaves) do fn(p) end end
local function die(p) for _, fn in ipairs(deaths) do fn(p) end end
local function respawn(p) for _, fn in ipairs(respawns) do fn(p) end end
local function step(dtime)
	now_us = now_us + math.floor(dtime * 1e6 + 0.5)
	steps[1](dtime)
end

local HL = grug_visuals.HEAD_LOOK
local rad = math.rad

-- --- S: the sign on the model file --------------------------------------------
-- A minimal B3D reader: NODE names, bind position and rotation, KEYS.
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local data = read("mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d")
local function i32(at)
	local a, b, c, d = data:byte(at, at + 3)
	local v = a + b * 256 + c * 65536 + d * 16777216
	return v >= 2147483648 and v - 4294967296 or v
end
local function f32(at)
	local a, b, c, d = data:byte(at, at + 3)
	local sign = d >= 128 and -1 or 1
	local e = (d % 128) * 2 + math.floor(c / 128)
	local m = ((c % 128) * 256 + b) * 256 + a
	if e == 0 then return sign * math.ldexp(m, -149) end
	return sign * math.ldexp(1 + m / 8388608, e - 127)
end
local nodes = {}
local function parse(at, stop, parent)
	while at < stop do
		local tag, size = data:sub(at, at + 3), i32(at + 4)
		local body, finish = at + 8, at + 8 + size
		if tag == "BB3D" or tag == "MESH" then
			parse(body + 4, finish, parent)
		elseif tag == "NODE" then
			local zero = data:find("\0", body, true)
			local node = {name = data:sub(body, zero - 1), parent = parent, keys = {}}
			local v = zero + 1
			node.pos = {f32(v), f32(v + 4), f32(v + 8)}
			-- file order w, x, y, z; Irrlicht quaternions are (X, Y, Z, W)
			node.rot = {f32(v + 28), f32(v + 32), f32(v + 36), f32(v + 24)}
			nodes[node.name] = node
			parse(v + 40, finish, node)
		elseif tag == "KEYS" and parent then
			assert(i32(body) == 7, "keys with position, scale and rotation")
			for k = body + 4, finish - 1, 44 do
				parent.keys[i32(k)] = {f32(k + 32), f32(k + 36), f32(k + 40), f32(k + 28)}
			end
		end
		at = finish
	end
end
parse(1, #data + 1, nil)
local body, head, cloak = nodes.Body, nodes.Head, nodes.Cloak
check(body and head and cloak and head.parent == body and cloak.parent == body,
	"S Head and Cloak hang under Body")

-- Irrlicht's quaternion maths, verbatim (irr/include/quaternion.h).
local function qmul(a, o) -- a * o
	return {o[4] * a[1] + o[1] * a[4] + o[2] * a[3] - o[3] * a[2],
		o[4] * a[2] + o[2] * a[4] + o[3] * a[1] - o[1] * a[3],
		o[4] * a[3] + o[3] * a[4] + o[1] * a[2] - o[2] * a[1],
		o[4] * a[4] - o[1] * a[1] - o[2] * a[2] - o[3] * a[3]}
end
local function qinv(q) return {-q[1], -q[2], -q[3], q[4]} end
local function from_euler(x, y, z)
	local sr, cr = math.sin(x / 2), math.cos(x / 2)
	local sp, cp = math.sin(y / 2), math.cos(y / 2)
	local sy, cy = math.sin(z / 2), math.cos(z / 2)
	return {sr * cp * cy - cr * sp * sy, cr * sp * cy + sr * cp * sy,
		cr * cp * sy - sr * sp * cy, cr * cp * cy + sr * sp * sy}
end
-- getMatrix_transposed, applied the way Irrlicht's transformVect applies it.
local function rotate(q, v)
	local n = math.sqrt(q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4])
	local X, Y, Z, W = q[1] / n, q[2] / n, q[3] / n, q[4] / n
	local m = {[0] = 1 - 2 * Y * Y - 2 * Z * Z, 2 * X * Y - 2 * Z * W, 2 * X * Z + 2 * Y * W, 0,
		2 * X * Y + 2 * Z * W, 1 - 2 * X * X - 2 * Z * Z, 2 * Z * Y - 2 * X * W, 0,
		2 * X * Z - 2 * Y * W, 2 * Z * Y + 2 * X * W, 1 - 2 * X * X - 2 * Y * Y}
	return {m[0] * v[1] + m[4] * v[2] + m[8] * v[3],
		m[1] * v[1] + m[5] * v[2] + m[9] * v[3],
		m[2] * v[1] + m[6] * v[2] + m[10] * v[3]}
end
local function unrotate(q, v) return rotate(qinv(q), v) end

-- The model's own up and face. Up: the head sits above the body's pivot. The
-- face: away from the cloak, which hangs on the back.
local root = assert(nodes.Player, "the root node")
check(body.parent == root, "S Body hangs under the root")
local head_at = rotate(root.rot, rotate(body.rot, head.pos))
check(head_at[2] > 0, "S the head is above the body's pivot: up is +y")
local cloak_at = rotate(root.rot, rotate(body.rot, cloak.pos))
local face = {-cloak_at[1], 0, -cloak_at[3]}
local flen = math.sqrt(face[1] * face[1] + face[3] * face[3])
check(flen > 1, "S the cloak hangs behind the body")
face = {face[1] / flen, 0, face[3] / flen}
-- The face in the head's own frame, from the bind pose.
local face_local = unrotate(head.rot, unrotate(body.rot, unrotate(root.rot, face)))

-- The face in the model for a frame's keys and a Head override (Euler
-- radians as the module writes them): getRotationEulerDeg composes
-- `override * quaternion(bone->getRotation())`, where getRotation() is the
-- inverse of the joint's quaternion, and setRotation stores the inverse
-- again (BoneSceneNode).
local function face_at(frame, ox)
	local joint = head.keys[frame] or head.rot
	local bq = body.keys[frame] or body.rot
	local final = joint
	if ox then
		final = qinv(qmul(from_euler(ox, 0, 0), qinv(joint)))
	end
	return rotate(nodes.Player.rot, rotate(bq, rotate(final, face_local)))
end

-- The overrides the module writes for a look 30° up and 30° down.
local probe = new_player("probe")
join(probe)
probe.look = -rad(30) -- the engine's pitch: negative is up
step(1)
local up_write = probe.writes[#probe.writes]
probe.look = rad(30)
step(1)
local down_write = probe.writes[#probe.writes]
leave(probe)
check(up_write and up_write.x > 0 and down_write and down_write.x < 0,
	"S a look up writes a positive x, a look down a negative one")

local level = face_at(1)
check(math.abs(level[2]) < 1e-6 and level[3] * face[3] + level[1] * face[1] > 0.999,
	"S stand frame 0 looks level ahead")
-- The played ranges in engine frames (file frame f is engine frame f - 1):
-- player_api's stand, sit, walk, mine and walk_mine, and the Round 40 pose
-- clips after them (grug_visuals.POSE_CLIPS); not lay (162-166, a dead
-- player's head stays level) nor the unplayed frames between ranges.
local PLAYED = {{0, 79}, {81, 160}, {168, 187}, {189, 198}, {200, 219}, {221, 484}}
local function played(engine_frame)
	for _, r in ipairs(PLAYED) do
		if engine_frame >= r[1] and engine_frame <= r[2] then return true end
	end
	return false
end
local frames, wrong, least = 0, {}, math.huge
for frame in pairs(head.keys) do
	if played(frame - 1) then
		frames = frames + 1
		local base = face_at(frame)
		local up = face_at(frame, up_write.x)
		local down = face_at(frame, down_write.x)
		least = math.min(least, up[2] - base[2], base[2] - down[2])
		if not (up[2] > base[2] + 0.1 and down[2] < base[2] - 0.1) then
			wrong[#wrong + 1] = frame - 1
		end
	end
end
check(frames > 400, "S every clip's frames are read (" .. frames .. ", the face moves "
	.. string.format("%.2f", least) .. " at least)")
check(#wrong == 0, "S up raises and down lowers the face in every played frame but lay"
	.. (#wrong > 0 and (" (wrong at " .. table.concat(wrong, ", ") .. ")") or ""))
local up_level = face_at(1, up_write.x)
check(math.abs(up_level[2] - math.sin(rad(30))) < 1e-4,
	"S over the stand frame 30° up is exactly 30° (" .. up_level[2] .. ")")

-- --- Q: quantization and the written override --------------------------------
local cases = {
	{0, 0}, {2.4, 0}, {-2.4, 0}, {2.6, 5}, {-2.6, -5}, {7.4, 5}, {7.6, 10},
	{47.4, 45}, {58, 60}, {62, 60}, {89.5, 60}, {-47.4, -45}, {-48, -50},
	{-55, -50}, {-89.5, -50},
}
for _, c in ipairs(cases) do
	eq(grug_visuals.head_step(-rad(c[1])), c[2], "Q " .. c[1] .. "° up steps to")
end
eq(HL.step, 5, "Q the step is 5°")
eq(HL.down, -50, "Q the clamp down")
eq(HL.up, 60, "Q the clamp up")
check(up_write.bone == "Head", "Q the Head bone")
check(math.abs(up_write.x - rad(30)) < 1e-12 and up_write.y == 0 and up_write.z == 0,
	"Q x only, the step in radians")
check(not up_write.absolute and up_write.position == nil and up_write.scale == nil,
	"Q a relative rotation, nothing else")
eq(up_write.interpolation, 0.15, "Q blended over 0.15 s")
check(HL.blend < 2 * 0.09, "Q the blend ends before the next write (two default steps)")

-- --- E: the epsilon -------------------------------------------------------------
writes = {}
local e = new_player("e")
e.look = -rad(40)
join(e)
eq(#e.writes, 1, "E the join writes at once")
local first = e.writes[1]
eq(first.x, HL.epsilon, "E the join writes the level head")
eq(first.interpolation, 0, "E unblended (the client snaps the first anyway)")
step(1)
check(math.abs(e.writes[2].x - rad(40)) < 1e-12, "E then the look")
e.look = rad(1) -- level again
step(1)
eq(e.writes[3].x, HL.epsilon, "E a level head is the epsilon")
check(HL.epsilon > 0 and HL.epsilon < rad(0.1), "E the epsilon is tiny but not zero")
leave(e)

-- --- R: the rate cap ------------------------------------------------------------
local function sweep(dtime, seconds)
	local p = new_player("r")
	join(p)
	local t, times = 0, {}
	while t < seconds do
		t = t + dtime
		-- Looking around without pause: a triangle from 45° down to 55° up
		-- and back every 0.7 s (inside the clamp, out of step with the pass).
		local phase = (t % 0.7) / 0.7
		local deg = (phase < 0.5 and phase * 2 or 2 - phase * 2) * 100 - 45
		p.look = -rad(deg)
		local before = #p.writes
		step(dtime)
		for _ = before + 1, #p.writes do times[#times + 1] = t end
	end
	leave(p)
	local gap = math.huge
	for i = 3, #times do gap = math.min(gap, times[i] - times[i - 1]) end
	return (#p.writes - 1) / seconds, gap
end
for _, dtime in ipairs({0.09, 0.05, 0.03}) do
	local rate, gap = sweep(dtime, 60)
	check(rate <= 4.0 + 0.05 and rate > 3, "R looking around at dtime " .. dtime ..
		" writes " .. string.format("%.2f", rate) .. " per second")
	check(gap >= 2 * dtime - 1e-9 and gap >= HL.period - dtime - 1e-9,
		"R at dtime " .. dtime .. " two writes are at least " ..
		string.format("%.2f", gap) .. " s apart")
end
do
	local p = new_player("still")
	p.look = -rad(20)
	join(p)
	for _ = 1, 200 do step(0.09) end
	eq(#p.writes, 2, "R a steady look: the join and one write, then nothing")
	leave(p)
end

-- --- P: the spread -------------------------------------------------------------
do
	local ps = {}
	for i = 1, 100 do
		ps[i] = new_player("p" .. i)
		join(ps[i])
	end
	local max_step, total = 0, 0
	for _ = 1, 100 do -- 9 s
		local before = 0
		for i = 1, 100 do before = before + ps[i].looks end
		step(0.09)
		local after = 0
		for i = 1, 100 do after = after + ps[i].looks end
		max_step = math.max(max_step, after - before)
		total = total + after - before
	end
	check(max_step < 100 and max_step <= math.ceil(100 * 0.09 / HL.period),
		"P no step visits everyone (most in one step: " .. max_step .. ")")
	local lo, hi = math.huge, 0
	for i = 1, 100 do
		lo = math.min(lo, ps[i].looks)
		hi = math.max(hi, ps[i].looks)
	end
	-- 9 s at one visit per 0.25 s: 36 each.
	check(lo >= 35 and hi <= 37, "P each player visited about every 0.25 s (" ..
		lo .. "-" .. hi .. " in 9 s)")
	for i = 1, 100 do ps[i].looks = 0 end
	step(5) -- a long step
	local once = true
	for i = 1, 100 do once = once and ps[i].looks == 1 end
	check(once, "P a long step visits each player once")
	for i = 1, 100 do leave(ps[i]) end
	ps[1].looks = 0
	step(1)
	eq(ps[1].looks, 0, "P nobody visited after leaving")
end

-- --- L: lifecycle ---------------------------------------------------------------
do
	local p = new_player("l")
	join(p)
	p.look = -rad(30)
	step(1)
	eq(#p.writes, 2, "L looking up written")
	die(p)
	eq(#p.writes, 2, "L death itself writes nothing")
	p.looks = 0
	step(1)
	eq(#p.writes, 3, "L the pass levels a dead player's head")
	eq(p.writes[3].x, HL.epsilon, "L to the epsilon")
	eq(p.writes[3].interpolation, HL.blend, "L blended")
	for _ = 1, 20 do step(0.09) end
	eq(p.looks, 0, "L a dead player's look is not read")
	eq(#p.writes, 3, "L a level head is not written again")
	respawn(p)
	step(1)
	check(p.looks > 0 and math.abs(p.writes[#p.writes].x - rad(30)) < 1e-12,
		"L respawn resumes the look")
	leave(p)
	local d = new_player("d", 0)
	join(d)
	eq(#d.writes, 1, "L joining dead: the level head")
	step(1)
	eq(d.looks, 0, "L joining dead: the look is not read")
	eq(#d.writes, 1, "L joining dead: stays level")
	respawn(d)
	step(1)
	check(d.looks > 0, "L joining dead: visited after respawn")
	leave(d)
end

-- --- H: holds -------------------------------------------------------------------
do
	local p = new_player("h")
	join(p)
	p.pose = "charge"
	p.look = -rad(30)
	for _ = 1, 20 do step(0.09) end
	eq(#p.writes, 1, "H no Head write while the charge pose runs")
	p.pose = "cast1"
	step(1)
	eq(#p.writes, 2, "H another pose does not hold")
	p.pose = nil
	-- CH's effects_end: the pose stops and the head is held (one player and
	-- 0.25 s steps: one visit per step).
	grug_visuals.hold_head(p, 0.6)
	p.look = -rad(45)
	step(0.25)
	eq(#p.writes, 2, "H no write during the hold")
	grug_visuals.hold_head(p, 0.1) -- a shorter hold does not cut the longer
	step(0.25)
	eq(#p.writes, 2, "H a shorter hold leaves the running one")
	step(0.25)
	eq(#p.writes, 3, "H after the hold the look catches up")
	check(math.abs(p.writes[3].x - rad(45)) < 1e-12, "H to the current step")
	grug_visuals.hold_head(new_player("nobody"), 1) -- not joined: no error
	-- A dead player under the charge pose levels only after it.
	p.pose = "charge"
	die(p)
	step(1)
	eq(#p.writes, 3, "H death waits for the charge pose too")
	p.pose = nil
	step(1)
	eq(p.writes[4].x, HL.epsilon, "H then levels")
	leave(p)
end

-- No write anywhere was identity.
local identity = 0
for _, w in ipairs(writes) do
	if w.x == 0 and w.y == 0 and w.z == 0 then identity = identity + 1 end
end
eq(identity, 0, "E no write is identity")

if failures > 0 then
	error(string.format("R40 AN2 PORTABLE FAIL failures=%d checks=%d", failures, checks), 0)
end
print(string.format("R40 AN2 PORTABLE PASS checks=%d", checks))
