-- Round 46 lane XP portable test (LuaJIT): kill XP by level difference,
-- the gray line, and the repeatable quests removed (round46-plan.md §4.4,
-- rulings 5, 7 and 8). Loads the REAL files under minimal `core` stubs:
--
--   A. the kill-XP table (grug_xp.kill_xp through grug_mobs.kill_xp): XP
--      per kill at player levels 10, 30 and 60 for d = -7, -3, 0, +3, +6,
--      normal and elite (printed for the lane report), and the factor at
--      every d from -8 to +8;
--   B. the target frame's con colour: gray with "(no XP)" from 7 below,
--      then a gradient per level, green at 6 below, yellow at the own
--      level, red from 5 above;
--   C. the shipped quest files hold no repeatable quest, and every hub
--      line of a giver still has a quest;
--   D. saved quest state holding removed quest ids (an active and tracked
--      bounty with progress, a completed one, a running cooldown) loads
--      without an error: the journal, the tracker, the markers, a kill
--      credit, an accept and an abandon all work, and the next save drops
--      the removed active and tracked ids;
--   E. the quest dialog's legend explains "(R)" only while a repeatable
--      quest is registered.
--
-- Usage (repo root): luajit tools/r46_xp/portable_test.lua [repo]

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg and arg[1] or "."
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
local function noop() end
local function read(path)
	local f = assert(io.open(path, "rb"), "cannot read " .. path)
	local text = f:read("*a")
	f:close()
	return text
end
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

------------------------------------------------------------------------------
-- A. The kill-XP table.
------------------------------------------------------------------------------
core = {settings = {get = function() return nil end}, log = noop,
	global_exists = function(name) return rawget(_G, name) ~= nil end}
setmetatable(core, {__index = function() return noop end})
grug_core = {hud_layout = {COLOR = {xp = 0}}, banner = noop, feed_xp = noop,
	particles = {play = noop}}
dofile(repo .. "/mods/PLAYER/grug_xp/init.lua")
local X = grug_xp
grug_mobs = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/levels.lua")

local function kill(mob_level, player_level, tier)
	return math.floor(grug_mobs.kill_xp({name = "test:mob", _grug_level = mob_level,
		_grug_tier = tier}, player_level))
end
do
	local expected_percent = {[-8] = 0, [-7] = 0, [-6] = 10, [-5] = 25, [-4] = 40, [-3] = 55,
		[-2] = 70, [-1] = 85, [0] = 100, [1] = 110, [2] = 120, [3] = 130, [4] = 140,
		[5] = 150, [6] = 150, [7] = 150, [8] = 150}
	for d = -8, 8 do
		eq(X.kill_percent(30 + d, 30), expected_percent[d], "A the factor at d = " .. d)
		eq(X.is_gray(30 + d, 30), d <= -7, "A gray at d = " .. d)
	end
	print("XP per kill (solo; d = mob level - player level)")
	print("player   tier     d=-7   d=-3    d=0   d=+3   d=+6")
	local want = {
		[10] = {normal = {0, 41, 75, 97, 112}, elite = {0, 165, 300, 390, 450}},
		[30] = {normal = {0, 96, 175, 227, 262}, elite = {0, 385, 700, 910, 1050}},
		[60] = {normal = {0, 178, 325, 422, 487}, elite = {0, 715, 1300, 1690, 1950}},
	}
	for _, level in ipairs({10, 30, 60}) do
		for _, tier in ipairs({"normal", "elite"}) do
			local row = {}
			for i, d in ipairs({-7, -3, 0, 3, 6}) do
				row[i] = kill(level + d, level, tier)
				eq(row[i], want[level][tier][i], ("A L%d %s at d = %d"):format(level, tier, d))
			end
			print(("%6d   %-6s %6d %6d %6d %6d %6d"):format(level, tier, unpack(row)))
		end
	end
	eq(kill(66, 60, "rare"), 2925, "A a rare 6 above at L60: 325 x 1.5 x 6")
	eq(kill(60, 60, "critter"), 0, "A a critter pays nothing")
	eq(kill(65, 60, "boss"), 487, "A a level-65 king at L60: the boss tier's x1 at +5")
	eq(grug_mobs.kill_xp({name = "test:mob", _grug_level = 20, _grug_tier = "normal"}), 125,
		"A without a player level: the mob's own-level value")
end

