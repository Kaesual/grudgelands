-- Round 79 lane ACC portable test (LuaJIT): website accounts, phase 1, the
-- game side (docs/technical/web-accounts.md, round79-plan.md §3.1, §3.3).
--
--   luajit tools/r79_acc/portable_test.lua [repo]
--
-- Loads the REAL grug_accounts/init.lua with its model.lua, flow.lua and
-- page.lua on a fake engine with a clock, core.after, mod storage, player
-- meta and the join, leave and arrival hooks. Checks:
--   L  the list: validation (malformed rows, an unknown account, a name twice
--      in any case, escapes and length of the account name, reward ids),
--      versions (none, the same, a lower one, stored with dropped rows);
--   I  the character id: all three index states, the adoption of a binding's
--      id, a tombstone, the meta winning over the index, the id at join in
--      character creation, a mismatched binding ignored and logged once;
--   U  an unlink, an account deleted and renamed, unknown reward ids kept
--      and granting nothing, then granting in a game that knows them;
--   P  persistence: a fresh load from the stored strings;
--   N  the binding and reward notices: online, after an offline change at
--      the next join, deferred by character creation until the arrival, the
--      own request's success line instead of the binding line;
--   C  code normalization;
--   F  every state transition of the link flow: the events and their fields,
--      the answer table per state, both timeouts, a cancel by the player, on
--      leave and by a new request, a direct binding ending open requests, the
--      attempt limit and its window, stale and duplicate answers, the
--      refusal texts, can_link;
--   K  the change callbacks and the link-state callbacks;
--   S  no code in the server log;
--   D  the deletion (Round 83): the tombstone, also without an entry; the
--      binding row leaves the stored list at once, the version stays, no log
--      line; half_deleted (a tombstone beside a used login).

local repo = arg and arg[1] or "."
local MOD = repo .. "/mods/PLAYER/grug_accounts"
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
local real_time = os.time
os.time = function() return clock end -- luacheck: ignore

local world
local all_logs = {} -- every boot's server log
local function new_storage(rows)
	rows = rows or {}
	return {rows = rows,
		get_string = function(self, key) return self.rows[key] or "" end,
		set_string = function(self, key, value)
			if value == "" then self.rows[key] = nil else self.rows[key] = value end
		end}
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

