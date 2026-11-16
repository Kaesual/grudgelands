-- Round 80 lane EMOTE portable test (LuaJIT): Cheer, the ownership gate and
-- the quickbar's emote icons (round80-plan.md rulings 1, 2, 7, 8, §3.1,
-- §3.3, §4 EMOTE).
--
--   luajit tools/r80_emote/portable_test.lua [repo]
--
-- Loads the REAL player_api, grug_visuals' registration (cut from apply.lua)
-- and poses.lua, grug_core/ui.lua, grug_quickbar and the REAL grug_accounts
-- model (model.lua, behind a small grug_accounts table with its
-- has_reward/register_reward) under a small fake engine. Checks:
--   C  the clip: EMOTE_CLIPS.cheer 702-761 standing and 762-821 seated, once,
--      right after Dance; `cheer` and `cheer_sit` registered like Wave's
--      (its own group, the seat's eye height, box and local override);
--      Cheer plays once for 2 s and ends through stand_resume, a move ends
--      it early, and seated it goes to the object and `sit` comes back;
--   O  ownership (grug_quickbar.owns_emote, grug_quickbar.emotes): Wave and
--      Dance for everyone; Cheer for no account, an account without and
--      with `emote:cheer`, the reward removed, a binding for another
--      character id; the order Wave, Dance, Cheer;
--   G  the gate: play_emote refuses Cheer with "not_owned" without the
--      reward (no animation sent), plays it with it and refuses again once
--      the list drops it; an unknown emote stays "unknown";
--   K  the catalogue: `emote:cheer`, kind emote, name Cheer, the Cheer icon,
--      the hint; the textures of every emote exist (icon and `_off`);
--   Q  the quickbar: image buttons four to a row in the mounts' slot size,
--      only the owned emotes, each tooltip the emote's name; riding: Wave
--      and Cheer live, Dance greyed (its `_off` field and dimmed icon, the
--      tooltip says why), a greyed click keeps the window open; a click
--      plays and closes; a forged Cheer click without the reward plays
--      nothing; the emote rows at the smallest and the largest text size.
-- Prints "R80 EMOTE PORTABLE PASS checks=<n>" or the failures.

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
local function exists(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if handle then handle:close() end
	return handle ~= nil
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
local window_info
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
	get_player_window_information = function() return window_info end,
	registered_items = {},
	get_item_group = function() return 0 end,
	settings = {get = function() return nil end},
	serialize = function() return "" end,
	deserialize = function() return nil end,
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
assert(loadstring(read("mods/PLAYER/grug_visuals/apply.lua"):match(
	"\n(grug_visuals%.PLAYER_MODEL = .-\nend)\n"), "=apply.lua registration"))()
dofile(ROOT .. "/mods/PLAYER/grug_visuals/poses.lua")

-- The real accounts model behind the part of grug_accounts' API the
-- quickbar uses.
local storage = {data = {}}
function storage:get_string(key) return self.data[key] or "" end
function storage:set_string(key, value) self.data[key] = value end
local online_ids = {}
local model = dofile(ROOT .. "/mods/PLAYER/grug_accounts/model.lua")({storage = storage,
	serialize = function() return "" end, deserialize = function() return nil end,
	log = function() end, online_id = function(name) return online_ids[name] end})
grug_accounts = {
	has_reward = model.has_reward,
	register_reward = model.register_reward,
	register_on_change = function() end,
}
local list_version = 0
local function apply(accounts, characters)
	list_version = list_version + 1
	model.apply({version = list_version, accounts = accounts, characters = characters})
end
local ID = {}
for _, name in ipairs({"plain", "linked", "fan", "rider", "other"}) do
	ID[name] = (("%x"):format(#name)):rep(32):sub(1, 32)
	online_ids[name] = ID[name]
end

-- The quickbar's other dependencies.
sfinv = {inventory_suspended = function() return false end}
grug_inventory = {POTION_BELT = "grug_potion_belt", POTION_BELT_SIZE = 4,
	home_state = function() return nil end,
	hotbar_switch = function() return "" end,
	hotbar_switch_fields = function() return false end}
grug_keys = {register_on_press = function() end}
grug_mounts = {active = {}, TIERS = {{name = "Horse", speed = 8, icon = "horse.png"}},
	owned_tier_ids = function() return {1} end,
	owns_tier = function() return true end,
	model_for = function() return {icon = "horse.png", description = "A horse"} end,
	toggle = function() end,
	dismount = function() return true end}
grug_home = {return_home = function() end}
dofile(ROOT .. "/mods/CORE/grug_core/ui.lua")
dofile(ROOT .. "/mods/PLAYER/grug_quickbar/init.lua")

local GV, QB = grug_visuals, grug_quickbar
local pmodel = player_api.registered_models[GV.PLAYER_MODEL]
local A = pmodel.animations

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
local function ids(list)
	local out = {}
	for index, entry in ipairs(list) do out[index] = entry.id end
	return table.concat(out, ",")
end
local function has(fs, text, label) check(fs:find(text, 1, true) ~= nil, label) end
local function lacks(fs, text, label) check(fs:find(text, 1, true) == nil, label) end
local function submit(p, fields)
	for _, fn in ipairs(receivers) do
		if fn(p, QB.FORMNAME, fields) then break end
	end
end

-- Every account below is granted from here on; `fan` is linked with Cheer.
local function grant(with_cheer)
	apply({{id = "acc_linked", name = "Linked", rewards = {"cloak:supporter"}},
		{id = "acc_fan", name = "Fan", rewards = with_cheer and {"emote:cheer"} or {}}},
		{{name = "linked", character_id = ID.linked, account_id = "acc_linked"},
		{name = "fan", character_id = ID.fan, account_id = "acc_fan"},
		{name = "rider", character_id = ID.rider, account_id = "acc_fan"},
		-- A binding for another character id of the same name counts for nothing.
		{name = "other", character_id = ("e"):rep(32), account_id = "acc_fan"}})
end

------------------------------------------------------------------------------
-- C: the clip.
------------------------------------------------------------------------------
do
	local E = GV.EMOTE_CLIPS
	local n = 0
	for _ in pairs(E) do n = n + 1 end
	eq(n, 3, "C three emotes")
	local c = E.cheer
	check(c and c.stand.x == 702 and c.stand.y == 761, "C cheer 702-761 (60 frames, 2 s)")
	check(c and c.sit and c.sit.x == 762 and c.sit.y == 821, "C cheer_sit 762-821")
	eq(c and c.once, true, "C cheer plays once")
	eq(c.stand.x, E.dance.stand.y + 1, "C cheer follows the dance")
	check(A.cheer and A.cheer.x == 702 and A.cheer.y == 761, "C cheer registered")
	eq(A.cheer and A.cheer._grug_phase, "cheer", "C cheer in its own group")
	local cs = A.cheer_sit
	check(cs and cs.x == 762 and cs.y == 821, "C cheer_sit registered")
	eq(cs and cs._grug_phase, "cheer", "C cheer_sit in the cheer's group")
	eq(cs and cs.eye_height, A.sit.eye_height, "C cheer_sit has the seat's eye height")
	eq(cs and cs.override_local, true, "C cheer_sit overrides the local animations like sit")
	eq(A.cheer_walk, nil, "C no walking twin")
	eq(player_api.registered_models["character.b3d"].animations.cheer, nil, "C NPCs get no cheer")
end

------------------------------------------------------------------------------
-- O, G, K: ownership, the gate, the catalogue.
------------------------------------------------------------------------------
do
	local plain, linked, fan, other = join("plain"), join("linked"), join("fan"), join("other")
	step(0.05)
	-- No list at all.
	eq(ids(QB.emotes(plain)), "wave,dance", "O no account: Wave and Dance")
	eq(QB.owns_emote(plain, "wave"), true, "O Wave for everyone")
	eq(QB.owns_emote(plain, "dance"), true, "O Dance for everyone")
	eq(QB.owns_emote(plain, "cheer"), false, "O no account: no Cheer")
	eq(QB.owns_emote(plain, "nod"), false, "O an unknown emote is nobody's")
	local sends = #plain.sent
	local ok, why = GV.play_emote(plain, "cheer")
	check(ok == false and why == "not_owned", "G no account: Cheer refused as not_owned (" ..
		tostring(why) .. ")")
	step(0.05)
	eq(#plain.sent, sends, "G ... and nothing is sent")
	eq(GV.current_pose(plain), nil, "G ... and nothing plays")
	local ok2, why2 = GV.play_emote(plain, "nod")
	check(ok2 == false and why2 == "unknown", "G an unknown emote stays unknown")
	eq(GV.play_emote(plain, "wave"), true, "G Wave plays without an account")

	grant(false)
	eq(ids(QB.emotes(linked)), "wave,dance", "O an account without emote:cheer: no Cheer")
	eq(ids(QB.emotes(fan)), "wave,dance", "O ... nor for the other account before its grant")
	grant(true)
	eq(ids(QB.emotes(fan)), "wave,dance,cheer", "O with emote:cheer: Wave, Dance, Cheer")
	eq(ids(QB.emotes(linked)), "wave,dance", "O ... only for that account's characters")
	eq(ids(QB.emotes(other)), "wave,dance", "O a binding for another character id gives nothing")
	eq(GV.play_emote(fan, "cheer"), true, "G with the reward Cheer plays")
	step(0.05)
	eq(anim_of(fan), "cheer", "G ... the cheer clip")
	eq(last(fan).start, 702, "G ... from its first frame")
	eq(last(fan).loop, false, "G ... once")
	step(1.0)
	eq(anim_of(fan), "cheer", "C still cheering at 1.05 s")
	step(0.95)
	eq(anim_of(fan), "stand_resume", "C cheer ends after its 2 s clip, through stand_resume")
	step(1.1)
	GV.play_emote(fan, "cheer")
	step(0.05)
	fan.controls = {up = true}
	step(0.05)
	eq(anim_of(fan), "walk_resume", "C a move ends the cheer")
	fan.controls = {}
	step(1.1)

	grant(false)
	eq(ids(QB.emotes(fan)), "wave,dance", "O the reward removed: Cheer is gone")
	local ok3, why3 = GV.play_emote(fan, "cheer")
	check(ok3 == false and why3 == "not_owned", "G ... and refused again at once")

	-- K: the catalogue entry and the textures.
	local entry
	for _, row in ipairs(model.catalog()) do
		if row.id == "emote:cheer" then entry = row end
	end
	check(entry ~= nil, "K emote:cheer in the catalogue")
	eq(entry and entry.kind, "emote", "K ... kind emote")
	eq(entry and entry.name, "Cheer", "K ... named Cheer")
	eq(entry and entry.icon, "grug_quickbar_emote_cheer.png", "K ... the Cheer icon")
	eq(entry and entry.hint, "Play it from the quickbar (E).", "K ... the hint")
	for _, e in ipairs(QB.EMOTES) do
		check(GV.EMOTE_CLIPS[e.id] ~= nil, "K " .. e.id .. " has a clip")
		for _, suffix in ipairs({"", "_off"}) do
			local file = "mods/PLAYER/grug_quickbar/textures/grug_quickbar_emote_" .. e.id .. suffix .. ".png"
			check(exists(file), "K " .. file .. " exists")
		end
	end
	eq(ids(QB.EMOTES), "wave,dance,cheer", "K the grid's order: Wave, Dance, then the rewards")
end

------------------------------------------------------------------------------
-- Q: the quickbar.
------------------------------------------------------------------------------
do
	grant(true)
	local plain, fan = by_name.plain, by_name.fan
	local rider = join("rider")
	step(1.1)
	local function button(fs, field)
		local x, y, w, h, img = fs:match("image_button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^;]*);" ..
			field:gsub("_", "%%_") .. ";%]")
		return tonumber(x), tonumber(y), tonumber(w), tonumber(h), img
	end
	local fs = QB.formspec(plain)
	has(fs, "Emotes", "Q the Emotes heading")
	local wx, wy, ww, wh, wimg = button(fs, "grug_quickbar_emote_wave")
	local dx, dy, _, _, dimg = button(fs, "grug_quickbar_emote_dance")
	check(wx ~= nil and dx ~= nil, "Q Wave and Dance are image buttons")
	eq(wimg, "grug_quickbar_emote_wave.png", "Q Wave's icon")
	eq(dimg, "grug_quickbar_emote_dance.png", "Q Dance's icon")
	local mx, _, mw, mh = button(fs, "grug_quickbar_mount_1")
	eq(ww, mw, "Q the mounts' slot width")
	eq(wh, mh, "Q ... and height")
	eq(wx, mx, "Q the first emote in the first column")
	eq(wy, dy, "Q Wave and Dance in one row")
	eq(dx - wx, 1.25, "Q one slot pitch apart")
	lacks(fs, "grug_quickbar_emote_cheer", "Q no Cheer without the reward")
	has(fs, "tooltip[grug_quickbar_emote_wave;Wave]", "Q Wave's tooltip names it")
	has(fs, "tooltip[grug_quickbar_emote_dance;Dance]", "Q Dance's tooltip names it")
	lacks(fs, "_off", "Q nothing greyed on foot")
	check(fs:find("[^_]button%[") == nil, "Q no text buttons left for the emotes")

	fs = QB.formspec(fan)
	local cx, cy, _, _, cimg = button(fs, "grug_quickbar_emote_cheer")
	eq(cimg, "grug_quickbar_emote_cheer.png", "Q Cheer's icon with the reward")
	eq(cy, wy, "Q Cheer in the same row")
	eq(cx - wx, 2.5, "Q ... in the third column")
	has(fs, "tooltip[grug_quickbar_emote_cheer;Cheer]", "Q Cheer's tooltip names it")

	-- Four to a row: a fifth emote opens a second row.
	local h_one = tonumber(fs:match("size%[[%d.]+,([%d.]+)%]"))
	local extra = {}
	for index = 1, 3 do
		extra[index] = {id = "test" .. index, name = "Test " .. index}
		QB.EMOTES[#QB.EMOTES + 1] = extra[index]
		GV.EMOTE_CLIPS[extra[index].id] = {stand = {x = 0, y = 1}}
	end
	fs = QB.formspec(fan)
	local fx, fy = button(fs, "grug_quickbar_emote_test1")
	eq(fx - wx, 3.75, "Q the fourth emote in the fourth column")
	eq(fy, wy, "Q ... in the first row")
	local gx, gy = button(fs, "grug_quickbar_emote_test2")
	eq(gx, wx, "Q the fifth emote opens a second row in the first column")
	eq(gy and gy - wy, 1.25, "Q ... one slot pitch lower")
	local h_two = tonumber(fs:match("size%[[%d.]+,([%d.]+)%]"))
	check(h_one and h_two and math.abs(h_two - h_one - 1.25) < 1e-6, "Q the second row adds one pitch (" ..
		tostring(h_one) .. ", " .. tostring(h_two) .. ")")
	for index = 1, 3 do
		QB.EMOTES[#QB.EMOTES] = nil
		GV.EMOTE_CLIPS[extra[index].id] = nil
	end

	-- Riding: the seated clips stay live, Dance is greyed.
	grug_mounts.active.rider = {tier = 1}
	fs = QB.formspec(rider)
	local _, _, _, _, rw = button(fs, "grug_quickbar_emote_wave")
	local _, _, _, _, rc = button(fs, "grug_quickbar_emote_cheer")
	local _, _, _, _, rd = button(fs, "grug_quickbar_emote_dance_off")
	eq(rw, "grug_quickbar_emote_wave.png", "Q riding: Wave live")
	eq(rc, "grug_quickbar_emote_cheer.png", "Q riding: Cheer live (it has a seated clip)")
	eq(rd, "grug_quickbar_emote_dance_off.png", "Q riding: Dance greyed, its dimmed icon")
	lacks(fs, ";grug_quickbar_emote_dance;", "Q ... with no live Dance field")
	has(fs, "style[grug_quickbar_emote_dance_off,grug_quickbar_emote_dance_off:hovered," ..
		"grug_quickbar_emote_dance_off:pressed;", "Q ... in a style that does not react")
	has(fs, "tooltip[grug_quickbar_emote_dance_off;Dance\nNot while riding.]", "Q ... saying why")

	-- Clicks.
	mount(rider)
	step(0.05)
	QB.open(rider)
	local closes = #closed
	submit(rider, {grug_quickbar_emote_dance_off = ""})
	eq(#closed, closes, "Q the greyed Dance keeps the window open")
	eq(GV.current_pose(rider), nil, "Q ... and plays nothing")
	submit(rider, {grug_quickbar_emote_cheer = ""})
	eq(#closed, closes + 1, "Q a Cheer click closes the window")
	check(last(rider).x == 762 and last(rider).y == 821, "Q ... and the rider cheers seated")
	eq(anim_of(rider), "sit", "Q ... player_api keeps sit")
	for _ = 1, 21 do
		step(0.1)
		mount_step(rider)
	end
	check(last(rider).x == A.sit.x and last(rider).y == A.sit.y, "C sit comes back after the seated cheer")
	dismount(rider)
	grug_mounts.active.rider = nil
	step(1.1)

	-- A forged Cheer click without the reward plays nothing (the gate).
	QB.open(plain)
	closes = #closed
	submit(plain, {grug_quickbar_emote_cheer = ""})
	eq(GV.current_pose(plain), nil, "Q a forged Cheer click without the reward plays nothing")
	eq(#closed, closes + 1, "Q ... and the window closes")
	step(1.1)
	QB.open(fan)
	submit(fan, {grug_quickbar_emote_cheer = ""})
	eq(GV.current_pose(fan), "cheer", "Q a Cheer click with the reward cheers")
	submit(fan, {grug_quickbar_emote_wave = ""})
	eq(GV.current_pose(fan), "cheer", "Q a click after the window closed does nothing")
	step(2.2)
	step(1.1)
	QB.open(fan)
	submit(fan, {grug_quickbar_emote_dance = ""})
	eq(GV.current_pose(fan), "dance", "Q a Dance click dances")

	-- The text sizes: the grid is in slot units and does not move with the
	-- text (grug_core.ui's growth, here forced to 1.5); the window keeps its
	-- width.
	local small = QB.formspec(fan)
	window_info = {size = {x = 3840, y = 2160}}
	grug_core.ui.form_growth = function() return 1.5 end
	local large = QB.formspec(fan)
	grug_core.ui.form_growth = nil
	window_info = nil
	check(large ~= small and large:find("font_size", 1, true) ~= nil, "Q the large text size grows the text")
	for _, form in ipairs({small, large}) do
		local x1, y1, w1 = button(form, "grug_quickbar_emote_wave")
		local x3 = button(form, "grug_quickbar_emote_cheer")
		check(w1 == 1 and x3 - x1 == 2.5, "Q the grid in slot units at either text size")
		local width = tonumber(form:match("size%[([%d.]+),"))
		check(width and x3 + 1 <= width - 0.5 + 1e-6, "Q the grid inside the window at either text size")
		check(y1 ~= nil, "Q the grid is drawn")
	end
end

if failures > 0 then
	error(("R80 EMOTE PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R80 EMOTE PORTABLE PASS checks=%d"):format(checks))
