-- Seed-0 integration corpus.  The first owner contains the measured connected
-- sinkhole witness from the R8-MAP-A seed-0 engine run (2026-09-18).
-- Keep ten owners so the existing profile harness validates the same population.
assert(core.settings:get("grug_wp40_profile_seed") == "0", "cave corpus requires seed 0")
local cases = {
	{id="connected_sinkhole", x=-1840, y=37, z=-2862, expected_nodes={}},
	{id="capital_region_probe", x=2247, y=38, z=-1749},
	{id="pine_hearthpine_south", x=-1800, y="surface", z=-2470},
	{id="human_capital", x=0, y="surface", z=-1500},
	{id="elandor_front", x=0, y="surface", z=-250},
	{id="broken_causeway", x=-750, y="surface", z=0},
	{id="whitebridge", x=-400, y="surface", z=-1500},
	{id="wyrmglass_channel", x=-2675, y="surface", z=0},
	{id="wyrmglass_island", x=-3260, y="surface", z=-40},
	{id="deep_cross_border", x=-1691, y=-842, z=191},
}
-- Measured against the authored-writer-disabled native-v7 seed-0 baseline:
-- target -1834/19/-2867, 124 exact lumen voxels, 703 native component voxels
-- outside the lumen and 706 total component voxels.  Checking the whole lumen
-- makes a closed mouth or partial surface scar fail this engine fixture.
local target_x, target_y, target_z = -1834, 19, -2867
local steps, seen = cases[1].y + 1 - target_y, {}
local function rounded(numerator, denominator)
	if numerator < 0 then
		return -math.floor((-numerator * 2 + denominator) / (denominator * 2))
	end
	return math.floor((numerator * 2 + denominator) / (denominator * 2))
end
for step = 0, steps do
	local y = cases[1].y + 1 - step
	local center_x = cases[1].x + rounded((target_x - cases[1].x) * step, steps)
	local center_z = cases[1].z + rounded((target_z - cases[1].z) * step, steps)
	local radius = step <= 2 and 2 or 1
	for dx = -radius, radius do for dz = -radius, radius do
		if dx * dx + dz * dz <= radius * radius then
			local key = (center_x + dx) .. "/" .. y .. "/" .. (center_z + dz)
			if not seen[key] then
				seen[key] = true
				cases[1].expected_nodes[#cases[1].expected_nodes + 1] = {
					x = center_x + dx, y = y, z = center_z + dz, name = "air"}
			end
		end
	end end
end
assert(#cases[1].expected_nodes == 124, "connected sinkhole lumen differs")
return cases
