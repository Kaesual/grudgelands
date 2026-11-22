-- 0.69.1 web bridge portable test: mods/PLAYER/grug_bridge on a stub engine.
-- Loads the REAL link.lua, mirror.lua, bans.lua, commands.lua and init.lua,
-- grug_mail's real model.lua, store.lua and api.lua, and (Round 79) the real
-- grug_accounts, and checks:
--   A. the exchange: the waits (next_ms and its bounds, the backoff, 401 and
--      409), the request's fields, empty arrays, the first online list;
--   B. the queue: seq, ack, 100 events a request, the byte bound, the oldest
--      dropped and counted, an unwritable event lost alone;
--   C. at most once: a repeated id, a lost response, an expired command, an
--      error inside a command, a command without an id, an unknown type;
--   D. every command type with success and refusal;
--   E. the mail mirror through grug_mail's own save: new, changed, removed,
--      pruned, a resync, nothing when nothing changed;
--   F. bans: pre-join, case, expiry, the text, storage across a restart, an
--      online character disconnected with the exact text;
--   G. init.lua: inert without any of the three, with not one hook or
--      request; active, the chat hook (shout, commands, escapes, 500
--      characters, never returning true), the request's headers.
--   H. accounts (docs/technical/web-accounts.md): the capabilities, the
--      request's accounts_version and reward_catalog (resent until a 200,
--      again on resync), the online rows' character_id and account_id, the
--      list applied before the commands, account.link_answer's argument
--      checks and answer table, the events through the queue,
--      account.set_password (the entry's form with the cases of
--      tools/web_accounts/luanti_password.py's self-test, the auth entry, the
--      binding, the results, the feed line, a log line without the entry).
--   C (Round 83) also a command that answers later: silent while it runs,
--      one result, a second done ignored, expired, an error before or after
--      its defer.
--   I. character.delete (Round 83): the capability, the arguments, no such
--      character (another letter case, a wrong id), the refusals (the server
--      admin's character, a deletion running), too little time; online end
--      to end (the disconnect text, the pre-join block, a repeated delivery
--      silent, nothing cleared before the engine is done, the tombstone, the
--      binding row, the mailbox, one commit wait, the removal, the answer,
--      one log line with name, id and admin); offline without an id; an index
--      id without a login; expired while still online; back in the game
--      between the steps; a failing clear and remove_player answering 2
--      (error, the half-deleted pre-join refusal, the retry); the
--      record_login guard and the removal of a join without a login.
--   J. grug_mail (Round 83): every list pruned at the start; a deleted
--      character's box, sent list, tickets and index row go, others' letters
--      from it and reports of them stay.
--
-- Usage (repo root): luajit tools/r691_bridge/portable_test.lua [REPO]

local repo = arg[1] or "."
local MOD = repo .. "/mods/PLAYER/grug_bridge"
local MAIL = repo .. "/mods/PLAYER/grug_mail"
local ACCOUNTS = repo .. "/mods/PLAYER/grug_accounts"

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
-- JSON, as core.write_json and core.parse_json behave for this mod: an empty
-- table is null, integers have no fraction, object keys are sorted.
--
local function encode(value)
	local kind = type(value)
	if kind == "nil" then return "null" end
	if kind == "boolean" then return tostring(value) end
	if kind == "number" then
		if value % 1 == 0 then return ("%d"):format(value) end
		return tostring(value)
	end
	if kind == "string" then
		return '"' .. value:gsub('[%c"\\]', function(c)
			return ("\\u%04x"):format(c:byte())
		end) .. '"'
	end
	if kind ~= "table" then error("cannot encode a " .. kind) end
	if next(value) == nil then return "null" end
	local parts = {}
	if value[1] ~= nil then
		for index, item in ipairs(value) do parts[index] = encode(item) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys)
	for index, key in ipairs(keys) do
		parts[index] = encode(key) .. ":" .. encode(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function decode(text)
	local at = 1
	local function space() at = text:find("%S", at) or #text + 1 end
	local value
	local function str()
		at = at + 1
		local out = {}
		while true do
			local char = text:sub(at, at)
			if char == "" then error("unterminated string") end
			if char == '"' then at = at + 1 break end
			if char == "\\" then
				if text:sub(at + 1, at + 1) == "u" then
					out[#out + 1] = string.char(tonumber(text:sub(at + 2, at + 5), 16))
					at = at + 6
				else
					out[#out + 1] = text:sub(at + 1, at + 1)
					at = at + 2
				end
			else
				out[#out + 1] = char
				at = at + 1
			end
		end
		return table.concat(out)
	end
	value = function()
		space()
		local char = text:sub(at, at)
		if char == "{" then
			local object = {}
			at = at + 1
			space()
			if text:sub(at, at) == "}" then at = at + 1 return object end
			while true do
				space()
				local key = str()
				space()
				at = at + 1
				object[key] = value()
				space()
				local mark = text:sub(at, at)
				at = at + 1
				if mark == "}" then return object end
				if mark ~= "," then error("bad object") end
			end
		elseif char == "[" then
			local list = {}
			at = at + 1
			space()
			if text:sub(at, at) == "]" then at = at + 1 return list end
			while true do
				list[#list + 1] = value()
				space()
				local mark = text:sub(at, at)
				at = at + 1
				if mark == "]" then return list end
				if mark ~= "," then error("bad array") end
			end
		elseif char == '"' then
			return str()
		elseif text:sub(at, at + 3) == "null" then
			at = at + 4
			return nil
		elseif text:sub(at, at + 3) == "true" then
			at = at + 4
			return true
		elseif text:sub(at, at + 4) == "false" then
			at = at + 5
			return false
		end
		local number = text:match("^-?%d+%.?%d*", at)
		if not number then error("bad value") end
		at = at + #number
		return tonumber(number)
	end
	return value()
end

--
-- The stub engine
--
local clock = 1000
local real_time = os.time
os.time = function() return clock end -- luacheck: ignore

local function serialize(value) return "return " .. encode(value) end
local function deserialize(text) return decode(text:sub(8)) end

local function new_storage(rows)
	rows = rows or {}
	local storage = {rows = rows}
	function storage:get_string(key) return rows[key] or "" end
	function storage:set_string(key, value) rows[key] = value end
	function storage:get_int(key) return tonumber(rows[key]) or 0 end
	function storage:set_int(key, value) rows[key] = value end
	function storage:get_keys()
		local keys = {}
		for key, value in pairs(rows) do
			if value ~= "" then keys[#keys + 1] = key end
		end
		table.sort(keys)
		return keys
	end
	return storage
end

local world -- what one setup changed
local function fresh_world()
	world = {players = {}, known = {}, privs = {}, logs = {}, chat = {}, kicked = {},
		disconnected = {}, feed = {}, hooks = {}, after = {}, storage = {},
		settings = {}, added = {}, http = nil, stores = {}, auth = {}, passwords = {},
		removed = {}, records = {}}
end
fresh_world()

_G.core = {
	log = function(level, text) world.logs[#world.logs + 1] = {level, text} end,
	write_json = function(value)
		local ok, json = pcall(encode, value)
		if ok then return json end
		return nil, json
	end,
	parse_json = function(text)
		local ok, value = pcall(decode, text)
		return ok and value or nil
	end,
	serialize = serialize, deserialize = deserialize,
	get_player_by_name = function(name) return world.players[name] end,
	player_exists = function(name) return world.known[name] == true end,
	get_connected_players = function()
		local list, names = {}, {}
		for name in pairs(world.players) do names[#names + 1] = name end
		table.sort(names)
		for index, name in ipairs(names) do list[index] = world.players[name] end
		return list
	end,
	get_player_information = function() return {address = "203.0.113.7"} end,
	kick_player = function(name, reason)
		world.kicked[#world.kicked + 1] = {name, reason}
		return true
	end,
	disconnect_player = function(name, reason)
		world.disconnected[#world.disconnected + 1] = {name, reason}
		return true
	end,
	chat_send_all = function(text) world.chat[#world.chat + 1] = text end,
	registered_items = {[""] = {}, air = {}, ignore = {}, unknown = {},
		["default:dirt"] = {stack = 99}, ["default:sword"] = {stack = 1},
		["grug_abilities:strike"] = {stack = 1, skill = true},
		["grug_money:bag_of_coins"] = {stack = 1}},
	registered_aliases = {mapgen_stone = "default:dirt"},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return group == "grug_bound_skill" and def and def.skill and 1 or 0
	end,
	registered_privileges = {fly = {}, shout = {}, interact = {}, grug_keep = {}},
	get_player_privs = function(name)
		local copy = {}
		for priv in pairs(world.privs[name] or {}) do copy[priv] = true end
		if name == "Owner" then copy.grug_keep = true end
		return copy
	end,
	set_player_privs = function(name, privs) world.privs[name] = privs end,
	check_player_privs = function(name, wanted)
		for priv in pairs(wanted) do
			if not core.get_player_privs(name)[priv] then return false end
		end
		return true
	end,
	add_item = function(_, stack) world.added[#world.added + 1] = stack end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return world.modname or "grug_bridge" end,
	get_mod_storage = function()
		local name = world.storage_name or "grug_bridge"
		world.stores[name] = world.stores[name] or new_storage()
		return world.stores[name]
	end,
	get_us_time = function() return 123456 end,
	sha1 = function(text) return ("%040x"):format(#text) end,
	settings = {get = function(_, key) return world.settings[key] end},
	request_http_api = function() return world.http end,
	after = function(delay, func) world.after[#world.after + 1] = {delay, func} end,
	get_auth_handler = function()
		return {get_auth = function(name) return world.auth[name] end,
			iterate = function()
				local names = {}
				for name in pairs(world.auth) do names[name] = true end
				return pairs(names)
			end}
	end,
	-- Round 83: the engine's side of a deletion.
	builtin_auth_handler = {
		get_auth = function(name) return world.auth[name] end,
		record_login = function(name)
			assert(world.auth[name])
			world.auth[name].last_login = clock
		end,
	},
	objects_by_guid = {},
	remove_player = function(name)
		world.removed[#world.removed + 1] = name
		if world.still_connected or world.players[name] then return 2 end
		if not world.records[name] then return 1 end
		world.records[name] = nil
		return 0
	end,
	remove_player_auth = function(name)
		local had = world.auth[name] ~= nil
		world.auth[name] = nil
		return had
	end,
	set_player_password = function(name, entry)
		world.passwords[#world.passwords + 1] = {name, entry}
		world.auth[name] = world.auth[name] or {created = true}
		world.auth[name].password = entry
		return true
	end,
}

-- core.encode_base64 and core.decode_base64 as the engine has them
-- (src/util/base64.cpp, src/script/lua_api/l_util.cpp): no padding written;
-- decode answers nil for what base64_is_valid refuses (a length of 1 mod 4, a
-- non-canonical last character, a foreign character, wrong padding).
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function core.encode_base64(data)
	local out = {}
	for at = 1, #data, 3 do
		local a, b, c = data:byte(at, at + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local chars = {math.floor(n / 262144) % 64, math.floor(n / 4096) % 64,
			math.floor(n / 64) % 64, n % 64}
		for index = 1, (c and 4) or (b and 3) or 2 do
			out[#out + 1] = B64:sub(chars[index] + 1, chars[index] + 1)
		end
	end
	return table.concat(out)
end
function core.decode_base64(text)
	local count = #(text:match("^[A-Za-z0-9+/]*"))
	local padding = 3 - ((count + 3) % 4)
	local last = text:sub(count, count)
	if padding == 3 or (padding == 1 and not ("AEIMQUYcgkosw048"):find(last, 1, true)) or
			(padding == 2 and not ("AQgw"):find(last, 1, true)) then
		return nil
	end
	local rest = text:sub(count + 1)
	if rest ~= "" and (rest ~= ("="):rep(#rest) or #rest ~= padding) then return nil end
	local out, bits, value = {}, 0, 0
	for index = 1, count do
		value = value * 64 + B64:find(text:sub(index, index), 1, true) - 1
		bits = bits + 6
		if bits >= 8 then
			bits = bits - 8
			local byte = math.floor(value / 2 ^ bits)
			out[#out + 1] = string.char(byte)
			value = value - byte * 2 ^ bits
		end
	end
	return table.concat(out)
end
_G.SecureRandom = function()
	local counter = 0
	return {next_bytes = function(_, count)
		counter = counter + 1
		return (("%0" .. (count * 2) .. "x"):format(counter):gsub("..", function(hex)
			return string.char(tonumber(hex, 16))
		end))
	end}
end
setmetatable(core.registered_items, {__index = function(items, name)
	return rawget(items, core.registered_aliases[name])
end})
for _, name in ipairs({"register_on_joinplayer", "register_on_leaveplayer",
		"register_on_prejoinplayer", "register_on_chat_message", "register_on_mods_loaded"}) do
	core[name] = function(func)
		world.hooks[name] = world.hooks[name] or {}
		table.insert(world.hooks[name], func)
	end
end

_G.ItemStack = function(item)
	local stack = {name = item, count = 1}
	function stack:get_stack_max() return core.registered_items[self.name].stack end
	function stack:set_count(count) self.count = count end
	function stack:get_count() return self.count end
	function stack:get_short_description() return "Item " .. self.name end
	function stack:is_empty() return self.count == 0 end
	function stack:to_string() return self.name end
	function stack:get_name() return self.name end
	return stack
end

local function new_player(name, ready)
	world.known[name] = true
	local player = {name = name, ready = ready ~= false, money = 0, xp = 0, level = 1,
		room = true, items = {}}
	function player:get_player_name() return self.name end
	function player:get_pos() return {x = 0, y = 0, z = 0} end
	function player:is_player() return true end
	player.meta = {}
	function player:get_meta()
		return {get_string = function(_, key) return self.meta[key] or "" end,
			set_string = function(_, key, value) self.meta[key] = value end}
	end
	world.players[name] = player
	return player
end

-- Round 81: the shared text rules (raw field cut, UTF-8 rule).
_G.grug_core = {text = dofile(repo .. "/mods/CORE/grug_core/text.lua"), feed = function(player, kind, text)
	world.feed[#world.feed + 1] = {player:get_player_name(), kind, text}
end}
_G.grug_money = {BAG = "grug_money:bag_of_coins",
	add = function(player, copper) player.money = player.money + copper return player.money end,
	format = function(copper) return copper .. "c" end,
	take_with_inventory = function() return true end, get = function() return 0 end}
_G.grug_xp = {
	add_xp = function(player, amount, source)
		player.xp_source = source
		local granted = math.min(amount, 194220 - player.xp)
		player.xp = player.xp + granted
		return true, granted
	end,
	get_level = function(player) return player.level end,
	register_on_level_change = function(func) world.hooks.level = func end,
}
_G.grug_inventory = {GAME_VERSION = "0.69.1",
	fits = function(player) return player.room end,
	give = function(player, stack)
		player.items[#player.items + 1] = {stack:get_name(), stack:get_count()}
		return (function() local left = ItemStack(stack:get_name()) left:set_count(0) return left end)()
	end,
}
_G.grug_classes = {
	get_class = function(player) return player.ready and "priest" or nil end,
	get_race = function(player) return player.ready and "human" or nil end,
	register_on_arrival = function(func) world.hooks.arrival = func end,
}
_G.grug_factions = {
	get_faction = function(player) return player.ready and "accord" or nil end,
	register_on_faction_chosen = function() end,
}
_G.string.trim = _G.string.trim or function(text) return text:match("^%s*(.-)%s*$") end

local function load_mail()
	world.storage_name = "grug_mail"
	_G.grug_mail = {}
	grug_mail.model = dofile(MAIL .. "/model.lua")
	grug_mail.store = dofile(MAIL .. "/store.lua")
	dofile(MAIL .. "/api.lua")
	grug_mail.character_ready = function(player) return player.ready end
	world.storage_name = nil
end

-- The real grug_accounts, with the Supporter Cloak as its one reward.
local function load_accounts()
	world.storage_name, world.modname = "grug_accounts", "grug_accounts"
	_G.grug_accounts = nil
	dofile(ACCOUNTS .. "/init.lua")
	grug_accounts.register_reward("cloak:supporter", {kind = "cloak", name = "Supporter Cloak",
		icon = "grug_cloak_supporter.png", hint = "Choose it on the Character page."})
	for _, func in ipairs(world.hooks.register_on_mods_loaded or {}) do func() end
	world.storage_name, world.modname = nil, nil
end

load_mail()
load_accounts()
local L = dofile(MOD .. "/link.lua")
local Mirror = dofile(MOD .. "/mirror.lua")
local B = dofile(MOD .. "/bans.lua")
local C = dofile(MOD .. "/commands.lua")

local function new_link(over)
	local state = {commands = {}, banlists = {}, resyncs = {}, rows = {}, version = 0}
	local opts = {boot = "b", version = "0.69.1", capabilities = {"online"},
		encode = core.write_json, decode = core.parse_json,
		now = function() return clock end,
		log = function(level, text) core.log(level, text) end,
		clean = function(text, max) return C.plain(text, max) end,
		online_rows = function() return state.rows end,
		banlist_version = function() return state.version end,
		run_command = function(command)
			state.commands[#state.commands + 1] = command.id
			return "ok", ""
		end,
		on_banlist = function(list) state.banlists[#state.banlists + 1] = list end,
		on_resync = function(name) state.resyncs[#state.resyncs + 1] = name end}
	for key, value in pairs(over or {}) do opts[key] = value end
	return L.new(opts), state
end

local function reply(fields, code)
	fields = fields or {}
	fields.protocol = fields.protocol or 1
	return {completed = true, succeeded = true, code = code or 200, data = encode(fields)}
end

-- A. The exchange -----------------------------------------------------------
do
	local link = new_link()
	local body = link:request()
	local sent = decode(body)
	eq(sent.protocol, 1, "A protocol")
	eq(sent.boot, "b", "A boot")
	eq(sent.game_version, "0.69.1", "A game version")
	eq(sent.banlist_version, 0, "A banlist version")
	eq(sent.dropped_events, 0, "A dropped events")
	check(body:find('"results":[]', 1, true), "A empty results are an array")
	check(body:find('"events":[]', 1, true), "A empty events are an array")
	check(body:find('"online":[]', 1, true), "A the first request has the online list")

	eq(link:finish(reply({next_ms = 3000})), 3, "A next_ms")
	check(link:request():find('"online":', 1, true) == nil, "A an unchanged list stays away")
	link:finish(reply({}))
	eq(link:finish(reply({next_ms = 1})), 1, "A next_ms has a floor")
	eq(link:finish(reply({next_ms = 999999})), 30, "A next_ms has a ceiling")
	eq(link:finish(reply({next_ms = "x"})), 2, "A a bad next_ms is the default")
	clock = clock + L.ONLINE_EVERY
	check(link:request():find('"online":', 1, true), "A the list every 30 seconds")
	link:finish(reply({}))
	check(link:request():find('"online":', 1, true) == nil, "A sent again only then")
	link:online_changed()
	check(link:request():find('"online":', 1, true), "A sent on a change")
	link:online_changed() -- while that request is in flight
	link:finish(reply({}))
	check(link:request():find('"online":', 1, true), "A a change in flight is not lost")
	link:finish(reply({}))

	local fail = {completed = true, succeeded = false, code = 0, data = ""}
	link:online_changed()
	check(link:request():find('"online":', 1, true), "A a change is due")
	link:finish(fail)
	check(link:request():find('"online":', 1, true), "A a failed request sends it again")
	link:finish(reply({}))
	local logged = #world.logs
	for index, wait in ipairs({5, 10, 20, 40, 60, 60}) do
		link:request()
		eq(link:finish(fail), wait, "A backoff " .. index)
	end
	eq(#world.logs, logged + 1, "A a failing bridge logs once")
	link:request()
	eq(link:finish(reply({next_ms = 2000})), 2, "A recovered")
	link:request()
	eq(link:finish(fail), 5, "A the backoff starts over")
	link:request()
	link:finish(reply({}))

	logged = #world.logs
	for _, code in ipairs({401, 401, 409, 409}) do
		link:request()
		eq(link:finish({completed = true, succeeded = true, code = code, data = ""}), 60,
			"A a refusal waits a minute")
	end
	eq(#world.logs, logged + 2, "A a refusal logs once per kind")
	link:request()
	eq(link:finish({completed = true, succeeded = true, code = 500, data = ""}), 5,
		"A a server error is a failure")
	link:request()
	eq(link:finish({completed = true, succeeded = true, code = 200, data = "not json"}), 10,
		"A an unreadable answer is a failure")
	link:request()
	eq(link:finish(reply({protocol = 2})), 20, "A another protocol is a failure")
	link:request()
	eq(link:finish({completed = true, succeeded = true, code = 200,
		data = (" "):rep(L.MAX_RESPONSE + 1)}), 40, "A an oversized answer is a failure")
end

-- B. The queue --------------------------------------------------------------
do
	local link = new_link()
	for index = 1, 150 do link:push({type = "chat", name = "A", text = "t" .. index}) end
	local sent = decode(link:request())
	eq(#sent.events, 100, "B 100 events a request")
	eq(sent.events[1].seq, 1, "B seq from 1")
	eq(sent.events[100].seq, 100, "B in order")
	eq(sent.events[1].time, clock, "B the time")
	link:finish(reply({ack_seq = 40}))
	sent = decode(link:request())
	eq(sent.events[1].seq, 41, "B the ack forgets up to it")
	link:finish({completed = true, succeeded = false, code = 0, data = ""})
	sent = decode(link:request())
	eq(sent.events[1].seq, 41, "B a failed request keeps the events")
	link:finish(reply({ack_seq = 150}))
	eq(link:queued(), 0, "B everything acknowledged")

	for index = 1, L.QUEUE_MAX + 5 do link:push({type = "chat", name = "A", text = "x"}) end
	eq(link:queued(), L.QUEUE_MAX, "B the queue is bound")
	sent = decode(link:request())
	eq(sent.dropped_events, 5, "B the dropped are counted")
	eq(sent.events[1].seq, 156, "B the oldest went")
	link:finish(reply({ack_seq = 100000}))

	local big = new_link()
	local text = ("y"):rep(30000)
	for _ = 1, 20 do big:push({type = "mail.ticket", ticket = {body = text}}) end
	local body = big:request()
	check(#body <= L.MAX_REQUEST, "B the byte bound")
	eq(#decode(body).events, 8, "B as many as fit")
	check(big:push({type = "mail.ticket", ticket = {body = ("z"):rep(L.EVENT_MAX)}}) == false,
		"B an event that can never fit is lost")
	check(big:push({type = "bad", value = function() end}) == false,
		"B an unwritable event is lost")
	for input, wanted in pairs({
		["plain"] = "plain",
		["caf\195\169 \240\159\144\151"] = "caf\195\169 \240\159\144\151",
		["a\194b"] = "a\239\191\189b",               -- a lead byte alone
		["\224\128c"] = "\239\191\189\239\191\189c", -- overlong
		["\237\160\128"] = "\239\191\189\239\191\189\239\191\189", -- a surrogate
		["\244\144\128\128"] = "\239\191\189\239\191\189\239\191\189\239\191\189", -- past U+10FFFF
		["\192\255"] = "\239\191\189\239\191\189",   -- never valid
		["end\240\159"] = "end\239\191\189\239\191\189", -- cut off
		["\224\128\128"] = ("\239\191\189"):rep(3),     -- overlong three bytes
		["\240\128\128\128"] = ("\239\191\189"):rep(4), -- overlong four bytes
		["\192\128"] = ("\239\191\189"):rep(2),         -- overlong two bytes
		["\245\128\128\128"] = ("\239\191\189"):rep(4), -- no such lead byte
		["\226\130\255"] = ("\239\191\189"):rep(3),     -- a bad third byte
		["\226\130A"] = "\239\191\189\239\191\189A",   -- an ASCII third byte
	}) do
		eq(L.valid_utf8(input), wanted, "B valid UTF-8")
	end
	local stray = new_link()
	stray:push({type = "mail.ticket", ticket = {body = "bad\194byte"}})
	eq(decode(stray:request()).events[1].ticket.body, "bad\239\191\189byte", "B a queued event is valid")

	local seq = big.next_seq
	eq(big.dropped, 2, "B both counted")
	big:push({type = "chat", name = "A", text = "after"})
	eq(big.events[big.last].seq, seq, "B no gap in seq")
end

-- C. At most once -----------------------------------------------------------
do
	local link, state = new_link()
	local command = {id = "c1", type = "x", args = {}}
	link:request()
	link:finish(reply({commands = {command}}))
	eq(#state.commands, 1, "C ran")
	local sent = decode(link:request())
	eq(sent.results[1].id, "c1", "C the result")
	eq(sent.results[1].status, "done", "C done")
	eq(sent.results[1].code, "ok", "C ok")

	-- The response to that request is lost: the result stays and goes again.
	link:finish({completed = true, succeeded = false, code = 0, data = ""})
	sent = decode(link:request())
	eq(sent.results[1].id, "c1", "C a lost response repeats the result")
	eq(#sent.results, 1, "C once")
	-- The command comes again while its result is still queued.
	link:finish({completed = true, succeeded = false, code = 0, data = ""})
	link:command(command)
	eq(#link.results, 1, "C not queued twice")
	eq(#state.commands, 1, "C did not act")
	link:request()
	link:finish(reply({}))
	eq(#link.results, 0, "C forgotten after an answer")
	check(decode(link:request()).results == nil or
		#decode(link:request()).results == 0, "C nothing left")
	link:finish(reply({commands = {command}}))
	eq(#state.commands, 1, "C a repeated id does not act")
	sent = decode(link:request())
	eq(sent.results[1].id, "c1", "C a repeated id repeats the stored result")
	link:finish(reply({}))

	-- A result that did not fit the request stays for the next one.
	for index = 1, 3 do link:command({id = "big" .. index, type = "x"}) end
	local cut = L.MAX_REQUEST
	L.MAX_REQUEST = 280
	sent = decode(link:request())
	check(#sent.results < 3 and #sent.results > 0, "C results obey the byte bound")
	local carried = #sent.results
	link:finish(reply({}))
	L.MAX_REQUEST = cut
	eq(#decode(link:request()).results, 3 - carried, "C the rest follows")
	link:finish(reply({}))

	link:finish(reply({commands = {{id = "old", type = "x", expires_at = clock - 1}}}))
	sent = decode(link:request())
	eq(sent.results[1].code, "expired", "C expired")
	eq(sent.results[1].status, "failed", "C failed")
	eq(#state.commands, 4, "C an expired command does not run")
	link:finish(reply({commands = {{id = "now", type = "x", expires_at = clock}}}))
	eq(#state.commands, 5, "C not past its time")
	link:request()
	link:finish(reply({}))

	-- Only an answer forgets a result: never a refusal or a failure.
	local kept = new_link()
	kept:command({id = "k", type = "x"})
	for _, res in ipairs({{completed = true, succeeded = true, code = 401, data = ""},
			{completed = true, succeeded = true, code = 409, data = ""},
			{completed = true, succeeded = true, code = 500, data = ""},
			{completed = true, succeeded = true, code = 200, data = "not json"},
			{completed = true, succeeded = false, code = 0, data = ""}}) do
		kept:request()
		kept:finish(res)
		eq(#kept.results, 1, "C a result stays after status " .. res.code)
	end

	-- One failing part of an answer leaves the others alone.
	local partly, parts = new_link({
		on_banlist = function() error("banlist") end,
		on_resync = function() error("resync") end})
	partly:request()
	eq(partly:finish(reply({ack_seq = 0, banlist = {version = 1}, resync = {"mail"},
		commands = {{id = "p", type = "x"}}, next_ms = 4000})), 4, "C the answer is read to its end")
	eq(parts.commands[1], "p", "C the command ran")

	local boom = new_link({run_command = function() error("kaboom") end})
	boom:request()
	boom:finish(reply({commands = {{id = "e", type = "x"}, {id = "f", type = "x"}}}))
	sent = decode(boom:request())
	eq(sent.results[1].code, "error", "C an error is a result")
	eq(#sent.results, 2, "C the next command still runs")
	boom:finish(reply({commands = {{type = "x"}, "nonsense"}}))
	eq(#boom.results, 0, "C a command without an id is ignored")

	local long = new_link({run_command = function() return "refused", ("m"):rep(500) end})
	long:command({id = "l", type = "x"})
	eq(#decode(long:request()).results[1].message, L.MESSAGE_MAX, "C the message is bound")

	local unknown = {C.run({type = "no.such", args = {}})}
	eq(unknown[1], "unsupported", "C an unknown type")
	eq(C.run({type = "kick"}), "invalid_args", "C args must be a table")

	-- Round 83: a command that answers later. Silent while it runs, one
	-- result at done, a second done ignored, an error before or after defer.
	local later
	local deferring = new_link({run_command = function(command, defer)
		if command.type == "boom" then
			if command.args and command.args.after then defer() end
			error("kaboom")
		end
		later = defer()
		return "ok", "ignored"
	end})
	deferring:command({id = "d1", type = "x", expires_at = clock + 60})
	sent = decode(deferring:request())
	eq(#sent.results, 0, "C deferred: no result while it runs")
	deferring:finish(reply({commands = {{id = "d1", type = "x"}}}))
	sent = decode(deferring:request())
	eq(#sent.results, 0, "C deferred: a repeated delivery stays silent")
	deferring:finish(reply({}))
	local logged = #world.logs
	eq(later("ok", "done later"), true, "C deferred: done answers")
	eq(#world.logs, logged + 1, "C deferred: one log line at the answer")
	check(world.logs[#world.logs][2]:find("command d1 (x): ok done later", 1, true), "C deferred: the line")
	eq(later("error", "again"), false, "C deferred: a second done is ignored")
	eq(world.logs[#world.logs][1], "warning", "C deferred: and logged")
	sent = decode(deferring:request())
	eq(#sent.results, 1, "C deferred: one result")
	eq(sent.results[1].message, "done later", "C deferred: the first answer")
	deferring:finish(reply({commands = {{id = "d1", type = "x"}}}))
	sent = decode(deferring:request())
	eq(sent.results[1].message, "done later", "C deferred: repeated after the answer, the stored result")
	deferring:finish(reply({}))
	deferring:command({id = "d2", type = "x", expires_at = clock - 1})
	sent = decode(deferring:request())
	eq(sent.results[1].code, "expired", "C deferred: an expired one never runs")
	deferring:finish(reply({}))
	deferring:command({id = "d3", type = "boom"})
	deferring:command({id = "d4", type = "boom", args = {after = true}})
	sent = decode(deferring:request())
	eq(#sent.results, 2, "C deferred: an error before or after defer is a result")
	eq(sent.results[1].code .. sent.results[2].code, "errorerror", "C deferred: error")
	deferring:finish(reply({}))
end

-- D. The command types ------------------------------------------------------
local function run(kind, args) return (C.run({type = kind, args = args})) end
do
	local rowan = new_player("Rowan")
	new_player("Newbie", false)
	world.known.Gone = true

	-- kick
	eq(run("kick", {name = "Gone"}), "not_online", "D kick offline")
	eq(run("kick", {name = "Nobody"}), "unknown_target", "D kick unknown")
	eq(run("kick", {name = 5}), "invalid_args", "D kick a bad name")
	eq(run("kick", {name = "Rowan", reason = ("r"):rep(201)}), "invalid_args", "D kick a long reason")
	eq(run("kick", {name = "Rowan", reason = "Please\nread \27(c@#ff0000)the rules."}), "ok", "D kick")
	eq(world.kicked[1][2], "Please read the rules.", "D kick cleans the reason")
	eq(run("kick", {name = "Rowan"}), "ok", "D kick without a reason")
	eq(world.kicked[2][2], nil, "D no reason")
	eq(run("kick", {name = "Rowan", reason = ""}), "ok", "D kick with an empty reason")

	-- chat
	eq(run("chat.send", {admin = "Jan", text = ""}), "invalid_args", "D chat empty")
	eq(run("chat.send", {text = "hi"}), "invalid_args", "D chat without an admin")
	eq(run("chat.send", {admin = "Jan", text = ("t"):rep(501)}), "invalid_args", "D chat too long")
	eq(run("chat.send", {admin = "J\nan", text = "one\ntwo \27(c@#00ff00)three\27E"}), "ok", "D chat")
	eq(world.chat[1], "[Admin]<J an> one two three", "D chat line")

	-- mail
	local player = rowan
	local M = grug_mail.model
	local ok = grug_mail.send_ticket(player, "Question", "Help", "Please", "Town")
	check(ok, "D a ticket")
	local id = grug_mail.tickets()[1].id
	eq(run("mail.answer", {ticket_id = 999, admin = "Jan", body = "x"}), "unknown_target", "D answer gone")
	eq(run("mail.answer", {ticket_id = "1", admin = "Jan", body = "x"}), "invalid_args", "D answer a bad id")
	eq(run("mail.answer", {ticket_id = id, admin = "Jan", body = "   "}), "invalid_args", "D answer empty")
	eq(run("mail.answer", {ticket_id = id, admin = "Jan", body = ("b"):rep(M.BODY_MAX + 1)}),
		"invalid_args", "D answer too long")
	eq(run("mail.answer", {ticket_id = id, body = "x"}), "invalid_args", "D answer without an admin")
	eq(run("mail.answer", {ticket_id = id, admin = "Jan", body = "Done"}), "ok", "D answer")
	eq(grug_mail.ticket(id).state, "closed", "D answered closes")
	eq(run("mail.answer", {ticket_id = id, admin = "Jan", body = "Again"}), "refused", "D answer closed")
	eq(run("mail.close", {ticket_id = id, admin = "Jan"}), "refused", "D close closed")
	grug_mail.send_ticket(player, "Question", "Two", "Two", "Town")
	local second = grug_mail.tickets()[1].id
	eq(run("mail.close", {ticket_id = 999, admin = "Jan"}), "unknown_target", "D close gone")
	eq(run("mail.close", {ticket_id = second, admin = "Jan"}), "ok", "D close")
	eq(grug_mail.ticket(second).answered, false, "D closed without an answer")
	eq(run("mail.delete", {ticket_id = second, admin = "Jan"}), "ok", "D delete")
	eq(run("mail.delete", {ticket_id = second, admin = "Jan"}), "unknown_target", "D delete gone")

	eq(run("mail.send", {to = "Nobody", subject = "S", body = "B", admin = "Jan"}),
		"unknown_target", "D send unknown")
	eq(run("mail.send", {to = "Rowan", subject = ("s"):rep(M.SUBJECT_MAX + 1), body = "B", admin = "Jan"}),
		"invalid_args", "D send a long subject is refused, not cut")
	eq(run("mail.send", {to = "Rowan", subject = "", body = "B", admin = "Jan"}),
		"invalid_args", "D send without a subject")
	eq(run("mail.send", {to = "Rowan", subject = "S", body = ("b"):rep(M.BODY_MAX + 1), admin = "Jan"}),
		"invalid_args", "D send a long body is refused, not cut")
	eq(run("mail.send", {to = "Rowan", subject = "S", body = "", admin = "Jan"}),
		"invalid_args", "D send an empty body")
	eq(run("mail.send", {to = "Gone", subject = "S", body = "B", admin = "Jan"}), "ok", "D send to an offline player")
	local box = grug_mail.store.box("Gone")
	eq(box.letters[1].from, M.ADMIN_LABEL, "D the admin label")

	eq(run("mail.broadcast", {subject = "S", body = ("b"):rep(M.BODY_MAX + 1), admin = "Jan"}),
		"invalid_args", "D broadcast too long")
	eq(run("mail.broadcast", {subject = "S", body = "B"}), "invalid_args", "D broadcast without an admin")
	eq(run("mail.broadcast", {subject = "S", body = "B", admin = "Jan"}), "ok", "D broadcast")
	local bid = grug_mail.broadcasts()[1].id
	eq(grug_mail.broadcasts()[1].by, "Jan", "D broadcast names the admin")
	eq(run("mail.broadcast_delete", {broadcast_id = 999, admin = "Jan"}), "unknown_target", "D broadcast gone")
	eq(run("mail.broadcast_delete", {broadcast_id = bid, admin = "Jan"}), "ok", "D broadcast delete")

	-- money
	eq(run("action.give_money", {name = "Gone", copper = 5}), "not_online", "D money offline")
	eq(run("action.give_money", {name = "Nobody", copper = 5}), "unknown_target", "D money unknown")
	eq(run("action.give_money", {name = "Newbie", copper = 5}), "refused", "D money in creation")
	eq(world.players.Newbie.money, 0, "D creation stores nothing")
	for _, bad in ipairs({0, -1, 1.5, 1000001, "5"}) do
		eq(run("action.give_money", {name = "Rowan", copper = bad}), "invalid_args", "D money bound")
	end
	eq(rowan.money, 0, "D nothing given")
	local feeds = #world.feed
	eq(run("action.give_money", {name = "Rowan", copper = 1000000}), "ok", "D money")
	eq(rowan.money, 1000000, "D the money")
	eq(world.feed[feeds + 1][2], "notice", "D the feed line")
	check(world.feed[feeds + 1][3]:find("1000000c", 1, true), "D the feed names the amount")

	-- XP
	eq(run("action.give_xp", {name = "Newbie", amount = 5}), "refused", "D xp in creation")
	eq(run("action.give_xp", {name = "Rowan", amount = 0}), "invalid_args", "D xp bound")
	eq(run("action.give_xp", {name = "Rowan", amount = 1000001}), "invalid_args", "D xp bound")
	local _, granted = C.run({type = "action.give_xp", args = {name = "Rowan", amount = 1000000}})
	check(granted:find("194220 XP granted", 1, true), "D the message names what was granted")
	eq(rowan.xp_source, nil, "D xp has no source")

	-- items
	eq(run("action.give_item", {name = "Newbie", item = "default:dirt", count = 1}), "refused", "D item in creation")
	eq(run("action.give_item", {name = "Rowan", item = "no:such", count = 1}), "unknown_target", "D item unknown")
	for _, item in ipairs({"", "air", "ignore", "unknown"}) do
		eq(run("action.give_item", {name = "Rowan", item = item, count = 1}), "unknown_target", "D the engine's own")
	end
	eq(run("action.give_item", {name = "Rowan", item = "default:dirt 99", count = 1}), "unknown_target", "D an item string")
	eq(run("action.give_item", {name = "Rowan", item = "mapgen_stone", count = 1}), "unknown_target", "D an alias")
	eq(run("action.give_item", {name = "Rowan", item = "grug_abilities:strike", count = 1}), "refused", "D a skill item")
	eq(run("action.give_item", {name = "Rowan", item = "grug_money:bag_of_coins", count = 1}), "refused", "D an empty bag")
	eq(run("action.give_item", {name = "Rowan", item = "default:sword", count = 2}), "invalid_args", "D over the stack")
	eq(run("action.give_item", {name = "Rowan", item = "default:dirt", count = 0}), "invalid_args", "D count bound")
	rowan.room = false
	eq(run("action.give_item", {name = "Rowan", item = "default:dirt", count = 5}), "refused", "D no room")
	eq(#rowan.items, 0, "D nothing half delivered")
	rowan.room = true
	feeds = #world.feed
	eq(run("action.give_item", {name = "Rowan", item = "default:dirt", count = 99}), "ok", "D item")
	eq(rowan.items[1][2], 99, "D the count")
	eq(world.feed[feeds + 1][1], "Rowan", "D the feed line")
	eq(#world.added, 0, "D nothing dropped")

	-- privileges
	eq(run("action.grant_priv", {name = "Gone", priv = "fly"}), "not_online", "D grant offline")
	eq(run("action.grant_priv", {name = "Rowan", priv = "nope"}), "unknown_target", "D grant unknown")
	eq(run("action.grant_priv", {name = "Rowan", priv = 5}), "invalid_args", "D grant bad")
	eq(run("action.grant_priv", {name = "Rowan", priv = "fly"}), "ok", "D grant")
	check(world.privs.Rowan.fly, "D granted")
	eq(run("action.grant_priv", {name = "Rowan", priv = "fly"}), "ok", "D grant twice")
	eq(run("action.grant_priv", {name = "Newbie", priv = "fly"}), "ok", "D a privilege is no character state")
	eq(run("action.revoke_priv", {name = "Rowan", priv = "nope"}), "unknown_target", "D revoke unknown")
	eq(run("action.revoke_priv", {name = "Rowan", priv = "fly"}), "ok", "D revoke")
	check(not world.privs.Rowan.fly, "D revoked")
	eq(run("action.revoke_priv", {name = "Rowan", priv = "fly"}), "ok", "D revoke twice")
	new_player("Owner")
	eq(run("action.revoke_priv", {name = "Owner", priv = "grug_keep"}), "refused", "D the admin keeps it")
end

-- E. The mail mirror --------------------------------------------------------
do
	local events = {}
	local mirror = Mirror.new(function(event) events[#events + 1] = event end, core.write_json)
	local S = grug_mail.store
	mirror:seed("tickets", grug_mail.tickets())
	mirror:seed("broadcasts", grug_mail.broadcasts())
	S.register_on_saved("tickets", function(list) mirror:saved("tickets", list) end)
	S.register_on_saved("broadcasts", function(list) mirror:saved("broadcasts", list) end)
	local rowan = world.players.Rowan

	grug_mail.send_ticket(rowan, "Question", "First", "Body", "Town")
	eq(#events, 1, "E a new ticket")
	eq(events[1].type, "mail.ticket", "E its type")
	eq(events[1].ticket.subject, "First", "E the record")
	local id = events[1].ticket.id

	grug_mail.send_ticket(rowan, "Question", "Second", "Body", "Town")
	eq(#events, 2, "E only what changed")
	eq(events[2].ticket.subject, "Second", "E the second")

	grug_mail.close_ticket(id, "Jan", false)
	eq(#events, 3, "E a change")
	eq(events[3].ticket.state, "closed", "E the changed record")

	grug_mail.delete_ticket(id, "Jan")
	eq(events[4].type, "mail.ticket_removed", "E a removal")
	eq(events[4].id, id, "E its id")

	local bid = grug_mail.send_broadcast("News", "Text", "Jan")
	eq(events[5].type, "mail.broadcast", "E a broadcast")
	eq(events[5].broadcast.id, bid, "E its record")
	grug_mail.delete_broadcast(bid, "Jan")
	eq(events[6].type, "mail.broadcast_removed", "E a broadcast removal")

	-- Expiry happens at a read: the read's own save reports it.
	local count = #events
	clock = clock + grug_mail.model.EXPIRY + 1
	eq(#grug_mail.tickets(), 0, "E pruned")
	eq(#events, count + 2, "E both pruned tickets (the one left by D and Second)")
	eq(events[#events].type, "mail.ticket_removed", "E is removed")

	count = #events
	grug_mail.send_ticket(rowan, "Question", "A", "Body", "Town")
	grug_mail.send_ticket(rowan, "Question", "B", "Body", "Town")
	grug_mail.send_broadcast("News", "Text", "Jan")
	events = {}
	mirror.push = function(event) events[#events + 1] = event end
	mirror:resync(grug_mail.tickets(), grug_mail.broadcasts())
	eq(#events, 4, "E a resync sends everything and an end")
	eq(events[1].ticket.subject, "A", "E oldest first")
	eq(events[2].ticket.subject, "B", "E then the next")
	eq(events[3].type, "mail.broadcast", "E the broadcasts")
	eq(events[4].type, "mail.snapshot_end", "E the end")
	eq(#events[4].ticket_ids, 2, "E the ticket ids")
	eq(#events[4].broadcast_ids, 1, "E the broadcast ids")
	events = {}
	mirror:saved("tickets", grug_mail.tickets())
	eq(#events, 0, "E nothing changed, nothing sent")
end

-- F. Bans -------------------------------------------------------------------
do
	local storage = new_storage()
	local list = B.load(storage, deserialize)
	eq(list.version, 0, "F no list yet")
	check(B.store(storage, serialize, {entries = {}}) == nil, "F a list needs a version")
	list = B.store(storage, serialize, {version = 3, entries = {
		{name = "Griefer", expires_at = clock + 100}, {name = "Griefer2"}, "nonsense"}})
	eq(B.active(list, "griefer", clock), clock + 100, "F case-insensitive")
	eq(B.active(list, "GRIEFER2", clock), false, "F without an end")
	eq(B.active(list, "Rowan", clock), nil, "F not listed")
	eq(B.active(list, "Griefer", clock + 100), nil, "F ended")
	local again = B.load(storage, deserialize)
	eq(again.version, 3, "F across a restart")
	eq(B.active(again, "griefer2", clock), false, "F the entries too")
	eq(B.text(false), "You are banned from this server.", "F the text")
	eq(B.text(1794700000), "You are banned from this server. Ban ends: " ..
		os.date("!%Y-%m-%d %H:%M UTC", 1794700000) .. ".", "F the text with an end")
	local empty = B.store(storage, serialize, {version = 4})
	eq(next(empty.entries), nil, "F null is an empty list")
	eq(B.load(new_storage({banlist = "return nonsense"}), function() return nil end).version, 0,
		"F an unreadable list is none")
end

-- G. init.lua ---------------------------------------------------------------
local function boot(settings, http)
	fresh_world()
	load_mail()
	load_accounts()
	world.hooks = {} -- grug_mail's and grug_accounts' own hooks
	world.settings = settings
	world.http = http
	_G.grug_bridge = nil
	dofile(MOD .. "/init.lua")
end

local HTTP_KEYS = {["grug_bridge.url"] = "http://bridge:8080/",
	["grug_bridge.token"] = ("a"):rep(64)}
do
	local fetches = {}
	local http = {fetch = function(request, callback)
		fetches[#fetches + 1] = {request = request, callback = callback}
	end}
	for label, case in pairs({
		["no http"] = {HTTP_KEYS, nil},
		["no url"] = {{["grug_bridge.token"] = "x"}, http},
		["no token"] = {{["grug_bridge.url"] = "http://b"}, http},
		["nothing"] = {{}, nil},
	}) do
		boot(case[1], case[2])
		eq(grug_bridge.active, false, "G inert: " .. label)
		eq(next(world.hooks), nil, "G no hook: " .. label)
		eq(#world.after, 0, "G no request: " .. label)
		eq(#world.logs, 1, "G one line: " .. label)
	end
	boot({}, nil)
	check(world.logs[1][2]:find("HTTP API", 1, true) and
		world.logs[1][2]:find("grug_bridge.url", 1, true) and
		world.logs[1][2]:find("grug_bridge.token", 1, true), "G the line names what is missing")

	boot(HTTP_KEYS, http)
	eq(grug_bridge.active, true, "G active")
	eq(world.after[1][1], 2, "G the first request after the default")
	world.after[1][2]()
	local request = fetches[1].request
	eq(request.url, "http://bridge:8080/v1/sync", "G the address")
	eq(request.method, "POST", "G POST")
	eq(request.timeout, 5, "G the timeout")
	eq(request.quiet, true, "G a failing bridge writes no engine errors")
	eq(request.extra_headers[1], "Authorization: Bearer " .. ("a"):rep(64), "G the token")
	eq(request.extra_headers[2], "Content-Type: application/json", "G the type")

	local chat = world.hooks.register_on_chat_message[1]
	local rowan = new_player("Rowan")
	world.privs.Rowan = {shout = true}
	world.privs.Mute = {}
	world.hooks.register_on_joinplayer[1](rowan)
	eq(chat("Rowan", "hello"), nil, "G never true")
	eq(chat("Rowan", "/msg Bob secret"), nil, "G never true for a command")
	eq(chat("Mute", "unheard"), nil, "G never true without shout")
	eq(chat("Rowan", "\27(c@#ff0000)red " .. ("x"):rep(600)), nil, "G a long line")
	eq(chat("Rowan", "   "), nil, "G an empty line")

	fetches[1].callback(reply({ack_seq = 0}))
	eq(world.after[2][1], 2, "G the next request")
	world.after[2][2]()
	local sent = decode(fetches[2].request.data)
	eq(#sent.events, 2, "G what others can read")
	eq(sent.events[1].text, "hello", "G the line")
	eq(sent.events[1].name, "Rowan", "G the name")
	check(sent.events[2].text:sub(1, 4) == "red ", "G escapes go")
	eq(#sent.events[2].text, C.CHAT_MAX, "G 500 characters")
	eq(sent.online[1].faction, "accord", "G the faction")
	eq(sent.online[1].joined_at, clock, "G the join time")
	eq(sent.online[1].address, "203.0.113.7", "G the address")

	-- A character being created has no class, race or faction.
	local newbie = new_player("Newbie", false)
	world.hooks.register_on_joinplayer[1](newbie)
	fetches[2].callback(reply({ack_seq = 100, banlist = {version = 7, entries = {
		{name = "newbie", expires_at = clock + 5}}}}))
	world.after[3][2]()
	sent = decode(fetches[3].request.data)
	eq(sent.banlist_version, 7, "G the held version")
	eq(world.disconnected[1][1], "Newbie", "G an online ban disconnects")
	check(world.disconnected[1][2]:find("^You are banned from this server%. Ban ends:"),
		"G with the exact text")
	eq(#world.kicked, 0, "G not through kick_player")
	local row = sent.online[1].name == "Newbie" and sent.online[1] or sent.online[2]
	eq(row.class, nil, "G no class")
	eq(row.faction, nil, "G no faction")

	local prejoin = world.hooks.register_on_prejoinplayer[1]
	check(prejoin("NEWBIE"):find("^You are banned"), "G pre-join refuses")
	eq(prejoin("Rowan"), nil, "G others join")
	clock = clock + 6
	eq(prejoin("Newbie"), nil, "G the ban ended")

	-- A list held in storage bans at the next boot, with the bridge down.
	local stored = world.stores.grug_bridge
	fresh_world()
	load_mail()
	load_accounts()
	world.hooks = {}
	world.settings, world.http = HTTP_KEYS, http
	world.stores.grug_bridge = stored
	stored:set_string("banlist", serialize({version = 9, entries = {griefer = false}}))
	_G.grug_bridge = nil
	dofile(MOD .. "/init.lua")
	check(world.hooks.register_on_prejoinplayer[1]("Griefer"), "G a stored ban holds")

	-- An error in a fetch or an answer keeps the exchange alive.
	local broken = {fetch = function() error("no") end}
	boot(HTTP_KEYS, broken)
	world.after[1][2]()
	eq(world.after[2][1], 60, "G a failed send tries again")
	boot(HTTP_KEYS, http)
	fetches = {}
	world.after[1][2]()
	fetches[1].callback(nil)
	eq(world.after[2][1], 60, "G a broken answer tries again")
	-- No hook lets an error reach the engine.
	eq(world.hooks.register_on_joinplayer[1](nil), nil, "G the join hook survives")
	eq(world.hooks.register_on_leaveplayer[1](nil), nil, "G the leave hook survives")
	eq(world.hooks.register_on_prejoinplayer[1](nil), nil, "G the ban check survives")
	local privs_check = core.check_player_privs
	core.check_player_privs = function() error("no") end
	eq(world.hooks.register_on_chat_message[1]("Rowan", "x"), nil, "G the chat hook survives")
	core.check_player_privs = privs_check
	local logged = #world.logs
	grug_mail.store.save_tickets({5}) -- not a ticket: the mirror raises, the save stands
	check(#world.logs > logged and world.logs[#world.logs][1] == "error", "G the mirror's error is logged")
	eq(world.logs[#world.logs][2]:find("the mail mirror", 1, true) ~= nil, true, "G by its name")
end

-- H. Accounts ---------------------------------------------------------------
local ID_ROWAN = ("a"):rep(32)
local ACCOUNT = {id = "a_1842", name = "jan", rewards = {"cloak:supporter"}}
do
	-- The link alone: the request's fields and the catalogue's flight.
	local version, rows = 0, {{id = "cloak:supporter", kind = "cloak", name = "Supporter Cloak"}}
	local applied, at_apply = {}, nil
	local link, state
	link, state = new_link({accounts_version = function() return version end,
		catalog_rows = function() return rows end,
		on_accounts = function(list)
			applied[#applied + 1] = list
			at_apply = #state.commands
		end})
	local sent = decode(link:request())
	eq(sent.accounts_version, 0, "H accounts_version 0 before a list")
	eq(sent.reward_catalog[1].id, "cloak:supporter", "H the catalogue in the first request")
	eq(sent.reward_catalog[1].kind .. sent.reward_catalog[1].name, "cloakSupporter Cloak", "H its fields")
	eq(sent.reward_catalog[1].icon, nil, "H only id, kind and name")
	link:finish({completed = true, succeeded = false, code = 0, data = ""})
	check(decode(link:request()).reward_catalog, "H a failed request sends it again")
	link:finish({completed = true, succeeded = true, code = 500, data = ""})
	check(decode(link:request()).reward_catalog, "H so does a server error")
	link:finish(reply({}))
	eq(decode(link:request()).reward_catalog, nil, "H a 200 ends it")
	link:finish(reply({}))
	link:catalog_changed()
	rows = {}
	local body = link:request()
	check(body:find('"reward_catalog":[]', 1, true), "H on demand again; an empty one is an array")
	link:finish(reply({}))
	eq(decode(link:request()).reward_catalog, nil, "H and then not")
	link:finish(reply({}))
	-- The list before the commands of the same response.
	version = 4
	link:request()
	link:finish(reply({accounts = {version = 5}, commands = {{id = "after", type = "x"}}}))
	eq(#applied, 1, "H the list is handed over")
	eq(at_apply, 0, "H before the commands")
	eq(state.commands[1], "after", "H the command ran after it")
	eq(decode(link:request()).accounts_version, 4, "H accounts_version is what the game holds")
	link:finish(reply({accounts = "nonsense"}))
	eq(#applied, 1, "H a list that is no object is ignored")
	-- Without the accounts options, nothing of it.
	sent = decode(new_link():request())
	check(sent.accounts_version == nil and sent.reward_catalog == nil, "H nothing without the options")
	-- One failing list leaves the rest of the answer alone.
	local broken, parts = new_link({on_accounts = function() error("list") end})
	broken:request()
	broken:finish(reply({accounts = {version = 1}, commands = {{id = "q", type = "x"}}}))
	eq(parts.commands[1], "q", "H a failing list leaves the commands")
end

-- The whole bridge with the real grug_accounts.
do
	local fetches = {}
	local http = {fetch = function(request, callback)
		fetches[#fetches + 1] = {request = request, callback = callback}
	end}
	boot(HTTP_KEYS, http)
	-- Answers the request in flight (acknowledging what it carried) and
	-- sends the next one.
	local function exchange(fields)
		local fetch = fetches[#fetches]
		local carried = decode(fetch.request.data).events or {}
		fields.ack_seq = #carried > 0 and carried[#carried].seq or 0
		fetch.callback(reply(fields))
		world.after[#world.after][2]()
		return decode(fetches[#fetches].request.data)
	end
	world.after[1][2]()
	local sent = decode(fetches[1].request.data)
	local capabilities = table.concat(sent.capabilities, ",")
	-- Round 83 adds characters.delete (section I), Round 86 rewards.defaults
	-- at the end (web-accounts.md §5).
	check(capabilities:find(",accounts,accounts.password,characters.delete,rewards.defaults$"),
		"H the capabilities")
	eq(#sent.capabilities, 14, "H fourteen capabilities")
	eq(sent.accounts_version, 0, "H no list yet")
	eq(sent.reward_catalog[1].id, "cloak:supporter", "H the registered catalogue")
	eq(grug_accounts.enabled(), false, "H the bridge alone does not enable accounts")

	local rowan = new_player("Rowan")
	rowan.meta["grug_accounts:character_id"] = ID_ROWAN
	local newbie = new_player("Newbie", false)
	local elara = new_player("Elara")
	for _, player in ipairs({rowan, newbie, elara}) do world.hooks.register_on_joinplayer[1](player) end
	sent = exchange({accounts = {version = 1, characters = {
		{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"}}, accounts = {ACCOUNT}},
		commands = {{id = "stale", type = "account.link_answer", args = {request_id = ("0"):rep(16),
			name = "Rowan", outcome = "offer", account_name = "jan"}}}})
	eq(sent.accounts_version, 1, "H the held version")
	eq(grug_accounts.enabled(), true, "H enabled with a list")
	eq(sent.reward_catalog, nil, "H the catalogue went with a 200")
	eq(sent.results[1].code, "refused", "H an answer for no open request")
	local by_name = {}
	for _, row in ipairs(sent.online) do by_name[row.name] = row end
	eq(by_name.Rowan.character_id, ID_ROWAN, "H the online row's character_id")
	eq(by_name.Rowan.account_id, "a_1842", "H and account_id while linked")
	eq(#by_name.Newbie.character_id, 32, "H a character in creation has its id")
	eq(by_name.Newbie.account_id, nil, "H no account_id without a binding")
	local elara_id = by_name.Elara.character_id
	eq(elara.meta["grug_accounts:character_id"], elara_id, "H the row's id is the meta's")

	sent = exchange({resync = {"reward_catalog"}})
	eq(sent.reward_catalog[1].id, "cloak:supporter", "H resync: the catalogue again")
	eq(sent.online, nil, "H nothing changed online")

	-- One link end to end; the list and the linked answer in one response.
	eq(grug_accounts.request_link(elara, "abcde fgh23"), true, "H a link request")
	sent = exchange({})
	local event = sent.events[#sent.events]
	eq(event.type, "account.link_request", "H the request event in the queue")
	check(event.seq and event.time, "H with seq and time")
	eq(event.code, "ABCDEFGH23", "H the normalized code")
	eq(event.character_id, elara_id, "H the character id")
	local R = event.request_id
	local function answer(args, id)
		args.request_id = args.request_id or R
		args.name = args.name or "Elara"
		return {id = id, type = "account.link_answer", args = args, expires_at = clock + 60}
	end
	sent = exchange({commands = {
		answer({outcome = "linked", account_name = "jan"}, "a1"),
		answer({outcome = "offer"}, "a2"),
		answer({outcome = "offer", account_name = "jan"}, "a3"),
		answer({outcome = "offer", account_name = "jan"}, "a4")}})
	local codes = {}
	for _, result in ipairs(sent.results) do codes[result.id] = result.code end
	eq(codes.a1, "invalid_args", "H linked in checking")
	eq(codes.a2, "invalid_args", "H an offer without account_name")
	eq(codes.a3, "ok", "H the offer")
	eq(codes.a4, "invalid_args", "H a second offer in offer")
	eq(grug_accounts.link_state(elara).state, "offer", "H the page's state")
	grug_accounts.confirm_link(elara)
	sent = exchange({})
	event = sent.events[#sent.events]
	eq(event.type .. event.request_id, "account.link_confirm" .. R, "H the confirmation event")
	sent = exchange({
		accounts = {version = 2, characters = {
			{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"},
			{name = "Elara", character_id = elara_id, account_id = "a_1842"}}, accounts = {ACCOUNT}},
		commands = {answer({outcome = "linked", account_name = "jan"}, "a5")}})
	eq(sent.results[1].code, "ok", "H the list first, then the linked answer")
	eq(grug_accounts.link_state(elara).state, "linked", "H linked")
	by_name = {}
	for _, row in ipairs(sent.online or {}) do by_name[row.name] = row end
	eq(by_name.Elara and by_name.Elara.account_id, "a_1842", "H a changed binding sends the online list")
	eq(world.feed[#world.feed - 1][3], "Linked to the website account jan.", "H the success line")
	eq(world.feed[#world.feed][3], "Your account gives you: Supporter Cloak.", "H then the reward")
	-- A cancel through the queue.
	grug_accounts.apply_list({version = 3, characters = {}, accounts = {}})
	grug_accounts.request_link(elara, "ABCDE-FGH23")
	grug_accounts.cancel_link(elara)
	sent = exchange({})
	local types = {}
	for _, row in ipairs(sent.events) do types[#types + 1] = row.type end
	eq(table.concat(types, ","), "account.link_request,account.link_cancel", "H the cancel follows the request")
	eq(sent.events[2].request_id, sent.events[1].request_id, "H for the same request")
	for _, row in ipairs(world.logs) do
		check(not row[2]:find("FGH23", 1, true), "H no code in the log")
	end
end

-- account.set_password (web-accounts.md §6b).
do
	load_accounts()
	local good = "#1#AAECAwQFBgcICQoLDA0ODw#q8LwnNKrKrCcWczylPFS6dl/Vb7NQgAcpngqZ9Nczwz4NP1X4HjOFf58ndlws5" ..
		"HBFBO70sfY6MrIGpIMy5JyyufXw/7LclL/bj/HtihnOMOf3hFP9CQh5YnmdyRJRH/W3V0rg0E+WibydYYcXjDgC9RjSOyVssTHiP" ..
		"MyEGOX8toQo6WCu4MVLk50eBii3nZqSOeK/3het0HdHmyzVAAo4k7GRPfhyy7KwZWNqQXA5PuRRepzZLIG90RQcjoRTEPLLU2fECA" ..
		"pIUjQwegBm9IEL9PmD6c81jMxFI26LOHKUF6PH5aID0HOhbNrehl+ojkatpEqRRl/iPZcSvEiXuBTzQ"
	-- make_entry("Rowan", "correct horse", bytes(range(16))) of luanti_password.py's self-test.
	local salt, verifier = good:match("^#1#([^#]+)#([^#]+)$")
	check(C.valid_entry(good), "H the self-test's good entry")
	check(C.valid_entry("#1#" .. salt .. "#" .. core.encode_base64(("\1"):rep(256))), "H a 256-byte verifier")
	check(C.valid_entry("#1#" .. salt .. "#" .. core.encode_base64(("\1"):rep(255))), "H a 255-byte verifier")
	check(C.valid_entry("#1#AA#AQ"), "H one byte each")
	local bad = {
		-- The self-test's cases.
		["a verifier cut by one character"] = "#1#" .. salt .. "#" .. verifier:sub(1, -2),
		["a length of 1 mod 4"] = "#1#" .. salt .. "#" .. verifier .. "AAAAA",
		["a non-canonical last character"] = "#1#" .. salt:sub(1, -2) .. "R#" .. verifier,
		["padding"] = "#1#" .. salt .. "==#" .. verifier,
		["a legacy entry"] = "aF279JkAQ3m38xybb/eIkidtM8w",
		["a plain password"] = "correct horse",
		["an empty salt"] = "#1##" .. verifier,
		["a verifier over 256 bytes"] = "#1#" .. salt .. "#" .. core.encode_base64(("\1"):rep(258)),
		-- And these.
		["a verifier of 257 bytes"] = "#1#" .. salt .. "#" .. core.encode_base64(("\1"):rep(257)),
		["an empty verifier"] = "#1#" .. salt .. "#",
		["a trailing #"] = good .. "#",
		["another mechanism"] = "#2#" .. salt .. "#" .. verifier,
		["a part before the first #"] = "x#1#" .. salt .. "#" .. verifier,
		["a line end"] = good .. "\n",
		["not a string"] = 5,
	}
	for label, entry in pairs(bad) do check(not C.valid_entry(entry), "H refused: " .. label) end

	local rowan = new_player("Rowan")
	rowan.meta["grug_accounts:character_id"] = ID_ROWAN
	world.players.Rowan = rowan
	world.auth = {Rowan = {password = "old"}, Away = {password = "old"}, Free = {password = "old"}}
	grug_accounts.apply_list({version = 1, characters = {
		{name = "Rowan", character_id = ID_ROWAN, account_id = "a_1842"},
		{name = "Away", character_id = ("d"):rep(32), account_id = "a_1842"},
		{name = "Nobody", character_id = ("e"):rep(32), account_id = "a_1842"}}, accounts = {ACCOUNT}})
	local function set(args) return C.run({type = "account.set_password", args = args}) end
	eq(set({account_id = "a_1842", entry = good}), "invalid_args", "H no name")
	eq(set({name = "Rowan", entry = good}), "invalid_args", "H no account_id")
	eq(set({name = "Nobody", account_id = "a_1842", entry = good}), "unknown_target",
		"H no auth entry, even with a binding")
	eq(world.auth.Nobody, nil, "H no login was created")
	local code, message = set({name = "Free", account_id = "a_1842", entry = good})
	eq(code, "refused", "H no binding")
	eq(message, "not linked to this account", "H its message")
	eq(set({name = "Rowan", account_id = "a_9", entry = good}), "refused", "H another account")
	eq(set({name = "Free", account_id = "a_1842", entry = "nonsense"}), "refused",
		"H the binding is checked before the form")
	for label, entry in pairs(bad) do
		eq(set({name = "Rowan", account_id = "a_1842", entry = entry}), "invalid_args", "H malformed: " .. label)
	end
	eq(#world.passwords, 0, "H nothing written so far")
	local feeds = #world.feed
	eq(set({name = "Rowan", account_id = "a_1842", entry = good}), "ok", "H set for an online character")
	eq(world.auth.Rowan.password, good, "H the entry as sent")
	eq(world.feed[feeds + 1][3], "Your password was changed on the website. It applies from your next login.",
		"H the feed line")
	eq(set({name = "Away", account_id = "a_1842", entry = good}), "ok", "H set for an offline character")
	eq(#world.feed, feeds + 1, "H no feed line offline")
	-- Through the link: neither the log nor the result holds the entry.
	local link = new_link({run_command = C.run})
	local logs = #world.logs
	link:command({id = "pw", type = "account.set_password",
		args = {name = "Rowan", account_id = "a_1842", entry = good}})
	local result = decode(link:request()).results[1]
	eq(result.code, "ok", "H through the link")
	eq(#world.logs, logs + 1, "H one log line")
	check(world.logs[logs + 1][2]:find("Rowan", 1, true) and world.logs[logs + 1][2]:find("a_1842", 1, true),
		"H with name and account id")
	check(not result.message:find(salt, 1, true), "H the result holds no entry")
	for _, row in ipairs(world.logs) do
		check(not row[2]:find(salt, 1, true) and not row[2]:find(verifier:sub(1, 20), 1, true),
			"H no entry in the log")
	end
end

-- I. character.delete (Round 83) ----------------------------------------------
-- The real commands.lua, delete.lua and init.lua's guards; the real registry
-- (grug_core/character_delete.lua) with the real grug_accounts and grug_mail
-- clears and a counting stand-in for the other mods.
do
	local fetches = {}
	local http = {fetch = function(request, callback) fetches[#fetches + 1] = callback end}
	boot(HTTP_KEYS, http)
	world.after = {}
	world.settings.name = "Owner"
	world.settings.server_map_save_interval = "5.3"
	local registry = dofile(repo .. "/mods/CORE/grug_core/character_delete.lua")
	registry.MODS = {"grug_accounts", "grug_mail", "r83_store"}
	grug_core.character_delete = registry
	local cleared, failing = {}, false
	_G.r83_store = {forget_character = function(name)
		cleared[#cleared + 1] = name
		if failing then error("store broken") end
	end}
	eq(#registry.missing(), 0, "I every listed mod has its clear")
	_G.r83_store.forget_character, failing = nil, false
	eq(registry.missing()[1], "r83_store", "I a missing clear is named")
	_G.r83_store.forget_character = function(name)
		cleared[#cleared + 1] = name
		if failing then error("store broken") end
	end
	-- The instance init.lua loaded: its pre-join hook shares the deletions.
	local C = grug_bridge.commands
	local D = C.delete
	local guids = core.objects_by_guid
	local accounts = world.stores.grug_accounts
	local mail = world.stores.grug_mail
	local prejoin = world.hooks.register_on_prejoinplayer[2]
	local deleted_login = world.hooks.register_on_joinplayer[2]

	-- Runs the deferred jobs in order, each advancing the clock by its delay.
	local function run_jobs(limit)
		local ran = 0
		while #world.after > 0 and ran < (limit or 1000) do
			local job = table.remove(world.after, 1)
			clock = clock + job[1]
			job[2]()
			ran = ran + 1
		end
		return ran
	end
	local link = new_link({run_command = C.run})
	local function results()
		local body = decode(link:request())
		link:finish(reply({}))
		return body.results
	end
	local function send(id, args, expires)
		link:command({id = id, type = "character.delete", args = args,
			expires_at = expires or clock + 60})
	end
	local function code_of(args, expires)
		return (C.run({type = "character.delete", args = args, expires_at = expires or clock + 60}))
	end
	local function character(name, online)
		world.auth[name] = {password = "#1#x#y", last_login = clock}
		world.records[name] = true
		world.known[name] = true
		local player = new_player(name)
		local id = grug_accounts.character_id(player)
		if not online then world.players[name] = nil end
		return player, id
	end

	-- The capability and the arguments.
	-- Round 86 added rewards.defaults after it.
	eq(C.CAPABILITIES[#C.CAPABILITIES - 1], "characters.delete", "I the capability")
	eq(code_of({admin = "jan"}), "invalid_args", "I no name")
	eq(code_of({name = "Ro wan", admin = "jan"}), "invalid_args", "I a name with a blank")
	eq(code_of({name = ("x"):rep(21), admin = "jan"}), "invalid_args", "I a name over 20")
	eq(code_of({name = "Rowan", admin = "jan", character_id = ("A"):rep(32)}), "invalid_args",
		"I an upper-case id")
	eq(code_of({name = "Rowan", admin = "jan", character_id = 5}), "invalid_args", "I an id no text")
	eq(code_of({name = "Rowan"}), "invalid_args", "I no admin")
	eq((C.run({type = "character.delete", args = {name = "Rowan", admin = "jan"}})), "invalid_args",
		"I no expires_at")

	-- No such character; another letter case; a wrong id; the refusals.
	eq(code_of({name = "Nobody", admin = "jan"}), "unknown_target", "I no login, no index")
	local rowan, rowan_id = character("Rowan", true)
	eq(code_of({name = "rowan", admin = "jan"}), "unknown_target", "I another letter case")
	local code, message = C.run({type = "character.delete", expires_at = clock + 60,
		args = {name = "Rowan", admin = "jan", character_id = ("f"):rep(32)}})
	eq(code, "unknown_target", "I a wrong character id")
	eq(message, "Rowan has another character id.", "I its message")
	character("Owner")
	code, message = C.run({type = "character.delete", expires_at = clock + 60,
		args = {name = "owner", admin = "jan"}})
	eq(code, "unknown_target", "I the admin's name in another case is no character")
	code, message = C.run({type = "character.delete", expires_at = clock + 60,
		args = {name = "Owner", admin = "jan"}})
	eq(code .. " " .. message, "refused Owner is the server administrator's character.",
		"I the server admin's character")
	eq(code_of({name = "Rowan", admin = "jan"}, clock + 9), "expired", "I too little time left")
	eq(#world.after + #world.disconnected + #cleared, 0, "I nothing happened so far")

	-- Online, end to end through the ledger.
	grug_accounts.apply_list({version = 3, characters = {
		{name = "Rowan", character_id = rowan_id, account_id = "a_1842"},
		{name = "Kept", character_id = ("b"):rep(32), account_id = "a_1842"}},
		accounts = {{id = "a_1842", name = "jan", rewards = {}}}})
	grug_mail.send_system("Rowan", "admin", "Server Admin", "Hi", "Text")
	check(mail:get_string("box:Rowan") ~= "", "I a mailbox to clear")
	guids.Rowan = rowan
	local logs = #world.logs
	send("del1", {name = "Rowan", admin = "jan", character_id = rowan_id})
	eq(#results(), 0, "I no answer yet")
	eq(world.disconnected[1][1] .. ": " .. world.disconnected[1][2],
		"Rowan: This character was deleted on the website.", "I disconnected with the text")
	eq(#world.kicked, 0, "I not through kick_player")
	eq(prejoin("ROWAN"), D.TEXT, "I no login during the deletion, any letter case")
	eq(prejoin("Kept"), nil, "I others join")
	code, message = C.run({type = "character.delete", expires_at = clock + 60,
		args = {name = "Rowan", admin = "jan"}})
	eq(code .. " " .. message, "refused Rowan is already being deleted.", "I a second deletion at once")
	link:command({id = "del1", type = "character.delete"})
	run_jobs(5)
	eq(#cleared, 0, "I online: nothing cleared")
	world.players.Rowan = nil -- left; the engine has not saved it yet
	run_jobs(5)
	eq(#cleared, 0, "I left but not saved: nothing cleared")
	eq(#results(), 0, "I a repeated delivery stays silent")
	guids.Rowan = nil
	run_jobs(1)
	eq(#cleared, 1, "I gone: the clears ran")
	eq(accounts:get_string("id:rowan"), "tombstone", "I the tombstone")
	eq(mail:get_string("box:Rowan"), "", "I the mailbox")
	eq(grug_accounts.account_of("Kept").id, "a_1842", "I another binding stays")
	check(not accounts:get_string("list"):find("Rowan", 1, true), "I the binding row went at once")
	eq(world.auth.Rowan ~= nil, true, "I the login stays until the commit")
	eq(#world.after, 1, "I one wait")
	check(math.abs(world.after[1][1] - 5.8) < 1e-9, "I one mod-storage commit and a step")
	run_jobs()
	eq(#cleared, 2, "I the clears again")
	eq(world.auth.Rowan, nil, "I the login went")
	eq(world.records.Rowan, nil, "I the player record went")
	local answer = results()
	eq(#answer, 1, "I one answer")
	eq(answer[1].code, "ok", "I ok")
	eq(answer[1].message, "Rowan (character " .. rowan_id .. ") deleted by admin jan.", "I the message")
	local named = 0
	for index = logs + 1, #world.logs do
		local text = world.logs[index][2]
		if text:find("Rowan", 1, true) then
			named = named + 1
			eq(world.logs[index][1], "action", "I the log line is an action line")
			check(text:find(rowan_id, 1, true) and text:find("jan", 1, true) and
				not text:find("a_1842", 1, true), "I name, id and admin, no account")
		end
	end
	eq(named, 1, "I one log line names the character")
	eq(prejoin("Rowan"), nil, "I the name is free again")
	eq(code_of({name = "Rowan", admin = "jan"}), "unknown_target", "I deleted: unknown_target")
	eq(code_of({name = "Rowan", admin = "jan", character_id = rowan_id}), "unknown_target",
		"I deleted: unknown_target with the id")

	-- Offline, without an id and never indexed: the tombstone all the same.
	world.auth.Cara, world.records.Cara = {password = "#1#x#y", last_login = clock}, true
	cleared = {}
	send("del2", {name = "Cara", admin = "jan"})
	run_jobs()
	answer = results()
	eq(answer[1].message, "Cara (no character id) deleted by admin jan.", "I offline without an id")
	eq(accounts:get_string("id:cara"), "tombstone", "I the tombstone without an entry")
	eq(#cleared, 2, "I cleared twice")

	-- A login gone but an index id left (a stopped deletion): found, finished.
	accounts:set_string("id:hal", ("c"):rep(32))
	send("del3", {name = "Hal", admin = "jan", character_id = ("c"):rep(32)})
	run_jobs()
	eq(results()[1].code, "ok", "I an index id without a login is finished")

	-- Not gone before the deadline: expired, disconnected, nothing cleared.
	local dora = character("Dora", true)
	cleared = {}
	send("del4", {name = "Dora", admin = "jan"}, clock + D.margin() + 3)
	run_jobs()
	answer = results()
	eq(answer[1].code, "expired", "I not gone in time: expired")
	eq(answer[1].message, "Dora was not deleted: the command expired first.", "I its message")
	eq(#cleared, 0, "I nothing cleared")
	check(world.auth.Dora and world.players.Dora == dora, "I nothing deleted")
	eq(prejoin("Dora"), nil, "I the block is off")

	-- Back in the game between the clears and the removal: once more.
	character("Ella")
	cleared = {}
	local disconnects = #world.disconnected
	send("del5", {name = "Ella", admin = "jan"})
	run_jobs(1)
	eq(#cleared, 1, "I Ella cleared")
	world.players.Ella = new_player("Ella")
	run_jobs(1)
	eq(#world.disconnected, disconnects + 1, "I disconnected again")
	world.players.Ella = nil
	run_jobs()
	eq(results()[1].code, "ok", "I then deleted")
	eq(#cleared, 3, "I cleared again before the removal")

	-- An error in a clear, and an engine that still holds the player.
	local _, fay_id = character("Fay")
	failing = true
	send("del6", {name = "Fay", admin = "jan"})
	run_jobs()
	failing = false
	answer = results()
	eq(answer[1].code .. " " .. answer[1].message, "error The deletion failed; see the server log.",
		"I a failing clear answers error")
	eq(prejoin("Fay"), D.TEXT, "I its tombstone beside a used login keeps it out")
	world.auth.Fay.last_login = -1
	eq(prejoin("Fay"), nil, "I a login never used is a new character's")
	world.auth.Fay.last_login = clock
	world.still_connected = true
	send("del7", {name = "Fay", admin = "jan"})
	run_jobs()
	world.still_connected = nil
	eq(results()[1].code, "error", "I remove_player answering 2 is an error")
	-- The website's retry carries the id; the game's index holds the
	-- tombstone, so the id cannot be compared: it finishes the deletion.
	local logged = #world.logs
	send("del8", {name = "Fay", admin = "jan", character_id = fay_id})
	run_jobs()
	answer = results()
	eq(answer[1].code .. " " .. answer[1].message,
		"ok Fay (character " .. fay_id .. ") deleted by admin jan.", "I the retry with the id finishes it")
	check(world.auth.Fay == nil and world.records.Fay == nil, "I its login and record went")
	check(world.logs[#world.logs][2]:find("Fay (character " .. fay_id .. ") deleted by admin jan.", 1, true)
		and #world.logs > logged, "I the log line names the id the website sent")
	eq(prejoin("Fay"), nil, "I and the name is free")
	eq(code_of({name = "Fay", admin = "jan", character_id = fay_id}), "unknown_target",
		"I a tombstone without a login stays unknown_target")

	-- A server lagging past expires_at between the steps removes nothing.
	local _, gus_id = character("Gus")
	send("del9", {name = "Gus", admin = "jan"}, clock + 30)
	run_jobs(1)
	clock = clock + 60
	run_jobs()
	answer = results()
	eq(answer[1].code .. " " .. answer[1].message,
		"expired Gus was not deleted completely: the command expired first. Send it again.",
		"I past expires_at at the removal: expired")
	check(world.auth.Gus and world.records.Gus, "I the login and the record stay")
	eq(prejoin("Gus"), D.TEXT, "I and the login is refused until a retry")
	send("del10", {name = "Gus", admin = "jan", character_id = gus_id})
	run_jobs()
	answer = results()
	eq(answer[1].code, "ok", "I the retry with the id deletes it")
	check(world.auth.Gus == nil and world.records.Gus == nil, "I its login and record went")

	-- The record_login guard: a join after the login went.
	local ghost = new_player("Ghost")
	logs = #world.logs
	core.builtin_auth_handler.record_login("Ghost")
	eq(world.logs[#world.logs][1], "warning", "I record_login without an entry: a warning, no error")
	check(not world.logs[#world.logs][2]:find("Ghost", 1, true), "I without the name")
	disconnects = #world.disconnected
	world.records.Ghost = true
	deleted_login(ghost)
	eq(world.disconnected[#world.disconnected][2], D.TEXT, "I sent away")
	eq(prejoin("Ghost"), D.TEXT, "I blocked while its record goes")
	world.players.Ghost = nil
	run_jobs()
	eq(world.records.Ghost, nil, "I its record went")
	eq(prejoin("Ghost"), nil, "I then free")
	eq(#results(), 0, "I no answer for it")
	world.auth.Gil = {last_login = clock}
	disconnects = #world.disconnected
	deleted_login(new_player("Gil"))
	eq(#world.disconnected, disconnects, "I a join with a login is left alone")
	world.auth.Gil.last_login = 1
	core.builtin_auth_handler.record_login("Gil")
	eq(world.auth.Gil.last_login, clock, "I record_login still records")
end

-- J. grug_mail at the start and for a deleted character (Round 83) -----------
do
	fresh_world()
	load_mail()
	local M, S = grug_mail.model, grug_mail.store
	local mail = world.stores.grug_mail
	local old, new = clock - M.EXPIRY - 1, clock - 10
	local function box(name, letters)
		local b = M.new_box()
		for _, letter in ipairs(letters) do M.deliver(b, letter) end
		mail:set_string("box:" .. name, serialize(b))
	end
	box("Ann", {M.letter(1, "player", "Vex", "Old", "x", {}, old), M.letter(2, "player", "Vex", "New", "y", {}, new)})
	box("Ben", {M.letter(3, "player", "Ann", "Old", "x", {}, old)})
	mail:set_string("sent:Ann", serialize({M.sent_copy(4, "Vex", "Old", "x", 5, {}, old)}))
	mail:set_string("sent:Vex", serialize({M.sent_copy(5, "Ann", "New", "y", 5, {}, new)}))
	mail:set_string("tickets", serialize({M.ticket(6, "Vex", "Question", "Old", "x", {}, old),
		M.ticket(7, "Vex", "Question", "Mine", "y", {}, new),
		M.report_ticket(8, "Ann", M.letter(2, "player", "Vex", "New", "y", {}, new), "spam", "",
			{}, {}, new)}))
	mail:set_string("broadcasts", serialize({{id = 9, subject = "Old", body = "x", time = old}}))
	eq(S.prune_all(), 6, "J the start reads every list")
	eq(#S.box("Ann").letters, 1, "J an expired letter went")
	eq(#S.box("Ben").letters, 0, "J a box of expired letters is empty")
	eq(mail:get_string("sent:Ann"), "", "J an expired sent list goes whole")
	eq(#S.tickets(), 2, "J an expired ticket went")
	eq(#S.broadcasts(), 0, "J an expired broadcast went")

	-- Vex is deleted: its box, sent copies, tickets and index row go; what
	-- Ann holds about it stays (ruling 1).
	S.index_player("Vex", "accord")
	S.index_player("Ann", "accord")
	box("Vex", {M.letter(10, "admin", "Server Admin", "Hi", "z", {"default:dirt 5"}, new)})
	grug_mail.forget_character("Vex")
	eq(mail:get_string("box:Vex"), "", "J its mailbox, attachments with it")
	eq(mail:get_string("sent:Vex"), "", "J its sent copies")
	local tickets = S.tickets()
	eq(#tickets, 1, "J its own ticket went")
	eq(tickets[1].from .. " " .. tickets[1].report.from, "Ann Vex", "J a report about its letter stays")
	eq(S.lookup("vex"), nil, "J its index row")
	eq(S.lookup("ann"), "Ann", "J others stay indexed")
	eq(S.box("Ann").letters[1].from, "Vex", "J its letter to Ann stays")
	grug_mail.forget_character("Vex")
	eq(#S.tickets(), 1, "J a second clear changes nothing")
end

os.time = real_time -- luacheck: ignore
print(("r691_bridge PASS (%d checks)"):format(checks))
