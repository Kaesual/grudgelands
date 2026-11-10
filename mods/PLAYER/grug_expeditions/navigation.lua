-- The mobs' way inside an Expedition (Round 74 NAV, round74-plan.md sections 3.1 and 3.2):
-- every path of an Expedition mob goes over its template's walk grid (walkgrid.lua), one
-- per template, made here once at load and shared by every run of it; a run only adds its
-- slot's minimum corner. Two users:
--   * the chase: grug_nav's backend (`mobs.grug_nav.grid`): its search and its walkable
--     line read the grid of the mob's run (mods/ENTITIES/mobs/grug_nav.lua);
--   * the evade: a guide of grug_mobs' evade seam (aggro.lua, register_evade_guide) that
--     walks the distance field of the mob's home: the furthest cell of the next
--     GUIDE_AHEAD on its way home that the mob walks to in a straight line.
-- Both answer only for a mob with `_grug_expedition` whose run is live and holds its home.
-- A moment off the grid (in the air, pushed into a wall: farther than walkgrid.SNAP from a
-- walking cell) the guide keeps its last point GUIDE_HOLD seconds. A mob whose home the
-- grid cannot reach (the user, 2026-11-10): on the grid with no way home over it (The
-- Last Mint's lake: mobs do not leap), or off the grid longer than GUIDE_HOLD (fallen into
-- that lake), is set home at once, the way a pack's jump places a mob (packs.lua jump:
-- grug_mobs.place_on_ground, its velocity stopped, its navigation forgotten), instead of
-- waiting for the evade's 40 s teleport; the guide then answers its home, and the evade
-- arrives on its next decision.
-- The door is read live: its place's node. Fields are built on first use and kept for the
-- server's life, keyed by the template, the home's cell, the body's class and the door.
local M = grug_expeditions
local path = core.get_modpath(core.get_current_modname())
local W = dofile(path .. "/walkgrid.lua")
local catalogue = M.catalogue
local nav = mobs.grug_nav

local DOOR = "grug_expeditions:reward_door"
-- Cells of the way home ahead of the mob a guide's point may lie at (nodes at most).
local GUIDE_AHEAD = 12
-- Nodes: a point the mob walks to straight but nearer than this is overrun before the
-- seam's next decision a second later (an evader runs 5 to 7 nodes a second: the Round 74
-- fix round's run saw a Lava Flan run from one ambush alcove of The Last Mint's flue to
-- the other and back for 40 s, each alcove's only straight cell one node away). Then the
-- guide answers the furthest cell of its way instead, out of the straight line, and the
-- navigation walks the grid's path there, steered every step (grug_nav fixed_step).
local GUIDE_NEAR = 3
-- Seconds a guide's last point stands in for an answer it lost (a jump, a knock aside, a
-- moment off the grid): a guide that flaps between a point and nil would switch the
-- seam's walk keys each second and so restart the navigation's episode (aggro.lua).
local GUIDE_HOLD = 2

M.walkgrid = W
for _, tpl in pairs(M.templates) do tpl.walkgrid = W.new(tpl) end

-- A run's view of its grid: {g, minp, run}, made once per run.
local views = setmetatable({}, {__mode = "k"})

local function view_of(self)
	local id = self._grug_expedition
	if not id then return nil end
	local home = self._grug_home
	local run = home and M.run_at(home)
	if not run or run.id ~= id then return nil end
	local view = views[run]
	if not view then
		local tpl = M.templates[catalogue.definition(run.expedition).template]
		if not (tpl and tpl.walkgrid) then return nil end
		view = {g = tpl.walkgrid, minp = run.minp, run = run}
		views[run] = view
	end
	return view
end

-- Open unless its node stands at the door place (unloaded reads shut).
local function door_open(view)
	local at = view.run.places and view.run.places.door
	if not at then return true end
	local node = core.get_node_or_nil(at)
	return node ~= nil and node.name ~= DOOR
end

-- The walking cell of a feet position for a body, or nil.
local function cell_of(view, pos, class, door)
	local o = view.minp
	return W.cell(view.g, pos.x - o.x, math.floor(pos.y + 0.55) - o.y, pos.z - o.z, class, door)
end

