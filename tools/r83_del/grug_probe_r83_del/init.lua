-- Disposable engine probe (Round 83, character.delete). Never shipped:
-- tools/r83_del/run.sh stages it through tools/luanti_headless.sh. It reads one
-- JSON request from <world>/r83_in, does it inside the server and answers in
-- <world>/r83_out. No test logic lives here: the checks are in scenario.py.
-- It seeds a character into the stores of round83-plan.md §3.2 through each
-- mod's own API, reports what a name still has, and timestamps the steps of a
-- deletion (core.get_us_time) for the timing the plan asks to confirm.

local IN = core.get_worldpath() .. "/r83_in"
local OUT = core.get_worldpath() .. "/r83_out"

local function submit(player, fields)
	for _, func in ipairs(core.registered_on_player_receive_fields) do
		if func(player, "", fields) then return end
	end
end

--
-- Timing: the watched names' disconnect, leave, the two engine conditions,
-- each run of the clears and the removal.
--

local watched, times = {}, {}
local function add(name, what)
	local list = times[name]
	list[#list + 1] = {what = what, us = core.get_us_time()}
end
-- The two engine conditions, looked at every step and before every stamp:
-- a core.after job may see them change before this mod's globalstep does.
local function observe(name)
	local state = watched[name]
	if not state.player_nil and core.get_player_by_name(name) == nil then
		state.player_nil = true
		add(name, "get_player_by_name=nil")
	end
	if not state.guid_nil and core.objects_by_guid[name] == nil then
		state.guid_nil = true
		add(name, "objects_by_guid=nil")
	end
end
local function stamp(name, what)
	if not watched[name] then return end
	observe(name)
	add(name, what)
end

local disconnect = core.disconnect_player
function core.disconnect_player(name, ...)
	stamp(name, "disconnect")
	return disconnect(name, ...)
end
local remove_player = core.remove_player
function core.remove_player(name)
	local result = remove_player(name)
	stamp(name, "remove_player=" .. tostring(result))
	return result
end
local clear = grug_core.character_delete.clear
function grug_core.character_delete.clear(name)
	stamp(name, "clear")
	return clear(name)
end
core.register_on_leaveplayer(function(player)
	stamp(player:get_player_name(), "on_leaveplayer")
end)
core.register_globalstep(function()
	for name in pairs(watched) do observe(name) end
end)

local OPS = {}

function OPS.watch(request)
	watched[request.name] = {}
	times[request.name] = {}
	add(request.name, "watch")
	observe(request.name)
	return {}
end

function OPS.timing(request)
	return {times = times[request.name] or {}}
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
	local pos = vector.round(player:get_pos())
	return {done = true, id = grug_accounts.character_id(player), pos = pos}
end

-- An online character's party favourites (another character's player meta).
function OPS.favourite(request)
	local player = core.get_player_by_name(request.name)
	player:get_meta():set_string("grug_parties:favorites", core.serialize({request.other}))
	return {}
end

