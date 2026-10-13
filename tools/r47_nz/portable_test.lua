-- Round 47 lane NZ portable test (LuaJIT; round47-plan.md §4.9, rulings
-- 20-22):
--   F  NPC facing: over every composition with NPC sockets (the starts, the
--      Round 14 villages, outposts and camps of every race, the Round 20
--      POIs, the PvP fortresses and camps in every camp race, every capital
--      core and plot) no NPC faces a wall within two nodes without a work
--      feature before it (tools/r47_nz/facing.lua); and the rule itself: a
--      wall a node or two ahead fails, its turned twin passes, `door` turns
--      the facing round, a feature or a low wall at the feet passes, a
--      wall course under a window is no stall counter;
--   B  the zone banner shows for 4 s (location_view.lua DISPLAY), through
--      the real location.lua too;
--   Z  zone discovery (grug_map/zone_discovery.lua with the REAL grug_xp,
--      through the REAL location.lua on a fake engine): the XP at both
--      sides of min(zone level_min, character level), source "discovery";
--      the level-up sound once, with and without a level-up; the visited
--      set in player meta, a second entry pays nothing; a new character's
--      start zone marked silently at its first sample (in its start town),
--      an existing character's current zone likewise; towns, the open sea
--      and the civic capital zones never count; the discovery runs only
--      when the zone changes.
--
-- Usage (repo root): luajit tools/r47_nz/portable_test.lua [REPO]
-- Prints "R47 NZ PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- F. NPC facing --------------------------------------------------------------
do
	local facing = dofile(repo .. "/tools/r47_nz/facing.lua")
	local palettes = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/palette.lua")
	local fails, comps, sockets = facing.run(repo)
	check(comps > 400 and sockets > 1500, "facing: every composition built (" ..
		comps .. " compositions, " .. sockets .. " NPC sockets)")
	check(#fails == 0, "facing: " .. #fails .. " NPCs face a wall:\n" ..
		table.concat(fails, "\n"))

	-- The rule on a hand-made composition: one socket at the origin facing +z.
	local function verdict(cells, socket)
		socket.id, socket.x, socket.y, socket.z = "s", 0, 1, 0
		socket.role = socket.role or "idle"
		socket.dir = socket.dir or {x = 0, z = 1}
		local list = {}
		for _, c in ipairs(cells) do
			list[#list + 1] = {x = c[1], y = c[2], z = c[3], name = c[4]}
		end
		return #facing.check({label = "t", cells = list, sockets = {socket}},
			palettes) == 0
	end
	local wall = "default:stonebrick"
	check(not verdict({{0, 2, 1, wall}}, {}), "rule: a wall a node ahead fails")
	check(not verdict({{0, 2, 2, wall}}, {}), "rule: a wall two nodes ahead fails")
	check(verdict({{0, 2, 3, wall}}, {}), "rule: a wall three nodes ahead passes")
	check(verdict({{0, 2, -1, wall}}, {}), "rule: a wall behind passes")
	check(verdict({{0, 2, 1, wall}}, {dir = {x = 0, z = -1}}),
		"rule: the turned twin passes")
	check(not verdict({{0, 2, -1, "doors:hidden"}}, {dir = {x = 0, z = -1},
		tags = {"work"}}), "rule: a door ahead is a wall")
	check(verdict({{0, 2, -1, "doors:hidden"}}, {dir = {x = 0, z = -1},
		tags = {"work", "door"}}), "rule: `door` turns the facing round")
	check(not verdict({{0, 2, 1, "doors:hidden"}}, {dir = {x = 0, z = -1},
		tags = {"door"}}), "rule: a `door` socket facing away from its door fails")
	check(verdict({{0, 1, 1, "walls:cobble"}}, {}), "rule: a low wall at the feet passes")
	check(verdict({{0, 1, 1, "grug_decor:xdecor_cauldron"}, {0, 2, 1, wall}}, {}),
		"rule: a feature at the feet passes")
	check(verdict({{0, 1, 2, "grug_decor:xdecor_barrel"}, {0, 2, 1, "air"}}, {}),
		"rule: a feature two nodes ahead passes")
	check(verdict({{0, 2, 1, "default:tree"}}, {role = "work", activity = "chop"}),
		"rule: a woodcutter faces its log")
	check(not verdict({{0, 2, 1, "default:tree"}}, {role = "work", activity = "tend"}),
		"rule: a gardener does not")
	check(verdict({{0, 1, 1, "default:stonebrick"}}, {role = "work", activity = "stall"}),
		"rule: a stall's counter under open air passes")
	check(not verdict({{0, 1, 1, "grug_decor:darkage_slate_brick"},
		{0, 2, 1, "xpanes:pane_flat"}}, {role = "work", activity = "stall"}),
		"rule: a wall course under a window is no counter")
	check(verdict({{0, 2, 1, wall}}, {role = "guard_patrol"}),
		"rule: a patrol waypoint is no standing NPC")
