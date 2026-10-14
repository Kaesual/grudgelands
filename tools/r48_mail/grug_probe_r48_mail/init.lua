-- Disposable engine probe (Round 48 lane MAIL): the mailbox window for
-- screenshots. Never shipped: tools/r48_mail/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r47_tc's probe.
--
-- Without lane WORLD's mailbox node the probe registers a stand-in under the
-- final name grug_mapgen:mailbox (a plain box); either way it places one
-- three nodes east of the start's waystone, fills the character's mailbox
-- with sample letters, a broadcast and tickets, and opens every tab and
-- dialog through the window's own field handler.

local P = "[r48mail] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r48mail_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

if not core.registered_nodes["grug_mapgen:mailbox"] then
	core.register_node(":grug_mapgen:mailbox", {
		description = "Mailbox (probe stand-in)",
		tiles = {"default_wood.png"},
		groups = {not_in_creative_inventory = 1},
		on_rightclick = function(pos, _, clicker) grug_mail.open_mailbox(clicker, pos) end,
	})
end

local state = {phase = "wait", clock = 0}
local mailbox

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function mail_fields(player, fields)
	local session = grug_mail.session(NAME)
	submit(player, session and session.formname or "", fields)
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r48mail_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The sample mail, oldest first (the window lists newest first).
local function fill_mail(player)
	local M, S = grug_mail.model, grug_mail.store
	local name = player:get_player_name()
	local now = os.time()
	local box = S.box(name)
	local function add(kind, from, subject, body, items, age_days, read)
		local letter = M.letter(S.next_id(), kind, from, subject, body, items,
			now - age_days * 86400)
		letter.read = read
		M.deliver(box, letter)
		return letter
	end
	add("player", "Thalion", "Re: Group for the rift?",
		"Count me in. I will bring potions.\n\n> Anyone up for the rift tonight?", {}, 4, true)
	add("npc", "Housing Steward", "The king has heard of you",
		"[Placeholder text by lane TEXT]\n\nCome and see me in your capital.", {}, 3, true)
	add("player", "Brakka", "Your axe, as promised",
		"Here is the bronze axe I owed you. The ingots are for the next repair.\n\n" ..
		"See you at the forge.\nBrakka", {"grug_materials:axe_bronze", "grug_materials:iron_bar 12"}, 1, false)
	add("npc", "Riding Trainer", "Time for a mount",
		"[Placeholder text by lane TEXT]\n\nVisit me in your capital and choose your first mount.",
		{}, 0, false)
	add("admin", M.ADMIN_LABEL, "Welcome to Grudgelands",
		"[Placeholder text by lane TEXT]\n\nThis mailbox stands in every capital and every " ..
		"starting village. Write to us any time under \"To the admin\": feedback on the game " ..
		"and bug reports are welcome.", {}, 0, false)
	S.save_box(name, box)
	grug_mail.send_broadcast("Server restart tonight",
		"The server restarts tonight at 22:00 for the update to 0.48.0.", "probe")
	grug_mail.send_ticket(player, "Question", "Can I move my Claim Stone?",
		"I placed it too close to the river.", "Mailbox in Dawnmere")
	grug_mail.send_ticket(player, "Feedback", "Love the swamp, but it is dark",
		"The new swamp is great. A bit dark at night.", "Mailbox in Dawnmere")
	local tickets = grug_mail.tickets()
	grug_mail.answer_ticket(tickets[2].id, "probe", "Yes: pick it up and place it again.")
	grug_mail.refresh_count(name)
end

local function rows()
	return grug_mail.store.box(NAME).letters
end
local function row_of(subject)
	for index, letter in ipairs(rows()) do
		if letter.subject == subject then return index end
	end
	return 1
end

