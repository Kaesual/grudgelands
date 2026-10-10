local FORMNAME = "grug_jobs:trainer"

-- Professions every character knows from the start (spec ruling 28, Round
-- 45): no trainer teaches them. The trainer sockets the world data still
-- gives them (every start and every capital) hold a mender instead: no
-- trainer dialog, no teaching, no map icon, but a click opens the repair
-- form with the trainers' rules and prices (the user, 2026-10-09). A
-- runtime mapping in the trainer-role readers decides it, asking
-- trainer_teaches: grug_mobs/start_npcs.lua (at placement and at every
-- activation), grug_map/providers.lua and open_trainer below.
grug_jobs.STARTER_PROFESSIONS = {cooking = true}

-- The repair NPC's nametag, in this one place (the user, 2026-10-09: the
-- same in every town; a title, not a person's name).
grug_jobs.MENDER_TITLE = "Grudge-Free Repairs"

-- The greetings (0.45.1, fix plan row 12): one per trainer profession, shown
-- on top of its trainer window, and the mender's, shown in its repair form
-- (grug_repair/providers.lua). The same text in every town. Texts by GPT-6
-- Astra and Opus, picked by the user on 2026-10-10 (the proposals are in
-- tools/r451_tx). Each window keeps room for three lines (about 200
-- characters); a longer text grows the window.
grug_jobs.GREETINGS = {
	weaponsmith = "Ready to learn weaponsmithing? I'll show you how to make swords, daggers " ..
		"and battle axes at the forge, one good hammer stroke at a time.",
	armorsmith = "Ah, you'd like to learn armorsmithing? Wise choice! At this forge I'll " ..
		"teach you to make metal armor and shields: the kind that answers every " ..
		"blow with a firm, ringing 'no'.",
	alchemist = "Curious about Alchemy? You're welcome at the brewing stand, where I'll " ..
		"teach you to bottle a little help for the road in potions and elixirs.",
	tailor = "Ah, you'd like to learn tailoring! Join me at the tailor bench, and " ..
		"we'll make cloth armor, roomy bags and well-bound spellbooks.",
	leatherworker = "Good leather has many journeys in it. Join me at the tanning rack, and " ..
		"I'll teach you to make leather armor, bags and bows for yours.",
	woodcarver = "You bring the magic; I'll teach you to make something to wave it with. " ..
		"At the carving bench, woodcarving gives you wands and staves.",
	goldsmith = "An eye for the finer things? Join me at the jeweller's bench, and I'll " ..
		"teach you goldsmithing: rings, pendants and little treasures with real " ..
		"purpose.",
	mender = "Welcome to Grudge-Free Repairs! These lands run on grudges, but I don't: " ..
		"I'll mend your battered gear for coin and never ask who started it.",
}

-- Whether a trainer socket of `profession` holds a trainer.
function grug_jobs.trainer_teaches(profession)
	return grug_jobs.PROFESSIONS[profession] ~= nil and
		not grug_jobs.STARTER_PROFESSIONS[profession]
end
local sessions = {}
local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function log_action(event, player, profession, before)
	core.log("action", ("[grug_jobs] trainer_%s player=%s profession=%s " ..
		"known_before=%s known_after=%s primary_1=%s primary_2=%s"):format(
		event, player:get_player_name(), profession, tostring(before),
		tostring(grug_jobs.has(player, profession)),
		tostring(grug_jobs.primary_at(player, 1) or ""),
		tostring(grug_jobs.primary_at(player, 2) or "")))
end

-- Where a profession's recipes are (Round 45): its area of the Crafting
-- tab, crafted with its station nearby.
local function crafting_hint(profession)
	local info = grug_jobs.station_info(grug_jobs.PROFESSION_STATIONS[profession])
	return "Craft its recipes in the Crafting tab" ..
		(info and (", with a " .. info.display_name .. " nearby.") or ".")
end

