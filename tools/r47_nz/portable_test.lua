-- Round 47 lane NZ portable test (LuaJIT; round47-plan.md §4.9, rulings
-- 20-22):
--   F  NPC facing: over every composition with NPC sockets (the starts, the
--      Round 14 villages, outposts and camps of every race, the Round 20
--      POIs, the PvP fortresses and camps in every camp race, every capital
--      core and plot) no NPC faces a wall within two nodes without a work
--      feature before it (tools/r47_nz/facing.lua); and the rule itself: a
--      wall a node or two ahead fails, its turned twin passes, `door` turns
--      the facing round, a feature or a low wall at the feet passes, a
--      wall course under a window is no stall counter.
--
-- Usage (repo root): luajit tools/r47_nz/portable_test.lua [REPO]
-- Prints "R47 NZ PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- F. NPC facing --------------------------------------------------------------
do
	local facing = dofile(repo .. "/tools/r47_nz/facing.lua")
	local palettes = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/palette.lua")
	local fails, comps, sockets = facing.run(repo)
	check(comps > 400 and sockets > 1500, "facing: every composition built (" ..
		comps .. " compositions, " .. sockets .. " NPC sockets)")
	check(#fails == 0, "facing: " .. #fails .. " NPCs face a wall:\n" ..
		table.concat(fails, "\n"))

	-- The rule on a hand-made composition: one socket at the origin facing +z.
	local function verdict(cells, socket)
		socket.id, socket.x, socket.y, socket.z = "s", 0, 1, 0
		socket.role = socket.role or "idle"
		socket.dir = socket.dir or {x = 0, z = 1}
		local list = {}
		for _, c in ipairs(cells) do
			list[#list + 1] = {x = c[1], y = c[2], z = c[3], name = c[4]}
		end
		return #facing.check({label = "t", cells = list, sockets = {socket}},
			palettes) == 0
	end
	local wall = "default:stonebrick"
	check(not verdict({{0, 2, 1, wall}}, {}), "rule: a wall a node ahead fails")
	check(not verdict({{0, 2, 2, wall}}, {}), "rule: a wall two nodes ahead fails")
	check(verdict({{0, 2, 3, wall}}, {}), "rule: a wall three nodes ahead passes")
	check(verdict({{0, 2, -1, wall}}, {}), "rule: a wall behind passes")
	check(verdict({{0, 2, 1, wall}}, {dir = {x = 0, z = -1}}),
		"rule: the turned twin passes")
	check(not verdict({{0, 2, -1, "doors:hidden"}}, {dir = {x = 0, z = -1},
		tags = {"work"}}), "rule: a door ahead is a wall")
	check(verdict({{0, 2, -1, "doors:hidden"}}, {dir = {x = 0, z = -1},
		tags = {"work", "door"}}), "rule: `door` turns the facing round")
	check(not verdict({{0, 2, 1, "doors:hidden"}}, {dir = {x = 0, z = -1},
		tags = {"door"}}), "rule: a `door` socket facing away from its door fails")
	check(verdict({{0, 1, 1, "walls:cobble"}}, {}), "rule: a low wall at the feet passes")
	check(verdict({{0, 1, 1, "grug_decor:xdecor_cauldron"}, {0, 2, 1, wall}}, {}),
		"rule: a feature at the feet passes")
	check(verdict({{0, 1, 2, "grug_decor:xdecor_barrel"}, {0, 2, 1, "air"}}, {}),
		"rule: a feature two nodes ahead passes")
	check(verdict({{0, 2, 1, "default:tree"}}, {role = "work", activity = "chop"}),
		"rule: a woodcutter faces its log")
	check(not verdict({{0, 2, 1, "default:tree"}}, {role = "work", activity = "tend"}),
		"rule: a gardener does not")
	check(verdict({{0, 1, 1, "default:stonebrick"}}, {role = "work", activity = "stall"}),
		"rule: a stall's counter under open air passes")
	check(not verdict({{0, 1, 1, "grug_decor:darkage_slate_brick"},
		{0, 2, 1, "xpanes:pane_flat"}}, {role = "work", activity = "stall"}),
		"rule: a wall course under a window is no counter")
	check(verdict({{0, 2, 1, wall}}, {role = "guard_patrol"}),
		"rule: a patrol waypoint is no standing NPC")
end

print("R47 NZ PORTABLE PASS checks=" .. checks)
