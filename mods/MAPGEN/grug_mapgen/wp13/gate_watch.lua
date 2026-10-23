-- The watch of a capital's core gatehouse (Round 58; the user's ruling of
-- 2026-10-22, round56-plan.md §8 "Gate guards"): the two ground guards walk a
-- rectangle on the city side of the gate in opposite directions, and the
-- tower guard holds a post on the deck.
--
-- The gatehouse template (`<capital>_gate_south.tpl`, five capitals; Kezamba's
-- open core has no gatehouse) keeps the watch's points where the frozen
-- generator put them: two guard posts in the passage, `{id}_post_west` and
-- `{id}_post_east`, and the tower's two waypoints, `{id}_deck` and
-- `{id}_rampart`. A capital's core turns them into the watch here, after it
-- has taken the stamped gate's sockets: the passage posts go (their two
-- guards walk the rectangle), the deck waypoint becomes the tower guard's
-- post and the rampart waypoint goes. The rectangle lies outside the
-- template's box, on the capital's own ground, so it is the capital's point
-- (format doc §3.4), written here once for the five capitals.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The rectangle in the gatehouse's own frame (the template's, turns = 0:
	-- x along the field face, z = 0 the field side, the passage x 4..8 with
	-- its city mouth at z = 6, the chamber doors at x 2 and 10). Two nodes in
	-- front of the city wall, so the doors stay free, and between the avenue
	-- lamps the capitals stand at x 3 and 9: clear ground in every capital's
	-- every gate (tools/r58_townfix).
	M.RECT = {x1 = 2, z1 = 8, x2 = 10, z2 = 12}

	-- Each guard starts at a front corner and walks its own side out first,
	-- so the two meet in the middle of the far side and in front of the gate
	-- mouth: the west guard clockwise, the east guard counter-clockwise (seen
	-- from above, x east and z north).
	local r = M.RECT
	M.LOOPS = {
		{name = "west", corners = {{r.x1, r.z1}, {r.x1, r.z2}, {r.x2, r.z2}, {r.x2, r.z1}}},
		{name = "east", corners = {{r.x2, r.z1}, {r.x2, r.z2}, {r.x1, r.z2}, {r.x1, r.z1}}},
	}

	local DROPPED = {post_west = true, post_east = true, rampart = true}

	local function sign(value)
		if value > 0 then return 1 elseif value < 0 then return -1 end
		return 0
	end

	-- `sockets[first ..]` are the gate's own sockets, as the capital took
	-- them from the stamp; `plot` is its placement ({id, x, z, turns}, stamped
	-- at y 0), `w` and `d` its part's pivot, `prefix` the capital's key (the
	-- loop names, as the template's own `group=<capital>_{id}_tower` had it),
	-- `buf` the core's buffer (it remembers the corners for `clear_cover`).
	function M.apply(sockets, first, plot, w, d, prefix, buf)
		buf.watch_corners = buf.watch_corners or {}
		local kept, posts = {}, 0
		for index = first, #sockets do
			local socket = sockets[index]
			local tail = socket.id:sub(#plot.id + 2)
			if tail == "deck" then
				socket.role, socket.group, socket.order = "guard_post", nil, nil
				posts = posts + 1
			end
			if not DROPPED[tail] then kept[#kept + 1] = socket end
			sockets[index] = nil
		end
		if posts ~= 1 then
			error("wp13 gate watch: " .. prefix .. "'s " .. plot.id ..
				" has no deck waypoint", 0)
		end
		for index, socket in ipairs(kept) do sockets[first + index - 1] = socket end
		for _, loop in ipairs(M.LOOPS) do
			local corners = loop.corners
			for order, corner in ipairs(corners) do
				local nxt = corners[order % #corners + 1]
				local face = parts.step_facedir(sign(nxt[1] - corner[1]),
					sign(nxt[2] - corner[2]))
				local rx, rz = parts.rotate_footprint(corner[1], corner[2], w, d,
					plot.turns)
				local corners_seen = buf.watch_corners
				corners_seen[#corners_seen + 1] = {plot.x + rx, plot.z + rz}
				sockets[#sockets + 1] = {
					id = plot.id .. "_watch_" .. loop.name .. "_" .. order,
					role = "guard_patrol", x = plot.x + rx, y = 1, z = plot.z + rz,
					face = (face + plot.turns) % 4,
					group = prefix .. "_" .. plot.id .. "_watch_" .. loop.name,
					order = order,
				}
			end
		end
	end

	-- The ground cover the capital's meadow flora planted on a corner's feet
	-- or head cell (after the plots, `dressing.undergrowth`), taken off again
	-- so the watch's corners stand on open ground (the cover rule of
	-- tools/r51_ft: no cover on a socket). `palette` is the core's race
	-- palette.
	local COVER = {"undergrowth", "grass_tuft", "fern"}
	function M.clear_cover(buf, palette)
		local cover = {}
		for _, role in ipairs(COVER) do
			local name = palette.maybe(role)
			if name then cover[name] = true end
		end
		for _, corner in ipairs(buf.watch_corners or {}) do
			for y = 1, 2 do
				local cell = buf:at(corner[1], y, corner[2])
				if cell and cover[cell.name] then
					buf:put(corner[1], y, corner[2], parts.AIR, 0)
				end
			end
		end
		buf.watch_corners = nil
	end

	return M
end

return loader
