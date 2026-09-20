local repo = assert(arg[1])
-- Integration replacements use the current shared modules and CAP-updated
-- trainer/station fixtures. Each returned fixture restores its own stubs.
local function run(relative, options)
	local result = assert(dofile(repo .. "/" .. relative))(repo, options)
	if result then io.write(result) end
	collectgarbage("collect")
end
for _, relative in ipairs({
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
	"tools/r10_cap/geometry_micro.lua",
	"tools/r10_cap/services_micro.lua",
	"tools/r10_cap/purchase_micro.lua",
	"tools/r10_cap/furnace_micro.lua",
	"tools/wp13/character_visuals_kat.lua",
	"tools/r10_art/mount_icon_kat.lua",
	"tools/r10_art/art_kat.lua",
	"tools/r10_gameplay/cliff_kat.lua",
	"tools/r6_food_buffs/kat.lua",
	"tools/r8_mob1/bosses_kat.lua",
}) do run(relative) end
-- The full mount binary/asset audit belongs to LuaJIT development only.
run("tools/r9_mounts/mounts_kat.lua", {compact = true})
run("tools/r10_gameplay/potion_kat.lua")
-- This standalone fixture reads arg[1], prints its canonical output and leaves
-- globals installed. It must stay last; do not append returned fixtures below.
dofile(repo .. "/tools/wp39/combat_integration_test.lua")
