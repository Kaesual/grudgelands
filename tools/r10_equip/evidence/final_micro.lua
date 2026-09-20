local repo = assert(arg[1], "repository path required")
local tests = {
	"tools/r8_prof/framework_kat.lua",
	"tools/r8_prof/geometry_kat.lua",
	"tools/r8_prof/scaling_kat.lua",
	"tools/r8_prof/trainer_sockets_kat.lua",
	"tools/r9_prof/blacksmith_kat.lua",
	"tools/r9_prof/leatherworker_kat.lua",
	"tools/r9_prof/tailor_kat.lua",
	"tools/r9_prof/woodcarver_kat.lua",
	"tools/r9_prof/goldsmith_kat.lua",
	"tools/r9_prof/stations_kat.lua",
	"tools/r9_ench/quality_kat.lua",
	"tools/wp13/gear_catalogue_kat.lua",
	"tools/r10_equip/base_recipes_kat.lua",
	"tools/r10_equip/profession_contract_kat.lua",
	"tools/r10_equip/vendor_rotation_kat.lua",
}
for index = 1, #tests do
	local run = assert(dofile(repo .. "/" .. tests[index]))
	local output = run(repo)
	if output then io.write(output) end
end
