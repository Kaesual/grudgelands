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
--   * NEVER A LOCKED DOOR: a door with an owner (a locked door a player
--     placed) is no door for an NPC. Trapdoors and fence gates are not doors
--     here either: a trapdoor is no way through a wall, and mobs_redo stops
--     every walker that faces a fence gate (`facing_fence`: a blocking node
--     named "gate"; open or closed, a gate's node is walkable), so NPCs route
--     round a gate as round a fence (settlements.md).
--   * OPENING: `doors.get(pos):open()` with no player, which skips the
--     interaction check (doors.door_toggle), so a door in a protected
--     settlement opens; the vendored toggle plays the door's own open and
--     close sounds (ruling 15; no second play path). Opening and closing a
--     settlement door is the second recorded exception to the terrain-damage
--     guard besides the rift's crack (AGENTS.md).
--   * CLOSING: a walker closes the door it opened once it is through (CLEAR
--     from the centre), unless another NPC heading through the same door is
--     right behind (BEHIND): that one closes it after it. A player or a mob
--     standing in the doorway (within CLEAR of the centre, the same measure)
--     keeps it open for now; attached objects (a nametag carrier) and items
--     are nobody. A walker holds every door it opened or was handed until
--     each is settled (`grug_door_open`, door key -> door), so a second door
--     never drops the first. A door a player opened, or one an NPC found
--     open, stays open; so does one whose opener was unloaded or died on the
--     way (the claims are runtime state, never saved).
--
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local D = {
	REACH = 20, -- nodes (horizontal) from a walk's end a door is looked for
	RISE = 4, -- nodes up and down
	PER_END = 3, -- doors tried per end, nearest first
	OPEN_REACH = 1.6, -- nodes from the door's centre: the walker opens it
	CLEAR = 0.9, -- nodes from the door's centre: the walker (0.6 wide) is through
	BEHIND = 4, -- nodes: another NPC heading through this close keeps it open
	FORGET = 8, -- nodes: a walker this far from the door it opened lets it be
	RETRY = 0.5, -- s before a close kept back by somebody in the doorway retries
	FRONT_REACH = 0.15, -- nodes: the cell in front of a door is reached
	-- An open leaf lies along one side of its cell (a 1/8 node panel): the
	-- way through is 7/8 wide and its middle 1/16 off the cell's centre.
	-- A body 0.6 wide has 0.14 to spare on either side of that middle.
	SHIFT = 1 / 16,
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

-- Where a walker aims at point `p` of the way through door `d` (its
-- centre, the cells in front and behind): the middle of the doorway, 1/16
-- off the cell's centre away from the open leaf. A leaf's panel lies on its
-- node's -z face turned by its facedir (doors/init.lua collision_box), so
-- an open leaf of facedir f lies toward -dir(f).
local FACE = {[0] = {0, 1}, [1] = {1, 0}, [2] = {0, -1}, [3] = {-1, 0}}
function D.aim(d, p)
	local doors = api()
	local node = core.get_node_or_nil({x = d.x, y = d.y, z = d.z})
	if not doors or not node or not doors.registered_doors[node.name] then return p end
	local ref = doors.get({x = d.x, y = d.y, z = d.z})
	if not ref or not ref:state() then return p end
	local f = FACE[node.param2 % 4]
	return {x = p.x + f[1] * D.SHIFT, y = p.y, z = p.z + f[2] * D.SHIFT}
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
		local t = self.temp
		t.grug_door_open = t.grug_door_open or {}
		t.grug_door_open[d.key] = {x = d.x, y = d.y, z = d.z, key = d.key}
	end
end

-- Is `obj` somebody in the doorway of door `o`: a player or a mob (not one
-- attached to something: a nametag carrier, a rider) within CLEAR of the
-- door's centre, the measure a walker is through by.
local function in_doorway(obj, o)
	if obj:get_attach() then return false end
	if not obj:is_player() then
		local ent = obj:get_luaentity()
		if not (ent and ent._cmi_is_mob) then return false end
	end
	local p = obj:get_pos()
	if not p or abs(p.y - (o.y + 0.5)) >= 2 then return false end
	local dx, dz = p.x - o.x, p.z - o.z
	return dx * dx + dz * dz < D.CLEAR * D.CLEAR
end

-- One held door `o`: true when it is settled (closed, handed over, shut by
-- somebody else, or let be from far away); "wait" when somebody stands in
-- the doorway; false while the walker is not through yet.
local function settle_one(self, t, pos, o)
	if t.grug_door_next == o.key then return false end
	local dx, dz = o.x - pos.x, o.z - pos.z
	local d2 = dx * dx + dz * dz
	if d2 > D.FORGET * D.FORGET then return true end
	if d2 < D.CLEAR * D.CLEAR then return false end
	local ref = door_ref(o)
	-- Shut by somebody else, or no door any more.
	if not ref or not ref:state() then return true end
	local centre = {x = o.x, y = o.y + 0.5, z = o.z}
	local in_door = false
	for _, obj in ipairs(core.get_objects_inside_radius(centre, D.BEHIND)) do
		local ent = not obj:is_player() and obj:get_luaentity()
		if ent ~= self then
			if ent and ent.temp and ent.temp.grug_door_next == o.key then
				-- Right behind: the close is its own once it is through
				-- (added to what it holds, never in place of it).
				local held = ent.temp.grug_door_open or {}
				ent.temp.grug_door_open = held
				held[o.key] = o
				return true
			end
			if in_doorway(obj, o) then in_door = true end
		end
	end
	if in_door then return "wait" end
	ref:close()
	return true
end

--
-- Every step of a walker that holds doors it opened (or was handed): once
-- it is through one, close it, or hand the close to an NPC right behind, or
-- wait for the doorway to clear. Far away (an arrival beside it, a fight
-- that pulled it off), it lets the door be.
--
function D.settle(self, pos)
	local t = self.temp
	local now = core.get_us_time()
	if now < (t.grug_door_retry or 0) then return end
	local left, wait = false, false
	for key, o in pairs(t.grug_door_open) do
		local done = settle_one(self, t, pos, o)
		if done == true then
			t.grug_door_open[key] = nil
		else
			left, wait = true, wait or done == "wait"
		end
	end
	if not left then t.grug_door_open = nil end
	-- Kept back by somebody in a doorway: look again a little later.
	t.grug_door_retry = wait and now + D.RETRY * 1000000 or nil
end

return D
