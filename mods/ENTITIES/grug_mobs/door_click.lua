--
-- DOORS BEFORE NPCs (0.49.1, fix-0.49.1-plan.md ruling 8). A right-click on a
-- closed door opens it, also when a dialog NPC stands right behind it.
--
-- THE CAUSE is the engine's pointing, not our code: the raycast the client
-- points with (Environment::continueRaycast, shared by core.raycast) orders
-- its hits by RaycastSort, which counts an object one node squared nearer
-- than a node (src/raycast.cpp, "Ease selection of entities behind nodes",
-- upstream since 2018). An object whose squared distance is at most one more
-- than a node's wins: at 2 m that is about 0.24 m behind the node, at 1 m
-- about 0.41 m. A door is a thin panel at the edge of its cell, so an NPC
-- standing just behind it (in the door's own cell, or close to it on the
-- other side) wins wherever the ray meets its body at a shallow angle: about
-- eye level, the upper half. A ray aimed low runs longer through the gap and
-- the door wins (tools/r491_door/probe.sh measures both). The client then
-- sends an object click, and the engine calls the NPC's on_rightclick.
--
-- THE FIX: every NPC that opens a dialog calls this first. It casts the
-- clicker's own look ray (the aiming ray, grug_core.aim_raycast) and, when
-- the nearest node on it is a closed door that lies physically before the
-- NPC, hands the click to that door's on_rightclick, as a node click would.
-- With the door open, with no door, or with the NPC in front of the door,
-- it does nothing and the NPC answers as before. One cast per click; no
-- per-step work.
--
local REACH = 4.5 -- nodes: the hand reach of 4, plus slack for the eye

-- The first node on the ray and how far the clicked NPC's own hit is, if it
-- comes first. The engine yields nodes in their true order among themselves
-- and an object at most one node squared later, so the first node ends the
-- search: an NPC hit after it is farther.
local function first_node(origin, look, object)
	local destination = vector.add(origin, vector.multiply(look, REACH))
	local npc_distance
	for pointed in grug_core.aim_raycast(origin, destination, false) do
		local point = pointed.intersection_point
		if pointed.type == "node" then
			return pointed, point and vector.distance(origin, point), npc_distance
		elseif pointed.ref == object and point then
			npc_distance = vector.distance(origin, point)
		end
	end
	return nil, nil, npc_distance
end

-- True when the click went to a closed door in front of NPC `self`; the
-- caller then opens no dialog.
function grug_mobs.door_before_npc(self, clicker)
	local doors = rawget(_G, "doors")
	if not doors or not self or not self.object or not clicker or
			not clicker.is_player or not clicker:is_player() then
		return false
	end
	-- A sneak click never opens a door (builtin core.item_place's rule).
	local control = clicker:get_player_control()
	if control and control.sneak then return false end
	local origin = grug_core.combat_eye_pos(clicker)
	local look = clicker:get_look_dir()
	if not origin or not look then return false end
	local pointed, distance, npc_distance = first_node(origin, look, self.object)
	if not pointed or not distance then return false end
	if npc_distance and npc_distance <= distance then return false end
	local pos = pointed.under
	local node = core.get_node_or_nil(pos)
	if not node or not doors.registered_doors[node.name] then return false end
	local door = doors.get(pos)
	if not door or door:state() then return false end
	local def = core.registered_nodes[node.name]
	if not def or not def.on_rightclick then return false end
	def.on_rightclick(pos, node, clicker, clicker:get_wielded_item(), pointed)
	return true
end
