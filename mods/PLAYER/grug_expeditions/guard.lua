-- The rules inside an Expedition (Round 71, concept sections 2 and 7): no mounts,
-- a death respawns at the start waystone, and only what the template marks can be
-- dug. Each rule fills a seam of the mod that owns it. Building, liquids and flight
-- need nothing here: the open sea's rule refuses them in every box.
local M = grug_expeditions

local HINT = "Expedition – protected"

-- No natural mob spawns over the whole slot field, at any y: nobody may see a
-- random mob's nametag through a wall. An ABM spawns within 80 nodes of a player
-- (active_block_range 4), so nothing spawns for a player in a box. A client gets
-- objects within 128 nodes (active_object_send_range_blocks 8), so a mob spawned
-- outside the field must cross 192 nodes of it. A mob stays active only in a
-- player's active blocks and is culled at 128 nodes from every player
-- (remove_far_mobs), so that takes a second player leading it in. Measured wander
-- without a lure: at most 37 nodes in a cave, 55 for a chasing Kraken at sea.
local SPAWN_MARGIN = 320
local first = M.slot_box(1)
local _, last = M.slot_box(M.catalogue.SLOTS)
grug_mobs.set_spawn_free_field(first.x - SPAWN_MARGIN, last.x + SPAWN_MARGIN,
	first.z - SPAWN_MARGIN, last.z + SPAWN_MARGIN)

grug_mounts.register_summon_guard(function(_, pos)
	if M.slot_at(pos) then return "Mounts cannot be used in an Expedition." end
end)

-- A player who died in their run. Asked again when the area is ready: a run that
-- ended meanwhile hands the respawn back to the ordinary home.
grug_home.register_respawn_home(function(player)
	local run = M.run_at(player:get_pos())
	if not run or not run.entered[player:get_player_name()] or not M.belongs(run, player) then
		return nil
	end
	return {id = "expedition:" .. run.id, pos = run.places.arrival,
		arrival = M.start_arrival(run)}
end)

-- The open sea's rule refuses every box; this answers for the marked nodes. What
-- was dug is air, marks nothing, and so takes no placement.
local function marked(run, pos)
	local node = core.get_node_or_nil(pos)
	local tpl = M.templates[M.definition(run.expedition).template]
	return node ~= nil and tpl.dig[node.name] == true
end

grug_core.register_world_exception(function(pos, name)
	if not M.slot_at(pos) then return nil end
	local run = M.run_at(pos)
	if run and run.state == "running" and marked(run, pos) and M.belongs(run, name) then
		return true
	end
	return false, HINT
end)