-- The window (0.45.1, fix plan row 12), in real coordinates: the title, the
-- greeting, the status line and one notice (the unlearn question, the last
-- action's result or the Crafting tab hint, Round 34 and Round 45), then
-- every button in one bottom row of one height, Close on the right. Plain
-- labels, one per wrapped line (grug_jobs/overview.lua's way): no edit box,
-- so the engine's first focus falls on the last button, Close, and the
-- inventory key closes the window. The greeting keeps room for three lines
-- and the notice for two, so the window keeps its height across the states;
-- a longer text grows the window instead of needing a scrollbar.
local WIDTH, PAD, LINE_STEP = 11, 0.4, 0.42
local GREETING_LINES, NOTICE_LINES = 3, 2
local BUTTON_H, BUTTON_GAP, CLOSE_W = 0.8, 0.25, 1.8
-- Characters per line (overview.lua's estimate: 6.6 per unit).
local LINE_CHARS = math.floor((WIDTH - 2 * PAD) * 6.6)

local function trainer_formspec(player, profession, confirming)
	local definition = grug_jobs.PROFESSIONS[profession]
	local known = grug_jobs.has(player, profession)
	local status
	if known then
		status = ("Known: %s — tier %d, %d crafts in this tier."):format(
			definition.name, grug_jobs.profession_level(player, profession),
			grug_jobs.crafts_in_tier(player, profession))
	elseif definition.class == "primary" and grug_jobs.primary_at(player, 1) and
			grug_jobs.primary_at(player, 2) then
		status = "Two primary professions already learned."
	else
		status = "Learn " .. definition.name .. "?"
	end
	local session = sessions[player:get_player_name()]
	local text
	if confirming then
		text = ("Unlearn %s? Only this profession's progression will be permanently lost.")
			:format(definition.name)
	elseif session and session.notice then
		text = session.notice
	elseif known then
		text = crafting_hint(profession)
	end
	local fs = {("label[%.2f,0.50;%s Trainer]"):format(PAD, esc(definition.name))}
	-- `y` is the centre of the next line (real-coordinate labels are centred
	-- on their y); a block takes at least `reserved` lines.
	local y = 1.1
	local function block(value, reserved)
		local count = 0
		if value then
			for piece in (grug_inventory.wrap_text(value, LINE_CHARS) .. "\n"):gmatch("(.-)\n") do
				fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(PAD, y + count * LINE_STEP, esc(piece))
				count = count + 1
			end
		end
		y = y + math.max(count, reserved) * LINE_STEP
	end
	block(grug_jobs.GREETINGS[profession], GREETING_LINES)
	y = y + 0.2
	block(status, 1)
	block(text, NOTICE_LINES)
	local buttons = {}
	if confirming then
		buttons = {{"grug_jobs_confirm", "Confirm unlearn", 2.8}, {"grug_jobs_cancel", "Cancel", 1.8}}
	elseif known and definition.class == "primary" then
		buttons = {{"grug_jobs_unlearn", "Unlearn", 2.2}}
	elseif not known then
		buttons = {{"grug_jobs_learn", "Learn " .. definition.name, 3.6}}
	end
	local repair = rawget(_G, "grug_repair")
	if not confirming and repair and session and
			repair.can_open_trainer(player, session.entity) then
		buttons[#buttons + 1] = {"grug_jobs_repair", "Repair equipment", 3.0}
	end
	-- The row sits 0.35 below the last line's foot (its centre + 0.21).
	local row_y = y - LINE_STEP + 0.56
	local x = PAD
	for _, button in ipairs(buttons) do
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;%s;%s]"):format(x, row_y, button[3],
			BUTTON_H, button[1], esc(button[2]))
		x = x + button[3] + BUTTON_GAP
	end
	fs[#fs + 1] = ("button_exit[%.2f,%.2f;%.2f,%.2f;grug_jobs_close;Close]"):format(
		WIDTH - PAD - CLOSE_W, row_y, CLOSE_W, BUTTON_H)
	return ("formspec_version[4]size[%.2f,%.2f]"):format(WIDTH, row_y + BUTTON_H + PAD) ..
		table.concat(fs)
end

function grug_jobs.open_trainer(player, profession, position, entity)
	if not player or not player:is_player() or not grug_jobs.PROFESSIONS[profession] then
		return false
	end
	if not grug_jobs.trainer_teaches(profession) then
		-- A mender: the repair form only (grug_repair's trainer provider
		-- checks the socket, the distance and the faction).
		local repair = rawget(_G, "grug_repair")
		return repair ~= nil and entity ~= nil and repair.open_trainer(player, entity) == true
	end
	local name = player:get_player_name()
	sessions[name] = {profession = profession, entity = entity,
		position = {x = position.x, y = position.y, z = position.z}}
	log_action("open", player, profession, grug_jobs.has(player, profession))
	grug_sounds.play("npc_trainer", player)
	core.show_formspec(name, FORMNAME, trainer_formspec(player, profession, false))
	return true
end

local function valid_session(player, session)
	local pos = player:get_pos()
	if not pos or not session then return false end
	local dx = pos.x - session.position.x
	local dy = pos.y - session.position.y
	local dz = pos.z - session.position.z
	return dx * dx + dy * dy + dz * dz <= 8 * 8
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not valid_session(player, session) then sessions[name] = nil return true end
	if fields.grug_jobs_repair then
		local repair = rawget(_G, "grug_repair")
		if repair then repair.open_trainer(player, session.entity) end
	elseif fields.grug_jobs_learn then
		local before = grug_jobs.has(player, session.profession)
		local ok, reason = grug_jobs.learn(player, session.profession)
		if ok and not before then
			session.notice = "Learned " ..
				grug_jobs.PROFESSIONS[session.profession].name .. ". " ..
				crafting_hint(session.profession)
		else
			session.notice = reason
		end
		log_action("learn", player, session.profession, before)
		core.show_formspec(name, FORMNAME,
			trainer_formspec(player, session.profession, false))
	elseif fields.grug_jobs_unlearn then
		local definition = grug_jobs.PROFESSIONS[session.profession]
		if definition.class == "primary" and grug_jobs.has(player, session.profession) then
			session.notice = nil
			session.confirming_unlearn = true
			core.show_formspec(name, FORMNAME,
				trainer_formspec(player, session.profession, true))
		else
			session.notice = definition.name .. " cannot be unlearned."
			core.show_formspec(name, FORMNAME,
				trainer_formspec(player, session.profession, false))
		end
	elseif fields.grug_jobs_confirm then
		local before = grug_jobs.has(player, session.profession)
		local definition = grug_jobs.PROFESSIONS[session.profession]
		local ok, reason = false, "Choose Unlearn before confirming."
		if definition.class == "primary" and session.confirming_unlearn then
			ok, reason = grug_jobs.unlearn(player, session.profession)
		end
		session.confirming_unlearn = nil
		session.notice = reason
		log_action("unlearn", player, session.profession, before)
		core.show_formspec(name, FORMNAME,
			trainer_formspec(player, session.profession, false))
	elseif fields.grug_jobs_cancel then
		session.confirming_unlearn = nil
		session.notice = "Unlearn cancelled. Your profession and progression are unchanged."
		core.show_formspec(name, FORMNAME,
			trainer_formspec(player, session.profession, false))
	end
	if fields.quit then sessions[name] = nil end
	return true
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)

grug_mobs.register_start_socket_role("trainer", function(socket, settlement)
	return "grug_mobs:villager_" .. settlement.race_id
end)
