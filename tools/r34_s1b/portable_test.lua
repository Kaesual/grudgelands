-- Round 34 Lane S1b portable test (LuaJIT): combat and creature sounds
-- (round34-plan.md §1 approval gate, §3, §4.3).
--
--   luajit tools/r34_s1b/portable_test.lua [repo]
--
-- Loads the REAL mods/CORE/grug_sounds/init.lua and grug_mobs/voices.lua on a
-- fake engine and reads the sources it names. Checks:
--   V  mob voices: every family's events are declared hooks of the lane; every
--      `_grug_voice` in grug_mobs names a family (or false), and every family
--      is used; the panther is a feline and the feline family has no war_cry,
--      so the panther gets none even with every voice approved;
--      apply_voice keeps only events with a spec, lets an explicit sounds
--      entry win and refuses a definition without a family;
--   A  abilities: every ability registered in grug_abilities has a cue in
--      CAST_SOUNDS ("weapon", "projectile" or a declared hook), the swing
--      skills are "weapon", the projectile ones register a projectile whose
--      launch and hit are declared hooks;
--   H  the hit by weapon kind: every weapon family of grug_gear has a hit
--      sound, every value is a declared hook; the vendored mobs_redo patches
--      route voices and player hits through grug_sounds;
--   F  files: every S1b spec names an existing file; every file on
--      tools/r34_s1b/approved.txt ships in grug_sounds/sounds, is mono and is
--      played by a spec; every S1b hook has a spec; the user's silent choices
--      have neither hook nor spec.
-- Prints "R34 S1B PORTABLE PASS checks=<n>" or the failures.

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
-- Fake engine and the real files.
------------------------------------------------------------------------------
core = {
	get_us_time = function() return 0 end,
	sound_play = function() return 0 end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
}
assert(loadfile(ROOT .. "/mods/CORE/grug_sounds/init.lua"))()
local EVENTS = grug_sounds.EVENTS
grug_mobs = {}
assert(loadfile(ROOT .. "/mods/ENTITIES/grug_mobs/voices.lua"))()
local VOICES = grug_mobs.VOICES