-- Each shot: a step that sets the window up, then the screenshot.
local SHOTS = {
	{name = "L1_letters_admin", run = function(player)
		-- Through the node's own right-click (lane WORLD's node once merged).
		local node = core.get_node(mailbox)
		core.registered_nodes[node.name].on_rightclick(mailbox, node, player, ItemStack(""))
		log("right-click opened the window: " .. tostring(grug_mail.session(NAME) ~= nil))
		mail_fields(player, {letters = "CHG:" .. row_of("Welcome to Grudgelands") .. ":5"})
	end},
	{name = "L2_letters_player", run = function(player)
		mail_fields(player, {letters = "CHG:" .. row_of("Your axe, as promised") .. ":5"})
	end},
	{name = "L3_report_dialog", run = function(player)
		mail_fields(player, {report = "Report"})
	end},
	{name = "L4_delete_dialog", run = function(player)
		mail_fields(player, {report_cancel = "Cancel"})
		mail_fields(player, {delete = "Delete"})
	end},
	{name = "L5_letters_npc", run = function(player)
		mail_fields(player, {delete_cancel = "Cancel"})
		mail_fields(player, {letters = "CHG:" .. row_of("Time for a mount") .. ":5"})
	end},
	{name = "A1_announcements", run = function(player)
		mail_fields(player, {grug_mail_tab = "2"})
		mail_fields(player, {announcements = "CHG:1:5"})
	end},
	{name = "W1_write", run = function(player)
		local inv = player:get_inventory()
		inv:set_stack(grug_mail.ATTACH_LIST, 1, ItemStack("grug_materials:iron_bar 12"))
		inv:set_stack(grug_mail.ATTACH_LIST, 2, ItemStack("default:apple 5"))
		local session = grug_mail.session(NAME)
		session.draft = {to = "Brakka", subject = "Re: Your axe, as promised",
			body = "Thanks, the axe is great! Here are the ingots back.\n\n" ..
			"> Here is the bronze axe I owed you."}
		mail_fields(player, {grug_mail_tab = "3"})
	end},
	{name = "W2_write_refused", run = function(player)
		mail_fields(player, {mail_to = "Grommash", mail_subject = "Hi", mail_body = "Hello",
			write_send = "Send"})
	end},
	{name = "T1_to_the_admin", run = function(player)
		local session = grug_mail.session(NAME)
		session.admin = {topic = 2, subject = "Waystone in Dawnmere does nothing",
			body = "When I right-click the waystone next to the inn nothing happens."}
		mail_fields(player, {grug_mail_tab = "4"})
		mail_fields(player, {tickets = "CHG:2:1"})
	end},
	{name = "H1_help_mail", run = function(player)
		mail_fields(player, {quit = "true"})
		core.close_formspec(NAME, grug_mail.session(NAME) and grug_mail.session(NAME).formname or "")
		local context = sfinv.get_or_create_context(player)
		context.grug_help_section = "mail"
		sfinv.set_page(player, "grug_inventory:help")
		core.show_formspec(NAME, "grug_probe_r48_mail:help",
			sfinv.get_formspec(player, sfinv.get_or_create_context(player)))
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
		local socket
		for _, entry in ipairs(grug_core.settlement_sockets("human")) do
			if entry.role == "waypoint" then socket = entry end
		end
		mailbox = vector.offset(socket.pos, 3, 0, 0)
		local stand = vector.offset(socket.pos, 3, 0, 2)
		state.phase = "emerge"
		core.emerge_area(vector.offset(mailbox, -8, -4, -8), vector.offset(mailbox, 8, 8, 8),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				core.set_node(mailbox, {name = "grug_mapgen:mailbox"})
				player:set_pos(stand)
				grug_money.set(player, 124)
				fill_mail(player)
				log("mailbox at " .. core.pos_to_string(mailbox) .. " label " ..
					tostring(grug_mail.mailbox_label(mailbox)))
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				log("READY")
			end)
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
			player:set_physics_override({gravity = 0, speed = 0, jump = 0})
			shot.run(player)
			log("formspec " .. shot.name .. " bytes " .. tostring(#(grug_mail.session(NAME) and
				grug_mail.window_formspec(player, grug_mail.session(NAME)) or "")))
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
