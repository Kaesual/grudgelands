-- Round 34 Lane S1a portable test (LuaJIT): the sound events of grug_sounds
-- (round34-plan.md §1 approval gate, §3, §4.1).
--
--   luajit tools/r34_s1a/portable_test.lua [repo]
--
-- Loads the REAL mods/CORE/grug_sounds/init.lua on a fake engine. Checks:
--   E  the event table: every spec is a declared hook and names a sound file
--      that exists in some mod's sounds/ (the name itself or its .1, .2 ...
--      variants); every grug_sounds_* file is played by a spec (as itself or
--      as a variant); every .ogg in grug_sounds/sounds is mono and on
--      tools/r34_s1a/approved.txt, tools/r34_s1b/approved.txt,
--      tools/r35_f/approved.txt or tools/r37_sn/approved.txt (the user's
--      picks; '#' lines are comments),
--      and every listed file ships;
--   C  the call sites (and grug_jobs' craft-sound table: real professions
--      and operation kinds): every grug_sounds.play("...") in mods/ names a declared
--      hook, and every declared hook appears as a string in some hooked file
--      (a typo in an indirect name, e.g. a craft or drop helper, leaves the
--      right name without a site); the click is the formspec style; the
--      events the user chose to keep silent have neither a spec nor a hook
--      (plan §2.2a), enchant keeps its hook without a spec;
--   P  play: a player target hears it positionally on its object or, for a
--      personal spec, alone; an object target carries the object, a position
--      the position; an event without a spec and a nil target are silent;
--      gain, distance and pitch spread reach the engine; every sound is
--      ephemeral;
--   R  the rate limit: a repeat inside the interval is dropped, after it
--      plays; targets, events and players are limited independently; a
--      leaving player's times are forgotten;
--   K  the click style: present exactly when the click has a spec, and a
--      joining player's prepend is extended by it.
-- Prints "R34 S1A PORTABLE PASS checks=<n>" or the failures.

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
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function read(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
local function lines_of(command)
	local out = {}
	local pipe = assert(io.popen(command))
	for line in pipe:lines() do out[#out + 1] = line end
	pipe:close()
	return out
end

------------------------------------------------------------------------------
-- Fake engine.
------------------------------------------------------------------------------
local clock_us, played, joins, leaves = 0, {}, {}, {}
core = {
	get_us_time = function() return clock_us end,
	sound_play = function(spec, params, ephemeral)
		played[#played + 1] = {spec = spec, params = params, ephemeral = ephemeral}
		return 0
	end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
}
local function player(name)
	local prepend = "bgcolor[#080808BB;true]"
	return {
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		is_player = function() return true end,
		get_player_name = function() return name end,
		get_formspec_prepend = function() return prepend end,
		set_formspec_prepend = function(_, text) prepend = text end,
	}
end
local function entity()
	return {get_pos = function() return {x = 1, y = 2, z = 3} end,
		is_player = function() return false end}
end

local MOD = ROOT .. "/mods/CORE/grug_sounds"
assert(loadfile(MOD .. "/init.lua"))()
local S = grug_sounds
local EVENTS = S.EVENTS

------------------------------------------------------------------------------
-- E: the event table, the files and the approval list.
------------------------------------------------------------------------------
local hooks = {}
for _, name in ipairs(S.HOOKS) do
	check(not hooks[name], "E hook declared once: " .. name)
	hooks[name] = true
end

-- Every sound file of the game: base name -> true, "name.N" variants too.
local files = {}
for _, path in ipairs(lines_of("find '" .. ROOT .. "/mods' -path '*/sounds/*.ogg' -type f")) do
	files[path:match("([^/]+)%.ogg$")] = true
end
local function exists(name)
	return files[name] or files[name .. ".1"]
end

local played_names = {}
for event, spec in pairs(EVENTS) do
	check(hooks[event], "E spec is a declared hook: " .. event)
	check(type(spec.name) == "string" and exists(spec.name),
		"E spec names an existing sound file: " .. event .. " -> " .. tostring(spec.name))
	played_names[spec.name] = true
end

-- Both sound lanes ship into this mod: lane S1b's picks (combat and
-- creatures) are listed in tools/r34_s1b/approved.txt, Round 35 lane F's
-- break sound in tools/r35_f/approved.txt and Round 37 lane SN's dragon
-- return and Rift Spawn cues in tools/r37_sn/approved.txt.
local approved = {}
for _, lane in ipairs({"r34_s1a", "r34_s1b", "r35_f", "r37_sn"}) do
	local approved_text = read(ROOT .. "/tools/" .. lane .. "/approved.txt")
	check(approved_text ~= nil, "E tools/" .. lane .. "/approved.txt exists")
	for line in (approved_text or ""):gmatch("[^\n]+") do
		if not line:match("^%s*#") and line:match("%S") then
			local file = line:match("^%s*([^,%s]+%.ogg)")
			if check(file ~= nil, "E approved line starts with a file name: " .. line) then
				approved[file] = true
			end
		end
	end
end

-- The channel count of an Ogg Vorbis file: the identification header is the
-- first packet of the first page.
local function channels(data)
	if not data or data:sub(1, 4) ~= "OggS" then return nil end
	local segments = data:byte(27)
	local start = 28 + segments
	if data:sub(start + 1, start + 6) ~= "vorbis" or data:byte(start) ~= 1 then return nil end
	return data:byte(start + 11)
end

local shipped = {}
for _, path in ipairs(lines_of("find '" .. MOD .. "/sounds' -type f 2>/dev/null")) do
	local file = path:match("([^/]+)$")
	shipped[file] = true
	check(file:match("%.ogg$") ~= nil, "E only .ogg files in grug_sounds/sounds: " .. file)
	check(approved[file], "E shipped file is on approved.txt: " .. file)
	check(file:match("^grug_sounds_[%w_]+[%.%d]*%.ogg$") ~= nil,
		"E file is named grug_sounds_<what>[.n].ogg: " .. file)
	local base = file:gsub("%.ogg$", ""):gsub("%.%d+$", "")
	check(played_names[base], "E shipped file is played by a spec: " .. file)
	eq(channels(read(path)), 1, "E shipped file is mono: " .. file)
end
for file in pairs(approved) do
	check(shipped[file], "E approved file ships: " .. file)
end

------------------------------------------------------------------------------
-- C: the call sites.
------------------------------------------------------------------------------
local PENDING = {click = "the formspec style"}
local seen = {}
local calls = 0
-- A hooked file plays an event, or (Round 34 S1b) registers a projectile
-- with its launch and hit events (grug_projectiles.register).
for _, path in ipairs(lines_of("grep -rlE --include=*.lua 'grug_sounds[.]play|sound_launch' '" .. ROOT .. "/mods'")) do
	if not path:find("/grug_sounds/init.lua", 1, true) then
		local text = read(path)
		for event in text:gmatch('grug_sounds%.play%(%s*"([^"]+)"') do
			calls = calls + 1
			check(hooks[event], "C call names a declared hook: " .. event .. " in " .. path)
		end
		for literal in text:gmatch('"([%l_]+)"') do seen[literal] = true end
	end
end
check(calls >= 25, "C at least 25 literal call sites (got " .. calls .. ")")
-- The user's choices (plan §2.2a): no spec, and no hook where no sound may come.
for _, name in ipairs({"quest_progress", "talent", "achievement", "drop_blue", "drop_gold",
		"drop_bag", "drop_boss", "mount_summon", "mount_dismount", "respawn", "zone_banner",
		"pvp_off", "quest_accept"}) do
	check(not hooks[name] and not EVENTS[name], "C silent by choice, no hook: " .. name)
end
check(hooks.enchant and not EVENTS.enchant, "C hook without a sound for now: enchant")
check(EVENTS.quest_complete ~= nil, "C quest_complete plays the confirmed cut (R1.1)")
for _, name in ipairs(S.HOOKS) do
	check(seen[name] or PENDING[name], "C declared hook has a call site: " .. name)
end

-- The craft sounds of grug_jobs/state.lua (read from the source): every
-- profession key is a profession of registry.lua, every operation key a
-- station operation kind, every value a declared hook.
local jobs = ROOT .. "/mods/PLAYER/grug_jobs/"
local professions = {}
local block = read(jobs .. "registry.lua"):match("grug_jobs%.PROFESSIONS = (%b{})")
for key in (block or ""):gmatch("\n%s*([%w_]+) = {") do professions[key] = true end
check(professions.cooking and professions.alchemist, "C registry.lua professions read")
local kinds = {}
for kind in read(jobs .. "station_operations.lua"):gmatch('recipe%.operation == "([%w_]+)"') do kinds[kind] = true end
check(kinds.enchant and kinds.upgrade, "C station operation kinds read")
local sounds = read(jobs .. "state.lua"):match("local CRAFT_SOUNDS = (%b{})")
check(sounds ~= nil, "C CRAFT_SOUNDS found in grug_jobs/state.lua")
for key, event in (sounds or ""):gmatch('([%w_]+) = "([%w_]+)"') do
	check(professions[key] or kinds[key], "C CRAFT_SOUNDS key is a profession or operation kind: " .. key)
	check(hooks[event], "C CRAFT_SOUNDS value is a declared hook: " .. event)
end

------------------------------------------------------------------------------
-- P: play.
------------------------------------------------------------------------------
-- Test specs on top of the shipped table (restored at the end).
local saved = {}
for event, spec in pairs(EVENTS) do saved[event] = spec end
EVENTS.quest_abandon = {name = "test_accept", gain = 0.5, distance = 8}
EVENTS.level_up = {name = "test_level", personal = true, pitch = 0.1}
EVENTS.mount_gallop = {name = "test_gallop", interval = 2}
EVENTS.fishing_cast = {name = "test_cast"}

local alice, bob, mount = player("alice"), player("bob"), entity()
local function last() return played[#played] end

played = {}
EVENTS.enchant = nil
eq(S.play("enchant", alice), false, "P an event without a spec is silent")
eq(S.play("quest_abandon", nil), false, "P a nil target is silent")
eq(S.play(nil, alice), false, "P a nil event is silent")
eq(#played, 0, "P nothing reached the engine")

eq(S.play("quest_abandon", alice), true, "P a player target plays")
eq(last().spec, "test_accept", "P the spec's name")
eq(last().params.object, alice, "P positional on the player's object")
eq(last().params.to_player, nil, "P not personal")
eq(last().params.gain, 0.5, "P gain")
eq(last().params.max_hear_distance, 8, "P distance")
eq(last().ephemeral, true, "P ephemeral")

clock_us = 10 * 1000000
S.play("level_up", alice)
eq(last().params.to_player, "alice", "P a personal spec plays to the player")
eq(last().params.object, nil, "P a personal spec is not positional")
eq(last().params.pos, nil, "P a personal spec has no position")
check(last().params.pitch >= 0.9 and last().params.pitch <= 1.1,
	"P pitch within the spread (" .. tostring(last().params.pitch) .. ")")
eq(last().params.gain, 1, "P default gain")
eq(last().params.max_hear_distance, 16, "P default distance")

S.play("mount_gallop", mount)
eq(last().params.object, mount, "P an object target carries the object")
eq(last().params.pitch, nil, "P no pitch without a spread")
local pos = {x = 4, y = 5, z = 6}
S.play("fishing_cast", pos)
eq(last().params.pos, pos, "P a position target carries the position")
eq(last().params.object, nil, "P a position is not an object")

------------------------------------------------------------------------------
-- R: the rate limit.
------------------------------------------------------------------------------
clock_us = 100 * 1000000
played = {}
eq(S.play("quest_abandon", bob), true, "R first play")
eq(S.play("quest_abandon", bob), false, "R the same step folds (default 0.1 s)")
clock_us = clock_us + 50000
eq(S.play("quest_abandon", bob), false, "R 0.05 s later still inside")
clock_us = clock_us + 60000
eq(S.play("quest_abandon", bob), true, "R after the interval it plays")
eq(S.play("quest_abandon", alice), true, "R another player is limited apart")
eq(S.play("level_up", bob), true, "R another event is limited apart")

clock_us = 200 * 1000000
local other = entity()
eq(S.play("mount_gallop", mount), true, "R gallop plays")
eq(S.play("mount_gallop", other), true, "R another mount plays at once")
clock_us = clock_us + 1500000
eq(S.play("mount_gallop", mount), false, "R a spec interval (2 s) drops the repeat at 1.5 s")
clock_us = clock_us + 600000
eq(S.play("mount_gallop", mount), true, "R the repeat plays at 2.1 s")

eq(S.play("fishing_cast", {x = 0, y = 0, z = 0}), true, "R a position plays")
eq(S.play("fishing_cast", {x = 9, y = 9, z = 9}), false, "R positions share one limit per event")

clock_us = 300 * 1000000
eq(S.play("quest_abandon", bob), true, "R bob plays")
for _, fn in ipairs(leaves) do fn(bob) end
eq(S.play("quest_abandon", bob), true, "R a player who left and returns starts fresh")

for event in pairs(EVENTS) do EVENTS[event] = nil end
for event, spec in pairs(saved) do EVENTS[event] = spec end

------------------------------------------------------------------------------
-- K: the click style.
------------------------------------------------------------------------------
if EVENTS.click then
	eq(S.CLICK_STYLE, "style_type[button,image_button,checkbox,tabheader,dropdown;sound=" ..
		EVENTS.click.name .. "]", "K click style names the click file")
	eq(#joins, 1, "K one join callback extends the prepend")
	local carol = player("carol")
	joins[1](carol)
	eq(carol:get_formspec_prepend(), "bgcolor[#080808BB;true]" .. S.CLICK_STYLE,
		"K the prepend ends with the click style")
else
	eq(S.CLICK_STYLE, "", "K no click style without a click spec")
	eq(#joins, 0, "K no join callback without a click spec")
end

if failures > 0 then
	print(("R34 S1A PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R34 S1A PORTABLE PASS checks=%d"):format(checks))
