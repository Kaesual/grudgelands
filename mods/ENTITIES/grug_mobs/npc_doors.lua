--
-- NPC DOORS (Round 42 DR; round42-plan.md §4.5, ruling 15; settlements.md
-- "Doors"). Settlement NPCs open a door on their way, pass it and close it
-- again. To the engine's pathfinder a door is a wall, open or closed (its
-- node is walkable: doors/init.lua), so no search ever goes through one: a
-- walk through a door is three pieces, "to the door" (a search to the cell
-- in front of it), "through the door" (a straight walk over its centre to
-- the cell behind it) and "from the door" (a search on).
--
--   * THE DOORS ARE FOUND AT RUNTIME, in the world, only where a walk needs
--     one: the upright doors (`doors.registered_doors`) within REACH of a
--     walk's end, nearest first. Nothing is written by the mapgen for it and
--     nothing is saved: a door is keyed by its node position. A door counts
--     when it stands in a wall (its two neighbours along the wall are not
--     open, the cells in front of and behind it are) and nobody owns it.
--   * NEVER WHAT A PLAYER OWNS: a door with an owner (a locked door a player
--     placed) is no door for an NPC. Trapdoors and fence gates are not doors
--     here either: a trapdoor is no way through a wall, and mobs_redo stops
--     every walker that faces a node named "gate" (`facing_fence`), open or
--     not, so NPCs route round a gate as round a fence (settlements.md).
--   * OPENING: `doors.get(pos):open()` with no player, which skips the
--     interaction check (doors.door_toggle), so a door in a protected
--     settlement opens; the vendored toggle plays the door's own open and
--     close sounds (ruling 15; no second play path). Opening and closing a
--     settlement door is the second recorded exception to the terrain-damage
--     guard besides the rift's crack (AGENTS.md).
--   * CLOSING: a walker closes the door it opened once it is through (CLEAR
--     from the centre), unless another NPC heading through the same door is
--     right behind (BEHIND): that one closes it after it. Somebody standing
--     in the doorway keeps it open for now. A door a player opened, or one
--     an NPC found open, stays open; so does one whose opener was unloaded
--     or died on the way (the claim is runtime state, never saved).
--
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local D = {
	REACH = 20, -- nodes (horizontal) from a walk's end a door is looked for
	RISE = 4, -- nodes up and down
	PER_END = 3, -- doors tried per end, nearest first
	OPEN_REACH = 1.6, -- nodes from the door's centre: the walker opens it
	CLEAR = 1, -- nodes from the door's centre: the walker is through
	BEHIND = 4, -- nodes: another NPC heading through this close keeps it open
	FORGET = 8, -- nodes: a walker this far from the door it opened lets it be
	IN_DOOR = 0.9, -- nodes from the centre: somebody stands in the doorway
	RETRY = 0.5, -- s before a close kept back by somebody in the doorway retries
}
grug_mobs.npc_doors = D

local function api()
	return rawget(_G, "doors")
end

function D.key(p)
	return p.x .. "," .. p.y .. "," .. p.z
end

--
-- Cells.
--
local P = {x = 0, y = 0, z = 0}
local function def_at(x, y, z)
	P.x, P.y, P.z = x, y, z
	local node = core.get_node_or_nil(P)
	if not node or node.name == "ignore" then return nil end
	return core.registered_nodes[node.name]
end

-- Feet and head free: loaded, known and not walkable (an unknown or
-- unloaded node is a wall, as for the navigation).
local function open_cell(x, y, z)
	local a, b = def_at(x, y, z), def_at(x, y + 1, z)
	return a ~= nil and b ~= nil and not a.walkable and not b.walkable
end

local function stands(x, y, z)
	if not open_cell(x, y, z) then return false end
	local g = def_at(x, y - 1, z)
	return g ~= nil and g.walkable == true
end

-- The feet height of the cell in front of or behind a door: level with the
-- door, or one lower (a step down off the threshold).
local function side_y(x, y, z)
	if stands(x, y, z) then return y end
	if stands(x, y - 1, z) then return y - 1 end
	return nil
end

--
-- The door at node position `p` as NPCs see it, or nil: an upright door
-- nobody owns, standing in a wall, with a place to stand on either side.
-- {x, y, z (its foot), key, ax, az (the way through), sides = {the cell on
-- the -axis side, the cell on the +axis side}}.
--
function D.at(p)
	local doors = api()
	local node = core.get_node_or_nil(p)
	if not doors or not node or not doors.registered_doors[node.name] then
		return nil
	end
	if core.get_meta(p):get_string("owner") ~= "" then return nil end
	local x, y, z = p.x, p.y, p.z
	local along_x = open_cell(x - 1, y, z) and open_cell(x + 1, y, z)
	local along_z = open_cell(x, y, z - 1) and open_cell(x, y, z + 1)
	local ax, az
	if along_x and not along_z then
		ax, az = 1, 0
	elseif along_z and not along_x then
		ax, az = 0, 1
	else
		return nil
	end
	local y1 = side_y(x - ax, y, z - az)
	local y2 = side_y(x + ax, y, z + az)
	if not y1 or not y2 then return nil end
	return {x = x, y = y, z = z, key = D.key(p), ax = ax, az = az,
		sides = {{x = x - ax, y = y1, z = z - az}, {x = x + ax, y = y2, z = z + az}}}
end

-- Which side of door `d` position `p` is on: the cell on p's side, the cell
-- on the other side, and how far p is from the door's plane.
function D.sides(d, p)
	local s = (p.x - d.x) * d.ax + (p.z - d.z) * d.az
	if s < 0 then return d.sides[1], d.sides[2], -s end
	return d.sides[2], d.sides[1], s
end

