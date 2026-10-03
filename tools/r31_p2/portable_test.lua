-- Round 31 Lane P2 portable test (LuaJIT): the PvP UI (pvp-plan.md lane P2).
--
--   luajit tools/r31_p2/portable_test.lua [repo]
--
-- Loads the REAL grug_pvp view.lua, page.lua and hud.lua, grug_core
-- status_icons.lua and hud_layout.lua, grug_map location_view.lua and
-- location.lua and grug_mobs target_frame.lua on fake engines, with a
-- settable grug_pvp state in place of lane P1's. Checks:
--   V  state -> text: safe, both territories, button and contact countdowns,
--      a flag without seconds, the PvP combat line; the stats rows in ruling
--      16 order (missing counters read 0); the page key follows every
--      printed change and nothing else;
--   S  state -> status icon (the status source): nothing while safe, the
--      untimed contested icon with its territory label, the tagged icon with
--      the countdown caption for button and contact, no icon for a timer at
--      0; labels and details fit the Effects tab's clip widths;
--   P  the PvP tab: button, headline, detail, combat line and all seven
--      counters; every element above the shared inventory (y 7.0) and
--      inside the page width; the button flags and re-sends; the 1 s poll
--      re-sends only while the open tab's text changes; another page gets
--      nothing; nav order: right after Group for every order of the other
--      tabs' hooks (ours runs after Group's, it loads after grug_parties);
--   B  the banner subtitle: pure debounce rules (entry with the name, the
--      subtitle joining a running display, taken off, entry below y -700
--      inside one zone, silent loss) and the runtime (subtitle element,
--      shown and hidden with the banner, no extra zone query per sample, a
--      flag change sampling on the next step, HUD writes only on change);
--      layout: subtitle under the banner, flight warning under the
--      subtitle and above the level-up banner;
--   T  target frame: own faction green without a marker, an enemy without
--      grug_pvp unchanged, "(protected)" gray, "(flagged)" gray while the
--      viewer is unflagged, "(flagged)" red when both are flagged.
-- Prints "R31 P2 PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
function table.indexof(list, value)
	for i, v in ipairs(list) do if v == value then return i end end
	return -1
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

