-- Capital-only Riding service. Each open dialog is bound to the live authored
-- trainer and a unique session; a stale form cannot purchase at another NPC.
local sessions = {}
local serial = 0
local CAPITAL_FACTION = {
	highcourt = "accord", dur_brannoc = "accord", lethariel = "accord",
	nhal_veyr = "throng", gor_drazhak = "throng", kezamba = "throng",
}

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function permitted(player, entity)
	if not player or not player.is_player or not player:is_player() or
			player:get_hp() <= 0 or not entity or
			entity._grug_socket_role ~= "riding_trainer" or not entity.object then
		return false
	end
	local faction = CAPITAL_FACTION[entity._grug_start]
	if not faction or grug_factions.get_faction(player) ~= faction then return false end
	local pos, npc = player:get_pos(), entity.object:get_pos()
	if not pos or not npc then return false end
	local dx, dy, dz = pos.x - npc.x, pos.y - npc.y, pos.z - npc.z
	if dx * dx + dy * dy + dz * dz > 64 then return false end
	for _, socket in ipairs(grug_core.settlement_sockets_at(entity._grug_start)) do
		if socket.id == entity._grug_socket and socket.role == "riding_trainer" then
			local sx, sy, sz = npc.x - socket.pos.x, npc.y - socket.pos.y,
				npc.z - socket.pos.z
			return sx * sx + sy * sy + sz * sz <= 4
		end
	end
	return false
end

-- Every tier is listed with its state (Round 28 ruling 19), so a player sees
-- the whole ladder and why a tier is not for sale yet. Only "buy" has a
-- button; the other blocked states are greyed text.
local GREY = "#8a8a8a"
local OWNED = "#7ae08a"
local NOTICE = {[true] = "#7ae08a", [false] = "#ff6b6b"}

-- One row per tier: {id, name, level, state, price, previous}. Pure, so the
-- portable fixture renders it without an engine.
function grug_mounts.trainer_formspec(rows, notice)
	local fs = {"formspec_version[3]size[10,6]",
		"label[0.4,0.4;Riding Trainer]",
		"label[0.4,0.85;Universal skill — no profession slot]"}
	for index, row in ipairs(rows) do
		local y = 1.5 + (index - 1) * 0.85
		local name = ("%s (L%d)"):format(row.name, row.level)
		local open = row.state == "buy" or row.state == "owned"
		fs[#fs + 1] = ("label[0.4,%.2f;%s]"):format(y,
			esc(open and name or core.colorize(GREY, name)))
		if row.state == "buy" then
			fs[#fs + 1] = ("button[5.0,%.2f;3.0,0.65;buy_%d;%s]"):format(y - 0.3,
				row.id, esc("Buy " .. row.price))
		else
			local text
			if row.state == "owned" then
				text = core.colorize(OWNED, "Owned")
			elseif row.state == "level" then
				text = core.colorize(GREY, ("Requires level %d"):format(row.level))
			elseif row.state == "previous" then
				text = core.colorize(GREY, "Learn " .. row.previous .. " first")
			else
				text = core.colorize(GREY, "Price pending")
			end
			fs[#fs + 1] = ("label[5.0,%.2f;%s]"):format(y, esc(text))
		end
	end
	if notice then
		fs[#fs + 1] = ("label[0.4,5.0;%s]"):format(esc(core.colorize(
			NOTICE[notice.ok == true], notice.text)))
	end
	fs[#fs + 1] = "button_exit[8.1,5.1;1.5,0.6;close;Close]"
	return table.concat(fs)
end

local function formspec(player, notice)
	local rows = {}
	for tier_id = 1, 4 do
		local tier = grug_mounts.TIERS[tier_id]
		local state, price = grug_mounts.tier_state(player, tier_id)
		local previous = grug_mounts.TIERS[tier_id - 1]
		rows[tier_id] = {id = tier_id, name = tier.name, level = tier.level,
			state = state, price = price and grug_money.format(price),
			previous = previous and previous.name}
	end
	return grug_mounts.trainer_formspec(rows, notice)
end

function grug_mounts.open_trainer(player, entity)
	if not permitted(player, entity) then return false end
	local name = player:get_player_name()
	serial = serial + 1
	local formname = "grug_mounts:riding:" .. serial
	sessions[name] = {entity = entity, formname = formname}
	core.show_formspec(name, formname, formspec(player))
	return true
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, 19) ~= "grug_mounts:riding:" then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session or formname ~= session.formname then return true end
	if fields.quit or not permitted(player, session.entity) then
		sessions[name] = nil
		return true
	end
	local selected
	for tier_id = 1, 4 do
		if fields["buy_" .. tier_id] then
			if selected then return true end
			selected = tier_id
		end
	end
	if selected then
		-- The result goes to the flash line, never to chat, and stays in the
		-- reopened form (whose box may cover the flash line).
		local ok, message = grug_mounts.purchase(player, selected)
		grug_core.flash(player, message, ok and grug_core.FLASH_COLOR.notice or
			grug_core.FLASH_COLOR.error)
		core.show_formspec(name, formname, formspec(player,
			{ok = ok == true, text = message}))
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)
core.register_on_dieplayer(function(player)
	sessions[player:get_player_name()] = nil
end)

grug_mobs.register_start_socket_role("riding_trainer", function(socket, settlement)
	return "grug_mobs:villager_" .. settlement.race_id
end)
