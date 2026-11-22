-- Round 79 lane PAGE portable test (LuaJIT): the Account page and the
-- Supporter Cloak as a website-account reward (round79-plan.md §4 PAGE).
--
--   luajit tools/r79_page/portable_test.lua [repo]
--
-- Loads the REAL grug_accounts (init.lua, model.lua, flow.lua, page.lua),
-- grug_core/ui.lua, grug_achievements (core.lua, init.lua, the real
-- catalog.lua) and grug_inventory/navigation.lua on a fake engine with a
-- clock, core.after, mod storage, player meta, sfinv's page table and the
-- join, leave and arrival hooks. Checks:
--   T  the tab: hidden until the bridge is attached and a list is held; the
--      caption "Account" in the bar beside every other tab (Creative and
--      Admin Mail included), its tooltip the full title;
--   P  the page in every state: not linked (texts, address, field, Link),
--      a local refusal, waiting after Link (text, the buttons inert, no Link
--      field, the typed code kept), the offer (question, warning, green Link
--      and red Cancel), Cancel back to the code, waiting after the
--      confirmation, linked without and with rewards (icon, name, kind,
--      hint), a refusal from the website, the 30 s timeout, character
--      creation (only its line), a 64-character account name escaped and inside the card;
--      the page re-sends by itself only while it is shown, once per click;
--   C  the cloak rules on core.lua: the injected account set in
--      R.unlocked, R.has_cloak, R.selected and R.select, only for a flagged
--      cloak; the fallback on loss; R.revoke keeping a cloak the account
--      gives; the earned cloak untouched; the catalogue flag's validation;
--   A  grug_achievements with grug_accounts: the reward registered, the
--      picker and the choice, the cloak source (texture and wings, so the
--      stored appearance follows), the redraw of online characters on a
--      change, /achievement revoke keeping the worn account cloak;
--   S  no link code in the server log.
--
-- Round 86 (lane ACCOUNT) rebuilt the page as "The Charter"
-- (tools/r84_account_mock): the P checks follow its texts, places and
-- button labels; tools/r86_account checks the default rewards.

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
	-- Round 81: the shared text rules (raw field cut, UTF-8 rule).
	text = dofile(repo .. "/mods/CORE/grug_core/text.lua"),
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
eq(PAGE, "grug_accounts:account", "P the page id")
eq(page.title, "Website Account", "P the page title")

local events = {}
local list_version = 0
local function send_list(characters, accounts)
	list_version = list_version + 1
	return grug_accounts.apply_list({version = list_version, characters = characters or {},
		accounts = accounts or {}})
end

-- The page as sent: the formspec of its `get`.
local function view(player)
	local context = sfinv.contexts[player.name]
	return page:get(player, context)
end
local function click(player, fields)
	return page:on_player_receive_fields(player, sfinv.contexts[player.name], fields)
end
local function open(player)
	sfinv.contexts[player.name].page = PAGE
end

--
-- T: the tab
--

