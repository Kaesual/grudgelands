-- The lift's interaction (spec §3, lane LIFT): a teleport lift with no
-- shaft between a camp's surface and its rooms (one per tier depth, lane
-- ROOMS). It overrides grug_mapgen:guild_lift's right-click only; the node's
-- static fields and its art are grug_mapgen's (`world_nodes.lua`), because
-- the settlement content's semantic digest reads them in both environments.
--
-- A right-click finds the camp from the clicked node: a room's lift through
-- grug_mapgen.guild_rooms.room_at (the room's box), the surface lift through
-- grug_mapgen.mining_camps.near (its column, above the shallowest room). A
-- member of the camp's faction gets the list of the camp's levels: the
-- surface and each room, "Level N (floor y)", the current one marked; every
-- other character (the enemy, one without a faction) gets the refusal line
-- every service of a faction gives. Enemies may stand in a room but never
-- use its lift.
--
-- The trip runs through grug_home's one travel path (`grug_home.travel`:
-- emerge, re-check on the next server step, a running dash ended, dismount,
-- the travel sound) with the waystones' rules: free, no cooldown, alive and
-- out of combat, standing at the lift, one trip at a time; a mount is left
-- behind, nobody else travels along. A room's arrival is its `arrival`
-- point beside the lift; the surface arrival is the first safe cell beside
-- the surface lift, its front first (the node's `4dir` param2), then its
-- back and sides. Both go through `grug_home.safe_arrival`.
--
-- No saved state: the list always offers every level, so no return point is
-- kept (nothing in player meta, no register_on_relocate clear).
--
--   grug_guild.lift_at(pos) -> {camp, level, levels} | nil
--       the camp of a lift node at pos, the level it stands on (0 the
--       surface, else the room's tier) and the camp's levels
--       {level, label, room} (the surface first)
--   grug_guild.use_lift(player, pos)   the right-click

local LIFT = "grug_mapgen:guild_lift"
local SUBJECT = "Miner's Guild Lift"
-- A rider stands within this reach of the lift node (the waystones' reach:
-- horizontally, and as far up or down).
local REACH = 8
local FORM_PREFIX = "grug_guild:lift:"

-- grug_home is not a dependency of this mod (spec §10.1); it is read when a
-- trip starts, like the mailbox reads grug_mail.
local function home() return rawget(_G, "grug_home") end

local function level_label(level, room)
	if level == 0 then return "Surface" end
	return ("Level %d (%d)"):format(level, room.floor_y)
end

function grug_guild.lift_at(pos)
	if type(pos) ~= "table" then return nil end
	local rooms, camps = grug_mapgen.guild_rooms, grug_mapgen.mining_camps
	if not rooms or not camps then return nil end
	local camp, level
	local room = rooms.room_at(pos)
	if room then
		camp, level = camps.get(room.camp_id), room.tier
	else
		camp, level = camps.near(pos, 0), 0
	end
	if not camp then return nil end
	local levels = {{level = 0, label = level_label(0)}}
	for _, row in ipairs(rooms.rooms_for_camp(camp.id) or {}) do
		levels[#levels + 1] = {level = row.tier, label = level_label(row.tier, row), room = row}
	end
	return {camp = camp, level = level, levels = levels}
end

-- The surface lift's node: the camp's `lift` socket (settlements.md, the
-- camp socket contract), the cell the writer put the node in.
local function surface_lift(camp)
	for _, socket in ipairs(grug_core.settlement_sockets_at(camp.id)) do
		if socket.id == "lift" and socket.role == "lift" then return socket.pos end
	end
end

-- The first safe cell beside the surface lift: its front (param2 0 faces
-- -z; `4dir` turns it like the engine's fourdir_to_dir, whose direction is
-- the back), then its back, then the two sides. The deck the headframe
-- stands on is open in front of and behind the lift, its posts beside it.
local function surface_arrival(pos)
	local node = core.get_node_or_nil(pos)
	local param2 = node and node.name == LIFT and node.param2 or 0
	local back = core.fourdir_to_dir(param2 % 4)
	local sides = {{x = -back.x, z = -back.z}, {x = back.x, z = back.z},
		{x = back.z, z = -back.x}, {x = -back.z, z = back.x}}
	for _, side in ipairs(sides) do
		local arrival = home().safe_arrival(vector.offset(pos, side.x, -0.49, side.z))
		if arrival then return arrival end
	end
end

local function near(player, pos)
	local at = player:get_pos()
	if not at or not pos then return false end
	local dx, dy, dz = at.x - pos.x, at.y - pos.y, at.z - pos.z
	return dy <= REACH and dy >= -REACH and dx * dx + dz * dz <= REACH * REACH
end

local dialogs, serial = {}, 0

local function form(found)
	local count = #found.levels
	local fs = {grug_core.ui.frame(10, 2.4 + 0.8 * count, grug_guild.catalog.UI_NAME .. " Lift"),
		"label[0.4,0.95;", core.formspec_escape(found.camp.label or found.camp.id), "]"}
	for index, entry in ipairs(found.levels) do
		local y = 0.9 + 0.8 * index
		fs[#fs + 1] = grug_core.ui.panel(0.2, y - 0.35, 9.6, 0.72)
		fs[#fs + 1] = ("label[0.4,%.2f;%s]"):format(y, core.formspec_escape(entry.label))
		if entry.level == found.level then
			fs[#fs + 1] = ("label[6.8,%.2f;You are here]"):format(y)
		else
			fs[#fs + 1] = ("button[6.8,%.2f;2.4,0.6;go_%d;Travel]"):format(y - 0.3, entry.level)
		end
	end
	fs[#fs + 1] = ("button_exit[7.9,%.2f;1.7,0.65;close;Close]"):format(1.5 + 0.8 * count)
	return table.concat(fs)
end

function grug_guild.use_lift(player, pos)
	if not player or not player:is_player() or player:get_hp() <= 0 then return end
	pos = vector.round(pos)
	local found = grug_guild.lift_at(pos)
	if not found then return end
	if not grug_factions.serves(found.camp.faction, player) then
		grug_factions.refuse(player, SUBJECT, found.camp.faction)
		return
	end
	local name = player:get_player_name()
	serial = serial + 1
	local formname = FORM_PREFIX .. serial
	dialogs[name] = {formname = formname, camp = found.camp.id, pos = pos}
	core.show_formspec(name, formname, form(found))
end

core.override_item(LIFT, {
	on_rightclick = function(pos, _, clicker)
		grug_guild.use_lift(clicker, pos)
	end,
})

-- Starts the trip from the dialog's lift to `level` of the same camp: ok,
-- or false and the refusal line. On the server step after the emerge the
-- trip still needs the same living, out-of-combat member at the lift.
local function start_trip(player, dialog, level)
	local found = grug_guild.lift_at(dialog.pos)
	if not found or found.camp.id ~= dialog.camp then return false, "This lift does not answer you." end
	local camp = found.camp
	if player:get_hp() <= 0 then return false, "You cannot travel now." end
	if not grug_factions.serves(camp.faction, player) then
		return false, grug_factions.refusal(SUBJECT, camp.faction)
	end
	local target
	for _, entry in ipairs(found.levels) do
		if entry.level == level then target = entry end
	end
	if not target then return false, "This lift does not go there." end
	if target.level == found.level then return false, "You are already here." end
	if not near(player, dialog.pos) then return false, "Stand at the lift to travel." end
	if grug_core.in_combat(player) then return false, "Cannot travel in combat." end
	local travel = home()
	if not travel then return false, "The lift cannot be used right now." end
	if travel.is_pending(player) then return false, "Travel is already being prepared." end
	local destination = target.room and target.room.lift_cell or surface_lift(camp)
	if not destination then return false, "The lift cannot be used right now." end
	local name, origin = player:get_player_name(), dialog.pos
	return travel.travel(player, {pos = destination,
		unavailable = "The lift cannot reach " .. target.label .. " right now. Please try again.",
		check = function(p)
			if p:get_hp() <= 0 or not grug_factions.serves(camp.faction, p) then return false end
			if grug_core.in_combat(p) or not near(p, origin) then
				core.chat_send_player(name, "Travel canceled.")
				return false
			end
			return true
		end,
		arrival = function()
			if target.room then return travel.safe_arrival(target.room.arrival) end
			return surface_arrival(destination)
		end}), "Travel is already being prepared."
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, #FORM_PREFIX) ~= FORM_PREFIX then return false end
	local name = player:get_player_name()
	local dialog = dialogs[name]
	if not dialog or dialog.formname ~= formname then return true end
	if fields.quit then
		dialogs[name] = nil
		return true
	end
	local level
	for field in pairs(fields) do
		local value = tonumber(field:match("^go_(%d+)$"))
		if value then level = value end
	end
	if not level then return true end
	local ok, refusal = start_trip(player, dialog, level)
	if not ok then
		core.chat_send_player(name, refusal)
		return true
	end
	dialogs[name] = nil
	core.close_formspec(name, formname)
	return true
end)

local function clear(player) dialogs[player:get_player_name()] = nil end
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(clear)
