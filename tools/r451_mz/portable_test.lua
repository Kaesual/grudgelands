-- Release 0.45.1 lane MZ, portable test (LuaJIT): the map window's zoom
-- with the soft lock on the player (the user's decision of 2026-10-10).
--
--   luajit tools/r451_mz/portable_test.lua [repo]
--
-- Loads the REAL grug_map atlas.lua (pure: no engine calls) and drives its
-- view state the way window.lua does: atlas.zoom_view for a zoom click,
-- atlas.scroll_event for the scrollbar fields of a window event. The
-- window's wiring and its focus rule are checked by tools/r44_mq.
-- Checks:
--   C  centre_scroll puts a point in the middle, clamps at the map's edges;
--   L  with the lock (every opening) zooming in from 1x centres on the
--      player; in, out, in stays on the player, near an edge too (clamped,
--      recomputed each step, no drift); echoed VAL fields change nothing;
--   B  a CHG at 2x-8x breaks the lock (also one scrolled exactly back); the
--      next zoom, in or out, keeps the current centre; a CHG at 1x does not
--      break it;
--   R  back at 1x the lock holds again and the next zoom centres on the
--      player;
--   S  values from a form of an older zoom (a send still owed) are read at
--      that zoom.
-- Prints "R451 MZ PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, ("%s (got %s, expected %s)"):format(label, tostring(actual),
		tostring(expected)))
end

local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local view = atlas.view()

-- The view centre in world coordinates for a state (the inverse of
-- centre_scroll without the clamp).
local function centre_of(state)
	local zoom = state.zoom
	local fx = (state.scroll_x + 500) / (1000 * zoom)
	local fy = (state.scroll_y + 500) / (1000 * zoom)
	return view.min_x + fx * (view.max_x - view.min_x), view.max_z - fy * (view.max_z - view.min_z)
end
-- Whether a world point is inside the shown viewport.
local function visible(state, pos)
	local zoom = state.zoom
	local px = (pos.x - view.min_x) / (view.max_x - view.min_x) * 1000 * zoom
	local py = (view.max_z - pos.z) / (view.max_z - view.min_z) * 1000 * zoom
	return px >= state.scroll_x and px <= state.scroll_x + 1000 and
		py >= state.scroll_y and py <= state.scroll_y + 1000
end
-- One window opening (window.lua W.open).
local function opened() return {zoom = 1, scroll_x = 0, scroll_y = 0, follow = true} end
-- Two scroll units of tolerance: scroll values are rounded integers (one
-- unit is 7.2 nodes across and 6.4 down at 1x, 0.9 and 0.8 at 8x), and a
-- kept centre is rounded at each step.
local function near_pos(state, pos, label)
	local x, z = centre_of(state)
	check(math.abs(x - pos.x) <= 14.4 / state.zoom + 1e-6 and
		math.abs(z - pos.z) <= 12.8 / state.zoom + 1e-6,
		("%s (centre %.1f,%.1f vs %.1f,%.1f at %dx)"):format(label, x, z, pos.x, pos.z, state.zoom))
end

-- C: centre_scroll.
do
	local x, y = atlas.centre_scroll(view, {x = 0, z = 0}, 2)
	eq(x, 500, "C the map's centre at 2x, x")
	eq(y, 500, "C the map's centre at 2x, y")
	x, y = atlas.centre_scroll(view, {x = view.min_x, z = view.max_z}, 4)
	check(x == 0 and y == 0, "C the north-west corner clamps to 0,0")
	x, y = atlas.centre_scroll(view, {x = view.max_x + 500, z = view.min_z - 500}, 8)
	check(x == 7000 and y == 7000, "C a point beyond the south-east corner clamps to the limit")
	x, y = atlas.centre_scroll(view, {x = 1800, z = 0}, 1)
	check(x == 0 and y == 0, "C 1x has no scroll")
end

-- L: the lock on the player, in the middle of the map and near an edge.
local mid = {x = 1234, y = 12, z = -987}
local edge = {x = view.max_x - 150, y = 3, z = view.max_z - 90}
do
	local state = opened()
	atlas.zoom_view(state, true, view, mid)
	eq(state.zoom, 2, "L zoom in from 1x")
	near_pos(state, mid, "L 1x->2x centres on the player")
	atlas.zoom_view(state, true, view, mid)
	near_pos(state, mid, "L 2x->4x stays on the player")
	atlas.zoom_view(state, false, view, mid)
	near_pos(state, mid, "L 4x->2x stays on the player")
	atlas.zoom_view(state, true, view, mid)
	atlas.zoom_view(state, true, view, mid)
	eq(state.zoom, 8, "L up to 8x")
	near_pos(state, mid, "L in, out, in, in stays on the player")
	-- The echo of the shown form changes nothing while the lock holds.
	local sx, sy = state.scroll_x, state.scroll_y
	check(not atlas.scroll_event(state, "VAL:12", "VAL:34", 8), "L VAL is no move")
	check(state.follow and state.scroll_x == sx and state.scroll_y == sy,
		"L VAL keeps the lock and the view")

	-- Near the north-east edge: clamped (visible, not centred), and the
	-- same view after in/out/in as straight in (no drift).
	local a = opened()
	atlas.zoom_view(a, true, view, edge)
	atlas.zoom_view(a, true, view, edge)
	local b = opened()
	atlas.zoom_view(b, true, view, edge)
	atlas.zoom_view(b, true, view, edge)
	atlas.zoom_view(b, false, view, edge)
	atlas.zoom_view(b, true, view, edge)
	eq(a.zoom, 4, "L edge at 4x")
	check(a.scroll_x == 3000 and a.scroll_y == 0, ("L edge clamps (%d,%d)"):format(a.scroll_x, a.scroll_y))
	check(visible(a, edge), "L edge: the player stays visible")
	check(a.scroll_x == b.scroll_x and a.scroll_y == b.scroll_y and b.zoom == 4,
		"L edge: in/out/in ends where straight in does (no drift)")
	atlas.zoom_view(b, false, view, edge)
	check(b.zoom == 2 and b.scroll_x == 1000 and b.scroll_y == 0 and visible(b, edge),
		"L edge: out from 4x is clamped on the player too")