-- ---------------------------------------------------------------------------
-- V: view.lua
-- ---------------------------------------------------------------------------
local V = dofile(repo .. "/mods/PLAYER/grug_pvp/view.lua")
do
	local safe = V.state_lines({flagged = false})
	eq(safe.headline, "Safe", "V safe headline")
	eq(safe.color, V.COLOR_SAFE, "V safe is green")
	eq(safe.combat, nil, "V no combat line out of PvP combat")
	local contested = V.state_lines({flagged = true, reason = "location_contested"})
	eq(contested.headline, "Flagged: Contested Territory", "V contested headline")
	eq(contested.color, V.COLOR_FLAGGED, "V flagged is red")
	eq(V.state_lines({flagged = true, reason = "location_enemy", seconds_left = 30}).headline,
		"Flagged: Enemy Territory", "V enemy territory headline ignores timers")
	local button = V.state_lines({flagged = true, reason = "button", seconds_left = 42})
	eq(button.headline, "Flagged for 42 s", "V button countdown")
	check(button.detail:find("Flag me for PvP", 1, true) ~= nil, "V button reason line")
	local contact = V.state_lines({flagged = true, reason = "contact", seconds_left = 7.2,
		pvp_combat = true})
	eq(contact.headline, "Flagged for 8 s", "V contact countdown rounds up")
	check(contact.detail:find("PvP contact", 1, true) ~= nil, "V contact reason line")
	eq(contact.combat, V.COMBAT, "V PvP combat line")
	eq(V.state_lines({flagged = true, reason = "button"}).headline, "Flagged",
		"V a flag without seconds")
	eq(V.state_lines(nil).headline, "Safe", "V no state reads safe")

	local rows = V.stats_rows({kills = 3, killing_blows = 1, deaths = 2, kings = 1,
		guards = -4})
	eq(#rows, 7, "V seven counters")
	local expected = {{"Player kills", 3}, {"Killing blows", 1}, {"Deaths to players", 2},
		{"Enemy guards killed", 0}, {"Enemy captains killed", 0},
		{"Enemy generals killed", 0}, {"Enemy kings killed", 1}}
	for index, row in ipairs(expected) do
		eq(rows[index][1], row[1], "V counter " .. index .. " label")
		eq(rows[index][2], row[2], "V counter " .. index .. " value")
	end

	local stats = {kills = 1}
	local a = V.page_key({flagged = true, reason = "button", seconds_left = 10}, stats)
	eq(V.page_key({flagged = true, reason = "button", seconds_left = 10}, stats), a,
		"V the same state gives the same key")
	check(V.page_key({flagged = true, reason = "button", seconds_left = 9}, stats) ~= a,
		"V a countdown second changes the key")
	check(V.page_key({flagged = true, reason = "button", seconds_left = 10}, {kills = 2}) ~= a,
		"V a counter changes the key")
	check(V.page_key({flagged = true, reason = "button", seconds_left = 10,
		pvp_combat = true}, stats) ~= a, "V PvP combat changes the key")
	eq(V.page_key({flagged = true, reason = "location_contested", seconds_left = 10}, stats),
		V.page_key({flagged = true, reason = "location_contested", seconds_left = 9}, stats),
		"V a location flag's key ignores timers it does not print")
end

-- A settable grug_pvp in place of lane P1's.
local pvp_state, pvp_stats, pvp_calls = {}, {}, {state = 0, flag_now = 0}
local change_callbacks = {}
local function fake_pvp()
	return {
		state = function(player)
			pvp_calls.state = pvp_calls.state + 1
			local s = pvp_state[player:get_player_name()] or {}
			return {flagged = s.flagged == true, reason = s.reason,
				seconds_left = s.seconds_left, pvp_combat = s.pvp_combat == true}
		end,
		stats = function(player)
			local copy = {}
			for k, v in pairs(pvp_stats[player:get_player_name()] or {}) do copy[k] = v end
			return copy
		end,
		flagged = function(player)
			local s = pvp_state[player:get_player_name()]
			return s ~= nil and s.flagged == true
		end,
		can_harm = function(a, b)
			local sa, sb = pvp_state[a:get_player_name()], pvp_state[b:get_player_name()]
			return sa ~= nil and sa.flagged == true and sb ~= nil and sb.flagged == true
		end,
		flag_now = function(player)
			pvp_calls.flag_now = pvp_calls.flag_now + 1
			pvp_state[player:get_player_name()] = {flagged = true, reason = "button",
				seconds_left = 60}
			for _, fn in ipairs(change_callbacks) do fn(player, {}) end
		end,
		register_on_change = function(fn) change_callbacks[#change_callbacks + 1] = fn end,
	}
end
local function fake_player(name, extra)
	local p = {name = name, huds = {}, next_id = 0, sent = 0, pos = {x = 0, y = 0, z = 0}}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_hp() return 20 end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		self.sent = self.sent + 1
		return self.next_id
	end
	function p:hud_change(id, stat, value)
		assert(self.huds[id], "hud_change on a removed element")
		self.huds[id][stat] = value
		self.sent = self.sent + 1
	end
	for k, v in pairs(extra or {}) do p[k] = v end
	return p
end

-- ---------------------------------------------------------------------------
-- S: hud.lua, the status source
-- ---------------------------------------------------------------------------
do
	local sources = {}
	rawset(_G, "core", {
		get_current_modname = function() return "grug_pvp" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_pvp" end,
	})
	rawset(_G, "grug_core", {register_status_source = function(fn)
		sources[#sources + 1] = fn
		return true
	end})
	dofile(repo .. "/mods/CORE/grug_core/status_icons.lua")
	rawset(_G, "grug_pvp", fake_pvp())
	dofile(repo .. "/mods/PLAYER/grug_pvp/hud.lua")
	eq(#sources, 1, "S one status source")
	local icons = grug_core.status_icons
	local source = sources[1]
	local alice = fake_player("alice")
	local NOW = 5e9
	pvp_state.alice = nil
	eq(source(alice, NOW), nil, "S safe: no icon")
	pvp_state.alice = {flagged = true, reason = "location_contested"}
	local e = source(alice, NOW)
	check(e and #e == 1 and e[1].id == "pvp_contested" and e[1].untimed == true,
		"S contested: one untimed contested icon")
	eq(e and e[1].label, "Contested Territory", "S contested label")
	pvp_state.alice = {flagged = true, reason = "location_enemy", seconds_left = 40}
	e = source(alice, NOW)
	check(e and e[1].id == "pvp_contested" and e[1].untimed and
		e[1].label == "Enemy Territory", "S enemy territory: contested icon, own label")
	pvp_state.alice = {flagged = true, reason = "button", seconds_left = 42}
	e = source(alice, NOW)
	check(e and #e == 1 and e[1].id == "pvp_tagged" and not e[1].untimed and
		e[1].expiry_us == NOW + 42e6, "S button: tagged icon expiring with the flag")
	eq(icons.caption(nil, false, e[1].expiry_us - NOW), "42s", "S button countdown caption")
	pvp_state.alice = {flagged = true, reason = "contact", seconds_left = 75}
	e = source(alice, NOW)
	check(e and e[1].id == "pvp_tagged", "S contact: tagged icon")
	eq(icons.caption(nil, false, e[1].expiry_us - NOW), "1:15", "S contact caption")
	check(e[1].detail:find("PvP fight", 1, true) ~= nil, "S contact detail")
	pvp_state.alice = {flagged = true, reason = "button", seconds_left = 0}
	eq(source(alice, NOW), nil, "S a timer at 0: no icon")
	pvp_state.alice = {flagged = false, reason = "button", seconds_left = 9}
	eq(source(alice, NOW), nil, "S unflagged: no icon whatever the rest says")
	for id, reason in pairs(V.REASONS) do
		check(#reason.label <= 28 and #reason.effect <= 34,
			"S " .. id .. " fits the Effects tab (28/34 characters)")
	end
	check(icons.kind_of("pvp_tagged") == "neutral" and icons.kind_of("pvp_contested") ==
		"neutral", "S both PvP icons are neutral (gold)")
	pvp_state.alice = nil
end

-- ---------------------------------------------------------------------------
-- P: page.lua, the PvP tab
-- ---------------------------------------------------------------------------
do
	local steps, loaded, pages, sends = {}, {}, {}, {}
	local players = {}
	change_callbacks = {}
	rawset(_G, "core", {
		get_current_modname = function() return "grug_pvp" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_pvp" end,
		formspec_escape = function(text)
			return (text:gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]")
				:gsub(";", "\\;"):gsub(",", "\\,"))
		end,
		colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		get_connected_players = function()
			local list = {}
			for _, p in pairs(players) do list[#list + 1] = p end
			return list
		end,
	})
	rawset(_G, "sfinv", {
		pages = {}, pages_unordered = {}, contexts = {},
		register_page = function(name, def)
			def.name = name
			sfinv.pages[name] = def
			sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def
			pages[#pages + 1] = name
		end,
		make_formspec = function(_, _, content, show_inv)
			return (show_inv and "INV|" or "") .. content
		end,
		set_player_inventory_formspec = function(player, context)
			sends[#sends + 1] = player:get_player_name()
			context.last_form = sfinv.pages[context.page]:get(player, context)
		end,
	})
	rawset(_G, "grug_pvp", fake_pvp())
	dofile(repo .. "/mods/PLAYER/grug_pvp/page.lua")
	local def = sfinv.pages["grug_pvp:pvp"]
	check(def and def.title == "PvP", "P the PvP page is registered")
	eq(#change_callbacks, 1, "P the page follows grug_pvp changes")

	local bob = fake_player("bob")
	players.bob = bob
	local context = {page = "grug_pvp:pvp"}
	sfinv.contexts.bob = context
	pvp_state.bob = {flagged = true, reason = "contact", seconds_left = 12, pvp_combat = true}
	pvp_stats.bob = {kills = 4, killing_blows = 2, deaths = 1, guards = 9, captains = 1,
		generals = 0, kings = 1}
	local form = def:get(bob, context)
	check(form:sub(1, 4) == "INV|", "P the page carries the shared inventory")
	check(form:find("button[0.2,2.05;3.6,0.8;grug_pvp_flag;Flag me for PvP]", 1, true) ~= nil,
		"P the Flag me for PvP button")
	check(form:find("Flagged for 12 s", 1, true) ~= nil, "P the headline with seconds")
	check(form:find("PvP contact", 1, true) ~= nil, "P the reason line")
	check(form:find("In PvP combat", 1, true) ~= nil, "P the PvP combat line")
	for _, row in ipairs(V.stats_rows(pvp_stats.bob)) do
		check(form:find(row[1], 1, true) ~= nil, "P counter " .. row[1])
	end
	check(form:find("label%[[%d.]+,[%d.]+;9%]") ~= nil, "P a counter value")
	check(not form:find("rank", 1, true) and not form:find("title", 1, true),
		"P statistics only: no rank or titles")
	-- Geometry: every element above y 7.0 and inside the 10.4 width, at about
	-- six characters per legacy unit for a label (a generous estimate).
	local inside = true
	for kind, args in form:gmatch("(%a+)%[([^%]]*)%]") do
		local x, y, rest = args:match("^([%d.]+),([%d.]+);(.*)$")
		x, y = tonumber(x), tonumber(y)
		if kind == "label" and x then
			local text = rest:gsub("\27%(c@#%x+%)", "")
			if y > 6.5 or x + #text / 6 > 10.2 then
				inside = false
				print("outside: " .. args)
			end
		elseif kind == "button" and x then
			local w, h = rest:match("^([%d.]+),([%d.]+);")
			if y + tonumber(h) > 7.0 or x + tonumber(w) > 10.4 then inside = false end
		end
	end
	check(inside, "P every element fits above the inventory and inside the page")
	-- Stats labels do not run into their values.
	local longest = 0
	for _, row in ipairs(V.STATS) do longest = math.max(longest, #row[2]) end
	check(longest / 6 < 3.6, "P counter labels end before their values")

	-- The button.
	sends = {}
	pvp_state.bob = {flagged = false}
	context.grug_pvp_key = V.page_key(pvp_state.bob, pvp_stats.bob)
	local handled = def:on_player_receive_fields(bob, context, {grug_pvp_flag = "Flag me for PvP"})
	check(handled == true and pvp_calls.flag_now == 1, "P the button flags the player")
	eq(#sends, 1, "P the button re-sends the page once")
	check(context.last_form and context.last_form:find("Flagged for 60 s", 1, true) ~= nil,
		"P the re-sent page shows the new flag")
	-- The poll: once a second, only while the text changes.
	local function step(seconds)
		local t = 0
		while t < seconds - 1e-9 do
			t = t + 0.1
			for _, fn in ipairs(steps) do fn(0.1) end
		end
	end
	sends = {}
	step(3)
	eq(#sends, 0, "P an unchanged open tab is not re-sent")
	pvp_state.bob.seconds_left = 59
	step(1)
	eq(#sends, 1, "P a countdown second re-sends once")
	pvp_stats.bob.kills = 5
	step(1)
	eq(#sends, 2, "P a new counter value re-sends")
	context.page = "grug_inventory:character"
	pvp_state.bob.seconds_left = 30
	local calls = pvp_calls.state
	step(3)
	eq(#sends, 2, "P another page gets nothing")
	eq(pvp_calls.state, calls, "P another page asks grug_pvp nothing")
	change_callbacks[1](bob, {})
	eq(#sends, 2, "P a change on another page re-sends nothing")
	context.page = "grug_pvp:pvp"
	change_callbacks[1](bob, {})
	eq(#sends, 3, "P a change on the open tab re-sends at once")
	pvp_state.bob, pvp_stats.bob, players.bob = nil, nil, nil

	-- Nav order: grug_inventory's order, then the other tabs' hooks (each moves
	-- its page right after its predecessor) in every order, ours last (it
	-- loads after grug_parties); the start lists both load positions of Skills
	-- seen in practice. PvP must follow Group directly.
	local reorder = loaded[1]
	local function move_after(name, after)
		return function()
			local page, ordered, inserted = sfinv.pages[name], {}, false
			for _, d in ipairs(sfinv.pages_unordered) do
				if d ~= page then ordered[#ordered + 1] = d end
				if d.name == after then ordered[#ordered + 1] = page; inserted = true end
			end
			if not inserted then ordered[#ordered + 1] = page end
			sfinv.pages_unordered = ordered
		end
	end
	local others = {move_after("grug_classes:talents", "grug_inventory:bags"),
		move_after("grug_skills:skills", "grug_classes:talents"),
		move_after("grug_quests:quests", "grug_skills:skills"),
		move_after("grug_parties:group", "grug_quests:quests")}
	local starts = {
		{"grug_inventory:character", "grug_inventory:bags", "grug_inventory:help",
			"sfinv:crafting", "grug_classes:talents", "grug_skills:skills",
			"grug_quests:quests", "grug_parties:group", "grug_pvp:pvp", "grug_map:atlas"},
		{"grug_inventory:character", "grug_inventory:bags", "grug_inventory:help",
			"sfinv:crafting", "grug_classes:talents", "grug_quests:quests",
			"grug_parties:group", "grug_map:atlas", "grug_pvp:pvp", "grug_skills:skills"},
	}
	local function permutations(list)
		if #list <= 1 then return {list} end
		local out = {}
		for i = 1, #list do
			local rest = {}
			for j = 1, #list do if j ~= i then rest[#rest + 1] = list[j] end end
			for _, tail in ipairs(permutations(rest)) do
				local p = {list[i]}
				for _, item in ipairs(tail) do p[#p + 1] = item end
				out[#out + 1] = p
			end
		end
		return out
	end
	local all_ok, runs = true, 0
	for _, start in ipairs(starts) do
		for _, hooks in ipairs(permutations(others)) do
			for _, name in ipairs(start) do
				sfinv.pages[name] = sfinv.pages[name] or {name = name}
			end
			sfinv.pages_unordered = {}
			for _, name in ipairs(start) do
				sfinv.pages_unordered[#sfinv.pages_unordered + 1] = sfinv.pages[name]
			end
			for _, fn in ipairs(hooks) do fn() end
			reorder()
			runs = runs + 1
			local names = {}
			for index, d in ipairs(sfinv.pages_unordered) do names[index] = d.name end
			local at = table.indexof(names, "grug_parties:group")
			if names[at + 1] ~= "grug_pvp:pvp" or #names ~= #start then
				all_ok = false
				print("nav order: " .. table.concat(names, " "))
			end
		end
	end
	eq(runs, 48, "P nav: every hook order on both load orders")
	check(all_ok, "P PvP follows Group for every hook order")
end

-- ---------------------------------------------------------------------------
-- B: the banner subtitle
-- ---------------------------------------------------------------------------
local L = dofile(repo .. "/mods/PLAYER/grug_map/location_view.lua")
do
	local C = L.subtitle("location_contested")
	local E = L.subtitle("location_enemy")
	eq(C, "Contested Territory — PvP enabled", "B contested subtitle")
	eq(E, "Enemy Territory — PvP enabled", "B enemy subtitle")
	check(L.subtitle("button") == nil and L.subtitle("contact") == nil and
		L.subtitle(nil) == nil, "B no subtitle for the button, contact or safe")

	-- Entering a contested zone with the flag already set: name and subtitle.
	local s = L.new_state()
	eq(L.sample(s, "Home", 0), "Home", "B join shows the name")
	eq(L.expire(s, "Home", 1.5), false, "B and hides")
	eq(L.sample(s, "Front", 2, C), "Front", "B a flagging zone shows its name")
	eq(s.sub, C, "B with the subtitle")
	-- The flag arrives a moment after the name: it joins the running display
	-- and restarts it.
	s = L.new_state()
	L.sample(s, "Home", 0)
	L.expire(s, "Home", 1.5)
	eq(L.sample(s, "Front", 2), "Front", "B the name first")
	eq(L.sample(s, "Front", 3, C), "Front", "B the subtitle joins the running display")
	eq(s.busy_until, 3 + L.DISPLAY, "B and restarts it")
	eq(L.sample(s, "Front", 4, C), nil, "B nothing new while unchanged")
	eq(L.expire(s, "Front", 4.5, C), false, "B then hides")
	-- Leaving: a new name without the subtitle; a stale subtitle on it is
	-- taken off at the next sample.
	eq(L.sample(s, "Home", 6, C), "Home", "B back home (flag still stale)")
	eq(L.sample(s, "Home", 7), "Home", "B the stale subtitle is taken off")
	eq(s.sub, nil, "B no subtitle")
	eq(s.busy_until, 6 + L.DISPLAY, "B taking it off does not restart the display")
	eq(L.expire(s, "Home", 7.5), false, "B hides")
	-- Below y -700 inside one zone: the subtitle alone is an entry.
	eq(L.sample(s, "Home", 10, C), "Home", "B entering a flagging area without a new name")
	eq(L.expire(s, "Home", 11.5, C), false, "B hides after its display")
	-- Losing it outside a display shows nothing; the next entry shows again.
	eq(L.sample(s, "Home", 12), nil, "B losing the flag outside a display shows nothing")
	eq(L.sample(s, "Home", 13, C), "Home", "B the next entry shows again")
	L.expire(s, "Home", 14.5, C)
	-- Contested to enemy ground: the subtitle changes with the name.
	eq(L.sample(s, "Enemy Capital", 15, E), "Enemy Capital", "B into enemy territory")
	eq(s.sub, E, "B the enemy subtitle")
	-- Entering during the end of a display: expire shows it.
	s = L.new_state()
	L.sample(s, "Front", 0)
	eq(L.expire(s, "Front", 1.5, C), "Front", "B a flag arriving at the display's end shows")
	-- Old callers (no subtitle) behave as before.
	s = L.new_state()
	eq(L.sample(s, "A", 0), "A", "B no subtitle: A")
	eq(L.sample(s, "B", 1), nil, "B no subtitle: busy")
	eq(L.expire(s, "B", 1.5), "B", "B no subtitle: B after the display")
end

do
	local now_us = 0
	local joins, leaves, steps, loaded = {}, {}, {}, {}
	local players = {}
	rawset(_G, "core", {
		get_current_modname = function() return "grug_map" end,
		get_modpath = function() return repo .. "/mods/PLAYER/grug_map" end,
		get_us_time = function() return now_us end,
		get_worldpath = function() return "/nonexistent/grug_r31_p2_world" end,
		safe_file_write = function() return false end,
		log = function() end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		get_connected_players = function()
			local list = {}
			for _, p in pairs(players) do list[#list + 1] = p end
			return list
		end,
		get_player_by_name = function(name) return players[name] end,
		get_player_window_information = function() return nil end,
	})
	rawset(_G, "grug_core", {
		FEED_COLOR = {notice = 0xf0e6c8},
		zone_authority_installed = function() return true end,
		settlement_socket_settlements = function() return {} end,
	})
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	local zone_queries = 0
	rawset(_G, "grug_zones", {
		id_at = function(_, z)
			zone_queries = zone_queries + 1
			return z < 0 and "home" or "front"
		end,
		get = function(id) return {id = id, numeric_id = 1,
			display_name = id == "home" and "Home Vale" or "The Front"} end,
		water_class_at = function() return "deep_ocean" end,
		hard_footprint_in = function() return nil end,
	})
	rawset(_G, "grug_home", {locations = function() return {} end})
	rawset(_G, "grug_map", {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")})
	grug_map.page_layout = {map_w = 12.37, region_labels = {}}
	grug_map.static_marker_positions = function() return {} end
	change_callbacks = {}
	rawset(_G, "grug_pvp", nil)
	dofile(repo .. "/mods/PLAYER/grug_map/location.lua")
	-- grug_pvp exists by the time the mods-loaded hooks run.
	rawset(_G, "grug_pvp", fake_pvp())
	for _, fn in ipairs(loaded) do fn() end
	eq(#change_callbacks, 1, "B the banner follows grug_pvp changes")

	local function step(seconds)
		local target = now_us + seconds * 1e6
		while now_us < target - 1 do
			now_us = now_us + 50000
			for _, fn in ipairs(steps) do fn(0.05) end
		end
	end
	local p = fake_player("cara", {pos = {x = 0, y = 10, z = -100}})
	players.cara = p
	for _, fn in ipairs(joins) do fn(p) end
	local banner, subtitle
	for id, def in pairs(p.huds) do
		if def.type == "text" and def.position and def.position.y == 0 then
			if def.size then banner = id else subtitle = id end
		end
	end
	check(banner and subtitle, "B banner and subtitle elements on join")
	local layout = grug_core.hud_layout
	check(subtitle and p.huds[subtitle].offset.y == layout.zone_subtitle_offset(nil).y and
		p.huds[subtitle].number == 0xff5555, "B subtitle at its anchor, in red")
	step(1.0)
	eq(p.huds[banner].text, "Home Vale", "B join shows the name")
	eq(p.huds[subtitle].text, "", "B safe: no subtitle")
	step(1.6)
	eq(p.huds[banner].text, "", "B hidden")
	-- Walk into the front; the flag follows a moment later (lane P1's tick).
	local queries_before, samples_before = zone_queries, grug_map.location.stats.samples
	p.pos = {x = 0, y = 10, z = 100}
	local waited = 0
	while p.huds[banner].text ~= "The Front" and waited < 2 do
		step(0.05)
		waited = waited + 0.05
	end
	eq(p.huds[banner].text, "The Front", "B the front's name")
	eq(p.huds[subtitle].text, "", "B before the flag: no subtitle yet")
	step(1.0)
	pvp_state.cara = {flagged = true, reason = "location_contested"}
	local sent = p.sent
	change_callbacks[1](p, {})
	step(0.1)
	eq(p.huds[subtitle].text, "Contested Territory — PvP enabled",
		"B the flag change shows the subtitle on the next step")
	eq(p.huds[banner].text, "The Front", "B under the same name")
	eq(p.sent - sent, 1, "B only the subtitle is written")
	step(1.0)
	eq(p.huds[banner].text, "The Front", "B the display was restarted")
	step(1.0)
	check(p.huds[banner].text == "" and p.huds[subtitle].text == "",
		"B name and subtitle hide together")
	-- Zone queries: one per sample, with or without grug_pvp.
	eq(zone_queries - queries_before, grug_map.location.stats.samples - samples_before,
		"B no zone query beyond one per sample")
	sent = p.sent
	step(5)
	eq(p.sent, sent, "B a flagged player standing still sends nothing")
	-- Back home; the flag clears a moment later: the subtitle comes off.
	p.pos = {x = 0, y = 10, z = -100}
	step(1.0)
	eq(p.huds[banner].text, "Home Vale", "B back home")
	pvp_state.cara = nil
	change_callbacks[1](p, {})
	step(0.1)
	eq(p.huds[subtitle].text, "", "B the cleared flag takes the subtitle off")
	step(2)
	eq(p.huds[banner].text, "", "B hidden again")
	for _, fn in ipairs(leaves) do fn(p) end
	players.cara = nil
	change_callbacks[1](p, {}) -- a change after leave touches nothing
	pvp_state.cara = nil

	-- Layout: subtitle under the banner, the flight warning under the
	-- subtitle and above the level-up banner (0.25 H, size 2).
	for _, w in ipairs({{720, 1, 1}, {1080, 1, 1}, {1080, 1.5, 1.5}, {1440, 2, 2}}) do
		local window = {size = {x = w[1] * 16 / 9, y = w[1]}, real_hud_scaling = w[2],
			real_gui_scaling = w[3]}
		local hud, gui = w[2], w[3]
		local line = math.ceil(20 * gui / hud) * hud
		local banner_y = layout.zone_banner_offset(window).y * hud
		local banner_bottom = banner_y + math.ceil(20 * 2.5 * gui / hud) * hud / 2
		local sub_y = layout.zone_subtitle_offset(window).y * hud
		local warn_y = layout.flight_warning_offset(window).y * hud
		check(sub_y - line / 2 > banner_bottom, "B subtitle below the banner at " .. w[1])
		check(warn_y - line / 2 > sub_y + line / 2, "B flight warning below the subtitle at " ..
			w[1])
		check(warn_y + line / 2 < 0.25 * w[1] - 20 * gui,
			"B flight warning above the level-up banner at " .. w[1] .. "p scale " .. w[2])
	end
end

-- ---------------------------------------------------------------------------
-- T: the target frame's PvP marker
-- ---------------------------------------------------------------------------
do
	local steps, joins = {}, {}
	rawset(_G, "core", {
		register_globalstep = function(fn) steps[#steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function() end,
		is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and
			obj:is_player() end,
		get_connected_players = nil,
	})
	local faction = {}
	rawset(_G, "grug_factions", {
		get_faction = function(player) return faction[player:get_player_name()] end,
		display_name = function(id)
			return ({accord = "The Accord", throng = "The Throng"})[id]
		end,
	})
	local looking_at = {}
	rawset(_G, "grug_abilities", {crosshair = {recent_aim = function(player)
		local target = looking_at[player:get_player_name()]
		return {ray = {range = 30, reason = "object", distance = 5,
			pointed = {type = "object", ref = target}}}
	end}})
	rawset(_G, "grug_pvp", nil)
	dofile(repo .. "/mods/ENTITIES/grug_mobs/target_frame.lua")
	local viewer = fake_player("dana")
	local friend, enemy = fake_player("eli"), fake_player("finn")
	faction.dana, faction.eli, faction.finn = "accord", "accord", "throng"
	local online = {viewer}
	core.get_connected_players = function() return online end
	for _, fn in ipairs(joins) do fn(viewer) end
	local frame = viewer.next_id
	local function frame_of(target)
		looking_at.dana = target
		for _, fn in ipairs(steps) do fn(0.5) end
		return viewer.huds[frame].text, viewer.huds[frame].number
	end
	local text, color = frame_of(enemy)
	eq(text, "finn — The Throng", "T without grug_pvp: unchanged text")
	eq(color, 0xff5555, "T without grug_pvp: enemy red")
	rawset(_G, "grug_pvp", fake_pvp())
	text, color = frame_of(friend)
	eq(text, "eli — The Accord", "T own faction: no marker")
	eq(color, 0x55ff55, "T own faction green")
	pvp_state.finn = nil
	text, color = frame_of(enemy)
	eq(text, "finn — The Throng (protected)", "T an unflagged enemy is protected")
	eq(color, 0xaaaaaa, "T protected is gray")
	pvp_state.finn = {flagged = true}
	text, color = frame_of(enemy)
	eq(text, "finn — The Throng (flagged)", "T a flagged enemy")
	eq(color, 0xaaaaaa, "T gray while the viewer is unflagged")
	pvp_state.dana = {flagged = true}
	text, color = frame_of(enemy)
	eq(text, "finn — The Throng (flagged)", "T both flagged")
	eq(color, 0xff5555, "T red when both can fight")
	pvp_state.finn = nil
	text, color = frame_of(enemy)
	eq(text, "finn — The Throng (protected)", "T a flagged viewer, protected enemy")
	eq(color, 0xaaaaaa, "T still gray")
	pvp_state.dana = nil
end

if #failures > 0 then
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R31 P2 PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
print("R31 P2 PORTABLE PASS checks=" .. checks)
