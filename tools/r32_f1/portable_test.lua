-- Round 32 Lane F1 portable test (LuaJIT): the zone banner's territory line
-- and colour (round32-plan.md §2.3) and the hostile-camp map symbol (§2.2).
--
--   luajit tools/r32_f1/portable_test.lua [repo]
--
-- Loads the REAL grug_map location_view.lua, location.lua and
-- settlement_icons.lua, grug_pvp rules.lua and grug_core hud_layout.lua on
-- a fake engine. The territory comes from grug_pvp's real R.territory over
-- a stub world: x < 0 Accord peaceful land ("Home Vale"), 0 <= x < 100 a
-- contested zone ("The Front"), 100 <= x < 200 deep ocean, x >= 200 Throng
-- peaceful land ("Ember Hold"); every land column at y <= -501 contested.
-- Checks:
--   P  pure: the three lines and colours, no line and the neutral colour
--      without a status; the trigger: a zone change shows, a status change
--      on the same name shows (friendly <-> contested and enemy <->
--      contested by depth), a depth crossing inside a contested zone shows
--      nothing, a change during a display waits for its end;
--   R  runtime: banner and line texts and colours on join and on every
--      crossing above, the button flag in friendly land still "Friendly
--      Territory", the open sea neutral, a player without a faction neutral
--      and no crash, no grug_pvp no crash, the minimap line's colour
--      (text_of), HUD writes only on change, zone queries per sample;
--   H  the hostile-camp class: bandit and Mirefolk camp slots are hostile,
--      every other slot is not.
-- Prints "R32 F1 PORTABLE PASS checks=<n>", or the failures and raises an
-- error (exit status 1).
grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

local GREEN, YELLOW, RED, NOTICE = 0x55ff55, 0xffdd33, 0xff5555, 0xf0e6c8
local FRIENDLY, CONTESTED, ENEMY = "Friendly Territory", "Contested Territory (PvP)",
	"Enemy Territory (PvP)"

-- ---------------------------------------------------------------------------
-- P: pure rules (location_view.lua)
-- ---------------------------------------------------------------------------
local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")
do
	eq(L.line("friendly"), FRIENDLY, "P friendly line")
	eq(L.line("contested"), CONTESTED, "P contested line")
	eq(L.line("enemy"), ENEMY, "P enemy line")
	eq(L.line(nil), "", "P no status: no line")
	eq(L.color("friendly", NOTICE), GREEN, "P friendly is green")
	eq(L.color("contested", NOTICE), YELLOW, "P contested is yellow")
	eq(L.color("enemy", NOTICE), RED, "P enemy is red")
	eq(L.color(nil, NOTICE), NOTICE, "P no status: the neutral colour")

	local s = L.new_state()
	eq(L.sample(s, "Home", 0, "friendly"), "Home", "P join shows the name")
	eq(L.sample(s, "Home", 1, "friendly"), nil, "P busy: nothing")
	eq(L.expire(s, "Home", 1.5, "friendly"), false, "P same place at the end: hide")
	eq(L.sample(s, "Home", 2, "friendly"), nil, "P unchanged: nothing")
	-- Below y -501 under own land: the same name again with the new status.
	eq(L.sample(s, "Home", 3, "contested"), "Home", "P friendly -> contested by depth shows")
	eq(s.shown_status, "contested", "P ...with the contested status")
	eq(L.expire(s, "Home", 4.5, "contested"), false, "P then hides")
	eq(L.sample(s, "Home", 5, "friendly"), "Home", "P contested -> friendly shows")
	L.expire(s, "Home", 6.5, "friendly")
	-- A zone change always shows, with or without a status change.
	eq(L.sample(s, "Front", 7, "contested"), "Front", "P into a contested zone")
	L.expire(s, "Front", 8.5, "contested")
	eq(L.sample(s, "Front", 9, "contested"), nil,
		"P a depth crossing inside a contested zone shows nothing")
	eq(L.sample(s, "Front Two", 10, "contested"), "Front Two",
		"P a zone change with the same status shows")
	L.expire(s, "Front Two", 11.5, "contested")
	-- Enemy land and its depth.
	eq(L.sample(s, "Ember", 12, "enemy"), "Ember", "P into enemy land")
	L.expire(s, "Ember", 13.5, "enemy")
	eq(L.sample(s, "Ember", 14, "contested"), "Ember", "P enemy -> contested by depth shows")
	L.expire(s, "Ember", 15.5, "contested")
	eq(L.sample(s, "Ember", 16, "enemy"), "Ember", "P contested -> enemy shows")
	-- A status change during a display waits for its end, then shows.
	eq(L.sample(s, "Ember", 16.5, "contested"), nil, "P busy: a status change waits")
	eq(L.expire(s, "Ember", 17.5, "contested"), "Ember", "P ...and shows at the end")
	eq(s.shown_status, "contested", "P ...with the new status")
	-- ...and a change undone during the display shows nothing more.
	eq(L.sample(s, "Ember", 18, "enemy"), nil, "P busy again")
	eq(L.expire(s, "Ember", 19, "contested"), false, "P back to what is shown: hide")
	-- No location: nothing.
	eq(L.sample(L.new_state(), nil, 0, "friendly"), nil, "P no location: nothing")
	-- No status (the open sea): the name shows; gaining one shows again.
	s = L.new_state()
	eq(L.sample(s, "Open sea", 0, nil), "Open sea", "P the open sea shows")
	L.expire(s, "Open sea", 1.5, nil)
	eq(L.sample(s, "Open sea", 2, nil), nil, "P ...once")
