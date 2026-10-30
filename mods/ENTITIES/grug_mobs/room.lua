--
-- Room for a body (Round 67 lane WORLD, round67-plan.md §2 rulings 23 and 26
-- and the coordinator defaults "Summon room" and "Spiders").
--
-- One geometry rule for four questions:
--   * a wide mob's spawn row: does its body fit on the node the ABM matched
--     (mobs_redo's own row check tests one node column, so a 2.1-node spider
--     spawned into cave walls);
--   * an elite or rare promotion: does the scaled body still fit where the
--     mob stands (otherwise it keeps its size);
--   * a mob that gave up its target: is it stuck in the rock (its body
--     overlapping walkable nodes, not just its origin);
--   * a flying mount's summon (grug_mounts entity.lua): does its body fit at
--     the rider's position, underground too.
--
-- A body is a collision box around an origin. It overlaps a node when one
-- of the node's real collision boxes (core.get_node_boxes: slabs, stairs,
-- snow layers, fences) overlaps the body shrunk by MARGIN on every side, so
-- faces that merely touch (a mob resting on the ground, pressed against a
-- wall) never count. Boxes whose top is at most FOOTING above the body's
-- bottom are footing, not an obstacle: a snow layer, a slab or a stair's
-- lower step under or beside the feet is ground the engine steps the body
-- onto. Non-walkable nodes (air, plants, liquids, torches) are free;
-- unknown, unloaded and `ignore` nodes are solid full cubes.
--

local floor, min, max = math.floor, math.min, math.max

local MARGIN = 0.05
local FOOTING = 0.5
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
grug_mobs.ROOM_FOOTING = FOOTING

local function node_boxes(pos)
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "ignore" then
		return FULL
	end
	local def = core.registered_nodes[node.name]
	if not def then
		return FULL
	end
	if not def.walkable then
		return nil
	end
	return core.get_node_boxes("collision_box", pos, node)
end

-- Does the body `box` with its origin at `pos` overlap a walkable node's
-- collision box above its footing? One node row below the body is read too,
-- because node boxes may reach up out of their own node (fences).
function grug_mobs.box_blocked(pos, box)
	local x1, x2 = pos.x + box[1] + MARGIN, pos.x + box[4] - MARGIN
	local feet = pos.y + box[2]
	local y1, y2 = feet + MARGIN, pos.y + box[5] - MARGIN
	local z1, z2 = pos.z + box[3] + MARGIN, pos.z + box[6] - MARGIN
	local footing = feet + FOOTING
	for nx = floor(x1 + 0.5), floor(x2 + 0.5) do
		for ny = floor(y1 + 0.5) - 1, floor(y2 + 0.5) do
			for nz = floor(z1 + 0.5), floor(z2 + 0.5) do
				local boxes = node_boxes({x = nx, y = ny, z = nz})
				if boxes then
					for i = 1, #boxes do
						local b = boxes[i]
						local top = ny + max(b[2], b[5])
						if top > footing and top > y1 and ny + min(b[2], b[5]) < y2 and
								nx + min(b[1], b[4]) < x2 and nx + max(b[1], b[4]) > x1 and
								nz + min(b[3], b[6]) < z2 and nz + max(b[3], b[6]) > z1 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

-- The box a mob moves with (mobs_redo scale_mob: a body taller than two
-- nodes collides with a shorter physics box, mobs/grug_obstacle.lua).
local function physics_box(box, self)
	local obstacle = mobs.grug_obstacle
	return obstacle and obstacle.physics_box(box, self) or box
end

--
-- The spawn rows of wide mobs (ruling 26, default "Spiders"): mobs_redo's
-- spawn_action tests one node column above the matched node unless the
-- global `mob_area_spawn` is on. A mob wider than one node also has its
-- whole body tested here, through mobs:spawn_abm_check (init.lua), where
-- spawn_action puts it: on the column above the matched node, its feet on
-- that node's top. Name -> box, or false for a body one node wide or less.
--
local wide_boxes = {}

local function wide_box(name)
	local box = wide_boxes[name]
	if box == nil then
		local ent = core.registered_entities[name]
		local base = ent and ent.base_colbox
		box = false
		if base and (base[4] - base[1] > 1 or base[6] - base[3] > 1) then
			box = physics_box(base, ent)
		end
		wide_boxes[name] = box
	end
	return box
