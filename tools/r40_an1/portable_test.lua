-- Round 40 lane AN1 portable test (LuaJIT): the pose clips and their
-- triggers (round40-plan.md §2.14, §3.2, §4.2 AN1; character_visuals.md §5c).
--
--   luajit tools/r40_an1/portable_test.lua [repo]
--
-- Loads the REAL player_api (api.lua, init.lua), grug_visuals' registration
-- (cut from apply.lua) and poses.lua, the REAL Scout bow-draw hook (cut from
-- scout.lua), and, cut from grug_abilities/init.lua, SKILL_POSES with its
-- trigger, try_cast and the authoritative swing's finish. Checks:
--   R  the registration: every pose and its walking twin with the baked
--      ranges, held clips 20 frames, swing and flinch once; the walk-phase
--      groups (walk, walk_mine, every held walking twin) and the one-shot
--      groups;
--   S  pose per skill: Fireball, Smite, Word of Ruin, Cinderfall cast1; Ice
--      Nova, Glacial Ward, Heal, Mend, Shield cast2; Hold Ground block;
--      Mighty Blow swing; nothing else; every named pose has clips;
--   T  never on the fallback: a refused cast, a cast whose target check
--      fails and a swing skill through try_cast play nothing; a successful
--      cast plays its pose; an authoritative swing without a proc (the Strike
--      fallback), a dodged Mighty Blow and a landed Hamstring play nothing, a
--      landed Mighty Blow plays swing;
--   W  the walking twin: a held pose standing plays its stand clip, on the
--      move its walking twin, which continues the walk cycle's frame offset
--      (play_animation start_frame) and hands it back to walk; sneaking
--      halves the speed and keeps the offset; every switch blends 0.12 s;
--   H  hold times: a cast holds 0.6 s, Hold Ground 1.0 s, a second cast
--      extends without a restart; start_pose holds until stop_pose, which
--      ignores another pose; death and logout clear;
--   O  one-shots: swing plays once (loop false), a second swing restarts it,
--      a twin switch mid-swing keeps its progress, it ends after its clip;
--   F  the flinch: on a settled hit; at most one per 1.5 s; never over
--      another pose, the drawn bow, a seat; and the bow's own clips.
-- Prints "R40 AN1 PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
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
local function near(actual, expected, label)
	return check(actual and math.abs(actual - expected) < 1e-6, label .. " (got " ..
		tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(path, pattern, label)
	local block = read(path):match(pattern)
	assert(block, label .. " not found in " .. path)
	return block
end
table.copy = function(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end

------------------------------------------------------------------------------
-- Fake engine.
------------------------------------------------------------------------------
local now_us = 1e9
local joins, leaves, dies, settled = {}, {}, {}, {}
local connected = {}
core = {
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function(fn) dies[#dies + 1] = fn end,
	register_globalstep = function() end,
	get_connected_players = function() return connected end,
	calculate_knockback = function() return 0 end,
	get_us_time = function() return now_us end,
	get_modpath = function(name)
		return ROOT .. (name == "player_api" and "/mods/BASE/" or "/mods/PLAYER/") .. name
	end,
	log = function() end,
}
minetest = core

local function new_player(name)
	local p = {name = name, controls = {}, hp = 20, sent = {}}
	function p:get_player_name() return self.name end
	function p:get_player_control() return self.controls end
	function p:get_hp() return self.hp end
	function p:set_animation(range, speed, blend, loop)
		self.sent[#self.sent + 1] = {x = range.x, y = range.y, start = range.x,
			speed = speed, blend = blend, loop = loop}
	end
	function p:play_animation(track, spec)
		self.sent[#self.sent + 1] = {track = track, x = spec.min_frame, y = spec.max_frame,
			start = spec.start_frame, speed = spec.speed, blend = spec.blend, loop = spec.loop}
	end
	function p:set_properties() end
	function p:set_local_animation() end
	return p
end

dofile(ROOT .. "/mods/BASE/player_api/init.lua")
grug_visuals = {}
grug_core = {register_on_settled_incoming_hit = function(fn) settled[#settled + 1] = fn end}
assert(loadstring(cut("mods/PLAYER/grug_visuals/apply.lua",
	"\n(grug_visuals%.PLAYER_MODEL = .-\nend)\n", "player model registration"),
	"=apply.lua registration"))()
dofile(ROOT .. "/mods/PLAYER/grug_visuals/poses.lua")
local draws = {}
assert(loadstring("local draws = ...\n" .. cut("mods/PLAYER/grug_abilities/scout.lua",
	"\n(player_api%.register_control_animation_override%(function.-\nend%))\n",
	"bow-draw hook"), "=scout.lua hook"))(draws)

local GV = grug_visuals
local model = player_api.registered_models[GV.PLAYER_MODEL]
local A = model.animations

local function join(name)
	local p = new_player(name)
	connected[#connected + 1] = p
	for _, fn in ipairs(joins) do fn(p) end
	player_api.set_model(p, GV.PLAYER_MODEL)
	return p
end
local function step(seconds)
	now_us = now_us + seconds * 1e6
	player_api.globalstep(seconds)
end
local function last(p) return p.sent[#p.sent] end
local function anim_of(p) return player_api.get_animation(p).animation end

------------------------------------------------------------------------------
-- R: the registration.
------------------------------------------------------------------------------
do
	local expect = {
		cast1 = {221, 240, 241, 260}, cast2 = {261, 280, 281, 300},
		swing = {301, 314, 315, 334, true}, bow = {335, 354, 355, 374},
		block = {375, 394, 395, 414}, charge = {415, 434, 435, 454},
		flinch = {455, 464, 465, 484, true},
	}
	local count = 0
	for pose, e in pairs(expect) do
		count = count + 1
		local s, w = A[pose], A[pose .. "_walk"]
		check(s and s.x == e[1] and s.y == e[2], "R " .. pose .. " stand range")
		check(w and w.x == e[3] and w.y == e[4], "R " .. pose .. " walk range")
		eq(GV.POSE_CLIPS[pose].once, e[5], "R " .. pose .. " once")
		if e[5] then
			eq(s._grug_phase, pose, "R " .. pose .. " one-shot group (stand)")
			eq(w._grug_phase, pose, "R " .. pose .. " one-shot group (walk)")
		else
			eq(s.y - s.x, 19, "R " .. pose .. " held clip loops over 19 frames")
			eq(s._grug_phase, nil, "R " .. pose .. " stand twin starts at its first frame")
			eq(w._grug_phase, "walk", "R " .. pose .. " walking twin in the walk group")
		end
	end
	local n = 0
	for _ in pairs(GV.POSE_CLIPS) do n = n + 1 end
	eq(n, count, "R seven poses")
	eq(A.walk._grug_phase, "walk", "R walk group")
	eq(A.walk_mine._grug_phase, "walk", "R walk_mine group")
	eq(A.stand._grug_phase, nil, "R stand has no group")
	eq(player_api.registered_models["character.b3d"].animations.walk._grug_phase, nil,
		"R the NPC model's table stays player_api's own")
	eq(player_api.registered_models["character.b3d"].animations.cast1, nil,
		"R NPCs get no pose clips")
end

------------------------------------------------------------------------------
-- S and T: pose per skill, only when the skill really fires.
------------------------------------------------------------------------------
grug_abilities = {}
local played = {}
local real_play = GV.play_pose
GV.play_pose = function(player, pose, hold)
	played[#played + 1] = pose
end
local INIT = "mods/PLAYER/grug_abilities/init.lua"
local play_skill_pose = assert(loadstring(cut(INIT,
	"\n(grug_abilities%.SKILL_POSES = {.-\nend)\n", "SKILL_POSES") ..
	"\nreturn play_skill_pose", "=SKILL_POSES"))()
do
	local want = {
		fireball = "cast1", smite = "cast1", word_of_ruin = "cast1", cinderfall = "cast1",
		ice_nova = "cast2", glacial_ward = "cast2", heal = "cast2", mend = "cast2",
		shield_spell = "cast2", hold_ground = "block", mighty_blow = "swing",
	}
	local n = 0
	for id, pose in pairs(grug_abilities.SKILL_POSES) do
		n = n + 1
		eq(pose, want[id], "S pose of " .. id)
		check(GV.POSE_CLIPS[pose] ~= nil, "S " .. pose .. " has clips")
	end
	eq(n, 11, "S eleven skills pose")
	for _, id in ipairs({"strike", "charge", "loose", "hamstring", "taunt", "blink",
			"sidestep", "sprint", "opening", "snare_shot", "pinning_shot"}) do
		eq(grug_abilities.SKILL_POSES[id], nil, "S " .. id .. " plays no skill pose")
	end
end

do
	local refusal, spent, cooled = nil, 0, 0
	grug_abilities.CAST_SOUNDS = {}
	grug_abilities.cost_for = function() return {} end
	grug_abilities.arm_cooldown = function() cooled = cooled + 1 end
	grug_abilities.effective_cooldown = function() return 1 end
	grug_abilities.flash = function() end
	grug_sounds = {play = function() end}
	grug_core.is_stunned = function() return false end
	local try_cast = assert(loadstring(
		"local reset_swing_boundary, refuse_mounted_attack, cast_refusal, spend, " ..
		"arm_cast_interval, play_skill_pose = ...\n" ..
		cut(INIT, "\n(function grug_abilities%.try_cast%(.-\nend)\n", "try_cast"),
		"=try_cast"))(
		function() end, function() return false end, function() return refusal end,
		function() spent = spent + 1 return true end, function() end, play_skill_pose)
	local caster = new_player("caster")
	local function def(id, kind, ok)
		return {id = id, kind = kind or "cast", cast = function() return ok ~= false end}
	end
	played = {}
	refusal = "Fireball is not ready."
	check(not grug_abilities.try_cast(caster, def("fireball"), nil, function() end),
		"T a refused cast fails")
	eq(#played, 0, "T a refused cast (cooldown: the Strike fallback's case) plays no pose")
	refusal = nil
	check(not grug_abilities.try_cast(caster, def("smite", "cast", false), nil, function() end),
		"T a cast without a target fails")
	eq(#played, 0, "T a cast without a target plays no pose")
	grug_abilities.try_cast(caster, def("mighty_blow", "swing"), nil, function() end)
	eq(#played, 0, "T a swing skill through try_cast plays no pose")
	check(grug_abilities.try_cast(caster, def("heal"), nil, function() end),
		"T a cast succeeds")
	eq(played[1], "cast2", "T a successful Heal plays cast2")
	check(grug_abilities.try_cast(caster, def("taunt"), nil, function() end),
		"T Taunt succeeds")
	eq(#played, 1, "T Taunt plays no pose")

	grug_abilities.add_rage = function() end
	grug_abilities.reset_charge = function() end
	grug_core.run_settled_outgoing_action = function() end
	grug_core.combat_debug_due = function() return false end
	grug_core.add_threat = function() end
	local finish = assert(loadstring(
		"local spend, swing_rage, play_skill_pose = ...\n" ..
		cut(INIT, "\n(local function finish_authoritative_swing%(.-\nend)\n", "finish") ..
		"\nreturn finish_authoritative_swing", "=finish"))(
		function() return true end, function() return 8 end, play_skill_pose)
	local function swing(proc, result)
		return finish({player = caster, proc = proc, proc_cost = {}}, result)
	end
	played = {}
	swing(nil, {landed = true, grant_rage = true})
	eq(#played, 0, "T a landed swing without a proc (Strike, the fallback) plays no pose")
	swing({id = "mighty_blow"}, {landed = false})
	eq(#played, 0, "T a dodged Mighty Blow plays no pose")
	swing({id = "mighty_blow"}, {landed = true, cancelled = true})
	eq(#played, 0, "T a cancelled Mighty Blow plays no pose")
	swing({id = "hamstring"}, {landed = true})
	eq(#played, 0, "T a landed Hamstring plays no pose")
	swing({id = "mighty_blow"}, {landed = true})
	eq(played[1], "swing", "T a landed Mighty Blow plays swing")
end
GV.play_pose = real_play

------------------------------------------------------------------------------
-- W: standing and walking twins, the walk phase, the blend.
------------------------------------------------------------------------------
do
	local p = join("walker")
	eq(last(p).x, 0, "W joins standing")
	eq(last(p).blend, 0.12, "W the switch blends 0.12 s")
	p.controls = {up = true}
	step(0.05)
	eq(anim_of(p), "walk", "W walking")
	eq(last(p).start, 168, "W a walk from standing starts at its first frame")
	step(0.15) -- 0.15 s into the walk
	GV.play_pose(p, "cast1")
	step(0.05) -- 0.2 s: frame offset 6
	eq(anim_of(p), "cast1_walk", "W a cast on the move plays the walking twin")
	eq(last(p).track, 1, "W the offset start goes through play_animation track 1")
	near(last(p).start, 241 + 6, "W the walking twin continues the stride")
	eq(last(p).loop, true, "W a held clip loops")
	eq(last(p).blend, 0.12, "W into the pose blends")
	p.controls = {up = true, sneak = true}
	step(0.05) -- 6 + 1.5 = 7.5 frames, then half speed
	eq(last(p).speed, 15, "W sneaking halves the speed")
	near(last(p).start, 241 + 7.5, "W a speed change keeps the offset")
	p.controls = {up = true}
	step(0.6) -- past the hold: 7.5 + 0.6 * 15 = 16.5 frames
	eq(anim_of(p), "walk", "W after the hold back to walk")
	near(last(p).start, 168 + 16.5, "W walk takes the stride back")
	eq(last(p).blend, 0.12, "W out of the pose blends")
	p.controls = {}
	step(0.05)
	eq(anim_of(p), "stand", "W standing again")
	GV.play_pose(p, "cast2")
	step(0.05)
	eq(anim_of(p), "cast2", "W a cast standing plays the stand clip")
	eq(last(p).start, 261, "W the stand clip starts at its first frame")
	p.controls = {up = true}
	step(0.05)
	eq(anim_of(p), "cast2_walk", "W starting to walk switches to the twin")
	eq(last(p).start, 281, "W from a stand clip the walk starts at its first frame")
	p.controls = {}
end

------------------------------------------------------------------------------
-- H: hold times, start/stop, death and logout.
------------------------------------------------------------------------------
do
	local p = join("holder")
	GV.play_pose(p, "cast1")
	step(0.05)
	eq(anim_of(p), "cast1", "H cast1 plays")
	local sends = #p.sent
	step(0.5)
	eq(anim_of(p), "cast1", "H still held at 0.55 s")
	GV.play_pose(p, "cast1")
	step(0.3)
	eq(anim_of(p), "cast1", "H a second cast extends the hold")
	eq(#p.sent, sends, "H ... without a restart or any resend")
	step(0.35)
	eq(anim_of(p), "stand", "H the extended hold ends 0.6 s after the second cast")
	GV.play_pose(p, "block")
	step(0.95)
	eq(anim_of(p), "block", "H Hold Ground's guard holds near 1 s")
	step(0.1)
	eq(anim_of(p), "stand", "H ... and then ends")
	GV.start_pose(p, "charge")
	step(5)
	eq(anim_of(p), "charge", "H start_pose holds until stopped")
	GV.stop_pose(p, "cast1")
	step(0.05)
	eq(anim_of(p), "charge", "H stop_pose of another pose changes nothing")
	GV.stop_pose(p, "charge")
	step(0.05)
	eq(anim_of(p), "stand", "H stop_pose ends it")
	GV.start_pose(p, "charge")
	for _, fn in ipairs(dies) do fn(p) end
	eq(GV.current_pose(p), nil, "H death clears the pose")
	GV.start_pose(p, "charge")
	for _, fn in ipairs(leaves) do fn(p) end
	eq(GV.current_pose(p), nil, "H logout clears the pose")
end

------------------------------------------------------------------------------
-- O: one-shots.
------------------------------------------------------------------------------
do
	local p = join("warrior")
	GV.play_pose(p, "swing")
	step(0.05)
	eq(anim_of(p), "swing", "O swing plays")
	eq(last(p).loop, false, "O ... once")
	eq(last(p).start, 301, "O ... from its first frame")
	local sends = #p.sent
	step(0.1)
	eq(#p.sent, sends, "O a running one-shot is not resent")
	GV.play_pose(p, "swing")
	step(0.05)
	eq(#p.sent, sends + 1, "O a second swing is sent again")
	eq(last(p).start, 301, "O ... and restarts from the first frame")
	step(0.1)
	p.controls = {up = true}
	step(0.05) -- 0.15 s into the restarted swing: 4.5 frames
	eq(anim_of(p), "swing_walk", "O on the move the walking twin")
	near(last(p).start, 315 + 4.5, "O ... keeps the swing's progress")
	eq(last(p).loop, false, "O ... still once")
	step(0.6) -- 24 frames: past the walking twin's 19
	eq(anim_of(p), "walk", "O the swing ends after its clip")
	p.controls = {}
	step(0.05)
	GV.play_pose(p, "swing")
	step(0.4) -- 12 of the stand clip's 13 frames
	eq(anim_of(p), "swing", "O a standing swing runs 13 frames")
	step(0.05)
	eq(anim_of(p), "stand", "O ... then stands")
end

------------------------------------------------------------------------------
-- F: the flinch and the bow.
------------------------------------------------------------------------------
do
	local p = join("tank")
	step(0.05)
	for _, fn in ipairs(settled) do fn(p, 3, {type = "punch"}) end
	step(0.05)
	eq(anim_of(p), "flinch", "F a settled hit flinches")
	eq(last(p).loop, false, "F the flinch plays once")
	step(0.4)
	eq(anim_of(p), "stand", "F the flinch ends")
	GV.flinch(p)
	step(0.05)
	eq(anim_of(p), "stand", "F no second flinch within 1.5 s")
	step(1.2)
	GV.flinch(p)
	step(0.05)
	eq(anim_of(p), "flinch", "F a flinch again after 1.5 s")
	step(2)
	GV.play_pose(p, "cast1")
	step(0.05)
	GV.flinch(p)
	step(0.05)
	eq(anim_of(p), "cast1", "F never over another pose")
	step(2)
	draws[p.name] = {}
	step(0.05)
	eq(anim_of(p), "bow", "F the drawn bow plays bow")
	p.controls = {up = true}
	step(0.05)
	eq(anim_of(p), "bow_walk", "F ... and bow_walk on the move")
	near(last(p).start, 355, "F the bow's walking twin from standing starts at its first frame")
	GV.flinch(p)
	step(0.05)
	eq(anim_of(p), "bow_walk", "F never over the drawn bow")
	draws[p.name] = nil
	p.controls = {}
	step(2)
	player_api.player_attached[p.name] = true
	GV.flinch(p)
	eq(GV.current_pose(p), nil, "F never on a seat")
	player_api.player_attached[p.name] = false
	step(0.05)
	GV.flinch(p)
	eq(GV.current_pose(p), "flinch", "F standing again it flinches")
end

if failures > 0 then
	print(("R40 AN1 PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R40 AN1 PORTABLE PASS checks=%d"):format(checks))