end

-- B: the player's own scrolling breaks the lock.
do
	local state = opened()
	atlas.zoom_view(state, true, view, mid)
	atlas.zoom_view(state, true, view, mid)
	check(atlas.scroll_event(state, "CHG:1200", "VAL:" .. state.scroll_y, 4), "B CHG is a move")
	check(not state.follow, "B a CHG at 4x breaks the lock")
	eq(state.scroll_x, 1200, "B the moved value is kept")
	local cx, cz = centre_of(state)
	atlas.zoom_view(state, true, view, mid)
	local nx, nz = centre_of(state)
	check(state.zoom == 8 and math.abs(nx - cx) < 1 and math.abs(nz - cz) < 1,
		"B zoom in keeps the current centre, not the player")
	atlas.zoom_view(state, false, view, mid)
	nx, nz = centre_of(state)
	check(state.zoom == 4 and math.abs(nx - cx) < 1 and math.abs(nz - cz) < 1,
		"B zoom out keeps the current centre too")
	-- Further scrolling moves that centre.
	atlas.scroll_event(state, "VAL:" .. state.scroll_x, "CHG:2500", 4)
	cx, cz = centre_of(state)
	atlas.zoom_view(state, false, view, mid)
	nx, nz = centre_of(state)
	check(state.zoom == 2 and math.abs(nx - cx) < 4 and math.abs(nz - cz) < 4,
		"B scrolling again moves the kept centre")

	-- Scrolled exactly back: still broken.
	local back = opened()
	atlas.zoom_view(back, true, view, mid)
	local x0, y0 = back.scroll_x, back.scroll_y
	atlas.scroll_event(back, "CHG:" .. x0, "VAL:" .. y0, 2)
	check(not back.follow and back.scroll_x == x0 and back.scroll_y == y0,
		"B scrolled exactly back still breaks the lock")
	atlas.zoom_view(back, true, view, {x = -2000, z = 2000})
	near_pos(back, mid, "B ... so the next zoom ignores the player and keeps the centre")

	-- At 1x a CHG (the bar cannot move there) does not break the lock.
	local one = opened()
	atlas.scroll_event(one, "CHG:0", "VAL:0", 1)
	check(one.follow, "B a CHG at 1x keeps the lock")
end

-- R: back at 1x the lock is restored.
do
	local state = opened()
	atlas.zoom_view(state, true, view, mid)
	atlas.scroll_event(state, "CHG:0", "VAL:0", 2)
	check(not state.follow, "R broken at 2x")
	atlas.zoom_view(state, false, view, mid)
	check(state.zoom == 1 and state.follow and state.scroll_x == 0 and state.scroll_y == 0,
		"R back at 1x restores the lock")
	atlas.zoom_view(state, true, view, mid)
	near_pos(state, mid, "R the next zoom centres on the player again")
	-- Broken at 8x, out to 1x step by step: the centre is kept down to 2x,
	-- the lock returns at 1x.
	atlas.zoom_view(state, true, view, mid)
	atlas.zoom_view(state, true, view, mid)
	atlas.scroll_event(state, "CHG:3000", "CHG:4000", 8)
	local cx, cz = centre_of(state)
	atlas.zoom_view(state, false, view, mid)
	local nx, nz = centre_of(state)
	check(not state.follow and math.abs(nx - cx) < 1 and math.abs(nz - cz) < 1,
		"R 8x->4x keeps the scrolled centre")
	atlas.zoom_view(state, false, view, mid)
	atlas.zoom_view(state, false, view, mid)
	check(state.zoom == 1 and state.follow, "R 1x restores it")
	atlas.zoom_view(state, true, view, mid)
	near_pos(state, mid, "R and the zoom from 1x centres on the player")
end

-- S: a form of an older zoom (the zoom's send still owed).
do
	local state = opened()
	atlas.zoom_view(state, true, view, mid)
	atlas.scroll_event(state, "CHG:300", "VAL:400", 2) -- broken at 2x
	local cx, cz = centre_of(state)
	atlas.zoom_view(state, true, view, mid) -- 4x, not yet sent
	-- Another click on the 2x form: its values are 2x values.
	atlas.scroll_event(state, "VAL:300", "VAL:400", 2)
	local nx, nz = centre_of(state)
	check(state.zoom == 4 and math.abs(nx - cx) < 1 and math.abs(nz - cz) < 1,
		"S a stale form's values are read at its zoom")
	-- With the lock, a stale echo cannot move the view off the player.
	local locked = opened()
	atlas.zoom_view(locked, true, view, mid) -- 2x, not yet sent
	atlas.scroll_event(locked, "VAL:0", "VAL:0", 1)
	near_pos(locked, mid, "S a stale 1x echo leaves the lock's view alone")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R451 MZ PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print(("R451 MZ PORTABLE PASS checks=%d"):format(checks))
