-- Disposable engine probe (0.69.1 web bridge). Never shipped:
-- tools/r691_bridge/run.sh stages it through tools/luanti_headless.sh. It
-- reads one JSON request from <world>/r691_in, does it inside the server and
-- answers in <world>/r691_out. No test logic lives here: the checks are in
-- scenario.py. Chat cannot be typed by a client without a window, so `chat`
-- walks the engine's registered hooks as Server::handleChat does.

local IN = core.get_worldpath() .. "/r691_in"
local OUT = core.get_worldpath() .. "/r691_out"

local chat_lines = {}
local chat_send_all = core.chat_send_all
function core.chat_send_all(text)
	chat_lines[#chat_lines + 1] = text
	return chat_send_all(text)
end

local feed_lines = {}
local feed = grug_core.feed
function grug_core.feed(player, kind, text, key)
	feed_lines[#feed_lines + 1] = text
	return feed(player, kind, text, key)
end

local function submit(player, fields)
	for _, func in ipairs(core.registered_on_player_receive_fields) do
		if func(player, "", fields) then return end
	end
end

local OPS = {}

function OPS.status()
	return {active = grug_bridge.active, prepared = grug_core.world_preparation_status().ready}
end

-- Finishes character creation; ready once the character has arrived.
function OPS.ready(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	if not grug_core.world_preparation_status().ready then return {prepared = false} end
	if player:get_meta():get_string("grug_classes:arriving") ~= "" then return {arriving = true} end
	if not grug_classes.get_class(player) then
		submit(player, {faction_accord = "Accord"})
		submit(player, {race_human = "Human"})
		submit(player, {class_warrior = "Warrior"})
		submit(player, {create_character = "Create"})
		return {created = false}
	end
	core.close_formspec(request.name, "")
	return {done = true}
end

function OPS.state(request)
	local player = core.get_player_by_name(request.name)
	if not player then return {online = false} end
	local inv = player:get_inventory()
	local privs = {}
	for priv in pairs(core.get_player_privs(request.name)) do privs[#privs + 1] = priv end
	table.sort(privs)
	local dirt = 0
	for _, list in ipairs(grug_inventory.carried_lists(inv)) do
		for _, stack in ipairs(inv:get_list(list) or {}) do
			if stack:get_name() == "default:dirt" then dirt = dirt + stack:get_count() end
		end
	end
	return {online = true, money = grug_money.get(player), xp = grug_xp.get_xp(player),
		level = grug_xp.get_level(player), privs = privs, dirt = dirt,
		letters = #grug_mail.store.box(request.name).letters}
end

function OPS.ticket(request)
	local player = core.get_player_by_name(request.name)
	local ok, message = grug_mail.send_ticket(player, "Question", request.subject, "Body", "Probe")
	return {ok = ok, message = message}
end

-- As Server::handleChat: the hooks in order, until one returns true.
function OPS.chat(request)
	for _, func in ipairs(core.registered_on_chat_messages) do
		if func(request.name, request.message) then return {eaten = true} end
	end
	return {eaten = false}
end

function OPS.lines()
	return {chat = chat_lines, feed = feed_lines}
end

function OPS.shutdown()
	core.after(0.5, core.request_shutdown)
	return {}
end

local last_id
local clock = 0
core.register_globalstep(function(dtime)
	clock = clock + dtime
	if clock < 0.2 then return end
	clock = 0
	local file = io.open(IN, "r")
	if not file then return end
	local text = file:read("*a")
	file:close()
	local request = core.parse_json(text, nil, true)
	if type(request) ~= "table" or request.id == last_id then return end
	last_id = request.id
	local ok, result = pcall(OPS[request.op], request)
	if not ok then result = {probe_error = tostring(result)} end
	core.safe_file_write(OUT, core.write_json({id = request.id, result = result}))
end)
