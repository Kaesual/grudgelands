-- Round 69 lane CAMP: the camp site templates through the real blueprint
-- (every race, every turn) and the box rewrite's job with a recording engine.
--   luajit tools/r69_camp/portable_test.lua <repo>
local repo = assert(arg[1])
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local build = dofile(dir .. "/r58_camp_blueprint.lua")
local rot = dofile(dir .. "/../wp13/plot_approach.lua").rot
local R, HEIGHT = 11, 9
local function key(x, y, z) return x .. ":" .. y .. ":" .. z end

local SOCKETS = {gate_west = {-2, -9, 1, 0, "guard_post", "gate"}, gate_east = {2, -9, -1, 0, "guard_post", "gate"},
	yard_west = {-4, 1, 0, -1, "guard_post", "camp"}, yard_east = {4, 1, 0, -1, "guard_post", "camp"},
	captain = {0, 3, 0, -1, "captain"}}
local FACTION = {human = "accord", dwarf = "accord", elf = "accord", orc = "throng", undead = "throng", troll = "throng"}

local builds = 0
for race, faction in pairs(FACTION) do
	for turns = 0, 3 do
		local bp = build({}, {blueprint_schema = "test", art = {kind = "camp_construction",
			faction = faction, race = race, turns = turns}})
		builds = builds + 1
		local label = race .. " turn " .. turns .. ": "
		assert(bp.clear_to == HEIGHT and bp.bounds.max.y == HEIGHT and bp.bounds.max.x == R,
			label .. "the box differs")
		local cells = {}
		for _, c in ipairs(bp.cells) do
			assert(math.abs(c.x) <= R and math.abs(c.z) <= R and c.y >= 0 and c.y <= HEIGHT,
				label .. "a cell outside the box")
			assert(not cells[key(c.x, c.y, c.z)], label .. "a cell twice")
			assert(c.name ~= "ignore" and not c.name:match("^wool:"), label .. "wool or ignore: " .. c.name)
			cells[key(c.x, c.y, c.z)] = c.name
		end
		assert(#bp.cells == (2 * R + 1) * (2 * R + 1) * (HEIGHT + 1), label .. "the box is not whole")
		local function clear(x, y, z) return cells[key(x, y, z)] == "air" end
		local function stand(x, z)
			return clear(x, 1, z) and clear(x, 2, z) and not clear(x, 0, z)
		end
		-- Yard and anchor support (the local frame's centre does not turn).
		for z = -2, 2 do for x = -2, 2 do for y = 1, 3 do
			assert(clear(x, y, z), label .. "the yard is blocked")
		end end end
		assert(not clear(0, 0, 0), label .. "no anchor support")
		-- The gate: every cell of the opening, and a walk from it.
		local gx, gz = rot(0, -R, turns)
		assert(stand(gx, gz), label .. "the gate is blocked")
		local queue, seen, at = {{gx, gz}}, {[key(gx, 1, gz)] = true}, 1
		while queue[at] do
			local p = queue[at]
			at = at + 1
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local x, z = p[1] + d[1], p[2] + d[2]
				local k = key(x, 1, z)
				if math.abs(x) <= R and math.abs(z) <= R and not seen[k] and stand(x, z) then
					seen[k] = true
					queue[#queue + 1] = {x, z}
				end
			end
		end
		-- The sockets: ids, cells, facings and tags as every world's garrison
		-- has them, clear and reachable from the gate.
		local found = 0
		for _, s in ipairs(bp.landmarks.sockets) do
			local row = assert(SOCKETS[s.id], label .. "an unknown socket " .. tostring(s.id))
			local x, z = rot(row[1], row[2], turns)
			local dx, dz = rot(row[3], row[4], turns)
			assert(s.x == x and s.z == z and s.y == 1 and s.dir.x == dx and s.dir.z == dz and
				s.role == row[5], label .. "socket " .. s.id .. " moved")
			assert((s.tags and s.tags[1]) == row[6], label .. "socket " .. s.id .. " tags")
			assert(stand(x, z), label .. "socket " .. s.id .. " blocked")
			assert(seen[key(x, 1, z)], label .. "socket " .. s.id .. " unreachable")
			found = found + 1
		end
		assert(found == 5, label .. "a socket is missing")
	end
end
print(("templates: %d builds, gate, yard, support, sockets, whole box"):format(builds))
