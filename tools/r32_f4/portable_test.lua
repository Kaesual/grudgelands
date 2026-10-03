-- Round 32 Lane F4 portable test (LuaJIT): per-step spreading of the Map
-- tab rebuilds and the party HUD before a multi-player playtest (perf review
-- R1, R2). The camp and leader tick's zone slices (R3) are checked with the
-- real spawner globalstep in tools/r28_s1/portable_test.lua (section
-- "Round 32 F4"), whose harness loads spawn_regions.lua with a recipe zone.
--
--   luajit tools/r32_f4/portable_test.lua [repo]
--
-- Loads the REAL grug_map atlas.lua, providers.lua and page.lua, and the
-- real grug_core/hud_layout.lua and grug_parties/hud.lua, on a fake engine
-- (the stub style of tools/r26_map/portable_test.lua). Checks:
--   M  Map tab poll, 0.1 s passes: twelve walking viewers who opened the tab
--      together are rebuilt at most two per pass, each every 2 s on its own
--      phase; sixty walking viewers (more than the budget) are served
--      longest-waiting first, none starves, at most 8 signature reads and 2
--      builds per pass; a viewer who leaves or changes tab mid-queue is
--      dropped and gets nothing more; still viewers get no sends; a
--      scrollbar move defers the rebuild by 0.5 s;
--   P  party HUD: every player is polled exactly once per 0.5 s in one of
--      five slots; players without a party never build a view; the row
--      layout is recomputed only when a player's window (or the row count)
--      changes; a member's HP change shows within 0.5 s; a player who left
--      the party loses the rows on the next poll; a player who leaves the
--      server is dropped from the slots.
-- Prints "R32 F4 PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

-- ---------------------------------------------------------------------------
-- Fake engine
-- ---------------------------------------------------------------------------
local us = 0
local players, steps, joins, leaves, loaded = {}, {}, {}, {}, {}
local windows = {}
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function() end,
	get_player_by_name = function(name) return players[name] end,
	get_player_window_information = function(name) return windows[name] end,
	get_us_time = function() return us end,
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	registered_entities = {},
})
rawset(_G, "grug_core", {
	settlement_socket_settlements = function() return {} end,
	settlement_sockets_at = function() return {} end,
	zone_authority_installed = function() return false end,
	faction_ids = {"accord", "throng"},
	start_identities = function() return {{race_id = "human", faction_id = "accord"}} end,
	status_icons = {class_icon = function(class) return "icon_" .. tostring(class) .. ".png" end},
})
rawset(_G, "grug_factions", {get_faction = function() return "accord" end,
	register_on_faction_chosen = function() end})
rawset(_G, "grug_jobs", {PROFESSIONS = {}})
rawset(_G, "grug_mobs", {dragon_map_markers = function() return {} end})
rawset(_G, "grug_quests", {registered_npcs = {}, marker_states = function() return {}, 1 end})
rawset(_G, "grug_parties", {view = function() return nil end})
rawset(_G, "grug_home", {get = function() return nil end, locations = function() return {} end,
	known_waypoints = function() return {} end})
rawset(_G, "grug_zones", {at = function() return nil end})
rawset(_G, "grug_inventory", {UI = {width = 10.4, height = 11.1}})
local page
rawset(_G, "sfinv", {register_page = function(_, p) page = p end,
	make_formspec = function(_, _, fs) return fs end, contexts = {},
	set_page = function() end, set_player_inventory_formspec = function() end,
	inventory_suspended = function() return false end})
local minimap_reads = 0
rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	minimap = {available = function() return true end,
		enabled = function() minimap_reads = minimap_reads + 1; return true end}})
