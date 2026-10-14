-- Disposable engine probe (Round 48 lane FARM). Never shipped: staged by
--   PROBE=tools/r48_farm/grug_probe_farm tools/luanti_headless.sh 240
-- In the real engine: the noon light the plant rule reads (a closed stone
-- box high in the sky, dark, then a Coal torch beside the crop; a glass roof
-- for natural light), the registered Salt Pan recipe, the tooltips and the
-- wild looks. Prints "[farm_probe] RESULT PASS|FAIL" and shuts down.
local P = "[farm_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then log("ok   " .. msg) else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
end

local function finish()
	log("RESULT " .. (failures == 0 and "PASS" or "FAIL") .. " checks=" .. checks)
	core.request_shutdown("farm probe done", false, 0)
end

local function registrations()
	local recipes = grug_jobs.recipes_for_output("grug_farming:salt_pan")
	check(#recipes == 1, "one Salt Pan recipe is registered")
	local names = {}
	for _, entry in ipairs(recipes[1] and recipes[1].ingredients or {}) do
		names[#names + 1] = (entry.item or entry.group) .. "*" .. entry.n
	end
	table.sort(names)
	log("salt pan recipe: " .. table.concat(names, " "))
	check(#grug_jobs.recipes_for_output("grug_farming:seed_mushroom") == 1, "the Mushroom Spores recipe")
	check(core.registered_items["grug_farming:seed_salt_crust"] == nil, "no Salt Crust seeds")
	for _, name in ipairs({"grug_cooking:carrot", "grug_farming:seed_carrot",
			"grug_farming:seed_mushroom", "grug_gathering:mushroom", "default:papyrus",
			"default:cactus", "default:sapling", "grug_gathering:sunleaf",
			"grug_farming:salt_pan", "grug_cooking:salt_crust"}) do
		log("tooltip " .. name .. ": " ..
			core.get_translated_string("en", core.registered_items[name].description):gsub("\n", " | "))
	end
	for _, key in ipairs({"potato", "corn", "melon", "mushroom", "sunleaf"}) do
		local def = core.registered_nodes["grug_gathering:" .. key .. "_source"]
		log("source " .. key .. ": " .. tostring(def.tiles[1].name or def.tiles[1]) ..
			" scale " .. tostring(def.visual_scale))
	end
	check(core.registered_nodes["grug_gathering:melon_source"].visual_scale == 1.15,
		"the wild Melon wears the wild crop scale")
end

-- A closed 5 x 5 x 5 stone box (inner 3 x 3 x 3) high in the sky.
local BASE = {x = 40, y = 400, z = 40}
local function at(dx, dy, dz) return {x = BASE.x + dx, y = BASE.y + dy, z = BASE.z + dz} end
local function light_tests()
	for x = 0, 4 do for y = 0, 4 do for z = 0, 4 do
		local edge = x == 0 or x == 4 or y == 0 or y == 4 or z == 0 or z == 4
		core.set_node(at(x, y, z), {name = edge and "default:stone" or "air"})
	end end end
	local crop = at(2, 1, 2)
	core.set_node(crop, {name = "grug_farming:carrot_1"})
	log("dark box: noon light " .. tostring(core.get_node_light(crop, 0.5)) ..
		", natural " .. tostring(core.get_natural_light(crop, 0.5)))
	check(not default.plant_lit(crop), "a closed box is too dark for plants")
	core.set_node(at(1, 1, 2), {name = "default:torch", param2 = 1})
	log("torch beside it: noon light " .. tostring(core.get_node_light(crop, 0.5)) ..
		", at midnight " .. tostring(core.get_node_light(crop, 0)))
	check(default.plant_lit(crop), "a Coal torch beside the crop gives plant light")
	check((core.get_natural_light(crop, 0.5) or 0) < 13, "a torch gives no natural light")
	-- Two nodes from the torch (light 12 - 2 = 10) still grows; light falls
	-- by one per node.
	local far = at(3, 1, 3)
	log("two nodes from the torch: " .. tostring(core.get_node_light(far, 0.5)))
	-- A glass roof: natural light for a sapling.
	for x = 1, 3 do for z = 1, 3 do core.set_node(at(x, 4, z), {name = "default:glass"}) end end
	core.set_node(at(1, 1, 2), {name = "air"})
	log("glass roof: natural light " .. tostring(core.get_natural_light(crop, 0.5)))
	check((core.get_natural_light(crop, 0.5) or 0) >= 13, "a glass roof lets the sun through")
	core.set_node(at(2, 0, 2), {name = "default:dirt"})
	check(default.can_grow(crop), "a sapling under glass on dirt can grow")
	for x = 1, 3 do for z = 1, 3 do core.set_node(at(x, 4, z), {name = "default:stone"}) end end
	core.set_node(at(1, 1, 2), {name = "grug_materials:anthracite_torch", param2 = 1})
	check(not default.can_grow(crop), "a sapling under stone beside an Anthracite torch cannot grow")
	check(default.plant_lit(crop), "...while a crop there has plant light")
end

core.after(1, function()
	registrations()
	core.emerge_area(at(-8, -8, -8), at(12, 12, 12), function(_, _, remaining)
		if remaining > 0 then return end
		local ok, err = pcall(light_tests)
		check(ok, "light tests ran (" .. tostring(err) .. ")")
		finish()
	end)
end)
