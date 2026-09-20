-- Independent oracle for the accepted universal Basics equipment grids.
-- Usage: luajit -e 'io.write(dofile("tools/r10_equip/base_recipes_kat.lua")("."))'
return function(repo)
	local saved = {core = core, grug_professions = grug_professions,
		grug_gear = grug_gear}
	local crafts, items = {}, {}
	core = {registered_items = {["grug_farming:hoe"] = {}}}
	local clears = {}
	function core.clear_craft(def) clears[def.output] = (clears[def.output] or 0) + 1 end
	function core.register_craft(def)
		local output = def.output:match("^([^%s]+)")
		crafts[output] = crafts[output] or {}
		crafts[output][#crafts[output] + 1] = def.recipe
	end
	grug_professions = {register_item = function(name) items[name] = true return name end}
	grug_gear = {
		BRACKET_TINT = {"a", "b", "c", "d", "e", "f"},
		MATERIALS = {
			{metal={name="Bronze"}}, {metal={name="Iron"}},
			{metal={name="Steel"}}, {metal={name="Silversteel"}},
			{metal={name="Embersteel"}}, {metal={name="Abyssal Steel"}},
		},
	}
	local ok, problem = pcall(dofile, repo ..
		"/mods/ITEMS/grug_professions/base_recipes.lua")
	if not ok then
		core, grug_professions, grug_gear = saved.core, saved.grug_professions,
			saved.grug_gear
		error(problem, 0)
	end
	local function fail(message)
		core, grug_professions, grug_gear = saved.core, saved.grug_professions,
			saved.grug_gear
		error("r10 base recipes: " .. message, 0)
	end
	local function flat(recipe)
		local out = {}
		for row = 1, #recipe do
			for column = 1, #recipe[row] do
				local item = recipe[row][column]
				if item and item ~= "" then out[#out + 1] = item end
			end
		end
		return table.concat(out, ",")
	end
	local metals = {"bronze", "iron", "steel", "silversteel", "embersteel",
		"abyssal_steel"}
	local bars = {}
	local axes = {"default:axe_bronze", "grug_materials:axe_iron",
		"default:axe_steel", "grug_materials:axe_silversteel",
		"grug_materials:axe_embersteel", "grug_materials:axe_abyssal_steel"}
	for tier = 1, 6 do bars[tier] = "grug_materials:" .. metals[tier] .. "_bar" end
	local armor_counts = {head=5, chest=8, legs=7, feet=4}
	local checked = 0
	local sticks = crafts["default:stick"]
	if clears["default:stick"] ~= 1 or not sticks or #sticks ~= 1 or
			#sticks[1] ~= 2 or #sticks[1][1] ~= 1 or #sticks[1][2] ~= 1 or
			flat(sticks[1]) ~= "group:wood,group:wood" then
		fail("stick path is not exactly two vertical planks")
	end
	for tier = 1, 6 do
		local metal, bar = metals[tier], bars[tier]
		local rod = "grug_professions:metal_rod_" .. metal
		if not items[rod] then fail("missing rod " .. rod) end
		local sword = crafts["grug_gear:sword_" .. metal]
		if #sword ~= 2 or flat(sword[1]) ~= table.concat({bar,bar,"group:stick"},",") or
				flat(sword[2]) ~= table.concat({bar,bar,rod},",") then
			fail(metal .. " sword routes differ")
		end
		local axe_routes = crafts[axes[tier]]
		if not axe_routes or #axe_routes ~= 2 then
			fail(metal .. " axe lacks its mirrored recipe")
		end
		local expected = {
			dagger = bar .. ",group:stick",
			greataxe = table.concat({bar,bar,bar,bar,"group:stick",bar,"group:stick"},","),
			wand = "grug_artisans:" .. ({"seasoned","polished","hardened","inlaid","lacquered","heartwood"})[tier] .. "_wood,group:stick",
			scepter = bar .. ",grug_artisans:" .. ({"seasoned","polished","hardened","inlaid","lacquered","heartwood"})[tier] .. "_wood,group:stick",
		}
		for family, sequence in pairs(expected) do
			local routes = crafts["grug_gear:" .. family .. "_" .. metal]
			if not routes or #routes ~= 2 or flat(routes[1]) ~= sequence then
				fail(metal .. " " .. family .. " differs")
			end
		end
		local wood = "grug_artisans:" .. ({"seasoned","polished","hardened","inlaid","lacquered","heartwood"})[tier] .. "_wood"
		local orb = crafts["grug_gear:orb_" .. metal]
		if not orb or #orb ~= 1 or flat(orb[1]) ~= table.concat({wood,wood,wood,wood},",") then
			fail(metal .. " orb is not four wood")
		end
		if flat(orb[1]):find("diamond", 1, true) then fail(metal .. " orb has a gem") end
		local staff = crafts["grug_gear:staff_" .. metal]
		if not staff or flat(staff[1]) ~= table.concat({wood,wood,wood},",") then
			fail(metal .. " staff differs")
		end
		for slot, count in pairs(armor_counts) do
			local recipe = crafts["grug_gear:" .. slot .. "_metal_" .. metal]
			local actual = 0
			for _ in flat(recipe[1]):gmatch("[^,]+") do actual = actual + 1 end
			if actual ~= count then fail(metal .. " " .. slot .. " count differs") end
		end
		checked = checked + 1
	end
	local hoes=crafts["grug_farming:hoe"]
	if not hoes or #hoes~=2 then fail("Farmer's Hoe lacks mirrored recipes") end
	core, grug_professions, grug_gear = saved.core, saved.grug_professions,
		saved.grug_gear
	return "r10_base_recipes\t" .. checked .. " tiers\tcanonical grids\tPASS\n"
end
