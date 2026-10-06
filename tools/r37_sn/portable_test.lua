-- Round 37 Lane SN portable test (LuaJIT): the three repurposed cues of the
-- audit's MOC-07 and the neutral Ice Nova id (round37-plan.md §2.3.3, §2.3.6,
-- §4.7).
--
--   luajit tools/r37_sn/portable_test.lua [repo]
--
-- Loads the REAL mods/CORE/grug_sounds/init.lua and grug_mobs/rift_spawn.lua
-- on a fake engine and reads the sources it names. Checks:
--   E  the events: dragon_return, rift_fuse and rift_burst are declared hooks
--      with a spec (hearing distance 160, 10 and 32 as before); their files
--      ship in grug_sounds/sounds (the fuse as three variants), are mono and
--      are on tools/r37_sn/approved.txt; every file on that list ships and is
--      played by one of these specs; every .ogg in grug_sounds/sounds is on
--      one of the four approval lists (the approval gate);
--   W  the wiring: the dragon's return warning plays dragon_return at the lair
--      and no raw mobs_spell; the Rift Spawn's fuse is the rift_fuse event
--      (mobs_redo's mob_sound routes grug_sounds events) and its burst plays
--      rift_burst once, at the burst position, through the real burst_due;
--      two return warnings or bursts in one step both play (no interval on a
--      shared position key);
--   S  the sweep: no core.sound_play in a grug_ mod outside grug_sounds and
--      grug_ambience except the inherited calls listed below, and every
--      literal sounds-table entry in grug_mobs is a declared grug_sounds hook;
--   N  the rename: cast_ice_nova is the Ice Nova cue (hook, spec, CAST_SOUNDS),
--      its file has the bytes approved for cast_frost_nova (sha256
--      d0567e8f35417ece...), and cast_frost_nova appears in no Lua file under
--      mods/ and in no approval line.
-- Prints "R37 SN PORTABLE PASS checks=<n>" or the failures.

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
-- Fake engine and the real grug_sounds.
------------------------------------------------------------------------------
local clock_us, played = 0, {}
core = {
	get_us_time = function() return clock_us end,
	sound_play = function(spec, params, ephemeral)
		played[#played + 1] = {spec = spec, params = params, ephemeral = ephemeral}
		return 0
	end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
}
local MOD = ROOT .. "/mods/CORE/grug_sounds"
assert(loadfile(MOD .. "/init.lua"))()
local S = grug_sounds
local EVENTS = S.EVENTS
local hooks = {}
for _, name in ipairs(S.HOOKS) do hooks[name] = true end

------------------------------------------------------------------------------
-- E: events, files and the approval list.
------------------------------------------------------------------------------
local shipped = {}
for _, path in ipairs(lines_of("find '" .. MOD .. "/sounds' -type f 2>/dev/null")) do
	shipped[path:match("([^/]+)$")] = path
end
local function channels(data)
	if not data or data:sub(1, 4) ~= "OggS" then return nil end
	local start = 28 + data:byte(27)
	if data:sub(start + 1, start + 6) ~= "vorbis" or data:byte(start) ~= 1 then return nil end
	return data:byte(start + 11)
end
local function approved_of(lane)
	local list, text = {}, read(ROOT .. "/tools/" .. lane .. "/approved.txt")
	check(text ~= nil, "E tools/" .. lane .. "/approved.txt exists")
	for line in (text or ""):gmatch("[^\n]+") do
		if not line:match("^%s*#") and line:match("%S") then
			local file = line:match("^%s*([^,%s]+%.ogg)")
			if check(file ~= nil, "E approved line starts with a file name: " .. line) then
				list[file] = true
			end
		end
	end
	return list
end

local CUES = {
	dragon_return = {distance = 160, files = {"grug_sounds_dragon_return.ogg"}},
	rift_fuse = {distance = 10, files = {"grug_sounds_rift_fuse.1.ogg",
		"grug_sounds_rift_fuse.2.ogg", "grug_sounds_rift_fuse.3.ogg"}},
	rift_burst = {distance = 32, files = {"grug_sounds_rift_burst.ogg"}},
}
local mine = approved_of("r37_sn")
local played_by = {}
for event, cue in pairs(CUES) do
	check(hooks[event], "E declared hook: " .. event)
	local spec = EVENTS[event]
	if check(spec ~= nil, "E has a spec: " .. event) then
		eq(spec.distance, cue.distance, "E hearing distance of " .. event)
		eq(spec.personal, nil, "E positional: " .. event)
		for _, file in ipairs(cue.files) do
			eq(file:gsub("%.ogg$", ""):gsub("%.%d+$", ""), spec.name, "E " .. event .. " plays " .. file)
			played_by[file] = event
			check(shipped[file] ~= nil, "E file ships: " .. file)
			eq(channels(read(shipped[file] or "")), 1, "E file is mono: " .. file)
			check(mine[file], "E file is on tools/r37_sn/approved.txt: " .. file)
		end
		-- No further variant beyond the approved ones.
		check(not shipped[spec.name .. ".ogg"] or #cue.files == 1,
			"E no unapproved plain file next to the variants: " .. spec.name)
		check(not shipped[spec.name .. "." .. (#cue.files + 1) .. ".ogg"],
			"E no unapproved further variant: " .. spec.name)
	end
end
for file in pairs(mine) do
	check(shipped[file] ~= nil, "E approved file ships: " .. file)
	check(played_by[file] ~= nil, "E approved file is played by an SN cue: " .. file)
end
local all = {}
for _, lane in ipairs({"r34_s1a", "r34_s1b", "r35_f", "r37_sn"}) do
	for file in pairs(approved_of(lane)) do all[file] = true end
end
for file in pairs(shipped) do
	check(all[file], "E shipped .ogg is on an approval list: " .. file)
end

------------------------------------------------------------------------------
-- W: the wiring.
------------------------------------------------------------------------------
local MOBS = ROOT .. "/mods/ENTITIES/grug_mobs/"
local bosses = read(MOBS .. "bosses.lua") or ""
local warn = bosses:match("local function warn_dragon%(.-\nend\n") or ""
check(warn ~= "", "W warn_dragon found in bosses.lua")
check(warn:find('grug_sounds.play("dragon_return", pos)', 1, true) ~= nil,
	"W the return warning plays dragon_return at the lair")
check(not bosses:find("mobs_spell", 1, true), "W bosses.lua plays no mobs_spell")
check(not bosses:find("sound_play", 1, true), "W bosses.lua has no raw sound_play")
local api = read(ROOT .. "/mods/ENTITIES/mobs/api.lua") or ""
check(api:find("if grug_sounds and grug_sounds.EVENTS[sound] then\n\t\tgrug_sounds.play(sound, self.object)", 1, true) ~= nil,
	"W mobs_redo's mob_sound routes grug_sounds events")
check(api:find("self:mob_sound(self.sounds.fuse)", 1, true) ~= nil, "W the fuse plays through mob_sound")

-- The real rift_spawn.lua under stubs: its definition and its burst.
local def
local sounds_played, removed = {}, false
local real_play = S.play
grug_mobs = {register_mob = function(_, d) def = d end}
mobs = {spawn = function() end}
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end}
core.get_objects_inside_radius = function() return {} end
core.add_particlespawner = function() end
core.is_player = function(o) return o and o.is_player and o:is_player() or false end
S.play = function(event, target)
	sounds_played[#sounds_played + 1] = {event = event, target = target}
	return true
end
played = {}
grug_core = {particles = dofile(ROOT .. "/tools/r40_pm/helper_stub.lua")(ROOT)} -- Round 40 PM
assert(loadfile(MOBS .. "rift_spawn.lua"))()
if check(def ~= nil, "W the Rift Spawn registers") then
	eq(def.sounds and def.sounds.fuse, "rift_fuse", "W the fuse sound is the rift_fuse event")
	eq(def.sounds and def.sounds.explode, nil, "W no raw explode sound")
	local mob_pos = {x = 10, y = 0, z = 10}
	local target = {
		get_pos = function() return {x = 11, y = 0, z = 10} end,
		get_hp = function() return 20 end,
		is_player = function() return false end,
	}
	local self = {
		v_start = true, timer = 1.99, explosion_timer = 2, reach = 3, attack = target,
		object = {get_pos = function() return mob_pos end, remove = function() removed = true end},
		line_of_sight = function() return true end,
		stop_attack = function() end,
		sounds = def.sounds,
	}
	def.do_custom(self, 0.05)
	eq(#sounds_played, 1, "W the burst plays one sound")
	eq(sounds_played[1] and sounds_played[1].event, "rift_burst", "W the burst plays rift_burst")
	eq(sounds_played[1] and sounds_played[1].target, mob_pos, "W at the burst position")
	eq(#played, 0, "W the burst plays nothing raw")
	check(removed, "W the Rift Spawn is gone after its burst")
	def.do_custom(self, 0.05)
	eq(#sounds_played, 1, "W a burst Rift Spawn does not burst again")
end
S.play = real_play

-- Two warnings or bursts in the same step share the "pos" key; both play.
played = {}
clock_us = 50 * 1000000
S.play("dragon_return", {x = -3260, y = 20, z = -40})
S.play("dragon_return", {x = 3260, y = 20, z = -40})
eq(#played, 2, "W two return warnings in one step both play")
eq(played[1] and played[1].params.max_hear_distance, 160, "W the warning is heard to 160")
eq(played[1] and played[1].params.pos and played[1].params.pos.x, -3260, "W at the lair")
S.play("rift_burst", {x = 1, y = 2, z = 3})
S.play("rift_burst", {x = 90, y = 2, z = 3})
eq(#played, 4, "W two bursts in one step both play")
local fuse_mob = {get_pos = function() return {x = 0, y = 0, z = 0} end, is_player = function() return false end}
S.play("rift_fuse", fuse_mob)
eq(played[5] and played[5].params.object, fuse_mob, "W the fuse follows its Rift Spawn")
check(played[5] and played[5].params.pitch >= 0.95 and played[5].params.pitch <= 1.05,
	"W the fuse keeps mobs_redo's pitch spread")
for i = 1, #played do eq(played[i].ephemeral, true, "W ephemeral " .. i) end

------------------------------------------------------------------------------
-- S: the sweep.
------------------------------------------------------------------------------
-- Inherited raw calls of existing sounds (vendored files, not MOC-07); a new
-- raw call anywhere else fails here.
local INHERITED = {
	["mods/ITEMS/grug_farming/hoes.lua"] = true,
	["mods/ITEMS/grug_farming/init.lua"] = true,
	["mods/ITEMS/grug_food/init.lua"] = true,
	["mods/ITEMS/grug_fishing/init.lua"] = true,
}
local raw = 0
for _, path in ipairs(lines_of("grep -rlE --include=*.lua '(core|minetest)[.]sound_play' '" .. ROOT .. "/mods'")) do
	local rel = path:sub(#ROOT + 2)
	if rel:match("/grug_[%w_]+/") and not rel:find("/grug_sounds/", 1, true) and
			not rel:find("/grug_ambience/", 1, true) then
		raw = raw + 1
		check(INHERITED[rel], "S no raw sound_play outside grug_sounds and grug_ambience: " .. rel)
	end
end
check(raw <= 4, "S at most the four inherited raw call files (got " .. raw .. ")")
for _, path in ipairs(lines_of("find '" .. MOBS .. "' -name '*.lua' -type f")) do
	local text = read(path)
	for block in text:gmatch("[^%w_]sounds%s*=%s*(%b{})") do
		for value in block:gmatch('=%s*"([^"]+)"') do
			check(hooks[value], "S a mob sounds entry is a grug_sounds hook: " .. value .. " in " .. path)
		end
	end
end

------------------------------------------------------------------------------
-- N: the rename.
------------------------------------------------------------------------------
check(hooks.cast_ice_nova, "N cast_ice_nova is a declared hook")
eq(EVENTS.cast_ice_nova and EVENTS.cast_ice_nova.name, "grug_sounds_cast_ice_nova", "N its spec")
check(not hooks.cast_frost_nova and not EVENTS.cast_frost_nova, "N cast_frost_nova is gone")
local abilities = read(ROOT .. "/mods/PLAYER/grug_abilities/init.lua") or ""
check(abilities:find('ice_nova = "cast_ice_nova"', 1, true) ~= nil, "N Ice Nova's cue in CAST_SOUNDS")
local file = shipped["grug_sounds_cast_ice_nova.ogg"]
if check(file ~= nil, "N the renamed file ships") then
	local sum = (lines_of("sha256sum '" .. file .. "'")[1] or ""):sub(1, 16)
	eq(sum, "d0567e8f35417ece", "N same bytes as the approved cast_frost_nova cut")
end
check(not shipped["grug_sounds_cast_frost_nova.ogg"], "N the old file name is gone")
eq(#lines_of("grep -rl --include=*.lua 'cast_frost_nova' '" .. ROOT .. "/mods'"), 0,
	"N cast_frost_nova in no Lua file (the LICENSE row records the rename)")
local s1b = read(ROOT .. "/tools/r34_s1b/approved.txt") or ""
check(s1b:find("\ngrug_sounds_cast_ice_nova.ogg, S1b R1.2", 1, true) ~= nil,
	"N the S1b approval keeps the renamed file")
check(not s1b:match("\ngrug_sounds_cast_frost_nova%.ogg"), "N no approval line for the old name")

if failures > 0 then
	print(("R37 SN PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R37 SN PORTABLE PASS checks=%d"):format(checks))
