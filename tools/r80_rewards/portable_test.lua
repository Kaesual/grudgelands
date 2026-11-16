-- Round 80 lane REWARDS portable test (LuaJIT): the six donor cloaks as
-- website-account rewards and the Account page holding every reward
-- (round80-plan.md §4 REWARDS).
--
--   luajit tools/r80_rewards/portable_test.lua [repo]
--
-- The fake engine of tools/r79_page/portable_test.lua (copied): the REAL
-- grug_accounts (init, model, flow, page), grug_core/ui.lua and
-- grug_achievements (core.lua, init.lua, the real catalog.lua). Checks:
--   R  the catalogue: the six rows (ids, names, account flag, texture and
--      wing names, the files and their sizes), no achievement unlocks them,
--      no row of the Achievements list names them, the account cloaks and
--      the reward catalogue in catalogue order (id, kind, name, icon, hint);
--   W  an account with a donor cloak: the picker lists it, a choice wears
--      it (texture and wings drawn and stored), a second character of the
--      account has it, a character of another account does not; losing it
--      falls back to No cloak and redraws; a worn donor cloak survives the
--      loss of another; an earned Supporter Cloak and a donor cloak together;
--   P  the Account page with all seven account cloaks at text scale 1 and
--      0.5: two columns, every cell inside the card and the card inside the
--      20 x 13.5 body, the text's rough width inside its column; a stub
--      catalogue of 18 rewards (an emote among them) still inside, and the
--      real catalogue within those 18.

local repo = arg and arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(a, b, label)
	checks = checks + 1
	if a ~= b then
		error(("FAIL %s: got %s, wanted %s"):format(label, tostring(a), tostring(b)), 2)
	end
end
local function has(text, needle, label)
	checks = checks + 1
	if not text:find(needle, 1, true) then error("FAIL " .. label .. ": no " .. needle, 2) end
end
-- A text as the formspec carries it.
local function shown(text, needle, label)
	checks = checks + 1
	if not text:find(core.formspec_escape(needle), 1, true) then
		error("FAIL " .. label .. ": no " .. needle, 2)
	end
end
local function lacks(text, needle, label)
	checks = checks + 1
	if text:find(needle, 1, true) then error("FAIL " .. label .. ": has " .. needle, 2) end
end

--
-- Fake engine
--

