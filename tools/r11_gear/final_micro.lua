local repo = assert(arg[1], "repository path required")
local tests = {
 "tools/r9_ench/quality_kat.lua",
 "tools/r10_equip/base_recipes_kat.lua",
 "tools/r10_equip/profession_contract_kat.lua",
 "tools/r10_equip/vendor_rotation_kat.lua",
	"tools/wp13/gear_catalogue_kat.lua",
	"tools/r9_prof/goldsmith_kat.lua",
	"tools/r9_prof/stations_kat.lua",
 "tools/r11_gear/ammo_kat.lua",
 "tools/r11_gear/book_mastery_kat.lua",
}
for _, path in ipairs(tests) do io.write(assert(dofile(repo .. "/" .. path))(repo)) end
