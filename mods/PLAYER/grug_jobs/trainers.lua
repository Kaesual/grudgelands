local FORMNAME = "grug_jobs:trainer"
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
	local fs = {
		"size[6.8,4.0]",
		("label[0.35,0.35;%s Trainer]"):format(esc(definition.name)),
		("label[0.35,0.95;%s]"):format(esc(status)),
	}
	local session = sessions[player:get_player_name()]
	if session and session.notice then
		fs[#fs + 1] = ("textarea[0.35,1.25;6.1,0.85;;;%s]"):format(
			esc(session.notice))
	elseif known then
		fs[#fs + 1] = "textarea[0.35,1.25;6.1,0.85;;;Open Inventory > Crafting and choose this profession's recipe book.]"
	end
	if confirming then
		fs[#fs + 1] = ("label[0.35,2.15;Unlearn %s? Only this profession's progression will be permanently lost.]"):format(esc(definition.name))
		fs[#fs + 1] = "button[0.35,2.75;2.0,0.7;grug_jobs_confirm;Confirm unlearn]"
		fs[#fs + 1] = "button[2.55,2.75;1.3,0.7;grug_jobs_cancel;Cancel]"
	elseif known and definition.class == "primary" then
		fs[#fs + 1] = "button[0.35,2.15;1.8,0.7;grug_jobs_unlearn;Unlearn]"
	elseif not known then
		fs[#fs + 1] = ("button[0.35,2.15;2.2,0.7;grug_jobs_learn;Learn %s]")
			:format(esc(definition.name))
	end
	local repair = rawget(_G, "grug_repair")
	if not confirming and repair and session and
			repair.can_open_trainer(player, session.entity) then
		fs[#fs + 1] = "button[3.0,2.15;2.2,0.7;grug_jobs_repair;Repair equipment]"
	end
	fs[#fs + 1] = "button_exit[5.35,3.15;1.1,0.55;grug_jobs_close;Close]"
	return table.concat(fs)
end

function grug_jobs.open_trainer(player, profession, position, entity)
	if not player or not player:is_player() or not grug_jobs.PROFESSIONS[profession] then
		return false
	end
	local name = player:get_player_name()
	sessions[name] = {profession = profession, entity = entity,
		position = {x = position.x, y = position.y, z = position.z}}
	log_action("open", player, profession, grug_jobs.has(player, profession))
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
				grug_jobs.PROFESSIONS[session.profession].name ..
				". Open Inventory > Crafting and choose its recipe book."
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