------------------------------------------------------------------------------
-- B. The target frame's con colour.
------------------------------------------------------------------------------
do
	local steps, joins = {}, {}
	core = {
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = noop,
		is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and
			obj:is_player() end,
	}
	local level = 30
	grug_xp = {get_level = function() return level end, is_gray = X.is_gray, GRAY_GAP = X.GRAY_GAP}
	grug_mobs = {tag_text = function(mob) return "Boar L" .. mob._grug_level end}
	grug_factions = {}
	local looking_at
	grug_abilities = {crosshair = {recent_aim = function()
		return {ray = {range = 30, reason = "object", distance = 5,
			pointed = {type = "object", ref = looking_at}}}
	end}}
	dofile(repo .. "/mods/ENTITIES/grug_mobs/target_frame.lua")
	local huds = {}
	local viewer = {
		get_player_name = function() return "dana" end,
		is_player = function() return true end,
		hud_add = function() huds[1] = {}; return 1 end,
		hud_change = function(_, id, key, value) huds[id][key] = value end,
	}
	core.get_connected_players = function() return {viewer} end
	for _, fn in ipairs(joins) do fn(viewer) end
	local function frame_of(mob_level)
		local mob = {_grug_level = mob_level, health = 10}
		looking_at = {is_player = function() return false end,
			get_luaentity = function() return mob end}
		for _, fn in ipairs(steps) do fn(0.5) end
		return huds[1].text, huds[1].number
	end
	local text, color = frame_of(23)
	eq(text, "Boar L23 (no XP)", "B 7 below: (no XP)")
	eq(color, 0xaaaaaa, "B 7 below: gray")
	text, color = frame_of(24)
	eq(text, "Boar L24", "B 6 below: no (no XP)")
	-- The gradient (Round 46 follow-up): green at -6, yellow at 0, red from +5.
	local gradient = {[-8] = 0xaaaaaa, [-7] = 0xaaaaaa, [-6] = 0x55ff55, [-5] = 0x71ff55,
		[-4] = 0x8eff55, [-3] = 0xaaff55, [-2] = 0xc6ff55, [-1] = 0xe3ff55, [0] = 0xffff55,
		[1] = 0xffdd55, [2] = 0xffbb55, [3] = 0xff9955, [4] = 0xff7755, [5] = 0xff5555,
		[6] = 0xff5555, [12] = 0xff5555}
	for _, d in ipairs({-8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 12}) do
		text, color = frame_of(30 + d)
		eq(color, gradient[d], ("B the colour at d = %d is %06x"):format(d, gradient[d]))
	end
	level = 1
	text, color = frame_of(1)
	eq(color, 0xffff55, "B a level-1 player on a level-1 mob: yellow")
	level = 30
	core, grug_abilities, grug_factions = nil, nil, nil
end

