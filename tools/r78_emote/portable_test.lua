-- Round 78 lane EMOTE portable test (LuaJIT): Wave and Dance from the
-- quickbar (round78-plan.md ruling 10, §3.1, §4 EMOTE).
--
--   luajit tools/r78_emote/portable_test.lua [repo]
--
-- Loads the REAL player_api (api.lua, init.lua), grug_visuals' registration
-- (cut from apply.lua), poses.lua, grug_core/ui.lua and grug_quickbar under a
-- small fake engine. Checks:
--   R  the registration: EMOTE_CLIPS' ranges after the poses' (the model's
--      generator holds them to the model), Wave once with a seated clip,
--      Dance looping without one, no walking twin; `wave_sit` carries the
--      seat's eye height, box and local override; the poses stay as they
--      were and NPCs get no emote;
--   P  a click plays once: Wave from its first frame, once, ending after its
--      clip through stand_resume; Dance loops and ends after 4 s;
--   I  interrupts: moving, jumping, an attack (LMB, RMB) end an emote with the
--      matching `<base>_resume`; a cast's pose replaces it; a mount ends it
--      (after the ride the hook does not bring it back); a flinch never cuts
--      it; death and logout clear it;
--   M  mounted: Wave plays seated (the clip goes to the object, player_api
--      keeps `sit`, the mount's own re-assertion changes nothing) and `sit`
--      comes back when it has played; no Dance on a mount; no emote on an
--      attachment that is no seat;
--   L  the rate limit and repeats: one start per EMOTE_GAP, the same emote
--      again while it plays is ignored, the other one replaces it;
--   Q  the quickbar: Wave and Dance buttons on foot, Dance greyed (its own
--      field, style and tooltip) while riding; a click plays the emote once
--      and closes the window; the greyed Dance keeps it open.
-- Prints "R78 EMOTE PORTABLE PASS checks=<n>" or the failures.

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
local joins, leaves, dies, settled, receivers = {}, {}, {}, {}, {}
local timers = {}
local connected, by_name = {}, {}
local shown, closed = {}, {}
core = {
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function(fn) dies[#dies + 1] = fn end,
	register_on_player_receive_fields = function(fn) receivers[#receivers + 1] = fn end,
	register_globalstep = function() end,
	get_connected_players = function() return connected end,
	get_player_by_name = function(name) return by_name[name] end,
	calculate_knockback = function() return 0 end,
	get_us_time = function() return now_us end,
	after = function(seconds, fn) timers[#timers + 1] = {at = now_us + seconds * 1e6, fn = fn} end,
	get_modpath = function(name)
		return ROOT .. (name == "player_api" and "/mods/BASE/" or "/mods/PLAYER/") .. name
	end,
	log = function() end,
	formspec_escape = function(text) return (tostring(text):gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text .. "(c@#ffffff)" end,
	show_formspec = function(name, formname, fs) shown[#shown + 1] = {name = name, form = formname, fs = fs} end,
	close_formspec = function(name, formname) closed[#closed + 1] = {name = name, form = formname} end,
	registered_items = {},
	get_item_group = function() return 0 end,
	settings = {get = function() return nil end},
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
	function p:get_inventory()
		return {get_stack = function() return {is_empty = function() return true end} end}
	end
	return p
end

dofile(ROOT .. "/mods/BASE/player_api/init.lua")
grug_visuals = {}
grug_core = {register_on_settled_incoming_hit = function(fn) settled[#settled + 1] = fn end}
assert(loadstring(cut("mods/PLAYER/grug_visuals/apply.lua",
	"\n(grug_visuals%.PLAYER_MODEL = .-\nend)\n", "player model registration"),
	"=apply.lua registration"))()
dofile(ROOT .. "/mods/PLAYER/grug_visuals/poses.lua")

local GV = grug_visuals
local model = player_api.registered_models[GV.PLAYER_MODEL]
local A = model.animations
local FPS = model.animation_speed

local function join(name)
	local p = new_player(name)
	connected[#connected + 1] = p
	by_name[name] = p
	for _, fn in ipairs(joins) do fn(p) end
	player_api.set_model(p, GV.PLAYER_MODEL)
	return p
end
local function run_timers()
	local due, keep = {}, {}
	for _, t in ipairs(timers) do
		if t.at <= now_us then due[#due + 1] = t else keep[#keep + 1] = t end
	end
	timers = keep
	for _, t in ipairs(due) do t.fn() end
end
local function step(seconds)
	now_us = now_us + seconds * 1e6
	run_timers()
	player_api.globalstep(seconds)
end
local function last(p) return p.sent[#p.sent] end
local function anim_of(p) return player_api.get_animation(p).animation end
-- Mounting and dismounting as grug_mounts/entity.lua does it (attach: the
-- flag and `sit`; the step re-asserts `sit` when it differs; restore_player:
-- the flag and `stand`).
local function mount(p)
	player_api.player_attached[p.name] = true
	player_api.set_animation(p, "sit", 30)
end
local function mount_step(p)
	if anim_of(p) ~= "sit" then player_api.set_animation(p, "sit", 30) end
end
local function dismount(p)
	player_api.player_attached[p.name] = false
	player_api.set_animation(p, "stand", 30)
end

------------------------------------------------------------------------------
-- R: the registration.
------------------------------------------------------------------------------
do
	local E = GV.EMOTE_CLIPS
	local n = 0
	for _ in pairs(E) do n = n + 1 end
	eq(n, 2, "R two emotes")
	check(E.wave and E.wave.stand.x == 485 and E.wave.stand.y == 544, "R wave 485-544 (2 s)")
	check(E.wave and E.wave.sit and E.wave.sit.x == 545 and E.wave.sit.y == 604, "R wave_sit 545-604")
	eq(E.wave and E.wave.once, true, "R wave plays once")
	check(E.dance and E.dance.stand.x == 605 and E.dance.stand.y == 645, "R dance 605-645 (a 40-frame loop)")
	eq(E.dance and E.dance.sit, nil, "R no seated dance")
	eq(E.dance and E.dance.once, nil, "R dance loops")
	local flinch = GV.POSE_CLIPS.flinch.walk
	eq(E.wave.stand.x, flinch.y + 1, "R the emotes follow the last pose clip")
	check(A.wave and A.wave.x == 485 and A.wave.y == 544 and A.wave._grug_phase == nil,
		"R wave registered, starting at its first frame")
	check(A.dance and A.dance.x == 605 and A.dance.y == 645, "R dance registered")
	eq(A.wave_walk, nil, "R no walking twin")
	eq(A.dance_sit, nil, "R no dance_sit")
	local ws = A.wave_sit
	check(ws and ws.x == 545 and ws.y == 604, "R wave_sit registered")
	eq(ws and ws.eye_height, A.sit.eye_height, "R wave_sit has the seat's eye height")
	eq(ws and ws.override_local, true, "R wave_sit overrides the local animations like sit")
	eq(ws and ws._equals, A.sit._equals, "R wave_sit is the seat's property class")
	local pn = 0
	for _ in pairs(GV.POSE_CLIPS) do pn = pn + 1 end
	eq(pn, 7, "R the seven poses stay")
	eq(player_api.registered_models["character.b3d"].animations.wave, nil, "R NPCs get no emote")
end

------------------------------------------------------------------------------
-- P: one click plays once.
------------------------------------------------------------------------------
do
	local p = join("waver")
	step(0.05)
	eq(GV.play_emote(p, "wave"), true, "P wave starts")
	step(0.05)
	eq(anim_of(p), "wave", "P wave plays")
	eq(last(p).start, 485, "P ... from its first frame")
	eq(last(p).loop, false, "P ... once")
	eq(last(p).blend, 0.12, "P ... blending in")
	local sends = #p.sent
	step(1.0)
	eq(anim_of(p), "wave", "P still waving at 1.05 s")
	eq(#p.sent, sends, "P ... with nothing resent")
	step(0.95) -- 2.0 s: past 59 frames at 30 fps
	eq(anim_of(p), "stand_resume", "P wave ends after its clip, back through stand_resume")
	step(0.05)
	eq(anim_of(p), "stand", "P ... then stand")

	step(1)
	eq(GV.play_emote(p, "dance"), true, "P dance starts")
	step(0.05)
	eq(anim_of(p), "dance", "P dance plays")
	eq(last(p).loop, true, "P ... looping")
	eq(last(p).start, 605, "P ... from its first frame")
	step(3.85)
	eq(anim_of(p), "dance", "P still dancing at 3.9 s")
	step(0.15)
	eq(anim_of(p), "stand_resume", "P dance ends after 4 s (three rounds)")
	eq(GV.current_pose(p), nil, "P ... and the row is gone")
end

------------------------------------------------------------------------------
-- I: interrupts.
------------------------------------------------------------------------------
do
	local p = join("mover")
	local cases = {
		{{up = true}, "walk_resume", "walking forward"},
		{{left = true}, "walk_resume", "strafing"},
		{{jump = true}, "stand_resume", "a jump"},
		{{LMB = true}, "mine_resume", "an attack (LMB)"},
		{{RMB = true}, "mine_resume", "a use (RMB)"},
	}
	for _, c in ipairs(cases) do
		for _, emote in ipairs({"wave", "dance"}) do
			step(1.1)
			GV.play_emote(p, emote)
			step(0.05)
			eq(anim_of(p), emote, "I " .. emote .. " plays before " .. c[3])
			p.controls = c[1]
			step(0.05)
			eq(anim_of(p), c[2], "I " .. c[3] .. " ends " .. emote)
			eq(GV.current_pose(p), nil, "I ... and clears it")
			p.controls = {}
			step(0.05)
		end
	end
	step(1.1)
	GV.play_emote(p, "dance")
	step(0.05)
	GV.play_pose(p, "cast1")
	step(0.05)
	eq(anim_of(p), "cast1", "I a cast's pose replaces the dance")
	step(1)
	step(0.05)
	eq(anim_of(p), "stand", "I ... and the dance does not come back")

	step(1.1)
	GV.play_emote(p, "dance")
	step(0.05)
	for _, fn in ipairs(settled) do fn(p, 3, {type = "punch"}) end
	step(0.05)
	eq(anim_of(p), "dance", "I a hit taken does not flinch over an emote")

	-- Mounting mid-dance: the hook stops while attached, the mount plays sit;
	-- after a quick dismount the dance is over.
	mount(p)
	step(0.5)
	eq(anim_of(p), "sit", "I mounting shows sit")
	dismount(p)
	step(0.05)
	eq(anim_of(p), "stand_resume", "I after the ride the dance is over")
	eq(GV.current_pose(p), nil, "I ... and cleared")

	step(1.1)
	GV.play_emote(p, "wave")
	for _, fn in ipairs(dies) do fn(p) end
	eq(GV.current_pose(p), nil, "I death clears an emote")
	step(1.1)
	GV.play_emote(p, "wave")
	for _, fn in ipairs(leaves) do fn(p) end
	eq(GV.current_pose(p), nil, "I logout clears an emote")
end

------------------------------------------------------------------------------
-- M: mounted.
------------------------------------------------------------------------------
do
	local p = join("rider")
	step(0.05)
	mount(p)
	step(0.05)
	local sends = #p.sent
	eq(GV.play_emote(p, "dance"), false, "M no Dance on a mount")
	local ok = GV.play_emote(p, "wave")
	eq(ok, true, "M Wave on a mount")
	eq(#p.sent, sends + 1, "M ... sent at once")
	check(last(p).x == 545 and last(p).y == 604, "M ... the seated clip")
	eq(last(p).loop, false, "M ... once")
	eq(anim_of(p), "sit", "M player_api keeps sit")
	for _ = 1, 10 do
		step(0.1)
		mount_step(p)
	end
	eq(#p.sent, sends + 1, "M the mount's step re-asserts nothing over it")
	step(1.0) -- 2.05 s: past 59 frames at 30 fps
	mount_step(p)
	check(last(p).x == A.sit.x and last(p).y == A.sit.y, "M sit comes back after the clip")
	eq(last(p).start, A.sit.x, "M ... restarted")
	eq(anim_of(p), "sit", "M ... and player_api still says sit")

	-- Dismounting mid-wave: the stand replaces it; the timer leaves the
	-- standing player alone.
	step(1.1)
	GV.play_emote(p, "wave")
	step(0.5)
	dismount(p)
	step(0.05)
	check(last(p).x == A.stand.x and last(p).y == A.stand.y, "M a dismount stands up mid-wave")
	local after = #p.sent
	step(2)
	eq(#p.sent, after, "M ... and the seated timer sends nothing")
	eq(anim_of(p), "stand", "M ... the player stands")

	-- Again while it plays, and an attachment that is no seat.
	mount(p)
	step(1.1)
	GV.play_emote(p, "wave")
	step(1.1)
	local again, why = GV.play_emote(p, "wave")
	check(again == false and why == "playing", "M the seated wave again while it plays is ignored")
	step(1)
	dismount(p)
	step(0.05)
	player_api.player_attached[p.name] = true -- attached, standing (no seat)
	step(1.1)
	local refused, reason = GV.play_emote(p, "wave")
	check(refused == false and reason == "seated", "M no emote attached without a seat")
	player_api.player_attached[p.name] = false
end

------------------------------------------------------------------------------
-- L: the rate limit and repeats.
------------------------------------------------------------------------------
do
	local p = join("spammer")
	step(0.05)
	eq(GV.play_emote(p, "wave"), true, "L a first wave")
	step(0.05)
	local sends = #p.sent
	for _ = 1, 9 do
		local ok, why = GV.play_emote(p, "dance")
		check(ok == false and why == "busy", "L a click within 1 s is refused")
		step(0.05)
	end
	eq(#p.sent, sends, "L ... and sends nothing")
	eq(anim_of(p), "wave", "L ... the wave runs on")
	step(0.6)
	local ok, why = GV.play_emote(p, "wave")
	check(ok == false and why == "playing", "L the same emote again is ignored")
	step(0.05)
	eq(GV.play_emote(p, "dance"), true, "L another emote after the gap")
	step(0.05)
	eq(anim_of(p), "dance", "L ... replaces it")
	eq(last(p).start, 605, "L ... from its first frame")
	eq(GV.play_emote(p, "nod"), false, "L an unknown emote is refused")
	p.hp = 0
	step(1.1)
	eq(GV.play_emote(p, "wave"), false, "L no emote while dead")
	p.hp = 20
end

------------------------------------------------------------------------------
-- Q: the quickbar.
------------------------------------------------------------------------------
do
	sfinv = {inventory_suspended = function() return false end}
	grug_inventory = {POTION_BELT = "grug_potion_belt", POTION_BELT_SIZE = 4,
		home_state = function() return nil end,
		hotbar_switch = function() return "" end,
		hotbar_switch_fields = function() return false end}
	grug_keys = {register_on_press = function() end}
	local toggles = {}
	grug_mounts = {active = {}, TIERS = {{name = "Horse", speed = 8, icon = "horse.png"}},
		owned_tier_ids = function() return {1} end,
		owns_tier = function() return true end,
		model_for = function() return {icon = "horse.png", description = "A horse"} end,
		toggle = function(player, tier) toggles[#toggles + 1] = tier end,
		dismount = function() return true end}
	grug_home = {return_home = function() end}
	core.get_player_window_information = function() return nil end
	dofile(ROOT .. "/mods/CORE/grug_core/ui.lua")
	dofile(ROOT .. "/mods/PLAYER/grug_quickbar/init.lua")
	local QB = grug_quickbar
	local function has(fs, text, label) check(fs:find(text, 1, true) ~= nil, label) end
	local function lacks(fs, text, label) check(fs:find(text, 1, true) == nil, label) end
	local function submit(p, fields)
		for _, fn in ipairs(receivers) do
			if fn(p, QB.FORMNAME, fields) then break end
		end
	end

	local p = join("clicker")
	step(0.05)
	local fs = QB.formspec(p)
	has(fs, "Emotes", "Q an Emotes heading")
	has(fs, ";grug_quickbar_wave;Wave]", "Q a Wave button")
	has(fs, ";grug_quickbar_dance;Dance]", "Q a Dance button on foot")
	lacks(fs, "grug_quickbar_dance_off", "Q ... not greyed on foot")
	local wy = tonumber(fs:match("button%[[%d.]+,([%d.]+);[^%]]*grug_quickbar_wave;"))
	local dy = tonumber(fs:match("button%[[%d.]+,([%d.]+);[^%]]*grug_quickbar_dance;"))
	eq(wy, dy, "Q the two buttons side by side")

	grug_mounts.active[p.name] = {tier = 1}
	fs = QB.formspec(p)
	has(fs, ";grug_quickbar_wave;Wave]", "Q Wave stays while riding")
	has(fs, ";grug_quickbar_dance_off;Dance]", "Q Dance greyed while riding")
	lacks(fs, ";grug_quickbar_dance;", "Q ... with no live Dance field")
	has(fs, "style[grug_quickbar_dance_off,grug_quickbar_dance_off:hovered,grug_quickbar_dance_off:pressed;",
		"Q ... in the greyed style")
	has(fs, "textcolor=#808080", "Q ... grey text")
	has(fs, "tooltip[grug_quickbar_dance_off;Not while riding.]", "Q ... saying why")

	-- A greyed click keeps the window; nothing plays.
	QB.open(p)
	local closes = #closed
	submit(p, {grug_quickbar_dance_off = "Dance"})
	eq(#closed, closes, "Q the greyed Dance keeps the window open")
	eq(GV.current_pose(p), nil, "Q ... and plays nothing")
	grug_mounts.active[p.name] = nil

	QB.open(p)
	submit(p, {grug_quickbar_wave = "Wave"})
	eq(#closed, closes + 1, "Q a Wave click closes the window")
	eq(GV.current_pose(p), "wave", "Q ... and waves")
	submit(p, {grug_quickbar_dance = "Dance"})
	eq(GV.current_pose(p), "wave", "Q a click after the window closed does nothing")
	step(1.1)
	QB.open(p)
	submit(p, {grug_quickbar_dance = "Dance"})
	eq(GV.current_pose(p), "dance", "Q a Dance click dances")
	eq(#toggles, 0, "Q no mount was touched")
end

if failures > 0 then
	print(("R78 EMOTE PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R78 EMOTE PORTABLE PASS checks=%d"):format(checks))
