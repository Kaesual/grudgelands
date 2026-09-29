-- The Housing Steward (rulings 7 and 14; renamed from Housing Manager in
-- Round 26, ruling 11): one per capital, handing out the Claim Stone through
-- issue_stone and explaining activation and upkeep in a few lines. The
-- internal role id stays "housing_manager" (sockets, grug_mobs, grug_map).
--
-- NO MAPGEN CHANGE. Like the innkeeper (grug_home), the Steward takes over an
-- existing inhabited gate resident: the gate socket of each capital's tailor
-- service plot (capital_services.lua M.PLOTS[city].tailor). Service plots are
-- required plots, so the capital planner always places them, and the socket
-- keeps its authored, terrain-resolved position; only its role changes before
-- grug_mobs builds its rows at mods-loaded. A missing socket fails the load.
--
-- Needs grug_mapgen (the sockets are registered at its load) and grug_mobs
-- (the role resolver) loaded first: mod.conf `depends` must list both.

return function(ui)

local FORMNAME = "grug_housing:manager"

local MANAGERS = {
	{key = "highcourt", faction = "accord",
		socket = "market_counting_house/market_counting_house_gate_idle"},
	{key = "dur_brannoc", faction = "accord",
		socket = "forge_guild_house/forge_guild_house_gate_idle"},
	{key = "lethariel", faction = "accord",
		socket = "market_weaver/market_weaver_gate_idle"},
	{key = "nhal_veyr", faction = "throng",
		socket = "market_shroud_house/market_shroud_house_gate_idle"},
	{key = "gor_drazhak", faction = "throng",
		socket = "warren_weaver/warren_weaver_gate_idle"},
	{key = "kezamba", faction = "throng",
		socket = "shore_tailor/shore_tailor_gate_idle"},
}
local FACTION = {}

local mobs = rawget(_G, "grug_mobs")
if not mobs or not mobs.register_start_socket_role then
	error("grug_housing: the Housing Steward needs grug_mobs loaded first " ..
		"(mod.conf: depends = grug_mapgen, grug_mobs)", 0)
end
for _, row in ipairs(MANAGERS) do
	grug_core.assign_service_socket(row.key, row.socket, "housing_manager")
	FACTION[row.key] = row.faction
end
mobs.register_start_socket_role("housing_manager", function(_, settlement)
	return "grug_mobs:villager_" .. settlement.race_id
end)

-- The six Steward sockets as world positions, for the map and for probes.
function grug_housing.manager_sockets()
	local result = {}
	for _, row in ipairs(MANAGERS) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(row.key)) do
			if socket.id == row.socket then
				result[#result + 1] = {settlement = row.key, socket = socket.id,
					role = socket.role, pos = socket.pos}
			end
		end
	end
	return result
end

local sessions = {}

-- The dialog is bound to the live Steward standing on its own socket, within
-- talking range, and to players of the capital's faction.
local function permitted(player, entity)
	if not player or not player.is_player or not player:is_player() or
			player:get_hp() <= 0 or type(entity) ~= "table" or
			entity._grug_socket_role ~= "housing_manager" or not entity.object then
		return false
	end
	local faction = FACTION[entity._grug_start]
	if not faction or grug_factions.get_faction(player) ~= faction then return false end
	local pos, npc = player:get_pos(), entity.object:get_pos()
	if not pos or not npc then return false end
	local dx, dy, dz = pos.x - npc.x, pos.y - npc.y, pos.z - npc.z
	if dx * dx + dy * dy + dz * dz > 64 then return false end
	for _, socket in ipairs(grug_core.settlement_sockets_at(entity._grug_start)) do
		if socket.id == entity._grug_socket and socket.role == "housing_manager" then
			local sx, sy, sz = npc.x - socket.pos.x, npc.y - socket.pos.y,
				npc.z - socket.pos.z
			return sx * sx + sy * sy + sz * sz <= 4
		end
	end
	return false
end

local LINES = {
	"From level 20 you get one Claim Stone for free.",
	"Place it in your faction's lands of level 11 to 30.",
	("Activate it within %d minutes with %d coal lumps or charcoal,"):format(
		grug_housing.DRAFT_SECONDS / 60, grug_housing.ACTIVATION_LUMPS),
	"or it crumbles and I give you a new one.",
	"It burns coal lumps or charcoal: 99 lumps last about 30 days.",
	"When the fuel runs out, the protection ends.",
	("After activation the stone stays in place for %d hours."):format(
		grug_housing.PICKUP_LOCK_SECONDS / 3600),
}

local function formspec(session)
	local fs = {"formspec_version[4]size[10.5,6.8]",
		"label[0.4,0.5;Housing Steward]"}
	for index, line in ipairs(LINES) do
		fs[#fs + 1] = ("label[0.4,%.2f;%s]"):format(0.7 + index * 0.45, ui.esc(line))
	end
	if session.message then
		fs[#fs + 1] = ("label[0.4,4.75;%s]"):format(ui.text(session.message,
			session.message_color))
	end
	fs[#fs + 1] = "button[0.4,5.5;5.2,0.8;receive;Receive Claim Stone]"
	fs[#fs + 1] = "button_exit[6.9,5.5;3.2,0.8;close;Close]"
	return table.concat(fs)
end

function grug_housing.open_manager(player, entity)
	if not permitted(player, entity) then return false end
	local name = player:get_player_name()
	local session = {entity = entity}
	sessions[name] = session
	core.show_formspec(name, FORMNAME, formspec(session))
	return true
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then return true end
	if fields.quit or not permitted(player, session.entity) then
		sessions[name] = nil
		if not fields.quit then core.close_formspec(name, FORMNAME) end
		return true
	end
	if fields.receive then
		local ok, message = grug_housing.issue_stone(player)
		session.message = message or (ok and "Here is your Claim Stone." or
			"You cannot receive a Claim Stone now.")
		session.message_color = ok and ui.GREEN or ui.RED
		core.show_formspec(name, FORMNAME, formspec(session))
		ui.refresh_character(player)
	end
	return true
end)

local function forget(player)
	sessions[player:get_player_name()] = nil
end
core.register_on_leaveplayer(forget)
core.register_on_dieplayer(forget)

ui.manager_sessions = sessions
ui.manager_formname = FORMNAME

end