-- The lane's hooks: the HOOKS list from "swing" (S1b's first) to the end.
local hooks, lane_hooks = {}, {}
local in_lane = false
for _, name in ipairs(grug_sounds.HOOKS) do
	hooks[name] = true
	if name == "swing" then in_lane = true end
	if in_lane then lane_hooks[#lane_hooks + 1] = name end
end
check(#lane_hooks > 50, "the S1b hooks start at \"swing\" (" .. #lane_hooks .. ")")
local lane_hook = {}
for _, name in ipairs(lane_hooks) do lane_hook[name] = true end

------------------------------------------------------------------------------
-- V: voices.
------------------------------------------------------------------------------
local MOBS = ROOT .. "/mods/ENTITIES/grug_mobs/"
local KINDS = {war_cry = true, damage = true, death = true, random = true, attack = true,
	telegraph = true}
for family, voice in pairs(VOICES) do
	for kind, event in pairs(voice) do
		check(KINDS[kind], "V " .. family .. ": a mobs_redo sound kind: " .. kind)
		check(lane_hook[event], "V " .. family .. "." .. kind .. " is a lane hook: " .. event)
		check(kind == "telegraph" or event == "voice_" .. family .. "_" .. kind,
			"V " .. family .. "." .. kind .. " is named voice_<family>_<kind>: " .. event)
	end
end
check(VOICES.feline and VOICES.feline.war_cry == nil, "V felines stalk silently: no war_cry")

local used = {}
local voiced_files = 0
for _, path in ipairs(lines_of("ls '" .. MOBS .. "'*.lua")) do
	local text = read(path)
	for value in text:gmatch("_grug_voice = ([%w_\"]+)") do
		voiced_files = voiced_files + 1
		local family = value:match('^"([%w_]+)"$')
		check(value == "false" or (family and VOICES[family]),
			"V _grug_voice names a family: " .. value .. " in " .. path:match("[^/]+$"))
		if family then used[family] = true end
	end
	if path:match("/panther%.lua$") then
		check(text:find('_grug_voice = "feline"', 1, true) ~= nil, "V the panther is a feline")
	end
end
check(voiced_files >= 60, "V at least 60 definitions name a voice (" .. voiced_files .. ")")
for family in pairs(VOICES) do
	check(used[family], "V family used by a mob: " .. family)
end

-- apply_voice with every voice event approved (test specs), restored after.
local saved = {}
for event, spec in pairs(EVENTS) do saved[event] = spec end
for family, voice in pairs(VOICES) do
	for _, event in pairs(voice) do EVENTS[event] = {name = "test_" .. event} end
end
local panther = {_grug_voice = "feline"}
grug_mobs.apply_voice("grug_mobs:panther", panther)
check(panther.sounds and panther.sounds.damage == "voice_feline_damage",
	"V a feline gets its damage voice")
check(panther.sounds and panther.sounds.war_cry == nil, "V the panther gets no war_cry")
local rift = {_grug_voice = "spirit", sounds = {fuse = "rift_fuse", death = "own_death"}}
grug_mobs.apply_voice("grug_mobs:rift_spawn", rift)
check(rift.sounds.fuse == "rift_fuse" and rift.sounds.death == "own_death" and
	rift.sounds.damage == "voice_spirit_damage", "V explicit sounds win, the family fills the rest")
EVENTS.voice_canine_damage = nil
local wolf = {_grug_voice = "canine"}
grug_mobs.apply_voice("grug_mobs:wolf", wolf)
check(wolf.sounds.war_cry == "voice_canine_war_cry" and wolf.sounds.damage == nil,
	"V an event without a spec is left out")
local fish = {_grug_voice = false}
grug_mobs.apply_voice("grug_mobs:reed_angelfish", fish)
check(fish.sounds == nil, "V false: no voice")
check(not pcall(grug_mobs.apply_voice, "grug_mobs:nameless", {}),
	"V a definition without _grug_voice is refused")
check(not pcall(grug_mobs.apply_voice, "grug_mobs:odd", {_grug_voice = "unicorn"}),
	"V an unknown family is refused")
for event in pairs(EVENTS) do EVENTS[event] = nil end
for event, spec in pairs(saved) do EVENTS[event] = spec end
local none = {_grug_voice = "canine"}
grug_mobs.apply_voice("grug_mobs:wolf", none)
local any_spec = false
for _, event in pairs(VOICES.canine) do any_spec = any_spec or EVENTS[event] ~= nil end
check(any_spec or none.sounds == nil, "V without approved voices a mob has no sounds table")

------------------------------------------------------------------------------
-- A: abilities.
------------------------------------------------------------------------------
local ABIL = ROOT .. "/mods/PLAYER/grug_abilities/"
local init_src = read(ABIL .. "init.lua")
local block = init_src:match("grug_abilities%.CAST_SOUNDS = (%b{})")
check(block ~= nil, "A CAST_SOUNDS found in grug_abilities/init.lua")
local cues = {}
for id, cue in (block or ""):gmatch('([%w_]+) = "([%w_]+)"') do
	check(cues[id] == nil, "A one cue per ability: " .. id)
	cues[id] = cue
end
local registered, swings = {}, {}
for _, file in ipairs({"kits.lua", "scout.lua", "blink.lua"}) do
	local text = read(ABIL .. file) or ""
	-- Each registration's id and kind (the strike definition is a local table).
	for body in text:gmatch("register_ability(%b())") do
		local id = body:match('id = "([%w_]+)"')
		if id then
			registered[id] = true
			if body:match('kind = "swing"') then swings[id] = true end
		end
	end
	local strike = text:match("local strike_def = (%b{})")
	if strike then
		registered.strike = true
		if strike:match('kind = "swing"') then swings.strike = true end
	end
end
local count = 0
for id in pairs(registered) do
	count = count + 1
	local cue = cues[id]
	check(cue ~= nil, "A ability has a cue: " .. id)
	if cue then
		check(cue == "weapon" or cue == "projectile" or cue == "silent" or lane_hook[cue],
			"A cue is weapon, projectile, silent or a lane hook: " .. id .. " -> " .. cue)
		check((cue == "weapon") == (swings[id] == true),
			"A exactly the swing skills sound through the weapon: " .. id)
	end
end
check(count >= 21, "A at least 21 registered abilities (" .. count .. ")")
for id in pairs(cues) do check(registered[id], "A cue for a registered ability: " .. id) end
-- The projectile abilities and their projectiles.
local projectiles = 0
for _, file in ipairs({"kits.lua", "scout.lua"}) do
	local text = read(ABIL .. file) or ""
	for body in text:gmatch("grug_projectiles%.register(%b())") do
		projectiles = projectiles + 1
		local launch, hit = body:match('sound_launch = "([%w_]+)"'), body:match('sound_hit = "([%w_]+)"')
		check(launch and lane_hook[launch], "A projectile launch is a lane hook: " .. tostring(launch))
		check(hit and lane_hook[hit], "A projectile hit is a lane hook: " .. tostring(hit))
	end
end
check(projectiles == 2, "A two projectiles: the fireball and the arrow (" .. projectiles .. ")")
check(cues.fireball == "projectile" and cues.loose == "projectile", "A fireball and Loose are projectiles")
check(cues.blink == "silent" and cues.sprint == "silent", "A Blink and Sprint are silent by choice")

------------------------------------------------------------------------------
-- H: the hit by weapon kind and the vendored patches.
------------------------------------------------------------------------------
local combat_src = read(ROOT .. "/mods/CORE/grug_core/combat.lua")
local hits = combat_src:match("local HIT_SOUNDS = (%b{})")
check(hits ~= nil, "H HIT_SOUNDS found in grug_core/combat.lua")
local hit_of = {}
for family, event in (hits or ""):gmatch('([%w_]+) = "([%w_]+)"') do
	hit_of[family] = event
	check(lane_hook[event], "H hit sound is a lane hook: " .. family .. " -> " .. event)
end
local gear = read(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
local weapons = gear:match("local WEAPONS = (%b{})") or ""
for family, rest in weapons:gmatch('{key = "([%w_]+)"(.-)}') do
	if rest:match("bow = true") then
		check(hit_of[family] == nil, "H the bow is no melee weapon: no hit sound")
	else
		check(hit_of[family] ~= nil, "H melee weapon family has a hit sound: " .. family)
	end
end
check(combat_src:find('or "hit_fist"', 1, true) ~= nil, "H the bare hand punches (hit_fist)")
local api = read(ROOT .. "/mods/ENTITIES/mobs/api.lua")
check(api:find("if grug_sounds and grug_sounds.EVENTS[sound] then", 1, true) ~= nil,
	"H mob_sound plays a grug_sounds voice through its spec")
check(api:find("grug_sounds.play(grug_core.melee_hit_sound(hitter), self.object)", 1, true) ~= nil,
	"H a player's hit on a mob sounds by weapon kind")

------------------------------------------------------------------------------
-- F: files and specs.
------------------------------------------------------------------------------
local files = {}
for _, path in ipairs(lines_of("find '" .. ROOT .. "/mods' -path '*/sounds/*.ogg' -type f")) do
	files[path:match("([^/]+)%.ogg$")] = true
end
local function exists(name) return files[name] or files[name .. ".1"] end

local played = {}
for _, event in ipairs(lane_hooks) do
	local spec = EVENTS[event]
	if spec then
		played[spec.name] = true
		check(exists(spec.name), "F spec names an existing file: " .. event .. " -> " .. spec.name)
		check(spec.personal == nil or event == "dragon_wrath",
			"F combat cues are positional: " .. event)
	end
end

local approved = {}
local text = read(ROOT .. "/tools/r34_s1b/approved.txt")
check(text ~= nil, "F tools/r34_s1b/approved.txt exists")
for line in (text or ""):gmatch("[^\n]+") do
	if not line:match("^%s*#") and line:match("%S") then
		local file = line:match("^%s*([^,%s]+%.ogg)")
		if check(file ~= nil, "F approved line starts with a file name: " .. line) then
			approved[file] = true
		end
	end
end
local function channels(data)
	if not data or data:sub(1, 4) ~= "OggS" then return nil end
	local start = 28 + data:byte(27)
	if data:sub(start + 1, start + 6) ~= "vorbis" or data:byte(start) ~= 1 then return nil end
	return data:byte(start + 11)
end
local SOUNDS = ROOT .. "/mods/CORE/grug_sounds/sounds/"
for file in pairs(approved) do
	local data = read(SOUNDS .. file)
	check(data ~= nil, "F approved file ships: " .. file)
	check(channels(data) == 1, "F approved file is mono: " .. file)
	local base = file:gsub("%.ogg$", ""):gsub("%.%d+$", "")
	check(played[base], "F approved file is played by an S1b spec: " .. file)
end

-- Every lane hook has the user's pick.
for _, event in ipairs(lane_hooks) do
	check(EVENTS[event] ~= nil, "F hook has the user's pick: " .. event)
end
for _, name in ipairs({"crit", "cast_blink", "cast_sprint", "voice_crow_random"}) do
	check(not hooks[name] and not EVENTS[name], "F silent by choice, no hook: " .. name)
end
check(EVENTS.hit_fist and EVENTS.hit_fist.name == "mobs_punch", "F the fist keeps mobs_punch")
check(EVENTS.dragon_enrage and EVENTS.dragon_enrage.name == "grug_sounds_voice_dragon_war_cry",
	"F the enrage is the 11.1 roar again (E4.1)")
-- The dragons growl at their own wind-ups; of the elites only the humanoids
-- have a wind-up cue (telegraph.lua), the special attack the kings share.
for family, voice in pairs(VOICES) do
	check(voice.telegraph == nil or family == "humanoid", "F no elite wind-up cue for " .. family)
end
check(VOICES.humanoid.telegraph == "king_signature", "F the humanoid wind-up is the special attack")
check(read(MOBS .. "boss_dragons.lua"):find('grug_sounds.play("telegraph", self.object)', 1, true) ~= nil,
	"F the dragon's wind-up plays the telegraph growl")
local approved_count = 0
for _ in pairs(approved) do approved_count = approved_count + 1 end
check(approved_count == 88, "F 88 approved files (" .. approved_count .. ")")

if failures > 0 then
	print(("R34 S1B PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print(("R34 S1B PORTABLE PASS checks=%d"):format(checks))
