-- Disposable engine probe (Round 48 lane ADMIN): the Admin Mail tab for
-- screenshots. Never shipped: tools/r48_admin/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r48_mail's probe.
--
-- It grants the character mail_admin, fills the admin inbox with sample
-- messages (a bug report, feedback, a question, a Player report with its
-- letter copy, one closed) and an announcement, and shows the inventory
-- window's Admin Mail page, driving it through the page's own field handler.

local P = "[r48admin] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r48admin_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r48admin_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- Sample messages from other characters, oldest first (the inbox lists
-- newest first), with the header the mailbox window would freeze.
local function fill_inbox()
	local M, S = grug_mail.model, grug_mail.store
	local now = os.time()
	local tickets = S.tickets()
	local function header(level, faction, race, class, x, y, z, town)
		return {mailbox = "Mailbox in " .. town, version = grug_inventory.GAME_VERSION,
			level = level, faction = faction, race = race, class = class,
			pos = {x = x, y = y, z = z}}
	end
	local function add(ticket) table.insert(tickets, 1, ticket) end
	local closed = M.ticket(S.next_id(), "Brakka", "Other", "Name change?",
		"Can I change the name of my character?",
		header(12, "throng", "orc", "warrior", -2310, 9, 880, "Grakmar"), now - 4 * 86400)
	M.close(closed, "admin", false, now - 3 * 86400)
	add(closed)
	local letter = M.letter(S.next_id(), "player", "Scamz", "Cheap gold, pay first",
		"Send me 200c and I send you 10 gold bars tomorrow. Promise!",
		{"grug_money:bag_of_coins"}, now - 2 * 86400)
	add(M.report_ticket(S.next_id(), "Elowen", letter, "Scam", "He asked three people.",
		{"Bag of Coins"}, header(18, "accord", "elf", "priest", 455, 21, -1302, "Dawnmere"),
		now - 2 * 86400))
	add(M.ticket(S.next_id(), "Grashnak", "Question", "Can I move my Claim Stone?",
		"I placed it too close to the river. Can I pick it up again?",
		header(21, "throng", "troll", "mage", -2290, 12, 910, "Grakmar"), now - 86400))
	add(M.ticket(S.next_id(), "Morwen", "Feedback", "Love the swamp, but it is very dark",
		"The new swamp is great, but at night I cannot see a thing.",
		header(16, "accord", "human", "priest", 120, 4, 2300, "Dawnmere"), now - 3600))
	add(M.ticket(S.next_id(), "Kestrel", "Bug report", "Waystone in Hearthpine does nothing",
		"When I right-click the waystone next to the inn nothing happens. It worked yesterday.",
		header(23, "accord", "human", "warrior", 412, 18, -1290, "Dawnmere"), now - 600))
	S.save_tickets(tickets)
	grug_mail.send_broadcast("Restart on Sunday, 20:00",
		"The server restarts on Sunday at 20:00 for an update. It will be back within a few minutes.",
		"admin")
end

local function context_of(player) return sfinv.get_or_create_context(player) end

local function show(player)
	core.show_formspec(NAME, "grug_probe_r48_admin:inv",
		sfinv.get_formspec(player, context_of(player)))
end

local function fields(player, list)
	grug_mail.admin_fields(player, context_of(player), list)
	show(player)
end

local function serial(player, action)
	local state_ = context_of(player).grug_mail_admin
	return "mail_admin_" .. action .. "_" .. state_.draw
end

local function row_of(player, subject)
	for index, entry in ipairs(context_of(player).grug_mail_admin.rows or {}) do
		if entry.subject == subject then return index end
	end
	return 1
end

-- Each shot: a step that sets the page up, then the screenshot.
local SHOTS = {
	{name = "X1_inbox", run = function(player)
		sfinv.set_page(player, grug_mail.ADMIN_PAGE)
		show(player)
	end},
	{name = "X2_inbox_selected", run = function(player)
		fields(player, {mail_admin_list = "CHG:" ..
			row_of(player, "Waystone in Hearthpine does nothing") .. ":3"})
		local state_ = context_of(player).grug_mail_admin
		state_.answer = "Thanks for the report! The waystone needed a server restart; " ..
			"it works again." .. state_.answer
		show(player)
	end},
	{name = "X3_report", run = function(player)
		fields(player, {mail_admin_list = "CHG:" ..
			row_of(player, "Report: letter from Scamz") .. ":3"})
	end},
	{name = "X4_answered", run = function(player)
		fields(player, {mail_admin_list = "CHG:" ..
			row_of(player, "Waystone in Hearthpine does nothing") .. ":3"})
		fields(player, {mail_admin_answer = "Thanks for the report! The waystone needed a " ..
			"server restart; it works again.", [serial(player, "answer")] = "Send answer and close"})
	end},
	{name = "X5_all_closed", run = function(player)
		fields(player, {mail_admin_filter_all = "All"})
		fields(player, {mail_admin_list = "CHG:" .. row_of(player, "Name change?") .. ":3"})
	end},
	{name = "X6_compose", run = function(player)
		fields(player, {mail_admin_new = "New admin letter"})
		fields(player, {mail_admin_to = "Kestrel", mail_admin_subject = "About your waystone",
			mail_admin_body = "The waystone in Hearthpine works again. Thanks for telling us!",
			mail_admin_preview = "Update preview"})
	end},
	{name = "X7_compose_all", run = function(player)
		fields(player, {mail_admin_all = "true", mail_admin_subject = "Restart on Sunday, 20:00",
			mail_admin_body = "The server restarts on Sunday at 20:00 for an update. " ..
			"It will be back within a few minutes."})
	end},
	{name = "X8_announcements", run = function(player)
		fields(player, {mail_admin_back = "Back to admin mail"})
		fields(player, {mail_admin_filter_announcements = "Announcements"})
		fields(player, {mail_admin_list = "CHG:1:2"})
	end},
}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		local privs = core.get_player_privs(NAME)
		privs.mail_admin = true
		core.set_player_privs(NAME, privs)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		fill_inbox()
		log("mail_admin " .. tostring(core.check_player_privs(NAME, {mail_admin = true})))
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			shot.run(player)
			log("formspec " .. shot.name .. " bytes " ..
				tostring(#sfinv.get_formspec(player, context_of(player))))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