_G.core = {
	log = function(level, text)
		world.logs[#world.logs + 1] = {level, text}
		all_logs[#all_logs + 1] = text
	end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = deserialize,
	get_modpath = function() return MOD end,
	get_current_modname = function() return "grug_accounts" end,
	get_mod_storage = function() return world.storage end,
	sha1 = function(text) return ("%040x"):format(#text) end,
	get_us_time = function() return 1 end,
	after = function(delay, func)
		world.timers[#world.timers + 1] = {at = clock + delay, func = func}
	end,
	get_player_by_name = function(name) return world.players[name] end,
	-- Round 83: the logins half_deleted reads.
	get_auth_handler = function()
		return {get_auth = function(name) return world.auth[name] end}
	end,
}
for _, kind in ipairs({"joinplayer", "leaveplayer", "mods_loaded"}) do
	core["register_on_" .. kind] = function(func) world.hooks[kind] = func end
end
-- Round 81: the shared text rules (raw field cut, UTF-8 rule).
_G.grug_core = {text = dofile(repo .. "/mods/CORE/grug_core/text.lua"), feed = function(player, kind, text)
	world.feed[#world.feed + 1] = {player:get_player_name(), kind, text}
end}
_G.grug_classes = {
	get_class = function(player) return player.class end,
	register_on_arrival = function(func) world.hooks.arrival = func end,
}
_G.grug_factions = {get_faction = function(player) return player.faction end}

local function boot(storage)
	world = {storage = storage or new_storage(), logs = {}, timers = {}, hooks = {}, players = {},
		feed = {}, auth = {}}
	_G.grug_accounts = nil
	dofile(MOD .. "/init.lua")
	grug_accounts.register_reward("cloak:supporter", {kind = "cloak", name = "Supporter Cloak",
		icon = "grug_cloak_supporter.png", hint = "Choose it on the Character page."})
	world.hooks.mods_loaded()
	world.events = {}
	grug_accounts.attach(function(event) world.events[#world.events + 1] = event end)
end

local function new_player(name, ready, meta)
	local data = meta or {}
	local player = {name = name, class = ready ~= false and "priest" or nil,
		faction = ready ~= false and "accord" or nil, data = data}
	function player:get_player_name() return self.name end
	function player:get_meta()
		return {get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value end}
	end
	return player
end

local function join(player)
	world.players[player.name] = player
	world.hooks.joinplayer(player)
	return player
end

local function leave(player)
	world.hooks.leaveplayer(player)
	world.players[player.name] = nil
end

-- Runs every timer due by now, the ones it schedules included.
local function advance(seconds)
	clock = clock + seconds
	local ran = true
	while ran do
		ran = false
		for index, timer in ipairs(world.timers) do
			if timer.at <= clock then
				table.remove(world.timers, index)
				timer.func()
				ran = true
				break
			end
		end
	end
end

local function feed_of(name)
	local lines = {}
	for _, row in ipairs(world.feed) do
		if row[1] == name then lines[#lines + 1] = row[3] end
	end
	return lines
end

local function last_event() return world.events[#world.events] end

local ID_ROWAN = ("a"):rep(32)
local ID_ELARA = ("b"):rep(32)
local ID_OTHER = ("c"):rep(32)
local CODE = "ABCDE-FGH23" -- synthetic, never a real code

local function list(version, characters, accounts)
	return {version = version, characters = characters, accounts = accounts}
end
local JAN = {id = "a_1842", name = "jan", rewards = {"cloak:supporter"}}

-- L. The list -----------------------------------------------------------------
do
	boot()
	eq(grug_accounts.accounts_version(), 0, "L no list yet")
	eq(grug_accounts.enabled(), false, "L no list: not enabled")
	eq(grug_accounts.apply_list({characters = {}}), false, "L no version: ignored whole")
	eq(grug_accounts.apply_list({version = "3"}), false, "L a text version is no version")
	eq(grug_accounts.accounts_version(), 0, "L still none")
	local long = "\27(c@#ff0000)" .. ("n"):rep(70) .. "\n\1x"
	local before = #world.logs
	eq(grug_accounts.apply_list(list(3, {
		{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"},
		{name = "bad name", character_id = ID_ROWAN, account_id = "a_1842"},
		{name = "Short", character_id = ("A"):rep(32), account_id = "a_1842"},
		{name = "Shorter", character_id = ("a"):rep(31), account_id = "a_1842"},
		{name = "Spaced", character_id = ID_ROWAN, account_id = "a b"},
		{name = "Orphan", character_id = ID_ROWAN, account_id = "nobody"},
		{name = "Twin", character_id = ID_ELARA, account_id = "a_1842"},
		{name = "twin", character_id = ID_OTHER, account_id = "a_1842"},
		"nonsense",
	}, {
		{id = "a_1842", name = "jan", rewards = {"cloak:supporter", "cloak:future", "Bad", 5}},
		{id = "long", name = long, rewards = nil},
		{id = "a_1842", name = "second"},
		{id = "x y", name = "bad"},
		{id = "noname"},
	})), true, "L applied")
	eq(grug_accounts.accounts_version(), 3, "L the version is stored with rows dropped")
	eq(grug_accounts.enabled(), true, "L enabled with the bridge and a list")
	check(#world.logs - before >= 9, "L every dropped row has a warning")
	eq(grug_accounts.account_of("Rowan").id, "a_1842", "L a good row")
	eq(grug_accounts.account_of("rowan").name, "jan", "L names compare without case")
	for _, name in ipairs({"bad name", "Short", "Shorter", "Spaced", "Orphan", "Twin", "twin"}) do
		eq(grug_accounts.account_of(name), nil, "L dropped: " .. name)
	end
	local stored = deserialize(world.storage.rows.list)
	local long_account
	for _, account in ipairs(stored.accounts) do
		if account.id == "long" then long_account = account end
	end
	eq(#long_account.name, 64, "L an account name is cut to 64")
	check(not long_account.name:find("[%c\27]"), "L and cleaned")
	eq(stored.accounts[1].name, "jan", "L the first of two account rows wins")
	eq(#stored.accounts, 2, "L a malformed account row is dropped")
	eq(table.concat(stored.accounts[1].rewards, ","), "cloak:supporter,cloak:future",
		"L an unknown reward id stays stored, a malformed one goes")
	eq(grug_accounts.apply_list(list(3, {}, {})), false, "L the held version is not applied again")
	eq(grug_accounts.account_of("Rowan").id, "a_1842", "L so nothing changed")
	eq(grug_accounts.apply_list(list(2, nil, nil)), true, "L a lower version is applied")
	eq(grug_accounts.accounts_version(), 2, "L and held")
	eq(grug_accounts.account_of("Rowan"), nil, "L null arrays are empty lists")
end

-- I. The character id ---------------------------------------------------------
do
	boot()
	local rowan = join(new_player("Rowan"))
	local id = rowan.data["grug_accounts:character_id"]
	check(id and id:find("^[0-9a-f]+$") and #id == 32, "I a new id: 32 lower-case hex digits")
	eq(world.storage.rows["id:rowan"], id, "I the index holds it")
	eq(grug_accounts.character_id(rowan), id, "I character_id")
	leave(rowan)
	join(rowan)
	eq(rowan.data["grug_accounts:character_id"], id, "I never changed")

	-- No index entry and a binding: its id is adopted.
	grug_accounts.apply_list(list(5, {{name = "Elara", character_id = ID_ELARA, account_id = "a_1842"}},
		{JAN}))
	eq(grug_accounts.account_of("Elara").id, "a_1842", "I no index entry: the binding counts offline")
	local elara = join(new_player("Elara"))
	eq(elara.data["grug_accounts:character_id"], ID_ELARA, "I no entry: the binding's id is adopted")
	eq(world.storage.rows["id:elara"], ID_ELARA, "I and indexed")

	-- An index id and a lost meta: the index's id comes back.
	leave(elara)
	elara.data["grug_accounts:character_id"] = nil
	join(elara)
	eq(elara.data["grug_accounts:character_id"], ID_ELARA, "I an index id: the character takes it")
	leave(elara)

	-- The index names another id: the binding does not count, offline or online.
	world.storage.rows["id:elara"] = ID_OTHER
	local logged = #world.logs
	eq(grug_accounts.account_of("Elara"), nil, "I the index names another id: no binding")
	eq(grug_accounts.account_of("Elara"), nil, "I again")
	eq(#world.logs, logged + 1, "I the mismatch is logged once")
	-- At a join the meta wins and the index is rewritten.
	join(elara)
	eq(world.storage.rows["id:elara"], ID_ELARA, "I the meta wins over the index")
	check(world.logs[#world.logs][2]:find("the meta wins", 1, true), "I with a log line")
	eq(grug_accounts.account_of("Elara").id, "a_1842", "I so the binding counts again")
	leave(elara)

	-- A tombstone: no binding counts and nothing is adopted.
	world.storage.rows["id:elara"] = "tombstone"
	eq(grug_accounts.account_of("Elara"), nil, "I a tombstone: no binding counts")
	local again = join(new_player("Elara"))
	local fresh = again.data["grug_accounts:character_id"]
	check(fresh ~= ID_ELARA and #fresh == 32, "I a tombstone: a new id, none adopted")
	eq(world.storage.rows["id:elara"], fresh, "I the tombstone is replaced by the new id")
	eq(grug_accounts.account_of("Elara"), nil, "I the old binding names another id")
	leave(again)

	-- During character creation the id is given at join too.
	local newbie = join(new_player("Newbie", false))
	eq(#newbie.data["grug_accounts:character_id"], 32, "I an id in character creation")
	-- character_id before the join hook gives the same id the join keeps.
	local early = new_player("Early")
	world.players.Early = early
	local first = grug_accounts.character_id(early)
	world.hooks.joinplayer(early)
	eq(early.data["grug_accounts:character_id"], first, "I an early read and the join agree")
end

-- D. The deletion of a character (Round 83) ------------------------------------
do
	boot()
	grug_accounts.apply_list(list(7, {
		{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"},
		{name = "Elara", character_id = ID_ELARA, account_id = "a_1842"}}, {JAN}))
	local rowan = join(new_player("Rowan", true, {["grug_accounts:character_id"] = ID_ROWAN}))
	eq(grug_accounts.index_entry("ROWAN"), ID_ROWAN, "D index_entry, any letter case")
	leave(rowan)
	local logged = #world.logs
	grug_accounts.forget_character("Rowan")
	eq(world.storage.rows["id:rowan"], grug_accounts.TOMBSTONE, "D the tombstone")
	eq(grug_accounts.account_of("Rowan"), nil, "D its binding counts no more")
	local stored = deserialize(world.storage.rows.list)
	eq(#stored.characters, 1, "D its row left the stored list")
	eq(stored.characters[1].name, "Elara", "D the other row stays")
	eq(stored.version, 7, "D the version stays")
	eq(grug_accounts.accounts_version(), 7, "D also in memory")
	eq(grug_accounts.account_of("Elara").id, "a_1842", "D another binding still counts")
	eq(#world.logs, logged, "D no log line")
	-- Always a tombstone, also without an entry (no binding is adopted).
	eq(grug_accounts.index_entry("Elara"), nil, "D Elara never joined")
	grug_accounts.forget_character("Elara")
	eq(world.storage.rows["id:elara"], "tombstone", "D a tombstone without an entry")
	local elara = join(new_player("Elara"))
	check(elara.data["grug_accounts:character_id"] ~= ID_ELARA, "D a new Elara adopts nothing")
	-- The stored list after a restart lacks the row.
	boot(world.storage)
	eq(grug_accounts.account_of("Rowan"), nil, "D across a restart")
	-- half_deleted: a tombstone beside a login that was used.
	world.auth.Rowan = {last_login = 1794000000}
	world.storage.rows["id:rowan"] = "tombstone"
	eq(grug_accounts.half_deleted("Rowan"), true, "D half deleted")
	world.auth.Rowan.last_login = -1
	eq(grug_accounts.half_deleted("Rowan"), false, "D a login never used is a new character's")
	world.auth.Rowan = nil
	eq(grug_accounts.half_deleted("Rowan"), false, "D no login: deleted")
	world.auth.Rowan = {last_login = 1794000000}
	world.storage.rows["id:rowan"] = ID_ROWAN
	eq(grug_accounts.half_deleted("Rowan"), false, "D an id: a character")
end

-- U. Unlink, delete, rename, unknown rewards ----------------------------------
do
	boot()
	local changes = {}
	grug_accounts.register_on_change(function(names) changes[#changes + 1] = table.concat(names, ",") end)
	grug_accounts.apply_list(list(1, {
		{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"},
		{name = "Elara", character_id = ID_ELARA, account_id = "a_1842"}},
		{{id = "a_1842", name = "jan", rewards = {"cloak:future"}}}))
	eq(changes[1], "Elara,Rowan", "K the change callback names both")
	eq(grug_accounts.has_reward("Rowan", "cloak:future"), false, "U an unknown reward grants nothing")
	eq(#grug_accounts.rewards_of("Rowan"), 0, "U nor is it listed")
	grug_accounts.apply_list(list(2, {
		{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"},
		{name = "Elara", character_id = ID_ELARA, account_id = "a_1842"}},
		{{id = "a_1842", name = "jan", rewards = {"cloak:future", "cloak:supporter"}}}))
	eq(changes[2], "Elara,Rowan", "K a reward change names both")
	eq(grug_accounts.has_reward("Elara", "cloak:supporter"), true, "U a granted reward")
	local rewards = grug_accounts.rewards_of("Elara")
	eq(#rewards, 1, "U rewards_of lists what the catalogue knows")
	eq(rewards[1].id .. "|" .. rewards[1].kind .. "|" .. rewards[1].name,
		"cloak:supporter|cloak|Supporter Cloak", "U its fields")
	grug_accounts.apply_list(list(3, {{name = "Elara", character_id = ID_ELARA, account_id = "a_1842"}},
		{{id = "a_1842", name = "jan", rewards = {"cloak:future", "cloak:supporter"}}}))
	eq(changes[3], "Rowan", "K an unlink names only the unlinked")
	eq(grug_accounts.account_of("Rowan"), nil, "U unlinked")
	eq(grug_accounts.has_reward("Rowan", "cloak:supporter"), false, "U the rewards go with it")
	grug_accounts.apply_list(list(4, {{name = "Elara", character_id = ID_ELARA, account_id = "a_1842"}},
		{{id = "a_1842", name = "Jan the Second", rewards = {"cloak:future", "cloak:supporter"}}}))
	eq(changes[4], "Elara", "K a rename is a change")
	eq(grug_accounts.account_of("Elara").name, "Jan the Second", "U renamed")
	grug_accounts.apply_list(list(5, {}, {}))
	eq(changes[5], "Elara", "K an account deleted")
	eq(grug_accounts.account_of("Elara"), nil, "U deleting the account unlinks")
	grug_accounts.apply_list(list(6, {}, {{id = "a_1842", name = "jan", rewards = {}}}))
	eq(#changes, 5, "K no callback when no binding changed")

	-- A game that knows the reward: the stored id grants it (P with it).
	grug_accounts.apply_list(list(7, {{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"}},
		{{id = "a_1842", name = "jan", rewards = {"emote:wave"}}}))
	local stored = world.storage
	boot(stored)
	eq(grug_accounts.accounts_version(), 7, "P the version across a reload")
	eq(grug_accounts.account_of("Rowan").id, "a_1842", "P the binding across a reload")
	eq(grug_accounts.has_reward("Rowan", "emote:wave"), false, "P unknown to this game")
	world = {storage = stored, logs = {}, timers = {}, hooks = {}, players = {}, feed = {}}
	_G.grug_accounts = nil
	dofile(MOD .. "/init.lua")
	grug_accounts.register_reward("emote:wave", {kind = "emote", name = "Wave", icon = "x.png", hint = "h"})
	world.hooks.mods_loaded()
	eq(grug_accounts.has_reward("Rowan", "emote:wave"), true, "U a later game grants the stored id")
	eq(grug_accounts.enabled(), false, "P inert without the bridge: not enabled")
	eq(pcall(grug_accounts.register_reward, "cloak:late", {kind = "cloak", name = "Late", icon = "x",
		hint = "h"}), false, "U register_reward only at load time")
	eq(pcall(grug_accounts.register_reward, "Bad", {}), false, "U a bad reward id")
end

-- N. Notices -------------------------------------------------------------------
do
	boot()
	local rowan = join(new_player("Rowan"))
	local rid = rowan.data["grug_accounts:character_id"]
	eq(#feed_of("Rowan"), 0, "N nothing for an unlinked first join")
	eq(rowan.data["grug_accounts:seen"], "|", "N what it saw is stored")
	-- A direct binding while online.
	grug_accounts.apply_list(list(1, {{name = "Rowan", character_id = rid, account_id = "a_1842"}}, {JAN}))
	local lines = feed_of("Rowan")
	eq(lines[1], "This character is now linked to the website account jan.", "N the binding line")
	eq(lines[2], "Your account gives you: Supporter Cloak.", "N the reward line")
	eq(#lines, 2, "N once")
	grug_accounts.apply_list(list(2, {{name = "Rowan", character_id = rid, account_id = "a_1842"}},
		{{id = "a_1842", name = "jan2", rewards = {"cloak:supporter"}}}))
	eq(#feed_of("Rowan"), 2, "N a rename gives no line")
	grug_accounts.apply_list(list(3, {{name = "Rowan", character_id = rid, account_id = "a_1842"}},
		{{id = "a_1842", name = "jan", rewards = {}}}))
	eq(feed_of("Rowan")[3], "Your account no longer gives you: Supporter Cloak.", "N a revoked reward")
	grug_accounts.apply_list(list(4, {}, {}))
	eq(feed_of("Rowan")[4], "This character is no longer linked to a website account.", "N the unlink line")
	eq(#feed_of("Rowan"), 4, "N nothing else")

	-- Changed while offline: reported at the next join, once.
	leave(rowan)
	grug_accounts.apply_list(list(5, {{name = "Rowan", character_id = rid, account_id = "a_1842"}}, {JAN}))
	eq(#feed_of("Rowan"), 4, "N offline: no line")
	join(rowan)
	eq(feed_of("Rowan")[5], "This character is now linked to the website account jan.", "N at the next join")
	eq(feed_of("Rowan")[6], "Your account gives you: Supporter Cloak.", "N with the reward")
	leave(rowan)
	join(rowan)
	eq(#feed_of("Rowan"), 6, "N once only")
	leave(rowan)
	grug_accounts.apply_list(list(6, {}, {}))
	join(rowan)
	eq(feed_of("Rowan")[7], "This character is no longer linked to a website account.", "N an offline unlink")
	eq(feed_of("Rowan")[8], "Your account no longer gives you: Supporter Cloak.", "N and its reward")

	-- Character creation: stored and counted, reported after the arrival.
	local newbie = join(new_player("Newbie", false))
	local nid = newbie.data["grug_accounts:character_id"]
	local changes = 0
	grug_accounts.register_on_change(function() changes = changes + 1 end)
	grug_accounts.apply_list(list(7, {{name = "Newbie", character_id = nid, account_id = "a_1842"}}, {JAN}))
	eq(grug_accounts.account_of("Newbie").id, "a_1842", "N bound in creation")
	eq(grug_accounts.has_reward("Newbie", "cloak:supporter"), true, "N with its rewards")
	eq(#feed_of("Newbie"), 0, "N creation is not disturbed")
	eq(changes, 1, "N the change callback runs")
	eq(newbie.data["grug_accounts:seen"], nil, "N nothing seen yet")
	newbie.class, newbie.faction = "mage", "throng"
	world.hooks.arrival(newbie)
	eq(feed_of("Newbie")[1], "This character is now linked to the website account jan.", "N after the arrival")
	eq(#feed_of("Newbie"), 2, "N with the reward line")
	-- Created but not arrived yet: class and faction are stored, the arriving
	-- mark is still set; notices and linking wait until the arrival.
	local arriving = join(new_player("Arriving", false))
	arriving.class, arriving.faction = "warrior", "accord"
	arriving.data["grug_classes:arriving"] = "1"
	grug_accounts.apply_list(list(7.5, {
		{name = "Newbie", character_id = nid, account_id = "a_1842"},
		{name = "Arriving", character_id = arriving.data["grug_accounts:character_id"], account_id = "a_1842"}},
		{JAN}))
	eq(#feed_of("Arriving"), 0, "N the arrival wait is creation: no line")
	local ok, message = grug_accounts.can_link(arriving)
	eq(message, "Finish creating your character first. You can link it afterwards.",
		"N the arrival wait cannot link")
	check(not ok, "N refused")
	leave(arriving)
	join(arriving)
	eq(#feed_of("Arriving"), 0, "N a rejoin in the arrival wait: no line")
	arriving.data["grug_classes:arriving"] = ""
	world.hooks.arrival(arriving)
	eq(feed_of("Arriving")[1], "This character is now linked to the website account jan.",
		"N the line after the arrival")
	eq(#feed_of("Arriving"), 2, "N with the reward line")
	-- A character still in creation at a later join waits too.
	leave(newbie)
	local other = join(new_player("Fresh", false))
	grug_accounts.apply_list(list(8, {
		{name = "Newbie", character_id = nid, account_id = "a_1842"},
		{name = "Fresh", character_id = other.data["grug_accounts:character_id"], account_id = "a_1842"}},
		{JAN}))
	leave(other)
	join(other)
	eq(#feed_of("Fresh"), 0, "N a join in creation waits as well")
end

-- C. Code normalization ---------------------------------------------------------
do
	boot()
	local rowan = join(new_player("Rowan"))
	grug_accounts.apply_list(list(1, {}, {}))
	local accepted = {"ABCDE-FGH23", "abcde-fgh23", "ABCDEFGH23", " abc de-fg h23 ", "zzzzzzzzzz"}
	for _, text in ipairs(accepted) do
		world.events = {}
		eq(grug_accounts.request_link(rowan, text), true, "C accepted: " .. text)
		local event = world.events[#world.events]
		eq(event.type, "account.link_request", "C a request")
		check(event.code:find("^[A-Z2-9]+$") and #event.code == 10, "C sent normalized: " .. text)
		grug_accounts.cancel_link(rowan)
		leave(rowan)
		join(rowan) -- a relog resets the attempt limit
	end
	eq(world.events[1].code, "ZZZZZZZZZZ", "C upper case")
	for _, text in ipairs({"ABCDE-FGH2", "ABCDE-FGH234", "0BCDE-FGH23", "OBCDE-FGH23", "IBCDE-FGH23",
			"1BCDE-FGH23", "ABCDE_FGH23", "", ("A"):rep(65), "ÄBCDE-FGH23"}) do
		world.events = {}
		local ok, message = grug_accounts.request_link(rowan, text)
		eq(ok, false, "C refused at once: " .. text)
		eq(message, "A code has 10 letters and digits, as the website shows it.", "C its text")
		eq(#world.events, 0, "C without a request")
	end
	eq(grug_accounts.link_state(rowan).state, "refused", "C the status line")
	eq(grug_accounts.request_link(rowan, 5), false, "C not a string")
end

-- F. The link flow ----------------------------------------------------------------
do
	boot()
	local states = {}
	grug_accounts.register_on_link_state(function(player)
		states[#states + 1] = player:get_player_name() .. ":" .. grug_accounts.link_state(player).state
	end)
	local rowan = join(new_player("Rowan"))
	local rid = rowan.data["grug_accounts:character_id"]
	local function answer(args) return (grug_accounts.link_answer(args)) end

	-- Not enabled: without a list nothing is sent.
	local ok, message = grug_accounts.can_link(rowan)
	eq(ok, false, "F not enabled without a list")
	eq(message, "Linking is not available right now.", "F its text")
	eq(grug_accounts.request_link(rowan, CODE), false, "F no request without a list")
	eq(#world.events, 0, "F nothing sent")
	grug_accounts.apply_list(list(1, {}, {}))
	eq(grug_accounts.can_link(rowan), true, "F can link")
	eq(grug_accounts.link_state(rowan).state, "refused", "F the refusal is the status line")

	-- request -> checking
	eq(grug_accounts.request_link(rowan, CODE), true, "F request")
	local event = last_event()
	eq(event.type, "account.link_request", "F the request event")
	eq(event.name, "Rowan", "F its name")
	eq(event.character_id, rid, "F its character id")
	eq(event.code, "ABCDEFGH23", "F its normalized code")
	check(event.request_id:find("^[0-9a-f]+$") and #event.request_id == 16, "F a 16-hex request id")
	local R = event.request_id
	eq(grug_accounts.link_state(rowan).state, "checking", "F checking")
	eq(states[#states], "Rowan:checking", "F the state callback")

	-- checking takes offer or refused; others are invalid_args and the request stays.
	eq(answer({request_id = R, name = "Rowan", outcome = "linked", account_name = "jan"}),
		"invalid_args", "F linked in checking")
	eq(grug_accounts.link_state(rowan).state, "checking", "F still open")
	eq(answer({request_id = R, name = "Elara", outcome = "offer", account_name = "jan"}),
		"invalid_args", "F another character's name")
	eq(answer({request_id = R, name = "Rowan", outcome = "maybe"}), "invalid_args", "F an unknown outcome")
	eq(answer({request_id = R, name = "Rowan", outcome = "offer"}), "invalid_args", "F offer without a name")
	eq(answer({request_id = R, name = "Rowan", outcome = "refused"}), "invalid_args", "F refused without a reason")
	eq(answer({request_id = "XYZ", name = "Rowan", outcome = "offer", account_name = "jan"}),
		"invalid_args", "F a malformed request id")
	eq(answer({request_id = R, outcome = "offer", account_name = "jan"}), "invalid_args", "F no name")
	eq(answer({request_id = ("0"):rep(16), name = "Rowan", outcome = "offer", account_name = "jan"}),
		"refused", "F no open request with this id")
	eq(answer({request_id = ("0"):rep(16), name = "Gone", outcome = "offer", account_name = "jan"}),
		"not_online", "F a character that left")
	eq(grug_accounts.link_state(rowan).state, "checking", "F none of that changed the request")

	-- offer
	local long = ("N"):rep(70) .. "\27(c@#f00)"
	eq(answer({request_id = R, name = "Rowan", outcome = "offer", account_name = long}), "ok", "F offer")
	local state = grug_accounts.link_state(rowan)
	eq(state.state, "offer", "F offer shown")
	eq(#state.account_name, 64, "F account_name cut to 64 and cleaned")
	eq(state.expires_at, clock + 120, "F the offer's two minutes")
	for _, outcome in ipairs({"offer", "linked", "refused"}) do
		eq(answer({request_id = R, name = "Rowan", outcome = outcome, account_name = "jan",
			reason = "other"}), "invalid_args", "F nothing is valid in offer: " .. outcome)
	end
	eq(grug_accounts.link_state(rowan).state, "offer", "F the offer stays")

	-- Cancel goes back; the next request may use the code again.
	eq(grug_accounts.cancel_link(rowan), true, "F cancel")
	eq(last_event().type, "account.link_cancel", "F the cancel event")
	eq(last_event().request_id, R, "F for the request")
	eq(last_event().name, "Rowan", "F with the name")
	eq(grug_accounts.link_state(rowan).state, "idle", "F back to idle")
	eq(answer({request_id = R, name = "Rowan", outcome = "offer", account_name = "jan"}),
		"refused", "F an answer after the cancel")
	eq(grug_accounts.cancel_link(rowan), false, "F nothing to cancel")
	eq(grug_accounts.confirm_link(rowan), false, "F nothing to confirm")

	-- request, offer, confirm -> confirming
	grug_accounts.request_link(rowan, CODE)
	R = last_event().request_id
	answer({request_id = R, name = "Rowan", outcome = "offer", account_name = "jan"})
	eq(grug_accounts.confirm_link(rowan), true, "F confirm")
	event = last_event()
	eq(event.type, "account.link_confirm", "F the confirm event")
	eq(event.request_id .. event.name .. event.character_id, R .. "Rowan" .. rid, "F its fields")
	eq(event.code, nil, "F no code in the confirmation")
	eq(grug_accounts.link_state(rowan).state, "confirming", "F confirming")
	eq(answer({request_id = R, name = "Rowan", outcome = "offer", account_name = "jan"}),
		"invalid_args", "F offer in confirming")
	eq(answer({request_id = R, name = "Rowan", outcome = "linked", account_name = "jan"}),
		"invalid_args", "F linked without the binding in the list")
	eq(grug_accounts.link_state(rowan).state, "confirming", "F waits for the list")
	-- The list holds the binding: linked, with the own success line.
	local feeds = #feed_of("Rowan")
	grug_accounts.apply_list(list(2, {{name = "Rowan", character_id = rid, account_id = "a_1842"}},
		{{id = "a_1842", name = "Jan From The List", rewards = {}}}))
	state = grug_accounts.link_state(rowan)
	eq(state.state, "linked", "F the list ends it as linked")
	eq(state.message, "Linked to the website account Jan From The List.", "F the name from the list")
	eq(feed_of("Rowan")[feeds + 1], "Linked to the website account Jan From The List.",
		"F the success line instead of the binding line")
	eq(#feed_of("Rowan"), feeds + 1, "F only that line")
	eq(answer({request_id = R, name = "Rowan", outcome = "linked", account_name = "jan"}), "ok",
		"F the linked answer after its list")
	eq(answer({request_id = R, name = "Rowan", outcome = "refused", reason = "other"}), "refused",
		"F a second answer after the end")
	eq(answer({request_id = R, name = "Rowan", outcome = "linked", account_name = "jan"}), "refused",
		"F a second linked answer after the end")
	ok, message = grug_accounts.can_link(rowan)
	eq(message, "This character is already linked to a website account.", "F a linked character cannot link")
	eq(grug_accounts.request_link(rowan, CODE), false, "F so no request")

	-- Refusals in checking and confirming, an unknown reason as other.
	local elara = join(new_player("Elara"))
	local eid = elara.data["grug_accounts:character_id"]
	for reason, text in pairs({unknown_code = "The website does not know this code. Please check it.",
			expired_code = "This code has expired. Please create a new one on the website.",
			used_code = "This code was already used or replaced. Please create a new one on the website.",
			account_full = "That website account already has 10 characters.",
			already_linked = "This character is already linked to a website account.",
			too_many_attempts = "Too many attempts on the website. Please wait a while and try again.",
			other = "The website refused the link. Please try again later.",
			strange = "The website refused the link. Please try again later."}) do
		leave(elara)
		join(elara)
		grug_accounts.request_link(elara, CODE)
		R = last_event().request_id
		eq(answer({request_id = R, name = "Elara", outcome = "refused", reason = reason}), "ok",
			"F refused: " .. reason)
		state = grug_accounts.link_state(elara)
		eq(state.state, "refused", "F refused state: " .. reason)
		eq(state.message, text, "F the refusal text: " .. reason)
		eq(answer({request_id = R, name = "Elara", outcome = "refused", reason = reason}), "refused",
			"F a duplicate answer: " .. reason)
	end
	grug_accounts.request_link(elara, CODE)
	R = last_event().request_id
	answer({request_id = R, name = "Elara", outcome = "offer", account_name = "jan"})
	grug_accounts.confirm_link(elara)
	eq(answer({request_id = R, name = "Elara", outcome = "refused", reason = "used_code"}), "ok",
		"F refused in confirming")
	eq(grug_accounts.link_state(elara).message,
		"This code was already used or replaced. Please create a new one on the website.", "F its text")

	-- Timeouts: 30 s without an answer, then 2 minutes without a confirmation, 30 s confirming.
	leave(elara)
	join(elara)
	grug_accounts.request_link(elara, CODE)
	R = last_event().request_id
	advance(29)
	eq(grug_accounts.link_state(elara).state, "checking", "F 29 s: still waiting")
	advance(1)
	state = grug_accounts.link_state(elara)
	eq(state.state, "refused", "F 30 s: given up")
	eq(state.message, "The website did not answer. Please try again later.", "F the timeout text")
	eq(last_event().type .. last_event().request_id, "account.link_cancel" .. R, "F with a cancel")
	eq(answer({request_id = R, name = "Elara", outcome = "offer", account_name = "jan"}), "refused",
		"F a late answer")
	grug_accounts.request_link(elara, CODE)
	R = last_event().request_id
	advance(20)
	answer({request_id = R, name = "Elara", outcome = "offer", account_name = "jan"})
	advance(119)
	eq(grug_accounts.link_state(elara).state, "offer", "F 119 s: the offer stands (the request's timer is gone)")
	advance(1)
	state = grug_accounts.link_state(elara)
	eq(state.message, "The offer lapsed. Please enter the code again.", "F 2 minutes: the offer lapsed")
	eq(last_event().type .. last_event().request_id, "account.link_cancel" .. R, "F with a cancel")
	grug_accounts.request_link(elara, CODE)
	R = last_event().request_id
	answer({request_id = R, name = "Elara", outcome = "offer", account_name = "jan"})
	advance(100)
	grug_accounts.confirm_link(elara)
	advance(29)
	eq(grug_accounts.link_state(elara).state, "confirming", "F confirming: 29 s")
	advance(1)
	eq(grug_accounts.link_state(elara).message, "The website did not answer. Please try again later.",
		"F confirming: 30 s")
	eq(last_event().type, "account.link_cancel", "F with a cancel")
	-- A timer that fires early waits for its deadline.
	grug_accounts.request_link(elara, CODE)
	local timer = world.timers[#world.timers]
	timer.at = clock
	advance(0)
	eq(grug_accounts.link_state(elara).state, "checking", "F an early timer waits")
	advance(30)
	eq(grug_accounts.link_state(elara).state, "refused", "F then ends it")

	-- The attempt limit: five requests in 10 minutes.
	leave(elara)
	join(elara)
	for index = 1, 5 do
		eq(grug_accounts.request_link(elara, CODE), true, "F attempt " .. index)
		advance(10)
	end
	-- A new request cancelled the old one first.
	local types = {}
	for index = #world.events - 2, #world.events do types[#types + 1] = world.events[index].type end
	eq(table.concat(types, ","), "account.link_request,account.link_cancel,account.link_request",
		"F a new request cancels the open one first")
	ok, message = grug_accounts.request_link(elara, CODE)
	eq(ok, false, "F the sixth is refused")
	eq(message, "Too many link attempts. Please wait a few minutes and try again.", "F its text")
	eq(grug_accounts.link_state(elara).state, "checking", "F the open request goes on")
	advance(560)
	eq(grug_accounts.request_link(elara, CODE), true, "F the window moves on")

	-- Leaving cancels an open request.
	R = last_event().request_id
	leave(elara)
	eq(last_event().type .. last_event().request_id, "account.link_cancel" .. R, "F a leave cancels")
	eq(answer({request_id = R, name = "Elara", outcome = "offer", account_name = "jan"}), "not_online",
		"F an answer after the leave")

	-- A direct binding ends an open request: in checking or offer with a cancel.
	join(elara)
	grug_accounts.request_link(elara, CODE)
	R = last_event().request_id
	answer({request_id = R, name = "Elara", outcome = "offer", account_name = "jan"})
	feeds = #feed_of("Elara")
	grug_accounts.apply_list(list(3, {
		{name = "Rowan", character_id = rid, account_id = "a_1842"},
		{name = "Elara", character_id = eid, account_id = "a_1842"}}, {JAN}))
	eq(last_event().type .. last_event().request_id, "account.link_cancel" .. R, "F a direct binding cancels")
	eq(grug_accounts.link_state(elara).state, "idle", "F the request ended")
	eq(feed_of("Elara")[feeds + 1], "This character is now linked to the website account jan.",
		"F the binding line")
	eq(answer({request_id = R, name = "Elara", outcome = "refused", reason = "already_linked"}), "refused",
		"F the website's late answer")

	-- In character creation: no request.
	local newbie = join(new_player("Newbie", false))
	ok, message = grug_accounts.can_link(newbie)
	eq(message, "Finish creating your character first. You can link it afterwards.", "F creation")
	eq(grug_accounts.request_link(newbie, CODE), false, "F so no request")
	eq(grug_accounts.link_state(newbie).message, message, "F as the status line")
end

-- S. No code reaches the log ---------------------------------------------------------
do
	for _, text in ipairs(all_logs) do
		check(not text:upper():find("ABCDE", 1, true) and not text:upper():find("FGH23", 1, true) and
			not text:find("ZZZZZ", 1, true), "S no code in the log")
	end
	check(#all_logs > 20, "S the log was read")
end

os.time = real_time -- luacheck: ignore
print(("r79_acc PASS (%d checks)"):format(checks))
