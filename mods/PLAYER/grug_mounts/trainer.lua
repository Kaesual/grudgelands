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

local function formspec(player)
	local fs = {"formspec_version[3]size[8,6]",
		"label[0.4,0.4;Riding Trainer]",
		"label[0.4,0.85;Universal skill — no profession slot]"}
	local level = grug_xp.get_level(player)
	local row = 0
	for tier_id = 1, 4 do
		local tier = grug_mounts.TIERS[tier_id]
		if level >= tier.level then
			local y = 1.5 + row * 0.85
			fs[#fs + 1] = ("label[0.4,%.2f;%s (L%d)]")
				:format(y, esc(tier.name), tier.level)
			local price = grug_mounts.price_for_tier(tier_id)
			if grug_mounts.owns_tier(player, tier_id) or not price then
				fs[#fs + 1] = ("label[5.0,%.2f;%s]"):format(y,
					grug_mounts.owns_tier(player, tier_id) and "Owned" or "Price pending")
			else
				fs[#fs + 1] = ("button[4.8,%.2f;2.7,0.65;buy_%d;Buy %s]")
					:format(y - 0.2, tier_id, esc(grug_money.format(price)))
			end
			row = row + 1
		end
	end
	if row == 0 then
		fs[#fs + 1] = "label[0.4,1.5;First riding tier unlocks at level 15.]"
	end
	fs[#fs + 1] = "button_exit[6,5.1;1.5,0.6;close;Close]"
	return table.concat(fs)
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
		local _, message = grug_mounts.purchase(player, selected)
		core.chat_send_player(name, message)
		core.show_formspec(name, formname, formspec(player))
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