-- A cell's feet point in the map; a two-node body steers at the middle of its free 2 x 2
-- block (the previous one's quarter first, as grug_nav's fit).
local function point(view, i, class, quad)
	local g, o = view.g, view.minp
	local x, z = W.xz(g, i)
	local p = {x = o.x + x, y = o.y + W.height(g, i), z = o.z + z}
	if class == 2 then
		local bits = math.floor(W.flags(g, i) / 2)
		local pick
		if quad and math.floor(bits / 2 ^ (quad - 1)) % 2 == 1 then pick = quad end
		for k = 1, 4 do
			if not pick and math.floor(bits / 2 ^ (k - 1)) % 2 == 1 then pick = k end
		end
		if pick then
			p.x, p.z = p.x + W.QUADS[pick][1] * 0.5, p.z + W.QUADS[pick][2] * 0.5
			quad = pick
		end
	end
	return p, quad
end

-- A failed search's reason, counted in grug_nav's counters (the navigation probe reads
-- them): its start or its goal off the grid, or no way between them.
local function failed(reason)
	local counters = nav.counters
	counters[reason] = (counters[reason] or 0) + 1
	return nil
end

local function grid_path(view, body, from, goal)
	local class = W.class(body.width)
	local door = door_open(view)
	local s, t = cell_of(view, from, class, door), cell_of(view, goal, class, door)
	if not s then return failed("grid_off_start") end
	if not t then return failed("grid_off_goal") end
	local cells = W.path(view.g, s, t, class, door)
	if not cells then return failed("grid_no_way") end
	local steer, quad = {}, nil
	for k, i in ipairs(cells) do steer[k], quad = point(view, i, class, quad) end
	return steer
end

local A, B = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}
local function grid_line(view, body, a, b, rise)
	local o = view.minp
	A.x, A.y, A.z = a.x - o.x, a.y - o.y, a.z - o.z
	B.x, B.y, B.z = b.x - o.x, b.y - o.y, b.z - o.z
	return W.line(view.g, A, B, W.class(body.width), body.hw, door_open(view), rise)
end

nav.grid = {view = view_of, path = grid_path, line = grid_line}

-- The evade guide's next point on the way home; else nil and why: "off" (no walking cell
-- within SNAP) or "apart" (no way home over the grid). nil alone: not this guide's mob.
local function next_point(self, pos, home)
	local view = view_of(self)
	if not view then return nil end
	local body = nav.body(self)
	local g, o = view.g, view.minp
	local class, door = W.class(body.width), door_open(view)
	local feet = {x = pos.x, y = pos.y + body.feet, z = pos.z}
	local t = cell_of(view, home, class, door)
	if not t then return nil end
	local s = cell_of(view, feet, class, door)
	if not s then return nil, "off" end
	local field = W.field(g, t, class, door)
	if field:byte(s) == W.NONE then return nil, "apart" end
	local cells = W.descend(g, field, s, GUIDE_AHEAD)
	if #cells == 0 then return {x = home.x, y = home.y, z = home.z} end
	local a = {x = feet.x - o.x, y = feet.y - o.y, z = feet.z - o.z}
	local pick = 1
	for k = #cells, 1, -1 do
		local x, z = W.xz(g, cells[k])
		if W.line(g, a, {x = x, y = W.height(g, cells[k]), z = z}, class, body.hw, door, 0) then
			pick = k
			break
		end
	end
	local x, z = W.xz(g, cells[pick])
	if (x - a.x) ^ 2 + (z - a.z) ^ 2 < GUIDE_NEAR * GUIDE_NEAR then
		pick = #cells
		x, z = W.xz(g, cells[pick])
	end
	return {x = o.x + x, y = o.y + W.height(g, cells[pick]), z = o.z + z}
end

local function set_home(self, home)
	local t = self.temp
	t.grug_guide, t.grug_guide_off = nil, nil
	grug_mobs.place_on_ground(self.object, home)
	self.object:set_velocity({x = 0, y = 0, z = 0})
	nav.forget(t)
	return {x = home.x, y = home.y, z = home.z}
end

function M.evade_guide(self, pos, home)
	if not self._grug_expedition then return nil end
	self.temp = self.temp or {}
	local t = self.temp
	local now = core.get_us_time() / 1e6
	local p, why = next_point(self, pos, home)
	if p then
		t.grug_guide, t.grug_guide_off = {p = p, at = now}, nil
		return p
	end
	if why == "apart" then return set_home(self, home) end
	if why ~= "off" then return nil end
	local last = t.grug_guide
	if last and now - last.at <= GUIDE_HOLD then return last.p end
	-- Off the grid since when: answers come once a second, so a gap ends the stretch.
	local off = t.grug_guide_off
	if not off or now - off.seen > GUIDE_HOLD then
		off = {since = now}
		t.grug_guide_off = off
	end
	off.seen = now
	if now - off.since > GUIDE_HOLD then return set_home(self, home) end
	return nil
end

grug_mobs.register_evade_guide(M.evade_guide)
