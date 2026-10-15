-- Round 46 lane XP portable test (LuaJIT): kill XP by level difference,
-- the gray line, and the repeatable quests removed (round46-plan.md §4.4,
-- rulings 5, 7 and 8). Loads the REAL files under minimal `core` stubs:
--
--   A. the kill-XP table (grug_xp.kill_xp through grug_mobs.kill_xp): XP
--      per kill at player levels 10, 30 and 60 for d = -10, -9, -3, 0, +3,
--      +6, normal, elite and rare (printed for the lane report), and the
--      factor at every d from -11 to +8 (Round 49 rulings 5 and 6: -10 % per
--      level below, gray at 10 below, rare x2);
--   B. the target frame's con colour: gray with "(no XP)" for every mob
--      whose kill pays the viewer nothing (10 below, a critter, a
--      `_grug_xp_reward` of 0, the viewer's own faction; the settlement's
--      own predicate grug_mobs.player_kill_xp), else a gradient per level,
--      green at 9 below, yellow at the own level, red from 5 above;
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
	local expected_percent = {[-11] = 0, [-10] = 0, [-9] = 10, [-8] = 20, [-7] = 30,
		[-6] = 40, [-5] = 50, [-4] = 60, [-3] = 70, [-2] = 80, [-1] = 90, [0] = 100,
		[1] = 110, [2] = 120, [3] = 130, [4] = 140, [5] = 150, [6] = 150, [7] = 150, [8] = 150}
	for d = -11, 8 do
		eq(X.kill_percent(30 + d, 30), expected_percent[d], "A the factor at d = " .. d)
		eq(X.is_gray(30 + d, 30), d <= -10, "A gray at d = " .. d)
	end
	print("XP per kill (solo; d = mob level - player level)")
	print("player   tier    d=-10  d=-9   d=-3    d=0   d=+3   d=+6")
	local want = {
		[10] = {normal = {0, 7, 52, 75, 97, 112}, elite = {0, 30, 210, 300, 390, 450},
			rare = {0, 15, 105, 150, 195, 225}},
		[30] = {normal = {0, 17, 122, 175, 227, 262}, elite = {0, 70, 490, 700, 910, 1050},
			rare = {0, 35, 245, 350, 455, 525}},
		[60] = {normal = {0, 32, 227, 325, 422, 487}, elite = {0, 130, 910, 1300, 1690, 1950},
			rare = {0, 65, 455, 650, 845, 975}},
	}
	for _, level in ipairs({10, 30, 60}) do
		for _, tier in ipairs({"normal", "elite", "rare"}) do
			local row = {}
			for i, d in ipairs({-10, -9, -3, 0, 3, 6}) do
				row[i] = kill(level + d, level, tier)
				eq(row[i], want[level][tier][i], ("A L%d %s at d = %d"):format(level, tier, d))
			end
			print(("%6d   %-6s %6d %6d %6d %6d %6d %6d"):format(level, tier, unpack(row)))
		end
	end
	eq(kill(66, 60, "rare"), 975, "A a rare 6 above at L60: 325 x 1.5 x 2")
	-- The rare tier between normal and elite (Round 49 ruling 6): x2.5 HP,
	-- x1.4 damage, x2 XP, armor 90; at L30 764 / 1910 / 2292 HP.
	local n_hp, n_dmg, n_xp = grug_mobs.stats_for(30, "normal")
	local r_hp, r_dmg, r_xp = grug_mobs.stats_for(30, "rare")
	local e_hp, e_dmg, e_xp = grug_mobs.stats_for(30, "elite")
	eq(n_hp, 764, "A a normal L30 has 764 HP")
	eq(r_hp, 1910, "A a rare L30: 764 x 2.5")
	eq(e_hp, 2292, "A an elite L30: x3")
	eq(r_dmg, grug_mobs.scale_attack_damage(21.7), "A a rare L30 hits 15.5 x 1.4 = 21.7 (before the scale)")
	eq(r_xp, 350, "A a rare L30 is worth 2 x 175")
	check(n_hp < r_hp and r_hp < e_hp and n_dmg < r_dmg and r_dmg < e_dmg and n_xp < r_xp and r_xp < e_xp,
		"A the rare lies between normal and elite in HP, damage and XP")
	-- Promoting a live, full-health L30 mob applies the rare's HP and armor
	-- 90 (its tier visuals already in place, so no rescale here).
	local groups
	local ent = {name = "test:rare", _grug_level = 30, _grug_visual_tier = "rare",
		health = 764, hp_max = 764, object = {set_properties = noop,
			get_properties = function() return {hp_max = 764} end,
			set_armor_groups = function(_, g) groups = g end}}
	grug_core.format_k, grug_core.set_tag_carrier_text = tostring, noop
	grug_mobs.ensure_tag_carrier = noop
	grug_mobs.set_tier(ent, "rare")
	eq(ent.hp_max, 1910, "A set_tier rare: 1910 HP max")
	eq(ent.health, 1910, "A set_tier rare: full health stays full")
	eq(ent.armor, 90, "A set_tier rare: armor 90")
	eq(groups and groups.fleshy, 90, "A set_tier rare: the fleshy armor group is 90")
	eq(ent._grug_xp, 350, "A set_tier rare: 350 XP at L30")
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
	-- The real grug_xp and levels.lua of A: the frame asks the payout's own
	-- predicate, grug_mobs.player_kill_xp.
	local level = 30
	X.get_level = function() return level end
	grug_xp = X
	grug_mobs.tag_text = function(mob) return "Boar L" .. mob._grug_level end
	grug_factions = {same_faction = function(_, object)
		return object ~= nil and object.faction == "accord"
	end}
	grug_mobs.register_level_cfg("test:kraken", {_grug_xp_reward = 0})
	grug_mobs.register_level_cfg("test:fixed", {_grug_xp_reward = 77})
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
	local function frame_of(mob_level, opts)
		opts = opts or {}
		local mob = {name = opts.name or "test:mob", _grug_level = mob_level,
			_grug_tier = opts.tier or "normal", health = 10, object = {faction = opts.faction}}
		looking_at = {is_player = function() return false end,
			get_luaentity = function() return mob end}
		for _, fn in ipairs(steps) do fn(0.5) end
		return huds[1].text, huds[1].number
	end
	local text, color = frame_of(20)
	eq(text, "Boar L20 (no XP)", "B 10 below: (no XP)")
	eq(color, 0xaaaaaa, "B 10 below: gray")
	text, color = frame_of(21)
	eq(text, "Boar L21", "B 9 below: no (no XP)")
	eq(color, 0x55ff55, "B 9 below: green")
	-- The gradient (Round 46 follow-up, Round 49 ruling 5): green at -9,
	-- yellow at 0, red from +5.
	local gradient = {[-11] = 0xaaaaaa, [-10] = 0xaaaaaa, [-9] = 0x55ff55, [-8] = 0x68ff55,
		[-7] = 0x7bff55, [-6] = 0x8eff55, [-5] = 0xa1ff55, [-4] = 0xb3ff55, [-3] = 0xc6ff55,
		[-2] = 0xd9ff55, [-1] = 0xecff55, [0] = 0xffff55,
		[1] = 0xffdd55, [2] = 0xffbb55, [3] = 0xff9955, [4] = 0xff7755, [5] = 0xff5555,
		[6] = 0xff5555, [12] = 0xff5555}
	for _, d in ipairs({-11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 12}) do
		text, color = frame_of(30 + d)
		eq(color, gradient[d], ("B the colour at d = %d is %06x"):format(d, gradient[d]))
	end
	level = 1
	text, color = frame_of(1)
	eq(color, 0xffff55, "B a level-1 player on a level-1 mob: yellow")
	level = 30
	-- Every other zero-XP case is gray with "(no XP)" too (the user, Round 46),
	-- read from the predicate the kill settlement pays by.
	local function no_xp(label, mob_level, opts)
		text, color = frame_of(mob_level, opts)
		eq(color, 0xaaaaaa, "B " .. label .. ": gray")
		eq(text, "Boar L" .. mob_level .. " (no XP)", "B " .. label .. ": (no XP)")
	end
	no_xp("a critter (tier xp 0)", 30, {tier = "critter"})
	no_xp("a _grug_xp_reward of 0 (the Kraken)", 35, {name = "test:kraken", tier = "elite"})
	no_xp("a mob of the viewer's own faction", 31, {faction = "accord"})
	no_xp("an own-faction elite guard above the viewer", 40, {faction = "accord", tier = "elite"})
	text, color = frame_of(31, {faction = "throng"})
	eq(color, 0xffdd55, "B an enemy-faction mob keeps its gradient colour")
	text, color = frame_of(30, {name = "test:fixed"})
	eq(text, "Boar L30", "B a positive _grug_xp_reward pays, so no (no XP)")
	no_xp("a positive _grug_xp_reward 10 below (the gray line covers overrides)", 20,
		{name = "test:fixed"})
	-- The predicate is what the settlement pays before the split.
	local viewer_mob = {name = "test:mob", _grug_level = 33, _grug_tier = "normal", object = {}}
	eq(grug_mobs.player_kill_xp(viewer_mob, viewer, 30), 227.5, "B the predicate: 175 x 1.3 at +3 (floored at the split)")
	eq(grug_mobs.player_kill_xp(viewer_mob, viewer, 42), 23.5, "B ...M(42) 235 x 0.1 at 9 below")
	eq(grug_mobs.player_kill_xp(viewer_mob, viewer, 43), 0, "B ...and 0 at 10 below")
	local init_src = read(repo .. "/mods/ENTITIES/grug_mobs/init.lua")
	check(init_src:find("math.floor(grug_mobs.player_kill_xp(self, player, player_level) / count)", 1, true)
		~= nil, "B the kill settlement pays the same predicate")
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
