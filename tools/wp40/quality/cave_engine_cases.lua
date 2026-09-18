-- Seed-0 integration corpus.  The first owner contains the measured connected
-- sinkhole witness from the R8-MAP-A seed-0 engine run (2026-09-18).
-- Keep ten owners so the existing profile harness validates the same population.
assert(core.settings:get("grug_wp40_profile_seed") == "0", "cave corpus requires seed 0")
local cases = {
	{id="connected_sinkhole", x=-1840, y=37, z=-2862, expected_nodes={}},
	{id="capital_sinkhole", x=2247, y=38, z=-1749},
	{id="pine_hearthpine_south", x=-1800, y="surface", z=-2470},
	{id="human_capital", x=0, y="surface", z=-1500},
	{id="elandor_front", x=0, y="surface", z=-250},
	{id="broken_causeway", x=-750, y="surface", z=0},
	{id="whitebridge", x=-400, y="surface", z=-1500},
	{id="wyrmglass_channel", x=-2675, y="surface", z=0},
	{id="wyrmglass_island", x=-3260, y="surface", z=-40},
	{id="deep_cross_border", x=-1691, y=-842, z=191},
}
-- The writer's radius-1 mouth cross distinguishes a carved sinkhole from a
-- coincidental native surface-air node.  All five nodes were measured as air;
-- the engine probe also measured its component outside the authored shaft.
local cross = {{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}
for index = 1, #cross do
	cases[1].expected_nodes[#cases[1].expected_nodes + 1] = {
		x = cases[1].x + cross[index][1], y = cases[1].y,
		z = cases[1].z + cross[index][2], name = "air"}
end
return cases