end

-- B, Z. The banner and zone discovery ---------------------------------------
local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")
check(L.DISPLAY == 4, "B the zone banner shows for 4 s (ruling 21)")
do
	-- The engine: grug_xp registers its HUD, command and join hooks into
	-- no-ops; location.lua's are collected and driven below.
	local now_us = 0
	local joins, leaves, steps = {}, {}, {}
	local online = {}
	local noop = function() end
	local fake_core = setmetatable({
		get_current_modname = function() return "grug_map" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
		get_us_time = function() return now_us end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
		get_player_window_information = function() return nil end,
		get_player_by_name = function(name) return online[name] end,
		get_connected_players = function()
			local list = {}
			for _, p in pairs(online) do list[#list + 1] = p end
			table.sort(list, function(a, b) return a.name < b.name end)
			return list
		end,
	}, {__index = function() return noop end})
	rawset(_G, "core", fake_core)
	local banners, fed, sounds = {}, {}, {}
	rawset(_G, "grug_sounds", {play = function(event, player)
		sounds[#sounds + 1] = {event = event, name = player.name}
		return true
	end})
	rawset(_G, "grug_core", {
		banner = function(_, text) banners[#banners + 1] = text end,
		feed_xp = function(_, amount) fed[#fed + 1] = amount end,
		particles = {play = noop},
		FEED_COLOR = {notice = 0xf0e6c8},
		player_in_creation_stasis = function() return false end,
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function()
			return {{key = "dawnmere", display_name = "Dawnmere",
				anchor = {x = 0, y = 10, z = -2550}},
				{key = "highcourt", display_name = "Highcourt", slot = "capital",
				anchor = {x = 0, y = 10, z = -1500}}}
		end,
	})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	dofile(repo .. "/mods/PLAYER/grug_xp/init.lua")
	fake_core.register_on_joinplayer = function(fn) joins[#joins + 1] = fn end
	fake_core.register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end
	fake_core.register_globalstep = function(fn) steps[#steps + 1] = fn end

	-- The world: Dawnmere Fields (start zone, L1-10, z < -2300) with the start
	-- town Dawnmere at (0, -2550); Goldmead Vale (L11-20) to -1800; the civic
	-- Highcourt zone (L20-30) with its city at (0, -1500); Ashenward March
	-- (L31-40) beyond -1000; open sea at |x| > 1000.
	local RECORDS = {
		elandor_dawnmere_fields = {id = "elandor_dawnmere_fields",
			display_name = "Dawnmere Fields", level_min = 1, level_max = 10},
		elandor_goldmead_vale = {id = "elandor_goldmead_vale",
			display_name = "Goldmead Vale", level_min = 11, level_max = 20},
		elandor_highcourt = {id = "elandor_highcourt", display_name = "Highcourt",
			level_min = 20, level_max = 30, civic_no_hostiles = true},
		elandor_ashenward_march = {id = "elandor_ashenward_march",
			display_name = "Ashenward March", level_min = 31, level_max = 40},
	}
	local function zone_at(x, z)
		if math.abs(x) > 1000 then return nil end
		if z < -2300 then return "elandor_dawnmere_fields" end
		if z < -1800 then return "elandor_goldmead_vale" end
		if z < -1000 then return "elandor_highcourt" end
		return "elandor_ashenward_march"
	end
	local function footprint_at(x, z)
		if math.abs(x) <= 76 and math.abs(z + 2550) <= 76 then return "hard:dawnmere" end
		if x * x + (z + 1500) * (z + 1500) <= 200 * 200 then return "hard:highcourt" end
		return nil
	end
	rawset(_G, "grug_zones", {
		id_at = zone_at,
		get = function(id) return RECORDS[id] end,
		hard_footprint_in = function(min_x, min_z)
			local id = footprint_at(min_x, min_z)
			if id then return id, "town" end
			return nil
		end,
	})
	rawset(_G, "grug_map", {})
	dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
	local M = grug_map.location
	check(M.discovery == nil, "Z location.lua alone installs no discovery")

	local D = dofile(repo .. "/mods/PLAYER/grug_map/zone_discovery.lua")
	check(D.KEY == "grug_map:visited_zones" and D.SOURCE == "discovery" and
		D.WEIGHT == 0.75, "Z key, source and weight")
	-- core.serialize's format for a list of strings, and its reader.
	local function serialize(list)
		local parts = {}
		for i, v in ipairs(list) do parts[i] = ("%q"):format(v) end
		return "return {" .. table.concat(parts, ", ") .. "}"
	end
	local function deserialize(text)
		local fn = loadstring(text)
		if not fn then return nil end
		setfenv(fn, {})
		local ok, value = pcall(fn)
		return ok and value or nil
	end
	local enters = 0
	local api = {
		record = function(id) return grug_zones.get(id) end,
		level = grug_xp.get_level, add_xp = grug_xp.add_xp,
		quest_reward = grug_xp.quest_reward, play = grug_sounds.play,
		read = function(player) return player:get_meta():get_string(D.KEY) end,
		write = function(player, text) player:get_meta():set_string(D.KEY, text) end,
		serialize = serialize, deserialize = deserialize,
	}
	local discovery = D.new(api)
	M.discovery = {start = discovery.start, enter = function(player, zone)
		enters = enters + 1
		return discovery.enter(player, zone)
	end}

	local function new_player(name, pos, xp, stored)
		local store = {["grug_xp:xp"] = xp or 0, [D.KEY] = stored}
		local meta = {
			get_int = function(_, k) return store[k] or 0 end,
			set_int = function(_, k, v) store[k] = v end,
			get_string = function(_, k) return store[k] or "" end,
			set_string = function(_, k, v) store[k] = v end,
		}
		local p = {name = name, pos = pos, store = store, huds = {}, next_id = 0}
		function p:get_meta() return meta end
		function p:get_player_name() return self.name end
		function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
		function p:hud_add(def)
			self.next_id = self.next_id + 1
			local copy = {}
			for k, v in pairs(def) do copy[k] = v end
			self.huds[self.next_id] = copy
			return self.next_id
		end
		function p:hud_change(id, stat, value) self.huds[id][stat] = value end
		online[name] = p
		for _, fn in ipairs(joins) do fn(p) end
		return p
	end
	local function step(seconds)
		local target = now_us + seconds * 1e6
		while now_us < target - 1 do
			now_us = now_us + 50000
			for _, fn in ipairs(steps) do fn(0.05) end
		end
	end
	local function visited(p)
		local set = {}
		for _, id in ipairs(deserialize(p.store[D.KEY] or "") or {}) do set[id] = true end
		return set
	end
	local function banner_of(p)
		for _, def in pairs(p.huds) do
			if def.type == "text" and def.position and def.position.y == 0 and def.size then
				return def
			end
		end
	end

	-- A new character, released in its start town at level 1.
	local ann = new_player("ann", {x = 10, y = 10, z = -2540}, 0)
	step(1.1)
	check(visited(ann).elandor_dawnmere_fields and #fed == 0 and #sounds == 0,
		"Z a new character's start zone is marked silently in its start town")
	-- The banner: shown at the first sample (0.2 s after the join), still up
	-- 3.6 s later, gone after 4 s.
	local banner = banner_of(ann)
	check(banner.text == "Dawnmere", "B the join banner shows the town")
	step(2.7)
	check(banner.text == "Dawnmere", "B still shown 3.6 s after it appeared")
	step(0.5)
	check(banner.text == "", "B hidden 4.1 s after it appeared")
	-- Out of the town into its own zone: already visited, nothing.
	ann.pos = {x = 300, y = 10, z = -2600}
	step(1.1)
	check(#fed == 0 and #sounds == 0, "Z leaving the start town into its zone pays nothing")
	-- Into Goldmead Vale (L11) at level 1: quest_reward(1, 0.75) = 23 XP, the
	-- sound once, no level-up.
	ann.pos = {x = 300, y = 10, z = -2100}
	step(1.1)
	check(#fed == 1 and fed[1] == grug_xp.quest_reward(1, 0.75) and fed[1] == 23,
		"Z first entry: the quarter reward at the character's level (got " ..
		tostring(fed[1]) .. ")")
	check(#sounds == 1 and sounds[1].event == "level_up" and #banners == 0,
		"Z the level-up sound once, without a level-up")
	check(visited(ann).elandor_goldmead_vale, "Z the zone joins the visited set")
	-- Back and forth: nothing more.
	ann.pos = {x = 300, y = 10, z = -2600}
	step(1.1)
	ann.pos = {x = 300, y = 10, z = -2100}
	step(1.1)
	check(#fed == 1 and #sounds == 1, "Z a second entry pays nothing")
	-- Standing still: no discovery call at all.
	local before = enters
	step(5)
	check(enters == before, "Z no discovery call while the zone stays the same")
	-- The open sea and the capital city and its civic zone: nothing.
	ann.pos = {x = 2000, y = 0, z = -2100}
	step(1.1)
	ann.pos = {x = 300, y = 10, z = -1500}
	step(1.1)
	ann.pos = {x = 0, y = 10, z = -1500}
	step(1.1)
	local seen = visited(ann)
	check(#fed == 1 and #sounds == 1 and not seen.elandor_highcourt,
		"Z the open sea, a civic capital zone and the city never count")
	for _, fn in ipairs(leaves) do fn(ann) end
	online.ann = nil

	-- A level-15 character from before Round 47 (no visited set) logs in in
	-- Goldmead Vale: marked silently. Then Ashenward March (L31): the XP at
	-- its own level 15, quest_reward(15, 0.75) = 75.
	local bob = new_player("bob", {x = 300, y = 10, z = -2100},
		grug_xp.xp_for_level(15))
	step(1.1)
	check(visited(bob).elandor_goldmead_vale and #fed == 1 and #sounds == 1,
		"Z an existing character's current zone is marked silently")
	bob.pos = {x = 300, y = 10, z = -500}
	step(1.1)
	check(#fed == 2 and fed[2] == grug_xp.quest_reward(15, 0.75) and fed[2] == 75,
		"Z a high zone pays at the character's level (got " .. tostring(fed[2]) .. ")")
	check(#sounds == 2, "Z ...with one sound")
	-- Dawnmere Fields (L1) at level 15: the zone's level, quest_reward(1, 0.75).
	bob.pos = {x = 300, y = 10, z = -2600}
	step(1.1)
	check(#fed == 3 and fed[3] == grug_xp.quest_reward(1, 0.75),
		"Z a low zone pays at the zone's level (got " .. tostring(fed[3]) .. ")")
	for _, fn in ipairs(leaves) do fn(bob) end
	online.bob = nil

	-- One XP short of level 12: the discovery levels the character up, and
	-- the level-up sound still plays once (grug_xp's own).
	local cid = new_player("cid", {x = 300, y = 10, z = -2600},
		grug_xp.xp_for_level(12) - 1, serialize({"elandor_dawnmere_fields"}))
	step(1.1)
	check(grug_xp.get_level(cid) == 11 and #fed == 3, "Z a stored set is kept at join")
	local plays = #sounds
	cid.pos = {x = 300, y = 10, z = -2100}
	step(1.1)
	check(grug_xp.get_level(cid) == 12 and #banners == 1, "Z the discovery XP levels up")
	check(#sounds - plays == 1 and sounds[#sounds].event == "level_up",
		"Z one level-up sound with a level-up (got " .. (#sounds - plays) .. ")")
	for _, fn in ipairs(leaves) do fn(cid) end
	online.cid = nil

	-- The pure rules.
	check(D.real(RECORDS.elandor_goldmead_vale) and not D.real(RECORDS.elandor_highcourt) and
		not D.real(nil), "Z a real zone: a zone record that is not civic")
	check(D.amount(31, 5, grug_xp.quest_reward) == grug_xp.quest_reward(5, 0.75) and
		D.amount(11, 20, grug_xp.quest_reward) == grug_xp.quest_reward(11, 0.75),
		"Z the amount at both sides of the min")
	local dan = new_player("dan", {x = 300, y = 10, z = -2100}, 0, "")
	check(discovery.enter(dan, "elandor_goldmead_vale") == nil and
		visited(dan).elandor_goldmead_vale and #fed == 4,
		"Z an entry before any sample starts the set silently")
	online.dan = nil
end

print("R47 NZ PORTABLE PASS checks=" .. checks)