local function hdist(a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	return sqrt(dx * dx + dz * dz)
end

-- Is the box loaded (sampled per mapblock at its two heights)?
local function box_loaded(minp, maxp)
	for _, y in ipairs({minp.y, maxp.y}) do
		local x = minp.x
		while true do
			local z = minp.z
			while true do
				P.x, P.y, P.z = x, y, z
				local node = core.get_node_or_nil(P)
				if not node or node.name == "ignore" then return false end
				if z >= maxp.z then break end
				z = math.min(z + 16, maxp.z)
			end
			if x >= maxp.x then break end
			x = math.min(x + 16, maxp.x)
		end
	end
	return true
end

--
-- The doors near `p` (a walk's end): within REACH and RISE, not on p's own
-- plane, not in `tried` (keys), nearest first, at most PER_END. "wait" when
-- the area is not loaded (unloaded is never "no door": the route cache
-- remembers its verdict); `partial`: the loaded part answers (a fixed
-- walk's detour, which is tried again on its next failure).
--
function D.near(p, tried, partial)
	if not api() then return {} end
	local cx, cy, cz = floor(p.x + 0.5), floor(p.y + 0.5), floor(p.z + 0.5)
	local minp = {x = cx - D.REACH, y = cy - D.RISE, z = cz - D.REACH}
	local maxp = {x = cx + D.REACH, y = cy + D.RISE, z = cz + D.REACH}
	if not partial and not box_loaded(minp, maxp) then return "wait" end
	local out = {}
	for _, q in ipairs(core.find_nodes_in_area(minp, maxp, "group:door")) do
		local d = D.at(q)
		if d and not (tried and tried[d.key]) then
			local _, _, off = D.sides(d, p)
			d.dist = hdist(p, d)
			if off >= 0.5 and d.dist <= D.REACH then out[#out + 1] = d end
		end
	end
	table.sort(out, function(a, b)
		if a.dist ~= b.dist then return a.dist < b.dist end
		return a.key < b.key
	end)
	for k = #out, D.PER_END + 1, -1 do out[k] = nil end
	return out
end

--
-- The door a fixed walk from `from` to `to` (feet positions) may cross: one
-- near either end (in the loaded part) whose wall has the two on opposite
-- sides, the shortest way over it first; nil when there is none.
--
function D.between(from, to, tried)
	local list = {}
	for _, p in ipairs({to, from}) do
		for _, d in ipairs(D.near(p, tried, true)) do list[#list + 1] = d end
	end
	local best, cost
	for _, d in ipairs(list) do
		local here = D.sides(d, from)
		local there = D.sides(d, to)
		if here ~= there then
			local c = hdist(from, d) + hdist(d, to)
			if not cost or c < cost or (c == cost and d.key < best.key) then
				best, cost = d, c
			end
		end
	end
	return best
end

--
-- Crossing. `d` is a door as a walk carries it ({x, y, z, key}).
--
local function door_ref(d)
	local doors = api()
	local ref = doors and doors.get({x = d.x, y = d.y, z = d.z})
	if not ref then return nil end
	if core.get_meta({x = d.x, y = d.y, z = d.z}):get_string("owner") ~= "" then
		return nil
	end
	return ref
end

-- The walker heads through door `d` (runtime only; the right-behind test of
-- another walker reads it). nil: no door ahead.
function D.heading(self, d)
	self.temp.grug_door_next = d and d.key or nil
end

-- The walker heads into door `d`: within OPEN_REACH it opens it when shut,
-- and the close is then its own.
function D.approach(self, pos, d)
	local dx, dz = d.x - pos.x, d.z - pos.z
	if dx * dx + dz * dz > D.OPEN_REACH * D.OPEN_REACH then return end
	local ref = door_ref(d)
	if not ref or ref:state() then return end
	if ref:open() then
		self.temp.grug_door_open = {x = d.x, y = d.y, z = d.z, key = d.key}
	end
end

--
-- Every step of a walker that opened a door: once it is through, close it,
-- or hand the close to an NPC right behind, or wait for the doorway to
-- clear. Far away (an arrival beside it, a fight that pulled it off), it
-- lets the door be.
--
function D.settle(self, pos)
	local t = self.temp
	local o = t.grug_door_open
	if t.grug_door_next == o.key then return end
	local dx, dz = o.x - pos.x, o.z - pos.z
	local d2 = dx * dx + dz * dz
	if d2 > D.FORGET * D.FORGET then
		t.grug_door_open = nil
		return
	end
	if d2 < D.CLEAR * D.CLEAR then return end
	local now = core.get_us_time()
	if now < (t.grug_door_retry or 0) then return end
	local ref = door_ref(o)
	if not ref or not ref:state() then
		-- Shut by somebody else, or no door any more.
		t.grug_door_open = nil
		return
	end
	local centre = {x = o.x, y = o.y + 0.5, z = o.z}
	local in_door = false
	for _, obj in ipairs(core.get_objects_inside_radius(centre, D.BEHIND)) do
		local ent = not obj:is_player() and obj:get_luaentity()
		if ent ~= self then
			if ent and ent.temp and ent.temp.grug_door_next == o.key then
				-- Right behind: the close is its own once it is through.
				if not ent.temp.grug_door_open then ent.temp.grug_door_open = o end
				t.grug_door_open = nil
				return
			end
			local p = obj:get_pos()
			if p and abs(p.y - centre.y) < 2 and abs(p.x - o.x) < D.IN_DOOR
					and abs(p.z - o.z) < D.IN_DOOR then
				in_door = true
			end
		end
	end
	if in_door then
		t.grug_door_retry = now + D.RETRY * 1000000
		return
	end
	ref:close()
	t.grug_door_open = nil
end

return D