local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local parts, keys = {}, {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

local clock = 1794095000
os.time = function() return clock end -- luacheck: ignore

local function new_storage()
	local rows = {}
	return {rows = rows,
		get_string = function(_, key) return rows[key] or "" end,
		set_string = function(_, key, value) rows[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return tonumber(rows[key]) or 0 end,
		set_int = function(_, key, value) rows[key] = tostring(value) end}
end

local random_counter = 0
_G.SecureRandom = function()
	return {next_bytes = function(_, count)
		random_counter = random_counter + 1
		local out = {}
		for index = 1, count do out[index] = string.char((random_counter * 7 + index * 13) % 256) end
		return table.concat(out)
	end}
end

local logs, feed, timers, hooks, players, storages = {}, {}, {}, {}, {}, {}
local commands, current_mod = {}, nil
local function hook(kind)
	return function(func)
		hooks[kind] = hooks[kind] or {}
		table.insert(hooks[kind], func)
	end
end
local function run_hooks(kind, ...)
	for _, func in ipairs(hooks[kind] or {}) do func(...) end
end

local escapes = {["\\"] = "\\\\", ["["] = "\\[", ["]"] = "\\]", [";"] = "\\;", [","] = "\\,",
	["$"] = "\\$"}
_G.core = {
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		local chunk = loadstring("return " .. text:gsub("^return ", ""))
		return chunk and chunk() or nil
	end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function()
		storages[current_mod] = storages[current_mod] or new_storage()
		return storages[current_mod]
	end,
	sha1 = function(text) return ("%040x"):format(#text) end,
	get_us_time = function() return clock * 1000000 end,
	after = function(delay, func, ...)
		timers[#timers + 1] = {at = clock + delay, func = func, args = {...}}
	end,
	get_player_by_name = function(name) return players[name] end,
	player_exists = function(name) return players[name] ~= nil end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	register_on_joinplayer = hook("join"),
	register_on_leaveplayer = hook("leave"),
	register_on_mods_loaded = hook("mods_loaded"),
	register_on_dieplayer = hook("die"),
	register_chatcommand = function(name, def) commands[name] = def end,
	formspec_escape = function(text) return (text:gsub("[\\%[%];,$]", escapes)) end,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
}

local function advance(seconds)
	clock = clock + seconds
	local again = true
	while again do
		again = false
		for index, timer in ipairs(timers) do
			if timer.at <= clock then
				table.remove(timers, index)
				timer.func(unpack(timer.args))
				again = true
				break
			end
		end
	end
end

-- sfinv as far as the page and the navigation use it: the page table, the
-- contexts and the sends (one count per player).
local sends = {}
_G.sfinv = {pages = {}, pages_unordered = {}, contexts = {},
	register_page = function(name, def)
		def.name = name
		sfinv.pages[name] = def
		sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def
	end,
	set_player_inventory_formspec = function(player)
		local name = player:get_player_name()
		sends[name] = (sends[name] or 0) + 1
	end,
	make_formspec = function(_, _, content) return content end,
	handle_scroll = function() return false end,
	get_formspec = function() return "" end,
	get_homepage_name = function() return "grug_inventory:character" end,
	set_page = function() end,
}

_G.grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
_G.grug_core = {
	feed = function(player, kind, text) feed[#feed + 1] = {player:get_player_name(), kind, text} end,
	get_player_faction = function(name) return players[name] and players[name].faction end,
}
_G.grug_classes = {
	get_class = function(player) return player.class end,
	register_on_arrival = hook("arrival"),
}
_G.grug_factions = {get_faction = function(player) return player.faction end}
local applied, character_refreshes = {}, {}
local cloak_source
_G.grug_visuals = {
	register_cloak_source = function(func) cloak_source = func end,
	-- The look as grug_visuals.apply would draw and store it (the stored
	-- appearance's cloak comes from the same source).
	apply = function(player)
		local texture, id, wings = cloak_source(player)
		applied[#applied + 1] = {name = player:get_player_name(), texture = texture, id = id,
			wings = wings}
	end,
}
_G.grug_inventory = {UI = {frame_w = 20, frame_h = 13.5},
	refresh_character = function(player)
		local name = player:get_player_name()
		character_refreshes[name] = (character_refreshes[name] or 0) + 1
	end,
	refresh_character_tab = function() end,
}

local function new_player(name, created)
	local meta = new_storage()
	local player = {name = name, class = created ~= false and "warrior" or nil,
		faction = created ~= false and "accord" or nil, meta = meta}
	function player:get_player_name() return self.name end
	function player:get_meta() return self.meta end
	function player:is_player() return true end
	return player
end

local function join(player)
	players[player.name] = player
	sfinv.contexts[player.name] = {page = "grug_inventory:character"}
	run_hooks("join", player)
end

--
-- Load the mods in their dependency order
--

dofile(repo .. "/mods/CORE/grug_core/ui.lua")
current_mod = "grug_accounts"
dofile(repo .. "/mods/PLAYER/grug_accounts/init.lua")
current_mod = "grug_achievements"
dofile(repo .. "/mods/PLAYER/grug_achievements/init.lua")
current_mod = nil
run_hooks("mods_loaded")

local A, R, book = grug_achievements, grug_achievements.rules, grug_achievements.book
local PAGE = grug_accounts.PAGE
local page = sfinv.pages[PAGE]
local UI = grug_core.ui

local DONOR = {
	{"emberwake", "Emberwake"}, {"veilstream", "Veilstream"}, {"pearlwing", "Pearlwing"},
	{"moonfall", "Moonfall"}, {"wintercourt", "Wintercourt"}, {"frost_regent", "Frost Regent"},
}

-- A PNG's width and height from its IHDR chunk.
local function png_size(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local data = handle:read(24)
	handle:close()
	local function u32(at)
		local a, b, c, d = data:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	if not data or #data < 24 or data:sub(13, 16) ~= "IHDR" then return nil end
	return u32(17), u32(21)
end

--
-- R: the catalogue
--

local TEXTURES = repo .. "/mods/PLAYER/grug_achievements/textures/"
for _, row in ipairs(DONOR) do
	local id, name = row[1], row[2]
	local cloak = book.cloak[id]
	check(cloak ~= nil, "R1 the catalogue has " .. id)
	eq(cloak.name, name, "R1 the name of " .. id)
	eq(cloak.account, true, "R1 " .. id .. " is an account cloak")
	eq(cloak.texture, "grug_achievements_cloak_" .. id .. ".png", "R1 the texture of " .. id)
	eq(cloak.wings, "grug_achievements_cloak_" .. id .. "_wings.png", "R1 the wings of " .. id)
	local w, h = png_size(TEXTURES .. cloak.texture)
	check(w == 32 and h == 32, "R1 " .. cloak.texture .. " is 32 x 32")
	w, h = png_size(TEXTURES .. cloak.wings)
	check(w == 16 and h == 32, "R1 " .. cloak.wings .. " is 16 x 32")
	check(not book.default[id], "R1 " .. id .. " is no default")
end
-- No achievement unlocks a donor cloak (they are account rewards only), so
-- none is earnable and the Achievements list never names one.
local donor_set = {}
for _, row in ipairs(DONOR) do donor_set[row[1]] = true end
for _, ach in ipairs(book.achievements) do
	for t, tier in ipairs(ach.tiers) do
		check(not donor_set[tier.cloak], "R2 " .. ach.id .. " tier " .. t .. " unlocks no donor cloak")
	end
end
do
	local list = {}
	for index, id in ipairs(book.account_cloaks) do list[index] = id end
	eq(table.concat(list, ","), "supporter,emberwake,veilstream,pearlwing,moonfall,wintercourt," ..
		"frost_regent", "R3 the account cloaks in catalogue order")
	local catalog = grug_accounts.catalog()
	eq(#catalog, 7, "R3 seven rewards registered")
	for index, id in ipairs(list) do
		local entry, cloak = catalog[index], book.cloak[id]
		eq(entry.id, "cloak:" .. id, "R3 reward " .. index .. " id")
		eq(entry.kind, "cloak", "R3 " .. id .. " kind")
		eq(entry.name, cloak.name, "R3 " .. id .. " name")
		eq(entry.hint, "Choose it on the Character page.", "R3 " .. id .. " hint")
		eq(entry.icon, "[combine:32x32:8,0=" .. cloak.texture .. "\\^[sheet\\:2x1\\:0,0",
			"R3 " .. id .. " icon: the outer face")
	end
	-- The website receives id, kind and name only.
	local rows = grug_accounts.catalog_rows()
	eq(rows[2].id .. "|" .. rows[2].kind .. "|" .. rows[2].name, "cloak:emberwake|cloak|Emberwake",
		"R3 the website's catalogue row")
end
do
	-- Without an account no donor cloak is owned, worn or selectable.
	local meta = new_storage()
	for _, id in ipairs(R.unlocked(book, meta)) do
		check(not donor_set[id], "R4 " .. id .. " not owned without the account")
	end
	check(not R.select(book, meta, "emberwake"), "R4 not selectable without the account")
	meta:set_string(R.KEY_SELECTED, "emberwake")
	eq(R.selected(book, meta), "none", "R4 a stored choice without the account reads as none")
	-- The Achievements list (every achievement, every faction) names none.
	for _, faction in ipairs({"accord", "throng"}) do
		for _, ach in ipairs(R.visible_list(book, faction)) do
			for _, tier in ipairs(ach.tiers) do
				check(not donor_set[tier.cloak], "R4 " .. faction .. " list: " .. ach.id)
			end
		end
	end
end

--
-- W: an account with donor cloaks
--

grug_accounts.attach(function() end)
local version = 0
local function send_list(characters, accounts)
	version = version + 1
	return grug_accounts.apply_list({version = version, characters = characters or {},
		accounts = accounts or {}})
end
local function view(player)
	return page:get(player, sfinv.contexts[player.name])
end

local rowan, dara, brann = new_player("Rowan"), new_player("Dara"), new_player("Brann")
join(rowan)
join(dara)
join(brann)
local function cid(player) return player:get_meta():get_string("grug_accounts:character_id") end
local ONE = {id = "a_one", name = "Donor One", rewards = {"cloak:emberwake"}}
local TWO = {id = "a_two", name = "Donor Two", rewards = {}}
local function bindings()
	return {{name = "Rowan", character_id = cid(rowan), account_id = "a_one"},
		{name = "Dara", character_id = cid(dara), account_id = "a_one"},
		{name = "Brann", character_id = cid(brann), account_id = "a_two"}}
end
local function owns(player, id)
	for _, owned in ipairs(A.unlocked_cloaks(player)) do
		if owned == id then return true end
	end
	return false
end

send_list(bindings(), {ONE, TWO})
check(owns(rowan, "emberwake"), "W1 Rowan's account gives Emberwake")
check(owns(dara, "emberwake"), "W1 so does Dara's (the same account)")
check(not owns(brann, "emberwake"), "W1 Brann's account does not")
check(not owns(rowan, "veilstream"), "W1 a cloak the account does not give is not owned")
has(A.cloak_dropdown(rowan, 0, 0, 4), ",Emberwake", "W1 the picker lists it by name")
lacks(A.cloak_dropdown(rowan, 0, 0, 4), "Veilstream", "W1 and not the others")
lacks(A.cloak_dropdown(brann, 0, 0, 4), "Emberwake", "W1 nor in Brann's picker")
applied = {}
check(A.choose_cloak_by_name(rowan, "Emberwake"), "W2 chosen by name")
eq(A.selected_cloak(rowan), "emberwake", "W2 worn")
eq(applied[#applied].texture, book.cloak.emberwake.texture, "W2 drawn with its texture")
eq(applied[#applied].wings, book.cloak.emberwake.wings, "W2 and its wings")
eq(applied[#applied].id, "emberwake", "W2 the stored appearance's cloak")
check(not A.select_cloak(brann, "emberwake"), "W2 Brann cannot wear it")

-- A second donor cloak granted; the first one revoked while Dara wears the
-- second and Rowan the first.
ONE.rewards = {"cloak:emberwake", "cloak:frost_regent"}
send_list(bindings(), {ONE, TWO})
check(A.select_cloak(dara, "frost_regent"), "W3 Dara wears Frost Regent")
applied, character_refreshes = {}, {}
ONE.rewards = {"cloak:frost_regent"}
send_list(bindings(), {ONE, TWO})
eq(A.selected_cloak(rowan), "none", "W3 Rowan's Emberwake falls back to No cloak")
eq(A.selected_cloak(dara), "frost_regent", "W3 Dara's Frost Regent stays")
local drawn = {}
for _, row in ipairs(applied) do drawn[row.name] = row end
eq(drawn.Rowan and drawn.Rowan.texture, nil, "W3 Rowan redrawn without a cloak")
eq(drawn.Rowan and drawn.Rowan.wings, nil, "W3 and without wings")
eq(drawn.Dara and drawn.Dara.texture, book.cloak.frost_regent.texture, "W3 Dara redrawn with hers")
eq(character_refreshes.Rowan, 1, "W3 Rowan's Character page refreshed")
check(not owns(rowan, "emberwake"), "W3 gone from Rowan's picker")
-- The stored choice comes back with a new grant.
ONE.rewards = {"cloak:frost_regent", "cloak:emberwake"}
send_list(bindings(), {ONE, TWO})
eq(A.selected_cloak(rowan), "emberwake", "W4 a new grant wears it again")
-- The earned Supporter Cloak and a donor cloak side by side.
check(commands.achievement.func("admin", "grant Rowan supporter"), "W5 Supporter granted")
local list = A.unlocked_cloaks(rowan)
local last = {}
for index = #list - 2, #list do last[#last + 1] = list[index] end
eq(table.concat(last, ","), "supporter,emberwake,frost_regent", "W5 the picker in catalogue order")
check(A.select_cloak(rowan, "supporter"), "W5 the Supporter Cloak worn")
ONE.rewards = {}
send_list(bindings(), {ONE, TWO})
eq(A.selected_cloak(rowan), "supporter", "W5 the earned cloak stays when the account gives nothing")
eq(A.selected_cloak(dara), "none", "W5 Dara back to No cloak")

--
-- P: the Account page holds every reward
--

local CARD_X = 3.5
-- Rough widths in form units per character at text scale 1 (measured on the
-- Round 79 capture: about 0.135 for the bold name, 0.1 for the hint at 0.9;
-- with a margin).
local BOLD_W, HINT_W = 0.16, 0.13

local function strip(text)
	return (text:gsub("\27%(c@[^)]*%)", ""):gsub("\\(.)", "%1"))
end

-- The card, the rewards' images and labels of a linked page, and the
-- checks every layout must pass.
local function layout(fs, scale, count, label)
	local cx, cy, cw, ch = fs:match("background9%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_ui_panel")
	cx, cy, cw, ch = tonumber(cx), tonumber(cy), tonumber(cw), tonumber(ch)
	check(cx and cy + ch <= 13.5 + 1e-6, label .. " the card inside the body (" .. tostring(ch) .. ")")
	eq(cx, CARD_X, label .. " the card's x")
	local images, columns = 0, {}
	for x, y in fs:gmatch("image%[([%d.]+),([%d.]+);0%.8,0%.8;") do
		x, y = tonumber(x), tonumber(y)
		images = images + 1
		columns[x] = true
		check(x >= cx and x + 0.8 <= cx + cw and y >= cy and y + 0.8 <= cy + ch,
			label .. " icon " .. images .. " inside the card")
	end
	eq(images, count, label .. " one icon per reward")
	local xs = {}
	for x in pairs(columns) do xs[#xs + 1] = x end
	table.sort(xs)
	eq(#xs, math.min(2, count), label .. " two columns")
	local right = {}
	for index, x in ipairs(xs) do right[index] = xs[index + 1] or (cx + cw - 0.5) end
	local function column_end(x)
		for index, left in ipairs(xs) do
			if math.abs(left + 1.0 - x) < 1e-6 then return right[index] end
		end
	end
	-- Name and hint labels sit 1.0 right of their icon; each must end before
	-- the next column (or the card's inner edge) at this text scale.
	local labels = 0
	for x, y, text in fs:gmatch("label%[([%d.]+),([%d.]+);([^%]]*)%]") do
		x, y = tonumber(x), tonumber(y)
		local stop = column_end(x)
		if stop and y > 3.85 then
			labels = labels + 1
			local plain = strip(text)
			local per = (plain:find("  ", 1, true) and BOLD_W or HINT_W) * scale
			check(x + per * #plain <= stop, ("%s %q fits its column (%.2f > %.2f)"):format(label,
				plain, x + per * #plain, stop))
			check(y >= cy and y <= cy + ch, label .. " label inside the card")
		end
	end
	eq(labels, count * 2, label .. " a name and a hint per reward")
end

local ALL = {}
for index, id in ipairs(book.account_cloaks) do ALL[index] = "cloak:" .. id end
ONE.rewards = ALL
send_list(bindings(), {ONE, TWO})
sfinv.contexts.Rowan.page = PAGE
local real_scale = UI.text_scale
for _, scale in ipairs({1, 0.5}) do
	UI.text_scale = function() return scale end
	local fs = view(rowan)
	for _, id in ipairs(book.account_cloaks) do
		has(fs, core.formspec_escape(book.cloak[id].name), "P1 " .. id .. " listed")
	end
	layout(fs, scale, 7, "P1 seven cloaks at " .. scale)
end

-- A stub catalogue of 18 rewards (nine rows, the most the card holds), an
-- emote and long names among them; the real catalogue stays within that.
local real_catalog, real_rewards = grug_accounts.catalog, grug_accounts.rewards_of
local STUB = {}
for index = 1, 18 do
	local emote = index % 3 == 0
	STUB[index] = {id = (emote and "emote:e" or "cloak:c") .. index, kind = emote and "emote" or "cloak",
		name = emote and ("Cheer " .. index) or ("Mantle of the Unburnt " .. index),
		hint = emote and "Play it from the quickbar (E)." or "Choose it on the Character page.",
		icon = "grug_achievements_cloak_supporter.png"}
end
grug_accounts.catalog = function() return STUB end
grug_accounts.rewards_of = function()
	local out = {}
	for index, entry in ipairs(STUB) do out[index] = {id = entry.id, kind = entry.kind, name = entry.name} end
	return out
end
for _, scale in ipairs({1, 0.5}) do
	UI.text_scale = function() return scale end
	layout(view(rowan), scale, 18, "P2 eighteen rewards at " .. scale)
end
grug_accounts.catalog, grug_accounts.rewards_of, UI.text_scale = real_catalog, real_rewards, real_scale
check(#grug_accounts.catalog() <= 18, "P2 the real catalogue fits the card")

-- One reward: one column, the default card height.
ONE.rewards = {"cloak:moonfall"}
send_list(bindings(), {ONE, TWO})
local fs = view(rowan)
layout(fs, 1, 1, "P3 one reward")
has(fs, "background9[3.500,0.600;13.000,6.600;", "P3 the default card")

print(("r80_rewards: %d checks passed"):format(checks))
