-- The user's room rules, proved over a written Expedition template (Round 72 PROOF).
-- One copy for the three fixtures that own a template (tools/r71_l20, tools/r72_shift,
-- tools/r72_mint): each reads its template, knows its rooms, packs and sight, and asks
-- these questions of it (round72-plan.md section 2.9):
--
--   free height  at least three nodes of air over every floor cell;
--   perches      no surface a player reaches by walking, jumping and falling lies off
--                the floor, apart from waystones and the chest, and no rope in reach;
--   coverage     every floor cell of a pack's fighting room is noticed by a mob of it;
--   walk round   no walk from a pack room's entrance to its exit or its ore avoids
--                every cell the pack notices.
--
-- A map is {tpl = <template.lua's parse>, F = <the walking cells' y>}; `changed` names
-- nodes read as air (the door open, the ore dug), as the fixtures do.
local P = {}

-- Every node the templates use, by what it does to a body (the registry's walkable and
-- climbable, tools/building_templates/nodes.json). A node missing here stops the proof:
-- it has to be thought about.
--   air     nothing
--   open    not walkable: a body passes, but it is no air for the free height
--   climb   not walkable, climbable (a rope)
--   flat    walkable, flush with the floor (a rail's top is 1/16 of a node): the floor
--   solid   walkable: a body stops, a foot stands on its top (a table's at 0.48, a
--           bench's at 0.45, a cart's at 0.75: all within the one node a jump climbs)
--   liquid  lava: a fall into it ends the walk
P.BODY = {
	air = "air",
	["default:torch_wall"] = "open", ["grug_decor:xdecor_lantern_hanging"] = "open",
	["default:sign_wall_wood"] = "open",
	["grug_decor:xdecor_rope"] = "climb",
	["grug_mapgen:mine_rail"] = "flat",
	["default:lava_source"] = "liquid",
}
for _, name in ipairs({"default:stone", "default:cobble", "default:gravel", "default:tree", "default:wood",
	"default:pine_wood", "default:stonebrick", "default:stone_block", "grug_decor:darkage_reinforced_wood",
	"grug_decor:darkage_basalt_brick", "grug_decor:darkage_slate_tile", "grug_materials:steel_block",
	"grug_materials:iron_block", "grug_materials:stone_with_anthracite", "grug_materials:stone_with_jade",
	"grug_decor:cottages_table", "grug_decor:cottages_bench", "grug_decor:cottages_barrel",
	"grug_mapgen:mine_cart", "grug_expeditions:waystone", "grug_expeditions:reward_chest",
	"grug_expeditions:reward_door"}) do
	P.BODY[name] = "solid"
end
-- What a player may stand on above the floor (the user's exception).
P.ALLOWED = {["grug_expeditions:waystone"] = true, ["grug_expeditions:reward_chest"] = true}

local function new_map(tpl, F)
	local sx, sy, sz = tpl.size.x, tpl.size.y, tpl.size.z
	local rows = sx * sy
	local class = {}
	for index, name in ipairs(tpl.nodes) do
		class[index - 1] = assert(P.BODY[name], "proofs: a node to think about: " .. name)
	end
	local m = {tpl = tpl, F = F, sx = sx, sy = sy, sz = sz}
	function m.inside(x, y, z) return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz end
	function m.at(x, y, z) return z * rows + y * sx + x + 1 end
	function m.name(x, y, z) return tpl.nodes[tpl.cells:byte(m.at(x, y, z)) + 1] end
	-- The cell's class; outside the box is rock.
	function m.class(x, y, z, changed)
		if not m.inside(x, y, z) then return "solid" end
		if changed and changed[m.name(x, y, z)] then return "air" end
		return class[tpl.cells:byte(m.at(x, y, z))]
	end
	-- A body fits in the cell.
	function m.passes(x, y, z, changed)
		local c = m.class(x, y, z, changed)
		return c ~= "solid" and c ~= "liquid"
	end
	-- A player stands in (x, y, z): something to stand on below, the body's two cells free.
	function m.stands(x, y, z, changed)
		local below = m.class(x, y - 1, z, changed)
		return (below == "solid" or m.class(x, y, z, changed) == "flat")
			and m.passes(x, y, z, changed) and m.passes(x, y + 1, z, changed)
	end
	return m
end
P.map = new_map

-- The floor: every cell a player stands in at F, as {x, z} lists and a set by x, z.
function P.floor(m, changed)
	local list, set = {}, {}
	for z = 0, m.sz - 1 do
		for x = 0, m.sx - 1 do
			if m.stands(x, m.F, z, changed) then
				list[#list + 1] = {x = x, z = z}
				set[z * m.sx + x] = true
			end
		end
	end
	return list, set
end

-- The free height over every floor cell: air from F up (a rail at F counts as floor).
-- Returns the lowest, where, and the cells with less than `need` ("x,z", in floor order).
function P.free_height(m, floor, need)
	local lowest, where, short = math.huge, nil, {}
	for _, cell in ipairs(floor) do
		local h = 0
		while true do
			local c = m.class(cell.x, m.F + h, cell.z)
			if not (c == "air" or (h == 0 and c == "flat")) then break end
			h = h + 1
		end
		if h < lowest then lowest, where = h, cell.x .. "," .. cell.z end
		if need and h < need then short[#short + 1] = cell.x .. "," .. cell.z end
	end
	return lowest, where, short
end

-- Perches: a search over every place a player can stand, from `from` ({x, y, z}), by
-- walking, a jump of one node up (the pinned engine's jump climbs 1.08 nodes; head room
-- over the take-off), a leap over one or two open columns (one node up over one, level
-- or down over two) and a fall off an edge (never into lava). Generous on purpose: the
-- proof finds more places than a player could reach, never fewer. Returns the list of
-- places off the floor not on a waystone or the chest, and of ropes in reach (a body
-- climbs a rope in its feet or the next cell, the next but one at a jump's top), and
-- the count of places searched.
function P.perches(m, from, changed)
	local F = m.F
	local seen, queue, head = {}, {}, 1
	local found, ropes = {}, {}
	local function push(x, y, z)
		local index = m.at(x, y, z)
		if not seen[index] then
			seen[index] = true
			queue[#queue + 1] = {x, y, z}
		end
	end
	-- Where a body stepping into (x, z) at y comes to rest, or nil (lava, nothing).
	local function land(x, y, z)
		if not (m.passes(x, y, z, changed) and m.passes(x, y + 1, z, changed)) then return nil end
		while y > 0 do
			if m.stands(x, y, z, changed) then return y end
			if m.class(x, y - 1, z, changed) == "liquid" or m.class(x, y, z, changed) == "liquid" then return nil end
			y = y - 1
		end
		return nil
	end
	push(from[1], from[2], from[3])
	while queue[head] do
		local x, y, z = queue[head][1], queue[head][2], queue[head][3]
		head = head + 1
		local below = m.name(x, y - 1, z)
		if y ~= F and not (changed and changed[below]) and not P.ALLOWED[below] then
			found[#found + 1] = ("%d,%d,%d on %s"):format(x, y, z, below)
		end
		for dy = 0, 2 do
			if m.class(x, y + dy, z, changed) == "climb" then
				ropes[#ropes + 1] = ("%d,%d,%d"):format(x, y + dy, z)
			end
		end
		local head_room = m.passes(x, y + 2, z, changed)
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local nx, nz = x + d[1], z + d[2]
			local to = land(nx, y, nz)
			if to then push(nx, to, nz) end
			if head_room and m.stands(nx, y + 1, nz, changed) then push(nx, y + 1, nz) end
			-- A leap: the columns crossed open from y to y + 2.
			if head_room then
				for k = 1, 2 do
					local cx, cz = x + d[1] * k, z + d[2] * k
					local clear = true
					for dy = 0, 2 do clear = clear and m.passes(cx, y + dy, cz, changed) end
					if not clear then break end
					local lx, lz = x + d[1] * (k + 1), z + d[2] * (k + 1)
					if k == 1 and m.inside(lx, y + 1, lz) and m.stands(lx, y + 1, lz, changed) then
						push(lx, y + 1, lz)
					end
					if m.inside(lx, y, lz) then
						local to2 = land(lx, y, lz)
						if to2 then push(lx, to2, lz) end
					end
				end
			end
		end
	end
	return found, ropes, head - 1
end

-- The mobs of `spots` that notice a player at (x, z): within view range less `margin`
-- and in sight (`sees`, the fixture's model). Returns the best spare range or nil.
function P.noticed(spots, x, z, margin, sees)
	local best
	for _, spot in ipairs(spots) do
		local d = math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2)
		if d <= spot.view - margin and sees(spot.x, spot.z, x, z) then
			local spare = spot.view - d
			if not best or spare > best then best = spare end
		end
	end
	return best
end

-- Coverage: every floor cell `in_room` holds is noticed by `spots` with `margin` to
-- spare. Returns the cells, the thinner spare range and the cells nobody notices.
function P.coverage(floor, in_room, spots, margin, sees)
	local cells, thinnest, missed = 0, math.huge, {}
	for _, cell in ipairs(floor) do
		if in_room(cell.x, cell.z) then
			cells = cells + 1
			local spare = P.noticed(spots, cell.x, cell.z, margin, sees)
			if spare then
				thinnest = math.min(thinnest, spare)
			else
				missed[#missed + 1] = cell.x .. "," .. cell.z
			end
		end
	end
	return cells, thinnest, missed
end

-- Walking round: a player's walk over the floor (`set` from P.floor) from `from`
-- ({x, z}) that never enters a cell `spots` notice (with `margin` to spare). The floor
-- is the only walking surface (P.perches proves it), so a walk on it is every walk.
-- `from` must be a floor cell nobody notices, or the question would answer itself; a
-- target the pack notices is no way round and drops out. Returns the first target
-- reached or nil, the targets kept and the cells noticed.
function P.walk_round(m, set, from, targets, spots, margin, sees)
	local sx = m.sx
	local noticed, count = {}, 0
	for key in pairs(set) do
		if P.noticed(spots, key % sx, math.floor(key / sx), margin, sees) then
			noticed[key] = true
			count = count + 1
		end
	end
	local function key(p) return p[2] * sx + p[1] end
	assert(set[key(from)] and not noticed[key(from)],
		("walk_round: the entrance %d,%d is a floor cell nobody notices"):format(from[1], from[2]))
	local want, kept = {}, 0
	for _, t in ipairs(targets) do
		if set[key(t)] and not noticed[key(t)] then
			want[key(t)] = t
			kept = kept + 1
		end
	end
	local seen, queue, head = {[key(from)] = true}, {from}, 1
	while queue[head] do
		local c = queue[head]
		head = head + 1
		if want[key(c)] then return want[key(c)], kept, count end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local n = {c[1] + d[1], c[2] + d[2]}
			local k = key(n)
			if n[1] >= 0 and n[1] < sx and set[k] and not noticed[k] and not seen[k] then
				seen[k] = true
				queue[#queue + 1] = n
			end
		end
	end
	return nil, kept, count
end

-- The floor cells within `reach` of a node at (x, z) a player digs from (the hand's and
-- every tool's range, 4 nodes, from the eye to the node's middle): an ore's targets.
function P.within_reach(set, sx, x, z, reach)
	local list = {}
	for dz = -reach, reach do
		for dx = -reach, reach do
			if dx * dx + dz * dz <= reach * reach and set[(z + dz) * sx + x + dx] then
				list[#list + 1] = {x + dx, z + dz}
			end
		end
	end
	return list
end

return P
