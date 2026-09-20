local repo = assert(arg[1], "repository path required")
local function check(value, message)
	if not value then error("R12 farming profiles: " .. message, 0) end
	return value
end

local profiles = assert(loadfile(repo ..
	"/mods/ITEMS/grug_farming/crop_profiles.lua"))()
local expected = {
	wild_grain="annual_low", carrot="annual_low", cassava="annual_low",
	wild_onion="annual_low", fire_pepper="regrow_bush",
	pumpkin="regrow_ground_fruit", blightberry="regrow_bush",
	sunberry="regrow_bush", jungle_berry="regrow_bush",
	frost_melon="regrow_ground_fruit", sugar_cane="vertical_retained",
	bamboo_shoot="vertical_retained", cave_cap="regrow_bush",
	salt_crust="regrow_special", ember_moss="regrow_bush",
	potato="annual_low", corn="vertical_annual",
}
local count = 0
for key, kind in pairs(expected) do
	count = count + 1
	local profile = check(profiles[key], "missing " .. key)
	check(profile.kind == kind, "wrong kind for " .. key)
	if kind:match("^vertical_") then
		check(#profile.heights == 4 and profile.heights[1] == 1,
			"invalid height ladder for " .. key)
	end
	if kind:match("^regrow_") or kind == "vertical_retained" then
		check(profile.regrow_stage == 1 or profile.regrow_stage == 2,
			"missing regrowth stage for " .. key)
	else
		check(profile.regrow_stage == nil, "annual regrows " .. key)
	end
end
local actual = 0
for key in pairs(profiles) do actual = actual + 1; check(expected[key], "extra " .. key) end
check(count == 17 and actual == 17, "population differs")

local visual = assert(loadfile(repo ..
	"/mods/ITEMS/grug_nodes/crop_visual.lua"))()
for key in pairs(expected) do
	for stage = 1, 4 do
		local cultivated = visual(key, stage, {}, "cultivated")
		local wild = visual(key, stage, {}, "wild")
		check(cultivated.selection_box and cultivated.tiles,
			"incomplete cultivated visual " .. key .. "/" .. stage)
		check(wild.visual_scale == (key == "salt_crust" and 1 or 1.15),
			"wild context differs " .. key .. "/" .. stage)
	end
end
io.write("r12_farming_profiles\tPASS\nfamilies\t17\nstages\t68\n")
