-- The rules inside an Expedition (Round 71, concept sections 2 and 7): no mounts,
-- a death respawns at the start waystone, and only what the template marks can be
-- dug; since Round 72 lava stays put and Return Home is refused in it. Each rule
-- fills a seam of the mod that owns it. Building, liquids and flight need nothing
-- here: the open sea's rule refuses them in every box.
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

-- Lava stays where the template wrote it (Round 72, The Last Mint's lake): every box
-- holds its lava (grug_core/lava_guard.lua). The templates' lava has nothing beside or
-- below it to flow into; the hold covers whatever else could move it.
grug_core.register_lava_hold(function(pos) return M.slot_at(pos) ~= nil end)

-- Return Home is refused in lava inside an Expedition, and on the way down into it
-- (Round 72, the user's ruling for The Last Mint): a fall there is death, with no
-- way out. Standing on anything, at the edge of a top too, is no fall. Logging out
-- stays as it is: a login stands where the player was. One look down a column, on
-- a click only.
local FALL_DEPTH = 32
local FOOT = 0.3 -- the body's half width (the player's collision box)

local function lava_at(pos)
	local node = core.get_node_or_nil(pos)
	return node ~= nil and core.get_item_group(node.name, "lava") > 0
end

local function walkable_at(pos)
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	return not def or def.walkable ~= false
end

local function in_or_over_lava(pos)
	local x, z = math.floor(pos.x + 0.5), math.floor(pos.z + 0.5)
	local y = math.floor(pos.y + 0.5)
	if lava_at({x = x, y = y, z = z}) or lava_at({x = x, y = y + 1, z = z}) then return true end
	-- Standing: a corner of the feet on a walkable node right below them.
	for _, dx in ipairs({-FOOT, FOOT}) do
		for _, dz in ipairs({-FOOT, FOOT}) do
			if walkable_at({x = math.floor(pos.x + dx + 0.5), y = math.floor(pos.y - 0.05 + 0.5),
					z = math.floor(pos.z + dz + 0.5)}) then
				return false
			end
		end
	end
	for dy = 1, FALL_DEPTH do
		local below = {x = x, y = y - dy, z = z}
		if lava_at(below) then return true end
		if walkable_at(below) then return false end
	end
	return false
end

grug_home.register_return_guard(function(player)
	local pos = player:get_pos()
	if pos and M.slot_at(pos) and in_or_over_lava(pos) then
		return "Cannot return home from the lava."
	end
end)

-- A player who died in a box. In their run: the start waystone. Their run gone, a
-- logout death's login included: the capital they came from, without a saved one the
-- ordinary home. Asked again when the area is ready: a run that ended meanwhile
-- hands the respawn on. That second look finds the player held on the capital's
-- arrival, out of the box, so the first answer waits for it here.
local to_capital = {} -- player name -> the row of a respawn on its way there

grug_home.register_respawn_home(function(player)
	local name = player:get_player_name()
	local pos = player:get_pos()
	if not M.slot_at(pos) then
		local row = to_capital[name]
		if row and vector.distance(pos, row.arrival) < 1 then return row end
		to_capital[name] = nil
		return nil
	end
	to_capital[name] = nil
	local run = M.run_at(pos)
	if run and run.entered[name] and M.belongs(run, player) then
		return {id = "expedition:" .. run.id, pos = run.places.arrival,
			arrival = M.start_arrival(run)}
	end
	local origin = M.saved_origin(player)
	local way = origin and grug_home.waystone_pos(origin)
	if not way then return nil end
	-- The arrival is judged on the nodes: a stone the player came from is generated.
	core.load_area(vector.subtract(way, 2), vector.add(way, 2))
	local arrival = grug_home.waystone_arrival(origin)
	if not arrival then return nil end
	to_capital[name] = {id = "expedition_origin:" .. origin, pos = way, arrival = arrival}
	return to_capital[name]
end)

local function forget_capital(player) to_capital[player:get_player_name()] = nil end
core.register_on_dieplayer(forget_capital)
core.register_on_leaveplayer(forget_capital)

-- The open sea's rule refuses every box; this answers for the marked nodes, as the
-- run's tier wrote them. What was dug is air, marks nothing, and so takes no placement.
local function marked(run, pos)
	local node = core.get_node_or_nil(pos)
	return node ~= nil and M.written(run).dig[node.name] == true
end

grug_core.register_world_exception(function(pos, name)
	if not M.slot_at(pos) then return nil end
	local run = M.run_at(pos)
	if run and run.state == "running" and marked(run, pos) and M.belongs(run, name) then
		return true
	end
	return false, HINT
end)