end

-- ---------------------------------------------------------------------------
-- R: runtime (location.lua on a fake engine)
-- ---------------------------------------------------------------------------
local R = dofile(repo .. "/mods/PLAYER/grug_pvp/rules.lua")
do
	local now_us = 0
	local joins, leaves, steps, loaded = {}, {}, {}, {}
	local players = {}
	rawset(_G, "core", {
		get_current_modname = function() return "grug_map" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
		get_us_time = function() return now_us end,
		get_worldpath = function() return "/nonexistent/grug_r32_f1_world" end,
		safe_file_write = function() return false end,
		log = function() end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		get_connected_players = function()
			local list = {}
			for _, p in pairs(players) do list[#list + 1] = p end
			table.sort(list, function(a, b) return a.name < b.name end)
			return list
		end,
		get_player_by_name = function(name) return players[name] end,
		get_player_window_information = function() return nil end,
	})
	rawset(_G, "grug_core", {
		FEED_COLOR = {notice = NOTICE},
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function() return {} end,
	})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	local queries = 0
	local function ocean(pos) return pos.x >= 100 and pos.x < 200 end
	rawset(_G, "grug_zones", {
		id_at = function(x)
			queries = queries + 1
			if x < 0 then return "home" end
			if x < 100 then return "front" end
			if x < 200 then return nil end
			return "ember"
		end,
		get = function(id)
			local names = {home = "Home Vale", front = "The Front", ember = "Ember Hold"}
			return {id = id, numeric_id = 1, display_name = names[id]}
		end,
		water_class_at = function() return "deep_ocean" end,
		hard_footprint_in = function() return nil end,
		pvp_rule_at = function(pos)
			queries = queries + 1
			if ocean(pos) then return nil end
			if pos.y <= -501 then return "contested" end
			if pos.x >= 0 and pos.x < 100 then return "contested" end
			return "peaceful"
		end,
		faction_at = function(pos)
			queries = queries + 1
			if pos.x < 0 then return "accord" end
			if pos.x >= 200 then return "throng" end
			return nil
		end,
	})
	local faction = {}
	rawset(_G, "grug_factions", {get_faction = function(player)
		return faction[player:get_player_name()]
	end})
	-- grug_pvp: its real territory rule over the zone stub (the same as
	-- grug_pvp.territory_at), and a flag the banner must not read.
	local flagged = {}
	local pvp = {
		territory_at = function(pos, own)
			if not own then return nil end
			local rule = grug_zones.pvp_rule_at(pos)
			local here = rule == "peaceful" and grug_zones.faction_at(pos) or nil
			return R.territory(rule, here, own)
		end,
		state = function(player)
			return flagged[player:get_player_name()] and
				{flagged = true, reason = "button", seconds_left = 60} or {flagged = false}
		end,
	}
	rawset(_G, "grug_home", {locations = function() return {} end})
	rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
	grug_map.page_layout = {map_w = 12.37, region_labels = {}}
	grug_map.static_marker_positions = function() return {} end
	rawset(_G, "grug_pvp", pvp)
	dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
	for _, fn in ipairs(loaded) do fn() end
	local M = grug_map.location

	local function step(seconds)
		local target = now_us + seconds * 1e6
		while now_us < target - 1 do
			now_us = now_us + 50000
			for _, fn in ipairs(steps) do fn(0.05) end
		end
	end
	local function new_player(name, pos)
		local p = {name = name, huds = {}, next_id = 0, sent = 0,
			pos = {x = pos.x, y = pos.y, z = pos.z}}
		function p:get_player_name() return self.name end
		function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
		function p:hud_add(def)
			self.next_id = self.next_id + 1
			local copy = {}
			for k, v in pairs(def) do copy[k] = v end
			self.huds[self.next_id] = copy
			return self.next_id
		end
		function p:hud_change(id, stat, value)
			self.sent = self.sent + 1
			self.huds[id][stat] = value
		end
		return p
	end
	local function join(p)
		players[p.name] = p
		for _, fn in ipairs(joins) do fn(p) end
		local banner, line
		for id, def in pairs(p.huds) do
			if def.type == "text" and def.position and def.position.y == 0 then
				if def.size then banner = id else line = id end
			end
		end
		return p.huds[banner], p.huds[line]
	end
	local function shows(banner, line, text, second, color, label)
		check(banner.text == text and line.text == second and banner.number == color and
			line.number == color, ("%s (got %q / %q / %06x / %06x)"):format(label,
			tostring(banner.text), tostring(line.text), banner.number or -1, line.number or -1))
	end
	-- Walk until the banner shows `text` (at most 2 s): the next sample.
	local function until_shown(banner, text)
		local waited = 0
		while banner.text ~= text and waited < 2 do
			step(0.05)
			waited = waited + 0.05
		end
	end

	faction.ann = "accord"
	local ann = new_player("ann", {x = -50, y = 10, z = 0})
	local banner, line = join(ann)
	check(banner and line, "R banner and line elements on join")
	eq(line.offset.y, grug_core.hud_layout.zone_subtitle_offset(nil).y,
		"R the line sits at the second-line anchor")
	step(1.0)
	shows(banner, line, "Home Vale", FRIENDLY, GREEN, "R join: own land, green")
	local text, color = M.text_of(ann)
	check(text == "Home Vale" and color == GREEN, "R the minimap line is green")
	step(1.6)
	check(banner.text == "" and line.text == "", "R both lines hide together")
	-- The PvP button in friendly land: still "Friendly Territory".
	flagged.ann = true
	step(3)
	eq(banner.text, "", "R the button flag shows nothing")
	eq(select(2, M.text_of(ann)), GREEN, "R the button flag keeps the line green")
	-- Down to y -501 under own land: the same name, contested, yellow.
	local queries_before, samples_before = queries, M.stats.samples
	ann.pos.y = -501
	until_shown(banner, "Home Vale")
	shows(banner, line, "Home Vale", CONTESTED, YELLOW, "R own land at y -501: contested")
	eq(select(2, M.text_of(ann)), YELLOW, "R the minimap line turns yellow")
	step(2)
	eq(banner.text, "", "R hidden after its display")
	ann.pos.y = -500
	until_shown(banner, "Home Vale")
	shows(banner, line, "Home Vale", FRIENDLY, GREEN, "R back up at y -500: friendly again")
	step(2)
	-- Into the contested zone: always shows; its depth crossing does not.
	ann.pos = {x = 50, y = 10, z = 0}
	until_shown(banner, "The Front")
	shows(banner, line, "The Front", CONTESTED, YELLOW, "R a contested zone: yellow")
	step(2)
	ann.pos.y = -600
	step(2)
	eq(banner.text, "", "R a depth crossing in a contested zone shows nothing")
	ann.pos.y = 10
	step(2)
	eq(banner.text, "", "R ...nor back up")
	-- Over the open sea: the name, no line, the notice colour.
	ann.pos = {x = 150, y = 0, z = 0}
	until_shown(banner, "Open sea")
	shows(banner, line, "Open sea", "", NOTICE, "R the open sea: no line, neutral")
	eq(select(2, M.text_of(ann)), NOTICE, "R the minimap line is neutral at sea")
	step(2)
	-- Enemy land and its depth.
	ann.pos = {x = 250, y = 10, z = 0}
	until_shown(banner, "Ember Hold")
	shows(banner, line, "Ember Hold", ENEMY, RED, "R enemy land: red")
	step(2)
	ann.pos.y = -501
	until_shown(banner, "Ember Hold")
	shows(banner, line, "Ember Hold", CONTESTED, YELLOW, "R enemy land at y -501: contested")
	step(2)
	ann.pos.y = 10
	until_shown(banner, "Ember Hold")
	shows(banner, line, "Ember Hold", ENEMY, RED, "R enemy land back up: red")
	step(2)
	-- Cost: the territory adds two zone queries to the name's one.
	local samples = M.stats.samples - samples_before
	check(samples > 0 and queries - queries_before <= 3 * samples,
		("R at most three zone queries per sample (%d for %d)"):format(
			queries - queries_before, samples))
	-- Standing still sends nothing.
	local sent = ann.sent
	step(5)
	eq(ann.sent, sent, "R a player standing still sends nothing")
	-- The same colour again is not resent: home, then a town of the same
	-- status would only change the text. Here: two enemy displays in a row.
	ann.pos = {x = 250, y = -501, z = 0}
	until_shown(banner, "Ember Hold")
	step(2)
	sent = ann.sent
	ann.pos.y = 10
	until_shown(banner, "Ember Hold")
	-- name, line and both colours: the name is restored, the line and the
	-- colours change, nothing else
	eq(ann.sent - sent, 4, "R a status change writes name, line and both colours once")
	step(2)
	for _, fn in ipairs(leaves) do fn(ann) end
	players.ann = nil
	text, color = M.text_of("ann")
	check(text == "" and color == NOTICE, "R after leave: no text, neutral")

	-- A player without a faction: the name, no line, neutral; no crash.
	local cid = new_player("cid", {x = -50, y = 10, z = 0})
	banner, line = join(cid)
	local ok = pcall(step, 1.0)
	check(ok, "R no faction: no error")
	shows(banner, line, "Home Vale", "", NOTICE, "R no faction: no line, neutral")
	for _, fn in ipairs(leaves) do fn(cid) end
	players.cid = nil

	-- No grug_pvp at all: neutral, no crash.
	rawset(_G, "grug_pvp", nil)
	faction.dan = "accord"
	local dan = new_player("dan", {x = -50, y = 10, z = 0})
	banner, line = join(dan)
	ok = pcall(step, 1.0)
	check(ok, "R without grug_pvp: no error")
	shows(banner, line, "Home Vale", "", NOTICE, "R without grug_pvp: no line, neutral")
	for _, fn in ipairs(leaves) do fn(dan) end
	players.dan = nil
end

-- ---------------------------------------------------------------------------
-- H: hostile camps (settlement_icons.lua): their own baked icon kinds
-- since Round 44 (bake.lua draws every settlement for everyone).
-- ---------------------------------------------------------------------------
do
	local icons = dofile(repo .. "/mods/PLAYER/grug_map/settlement_icons.lua")
	check(icons.kind("bandit_1") == "bandit" and icons.kind("bandit_2") == "bandit",
		"H bandit camps have the bandit icon")
	check(icons.kind("mirefolk") == "mirefolk", "H Mirefolk camps have the Mirefolk icon")
	for _, slot in ipairs({"start", "capital", "village_1", "outpost_2", "pvp_fortress",
			"pvp_battlegrounds_low", "mine", "apex_mine", "clash_1", "dragon",
			"rare_ashmaw", "landmark"}) do
		local kind = icons.kind(slot)
		check(kind ~= "bandit" and kind ~= "mirefolk", "H " .. slot .. " is not a hostile camp")
	end
	check(icons.kind(nil) == nil, "H no slot: no icon")
end

if #failures == 0 then
	print(("R32 F1 PORTABLE PASS checks=%d"):format(checks))
else
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R32 F1 PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
