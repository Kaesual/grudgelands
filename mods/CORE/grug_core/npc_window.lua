-- "May this player still use this NPC's window" (Round 81 GUARDS; audit
-- X2-02, X6-03). A settlement service window (Riding Trainer and Shipwright,
-- Housing Steward, Innkeeper, profession trainer, the trainer's repair form,
-- Expedition Registrar) asks it when it opens and again on every field event:
--   * a live player with HP above 0;
--   * the NPC's entity still alive: `get_luaentity()` of its object is the
--     entity itself (a removed object answers nil there, as on get_pos);
--   * the NPC's socket role is `role`;
--   * the player is of `faction`, the faction the NPC serves. Each window
--     passes its own source (a capital table, the home row, the settlement's
--     race); nil refuses. The player's side comes through
--     grug_core.get_player_object_faction, which grug_factions resolves to
--     grug_factions.get_faction: grug_core never depends on a player mod;
--   * the player within `opts.reach` (8) nodes of the NPC;
--   * the NPC within 2 nodes of its socket: the socket registry's socket of
--     the NPC's settlement and socket id with that role (and, when
--     `opts.profession` is set, that profession), or `opts.socket_pos` when
--     the window keeps the position itself (the innkeeper's home row).
-- The Crownbinder's window holds no entity and keeps its own check
-- (grug_traders/crown.lua).

local REACH = 8
local SOCKET_REACH_SQ = 2 * 2

local function squared(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return dx * dx + dy * dy + dz * dz
end

local function socket_of(entity, role, profession)
	for _, socket in ipairs(grug_core.settlement_sockets_at(entity._grug_start)) do
		if socket.id == entity._grug_socket and socket.role == role and
				(profession == nil or socket.profession == profession) then
			return socket.pos
		end
	end
	return nil
end

function grug_core.npc_window_permitted(player, entity, role, faction, opts)
	if not player or not player.is_player or not player:is_player() or
			player:get_hp() <= 0 then
		return false
	end
	if type(entity) ~= "table" or not entity.object or
			entity.object:get_luaentity() ~= entity or
			entity._grug_socket_role ~= role then
		return false
	end
	if faction == nil or grug_core.get_player_object_faction(player) ~= faction then
		return false
	end
	local pos, npc = player:get_pos(), entity.object:get_pos()
	if not pos or not npc then return false end
	local reach = opts and opts.reach or REACH
	if squared(pos, npc) > reach * reach then return false end
	local socket = opts and opts.socket_pos or
		socket_of(entity, role, opts and opts.profession)
	return socket ~= nil and squared(npc, socket) <= SOCKET_REACH_SQ
end