grug_map.atlas.set_base_texture("grug_map_base.png")
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
dofile(repo .. "/mods/PLAYER/grug_map/page.lua")
for _, fn in ipairs(loaded) do fn() end
local page_step = steps[#steps]

local sends = {} -- {t, name}
local function new_player(name, x)
	local p = {name = name, pos = {x = x, y = 10, z = -200}, yaw = 0, huds = {}, next_hud = 0,
		hud_changes = 0, offset_changes = 0, removed = 0}
	function p:get_player_name() return self.name end
	function p:get_pos() return self.pos end
	function p:get_look_horizontal() return self.yaw end
	function p:set_inventory_formspec() sends[#sends + 1] = {t = us / 1e6, name = self.name} end
	function p:hud_add(def) self.next_hud = self.next_hud + 1; self.huds[self.next_hud] = def; return self.next_hud end
	function p:hud_change(_, property) self.hud_changes = self.hud_changes + 1
		if property == "offset" then self.offset_changes = self.offset_changes + 1 end end
	function p:hud_remove(id) self.huds[id] = nil; self.removed = self.removed + 1 end
	players[name] = p
	return p
end
local function leave(p)
	for _, fn in ipairs(leaves) do fn(p) end
	players[p.name] = nil
end

-- ---------------------------------------------------------------------------
-- M: the Map tab poll
-- ---------------------------------------------------------------------------
local PAGE = "grug_map:atlas"
local function open(p)
	local context = {page = PAGE}
	sfinv.contexts[p.name] = context
	page.on_enter(page, p, context)
	page.get(page, p, context)
	return context
end
-- One 0.1 s pass; walkers move 5 nodes east (2 s of it are about ten arrow
-- cells at 1x). Returns the pass's sends and signature reads.
local function pass(walkers)
	for _, p in ipairs(walkers) do p.pos.x = p.pos.x + 5 end
	local before_sends, before_reads = #sends, minimap_reads
	us = us + 100000
	page_step(0.1)
	local built = #sends - before_sends
	-- a build reads the switch twice (form and its signature), a check once
	return built, minimap_reads - before_reads - 2 * built
end
local function gaps_of(name, from)
	local times = {}
	for _, row in ipairs(sends) do
		if row.name == name and row.t >= from then times[#times + 1] = row.t end
	end
	local least, most = math.huge, 0
	for i = 2, #times do
		least = math.min(least, times[i] - times[i - 1])
		most = math.max(most, times[i] - times[i - 1])
	end
	return times, least, most
end

-- M1: twelve viewers open the tab in the same step and keep walking.
do
	local list = {}
	for i = 1, 12 do list[i] = new_player(("m%02d"):format(i), -2000 + i * 20) end
	for _, p in ipairs(list) do open(p) end
	local start, most_built, most_reads = us / 1e6, 0, 0
	local passes_with_builds = {}
	for k = 1, 300 do
		local built, reads = pass(list)
		most_built, most_reads = math.max(most_built, built), math.max(most_reads, reads)
		if built > 0 and k > 20 and k <= 40 then passes_with_builds[#passes_with_builds + 1] = k end
	end
	check(most_built <= 2, "M1 at most two builds per pass (" .. most_built .. ")")
	check(most_reads <= 8, "M1 at most eight signature reads per pass (" .. most_reads .. ")")
	check(#passes_with_builds >= 6, "M1 the twelve rebuilds spread over at least six passes of 2 s (" ..
		#passes_with_builds .. ")")
	local fair = true
	for _, p in ipairs(list) do
		local times, least, most = gaps_of(p.name, start)
		fair = fair and #times >= 13 and times[1] - start <= 2.65 and
			least >= 2 - 1e-6 and most <= 2.1 + 1e-6
		if not fair then
			check(false, ("M1 %s: %d sends, first %.2f s, gaps %.2f..%.2f s"):format(p.name,
				#times, (times[1] or 0) - start, least, most))
			break
		end
	end
	check(fair, "M1 every viewer is rebuilt every 2 s (never sooner), the first within 2.6 s")
	for _, p in ipairs(list) do leave(p) end
	local before = #sends
	for _ = 1, 30 do pass(list) end
	check(#sends == before, "M1 viewers who left get nothing more")
end

-- M2: sixty walking viewers, more than two builds per pass can serve every
-- 2 s; one leaves and one changes tab while waiting in the queue.
do
	sends = {}
	local list = {}
	for i = 1, 60 do list[i] = new_player(("n%02d"):format(i), -3000 + i * 10) end
	for _, p in ipairs(list) do open(p) end
	local start, most_built, most_reads = us / 1e6, 0, 0
	for _ = 1, 200 do
		local built, reads = pass(list)
		most_built, most_reads = math.max(most_built, built), math.max(most_reads, reads)
	end
	local leaver, switcher = list[17], list[40]
	local cut = us / 1e6
	leave(leaver)
	sfinv.contexts[switcher.name].page = "grug_inventory:character"
	for _ = 1, 300 do
		local built, reads = pass(list)
		most_built, most_reads = math.max(most_built, built), math.max(most_reads, reads)
	end
	check(most_built <= 2 and most_reads <= 8, ("M2 the pass budget holds under load (%d builds, %d reads)")
		:format(most_built, most_reads))
	local worst, served = 0, true
	for _, p in ipairs(list) do
		if p ~= leaver and p ~= switcher then
			local times, _, most = gaps_of(p.name, start)
			served = served and #times >= 12 and times[1] - start <= 5
			worst = math.max(worst, most)
		end
	end
	check(served and worst <= 3.5, ("M2 nobody starves: every viewer is served, at most %.2f s apart")
		:format(worst))
	local after = 0
	for _, row in ipairs(sends) do
		if (row.name == leaver.name or row.name == switcher.name) and row.t > cut then after = after + 1 end
	end
	check(after == 0, "M2 a viewer who leaves or changes tab mid-queue is dropped (" .. after .. " sends)")
	for _, p in ipairs(list) do if players[p.name] then leave(p) end end
end

-- M3: still viewers are read, never rebuilt; a scrollbar move defers.
do
	sends = {}
	local list = {}
	for i = 1, 30 do list[i] = new_player(("s%02d"):format(i), -1450 + i * 90) end
	for _, p in ipairs(list) do open(p) end
	local most_reads, reads_total = 0, 0
	for _ = 1, 100 do
		local _, reads = pass({})
		most_reads = math.max(most_reads, reads)
		reads_total = reads_total + reads
	end
	check(#sends == 0, "M3 still viewers get no sends")
	check(most_reads <= 8 and reads_total >= 30 * 4, ("M3 every still viewer is read every 2 s " ..
		"(%d reads in 10 s, at most %d per pass)"):format(reads_total, most_reads))
	local p = list[1]
	for _ = 1, 25 do pass({}) end
	local context = sfinv.contexts[p.name]
	page.on_player_receive_fields(page, p, context, {grug_map_scroll_x = "CHG:40"})
	local moved = us / 1e6
	p.pos.x = p.pos.x + 400
	for _ = 1, 30 do pass({}) end
	local times = gaps_of(p.name, moved)
	check(times[1] and times[1] - moved >= 0.5 - 1e-6 and times[1] - moved <= 2.1 + 1e-6,
		("M3 a scrollbar move defers the rebuild by 0.5 s (sent after %.2f s)"):format(
			(times[1] or moved) - moved))
	for _, q in ipairs(list) do leave(q) end
end

-- ---------------------------------------------------------------------------
-- P: the party HUD
-- ---------------------------------------------------------------------------
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
local layout = grug_core.hud_layout
local layout_calls = 0
for _, key in ipairs({"party_row_offset", "party_icon_size", "side_text_width"}) do
	local real = layout[key]
	layout[key] = function(...) layout_calls = layout_calls + 1; return real(...) end
end
local membership, groups, views, member_reads, on_change = {}, {}, {}, {}, nil
grug_parties.view = function(player)
	local name = player:get_player_name()
	views[name] = (views[name] or 0) + 1
	local group = groups[membership[name]]
	if not group then return nil end
	local out = {leader = group[1], members = {}}
	for _, member in ipairs(group) do
		local other = players[member]
		out.members[#out.members + 1] = {name = member, online = other ~= nil, level = 5,
			hp = other and other.hp or 0, hp_max = 20, class = "mage"}
	end
	return out
end
grug_parties.in_party = function(player)
	local name = type(player) == "string" and player or player:get_player_name()
	member_reads[name] = (member_reads[name] or 0) + 1
	return membership[name] ~= nil
end
grug_parties.hud_enabled = function() return true end
grug_parties.health_color_mode = function() return "by_class" end
grug_parties.register_on_change = function(fn) on_change = fn end
local before_steps = #steps
dofile(repo .. "/mods/PLAYER/grug_parties/hud.lua")
check(#steps == before_steps + 1 and on_change, "P hud.lua registers one globalstep and a change callback")
local hud_step = steps[#steps]
local function hud_pass() us = us + 100000; hud_step(0.1) end

local party_players, solo = {}, {}
groups = {a = {}, b = {}}
for i = 1, 23 do
	local p = new_player(("p%02d"):format(i), i * 10)
	p.hp = 20
	windows[p.name] = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	-- members of two parties of five, interleaved with players alone
	if i % 2 == 0 and i <= 20 then
		local id = i <= 10 and "a" or "b"
		membership[p.name] = id
		groups[id][#groups[id] + 1] = p.name
		party_players[#party_players + 1] = p
	else
		solo[#solo + 1] = p
	end
end
for i = 1, 23 do
	local p = players[("p%02d"):format(i)]
	for _, fn in ipairs(joins) do fn(p) end
end
-- After every join the rows stand at their final count.
for _, p in ipairs(party_players) do on_change(p.name) end

-- P1: one poll per player per 0.5 s, in five slots; nobody alone builds a view.
do
	views, member_reads, layout_calls = {}, {}, 0
	local per_pass = {}
	for k = 1, 20 do
		local before = 0
		for _, n in pairs(member_reads) do before = before + n end
		hud_pass()
		local after = 0
		for _, n in pairs(member_reads) do after = after + n end
		per_pass[k] = after - before
	end
	local once = true
	for _, p in ipairs(party_players) do once = once and views[p.name] == 4 end
	for _, p in ipairs(solo) do once = once and views[p.name] == nil and member_reads[p.name] == 4 end
	check(once, "P1 every player is polled once per 0.5 s; players alone never build a view")
	local most = 0
	for _, n in ipairs(per_pass) do most = math.max(most, n) end
	check(most <= 5, "P1 at most five of 23 players per pass (" .. most .. ")")
	check(layout_calls == 0, "P1 no layout work while no window changes (" .. layout_calls .. ")")
end

-- P2: a window change relayouts that player only; HP shows within 0.5 s.
do
	local p = party_players[1]
	p.offset_changes, layout_calls = 0, 0
	windows[p.name] = {size = {x = 1280, y = 720}, real_hud_scaling = 1, real_gui_scaling = 1.5}
	for _ = 1, 5 do hud_pass() end
	check(layout_calls > 0 and p.offset_changes > 0, "P2 a window change moves that player's rows")
	local calls = layout_calls
	for _ = 1, 10 do hud_pass() end
	check(layout_calls == calls, "P2 ...once: the next polls leave the layout alone")
	local mate = party_players[2]
	p.hp = 7
	local changes = mate.hud_changes
	for _ = 1, 5 do hud_pass() end
	check(mate.hud_changes > changes, "P2 a member's HP change shows on a mate's HUD within 0.5 s")
end

-- P3: leaving the party drops the rows on the next poll; leaving the server
-- drops the player from the slots.
do
	local p = party_players[3]
	local rows = 0
	for _ in pairs(p.huds) do rows = rows + 1 end
	membership[p.name] = nil
	for _ = 1, 5 do hud_pass() end
	local left = 0
	for _ in pairs(p.huds) do left = left + 1 end
	check(rows == 20 and left == 0, ("P3 a player who left the party loses the rows (%d -> %d HUDs)")
		:format(rows, left))
	views[p.name] = 0
	for _ = 1, 10 do hud_pass() end
	check(views[p.name] == 0, "P3 ...and builds no view after that")
	local gone = party_players[4]
	leave(gone)
	views[gone.name] = 0
	local ok = pcall(function() for _ = 1, 10 do hud_pass() end end)
	check(ok and views[gone.name] == 0, "P3 a player who left the server is not polled")
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R32 F4 PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print(("R32 F4 PORTABLE PASS checks=%d"):format(checks))
