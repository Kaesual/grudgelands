--
-- Round 36 lane R: the rift's pure rules (round36-plan.md §2.1): which clash
-- site carries it, the crack's cells, when the rift boss comes back and the
-- particle budget. rift.lua is the engine half; tools/r36_r drives this file
-- directly. Plain Lua 5.1, no globals.
--
-- The site is ONE constant (SITE): the user picks it among the four
-- candidates on lane P's review page, and the pick is a one-line change. The
-- default is Tombroad Ambush, the candidate whose surroundings lie in the
-- level 58-60 belt on all six quest seeds (42, 7, 2026, 1234, 99999, 314159;
-- the others drop to the 54-57 belt on one or two of them).
--
local M = {}

-- The four candidates (anchor rows of grug_mapgen/wp40/r20_poi_catalog.lua)
-- and, per site, the crack's authored waypoints relative to the anchor. A
-- composition is fixed, never seed-generated, so its crack is too: the
-- waypoints run through the open floor around the props and the centre.
M.CANDIDATES = {
	-- Saltgate Remnant, front_gravesalt_escarpment clash_1
	r20_anchor_076 = {{6, 1}, {5, -1}, {6, -3}, {6, -7}, {3, -7}, {1, -5}, {-1, -6},
		{-3, -4}, {-2, -7}, {-6, -7}},
	-- Tombroad Ambush, front_gravesalt_escarpment clash_2
	r20_anchor_077 = {{-7, -5}, {-4, -6}, {-2, -5}, {1, -7}, {6, -7}, {5, -4},
		{6, -1}, {4, 1}, {6, 3}, {6, 6}},
	-- Skyroot Crossing, front_skyglass_canopy clash_1
	r20_anchor_084 = {{-7, 6}, {-4, 4}, {-1, 6}, {2, 4}, {4, 2}, {6, 0}, {4, -2},
		{6, -3}},
	-- Cloudwatch Fall, front_skyglass_canopy clash_2
	r20_anchor_085 = {{-7, -1}, {-5, 1}, {-3, 4}, {0, 6}, {3, 4}, {6, 6}},
}
M.SITE = "r20_anchor_077"

-- The boss: its name from the story bible (round36-plan.md
-- §2.9), its encounter id (bosses.lua's ledger; grug_achievements counts
-- "boss:rift" and "boss:<id>") and its return after a death, seconds of
-- wall-clock time like every boss's.
M.BOSS_NAME = "Isquarre the Tithe-Eater"
M.RESPAWN = 5 * 60
function M.boss_id(site_key)
	return "rift:" .. site_key
end

-- The runtime triggers around the site's anchor (horizontal distance): the
-- boss appears when a player is within SPAWN_RANGE (the leaders' reach at the
-- default active block range) and none stands within SPAWN_CLEAR of its spot;
-- the particles run while a player is within PARTICLE_RANGE.
M.SPAWN_RANGE = 48
M.SPAWN_CLEAR = 6
M.PARTICLE_RANGE = 48
-- One particle spawner per near player every PARTICLE_PERIOD seconds, each
-- with PARTICLE_AMOUNT particles living PARTICLE_LIFE seconds: about
-- amount x mean life / period alive at once per player (the web budget:
-- hundreds, never thousands).
M.PARTICLE_PERIOD = 5
M.PARTICLE_AMOUNT = 80
M.PARTICLE_LIFE = {2, 4}

function M.particles_alive()
	local life = (M.PARTICLE_LIFE[1] + M.PARTICLE_LIFE[2]) / 2
	return M.PARTICLE_AMOUNT * life / M.PARTICLE_PERIOD
end

-- When the boss may come back: `due` is the wall-clock time stored at its
-- death (0 before the first spawn).
function M.respawn_due(death_time)
	return death_time + M.RESPAWN
end

function M.may_spawn(alive, due, now)
	return not alive and now >= (due or 0)
end

-- The crack's depth: the floor node and the one below it become void, so a
-- player sinks two nodes and stands on the natural ground beneath.
M.DEPTH = 2

-- Cells the crack never takes (anchor-relative x/z): the clash composition's
-- central actor clearance (|x|, |z| <= 2, r20_poi_blueprint.lua) with one
-- node of margin, where the boss stands and the quest objects appear; every
-- prop's 3 x 3 footprint; and the box's outermost ring, so the crack stays
-- inside the protected POI core with a node of floor around it.
M.CENTRE = 3
M.PROP_REACH = 1
M.EDGE = 1

local function excluded(art, x, z)
	local lo, hi = -art.width / 2, art.width / 2 - 1
	if x < lo + M.EDGE or x > hi - M.EDGE or z < lo + M.EDGE or z > hi - M.EDGE then
		return true
	end
	if math.abs(x) <= M.CENTRE and math.abs(z) <= M.CENTRE then return true end
	for _, prop in ipairs(art.props or {}) do
		if math.abs(x - prop[2]) <= M.PROP_REACH and math.abs(z - prop[3]) <= M.PROP_REACH then
			return true
		end
	end
	return false
end
M.excluded = excluded

-- The crack of a site: its waypoints joined by 4-connected steps (one axis at
-- a time, the longer one first, so the line zig-zags on a diagonal), every
-- cell once, the excluded cells dropped. `art` is the site's catalogue row
-- (width, props). Returns {{x, z}, ...} in line order.
function M.crack_cells(art, waypoints)
	local out, seen = {}, {}
	local function add(x, z)
		local key = x .. "," .. z
		if seen[key] or excluded(art, x, z) then return end
		seen[key] = true
		out[#out + 1] = {x, z}
	end
	local x, z = waypoints[1][1], waypoints[1][2]
	add(x, z)
	for index = 2, #waypoints do
		local tx, tz = waypoints[index][1], waypoints[index][2]
		while x ~= tx or z ~= tz do
			local dx, dz = tx - x, tz - z
			if math.abs(dx) >= math.abs(dz) and dx ~= 0 then
				x = x + (dx > 0 and 1 or -1)
			else
				z = z + (dz > 0 and 1 or -1)
			end
			add(x, z)
		end
	end
	return out
end

-- A catalogue row by key, from r20_poi_catalog.lua's rows.
function M.site_row(rows, key)
	for _, row in ipairs(rows) do
		if row.key == key then return row end
	end
	return nil
end

-- The site's protected POI box (world_protection.lua settlement_boxes for a
-- clash composition: its cells on the anchor, 10 below the placement height
-- to 10 above its top) in world coordinates; `anchor` = {x, y, z}.
function M.box(art, anchor)
	local lo, hi = -art.width / 2, art.width / 2 - 1
	return {min_x = anchor.x + lo, max_x = anchor.x + hi,
		min_z = anchor.z + lo, max_z = anchor.z + hi,
		min_y = anchor.y - 10, max_y = anchor.y + art.height + 10}
end

-- The world nodes the crack writes: every cell's floor (the anchor height)
-- and the DEPTH - 1 nodes below it.
function M.crack_nodes(cells, anchor)
	local out = {}
	for _, cell in ipairs(cells) do
		for depth = 0, M.DEPTH - 1 do
			out[#out + 1] = {x = anchor.x + cell[1], y = anchor.y - depth,
				z = anchor.z + cell[2]}
		end
	end
	return out
end

return M
