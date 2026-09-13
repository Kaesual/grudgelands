-- Seed-0 integration corpus. Two adjacent owners contain one whole real tube.
-- Keep ten owners so the existing profile harness validates the same population.
assert(core.settings:get("grug_wp40_profile_seed") == "0", "cave corpus requires seed 0")
local cases = {
	{id="cave_west", x=1643, y=72, z=-1983, expected_nodes={}},
	{id="cave_east", x=1674, y=72, z=-1983},
	{id="pine_hearthpine_south", x=-1800, y="surface", z=-2470},
	{id="human_capital", x=0, y="surface", z=-1500},
	{id="elandor_front", x=0, y="surface", z=-250},
	{id="broken_causeway", x=-750, y="surface", z=0},
	{id="whitebridge", x=-400, y="surface", z=-1500},
	{id="wyrmglass_channel", x=-2675, y="surface", z=0},
	{id="wyrmglass_island", x=-3260, y="surface", z=-40},
	{id="deep_cross_border", x=-1691, y=-842, z=191},
}
-- Witness generated independently by the production candidate search.
-- This tube extends east; all 32 radius-2 circular sections must remain air.
for forward=0,31 do
	local center_y=73-math.floor(forward/4)
	for side=-2,2 do
		local radius_y=math.floor(math.sqrt(4-side*side))
		for y=center_y-radius_y,center_y+radius_y do
			cases[1].expected_nodes[#cases[1].expected_nodes+1] = {
				x=1643+forward, y=y, z=-1983+side, name="air"}
		end
	end
end
return cases