------------------------------------------------------------------------------
-- C. The shipped quest files.
------------------------------------------------------------------------------
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local zone_dir = repo .. "/mods/PLAYER/grug_quests/data/zones/"
do
	local pipe = assert(io.popen("ls '" .. zone_dir .. "'"))
	local files = {}
	for name in pipe:read("*a"):gmatch("[^\n]+") do
		if name:match("%.quests%.json$") then files[#files + 1] = name end
	end
	pipe:close()
	local quests, repeatables, line_quests, hub_lines = 0, {}, {}, {}
	for _, name in ipairs(files) do
		local data = json.parse(read(zone_dir .. name))
		for _, q in ipairs(data.quests) do
			quests = quests + 1
			if q.repeatable ~= nil then repeatables[#repeatables + 1] = q.id end
			line_quests[q.giver .. "/" .. q.line] = true
		end
		for _, hub in ipairs(data.hubs or {}) do
			for _, giver in ipairs(hub.givers) do
				for _, line in ipairs(giver.lines) do hub_lines[#hub_lines + 1] = giver.npc .. "/" .. line end
			end
		end
	end
	eq(#files, 42, "C the 42 quest files are read")
	eq(quests, 485, "C 485 quests ship (540 less the 55 repeatables)")
	eq(table.concat(repeatables, ", "), "", "C no repeatable quest ships")
	local empty = {}
	for _, key in ipairs(hub_lines) do
		if not line_quests[key] then empty[#empty + 1] = key end
	end
	eq(table.concat(empty, ", "), "", "C every hub line of a giver has a quest")
end

------------------------------------------------------------------------------
-- D. Saved quest state with removed quest ids.
------------------------------------------------------------------------------
do
	local serial = {}
	local function serialize(value)
		serial[#serial + 1] = deep_copy(value)
		return "#" .. #serial
	end
	local function deserialize(text)
		local index = tonumber((text or ""):match("^#(%d+)$"))
		return index and deep_copy(serial[index]) or nil
	end
	core = {
		serialize = serialize, deserialize = deserialize,
		get_item_group = function() return 0 end,
		registered_items = {}, registered_entities = {},
		log = noop, chat_send_player = noop,
	}
	setmetatable(core, {__index = function(_, key)
		if type(key) == "string" and key:match("^register_") then return noop end
	end})
	grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
	grug_factions = {get_faction = function() return "accord" end,
		same_faction = function() return false end}
	grug_classes = {get_race = function() return "dwarf" end}
	grug_xp = {get_level = function() return 20 end, quest_reward = function() return 0 end,
		register_on_level_change = noop}
	grug_mobs = {register_on_eligible_kill = noop, register_participant_drop_hook = noop}
	grug_money = {}
	grug_quests = {}
	grug_core = {hud_layout = {side_text_width = function() return 400 end}}
	dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/state.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/labels.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/hud.lua")
	local Q = grug_quests
	local now = 1000000
	Q.clock = function() return now end
	Q.register_npc("r14_dwarf_steward", {settlement = "s", socket = "a", title = "Steward"})
	-- A kept quest of the steward's other line, and a second one to accept.
	Q.register_quest("copperfell_survey_01", {title = "Survey", description = "d",
		npc = "r14_dwarf_steward", rewards = {weight = 1},
		objectives = {{type = "item", item = "grug_food:raw_meat", count = 4}}})
	Q.register_quest("copperfell_survey_02", {title = "Survey Two", description = "d",
		npc = "r14_dwarf_steward", rewards = {weight = 1},
		objectives = {{type = "item", item = "grug_food:raw_meat", count = 2}}})
	-- Saved by 0.45: two shipped bounties in progress, one done and cooling down.
	local store = {["grug_quests:state"] = serialize({
		active = {copperfell_survey_01 = {1}, copperfell_bounty_rats = {3},
			mournfen_steward_bounty = {}},
		completed = {copperfell_bounty_gnawers = true, copperfell_bounty_rats = true},
		cooldowns = {copperfell_bounty_gnawers = now + 600, copperfell_bounty_rats = now - 60},
		tracked = {"copperfell_bounty_rats", "copperfell_survey_01", "mournfen_steward_bounty"},
		hud = true})}
	local meta = {get_string = function(_, k) return store[k] or "" end,
		set_string = function(_, k, v) store[k] = v ~= "" and v or nil end}
	local player = {get_meta = function() return meta end,
		get_player_name = function() return "brannoc" end,
		get_inventory = function()
			return {get_list = function() return {} end, get_size = function() return 0 end}
		end}
	local ok, journal = pcall(Q.journal, player)
	check(ok, "D the journal loads: " .. tostring(journal))
	if ok then
		eq(#journal.quests, 1, "D ...and lists the kept quest only")
		eq(journal.quests[1] and journal.quests[1].id, "copperfell_survey_01", "D ...the survey")
		eq(table.concat(journal.tracked, ","), "copperfell_survey_01", "D ...and tracks it only")
		local hud_ok, hud_err = pcall(Q.hud_text, journal, nil)
		check(hud_ok, "D the tracker draws: " .. tostring(hud_err))
	end
	local markers_ok, states = pcall(Q.marker_states, player)
	check(markers_ok, "D the markers compute: " .. tostring(states))
	eq(markers_ok and states.r14_dwarf_steward, "available", "D the steward offers the second survey")
	check(pcall(Q.credit_kill, player, {object = {}, description = "Mangy Rat"}, {x = 0, y = 0, z = 0}),
		"D a kill credit with removed active ids does not crash")
	local status_ok, status = pcall(Q.status, player, "copperfell_bounty_rats")
	check(status_ok, "D the status of a removed id does not crash: " .. tostring(status))
	local accept_ok, accepted = pcall(Q.accept, player, "copperfell_bounty_rats")
	check(accept_ok and not accepted, "D a removed id cannot be accepted, without an error")
	accept_ok, accepted = pcall(Q.accept, player, "copperfell_survey_02")
	check(accept_ok and accepted, "D a kept quest is accepted: " .. tostring(accepted))
	local saved = deserialize(store["grug_quests:state"])
	check(saved.active.copperfell_bounty_rats == nil and saved.active.mournfen_steward_bounty == nil,
		"D the save drops the removed active ids")
	eq(table.concat(saved.tracked, ","), "copperfell_survey_01,copperfell_survey_02",
		"D ...and the removed tracked id")
	eq(saved.active.copperfell_survey_01 and saved.active.copperfell_survey_01[1], 1,
		"D the kept quest's progress stays")
	check(saved.completed.copperfell_bounty_gnawers == true,
		"D completed ids stay as written (only looked up by id)")
	check(pcall(Q.abandon, player, "copperfell_survey_02"), "D abandon works")
	now = now + 3600
	check(pcall(Q.marker_states, player), "D the markers after the old cooldown's end")
end

------------------------------------------------------------------------------
-- E. The dialog legend.
------------------------------------------------------------------------------
do
	local Q = grug_quests
	core.formspec_escape = function(text) return text end
	core.colorize = function(_, text) return text end
	setmetatable(grug_core, {__index = function(_, key)
		if type(key) == "string" and key:match("^register_") then return noop end
	end})
	dofile(repo .. "/mods/PLAYER/grug_quests/npc.lua")
	check(Q.status_legend():find("(R)", 1, true) == nil, "E no repeatable: the legend has no (R)")
	check(Q.status_tooltip():find("(R)", 1, true) == nil, "E ...nor the tooltip")
	Q.register_quest("test_bounty", {title = "Bounty", description = "d", npc = "r14_dwarf_steward",
		rewards = {weight = 1}, repeatable = {cooldown = 60},
		objectives = {{type = "item", item = "grug_food:raw_meat", count = 1}}})
	check(Q.status_legend():find("(R) Repeatable", 1, true) ~= nil, "E a repeatable: the legend explains (R)")
	check(Q.status_tooltip():find("(R): repeatable", 1, true) ~= nil, "E ...and the tooltip")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	print("R46 XP PORTABLE FAIL")
	os.exit(1)
end
print("R46 XP PORTABLE PASS checks=" .. checks)
