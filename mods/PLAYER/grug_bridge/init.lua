-- The web bridge (0.69.1, docs/technical/web-bridge.md): the hosting
-- platform's website administers a running realm through one HTTP exchange
-- this mod starts. Inert unless the engine granted the HTTP API and both
-- settings are present: no request, no hook, one log line. A world without
-- them plays exactly as it would without this mod.
grug_bridge = {active = false}

-- Only here: request_http_api answers in a mod's main scope, and the table
-- stays in this local.
local http = core.request_http_api and core.request_http_api()
local url = core.settings:get("grug_bridge.url") or ""
local token = core.settings:get("grug_bridge.token") or ""

local function log(level, text)
	core.log(level, "[grug_bridge] " .. text)
end

do
	local missing = {}
	if not http then missing[#missing + 1] = "the HTTP API (secure.http_mods)" end
	if url == "" then missing[#missing + 1] = "grug_bridge.url" end
	if token == "" then missing[#missing + 1] = "grug_bridge.token" end
	if #missing > 0 then
		log("action", "inert, missing: " .. table.concat(missing, ", "))
		return
	end
end

local path = core.get_modpath(core.get_current_modname())
local L = dofile(path .. "/link.lua")
local Mirror = dofile(path .. "/mirror.lua")
local B = dofile(path .. "/bans.lua")
local C = dofile(path .. "/commands.lua")

grug_bridge.active = true

local storage = core.get_mod_storage()
local banlist = B.load(storage, core.deserialize)
local joined_at = {}

-- A hook that may not fail: an error here would end the server.
local function guarded(what, func)
	return function(...)
		local ok, result = pcall(func, ...)
		if ok then return result end
		log("error", what .. " failed: " .. tostring(result))
	end
end

local function online_rows()
	local rows = {}
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local info = core.get_player_information(name) or {}
		rows[#rows + 1] = {name = name, level = grug_xp.get_level(player),
			class = grug_classes.get_class(player), race = grug_classes.get_race(player),
			faction = grug_factions.get_faction(player),
			joined_at = joined_at[name] or os.time(), address = info.address}
	end
	return rows
end

local function apply_banlist(sent)
	local list = B.store(storage, core.serialize, sent)
	if not list then
		log("warning", "ignored a ban list without a version")
		return
	end
	banlist = list
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local ban = B.active(banlist, name, os.time())
		if ban ~= nil then
			-- Not kick_player: the text would gain its "Kicked: ".
			core.disconnect_player(name, B.text(ban))
		end
	end
end

local mirror
local function resync(name)
	if name ~= "mail" then return end
	mirror:resync(grug_mail.tickets(), grug_mail.broadcasts())
end

local link = L.new({
	boot = core.sha1(os.time() .. ":" .. core.get_us_time()):sub(1, 16),
	version = grug_inventory.GAME_VERSION or "unknown",
	capabilities = C.CAPABILITIES,
	encode = core.write_json,
	decode = function(text) return (core.parse_json(text, nil, true)) end,
	now = os.time,
	log = log,
	clean = C.plain,
	online_rows = online_rows,
	banlist_version = function() return banlist.version end,
	run_command = C.run,
	on_banlist = apply_banlist,
	on_resync = resync,
})

mirror = Mirror.new(function(event) link:push(event) end, core.write_json)
-- The lists as they stand now; the website asks for them at a new boot. Read
-- before the hooks: a read may prune and write.
mirror:seed("tickets", grug_mail.tickets())
mirror:seed("broadcasts", grug_mail.broadcasts())
for _, kind in ipairs({"tickets", "broadcasts"}) do
	grug_mail.store.register_on_saved(kind, guarded("the mail mirror", function(list)
		mirror:saved(kind, list)
	end))
end

core.register_on_joinplayer(guarded("the join hook", function(player)
	joined_at[player:get_player_name()] = os.time()
	link:online_changed()
end))
core.register_on_leaveplayer(guarded("the leave hook", function(player)
	joined_at[player:get_player_name()] = nil
	link:online_changed()
end))
grug_xp.register_on_level_change(guarded("the level hook", function()
	link:online_changed()
end))
grug_classes.register_on_arrival(guarded("the arrival hook", function()
	link:online_changed()
end))

core.register_on_prejoinplayer(guarded("the ban check", function(name)
	local ban = B.active(banlist, name, os.time())
	if ban ~= nil then return B.text(ban) end
end))

-- Before the engine's own check of `shout`, so it is made here. What this
-- hook returns would decide over the line: it returns nothing.
core.register_on_chat_message(guarded("the chat hook", function(name, message)
	if message:sub(1, 1) == "/" or not core.check_player_privs(name, {shout = true}) then
		return
	end
	local text = C.plain(message, C.CHAT_MAX)
	if text ~= "" then link:push({type = "chat", name = name, text = text}) end
end))

local address = url:gsub("/+$", "") .. "/v1/sync"
local headers = {"Authorization: Bearer " .. token, "Content-Type: application/json"}
local send

local function answered(res)
	local ok, delay = pcall(link.finish, link, res)
	if not ok then
		log("error", "reading an answer failed: " .. tostring(delay))
		delay = L.REFUSED_RETRY
	end
	core.after(delay, send)
end

send = function()
	local ok, failure = pcall(function()
		http.fetch({url = address, method = "POST", data = link:request(),
			timeout = L.TIMEOUT, extra_headers = headers, quiet = true}, answered)
	end)
	if not ok then
		log("error", "sending failed: " .. tostring(failure))
		core.after(L.REFUSED_RETRY, send)
	end
end

core.after(L.DEFAULT_NEXT_MS / 1000, send)