end

-- True when a spawn of `name` on the node at `pos` has no room.
function grug_mobs.spawn_room_refused(name, pos)
	local box = wide_box(name)
	if not box then
		return false
	end
	return grug_mobs.box_blocked({x = pos.x, y = pos.y + 0.5 - box[2], z = pos.z}, box)
end

--
-- The elite and rare scale (levels.lua apply_tier_visuals): the scale a
-- live mob grows to from `current`, `wanted` when the body scaled by
-- wanted / current fits where the mob stands, its feet kept where they are;
-- otherwise it stays at `current` (the base size of a fresh mob). Shrinking
-- always fits.
--
function grug_mobs.tier_scale(self, current, wanted)
	if wanted <= current then
		return wanted
	end
	local pos = self.object and self.object:get_pos()
	local box = self.base_colbox
	if not pos or not box then
		return wanted
	end
	local f = wanted / current
	local scaled = physics_box({box[1] * f, box[2] * f, box[3] * f,
		box[4] * f, box[5] * f, box[6] * f}, self)
	local origin = {x = pos.x, y = pos.y + box[2] - scaled[2], z = pos.z}
	if grug_mobs.box_blocked(origin, scaled) then
		return current
	end
	return wanted
end

--
-- The stuck cleanup (ruling 26, default "Spiders"). A mob is stuck when its
-- current (scaled) body overlaps walkable nodes. Navigation gives a target up
-- after its path searches failed (aggro.lua give_up_target); a mob stuck at
-- that moment is removed quietly (no drops, XP or credit) once nobody
-- watches: on its next step, or on the first once-a-second check after the
-- last player moved beyond STUCK_WATCH nodes. Until then the give-up goes on
-- as before (it forgets the target and heals). A mob that moved free is let
-- go.
-- Mobs bound to something else (dawn.lua's list: NPCs, rares, bosses and
-- their adds, camp posts, patrols, leaders, tamed or owned mobs) stay.
--
local STUCK_WATCH = 32
local STUCK_INTERVAL = 1
grug_mobs.STUCK_WATCH = STUCK_WATCH
grug_mobs.stuck_stats = {flagged = 0, removed = 0}

function grug_mobs.mob_stuck(self)
	local object = self.object
	local pos = object and object:get_pos()
	if not pos then
		return false
	end
	local box = self._grug_cbox
	if not box then
		local properties = object:get_properties()
		box = properties and properties.collisionbox
	end
	return box ~= nil and grug_mobs.box_blocked(pos, box)
end

local function watched(pos)
	local d2 = grug_core.nearest_tag_player_d2(pos)
	return d2 ~= nil and d2 <= STUCK_WATCH * STUCK_WATCH
end

local function remove_stuck(self)
	local name, pos = self.name, self.object:get_pos()
	mobs:remove(self)
	grug_mobs.stuck_stats.removed = grug_mobs.stuck_stats.removed + 1
	core.log("action", "[grug_mobs] removed a stuck " .. tostring(name) ..
		" at " .. core.pos_to_string(vector.round(pos)))
	return true
end

-- Called by give_up_target before the reset: flags a stuck mob, and the
-- next do_custom step's stuck_tick checks it at once (a removal always
-- happens there, where the step can stop). True when the mob was flagged.
function grug_mobs.give_up_stuck(self)
	if grug_mobs.mob_bound(self) or not grug_mobs.mob_stuck(self) then
		return false
	end
	self.temp = self.temp or {}
	if not self.temp.grug_stuck then
		grug_mobs.stuck_stats.flagged = grug_mobs.stuck_stats.flagged + 1
	end
	self.temp.grug_stuck = STUCK_INTERVAL
	return true
end

-- Called from do_custom on every step: one field test unless the mob is
-- flagged, then one check a second. True when the mob was removed.
function grug_mobs.stuck_tick(self, dtime)
	local t = self.temp
	local acc = t and t.grug_stuck
	if not acc then
		return false
	end
	acc = acc + dtime
	if acc < STUCK_INTERVAL then
		t.grug_stuck = acc
		return false
	end
	t.grug_stuck = 0
	if not grug_mobs.mob_stuck(self) then
		t.grug_stuck = nil
		return false
	end
	if watched(self.object:get_pos()) then
		return false
	end
	return remove_stuck(self)
end