local rowan = new_player("Rowan")
join(rowan)
check(not page:is_in_nav(rowan), "T hidden without the bridge")
grug_accounts.attach(function(event) events[#events + 1] = event end)
check(not page:is_in_nav(rowan), "T hidden before the first list")
send_list()
check(page:is_in_nav(rowan), "T shown with the bridge and a list")

do
	-- The real bar with every tab a creative admin sees.
	local titles = {
		{"grug_inventory:inventory", "Inventory"}, {"grug_inventory:character", "Character"},
		{"grug_classes:talents", "Talents & Skills"}, {"sfinv:crafting", "Crafting"},
		{"grug_parties:group", "Social"}, {"grug_map:atlas", "Map & Quests"},
		{"grug_inventory:help", "Help"}, {"grug_mail:admin", "Admin Mail"},
		{"creative:all", "All"}, {"creative:food", "Food"},
	}
	local real_pages, real_unordered = sfinv.pages, sfinv.pages_unordered
	sfinv.pages, sfinv.pages_unordered = {[PAGE] = page}, {}
	for _, row in ipairs(titles) do
		local def = {name = row[1], title = row[2]}
		sfinv.pages[row[1]], sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def, def
	end
	sfinv.pages_unordered[#sfinv.pages_unordered + 1] = page
	_G.grug_xp = {get_level = function() return 12 end}
	grug_factions.display_name = function() return "The Accord" end
	dofile(repo .. "/mods/PLAYER/grug_inventory/navigation.lua")
	local context = {page = PAGE}
	local bar = grug_inventory.navigation(rowan, context, PAGE, 20)
	has(bar, ";Account]", "T the caption")
	has(bar, "tooltip[grug_ui_tab_11;Website Account]", "T the full title as the tooltip")
	eq(context.grug_ui_nav[11], PAGE, "T the tab after the TAB_ORDER pages")
	-- Every caption's share of the bar (19.5 units at 0.05 gaps) against a
	-- rough text width at the largest text size (about 0.21 units a
	-- character at 1.35 times the base size); the capture measures the real
	-- fit.
	local count = 0
	for w, caption in bar:gmatch("button%[[%d.]+,0%.890;([%d.]+),0%.46;grug_ui_[%w_]+;([^%]]+)%]") do
		count = count + 1
		check(tonumber(w) >= 0.21 * #caption, "T room for " .. caption .. " (" .. w .. ")")
	end
	eq(count, 10, "T ten captions: eight pages, Account and Creative")
	sfinv.pages, sfinv.pages_unordered = real_pages, real_unordered
end

--
-- P: the page in every state
--

local NAME64 = "Ser Aldric [the; Patient], keeper of the long road \\ home 123456"
eq(#NAME64, 64, "P the long name has 64 characters")
local ACCOUNT = {id = "a_test1", name = NAME64, rewards = {}}
local RID = rowan:get_meta():get_string("grug_accounts:character_id")
eq(#RID, 32, "P Rowan has an id")

open(rowan)
local fs = view(rowan)
has(fs, "WEBSITE ACCOUNT", "P1 the heading")
has(fs, "Link your character", "P1 the title")
has(fs, "grudgelands.com/play", "P1 the address")
has(fs, "Or link it there with this character's name and password.", "P1 how to link by password")
has(fs, "Enter your 10-character code", "P1 how to link by code")
has(fs, "field[9.080,10.140;5.960,1.000;grug_account_code;;]", "P1 the empty code field")
has(fs, "field_close_on_enter[grug_account_code;false]", "P1 Enter does not close the window")
has(fs, ";grug_account_link;Check code]", "P1 Link")
has(fs, "set_focus[grug_account_focus;true]", "P1 the focus on the invisible button")
lacks(fs, "grug_account_wait_", "P1 nothing inert")
lacks(fs, "please wait", "P1 no waiting line")

-- A code the API refuses at once (wrong length): its line, Link stays.
sends.Rowan = 0
click(rowan, {grug_account_code = "ABC12", grug_account_link = "Link"})
eq(sends.Rowan, 1, "P2 one send for the click")
fs = view(rowan)
shown(fs, "A code has 10 letters and digits, as the website shows it.", "P2 the refusal line")
has(fs, "textcolor=#efafa2", "P2 in the error colour (the mock's)")
has(fs, "grug_account_code;;ABC12]", "P2 the typed code kept")
has(fs, ";grug_account_link;Check code]", "P2 Link stays")
eq(#events, 0, "P2 no request for a refused code")

-- A good code: the request goes out, the page waits.
local CODE = "WXYZ2-34567"
sends.Rowan = 0
click(rowan, {grug_account_code = CODE, key_enter_field = "grug_account_code"})
eq(sends.Rowan, 1, "P3 one send for the click")
eq(#events, 1, "P3 Enter in the field sends the request")
eq(events[1].type, "account.link_request", "P3 the request event")
fs = view(rowan)
shown(fs, "Checking your code with the website. This can take a few seconds, please wait.",
	"P3 the waiting line")
lacks(fs, ";grug_account_link;", "P3 no live Link")
has(fs, "grug_account_wait_", "P3 Link drawn inert")
has(fs, "grug_account_code;;WXYZ2-34567]", "P3 the code kept in the field")
has(fs, "button[15.260,10.140;3.520,1.000;grug_account_wait_", "P3 the inert Check code in its place")
-- A click on the inert Link (or a stale Link) while waiting asks nothing.
click(rowan, {grug_account_code = CODE, grug_account_link = "Link"})
eq(#events, 1, "P3 no second request while waiting")
click(rowan, {grug_account_code = CODE, key_enter_field = "grug_account_code"})
eq(#events, 1, "P3 nor by Enter")

-- The website's offer re-sends the page by itself.
sends.Rowan = 0
local request_id = events[1].request_id
eq(grug_accounts.link_answer({request_id = request_id, name = "Rowan", outcome = "offer",
	account_name = NAME64}), "ok", "P4 the offer answer")
eq(sends.Rowan, 1, "P4 the page re-sent by itself")
fs = view(rowan)
local escaped = core.formspec_escape(NAME64)
has(fs, "Link Rowan to the website account", "P4 the question")
has(fs, escaped, "P4 the name escaped")
has(fs, "Only link to your own account.", "P4 the warning")
has(fs, "Only a website administrator can undo a link.", "P4 who undoes a link")
has(fs, ";grug_account_confirm;Confirm link]", "P4 Confirm link")
has(fs, ";grug_account_cancel;Cancel]", "P4 Cancel")
has(fs, "style[grug_account_confirm;border=false;bgcolor=#ffffff;bgimg=grug_ui_danger.png^\\[hsl:105:0:0",
	"P4 Confirm link green (the confirm role)")
has(fs, "style[grug_account_cancel;border=false;bgcolor=#ffffff;bgimg=grug_ui_danger.png;", "P4 Cancel red")
lacks(fs, "grug_account_code", "P4 no code field in the offer")
-- The long name wraps in a textarea inside the column.
do
	local x, w = fs:match("textarea%[([%d.]+),[%d.]+;([%d.]+),[%d.]+;;;Ser Aldric")
	check(x and tonumber(x) >= 8.3 and tonumber(x) + tonumber(w) <= 19.3 + 1e-6,
		"P4 the name inside the column")
end

-- Cancel: back to the code, which still works.
click(rowan, {grug_account_cancel = "Cancel"})
eq(events[#events].type, "account.link_cancel", "P5 Cancel sends the cancel")
fs = view(rowan)
has(fs, "grug_account_code;;WXYZ2-34567]", "P5 the code still in the field")
has(fs, ";grug_account_link;Check code]", "P5 Link again")
lacks(fs, "please wait", "P5 not waiting")

-- Link again, confirm: the page waits for the binding.
click(rowan, {grug_account_code = CODE, grug_account_link = "Link"})
request_id = events[#events].request_id
grug_accounts.link_answer({request_id = request_id, name = "Rowan", outcome = "offer",
	account_name = NAME64})
click(rowan, {grug_account_confirm = "Confirm link"})
eq(events[#events].type, "account.link_confirm", "P6 the confirmation")
fs = view(rowan)
shown(fs, "Linking your character. This can take a few seconds, please wait.", "P6 the waiting line")
lacks(fs, ";grug_account_confirm;", "P6 no live Confirm link")
lacks(fs, ";grug_account_cancel;", "P6 no live Cancel")
has(fs, "button[8.490,8.610;3.700,0.890;grug_account_wait_", "P6 Confirm link inert in its place")
has(fs, "button[12.430,8.610;2.450,0.890;grug_account_wait_", "P6 Cancel inert in its place")
has(fs, "Link Rowan to the website account", "P6 the question stays")
has(fs, escaped, "P6 with the name")
click(rowan, {grug_account_confirm = "Confirm link"})
eq(events[#events].type, "account.link_confirm", "P6 a second click sends nothing new")
local confirms = 0
for _, event in ipairs(events) do
	if event.type == "account.link_confirm" then confirms = confirms + 1 end
end
eq(confirms, 1, "P6 one confirmation")

-- The list with the binding: linked, no rewards yet.
sends.Rowan = 0
send_list({{name = "Rowan", character_id = RID, account_id = "a_test1"}}, {ACCOUNT})
check(sends.Rowan >= 1, "P7 the page re-sent by itself")
fs = view(rowan)
has(fs, "LINKED WEBSITE ACCOUNT", "P7 linked")
has(fs, escaped, "P7 the name escaped")
has(fs, "Linked to Rowan", "P7 the character")
has(fs, "Your rewards", "P7 the rewards heading")
has(fs, "Your account has no rewards yet.", "P7 no rewards")
lacks(fs, "grug_account_code", "P7 no code field")
do
	local x, w = fs:match("textarea%[([%d.]+),[%d.]+;([%d.]+),[%d.]+;;;Ser Aldric")
	check(x and tonumber(x) >= 0.43 and tonumber(x) + tonumber(w) <= 7.75 + 1e-6,
		"P7 the name inside the panel")
end
eq(grug_accounts.link_answer({request_id = request_id, name = "Rowan", outcome = "linked",
	account_name = NAME64}), "ok", "P7 the linked answer after its list")

-- The Supporter Cloak granted: one row.
ACCOUNT.rewards = {"cloak:supporter"}
send_list({{name = "Rowan", character_id = RID, account_id = "a_test1"}}, {ACCOUNT})
fs = view(rowan)
lacks(fs, "no rewards yet", "P8 a reward")
has(fs, "Supporter Cloak", "P8 the name")
has(fs, core.colorize("#b8bdb4", "Cloak"), "P8 the kind")
has(fs, "Choose it on the Character page.", "P8 the hint")
has(fs, "image[8.690,3.630;1.210,1.210;\\[combine:32x32:8\\,0=grug_achievements_cloak_supporter.png" ..
	"\\\\^\\[sheet\\\\:2x1\\\\:0\\,0]", "P8 the cloak's face as the icon, escaped")

-- A second character, not linked: the website's refusal, then the timeout.
local brann = new_player("Brann")
join(brann)
open(brann)
click(brann, {grug_account_code = "ABCDEFGH23", grug_account_link = "Link"})
grug_accounts.link_answer({request_id = events[#events].request_id, name = "Brann",
	outcome = "refused", reason = "unknown_code"})
fs = view(brann)
has(fs, "The website does not know this code. Please check it.", "P9 the website's refusal")
has(fs, ";grug_account_link;Check code]", "P9 Link again")
click(brann, {grug_account_code = "ABCDEFGH23", grug_account_link = "Link"})
sends.Brann = 0
advance(31)
eq(sends.Brann, 1, "P10 the timeout re-sends the page by itself")
eq(events[#events].type, "account.link_cancel", "P10 the timeout cancels")
fs = view(brann)
has(fs, "The website did not answer. Please try again later.", "P10 the timeout line")

-- Not shown: no send for a page the player is not on.
sfinv.contexts.Brann.page = "grug_inventory:character"
sends.Brann = 0
click(brann, {grug_account_code = "ABCDEFGH23", grug_account_link = "Link"})
sends.Brann = 0
advance(31)
eq(sends.Brann, 0, "P11 no send while another page is shown")
open(brann)

-- The attempt limit (5 per 10 minutes): the reason, and Link answers it.
click(brann, {grug_account_code = "ABCDEFGH23", grug_account_link = "Link"})
advance(31)
click(brann, {grug_account_code = "ABCDEFGH23", grug_account_link = "Link"})
advance(31)
fs = view(brann)
has(fs, "Too many link attempts. Please wait a few minutes and try again.", "P12 the attempt limit")

-- Character creation (user, 2026-11-15): only can_link's one line, no code
-- field and no Link; the page asks grug_accounts.in_creation.
local CREATION = "Finish creating your character first. You can link it afterwards."
local cora = new_player("Cora", false)
join(cora)
open(cora)
check(grug_accounts.in_creation(cora), "P13 in_creation without class and faction")
check(not grug_accounts.in_creation(rowan), "P13 not in_creation once created")
cora:get_meta():set_string("grug_classes:arriving", "1")
cora.class, cora.faction = "mage", "accord"
check(grug_accounts.in_creation(cora), "P13 in_creation while arriving")
fs = view(cora)
has(fs, CREATION, "P13 arriving: the line")
lacks(fs, "grug_account_code", "P13 arriving: no code field")
cora:get_meta():set_string("grug_classes:arriving", "")
cora.class, cora.faction = nil, nil
fs = view(cora)
has(fs, CREATION, "P13 in creation the line")
lacks(fs, "grug_account_code", "P13 no code field in creation")
lacks(fs, "grug_account_link", "P13 no Link in creation")
lacks(fs, "grug_account_wait_", "P13 no inert button either")
lacks(fs, "Enter your 10-character code", "P13 only the one line")
-- Created: the arrival re-sends the page, which offers the code.
cora.class, cora.faction = "mage", "accord"
sends.Cora = 0
run_hooks("arrival", cora)
eq(sends.Cora, 1, "P13 the arrival re-sends the page")
fs = view(cora)
has(fs, ";grug_account_link;Check code]", "P13 after creation Link")
has(fs, "grug_account_code", "P13 after creation the code field")
lacks(fs, "Finish creating", "P13 after creation no creation line")

--
-- C: the cloak rules (core.lua, the real catalogue)
--

local SUP = book.cloak.supporter
check(SUP and SUP.account == true, "C the Supporter Cloak is flagged")
-- Round 80 added the six donor cloaks after it (tools/r80_rewards checks them).
eq(#book.account_cloaks, 7, "C seven account cloaks")
eq(book.account_cloaks[1], "supporter", "C the first is the Supporter Cloak")
do
	local meta = new_storage()
	local GIVES = {supporter = true}
	local function owned(list, id)
		for _, owned_id in ipairs(list) do if owned_id == id then return true end end
		return false
	end
	check(not owned(R.unlocked(book, meta), "supporter"), "C1 not owned without the account")
	check(not owned(R.unlocked(book, meta, {}), "supporter"), "C1 nor with an empty set")
	check(owned(R.unlocked(book, meta, GIVES), "supporter"), "C1 owned with the account")
	check(R.has_cloak(book, meta, "supporter", GIVES), "C1 has_cloak sees the account")
	check(not R.has_cloak(book, meta, "supporter"), "C1 has_cloak without it")
	check(not R.has_cloak(book, meta, "hunter_1", {hunter_1 = true}), "C1 an unflagged cloak is not given")
	check(not owned(R.unlocked(book, meta, {hunter_1 = true}), "hunter_1"), "C1 nor listed")
	local list = R.unlocked(book, meta, GIVES)
	eq(list[1] .. "," .. list[2] .. "," .. list[3], "none,plain_grey,supporter", "C1 catalogue order")
	check(R.select(book, meta, "supporter", GIVES), "C2 wearable with the account")
	eq(R.selected(book, meta, GIVES), "supporter", "C2 worn")
	eq(R.cloak_texture(book, meta, GIVES), SUP.texture, "C2 its texture")
	eq(R.selected(book, meta), "none", "C2 the loss falls back to No cloak")
	eq(R.cloak_texture(book, meta), nil, "C2 no texture after the loss")
	check(not R.select(book, meta, "supporter"), "C2 not wearable without the account")
	-- R.revoke of the manual achievement while the account gives the cloak.
	local ach = book.achievement.supporter
	R.grant(book, meta, ach)
	R.select(book, meta, "supporter")
	local had, worn = R.revoke(book, meta, ach, GIVES)
	check(had and not worn, "C3 the revoke keeps the cloak the account gives")
	eq(R.selected(book, meta, GIVES), "supporter", "C3 still worn")
	check(not R.has_cloak(book, meta, "supporter"), "C3 the earned cloak is gone")
	had, worn = R.revoke(book, meta, ach, GIVES)
	check(not had and not worn, "C3 a second revoke changes nothing")
	-- Without the account the revoke takes it off, as before.
	R.grant(book, meta, ach)
	R.select(book, meta, "supporter")
	had, worn = R.revoke(book, meta, ach)
	check(had and worn, "C3 without the account the revoke takes it off")
	eq(meta:get_string(R.KEY_SELECTED), "", "C3 back to No cloak")
	-- The earned cloak is never touched by the account path.
	R.grant(book, meta, ach)
	R.select(book, meta, "supporter", GIVES)
	eq(R.selected(book, meta), "supporter", "C4 earned and given: worn without the account too")
	check(R.has_cloak(book, meta, "supporter"), "C4 the earned cloak stays after the loss")
	-- The flag's validation.
	local function catalogue(edit)
		local copy = {defaults = {"none", "plain_grey"}, cloaks = {
			{id = "none", name = "No cloak"},
			{id = "plain_grey", name = "Grey", texture = "grey.png"},
			{id = "gift", name = "Gift", texture = "gift.png", account = true}},
			achievements = {}}
		edit(copy)
		return pcall(R.build, copy)
	end
	check(catalogue(function() end), "C5 a flagged cloak builds")
	check(not catalogue(function(c) c.cloaks[3].account = "yes" end), "C5 account is true or absent")
	check(not catalogue(function(c) c.cloaks[2].account = true end), "C5 not on a default cloak")
	check(not catalogue(function(c) c.cloaks[3].texture = nil end), "C5 not without a texture")
end

--
-- A: grug_achievements with grug_accounts
--

local catalog = grug_accounts.catalog()
eq(#catalog, 7, "A seven rewards registered (Round 80: the donor cloaks after the Supporter Cloak)")
eq(catalog[1].id, "cloak:supporter", "A its id")
eq(catalog[1].kind, "cloak", "A its kind")
eq(catalog[1].name, "Supporter Cloak", "A its name")
eq(catalog[1].hint, "Choose it on the Character page.", "A its hint")
eq(catalog[1].icon, "[combine:32x32:8,0=grug_achievements_cloak_supporter.png\\^[sheet\\:2x1\\:0,0",
	"A its icon: the cloak's outer face")
check(grug_accounts.has_reward("Rowan", "cloak:supporter"), "A Rowan's account gives it")

-- Rowan (granted above): the picker lists it, a choice wears it, the look
-- and the stored appearance carry it with its wings.
local function listed(player)
	for _, id in ipairs(A.unlocked_cloaks(player)) do
		if id == "supporter" then return true end
	end
	return false
end
check(listed(rowan), "A1 in Rowan's picker")
has(A.cloak_dropdown(rowan, 0, 0, 4), "Supporter Cloak", "A1 in the dropdown")
check(not listed(brann), "A1 not in an unlinked character's picker")
applied = {}
check(A.choose_cloak_by_name(rowan, "Supporter Cloak"), "A2 chosen by name")
eq(A.selected_cloak(rowan), "supporter", "A2 worn")
eq(applied[#applied].texture, SUP.texture, "A2 drawn with its texture")
eq(applied[#applied].wings, SUP.wings, "A2 and its wings")

-- A second character of the same account has it too; Brann's own account
-- does not give it.
local dara = new_player("Dara")
join(dara)
local DID = dara:get_meta():get_string("grug_accounts:character_id")
local BID = brann:get_meta():get_string("grug_accounts:character_id")
local OTHER = {id = "a_test2", name = "Test Two", rewards = {}}
local function bindings()
	return {{name = "Rowan", character_id = RID, account_id = "a_test1"},
		{name = "Dara", character_id = DID, account_id = "a_test1"},
		{name = "Brann", character_id = BID, account_id = "a_test2"}}
end
applied, character_refreshes = {}, {}
send_list(bindings(), {ACCOUNT, OTHER})
check(listed(dara), "A3 a second character of the account has it")
check(not listed(brann), "A3 a character of the other account does not")
eq(character_refreshes.Dara, 1, "A3 Dara's Character page refreshed")
local redrawn = {}
for _, row in ipairs(applied) do redrawn[row.name] = true end
check(redrawn.Dara and redrawn.Brann, "A3 the affected online characters redrawn")
check(not redrawn.Rowan, "A3 an unchanged character is not")

-- An offline character of the account: nothing to redraw.
run_hooks("leave", dara)
players.Dara = nil
applied = {}

-- The revoke on the website: Rowan's worn cloak falls back to none.
ACCOUNT.rewards = {}
send_list(bindings(), {ACCOUNT, OTHER})
check(not listed(rowan), "A4 gone from the picker")
eq(A.selected_cloak(rowan), "none", "A4 back to No cloak")
eq(#applied, 1, "A4 one redraw (Rowan; Dara is offline)")
eq(applied[1].name, "Rowan", "A4 Rowan redrawn")
eq(applied[1].texture, nil, "A4 drawn and stored without the cloak")
eq(applied[1].id, "none", "A4 the stored appearance's cloak is none")
fs = view(rowan)
has(fs, "Your account has no rewards yet.", "A4 the page follows")

-- The character-bound Supporter achievement and the account together:
-- /achievement revoke keeps the worn cloak while the account gives it.
ACCOUNT.rewards = {"cloak:supporter"}
send_list(bindings(), {ACCOUNT, OTHER})
local cmd = commands.achievement
check(cmd.func("admin", "grant Rowan supporter"), "A5 the achievement granted")
check(A.select_cloak(rowan, "supporter"), "A5 worn")
applied = {}
local ok, text = cmd.func("admin", "revoke Rowan supporter")
check(ok, "A5 revoked: " .. tostring(text))
eq(A.selected_cloak(rowan), "supporter", "A5 still worn: the account gives it")
eq(#applied, 0, "A5 nothing to redraw")
-- The account's loss now takes it off.
ACCOUNT.rewards = {}
send_list(bindings(), {ACCOUNT, OTHER})
eq(A.selected_cloak(rowan), "none", "A5 the account's loss takes it off")
-- Earned again and the account gives it: the account's loss keeps it.
cmd.func("admin", "grant Rowan supporter")
ACCOUNT.rewards = {"cloak:supporter"}
send_list(bindings(), {ACCOUNT, OTHER})
A.select_cloak(rowan, "supporter")
ACCOUNT.rewards = {}
send_list(bindings(), {ACCOUNT, OTHER})
eq(A.selected_cloak(rowan), "supporter", "A6 the earned cloak stays worn after the account's loss")
-- An unlink returns the page to "not linked".
send_list({}, {})
fs = view(rowan)
has(fs, ";grug_account_link;Check code]", "A7 unlinked: the code again")
check(listed(rowan), "A7 the earned cloak stays")

--
-- S: no link code in the log
--

for _, line in ipairs(logs) do
	check(not line:find("WXYZ2", 1, true) and not line:find("ABCDEFGH23", 1, true),
		"S no code in the log: " .. line)
end

print(("r79_page: %d checks passed"):format(checks))