-- Every store of round83-plan.md §3.2 for `victim` (offline), and the
-- references to it in `other`'s data. `at` is a position near the arrival,
-- in the loaded map.
function OPS.seed(request)
	local victim, other, at = request.victim, request.other, request.at
	local M, S = grug_mail.model, grug_mail.store
	local now = os.time()
	-- Mail: a letter with an attachment, letters both ways with their sent
	-- copies, a ticket and the other's report of the victim's letter.
	assert(grug_mail.send_system(victim, "admin", "Server Admin", "Gift", "For you",
		{"default:dirt 5"}))
	local from_victim = M.letter(S.next_id(), "player", victim, "From " .. victim, "hello", {}, now)
	local box = S.box(other)
	M.deliver(box, from_victim)
	S.save_box(other, box)
	local sent = S.sent(victim)
	M.keep_sent(sent, M.sent_copy(from_victim.id, other, from_victim.subject, "hello", 5, {}, now))
	S.save_sent(victim, sent)
	local to_victim = M.letter(S.next_id(), "player", other, "To " .. victim, "hi", {}, now)
	box = S.box(victim)
	M.deliver(box, to_victim)
	S.save_box(victim, box)
	sent = S.sent(other)
	M.keep_sent(sent, M.sent_copy(to_victim.id, victim, to_victim.subject, "hi", 5, {}, now))
	S.save_sent(other, sent)
	local header = {level = 1, faction = "accord", race = "human", class = "warrior",
		pos = {x = at.x, y = at.y, z = at.z}, mailbox = "Probe", version = "probe"}
	local tickets = S.tickets()
	table.insert(tickets, 1, M.ticket(S.next_id(), victim, "Question", "Help", "Please", header, now))
	table.insert(tickets, 1, M.report_ticket(S.next_id(), other, from_victim, M.REPORT_REASONS[1], "",
		{}, header, now))
	S.save_tickets(tickets)
	-- Housing: the victim's activated claim with its stone, the other's claim
	-- where the victim has a right, map-reset belongings and packed contents.
	local model = grug_housing.model
	local stone = {x = at.x, y = at.y + 3, z = at.z}
	core.load_area(stone)
	local claim = model.create(victim, stone)
	model.activate(claim, 5)
	core.set_node(stone, {name = grug_housing.STONE_ITEM})
	local others_stone = {x = at.x, y = at.y + 6, z = at.z}
	local others = model.create(other, others_stone)
	model.activate(others, 5)
	core.set_node(others_stone, {name = grug_housing.STONE_ITEM})
	model.set_permission(others, victim, "everything")
	if request.third then
		model.set_permission(others, request.third, "interact")
		assert(grug_mail.send_system(request.third, "admin", "Server Admin", "Hello", "Text"))
	end
	grug_housing.storage:set_string("recovered:" .. victim .. ":1:1", "default:dirt 3")
	grug_housing.storage:set_string("packed:" .. victim .. ":1:1", core.serialize({main = {"default:dirt"}}))
	-- grug_home's "claim lost" notice, as a loss event writes it.
	grug_housing.notify_claim_changed({id = 9999, owner = victim}, "destroyed")
	-- A queued manual achievement.
	local ok, message = core.registered_chatcommands.achievement.func(other, "grant " .. victim .. " supporter")
	assert(ok, message)
	-- A locked chest of the victim's in the world (it stays, ruling 9).
	local chest = {x = at.x + 2, y = at.y, z = at.z + 2}
	core.load_area(chest)
	core.set_node(chest, {name = "default:chest_locked"})
	local meta = core.get_meta(chest)
	meta:set_string("owner", victim)
	meta:set_string("infotext", "Locked Chest (owned by " .. victim .. ")")
	return {stone = stone, chest = chest, claim = claim.id, others = others.id}
end

-- What a name still has.
function OPS.report(request)
	local name = request.name
	local S = grug_mail.store
	local from = 0
	for _, ticket in ipairs(S.tickets()) do
		if ticket.from == name then from = from + 1 end
	end
	local owned, rights = 0, 0
	for _, claim in ipairs(grug_housing.model.all_claims()) do
		if claim.owner == name then owned = owned + 1 end
		if claim.permissions[name] then rights = rights + 1 end
	end
	-- Counted from the keys: recovered.lua reads them once per start, and
	-- the seed writes them while the server runs.
	local recovered, prefix = 0, "recovered:" .. name .. ":"
	for _, key in ipairs(grug_housing.storage:get_keys()) do
		if key:sub(1, #prefix) == prefix then recovered = recovered + 1 end
	end
	local _, claim_state = grug_housing.player_claim(name)
	local party = grug_parties.view(name)
	local account = grug_accounts.account_of(name)
	local player = core.get_player_by_name(name)
	return {auth = core.get_auth_handler().get_auth(name) ~= nil,
		online = player ~= nil, index = grug_accounts.index_entry(name),
		account = account and account.id or nil,
		letters = #S.box(name).letters, sent = #S.sent(name), tickets = from,
		mail_index = S.lookup(name), clan_role = grug_clans.role_of(name),
		party = party and #party.members or 0, claim_state = claim_state, claims = owned,
		rights = rights, recovered = recovered,
		class = player and grug_classes.get_class(player) or nil,
		character_id = player and player:get_meta():get_string("grug_accounts:character_id") or nil}
end

function OPS.node(request)
	core.load_area(request.pos)
	local node = core.get_node_or_nil(request.pos)
	return {name = node and node.name or nil}
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
