-- Round 86 lane ACCOUNT portable test (LuaJIT): the website's default
-- rewards on the Account page "The Charter" (round86-plan.md §4 ACCOUNT;
-- docs/technical/web-accounts.md §5.1, §5.2 default_rewards, amended
-- 2026-11-22).
--
--   luajit tools/r86_account/portable_test.lua [repo]
--
-- Loads the REAL grug_accounts (init.lua, model.lua, flow.lua, page.lua) and
-- grug_core/ui.lua on a fake engine (the one of tools/r79_page, trimmed):
-- mod storage, player meta, sfinv's page table and contexts, the join and
-- arrival hooks. Checks:
--   F  the field: missing, null (absent after the bridge's JSON decode),
--      not a list, empty; malformed ids and duplicates dropped, the order
--      kept, an unknown id stored but not shown and taking no place, more
--      than four (the first four known shown); nothing granted;
--   V  the version rule: a stored list of 0.85.0 reports 0 while the game
--      keeps applying and showing it, the next list is applied whatever its
--      version (the held one too), then the real version is reported, also
--      when that answer had no field; after a reboot too; a list without a
--      version changes nothing; a character's deletion keeps the mark (and
--      the lack of it); the held version with other defaults changes
--      nothing;
--   R  the redraw: a defaults-only change with a new version re-sends every
--      open Account page (linked or not), no other page, runs no change
--      callback (the bridge's online resend hangs on those); a binding
--      change alone redraws no unlinked page;
--   P  the page: unlinked with one, three and no default rewards (the
--      strip, the crest, the steps naming the website's button, the link by
--      password, the address and "Open website", the field and Check code),
--      a wrong and an expired code, the offer, linked with and without
--      rewards (the hints, the help block), the buttons that only show do
--      not re-send.

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
local function lacks(text, needle, label)
	checks = checks + 1
	if text:find(needle, 1, true) then error("FAIL " .. label .. ": has " .. needle, 2) end
end
local function count(text, needle)
	local found, from = 0, 1
	while true do
		local at = text:find(needle, from, true)
		if not at then return found end
		found, from = found + 1, at + 1
	end
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
local function deserialize(text)
	local chunk = loadstring("return " .. text:gsub("^return ", ""))
	return chunk and chunk() or nil
end

local clock = 1794095000
os.time = function() return clock end -- luacheck: ignore

local function new_storage(rows)
	rows = rows or {}
	return {rows = rows,
		get_string = function(_, key) return rows[key] or "" end,
		set_string = function(_, key, value) rows[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return tonumber(rows[key]) or 0 end,
		set_int = function(_, key, value) rows[key] = tostring(value) end}
end

_G.SecureRandom = function()
	local counter = 0
	return {next_bytes = function(_, bytes)
		counter = counter + 1
		local out = {}
		for index = 1, bytes do out[index] = string.char((counter * 7 + index * 13) % 256) end
		return table.concat(out)
	end}
end

local world
local escapes = {["\\"] = "\\\\", ["["] = "\\[", ["]"] = "\\]", [";"] = "\\;", [","] = "\\,",
	["$"] = "\\$"}
_G.core = {
	log = function(level, text) world.logs[#world.logs + 1] = level .. " " .. text end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = deserialize,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return "grug_accounts" end,
	get_mod_storage = function() return world.storage end,
	sha1 = function(text) return ("%040x"):format(#text) end,
	get_us_time = function() return clock * 1000000 end,
	after = function(delay, func) world.timers[#world.timers + 1] = {at = clock + delay, func = func} end,
	get_player_by_name = function(name) return world.players[name] end,
	register_on_joinplayer = function(func) world.hooks.join[#world.hooks.join + 1] = func end,
	register_on_leaveplayer = function(func) world.hooks.leave[#world.hooks.leave + 1] = func end,
	register_on_mods_loaded = function(func) world.hooks.mods_loaded[#world.hooks.mods_loaded + 1] = func end,
	formspec_escape = function(text) return (text:gsub("[\\%[%];,$]", escapes)) end,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
}
_G.grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
_G.grug_core = {text = dofile(repo .. "/mods/CORE/grug_core/text.lua"),
	feed = function(player, kind, text) world.feed[#world.feed + 1] = {player:get_player_name(), kind, text} end}
_G.grug_classes = {
	get_class = function(player) return player.class end,
	register_on_arrival = function(func) world.hooks.arrival[#world.hooks.arrival + 1] = func end,
}
_G.grug_factions = {get_faction = function(player) return player.faction end}
_G.grug_inventory = {UI = {frame_w = 20, frame_h = 13.5}}
dofile(repo .. "/mods/CORE/grug_core/ui.lua")

local sends
_G.sfinv = {}

local CHEER_ICON = "grug_quickbar_emote_cheer.png"
local function cloak_icon(id)
	return "[combine:32x32:8,0=grug_achievements_cloak_" .. id .. ".png\\^[sheet\\:2x1\\:0,0"
end

-- A boot of the mod on `storage` (a new one when nil), with the bridge
-- attached and the game's catalogue registered (an emote and four cloaks).
local function boot(storage)
	world = {storage = storage or new_storage(), logs = {}, timers = {}, feed = {}, players = {},
		hooks = {join = {}, leave = {}, mods_loaded = {}, arrival = {}}}
	sends = {}
	sfinv.pages, sfinv.contexts = {}, {}
	sfinv.register_page = function(name, def) def.name = name; sfinv.pages[name] = def end
	sfinv.set_player_inventory_formspec = function(player)
		local name = player:get_player_name()
		sends[name] = (sends[name] or 0) + 1
	end
	sfinv.make_formspec = function(_, _, content) return content end
	_G.grug_accounts = nil
	dofile(repo .. "/mods/PLAYER/grug_accounts/init.lua")
	grug_accounts.register_reward("emote:cheer", {kind = "emote", name = "Cheer", icon = CHEER_ICON,
		hint = "Play it from the quickbar (E)."})
	for _, id in ipairs({"supporter", "emberwake", "pearlwing", "moonfall"}) do
		grug_accounts.register_reward("cloak:" .. id, {kind = "cloak",
			name = id == "supporter" and "Supporter Cloak" or id:sub(1, 1):upper() .. id:sub(2),
			icon = cloak_icon(id), hint = "Choose it on the Character page."})
	end
	for _, func in ipairs(world.hooks.mods_loaded) do func() end
	world.events = {}
	grug_accounts.attach(function(event) world.events[#world.events + 1] = event end)
	world.changes = {}
	grug_accounts.register_on_change(function(names) world.changes[#world.changes + 1] = names end)
	return sfinv.pages[grug_accounts.PAGE]
end

local function new_player(name, meta)
	local player = {name = name, class = "warrior", faction = "accord", meta = new_storage(meta)}
	function player:get_player_name() return self.name end
	function player:get_meta() return self.meta end
	return player
end

local function join(player, page)
	world.players[player.name] = player
	sfinv.contexts[player.name] = {page = page or "grug_inventory:character"}
	for _, func in ipairs(world.hooks.join) do func(player) end
	return player
end

local function list(version, extra, characters, accounts)
	local sent = {version = version, characters = characters or {}, accounts = accounts or {}}
	for key, value in pairs(extra or {}) do sent[key] = value end
	return sent
end

local function shown_ids()
	local out = {}
	for index, entry in ipairs(grug_accounts.default_rewards()) do out[index] = entry.id end
	return table.concat(out, ",")
end

local function stored()
	return deserialize(world.storage.rows.list)
end

local ID_ROWAN, ID_BRANN = ("a"):rep(32), ("b"):rep(32)

-- F. The field ----------------------------------------------------------------
do
	boot()
	eq(grug_accounts.accounts_version(), 0, "F no list yet")
	eq(grug_accounts.apply_list(list(1)), true, "F a list without the field is applied")
	eq(shown_ids(), "", "F missing: none shown")
	eq(type(stored().default_rewards), "table", "F missing: stored as an empty list (the mark)")
	eq(#stored().default_rewards, 0, "F missing: empty")
	eq(grug_accounts.accounts_version(), 1, "F the real version reported")
	-- JSON null reaches the game as an absent key (core.parse_json with a nil
	-- nullvalue); a value that is no list counts as none.
	eq(grug_accounts.apply_list(list(2, {default_rewards = "emote:cheer"})), true, "F not a list")
	eq(shown_ids(), "", "F not a list: none")
	eq(grug_accounts.apply_list(list(3, {default_rewards = {}})), true, "F empty")
	eq(shown_ids(), "", "F empty: none")
	local before = #world.logs
	grug_accounts.apply_list(list(4, {default_rewards = {"emote:cheer", "Emote:Cheer", 5,
		"cloak:future", "emote:cheer", "cloak:moonfall", "nocolon", {}, "cloak:emberwake"}}))
	eq(table.concat(stored().default_rewards, ","), "emote:cheer,cloak:future,cloak:moonfall,cloak:emberwake",
		"F malformed ids and the duplicate dropped, the order kept, the unknown id stored")
	check(#world.logs > before and world.logs[#world.logs]:find("dropped 5 malformed or repeated", 1, true),
		"F the dropped ids are logged once")
	eq(shown_ids(), "emote:cheer,cloak:moonfall,cloak:emberwake",
		"F the unknown id is not shown and takes no place")
	local entry = grug_accounts.default_rewards()[2]
	eq(entry.name, "Moonfall", "F a shown reward's name from the catalogue")
	eq(entry.icon, cloak_icon("moonfall"), "F and its icon")
	eq(entry.hint, "Choose it on the Character page.", "F and its hint")
	grug_accounts.apply_list(list(5, {default_rewards = {"cloak:future", "cloak:supporter", "cloak:pearlwing",
		"emote:cheer", "cloak:emberwake", "cloak:moonfall"}}))
	eq(shown_ids(), "cloak:supporter,cloak:pearlwing,emote:cheer,cloak:emberwake",
		"F more than four: the first four known, in the order sent")
	eq(#stored().default_rewards, 6, "F all six stored")
	-- Display only: an unlinked character and an account without them get nothing.
	local rowan = join(new_player("Rowan", {["grug_accounts:character_id"] = ID_ROWAN}))
	check(not grug_accounts.has_reward("Rowan", "emote:cheer"), "F nothing granted unlinked")
	grug_accounts.apply_list(list(6, {default_rewards = {"emote:cheer"}},
		{{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1"}},
		{{id = "a_1", name = "jan", rewards = {"cloak:moonfall"}}}))
	check(not grug_accounts.has_reward("Rowan", "emote:cheer"), "F nothing granted linked")
	check(grug_accounts.has_reward("Rowan", "cloak:moonfall"), "F the account's own rewards hold")
	eq(#grug_accounts.rewards_of(rowan:get_player_name()), 1, "F rewards_of is the account's")
end

-- V. The version rule (§5.1) ----------------------------------------------------
do
	-- The stored list of 0.85.0: no default_rewards.
	local OLD = {version = 7, characters = {{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1"}},
		accounts = {{id = "a_1", name = "jan", rewards = {"emote:cheer"}}}}
	local function old_storage()
		return new_storage({list = core.serialize(OLD)})
	end
	local page = boot(old_storage())
	local rowan = join(new_player("Rowan", {["grug_accounts:character_id"] = ID_ROWAN}))
	eq(grug_accounts.accounts_version(), 0, "V1 the list of 0.85.0: 0 reported")
	eq(grug_accounts.enabled(), true, "V1 the held list still enables the page")
	check(page:is_in_nav(rowan), "V1 the tab shows")
	eq(grug_accounts.account_of("Rowan").id, "a_1", "V1 the binding holds")
	check(grug_accounts.has_reward("Rowan", "emote:cheer"), "V1 the rewards hold")
	eq(shown_ids(), "", "V1 no defaults yet")
	-- A list without a version changes nothing.
	eq(grug_accounts.apply_list({characters = {}}), false, "V1 no version: ignored")
	eq(grug_accounts.accounts_version(), 0, "V1 still 0")
	-- A deletion while unmarked keeps it unmarked.
	grug_accounts.forget_character("Rowan")
	eq(stored().default_rewards, nil, "V1 a deletion keeps the old list's form")
	eq(#stored().characters, 0, "V1 and drops the row")
	eq(grug_accounts.accounts_version(), 0, "V1 still 0 after a deletion")
	boot(old_storage())
	-- The website's answer to 0: the held version, with no field.
	eq(grug_accounts.apply_list(list(7, nil, OLD.characters, OLD.accounts)), true,
		"V2 the held version is applied while 0 is reported")
	eq(grug_accounts.accounts_version(), 7, "V2 then the real version, without the field")
	eq(#world.changes, 0, "V2 an unchanged binding runs no change callback")
	eq(grug_accounts.apply_list(list(7, nil, OLD.characters, OLD.accounts)), false,
		"V2 the same version again is ignored")
	-- A reboot keeps the mark.
	boot(world.storage)
	eq(grug_accounts.accounts_version(), 7, "V2 after a reboot the real version")
	-- A deletion keeps the mark (M.forget rewrites the stored list).
	grug_accounts.forget_character("Rowan")
	boot(world.storage)
	eq(grug_accounts.accounts_version(), 7, "V2 a deletion keeps the mark")
	eq(grug_accounts.account_of("Rowan"), nil, "V2 and removed the row")

	-- The answer with the field, at the held version.
	boot(old_storage())
	eq(grug_accounts.accounts_version(), 0, "V3 0 reported")
	eq(grug_accounts.apply_list(list(7, {default_rewards = {"emote:cheer"}}, OLD.characters, OLD.accounts)),
		true, "V3 applied at the held version")
	eq(shown_ids(), "emote:cheer", "V3 the defaults shown")
	eq(grug_accounts.accounts_version(), 7, "V3 the real version")
	-- The held version with other defaults changes nothing.
	eq(grug_accounts.apply_list(list(7, {default_rewards = {"cloak:moonfall"}}, OLD.characters,
		OLD.accounts)), false, "V4 the same version changes nothing")
	eq(shown_ids(), "emote:cheer", "V4 the defaults stay")
	-- A higher version while 0 is reported, and a lower one later.
	boot(old_storage())
	eq(grug_accounts.apply_list(list(9, {default_rewards = {"cloak:moonfall"}}, OLD.characters,
		OLD.accounts)), true, "V5 a new version while 0 is reported")
	eq(grug_accounts.accounts_version(), 9, "V5 reported")
	eq(grug_accounts.apply_list(list(8, {default_rewards = {}}, OLD.characters, OLD.accounts)), true,
		"V5 a lower version (a restored backup) is applied")
	eq(shown_ids(), "", "V5 and its empty defaults shown")
	eq(grug_accounts.accounts_version(), 8, "V5 its version reported")
	-- A lost answer: nothing applied, 0 again at the next request.
	boot(old_storage())
	eq(grug_accounts.accounts_version(), 0, "V6 without an answer 0 again")
end

-- R. The redraw -----------------------------------------------------------------
do
	local page = boot()
	local PAGE = grug_accounts.PAGE
	grug_accounts.apply_list(list(1, {default_rewards = {"emote:cheer"}},
		{{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1"}},
		{{id = "a_1", name = "jan", rewards = {}}}))
	join(new_player("Rowan", {["grug_accounts:character_id"] = ID_ROWAN}), PAGE)
	join(new_player("Brann", {["grug_accounts:character_id"] = ID_BRANN}), PAGE)
	join(new_player("Cora"))
	check(page ~= nil, "R the page")
	local BINDINGS = {{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1"}}
	local ACCOUNTS = {{id = "a_1", name = "jan", rewards = {}}}
	world.changes, sends = {}, {}
	eq(grug_accounts.apply_list(list(2, {default_rewards = {"emote:cheer", "cloak:moonfall"}}, BINDINGS,
		ACCOUNTS)), true, "R a defaults-only change with a new version")
	eq(sends.Brann, 1, "R the unlinked open page re-sent")
	eq(sends.Rowan, 1, "R the linked open page re-sent")
	eq(sends.Cora, nil, "R another page not")
	eq(#world.changes, 0, "R no change callback (no online resend)")
	sends = {}
	eq(grug_accounts.apply_list(list(2, {default_rewards = {"cloak:pearlwing"}}, BINDINGS, ACCOUNTS)), false,
		"R the same version")
	eq(next(sends), nil, "R nothing re-sent")
	eq(grug_accounts.apply_list(list(3, {default_rewards = {"emote:cheer", "cloak:moonfall"}}, BINDINGS,
		ACCOUNTS)), true, "R a new version, the same defaults")
	eq(next(sends), nil, "R nothing re-sent for unchanged defaults")
	-- A binding change alone redraws its own character, not the unlinked page.
	ACCOUNTS[1].rewards = {"cloak:moonfall"}
	sends = {}
	grug_accounts.apply_list(list(4, {default_rewards = {"emote:cheer", "cloak:moonfall"}}, BINDINGS, ACCOUNTS))
	eq(sends.Rowan, 1, "R the changed account's page")
	eq(sends.Brann, nil, "R not the unlinked page")
	eq(#world.changes, 1, "R one change callback")
end

-- P. The page ---------------------------------------------------------------------
do
	local page = boot()
	local PAGE = grug_accounts.PAGE
	local rowan = join(new_player("Rowan", {["grug_accounts:character_id"] = ID_ROWAN}), PAGE)
	local function view(player) return page:get(player, sfinv.contexts[player.name]) end
	local function click(player, fields)
		return page:on_player_receive_fields(player, sfinv.contexts[player.name], fields)
	end
	local version = 0
	local function defaults(ids, characters, accounts)
		version = version + 1
		return grug_accounts.apply_list(list(version, {default_rewards = ids}, characters, accounts))
	end
	local ESC_CHEER = core.formspec_escape(CHEER_ICON)

	defaults({"emote:cheer"})
	local fs = view(rowan)
	has(fs, "image[1.280,1.120;5.620,5.620;grug_creation_crest.png]", "P1 one reward: the large crest")
	has(fs, "Every linked account gets", "P1 the strip's heading")
	has(fs, "image[1.200,8.290;1.490,1.490;" .. ESC_CHEER .. "]", "P1 the large icon")
	has(fs, "Cheer", "P1 the name")
	has(fs, "Play it from the quickbar (E).", "P1 the hint below")
	has(fs, "tooltip[1.120,8.210;5.940,1.650;Cheer · Emote. Play it from the quickbar (E).]", "P1 the tooltip")
	has(fs, "Link your character", "P1 the title")
	has(fs, "Connect Rowan to your Grudgelands website account.", "P1 the subtitle")
	has(fs, "Open the website", "P1 step 1")
	has(fs, "grudgelands.com/play", "P1 the address")
	has(fs, "button_url[15.270,4.680;3.540,0.820;grug_account_website;Open website;https://grudgelands.com/play]",
		"P1 Open website")
	has(fs, "Sign in and press \"Create Character\"", "P1 step 2 names the website's button (ruling 3)")
	has(fs, "It shows your code\\, valid for 10 minutes.", "P1 the code's validity")
	has(fs, "Or link it there with this character's name and password.", "P1 the link by password stays")
	has(fs, "Enter your 10-character code", "P1 step 3")
	has(fs, "field[9.080,10.140;5.960,1.000;grug_account_code;;]", "P1 the code field")
	has(fs, "button[15.260,10.140;3.520,1.000;grug_account_link;Check code]", "P1 Check code")
	has(fs, "bgimg=grug_ui_selected.png", "P1 Check code is the selected plate")

	defaults({"cloak:emberwake", "cloak:pearlwing", "emote:cheer"})
	fs = view(rowan)
	has(fs, "image[1.715,0.680;4.750,4.750;grug_creation_crest.png]", "P2 three rewards: the smaller crest")
	eq(count(fs, ";1.040,1.040;#a995674b]"), 3, "P2 three framed icons")
	has(fs, "image[1.200,6.950;0.880,0.880;" .. core.formspec_escape(cloak_icon("emberwake")) .. "]",
		"P2 the first in the order sent")
	has(fs, "image[1.200,9.510;0.880,0.880;" .. ESC_CHEER .. "]", "P2 the third")
	eq(count(fs, "Play it from the quickbar (E)."), 1, "P2 no hint line: the hint only in the tooltip")
	has(fs, "Every linked account gets", "P2 the heading")

	defaults({})
	fs = view(rowan)
	lacks(fs, "Every linked account gets", "P3 no defaults: no strip")
	has(fs, "image[1.150,3.580;5.880,5.880;grug_creation_crest.png]", "P3 the crest alone")
	has(fs, "grug_account_code", "P3 the field stays")
	has(fs, "Sign in and press", "P3 the steps stay")
	defaults({"cloak:future"})
	lacks(view(rowan), "Every linked account gets", "P3 an unknown id alone: no strip")

	-- A wrong and an expired code (the website's refusals).
	click(rowan, {grug_account_code = "ABCDE-FGH23", grug_account_link = "Check code"})
	eq(world.events[#world.events].type, "account.link_request", "P4 the request")
	grug_accounts.link_answer({request_id = world.events[#world.events].request_id, name = "Rowan",
		outcome = "refused", reason = "unknown_code"})
	fs = view(rowan)
	has(fs, "The website does not know this code. Please check it.", "P4 the wrong code's line")
	has(fs, "textcolor=#efafa2", "P4 in the error colour")
	has(fs, "grug_account_code;;ABCDE-FGH23]", "P4 the code kept")
	click(rowan, {grug_account_code = "ABCDE-FGH23", grug_account_link = "Check code"})
	grug_accounts.link_answer({request_id = world.events[#world.events].request_id, name = "Rowan",
		outcome = "refused", reason = "expired_code"})
	has(view(rowan), "This code has expired. Please create a new one on the website.", "P4 the expired line")

	-- The attempt limit (review finding): a fifth refusal shows only why
	-- Check code cannot start now, which fits the two-line status.
	do
		local brann = join(new_player("Brann", {["grug_accounts:character_id"] = ID_BRANN}), PAGE)
		for _ = 1, 5 do
			click(brann, {grug_account_code = "ABCDE-FGH23", grug_account_link = "Check code"})
			grug_accounts.link_answer({request_id = world.events[#world.events].request_id, name = "Brann",
				outcome = "refused", reason = "unknown_code"})
		end
		fs = view(brann)
		local text = fs:match("textarea%[[%d.]+,[%d.]+;[%d.]+,0%.950;;;([^%]]*)%]")
		eq(text, "Too many link attempts. Please wait a few minutes and try again.",
			"P4 the attempt limit alone in the status")
	end

	-- Buttons that only show re-send nothing.
	sends = {}
	click(rowan, {grug_account_website = "Open website"})
	click(rowan, {grug_account_text_1 = "Cheer"})
	click(rowan, {grug_account_focus = ""})
	eq(next(sends), nil, "P5 no re-send for Open website, a text or the focus")
	click(rowan, {grug_account_code = "ABCDE-FGH23", key_enter_field = "grug_account_code"})
	eq(sends.Rowan, 1, "P5 Enter in the field is an action")

	-- The offer.
	grug_accounts.link_answer({request_id = world.events[#world.events].request_id, name = "Rowan",
		outcome = "offer", account_name = "Fenlark"})
	fs = view(rowan)
	has(fs, "Confirm your account", "P6 the offer's heading")
	has(fs, "Link Rowan to the website account", "P6 the question")
	has(fs, "Fenlark", "P6 the account")
	has(fs, "Only a website administrator can undo a link.", "P6 the warning")
	has(fs, ";grug_account_confirm;Confirm link]", "P6 Confirm link")
	has(fs, ";grug_account_cancel;Cancel]", "P6 Cancel")
	lacks(fs, "Every linked account gets", "P6 no strip in the offer")

	-- Linked: the account's rewards and the help block.
	click(rowan, {grug_account_confirm = "Confirm link"})
	defaults({"emote:cheer"}, {{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1"}},
		{{id = "a_1", name = "Fenlark", rewards = {"emote:cheer", "cloak:emberwake"}}})
	fs = view(rowan)
	has(fs, "LINKED WEBSITE ACCOUNT", "P7 the panel's heading")
	has(fs, "Fenlark", "P7 the account")
	has(fs, "Linked to Rowan", "P7 the character")
	has(fs, "Your rewards", "P7 the column")
	has(fs, "Play it from the quickbar (E).", "P7 the emote's hint")
	has(fs, "Choose it on the Character page.", "P7 the cloak's hint")
	has(fs, "Missing a reward or want to unlink?", "P7 the help block")
	has(fs, "button_url[12.690,11.170;3.150,0.760;grug_account_website", "P7 Open website")
	lacks(fs, "Every linked account gets", "P7 no default strip when linked")
	lacks(fs, "grug_account_code", "P7 no field")

	defaults({"emote:cheer"}, {{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1"}},
		{{id = "a_1", name = "Fenlark", rewards = {}}})
	fs = view(rowan)
	has(fs, "Your account has no rewards yet.", "P8 an account with no rewards")
	has(fs, "Missing a reward or want to unlink?", "P8 the help block stays")

	-- Five rewards: two columns, every icon above the help block.
	defaults({}, {{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1"}},
		{{id = "a_1", name = "Fenlark", rewards = {"emote:cheer", "cloak:supporter", "cloak:emberwake",
			"cloak:pearlwing", "cloak:moonfall"}}})
	fs = view(rowan)
	local icons = 0
	for x, y, size in fs:gmatch("box%[([%d.]+),([%d.]+);([%d.]+),[%d.]+;#a995674b%]") do
		icons = icons + 1
		check(tonumber(x) >= 8.49 and tonumber(y) + tonumber(size) <= 9.56, "P9 icon " .. icons .. " in place")
	end
	eq(icons, 5, "P9 five rewards")
end

print(("r86_account: %d checks passed"):format(checks))
