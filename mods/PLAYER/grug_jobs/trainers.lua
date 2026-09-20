local FORMNAME = "grug_jobs:trainer"
local sessions = {}
local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function trainer_formspec(player, profession, confirming)
	local definition = grug_jobs.PROFESSIONS[profession]
	local known = grug_jobs.has(player, profession)
	local status
	if known then
		status = "You already know " .. definition.name .. "."
	elseif definition.class == "primary" and grug_jobs.primary_at(player, 1) and
			grug_jobs.primary_at(player, 2) then
		status = "Two primary professions already learned."
	else
		status = "Learn " .. definition.name .. "?"
	end
	local fs = {
		"size[5.5,3.2]",
		("label[0.35,0.35;%s Trainer]"):format(esc(definition.name)),
		("label[0.35,0.95;%s]"):format(esc(status)),
	}
	if confirming then
		fs[#fs + 1] = "label[0.35,1.40;Unlearning permanently loses progression.]"
		fs[#fs + 1] = "button[0.35,2.05;2.0,0.7;grug_jobs_confirm;Confirm unlearn]"
		fs[#fs + 1] = "button[2.55,2.05;1.3,0.7;grug_jobs_cancel;Cancel]"
	elseif known then
		fs[#fs + 1] = "button[0.35,1.65;1.8,0.7;grug_jobs_unlearn;Unlearn]"
	else
		fs[#fs + 1] = ("button[0.35,1.65;2.2,0.7;grug_jobs_learn;Learn %s]")
			:format(esc(definition.name))
	end
	local session = sessions[player:get_player_name()]
	local repair = rawget(_G, "grug_repair")
	if not confirming and repair and session and
			repair.can_open_trainer(player, session.entity) then
		fs[#fs + 1] = "button[2.8,1.65;2.2,0.7;grug_jobs_repair;Repair equipment]"
	end
	fs[#fs + 1] = "button_exit[4.0,2.35;1.1,0.55;grug_jobs_close;Close]"
	return table.concat(fs)
end

function grug_jobs.open_trainer(player, profession, position, entity)
	if not player or not player:is_player() or not grug_jobs.PROFESSIONS[profession] then
		return false
	end
	local name = player:get_player_name()
	sessions[name] = {profession = profession, entity = entity,
		position = {x = position.x, y = position.y, z = position.z}}
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
		grug_jobs.learn(player, session.profession)
		core.show_formspec(name, FORMNAME,
			trainer_formspec(player, session.profession, false))
	elseif fields.grug_jobs_unlearn then
		core.show_formspec(name, FORMNAME,
			trainer_formspec(player, session.profession, true))
	elseif fields.grug_jobs_confirm then
		grug_jobs.unlearn(player, session.profession)
		core.show_formspec(name, FORMNAME,
			trainer_formspec(player, session.profession, false))
	elseif fields.grug_jobs_cancel then
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
